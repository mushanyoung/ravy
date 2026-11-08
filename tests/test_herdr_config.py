"""Configuration contract; real parser and keyboard checks live in E2E."""

import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class HerdrConfigTests(unittest.TestCase):
    def config(self):
        path = ROOT / "dot_config/herdr/config.toml"
        self.assertTrue(path.is_file(), "Herdr config must be managed by chezmoi")
        return tomllib.loads(path.read_text())

    def test_native_ownership_and_privacy(self):
        cfg = self.config()
        self.assertTrue(cfg["remote"]["manage_ssh_config"])
        self.assertFalse(cfg["update"]["version_check"])
        self.assertFalse(cfg["update"]["manifest_check"])
        self.assertFalse(cfg["experimental"]["pane_history"])
        self.assertFalse(cfg["session"]["resume_agents_on_restore"])
        self.assertFalse(cfg["experimental"]["allow_nested"])
        self.assertEqual(cfg["terminal"]["new_cwd"], "follow")
        self.assertEqual(cfg["terminal"]["default_shell"], "fish")
        self.assertEqual(cfg["keys"]["new_worktree"], "")

    def test_muscle_memory(self):
        keys = self.config()["keys"]
        for key, value in {
            "prefix": "ctrl+space",
            "detach": "prefix+d",
            "new_tab": "prefix+n",
            "zoom": "prefix+z",
            "rename_tab": "prefix+comma",
            "previous_tab": "prefix+p",
            "cycle_pane_next": "prefix+o",
            "copy_mode": "prefix+[",
        }.items():
            self.assertEqual(keys[key], value)
        self.assertIn("alt+1..9", keys["switch_tab"])
        for direction, letter in zip(("left", "down", "up", "right"), "hjkl"):
            self.assertIn(f"prefix+{letter}", keys[f"focus_pane_{direction}"])
        commands = {entry["key"]: entry for entry in keys["command"]}
        self.assertIn("prefix+c", commands)
        self.assertIn("--cwd", commands["prefix+c"]["command"])
        self.assertIn("alt+0", commands)
        self.assertIn("ravy-herdr-tab-10", commands["alt+0"]["command"])

    def test_native_agent_socket_and_toolchain(self):
        for name in (
            ".chezmoitemplates/ravy_fish_common.tmpl",
            ".chezmoitemplates/ravy_sh_common.tmpl",
        ):
            data = (ROOT / name).read_text()
            self.assertNotIn("ssh_auth_sock", data)
            self.assertNotIn("CLOUDTOP_SSH_AUTH_SOCK", data)
        tools = tomllib.loads((ROOT / "dot_config/mise/config.toml").read_text())[
            "tools"
        ]
        self.assertEqual(tools["herdr"], "0.9.5")


if __name__ == "__main__":
    unittest.main()
