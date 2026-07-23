unit StreamingMarkdownVCL.Main;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Markdown4D.Vcl.Viewer;

type
  TStreamingMarkdownVCLForm = class(TForm)
  private
    const
      WindowCaption = 'Markdown4D LLM Chat Demo';
      InitialClientWidth = 760;
      InitialClientHeight = 680;
      InputPanelHeight = 44;
      ControlMargin = 8;
      SendButtonWidth = 80;
      SendButtonCaption = 'Send';
      MessageMargin = 8;
      MessageHeightPadding = 12;
      MinMessageHeight = 40;
      MinChunkLength = 30;
      MaxChunkLength = 80;
      MinTickMilliseconds = 30;
      MaxTickMilliseconds = 60;
      LayoutTickMilliseconds = 100;
      StackToBottomTop = 1000000;
      UserMessagePrefix = '**You:**'#10#10;
    var
      FMessagesBox: TScrollBox;
      FInputPanel: TPanel;
      FInputEdit: TEdit;
      FSendButton: TButton;
      FStreamTimer: TTimer;
      FLayoutTimer: TTimer;
      FMessageViewers: TList<TMarkdownViewer>;
      FStreamingViewer: TMarkdownViewer;
      FCannedResponse: string;
      FStreamPosition: Integer;
    procedure BuildMessagesBox;
    procedure BuildInputPanel;
    procedure BuildTimers;
    procedure HandleSendClick(Sender: TObject);
    procedure HandleInputEditKeyPress(Sender: TObject; var Key: Char);
    procedure SendPrompt;
    function AddMessageViewer(const Markdown: string): TMarkdownViewer;
    procedure StartStreaming;
    procedure HandleStreamTimer(Sender: TObject);
    procedure AppendNextChunk;
    procedure FinishStreaming;
    procedure HandleLayoutTimer(Sender: TObject);
    procedure SyncMessageHeights;
    procedure ScrollMessagesToBottom;
    class function BuildCannedResponse: string;

  public
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
  end;

var
  StreamingMarkdownVCLForm: TStreamingMarkdownVCLForm;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D.Extensions.Chart.BlockOverride,
  Markdown4D.Extensions.Mermaid.BlockOverride;

constructor TStreamingMarkdownVCLForm.Create(Owner: TComponent);
begin
  inherited CreateNew(Owner);

  TChartBlockOverride.RegisterOverride;
  TMermaidBlockOverride.RegisterOverride;

  Caption := WindowCaption;
  ClientWidth := InitialClientWidth;
  ClientHeight := InitialClientHeight;
  Position := TPosition.poScreenCenter;

  Randomize;
  FMessageViewers := TList<TMarkdownViewer>.Create;
  FCannedResponse := BuildCannedResponse;

  BuildMessagesBox;
  BuildInputPanel;
  BuildTimers;
end;

procedure TStreamingMarkdownVCLForm.BuildMessagesBox;
begin
  FMessagesBox := TScrollBox.Create(Self);
  FMessagesBox.Parent := Self;
  FMessagesBox.Align := alClient;
  FMessagesBox.VertScrollBar.Tracking := True;
  FMessagesBox.BorderStyle := bsNone;
end;

procedure TStreamingMarkdownVCLForm.BuildInputPanel;
begin
  FInputPanel := TPanel.Create(Self);
  FInputPanel.Parent := Self;
  FInputPanel.Align := alBottom;
  FInputPanel.Height := InputPanelHeight;
  FInputPanel.BevelOuter := bvNone;
  FInputPanel.ShowCaption := False;

  FSendButton := TButton.Create(Self);
  FSendButton.Parent := FInputPanel;
  FSendButton.Align := alRight;
  FSendButton.AlignWithMargins := True;
  FSendButton.Margins.SetBounds(0, ControlMargin, ControlMargin, ControlMargin);
  FSendButton.Width := SendButtonWidth;
  FSendButton.Caption := SendButtonCaption;
  FSendButton.OnClick := HandleSendClick;

  FInputEdit := TEdit.Create(Self);
  FInputEdit.Parent := FInputPanel;
  FInputEdit.Align := alClient;
  FInputEdit.AlignWithMargins := True;
  FInputEdit.Margins.SetBounds(ControlMargin, ControlMargin, ControlMargin, ControlMargin);
  FInputEdit.TextHint := 'Ask something...';
  FInputEdit.OnKeyPress := HandleInputEditKeyPress;
end;

