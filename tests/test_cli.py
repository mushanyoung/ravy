"""Argument boundaries and error paths in maintained command-line helpers."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class CliTests(unittest.TestCase):
    def test_git_diff_exec_preserves_spaces_and_glob_characters(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            names = ["a file.txt", "literal[1].txt", "literal1.txt"]
            for name in names:
                (root / name).write_text("original\n")
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            for name in names[:2]:
                (root / name).write_text("changed\n")
            capture = root / "capture"
            capture.write_text(
                f"#!{sys.executable}\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n"
            )
            capture.chmod(0o700)
            result = subprocess.run(
                [str(ROOT / "bin/git-diff-exec")],
                cwd=root,
                env=os.environ
                | {"DIFF_EXEC_CMD": str(capture), "DIFF_EXEC_VIM_LCS_DIR": ""},
                text=True,
                capture_output=True,
                check=True,
            )
            self.assertEqual(json.loads(result.stdout), names[:2])

    def test_docker_ips_empty_inventory_does_not_inspect(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            docker = root / "docker"
            docker.write_text('#!/bin/sh\n[ "$1" = ps ] || exit 70\n')
            docker.chmod(0o700)
            result = subprocess.run(
                [str(ROOT / "bin/dcips")],
                capture_output=True,
                text=True,
                env=os.environ | {"PATH": str(root) + os.pathsep + os.environ["PATH"]},
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "")

    def test_timestamp_errors_are_not_hidden_by_variable_declarations(self):
        result = subprocess.run(
            [str(ROOT / "bin/times"), "test"], capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = subprocess.run(
            [str(ROOT / "bin/times"), "invalid"], capture_output=True, text=True
        )
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
