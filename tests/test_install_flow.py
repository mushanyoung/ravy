"""Installer flows with real Git/chezmoi and isolated package-manager substitutes."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class InstallFlowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ravy-install-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = {
            "HOME": str(self.home),
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "RAVY_SKIP_CHSH": "1",
            "RAVY_CHEZMOI_FORCE": "0",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_TERMINAL_PROMPT": "0",
        }
        self.public = self.root / "public"
        self.public.mkdir()
        tracked = subprocess.check_output(
            ["git", "ls-files", "-z", "--", "chezmoi", ".chezmoiroot", ".gitignore"],
            cwd=ROOT,
        )
        # Read only public tracked inputs, including uncommitted template edits.
        for entry in tracked.split(b"\0"):
            if not entry:
                continue
            relative = Path(os.fsdecode(entry))
            target = self.public / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        self.commit(self.public)
        self.env["RAVY_REPO"] = str(self.public)
        self.stub(
            "mise",
            """case "$1" in
  exec)
    [ "$PWD" = "$HOME" ] || exit 83
    shift
    while [ "$1" != -- ]; do shift; done
    shift
    exec "$@"
    ;;
  install)
    printf '%s\\n' "$* token=${MISE_GITHUB_TOKEN:-}" >>"$HOME/mise.log"
    if [ -s "$HOME/.config/mise/conf.d/99-custom.toml" ]; then
      cp "$HOME/.config/mise/conf.d/99-custom.toml" "$HOME/installed-private.toml"
    fi
    [ "${RAVY_TEST_FAIL_MISE:-0}" != 1 ]
    ;;
  *) exit 99 ;;
esac
""",
        )
        self.stub(
            "brew",
            """case "$1" in
  --prefix|--repository) printf '%s\\n' "$HOME/brew" ;;
  --cellar) printf '%s\\n' "$HOME/brew/Cellar" ;;
  bundle)
    test -f "$HOMEBREW_BUNDLE_FILE"
    printf '%s\\n' "$HOMEBREW_BUNDLE_FILE" >>"$HOME/brew.log"
    ;;
  *) exit 99 ;;
