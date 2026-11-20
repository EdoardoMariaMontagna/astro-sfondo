// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Edoardo Maria Montagna

// Effemeridi a bassa precisione (P. Schlyter, "How to compute planetary positions",
// con le perturbazioni lunari principali). Precisione: Sole ~0,01°, Luna ~0,1-0,2°:
// più che sufficiente per uno sfondo, con eventi (fasi, stagioni) esatti a pochi minuti.

const RAD = Math.PI / 180;
const DEG = 180 / Math.PI;
const DAY_MS = 86400000;

export const norm360 = (x) => ((x % 360) + 360) % 360;
const norm180 = (x) => norm360(x + 180) - 180;
const sin = (x) => Math.sin(x * RAD);
const cos = (x) => Math.cos(x * RAD);

export const julianDay = (date) => date.getTime() / DAY_MS + 2440587.5;

// Giorni dal 2000 gen 0,0 TU: l'epoca su cui sono scritti i coefficienti di Schlyter
const dayNumber = (date) => julianDay(date) - 2451543.5;

export const obliquity = (date) => 23.4393 - 3.563e-7 * dayNumber(date);

// Tempo siderale medio di Greenwich, in gradi: di quanto la Terra ha ruotato rispetto alle stelle
export const gmst = (date) =>
  norm360(280.46061837 + 360.98564736629 * (julianDay(date) - 2451545.0));

function eccentricAnomaly(meanAnomalyDeg, e) {
  const m = meanAnomalyDeg * RAD;
  let E = m + e * Math.sin(m) * (1 + e * Math.cos(m));
  for (let i = 0; i < 6; i++) E -= (E - e * Math.sin(E) - m) / (1 - e * Math.cos(E));
  return E;
}

// Longitudine eclittica geocentrica del Sole, ascensione retta e declinazione (gradi)
export function sunPosition(date) {
  const d = dayNumber(date);
  const w = 282.9404 + 4.70935e-5 * d;
  const e = 0.016709 - 1.151e-9 * d;
  const M = norm360(356.047 + 0.9856002585 * d);
  const E = eccentricAnomaly(M, e);
  const xv = Math.cos(E) - e;
  const yv = Math.sqrt(1 - e * e) * Math.sin(E);
  const lon = norm360(Math.atan2(yv, xv) * DEG + w);
  const eps = obliquity(date);
  return {
    lon,
    distanceAU: Math.hypot(xv, yv),
    ra: norm360(Math.atan2(cos(eps) * sin(lon), cos(lon)) * DEG),
    dec: Math.asin(sin(eps) * sin(lon)) * DEG,
    meanAnomaly: M,
    meanLongitude: norm360(M + w),
  };
}

// Longitudine e latitudine eclittiche geocentriche della Luna (gradi), distanza in raggi terrestri
export function moonPosition(date) {
  const d = dayNumber(date);
  const N = norm360(125.1228 - 0.0529538083 * d); // nodo ascendente
  const inc = 5.1454;
  const w = norm360(318.0634 + 0.1643573223 * d);
  const a = 60.2666;
  const e = 0.0549;
  const M = norm360(115.3654 + 13.0649929509 * d);

  const E = eccentricAnomaly(M, e);
  const xv = a * (Math.cos(E) - e);
  const yv = a * Math.sqrt(1 - e * e) * Math.sin(E);
  const vw = Math.atan2(yv, xv) * DEG + w;
  let r = Math.hypot(xv, yv);
  const xh = r * (cos(N) * cos(vw) - sin(N) * sin(vw) * cos(inc));
  const yh = r * (sin(N) * cos(vw) + cos(N) * sin(vw) * cos(inc));
  const zh = r * sin(vw) * sin(inc);
  let lon = Math.atan2(yh, xh) * DEG;
  let lat = Math.atan2(zh, Math.hypot(xh, yh)) * DEG;

  const sun = sunPosition(date);
  const Ms = sun.meanAnomaly;
  const Lm = norm360(N + w + M);
  const D = Lm - sun.meanLongitude; // elongazione media
  const F = Lm - N; // argomento di latitudine
  lon += -1.274 * sin(M - 2 * D) + 0.658 * sin(2 * D) - 0.186 * sin(Ms)
    - 0.059 * sin(2 * M - 2 * D) - 0.057 * sin(M - 2 * D + Ms) + 0.053 * sin(M + 2 * D)
    + 0.046 * sin(2 * D - Ms) + 0.041 * sin(M - Ms) - 0.035 * sin(D)
    - 0.031 * sin(M + Ms) - 0.015 * sin(2 * F - 2 * D) + 0.011 * sin(M - 4 * D);
  lat += -0.173 * sin(F - 2 * D) - 0.055 * sin(M - F - 2 * D) - 0.046 * sin(M + F - 2 * D)
    + 0.033 * sin(F + 2 * D) + 0.017 * sin(2 * M + F);
  r += -0.58 * cos(M - 2 * D) - 0.46 * cos(2 * D);

  return { lon: norm360(lon), lat, distanceEarthRadii: r, node: N, inclination: inc };
}

// Fase: 0° = nuova, 90° = primo quarto, 180° = piena, 270° = ultimo quarto
export const moonElongation = (date) => norm360(moonPosition(date).lon - sunPosition(date).lon);

export function moonPhase(date) {
  const sun = sunPosition(date);
  const moon = moonPosition(date);
  const elong = norm360(moon.lon - sun.lon);
  const psi = Math.acos(cos(moon.lat) * cos(moon.lon - sun.lon)) * DEG;
  return {
    elongation: elong,
    illumination: (1 - cos(psi)) / 2,
    waxing: elong < 180,
    name: phaseName(elong),
  };
}

