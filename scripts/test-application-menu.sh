#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/whatnote-application-menu.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/Whatnote/StatusMenu.swift" \
  "$project_dir/Sources/Whatnote/ApplicationMenu.swift" \
  "$project_dir/Tests/ApplicationMenuProbe.swift" \
  -o "$probe_binary"

"$probe_binary"
