#!/usr/bin/env bash
# Build the markdown body for the sticky PR comment.
# Reads environment variables set by the workflow and prints markdown to stdout.
#
# Required env:
#   ERC_ERRORS, ERC_WARNINGS, DRC_ERRORS, DRC_WARNINGS
#   SITE_URL     e.g. https://jescarri.github.io/compute-board/pr-42/abc1234
#   COMMIT_SHA   full sha of the PR head commit

set -euo pipefail

erc_errors="${ERC_ERRORS:-0}"
erc_warnings="${ERC_WARNINGS:-0}"
drc_errors="${DRC_ERRORS:-0}"
drc_warnings="${DRC_WARNINGS:-0}"
site_url="${SITE_URL:?SITE_URL must be set}"
commit_sha="${COMMIT_SHA:?COMMIT_SHA must be set}"
short_sha="${commit_sha:0:7}"

icon_for() {
    local errors="$1" warnings="$2"
    if [ "$errors" != "0" ]; then
        echo ':x:'
    elif [ "$warnings" != "0" ]; then
        echo ':warning:'
    else
        echo ':white_check_mark:'
    fi
}

erc_icon=$(icon_for "$erc_errors" "$erc_warnings")
drc_icon=$(icon_for "$drc_errors" "$drc_warnings")

# File paths on the published preview site. These must match the `dir:` and
# `output:` settings in kibot.yaml.
schematic_pdf="${site_url}/schematic/compute-board-schematic.pdf"
schematic_svg="${site_url}/schematic/compute-board-schematic.svg"
pcb_layers_pdf="${site_url}/pcb/compute-board-pcb.pdf"
pcbdraw_front="${site_url}/pcb/compute-board-pcbdraw-front.png"
pcbdraw_back="${site_url}/pcb/compute-board-pcbdraw-back.png"
render_top="${site_url}/3d/top.png"
render_bottom="${site_url}/3d/bottom.png"
render_iso="${site_url}/3d/iso.png"
step_file="${site_url}/compute-board.step"

cat <<MARKDOWN
## KiCad CI preview &mdash; \`${short_sha}\`

| Check | Result |
|---|---|
| ERC | ${erc_icon} ${erc_errors} error(s), ${erc_warnings} warning(s) |
| DRC | ${drc_icon} ${drc_errors} error(s), ${drc_warnings} warning(s) |

### 3D renders

| Top (ray-traced) | Bottom | Iso |
|---|---|---|
| ![top](${render_top}) | ![bottom](${render_bottom}) | ![iso](${render_iso}) |

### PCB layers

| Front | Back |
|---|---|
| ![front](${pcbdraw_front}) | ![back](${pcbdraw_back}) |

### Downloads

- [Schematic (PDF)](${schematic_pdf}) &middot; [SVG](${schematic_svg})
- [PCB layers (PDF)](${pcb_layers_pdf})
- [STEP file](${step_file})
- [Browse full preview site](${site_url}/)

<sub>This comment is updated on every push to the PR branch. Previews hosted on GitHub Pages at <code>${site_url}/</code>.</sub>
MARKDOWN
