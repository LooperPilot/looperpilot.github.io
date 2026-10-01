# Looper Display

> **Download:** [`LooperDisplay-….zip` unter Releases](https://github.com/hennydrums/looper-display/releases/latest)
> — nicht „Source code", dem fehlt die App.
>
> **Schöner zu lesen:** die [Anleitung als Webseite](https://hennydrums.github.io/looper-display/install.html)
> (DE/EN), liegt auch im Zip als `Anleitung - Guide.html`. Dieses Dokument
> hier ist die reine Textversion zum Nachschlagen.

Zeigt den Zustand aller Looper eines Ableton-Live-Sets als drehende Ringe im
Browser: auf dem Mac, auf einem zweiten Monitor oder auf jedem Tablet im
selben Netz. Kein Max for Live, kein AbletonOSC, keine bestimmte Hardware
nötig.

**Voraussetzungen:** Mac mit Apple-Chip (M1 oder neuer), macOS 12 oder
neuer, Ableton Live 11 oder 12. **Empfohlen ist Live 12** — nur damit spielt
Stop den Loop zu Ende, kennt die Anzeige die Länge von Loops, die mit dem Set
geladen wurden, und zeigt bei leeren Loopern die voreingestellte
Aufnahmelänge. Unter Live 11 läuft alles andere wie gewohnt.

## Installation per Terminal (am schnellsten)

```
git clone https://github.com/hennydrums/looper-display.git
cd looper-display
./install.sh
```

**Update:** Ist `looper-display` schon vom ersten Mal da („destination path
'looper-display' already exists"), reicht:

```
cd looper-display
git pull
./install.sh
```

Lädt die neueste App, kopiert Remote Scripts und Vorlage an die richtigen
Stellen und startet die App — ohne Sicherheitsabfrage von macOS. Danach Live
neu starten und unter *Einstellungen → Link, Tempo & MIDI* `LooperDisplay`
als Bedienoberfläche wählen. `./install.sh --scripts` aktualisiert nur die
Remote Scripts.

Mit dem Morningstar MC6 Pro: `./install.sh --with-clips` installiert das Script
[MorningstarClips](https://github.com/hennydrums/morningstar-live-clips) gleich mit
(ohne Angabe fragt `install.sh` danach). Die MC6-Pro-Bank liegt dem Download bei.

Ab 2.0 zeigt die App die Anzeige in ihrem **eigenen Fenster** (Menü *Ansicht*: Clips ⌘1, Looper ⌘2, Tablet-Adresse mit QR-Code ⌘T); Fenster schließen lässt den Server für Tablets weiterlaufen, *Server beenden* (⌥⌘Q) stoppt ihn.

Später wieder starten: einfach die App **LooperDisplay** öffnen — aus
„Programme“, dem Launchpad oder per Spotlight. `install.sh` brauchst du nur
für die Installation und für Updates.

## Clips-Seite für das Morningstar MC6 Pro (ab 1.8)

Die Seite **🎛 Clips** ist die Startseite (`http://localhost:8080`, auf dem Tablet die
Adresse unter „📱 Tablet“; die Looper-Anzeige liegt unter `/looper`): das Morningstar MC6 Pro
im Browser und darunter eine Übersicht aller Spuren und Szenen mit Clip-Namen. Dafür
das Remote Script [Morningstar Live Clips](https://hennydrums.github.io/morningstar-live-clips/)
(ab 1.1) installieren – am einfachsten mit `./install.sh --with-clips` – und in Live als
Bedienoberfläche wählen; LooperDisplay findet es von selbst.
