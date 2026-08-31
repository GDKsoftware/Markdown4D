# Writing Markdown4D extensions

Markdown4D is extensible at two layers:

1. Parsing and HTML rendering: an extension implements `IMarkdownExtension`
   and registers parsers, delimiter processors, renderer hooks or document
   processors through the pipeline builder.
2. Native (canvas) rendering: an `ILayoutBlockOverride` teaches the VCL / FMX
   viewer to draw a block itself, painting onto the neutral
   `IExtensionCanvas`.

This guide walks three worked examples, all built purely on the public API:

- the sample `==mark==` extension (unit `Markdown4D.Extensions.Sample`), the
  parser reference. It is opt-in through `Use(TMarkExtension.Create)` and not
  auto-registered by `UseGfm`;
- an admonition extension, the custom-rendering walkthrough, combining a
  document processor, the node extension-data channel and a canvas block
  override;
- the shipped chart and mermaid extensions, the bundled references that
  follow the same shape at full scale.

> Every registration point takes an integer
> priority. Use the named constants on `TMarkdownPriorities` (unit
> `Markdown4D.Extensions.Interfaces`) instead of bare numbers: `Highest`, `High`,
> `AboveNormal`, `Normal`, `BelowNormal`, `Low`, `Lowest`, and the extension
> slots `ExtensionParser` (block, inline and delimiter parsers),
> `ExtensionProcessor` (document processors), `ExtensionRenderer` (renderer hooks)
> and `ExtensionLayoutOverride` (canvas block overrides).

## Part 1: the `==mark==` parser extension

The goal: turn `==highlighted==` into `<mark>highlighted</mark>`. `==` is a
paired delimiter, so the natural tools are a **delimiter processor** (matches the
runs and produces a `mark` inline node) and a **renderer hook** (emits the HTML
for that node).

### The extension entry point

An extension is a class that configures the pipeline in `Setup`:

```pascal
unit Sample.MarkExtension;

interface

uses
  Markdown4D.Extensions.Interfaces;

type
  TMarkExtension = class(TInterfacedObject, IMarkdownExtension)
  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

implementation

uses
  Markdown4D.Ast.Interfaces;

type
  TMarkDelimiterProcessor = class(TInterfacedObject, IMarkdownDelimiterProcessor)
  public
    function GetDelimiterCharacter: Char;
    function GetMinimumLength: Integer;
    function GetNodeName: string;
  end;

  TMarkRendererHook = class(TInterfacedObject, IMarkdownRendererHook)
  public
    function GetNodeName: string;
    procedure RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
    procedure RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
  end;

const
  MarkNodeName = 'mark';
  MarkDelimiterCharacter = '=';
  MarkDelimiterMinimumLength = 2;
  MarkOpenTag = '<mark>';
  MarkCloseTag = '</mark>';

procedure TMarkExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterDelimiterProcessor(TMarkDelimiterProcessor.Create, TMarkdownPriorities.ExtensionParser);
  Pipeline.RegisterRendererHook(TMarkRendererHook.Create, TMarkdownPriorities.ExtensionRenderer);
end;
```

### The delimiter processor

The processor declares which character it handles, the minimum run length, and
the node name the matched pair produces. The core emphasis engine does the run
scanning and pairing; you only describe the delimiter.

```pascal
function TMarkDelimiterProcessor.GetDelimiterCharacter: Char;
begin
  Result := MarkDelimiterCharacter;
end;

function TMarkDelimiterProcessor.GetMinimumLength: Integer;
begin
  Result := MarkDelimiterMinimumLength;
end;

function TMarkDelimiterProcessor.GetNodeName: string;
begin
  Result := MarkNodeName;
end;
```

A matched pair becomes an `IMarkdownCustomInline` whose `NodeName` is `'mark'`,
with the delimited content as its children.

### The renderer hook

A renderer hook binds a node name to HTML. `RenderEnter` runs before the node's
children, `RenderLeave` after. Write through the supplied `IMarkdownHtmlWriter`:
`WriteRaw` for literal markup, `WriteEscaped` for text that must be HTML-safe.

```pascal
function TMarkRendererHook.GetNodeName: string;
begin
  Result := MarkNodeName;
end;

procedure TMarkRendererHook.RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
begin
  Writer.WriteRaw(MarkOpenTag);
end;

procedure TMarkRendererHook.RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
begin
  Writer.WriteRaw(MarkCloseTag);
end;
```

### Using it

