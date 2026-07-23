# MarkdownPad — gedeelde code: nog te doen

De VCL- (`Examples/MarkdownPadVCL`) en FMX-build (`Examples/MarkdownPadFMX`) zijn
twee schillen om dezelfde app. De echt identieke stukken zijn al uitgetild naar
`Examples/Shared`:

- `MarkdownPad.Defines.pas` — alle gedeelde constanten (glyphs, hints,
  command-namen/shortcuts, categorieën, filters, format-strings, gedeelde maten).
- `MarkdownPad.Text.pas` — `TPadText.ComputeLineColumn` / `TPadText.CountWords`.
- `MarkdownPad.Outline.pas` — `TPadOutlineBuilder.Build` (TOC-boom → platte,
  ingesprongen lijst) en `.ActiveIndex` (actieve entry voor een bronregel).

## Nog niet gedeeld (bewust uitgesteld)

Dit doen we later — het is de grootste resterende duplicatie, maar het zit vast
aan de concrete UI-controls van elk framework, dus het vraagt een echte
abstractielaag i.p.v. knippen/plakken.

### 1. `RegisterStaticCommands` (~180 regels, vrijwel identiek)
Beide builds registreren exact dezelfde commando's in het palet. Alleen de
closures verschillen: ze roepen `mdEditor`/`FEditor` (VCL- vs FMX-editor) en
form-methoden aan.

Aanpak-idee: een gedeelde registratie die callbacks/una interface krijgt
aangereikt, bv. `TPadCommandSet.RegisterInto(Registry, Actions)` waarbij
`Actions` een record/interface van `TProc`'s is (Bold, Italic, Save, ToggleZen,
…). De form vult alleen die `Actions` en houdt de framework-specifieke
implementaties.

### 2. Sessie-/documentbeheer-lus
`SaveSession`, de open-files-lus in `RestoreSession`, en delen van
`SwitchToDocument` / `RebuildTabs` zijn grotendeels gelijk. Ze lezen echter de
live editor + form-state, dus vergen dezelfde `Actions`/host-interface-aanpak
als hierboven, of een klein view-model dat de editor-inhoud abstraheert.

### Bewust NIET delen
- `BuildSampleMarkdown` — de voorbeeldtekst verschilt per app (VCL vs FMX).
- Kleuren en maten die per framework verschillen (`TAlphaColor` vs `TColor`,
  custom title bar / DWM caption, tooltip-maten) — blijven in elke form.
