import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("release_notes", Path(__file__).parents[1] / "release_notes.py")
notes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notes)


def asset(name, size=1048576):
    return {"name": name, "size": size, "state": "uploaded", "browser_download_url": f"https://example.com/{name}", "updated_at": "2026-10-11T00:00:00Z"}


class ReleaseNotesTests(unittest.TestCase):
    def test_mixed_hashes_and_actual_urls(self):
        assets = [
            asset("app-arm64-v8a-release-without.embedded.Cronet-a123456.apk", 2621440),
            asset("windows-build-artifact-b234567.zip"),
            asset("listen1_xuan-2.7.1+51-macos-c345678.zip"),
            asset("listen1_xuan-ios-d456789.app.zip"),
        ]
        guide = notes.generate_guide(assets)
        for package in assets:
            self.assertIn(package["browser_download_url"], guide)
            self.assertIn(f"`{notes.classify(package['name'])['hash']}`", guide)
        self.assertIn("**[推荐下载](https://example.com/app-arm64-v8a-release-without.embedded.Cronet-a123456.apk) · 2.50 MiB · `a123456`**", guide)

    def test_android_matrix_and_recommendation(self):
        assets = []
        for arch in notes.ARCHES:
            prefix = "app-release" if arch == "universal" else f"app-{arch}-release"
            for embedded in (True, False):
                for ffmpeg in (False, True):
                    name = prefix + ("" if embedded else "-without.embedded.Cronet") + ("-ffmpeg" if ffmpeg else "") + "-a123456.apk"
                    package = asset(name)
                    assets.append(package)
                    info = notes.classify(name)
                    self.assertEqual((info["arch"], info["embedded"], info["ffmpeg"]), (arch, embedded, ffmpeg))
        guide = notes.generate_guide(assets)
        self.assertEqual(guide.count("[推荐下载]"), 1)
        self.assertEqual(guide.count("https://example.com/"), 16)
        self.assertIn("通用包 · 不推荐", guide)
        self.assertIn("GitHub 相关功能可能出现问题", guide)
        self.assertIn("**[推荐下载](https://example.com/app-arm64-v8a-release-without.embedded.Cronet-a123456.apk)", guide)
        self.assertNotIn("**[推荐下载](https://example.com/app-arm64-v8a-release-a123456.apk)", guide)
        self.assertNotIn("\u2b50", guide)
        self.assertNotIn("\u26a0", guide)
        self.assertFalse(notes.classify("app-release-without embedded Cronet-a123456.apk")["embedded"])

    def test_idempotence_and_preservation_of_manual_notes(self):
        manual = "## 更新内容\n修复问题。\n"
        guide = notes.generate_guide([])
        body = notes.merge_body(manual, guide)
        self.assertEqual(notes.merge_body(body, guide), body)
        new_guide = notes.generate_guide([asset("app-release-a123456.apk")])
        updated = notes.merge_body(body, new_guide)
        self.assertTrue(updated.endswith(manual))
        self.assertEqual(updated.count(notes.START), 1)
        self.assertNotIn("https://example.com", body)
        self.assertIn("https://example.com", updated)

    def test_malformed_markers_fail_safely(self):
        for body in (notes.START, notes.END, notes.END + notes.START, notes.START * 2 + notes.END):
            with self.assertRaises(ValueError):
                notes.merge_body(body, "new guide")

    def test_only_uploaded_packages_and_sizes(self):
        incomplete = asset("app-arm64-v8a-release-a123456.apk")
        incomplete["state"] = "starter"
        guide = notes.generate_guide([incomplete, asset("checksums.txt")])
        self.assertNotIn("https://example.com", guide)
        self.assertIn("暂未发布", guide)
        self.assertEqual(notes.size_label(1024 * 1024), "1.00 MiB")

    def test_macos_split_arches(self):
        assets = [
            asset("listen1_xuan-2.7.3+53-macos-apple-silicon-a123456.zip"),
            asset("listen1_xuan-2.7.3+53-macos-intel-a123456.zip"),
            asset("listen1_xuan-2.7.3+53-macos-apple-silicon-ffmpeg-a123456.zip"),
            asset("listen1_xuan-2.7.3+53-macos-intel-ffmpeg-a123456.zip"),
        ]
        self.assertEqual(notes.classify(assets[0]["name"])["arch"], "apple-silicon")
        self.assertEqual(notes.classify(assets[1]["name"])["arch"], "intel")
        self.assertFalse(notes.classify(assets[1]["name"])["ffmpeg"])
        self.assertTrue(notes.classify(assets[2]["name"])["ffmpeg"])
        guide = notes.generate_guide(assets)
        self.assertIn("Apple 芯片", guide)
        self.assertIn("Intel 芯片", guide)
        self.assertNotIn("通用包（旧版）", guide)
        self.assertEqual(guide.count("https://example.com/"), 4)
        self.assertEqual(guide.count("[推荐下载]"), 1)
        self.assertIn("**[推荐下载](https://example.com/listen1_xuan-2.7.3+53-macos-apple-silicon-a123456.zip)", guide)
        self.assertIn("macOS 选芯片", guide)

    def test_macos_names_do_not_collide_with_android_arch_filters(self):
        names = [
            "listen1_xuan-2.7.3+53-macos-apple-silicon-a123456.zip",
            "listen1_xuan-2.7.3+53-macos-intel-a123456.zip",
            "macos-app-artifact-apple-silicon",
            "macos-app-artifact-ffmpeg-intel",
        ]
        for name in names:
            for token in ("arm64", "armeabi", "x86_64"):
                self.assertNotIn(token, name.lower())

    def test_macos_legacy_universal_still_listed(self):
        assets = [
            asset("listen1_xuan-2.7.1+51-macos-c345678.zip"),
            asset("listen1_xuan-2.7.3+53-macos-apple-silicon-a123456.zip"),
        ]
        self.assertEqual(notes.classify(assets[0]["name"])["arch"], "universal")
        guide = notes.generate_guide(assets)
        self.assertIn("通用包（旧版）", guide)
        self.assertIn("Apple 芯片", guide)
        self.assertIn("Intel 芯片包暂未发布", guide)
        self.assertIn("https://example.com/listen1_xuan-2.7.1+51-macos-c345678.zip", guide)

    def test_macos_missing_assets_shows_placeholder(self):
        guide = notes.generate_guide([asset("windows-build-artifact-b234567.zip")])
        self.assertIn("### macOS", guide)
        self.assertIn("暂未发布", guide)

    def test_version_uses_triggering_commit(self):
        import base64
        sha = "a" * 40
        response = {"content": base64.b64encode(b"name: listen1_xuan\nversion: 2.7.1+51\n").decode()}
        with patch.object(notes, "gh_api", return_value=response) as api:
            self.assertEqual(notes.source_version("owner/repo", sha), "2.7.1+51")
            api.assert_called_once_with(f"repos/owner/repo/contents/pubspec.yaml?ref={sha}")


if __name__ == "__main__":
    unittest.main()
