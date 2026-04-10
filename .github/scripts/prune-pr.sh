#!/usr/bin/env bash
# Remove a pr-<N>/ subtree from the gh-pages checkout.
#
# Usage: prune-pr.sh <gh-pages-checkout-dir> <pr-number>

set -euo pipefail

site_dir="${1:?usage: prune-pr.sh <gh-pages-dir> <pr-number>}"
pr_num="${2:?usage: prune-pr.sh <gh-pages-dir> <pr-number>}"

target="${site_dir}/pr-${pr_num}"
if [ -d "$target" ]; then
    rm -rf "$target"
    echo "Removed ${target}"
else
    echo "Nothing to prune at ${target}"
fi
