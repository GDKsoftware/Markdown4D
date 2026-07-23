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
- `MarkdownPad.EditorView.pas` — `IPadEditorView` (framework-neutrale abstractie
  rond de live editor + preview: tekst, caret, edit-state, preview-scrolloffset,
  scroll-naar-bronregel, swap-suppressie) en `TPadDocumentSwitch.Execute` (de
  buffer-swap: uitgaand document opslaan, doel activeren, inkomend document laden).
  Elke form implementeert `IPadEditorView` met triviale forwarders naar zijn eigen
  `mdEditor`/`mdPreview` (VCL) resp. `FEditor`/`FPreview` (FMX); `SwitchToDocument`
  is nu een paar regels die `TPadDocumentSwitch.Execute` aanroepen.

## Nog niet gedeeld (bewust uitgesteld)

### Bewust NIET delen
- `BuildSampleMarkdown` — de voorbeeldtekst verschilt per app (VCL vs FMX).
- Kleuren en maten die per framework verschillen (`TAlphaColor` vs `TColor`,
  custom title bar / DWM caption, tooltip-maten) — blijven in elke form.
