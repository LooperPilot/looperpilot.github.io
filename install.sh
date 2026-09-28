#!/bin/sh
# Installiert LooperDisplay auf dem Mac:
#   1. Remote Scripts in die Ableton User Library
#   2. LooperDisplay.app nach /Applications
#   3. Vorlagen nach User Library/Templates (nur wenn noch keine gleichnamige da ist)
#   4. App starten
# Alles kommt aus dem Release-Zip: liegt install.sh im entpackten Zip, aus diesem
# Ordner, sonst (nach einem git clone) laedt es das neueste Release von GitHub.
#
# Usage:   ./install.sh               everything (asks about MorningstarClips)
#          ./install.sh --scripts     Remote Scripts only
#          ./install.sh --with-clips  also MorningstarClips for the Morningstar MC6 Pro
#          ./install.sh --no-clips    without MorningstarClips, without asking
set -e

SCRIPTS_ONLY=""
CLIPS="ask"
for arg in "$@"; do
  case "$arg" in
    --scripts) SCRIPTS_ONLY=1 ;;
    --with-clips) CLIPS=yes ;;
    --no-clips) CLIPS=no ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="hennydrums/looper-display"
CLIPS_REPO="hennydrums/morningstar-live-clips"
LIB="${LOOPER_LIB:-$HOME/Music/Ableton/User Library}"          # zum Testen umlenkbar
SCRIPTS_DEST="$LIB/Remote Scripts"
TEMPLATES_DEST="$LIB/Templates"
APP_DEST="${LOOPER_APP_DEST:-/Applications/LooperDisplay.app}"
TEMPLATE="LooperTemplateV1.6.als"
CLIPS_TEMPLATE="MorningStarTemplate.als"

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

if [ "$(uname -s)" != "Darwin" ]; then
  echo "LooperDisplay only runs on macOS."; exit 1
fi
if [ "$(uname -m)" != "arm64" ]; then
  echo "Note: the app is built for Macs with Apple silicon (M1 or newer)."
fi

TMP=""
CLIPS_TMP=""
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; [ -n "$CLIPS_TMP" ] && rm -rf "$CLIPS_TMP"; true; }
trap cleanup EXIT

# Neuestes Release-Zip eines Repos: URL der ersten .zip-Datei
latest_zip() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | sed 's/.*"\(http[^"]*\)"/\1/'
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
  URL="$(latest_zip "$REPO")"
  [ -n "$URL" ] || { echo "No release found. Please download it manually: https://github.com/$REPO/releases/latest"; exit 1; }
  echo "  downloading $(basename "$URL") ..."
  curl -fL --progress-bar -o "$TMP/release.zip" "$URL"
  ditto -x -k "$TMP/release.zip" "$TMP"
  PKG="$(dirname "$(find "$TMP" -maxdepth 2 -name LooperDisplay.app -type d | head -1)")"
  [ -d "$PKG/LooperDisplay.app" ] || { echo "Unexpected release contents."; exit 1; }
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

# --- 1b. MorningstarClips (optional) --------------------------------------
# Eigenes Projekt: steuert die Session View mit einem Morningstar MC6 Pro und
# fuettert die Clips-Seite der Anzeige. Liegt dem Release bei (ab 1.9.1); sonst
# aus dem neuesten Release von $CLIPS_REPO.
if [ "$CLIPS" = ask ]; then
  CLIPS=no
  if [ -t 0 ]; then
    printf '\nAlso install MorningstarClips (Session View with a Morningstar MC6 Pro)? [y/N] '
    read -r answer || answer=""
    case "$answer" in [yYjJ]*) CLIPS=yes ;; esac
  fi
fi
if [ "$CLIPS" = yes ]; then
  say "MorningstarClips"
  CLIPS_SRC="$SCRIPTS_SRC/MorningstarClips"
  BANK_SRC="$BANK_PKG"
  if [ ! -d "$CLIPS_SRC" ]; then
    CLIPS_SRC=""
    URL="$(latest_zip "$CLIPS_REPO" || true)"
    if [ -n "$URL" ]; then
      CLIPS_TMP="$(mktemp -d)"
      echo "  downloading $(basename "$URL") ..."
      if curl -fL --progress-bar -o "$CLIPS_TMP/clips.zip" "$URL" && ditto -x -k "$CLIPS_TMP/clips.zip" "$CLIPS_TMP"; then
        CLIPS_SRC="$(find "$CLIPS_TMP" -maxdepth 2 -name MorningstarClips -type d | head -1)"
        BANK_SRC="$(dirname "$CLIPS_SRC")/MorningStarPresets"
      fi
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
      BANK_DIR="$HERE/Presets/Morningstar MC6 Pro"
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

[ -n "$SCRIPTS_ONLY" ] && { say "Done (scripts only). Restart Live."; exit 0; }

# --- 2. App ---------------------------------------------------------------
say "App"
APP_SRC="$PKG/LooperDisplay.app"
[ -d "$APP_SRC" ] || { echo "LooperDisplay.app not found."; exit 1; }
[ "$PKG" = "$HERE" ] && echo "  from this folder"

# Wer das Release im Browser geladen hat, hat die Quarantaene-Markierung von macOS
# an allen Dateien. Das Script hat der Nutzer selbst gestartet -- also entfernen,
# damit die App ohne den Umweg ueber die Systemeinstellungen startet.
xattr -dr com.apple.quarantine "$APP_SRC" 2>/dev/null || true
rm -rf "$APP_DEST"
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
# Laeuft noch eine aeltere Version, ersetzt die App sie selbst.
say "Start"
if [ -z "$LOOPER_NO_OPEN" ]; then
  open "$APP_DEST"
  echo "  The display opens in its own window."
fi

say "Done. Now in Ableton Live:"
echo "  1. Restart Live (Remote Scripts are only read at startup)."
echo "  2. Settings > Link, Tempo & MIDI: choose 'LooperDisplay' as a Control Surface."
echo "  3. With a Roland SPD-SX PRO, also add 'SPD_SX_Pro_Looper' (input: SPD-SX PRO)."
if [ "$CLIPS" = yes ]; then
  echo "  4. With a Morningstar MC6 Pro, also add 'MorningstarClips' (input and output: MC6 Pro)"
  echo "     and load the bank from '$BANK_DIR' in the Morningstar Editor."
  echo "     The Clips page: http://localhost:8080/clips"
fi
echo
echo "To start it again later, just open the 'LooperDisplay' app -- from Applications,"
echo "Launchpad or Spotlight (Cmd+Space, 'LooperDisplay')."
echo "You only need install.sh for installing and updating."