```pascal
uses
  Markdown4D.Pipeline,
  Markdown4D.Extensions.Interfaces,
  Sample.MarkExtension;

const Pipeline = TMarkdownPipeline.Create
  .UseGfm
  .Use(TMarkExtension.Create)
  .UnsafeHtml
  .Build;

const Html = Pipeline.ToHtml('Highlight ==this== please.');
```

### The extension interfaces

All live in `Markdown4D.Extensions.Interfaces`.

| Interface | Purpose | Register with |
|-----------|---------|---------------|
| `IMarkdownExtension` | Bundles a set of registrations in `Setup` | `Use` |
| `IMarkdownBlockParser` | Starts a block from a trigger line | `RegisterBlockParser` |
| `IMarkdownInlineParser` | Parses inline syntax at a position | `RegisterInlineParser` |
| `IMarkdownDelimiterProcessor` | Pairs a run delimiter into a node | `RegisterDelimiterProcessor` |
| `IMarkdownRendererHook` | Emits HTML for a node name | `RegisterRendererHook` |
| `IMarkdownDocumentProcessor` | Post-processes the finished AST | `RegisterDocumentProcessor` |

Block and inline parsers register with a **trigger-character** string (the
characters that may begin the construct) and a **priority**. Delimiter
processors key off `DelimiterCharacter`; renderer hooks off `NodeName`.

When two delimiter processors claim the same `DelimiterCharacter` (for example a
new `=` extension registered alongside the sample `==mark==`), the pipeline
resolves the collision exactly as it does for renderer hooks and block overrides:
by **priority, then registration order**. The highest priority wins, and among
equal priorities the first registered wins. Register your processor above
`TMarkdownPriorities.ExtensionParser` if it must beat another extension for the
same character.

## Part 2: a custom-rendering walkthrough with admonitions

HTML rendering is not always the goal. This walkthrough builds a complete
extension that draws GitHub-style alert callouts (`> [!NOTE]`, `> [!WARNING]`, …)
as a coloured banner on the viewer canvas, using nothing but the public API. It
combines the three moving parts every native-rendering extension shares:

1. a **document processor** that recognises the construct and stashes a small
   payload on the node through the **extension-data channel**;
2. an **`ILayoutBlockOverride`** that claims those nodes during layout and draws
   them through the **`IExtensionCanvas`**;
3. registration in two places: the processor at parse time, the override at
   layout time.

The same three parts scale up to the shipped chart and mermaid extensions in
Part 3.

### The extension-data channel

Every `IMarkdownNode` carries a keyed slot for interface payloads:
`SetExtensionData(Key, Data)` and `TryGetExtensionData(Key, out Data)`. Use it
for any per-node state an extension computes once and consumes later. Key it with
a unique string.

The admonition payload is a tiny interface holding the alert kind:

```pascal
unit Sample.Admonition;

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Theme;

type
  IAdmonitionTag = interface
    ['{4F1B8C2A-7D63-4E09-9A15-2C6E5B0D3A88}']
    function GetKind: string;
    property Kind: string read GetKind;
  end;

  TAdmonitionExtension = class(TInterfacedObject, IMarkdownExtension)
  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

  TAdmonitionBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  strict private
    class var FRegistered: Boolean;
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
  public
    const
      OverrideName = 'sample.admonition';
      BannerHeight = 24.0;
    class procedure RegisterOverride;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Layout.Engine;

const
  ExtensionDataKey = 'sample.admonition.kind';
  KnownKinds: array[0..4] of string = ('NOTE', 'TIP', 'IMPORTANT', 'WARNING', 'CAUTION');
```

The concrete tag and a typed reader/writer pair keep the channel access in one
place:

```pascal
type
  TAdmonitionTag = class(TInterfacedObject, IAdmonitionTag)
  private
    FKind: string;
  public
    constructor Create(const Kind: string);
    function GetKind: string;
  end;

constructor TAdmonitionTag.Create(const Kind: string);
begin
  inherited Create;

  FKind := Kind;
end;

function TAdmonitionTag.GetKind: string;
begin
  Result := FKind;
end;

function TryGetAdmonitionKind(const Node: IMarkdownNode; out Kind: string): Boolean;
begin
  Kind := '';

  var Data: IInterface;
  if not Node.TryGetExtensionData(ExtensionDataKey, Data) then
    Exit(False);

  var Tag: IAdmonitionTag;
  Result := Supports(Data, IAdmonitionTag, Tag);
  if Result then
    Kind := Tag.Kind;
end;
```

