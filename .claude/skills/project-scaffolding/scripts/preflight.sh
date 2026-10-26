#!/usr/bin/env bash
# Environment preflight for a UC build. Thin wrapper around preflight.ps1 - the checks live
# there for the same reason validate-project does: one implementation, not two drifting ones.
#
# Usage:
#   ./preflight.sh [<project-dir>] [--skip-capture]
#
# Exit code 0 when nothing is blocking, 1 otherwise.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS1_SCRIPT="$HERE/preflight.ps1"

if [ ! -f "$PS1_SCRIPT" ]; then
    echo "error: $PS1_SCRIPT not found." >&2
    exit 2
fi

PWSH="$(command -v pwsh || true)"
if [ -z "$PWSH" ]; then
    cat >&2 <<'EOF'
error: pwsh (PowerShell 7+) is not on PATH.

  PowerShell 7 is itself one of the things preflight checks for, so this message is
  the first finding. Install it:

    Windows   winget install --id Microsoft.PowerShell
    macOS     brew install --cask powershell
    Linux     https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux
EOF
    exit 2
fi

ARGS=()
PROJECT=""
for a in "$@"; do
    case "$a" in
        --skip-capture) ARGS+=("-SkipCapture") ;;
        -*) echo "error: unknown option '$a'" >&2; exit 2 ;;
        *)  PROJECT="$a" ;;
    esac
done

if [ -n "$PROJECT" ]; then
    ARGS+=("-ProjectPath" "$PROJECT")
fi

# -NoProfile is not optional. A user PowerShell profile that prompts or loads slowly makes this
# script appear to hang with no output at all - which is exactly the class of confusing
# environment failure preflight exists to prevent.
exec "$PWSH" -NoProfile -File "$PS1_SCRIPT" ${ARGS[@]+"${ARGS[@]}"}
