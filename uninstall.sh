#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Edoardo Maria Montagna
#
# Disinstalla Astro Sfondo e rimette lo sfondo della Scrivania scelto in precedenza.
# La cartella del progetto non viene toccata.
set -uo pipefail

APP="$HOME/Applications/AstroSfondo.app"

# Prima si fermano app e verifica, altrimenti l'app reimposterebbe la propria istantanea
for name in local.astrosfondo.verifica local.astrosfondo; do
  launchctl bootout "gui/$(id -u)/$name" 2>/dev/null
  rm -f "$HOME/Library/LaunchAgents/$name.plist"
done

[[ -x "$APP/Contents/MacOS/AstroSfondo" ]] && "$APP/Contents/MacOS/AstroSfondo" --restore-wallpaper

rm -rf "$APP" "$HOME/Library/Application Support/AstroSfondo" "$HOME/Library/Logs/AstroSfondo"
defaults delete local.astrosfondo 2>/dev/null
echo "Astro Sfondo è stato rimosso e lo sfondo precedente ripristinato."