procedure TStreamingMarkdownVCLForm.BuildTimers;
begin
  FStreamTimer := TTimer.Create(Self);
  FStreamTimer.Enabled := False;
  FStreamTimer.Interval := MinTickMilliseconds;
  FStreamTimer.OnTimer := HandleStreamTimer;

  FLayoutTimer := TTimer.Create(Self);
  FLayoutTimer.Interval := LayoutTickMilliseconds;
  FLayoutTimer.OnTimer := HandleLayoutTimer;
end;

procedure TStreamingMarkdownVCLForm.HandleSendClick(Sender: TObject);
begin
  SendPrompt;
end;

procedure TStreamingMarkdownVCLForm.HandleInputEditKeyPress(Sender: TObject; var Key: Char);
begin
  if Key <> #13 then
    Exit;

  Key := #0;
  if FSendButton.Enabled then
    SendPrompt;
end;

procedure TStreamingMarkdownVCLForm.SendPrompt;
begin
  const Prompt = Trim(FInputEdit.Text);
  if Prompt = '' then
    Exit;

  AddMessageViewer(UserMessagePrefix + Prompt);
  FInputEdit.Text := '';
  StartStreaming;
end;

function TStreamingMarkdownVCLForm.AddMessageViewer(const Markdown: string): TMarkdownViewer;
begin
  Result := TMarkdownViewer.Create(Self);
  Result.Parent := FMessagesBox;
  Result.Top := StackToBottomTop;
  Result.Align := alTop;
  Result.AlignWithMargins := True;
  Result.Margins.SetBounds(MessageMargin, MessageMargin, MessageMargin, 0);
  Result.Height := MinMessageHeight;
  Result.Text := Markdown;

  FMessageViewers.Add(Result);
end;

procedure TStreamingMarkdownVCLForm.StartStreaming;
begin
  FStreamingViewer := AddMessageViewer('');
  FStreamPosition := 1;
  FSendButton.Enabled := False;
  FStreamTimer.Interval := MinTickMilliseconds;
  FStreamTimer.Enabled := True;
end;

procedure TStreamingMarkdownVCLForm.HandleStreamTimer(Sender: TObject);
begin
  const IsFinished = FStreamPosition > Length(FCannedResponse);
  if IsFinished then
  begin
    FinishStreaming;
    Exit;
  end;

  AppendNextChunk;
end;

procedure TStreamingMarkdownVCLForm.AppendNextChunk;
begin
  const Remaining = Length(FCannedResponse) - FStreamPosition + 1;
  const ChunkLength = Min(Remaining, MinChunkLength + Random(MaxChunkLength - MinChunkLength + 1));
  FStreamingViewer.AppendMarkdown(Copy(FCannedResponse, FStreamPosition, ChunkLength));
  Inc(FStreamPosition, ChunkLength);

  FStreamTimer.Interval := MinTickMilliseconds + Random(MaxTickMilliseconds - MinTickMilliseconds + 1);
end;

procedure TStreamingMarkdownVCLForm.FinishStreaming;
begin
  FStreamTimer.Enabled := False;
  FStreamingViewer := nil;
  FSendButton.Enabled := True;
  FInputEdit.SetFocus;
end;

procedure TStreamingMarkdownVCLForm.HandleLayoutTimer(Sender: TObject);
begin
  SyncMessageHeights;

  if FStreamingViewer <> nil then
    ScrollMessagesToBottom;
end;

procedure TStreamingMarkdownVCLForm.SyncMessageHeights;
begin
  for var Viewer in FMessageViewers do
  begin
    const DesiredHeight = Max(MinMessageHeight, Viewer.ContentHeight + MessageHeightPadding);
    if Viewer.Height <> DesiredHeight then
      Viewer.Height := DesiredHeight;
  end;
end;

procedure TStreamingMarkdownVCLForm.ScrollMessagesToBottom;
begin
  FMessagesBox.VertScrollBar.Position := FMessagesBox.VertScrollBar.Range;
end;

class function TStreamingMarkdownVCLForm.BuildCannedResponse: string;
begin
  Result :=
    '# Streaming Markdown'#10#10 +
    'Here is a rich answer that arrives in small chunks, exactly like an LLM response. ' +
    'The viewer re-parses incrementally and repaints as the text grows.'#10#10 +
    '## Why native rendering?'#10#10 +
    'No embedded browser, no HTML round-trip: the layout engine paints **bold**, *italic*, ' +
    '`inline code` and [links](https://commonmark.org) directly on the canvas.'#10#10 +
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
    '- [ ] FMX viewer'#10#10 +
    'Images stream in asynchronously too:'#10#10 +
    '![Sample photo](https://picsum.photos/seed/StreamingMarkdownVCL/280/140)'#10#10 +
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

destructor TStreamingMarkdownVCLForm.Destroy;
begin
  FMessageViewers.Free;

  inherited Destroy;
end;

end.