esac
""",
        )
        for command in ("curl", "sudo", "chsh"):
            self.stub(command, f'echo "unexpected {command}" >&2; exit 99\n')
        self.stub("age", '[ "$1" = --version ]\n')

    def stub(self, name, body):
        target = self.bin / name
        target.write_text("#!/bin/sh\nset -eu\n" + body)
        target.chmod(0o755)

    def run_command(self, *argv, cwd=None, env=None, input=None):
        result = subprocess.run(
            argv,
            cwd=cwd or self.home,
            env=env or self.env,
            input=input,
            text=True,
            capture_output=True,
            timeout=60,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def commit(self, repo):
        self.run_command("git", "init", "-q", str(repo))
        self.run_command("git", "-C", str(repo), "add", ".")
        self.run_command(
            "git",
            "-C",
            str(repo),
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "-c",
            "commit.gpgSign=false",
            "-c",
            "core.hooksPath=/dev/null",
            "commit",
            "-qm",
            "fixture",
        )

    def install(self, **overrides):
        # stdin matches curl | bash and cannot discover the developer's custom/.
        return self.run_command(
            "/bin/bash",
            "-s",
            input=(ROOT / "install.sh").read_text(),
            env=self.env | overrides,
        )

    def assert_public_source(self, checkout):
        working_tree = self.run_command(
            "chezmoi", "execute-template", "{{ .chezmoi.workingTree }}"
        ).strip()
        self.assertEqual(Path(working_tree).resolve(), checkout.resolve())
        source = self.run_command(
            "chezmoi", "source-path", str(self.home / ".gitconfig")
        )
        self.assertEqual(
            Path(source.strip()).resolve(),
            (checkout / "chezmoi/dot_gitconfig").resolve(),
        )
        for filename in (".bashrc", ".zshrc", ".config/fish/config.fish"):
            self.assertTrue((self.home / filename).is_file(), filename)
        self.assertIn(
            str(self.home / ".config/homebrew/Brewfile"),
            (self.home / "brew.log").read_text(),
        )
        self.assertTrue((self.home / "mise.log").exists())

    def prepare_private(self):
        key = self.home / ".config/chezmoi/key.txt"
        key.parent.mkdir(parents=True, exist_ok=True)
        self.run_command("chezmoi", "age-keygen", "-o", str(key))
        key.chmod(0o600)
        recipient = self.run_command("chezmoi", "age-keygen", "-y", str(key)).strip()
        private = self.root / "private"
        (private / "dot_config/ravy").mkdir(parents=True)
        (private / "mise").mkdir()
        (private / ".chezmoiignore").write_text("mise\ninstall.sh\n")
        (private / ".chezmoi.toml.tmpl").write_text(
            "sourceDir = {{ .chezmoi.workingTree | quote }}\n"
            'encryption = "age"\nuseBuiltinAge = true\n[age]\n'
            'identity = {{ joinPath .chezmoi.homeDir ".config/chezmoi/key.txt" | quote }}\n'
            f'recipient = "{recipient}"\n'
        )
        encrypt_config = self.root / "encrypt.toml"
        encrypt_config.write_text(
            f'encryption = "age"\nuseBuiltinAge = true\n[age]\nrecipient = "{recipient}"\n'
        )
        encrypted = self.run_command(
            "chezmoi",
            "-c",
            str(encrypt_config),
            "encrypt",
            input="MISE_GITHUB_TOKEN\t fixture-token\n",
        )
        (private / "dot_config/ravy/encrypted_private_secrets.tsv.age").write_text(
            encrypted
        )
        (private / "mise/config.toml").write_text(
            '[tools]\nnode = "26"\n"npm:pyright" = "latest"\n'
        )
        hook = private / "install.sh"
        hook.write_text('#!/bin/sh\nprintf hook >>"$HOME/private-hook.log"\n')
        hook.chmod(0o755)
        self.commit(private)
        return private

    def test_fresh_public_only_and_repeat_install(self):
        self.install()
        checkout = self.home / ".ravy"
        self.assert_public_source(checkout)
        self.assertFalse((self.home / ".local/share/chezmoi").exists())
        self.assertFalse((checkout / "custom").exists())
        self.assertFalse((self.home / ".config/chezmoi/ravy-private.toml").exists())
        self.assertFalse((self.home / ".config/mise/conf.d/99-custom.toml").exists())
        self.install()
        self.assert_public_source(checkout)

    def test_fresh_private_clone_decrypt_tools_and_repeat_install(self):
        private = self.prepare_private()
        self.install(RAVY_PRIVATE_REPO=str(private))
        checkout = self.home / ".ravy"
        self.assert_public_source(checkout)
        self.assertEqual((checkout / "custom").stat().st_mode & 0o777, 0o700)
        secrets = self.home / ".config/ravy/secrets.tsv"
        self.assertEqual(secrets.read_text(), "MISE_GITHUB_TOKEN\t fixture-token\n")
        self.assertEqual(secrets.stat().st_mode & 0o777, 0o600)
        self.assertIn('node = "26"', (self.home / "installed-private.toml").read_text())
        self.assertIn("tools", (checkout / "custom/mise/config.toml").read_text())
        self.assertIn("token=fixture-token", (self.home / "mise.log").read_text())
        self.assertIn(
            f"install -C {self.home} node", (self.home / "mise.log").read_text()
        )
        self.assertEqual((self.home / "private-hook.log").read_text(), "hook")
        self.assertTrue(
            (self.home / ".config/chezmoi/ravy-private-state.boltdb").is_file()
        )
        # Force must cover private changes too, without an interactive prompt.
        secrets.write_text("local edit\n")
        self.install(RAVY_PRIVATE_REPO=str(private), RAVY_CHEZMOI_FORCE="1")
        self.assertEqual(secrets.read_text(), "MISE_GITHUB_TOKEN\t fixture-token\n")
        self.assertEqual((self.home / "private-hook.log").read_text(), "hookhook")
        self.assert_public_source(checkout)

    def test_existing_location_and_relocation(self):
        old = self.home / ".local/share/chezmoi"
        self.install(RAVY_HOME=str(old), RAVY_PRIVATE_REPO=str(self.prepare_private()))
        self.install()
        self.assert_public_source(old)
        self.assertFalse((self.home / ".ravy").exists())
        relocated = self.home / ".ravy"
        old.rename(relocated)
        self.install(RAVY_HOME=str(relocated))
        self.assert_public_source(relocated)
        self.assertIn(str(relocated), (self.home / ".bashrc").read_text())
        self.assertEqual((self.home / "private-hook.log").read_text(), "hookhookhook")
        self.assertTrue((relocated / "custom/.git").exists())
        self.assertIn('node = "26"', (self.home / "installed-private.toml").read_text())

    def test_explicit_missing_private_path_does_not_run_other_hook(self):
        self.install()
        other = self.home / ".ravy/custom"
        other.mkdir()
        hook = other / "install.sh"
        hook.write_text('#!/bin/sh\ntouch "$HOME/wrong-hook"\n')
        hook.chmod(0o755)
        self.install(RAVY_PRIVATE_HOME=str(self.home / "missing"))
        self.assertFalse((self.home / "wrong-hook").exists())

    def test_existing_git_worktree_and_legacy_private_directory(self):
        checkout = self.home / "alternate checkout"
        self.run_command(
            "git",
            "-C",
            str(self.public),
            "worktree",
            "add",
            "-b",
            "fixture",
            str(checkout),
        )
        private = self.prepare_private()
        legacy = self.home / ".ravy-private"
        self.run_command("git", "clone", str(private), str(legacy))
        self.install(RAVY_HOME=str(checkout))
        self.install()
        self.assert_public_source(checkout)
        self.assertFalse((self.home / ".ravy").exists())
        self.assertFalse((checkout / "custom").exists())
        self.assertEqual(legacy.stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.home / "private-hook.log").read_text(), "hookhook")

    def test_invalid_existing_config_stops_before_clone(self):
        config = self.home / ".config/chezmoi/chezmoi.toml"
        config.parent.mkdir(parents=True)
        config.write_text("invalid = [\n")
        result = subprocess.run(
            ["/bin/bash", "-s"],
            input=(ROOT / "install.sh").read_text(),
            cwd=self.home,
            env=self.env,
            text=True,
            capture_output=True,
            timeout=60,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / ".ravy").exists())
        self.assertEqual(config.read_text(), "invalid = [\n")

    def test_tool_install_failure_does_not_change_shell(self):
        result = subprocess.run(
            ["/bin/bash", "-s"],
            input=(ROOT / "install.sh").read_text(),
            cwd=self.home,
            env=self.env | {"RAVY_SKIP_CHSH": "0", "RAVY_TEST_FAIL_MISE": "1"},
            text=True,
            capture_output=True,
            timeout=60,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.home / "mise.log").exists())
        self.assertNotIn("unexpected sudo", result.stderr)
        self.assertNotIn("unexpected chsh", result.stderr)
        self.assertNotIn("brew-managed fish is required", result.stdout)

    def test_neovim_finds_private_config_without_shell_environment(self):
        self.install(RAVY_PRIVATE_REPO=str(self.prepare_private()))
        private = self.home / ".ravy/custom/nvim"
        private.mkdir()
        (private / "init.lua").write_text('return {plugins = {"fixture"}}\n')
        # This runs without RAVY_HOME, as with a GUI-launched editor.
        lua = 'if require("ravy.private").load().plugins[1] ~= "fixture" then vim.cmd("cquit 1") end'
        self.run_command(
            "nvim",
            "--headless",
            "-c",
            f"lua {lua}",
            "+qa!",
            env=self.env | {"RAVY_NVIM_SKIP_PLUGINS": "1"},
        )


if __name__ == "__main__":
    unittest.main()
