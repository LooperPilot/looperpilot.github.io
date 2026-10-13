# StageCase

> **Download:** StageCase (bis 3.9 LooperPilot) ist in der Testphase – die Releases liegen im privaten Repo
> [LooperPilot/looper-pilot](https://github.com/LooperPilot/looper-pilot/releases/latest) (Zugang auf Anfrage).
>
> **Anleitung:** [looperpilot.github.io/install.html](https://looperpilot.github.io/install.html) (DE/EN, liegt auch im Zip als `Anleitung - Guide.html`).
> **Rundgang durch alle Seiten:** [hennys.de/stagecase](https://hennys.de/stagecase/)

Der Musical Director für Ableton Live – vom Proberaum bis auf die Bühne: Looper, Clips, Setlist,
Lead Sheet, Mixer und Soundkarte in einer App am Mac und auf jedem Tablet im selben Netz.

**Voraussetzungen:** macOS 12 oder neuer, Ableton Live 12 (empfohlen; unter Live 11 laufen Anzeige,
Songs, Clips, Mixer und Soundkarte).

## Installation und Update

```
curl -fsSL https://looperpilot.github.io/install.sh | sh
```

Beim ersten Mal einmal bei GitHub anmelden (Code im Terminal, Bestätigung im Browser); fehlt die
GitHub CLI, holt das Script sie selbst. Ohne Terminal: `StageCase-….zip` aus den Releases laden,
entpacken, im Ordner `sh install.sh` ausführen.

Danach Live mit ⌘Q neu starten und unter *Einstellungen → Link, Tempo & MIDI* **eine** Zeile
einrichten: Bedienoberfläche `Stagecase`, Eingang `Stagecase`, Ausgang `Stagecase`.
nanoKONTROL2, Morningstar MC6 Pro und Roland SPD-SX PRO findet StageCase selbst – bei ihren
MIDI-Anschlüssen *Track* und *Remote* ausschalten. Alte Zeilen `LooperDisplay`,
`SPD_SX_Pro_Looper`, `MorningstarClips` auf „Kein“ stellen.

Alles Weitere steht in der App unter **❓ Hilfe**.
