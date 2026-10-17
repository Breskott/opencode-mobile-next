"""Catch installer/engine pin drift without Flutter or a network connection."""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[3]


class PhoneEngineOc1PinTest(unittest.TestCase):
    def test_every_installer_uses_an_engine_supported_oc1_release(self):
        driver = (ROOT / "engine/phone/src/opencode1.rs").read_text()
        table = re.search(r"const SUPPORTED_RELEASES:.*?=\s*&\[(.*?)\];", driver, re.S)
        self.assertIsNotNone(table, "The engine must declare its supported OC1 releases")
        supported = set(re.findall(r'\(\s*"(1\.\d+\.\d+)"', table[1]))
        self.assertTrue(supported)

        runtime = (ROOT / "lib/termux/bridge_models.dart").read_text()
        pin = re.search(r"openCode1\('opencode1', '([^']+)'\)", runtime)
        self.assertIsNotNone(pin)
        self.assertIn(pin[1], supported, "Installed OC1 must pass engine health verification")

        for path in ("lib/builtin/setup/components.dart", "lib/domain/agent_catalog.dart"):
            source = (ROOT / path).read_text()
            versions = re.findall(r"anomalyco/opencode/releases/download/v(1\.\d+\.\d+)/", source)
            self.assertEqual(len(versions), 2, path)
            self.assertEqual(set(versions), {pin[1]}, path)

        catalog = (ROOT / "lib/domain/agent_catalog.dart").read_text()
        recipe = re.search(r"AgentRoute\.opencode1,.*?version: '([^']+)'", catalog, re.S)
        self.assertIsNotNone(recipe)
        self.assertEqual(recipe[1], pin[1])

        manager = (ROOT / "lib/termux/scripts/manager_script.dart").read_text()
        defaults = re.findall(r"opencode1\) requested_version=(\S+) ;;", manager)
        self.assertEqual(len(defaults), 2, "Check setup and runtime-switch defaults")
        self.assertEqual(set(defaults), {pin[1]})


if __name__ == "__main__":
    unittest.main()
