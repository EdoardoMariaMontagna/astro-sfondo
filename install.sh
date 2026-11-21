#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Edoardo Maria Montagna
#
# Installa Astro Sfondo: compila l'app in /Applications e attiva
# l'avvio automatico all'accesso e la verifica giornaliera. Si può rilanciare senza problemi.
set -euo pipefail
cd "${0:A:h}"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Servono i Command Line Tools di Apple: installali con  xcode-select --install" >&2
  exit 1
fi

ASTRO_NO_RESTART=1 ./build.sh # l'avvio automatico viene ricaricato qui sotto

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/AstroSfondo"
for name in local.astrosfondo local.astrosfondo.verifica; do
  dest="$HOME/Library/LaunchAgents/$name.plist"
  launchctl bootout "gui/$(id -u)/$name" 2>/dev/null || true
  sed -e "s#__HOME__#$HOME#g" -e "s#__PROJECT__#$PWD#g" "launchd/$name.plist.in" > "$dest"
  plutil -lint -s "$dest"
  launchctl bootstrap "gui/$(id -u)" "$dest"
done

echo "Astro Sfondo è attivo. L'icona del mappamondo nella barra dei menu ne mostra lo stato."
