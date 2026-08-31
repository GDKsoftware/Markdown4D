unit StreamingMarkdown.Demo;

// Framework-neutral pieces shared by the StreamingMarkdown chat demos
// (StreamingMarkdownVCL / StreamingMarkdownFMX): the chunking state machine and
// the sample answer. Each form keeps its own framework-specific controls,
// layout, timers and scrolling.

interface

type
  // Streams a fixed string out in chunks, remembering how far it has got.
  // The demo forms own the timer and the viewer; this only slices the text.
  TMarkdownStreamer = class
  private
    FText: string;
    FPosition: Integer;
  public
    // Loads the text and rewinds to the start.
    procedure Reset(const Text: string);
    // True while there is still text left to emit.
    function HasMore: Boolean;
    // Returns up to RequestedLength characters from the current position and
    // advances past them; clamps to what remains.
    function NextChunk(const RequestedLength: Integer): string;
  end;

// The canned markdown answer both chat demos stream out.
function BuildStreamingSampleAnswer: string;

implementation

uses
  System.Math;

{ TMarkdownStreamer }

procedure TMarkdownStreamer.Reset(const Text: string);
begin
  FText := Text;
  FPosition := 1;
end;

function TMarkdownStreamer.HasMore: Boolean;
begin
  Result := FPosition <= Length(FText);
end;

function TMarkdownStreamer.NextChunk(const RequestedLength: Integer): string;
begin
  const Remaining = Length(FText) - FPosition + 1;
  const ChunkLength = Min(Remaining, Max(0, RequestedLength));
  Result := Copy(FText, FPosition, ChunkLength);
  Inc(FPosition, ChunkLength);
end;

function BuildStreamingSampleAnswer: string;
begin
  Result :=
    '# Streaming Markdown'#10#10 +
    'This answer arrives in small chunks, the way an LLM response does. ' +
    'The viewer re-parses incrementally and repaints as the text grows.'#10#10 +
    '## Native rendering'#10#10 +
    'The layout engine paints **bold**, *italic*, `inline code` and ' +
    '[links](https://commonmark.org) directly on the canvas, without an embedded ' +
    'browser or an HTML round-trip.'#10#10 +
    '## Comparison'#10#10 +
    '| Approach | Startup | Memory | Streaming |'#10 +
    '| --- | --- | --- | --- |'#10 +
    '| Embedded browser | Slow | High | Awkward |'#10 +
    '| HTML export | Fast | Low | Full reload |'#10 +
    '| Markdown4D viewer | Fast | Low | Incremental |'#10#10 +
    '## Example code'#10#10 +
    '```pascal'#10 +
    'procedure StreamAnswer(const Viewer: TMarkdownViewer; const Chunk: string);'#10 +
    'begin'#10 +
    '  Viewer.AppendMarkdown(Chunk);'#10 +
    'end;'#10 +
    '```'#10#10 +
    '## Roadmap'#10#10 +
    '- [x] Incremental parser'#10 +
    '- [x] Debounced relayout'#10 +
    '- [x] Async image loading'#10 +
    '- [x] FMX viewer'#10#10 +
    'Images stream in asynchronously too:'#10#10 +
    '![Sample photo](https://picsum.photos/seed/streaming-markdown/280/140)'#10#10 +
    '## Live charts'#10#10 +
    'Charts arrive as fenced code blocks and upgrade to graphics the moment the fence closes:'#10#10 +
    '```json'#10 +
    '{"type":"chart","data":{"type":"bar","data":{"labels":["Q1","Q2","Q3","Q4"],' +
    '"datasets":[{"label":"Revenue","data":[12,19,14,23],"backgroundColor":"#4E79A7"},' +
    '{"label":"Costs","data":[8,11,9,15],"backgroundColor":"#F28E2B"}]},' +
    '"options":{"plugins":{"title":{"display":true,"text":"Quarterly Performance"},' +
    '"legend":{"position":"bottom"}}}}}'#10 +
    '```'#10#10 +
    'And a doughnut breakdown of where the traffic comes from:'#10#10 +
    '```json'#10 +
    '{"type":"chart","data":{"type":"doughnut","data":{"labels":["Desktop","Mobile","Tablet"],' +
    '"datasets":[{"data":[55,35,10],"backgroundColor":["#4E79A7","#F28E2B","#E15759"]}]},' +
    '"options":{"plugins":{"title":{"display":true,"text":"Traffic by Device"},' +
    '"legend":{"position":"right"}}}}}'#10 +
    '```'#10#10 +
    '## Live diagrams'#10#10 +
    'Mermaid fences upgrade to native diagrams the same way. A flowchart of the request path:'#10#10 +
    '```mermaid'#10 +
    'flowchart LR'#10 +
    '  Prompt[Prompt] --> Model{Model}'#10 +
    '  Model -->|tokens| Stream([Stream chunks])'#10 +
    '  Stream --> Render'#10 +
    '```'#10#10 +
    'And a sequence diagram of the streaming handshake:'#10#10 +
    '```mermaid'#10 +
    'sequenceDiagram'#10 +
    '  participant User'#10 +
    '  participant Client'#10 +
    '  participant Server'#10 +
    '  User->>Client: Ask question'#10 +
    '  Client->>Server: Send prompt'#10 +
    '  Server-->>Client: Stream tokens'#10 +
    '  Client-->>User: Render answer'#10 +
    '```'#10#10 +
    '> Try selecting text while the answer is still streaming - the selection survives relayouts.'#10#10 +
    'Read more in the [CommonMark spec](https://spec.commonmark.org) or the ' +
    '[GFM spec](https://github.github.com/gfm/).'#10;
end;

end.
