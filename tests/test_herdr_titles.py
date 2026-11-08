"""Title policy and reconciliation; actual foreground jobs are covered in E2E."""

import copy
import runpy
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

MODULE = runpy.run_path(
    str(
        Path(__file__).resolve().parents[1]
        / "chezmoi/dot_local/bin/executable_ravy-herdr-auto-title"
    )
)
Titles = MODULE["Titles"]


class FakeAPI:
    def __init__(self):
        self.tabs = [
            {"tab_id": "opaque-a", "workspace_id": "w", "number": 7, "label": "1"},
            {"tab_id": "opaque-b", "workspace_id": "w", "number": 9, "label": "2"},
            {"tab_id": "other", "workspace_id": "w2", "number": 1, "label": "1"},
        ]
        self.renames = []
        self.before_get = None

    def call(self, method, **params):
        if method == "session.snapshot":
            return {
                "snapshot": {
                    "tabs": copy.deepcopy(self.tabs),
                    "panes": [
                        {"pane_id": t["tab_id"], "cwd": "/home/user/repo/leaf"}
                        for t in self.tabs
                    ],
                    "layouts": [
                        {"tab_id": t["tab_id"], "focused_pane_id": t["tab_id"]}
                        for t in self.tabs
                    ],
                }
            }
        if method == "pane.process_info":
            return {"process_info": {"foreground_processes": []}}
        tab = next(t for t in self.tabs if t["tab_id"] == params["tab_id"])
        if method == "tab.get":
            if self.before_get:
                self.before_get(tab)
            return {"tab": copy.deepcopy(tab)}
        if method == "tab.rename":
            tab["label"] = params["label"]
            self.renames.append((tab["tab_id"], tab["label"]))
            return {}
        raise AssertionError(method)


class TitleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name) / "titles.json"
        self.api = FakeAPI()
        self.titles = Titles(self.api, "/home/user", self.state)

    def test_directory_basename_exact_home_root_and_controls(self):
        name = MODULE["directory_name"]
        self.assertEqual(name("/home/user", "/home/user"), "~")
        self.assertEqual(
            name("/home/user/nested/leaf with spaces", "/home/user"),
            "leaf with spaces/",
        )
        self.assertEqual(name("/home/user2", "/home/user"), "user2/")
        self.assertEqual(name("/", "/home/user"), "/")
        self.assertEqual(name("/tmp/a\nb\x1b", "/home/user"), "ab/")
        link = Path(self.temp.name) / "alias"
        link.symlink_to(self.temp.name, target_is_directory=True)
        self.assertEqual(name(str(link), self.temp.name), "~")

    def test_real_foreground_program_over_shell_wrapper_and_exec(self):
        name = MODULE["automatic_name"]
        shell = {"pid": 10, "name": "fish", "argv0": "-fish", "cwd": "/home/user"}
        command = {"pid": 12, "name": "sleep", "argv0": "/bin/sleep"}
        info = {
            "shell_pid": 10,
            "foreground_process_group_id": 10,
            "foreground_processes": [shell, command],
        }
        pane = {"cwd": "/stale/path"}
        with patch.dict(name.__globals__, {"process_is_live": lambda pid: True}):
            self.assertEqual(name(pane, info, "/home/user"), "▶ sleep")
            info["foreground_processes"] = [shell]
            self.assertEqual(name(pane, info, "/home/user"), "~")
            info["foreground_processes"] = [
                {**command, "pid": 10, "name": "nvim", "argv0": "nvim"}
            ]
            self.assertEqual(name(pane, info, "/home/user"), "▶ nvim")

    def test_linux_zombies_and_disappeared_processes_are_not_active(self):
        live = MODULE["process_is_live"]
        with patch.object(MODULE["sys"], "platform", "linux"):
            for state in ("R", "S", "D", "Z", "X"):
                with patch.object(
                    Path, "read_text", return_value=f"123 (odd ) name) {state} 1 123"
                ):
                    self.assertEqual(live(123), state not in {"Z", "X"})
            with patch.object(Path, "read_text", side_effect=FileNotFoundError):
                self.assertFalse(live(123))
            with patch.object(Path, "read_text", side_effect=PermissionError):
                self.assertTrue(live(123))

    def test_number_is_current_position_per_workspace_and_unchanged_titles_do_not_write(
        self,
    ):
        self.titles.update()
        self.assertEqual(
            [t["label"] for t in self.api.tabs], ["1 leaf/", "2 leaf/", "1 leaf/"]
        )
        before = self.state.stat().st_mtime_ns
        self.api.renames.clear()
        self.titles.update()
        self.assertEqual(self.api.renames, [])
        self.assertEqual(self.state.stat().st_mtime_ns, before)

    def test_manual_suffix_survives_reorder_restart_and_close(self):
        self.titles.update()
        self.api.tabs[0]["label"] = "1 review"
        self.titles.update()
        self.api.tabs[0], self.api.tabs[1] = self.api.tabs[1], self.api.tabs[0]
        Titles(self.api, "/home/user", self.state).update()
        self.assertEqual(
            [t["label"] for t in self.api.tabs], ["1 leaf/", "2 review", "1 leaf/"]
        )
        self.api.tabs.pop(0)
        Titles(self.api, "/home/user", self.state).update()
        self.assertEqual(self.api.tabs[0]["label"], "1 review")

    def test_previous_separator_migrates_without_losing_title_ownership(self):
        previous = {
            "opaque-a": {"last": "1: leaf", "number": 1, "manual": None},
            "opaque-b": {"last": "2: review", "number": 2, "manual": "review"},
        }
        for tab in self.api.tabs[:2]:
            tab_id = tab["tab_id"]
            assert isinstance(tab_id, str)
            tab["label"] = previous[tab_id]["last"]
        self.titles.records = previous
        self.titles.save()
        restored = Titles(self.api, "/home/user", self.state)
        restored.update()
        self.assertEqual(
            [t["label"] for t in self.api.tabs], ["1 leaf/", "2 review", "1 leaf/"]
        )
        self.assertIsNone(restored.records["opaque-a"]["manual"])
        self.assertEqual(restored.records["opaque-b"]["manual"], "review")
        # A rename dialog opened before the update still contains a colon.
        self.api.tabs[1]["label"] = "2: edited"
        restored.update()
        self.assertEqual(self.api.tabs[1]["label"], "2 edited")

    def test_existing_manual_name_is_preserved_and_empty_label_returns_to_auto(self):
        self.api.tabs[0]["label"] = "production logs"
        self.titles.update()
        self.assertEqual(self.api.tabs[0]["label"], "1 production logs")
        self.api.tabs[0]["label"] = ""
        self.titles.update()
        self.assertEqual(self.api.tabs[0]["label"], "1 leaf/")

    def test_manual_edit_during_process_read_is_not_overwritten(self):
        self.api.before_get = lambda tab: tab.update(label="edited while reading")
        self.titles.update()
        self.assertEqual(self.api.renames, [])
        self.api.before_get = None
        self.titles.update()
        self.assertEqual(self.api.tabs[0]["label"], "1 edited while reading")


if __name__ == "__main__":
    unittest.main()
