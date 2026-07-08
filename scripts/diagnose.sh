#!/bin/bash
# Collect a compact local diagnostic snapshot for Lid sleep-state issues.
set -euo pipefail

LOG_WINDOW="${LID_LOG_WINDOW:-2h}"

section() {
    printf '\n== %s ==\n' "$1"
}

section "system"
sw_vers

section "power"
/usr/bin/pmset -g 2>&1 || true

section "lid logs ($LOG_WINDOW)"
/usr/bin/log show \
    --last "$LOG_WINDOW" \
    --style compact \
    --info \
    --predicate 'subsystem == "top.qiyuey.lid"' 2>&1 || true
