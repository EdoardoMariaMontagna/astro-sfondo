// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Edoardo Maria Montagna

// Strato di nuvole generato all'avvio: rumore frattale 3D campionato sulla sfera (quindi senza
// giunture ai bordi della mappa), con più nubi all'equatore e alle medie latitudini e meno sui
// deserti subtropicali, come nella circolazione atmosferica reale. È decorativo: non sono le
// nuvole di oggi. Si genera una volta sola, poi la scena lo fa solo ruotare.

// Rumore di Perlin "migliorato" (2002) con permutazione ripetibile
function makeNoise(seed) {
  const perm = new Uint8Array(512);
  const base = Array.from({ length: 256 }, (_, i) => i);
  let s = seed >>> 0;
  for (let i = 255; i > 0; i--) {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    const j = s % (i + 1);
    [base[i], base[j]] = [base[j], base[i]];
  }
  for (let i = 0; i < 512; i++) perm[i] = base[i & 255];

  const fade = (t) => t * t * t * (t * (t * 6 - 15) + 10);
  const lerp = (a, b, t) => a + t * (b - a);
  const grad = (h, x, y, z) => {
    const u = h < 8 ? x : y;
    const v = h < 4 ? y : h === 12 || h === 14 ? x : z;
    return ((h & 1) ? -u : u) + ((h & 2) ? -v : v);
  };

  return function noise(x, y, z) {
    const X = Math.floor(x) & 255, Y = Math.floor(y) & 255, Z = Math.floor(z) & 255;
    x -= Math.floor(x); y -= Math.floor(y); z -= Math.floor(z);
    const u = fade(x), v = fade(y), w = fade(z);
    const A = perm[X] + Y, AA = perm[A] + Z, AB = perm[A + 1] + Z;
    const B = perm[X + 1] + Y, BA = perm[B] + Z, BB = perm[B + 1] + Z;
    return lerp(
      lerp(lerp(grad(perm[AA] & 15, x, y, z), grad(perm[BA] & 15, x - 1, y, z), u),
        lerp(grad(perm[AB] & 15, x, y - 1, z), grad(perm[BB] & 15, x - 1, y - 1, z), u), v),
      lerp(lerp(grad(perm[AA + 1] & 15, x, y, z - 1), grad(perm[BA + 1] & 15, x - 1, y, z - 1), u),
        lerp(grad(perm[AB + 1] & 15, x, y - 1, z - 1), grad(perm[BB + 1] & 15, x - 1, y - 1, z - 1), u), v),
      w);
  };
}

const smoothstep = (a, b, x) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};

// Copertura media per latitudine (radianti): fascia equatoriale, deserti a ±25°, perturbazioni a ±55°
function coverByLatitude(lat) {
  const a = Math.abs(lat);
  return 0.08 * Math.exp(-((lat / 0.14) ** 2))
    - 0.14 * Math.exp(-(((a - 0.42) / 0.14) ** 2))
    + 0.1 * Math.exp(-(((a - 0.96) / 0.22) ** 2));
}

// Restituisce i pixel (RGBA, riga 0 = polo sud, come vuole una DataTexture) di una mappa w×h
export function cloudPixels(w = 1024, h = 512, seed = 2026) {
  const noise = makeNoise(seed);
  const fbm = (x, y, z, octaves) => {
    let sum = 0, amp = 0.5, f = 1;
    for (let o = 0; o < octaves; o++) {
      sum += amp * noise(x * f, y * f, z * f);
      amp *= 0.5;
      f *= 2.03;
    }
    return sum;
  };
  const data = new Uint8Array(w * h * 4);
  for (let j = 0; j < h; j++) {
    const lat = ((j + 0.5) / h - 0.5) * Math.PI;
    const cl = Math.cos(lat), sl = Math.sin(lat);
    const cover = coverByLatitude(lat);
    for (let i = 0; i < w; i++) {
      const lon = ((i + 0.5) / w) * 2 * Math.PI;
      const x = cl * Math.cos(lon) * 2.2, y = sl * 2.2, z = cl * Math.sin(lon) * 2.2;
      // distorsione del dominio: dà alle nubi l'aspetto di vortici e fronti allungati
      const qx = fbm(x + 1.7, y + 9.2, z + 3.1, 3);
      const qy = fbm(x + 8.3, y + 2.8, z + 7.4, 3);
      const v = fbm(x * 1.6 + 2.2 * qx, y * 2.4 + 2.2 * qy, z * 1.6 + 2.2 * qx, 6) + cover;
      const d = Math.round(255 * smoothstep(-0.06, 0.3, v) ** 1.2);
      const k = (j * w + i) * 4;
      data[k] = data[k + 1] = data[k + 2] = d;
      data[k + 3] = 255;
    }
  }
  return data;
}
