// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Edoardo Maria Montagna

import * as A from './astro.js';

// Planetario visto dal polo nord dell'eclittica: la Terra gira in senso antiorario intorno al Sole.
// Posizione sullo schermo di una longitudine eclittica: x = cos λ, y = -sin λ.
const MONTHS = ['G', 'F', 'M', 'A', 'M', 'G', 'L', 'A', 'S', 'O', 'N', 'D'];
const SHORT_EVENT = {
  'Equinozio di primavera': 'equinozio',
  "Solstizio d'estate": 'solstizio',
  "Equinozio d'autunno": 'equinozio',
  "Solstizio d'inverno": 'solstizio',
};
const fDay = new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'short' });
const RAD = Math.PI / 180;

// Longitudine eliocentrica della Terra = longitudine geocentrica del Sole + 180°
const earthLon = (date) => A.norm360(A.sunPosition(date).lon + 180);

export function drawOrrery(canvas, t) {
  const dpr = window.devicePixelRatio || 1;
  const size = canvas.clientWidth;
  if (canvas.width !== Math.round(size * dpr)) canvas.width = canvas.height = Math.round(size * dpr);
  const g = canvas.getContext('2d');
  g.setTransform(dpr, 0, 0, dpr, 0, 0);
  g.clearRect(0, 0, size, size);

  const c = size / 2;
  const R = size * 0.36;
  const at = (lonDeg, radius) => [c + Math.cos(lonDeg * RAD) * radius, c - Math.sin(lonDeg * RAD) * radius];

  // Sole
  const glow = g.createRadialGradient(c, c, 0, c, c, size * 0.13);
  glow.addColorStop(0, 'rgba(255, 226, 160, 0.95)');
  glow.addColorStop(0.18, 'rgba(255, 196, 110, 0.55)');
  glow.addColorStop(1, 'rgba(255, 170, 80, 0)');
  g.fillStyle = glow;
  g.beginPath();
  g.arc(c, c, size * 0.13, 0, Math.PI * 2);
  g.fill();

  // Orbita, e il tratto già percorso dall'inizio dell'anno
  g.strokeStyle = 'rgba(170, 190, 230, 0.22)';
  g.lineWidth = 1;
  g.beginPath();
  g.arc(c, c, R, 0, Math.PI * 2);
  g.stroke();
  const yearStartLon = earthLon(new Date(t.getFullYear(), 0, 1));
  const nowLon = earthLon(t);
  g.strokeStyle = 'rgba(170, 200, 255, 0.55)';
  g.lineWidth = 1.6;
  g.beginPath();
  g.arc(c, c, R, -yearStartLon * RAD, -nowLon * RAD, true);
  g.stroke();

  // Iniziali dei mesi, poste dove si trova la Terra il primo giorno di ciascun mese
  g.font = `500 ${Math.round(size * 0.036)}px -apple-system, system-ui, sans-serif`;
  g.textAlign = 'center';
  g.textBaseline = 'middle';
  MONTHS.forEach((label, m) => {
    const lon = earthLon(new Date(t.getFullYear(), m, 1));
    const [tx, ty] = at(lon, R - size * 0.035);
    const [ox, oy] = at(lon, R + size * 0.075);
    g.strokeStyle = 'rgba(170, 190, 230, 0.35)';
    g.beginPath();
    g.moveTo(tx, ty);
    g.lineTo(...at(lon, R));
    g.stroke();
    g.fillStyle = m === t.getMonth() ? 'rgba(235, 240, 255, 0.95)' : 'rgba(200, 210, 235, 0.5)';
    g.fillText(label, ox, oy);
  });

  // Equinozi e solstizi
  g.font = `${Math.round(size * 0.03)}px -apple-system, system-ui, sans-serif`;
  A.seasonMarkers(t.getFullYear()).forEach((s) => {
    const lon = earthLon(s.date);
    const [x, y] = at(lon, R);
    g.fillStyle = 'rgba(255, 214, 150, 0.85)';
    g.beginPath();
    g.arc(x, y, 2.2, 0, Math.PI * 2);
    g.fill();
    const [lx, ly] = at(lon, R - size * 0.12);
    g.fillStyle = 'rgba(255, 220, 170, 0.45)';
    g.fillText(SHORT_EVENT[s.event], lx, ly - size * 0.018);
    g.fillStyle = 'rgba(255, 220, 170, 0.7)';
    g.fillText(fDay.format(s.date), lx, ly + size * 0.018);
  });

  // Terra: metà illuminata rivolta al Sole
  const [ex, ey] = at(nowLon, R);
  const er = size * 0.028;
  const toSun = Math.atan2(c - ey, c - ex);
  g.fillStyle = '#0d1a33';
  g.beginPath();
  g.arc(ex, ey, er, 0, Math.PI * 2);
  g.fill();
  g.fillStyle = '#7fb2ff';
  g.beginPath();
  g.arc(ex, ey, er, toSun - Math.PI / 2, toSun + Math.PI / 2);
  g.fill();

  // Asse terrestre: la proiezione del polo nord sull'eclittica punta sempre verso λ = 90°
  // (in alto): in giugno è rivolta al Sole, in dicembre dalla parte opposta
  const len = er + size * 0.045;
  g.strokeStyle = 'rgba(220, 230, 255, 0.75)';
  g.lineWidth = 1.2;
  g.beginPath();
  g.moveTo(ex, ey + len * 0.6);
  g.lineTo(ex, ey - len);
  g.stroke();
  g.fillStyle = 'rgba(235, 240, 255, 0.95)';
  g.beginPath();
  g.arc(ex, ey - len, 1.8, 0, Math.PI * 2);
  g.fill();

  // Luna intorno alla Terra (distanza non in scala)
  const moon = A.moonPosition(t);
  const mr = size * 0.075;
  const mx = ex + Math.cos(moon.lon * RAD) * mr;
  const my = ey - Math.sin(moon.lon * RAD) * mr;
  g.strokeStyle = 'rgba(200, 210, 235, 0.18)';
  g.lineWidth = 1;
  g.beginPath();
  g.arc(ex, ey, mr, 0, Math.PI * 2);
  g.stroke();
  const moonToSun = Math.atan2(c - my, c - mx);
  g.fillStyle = '#2a2c33';
  g.beginPath();
  g.arc(mx, my, er * 0.45, 0, Math.PI * 2);
  g.fill();
  g.fillStyle = '#e8e4da';
  g.beginPath();
  g.arc(mx, my, er * 0.45, moonToSun - Math.PI / 2, moonToSun + Math.PI / 2);
  g.fill();

  g.font = `500 ${Math.round(size * 0.034)}px -apple-system, system-ui, sans-serif`;
  g.fillStyle = 'rgba(200, 210, 235, 0.55)';
  g.fillText('Orbita terrestre vista da nord', c, size - size * 0.02);
}
