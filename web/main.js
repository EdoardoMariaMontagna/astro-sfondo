// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Edoardo Maria Montagna

import * as THREE from './vendor/three.module.min.js';
import * as A from './astro.js';
import { CONFIG } from './config.js';
import { createPanel } from './panel.js';
import { drawOrrery } from './orrery.js';

const RAD = Math.PI / 180;

// Istante mostrato: quello reale, oppure ?t=2026-12-21T12:00:00Z&speed=600 per provare altre date
const params = new URLSearchParams(location.search);
const realStart = Date.now();
const simStart = params.has('t') ? Date.parse(params.get('t')) : realStart;
const speed = Number(params.get('speed') || 1);
const now = () => new Date(simStart + (Date.now() - realStart) * speed);

// ---------------------------------------------------------------- renderer e camera
const renderer = new THREE.WebGLRenderer({
  canvas: document.getElementById('globe'),
  antialias: true,
  powerPreference: 'low-power',
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 500);
// Mondo = piano dell'eclittica (Y = polo nord eclittico). La camera guarda la Terra dal lato
// della sera, 60° dalla direzione del Sole e 12° sopra l'eclittica: il Sole illumina da sinistra.
const CAM_DIST = 7.8;
const CAM_ELEV = 12 * RAD;
const CAM_AZ = -60 * RAD;
camera.position.set(
  Math.cos(CAM_ELEV) * Math.cos(CAM_AZ) * CAM_DIST,
  Math.sin(CAM_ELEV) * CAM_DIST,
  Math.cos(CAM_ELEV) * Math.sin(CAM_AZ) * CAM_DIST,
);
camera.lookAt(0, 0, 0);

const SUN_DIR = new THREE.Vector3(1, 0, 0); // costante: è la scena a ruotare con il Sole

// ---------------------------------------------------------------- texture
const loader = new THREE.TextureLoader();
const maxAniso = renderer.capabilities.getMaxAnisotropy();
function texture(file, color = true) {
  const t = loader.load(`textures/${file}`);
  if (color) t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = maxAniso;
  return t;
}

// ---------------------------------------------------------------- shader comuni
const worldVertex = /* glsl */ `
  varying vec2 vUv;
  varying vec3 vNormalW;
  varying vec3 vPosW;
  void main() {
    vUv = uv;
    vNormalW = normalize(mat3(modelMatrix) * normal);
    vec4 wp = modelMatrix * vec4(position, 1.0);
    vPosW = wp.xyz;
    gl_Position = projectionMatrix * viewMatrix * wp;
  }`;

const outputChunks = `
  #include <tonemapping_fragment>
  #include <colorspace_fragment>`;

// ---------------------------------------------------------------- gerarchia
// sunRoot ruota di -longitudine del Sole: in questo modo il Sole resta sempre lungo +X
const sunRoot = new THREE.Group();
scene.add(sunRoot);
const earthTilt = new THREE.Group(); // inclinazione dell'asse (obliquità)
sunRoot.add(earthTilt);
const earthSpin = new THREE.Group(); // rotazione diurna (tempo siderale)
earthTilt.add(earthSpin);

// Terra: giorno, notte con luci delle città, riflesso degli oceani, crepuscolo
const earth = new THREE.Mesh(
  new THREE.SphereGeometry(1, 160, 80),
  new THREE.ShaderMaterial({
    uniforms: {
      dayMap: { value: texture('earth_atmos_2048.jpg') },
      nightMap: { value: texture('earth_lights_2048.png') },
      specMap: { value: texture('earth_specular_2048.jpg', false) },
      sunDir: { value: SUN_DIR },
    },
    vertexShader: worldVertex,
    fragmentShader: /* glsl */ `
      uniform sampler2D dayMap, nightMap, specMap;
      uniform vec3 sunDir;
      varying vec2 vUv;
      varying vec3 vNormalW;
      varying vec3 vPosW;
      void main() {
        vec3 n = normalize(vNormalW);
        vec3 v = normalize(cameraPosition - vPosW);
        float ndl = dot(n, sunDir);
        float dayAmt = smoothstep(-0.06, 0.14, ndl);
        vec3 day = texture2D(dayMap, vUv).rgb * (0.012 + 1.15 * max(ndl, 0.0));
        vec3 h = normalize(sunDir + v);
        float nh = max(dot(n, h), 0.0);
        vec3 spec = vec3(1.0, 0.93, 0.8) * texture2D(specMap, vUv).r * dayAmt
                  * (pow(nh, 90.0) * 0.16 + pow(nh, 14.0) * 0.025);
        vec3 lights = texture2D(nightMap, vUv).rgb * vec3(1.0, 0.82, 0.55)
                    * (1.0 - smoothstep(-0.14, 0.04, ndl)) * 1.8;
        // valori lineari piccoli diventano ben visibili dopo la conversione sRGB: dosi minime
        float twilight = exp(-pow(ndl / 0.05, 2.0));
        float rim = pow(1.0 - max(dot(n, v), 0.0), 3.0);
        vec3 col = day + spec + lights
                 + vec3(0.95, 0.45, 0.22) * twilight * 0.006
                 + vec3(0.3, 0.55, 1.0) * rim * 0.22 * smoothstep(-0.2, 0.4, ndl);
        gl_FragColor = vec4(col, 1.0);
        ${outputChunks}
      }`,
  }),
);
earthSpin.add(earth);

// Nuvole: strato decorativo che deriva lentamente sopra la superficie
const clouds = new THREE.Mesh(
  new THREE.SphereGeometry(1.007, 128, 64),
  new THREE.ShaderMaterial({
    uniforms: { cloudMap: { value: texture('earth_clouds_1024.png', false) }, sunDir: { value: SUN_DIR } },
    vertexShader: worldVertex,
    fragmentShader: /* glsl */ `
      uniform sampler2D cloudMap;
      uniform vec3 sunDir;
      varying vec2 vUv;
      varying vec3 vNormalW;
      void main() {
        float a = texture2D(cloudMap, vUv).a; // l'immagine è tutta bianca: la densità è nell'alfa
        float ndl = dot(normalize(vNormalW), sunDir);
        vec3 col = vec3(1.0) * (0.015 + 0.95 * max(ndl, 0.0));
        gl_FragColor = vec4(col, a * 0.7);
        ${outputChunks}
      }`,
    transparent: true,
    depthWrite: false,
  }),
);
earthSpin.add(clouds);

// Asse di rotazione: rende visibile l'inclinazione rispetto al Sole
const axis = new THREE.Line(
  new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(0, -1.32, 0), new THREE.Vector3(0, 1.32, 0)]),
  new THREE.LineBasicMaterial({ color: 0xc8d6ff, transparent: true, opacity: 0.35 }),
);
earthTilt.add(axis);

