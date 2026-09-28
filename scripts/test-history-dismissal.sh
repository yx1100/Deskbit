#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/whatnote-history-dismissal.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/Whatnote/HistoryPopoverDismissalMonitor.swift" \
  "$project_dir/Tests/HistoryDismissalProbe.swift" \
  -o "$probe_binary"

"$probe_binary"
