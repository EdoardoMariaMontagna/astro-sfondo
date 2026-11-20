// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Edoardo Maria Montagna

import * as A from './astro.js';

const DAY_MS = 86400000;
const fmt = (opts) => new Intl.DateTimeFormat('it-IT', opts);
const fClock = fmt({ hour: '2-digit', minute: '2-digit' });
const fDate = fmt({ weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
const fHM = fmt({ hour: '2-digit', minute: '2-digit' });
const fEvent = fmt({ weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
const fLongEvent = fmt({ weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' });
const num = (x, digits = 1) =>
  x.toLocaleString('it-IT', { minimumFractionDigits: digits, maximumFractionDigits: digits });

const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
const calendarDaysBetween = (a, b) => Math.round((startOfDay(b) - startOfDay(a)) / DAY_MS);

function dayOfYear(d) {
  return calendarDaysBetween(new Date(d.getFullYear(), 0, 1), d) + 1;
}

function isoWeek(d) {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const dow = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - dow);
  const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  return Math.ceil(((t - yearStart) / DAY_MS + 1) / 7);
}

const inDays = (n) => (n === 0 ? 'oggi' : n === 1 ? 'domani' : `tra ${n} giorni`);
const capitalize = (s) => s.charAt(0).toUpperCase() + s.slice(1);

function formatDuration(ms) {
  const min = Math.round(ms / 60000);
  return `${Math.floor(min / 60)} h ${String(min % 60).padStart(2, '0')} min`;
}

// Disco lunare con la parte illuminata vista dall'emisfero nord
export function drawMoonPhase(canvas, elongation) {
  const dpr = window.devicePixelRatio || 1;
  const size = canvas.clientWidth;
  canvas.width = canvas.height = Math.round(size * dpr);
  const g = canvas.getContext('2d');
  g.setTransform(dpr, 0, 0, dpr, 0, 0);
  const r = size / 2 - 1.5;
  const c = size / 2;
  g.clearRect(0, 0, size, size);
  g.fillStyle = '#1a1d26';
  g.beginPath();
  g.arc(c, c, r, 0, Math.PI * 2);
  g.fill();

  const e = (elongation * Math.PI) / 180;
  const waxing = elongation < 180;
  g.save();
  g.translate(c, c);
  if (!waxing) g.scale(-1, 1); // in fase calante la parte illuminata è a sinistra
  const lit = g.createRadialGradient(-r * 0.3, -r * 0.3, r * 0.1, 0, 0, r);
  lit.addColorStop(0, '#f4f1e8');
  lit.addColorStop(1, '#c9c4b6');
  g.fillStyle = lit;
  g.beginPath();
  g.arc(0, 0, r, -Math.PI / 2, Math.PI / 2, false);
  const k = Math.cos(e);
  g.ellipse(0, 0, Math.abs(r * k), r, 0, Math.PI / 2, -Math.PI / 2, k > 0);
  g.fill();
  g.restore();
}

export function createPanel(root, location) {
  root.innerHTML = `
    <div class="clock" data-k="clock"></div>
    <div class="date" data-k="date"></div>
    <div class="meta" data-k="meta"></div>

    <section>
      <h2>Stagione</h2>
      <p class="big" data-k="season"></p>
      <div class="bar"><span data-k="seasonBar"></span></div>
      <p data-k="seasonNext"></p>
      <p class="dim" data-k="seasonWhen"></p>
      <p class="dim" data-k="tilt"></p>
    </section>

    <section>
      <h2>Sole · ${location.name}</h2>
      <dl>
        <dt>Alba</dt><dd data-k="sunrise"></dd>
        <dt>Mezzogiorno</dt><dd data-k="noon"></dd>
        <dt>Tramonto</dt><dd data-k="sunset"></dd>
        <dt>Durata del giorno</dt><dd data-k="dayLength"></dd>
      </dl>
    </section>

    <section>
      <h2>Luna</h2>
      <div class="moon">
        <canvas data-k="moonIcon"></canvas>
        <div>
          <p class="big" data-k="moonName"></p>
          <p data-k="moonDetail"></p>
        </div>
      </div>
      <ul data-k="moonNext"></ul>
    </section>`;

  const el = {};
  root.querySelectorAll('[data-k]').forEach((n) => { el[n.dataset.k] = n; });
  const set = (k, text) => { if (el[k].textContent !== text) el[k].textContent = text; };

  let lastMinute = null;
  let lastDay = null;

  return {
    update(t) {
      const minute = Math.floor(t.getTime() / 60000);
      if (minute === lastMinute) return;
      lastMinute = minute;

      set('clock', fClock.format(t));
      set('date', capitalize(fDate.format(t)));
      set('meta', `giorno ${dayOfYear(t)} dell'anno · settimana ${isoWeek(t)}`);

      const s = A.season(t);
      set('season', s.name);
      const progress = (t - s.startDate) / (s.nextDate - s.startDate);
      el.seasonBar.style.width = `${(progress * 100).toFixed(1)}%`;
      set('seasonNext', `${s.nextEvent} ${inDays(calendarDaysBetween(t, s.nextDate))}`);
      set('seasonWhen', capitalize(fLongEvent.format(s.nextDate)));
      const sun = A.sunPosition(t);
      const hemi = sun.dec >= 0 ? 'N' : 'S';
      set('tilt', `Sole allo zenit a ${num(Math.abs(sun.dec))}° ${hemi} · asse inclinato di ${num(A.obliquity(t), 2)}°`);

      const dayKey = startOfDay(t).getTime();
      if (dayKey !== lastDay) {
        lastDay = dayKey;
        const st = A.sunTimes(t, location.lat, location.lon);
        set('sunrise', st.sunrise ? fHM.format(st.sunrise) : '—');
        set('noon', fHM.format(st.noon));
        set('sunset', st.sunset ? fHM.format(st.sunset) : '—');
        set('dayLength', st.dayLengthMs ? formatDuration(st.dayLengthMs) : '—');
      }

      const ph = A.moonPhase(t);
      const age = (t - A.lastNewMoon(t)) / DAY_MS;
      set('moonName', ph.name);
      set('moonDetail', `illuminata al ${Math.round(ph.illumination * 100)}% · età ${num(age)} giorni`);
      drawMoonPhase(el.moonIcon, ph.elongation);
      const next = A.nextMoonPhases(t).slice(0, 2)
        .map((p) => `<li><span>${p.name}</span><span>${fEvent.format(p.date)}</span></li>`).join('');
      if (el.moonNext.innerHTML !== next) el.moonNext.innerHTML = next;
    },
  };
}
