Reste der Mega-Base

Neue Strategie:

- Strukturen zuerst in Factorio als Blueprint bauen
- Blueprint-String exportieren
- mit der Ruinen-Pipeline konvertieren
- als generiertes Runtime-Paket in Worldgen spawnen

Megabase Ruins:

- Core District: done
- als ein einziges authored Paket, nicht mehr aus alten Block-Fragmenten zusammengesetzt

Scattered Districts als nächste authored Ziele:

- Blue Circuits
- Oil/Chem District
- Science District
- Mining Districts:
  - Iron
  - Copper
  - Coal
  - Stone
  - weiteres Ore-District nach Bedarf
- Rail remnants zwischen den Districts

Offene Punkte vor Feierabend:

- Core District Spawn ist noch nicht richtig:
  - darf nicht auf großem Wasser spawnen
  - soll so nah an den Spieler-Start, dass ein Rand auf der Minimap / am Viewport sichtbar ist
  - aktueller Spawn landete wieder am alten Ort

- Core District Wear / Ruin-Tuning ist noch nicht richtig:
  - es gibt aktuell nicht genug Rail-Remnants
  - generell mehr Ruinen-/Remnant-Charakter gewünscht
  - zu viele lebende Strukturen
  - Alive-Anteil nochmal runterdrehen

- Core District Combat-Setup:
  - alle Turrets sollen initial `enemy` sein
  - Turrets sollen mit wenig zufälliger Startmunition gespawnt werden

- Vor Commit nochmal prüfen:
  - ToDo/Planungsdokumente final gegen Code-Stand abgleichen
  - dann erst committen

3-4 Segmente on Block
- Solar Power
- Iron Smelting
- Electronic Circuits

Mauern drum (Outer-Defense + Straight)

Prüfen wo die Anchors von den Blueprints hin sind, damit man überlappende Strukturen generieren kann

Eventuell einfach das ganze Ding als eine einzige riesige Struktur.
=> für den Core District jetzt erledigt


Der feine Herr hat sich noch "kleine Defense Outposts" gewünscht. Was auch immer das sein soll. Das müssen wir auch noch generieren und verteilen

Anscheinend soll es auch mehrere Reste Mega-Base geben (haha genau) mit Varianten der Blöcke

- Near Water?
keine Ahnung


und weil das irgendwann vom spawnen völlig ausrastet, müssen wir nochmal in die LargeRuinRuntimeStrategy gucken. Die resultierenden Lua-Tables sind gigantomanisch


auf der anderen Seite habe ich jetzt ein Tool, was ein Blueprint in eine Ruine konvertieren kann.
Der Workflow ist jetzt genau das: bauen lassen, exportieren, konvertieren, als Ruine spawnen


codex resume 019ca5d8-0a53-7383-9420-4476cac821d3
