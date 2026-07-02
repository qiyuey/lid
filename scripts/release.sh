#!/bin/bash
# Compatibility entrypoint for Lid's self-signed release workflow.
set -euo pipefail
cd "$(dirname "$0")/.."

exec .agents/skills/lid-release/scripts/release-self-signed.sh "$@"
