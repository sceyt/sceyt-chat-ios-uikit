#!/usr/bin/env python3
"""Keeps the transfer layer's failures visible and its logs searchable.

Fails on:
  * a logger call whose message is empty or does not start with a known tag
    ([Transfer], [Attachment], [Encryption]); a message passed as a variable built
    elsewhere (`logger.error(line)`) is allowed;
  * `logger.errorIfNotNil`, which logs whatever text it is given, often none;
  * an empty `catch {}`;
  * a `try?` on a file change (remove, create, move, copy, write): a failure there must be
    logged, for example through `TransferLog.remove`.

Usage: python3 -I scripts/check_transfer_logs.py PATH...   (files or directories)
Dependency-free; exits 1 when it finds a problem.
"""

import os
import re
import sys

TAGS = ("[Transfer]", "[Attachment]", "[Encryption]")
LOG_CALL = re.compile(r"\blogger\.(verbose|debug|info|warn|warning|error|fatal)\(\s*")
FILE_CHANGE = re.compile(
    r"try\?\s*[\w.()]*\b(removeItem|createDirectory|moveItem|copyItem|replaceItemAt|write)\("
)
EMPTY_CATCH = re.compile(r"\bcatch\s*\{\s*\}")


def line_of(text, index):
    return text.count("\n", 0, index) + 1


def check_file(path):
    problems = []
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    for match in LOG_CALL.finditer(text):
        rest = text[match.end():]
        if rest.startswith('"'):
            message = rest[1:]
            if message.startswith('"') or not message.startswith(TAGS):
                head = message.split('"', 1)[0][:40]
                problems.append((line_of(text, match.start()), f"log message without a known tag: \"{head}\""))
        elif not re.match(r"[A-Za-z_]\w*\s*\)", rest):
            problems.append((line_of(text, match.start()), "log message is neither a tagged literal nor a prebuilt line"))
    for match in re.finditer(r"\blogger\.errorIfNotNil\(", text):
        problems.append((line_of(text, match.start()), "errorIfNotNil: log the failure with a tagged message"))
    for match in EMPTY_CATCH.finditer(text):
        problems.append((line_of(text, match.start()), "empty catch: log or handle the error"))
    for match in FILE_CHANGE.finditer(text):
        problems.append((line_of(text, match.start()), f"try? on {match.group(1)}: a failed file change must be logged"))
    return problems


def swift_files(paths):
    for path in paths:
        if os.path.isdir(path):
            for root, _, names in os.walk(path):
                for name in sorted(names):
                    if name.endswith(".swift"):
                        yield os.path.join(root, name)
        else:
            yield path


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip())
        return 2
    files = list(swift_files(argv[1:]))
    count = 0
    for path in files:
        for line, message in check_file(path):
            print(f"{path}:{line}: {message}")
            count += 1
    print(f"{len(files)} file(s) checked, {count} problem(s)")
    return 1 if count else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
