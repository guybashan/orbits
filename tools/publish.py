#!/usr/bin/env python3
"""
Upload build/orbits.aab to a Play Console track and roll it out.

    python3 tools/publish.py --key ~/.android-keys/play-api.json
    python3 tools/publish.py --key ... --track internal --no-rollout   # draft only

Needs a Google Play Developer API service account key. Creating it is a
one-time job that only the account owner can do, because it mints a
credential:

    1. Play Console -> Setup -> API access -> link a Google Cloud project
    2. Create a service account, then grant it "Release manager" for this app
       under Users and permissions
    3. Download its JSON key
    4. Pass the path with --key (or set PLAY_API_KEY)

Nothing else in the release pipeline changes: tools/build-release.sh still
produces the bundle, this only ships it.

Dependencies (install once):
    pip3 install google-auth requests
"""
import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_AAB = ROOT / "build" / "orbits.aab"
PACKAGE = "com.guybashan.orbits"
BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def die(message, hint=None):
    print(f"error: {message}", file=sys.stderr)
    if hint:
        print(f"       {hint}", file=sys.stderr)
    raise SystemExit(1)


def session_for(key_path):
    try:
        from google.oauth2 import service_account
        from google.auth.transport.requests import AuthorizedSession
    except ImportError:
        die("google-auth is not installed", "pip3 install google-auth requests")

    if not key_path or not Path(key_path).is_file():
        die(f"service account key not found: {key_path}",
            "see the header of this file for how to create one")

    creds = service_account.Credentials.from_service_account_file(
        str(key_path), scopes=[SCOPE]
    )
    return AuthorizedSession(creds)


def check(response, what):
    if response.status_code >= 400:
        detail = response.text.strip()
        # The API is specific about permission problems; surface them verbatim
        # rather than guessing at the cause.
        die(f"{what} failed ({response.status_code})", detail[:400])
    return response.json() if response.text else {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", default=os.environ.get("PLAY_API_KEY"))
    ap.add_argument("--aab", default=str(DEFAULT_AAB))
    ap.add_argument("--track", default="internal",
                    choices=["internal", "alpha", "beta", "production"])
    ap.add_argument("--notes", default="")
    ap.add_argument("--no-rollout", action="store_true",
                    help="upload and leave the release as a draft")
    args = ap.parse_args()

    aab = Path(args.aab)
    if not aab.is_file():
        die(f"bundle not found: {aab}", "run ./tools/build-release.sh first")

    api = session_for(args.key)
    size_mb = aab.stat().st_size / 1048576

    print(f"package {PACKAGE}  track {args.track}")
    print(f"bundle  {aab}  ({size_mb:.0f} MB)")

    edit = check(api.post(f"{BASE}/{PACKAGE}/edits"), "creating an edit")
    edit_id = edit["id"]

    print("uploading ...")
    with aab.open("rb") as handle:
        uploaded = check(
            api.post(
                f"{UPLOAD}/{PACKAGE}/edits/{edit_id}/bundles?uploadType=media",
                headers={"Content-Type": "application/octet-stream"},
                data=handle,
            ),
            "uploading the bundle",
        )
    version = uploaded["versionCode"]
    print(f"  versionCode {version} accepted")

    release = {"versionCodes": [str(version)],
               "status": "draft" if args.no_rollout else "completed"}
    if args.notes:
        release["releaseNotes"] = [{"language": "en-US", "text": args.notes}]

    check(
        api.put(
            f"{BASE}/{PACKAGE}/edits/{edit_id}/tracks/{args.track}",
            json={"track": args.track, "releases": [release]},
        ),
        "setting the track",
    )

    check(api.post(f"{BASE}/{PACKAGE}/edits/{edit_id}:commit"), "committing")

    state = "left as a draft" if args.no_rollout else "rolled out"
    print(f"done — versionCode {version} {state} on {args.track}")


if __name__ == "__main__":
    main()
