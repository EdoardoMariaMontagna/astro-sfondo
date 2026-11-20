# Componenti di terzi

## three.js 0.170.0 — inclusa (`web/vendor/three.module.min.js`)

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

## Immagini di Terra e Luna — **non incluse**

`earth_atmos_2048.jpg`, `earth_specular_2048.jpg`, `earth_lights_2048.png`,
`earth_clouds_1024.png`, `moon_1024.jpg` provengono dalla cartella
`examples/textures/planets` del repository di three.js. Furono aggiunte nel 2011 senza
indicarne autore e licenza, e non è chiaro se la licenza MIT del repository le copra.
Per questo non vengono ridistribuite qui: `scarica-risorse.sh` le scarica dalla fonte originale
durante l'installazione.

Un buon contributo al progetto sarebbe sostituirle con immagini di pubblico dominio della NASA
(ad esempio *Blue Marble*, *Black Marble* e il *CGI Moon Kit*), che si potrebbero includere
direttamente nel repository.

## Algoritmi astronomici

Le formule di `web/astro.js` seguono *How to compute planetary positions* di Paul Schlyter,
comprese le perturbazioni lunari principali. Il codice è originale: dall'opera si riprendono
solo metodi e costanti numeriche.
