#!/usr/bin/env python3
"""Restore the Android Firebase client config without printing its contents."""
import base64
import binascii
import json
import os
from pathlib import Path
import sys


def restore(encoded, destination, expected_project="listen1-xuan"):
    if not encoded:
        raise ValueError("Missing Actions secret GOOGLE_SERVICES_JSON_B64")
    try:
        raw = base64.b64decode("".join(encoded.split()), validate=True)
        config = json.loads(raw)
    except (binascii.Error, ValueError, UnicodeDecodeError):
        raise ValueError("GOOGLE_SERVICES_JSON_B64 must contain a base64-encoded google-services.json") from None
    if not isinstance(config, dict) or config.get("type") == "service_account" or "private_key" in config:
        raise ValueError("Expected Android client configuration, not a Firebase service account")
    info = config.get("project_info")
    if not isinstance(info, dict) or info.get("project_id") != expected_project:
        raise ValueError("Firebase client configuration does not match the expected project")
    clients = config.get("client")
    if not isinstance(clients, list):
        raise ValueError("Firebase client configuration has no Android clients")
    valid_client = False
    for client in clients:
        if not isinstance(client, dict):
            continue
        client_info = client.get("client_info")
        if not isinstance(client_info, dict):
            continue
        android = client_info.get("android_client_info")
        keys = client.get("api_key")
        if not isinstance(android, dict) or not isinstance(keys, list):
            continue
        if (android.get("package_name") == "com.xiebian.listen1_xuan" and
                isinstance(client_info.get("mobilesdk_app_id"), str) and client_info["mobilesdk_app_id"] and
                any(isinstance(key, dict) and isinstance(key.get("current_key"), str) and key["current_key"] for key in keys)):
            valid_client = True
            break
    if not valid_client:
        raise ValueError("Firebase client configuration is missing the application ID or API key for this Android package")
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "wb") as output:
        output.write(raw)
    destination.chmod(0o600)


def main():
    try:
        restore(os.environ.get("GOOGLE_SERVICES_JSON_B64"), "android/app/google-services.json",
                os.environ.get("FIREBASE_PROJECT_ID", "listen1-xuan"))
    except ValueError as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1
    print("Firebase Android client configuration restored and validated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
