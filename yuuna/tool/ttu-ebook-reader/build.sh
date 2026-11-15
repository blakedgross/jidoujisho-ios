#!/usr/bin/env bash
# Rebuilds assets/ttu-ebook-reader: ッツ Ebook Reader at the commit the app
# bundles, plus jidoujisho.patch:
#   - exports are handed to the app as a console message instead of a download
#   - wide windows (unfolded iPhone Duo, tablets in landscape) show two-page
#     spreads, for vertical text too
#
# Requires git, Node.js and corepack. Usage: tool/ttu-ebook-reader/build.sh
set -euo pipefail

TTU_REPOSITORY=https://github.com/ttu-ttu/ebook-reader.git
TTU_COMMIT=8d7115f
PNPM=pnpm@8.3.1

here="$(cd "$(dirname "$0")" && pwd)"
assets="$here/../../assets/ttu-ebook-reader"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

git clone --quiet --filter=blob:none "$TTU_REPOSITORY" "$work/ttu"
git -C "$work/ttu" checkout --quiet "$TTU_COMMIT"
git -C "$work/ttu" apply "$here/jidoujisho.patch"

export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
(cd "$work/ttu" && corepack "$PNPM" install --frozen-lockfile --ignore-scripts)
(cd "$work/ttu/apps/web" && corepack "$PNPM" build)

rm -rf "$assets"
cp -R "$work/ttu/apps/web/build" "$assets"
echo "Rebuilt $assets"
