#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/deskbit-media.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/Deskbit/NoteAppearance.swift" \
  "$project_dir/Sources/Deskbit/RichTextCodec.swift" \
  "$project_dir/Sources/Deskbit/NoteMedia.swift" \
  "$project_dir/Tests/MediaProbe.swift" \
  -o "$probe_binary"

"$probe_binary"
