#!/usr/bin/env bash
# Parse KiBot ERC/DRC plain-text reports and export summary counts to
# $GITHUB_OUTPUT.
#
# Usage: parse-reports.sh <kibot-output-dir>
#
# KiBot 1.8.5 writes the preflight results as RPT/TXT files at the output
# root (e.g. out/compute-board-drc.txt, out/compute-board-erc.txt). Both
# formats annotate every violation with a "    ; error" or "    ; warning"
# severity line immediately after the violation title. We count those.
#
# Filtered violations (see preflight.filters in kibot.yaml) do not appear
# in the TXT file at all, so the counts reflect the post-filter state.
#
# Emits: erc_errors, erc_warnings, drc_errors, drc_warnings

set -euo pipefail

out_dir="${1:?usage: parse-reports.sh <kibot-output-dir>}"

pick_report() {
    local kind="$1" candidate
    # KiBot writes these at the out/ root by default. Also check a reports/
    # subdir in case the config is changed later.
    for candidate in \
        "${out_dir}"/*"${kind}".txt \
        "${out_dir}"/*"${kind}".rpt \
        "${out_dir}"/reports/*"${kind}".txt \
        "${out_dir}"/reports/*"${kind}".rpt; do
        if [ -f "$candidate" ]; then
            echo "$candidate"
            return
        fi
    done
    echo ''
}

# Violation categories that are CI-environment noise: the CI container does
# not share the user's local KiCad library tables, so these warnings always
# fire here regardless of the board state. kibot.yaml filters them so the
# preflight doesn't abort; the parser also drops them so the PR badge shows
# actionable counts only.
#
# Note: silk_edge_clearance is intentionally *not* in this list. kibot.yaml
# filters it to keep the preflight green, but it is a real (cosmetic)
# finding the reviewer should see, so the parser still counts it.
readonly SUPPRESSED_CATEGORIES='lib_footprint_issues|footprint_link_issues'

count_severity() {
    local file="$1" severity="$2"
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo 0
        return
    fi
    # Walk the report: remember the most recent "[category]:" header, and
    # count "    ; <severity>" lines that follow unless their category is
    # in the suppress list.
    awk -v sev="$severity" -v suppress="$SUPPRESSED_CATEGORIES" '
        # Violation title line, e.g. "[silk_edge_clearance]: ...".
        # Use index/substr instead of gawk-only 3-arg match().
        /^\[/ {
            close_idx = index($0, "]:")
            if (close_idx > 2) {
                cat = substr($0, 2, close_idx - 2)
            } else {
                cat = ""
            }
            next
        }
        # Severity marker for the most recent title.
        $0 ~ "^[[:space:]]*;[[:space:]]*" sev "[[:space:]]*$" {
            if (cat !~ "^(" suppress ")$") n++
            next
        }
        END { print n+0 }
    ' "$file"
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
