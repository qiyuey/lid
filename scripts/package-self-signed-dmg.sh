#!/bin/bash
# Build a self-signed, unnotarized DMG for free GitHub distribution/testing.
# The signing identity is stable because it is created once in the login
# keychain and reused by common name on later runs.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Lid"
SCHEME="Lid"
CONFIGURATION="Release"
BUILD_DIR="${BUILD_DIR:-build/self-signed}"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_ENTITLEMENTS="$BUILD_DIR/self-signed-app.entitlements"
CERT_CN="${LID_SELF_SIGNED_CERT_CN:-Lid Local Self-Signed Code Signing}"
KEYCHAIN="${LID_SELF_SIGNED_KEYCHAIN:-$(security login-keychain | tr -d ' "')}"
APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"

identity_count() {
    security find-identity -v -p codesigning "$KEYCHAIN" | grep -F "\"$CERT_CN\"" | wc -l | tr -d ' '
}

certificate_sha1() {
    security find-certificate -c "$CERT_CN" -p "$KEYCHAIN" \
        | openssl x509 -outform DER \
        | openssl dgst -sha1 -binary \
        | xxd -p -c 40 \
        | tr '[:lower:]' '[:upper:]'
}

ensure_identity() {
    local count
    count="$(identity_count)"
    if [ "$count" = "1" ]; then
        echo "→ signing identity: $CERT_CN"
        return
    fi
    if [ "$count" != "0" ]; then
        echo "found $count code-signing identities named '$CERT_CN' in $KEYCHAIN; remove duplicates before packaging" >&2
        exit 1
    fi

    echo "→ creating stable self-signed signing identity: $CERT_CN"
    local tmp pass
    tmp="$(mktemp -d)"
    pass="$(openssl rand -hex 16)"
    trap 'rm -rf "$tmp"' RETURN

    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
        -subj "/CN=$CERT_CN/O=qiyuey Lid Local/OU=Lid Local Self-Signed" \
        -set_serial 0x4c494453454c465349474e \
        -addext "keyUsage = critical,digitalSignature" \
        -addext "extendedKeyUsage = codeSigning" \
        -keyout "$tmp/lid-self-signed.key" \
        -out "$tmp/lid-self-signed.crt" >/dev/null 2>&1

    openssl pkcs12 -export -legacy \
        -name "$CERT_CN" \
        -inkey "$tmp/lid-self-signed.key" \
        -in "$tmp/lid-self-signed.crt" \
        -out "$tmp/lid-self-signed.p12" \
        -passout "pass:$pass" >/dev/null 2>&1

    security import "$tmp/lid-self-signed.p12" \
        -k "$KEYCHAIN" \
        -P "$pass" \
        -T /usr/bin/codesign \
        -T /usr/bin/security \
        -T /usr/bin/xcodebuild >/dev/null
    security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$tmp/lid-self-signed.crt" >/dev/null

    if [ "$(identity_count)" != "1" ]; then
        echo "could not create code-signing identity '$CERT_CN' in $KEYCHAIN" >&2
        exit 1
    fi
}

sign_path() {
    local path="$1"
    [ -e "$path" ] || return 0
    codesign --force --sign "$CERT_CN" --options runtime --timestamp=none "$path"
}

sign_app_bundle() {
    cat > "$APP_ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
PLIST
    codesign --force --sign "$CERT_CN" --options runtime --timestamp=none --entitlements "$APP_ENTITLEMENTS" "$APP"
}

sign_app() {
    local sparkle="$APP/Contents/Frameworks/Sparkle.framework"
    sign_path "$sparkle/Versions/B/XPCServices/Downloader.xpc"
    sign_path "$sparkle/Versions/B/XPCServices/Installer.xpc"
    sign_path "$sparkle/Versions/B/Updater.app"
    sign_path "$sparkle/Versions/B/Autoupdate"
    sign_path "$sparkle"
    sign_app_bundle
}

cleanup_registered_app() {
    local lsregister
    lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    "$lsregister" -u "$APP" >/dev/null 2>&1 || true
    rm -rf "$APP"
}

make_dmg() {
    local version dmg staging
    version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
    dmg="$BUILD_DIR/$APP_NAME-$version-self-signed.dmg"
    staging="$BUILD_DIR/dmg"

    rm -rf "$staging" "$dmg"
    mkdir -p "$staging"
    ditto "$APP" "$staging/$APP_NAME.app"
    ln -s /Applications "$staging/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$staging" -ov -format UDZO "$dmg" >/dev/null
    sign_path "$dmg"
    codesign --verify --verbose=2 "$dmg"
    hdiutil verify "$dmg" >/dev/null
    rm -rf "$staging"
    echo "$dmg"
}

ensure_identity
CERT_SHA1="$(certificate_sha1)"

echo "→ generate project"
xcodegen generate

echo "→ build unsigned app"
echo "→ pinned certificate SHA-1: $CERT_SHA1"
rm -rf "$BUILD_DIR"
xcodebuild build \
    -scheme "$SCHEME" \
    -destination 'generic/platform=macOS' \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO

echo "→ sign app bundle"
sign_app

echo "→ verify app signature"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q 'com.apple.security.cs.disable-library-validation'
codesign -R="identifier \"top.qiyuey.lid\" and certificate leaf = H\"$CERT_SHA1\"" -v "$APP"

echo "→ create DMG"
DMG="$(make_dmg)"
cleanup_registered_app

echo "✓ self-signed DMG: $DMG"
