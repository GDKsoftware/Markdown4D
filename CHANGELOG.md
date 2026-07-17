# Changelog

All notable changes to Markdown4D are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and the
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0]

The first stable release of Markdown4D — a native Delphi markdown library and
component set with no external dependencies.

### Parsing and conformance

- CommonMark 0.31.2 parser passing all **652** official specification examples.
- GitHub Flavored Markdown extensions: tables, task list items, strikethrough,
  extended autolinks, and the disallowed-raw-HTML tag filter.
- Incremental / streaming parser that reparses only the changed region, with
  `Append` and `ReplaceRange` editing.

### Public API

- `TMarkdown` facade: `ToHtml`, `Parse`, `ToMarkdown`, `CreateIncrementalParser`,
  and `Version` (the `1.0.0` library version, unit `Markdown4D.Version`).
- Fluent pipeline builder with CommonMark / GFM presets, raw-HTML, XHTML and
  tag-filter options, and registration hooks for custom parsers, delimiter
  processors, renderer hooks and document processors.
- Typed, documented AST (`IMarkdownDocument` and the `IMarkdown*` node
  interfaces) with a visitor, source spans, and a per-node extension-data
  channel.
- Lossless markdown writer for round-tripping and programmatic editing.
- Fluent, validated document builder for constructing documents in code.
- Table-of-contents builder with de-duplicated GitHub-style anchors.
- Themeable rendering via `TMarkdownTheme`, with light and dark presets and
  JSON load / save.

### Extensions

- Open extension API (`IMarkdownExtension` and the pipeline registration
  interfaces).
- Sample `==mark==` extension demonstrating a delimiter processor and renderer
  hook.
- Native chart extension: `chart` code blocks render as bar, line, pie and
  doughnut graphics through a layout block override and the annular-wedge
  drawing primitive.
- Native mermaid extension: `mermaid` fences render as flowchart / `graph`
  (node shapes, labelled edges, ranked layout), `sequenceDiagram` (participants,
  lifelines, activation bars, notes) and `pie` diagrams through a layout block
  override, with a filled-polygon primitive for arrowheads. Unknown diagram
  types, parse errors, graphs above 500 nodes and still-streaming fences fall
  back to a plain code block, never an exception.

### Components

- Custom-drawn `TMarkdownViewer` for VCL and FMX — themed rendering, asynchronous
  image loading, text selection and copy, find, clickable and hoverable links,
  syntax-highlighted `pascal` / `sql` / `json` / `xml` code, live charts, and
  mermaid diagrams.
- Thread-safe, debounced `AppendMarkdown` streaming with auto-follow, suited to
  token-by-token LLM output.
- Syntax-highlighting `TMarkdownEditor` for VCL and FMX, with undo / redo,
  formatting commands, optional line-number gutter, and an attachable live
  preview.
- Design-time support: components register on a **Markdown4D** palette page and
  render a live sample document on the form designer.

### Packaging

- Runtime and design-time packages for both frameworks, building on Delphi 12
  Athens and Delphi 13 from the same sources via `{$LIBSUFFIX AUTO}`.
- Seven runnable example projects covering conversion, viewing, editing and
  streaming chat on both VCL and FMX.

### Requirements

- Delphi 12 Athens or later. Pure RTL — zero external dependencies. MIT licensed.

[1.0.0]: https://github.com/gdksoftware/Markdown4D/releases/tag/v1.0.0
