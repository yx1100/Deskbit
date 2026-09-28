#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/whatnote-focus.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  ${(f)"$(find "$project_dir/Sources/Whatnote" -maxdepth 1 -name '*.swift' ! -name 'main.swift' -print | sort)"} \
  "$project_dir/Tests/FocusProbe.swift" \
  -o "$probe_binary"

"$probe_binary"
