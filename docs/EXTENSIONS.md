# Writing Markdown4D extensions

Markdown4D is extensible at two layers:

1. **Parsing and HTML rendering** — add syntax and output through the pipeline
   builder. An extension implements `IMarkdownExtension` and registers parsers,
   delimiter processors, renderer hooks or document processors.
2. **Native (canvas) rendering** — teach the VCL / FMX viewer to draw a block
   itself through an `ILayoutBlockOverride`.

This guide walks the bundled `==mark==` extension as the parsing example, then
the chart extension as the custom-rendering reference.

## Part 1 — a parser extension: `==mark==`

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
  MarkPriority = 50;

procedure TMarkExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterDelimiterProcessor(TMarkDelimiterProcessor.Create, MarkPriority);
  Pipeline.RegisterRendererHook(TMarkRendererHook.Create, MarkPriority);
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

## Part 2 — a custom-rendering extension: charts

HTML rendering is not always the goal. The chart extension turns a fenced code
block of chart JSON into a real bar / line / pie / doughnut graphic drawn
directly on the viewer canvas. It combines three pieces:

1. a **document processor** that recognises chart code blocks and stashes a
   parsed model on the node via the **extension-data channel**;
2. an **`ILayoutBlockOverride`** that claims those nodes during layout and emits
   drawing primitives — including the **wedge** primitive for pie slices;
3. registration of both, at parse time and at layout time.

### The data channel

Every `IMarkdownNode` carries a keyed slot for interface payloads —
`SetExtensionData(Key, Data)` and `TryGetExtensionData(Key, out Data)`. The
chart document processor parses the JSON once and caches the resulting
`IChartModel` on the node, so layout never re-parses:

```pascal
class procedure TChartExtension.Process(const Document: IMarkdownDocument);
// walks the tree; for each fenced code block that parses as chart JSON:
//   Node.SetExtensionData(ChartModelExtensionKey, Model);
```

The block override reads it back:

```pascal
class function TChartExtension.TryGetModel(const Node: IMarkdownNode;
  out Model: IChartModel): Boolean;
begin
  Model := nil;
  if Node = nil then
    Exit(False);

  var Data: IInterface;
  Result := Node.TryGetExtensionData(ChartModelExtensionKey, Data)
    and Supports(Data, IChartModel, Model);
end;
```

Use this channel for any per-node state an extension computes once and consumes
later. Key it with a unique string (the chart extension uses
`'markdown4d.chart.model'`).

### The block-override contract

Unit `Markdown4D.Layout.BlockOverride`. An override decides which nodes it
handles and lays them out by emitting primitives through the context:

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

`Handles` returns `True` for nodes this override owns. `LayoutBlock` receives the
node, the `Top` at which it must lay out, and a context exposing the available
`Width`, the active `Theme`, and a text `Measurer`. It emits primitives and
returns the block's height. The context emit methods:

| Method | Draws |
|--------|-------|
| `EmitRectangle(Bounds, FillColor, StrokeColor, StrokeWidth)` | A filled / stroked rectangle |
| `EmitTextRun(TopLeft, Text, Font, Color)` | A run of text |
| `EmitLine(StartPoint, EndPoint, Color, StrokeWidth)` | A straight line (axes, gridlines) |
| `EmitWedge(Center, OuterRadius, InnerRadius, StartAngle, SweepAngle, Color)` | An annular wedge — the pie / doughnut slice primitive |

`EmitWedge` is the reason charts render natively: a pie slice is a wedge with
`InnerRadius = 0`; a doughnut slice keeps a positive inner radius. Angles are in
degrees.

Here is a complete, self-contained override that draws a framed block with a
half-doughnut gauge and a caption — exercising rectangle, wedge and text:

```pascal
unit Sample.GaugeOverride;

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.BlockOverride;

type
  TGaugeBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  public
    const
      OverrideName = 'demo.gauge';
      OverridePriority = 100;
    class var
      FRegistered: Boolean;
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single;
      const Context: ILayoutBlockContext): Single;
    class procedure RegisterOverride;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Layout.Engine;

const
  BlockHeight = 120.0;
  BorderStrokeWidth = 1.0;
  GaugeInfoString = 'gauge';

class procedure TGaugeBlockOverride.RegisterOverride;
begin
  if FRegistered then
    Exit;

  TMarkdownLayoutEngine.RegisterBlockOverride(TGaugeBlockOverride.Create, OverridePriority);
  FRegistered := True;
end;

function TGaugeBlockOverride.GetName: string;
begin
  Result := OverrideName;
end;

function TGaugeBlockOverride.Handles(const Node: IMarkdownNode): Boolean;
begin
  var Code: IMarkdownCodeBlock;
  Result := Supports(Node, IMarkdownCodeBlock, Code) and Code.IsFenced
    and (Code.InfoString = GaugeInfoString);
end;

function TGaugeBlockOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
begin
  const Bounds = TLayoutRectF.Create(0, Top, Context.Width, Top + BlockHeight);
  Context.EmitRectangle(Bounds, Context.Theme.CodeBackgroundColor,
    Context.Theme.TableBorderColor, BorderStrokeWidth);

  const Center = TLayoutPointF.Create(Context.Width / 2, Top + BlockHeight);
  Context.EmitWedge(Center, 90, 45, 180, 180, Context.Theme.LinkColor);

  Context.EmitTextRun(TLayoutPointF.Create(Bounds.Left + 8, Top + 8), 'Gauge',
    Context.Theme.BaseFont, Context.Theme.TextColor);

  Result := BlockHeight;
end;

end.
```

