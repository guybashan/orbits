#!/usr/bin/env bash
#
# Creates the Play Console upload key for Orbits.
#
# Run this yourself — keytool prompts for the password interactively so it is
# never typed on a command line, written into this repo, or stored in shell
# history. Keep the resulting file OUT of the repository.
#
#   ./tools/make-upload-key.sh [keystore-path] [alias]
#
# IMPORTANT: back the keystore up somewhere durable. If you lose it you cannot
# ship an update to the same listing (Play App Signing key reset is a support
# request, not a self-service fix).

set -euo pipefail

KEYSTORE="${1:-$HOME/.android-keys/orbits-upload.keystore}"
ALIAS="${2:-orbits-upload}"

if [ -e "$KEYSTORE" ]; then
	echo "error: $KEYSTORE already exists — refusing to overwrite it." >&2
	echo "Pass a different path if you really want a second key." >&2
	exit 1
fi

mkdir -p "$(dirname "$KEYSTORE")"
chmod 700 "$(dirname "$KEYSTORE")"

echo "Creating upload key at: $KEYSTORE"
echo "Alias: $ALIAS"
echo
echo "keytool will now ask you to choose a password. Use your password manager;"
echo "you will need the same password to build a release."
echo

keytool -genkeypair -v \
	-keystore "$KEYSTORE" \
	-alias "$ALIAS" \
	-keyalg RSA \
	-keysize 4096 \
	-validity 10000 \
	-dname "CN=Orbits, O=Orbits, C=IL"

chmod 600 "$KEYSTORE"

cat <<EOF

Done. To build a signed release, export these three (the password is read from
the environment, so pull it from your password manager rather than pasting it
into a file that gets committed):

  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ALIAS"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='...'

then run:

  ./tools/build-release.sh
EOF
