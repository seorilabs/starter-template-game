#!/usr/bin/env python3
import argparse
import base64
import json
import os
import sys
from pathlib import Path

import google.auth
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "play-store" / "google-play.config.json"
DEFAULT_AAB_DIR = ROOT / "build" / "android"
ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def default_aab_path():
    """org godot-deploy-google-play 는 build/android/<repo>.aab 로 export 하고 --aab-path 를
    넘기지 않으므로, repo 명과 무관하게 해당 디렉터리의 첫 .aab 를 기본값으로 쓴다."""
    candidates = sorted(DEFAULT_AAB_DIR.glob("*.aab"))
    return str(candidates[0]) if candidates else str(DEFAULT_AAB_DIR / "app.aab")


def load_config():
    with CONFIG_PATH.open(encoding="utf-8") as file:
        return json.load(file)


def default_release_notes(config, language):
    """config 의 release.releaseNotes 에서만 기본 노트를 읽는다(없으면 빈 문자열).
    실제 다국어 노트는 Backoffice 가 붙인 release-notes.json(env RELEASE_NOTES_JSON)에서 온다."""
    release_notes = config.get("release", {}).get("releaseNotes", {})
    if isinstance(release_notes, dict):
        if release_notes.get(language):
            return release_notes[language]
        default_language = config.get("defaultLanguage")
        if default_language and release_notes.get(default_language):
            return release_notes[default_language]
    return ""


def unit_fraction(value):
    parsed = float(value)
    if not 0 < parsed <= 1:
        raise argparse.ArgumentTypeError("must be in (0, 1]")
    return parsed


def load_notes_map(path):
    """Backoffice 가 붙인 release-notes.json({notes:{'ko-KR':..}}) → {storeLocale: text}."""
    if not path:
        return {}
    notes_path = Path(path)
    if not notes_path.exists():
        return {}
    with notes_path.open(encoding="utf-8") as file:
        doc = json.load(file)
    notes = doc.get("notes", {}) if isinstance(doc, dict) else {}
    return {k: v for k, v in notes.items() if isinstance(v, str) and v.strip()}


def listing_languages(publisher, package_name, edit_id):
    """앱 스토어 등록(listing) 언어 집합. 실패 시 빈 집합."""
    try:
        response = (
            publisher.edits()
            .listings()
            .list(packageName=package_name, editId=edit_id)
            .execute()
        )
    except Exception as error:
        print(f"Warning: failed to list Google Play listings: {error}", file=sys.stderr)
        return set()
    return {item.get("language") for item in response.get("listings", []) if item.get("language")}


def build_release_notes(publisher, package_name, edit_id, args):
    """release-notes.json 이 있으면 앱 등록 언어와 교집합인 언어별 노트 전부를,
    없으면 단일 --release-notes 를 반환한다(미등록 언어는 400 방지 위해 제외)."""
    notes_map = load_notes_map(getattr(args, "release_notes_json", None))
    if notes_map:
        languages = listing_languages(publisher, package_name, edit_id)
        if languages:
            selected = {lang: text for lang, text in notes_map.items() if lang in languages}
        else:
            selected = notes_map
        if selected:
            return [{"language": lang, "text": text} for lang, text in selected.items()]
    if args.release_notes:
        return [{"language": args.release_notes_language, "text": args.release_notes}]
    return []


def decode_service_account_secret():
    raw_json = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")
    encoded_json = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64")

    if raw_json and encoded_json:
        raise RuntimeError(
            "Set only one of GOOGLE_PLAY_SERVICE_ACCOUNT_JSON or "
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64."
        )

    if raw_json:
        return json.loads(raw_json)

    if encoded_json:
        decoded = base64.b64decode(encoded_json).decode("utf-8")
        return json.loads(decoded)

    return None


def make_android_publisher():
    info = decode_service_account_secret()
    if info:
        credentials = service_account.Credentials.from_service_account_info(
            info,
            scopes=[ANDROID_PUBLISHER_SCOPE],
        )
    else:
        credentials, _project_id = google.auth.default(scopes=[ANDROID_PUBLISHER_SCOPE])

    return build("androidpublisher", "v3", credentials=credentials, cache_discovery=False)


def resolve_version_code(publisher, package_name, edit_id, aab_path, args):
    if args.skip_upload:
        if args.version_code is None:
            raise RuntimeError("--version-code is required when using --skip-upload.")
        return int(args.version_code)

    media = MediaFileUpload(
        str(aab_path),
        mimetype="application/octet-stream",
        chunksize=16 * 1024 * 1024,
        resumable=True,
    )
    bundle = (
        publisher.edits()
        .bundles()
        .upload(packageName=package_name, editId=edit_id, media_body=media)
        .execute()
    )
    return int(bundle["versionCode"])


