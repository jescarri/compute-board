#!/usr/bin/env bash
# Parse KiBot ERC/DRC JSON reports and export summary counts to $GITHUB_OUTPUT.
#
# Usage: parse-reports.sh <kibot-output-dir>
#
# Expected layout inside the output dir (see kibot.yaml preflight.*.dir: reports):
#   <out>/reports/*erc*.json
#   <out>/reports/*drc*.json
#
# Emits:
#   erc_errors, erc_warnings, drc_errors, drc_warnings

set -euo pipefail

out_dir="${1:?usage: parse-reports.sh <kibot-output-dir>}"
reports_dir="${out_dir}/reports"

have_jq() { command -v jq >/dev/null 2>&1; }

if ! have_jq; then
    echo "::warning::jq not available, installing" >&2
    sudo apt-get update -qq && sudo apt-get install -yqq jq
fi

# Count violations of a given severity in a KiBot JSON report.
# KiBot writes the KiCad native JSON format which has top-level "violations"
# arrays under "sheets" (ERC) or "drc_violations"/"unconnected_items"/"schematic_parity" (DRC).
count_severity() {
    local file="$1" severity="$2"
    if [ ! -f "$file" ]; then
        echo 0
        return
    fi
    # Walk every object with a "severity" field anywhere in the document.
    jq -r --arg sev "$severity" '
        [.. | objects | select(has("severity")) | select(.severity == $sev)] | length
    ' "$file" 2>/dev/null || echo 0
}

pick_report() {
    local kind="$1"
    # Prefer the canonical name; fall back to a glob.
    local candidate
    for candidate in \
        "${reports_dir}"/*"${kind}"*.json \
        "${out_dir}"/*"${kind}"*.json; do
        if [ -f "$candidate" ]; then
            echo "$candidate"
            return
        fi
    done
    echo ''
}

erc_file="$(pick_report erc)"
drc_file="$(pick_report drc)"

echo "ERC report: ${erc_file:-<not found>}"
echo "DRC report: ${drc_file:-<not found>}"

erc_errors=$(count_severity "$erc_file" error)
erc_warnings=$(count_severity "$erc_file" warning)
drc_errors=$(count_severity "$drc_file" error)
drc_warnings=$(count_severity "$drc_file" warning)

echo "ERC: ${erc_errors} errors, ${erc_warnings} warnings"
echo "DRC: ${drc_errors} errors, ${drc_warnings} warnings"

{
    echo "erc_errors=${erc_errors}"
    echo "erc_warnings=${erc_warnings}"
    echo "drc_errors=${drc_errors}"
    echo "drc_warnings=${drc_warnings}"
} >>"${GITHUB_OUTPUT:-/dev/stdout}"
