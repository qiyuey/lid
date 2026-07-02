#!/bin/bash
# Prepare a self-signed Lid release by committing a version bump and pushing a
# release tag. GitHub Actions performs the build, GitHub Release, appcast, and
# Homebrew tap publishing work.
set -euo pipefail

APPCAST="docs/appcast.xml"
WORKFLOW_FILE="release.yml"

VERSION=""
DRY_RUN=0
NO_WATCH=0

usage() {
    cat <<USAGE
Usage:
  .agents/skills/lid-release/scripts/release-self-signed.sh [--version YYYY.M.N] [--dry-run] [--no-watch]

Creates a tag-driven self-signed Lid release:
  1. resolve/bump calendar version
  2. generate Xcode project
  3. run Lid-CI tests locally
  4. commit and push the version bump to main
  5. create and push vYYYY.M.N
  6. watch the GitHub Actions release workflow

GitHub Actions then builds the DMG, creates the GitHub Release, updates
docs/appcast.xml, and pushes the Homebrew cask to qiyuey/homebrew-tap.

Options:
  --version YYYY.M.N  Release a specific version instead of the next calendar version.
  --dry-run           Print the resolved version and release plan without changing files.
  --no-watch          Push the tag and print the workflow lookup command without waiting.
  -h, --help          Show this help.
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
        --no-watch)
            NO_WATCH=1
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
[ -f ".github/workflows/$WORKFLOW_FILE" ] || die ".github/workflows/$WORKFLOW_FILE is missing"

require_cmd git
require_cmd gh
require_cmd xcodegen
require_cmd xcodebuild
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

wait_for_release_run() {
    local sha="$1" run_id run_url

    log "wait for release workflow to start"
    for _ in $(seq 1 60); do
        run_id="$(gh run list \
            --workflow "$WORKFLOW_FILE" \
            --limit 20 \
            --json databaseId,event,headSha \
            --jq ".[] | select(.event == \"push\" and .headSha == \"$sha\") | .databaseId" \
            | head -n1)"
        if [ -n "$run_id" ]; then
            break
        fi
        sleep 5
    done

    [ -n "${run_id:-}" ] || die "release workflow did not start for commit $sha"
    run_url="$(gh run view "$run_id" --json url --jq .url)"
    echo "Release workflow: $run_url"
    gh run watch "$run_id" --exit-status
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

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    die "tag already exists locally: $TAG"
fi
if gh release view "$TAG" >/dev/null 2>&1; then
    die "GitHub Release already exists: $TAG"
fi

if [ "$DRY_RUN" = "1" ]; then
    cat <<DRYRUN
Self-signed Lid release dry run
  version:      $VERSION
  tag:          $TAG
  branch:       $BRANCH
  workflow:     .github/workflows/$WORKFLOW_FILE

Planned live steps:
  - update project.yml MARKETING_VERSION/CURRENT_PROJECT_VERSION to $VERSION
  - run xcodegen generate
  - run Lid-CI tests locally
  - commit and push version bump to main
  - create and push tag $TAG
  - GitHub Actions builds DMG, creates Release, updates appcast, and updates qiyuey/homebrew-tap
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

TARGET_COMMIT="$(git rev-parse HEAD)"

log "create and push release tag $TAG"
git tag -a "$TAG" -m "Lid $VERSION"
git push origin "$TAG"

if [ "$NO_WATCH" = "1" ]; then
    echo "Tag pushed: $TAG"
    echo "Watch with: gh run list --workflow $WORKFLOW_FILE --limit 5"
else
    wait_for_release_run "$TARGET_COMMIT"
fi

if [ -n "$(git status --porcelain=v1)" ]; then
    git status --short
    die "release tag pushed, but working tree is not clean"
fi

log "release tag pushed: $TAG"