The shipped `TChartBlockOverride` (unit `Markdown4D.Extensions.Chart.BlockOverride`)
follows the same shape but delegates its geometry to `TChartLayouter`, which
builds axes, bars, lines, legends and wedges from the cached `IChartModel`.

### Registration

Charts need registration in two places:

- **Parse time** — install `TChartExtension` in the pipeline so chart models are
  parsed and cached once, and layout never re-parses. This is optional: the block
  override also parses on demand, so the viewer still renders charts even though
  its internal GFM pipeline (`UseGfm`) does not register the chart extension.
- **Layout time** — register the block override once per process before the
  viewer lays out:

```pascal
uses
  Markdown4D.Extensions.Chart.BlockOverride;

TChartBlockOverride.RegisterOverride;
```

`RegisterOverride` is idempotent — it guards with a class flag, so calling it
from several forms is harmless.

### Priorities and resolution

Both the pipeline and the block-override registry resolve by **priority, then
registration order**: the highest priority wins, and among equal priorities the
first registered wins. Give an override a higher priority than any it must beat;
the built-in list rendering, for example, is the default a chart override
supersedes for code-block nodes.

## Part 3 — the bundled mermaid extension

The mermaid extension follows the exact shape of the chart extension: a code
block whose info string is `mermaid` (the GitHub convention) is parsed into an
`IMermaidModel` and drawn natively by a block override
(`TMermaidBlockOverride`, unit `Markdown4D.Extensions.Mermaid.BlockOverride`).
The AST keeps the block as a plain fenced code block, the HTML renderer emits a
normal `<pre><code class="language-mermaid">` (browsers render mermaid
themselves), and the markdown writer preserves the source byte-for-byte. Nothing
is ever evaluated as code.

### Supported subset

| Diagram | Header | What renders |
|---------|--------|--------------|
| Flowchart | `flowchart` / `graph` + `TD` `TB` `LR` `BT` `RL` | Node shapes `id[rect]`, `id(rounded)`, `id([stadium])`, `id((circle))`, `id{diamond}`; edges `-->` `---` `-.->` `==>` with `\|labels\|`; quoted / unicode labels; ranked layout with arrowheads |
| Sequence | `sequenceDiagram` | `participant` / `actor` declarations (and implicit); messages `->>` `-->>` `-x` `->` (solid / dashed, arrow / open / cross heads); `activate` / `deactivate` via `+` / `-`; `Note left of` / `right of` / `over` |
| Pie | `pie` (+ optional `title`) | `"label" : value` slices as one wedge each, legend and percentage labels |

### Fallback rules — never an exception

The override claims a node **only when a model parses**, so anything outside the
subset degrades to an ordinary highlighted code block instead of raising:

- an unknown diagram type (`gantt`, `classDiagram`, `stateDiagram`, …);
- a parse error anywhere in the body;
- a flowchart above the 500-node ceiling.

Streaming is handled at parse time, not in the override. On the pipeline path the
document processor caches a model **only for a closed fence** (`IsClosedFence` in
`TMermaidExtension.Process`), so while a fence is still streaming no model is
cached and the block stays an ordinary code block until the closing fence
arrives. Note that this closed-fence gate is a property of the document
processor: the viewer's on-demand override (see below) parses whatever the block
currently holds, so a syntactically valid partial diagram can render in the
native viewer before its fence closes.

`TMermaidExtension.TryGetModel` reads back a cached model, and the override falls
back to parsing on demand — the same two-step the chart override uses. Consumers
can inspect the parsed model directly:

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

### Registration

Like charts, register the block override once per process before the viewer
lays out — it is idempotent:

```pascal
uses
  Markdown4D.Extensions.Mermaid.BlockOverride;

TMermaidBlockOverride.RegisterOverride;
```

The arrowheads and diamond nodes are filled polygons, so the block-override
context also exposes `EmitPolygon(Points, Color)` alongside the rectangle, text,
line and wedge emitters.

## Lifetime and threading rules

- **Extensions are stateless and reusable.** `Setup` runs once when the pipeline
  is built. Keep per-parse state out of the extension object; use the node
  extension-data channel for per-node state.
- **Register block overrides once.** The registry is process-wide and static.
  Guard registration with a flag (as `RegisterOverride` does) so repeated calls
  are no-ops. There is no automatic unregister; overrides live for the process.
- **Layout runs on the UI thread.** `LayoutBlock` is called during the viewer's
  layout pass. Do only measuring and primitive emission there — no blocking I/O,
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

**Don't**

- Don't raise exceptions out to the host from a hook or override on bad input —
  a single malformed block would break the whole render. Detect and degrade.
- Don't cache mutable state on the extension instance across parses.
- Don't perform I/O or long work inside `LayoutBlock`.
- Don't assume your override is the only one; pick a priority deliberately.
