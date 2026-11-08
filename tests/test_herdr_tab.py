"""The tab-10 adapter only translates an index into native opaque IDs."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HELPER = Path(__file__).resolve().parents[1] / "dot_local/bin/executable_ravy-herdr-tab-10"


class TabTenTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ht-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        binary = self.root / "herdr stub"
        binary.write_text("#!" + sys.executable + "\n" + '''import json,os,sys
from pathlib import Path
with Path(os.environ["CALLS"]).open("a") as out:
 out.write(json.dumps(sys.argv[1:])+"\\n")
if sys.argv[1:3] == ["tab","list"]:
 print(os.environ["TABS"])
else:
 sys.exit(int(os.environ.get("FOCUS_EXIT","0")))
''')
        binary.chmod(0o700)
        self.env = {"PATH": "/usr/bin:/bin", "HOME": str(self.root),
                    "HERDR_BIN_PATH": str(binary), "HERDR_ACTIVE_WORKSPACE_ID": "w-opaque",
                    "HERDR_SOCKET_PATH": str(self.root / "socket"), "CALLS": str(self.root / "calls")}

    def run_helper(self, tabs):
        self.env["TABS"] = json.dumps({"result": {"tabs": tabs}})
        result = subprocess.run([sys.executable, str(HELPER)], env=self.env,
                                capture_output=True, text=True, timeout=8)
        path = self.root / "calls"
        calls = [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []
        return result, calls

    def tabs(self):
        return [{"number": index + 20, "workspace_id": "w-opaque", "tab_id": f"opaque-{index}"}
                for index in range(10)]

    def test_selects_display_position_after_moves_or_closes(self):
        result, calls = self.run_helper([
            {"number": 10, "workspace_id": "other", "tab_id": "wrong"},
            *self.tabs()])
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, [["tab", "list", "--workspace", "w-opaque"],
                                 ["tab", "focus", "opaque-9"]])

    def test_missing_tenth_is_noop(self):
        result, calls = self.run_helper([])
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)

    def test_ambiguous_or_malformed_response_never_focuses(self):
        tab = {"number": 10, "workspace_id": "w-opaque", "tab_id": "t"}
        for data in ([tab, tab], None, [None], [{}], [{**tab, "tab_id": 10}]):
            with self.subTest(data=data):
                (self.root / "calls").unlink(missing_ok=True)
                result, calls = self.run_helper(data)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(len(calls), 1)

    def test_missing_context_does_not_query_default_session(self):
        for key in ("HERDR_BIN_PATH", "HERDR_ACTIVE_WORKSPACE_ID", "HERDR_SOCKET_PATH"):
            with self.subTest(key=key):
                value = self.env.pop(key)
                result, calls = self.run_helper([])
                self.env[key] = value
                self.assertEqual(result.returncode, 2)
                self.assertEqual(calls, [])

    def test_native_failure_propagates(self):
        self.env["FOCUS_EXIT"] = "7"
        result, _ = self.run_helper(self.tabs())
        self.assertEqual(result.returncode, 7)


if __name__ == "__main__":
    unittest.main()
