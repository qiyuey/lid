#!/bin/bash
# Lid release pipeline: archive → Developer ID export → notarize → DMG →
# Sparkle appcast (EdDSA-signed) → publish to GitHub Releases + Pages.
# Run on a Mac that has the Developer ID Application certificate, a notarytool
# keychain profile, and the Sparkle EdDSA private key in the login keychain.
# Headless CI can't do this (no certs / no signing key), so it's a manual step.
#
# Prereqs (one-time):
#   xcrun notarytool store-credentials lid-notary \
#       --apple-id "you@example.com" --team-id 7T4ZKYBB6Z --password <app-specific-pw>
#   # Sparkle signing key (prints the base64 public key for Info.plist SUPublicEDKey):
#   "$(./scripts/release.sh --print-sparkle-tool generate_keys)" --account qiyuey-lid
#
# Usage:
#   ./scripts/release.sh                  # uses keychain profile "lid-notary"
#   RELEASE_VERSION=2026.7.2 ./scripts/release.sh
#   NOTARY_PROFILE=myprofile ./scripts/release.sh
#   PUBLISH=0 ./scripts/release.sh        # build appcast locally but skip gh/Pages publish
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="Lid"
APP_NAME="Lid"
BUILD="build/release"
ARCHIVE="$BUILD/$APP_NAME.xcarchive"
EXPORT="$BUILD/export"
NOTARY_PROFILE="${NOTARY_PROFILE:-lid-notary}"
PUBLISH="${PUBLISH:-1}"

# Signing workspace: generate_appcast scans this directory and (re)writes
# appcast.xml covering every release archive present. Kept out of git (DMGs are
# large and live on GitHub Releases); only the resulting appcast.xml is published.
UPDATES_DIR="updates"
APPCAST="$UPDATES_DIR/appcast.xml"
# Where GitHub Pages serves the feed from. docs/ on the default branch is served
# at https://<user>.github.io/<repo>/, matching the app's SUFeedURL.
PAGES_APPCAST="docs/appcast.xml"
# Stable base URL the appcast enclosures point at (GitHub Release asset downloads).
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-https://github.com/qiyuey/lid/releases/latest/download}"
# Keychain account holding this fork's Sparkle EdDSA private key.
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-qiyuey-lid}"

command -v xcodegen >/dev/null || { echo "need xcodegen (brew install xcodegen)"; exit 1; }

# --- Resolve a Sparkle CLI tool (generate_appcast / generate_keys / sign_update) ---
# Prefers the version-pinned tools vendored at scripts/sparkle/bin/ (deterministic,
# works on a clean machine), then falls back to the SPM artifact cache, any bin/
# under the tree, and finally the Homebrew cask. Echoes the path or exits non-zero.
sparkle_tool() {
    local name="$1" hit
    [ -x "scripts/sparkle/bin/$name" ] && { echo "scripts/sparkle/bin/$name"; return 0; }
    hit=$(find ~/Library/Developer/Xcode/DerivedData -type f -name "$name" -path '*/artifacts/sparkle/Sparkle/bin/*' 2>/dev/null | head -n1 || true)
    [ -n "$hit" ] || hit=$(find . -type f -name "$name" -path '*/bin/*' 2>/dev/null | head -n1 || true)
    [ -n "$hit" ] || { [ -x "/Applications/Sparkle.app/Contents/MacOS/$name" ] && hit="/Applications/Sparkle.app/Contents/MacOS/$name"; }
    [ -n "$hit" ] || hit=$(command -v "$name" 2>/dev/null || true)
    [ -n "$hit" ] || { echo "could not find Sparkle tool '$name' (build once so SPM resolves it, vendor bin/, or 'brew install --cask sparkle')" >&2; return 1; }
    echo "$hit"
}

# Escape hatch: `./scripts/release.sh --print-sparkle-tool generate_keys`
if [ "${1:-}" = "--print-sparkle-tool" ]; then sparkle_tool "${2:?tool name}"; exit 0; fi

extract_versions() {
    [ -f "$PAGES_APPCAST" ] || return 0
    /usr/bin/sed -n \
        -e 's/.*sparkle:version="\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)".*/\1/p' \
        -e 's/.*<sparkle:version>\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)<\/sparkle:version>.*/\1/p' \
        "$PAGES_APPCAST"
}

next_calendar_version() {
    local year month prefix last_patch
    year="$(date +%Y)"
    month="$(date +%-m)"
    prefix="$year.$month."
    last_patch="$(extract_versions | awk -F. -v y="$year" -v m="$month" '
        $1 == y && $2 == m && $3 + 0 > max { max = $3 + 0 }
        END { print max + 0 }
    ')"
    echo "$prefix$((last_patch + 1))"
}

