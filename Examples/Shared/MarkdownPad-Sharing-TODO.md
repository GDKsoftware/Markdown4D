# MarkdownPad — gedeelde code: nog te doen

De VCL- (`Examples/MarkdownPadVCL`) en FMX-build (`Examples/MarkdownPadFMX`) zijn
twee schillen om dezelfde app. De echt identieke stukken zijn al uitgetild naar
`Examples/Shared`:

- `MarkdownPad.Defines.pas` — alle gedeelde constanten (glyphs, hints,
  command-namen/shortcuts, categorieën, filters, format-strings, gedeelde maten).
- `MarkdownPad.Text.pas` — `TPadText.ComputeLineColumn` / `TPadText.CountWords`.
- `MarkdownPad.Outline.pas` — `TPadOutlineBuilder.Build` (TOC-boom → platte,
  ingesprongen lijst) en `.ActiveIndex` (actieve entry voor een bronregel).
- `MarkdownPad.CommandSet.pas` — `RegisterStaticPadCommands` registreert het
  vaste commandopalet (namen, categorieën, shortcuts, volgorde) één keer; elke
  form levert alleen de actie-bodies aan via `TPadCommandActions`.

## Nog niet gedeeld (bewust uitgesteld)

### Sessie-/documentbeheer-lus
`SaveSession`, de open-files-lus in `RestoreSession`, en delen van
`SwitchToDocument` / `RebuildTabs` zijn grotendeels gelijk. Ze lezen echter de
live editor + form-state, dus vergen dezelfde `Actions`/host-interface-aanpak
als `MarkdownPad.CommandSet`, of een klein view-model dat de editor-inhoud
abstraheert.

### Bewust NIET delen
- `BuildSampleMarkdown` — de voorbeeldtekst verschilt per app (VCL vs FMX).
- Kleuren en maten die per framework verschillen (`TAlphaColor` vs `TColor`,
  custom title bar / DWM caption, tooltip-maten) — blijven in elke form.
