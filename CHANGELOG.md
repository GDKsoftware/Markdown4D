# Changelog

All notable changes to Markdown4D are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and the
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Markdown4D no longer bundles any third-party code.** Image32 drew the SVG
  images and the anti-aliased chart wedges; both are now done by units written
  for this project, and `ThirdParty/` is gone. Nothing about installing or
  building changes except that two search paths fall away.

### Added

- **The SVG engine covers what a real drawing asks for**: `<use>`, `<mask>`,
  `<pattern>`, `<image>` with data URIs, and filters. A filtered element is
  drawn on a layer of its own and `feGaussianBlur`, `feOffset`, `feFlood`,
  `feComposite` and `feMerge` are applied to it, so a drop shadow arrives as a
  drop shadow rather than being left out.
- **Text renders on every platform.** Outlines come through
  `Markdown4D.Image.Glyphs`: the Windows font engine answers on Windows,
  needing nothing beside it, and Skia answers everywhere else. Skia is only
  compiled in where it is the answer, because its objects load their library as
  the program starts rather than when first asked.
- **Images embedded in an SVG** are decoded through `Markdown4D.Image.Decoder`,
  with the VCL picture classes answering on Windows and Skia elsewhere.
- `Markdown4D.Image.Rasterizer` fills polygons with anti-aliasing, exactly
  horizontally and over four sub-scanlines vertically, with the non-zero and
  even-odd rules, gradient paints, clip masks and source-over compositing.
- `Markdown4D.Image.Svg.Xml`, `.Path` and `.Native` draw an SVG: the shape
  elements, groups, transforms, the viewBox, solid and gradient fills, strokes
  with miter and round joins, opacity, both fill rules, clip paths and text.
  Patterns, filters, masks, embedded images and `<use>` are refused whole, so a
  document is never drawn half right.
- `Markdown4D.Image.Glyphs` is the seam text outlines come from, with a Windows
  implementation in `Markdown4D.Image.Glyphs.Gdi` that asks the system font
  engine. Text in an SVG now renders, which the bundled engine never did here.

## [2.0.0] - 2026-07-30

### Security

- **`TMarkdown.ToHtml` is now safe by default.** Raw HTML is replaced by
  `<!-- raw HTML omitted -->`, and link and image destinations using
  `javascript:`, `vbscript:`, `file:` or a non-image `data:` scheme are emptied.
  The previous behaviour is available under the new name `TMarkdown.ToUnsafeHtml`
  and through the pipeline builder. This mirrors cmark, which has had safe
  rendering as its default since 0.29.
- **Destination filtering** (unit `Markdown4D.Text.UrlSafety`) — judged after
  entity decoding and ignoring whitespace and control characters, so
  `&#106;avascript:`, `JaVaScRiPt:` and a leading space are all recognised.
  `data:image/png`, `gif`, `jpeg` and `webp` are kept.
- **The MarkdownPad examples no longer hand document links to the shell
  unchecked.** `TPadLinkPolicy` (unit `MarkdownPad.LinkPolicy`) opens `http`,
  `https` and `mailto`; every other destination, including `file:` URLs, UNC
  paths and local executables, is refused with a message naming the target.
  Since the pad can be registered as the handler for `.md`, a downloaded
  document could otherwise launch a program on a single click.
- **A link to a neighbouring markdown file is opened by the pad itself**, in a
  tab, instead of being handed to the shell. Only a relative path to an existing
  `.md` file qualifies; an absolute, drive-relative or UNC path does not, because
  reaching for someone else's share is what hands over the credentials Windows
  offers it. A trailing `#anchor` is dropped: the file opens at the top.
- **Every hop of an image redirect faces the address policy.** The viewers
  follow redirects themselves instead of letting the HTTP client do it, so
  `Images.AllowRemote` and `OnRemoteImageRequest` judge each destination in a
  chain. A permitted address could otherwise redirect to one the host would have
  refused. A chain is limited to five hops and must stay on `http` or `https`.
- **Raw HTML in image alt text is always escaped**, in unsafe rendering as well.
  Alt text is an attribute value, so an unescaped quote inside inline HTML could
  end the attribute and inject markup of the document's choosing. A line break
  in alt text now renders as a space, which is what an attribute can carry. Both
  match cmark.
- **`Images.BaseUrl` no longer switches off `RestrictToDocumentFolder`.** A base
  naming a local folder is resolved and then held against the restriction like
  any other path; a base carrying a scheme names a server and is left alone.

### Fixed

- **Quadratic block parsing on lines carrying many list markers.** A line such as
  `- - - - …` opens one list per marker, and the loose-list check walked the
  whole nested chain for each of them. Whether a block trails a blank line is
  now settled once, when the block is finalized. A 200 KB document of this shape
  went from 116 seconds to 0.15 seconds; parsing is linear in the input again.
- `TMarkdownImageDownloader` reports a result even when the fetch fails in a way
  `TryFetch` does not handle, so the download queue can no longer stall. An
  address out of a document is an outside boundary, so the fetch treats whatever
  the network stack, the stream or the decoder raises as one failed image rather
  than as a background task that dies unobserved.
- Local image paths are canonicalised, so a destination with `..` segments
  resolves to one spelling of the file.
- **Quadratic inline parsing on paragraphs carrying many `<` characters.** Each
  bracket had the remainder of the paragraph copied before the autolink and tag
  patterns were tried. The patterns are anchored with `\G` and matched in place,
  so a paragraph of brackets costs time proportional to its length.
- The lazily built pipelines behind `TMarkdown` carry a memory barrier on the
  unsynchronised read, so the double-checked initialisation also holds on a
  weakly ordered processor.
