#!/usr/bin/env bash
# Generate shields.io endpoint badge JSON files from parsed ERC/DRC counts.
# Reads counts from environment (exported by parse-reports.sh) or positional args,
# and writes <out>/badges/erc.json and <out>/badges/drc.json.
#
# Usage: gen-badges.sh <kibot-output-dir>
#
# Env vars (all optional, default to 0):
#   ERC_ERRORS, ERC_WARNINGS, DRC_ERRORS, DRC_WARNINGS

set -euo pipefail

out_dir="${1:?usage: gen-badges.sh <kibot-output-dir>}"
badges_dir="${out_dir}/badges"
mkdir -p "$badges_dir"

erc_errors="${ERC_ERRORS:-0}"
erc_warnings="${ERC_WARNINGS:-0}"
drc_errors="${DRC_ERRORS:-0}"
drc_warnings="${DRC_WARNINGS:-0}"

write_badge() {
    local path="$1" label="$2" message="$3" color="$4"
    cat >"$path" <<JSON
{
  "schemaVersion": 1,
  "label": "${label}",
  "message": "${message}",
  "color": "${color}"
}
JSON
}

status_color() {
    local errors="$1" warnings="$2"
    if [ "$errors" != "0" ]; then
        echo red
    elif [ "$warnings" != "0" ]; then
        echo yellow
    else
        echo brightgreen
    fi
}

erc_msg="${erc_errors} err, ${erc_warnings} warn"
drc_msg="${drc_errors} err, ${drc_warnings} warn"

write_badge "${badges_dir}/erc.json" "ERC" "$erc_msg" "$(status_color "$erc_errors" "$erc_warnings")"
write_badge "${badges_dir}/drc.json" "DRC" "$drc_msg" "$(status_color "$drc_errors" "$drc_warnings")"

echo "Wrote badges to ${badges_dir}"
