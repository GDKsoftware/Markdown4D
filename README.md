# Markdown4D

A native Delphi CommonMark / GFM markdown library with a public AST, an
incremental streaming parser, an HTML renderer, a lossless markdown writer, and
custom-drawn VCL & FMX viewer and editor components — no embedded browser, no
external dependencies.

<!-- badges -->
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version 1.1.0](https://img.shields.io/badge/version-1.1.0-blue.svg)](CHANGELOG.md)
[![Delphi 12+](https://img.shields.io/badge/Delphi-12%2B-e62329.svg)](https://www.embarcadero.com/products/delphi)
[![CommonMark 0.31.2](https://img.shields.io/badge/CommonMark-0.31.2%20652%2F652-1f6feb.svg)](https://spec.commonmark.org/0.31.2/)

## Why Markdown4D

- **Fully spec-conformant.** Passes all **652** official CommonMark 0.31.2
  examples, plus the GitHub Flavored Markdown extension corpora (tables, task
  list items, strikethrough, extended autolinks, disallowed raw HTML).
- **A real AST, not just HTML.** Parse to a typed, documented
  `IMarkdownDocument`, inspect or transform it, and write it back to clean
  markdown with the round-trip writer.
- **Built for live text.** An incremental / streaming parser reparses only what
  changed — ideal for editors and token-by-token LLM output.
- **Open extension API.** Add inline and block syntax, delimiter processors,
  renderer hooks and document processors through a fluent pipeline builder. The
  bundled chart extension shows how far a custom renderer can go.
- **Native UI, both frameworks.** Custom-drawn `TMarkdownViewer` and
  `TMarkdownEditor` for VCL and FMX, with theming, images, selection, search,
  syntax-highlighted code, live charts, mermaid diagrams and design-time preview.
- **Zero dependencies.** Pure RTL. MIT licensed. Delphi 12 Athens and Delphi 13.

## Features

| Area | What you get |
|------|--------------|
| CommonMark 0.31.2 | Full block and inline grammar, 652/652 official examples |
| GFM extensions | Tables, task list items, strikethrough, extended autolinks, tag filter |
| Public AST | Typed node interfaces, visitor, source spans, extension data slots |
| Round-trip writer | `IMarkdownDocument` → clean markdown, lossless editing |
| Document builder | Fluent, validated API to construct documents in code |
| Incremental parser | Append / replace-range reparsing for streaming and editors |
| HTML renderer | Spec-conformant output, safe by default, optional XHTML and tag filter |
| Table of contents | Slugged anchors with de-duplication from any document |
| Extension API | Block/inline parsers, delimiter processors, renderer hooks, document processors |
| Chart extension | `chart` code blocks rendered natively as bar/line/pie/doughnut graphics |
| Mermaid extension | `mermaid` fences rendered natively as flowchart / sequence / pie diagrams, with code-block fallback |
| VCL & FMX viewer | Themed rendering, async images, selection, copy, find, links |
| VCL & FMX editor | Syntax-highlighted source editing with an attachable live preview |
| Design-time | Live sample render on the form designer; components on the **Markdown4D** palette |

## Quick start

**One line — markdown to HTML:**

```pascal
uses
  Markdown4D;

const Html = TMarkdown.ToHtml('# Hello *world*');
```

**Configure a pipeline** (GFM, raw HTML allowed):

```pascal
uses
  Markdown4D.Pipeline,
  Markdown4D.Extensions.Interfaces;

const Html = TMarkdownPipeline.Create
  .UseGfm
  .UnsafeHtml
  .Build
  .ToHtml(Source);
```

**Drop a viewer onto a form** (VCL):

```pascal
uses
  Markdown4D.Theme,
  Markdown4D.Vcl.Viewer;

const Viewer = TMarkdownViewer.Create(Self);
Viewer.Parent := Self;
Viewer.Align := alClient;
Viewer.ThemePreset := TMarkdownThemePreset.Dark;
Viewer.Text := '# Welcome'#10#10 + 'This is **Markdown4D**.';
```

**Stream tokens from an LLM** — the viewer reparses incrementally, debounces
relayout, and auto-follows the tail:

```pascal
procedure TChatForm.OnTokenReceived(const Token: string);
begin
  FAnswerViewer.AppendMarkdown(Token);
end;
```

`AppendMarkdown` is safe to call from a worker thread; it marshals to the UI
thread for you. See [docs/STREAMING.md](docs/STREAMING.md).

## Installation

Markdown4D is source-only and has no external dependencies. Add the source
folders to your project's search path:

```
Source\Core     framework-neutral parser, AST, renderer, writer, extensions
Source\Layout   framework-neutral layout engine, theme, viewer/editor models
Source\Vcl      VCL painter, viewer, editor
Source\Fmx      FMX painter, viewer, editor
```

For a component-palette install, build the runtime and design-time packages in
`packages\` and install the two design packages in the IDE. `{$LIBSUFFIX AUTO}`
targets Delphi 12 (`290`) and Delphi 13 (`370`) from the same sources. Full
build order and step-by-step IDE instructions are in
[packages/INSTALL.md](packages/INSTALL.md).

## Examples

The `Examples\` folder contains seven runnable projects:

| Project | Framework | Shows |
|---------|-----------|-------|
| `Md2Html` | Console | `markdown → HTML` CLI with `--gfm`, `--xhtml`, `--safe`, `--version` |
| `VclViewerDemo` | VCL | Viewer with file open, light/dark theme switching, find and a native chart |
| `MarkdownPad` | VCL | Editor + live preview + table of contents, with native charts and mermaid diagrams |
| `LlmChat` | VCL | Streaming chat with incremental render, async images, live charts and mermaid diagrams |
| `FmxViewerDemo` | FMX | Viewer with file open, theme switching, find and a native chart |
| `FmxMarkdownPad` | FMX | Editor + live preview, with native charts and mermaid diagrams |
| `FmxLlmChat` | FMX | Streaming chat with live charts and mermaid diagrams |

## Architecture

Markdown4D is strictly layered. `Core` and `Layout` are framework-neutral; only
the outermost layer knows about VCL or FMX.

```
             +--------------------+      +--------------------+
   VCL app   |  Source\Vcl        |      |  Source\Fmx        |  FMX app
             |  Painter / Viewer  |      |  Painter / Viewer  |
             |  Editor            |      |  Editor            |
             +---------+----------+      +----------+---------+
                       |                            |
                       +-------------+--------------+
                                     |
                       +-------------v--------------+
                       |  Source\Layout             |   framework-neutral
                       |  Layout engine, display     |
                       |  list, theme, hit-testing,  |
                       |  viewer/editor models,      |
                       |  block overrides            |
                       |  (charts, mermaid)          |
                       +-------------+--------------+
                                     |
                       +-------------v--------------+
                       |  Source\Core               |   framework-neutral
                       |  Parser (blocks + inlines), |
                       |  incremental parser, AST,   |
                       |  HTML renderer, markdown     |
                       |  writer, TOC, extensions,   |
                       |  pipeline builder           |
                       +----------------------------+
```

A single string of markdown flows: **source → pipeline → AST → (HTML renderer
| markdown writer | layout engine → display list → painter)**.

## Conformance dashboard

The suite runs the CommonMark and GFM specification corpora plus round-trip and
incremental parsing corpora on every build. The table below is regenerated by
`build.bat`.

<!-- conformance:start -->
| Corpus | Tests | Passed | Pass rate |
|--------|------:|-------:|----------:|
| CommonMark | 26 | 26 | 100.0% |
| Gfm | 5 | 5 | 100.0% |
| RoundTrip | 31 | 31 | 100.0% |
| Incremental | 62 | 62 | 100.0% |
| **Total** | **124** | **124** | **100.0%** |
<!-- conformance:end -->

Each corpus row aggregates its specification example groups; the full CommonMark
0.31.2 corpus covers all 652 official examples.

## Building & testing

Run the build script from the repository root:

```bat
build.bat
```

It compiles and runs the DUnitX main and FMX test suites, builds every example
and every package, and regenerates the conformance dashboard above.

## Documentation

- [docs/API.md](docs/API.md) — the public surface: facade, pipeline, AST,
  builder, TOC, theme, and the viewer / editor components.
- [docs/EXTENSIONS.md](docs/EXTENSIONS.md) — writing extensions: the `==mark==`
  parser extension, an admonition custom-rendering walkthrough on the
  `IExtensionCanvas`, and the bundled chart and mermaid extensions.
- [docs/STREAMING.md](docs/STREAMING.md) — the LLM / streaming integration
  guide: `AppendMarkdown`, debounce, threading, charts and `Text` semantics.
- [packages/INSTALL.md](packages/INSTALL.md) — package build and IDE install.
- [CHANGELOG.md](CHANGELOG.md) — release history.

## License

Markdown4D is released under the [MIT License](LICENSE).

Copyright (c) 2026 GDK Software
