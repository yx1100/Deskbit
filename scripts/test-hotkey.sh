#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/whatnote-hotkey.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/Whatnote/GlobalHotKey.swift" \
  "$project_dir/Tests/HotKeyProbe.swift" \
  -o "$probe_binary"

"$probe_binary"