- A link to a neighbouring markdown file may no longer leave the document's own
  folder through `..` segments. The file is opened by the pad rather than by the
  shell, but any `.md` on the machine was previously reachable.

### Added

- `IMarkdownPipelineBuilder.UnsafeLinks` — the destination half of the previous
  rendering behaviour, separate from `UnsafeHtml`.
- **Viewer image settings** (unit `Markdown4D.Viewer.ImageSettings`, shared by
  the VCL and FMX viewers and republished by both):
  - `AllowRemote` (default `True`) — whether `http(s)` destinations may be
    fetched. Opening a document otherwise tells every host it names that the
    document was read.
  - `MaxBytes` (default 8 MB) — upper bound on one downloaded image, enforced
    against both the announced length and what actually arrives. A response
    claiming to be an image could previously grow until memory ran out.
  - `RestrictToDocumentFolder` (default `False`) — keeps a relative image path
    inside the document's own folder.
- **`TMarkdownViewer.OnRemoteImageRequest`** — vetoes or permits one remote
  image, starting from `Images.AllowRemote`, so an application can allow only
  the hosts it knows.
- Performance budget tests covering nested list markers and runs of `<`
  characters, each including a scaling ratio that fails if parsing turns
  quadratic again.
- `TMarkdownImageDownloader.OnAddressAllowed`, the seam through which the
  viewers judge every address in a redirect chain.

## [1.1.0]

A plumbing and extension-API release. End-user rendering is unchanged — the same
CommonMark, GFM, round-trip, chart and mermaid output — but the surface an
extension author draws and registers against is now unified and consistent.

### Added

- **`IExtensionCanvas`** (unit `Markdown4D.Layout.BlockOverride`) — a single,
  framework-neutral drawing surface for layout block overrides. It exposes
  `FillRectangle`, `DrawRectangle`, `FillAndStrokeRectangle`, `DrawText`,
  `DrawLine`, `DrawDashedLine`, `FillPolygon`, `FillWedge`, `DrawImage`,
  `MeasureText`, and `SaveState` / `SetClip` / `RestoreState`. An override reaches
  it through `ILayoutBlockContext.Canvas`. The reusable
  `TDisplayListExtensionCanvas` lives in the new unit
  `Markdown4D.Layout.ExtensionCanvas`.
- **`FillAndStrokeRectangle`** on the canvas — a filled-and-stroked rectangle as
  one primitive (mermaid nodes, sequence participant boxes), so bounds are never
  duplicated across two display items.
- **`TMarkdownPriorities`** (unit `Markdown4D.Extensions.Interfaces`) — named
  priority constants for every registration point: `Highest`, `High`,
  `AboveNormal`, `Normal`, `BelowNormal`, `Low`, `Lowest`, the built-in
  block / inline parser priorities, and the extension slots
  `ExtensionProcessor` (100), `ExtensionRenderer` (50) and
  `ExtensionLayoutOverride` (100). Registrations no longer need magic numbers.
- **Scoped layout registries** — `TLayoutBlockOverrideRegistry` and
  `TLayoutDocumentProcessorRegistry` (unit `Markdown4D.Layout.BlockOverride`)
  back `TMarkdownLayoutEngine.RegisterBlockOverride` /
  `ClearBlockOverrides`, with a single, documented priority-then-registration
  resolution shared with the pipeline.

### Changed

- **Viewer pipeline caching** — the viewer model relays out against the facade's
  cached per-dialect GFM pipeline instead of building a pipeline on every relayout,
  and runs the layout document-processor registry over the parsed document.
- Chart and mermaid layouters now draw onto an `IExtensionCanvas` rather than
  assembling display items directly; the shipped block overrides,
  layout-geometry output and corpora are byte-for-byte unchanged.

### Breaking (extension API)

The ad-hoc `Emit*` methods on `ILayoutBlockContext` were removed in favour of the
unified canvas. A block override that drew through the context must now draw
through `Context.Canvas`:

| 1.0.0 — `ILayoutBlockContext` | 1.1.0 — `Context.Canvas` (`IExtensionCanvas`) |
|-------------------------------|------------------------------------------------|
| `Context.EmitRectangle(Bounds, Fill)` | `Context.Canvas.FillRectangle(Bounds, Fill)` |
| `Context.EmitRectangle(Bounds, Fill, Stroke, Width)` | `Context.Canvas.FillAndStrokeRectangle(Bounds, Fill, Stroke, Width)` |
| `Context.EmitTextRun(TopLeft, Text, Font, Color)` | `Context.Canvas.DrawText(TopLeft, Text, Font, Color)` |
| `Context.EmitLine(P1, P2, Color, Width)` | `Context.Canvas.DrawLine(P1, P2, Color, Width)` |
| `Context.EmitWedge(Center, Outer, Inner, Start, Sweep, Color)` | `Context.Canvas.FillWedge(Center, Outer, Inner, Start, Sweep, Color)` |
| `Context.EmitPolygon(Points, Color)` | `Context.Canvas.FillPolygon(Points, Color)` |

`ILayoutBlockOverride`, `Handles`, `LayoutBlock` and the two-place
(parse-time processor, layout-time override) registration model are otherwise
unchanged. The parsing pipeline API (`IMarkdownExtension`, the `Register*`
methods, renderer hooks, delimiter processors, document processors) is
source-compatible with 1.0.0.

### Requirements

- Delphi 12 Athens or later. Pure RTL — zero external dependencies. MIT licensed.

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

[2.0.0]: https://github.com/gdksoftware/Markdown4D/releases/tag/v2.0.0
[1.1.0]: https://github.com/gdksoftware/Markdown4D/releases/tag/v1.1.0
[1.0.0]: https://github.com/gdksoftware/Markdown4D/releases/tag/v1.0.0