def upload_internal_release(args):
    config = load_config()
    package_name = args.package_name or config["packageName"]
    aab_path = Path(args.aab_path).resolve()

    if not args.skip_upload and not aab_path.exists():
        raise FileNotFoundError(f"AAB file does not exist: {aab_path}")

    publisher = make_android_publisher()
    edit = publisher.edits().insert(packageName=package_name, body={}).execute()
    edit_id = edit["id"]

    try:
        version_code = resolve_version_code(publisher, package_name, edit_id, aab_path, args)

        release = {
            "name": args.release_name,
            "versionCodes": [str(version_code)],
            "status": args.release_status,
        }
        release_notes = build_release_notes(publisher, package_name, edit_id, args)
        if release_notes:
            release["releaseNotes"] = release_notes
        track_body = {
            "track": args.track,
            "releases": [release],
        }

        publisher.edits().tracks().update(
            packageName=package_name,
            editId=edit_id,
            track=args.track,
            body=track_body,
        ).execute()

        commit_kwargs = {
            "packageName": package_name,
            "editId": edit_id,
        }
        if args.changes_not_sent_for_review:
            commit_kwargs["changesNotSentForReview"] = True

        committed_edit = publisher.edits().commit(**commit_kwargs).execute()
        return {
            "packageName": package_name,
            "track": args.track,
            "releaseStatus": args.release_status,
            "bundleUploaded": not args.skip_upload,
            "versionCode": version_code,
            "editId": committed_edit["id"],
        }
    except Exception:
        publisher.edits().delete(packageName=package_name, editId=edit_id).execute()
        raise


def promote_release(args):
    """from-track 최신 versionCode 를 재빌드 없이 to-track 으로 승격 + 언어별 노트 반영
    + commit(=심사 제출). rollout 지정 시 단계적 출시."""
    config = load_config()
    package_name = args.package_name or config["packageName"]
    publisher = make_android_publisher()
    edit = publisher.edits().insert(packageName=package_name, body={}).execute()
    edit_id = edit["id"]
    try:
        source = (
            publisher.edits()
            .tracks()
            .get(packageName=package_name, editId=edit_id, track=args.promote_from_track)
            .execute()
        )
        version_codes = []
        for release in source.get("releases", []):
            version_codes.extend(int(v) for v in release.get("versionCodes", []) or [])
        if not version_codes:
            raise RuntimeError(f"No versionCode on '{args.promote_from_track}' track to promote.")
        latest = str(max(version_codes))

        release_notes = build_release_notes(publisher, package_name, edit_id, args)
        release = {
            "name": args.release_name,
            "versionCodes": [latest],
            "status": args.release_status,
        }
        if release_notes:
            release["releaseNotes"] = release_notes
        if args.rollout is not None:
            release["status"] = "inProgress"
            release["userFraction"] = args.rollout

        publisher.edits().tracks().update(
            packageName=package_name,
            editId=edit_id,
            track=args.promote_to_track,
            body={"track": args.promote_to_track, "releases": [release]},
        ).execute()
        committed_edit = publisher.edits().commit(packageName=package_name, editId=edit_id).execute()
        return {
            "packageName": package_name,
            "fromTrack": args.promote_from_track,
            "toTrack": args.promote_to_track,
            "versionCode": int(latest),
            "releaseStatus": release["status"],
            "editId": committed_edit["id"],
        }
    except Exception:
        publisher.edits().delete(packageName=package_name, editId=edit_id).execute()
        raise


def main():
    config = load_config()
    release_config = config.get("release", {})
    version_name = release_config.get("versionName", "1.0.0")
    version_code = release_config.get("versionCode", 1)

    parser = argparse.ArgumentParser(
        description="Upload a signed AAB to Google Play internal testing via Android Publisher API."
    )
    parser.add_argument("--package-name", default=config.get("packageName"))
    parser.add_argument("--aab-path", default=default_aab_path())
    parser.add_argument("--track", default=release_config.get("track", "internal"))
    parser.add_argument(
        "--skip-upload",
        action="store_true",
        help="Create or update a track release from an already uploaded versionCode.",
    )
    parser.add_argument(
        "--version-code",
        type=int,
        help="Existing uploaded versionCode to use with --skip-upload.",
    )
    parser.add_argument(
        "--release-status",
        choices=["draft", "completed"],
        default="draft",
        help="Use draft for first automation runs; completed makes it available to internal testers.",
    )
    parser.add_argument(
        "--release-name",
        default=f"{version_name} ({version_code})",
    )
    parser.add_argument("--release-notes-language", default=config.get("defaultLanguage", "en-US"))
    parser.add_argument(
        "--release-notes",
        default=None,
    )
    parser.add_argument(
        "--release-notes-json",
        default=os.environ.get("RELEASE_NOTES_JSON") or None,
        help="Path to release-notes.json ({notes:{locale:text}}) for per-language notes.",
    )
    parser.add_argument(
        "--changes-not-sent-for-review",
        action="store_true",
        help="Commit the edit with changesNotSentForReview=true.",
    )
    parser.add_argument(
        "--promote",
        action="store_true",
        help="Promote an existing build from one track to another (no rebuild).",
    )
    parser.add_argument("--promote-from-track", default="internal")
    parser.add_argument("--promote-to-track", default="production")
    parser.add_argument(
        "--rollout",
        type=unit_fraction,
        default=None,
        help="Staged rollout fraction (0,1] for promotion. Omit for full release.",
    )
    args = parser.parse_args()
    if args.release_notes is None:
        args.release_notes = default_release_notes(config, args.release_notes_language)

    try:
        result = promote_release(args) if args.promote else upload_internal_release(args)
    except Exception as error:
        action = "promotion" if args.promote else "release update"
        print(f"Google Play {action} failed: {error}", file=sys.stderr)
        return 1

    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