### The document processor

An `IMarkdownDocumentProcessor` runs once over the finished AST. This one walks
the tree iteratively (never recurse an arbitrary-depth document), and for every
block quote whose first line is a known `[!KIND]` marker it caches a tag on the
node. It touches nothing else, so documents without alerts are unaffected.

```pascal
type
  TAdmonitionProcessor = class(TInterfacedObject, IMarkdownDocumentProcessor)
  private
    class function FirstLiteral(const BlockQuote: IMarkdownNode): string; static;
    class function TryMatchKind(const FirstLine: string; out Kind: string): Boolean; static;
  public
    procedure Process(const Document: IMarkdownDocument);
  end;

procedure TAdmonitionProcessor.Process(const Document: IMarkdownDocument);
begin
  const Pending = TStack<IMarkdownNode>.Create;
  try
    Pending.Push(Document);

    while Pending.Count > 0 do
    begin
      const Current = Pending.Pop;

      if Current.Kind = TMarkdownNodeKind.BlockQuote then
      begin
        var Kind: string;
        if TryMatchKind(FirstLiteral(Current), Kind) then
          Current.SetExtensionData(ExtensionDataKey, TAdmonitionTag.Create(Kind));
      end;

      for var Index := Current.ChildCount - 1 downto 0 do
      begin
        Pending.Push(Current.Children[Index]);
      end;
    end;
  finally
    Pending.Free;
  end;
end;

class function TAdmonitionProcessor.FirstLiteral(const BlockQuote: IMarkdownNode): string;
begin
  Result := '';

  if BlockQuote.ChildCount = 0 then
    Exit;

  const Paragraph = BlockQuote.Children[0];
  if (Paragraph.Kind <> TMarkdownNodeKind.Paragraph) or (Paragraph.ChildCount = 0) then
    Exit;

  var Text: IMarkdownText;
  if Supports(Paragraph.Children[0], IMarkdownText, Text) then
    Result := Text.Literal;
end;

class function TAdmonitionProcessor.TryMatchKind(const FirstLine: string; out Kind: string): Boolean;
begin
  Kind := '';

  const Trimmed = FirstLine.Trim;
  const HasMarker = Trimmed.StartsWith('[!') and Trimmed.EndsWith(']');
  if not HasMarker then
    Exit(False);

  const Inner = Trimmed.Substring(2, Length(Trimmed) - 3);
  for var Known in KnownKinds do
  begin
    if Known = Inner then
    begin
      Kind := Inner;
      Exit(True);
    end;
  end;

  Result := False;
end;
```

The extension bundles the processor at the `ExtensionProcessor` priority:

```pascal
procedure TAdmonitionExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterDocumentProcessor(TAdmonitionProcessor.Create, TMarkdownPriorities.ExtensionProcessor);
end;
```

### The block-override contract

Unit `Markdown4D.Layout.BlockOverride`. An override decides which nodes it
handles and lays them out by drawing through the context's canvas:

```pascal
type
  ILayoutBlockOverride = interface
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single;
      const Context: ILayoutBlockContext): Single;
    property Name: string read GetName;
  end;
```

`Handles` returns `True` for nodes this override owns: here, block quotes the
processor tagged. `LayoutBlock` receives the node, the `Top` at which it must lay
out, and a context exposing the available `Width`, the active `Theme`, a text
`Measurer`, and the `Canvas`. It draws onto the canvas and returns the block's
height.

**The `Theme`** is a `TMarkdownTheme` (unit `Markdown4D.Theme`), the same record
the viewer paints the rest of the document with. Add `Markdown4D.Theme` to your
uses clause to name the type. Besides the members this example touches
(`CodeBackgroundColor`, `LinkColor`, `TextColor`, `BaseFont`) it exposes every
colour, font and metric the built-in blocks use: `BlockQuoteBarColor`,
`CodeFont`, `CodeTextColor`, `ContentPadding`, `ChartPalette`, `ChartTextColor`,
and the rest. Read `Markdown4D.Theme.pas` for the full member list, and prefer
theme members over hard-coded colours so your block tracks the light and dark
presets.

**Coordinate origin.** The context's coordinate space is local to the block. The
`Top` you receive is already inset by the theme's `ContentPadding` **vertically**,
so draw at the `Top` you are given. The **x** origin is `0`, and `Context.Width`
is the content width already reduced by the left content padding and the block's
own indent (`FWidth - ContentPadding - Command.X`); it is not the full page
width. Drawing conventionally starts at `x = 0` and fills to `Context.Width`, as
the shipped chart and mermaid overrides do. A block that fills `0..Width` therefore
sits flush with the left content edge but is not full-bleed on the right; it is not
horizontally inset to match body text, because `Top` is pre-padded while the x
origin is not.

