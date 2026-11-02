"""Cloudtop is an argv-only adapter; Herdr owns transport and session state."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CloudtopTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ravy-cl-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        # The only stub is the external Herdr executable, not adapter behavior.
        stub = self.bin / "herdr"
        stub.write_text('#!/usr/bin/env python3\nimport json, os, sys\n'
                        'print(json.dumps({"argv": sys.argv[1:], '
                        '"sock": os.environ.get("SSH_AUTH_SOCK")}))\n'
                        'sys.exit(int(os.environ.get("STUB_EXIT", "0")))\n')
        stub.chmod(0o700)
        self.env = {"HOME": str(self.home), "PATH": f"{self.bin}:/usr/bin:/bin",
                    "SSH_AUTH_SOCK": "/synthetic/herdr-managed-agent.sock"}

    def run_adapter(self, *args, alias="cloudtop", **env):
        return subprocess.run([str(ROOT / "bin" / alias), *args],
                              env=self.env | env, text=True, capture_output=True,
                              timeout=5)

    def assert_argv(self, expected, *args, **kwargs):
        result = self.run_adapter(*args, **kwargs)
        self.assertEqual(result.returncode, 0, result.stderr)
        observed = json.loads(result.stdout)
        self.assertEqual(observed["argv"], expected)
        self.assertEqual(observed["sock"], self.env["SSH_AUTH_SOCK"])
        self.assertFalse((self.home / ".ssh").exists())
        self.assertFalse((self.home / ".cache").exists())

    def test_local_native_default_session(self):
        self.assert_argv([])

    def test_remote_developer_hosts(self):
        for host in ("mac-dev", "linux-dev", "ssh://dev@localhost:2222"):
            with self.subTest(host=host):
                self.assert_argv(["--remote", host], host)

    def test_server_named_session(self):
        self.assert_argv(["--remote", "linux-server", "--session", "ops"],
                         "linux-server", "--session", "ops")

    def test_native_flags_and_cl_alias(self):
        self.assert_argv(["--session", "work"], "--session", "work", alias="cl")
        self.assert_argv(["--remote", "dev"], "--remote", "dev")
        self.assert_argv(["--help"], "--help")

    def test_arguments_never_evaluated(self):
        self.assert_argv(["--remote", "$(touch OWNED); x", "--session", "a b"],
                         "$(touch OWNED); x", "--session", "a b")
        self.assertFalse((ROOT / "OWNED").exists())

    def test_legacy_environment_cannot_replace_native_transport(self):
        self.assert_argv(["--remote", "dev"], "dev", CLOUDTOP_EXEC_CMD="exit 88",
                         SSH_EXEC_CMD="exit 88", SSH_COMMAND="/nonexistent",
                         CLOUDTOP_SSH_AUTH_SOCK="/wrong/socket")

    def test_native_failure_is_not_retried_or_hidden(self):
        result = self.run_adapter("dev", STUB_EXIT="78")
        self.assertEqual(result.returncode, 78)
        self.assertEqual(len(result.stdout.splitlines()), 1)

    def test_removed_transports_fail_before_herdr(self):
        for flag in ("--mosh", "--tmux", "--zellij", "--ssh"):
            with self.subTest(flag=flag):
                result = self.run_adapter(flag, "dev")
                self.assertEqual(result.returncode, 2)
                self.assertIn("Herdr", result.stderr)
                self.assertEqual(result.stdout, "")

    def test_missing_binary_has_actionable_error(self):
        (self.bin / "herdr").unlink()
        result = self.run_adapter()
        self.assertEqual(result.returncode, 127)
        self.assertIn("mise install herdr", result.stderr)


if __name__ == "__main__":
    unittest.main()