function phaseName(elong) {
  const near = (target) => Math.abs(norm180(elong - target)) < 6; // circa ±12 ore
  if (near(0)) return 'Luna nuova';
  if (near(90)) return 'Primo quarto';
  if (near(180)) return 'Luna piena';
  if (near(270)) return 'Ultimo quarto';
  if (elong < 90) return 'Falce crescente';
  if (elong < 180) return 'Gibbosa crescente';
  if (elong < 270) return 'Gibbosa calante';
  return 'Falce calante';
}

// Primo istante dopo `from` in cui angleFn raggiunge `target` (angolo che cresce di ~ratePerDay)
function nextAngleCrossing(angleFn, target, from, ratePerDay) {
  const delta = norm360(target - angleFn(from));
  let t = from.getTime() + (delta / ratePerDay) * DAY_MS;
  for (let i = 0; i < 8; i++) {
    const err = norm180(target - angleFn(new Date(t)));
    t += (err / ratePerDay) * DAY_MS;
    if (Math.abs(err) < 1e-5) break;
  }
  return new Date(t);
}

const PHASES = [
  { angle: 0, name: 'Luna nuova' },
  { angle: 90, name: 'Primo quarto' },
  { angle: 180, name: 'Luna piena' },
  { angle: 270, name: 'Ultimo quarto' },
];

export function nextMoonPhases(from) {
  return PHASES.map((p) => ({ ...p, date: nextAngleCrossing(moonElongation, p.angle, from, 12.19075) }))
    .sort((a, b) => a.date - b.date);
}

// Ultima Luna nuova prima di `from`: serve per l'età della Luna
export function lastNewMoon(from) {
  const elong = moonElongation(from);
  const guess = new Date(from.getTime() - (elong / 12.19075 + 2) * DAY_MS);
  return nextAngleCrossing(moonElongation, 0, guess, 12.19075);
}

const SEASONS = [
  { angle: 0, event: 'Equinozio di primavera', season: 'Primavera' },
  { angle: 90, event: "Solstizio d'estate", season: 'Estate' },
  { angle: 180, event: "Equinozio d'autunno", season: 'Autunno' },
  { angle: 270, event: "Solstizio d'inverno", season: 'Inverno' },
];

// Stagione astronomica nell'emisfero nord e prossimo equinozio/solstizio
export function season(date) {
  const lon = sunPosition(date).lon;
  const current = SEASONS[Math.floor(lon / 90)];
  const next = SEASONS[(Math.floor(lon / 90) + 1) % 4];
  const sunLon = (d) => sunPosition(d).lon;
  const nextDate = nextAngleCrossing(sunLon, next.angle, date, 0.98565);
  // Le stagioni durano meno di 95 giorni: partendo da 95 giorni prima si trova l'inizio di quella in corso
  const startDate = nextAngleCrossing(sunLon, current.angle, new Date(date.getTime() - 95 * DAY_MS), 0.98565);
  return { name: current.season, nextEvent: next.event, nextDate, startDate };
}

// Equinozi e solstizi di un anno solare (per il planetario)
export function seasonMarkers(year) {
  const start = new Date(Date.UTC(year, 0, 1));
  return SEASONS.map((s) => ({
    ...s,
    date: nextAngleCrossing((d) => sunPosition(d).lon, s.angle, start, 0.98565),
  }));
}

// Altezza del Sole sull'orizzonte (gradi) per un osservatore
export function sunAltitude(date, latDeg, lonDeg) {
  const sun = sunPosition(date);
  const H = gmst(date) + lonDeg - sun.ra;
  return Math.asin(sin(latDeg) * sin(sun.dec) + cos(latDeg) * cos(sun.dec) * cos(H)) * DEG;
}

// Alba, mezzogiorno solare e tramonto del giorno civile locale che contiene `date`.
// -0,833° tiene conto della rifrazione e del semidiametro del Sole (convenzione standard).
export function sunTimes(date, latDeg, lonDeg) {
  const midnight = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  const end = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime();
  const h0 = -0.833;
  const f = (t) => sunAltitude(new Date(t), latDeg, lonDeg) - h0;
  const step = 10 * 60000;
  let sunrise = null;
  let sunset = null;
  let noon = midnight;
  let best = -Infinity;
  for (let t = midnight; t < end; t += step) {
    const a = f(t);
    const b = f(t + step);
    if (a + h0 > best) { best = a + h0; noon = t; }
    if (a < 0 && b >= 0) sunrise = bisect(f, t, t + step);
    if (a >= 0 && b < 0) sunset = bisect(f, t, t + step);
  }
  noon = goldenMax((t) => f(t), noon - step, noon + step);
  return {
    sunrise: sunrise && new Date(sunrise),
    noon: new Date(noon),
    sunset: sunset && new Date(sunset),
    dayLengthMs: sunrise && sunset ? sunset - sunrise : null,
  };
}

function bisect(f, lo, hi) {
  for (let i = 0; i < 30; i++) {
    const mid = (lo + hi) / 2;
    if ((f(lo) < 0) === (f(mid) < 0)) lo = mid; else hi = mid;
  }
  return (lo + hi) / 2;
}

function goldenMax(f, lo, hi) {
  const g = (Math.sqrt(5) - 1) / 2;
  for (let i = 0; i < 40; i++) {
    const a = hi - g * (hi - lo);
    const b = lo + g * (hi - lo);
    if (f(a) > f(b)) hi = b; else lo = a;
  }
  return (lo + hi) / 2;
}
