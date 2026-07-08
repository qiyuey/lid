# Security Policy

## Supported versions

Lid is a small project; security fixes land on the latest `main` and the most
recent release. Please test against the latest code before reporting.

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report privately via GitHub's **Security Advisories** — go to the repository's
**Security** tab → **Report a vulnerability**. If you can't use that, email
[nghialt01146@gmail.com](mailto:nghialt01146@gmail.com) instead.

Please include steps to reproduce, the macOS version, and the impact you
observed. I'll acknowledge as soon as I can and keep you posted on a fix.

## Security-relevant surface

Lid is not sandboxed and changes a system power setting after macOS
administrator authorization, so a few areas matter more than usual:

- **Administrator authorization**: the app asks macOS to run
  `/usr/bin/pmset -a disablesleep 1` or `0` through `osascript` with
  administrator privileges.
- **State verification**: after changing the setting, Lid reads `pmset -g` and
  verifies the observed `SleepDisabled` flag matches the requested state.
- **Power-setting persistence**: if Lid is not running, the last selected macOS
  power setting remains in effect until the user changes it again.
- **Sparkle updates**: update metadata and downloads are signed; please report
  any issue that could bypass update validation.

Issues in any of these (privilege escalation, command injection, state
verification failure, or update validation bypass) are the most valuable to
report.
