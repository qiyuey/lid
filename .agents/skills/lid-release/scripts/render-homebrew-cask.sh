#!/bin/bash
# Render and validate the Lid Homebrew cask from the repository template.
set -euo pipefail

VERSION=""
SHA256=""
OUTPUT=""
TEMPLATE=".github/homebrew/lid.rb.template"

usage() {
    cat <<USAGE
Usage:
  .agents/skills/lid-release/scripts/render-homebrew-cask.sh --version YYYY.M.N --sha256 SHA --output Casks/lid.rb
USAGE
}

die() {
    echo "error: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --version)
            [ "$#" -ge 2 ] || die "--version requires a value"
            VERSION="$2"
            shift 2
            ;;
        --sha256)
            [ "$#" -ge 2 ] || die "--sha256 requires a value"
            SHA256="$2"
            shift 2
            ;;
        --output)
            [ "$#" -ge 2 ] || die "--output requires a path"
            OUTPUT="$2"
            shift 2
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

[[ "$VERSION" =~ ^[0-9]{4}\.[0-9]{1,2}\.[0-9]+$ ]] || die "invalid version: $VERSION"
[[ "$SHA256" =~ ^[0-9a-f]{64}$ ]] || die "invalid sha256: $SHA256"
[ -n "$OUTPUT" ] || die "--output is required"
[ -f "$TEMPLATE" ] || die "$TEMPLATE is missing"

mkdir -p "$(dirname "$OUTPUT")"
RELEASE_VERSION="$VERSION" RELEASE_SHA256="$SHA256" /usr/bin/perl -0pe '
    s/__VERSION__/$ENV{RELEASE_VERSION}/g;
    s/__SHA256__/$ENV{RELEASE_SHA256}/g;
' "$TEMPLATE" > "$OUTPUT"

if grep -q '__VERSION__\|__SHA256__' "$OUTPUT"; then
    die "unexpanded placeholder remains in $OUTPUT"
fi

ruby -c "$OUTPUT" >/dev/null

if command -v brew >/dev/null 2>&1; then
    brew ruby -e 'require "cask/cask_loader"; content = File.read(ARGV.fetch(0)); c = Cask::CaskLoader::FromContentLoader.new(content).load(config: nil); abort "wrong cask token" unless c.token == "lid"; abort "wrong version" unless c.version.to_s == ARGV.fetch(1)' "$OUTPUT" "$VERSION" >/dev/null
fi
