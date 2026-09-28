#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/whatnote-storage.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/Whatnote/NoteAppearance.swift" \
  "$project_dir/Sources/Whatnote/Models.swift" \
  "$project_dir/Sources/Whatnote/NoteHistory.swift" \
  "$project_dir/Sources/Whatnote/RichTextCodec.swift" \
  "$project_dir/Sources/Whatnote/NoteStore.swift" \
  "$project_dir/Tests/StorageProbe.swift" \
  -o "$probe_binary"

"$probe_binary"
