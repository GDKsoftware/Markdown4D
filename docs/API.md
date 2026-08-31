# Markdown4D API reference

This document describes the public surface of Markdown4D: the facade, the
pipeline builder, the abstract syntax tree, the document builder, the table of
contents, the theme, and the VCL / FMX viewer and editor components.

All public enumerations are scoped (`{$SCOPEDENUMS ON}`), so qualify them:
`TMarkdownDialect.Gfm`, `TMarkdownNodeKind.Heading`, and so on.

## Contents

- [Facade — `TMarkdown`](#facade--tmarkdown)
- [Pipeline builder](#pipeline-builder)
- [Abstract syntax tree](#abstract-syntax-tree)
- [Document builder](#document-builder)
- [Table of contents](#table-of-contents)
- [Theme](#theme)
- [Incremental parser](#incremental-parser)
- [Viewer components](#viewer-components)
- [Editor components](#editor-components)
- [Drawing SVG](#drawing-svg)
- [Glyph outlines and image decoding](#glyph-outlines-and-image-decoding)

## Facade — `TMarkdown`

Unit `Markdown4D`. The one-stop entry point for the common cases.

```pascal
type
  TMarkdown = class
    class function Version: string;
    class function ToHtml(const Source: string;
      const Dialect: TMarkdownDialect = TMarkdownDialect.CommonMark): string;
    class function ToUnsafeHtml(const Source: string;
      const Dialect: TMarkdownDialect = TMarkdownDialect.CommonMark): string;
    class function Parse(const Source: string;
      const Dialect: TMarkdownDialect = TMarkdownDialect.CommonMark): IMarkdownDocument;
    class function ToMarkdown(const Document: IMarkdownDocument): string;
    class function CreateIncrementalParser(
      const Dialect: TMarkdownDialect = TMarkdownDialect.CommonMark): IMarkdownIncrementalParser;
  end;
```

`Version` returns the library version string (`'2.0.0'`, defined as
`Markdown4DVersion` in unit `Markdown4D.Version`).

`TMarkdownDialect` (unit `Markdown4D.Defines`) is `(CommonMark, Gfm)`. The
facade caches one pipeline per dialect and rendering mode.

`ToHtml` renders safely: raw HTML becomes `<!-- raw HTML omitted -->`, and a
link or image destination using `javascript:`, `vbscript:`, `file:` or a
non-image `data:` scheme is emptied. Use it for any document the application did
not produce itself.

`ToUnsafeHtml` renders what the CommonMark and GFM specifications prescribe:
raw HTML and every destination reach the output untouched. It is the right
choice for trusted input, or when the result passes through an HTML sanitizer
afterwards. The conformance suites are checked against this method.

For finer control build your own pipeline; `UnsafeHtml` and `UnsafeLinks` on the
builder correspond to the two halves of `ToUnsafeHtml`.

```pascal
uses
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces;

const Doc = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
const Markdown = TMarkdown.ToMarkdown(Doc);
```

Errors raised by the library derive from `EMarkdownError` (unit
`Markdown4D.Defines`).

## Pipeline builder

Units `Markdown4D.Pipeline` and `Markdown4D.Extensions.Interfaces`.
`TMarkdownPipeline.Create` returns a fluent `IMarkdownPipelineBuilder`. Every
configuration method returns the builder, so calls chain; `Build` produces an
immutable, reusable `IMarkdownPipeline`.

```pascal
type
  IMarkdownPipelineBuilder = interface
    function UseCommonMark: IMarkdownPipelineBuilder;
    function UseGfm: IMarkdownPipelineBuilder;
    function Use(const Extension: IMarkdownExtension): IMarkdownPipelineBuilder;
    function XhtmlOutput: IMarkdownPipelineBuilder;
    function UnsafeHtml: IMarkdownPipelineBuilder;
    function UnsafeLinks: IMarkdownPipelineBuilder;
    function TagFilter: IMarkdownPipelineBuilder;
    function RegisterBlockParser(const Parser: IMarkdownBlockParser;
      const TriggerCharacters: string; const Priority: Integer): IMarkdownPipelineBuilder;
    function RegisterInlineParser(const Parser: IMarkdownInlineParser;
      const TriggerCharacters: string; const Priority: Integer): IMarkdownPipelineBuilder;
    function RegisterDelimiterProcessor(const Processor: IMarkdownDelimiterProcessor;
      const Priority: Integer): IMarkdownPipelineBuilder;
    function RegisterRendererHook(const Hook: IMarkdownRendererHook;
      const Priority: Integer): IMarkdownPipelineBuilder;
    function RegisterDocumentProcessor(const Processor: IMarkdownDocumentProcessor;
      const Priority: Integer): IMarkdownPipelineBuilder;
    function Build: IMarkdownPipeline;
  end;

  IMarkdownPipeline = interface
    function ToHtml(const Source: string): string;
    function Parse(const Source: string): IMarkdownDocument;
  end;
```

### Configuration options

| Method | Effect |
|--------|--------|
| `UseCommonMark` | Registers the full CommonMark 0.31.2 block and inline grammar |
| `UseGfm` | `UseCommonMark` plus tables, task lists, strikethrough, autolinks, tag filter |
| `Use(ext)` | Installs a custom `IMarkdownExtension` |
| `UnsafeHtml` | Allows raw HTML in the rendered output (CommonMark spec behaviour) |
| `UnsafeLinks` | Writes every link and image destination out, including `javascript:`, `vbscript:`, `file:` and non-image `data:` (spec behaviour). Without it those destinations are emptied |
| `XhtmlOutput` | Emits self-closing XHTML tags |
| `TagFilter` | Applies the GFM tag filter to raw HTML |
| `Register*` | Adds a single parser, processor or hook at a given priority |

Higher priority wins; ties break by registration order. Rather than passing
magic numbers, use the named constants on `TMarkdownPriorities` (unit
`Markdown4D.Extensions.Interfaces`) — `Highest`, `High`, `AboveNormal`,
`Normal`, `BelowNormal`, `Low`, `Lowest`, and the extension slots
`ExtensionProcessor`, `ExtensionRenderer` and `ExtensionLayoutOverride`. A built
pipeline is thread-safe to reuse for parsing and rendering.

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

See [EXTENSIONS.md](EXTENSIONS.md) for the extension interfaces used by the
`Register*` and `Use` methods.

## Abstract syntax tree

Unit `Markdown4D.Ast.Interfaces`. `Parse` returns an `IMarkdownDocument`, the
root of a tree of `IMarkdownNode`. Nodes are reference-counted interfaces; hold
the document and the whole tree stays alive.

```pascal
type
  IMarkdownNode = interface
    function GetKind: TMarkdownNodeKind;
    function GetSegment: TMarkdownSegment;
    function GetChildCount: Integer;
    function GetChild(const Index: Integer): IMarkdownNode;
    procedure Accept(const Visitor: IMarkdownVisitor);
    procedure SetExtensionData(const Key: string; const Data: IInterface);
    function TryGetExtensionData(const Key: string; out Data: IInterface): Boolean;
    property Kind: TMarkdownNodeKind read GetKind;
    property Segment: TMarkdownSegment read GetSegment;
    property ChildCount: Integer read GetChildCount;
    property Children[const Index: Integer]: IMarkdownNode read GetChild;
  end;
```

`TMarkdownNodeKind` enumerates every node type: `Document, Paragraph, Heading,
ThematicBreak, CodeBlock, BlockQuote, List, ListItem, HtmlBlock, Text, Emphasis,
Strong, CodeSpan, Link, Image, Autolink, SoftLineBreak, HardLineBreak,
InlineHtml, CustomInline, Table, TableRow, TableCell`.

`TMarkdownSegment` (`StartOffset`, `EndOffset`, `Length`) locates the node in
the source string. `SetExtensionData` / `TryGetExtensionData` attach arbitrary
interface payloads keyed by string — the mechanism the chart extension uses to
cache its parsed model on the node.

### Typed node interfaces

Query a node for a richer interface with `as` or `Supports`:

| Interface | Extra members |
|-----------|---------------|
| `IMarkdownHeading` | `Level`, `SourceLine` |
| `IMarkdownCodeBlock` | `Literal`, `InfoString`, `IsFenced` |
| `IMarkdownList` | `IsOrdered`, `StartNumber`, `IsTight` |
| `IMarkdownText` | `Literal` (also used for code spans, HTML blocks, inline HTML) |
| `IMarkdownLink` | `Destination`, `Title` (also used for images and autolinks) |
| `IMarkdownCustomInline` | `NodeName` (extension inline nodes such as strikethrough) |
| `IMarkdownTableRow` | `IsHeader` |
| `IMarkdownTableCell` | `Alignment` (`TMarkdownTableColumnAlignment`) |

```pascal
const Doc = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);

for var Index := 0 to Doc.ChildCount - 1 do
begin
  const Child = Doc.Children[Index];
  if Child.Kind = TMarkdownNodeKind.Heading then
  begin
    const Heading = Child as IMarkdownHeading;
    Writeln(Format('H%d at line %d', [Heading.Level, Heading.SourceLine]));
  end;
end;
```

`IMarkdownVisitor` offers a `Visit*` method per node kind for double-dispatch
traversal via `Node.Accept(Visitor)`.

## Document builder

Unit `Markdown4D.Ast.Builder`. Constructs a valid document in code, then hands
it to the writer or the layout engine. `TMarkdownDocumentBuilder.Create` returns
a fluent `IMarkdownDocumentBuilder`.

Convenience methods (`Heading`, `Paragraph`, `Bold`, `Italic`, `Code`, `Link`,
`Image`, `Cell`, …) emit a complete node in one call. `Begin…` / `End…` pairs
open a container you fill with nested content (`BeginParagraph`,
`BeginBulletList`, `BeginOrderedList`, `BeginListItem`, `BeginTaskListItem`,
`BeginTable`, `BeginTableRow`, `BeginTableCell`, `BeginBlockQuote`,
`BeginBold`, `BeginItalic`, `BeginStrikethrough`, `BeginLink`, `BeginHeading`).
Structural rules are enforced — a table may contain only rows, a row only cells —
and `Build` raises `EMarkdownError` if any node is left open.

```pascal
uses
  Markdown4D,
  Markdown4D.Ast.Builder;

const Doc = TMarkdownDocumentBuilder.Create
  .Heading(1, 'Report')
  .Paragraph('Generated by Markdown4D.')
  .BeginBulletList
    .BeginListItem.Text('First item').EndListItem
    .BeginListItem.Text('Second item').EndListItem
  .EndList
  .Build;

const Markdown = TMarkdown.ToMarkdown(Doc);
```

## Table of contents

Unit `Markdown4D.Toc`. `TMarkdownToc.FromDocument` walks the headings of any
document and returns a nested `IMarkdownToc`. Each `IMarkdownTocEntry` carries
`Caption`, `Level`, `Anchor` (a GitHub-style slug, de-duplicated with a numeric
suffix), `SourceLine`, and nested `Children`.

```pascal
uses
  Markdown4D,
  Markdown4D.Toc;

const Doc = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
const Toc = TMarkdownToc.FromDocument(Doc);

for var Index := 0 to Toc.EntryCount - 1 do
begin
  const Entry = Toc.Entries[Index];
  Writeln(Format('%s -> #%s', [Entry.Caption, Entry.Anchor]));
end;
```

## Theme

Unit `Markdown4D.Theme`. `TMarkdownTheme` holds every colour, font and metric
the layout engine uses. Construct one with `CreateLight`, `CreateDark` or
`CreatePreset(TMarkdownThemePreset)`; you own the instance and must `Free` it
(the viewer/editor take ownership when you assign their `Theme` property).

Selected properties: `BaseFont`, `CodeFont`, `HeadingFonts[Level]`, `TextColor`,
`BackgroundColor`, `LinkColor`, `CodeTextColor`, `CodeBackgroundColor`,
`BlockQuoteBarColor`, `TableHeaderBackgroundColor`, `TableBorderColor`,
`ThematicBreakColor`, `ParagraphSpacing`, `ListIndent`, `ContentPadding`, the
`Chart*` colours and `ChartPalette`, and `TokenColors[Kind]` for code
highlighting. Colours are `TLayoutColor` (`$AARRGGBB`).

`SaveToJson` / `LoadFromJson` serialise a complete theme so you can ship it as a
resource or let users edit it.

```pascal
uses
  Markdown4D.Theme;

const Theme = TMarkdownTheme.CreateDark;
try
  Theme.LinkColor := $FF3B82F6;
  const Json = Theme.SaveToJson;
finally
  Theme.Free;
end;
```

## Incremental parser

Units `Markdown4D` and `Markdown4D.Parser.Interfaces`.
`TMarkdown.CreateIncrementalParser` returns an `IMarkdownIncrementalParser` that
keeps state between edits and reparses only the affected region.

```pascal
type
  IMarkdownIncrementalParser = interface
    procedure Append(const Chunk: string);
    procedure ReplaceRange(const StartIndex, Count: Integer; const Replacement: string);
    function ToHtml: string;
  end;
```

`Append` adds text at the end (the streaming case); `ReplaceRange` edits an
existing region (the editor case); `ToHtml` renders the current document.

```pascal
uses
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Parser.Interfaces;

const Parser = TMarkdown.CreateIncrementalParser(TMarkdownDialect.Gfm);

Parser.Append('# Live'#10);
Parser.Append('More **text** streaming in.'#10);

const Html = Parser.ToHtml;
```

The viewer components use the same incremental machinery internally; see
[STREAMING.md](STREAMING.md).

## Viewer components

`TMarkdownViewer` renders markdown natively onto the control canvas — no browser.
The VCL control lives in `Markdown4D.Vcl.Viewer` (a `TCustomControl`); the FMX
control in `Markdown4D.Fmx.Viewer` (a `TControl`). Their public surface is the
same.

### Published properties

| Property | Type | Notes |
|----------|------|-------|
| `Text` | `string` | The whole markdown document as one value |
| `ThemePreset` | `TMarkdownThemePreset` | `Light` / `Dark`, editable in the Object Inspector |
| `Images` | `TMarkdownViewerImageSettings` | How image destinations are resolved and fetched (see below) |

### Public members

| Member | Description |
|--------|-------------|
| `Theme: TMarkdownTheme` | Assign a fully customised theme at run time (the control takes ownership) |
| `AppendMarkdown(const Markdown: string)` | Append text and repaint; thread-safe, debounced |
| `LoadFromFile(const FileName)` / `LoadFromStream(const Stream)` | Load a document |
| `FindText(const Needle): Boolean` | Scroll to the first match |
| `CopySelectionToClipboard` | Copy the current selection |
| `SelectedText: string` | The selected text |
| `ContentHeight: Integer` | Laid-out document height, for auto-sizing |
| `ScrollOffset: Single` | Read / set the vertical scroll position |
| `LayoutCount: Integer` | Advances on every relayout (first width, resize, arriving images), so a host can notice layout-derived state going stale |
| `DisplayList: IMarkdownDisplayList` | The rendered primitives, for advanced hosts |

### Events

| Event | Signature | Raised when |
|-------|-----------|-------------|
| `OnLinkClick` | `(const Sender: TObject; const Url: string)` | A link is clicked |
| `OnLinkHover` | `(const Sender: TObject; const Url: string)` | The hovered link changes (`''` on leave) |
| `OnResolveImage` | `(const Sender: TObject; const Url: string; const Picture/Bitmap; var Handled: Boolean)` | An image needs resolving; set `Handled` to supply it yourself |
| `OnRemoteImageRequest` | `(const Sender: TObject; const Url: string; var Allow: Boolean)` | About to fetch a remote image. `Allow` arrives holding `Images.AllowRemote`; clear it to refuse this address |
| `OnScroll` | `TNotifyEvent` | The scroll position changes |

The viewer loads `http(s)` images asynchronously and local images relative to
`Images.BaseUrl` or the loaded document's folder. Code blocks tagged `pascal`,
`sql`, `json` or `xml` are syntax-highlighted; `chart` blocks render as
graphics when the chart block override is registered (see
[EXTENSIONS.md](EXTENSIONS.md)).

The mouse wheel scrolls the control only while its content overflows;
otherwise the wheel passes through to the parent, so viewers stacked inside a
scroll box scroll the list they sit in. The VCL controls carry the native
window scrollbar; the FMX viewer and editor draw a draggable overlay thumb
whenever their content overflows.

### Image settings

Unit `Markdown4D.Viewer.ImageSettings`, republished by both viewer units.

| Property | Default | Notes |
|----------|---------|-------|
| `BaseUrl` | `''` | Resolves relative image destinations |
| `AllowRemote` | `True` | Whether `http(s)` destinations may be fetched at all |
| `MaxBytes` | 8 MB | Upper bound on one downloaded image; `0` removes the bound |
| `RestrictToDocumentFolder` | `False` | Keeps a relative path inside the document's own folder |

Opening a document fetches every remote image it names, which tells those hosts
that the document was read. An application showing documents it did not write
should decide what it wants here: clear `AllowRemote` to fetch nothing, or leave
it on and refuse individual addresses through `OnRemoteImageRequest`.

```pascal
procedure TMainForm.ViewerRemoteImageRequest(const Sender: TObject; const Url: string;
  var Allow: Boolean);
begin
  Allow := Url.StartsWith('https://cdn.example.com/', True);
end;
```

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

## Editor components

`TMarkdownEditor` is a syntax-highlighting source editor for markdown. The VCL
control lives in `Markdown4D.Vcl.Editor`, the FMX control in
`Markdown4D.Fmx.Editor`.

### Published properties

| Property | Type | Notes |
|----------|------|-------|
| `Text` | `string` | The markdown source |
| `ThemePreset` | `TMarkdownThemePreset` | `Light` / `Dark` |
| `ShowLineNumbers` | `Boolean` | Gutter line numbers (default `False`) |

### Public members

| Member | Description |
|--------|-------------|
| `CaretPosition: Integer` | Read / set the caret offset |
| `SelectedText: string` | The current selection |
| `Theme: TMarkdownTheme` | Assign a custom theme at run time |
| `ExecuteCommand(const Command: TEditorCommand)` | Apply `Bold`, `Italic`, `Link` or `CodeBlock` to the selection |
| `Undo` / `Redo` / `CanUndo` / `CanRedo` | Undo stack |
| `AttachPreview(const Viewer: TMarkdownViewer)` / `DetachPreview` | Bind a live preview viewer |
| `FlushPreview` | Force a pending preview refresh immediately |

### Events

| Event | Signature | Raised when |
|-------|-----------|-------------|
| `OnChange` | `TNotifyEvent` | The text changes |
| `OnScroll` | `TNotifyEvent` | The editor scrolls |

`AttachPreview` wires the editor to a `TMarkdownViewer`: edits refresh the
preview on a short debounce, and the preview keeps its scroll aligned with the
editor's first visible source line.

```pascal
uses
  Markdown4D.Vcl.Editor,
  Markdown4D.Vcl.Viewer;

FEditor.AttachPreview(FPreview);
FEditor.Text := '# Live preview'#10#10 + 'Type on the left, rendered on the right.';
```

## Drawing SVG

The viewers render SVG images with an engine of this project. Nothing has to be
switched on for that: adding a viewer to a form brings it along.

`Markdown4D.Image.Svg` is the hook the viewers route image bytes through, and
`Markdown4D.Image.Svg.Native` is the engine registered on it:

```pascal
uses
  Markdown4D.Image.Svg,
  Markdown4D.Image.Svg.Native;

// Draws with this engine alone, reporting False for anything it will not draw
// rather than passing it on. TMarkdownSvgSupport.TryRasterize goes through
// whichever engine is registered.
var Raster: TMarkdownSvgRaster;
if TryRasterizeSvgNatively(Bytes, 200, 200, Raster) then
  // Raster.Pixels is premultiplied BGRA, top down, stride = Width * 4.
```

Covered: `path`, `rect` with corner radii, `circle`, `ellipse`, `line`,
`polyline`, `polygon`, `g`, `use`, `svg` with a `viewBox`, transform lists,
solid fills, linear and radial gradients, patterns, strokes with miter and
round joins and caps, opacity, both fill rules, `clipPath`, `mask`, `image`
carrying a data URI, `text`, and filters built from `feGaussianBlur`,
`feOffset`, `feFlood`, `feComposite` and `feMerge`.

Refused whole, so a document is never drawn half right: `foreignObject`, an
image pointing outside the document, and any filter primitive not in that list.

Two units underneath are useful on their own. `Markdown4D.Image.Rasterizer`
fills polygons with anti-aliasing, one colour or a gradient or a tile, held
inside an optional mask. `Markdown4D.Image.Filters` holds the pixel operations
the filters are built from.

## Glyph outlines and image decoding

Two things drawing an SVG needs from the machine it runs on. Both sit behind a
seam, and both already have an answer on every platform, so an application
normally does nothing here.

```pascal
uses
  Markdown4D.Image.Glyphs;

// The outlines of a run of text, laid out from an origin at the baseline
// start. Registered by Markdown4D.Image.Glyphs.Gdi on Windows and by
// Markdown4D.Fmx.Glyphs everywhere FMX runs.
TMarkdownGlyphSupport.RegisterOutliner(
  function (const FamilyName: string; const PixelSize: Single; const Bold, Italic: Boolean;
    const Text: string; out Run: TMarkdownGlyphRun): Boolean
  begin
    // Run.Contours in the units of PixelSize, Run.Advance is the width.
  end);
```

```pascal
uses
  Markdown4D.Image.Decoder;

// Encoded image bytes to pixels. Registered by Markdown4D.Vcl.ImageDecoder and
// Markdown4D.Fmx.ImageDecoder, whichever the application already has.
TMarkdownImageDecoding.RegisterDecoder(
  function (const Data: TBytes; out Raster: TMarkdownPixelRaster): Boolean
  begin
  end);
```

Register your own to reach a font or a format the platform does not offer. A
provider registered before the viewer unit initialises keeps its place: the
bundled ones step aside when something is already there.
