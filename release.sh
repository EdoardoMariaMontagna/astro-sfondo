#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Edoardo Maria Montagna
#
# Prepara il .dmg da allegare a una Release di GitHub: app universale (Apple Silicon e Intel)
# con pagina e immagini incluse, firmata in locale ("ad hoc"), più l'impronta SHA-256.
# Uso: ./release.sh 1.0.0      → dist/AstroSfondo-1.0.0.dmg e dist/AstroSfondo-1.0.0.dmg.sha256
set -euo pipefail
cd "${0:A:h}"

VERSION=${1:?"Uso: ./release.sh <versione>, ad esempio ./release.sh 1.0.0"}
OUT=dist
APP="$OUT/Astro Sfondo.app"
DMG="$OUT/AstroSfondo-$VERSION.dmg"

rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$arch-apple-macos14" \
    -framework Cocoa -framework WebKit -framework ServiceManagement \
    -o "$OUT/AstroSfondo-$arch" app/main.swift
done
lipo -create -output "$APP/Contents/MacOS/AstroSfondo" "$OUT"/AstroSfondo-arm64 "$OUT"/AstroSfondo-x86_64
rm "$OUT"/AstroSfondo-arm64 "$OUT"/AstroSfondo-x86_64

# Senza AstroWebRoot l'app usa la pagina contenuta in sé stessa invece della cartella del progetto
cp app/Info.plist "$APP/Contents/Info.plist"
plutil -remove AstroWebRoot "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
cp app/AppIcon.icns "$APP/Contents/Resources/"
rsync -a --exclude debug.html --exclude config.local.js --exclude README.md web/ "$APP/Contents/Resources/web/"

codesign --force --sign - "$APP"
codesign --verify --strict "$APP"

# Contenuto del disco: l'app e un collegamento ad Applicazioni in cui trascinarla
STAGE="$OUT/dmg"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Astro Sfondo.app"
ln -s /Applications "$STAGE/Applicazioni"
hdiutil create -quiet -volname "Astro Sfondo $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$STAGE"

(cd "$OUT" && shasum -a 256 "${DMG:t}" > "${DMG:t}.sha256")
echo "Creato $DMG ($(du -h "$DMG" | cut -f1))"
cat "$DMG.sha256"
