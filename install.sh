#!/bin/sh
# Installiert LooperPilot (bis 3.0: LooperDisplay) auf dem Mac:
#   1. Remote Scripts in die Ableton User Library
#   2. LooperPilot.app nach /Applications (eine alte LooperDisplay.app wird ersetzt)
#   3. Vorlagen nach User Library/Templates (nur wenn noch keine gleichnamige da ist)
#   4. App starten
# Alles kommt aus dem Release-Zip: liegt install.sh im entpackten Zip, aus diesem
# Ordner, sonst laedt es das neueste Release aus dem privaten Repo LooperPilot/looper-pilot
# (nur fuer eingeladene Testleute). Dafuer braucht es die GitHub CLI: fehlt sie, laedt das Script
# die offizielle (github.com/cli/cli) nur fuer diesen Lauf; ohne Anmeldung startet es gh auth login.
#
# Per Terminal ohne Download (Testleute; beim ersten Mal Anmeldung bei GitHub im Browser):
#          curl -fsSL https://looperpilot.github.io/install.sh | sh
#
# Usage:   ./install.sh               everything, including MorningstarClips (Morningstar MC6 Pro)
#          ./install.sh --scripts     Remote Scripts only
#          ./install.sh --no-clips    without MorningstarClips
set -e

SCRIPTS_ONLY=""
CLIPS="yes"                     # MorningstarClips immer mit (ohne Rueckfrage); --no-clips laesst es weg
for arg in "$@"; do
  case "$arg" in
    --scripts) SCRIPTS_ONLY=1 ;;
    --with-clips) CLIPS=yes ;;   # alte Option, weiter erlaubt (ist jetzt Standard)
    --no-clips) CLIPS=no ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="LooperPilot/looper-pilot"
CLIPS_REPO="LooperPilot/morningstar-live-clips"
LIB="${LOOPER_LIB:-$HOME/Music/Ableton/User Library}"          # zum Testen umlenkbar
SCRIPTS_DEST="$LIB/Remote Scripts"
TEMPLATES_DEST="$LIB/Templates"
APP_DEST="${LOOPER_APP_DEST:-/Applications/LooperPilot.app}"
OLD_APP="${APP_DEST%/*}/LooperDisplay.app"                    # Name bis 3.0
TEMPLATE="LooperTemplateV1.6.als"
CLIPS_TEMPLATE="MorningStarTemplate.als"

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# Live liest Remote Scripts nur beim Start: laeuft es gerade, gelten sonst die alten weiter
live_hint() {
  if pgrep -xq Live 2>/dev/null; then
    printf '\n\033[1;33m%s\033[0m\n' "Ableton Live is running -- quit and restart it now, otherwise the OLD scripts stay active."
  fi
}

if [ "$(uname -s)" != "Darwin" ]; then
  echo "LooperPilot only runs on macOS."; exit 1
fi
if [ "$(uname -m)" != "arm64" ]; then
  echo "Note: the app is built for Macs with Apple silicon (M1 or newer)."
fi

TMP=""
CLIPS_TMP=""
GH_TMP=""
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; [ -n "$CLIPS_TMP" ] && rm -rf "$CLIPS_TMP"; [ -n "$GH_TMP" ] && rm -rf "$GH_TMP"; true; }
trap cleanup EXIT

# Terminal fuer Rueckfragen: auch bei "curl ... | sh" (dann ist stdin die Pipe)
has_tty() { [ -t 0 ] || { [ -r /dev/tty ] && (exec </dev/tty) 2>/dev/null; }; }

