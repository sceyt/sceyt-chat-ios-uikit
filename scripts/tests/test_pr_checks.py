"""Exercise the changed-line checks without git history or a result bundle."""

from contextlib import ExitStack, redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import pr_checks  # noqa: E402


ROOT = pr_checks.ROOT
SOURCE = "Sources/SceytChatUIKit/Data Providers/ChannelMessageProvider.swift"


class HelpTest(unittest.TestCase):
    def test_help_formats_every_command(self):
        # Python 3.15 formats help strings when a command is added; earlier versions do so here.
        output = StringIO()
        with redirect_stdout(output), patch.object(sys, "argv", ["pr_checks.py", "--help"]):
            with self.assertRaises(SystemExit) as exit:
                pr_checks.main()

        self.assertEqual(exit.exception.code, 0)
        self.assertIn("require 80% coverage of changed", output.getvalue())


class ChangedLinesTest(unittest.TestCase):
    def test_rename_counts_single_and_multiple_added_lines(self):
        before = "Sources/SceytChatUIKit/Utils/Before.swift"
        after = "Sources/SceytChatUIKit/Utils/After.swift"
        diff = (
            "@@ -2 +3 @@\n-before\n+after\n"
            "@@ -7 +8,2 @@\n-before\n+first\n+second\n"
            "@@ -13 +14,0 @@\n-removed\n"
        )

        with patch.object(pr_checks, "git", side_effect=[
            "base\n", f"R090\0{before}\0{after}\0", diff
        ]) as git:
            self.assertEqual(pr_checks.changed_lines("target"), {after: {3, 8, 9}})

        self.assertEqual(git.call_args.args[-2:], (f"base:{before}", f"HEAD:{after}"))

    def test_ignores_non_source_files_and_keeps_paths_with_spaces(self):
        listing = (
            "M\0Sources/SceytChatUIKit/Resources/Images.xcassets/Contents.json\0"
            "M\0README.md\0"
            f"M\0{SOURCE}\0"
            "A\0Sources/SceytChatUIKitObjCSupport/ObjCExceptionCatcher.m\0"
        )
        with patch.object(pr_checks, "git", return_value=listing):
            self.assertEqual(
                [path for _, path in pr_checks.changed_sources("base")],
                [SOURCE, "Sources/SceytChatUIKitObjCSupport/ObjCExceptionCatcher.m"],
            )


class FormatTest(unittest.TestCase):
    def test_accepts_space_indentation_and_final_newline(self):
        self.assertEqual(pr_checks.format_problems(b"struct A {\n    let b = 1\t// aligned\n}\n"), [])

    def test_reports_each_editorconfig_rule(self):
        self.assertEqual(
            pr_checks.format_problems(b"struct A {\r\n\tlet b = 1\r\n}"),
            [
                "uses CR line endings instead of LF",
                "does not end with a newline",
                "indents with tabs on lines 2",
            ],
        )
        self.assertEqual(pr_checks.format_problems(b"\xff\n"), ["is not valid UTF-8"])


class WarningsTest(unittest.TestCase):
    def test_reports_only_warnings_on_changed_repository_lines(self):
        log = "\n".join([
            f"{ROOT}/{SOURCE}:12:5: warning: changed line",
            f"{ROOT}/{SOURCE}:12:5: warning: changed line",
            f"{ROOT}/{SOURCE}:13:1: warning: unchanged line",
            f"{ROOT}/Sources/SceytChatUIKit/Other.swift:12:1: warning: unchanged file",
            "/DerivedData/SourcePackages/artifacts/SceytChat.h:12:1: warning: dependency",
            f"{ROOT}/{SOURCE}:14:2: error: not a warning",
        ])

        self.assertEqual(
            pr_checks.warnings_on_lines(log, {SOURCE: {12, 14}}),
            [(SOURCE, 12, "changed line")],
        )


class PackageTargetTest(unittest.TestCase):
    MANIFEST = """
        .target(
            name: "SceytChatUIKit",
            exclude: ["Legacy", "Debug/Probe.swift"],
            resources: [.process("Database/SceytChatModel.xcdatamodeld"), .process("Resources")]
        ),
    """

    def test_compiles_swift_files_in_the_target_directory(self):
        self.assertTrue(pr_checks.in_package_target(SOURCE, self.MANIFEST))
        self.assertTrue(pr_checks.in_package_target("Sources/SceytChatUIKit/LegacyKit.swift", self.MANIFEST))

    def test_excluded_resource_and_outside_paths_are_not_compiled(self):
        for path in (
            "Sources/SceytChatUIKit/Legacy/Old.swift",
            "Sources/SceytChatUIKit/Debug/Probe.swift",
            "Sources/SceytChatUIKit/Resources/Template.swift",
            "Sources/SceytChatUIKitObjCSupport/ObjCExceptionCatcher.m",
            "Tests/SceytChatUIKitTests/TransferStoreTests.swift",
        ):
            with self.subTest(path=path):
                self.assertFalse(pr_checks.in_package_target(path, self.MANIFEST))

    def test_reads_the_repository_manifest(self):
        self.assertTrue(pr_checks.in_package_target(SOURCE))


class CoverageThresholdTest(unittest.TestCase):
    def run_check(self, changes, coverage, in_package=True):
        output = StringIO()
        with ExitStack() as stack:
            stack.enter_context(redirect_stdout(output))
            stack.enter_context(redirect_stderr(output))
            stack.enter_context(patch.object(sys, "argv", ["pr_checks.py", "coverage", "base", "Tests.xcresult"]))
            stack.enter_context(patch.object(pr_checks, "changed_lines", return_value=changes))
            stack.enter_context(patch.object(pr_checks, "read_coverage", return_value=coverage))
            stack.enter_context(patch.object(pr_checks, "in_package_target", return_value=in_package))
            return pr_checks.main(), output.getvalue()

    def test_passes_at_80_percent_and_fails_below(self):
        executable = range(1, 101)

        for covered, expected in ((80, 0), (79, 1)):
            with self.subTest(covered=covered):
                result, output = self.run_check(
                    {SOURCE: set(executable)},
                    {SOURCE: {line: line <= covered for line in executable}},
                )
                self.assertEqual(result, expected)
                self.assertIn(f"{covered}.00% ({covered}/100, required 80%)", output)

    def test_ignores_test_and_objc_support_sources(self):
        result, output = self.run_check({
            "Tests/SceytChatUIKitTests/TransferStoreTests.swift": {1},
            "Sources/SceytChatUIKitObjCSupport/ObjCExceptionCatcher.m": {2},
        }, {})
        self.assertEqual(result, 0)
        self.assertIn("No added or modified Sources/SceytChatUIKit/ lines.", output)

    def test_skips_compiled_file_without_executable_lines(self):
        result, output = self.run_check(
            {"Sources/SceytChatUIKit/Models/Payload.swift": {3}}, {SOURCE: {}}
        )
        self.assertEqual(result, 0)
        self.assertIn("No changed executable Sources/SceytChatUIKit/ lines.", output)

    def test_fails_for_file_the_package_does_not_compile(self):
        result, output = self.run_check(
            {"Sources/SceytChatUIKit/Legacy/Old.swift": {3}}, {SOURCE: {}}, in_package=False
        )
        self.assertEqual(result, 1)
        self.assertIn("is not compiled by the package", output)


if __name__ == "__main__":
    unittest.main()
