Ziel: Blueprints als Vorlagen für Ruinen

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