```pascal
function TAdmonitionBlockOverride.GetName: string;
begin
  Result := OverrideName;
end;

function TAdmonitionBlockOverride.Handles(const Node: IMarkdownNode): Boolean;
begin
  const IsBlockQuote = (Node.Kind = TMarkdownNodeKind.BlockQuote);

  var Kind: string;
  Result := IsBlockQuote and TryGetAdmonitionKind(Node, Kind);
end;

function TAdmonitionBlockOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
begin
  var Kind: string;
  if not TryGetAdmonitionKind(Node, Kind) then
    Exit(0);

  const Canvas = Context.Canvas;
  const Bounds = TLayoutRectF.Create(0, Top, Context.Width, Top + BannerHeight);

  Canvas.FillAndStrokeRectangle(Bounds, Context.Theme.CodeBackgroundColor, Context.Theme.LinkColor, 1);
  Canvas.DrawText(TLayoutPointF.Create(0, Top), Kind, Context.Theme.BaseFont, Context.Theme.TextColor);

  Result := BannerHeight;
end;
```

### The canvas

`ILayoutBlockContext.Canvas` is an `IExtensionCanvas`, the single neutral
drawing surface. Its primitives:

| Method | Draws |
|--------|-------|
| `FillRectangle(Bounds, Color)` | A filled rectangle |
| `DrawRectangle(Bounds, StrokeColor, StrokeWidth)` | A stroked rectangle |
| `FillAndStrokeRectangle(Bounds, FillColor, StrokeColor, StrokeWidth)` | A filled and stroked rectangle in one primitive |
| `DrawText(TopLeft, Text, Font, Color)` | A run of text |
| `DrawLine(StartPoint, EndPoint, Color, StrokeWidth)` | A straight line (axes, gridlines, lifelines) |
| `DrawDashedLine(StartPoint, EndPoint, Color, StrokeWidth)` | A dashed line |
| `FillPolygon(Points, Color)` | A filled polygon (arrowheads) |
| `DrawPolygon(Points, StrokeColor, StrokeWidth)` | A stroked polygon |
| `FillAndStrokePolygon(Points, FillColor, StrokeColor, StrokeWidth)` | A filled and stroked polygon in one primitive (diamond, stadium and rounded nodes) |
| `FillWedge(Center, OuterRadius, InnerRadius, StartAngle, SweepAngle, Color)` | An annular wedge, the pie / doughnut slice primitive; angles in degrees |
| `DrawWedge(Center, OuterRadius, InnerRadius, StartAngle, SweepAngle, StrokeColor, StrokeWidth)` | A stroked wedge |
| `FillAndStrokeWedge(Center, OuterRadius, InnerRadius, StartAngle, SweepAngle, FillColor, StrokeColor, StrokeWidth)` | A filled and stroked wedge in one primitive (circle nodes) |
| `DrawImage(Bounds, Source, AltText)` | An image slot |
| `MeasureText(Text, Font)` | Measures without drawing |
| `SaveState` / `SetClip(Bounds)` / `RestoreState` | Push a clip region and pop it |

Each of the three shapes comes in the same three forms: fill, stroke, or both
at once. Reach for the combined one when a shape needs a fill and an outline,
so it stays a **single** display item and its bounds are never duplicated
across two primitives.

`FillWedge` is why charts render natively: a pie slice is a wedge with
`InnerRadius = 0`; a doughnut slice keeps a positive inner radius.

How smoothly a curve is drawn follows how large it is, so a shape asks for no
segment count of its own. On a canvas without anti-aliasing of its own the
painter fills and strokes through this project's rasterizer, which is why a
diamond has no staircase on its diagonals.

### Registration

The single most common mistake: **the viewer does not run your parse-time
pipeline.** `TMarkdownViewerModel` parses with a fixed
`TMarkdown.Parse(..., Gfm)` and then, at layout time, runs every processor
registered with the static `TLayoutDocumentProcessorRegistry` before it lays the
document out. An extension installed only into an `IMarkdownPipelineBuilder`
(through `Use`) never runs in the viewer, so its tag is never cached, `Handles`
returns `False`, and the banner never draws.