// Atmosfera: alone azzurro sul bordo del disco, solo dal lato illuminato
const atmosphere = new THREE.Mesh(
  new THREE.SphereGeometry(1.07, 96, 48),
  new THREE.ShaderMaterial({
    uniforms: { sunDir: { value: SUN_DIR } },
    vertexShader: worldVertex,
    fragmentShader: /* glsl */ `
      uniform vec3 sunDir;
      varying vec3 vPosW;
      void main() {
        vec3 r = normalize(vPosW - cameraPosition);
        vec3 closest = cameraPosition + r * dot(-cameraPosition, r);
        float b = length(closest);
        float glow = smoothstep(1.07, 1.0, b) * smoothstep(0.96, 1.0, b);
        float lit = smoothstep(-0.35, 0.45, dot(normalize(closest), sunDir));
        gl_FragColor = vec4(vec3(0.32, 0.58, 1.0) * glow * lit * 0.42, 1.0);
        ${outputChunks}
      }`,
    side: THREE.BackSide,
    blending: THREE.AdditiveBlending,
    transparent: true,
    depthWrite: false,
  }),
);
sunRoot.add(atmosphere);

// Puntini luminosi (stelle e luogo dell'utente) disegnati come dischi sfumati
function glowPoints(positions, sizes, colors, phases, twinkle) {
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geo.setAttribute('size', new THREE.Float32BufferAttribute(sizes, 1));
  geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  geo.setAttribute('phase', new THREE.Float32BufferAttribute(phases, 1));
  const mat = new THREE.ShaderMaterial({
    uniforms: { time: { value: 0 }, pixelRatio: { value: renderer.getPixelRatio() }, twinkle: { value: twinkle } },
    vertexShader: /* glsl */ `
      attribute float size;
      attribute float phase;
      attribute vec3 color;
      uniform float time, pixelRatio, twinkle;
      varying vec3 vColor;
      varying float vAlpha;
      void main() {
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        float speed = 0.5 + fract(phase * 7.31) * 1.6;
        vAlpha = 1.0 - twinkle * (0.5 + 0.5 * sin(time * speed + phase * 6.2832));
        vColor = color;
        gl_PointSize = size * pixelRatio;
      }`,
    fragmentShader: /* glsl */ `
      varying vec3 vColor;
      varying float vAlpha;
      void main() {
        float d = length(gl_PointCoord - 0.5);
        float a = smoothstep(0.5, 0.0, d);
        gl_FragColor = vec4(vColor, a * a * vAlpha);
        ${outputChunks}
      }`,
    transparent: true,
    depthWrite: false,
  });
  return new THREE.Points(geo, mat);
}

