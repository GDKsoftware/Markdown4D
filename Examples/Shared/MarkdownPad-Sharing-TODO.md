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
  `mdEditor`/`mdPreview` (VCL) resp. `FEditor`/`FPreview` (FMX).
- `MarkdownPad.Shell.pas` — `IPadShell`: de seam waarmee de controller de
  framework-specifieke schil aanstuurt (tab-strip, titel, dialogs, clipboard,
  per-app tekst zoals `SampleMarkdown`). Elke form implementeert deze interface.
- `MarkdownPad.Controller.pas` — `TPadController`: framework-agnostische
  orkestratie. Bezit het document-model (workspace/session/file-watcher) en de
  applicatielogica die eerst verbatim in beide forms stond. Praat met de editor
  via `IPadEditorView` en met de schil via `IPadShell`; raakt nooit een VCL/FMX-
  control aan. **Gefaseerde extractie — nu verhuisd:** document-lifecycle (nieuw
  document, openen, opslaan/opslaan-als, sluiten, document wisselen, sessie
  herstellen/bewaren); de command-palette (registry-opbouw, recent-files,
  fuzzy-match, commando uitvoeren; de form levert de actie-closures + rendert de
  lijst); de **editing-loop** (editor-change, tick, status/titel, find,
  TOC-sync, extern-gewijzigd-bestand herladen, close-query); en **HTML-export/
  copy** (de controller genereert het document/fragment via `TMarkdownHtmlExport`
  / `TMarkdown.ToHtml`, de form doet de save-dialog en het klembord). De
  `FTocFollowing`-reentrancy-guard blijft bewust FMX-only (VCL's lijst vuurt geen
  change op een programmatische `ItemIndex`).

### Bewust NIET naar de controller
- **View-mode + zen** (`ApplyViewMode`, `SetViewMode`, `EnterZen`/`ExitZen`,
  `UpdateZenPadding`): dit is view-logica, geen app-logica. Elke regel is
  framework-specifiek (pane-visibility/align, `TPanel`/`TLayout` pad-panelen,
  `TColor` vs `TAlphaColor`, `ClientWidth`); de gedeelde kern is ~5 regels en
  loopt al via de `EffectiveViewMode` / `ApplyRestoredViewMode`-seams. De
  controller hoort niks te weten van pad-panelen en pane-alignment.

## Nog niet gedeeld (bewust uitgesteld)

### Bewust NIET delen
- `BuildSampleMarkdown` — de voorbeeldtekst verschilt per app (VCL vs FMX).
- Kleuren en maten die per framework verschillen (`TAlphaColor` vs `TColor`,
  custom title bar / DWM caption, tooltip-maten) — blijven in elke form.
