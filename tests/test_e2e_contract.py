"""E2E selection and startup isolation, without live account configuration."""

import io
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import e2e_herdr


def test_ids(suite):
    result = set()
    for item in suite:
        if isinstance(item, unittest.TestSuite):
            result.update(test_ids(item))
        else:
            result.add(item.id().rsplit(".", 1)[-1])
    return result


class E2EContractTests(unittest.TestCase):
    def suite(self, series):
        self.assertTrue(
            callable(getattr(e2e_herdr, "build_suite", None)),
            "E2E needs explicit required/diagnostic suite selection",
        )
        return e2e_herdr.build_suite(series)

    def test_developer_requires_normal_and_explicit_recovery(self):
        self.assertEqual(
            test_ids(self.suite("developer")),
            {
                "test_native_remote_keys_forwarding_and_reattach",
                "test_remote_custom_home_tab_and_tab_ten",
                "test_replaced_agent_with_fresh_transport",
            },
        )

    def test_rotation_diagnostic_is_preserved_and_not_skipped(self):
        suite = self.suite("agent-rotation")
        self.assertEqual(test_ids(suite), {"test_replaced_agent_with_reused_transport"})
        for group in suite:
            for case in group:
                method = getattr(case, case._testMethodName)
                self.assertFalse(getattr(method, "__unittest_skip__", False))
                self.assertFalse(
                    getattr(method, "__unittest_expecting_failure__", False)
                )
                self.assertFalse(getattr(type(case), "__unittest_skip__", False))

    def test_server_contract_includes_automatic_titles(self):
        self.assertEqual(self.suite("server").countTestCases(), 5)
        self.assertIn("test_automatic_tab_titles", test_ids(self.suite("server")))
        self.assertNotIn(
            "test_replaced_agent_with_reused_transport", test_ids(self.suite("server"))
        )

    def test_unknown_series_cannot_silently_select_developer(self):
        with self.assertRaises(ValueError):
            self.suite("typo")


class IsolationTests(unittest.TestCase):
    def test_runtime_ignores_long_or_account_local_tmpdir_and_cleans_up(self):
        with patch.dict(os.environ, {"TMPDIR": "/nonexistent/long/account-local/temp"}):
            with e2e_herdr.temporary_runtime("he-") as name:
                path = Path(name)
                self.assertEqual(path.parent.resolve(), Path("/tmp").resolve())
                self.assertEqual(path.stat().st_mode & 0o777, 0o700)
        self.assertFalse(path.exists())

    def test_authorized_keys_use_account_home_even_with_fake_home(self):
        with tempfile.TemporaryDirectory() as root:
            account_home = Path(root) / "account with spaces"
            account_home.mkdir(mode=0o700)
            with patch.dict(os.environ, {"HOME": "/nonexistent/fake-home"}):
                with e2e_herdr.authorized_keys_directory(account_home) as name:
                    path = Path(name)
                    self.assertEqual(path.parent, account_home.resolve())
                    self.assertEqual(path.stat().st_mode & 0o777, 0o700)
            self.assertFalse(path.exists())

    def test_unsafe_account_home_fails_before_sshd(self):
        with tempfile.TemporaryDirectory() as root:
            account_home = Path(root) / "unsafe"
            account_home.mkdir()
            for mode in (0o770, 0o777):
                account_home.chmod(mode)
                with self.assertRaisesRegex(ValueError, "account home"):
                    e2e_herdr.authorized_keys_directory(account_home)
                self.assertEqual(list(account_home.iterdir()), [])

    def test_real_shell_startup_uses_isolated_home(self):
        for name in ("fish", "zsh", "bash"):
            with self.subTest(shell=name), tempfile.TemporaryDirectory() as root:
                shell = shutil.which(name)
                self.assertIsNotNone(shell, f"required shell missing: {name}")
                assert shell is not None
                home = Path(root) / "isolated"
                env, marker = e2e_herdr.prepare_ssh_home(home, shell)
                # Poison inherited lookup paths; the prepared environment must
                # replace them before any shell startup file is evaluated.
                inherited = {key: "/nonexistent/unisolated" for key in env}
                command = [shell, "-ic" if name == "bash" else "-c", "true"]
                result = subprocess.run(
                    command,
                    env=inherited | env,
                    cwd=root,
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    marker.read_text().splitlines(),
                    [str(home), str(home / ".config"), str(home)],
                )

    def test_unknown_login_shell_is_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaisesRegex(ValueError, "unsupported SSH login shell"):
                e2e_herdr.prepare_ssh_home(Path(root) / "home", "/bin/unknown-shell")

    def test_failure_artifacts_include_diagnostics_without_copying_keys(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fixture = object.__new__(e2e_herdr.Fixture)
            fixture.root = root / "fixture"
            fixture.root.mkdir()
            fixture.clients = [SimpleNamespace(output=bytearray(b"terminal failure"))]
            (fixture.root / "server.log").write_text("server diagnostic")
            (fixture.root / "identity").write_text("synthetic private key sentinel")
            (root / "sshd.log").write_text("SSH diagnostic")
            case = SimpleNamespace(id=lambda: "failing-test", fx=fixture, root=root)
            result = e2e_herdr.ArtifactResult(io.StringIO(), True, 2)
            with (
                patch.object(e2e_herdr, "ROOT", root),
                patch.object(e2e_herdr, "SERIES", "server"),
            ):
                result.save_diagnostics(case)
            output = root / "artifacts/e2e/server/failing-test"
            self.assertEqual(
                {p.name for p in output.iterdir()},
                {"fx-pty-0.log", "fx-server.log", "sshd.log"},
            )
            self.assertEqual(
                (output / "fx-pty-0.log").read_bytes(), b"terminal failure"
            )


if __name__ == "__main__":
    unittest.main()
