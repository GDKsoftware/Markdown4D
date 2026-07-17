# Streaming markdown into the viewer

Markdown4D is built for text that arrives a little at a time — most obviously an
LLM response that streams token by token. This guide covers the streaming API
of `TMarkdownViewer`: `AppendMarkdown`, the debounce and auto-follow behaviour,
the threading contract, how chart blocks behave mid-stream, and what the `Text`
property means while data is still arriving.

Everything here applies to both the VCL viewer (`Markdown4D.Vcl.Viewer`) and the
FMX viewer (`Markdown4D.Fmx.Viewer`) — the streaming surface is identical.

## `AppendMarkdown`

```pascal
procedure AppendMarkdown(const Markdown: string);
```

Call it with each new chunk. The viewer appends the chunk to its pending buffer
and schedules a repaint; it reparses incrementally, so cost scales with what
changed, not with the whole document.

```pascal
procedure TChatForm.OnTokenReceived(const Token: string);
begin
  FAnswerViewer.AppendMarkdown(Token);
end;
```

Chunks need not fall on any boundary. A chunk may split a word, a `**bold**`
span, a fenced code block or a table row; the incremental parser reconciles
partial constructs as later chunks complete them.

To start a fresh message, create (or reuse) a viewer and either set `Text := ''`
or set the initial content, then stream into it. Setting `Text` replaces the
document and resets the pending buffer.

## Debounce and auto-follow

Streaming can deliver dozens of chunks per second. Relaying out on every chunk
would be wasteful, so the viewer **coalesces** appends: after the first pending
chunk it waits a short debounce interval (~100 ms) and then flushes everything
accumulated so far in one reparse-and-repaint. A burst of chunks becomes a
handful of relayouts per second, and the control stays responsive.

You do not drive the debounce — an internal timer flushes pending text and
disables itself once the buffer is drained. Just keep calling `AppendMarkdown`.

**Auto-follow.** At each flush the viewer checks whether you were scrolled to the
bottom. If you were, it scrolls to the new bottom so the latest text stays in
view; if you had scrolled up to read earlier content, it leaves your position
alone. Streaming never yanks the viewport away from the reader.

**Selection survives.** Selections are tracked as text positions, not pixels, so
a selection made mid-stream remains valid across the relayouts that follow.

## Threading contract

LLM clients usually deliver tokens on a background thread. `AppendMarkdown` (and
`Text`, `LoadFromFile`, `LoadFromStream`) are **safe to call from any thread** —
if called off the UI thread they marshal themselves onto it, so you never touch
VCL/FMX state from a worker.

```pascal
procedure StreamFromThread(const Viewer: TMarkdownViewer; const Tokens: TArray<string>);
begin
  TThread.CreateAnonymousThread(
    procedure
    begin
      for var Token in Tokens do
        Viewer.AppendMarkdown(Token);
    end).Start;
end;
```

The marshalled call is guarded by the viewer's lifetime: if the control is
destroyed while chunks are still in flight, the queued work is dropped instead
of touching a freed control. You do not need to stop the stream before closing
the form.

Because the marshal is asynchronous (`TThread.Queue`), an `AppendMarkdown` call
from a worker returns immediately and the append is applied on the next UI-thread
turn. Order is preserved: chunks apply in the order you call them.

## Chart blocks during streaming

Charts arrive as fenced code blocks of chart JSON. While the closing fence has
not yet streamed in, the block is simply an incomplete fenced code block and
renders as code. The moment the closing fence arrives and the block parses as a
valid chart model, it upgrades in place to a native bar / line / pie / doughnut
graphic on the next flush.

For that upgrade to render as graphics rather than code, register the chart
block override once at startup:

```pascal
uses
  Markdown4D.Extensions.Chart.BlockOverride;

TChartBlockOverride.RegisterOverride;
```

Chart parsing is part of the viewer's built-in GFM pipeline, so no pipeline
wiring is required — only the layout-time override registration above. See
[EXTENSIONS.md](EXTENSIONS.md) for how the chart override is built. Partial or
malformed chart JSON degrades to a plain code block; it never breaks the stream.

## `Text` semantics while streaming

`Text` always reflects the **entire** document you have appended — the committed
text plus any pending chunk that has not been flushed yet. Reading `Text`
immediately after `AppendMarkdown`, before the next repaint, still returns the
full accumulated markdown.

```pascal
function FullDocument(const Viewer: TMarkdownViewer): string;
begin
  Result := Viewer.Text;
end;
```

This makes `Text` the right source of truth for persisting a message, copying
the raw markdown, or handing the finished document to another component when the
stream ends — there is no separate "pending" text to reconcile.

`ContentHeight` reports the laid-out height and is handy for auto-sizing a
message bubble as it grows: read it after each flush (for example on `OnScroll`
or a low-frequency timer) and resize the host control to
`Max(MinHeight, Viewer.ContentHeight + Padding)`.

## Putting it together

A minimal streaming message viewer:

```pascal
procedure StreamToken(const Viewer: TMarkdownViewer; const Token: string);
begin
  Viewer.AppendMarkdown(Token);
end;
```

- Create one `TMarkdownViewer` per message.
- Register `TChartBlockOverride.RegisterOverride` once at application start if
  you expect charts.
- Feed tokens with `AppendMarkdown` from wherever they arrive — worker thread or
  UI thread, in any chunk size.
- Let the viewer debounce, reparse, repaint and auto-follow.
- Read `Text` for the finished markdown when the stream completes.

The `LlmChat` and `FmxLlmChat` examples implement exactly this pattern,
including streaming charts and asynchronous image loading.
