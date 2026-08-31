# Markdown4D package build and IDE installation

This folder contains the runtime and design-time packages that make the
Markdown4D VCL and FMX components available on the RAD Studio component palette.

## Packages

| Package | Kind | Requires | Contains |
|---------|------|----------|----------|
| `Markdown4D.Core` | runtime | `rtl` | all `Source\Core` + `Source\Layout` units (framework-neutral) |
| `Markdown4D.Vcl` | runtime | `rtl`, `vcl`, `vclimg`, `Markdown4D.Core` | `Source\Vcl` painter/viewer/editor |
| `Markdown4D.Fmx` | runtime | `rtl`, `fmx`, `Markdown4D.Core` | `Source\Fmx` painter/viewer/editor |
| `Markdown4D.Vcl.Design` | design-time | `designide`, `Markdown4D.Vcl` | `Markdown4D.Vcl.Register` (+ palette icons) |
| `Markdown4D.Fmx.Design` | design-time | `designide`, `Markdown4D.Fmx` | `Markdown4D.Fmx.Register` (+ palette icons) |

Both design packages register `TMarkdownViewer` and `TMarkdownEditor` on a
component palette page named **Markdown4D**.

## Build outputs

- BPL (Win32) → `$(BDSCOMMONDIR)\Bpl` (e.g. `C:\Users\Public\Documents\Embarcadero\Studio\37.0\Bpl`), the standard shared package folder, which is always on the IDE's package search path, so design-time packages and their runtime dependencies load without any PATH configuration
- BPL (Win64x) → `$(BDSCOMMONDIR)\Bpl\Win64x`, kept out of the Win32 folder because the BPL file names are identical across platforms
- DCP → `packages\dcp\<Platform>\<Config>`
- DCU → `packages\<Platform>\<Config>`

`{$LIBSUFFIX AUTO}` appends the compiler's product version to the runtime BPL
name automatically, so the same sources produce `Markdown4D.Core290.bpl` on
Delphi 12 Athens and `Markdown4D.Core370.bpl` on Delphi 13. No manual edits are
needed to target either version.

## How to build (command line)

From a Developer Command Prompt (or after calling `rsvars.bat`), build in
dependency order:

```
msbuild packages\Markdown4D.Core.dproj        /t:Build /p:Config=Release /p:Platform=Win32
msbuild packages\Markdown4D.Vcl.dproj         /t:Build /p:Config=Release /p:Platform=Win32
msbuild packages\Markdown4D.Fmx.dproj         /t:Build /p:Config=Release /p:Platform=Win32
msbuild packages\Markdown4D.Vcl.Design.dproj  /t:Build /p:Config=Release /p:Platform=Win32
msbuild packages\Markdown4D.Fmx.Design.dproj  /t:Build /p:Config=Release /p:Platform=Win32
```

The `Core`, `Vcl` and `Vcl.Design` packages also target **Win64x** (for 64-bit
package consumers and the 64-bit IDE); build them the same way with
`/p:Platform=Win64x`.

`build.bat` in the repository root also builds all five packages (Release,
Win32) plus the three Win64x VCL packages as part of the standard build.

## Palette icons

`packages\icons\make-icons.ps1` renders the 24x24 and 32x32 palette glyphs
(`TMARKDOWNVIEWER.bmp` / `TMARKDOWNEDITOR.bmp`, a rounded "M" + down-arrow on
brand blue). `Markdown4D.Icons.rc` is compiled with `brcc32` into
`Markdown4D.Vcl.Icons.dcr` and `Markdown4D.Fmx.Icons.dcr`, which the design
packages embed via `{$R}`. The 24px bitmap is the palette glyph the IDE scales
for high DPI; the 32px bitmap is included as a higher-resolution spare. To
regenerate:

```
powershell -ExecutionPolicy Bypass -File packages\icons\make-icons.ps1
brcc32 packages\Markdown4D.Icons.rc -fopackages\Markdown4D.Vcl.Icons.dcr
brcc32 packages\Markdown4D.Icons.rc -fopackages\Markdown4D.Fmx.Icons.dcr
```

## Manual IDE installation (per developer machine)

Installation registers the BPLs with the IDE; it is a one-time manual step and
is **not** performed by the automated build.

1. Build the packages (Release, Win32) as above, or run `build.bat`.
2. In RAD Studio open `packages\Markdown4D.Core.dproj`, then the `Vcl` and `Fmx`
   runtime packages, and **Compile** each (Project ▸ Build). Runtime packages
   are not installed, only compiled.
3. Open `packages\Markdown4D.Vcl.Design.dproj`, right-click the project in the
   Project Manager and choose **Install**. Repeat for
   `packages\Markdown4D.Fmx.Design.dproj`. The IDE reports that
   `TMarkdownViewer` and `TMarkdownEditor` were registered.
4. Add the DCP output folder to the library path so projects can find the
   runtime `.dcp`s: Tools ▸ Options ▸ Language ▸ Delphi ▸ Library ▸ *Library
   path* (Win32) → add `...\packages\dcp\Win32\Release`.
5. Applications linked without runtime packages (the default) need nothing
   extra. Only when an application is built WITH runtime packages and runs
   outside the IDE do the runtime BPLs need to be findable: copy them next to
   the executable or add the shared Bpl folder to the system `PATH`.
6. Drop `TMarkdownViewer` / `TMarkdownEditor` from the **Markdown4D** palette
   page onto a form. The control renders a live sample document at design time.

To uninstall: Component ▸ Install Packages ▸ select each Markdown4D design
package ▸ Remove.

## Published-property design decisions (Object Inspector / DFM streaming)

- **Theme → `ThemePreset` enum.** The full `TMarkdownTheme` is a rich object
  graph that the Object Inspector cannot edit without a custom property editor.
  A published `ThemePreset: (Light, Dark)` enum streams cleanly, is editable as
  a dropdown, and carries `default TMarkdownThemePreset.Light` (ordinal 0, which
  matches the zero-initialized field, so the default is omitted from the DFM).
  Code that needs full control still assigns the `Theme` object at run time (that
  property stays public, non-published).
- **`Text` → plain `string`.** The viewer/editor already hold the document as a
  single string in their model; a plain published `string` streams the whole
  document as one DFM value and needs no `TStrings`/`DefineProperties` plumbing.
  It is guarded by `stored IsTextStored`, which returns `False` while the
  design-time sample is showing so the placeholder sample is never written to the
  DFM.
- **`Images` → published TPersistent with a setter.** `Images` is a
  `TMarkdownViewerImageSettings` (holds `BaseUrl`). A read-only class property is
  only streamed by the RTL when it is a `csSubComponent` `TComponent`; a
  read-only `TPersistent` is skipped. The property therefore has a
  `write SetImages` setter that calls `Assign`, and the settings class overrides
  `Assign`, so `Images.BaseUrl` round-trips through DFM/FMX streaming.
- **Events.** `OnLinkClick`, `OnLinkHover`, `OnResolveImage`, `OnScroll`
  (viewer) and `OnChange`, `OnScroll` (editor) are published so the designer can
  wire handlers and stream them by method name.

DFM/FMX round-trip of these properties is covered by
`Tests\Markdown4D.Vcl.Design.Tests.pas` and `Tests\Markdown4D.Fmx.Design.Tests.pas`
(`WriteComponent`/`ReadComponent`), alongside the design-time-preview render
tests that exercise the `csDesigning` sample path.
