#!/usr/bin/env bash
# Clones large API references into .refs/ (git-ignored) for deep lookups.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .refs
clone() { [ -d ".refs/$2" ] && git -C ".refs/$2" pull -q || git clone -q --depth 1 "https://github.com/$1/$2" ".refs/$2"; }
clone Amadeus- WoWAddonDevGuide   # 12a_Secret_Safe_APIs.md, 13_Cooldown_Viewer_Guide.md, 01_API_Reference.md
clone Gethe wow-ui-source         # Blizzards eigener UI-Code und API-Doku
clone BigWigsMods BigWigs         # Timeline-Anbindung: Plugins/Timeline.lua, Plugins/BarStyles.lua
echo "refs in .refs/"
