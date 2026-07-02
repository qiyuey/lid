#!/bin/bash
# Build the same self-signed Release artifact used for distribution and install
# it into /Applications for local testing.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Lid"
APP_ID="top.qiyuey.lid"
BUILD_DIR="${BUILD_DIR:-build/local-self-signed-install}"
LEGACY_LOCAL_RELEASE_DERIVED_DATA="${LEGACY_LOCAL_RELEASE_DERIVED_DATA:-build/LocalReleaseInstallDerivedData}"
DEST="/Applications/$APP_NAME.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

unregister_launch_services_app() {
    local app_path="$1"
    [ -d "$app_path" ] || return 0
    "$LSREGISTER" -u "$app_path" >/dev/null 2>&1 || true
}

echo "-> build self-signed Release DMG"
BUILD_DIR="$BUILD_DIR" ./scripts/package-self-signed-dmg.sh

DMG="$(find "$BUILD_DIR" -maxdepth 1 -name "$APP_NAME-*-self-signed.dmg" -print | sort | tail -1)"
if [ -z "$DMG" ] || [ ! -f "$DMG" ]; then
    echo "could not find self-signed DMG in $BUILD_DIR" >&2
    exit 1
fi

echo "-> quit running app"
osascript -e "tell application id \"$APP_ID\" to quit" >/dev/null 2>&1 || true
for _ in {1..20}; do
    if ! pgrep -x "$APP_NAME" >/dev/null; then
        break
    fi
    sleep 0.25
done
if pgrep -x "$APP_NAME" >/dev/null; then
    pkill -x "$APP_NAME" || true
fi

if [ -x "$DEST/Contents/MacOS/$APP_NAME" ]; then
    echo "-> unregister existing helper if present"
    "$DEST/Contents/MacOS/$APP_NAME" --unregister-helper >/dev/null 2>&1 || true
    sleep 1
fi

echo "-> unregister old LaunchServices entries"
unregister_launch_services_app "$DEST"
if [ -d build ]; then
    while IFS= read -r app_path; do
        unregister_launch_services_app "$app_path"
    done < <(find build -path "*/$APP_NAME.app" -type d -prune 2>/dev/null)
fi

if [ -d "$LEGACY_LOCAL_RELEASE_DERIVED_DATA" ]; then
    echo "-> remove legacy raw Release build output"
    rm -rf "$LEGACY_LOCAL_RELEASE_DERIVED_DATA"
fi

echo "-> install $DMG"
mount_output="$(hdiutil attach "$DMG" -nobrowse -readonly)"
mount_point="$(printf '%s\n' "$mount_output" | awk '/\/Volumes\// {for (i=3; i<=NF; i++) {printf "%s%s", (i==3 ? "" : OFS), $i}; print ""}' | tail -1)"
if [ -z "$mount_point" ] || [ ! -d "$mount_point/$APP_NAME.app" ]; then
    echo "could not find mounted $APP_NAME.app" >&2
    exit 1
fi

rm -rf "$DEST"
/usr/bin/ditto "$mount_point/$APP_NAME.app" "$DEST"
hdiutil detach "$mount_point" >/dev/null
/usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
"$LSREGISTER" -f -R "$DEST" >/dev/null 2>&1 || true
mdimport "$DEST" >/dev/null 2>&1 || true

echo "-> verify installed signature"
codesign --verify --deep --strict --verbose=2 "$DEST"
codesign -dv --verbose=2 "$DEST" 2>&1 | sed -n '1,35p'

echo "-> launch $DEST"
/usr/bin/open "$DEST"
echo "Installed self-signed $DEST. Install or approve the helper from Lid's menu if macOS requests it."
