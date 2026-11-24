#!/usr/bin/env python3
"""Check the formatting, compiler warnings, and test coverage of changed lines.

Each command compares HEAD with its merge base with a target branch or commit,
so commit the change before running a command locally.
"""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "Package.swift"
PACKAGE_SOURCES = "Sources/SceytChatUIKit/"
SOURCE_SUFFIXES = (".swift", ".h", ".m")
EXECUTABLE_SUFFIXES = (".swift",)
MIN_COVERAGE = 80
HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", re.MULTILINE)
WARNING = re.compile(r"^(/[^:\n]+):(\d+):\d+: warning: ([^\n]*)", re.MULTILINE)
# Paths that Package.swift takes out of compilation: exclude lists and resource rules.
EXCLUDE_LIST = re.compile(r"\bexclude:\s*\[([^\]]*)\]")
RESOURCE_RULE = re.compile(r"\.(?:process|copy)\(\s*\"([^\"]+)\"")
QUOTED = re.compile(r"\"([^\"]+)\"")


def git(*args):
    return subprocess.check_output(
        ["git", "--literal-pathspecs", *args],
        cwd=ROOT,
        encoding="utf-8",
        errors="surrogateescape",
    )


def merge_base(target):
    return git("merge-base", "--", target, "HEAD").strip()


def changed_sources(base):
    """Yield (old path, path) for source files that HEAD adds, modifies, or renames."""
    entries = iter(git(
        "diff", "--name-status", "-z", "--find-renames", "--diff-filter=AMRT", base, "HEAD",
    ).split("\0")[:-1])
    for status in entries:
        old_path = next(entries)
        path = next(entries) if status.startswith("R") else old_path
        if path.endswith(SOURCE_SUFFIXES):
            yield old_path, path


def changed_lines(target):
    """Map each changed source file to the HEAD line numbers that it adds or modifies."""
    base = merge_base(target)
    result = {}
    for old_path, path in changed_sources(base):
        revisions = (
            (f"{base}:{old_path}", f"HEAD:{path}")
            if old_path != path else (base, "HEAD", "--", path)
        )
        diff = git("diff", "--no-color", "--no-ext-diff", "--no-textconv", "--unified=0", *revisions)
        lines = set()
        for start, length in HUNK.findall(diff):
            first_line = int(start)
            lines.update(range(first_line, first_line + int(length or "1")))
        if lines:
            result[path] = lines
    return result


def relative_to_root(path):
    path = os.path.realpath(path)
    root = os.path.realpath(ROOT) + os.sep
    return path[len(root):] if path.startswith(root) else None


def format_problems(data):
    """Apply the .editorconfig rules for Swift and Objective-C sources."""
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return ["is not valid UTF-8"]

    problems = []
    if "\r" in text:
        problems.append("uses CR line endings instead of LF")
    if text and not text.endswith("\n"):
        problems.append("does not end with a newline")
    tabbed = [
        number for number, line in enumerate(text.split("\n"), 1)
        if "\t" in line[:len(line) - len(line.lstrip(" \t"))]
    ]
    if tabbed:
        shown = ", ".join(map(str, tabbed[:10]))
        problems.append(f"indents with tabs on lines {shown}{' and more' if len(tabbed) > 10 else ''}")
    return problems


def check_format(target):
    failed = False
    for _, path in changed_sources(merge_base(target)):
        data = subprocess.check_output(["git", "show", f"HEAD:{path}"], cwd=ROOT)
        for problem in format_problems(data):
            print(f"{path}: {problem}")
            failed = True
    if not failed:
        print("Changed source files match .editorconfig.")
    return int(failed)


def warnings_on_lines(log, changed):
    """Return compiler warnings reported on the changed lines of repository files."""
    found = set()
    for match in WARNING.finditer(log):
        path = relative_to_root(match[1])
        line = int(match[2])
        if path is not None and line in changed.get(path, ()):
            found.add((path, line, match[3].strip()))
    return sorted(found)


