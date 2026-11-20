#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Edoardo Maria Montagna
#
# Verifica automatica di Astro Sfondo (avviata da launchd all'accesso e ogni giorno alle 13).
# Controlla che l'app funzioni, la ripara riavviandola o ricompilandola dai sorgenti locali
# e segnala, senza installarle, le nuove versioni di three.js. Non scarica né esegue codice.
# Esito: ~/Library/Application Support/AstroSfondo/stato.txt (letto dal menu dell'app)
# Registro: ~/Library/Logs/AstroSfondo/verifica.log
set -uo pipefail
cd "${0:A:h}"

APP="/Applications/Astro Sfondo.app"
BIN="$APP/Contents/MacOS/AstroSfondo"
SUPPORT="$HOME/Library/Application Support/AstroSfondo"
STATE="$SUPPORT/verifica-stato"
STATUS="$SUPPORT/stato.txt"
LOG_DIR="$HOME/Library/Logs/AstroSfondo"
LOG="$LOG_DIR/verifica.log"
AGENT="gui/$(id -u)/local.astrosfondo"
mkdir -p "$SUPPORT" "$LOG_DIR"

log() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }
typeset -a errors warnings infos notices
needs_repair=0
user_quit=0

# Stato persistente tra un'esecuzione e l'altra (chiave=valore)
typeset -A st
[[ -f $STATE ]] && while IFS='=' read -r k v; do [[ -n $k ]] && st[$k]=$v; done < "$STATE"
save_state() {
  : > "$STATE.tmp"
  for k v in "${(@kv)st}"; do print -r -- "$k=$v" >> "$STATE.tmp"; done
  mv "$STATE.tmp" "$STATE"
}

agent_field() { launchctl print "$AGENT" 2>/dev/null | awk -F' = ' -v k="$1" '$1 ~ "^\t" k "$" {print $2; exit}'; }
app_pid() { agent_field pid; }