# GitHub CLI fuer die privaten Releases: vorhandene nehmen, sonst die offizielle von
# github.com/cli/cli nur fuer diesen Lauf laden; nicht angemeldet -> gh auth login (Browser).
# Setzt GH; Rueckgabe 1, wenn kein Zugang moeglich ist.
GH=""
GH_FALLBACK_VERSION="2.102.0"   # falls die GitHub-API nicht antwortet
gh_manual() {
  echo ""
  echo "  The GitHub CLI could not be downloaded automatically (slow or blocked connection?)."
  echo "  Install it once by hand, then run this command again:"
  echo "    1. open https://cli.github.com and click \"Download for Mac\" (installer .pkg)"
  echo "    2. double-click the downloaded file and follow the installer"
  echo "  (or with Homebrew:  brew install gh)"
  echo ""
}
need_gh() {
  [ -n "$GH" ] && return 0
  if command -v gh >/dev/null 2>&1; then
    GH="$(command -v gh)"
  else
    echo "  getting the GitHub CLI (for the private download) ..."
    GH_TMP="$(mktemp -d)"
    case "$(uname -m)" in arm64) ARCH=arm64 ;; *) ARCH=amd64 ;; esac
    # Jeder Schritt mit Zeitlimit und sichtbar -- vorher lief das lautlos und sah bei langsamer
    # Verbindung wie "haengt" aus (oder hing wirklich, curl hatte kein Limit).
    echo "  - looking up the latest version on github.com ..."
    GH_URL="$(curl -fsSL --connect-timeout 15 --max-time 60 https://api.github.com/repos/cli/cli/releases/latest \
      | grep -o "\"browser_download_url\": *\"[^\"]*macOS_$ARCH\.zip\"" | head -1 | sed 's/.*"\(http[^"]*\)"/\1/')"
    if [ -z "$GH_URL" ]; then
      # API nicht erreichbar oder Limit erreicht: bekannte Version direkt nehmen
      GH_URL="https://github.com/cli/cli/releases/download/v$GH_FALLBACK_VERSION/gh_${GH_FALLBACK_VERSION}_macOS_$ARCH.zip"
      echo "    (no answer -- using version $GH_FALLBACK_VERSION)"
    fi
    echo "  - downloading $(basename "$GH_URL") (about 15 MB) ..."
    if ! curl -fL --connect-timeout 15 --max-time 600 --retry 2 --progress-bar -o "$GH_TMP/gh.zip" "$GH_URL" </dev/null; then
      echo "    download failed."
      gh_manual; return 1
    fi
    echo "  - unpacking ..."
    ditto -x -k "$GH_TMP/gh.zip" "$GH_TMP" || { gh_manual; return 1; }
    GH="$(find "$GH_TMP" -path '*/bin/gh' -type f | head -1)"
    [ -x "$GH" ] || { gh_manual; return 1; }
    echo "  - GitHub CLI ready."
  fi
  if ! "$GH" auth status >/dev/null 2>&1; then
    say "Sign in to GitHub"
    echo "  LooperPilot is private: sign in once with the GitHub account you were invited with."
    # Ohne Rueckfragen (stdin kein Terminal): gh zeigt nur Code und Adresse und wartet auf die
    # Bestaetigung -- mit Terminal-Eingabe scheitert gh per "curl | sh" an seinen Rueckfragen.
    # Den Code zeigen wir selbst gross an und oeffnen den Browser erst danach.
    "$GH" auth login --hostname github.com --git-protocol https --web </dev/null 2>&1 | while IFS= read -r line; do
      CODE="$(printf '%s' "$line" | grep -o '[A-Z0-9]\{4\}-[A-Z0-9]\{4\}' | head -1)"
      if [ -n "$CODE" ]; then
        printf '%s' "$CODE" | pbcopy 2>/dev/null || true
        printf '\n  Your code:   \033[1;33m%s\033[0m   (already copied -- just paste it with Cmd+V)\n\n' "$CODE"
        echo "  Opening github.com/login/device in your browser: paste the code, confirm with"
        echo "  your GitHub account, then come back here -- the installation continues by itself."
        sleep 3
        open "https://github.com/login/device" >/dev/null 2>&1 || echo "  Open https://github.com/login/device in your browser."
      else
        case "$line" in ''|*'login/device'*) ;; *) echo "  $line" ;; esac
      fi
    done
    "$GH" auth status >/dev/null 2>&1 || return 1
    echo "  signed in."
  fi
  return 0
}

# --- 0. Paket ---------------------------------------------------------------
# PKG = der Ordner mit App, Scripts, Vorlagen und Presets: das entpackte Zip selbst
# oder das frisch geladene neueste Release. Aufbau ab 2.0.2: copy_to_RemoteScripts/,
# AbletonTemplates/, Presets/ -- aeltere Zips hatten "Zum Kopieren/".
if [ -d "$HERE/copy_to_RemoteScripts" ] || [ -d "$HERE/Zum Kopieren/Remote Scripts" ]; then
  PKG="$HERE"
