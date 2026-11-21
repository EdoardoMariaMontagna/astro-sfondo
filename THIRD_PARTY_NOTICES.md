# Componenti di terzi

## three.js 0.170.0 (`web/vendor/three.module.min.js`)

Licenza MIT, compatibile con la AGPL-3.0. Il file è distribuito senza modifiche, con la sua
intestazione originale.

```
The MIT License

Copyright © 2010-2024 three.js authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

## Immagini di Terra e Luna (`web/textures/`)

Tutte di pubblico dominio (immagini NASA). Sono state ridimensionate e, dove indicato, elaborate.

| File | Origine | Crediti |
|---|---|---|
| `terra_giorno.jpg` | *Blue Marble 2002*, [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Blue_Marble_2002.jpg) (da NASA Visible Earth) | NASA Goddard Space Flight Center, immagine di Reto Stöckli; miglioramenti di Robert Simmon; dati MODIS Land Group |
| `terra_oceani.jpg` | Maschera degli oceani ricavata da *Blue Marble 2002* | come sopra |
| `terra_notte.jpg` | *Earth at Night 2012* (Black Marble), [NASA SVS 30028](https://svs.gsfc.nasa.gov/30028); solo le luci, isolate dal fondo | NASA Earth Observatory e NASA's Scientific Visualization Studio, visualizzazione di Robert Simmon; dati Suomi NPP VIIRS |
| `luna.jpg` | *CGI Moon Kit*, [NASA SVS 4720](https://svs.gsfc.nasa.gov/4720) (`lroc_color_poles_2k.tif`) | NASA's Scientific Visualization Studio, Ernie Wright; scienziato Noah Petro; dati Lunar Reconnaissance Orbiter (LROC) |

Le nuvole non vengono da immagini: le genera `web/nuvole.js` all'avvio.

## Algoritmi astronomici

Le formule di `web/astro.js` seguono *How to compute planetary positions* di Paul Schlyter,
comprese le perturbazioni lunari principali. Il codice è originale: dall'opera si riprendono
solo metodi e costanti numeriche.
