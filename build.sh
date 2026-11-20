#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Edoardo Maria Montagna
#
# Compila AstroSfondo.app, la firma in locale e la installa in ~/Applications.
# Uso: ./build.sh            (dopo modifiche a app/main.swift; per web/ basta "Ricarica lo sfondo")
set -euo pipefail
cd "${0:A:h}"

BUILD=build/AstroSfondo.app
DEST="$HOME/Applications/AstroSfondo.app"

rm -rf build
mkdir -p "$BUILD/Contents/MacOS" "$BUILD/Contents/Resources"

# architettura del Mac che compila: Apple Silicon (arm64) o Intel (x86_64)
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos14" \
  -framework Cocoa -framework WebKit \
  -o "$BUILD/Contents/MacOS/AstroSfondo" app/main.swift

sed "s#__WEB_ROOT__#$PWD/web#" app/Info.plist > "$BUILD/Contents/Info.plist"
rsync -a --exclude debug.html web/ "$BUILD/Contents/Resources/web/"

# Firma "ad hoc" dell'intera app: sigilla anche risorse e Info.plist, così Gatekeeper la considera integra
codesign --force --sign - "$BUILD"
codesign --verify --strict "$BUILD"

mkdir -p "$HOME/Applications"
rm -rf "$DEST"
ditto "$BUILD" "$DEST"
echo "Installata in $DEST"

# Se l'avvio automatico è attivo, riavvia l'app per usare la nuova versione
if launchctl print "gui/$(id -u)/local.astrosfondo" >/dev/null 2>&1; then
  launchctl kickstart -k "gui/$(id -u)/local.astrosfondo"
  echo "Riavviata"
fi