// Cielo: stelle casuali, più fitte lungo una fascia che ricorda la Via Lattea
function makeStars(count) {
  const pos = [], size = [], col = [], phase = [];
  const band = new THREE.Vector3(0.3, 0.85, 0.42).normalize(); // polo della "galassia"
  const v = new THREE.Vector3();
  let rand = 12345;
  const rnd = () => ((rand = (rand * 16807) % 2147483647) / 2147483647); // ripetibile
  for (let i = 0; i < count; i++) {
    do {
      v.set(rnd() * 2 - 1, rnd() * 2 - 1, rnd() * 2 - 1);
    } while (v.lengthSq() > 1 || v.lengthSq() < 0.01);
    v.normalize();
    if (i % 3 === 0 && Math.abs(v.dot(band)) > 0.18) { i--; continue; } // addensa la fascia
    v.multiplyScalar(120);
    pos.push(v.x, v.y, v.z);
    const m = Math.pow(rnd(), 6); // poche stelle brillanti, molte deboli
    size.push(1.6 + m * 5.5);
    const warm = rnd();
    const c = warm < 0.15 ? [1.0, 0.82, 0.65] : warm > 0.85 ? [0.7, 0.8, 1.0] : [0.92, 0.94, 1.0];
    const b = 0.35 + m * 0.65;
    col.push(c[0] * b, c[1] * b, c[2] * b);
    phase.push(rnd());
  }
  return glowPoints(pos, size, col, phase, 0.45);
}
const stars = makeStars(4200);
scene.add(stars);

// Il luogo dell'utente sulla superficie terrestre
function surfacePoint(latDeg, lonDeg, r) {
  const la = latDeg * RAD, lo = lonDeg * RAD;
  return new THREE.Vector3(Math.cos(la) * Math.cos(lo), Math.sin(la), -Math.cos(la) * Math.sin(lo)).multiplyScalar(r);
}
const home = surfacePoint(CONFIG.location.lat, CONFIG.location.lon, 1.004);
const homeMarker = glowPoints([home.x, home.y, home.z], [9], [1.0, 0.78, 0.42], [0], 0.0);
earthSpin.add(homeMarker);

// Luna, con la faccia visibile sempre rivolta verso la Terra
const moon = new THREE.Mesh(
  new THREE.SphereGeometry(0.273, 96, 48),
  new THREE.ShaderMaterial({
    uniforms: { moonMap: { value: texture('moon_1024.jpg') }, sunDir: { value: SUN_DIR } },
    vertexShader: worldVertex,
    fragmentShader: /* glsl */ `
      uniform sampler2D moonMap;
      uniform vec3 sunDir;
      varying vec2 vUv;
      varying vec3 vNormalW;
      void main() {
        float ndl = dot(normalize(vNormalW), sunDir);
        vec3 col = texture2D(moonMap, vUv).rgb * (0.012 + 1.1 * max(ndl, 0.0));
        gl_FragColor = vec4(col, 1.0);
        ${outputChunks}
      }`,
  }),
);
sunRoot.add(moon);

const ORBIT_SEGMENTS = 256;
const moonOrbit = new THREE.LineLoop(
  new THREE.BufferGeometry().setAttribute('position', new THREE.Float32BufferAttribute(new Float32Array(ORBIT_SEGMENTS * 3), 3)),
  new THREE.LineBasicMaterial({ color: 0x9fb4e0, transparent: true, opacity: 0.16, depthWrite: false }),
);
sunRoot.add(moonOrbit);

// Da coordinate eclittiche (gradi) alla direzione nella scena (X = equinozio, Y = polo eclittico)
function eclipticDir(lonDeg, latDeg, out = new THREE.Vector3()) {
  const l = lonDeg * RAD, b = latDeg * RAD;
  return out.set(Math.cos(b) * Math.cos(l), Math.sin(b), -Math.cos(b) * Math.sin(l));
}

