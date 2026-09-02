#!/usr/bin/env bash
#
# Fetch one or more REFramework templates out of rpa-ai-skills without cloning the
# whole repo. Blobless, depth-1, sparse checkout of templates/<name>/ only.
#
#   fetch-template.sh [-r <repo-url>] [-b <ref>] [-d <dest>] <template> [<template>...]
#
# Works with no setup: the canonical repo is the default. Override with -r, or by
# setting RPA_SKILLS_REPO, when you work from a fork or an internal mirror.
# Precedence: -r  >  $RPA_SKILLS_REPO  >  default.

set -euo pipefail

DEFAULT_REPO="https://github.com/ramesh09laksh-boop/rpa-ai-skills"

if [ -n "${RPA_SKILLS_REPO:-}" ]; then
    REPO="$RPA_SKILLS_REPO"
    REPO_SOURCE="\$RPA_SKILLS_REPO"
else
    REPO="$DEFAULT_REPO"
    REPO_SOURCE="default"
fi

REF=""
DEST="."

VALID_TEMPLATES="REFramework-Dispatcher-Base REFramework-Performer-Finnova REFramework-Performer-Avaloq"

usage() {
    cat <<EOF
Usage: $(basename "$0") [-r <repo-url>] [-b <ref>] [-d <dest>] <template> [<template>...]

  -r <repo-url>  Git URL of rpa-ai-skills. Overrides \$RPA_SKILLS_REPO.
                 Default: $DEFAULT_REPO
  -b <ref>       Branch or tag to fetch. Defaults to the remote's default branch.
  -d <dest>      Directory to place the templates in. Defaults to the current directory.
  -h             This message.

Templates:
$(for t in $VALID_TEMPLATES; do echo "  $t"; done)

Always fetch REFramework-Dispatcher-Base plus whichever Performer the SDD calls for.

Examples:
  # Canonical repo, no setup needed:
  $(basename "$0") REFramework-Dispatcher-Base REFramework-Performer-Finnova

  # Fork or internal mirror:
  $(basename "$0") -r https://git.internal/rpa-ai-skills.git \\
      REFramework-Dispatcher-Base REFramework-Performer-Finnova
EOF
}

while getopts ':r:b:d:h' opt; do
    case "$opt" in
        r) REPO="$OPTARG"; REPO_SOURCE="-r" ;;
        b) REF="$OPTARG" ;;
        d) DEST="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) echo "error: -$OPTARG requires an argument" >&2; usage >&2; exit 2 ;;
        \?) echo "error: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

command -v git >/dev/null 2>&1 || { echo "error: git is not on PATH" >&2; exit 1; }

if [ -z "$REPO" ]; then
    echo "error: repository URL is empty ($REPO_SOURCE)." >&2
    echo "       Unset it to fall back to the default, or pass a real URL to -r." >&2
    exit 2
fi

if [ "$#" -eq 0 ]; then
    echo "error: name at least one template." >&2
    usage >&2
    exit 2
fi

# Reject anything not on the known list, so a stray argument cannot turn into an
# arbitrary sparse-checkout path.
TEMPLATES=()
for requested in "$@"; do
    matched=""
    for known in $VALID_TEMPLATES; do
        [ "$requested" = "$known" ] && matched="$known" && break
    done
    if [ -z "$matched" ]; then
        echo "error: unknown template '$requested'." >&2
        echo "       Valid: $VALID_TEMPLATES" >&2
        exit 2
    fi
    TEMPLATES+=("$matched")
done

mkdir -p "$DEST"
DEST_ABS="$(cd "$DEST" && pwd)"

# Refuse to clobber. A re-run must not silently discard work in progress.
for t in "${TEMPLATES[@]}"; do
    if [ -e "$DEST_ABS/$t" ]; then
        echo "error: $DEST_ABS/$t already exists. Move or delete it first." >&2
        exit 1
    fi
done

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

echo "Fetching from $REPO [$REPO_SOURCE]${REF:+ (ref: $REF)}"

CLONE_ARGS=(--filter=blob:none --sparse --depth 1)
[ -n "$REF" ] && CLONE_ARGS+=(--branch "$REF")

# --sparse checks out root-level files only; sparse-checkout set then adds the
# directories we actually want. Cone mode (the default) is what populates a whole
# directory from a path -- --no-cone takes gitignore-style patterns and silently
# checks out nothing for a bare "/templates/<name>/".
if ! git clone "${CLONE_ARGS[@]}" "$REPO" "$WORK/repo" >/dev/null; then
    echo "" >&2
    echo "error: could not clone $REPO [$REPO_SOURCE]." >&2
    if [ "$REPO_SOURCE" = "default" ]; then
        cat >&2 <<EOF
       GitHub reports "not found" both for a repo that does not exist and for a
       private repo you are not authenticated to. If this one is private, set up
       credentials (gh auth login, SSH key, or a PAT) and retry. If your team works
       from a fork or an internal mirror, point at it instead:

         export RPA_SKILLS_REPO=<your-url>     # once, per developer
         $(basename "$0") -r <your-url> ...    # or per invocation
EOF
    fi
    exit 1
fi

SPARSE_PATHS=()
for t in "${TEMPLATES[@]}"; do
    SPARSE_PATHS+=("templates/$t")
done
git -C "$WORK/repo" sparse-checkout set "${SPARSE_PATHS[@]}" >/dev/null

for t in "${TEMPLATES[@]}"; do
    if [ ! -d "$WORK/repo/templates/$t" ]; then
        echo "error: templates/$t not found in $REPO${REF:+ at $REF}." >&2
        exit 1
    fi
    mv "$WORK/repo/templates/$t" "$DEST_ABS/$t"
    echo "  -> $DEST_ABS/$t"
done

cat <<EOF

Fetched $# template(s). This is scaffolding, not a project yet:

  1. Studio: File > New > Robotic Enterprise Process, Compatibility: Windows
     (not 'Windows - Legacy'), then copy the fetched project.json, project.uiproj,
     entry-points.json, Data/ and Tests/ over what Studio generated.
  2. Apply the 'Deltas to apply to the generated skeleton' section in each fetched
     template's README.md.
  3. Work the instantiation checklist in templates/README.md - project name, fresh
     GUIDs, every [UC-SPECIFIC - replace] in Config_TST.xlsx AND Config_PRD.xlsx,
     and the shared queue name.

project.json ships "name": "<PROJECT-NAME-TBD-ask-team>", which fails the
publishability check on purpose. Ask the team for the name before the first publish.
EOF
