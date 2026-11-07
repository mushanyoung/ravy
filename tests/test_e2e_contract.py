"""Keep required acceptance separate from opt-in compatibility diagnostics."""
import unittest

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
        self.assertTrue(callable(getattr(e2e_herdr, "build_suite", None)),
                        "E2E needs explicit required/diagnostic suite selection")
        return e2e_herdr.build_suite(series)

    def test_developer_requires_normal_and_explicit_recovery(self):
        self.assertEqual(test_ids(self.suite("developer")), {
            "test_native_remote_keys_forwarding_and_reattach",
            "test_replaced_agent_with_fresh_transport",
        })

    def test_rotation_diagnostic_is_preserved_and_not_skipped(self):
        suite = self.suite("agent-rotation")
        self.assertEqual(test_ids(suite), {"test_replaced_agent_with_reused_transport"})
        for group in suite:
            for case in group:
                method = getattr(case, case._testMethodName)
                self.assertFalse(getattr(method, "__unittest_skip__", False))
                self.assertFalse(getattr(method, "__unittest_expecting_failure__", False))
                self.assertFalse(getattr(type(case), "__unittest_skip__", False))

    def test_server_contract_is_unchanged(self):
        self.assertEqual(self.suite("server").countTestCases(), 4)
        self.assertNotIn("test_replaced_agent_with_reused_transport",
                         test_ids(self.suite("server")))

    def test_unknown_series_cannot_silently_select_developer(self):
        with self.assertRaises(ValueError):
            self.suite("typo")


if __name__ == "__main__":
    unittest.main()
