import base64
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("restore_android_firebase", Path(__file__).parents[1] / "restore_android_firebase.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def config():
    return {
        "project_info": {"project_id": "listen1-xuan"},
        "client": [{"client_info": {"android_client_info": {"package_name": "com.xiebian.listen1_xuan"},
                                    "mobilesdk_app_id": "test-client-app-id"},
                    "api_key": [{"current_key": "test-public-client-key"}]}],
    }


class RestoreFirebaseTest(unittest.TestCase):
    def restore(self, data, destination):
        return module.restore(base64.b64encode(json.dumps(data).encode()).decode(), destination)

    def test_valid_configuration_is_restored_without_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "android" / "app" / "google-services.json"
            raw = json.dumps(config(), ensure_ascii=False, indent=2).encode()
            module.restore(base64.b64encode(raw).decode(), path)
            self.assertEqual(path.read_bytes(), raw)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_wrapped_base64_secret_is_supported(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "google-services.json"
            raw = json.dumps(config()).encode()
            encoded = base64.encodebytes(raw).decode()
            module.restore(encoded, path)
            self.assertEqual(path.read_bytes(), raw)

    def test_empty_or_malformed_secret_does_not_write_a_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "google-services.json"
            for value in (None, "", "not base64!", base64.b64encode(b"not JSON").decode()):
                with self.subTest(value=value):
                    with self.assertRaises(ValueError):
                        module.restore(value, path)
                    self.assertFalse(path.exists())

    def test_service_account_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "google-services.json"
            with self.assertRaisesRegex(ValueError, "service account"):
                self.restore({"type": "service_account", "private_key": "test-only-marker"}, path)
            self.assertFalse(path.exists())

    def test_wrong_project_package_or_missing_key_is_rejected(self):
        original = config()
        variants = []
        wrong_project = copy.deepcopy(original)
        wrong_project["project_info"]["project_id"] = "another-project"
        variants.append(wrong_project)
        wrong_package = copy.deepcopy(original)
        wrong_package["client"][0]["client_info"]["android_client_info"]["package_name"] = "another.package"
        variants.append(wrong_package)
        missing_key = copy.deepcopy(original)
        missing_key["client"][0]["api_key"] = []
        variants.append(missing_key)
        malformed_client = copy.deepcopy(original)
        malformed_client["client"][0]["client_info"] = None
        variants.append(malformed_client)
        for data in variants:
            with self.subTest(data=data), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "google-services.json"
                with self.assertRaises(ValueError):
                    self.restore(data, path)
                self.assertFalse(path.exists())


if __name__ == "__main__":
    unittest.main()