version_gt() {
    awk -F. -v a="$1" -v b="$2" '
        BEGIN {
            split(a, av, "."); split(b, bv, ".");
            for (i = 1; i <= 3; i++) {
                ai = av[i] + 0; bi = bv[i] + 0;
                if (ai > bi) exit 0;
                if (ai < bi) exit 1;
            }
            exit 1;
        }
    '
}

# Calendar version used for both CFBundleShortVersionString and CFBundleVersion.
# Format: YYYY.M.N, where N increments for every release in the same month.
RELEASE_VERSION="${RELEASE_VERSION:-$(next_calendar_version)}"

# Guard: Sparkle requires an incrementing CFBundleVersion. Read committed appcast
# versions as the durable source of truth and refuse non-incrementing releases.
LAST_VERSION="$(extract_versions | awk -F. '
    function gt(a1,a2,a3,b1,b2,b3) {
        return (a1>b1 || (a1==b1 && (a2>b2 || (a2==b2 && a3>b3))))
    }
    gt($1+0,$2+0,$3+0,y,m,p) { y=$1+0; m=$2+0; p=$3+0 }
    END { if (y) printf "%d.%d.%d\n", y, m, p }
')"
if [ -n "${LAST_VERSION:-}" ] && ! version_gt "$RELEASE_VERSION" "$LAST_VERSION"; then
    echo "✗ RELEASE_VERSION ($RELEASE_VERSION) must be > last shipped version ($LAST_VERSION)." >&2
    exit 1
fi

echo "→ [1/7] generate project"
xcodegen generate

echo "→ [2/7] archive (Developer ID signed, version $RELEASE_VERSION)"
rm -rf "$BUILD"
xcodebuild archive \
    -scheme "$SCHEME" \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    -configuration Release \
    MARKETING_VERSION="$RELEASE_VERSION" \
    CURRENT_PROJECT_VERSION="$RELEASE_VERSION"

echo "→ [3/7] export"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT" \
    -exportOptionsPlist ExportOptions.plist

APP="$EXPORT/$APP_NAME.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$BUILD/${APP_NAME}-${VERSION}.dmg"

# Notarize + staple the APP first, so the copy that ends up in the DMG carries
# its own stapled ticket (works even offline, dragged to /Applications).
echo "→ [4/7] notarize app"
ZIP="$BUILD/$APP_NAME.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "→ [5/7] staple app"
xcrun stapler staple "$APP"

echo "→ [6/7] build DMG ($DMG) from the stapled app"
STAGING="$BUILD/dmg"
rm -rf "$STAGING"; mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

echo "→ [7/7] sign + generate Sparkle appcast"
GENERATE_APPCAST=$(sparkle_tool generate_appcast)
# Start from a clean workspace each release. Every build of the same marketing
# version ships to one stable "latest" DMG URL, so the feed must advertise only
# the current build — keeping old entries would point several versions at the
# same URL with mismatched signatures. Monotonicity is still guarded against the
# committed docs/appcast.xml above, not this ephemeral dir.
rm -rf "$UPDATES_DIR"
mkdir -p "$UPDATES_DIR"
cp "$DMG" "$UPDATES_DIR/"
# Sign the archive with the keychain private key and write a fresh appcast.
# --download-url-prefix points the enclosure at the GitHub Release asset.
"$GENERATE_APPCAST" --account "$SPARKLE_ACCOUNT" --download-url-prefix "$DOWNLOAD_URL_PREFIX/" "$UPDATES_DIR"
mkdir -p "$(dirname "$PAGES_APPCAST")"
cp "$APPCAST" "$PAGES_APPCAST"

echo "✓ Released: $DMG (v$VERSION) — notarized + stapled; feed copied to $PAGES_APPCAST."

if [ "$PUBLISH" = "1" ]; then
    command -v gh >/dev/null || { echo "skip publish: need gh (brew install gh)"; exit 0; }
    TAG="v${VERSION}"
    echo "→ publish: GitHub Release $TAG (DMG asset) + appcast on Pages"
    # Create the release if absent, then upload the DMG (clobber to allow re-runs).
    gh release view "$TAG" >/dev/null 2>&1 || gh release create "$TAG" --title "$TAG" --notes "Lid $VERSION"
    gh release upload "$TAG" "$DMG" --clobber
    echo "→ commit + push the published feed so GitHub Pages serves it at SUFeedURL:"
    echo "  git add $PAGES_APPCAST && git commit -m \"appcast: $VERSION\" && git push"
fi