A native-rendering extension therefore registers in **two layout-time registries**,
both from a single guarded `RegisterOverride`:

- the **document processor** with `TLayoutDocumentProcessorRegistry.Register`, so
  the `[!KIND]` tag is cached on the node during the viewer's layout pass;
- the **block override** with `TMarkdownLayoutEngine.RegisterBlockOverride`, so
  the tagged node is claimed and drawn.

```pascal
class procedure TAdmonitionBlockOverride.RegisterOverride;
begin
  if FRegistered then
    Exit;

  TMarkdownLayoutEngine.RegisterBlockOverride(TAdmonitionBlockOverride.Create,
    TMarkdownPriorities.ExtensionLayoutOverride);
  TLayoutDocumentProcessorRegistry.Register(TAdmonitionProcessor.Create);

  FRegistered := True;
end;
```

Declare `class var FRegistered: Boolean;` (strict private) on the override so the
guard makes repeated calls from several forms harmless; the shipped chart and
mermaid overrides register in exactly this shape. `TAdmonitionExtension` (the
pipeline extension from Part 2) remains useful when you drive the HTML or AST
pipeline yourself, where it caches the tag at parse time; but it has no effect on
the viewer, which ignores author pipelines.

`RegisterBlockOverride` / `ClearBlockOverrides` and
`TLayoutDocumentProcessorRegistry.Register` / `.Clear` are the public front of the
two static layout registries in unit `Markdown4D.Layout.BlockOverride`
(`RegisterBlockOverride` / `ClearBlockOverrides` are surfaced on
`TMarkdownLayoutEngine`). Tests reset both with
`TMarkdownLayoutEngine.ClearBlockOverrides`, which clears the override registry
**and** the document-processor registry.

**Laying out without the viewer.** `TMarkdownLayoutEngine.LayoutDocument` does
**not** run `TLayoutDocumentProcessorRegistry.Process`; only
`TMarkdownViewerModel` does, immediately after it parses. If you lay out a freshly
parsed document directly through `LayoutDocument` (bypassing the viewer model),
run the processors yourself first, or the tagged nodes will not be cached and your
override will see nothing:

```pascal
const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
TLayoutDocumentProcessorRegistry.Process(Document);
const DisplayList = TMarkdownLayoutEngine.LayoutDocument(Document, Width, Theme, Measurer);
```

### Priorities and resolution

Both the pipeline and the block-override registry resolve by **priority, then
registration order**: the highest priority wins, and among equal priorities the
first registered wins. `ExtensionLayoutOverride` (100) sits above the built-in
block rendering an override supersedes; raise it further if you must beat another
override for the same node.

## Part 3: the bundled chart and mermaid extensions

The shipped chart and mermaid extensions are the same three parts at full scale.

### Charts

A fenced code block of chart JSON renders as a real bar / line / pie / doughnut
graphic. `TChartExtension` (unit `Markdown4D.Extensions.Chart`) is the document
processor: it parses the JSON once and caches an `IChartModel` on the node under
`'markdown4d.chart.model'`, so layout never re-parses. `TChartBlockOverride`
(unit `Markdown4D.Extensions.Chart.BlockOverride`) claims those nodes and
delegates its geometry to `TChartLayouter`, which builds axes, bars, lines,
legends and wedges onto the canvas.

Consumers can read the cached model back:

```pascal
uses
  System.SysUtils,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Chart;

function ChartKindName(const Node: IMarkdownNode): string;
begin
  var Model: IChartModel;
  if not TChartExtension.TryGetModel(Node, Model) then
    Exit('not a cached chart');

  Result := Format('chart with %d datasets', [Model.DatasetCount]);
end;
```

Chart registration mirrors the admonition, and for the same reason: the viewer's
fixed GFM pipeline does not register the chart extension, so charts render only
because `TChartBlockOverride.RegisterOverride` installs **both** halves at layout
time. It calls `TMarkdownLayoutEngine.RegisterBlockOverride` for the override
**and** `TLayoutDocumentProcessorRegistry.Register(TChartExtension.CreateDocumentProcessor)`
for the document processor. That processor, not any on-demand parse in the
override, is what runs during `TMarkdownViewerModel`'s layout pass and caches the
`IChartModel`; `TChartBlockOverride.Handles` then merely reads the cached model
back through `TChartExtension.TryGetModel` (no parsing). Installing
`TChartExtension` in an author pipeline is optional and only matters when you drive
the HTML or AST pipeline yourself. The single call is idempotent:

