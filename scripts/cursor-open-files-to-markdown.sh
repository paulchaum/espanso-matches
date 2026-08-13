#!/bin/bash

# Copy the files currently open in Cursor for the git project in the current
# directory to the clipboard, as markdown snippets prefixed with their
# project-relative path.

set -o pipefail

# Project root = git repo containing the current directory
ROOT=$(git rev-parse --show-toplevel)

if [ -z "$ROOT" ]; then
    echo "Not inside a git repository" >&2
    exit 1
fi

# Most recently written workspace state DB for that project
WAL=$(ls -t $(grep -l "\"file://$ROOT\"" ~/.config/Cursor/User/workspaceStorage/*/workspace.json | sed 's/workspace\.json$/state.vscdb-wal/') 2>/dev/null | head -1)

if [ -z "$WAL" ]; then
    echo "No Cursor workspace storage found for $ROOT" >&2
    exit 1
fi

# Read the editor layout memento, keep unique paths inside the project, dump each file
sqlite3 "file:${WAL%-wal}?mode=ro" \
    "select value from ItemTable where key='memento/workbench.parts.editor'" \
    | grep -oP '(?<=fsPath\\":\\")[^\\"]+' \
    | awk -v p="$ROOT/" 'index($0,p)==1 && !seen[$0]++' \
    | while read -r f; do
        printf '```\n// %s\n%s\n```\n\n' "${f#$ROOT/}" "$(cat "$f")"
    done \
    | xclip -selection clipboard && echo "Copied to clipboard"
