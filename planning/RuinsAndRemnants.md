Ziel: Blueprints als Vorlagen für Ruinen

## Aktueller Stand

Schritt 1 und 2 sind jetzt als Offline-Importer im Repo umgesetzt:

- Eingabe: `tools/blueprint-input.txt`
- Kommando: `npm run blueprint:extract`
- Ausgabe: `tools/blueprint-extracted/`

Alternativ:

- `npm run blueprint:extract -- --stdout`
- `npm run blueprint:extract -- --string "0eN..."`
- `npm run blueprint:extract -- --input path/to/book.txt`
- `npm run blueprint:extract -- --output-dir path/to/exported-books`

Der Importer macht aktuell genau Schritt 1 und 2:

- Blueprint-String decodieren
- Blueprint-JSON parsen
- rekursiv durch Blueprint-Books laufen
- pro Blueprint-Book ein Verzeichnis schreiben
- pro Blueprint eine eigene JSON-Datei schreiben
- pro JSON-Datei nur `entities[]` und `tiles[]` extrahieren
- bei Entities nur `name`, `position`, `direction`, `type`

Für den aktuellen Testlauf ist Schritt 3 zusätzlich für genau zwei Blueprints umgesetzt:

- `tools/blueprint-extracted/root-modular-train-grid/0-grid-rails/03-rails-barbone-grid.json`
- `tools/blueprint-extracted/root-modular-train-grid/0-grid-rails/11-solar-grid.json`

Kommando:

- `npm run blueprint:normalize-merge`

Ausgabe:

- `tools/blueprint-normalized/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.json`

Dieses Testskript:

- merged genau diese zwei Blueprints vor der Normalisierung
- wählt einen gemeinsamen Anchor aus der kleinsten absoluten `x/y`-Koordinate
- rechnet alle Koordinaten relativ zu diesem Anchor um
- berechnet die Bounding Box des gemergten Ergebnisses
- entfernt nur exakte Duplikate

Für den gleichen Testfall gibt es jetzt zusätzlich einen ersten Schritt-4-Converter:

- Kommando: `npm run blueprint:ruin-template`
- Eingabe: `tools/blueprint-normalized/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.json`
- Ausgabe: `tools/ruin-templates/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.ruin-template.json`

Der Converter macht aktuell noch keine finale Platzierungs-Lua daraus, sondern ein Review-/Zwischenformat:

- `convert_to_remnant`: für bereits klar gemappte Remnant-Ziele
- `cluster_to_remnants`: für Rail-Netze, die später nicht 1:1 gespawnt werden sollen
- `collapsed_to_remnants`: aus dem Rail-Cluster abgeleitete sparsame Remnant-Skelett-Version
- `preserve_as_damaged`: für teure Infrastruktur, die vorerst als beschädigte Live-Entity gedacht ist
- `foundation`: für Untergrund-Tiles wie `landfill`

Für denselben Testfall gibt es jetzt zusätzlich einen deterministischen Abnutzungs-Pass:

- Kommando: `npm run blueprint:wear-profile`
- Eingabe: `tools/ruin-templates/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.ruin-template.json`
- Ausgabe: `tools/ruin-templates-worn/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.worn.json`

Der Wear-Pass verteilt das Template in reviewbare Endzustände:

- `entities.remnant`
- `entities.damaged_live`
- `entities.missing`
- `tiles.foundation_kept`
- `tiles.foundation_cracked`
- `tiles.foundation_missing`

Der aktuelle Test-Profile-Ansatz ist deterministisch und positionsbasiert, damit derselbe Template-Input immer denselben Abnutzungszustand erzeugt.

Zusätzlich gibt es jetzt einen Export in eine echte Lua-Datendatei für das Mod:

- Kommando: `npm run blueprint:export-lua`
- Eingabe: `tools/ruin-templates-worn/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.worn.json`
- Ausgabe: `second_engineer/scripts/worldgeneration/generated/merged_rails_solar.lua`

Der Export bleibt absichtlich datenorientiert:

- `entities.remnant`
- `entities.damaged_live`
- `entities.missing`
- `tiles.foundation_kept`
- `tiles.foundation_cracked`
- `tiles.foundation_missing`

