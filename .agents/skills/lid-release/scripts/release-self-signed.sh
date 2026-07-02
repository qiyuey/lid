#!/bin/bash
# Publish a self-signed Lid release.
#
# This is the single high-level release entry point for the free/self-signed
# distribution path. It intentionally does not support Developer ID notarization.
set -euo pipefail

APP_NAME="Lid"
APPCAST="docs/appcast.xml"
PACKAGE_SCRIPT="scripts/package-self-signed-dmg.sh"
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-qiyuey-lid}"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-https://github.com/qiyuey/lid/releases/latest/download}"

VERSION=""
DRY_RUN=0

usage() {
    cat <<USAGE
Usage:
  .agents/skills/lid-release/scripts/release-self-signed.sh [--version YYYY.M.N] [--dry-run]

Publishes the next self-signed Lid GitHub release:
  1. resolve/bump calendar version
  2. generate Xcode project
  3. run Lid-CI tests
  4. commit and push the version bump
  5. build and verify the self-signed DMG
  6. create GitHub Release and upload the DMG
  7. generate Sparkle appcast
  8. commit and push appcast
  9. verify release/tag/main state

Options:
  --version YYYY.M.N  Release a specific version instead of the next calendar version.
  --dry-run          Print the resolved version and release plan without changing files.
  -h, --help         Show this help.
USAGE
}

die() {
    echo "error: $*" >&2
    exit 1
}

log() {
    echo "-> $*"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --version)
            [ "$#" -ge 2 ] || die "--version requires YYYY.M.N"
            VERSION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || die "must run inside the Lid git repository"
cd "$ROOT"

[ -f "project.yml" ] || die "project.yml not found; run from the Lid repository"
[ -x "$PACKAGE_SCRIPT" ] || die "$PACKAGE_SCRIPT is missing or not executable"

require_cmd git
require_cmd gh
require_cmd xcodegen
require_cmd xcodebuild
require_cmd hdiutil
require_cmd codesign
require_cmd /usr/libexec/PlistBuddy
require_cmd /usr/bin/perl

DIRTY_STATUS="$(git status --porcelain=v1)"
if [ -n "$DIRTY_STATUS" ]; then
    git status --short
    if [ "$DRY_RUN" = "1" ]; then
        echo "warning: working tree is dirty; dry-run will not change files" >&2
    else
        die "working tree must be clean before release"
    fi
fi

BRANCH="$(git branch --show-current)"
[ "$BRANCH" = "main" ] || die "release must run from main, current branch is '$BRANCH'"

gh auth status >/dev/null

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

extract_appcast_versions() {
    [ -f "$APPCAST" ] || return 0
    /usr/bin/sed -n \
        -e 's/.*sparkle:version="\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)".*/\1/p' \
        -e 's/.*<sparkle:version>\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)<\/sparkle:version>.*/\1/p' \
        "$APPCAST"
}

extract_tag_versions() {
    git tag --list 'v[0-9]*.[0-9]*.[0-9]*' | /usr/bin/sed 's/^v//'
}

extract_release_versions() {
    gh release list --limit 100 --json tagName --jq '.[].tagName' 2>/dev/null \
        | /usr/bin/sed -n 's/^v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$/\1/p' || true
}

all_known_versions() {
    {
        extract_appcast_versions
        extract_tag_versions
        extract_release_versions
    } | awk 'NF' | sort -u
}

max_version() {
    all_known_versions | awk -F. '
        function gt(a1,a2,a3,b1,b2,b3) {
            return (a1>b1 || (a1==b1 && (a2>b2 || (a2==b2 && a3>b3))))
        }
        /^[0-9]+\.[0-9]+\.[0-9]+$/ && gt($1+0,$2+0,$3+0,y,m,p) {
            y=$1+0; m=$2+0; p=$3+0; seen=1
        }
        END { if (seen) printf "%d.%d.%d\n", y, m, p }
    '
}

