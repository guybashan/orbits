#!/usr/bin/env bash
#
# Builds the signed release .aab for the Play Console.
#
#   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/.android-keys/orbits-upload.keystore
#   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=orbits-upload
#   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='...'   # from your password manager
#   ./tools/build-release.sh
#
# Optional: bump the build before exporting. Play rejects an upload whose
# versionCode it has already seen, so raise it for every new internal-test build.
#
#   VERSION_CODE=2 VERSION_NAME=1.0.1 ./tools/build-release.sh

set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
PRESET="Android"
OUTPUT="${OUTPUT:-build/orbits.aab}"

for var in GODOT_ANDROID_KEYSTORE_RELEASE_PATH \
           GODOT_ANDROID_KEYSTORE_RELEASE_USER \
           GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
	if [ -z "${!var:-}" ]; then
		echo "error: $var is not set." >&2
		echo "Run ./tools/make-upload-key.sh first, then export the three variables it prints." >&2
		exit 1
	fi
done

if [ ! -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]; then
	echo "error: keystore not found at $GODOT_ANDROID_KEYSTORE_RELEASE_PATH" >&2
	exit 1
fi

if [ -n "${VERSION_CODE:-}" ]; then
	sed -i '' -E "s|^version/code=.*|version/code=${VERSION_CODE}|" export_presets.cfg
	echo "versionCode -> ${VERSION_CODE}"
fi
if [ -n "${VERSION_NAME:-}" ]; then
	sed -i '' -E "s|^version/name=.*|version/name=\"${VERSION_NAME}\"|" export_presets.cfg
	echo "versionName -> ${VERSION_NAME}"
fi

mkdir -p "$(dirname "$OUTPUT")"
rm -f "$OUTPUT"

echo "Building $OUTPUT ..."
"$GODOT" --headless --export-release "$PRESET" "$OUTPUT"

if [ ! -f "$OUTPUT" ]; then
	echo "error: export finished but $OUTPUT was not produced." >&2
	exit 1
fi

echo
echo "Built $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
grep -E '^version/(code|name)=' export_presets.cfg | sed 's/^/  /'
echo
echo "Upload it at: Play Console -> Testing -> Internal testing -> Create new release"
