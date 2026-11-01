import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


configure = module('configure_build').configure
verify = module('verify_firebase_dependencies').verify


class BuildDependencyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'lib/services').mkdir(parents=True)
        (self.root / 'lib/services/ffmpeg_config.dart').write_text('const bool isFfmpegEnabled = true;\n')
        (self.root / 'pubspec.yaml').write_text('name: example\n')

    def test_both_modes_survive_switches_in_either_order(self):
        for firebase in ('stub', 'real'):
            configure(self.root, 'firebase', firebase)
            for ffmpeg in ('without', 'with', 'without', 'with'):
                configure(self.root, 'ffmpeg', ffmpeg)
                text = (self.root / 'pubspec.yaml').read_text()
                self.assertEqual('path: packages/firebase_core_stub' in text, firebase == 'stub')
                self.assertEqual('path: packages/ffmpeg_kit_flutter_new_audio' in text, ffmpeg == 'without')
                self.assertLessEqual(text.count('dependency_overrides:'), 1)
                self.assertEqual(configure(self.root, 'ffmpeg', 'check'), ffmpeg)
                configure(self.root, 'firebase', 'real' if firebase == 'stub' else 'stub')
                self.assertEqual(configure(self.root, 'ffmpeg', 'check'), ffmpeg)
                configure(self.root, 'firebase', firebase)

    def test_migrates_old_block_and_is_idempotent(self):
        p = self.root / 'pubspec.yaml'
        p.write_text('name: example\n# BEGIN: no-ffmpeg override\ndependency_overrides:\n  ffmpeg_kit_flutter_new_audio:\n    path: packages/ffmpeg_kit_flutter_new_audio\n# END: no-ffmpeg override\n')
        (self.root / 'lib/services/ffmpeg_config.dart').write_text('const bool isFfmpegEnabled = false;\n')
        configure(self.root, 'firebase', 'stub')
        expected = p.read_text()
        configure(self.root, 'firebase', 'stub')
        self.assertEqual(p.read_text(), expected)
        self.assertIn('path: packages/ffmpeg_kit_flutter_new_audio', expected)

    def test_unknown_overrides_are_never_silently_removed(self):
        p = self.root / 'pubspec.yaml'
        text = 'name: example\ndependency_overrides:\n  other: 1.0.0\n'
        p.write_text(text)
        with self.assertRaises(ValueError):
            configure(self.root, 'firebase', 'stub')
        self.assertEqual(p.read_text(), text)

    def graph(self, real=False, extra=False, plugin=False):
        (self.root / '.dart_tool').mkdir(exist_ok=True)
        packages = [dict(name=n, rootUri=(self.root / ('cache' if real else 'packages') / (n + '_stub')).as_uri()) for n in ('firebase_core', 'firebase_messaging')]
        if extra:
            packages.append(dict(name='firebase_core_web', rootUri='file:///cache/firebase_core_web'))
        (self.root / '.dart_tool/package_config.json').write_text(json.dumps(dict(packages=packages)))
        (self.root / '.flutter-plugins-dependencies').write_text(json.dumps(dict(plugins=dict(android=[dict(name=n) for n in ('firebase_core', 'firebase_messaging')] if plugin else []))))

    def test_stub_gate_rejects_real_package_or_transitive_plugin(self):
        self.graph()
        verify(self.root, 'stub')
        for options in (dict(real=True), dict(extra=True), dict(plugin=True)):
            self.graph(**options)
            with self.assertRaises(ValueError):
                verify(self.root, 'stub')

    def test_android_gate_rejects_stubs_and_requires_native_plugins(self):
        self.graph()
        with self.assertRaises(ValueError):
            verify(self.root, 'real')
        self.graph(real=True)
        with self.assertRaises(ValueError):
            verify(self.root, 'real')
        self.graph(real=True, plugin=True)
        verify(self.root, 'real')

    def test_apple_gate_rejects_firebase_pods(self):
        self.graph()
        (self.root / 'ios').mkdir()
        lock = self.root / 'ios/Podfile.lock'
        lock.write_text('PODS:\n  - Flutter (1.0.0)\n')
        verify(self.root, 'stub', 'ios')
        lock.write_text('PODS:\n  - Firebase/CoreOnly (11.15.0)\n')
        with self.assertRaises(ValueError):
            verify(self.root, 'stub', 'ios')


if __name__ == '__main__':
    unittest.main()