else
  say "Download"
  TMP="$(mktemp -d)"
  # Die Releases sind privat: laden nur mit Zugang zum Repo, ueber die GitHub CLI
  if need_gh && "$GH" release download -R "$REPO" -p 'LooperPilot-*.zip' -D "$TMP" 2>/dev/null; then
    ZIP="$(ls "$TMP"/LooperPilot-*.zip | head -1)"
    echo "  downloaded $(basename "$ZIP")"
  else
    echo "No access to the private releases (invited testers only)."
    echo "Accept the invitation to the GitHub organization LooperPilot, then run this again --"
    echo "or download LooperPilot-....zip in your browser from"
    echo "  https://github.com/$REPO/releases/latest"
    echo "unzip it and run  sh install.sh  in that folder."
    exit 1
  fi
  ditto -x -k "$ZIP" "$TMP"
  PKG="$(dirname "$(find "$TMP" -maxdepth 2 -name LooperPilot.app -type d | head -1)")"
  [ -d "$PKG/LooperPilot.app" ] || { echo "Unexpected release contents."; exit 1; }
fi
if [ -d "$PKG/copy_to_RemoteScripts" ]; then
  SCRIPTS_SRC="$PKG/copy_to_RemoteScripts"
  TEMPLATES_SRC="$PKG/AbletonTemplates"
  BANK_PKG="$PKG/Presets/Morningstar MC6 Pro"
else
  SCRIPTS_SRC="$PKG/Zum Kopieren/Remote Scripts"
  TEMPLATES_SRC="$PKG"
  BANK_PKG="$PKG/Zum Kopieren/Morningstar MC6 Pro Bank"
fi

# --- 1. Remote Scripts --------------------------------------------------
# Nur die eigenen Dateien ersetzen: eigene Sicherungen im Zielordner bleiben erhalten.
say "Remote Scripts"
mkdir -p "$SCRIPTS_DEST"
for s in LooperDisplay SPD_SX_Pro_Looper; do
  src="$SCRIPTS_SRC/$s"
  [ -d "$src" ] || { echo "Missing: $src"; exit 1; }
  mkdir -p "$SCRIPTS_DEST/$s"
  cp -R "$src/." "$SCRIPTS_DEST/$s/"
  rm -rf "$SCRIPTS_DEST/$s/__pycache__"
  echo "  $s -> $SCRIPTS_DEST/$s"
done

