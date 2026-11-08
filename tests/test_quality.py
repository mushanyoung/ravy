"""Quality gate failure propagation and progressive-document navigation."""

import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import check_docs
import quality


class QualityTests(unittest.TestCase):
    def test_failed_stage_keeps_diagnostics_and_runs_remaining_stages(self):
        failed = Mock(stdout=io.StringIO("assertion failed\n"))
        failed.wait.return_value = 7
        passed = Mock(stdout=io.StringIO("build passed\n"))
        passed.wait.return_value = 0
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            with (
                patch.object(quality, "STAGES", ("unit", "build")),
                patch.object(quality.subprocess, "Popen", side_effect=[failed, passed]),
            ):
                self.assertFalse(quality.check(output))
            results = json.loads((output / "summary.json").read_text())
            self.assertEqual([row["exit_code"] for row in results], [7, 0])
            self.assertEqual((output / "unit.log").read_text(), "assertion failed\n")
            self.assertEqual((output / "build.log").read_text(), "build passed\n")

    def test_failed_server_suite_still_runs_developer_and_fails_gate(self):
        with (
            patch.object(quality.sys, "platform", "linux"),
            patch.object(
                quality,
                "run",
                side_effect=[subprocess.CalledProcessError(1, "server"), None],
            ) as run,
        ):
            with self.assertRaisesRegex(ValueError, "E2E series failed"):
                quality.e2e()
            self.assertEqual(
                [call.args[-1] for call in run.call_args_list], ["server", "developer"]
            )

    def test_links_allow_fragments_and_encoded_paths_but_reject_missing_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "a b.md").write_text("# Example\n")
            page = root / "index.md"
            page.write_text(
                "[ok](a%20b.md#example) [external](https://example.org) [missing](gone.md)"
            )
            self.assertEqual(check_docs.broken_links(page), ["gone.md"])

    def test_extensionless_programs_and_new_files_are_checked(self):
        paths = quality.groups()
        self.assertIn("dot_local/bin/executable_ravy-herdr-tab-10", paths["python"])
        self.assertIn("bin/cloudtop", paths["shell"])
        self.assertIn("scripts/quality.py", paths["python"])


if __name__ == "__main__":
    unittest.main()
