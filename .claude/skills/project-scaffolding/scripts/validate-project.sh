#!/usr/bin/env bash
# Conformance checker for a UiPath REFramework project instantiated from templates/.
#
# The rules live in validate-project.ps1 and this is a thin wrapper around it. That is
# deliberate: the checker has to read .xlsx, and PowerShell 7 ships System.IO.Compression
# everywhere it runs, including Linux and macOS. Maintaining a second, independent
# implementation in bash would mean two rule sets drifting apart - and a checker nobody
# trusts is worse than no checker.
#
# Usage:
#   ./validate-project.sh <project-dir> [<project-dir> ...] [--warnings-as-errors]
#
# Exit code 0 when there are no errors, 1 otherwise.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS1_SCRIPT="$HERE/validate-project.ps1"

if [ ! -f "$PS1_SCRIPT" ]; then
    echo "error: $PS1_SCRIPT not found." >&2
    exit 2
fi

PWSH="$(command -v pwsh || true)"
if [ -z "$PWSH" ]; then
    cat >&2 <<'EOF'
error: pwsh (PowerShell 7+) is not on PATH.

  The checker reads the Config_*.xlsx workbooks as OOXML, which needs
  System.IO.Compression. Install PowerShell 7:

    Windows   winget install --id Microsoft.PowerShell
    macOS     brew install --cask powershell
    Linux     https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux
EOF
    exit 2
fi

if [ $# -eq 0 ]; then
    echo "usage: $(basename "$0") <project-dir> [<project-dir> ...] [--warnings-as-errors]" >&2
    exit 2
fi

ARGS=()
WAE=""
for a in "$@"; do
    case "$a" in
        --warnings-as-errors) WAE="-WarningsAsErrors" ;;
        *) ARGS+=("$a") ;;
    esac
done

if [ -n "$WAE" ]; then
    exec "$PWSH" -NoProfile -File "$PS1_SCRIPT" "${ARGS[@]}" "$WAE"
else
    exec "$PWSH" -NoProfile -File "$PS1_SCRIPT" "${ARGS[@]}"
fi