# Secondi di vita di un processo: il ps di macOS dà solo "etime" nel formato [[gg-]hh:]mm:ss
process_age() {
  local e=$(ps -o etime= -p "$1" 2>/dev/null | tr -d ' ')
  [[ -z $e ]] && return 1
  local days=0
  [[ $e == *-* ]] && { days=${e%%-*}; e=${e#*-}; }
  local -a p=("${(@s/:/)e}")
  while (( ${#p} < 3 )); do p=(0 "${p[@]}"); done
  print $(( days * 86400 + 10#${p[1]} * 3600 + 10#${p[2]} * 60 + 10#${p[3]} ))
}

log "---- verifica avviata"

# All'accesso l'app è appena partita: le si lascia il tempo di caricare la scena
pid=$(app_pid)
if [[ -n $pid ]]; then
  age=$(process_age "$pid")
  [[ -n $age ]] && (( age < 60 )) && sleep $(( 60 - age ))
fi

# 1. Versione di macOS: gli aggiornamenti di sistema sono la causa più probabile di guasti
macos="$(sw_vers -productVersion) ($(sw_vers -buildVersion))"
if [[ -n ${st[macos]:-} && ${st[macos]} != "$macos" ]]; then
  infos+=("macOS aggiornato da ${st[macos]} a $macos: verifica completa eseguita")
  notices+=("macOS aggiornato a $macos")
fi
st[macos]=$macos

# 2. Avvio automatico e app in esecuzione
if ! launchctl print "$AGENT" >/dev/null 2>&1; then
  errors+=("L'avvio automatico non è attivo (manca local.astrosfondo)")
else
  state=$(agent_field state)
  last_exit=$(agent_field "last exit code")
  if [[ $state != running ]]; then
    if [[ $last_exit == 0 ]]; then
      user_quit=1
      infos+=("L'app è chiusa dal menu: non la riavvio")
    else
      log "app ferma (state=$state, uscita=$last_exit): riavvio"
      launchctl kickstart "$AGENT"
      sleep 20
      if [[ $(agent_field state) == running ]]; then
        warnings+=("L'app era ferma (codice $last_exit) ed è stata riavviata")
      else
        errors+=("L'app non riesce a partire (codice $last_exit)")
        needs_repair=1
      fi
    fi
  fi
fi

# 3. Firma dell'app
if ! codesign --verify --strict "$APP" >> "$LOG" 2>&1; then
  errors+=("La firma dell'app non è valida")
  needs_repair=1
fi

# 4. Blocchi di Gatekeeper dall'ultima verifica (al massimo 26 ore). Contano solo i rifiuti veri
# di syspolicyd (avviso mostrato o rifiuto registrato), non le righe "would not allow" del kernel:
# quelle compaiono anche quando un avvio si sovrappone a una reinstallazione, e poi l'app parte.
now=$(date +%s)
since=$(( ${st[lastrun]:-0} > now - 93600 ? ${st[lastrun]:-0} : now - 93600 ))
blocks=$(/usr/bin/log show --style compact --start "$(date -r $since '+%Y-%m-%d %H:%M:%S')" \
  --predicate 'process == "syspolicyd" AND eventMessage CONTAINS "local.astrosfondo" AND (eventMessage CONTAINS "Prompt shown" OR eventMessage CONTAINS "denial breadcrumb")' \
  2>/dev/null | grep -c '^20')
if (( blocks > 0 )); then
  errors+=("Gatekeeper ha rifiutato l'app $blocks volte")
  needs_repair=1
fi

# 5. Ricompilazione dai sorgenti locali, se serve e se gli strumenti ci sono
has_swiftc=0
xcrun --find swiftc >/dev/null 2>&1 && has_swiftc=1
(( has_swiftc )) || warnings+=("Mancano i Command Line Tools: in caso di guasto non potrei ricompilare (si reinstallano con: xcode-select --install)")
if (( needs_repair && has_swiftc && ! user_quit )); then
  log "riparazione: ricompilo l'app"
  if ./build.sh >> "$LOG" 2>&1; then
    sleep 20
    infos+=("App ricompilata e reinstallata automaticamente")
    notices+=("Astro Sfondo è stata ricompilata per correggere un guasto")
  else
    errors+=("Ricompilazione non riuscita: dettagli nel registro")
  fi
fi

# 6. La scena viene davvero disegnata? L'app salva un'istantanea, si misura il globo
if (( ! user_quit )) && pid=$(app_pid) && [[ -n $pid ]]; then
  check_render() {
    rm -f "$SUPPORT/verifica.jpg"
    kill -USR1 "$pid" 2>/dev/null
    for _ in {1..20}; do [[ -s "$SUPPORT/verifica.jpg" ]] && break; sleep 1; done
    [[ -s "$SUPPORT/verifica.jpg" ]] || { print -r -- "nessuna"; return; }
    "$BIN" --check-image "$SUPPORT/verifica.jpg" 2>/dev/null || print -r -- "illeggibile"
  }
  lum=$(check_render)
  log "luminosità del globo: $lum"
  if [[ $lum != <->.<-> ]] || (( lum < 0.05 )); then
    log "scena non disegnata: riavvio l'app e riprovo"
    launchctl kickstart -k "$AGENT"
    sleep 25
    pid=$(app_pid)
    lum=$(check_render)
    log "luminosità dopo il riavvio: $lum"
    if [[ $lum == <->.<-> ]] && (( lum >= 0.05 )); then
      warnings+=("La scena non veniva disegnata: risolto riavviando l'app")
    else
      errors+=("La scena 3D non viene disegnata (luminosità del globo: $lum)")
    fi
  fi

  # 7. Lo sfondo di sistema deve essere l'istantanea della scena
  wallpaper=$("$BIN" --print-wallpaper 2>/dev/null)
  if [[ $wallpaper != "$SUPPORT"/* ]]; then
    warnings+=("Lo sfondo di sistema non è quello di Astro Sfondo: $wallpaper")
  fi
fi

# 8. Nuove versioni di three.js: solo segnalazione, una volta a settimana
installed=$(<web/vendor/VERSION)
if (( now - ${st[threecheck]:-0} > 7 * 86400 )); then
  latest=$(curl -fsS --max-time 15 https://registry.npmjs.org/three/latest 2>>"$LOG" \
    | plutil -extract version raw -o - - 2>>"$LOG")
  if [[ -n $latest ]]; then
    st[threecheck]=$now
    st[threelatest]=$latest
  fi
fi
latest=${st[threelatest]:-}
if [[ -n $latest && $latest != "$installed" ]]; then
  infos+=("Disponibile three.js $latest (in uso $installed): non installata, da valutare insieme")
  if [[ ${st[threenotified]:-} != "$latest" ]]; then
    notices+=("Disponibile three.js $latest: non installata automaticamente")
    st[threenotified]=$latest
  fi
fi

# Esito
if (( ${#errors} )); then level=error; summary=${errors[1]}
elif (( ${#warnings} )); then level=warning; summary=${warnings[1]}
elif (( ${#infos} )); then level=info; summary="Tutto funziona · ${#infos} segnalazioni"
  (( ${#infos} == 1 )) && summary="Tutto funziona · 1 segnalazione"
else level=ok; summary="Tutto in ordine"
fi
{
  print -r -- "level=$level"
  print -r -- "time=$now"
  print -r -- "summary=$summary"
  for d in "${errors[@]}" "${warnings[@]}" "${infos[@]}"; do print -r -- "detail=$d"; done
} > "$STATUS.tmp" && mv "$STATUS.tmp" "$STATUS"

st[lastrun]=$now
save_state
log "esito: $level · $summary"
for d in "${errors[@]}" "${warnings[@]}" "${infos[@]}"; do log "  - $d"; done

# Notifica solo quando c'è qualcosa da sapere
if [[ $level == error || $level == warning ]]; then
  notices=("$summary" "${notices[@]}")
fi
if (( ${#notices} )); then
  msg=${(j:. :)notices}
  osascript -e "display notification \"${msg//\"/\'}\" with title \"Astro Sfondo\"" >/dev/null 2>&1
fi

# Il registro tiene le ultime 2000 righe
tail -n 2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
[[ $level == error ]] && exit 1 || exit 0
