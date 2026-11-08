"""Real chezmoi source-root selection and private overlay precedence."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class SourceLayoutTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ravy-layout-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "project with spaces"
        self.home = self.root / "home"
        self.home.mkdir()
        self.source = self.repo / "chezmoi"
        self.source.mkdir(parents=True)
        (self.repo / ".git").mkdir()
        shutil.copyfile(ROOT / ".chezmoiroot", self.repo / ".chezmoiroot")
        shutil.copyfile(ROOT / "chezmoi/.chezmoiignore", self.source / ".chezmoiignore")
        self.config = self.root / "config.toml"
        self.config.touch()
        self.env = {"PATH": os.environ["PATH"], "HOME": str(self.home)}

    def chezmoi(self, *args, private=None):
        env = self.env | ({"RAVY_PRIVATE_HOME": str(private)} if private else {})
        return subprocess.check_output(
            [
                "chezmoi",
                "-S",
                str(self.repo),
                "-D",
                str(self.home),
                "-c",
                str(self.config),
                *args,
            ],
            env=env,
            cwd=self.home,
            text=True,
        )

    def test_only_source_state_is_managed_and_worktree_stays_at_project_root(self):
        for name in (
            "AGENTS.md",
            "docs/guide.md",
            "custom/private-marker",
            "scripts/check.py",
            "dist/output",
        ):
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("must not deploy\n")
        (self.source / "AGENTS.md").write_text("rules\n")
        (self.source / "dot_example").write_text("public\n")
        self.assertEqual(
            Path(self.chezmoi("source-path").strip()).resolve(), self.source.resolve()
        )
        self.assertEqual(
            Path(
                self.chezmoi("execute-template", "{{ .chezmoi.workingTree }}").strip()
            ).resolve(),
            self.repo.resolve(),
        )
        self.chezmoi("apply", "--force")
        self.assertEqual((self.home / ".example").read_text(), "public\n")
        self.assertEqual({p.name for p in self.home.iterdir()}, {".example"})

    def test_private_default_is_sibling_and_explicit_missing_override_stays_empty(self):
        relative = Path("dot_config/mise/conf.d/99-custom.toml.tmpl")
        target = self.source / relative
        target.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / "chezmoi" / relative, target)
        private = self.repo / "custom"
        (private / "mise").mkdir(parents=True)
        (private / "mise/config.toml").write_text('[tools]\nnode = "22"\n')
        deployed = str(self.home / ".config/mise/conf.d/99-custom.toml")
        self.assertIn('node = "22"', self.chezmoi("cat", deployed))
        override = self.root / "other-private"
        self.assertEqual(self.chezmoi("cat", deployed, private=override).strip(), "")
        (override / "mise").mkdir(parents=True)
        (override / "mise/config.toml").write_text('[tools]\nnode = "24"\n')
        rendered = self.chezmoi("cat", deployed, private=override)
        self.assertIn('node = "24"', rendered)
        self.assertNotIn('node = "22"', rendered)


if __name__ == "__main__":
    unittest.main()
