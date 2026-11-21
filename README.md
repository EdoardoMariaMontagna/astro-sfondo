<img src="app/AppIcon-1024.png" alt="Icona di Astro Sfondo: sistema solare stilizzato" width="128" align="right">

# Astro Sfondo

Sfondo animato per macOS che mostra la Terra, la Luna e le stagioni **come sono in questo
istante**: una sorta di calendario perpetuo astronomico sulla Scrivania.

![Astro Sfondo il 21 dicembre 2026 alle 17:00: solstizio d'inverno, asse terrestre inclinato lontano dal Sole, Europa già al buio con le luci delle città, Luna gibbosa crescente](docs/anteprima.jpg)

*Il solstizio d'inverno 2026 alle 17:00 (ora italiana), con la località predefinita Greenwich.*

> **English summary.** A live macOS desktop wallpaper showing the Earth as it is right now:
> real rotation, day/night terminator with city lights, axial tilt relative to the Sun through
> the seasons, the Moon at its true position and phase, a heliocentric orrery and an almanac
> panel (sunrise/sunset, season, moon phases). Native Swift wrapper around a WebGL page
> (three.js), with low-precision ephemerides validated against PyEphem and NASA public-domain
> imagery. Download the `.dmg` from Releases or build from source. UI is in Italian;
> translations and contributions are welcome. License: AGPL-3.0-only.

## Cosa mostra

- **La Terra in tempo reale**: rotazione secondo il tempo siderale, notte con le luci delle
  città, asse inclinato di 23,44° che si volge verso il Sole o lontano da esso con le stagioni,
  e un puntino sul luogo scelto.
- **La Luna** nella posizione reale sulla sua orbita, con la faccia visibile rivolta alla Terra.
- **Un pannello-calendario**: ora, data, giorno dell'anno e settimana; stagione con avanzamento
  e prossimo equinozio o solstizio; alba, mezzogiorno, tramonto e durata del giorno; fase,
  illuminazione ed età della Luna con le fasi successive.
- **Un planetario** visto dal polo nord dell'eclittica: orbita terrestre con mesi, equinozi,
  solstizi, l'asse e la Luna.
- **Animazioni d'ambiente leggere**: le stelle brillano, le nuvole scorrono lentamente.

## Precisione

`web/astro.js` usa effemeridi a bassa precisione, confrontate con PyEphem su più date:

| Grandezza | Scarto massimo |
|---|---|
| Posizione del Sole | 0,003° |
| Posizione della Luna | 0,04° |
| Rotazione terrestre (tempo siderale) | 1,2 s |
| Fasi lunari | 9 min |
| Equinozi e solstizi | 7 min |
| Alba e tramonto | 2 s |

Elementi decorativi e non reali: le nuvole sono generate al computer (non sono quelle di oggi) e
la distanza della Luna è ridotta per farla stare sullo schermo.

## Installazione

Serve macOS 14 o successivo, su Mac Apple Silicon o Intel.

### Dal file .dmg (consigliata)

1. Scarica `AstroSfondo-<versione>.dmg` dalla pagina
   [Releases](https://github.com/EdoardoMariaMontagna/astro-sfondo/releases).
2. Aprilo e trascina **Astro Sfondo** in **Applicazioni**.
3. Apri Astro Sfondo da Applicazioni. La prima volta macOS lo blocca, perché l'app non è firmata
   con un certificato Apple a pagamento: vai in **Impostazioni di Sistema → Privacy e sicurezza**,
   scorri fino al messaggio su Astro Sfondo e scegli **Apri comunque**. Serve una volta sola.
4. Lo sfondo parte e da allora si avvia a ogni accesso (lo si disattiva dal menu).

Per disinstallare: dal menu del mappamondo togli la spunta da **Apri all'accesso**, scegli
**Esci da Astro Sfondo** (rimette lo sfondo di prima) e sposta l'app nel Cestino.

### Dai sorgenti

Servono anche i Command Line Tools di Apple (`xcode-select --install`).

```bash
git clone https://github.com/EdoardoMariaMontagna/astro-sfondo.git
cd astro-sfondo
./install.sh
```

`install.sh` compila l'app in `/Applications/Astro Sfondo.app` (serve un utente amministratore) e
attiva due avvii automatici: l'app all'accesso, che launchd riavvia se si chiude per errore, e
una verifica giornaliera che controlla che tutto funzioni e ripara ricompilando dai sorgenti.
Compilata sul proprio Mac, l'app non ha il marchio di quarantena e Gatekeeper non chiede nulla.

Per disinstallare, rimettendo lo sfondo precedente: `./uninstall.sh`.

## Uso e personalizzazione

- L'icona del **mappamondo** nella barra dei menu permette di ricaricare lo sfondo, mettere in
  pausa le animazioni, scegliere se aprirlo all'accesso o uscire. Uscendo dal menu si rimette lo
  sfondo originale. Nell'installazione dai sorgenti mostra anche l'esito dell'ultima verifica.
- Aprire **Astro Sfondo** da Applicazioni o dal Launchpad quando è già attivo ne apre il menu:
  non partono mai due sfondi sovrapposti.
- **Personalizza luogo e impostazioni…** nel menu apre il file delle impostazioni personali, con
  solo le voci da cambiare rispetto a `web/config.js` (luogo, fotogrammi al secondo, distanza della
  Luna). Ad esempio:
  ```js
  export const CONFIG = { location: { name: 'Napoli', lat: 40.8518, lon: 14.2681 } };
  ```
  Dopo averlo salvato, scegli **Ricarica lo sfondo**. Il luogo predefinito è Greenwich e gli
  orari si mostrano nel fuso orario del Mac. Il file è `web/config.local.js` (escluso da git)
  nell'installazione dai sorgenti, `~/Library/Application Support/AstroSfondo/config.local.js`
  in quella dal `.dmg`.
- Per provare altre date:
  `"/Applications/Astro Sfondo.app/Contents/MacOS/AstroSfondo" --query "?t=2027-06-21T12:00:00Z&speed=3600"`

## Come funziona

```
app/main.swift   finestra al livello della Scrivania (sotto le icone, su tutti gli Spaces)
                 con una WKWebView; serve web/ con lo schema astro:// perché WebGL richiede
                 texture della stessa origine; ogni 3 minuti e a ogni cambio di Scrivania
                 imposta come sfondo di sistema un'istantanea della scena, che macOS mostra
                 mentre si spostano i widget, in Mission Control e nella schermata di blocco
app/icona.swift  disegna l'icona (swift app/icona.swift rigenera app/AppIcon.icns)
web/astro.js     effemeridi (Sole, Luna, fasi, stagioni, alba e tramonto)
web/main.js      scena three.js: eclittica orizzontale, scena che ruota con il Sole
                 (illuminazione sempre da sinistra), asse inclinato, rotazione siderale
web/nuvole.js    nuvole generate all'avvio con rumore frattale 3D, distribuite per latitudine
web/panel.js     pannello-calendario
web/orrery.js    planetario 2D
build.sh         compila e installa l'app per l'uso dai sorgenti
release.sh       crea il .dmg universale (Apple Silicon e Intel) per le Releases
verifica.sh      verifica automatica (all'accesso e alle 13): app attiva, firma, blocchi di
                 Gatekeeper, scena davvero disegnata (luminosità del globo in un'istantanea),
                 sfondo di sistema; ripara riavviando o ricompilando dai sorgenti locali;
                 segnala nuove versioni di three.js senza installarle
```

L'app non fa connessioni di rete. Consumo misurato su un M1 Pro: circa il 13% di un core e
340 MB di memoria, con pausa automatica a schermo spento o Scrivania coperta.

Le immagini di Terra e Luna sono della NASA, di pubblico dominio: fonti e crediti in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Contribuire

Idee e richieste di modifica sono benvenute, per esempio:

- traduzione dell'interfaccia;
- stelle e costellazioni reali da un catalogo;
- nuvole reali da una fonte di pubblico dominio;
- aggiornamento a una versione più recente di three.js.

## Licenza

Copyright (C) 2026 Edoardo Maria Montagna

Questo programma è software libero: puoi ridistribuirlo e/o modificarlo secondo i termini della
GNU Affero General Public License, versione 3 (solo la versione 3), come pubblicata dalla Free
Software Foundation. È distribuito nella speranza che sia utile, ma SENZA ALCUNA GARANZIA. Il
testo completo è in [LICENSE](LICENSE).

SPDX-License-Identifier: `AGPL-3.0-only`
