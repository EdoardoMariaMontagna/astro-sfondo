#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Edoardo Maria Montagna
#
# Scarica le immagini di Terra e Luna dagli esempi di three.js (versione r170) e ne verifica
# l'impronta SHA-256. Non sono incluse nel repository perché la loro licenza non è dichiarata:
# vedi THIRD_PARTY_NOTICES.md
set -euo pipefail
cd "${0:A:h}/web/textures"

BASE=https://raw.githubusercontent.com/mrdoob/three.js/r170/examples/textures/planets
typeset -A SHA256=(
  earth_atmos_2048.jpg    2faa400d1eade3bc44caf6750d1b772bd9bbb6d87362c02bc7c3304e78fa0a9d
  earth_specular_2048.jpg 2df48906732d7a458b2d0a7cdec51a829262307c6bdee4cfdf079a4dd7c71c69
  earth_lights_2048.png   3cc6972d1d5b6310f33ea6ef4cc14a38f1dd141a91d26888206889327d983d7b
  earth_clouds_1024.png   7d3b82ef6b3feb506fc06f02a744aed3d864e23e7417075005f4082a7ff935a4
  moon_1024.jpg           fcb0f1f5548e6e18d40063dd55c6aacd3daedf2407b181dab85b61e22bf9fe57
)

hash_of() { shasum -a 256 "$1" | cut -d' ' -f1; }

for file in ${(k)SHA256}; do
  if [[ -s $file && $(hash_of "$file") == ${SHA256[$file]} ]]; then
    echo "$file: già presente"
    continue
  fi
  curl -fsSL --max-time 120 -o "$file.tmp" "$BASE/$file"
  if [[ $(hash_of "$file.tmp") != ${SHA256[$file]} ]]; then
    rm -f "$file.tmp"
    echo "$file: impronta non corrispondente, file scartato" >&2
    exit 1
  fi
  mv "$file.tmp" "$file"
  echo "$file: scaricato e verificato"
done