def check_warnings(target, log_path):
    log = Path(log_path).read_text(encoding="utf-8", errors="replace")
    if not log.strip():
        raise ValueError(f"{log_path} is empty")

    warnings = warnings_on_lines(log, changed_lines(target))
    for path, line, message in warnings:
        print(f"{path}:{line}: warning: {message}")
    if warnings:
        print(f"Fix the {len(warnings)} compiler warning(s) reported on changed lines.")
        return 1
    print("No compiler warnings on changed lines.")
    return 0


def read_coverage(result_bundle):
    output = subprocess.check_output(
        ["xcrun", "xccov", "view", "--archive", "--json", str(result_bundle)],
        cwd=ROOT,
    )
    coverage = {}
    for file, lines in json.loads(output).items():
        path = relative_to_root(file)
        if path is not None and path.startswith(PACKAGE_SOURCES):
            coverage[path] = {
                line["line"]: line.get("executionCount", 0) > 0
                for line in lines if line["isExecutable"]
            }
    if not any(any(lines.values()) for lines in coverage.values()):
        raise ValueError(f"{result_bundle} has no {PACKAGE_SOURCES} line coverage data")
    return coverage


def in_package_target(path, manifest=None):
    """Return whether SwiftPM compiles the file into the SceytChatUIKit target.

    SwiftPM compiles every Swift file under the target directory except the
    paths that Package.swift excludes or declares as resources.
    """
    if not (path.startswith(PACKAGE_SOURCES) and path.endswith(EXECUTABLE_SUFFIXES)):
        return False
    if manifest is None:
        manifest = PACKAGE.read_text(encoding="utf-8")
    removed = [entry for block in EXCLUDE_LIST.findall(manifest) for entry in QUOTED.findall(block)]
    removed += RESOURCE_RULE.findall(manifest)
    relative = path[len(PACKAGE_SOURCES):]
    return not any(
        relative == entry.rstrip("/") or relative.startswith(entry.rstrip("/") + "/")
        for entry in removed
    )


def check_coverage(target, result_bundle):
    changes = {
        path: lines for path, lines in changed_lines(target).items()
        if path.startswith(PACKAGE_SOURCES) and path.endswith(EXECUTABLE_SUFFIXES)
    }
    if not changes:
        print(f"No added or modified {PACKAGE_SOURCES} lines.")
        return 0

    coverage = read_coverage(result_bundle)
    total = covered = 0
    for path, changed in sorted(changes.items()):
        if path not in coverage:
            # Compiled files without executable code, such as declarations, have no coverage data.
            if in_package_target(path):
                continue
            raise ValueError(f"{path!r} has no coverage data and is not compiled by the package")

        executable = changed & coverage[path].keys()
        uncovered = sorted(line for line in executable if not coverage[path][line])
        total += len(executable)
        covered += len(executable) - len(uncovered)
        if uncovered:
            print(f"{path!r}: uncovered lines {', '.join(map(str, uncovered))}")

    if total == 0:
        print(f"No changed executable {PACKAGE_SOURCES} lines.")
        return 0

    print(f"Changed {PACKAGE_SOURCES} line coverage: {covered / total:.2%} ({covered}/{total}, required {MIN_COVERAGE}%)")
    return int(covered * 100 < total * MIN_COVERAGE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)

    format_command = commands.add_parser("format", help="check changed sources against .editorconfig")
    format_command.add_argument("base", help="target branch or commit to compare with HEAD")

    warnings_command = commands.add_parser("warnings", help="fail on compiler warnings on changed lines")
    warnings_command.add_argument("base", help="target branch or commit to compare with HEAD")
    warnings_command.add_argument("log", help="xcodebuild output that compiled the changed files")

    # argparse formats help with %, so a literal percent sign is written %%.
    coverage_command = commands.add_parser(
        "coverage", help=f"require {MIN_COVERAGE}%% coverage of changed {PACKAGE_SOURCES} lines",
    )
    coverage_command.add_argument("base", help="target branch or commit to compare with HEAD")
    coverage_command.add_argument("result_bundle", help="test .xcresult recorded with code coverage")

    args = parser.parse_args()
    try:
        if args.command == "format":
            return check_format(args.base)
        if args.command == "warnings":
            return check_warnings(args.base, args.log)
        return check_coverage(args.base, args.result_bundle)
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError, KeyError, ValueError) as error:
        print(f"{args.command} check failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