Damit kann die Runtime später gezielt entscheiden, was wirklich gespawnt, was nur dekorativ genutzt und was ganz verworfen wird.

### Offline/Build-Time Pipeline

1. Wähle Decoder (JS/TS oder Python; siehe Quellen oben). ([GitHub][2])
2. Parse Blueprint-JSON und extrahiere nur:

   * `entities[]`: name, position, direction (+ evtl. type hints)
   * `tiles[]`: name, position
3. Normalisiere:

   * anchor/pivot definieren
   * Koordinaten relativ zum anchor
   * Bounding box berechnen und speichern
4. “Ruin mapping” offline anwenden:

   * Entity name/type → ruined-entity prototype / decorative / skip
   * optional: belt/pipe clustering (nicht 1:1 Segmente)
5. Export als Lua-Tabellen ins Mod (templates + metadata + bounding boxes).

### Ingame/Worldgen Pipeline

6. Bei Chunk-Generation: entscheide deterministisch, ob/wo ein Template platziert wird.


7. Definiere ein Abnutzungsprofil als Datensatz pro Template (oder global mit Overrides), z.B.:

* `missing_rate_by_category` (z.B. 40% fehlen)
* `collapsed_rate_by_category` (z.B. 15% der Maschinen “eingestürzt”)
* `scorch_density` / `crater_density`
* `tile_damage_level` (clean → cracked → ruined)
* `debris_density`
* `loot_density` + `loot_quality`

Beispiel:
=> 3/4 sind zerstört, davon 2/4 Remnants, 1/4 fehlen
=> 1/4 sind richtige Entities, davon sind nochmal 50% beschädigt
=> Abnutzung wird random auf den ganzen Blueprint gerechnet, nicht extra für jede entity
Die Verhältnisse (3/4 kaputt, etc.) sollten sich anpassen lassen

8. Site Selection:

   * N Kandidaten-Ankerpunkte testen
   * pro Kandidat: tile-check (kein Wasser) + entity collision check
9. Wenn kein Spot gefunden:

   * fallback: anderes Template / kleinere Variante / skip
   * (oder Strategie B aktivieren: controlled terraforming)
10. Platzierung:

   * zuerst ggf. Untergrund fixen (`set_tiles`), dann Ruinen-Tiles/Decals, dann Ruinen-Entities
11. Budget/Performance:

* Megabase nicht in einem Tick voll spawnen → in Batches über mehrere Ticks/Chunks

---

## Empfehlung für “Mega-Base”

Nimm **Strategie A mit Fallback auf B**:

* Primär: suche eine passende Landfläche (wirkt natürlich)
* Wenn nach X Versuchen keine Fläche: “fülle Wasser auf” *nur in der Bounding Box*, aber maskiere den Rand mit kaputten Tiles + Schutt, damit es nicht wie ein Rechteck-Landfill aussieht.

Wenn du willst, formuliere ich dir daraus eine **Agenten-Aufgabenbeschreibung** als Ticket-Text (inkl. Inputs/Outputs/akzeptanzkriterien), weiterhin ohne Code.

[1]: https://wiki.factorio.com/Blueprint_string_format?utm_source=chatgpt.com "Blueprint string format - Official Factorio Wiki"
[2]: https://github.com/JensForstmann/factorio-blueprint-tools?utm_source=chatgpt.com "JensForstmann/factorio-blueprint-tools: JS/TS library for ..."
[3]: https://github.com/argoarsiks/factorio-blueprint-decoder?utm_source=chatgpt.com "argoarsiks/factorio-blueprint-decoder"
[4]: https://github.com/ericmburgess/python-factorio/blob/master/sources/factorio/blueprints.py?utm_source=chatgpt.com "python-factorio/sources/factorio/blueprints.py at master"
[5]: https://github.com/nyurik/fatul?utm_source=chatgpt.com "nyurik/fatul: Make Factorio blueprints easy to version in git ..."
[6]: https://lua-api.factorio.com/latest/classes/LuaItemStack.html?utm_source=chatgpt.com "LuaItemStack - Runtime Docs | Factorio"
[7]: https://lua-api.factorio.com/latest/classes/LuaSurface.html?utm_source=chatgpt.com "LuaSurface - Runtime Docs | Factorio"
