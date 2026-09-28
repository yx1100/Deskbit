#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/whatnote-note-creation-layout.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/Whatnote/NoteCreationLayout.swift" \
  "$project_dir/Tests/NoteCreationLayoutProbe.swift" \
  -o "$probe_binary"

"$probe_binary"