next_calendar_version() {
    local year month
    year="$(date +%Y)"
    month="$(date +%m | /usr/bin/sed 's/^0//')"
    all_known_versions | awk -F. -v y="$year" -v m="$month" '
        $1 == y && $2 == m && $3 + 0 > max { max = $3 + 0 }
        END { printf "%d.%d.%d\n", y, m, max + 1 }
    '
}

latest_git_tag() {
    extract_tag_versions | awk -F. '
        function gt(a1,a2,a3,b1,b2,b3) {
            return (a1>b1 || (a1==b1 && (a2>b2 || (a2==b2 && a3>b3))))
        }
        /^[0-9]+\.[0-9]+\.[0-9]+$/ && gt($1+0,$2+0,$3+0,y,m,p) {
            y=$1+0; m=$2+0; p=$3+0; seen=1
        }
        END { if (seen) printf "v%d.%d.%d\n", y, m, p }
    '
}

sparkle_tool() {
    local name="$1" hit
    [ -x "scripts/sparkle/bin/$name" ] && { echo "scripts/sparkle/bin/$name"; return 0; }
    hit="$(command -v "$name" 2>/dev/null || true)"
    [ -n "$hit" ] || die "could not find Sparkle tool '$name'"
    echo "$hit"
}

if [ "$DRY_RUN" = "0" ]; then
    log "sync main and tags"
    git fetch origin main --tags
    LOCAL="$(git rev-parse HEAD)"
    REMOTE="$(git rev-parse origin/main)"
    BASE="$(git merge-base HEAD origin/main)"
    if [ "$LOCAL" = "$REMOTE" ]; then
        :
    elif [ "$LOCAL" = "$BASE" ]; then
        git pull --ff-only origin main
    else
        die "main has diverged from origin/main"
    fi
fi

if [ -z "$VERSION" ]; then
    VERSION="$(next_calendar_version)"
fi

[[ "$VERSION" =~ ^[0-9]{4}\.[0-9]{1,2}\.[0-9]+$ ]] || die "invalid version '$VERSION'; expected YYYY.M.N"

LAST_VERSION="$(max_version)"
if [ -n "${LAST_VERSION:-}" ] && ! version_gt "$VERSION" "$LAST_VERSION"; then
    die "release version $VERSION must be greater than last known version $LAST_VERSION"
fi

TAG="v$VERSION"
DMG="build/self-signed/${APP_NAME}-${VERSION}-self-signed.dmg"

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    die "tag already exists locally: $TAG"
fi
if gh release view "$TAG" >/dev/null 2>&1; then
    die "GitHub Release already exists: $TAG"
fi

PREVIOUS_TAG="$(latest_git_tag)"

if [ "$DRY_RUN" = "1" ]; then
    cat <<DRYRUN
Self-signed Lid release dry run
  version:        $VERSION
  tag:            $TAG
  previous tag:   ${PREVIOUS_TAG:-none}
  dmg:            $DMG
  branch:         $BRANCH

Planned live steps:
  - update project.yml MARKETING_VERSION/CURRENT_PROJECT_VERSION to $VERSION
  - run xcodegen generate
  - run Lid-CI tests
  - commit and push version bump
  - run $PACKAGE_SCRIPT
  - create GitHub Release $TAG with DMG asset
  - generate and commit docs/appcast.xml
  - push main and verify release/tag/main
DRYRUN
    exit 0
fi

log "bump project version to $VERSION"
RELEASE_VERSION="$VERSION" /usr/bin/perl -0pi -e '
    s/MARKETING_VERSION: "[0-9]+\.[0-9]+\.[0-9]+"/MARKETING_VERSION: "$ENV{RELEASE_VERSION}"/g;
    s/CURRENT_PROJECT_VERSION: "[0-9]+\.[0-9]+\.[0-9]+"/CURRENT_PROJECT_VERSION: "$ENV{RELEASE_VERSION}"/g;
' project.yml

log "generate project"
xcodegen generate

log "run Lid-CI tests"
set -o pipefail
if command -v xcbeautify >/dev/null 2>&1; then
    xcodebuild test -scheme Lid-CI -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO | xcbeautify
else
    xcodebuild test -scheme Lid-CI -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
fi

