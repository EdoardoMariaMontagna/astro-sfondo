// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Edoardo Maria Montagna

// Impostazioni dello sfondo. Per personalizzarle senza toccare questo file crea
// web/config.local.js (escluso da git) con solo le voci da cambiare, ad esempio:
//   export const CONFIG = { location: { name: 'Napoli', lat: 40.8518, lon: 14.2681 } };
// e poi scegli "Ricarica lo sfondo" dal menu dell'app.
const DEFAULTS = {
  // Luogo per alba, tramonto e il puntino sul globo: l'Osservatorio di Greenwich (longitudine 0°)
  location: { name: 'Greenwich', lat: 51.4769, lon: -0.0005 },
  // Fotogrammi al secondo delle animazioni d'ambiente (stelle, nuvole): più alto = più fluido, più consumi
  fps: 15,
  // Deriva decorativa delle nuvole, in gradi al minuto (le nuvole non sono quelle reali)
  cloudDriftDegPerMin: 1.5,
  // Distanza della Luna in raggi terrestri: quella vera (60) la porterebbe fuori dallo schermo
  moonDistance: 1.85,
};

let local = {};
try {
  local = (await import('./config.local.js')).CONFIG ?? {};
} catch {
  // nessuna personalizzazione locale
}

export const CONFIG = { ...DEFAULTS, ...local, location: { ...DEFAULTS.location, ...local.location } };
