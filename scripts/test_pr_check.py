"""Local fixtures only; these are not reports from smoke runs."""
from contextlib import redirect_stdout
from io import StringIO
from subprocess import CompletedProcess
import unittest
from unittest.mock import patch

import pr_check


class BaselineTest(unittest.TestCase):
    def test_baseline_provenance(self):
        head, fork_base, ancestor, other_main, feature = (c * 40 for c in "abcde")
        sections = "**Tested**\nfixture\n**Not tested**\nfixture\n**AI use**\nnone\n"
        runtime_path = "crates/xcl/src/runtime.rs"
        args = ["pr_check.py", "--body", "body.md", "--head", head, "--files", "files.tsv",
                "--repo", "fixture/fork"]

        def smoke(commit):
            return (f"xcl-smoke v1\ncommit: {commit}\ntitle: LOCAL TEST FIXTURE ONLY\n"
                    "seconds: 60\nframes shown: 100\npeak commit: 100\n"
                    "device removals: 0\ncrashes: 0\nexit: 0x0\n```\n")

        for baseline, status, accepted in ((fork_base, "identical", True),
                                           (ancestor, "ahead", True),
                                           (other_main, "behind", False),
                                           (feature, "diverged", False),
                                           (None, None, True)):
            with self.subTest(baseline=baseline):
                contents = {
                    "body.md": sections + (smoke(head) + smoke(baseline) if baseline else ""),
                    "files.tsv": f"{runtime_path if baseline else 'crates/xcl/src/tests.rs'}\tmodified\tfalse\tfixture\n",
                }
                with (patch("sys.argv", args + ["--base", fork_base]),
                      patch("builtins.open", side_effect=lambda path, **_: StringIO(contents[path])),
                      patch.object(pr_check.subprocess, "run", return_value=CompletedProcess(
                          [], 0, status)) as compare,
                      redirect_stdout(StringIO()) as output):
                    if accepted:
                        pr_check.main()
                        self.assertEqual(output.getvalue().strip(), "description ok")
                    else:
                        with self.assertRaises(SystemExit) as error:
                            pr_check.main()
                        self.assertEqual(error.exception.code, 1)
                        self.assertIn("PR base commit or an ancestor", output.getvalue())

                if baseline:
                    compare.assert_called_once_with(
                        ["gh", "api", f"repos/fixture/fork/compare/{baseline}...{fork_base}", "--jq", ".status"],
                        capture_output=True, text=True)
                else:
                    compare.assert_not_called()


if __name__ == "__main__":
    unittest.main()