log "commit and push version bump"
git add project.yml
if git diff --cached --quiet; then
    die "project.yml did not change while bumping to $VERSION"
fi
git commit -m "chore(release): bump version to $VERSION"
git push

log "build self-signed DMG"
"$PACKAGE_SCRIPT"
[ -f "$DMG" ] || die "expected DMG was not produced: $DMG"
codesign --verify --verbose=2 "$DMG"
hdiutil verify "$DMG" >/dev/null

log "verify app inside DMG"
MOUNT="$(mktemp -d /tmp/lid-release.XXXXXX)"
cleanup_mount() {
    hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
    rmdir "$MOUNT" >/dev/null 2>&1 || true
}
trap cleanup_mount EXIT
hdiutil attach "$DMG" -mountpoint "$MOUNT" -nobrowse -readonly >/dev/null
APP="$MOUNT/$APP_NAME.app"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
[ "$APP_VERSION" = "$VERSION" ] || die "DMG app version is $APP_VERSION, expected $VERSION"
[ "$APP_BUILD" = "$VERSION" ] || die "DMG app build is $APP_BUILD, expected $VERSION"
codesign --verify --deep --strict --verbose=2 "$APP"
cleanup_mount
trap - EXIT

log "create release notes"
NOTES_FILE="build/self-signed/release-notes-$VERSION.md"
mkdir -p "$(dirname "$NOTES_FILE")"
{
    echo "Lid helps your Mac keep working with the lid closed, so long-running agent sessions, builds, downloads, and remote connections can continue while the MacBook is tucked away."
    echo
    echo "## What's New"
    echo
    if [ -n "$PREVIOUS_TAG" ]; then
        git log --reverse --pretty=format:'- %s' "$PREVIOUS_TAG"..HEAD \
            | grep -Ev '^- chore\(release\): (bump version|update appcast)' || true
    else
        git log --reverse --pretty=format:'- %s' HEAD \
            | grep -Ev '^- chore\(release\): (bump version|update appcast)' || true
    fi
    echo
    echo "## Install Note"
    echo
    echo "Lid requires macOS 26 or later."
    echo
    echo 'The attached DMG is self-signed and not notarized. If macOS blocks first launch, right-click `Lid.app` in Finder and choose **Open**, or allow it in **System Settings > Privacy & Security**.'
} > "$NOTES_FILE"

if ! grep -q '^- ' "$NOTES_FILE"; then
    /usr/bin/perl -0pi -e 's/## What'\''s New\n\n/## What'\''s New\n\n- Maintenance release.\n/' "$NOTES_FILE"
fi

log "create GitHub Release $TAG"
TARGET_COMMIT="$(git rev-parse HEAD)"
gh release create "$TAG" "$DMG" --target "$TARGET_COMMIT" --title "Lid $VERSION" --notes-file "$NOTES_FILE"

log "generate Sparkle appcast"
GENERATE_APPCAST="$(sparkle_tool generate_appcast)"
rm -rf updates
mkdir -p updates
cp "$DMG" updates/
"$GENERATE_APPCAST" --account "$SPARKLE_ACCOUNT" --download-url-prefix "$DOWNLOAD_URL_PREFIX/" updates
cp updates/appcast.xml "$APPCAST"

log "commit and push appcast"
git add "$APPCAST"
if git diff --cached --quiet; then
    die "$APPCAST did not change"
fi
git commit -m "chore(release): update appcast for $VERSION"
git push

log "verify published state"
git fetch origin "refs/tags/$TAG:refs/tags/$TAG" >/dev/null 2>&1 || true
gh release view "$TAG" --json tagName,name,isDraft,isPrerelease,url,assets,publishedAt,targetCommitish \
    --jq '{tagName,name,isDraft,isPrerelease,url,publishedAt,targetCommitish,assets:[.assets[].name]}'
git ls-remote --exit-code --tags origin "$TAG" >/dev/null
git ls-remote --exit-code origin refs/heads/main >/dev/null

if [ -n "$(git status --porcelain=v1)" ]; then
    git status --short
    die "release completed, but tracked working tree is not clean"
fi

log "published $TAG"
echo "DMG: $DMG"
