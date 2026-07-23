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
- `MarkdownPad.SessionSync.pas` — `TPadSessionSync`: opent de sessiebestanden in
  de workspace (`RestoreOpenFiles`), verzamelt de op te slaan getitelde bestanden
  (`CollectOpenFiles`) en de tab-captions/modified-vlaggen (`CollectTabs`).

## Nog niet gedeeld (bewust uitgesteld)

### `SwitchToDocument`: editor-/preview-state
De workspace-kant is nu gedeeld, maar het opslaan en herladen van de live
editor-/preview-state blijft per form, omdat het aan de concrete controls hangt
(`mdEditor`/`mdPreview` vs `FEditor`/`FPreview`). Dit delen vraagt een
editor/preview-abstractie (een klein view-model of interface rond `Text`,
`CaretPosition`, `SaveEditState`/`LoadEditState`, `ScrollToSourceLine` en de
preview-scrolloffset), los van de VCL/FMX-controls.

### Bewust NIET delen
- `BuildSampleMarkdown` — de voorbeeldtekst verschilt per app (VCL vs FMX).
- Kleuren en maten die per framework verschillen (`TAlphaColor` vs `TColor`,
  custom title bar / DWM caption, tooltip-maten) — blijven in elke form.
