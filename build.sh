#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Edoardo Maria Montagna
#
# Compila "Astro Sfondo.app", la firma in locale e la installa in /Applications.
# Uso: ./build.sh            (dopo modifiche a app/main.swift; per web/ basta "Ricarica lo sfondo")
set -euo pipefail
cd "${0:A:h}"

BUILD=build/AstroSfondo.app
DEST="/Applications/Astro Sfondo.app"
LEGACY="$HOME/Applications/AstroSfondo.app" # posizione delle prime versioni

if [[ ! -w /Applications ]]; then
  echo "Non posso scrivere in /Applications: serve un utente amministratore" >&2
  exit 1
fi

rm -rf build
mkdir -p "$BUILD/Contents/MacOS" "$BUILD/Contents/Resources"

# architettura del Mac che compila: Apple Silicon (arm64) o Intel (x86_64)
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos14" \
  -framework Cocoa -framework WebKit -framework ServiceManagement \
  -o "$BUILD/Contents/MacOS/AstroSfondo" app/main.swift

sed "s#__WEB_ROOT__#$PWD/web#" app/Info.plist > "$BUILD/Contents/Info.plist"
cp app/AppIcon.icns "$BUILD/Contents/Resources/"
rsync -a --exclude debug.html --exclude config.local.js web/ "$BUILD/Contents/Resources/web/"

# Firma "ad hoc" dell'intera app: sigilla anche risorse e Info.plist, così Gatekeeper la considera integra
codesign --force --sign - "$BUILD"
codesign --verify --strict "$BUILD"

rm -rf "$DEST" "$LEGACY"
ditto "$BUILD" "$DEST"
# registra l'app presso LaunchServices, così il Finder mostra subito la nuova icona
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
echo "Installata in $DEST"

# Se l'avvio automatico è attivo, riavvia l'app per usare la nuova versione.
# install.sh lo salta (ASTRO_NO_RESTART=1) perché ricarica comunque l'avvio automatico:
# due avvii sovrapposti producono un falso "blocco" di Gatekeeper nei log.
if [[ -z ${ASTRO_NO_RESTART:-} ]] && launchctl print "gui/$(id -u)/local.astrosfondo" >/dev/null 2>&1; then
  launchctl kickstart -k "gui/$(id -u)/local.astrosfondo"
  echo "Riavviata"
fi