# --- 1b. MorningstarClips (immer dabei, ausser --no-clips) ------------------
# Eigenes Projekt: steuert die Session View mit einem Morningstar MC6 Pro und
# fuettert die Clips-Seite der Anzeige. Liegt dem Release bei (ab 1.9.1); sonst
# aus dem neuesten Release von $CLIPS_REPO.
if [ "$CLIPS" = yes ]; then
  say "MorningstarClips"
  CLIPS_SRC="$SCRIPTS_SRC/MorningstarClips"
  BANK_SRC="$BANK_PKG"
  if [ ! -d "$CLIPS_SRC" ]; then
    CLIPS_SRC=""
    # privates Repo: nur mit Zugang ueber die GitHub CLI
    CLIPS_TMP="$(mktemp -d)"
    if need_gh && "$GH" release download -R "$CLIPS_REPO" -p 'morningstar-live-clips-*.zip' -D "$CLIPS_TMP" 2>/dev/null \
       && ditto -x -k "$(ls "$CLIPS_TMP"/morningstar-live-clips-*.zip | head -1)" "$CLIPS_TMP"; then
      echo "  downloaded MorningstarClips"
      CLIPS_SRC="$(find "$CLIPS_TMP" -maxdepth 2 -name MorningstarClips -type d | head -1)"
      BANK_SRC="$(dirname "$CLIPS_SRC")/MorningStarPresets"
    fi
  fi
  if [ -n "$CLIPS_SRC" ] && [ -d "$CLIPS_SRC" ]; then
    mkdir -p "$SCRIPTS_DEST/MorningstarClips"
    cp -R "$CLIPS_SRC/." "$SCRIPTS_DEST/MorningstarClips/"
    rm -rf "$SCRIPTS_DEST/MorningstarClips/__pycache__"
    echo "  MorningstarClips -> $SCRIPTS_DEST/MorningstarClips"
    # Die Bank bleibt nur im entpackten Zip von selbst liegen -- sonst hierher kopieren
    BANK_DIR="$BANK_SRC"
    if [ "$PKG" != "$HERE" ] || [ -n "$CLIPS_TMP" ]; then
      # geladenes Release (auch per curl | sh): an einen festen, leicht auffindbaren Ort
      BANK_DIR="$HOME/Music/Ableton/LooperPilot/Presets/Morningstar MC6 Pro"
      mkdir -p "$BANK_DIR"
      cp "$BANK_SRC"/*.json "$BANK_DIR/" 2>/dev/null || true
    fi
    echo "  MC6 Pro bank for the Morningstar Editor: $BANK_DIR"
  else
    echo "  MorningstarClips could not be downloaded -- skipped."
    echo "  Get it later: https://github.com/$CLIPS_REPO/releases/latest"
    CLIPS=no
  fi
fi

[ -n "$SCRIPTS_ONLY" ] && { say "Done (scripts only). Restart Live."; live_hint; exit 0; }

# --- 2. App ---------------------------------------------------------------
say "App"
APP_SRC="$PKG/LooperPilot.app"
[ -d "$APP_SRC" ] || { echo "LooperPilot.app not found."; exit 1; }
[ "$PKG" = "$HERE" ] && echo "  from this folder"

# Wer das Release im Browser geladen hat, hat die Quarantaene-Markierung von macOS
# an allen Dateien. Das Script hat der Nutzer selbst gestartet -- also entfernen,
# damit die App ohne den Umweg ueber die Systemeinstellungen startet.
xattr -dr com.apple.quarantine "$APP_SRC" 2>/dev/null || true
# Eine laufende (aeltere) App zuerst beenden -- sonst holt "open" unten nur das
# alte Fenster nach vorne und dessen Server laeuft mit der alten Version weiter.
if [ -z "$LOOPER_NO_OPEN" ]; then
  for NAME in LooperPilot LooperDisplay; do      # LooperDisplay = alter Name bis 3.0
    pgrep -xq "$NAME" 2>/dev/null || continue
    echo "  quitting the running $NAME ..."
    osascript -e "quit app \"$NAME\"" >/dev/null 2>&1 || true
    i=0
    while pgrep -xq "$NAME" 2>/dev/null && [ $i -lt 10 ]; do sleep 1; i=$((i + 1)); done
    pkill -x "$NAME" 2>/dev/null || true
    sleep 1
  done
fi
rm -rf "$APP_DEST"
# Aus LooperDisplay wurde LooperPilot: die alte App entfernen, damit nur eine im Dock landet
if [ -d "$OLD_APP" ]; then rm -rf "$OLD_APP"; echo "  removed the old $(basename "$OLD_APP") (now LooperPilot)"; fi
ditto "$APP_SRC" "$APP_DEST"
echo "  -> $APP_DEST ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DEST/Contents/Info.plist"))"

# --- 3. Vorlagen ----------------------------------------------------------
say "Template"
install_template() {      # $1 = Dateiname, $2 = Quelle
  if [ ! -f "$2" ]; then
    echo "  $1: not found, skipped"
  elif [ -e "$TEMPLATES_DEST/$1" ]; then
    echo "  $1 already exists there -- not overwritten"
  else
    mkdir -p "$TEMPLATES_DEST"
    cp "$2" "$TEMPLATES_DEST/"
    xattr -d com.apple.quarantine "$TEMPLATES_DEST/$1" 2>/dev/null || true
    echo "  -> $TEMPLATES_DEST/$1"
  fi
}
install_template "$TEMPLATE" "$TEMPLATES_SRC/$TEMPLATE"
# Mit MorningstarClips: Vorlage mit Aufnahme-Bereich (> ... <) und Looper-Gruppe
[ "$CLIPS" = yes ] && install_template "$CLIPS_TEMPLATE" "$TEMPLATES_SRC/$CLIPS_TEMPLATE"

# --- 4. Starten -----------------------------------------------------------
say "Start"
if [ -z "$LOOPER_NO_OPEN" ]; then
  open "$APP_DEST"
  echo "  The display opens in its own window."
fi

say "Done. Now in Ableton Live:"
echo "  1. Restart Live (Remote Scripts are only read at startup)."
echo "  2. Settings > Link, Tempo & MIDI: choose 'LooperDisplay' as a Control Surface (the script keeps its name)."
echo "  3. With a Roland SPD-SX PRO, also add 'SPD_SX_Pro_Looper' (input: SPD-SX PRO)."
if [ "$CLIPS" = yes ]; then
  echo "  4. With a Morningstar MC6 Pro, also add 'MorningstarClips' (input and output: MC6 Pro)"
  echo "     and load the bank from '$BANK_DIR' in the Morningstar Editor."
  echo "     The Clips page: http://localhost:8080/clips"
fi
echo
echo "To start it again later, just open the 'LooperPilot' app -- from Applications,"
echo "Launchpad or Spotlight (Cmd+Space, 'LooperPilot')."
echo "You only need install.sh for installing and updating."
live_hint
