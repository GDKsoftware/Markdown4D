# Markdown4D package build and IDE installation

This folder contains the runtime and design-time packages that make the
Markdown4D VCL and FMX components available on the RAD Studio component palette.

## Packages

| Package | Kind | Requires | Contains |
|---------|------|----------|----------|
| `Markdown4D.Core` | runtime | `rtl` | all `Source\Core` + `Source\Layout` units (framework-neutral) |
| `Markdown4D.Vcl` | runtime | `rtl`, `vcl`, `vclimg`, `Markdown4D.Core` | `Source\Vcl` painter/viewer/editor, plus the formula font loader `Markdown4D.Vcl.MathFont` |
| `Markdown4D.Fmx` | runtime | `rtl`, `fmx`, `Markdown4D.Core` | `Source\Fmx` painter/viewer/editor, plus the formula font loader `Markdown4D.Fmx.MathFont` |
| `Markdown4D.Vcl.Design` | design-time | `designide`, `Markdown4D.Vcl` | `Markdown4D.Vcl.Register` (+ palette icons) |
| `Markdown4D.Fmx.Design` | design-time | `designide`, `Markdown4D.Fmx` | `Markdown4D.Fmx.Register` (+ palette icons) |

Both design packages register `TMarkdownViewer` and `TMarkdownEditor` on a
component palette page named **Markdown4D**.

## Formula font

The two framework packages carry `Source\Fonts\STIXTwoMath-Regular.otf` as a
resource (`Source\Fonts\STIXTwoMath.rc`, compiled to `STIXTwoMath.res`, about
840 KB). Nothing installs it by itself: an application that wants the bundled
font for its formulas adds `Markdown4D.Vcl.MathFont` or `Markdown4D.Fmx.MathFont`
to a uses clause, which registers the font for that process only. The
registration runs when the first viewer or editor is created. Without the
unit, formulas use the math font the platform ships with: Cambria Math on
Windows, STIX Two Math on macOS 13 and later.

What the FMX loader can do depends on the platform's font manager:

| Platform | Without Skia | With Skia (`GlobalUseSkia := True`) |
|---|---|---|
| Windows | installs (GDI+ and DirectWrite) | installs |
| macOS | installs (CoreText) | installs |
| iOS, Android, Linux | no font manager service; formulas fall back | installs through the Skia font manager |

The fallback family exists only on Windows and macOS; on the other platforms
the OS substitutes its default font, which carries the Unicode math symbols
but not the metrics the formula layout is tuned for.

On Windows the FMX font manager finishes a registration with a synchronous
`WM_FONTCHANGE` broadcast to every top-level window, so an unresponsive
application elsewhere on the desktop stalls the FMX loader until that
application responds again. The VCL loader registers through
`AddFontMemResourceEx`, which does not broadcast.

## Build outputs

- BPL (Win32) → `$(BDSCOMMONDIR)\Bpl` (e.g. `C:\Users\Public\Documents\Embarcadero\Studio\37.0\Bpl`), the standard shared package folder, which is always on the IDE's package search path, so design-time packages and their runtime dependencies load without any PATH configuration
- BPL (Win64, Win64x) → `$(BDSCOMMONDIR)\Bpl\Win64` and `$(BDSCOMMONDIR)\Bpl\Win64x`, kept out of the Win32 folder because the BPL file names are identical across platforms
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

The runtime packages `Core`, `Vcl` and `Fmx` also target **Win64** and
**Win64x**; build them the same way with `/p:Platform=Win64` or
`/p:Platform=Win64x`. The IDE greys out a component on the palette when its
runtime package does not list the project's target platform. `Vcl.Design` and
`Fmx.Design` also target Win64x, for the 64-bit IDE; build them the same way
with `/p:Platform=Win64x`.

`build.bat` in the repository root also builds all five packages (Release,
Win32), the three runtime packages for Win64 and Win64x, and both design
packages (`Vcl.Design` and `Fmx.Design`) for Win64x as part of the standard
build.

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
   path* (Win32) → add `...\packages\dcp\Win32\Release`, and the same for each
   64-bit platform you target (`...\packages\dcp\Win64\Release`).
5. Applications linked without runtime packages (the default) need nothing
   extra. Only when an application is built WITH runtime packages and runs
   outside the IDE do the runtime BPLs need to be findable: copy them next to
   the executable or add the shared Bpl folder to the system `PATH`.
6. Drop `TMarkdownViewer` / `TMarkdownEditor` from the **Markdown4D** palette
   page onto a form. The control renders a live sample document at design time.

To uninstall: Component ▸ Install Packages ▸ select each Markdown4D design
package ▸ Remove.

### Installing in the 64-bit IDE

Delphi 13 also ships a 64-bit IDE, which loads design-time packages built for
**Win64x**, not Win32. The Win32 steps above are for the 32-bit IDE; the 64-bit
IDE needs its own build and install:

1. Build the three runtime packages and both design packages for Win64x
   (Release), either with `build.bat` or by hand:

   ```
   msbuild packages\Markdown4D.Core.dproj        /t:Build /p:Config=Release /p:Platform=Win64x
   msbuild packages\Markdown4D.Vcl.dproj         /t:Build /p:Config=Release /p:Platform=Win64x
   msbuild packages\Markdown4D.Fmx.dproj         /t:Build /p:Config=Release /p:Platform=Win64x
   msbuild packages\Markdown4D.Vcl.Design.dproj  /t:Build /p:Config=Release /p:Platform=Win64x
   msbuild packages\Markdown4D.Fmx.Design.dproj  /t:Build /p:Config=Release /p:Platform=Win64x
   ```

   The BPLs go to `$(BDSCOMMONDIR)\Bpl\Win64x`, a separate folder from the Win32
   ones, so installing for one IDE never overwrites the other's files.
2. The 64-bit IDE does not search that folder for the runtime BPLs the design
   packages depend on. Add it to the user `PATH`, for example
   `C:\Users\Public\Documents\Embarcadero\Studio\37.0\Bpl\Win64x`, and restart the
   IDE so it sees the change.
3. In the 64-bit IDE open `packages\Markdown4D.Vcl.Design.dproj`. In the Project
   Manager make **Windows 64-bit (Modern)** the active target platform and
   **Release** the active configuration, then right-click the project and choose
   **Install**. Repeat for `packages\Markdown4D.Fmx.Design.dproj`. With the IDE
   defaults (Debug, or Windows 64-bit) the build stops with E2225 on
   `designide` or E2202 on the runtime package.
4. Add `...\packages\dcp\Win64x\Release` to the Win64x library path
   (Tools ▸ Options ▸ Language ▸ Delphi ▸ Library) so projects can find the
   runtime `.dcp`s.

The two IDEs keep separate package lists, so install in each IDE you use.

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
