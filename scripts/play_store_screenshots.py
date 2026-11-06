#!/usr/bin/env python3
"""Upload the phone screenshots in store/google-play/graphics/screenshots/ to the Play store listing.

Uses the Google Play Developer API with the service account JSON in PLAY_SERVICE_ACCOUNT_JSON.
Replaces ALL phone screenshots of the given locale (default en-US) with phone-*.png, sorted by name.
Without --upload it only lists what it would do (dry run). The secret is only read from the environment.
"""
import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"


def package_name() -> str:
    in_app = False
    for line in open(os.path.join(ROOT, "app.config.yaml"), encoding="utf-8"):
        if re.match(r"^app:\s*$", line):
            in_app = True
        elif in_app and re.match(r"^\S", line):
            in_app = False
        m = re.match(r"^\s+package_name:\s*(\S+)", line)
        if in_app and m:
            return m.group(1).strip("\"'")
    sys.exit("package_name not found in app.config.yaml")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--locale", default="en-US")
    ap.add_argument("--upload", action="store_true")
    args = ap.parse_args()
    files = sorted(glob.glob(os.path.join(ROOT, "store/google-play/graphics/screenshots/phone-*.png")))
    if not 2 <= len(files) <= 8:
        sys.exit(f"need 2 to 8 phone screenshots, found {len(files)}")
    pkg = package_name()
    print(f"package {pkg}, locale {args.locale}, {len(files)} screenshots:")
    for f in files:
        print("  ", os.path.basename(f))
    if not args.upload:
        print("dry run: nothing uploaded (use --upload)")
        return 0

    import google.auth.transport.requests
    from google.oauth2 import service_account

    info = json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"])
    creds = service_account.Credentials.from_service_account_info(
        info, scopes=["https://www.googleapis.com/auth/androidpublisher"]
    )
    session = google.auth.transport.requests.AuthorizedSession(creds)

    def check(r, what):
        if not r.ok:
            sys.exit(f"{what} failed: HTTP {r.status_code} {r.text[:400]}")
        return r

    edit = check(session.post(f"{API}/{pkg}/edits", json={}), "create edit").json()["id"]
    base = f"{API}/{pkg}/edits/{edit}/listings/{args.locale}/phoneScreenshots"
    check(session.delete(base), "delete old screenshots")
    for f in files:
        with open(f, "rb") as fh:
            r = session.post(
                f"{UPLOAD}/{pkg}/edits/{edit}/listings/{args.locale}/phoneScreenshots?uploadType=media",
                data=fh.read(),
                headers={"Content-Type": "image/png"},
            )
        check(r, f"upload {os.path.basename(f)}")
        print("uploaded", os.path.basename(f))
    check(session.post(f"{API}/{pkg}/edits/{edit}:commit"), "commit")
    print("committed the store listing edit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
