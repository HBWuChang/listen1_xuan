#!/usr/bin/env python3
"""Fail CI if the resolved Firebase graph does not match the requested mode."""
import argparse
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlparse


def verify(root, mode, native=None):
    config_path = root / ".dart_tool/package_config.json"
    packages = json.loads(config_path.read_text(encoding="utf-8"))["packages"]
    firebase = {p["name"]: p for p in packages if p["name"].startswith(("firebase_", "_flutterfire_"))}
    required = {"firebase_core", "firebase_messaging"}
    if not required <= firebase.keys():
        raise ValueError("Firebase core/messaging missing from resolved graph")
    for name in required:
        uri = urlparse(firebase[name]["rootUri"])
        path = Path(unquote(uri.path))
        if not uri.scheme:
            path = config_path.parent / path
        is_stub = path.resolve() == (root / "packages" / (name + "_stub")).resolve()
        if is_stub != (mode == "stub"):
            raise ValueError(f"{name} resolved to the wrong implementation")
    if mode == "stub" and firebase.keys() != required:
        raise ValueError("Real Firebase transitive packages remain: " + str(sorted(firebase.keys() - required)))
    plugins = json.loads((root / ".flutter-plugins-dependencies").read_text(encoding="utf-8"))["plugins"]
    names = {p["name"] for platform in plugins.values() for p in platform}
    if mode == "stub" and any(n.startswith("firebase_") for n in names):
        raise ValueError("Native/web Firebase plugins remain registered")
    if mode == "real" and not required <= {p["name"] for p in plugins.get("android", [])}:
        raise ValueError("Real Android Firebase plugins are missing")
    if native:
        lock = (root / native / "Podfile.lock").read_text(encoding="utf-8")
        if re.search(r"firebase|Firebase", lock):
            raise ValueError("Firebase remains in CocoaPods lockfile")
    print(f"Firebase dependency graph verified: {mode}" + (f" ({native} pods)" if native else ""))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["real", "stub"])
    parser.add_argument("--native", choices=["ios", "macos"])
    args = parser.parse_args()
    verify(Path(__file__).resolve().parent.parent, args.mode, args.native)