```pascal
uses
  Markdown4D.Extensions.Chart.BlockOverride;

TChartBlockOverride.RegisterOverride;
```

### Mermaid

A fenced code block whose info string is `mermaid` (the GitHub convention) is
parsed into an `IMermaidModel` and drawn natively by `TMermaidBlockOverride`
(unit `Markdown4D.Extensions.Mermaid.BlockOverride`). The AST keeps the block as
a plain fenced code block, the HTML renderer emits a normal
`<pre><code class="language-mermaid">` (browsers render mermaid themselves), and
the markdown writer preserves the source byte-for-byte. Nothing is ever
evaluated as code.

| Diagram | Header | What renders |
|---------|--------|--------------|
| Flowchart | `flowchart` / `graph` + `TD` `TB` `LR` `BT` `RL` | Node shapes `id[rect]`, `id(rounded)`, `id([stadium])`, `id((circle))`, `id{diamond}`; edges `-->` `---` `-.->` `==>` with `\|labels\|`; ranked layout with arrowheads |
| Sequence | `sequenceDiagram` | `participant` / `actor` declarations; messages `->>` `-->>` `-x` `->`; `activate` / `deactivate` via `+` / `-`; `Note left of` / `right of` / `over` |
| Pie | `pie` (+ optional `title`) | `"label" : value` slices as one wedge each, legend and percentage labels |

The override claims a node **only when a model
parses**, so anything outside the subset degrades to an ordinary highlighted code
block instead of raising: an unknown diagram type (`gantt`, `classDiagram`, …), a
parse error anywhere in the body, or a flowchart above the 500-node ceiling.

Streaming is handled by the document processor, which caches a model **only for a
closed fence**: while a fence is still streaming the block stays an ordinary code
block until its closing fence arrives. The viewer runs that same processor at
layout time, so the behaviour is identical on both paths: a partial diagram
renders as plain code and upgrades to a native diagram once its fence closes.

`TMermaidExtension.TryGetModel` reads back a cached model:

```pascal
uses
  System.SysUtils,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Mermaid;

function DescribeMermaid(const Node: IMarkdownNode): string;
begin
  var Model: IMermaidModel;
  if not TMermaidExtension.TryGetModel(Node, Model) then
    Exit('not a cached mermaid diagram');

  case Model.DiagramKind of
    TMermaidDiagramKind.Flowchart:
      Result := Format('flowchart: %d nodes, %d edges', [Model.NodeCount, Model.EdgeCount]);
    TMermaidDiagramKind.Sequence:
      Result := Format('sequence: %d participants, %d messages',
        [Model.ParticipantCount, Model.MessageCount]);
    TMermaidDiagramKind.Pie:
      Result := Format('pie: %d slices', [Model.SliceCount]);
  else
    Result := 'unknown';
  end;
end;
```

Mermaid registration is the same idempotent, layout-time call:

```pascal
uses
  Markdown4D.Extensions.Mermaid.BlockOverride;

TMermaidBlockOverride.RegisterOverride;
```

## Lifetime and threading rules

- Extensions are stateless and reusable. `Setup` runs once when the pipeline
  is built. Keep per-parse state out of the extension object; use the node
  extension-data channel for per-node state.
- Block overrides register once. The registry is process-wide and static.
  Guard registration with a flag so repeated calls are no-ops. There is no
  automatic unregister; overrides live for the process. Tests call
  `TMarkdownLayoutEngine.ClearBlockOverrides` to reset it.
- Layout runs on the UI thread. `LayoutBlock` is called during the viewer's
  layout pass. Do only measuring and primitive emission there: no blocking I/O,
  no network. Resolve data earlier (at parse time, into extension data).

## Do's and don'ts

**Do**

- Return an accurate height from `LayoutBlock`; the engine stacks the next block
  directly below it.
- Respect the `Theme` from the context for colours and fonts, so your block
  matches light and dark presets.
- Escape user text with `WriteEscaped` in renderer hooks.
- Fail soft: if your model is missing or malformed, lay out nothing (return `0`)
  or fall back to the default rendering rather than raising.
- Reach for `TMarkdownPriorities` constants instead of literal priority numbers.

**Don't**

- Don't raise exceptions out to the host from a hook or override on bad input;
  a single malformed block would break the whole render. Detect and degrade.
- Don't cache mutable state on the extension instance across parses.
- Don't perform I/O or long work inside `LayoutBlock`.
- Don't assume your override is the only one; pick a priority deliberately.
