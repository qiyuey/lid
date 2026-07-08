#!/bin/bash
# Lid — M0 spike
# Keep a MacBook (Apple Silicon) running EVEN WITH THE LID CLOSED so coding
# agents keep working. Mechanism: set the SleepDisabled flag in IOPMrootDomain
# via `pmset -a disablesleep`. This shell version is the spike; the real app
# uses the same system setting through macOS administrator authorization.
#
# USAGE (run on the MacBook, not the Mac mini — the mini has no lid):
#   chmod +x lid.sh
#   ./lid.sh on        # keep running with lid closed
#   ./lid.sh off       # restore normal sleep (RUN THIS WHEN DONE!)
#   ./lid.sh status
#   ./lid.sh toggle

set -euo pipefail

get_state() {
  if pmset -g 2>/dev/null | grep -qiE 'SleepDisabled[[:space:]]+1'; then
    echo "on"
  else
    echo "off"
  fi
}

show_status() {
  local s; s=$(get_state)
  if [ "$s" = "on" ]; then
    echo "🟢 Lid ON — running with lid closed."
  else
    echo "⚪️ Lid OFF — normal sleep on lid close."
  fi
}

turn_on() {
  echo "→ Enabling Lid (sudo)..."
  sudo pmset -a disablesleep 1
  sleep 1
  if [ "$(get_state)" = "on" ]; then
    echo "✅ ON. Close the lid — the machine should stay up."
    echo "⚠️  Remember to run: ./lid.sh off"
  else
    echo "❌ Could not set the flag."
    echo "   $(pmset -g | grep -i sleepdisabled || echo 'no SleepDisabled line')"
    exit 1
  fi
}

turn_off() {
  echo "→ Disabling Lid (sudo)..."
  sudo pmset -a disablesleep 0
  sleep 1
  if [ "$(get_state)" = "off" ]; then
    echo "✅ OFF. Normal sleep restored."
  else
    echo "❌ Still on? Try again or reboot to reset."
    exit 1
  fi
}

cmd="${1:-status}"
case "$cmd" in
  on)      turn_on ;;
  off)     turn_off ;;
  status)  show_status ;;
  toggle)  [ "$(get_state)" = "on" ] && turn_off || turn_on ;;
  *) echo "Usage: $0 {on|off|status|toggle}"; exit 2 ;;
esac