function updateMoonOrbit(node, inclination) {
  const attr = moonOrbit.geometry.attributes.position;
  const N = node * RAD, i = inclination * RAD, R = CONFIG.moonDistance;
  for (let k = 0; k < ORBIT_SEGMENTS; k++) {
    const u = (k / ORBIT_SEGMENTS) * Math.PI * 2;
    const x = Math.cos(N) * Math.cos(u) - Math.sin(N) * Math.sin(u) * Math.cos(i);
    const y = Math.sin(N) * Math.cos(u) + Math.cos(N) * Math.sin(u) * Math.cos(i);
    const z = Math.sin(u) * Math.sin(i);
    attr.setXYZ(k, x * R, z * R, -y * R);
  }
  attr.needsUpdate = true;
}

// Sfondo: nero spaziale con un lieve bagliore caldo dal lato del Sole (a sinistra)
function makeBackground(w, h) {
  const c = document.createElement('canvas');
  c.width = 512;
  c.height = Math.round(512 * (h / w));
  const g = c.getContext('2d');
  g.fillStyle = '#02030a';
  g.fillRect(0, 0, c.width, c.height);
  const grad = g.createRadialGradient(-c.width * 0.08, c.height * 0.46, 0, -c.width * 0.08, c.height * 0.46, c.width * 0.75);
  grad.addColorStop(0, 'rgba(255, 196, 130, 0.16)');
  grad.addColorStop(0.35, 'rgba(255, 170, 110, 0.05)');
  grad.addColorStop(1, 'rgba(0, 0, 0, 0)');
  g.fillStyle = grad;
  g.fillRect(0, 0, c.width, c.height);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

// ---------------------------------------------------------------- aggiornamento
const moonDir = new THREE.Vector3();
const toEarth = new THREE.Vector3();
const X_AXIS = new THREE.Vector3(1, 0, 0);
const cloudStart = Date.now();

function updateScene(t) {
  const sun = A.sunPosition(t);
  const m = A.moonPosition(t);
  sunRoot.rotation.y = -sun.lon * RAD;
  earthTilt.rotation.x = -A.obliquity(t) * RAD;
  earthSpin.rotation.y = A.gmst(t) * RAD;
  clouds.rotation.y = ((Date.now() - cloudStart) / 60000) * CONFIG.cloudDriftDegPerMin * RAD;

  eclipticDir(m.lon, m.lat, moonDir);
  moon.position.copy(moonDir).multiplyScalar(CONFIG.moonDistance);
  // la texture ha il centro della faccia visibile lungo +X: la si orienta verso la Terra
  moon.quaternion.setFromUnitVectors(X_AXIS, toEarth.copy(moonDir).negate());
}

function resize() {
  const w = window.innerWidth, h = window.innerHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  // sposta il globo a destra, lasciando a sinistra lo spazio per pannello e planetario
  camera.setViewOffset(w, h, -w * 0.11, 0, w, h);
  camera.updateProjectionMatrix();
  if (scene.background) scene.background.dispose();
  scene.background = makeBackground(w, h);
  stars.material.uniforms.pixelRatio.value = renderer.getPixelRatio();
  homeMarker.material.uniforms.pixelRatio.value = renderer.getPixelRatio();
  slowUpdate(true);
}

// ---------------------------------------------------------------- pannello e planetario
const panel = createPanel(document.getElementById('panel'), CONFIG.location);
const orreryCanvas = document.getElementById('orrery');
let lastSlow = 0;
function slowUpdate(force = false) {
  const t = now();
  if (!force && Math.abs(t - lastSlow) < 30000) return;
  lastSlow = t.getTime();
  const m = A.moonPosition(t);
  updateMoonOrbit(m.node, m.inclination);
  drawOrrery(orreryCanvas, t);
}

// ---------------------------------------------------------------- ciclo di disegno
// In pausa le animazioni d'ambiente si fermano, ma Terra, Luna e orologio restano esatti:
// si ridisegna comunque ogni 30 secondi.
let paused = false;
let lastFrame = -Infinity;
let ambientTime = 0;
const clockStart = performance.now();

function frame(ts) {
  requestAnimationFrame(frame);
  const interval = paused ? 30000 : 1000 / CONFIG.fps;
  if (ts - lastFrame < interval) return;
  lastFrame = ts;
  const t = now();
  updateScene(t);
  if (!paused) ambientTime = (ts - clockStart) / 1000;
  stars.material.uniforms.time.value = ambientTime;
  renderer.render(scene, camera);
  panel.update(t);
  slowUpdate();
}

// Chiamata dall'app: pausa scelta dall'utente, schermo spento, finestra coperta
window.astroPause = (p) => {
  if (paused === p) return;
  paused = p;
  lastFrame = -Infinity; // ridisegna subito con l'ora corretta
  if (!p) slowUpdate(true);
};

window.addEventListener('resize', resize);
resize();
requestAnimationFrame(frame);
