unit FmxLlmChat.Main;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.UITypes,
  System.Generics.Collections,
  FMX.Forms,
  FMX.Types,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.Layouts,
  Markdown4D.Fmx.Viewer;

type
  TFmxLlmChatForm = class(TForm)
  private
    const
      WindowCaption = 'Markdown4D FMX LLM Chat Demo';
      InitialClientWidth = 760;
      InitialClientHeight = 680;
      InputPanelHeight = 52;
      ControlMargin = 8;
      SendButtonWidth = 80;
      SendButtonCaption = 'Send';
      InputHintCaption = 'Ask something...';
      MessageMargin = 8;
      MessageHeightPadding = 12;
      MinMessageHeight = 40;
      MinChunkLength = 30;
      MaxChunkLength = 80;
      MinTickMilliseconds = 30;
      MaxTickMilliseconds = 60;
      LayoutTickMilliseconds = 100;
      UserMessagePrefix = '**You:**'#10#10;
    var
      FMessagesBox: TVertScrollBox;
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
    procedure SetUniformMargins(const Control: TControl; const Amount: Single);
    procedure HandleSendClick(Sender: TObject);
    procedure HandleInputEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
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
  FmxLlmChatForm: TFmxLlmChatForm;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Types,
  Markdown4D.Extensions.Chart.BlockOverride,
  Markdown4D.Extensions.Mermaid.BlockOverride;

constructor TFmxLlmChatForm.Create(Owner: TComponent);
begin
  inherited CreateNew(Owner);

  TChartBlockOverride.RegisterOverride;
  TMermaidBlockOverride.RegisterOverride;

  Caption := WindowCaption;
  ClientWidth := InitialClientWidth;
  ClientHeight := InitialClientHeight;
  Position := TFormPosition.ScreenCenter;

  Randomize;
  FMessageViewers := TList<TMarkdownViewer>.Create;
  FCannedResponse := BuildCannedResponse;

  BuildInputPanel;
  BuildMessagesBox;
  BuildTimers;
end;

procedure TFmxLlmChatForm.BuildMessagesBox;
begin
  FMessagesBox := TVertScrollBox.Create(Self);
  FMessagesBox.Parent := Self;
  FMessagesBox.Align := TAlignLayout.Client;
end;

procedure TFmxLlmChatForm.BuildInputPanel;
begin
  FInputPanel := TPanel.Create(Self);
  FInputPanel.Parent := Self;
  FInputPanel.Align := TAlignLayout.Bottom;
  FInputPanel.Height := InputPanelHeight;

  FSendButton := TButton.Create(Self);
  FSendButton.Parent := FInputPanel;
  FSendButton.Align := TAlignLayout.Right;
  SetUniformMargins(FSendButton, ControlMargin);
  FSendButton.Width := SendButtonWidth;
  FSendButton.Text := SendButtonCaption;
  FSendButton.OnClick := HandleSendClick;

  FInputEdit := TEdit.Create(Self);
  FInputEdit.Parent := FInputPanel;
  FInputEdit.Align := TAlignLayout.Client;
  SetUniformMargins(FInputEdit, ControlMargin);
  FInputEdit.TextPrompt := InputHintCaption;
  FInputEdit.OnKeyDown := HandleInputEditKeyDown;
end;

procedure TFmxLlmChatForm.BuildTimers;
begin
  FStreamTimer := TTimer.Create(Self);
  FStreamTimer.Enabled := False;
  FStreamTimer.Interval := MinTickMilliseconds;
  FStreamTimer.OnTimer := HandleStreamTimer;

  FLayoutTimer := TTimer.Create(Self);
  FLayoutTimer.Interval := LayoutTickMilliseconds;
  FLayoutTimer.OnTimer := HandleLayoutTimer;
end;

procedure TFmxLlmChatForm.SetUniformMargins(const Control: TControl; const Amount: Single);
begin
  Control.Margins.Left := Amount;
  Control.Margins.Top := Amount;
  Control.Margins.Right := Amount;
  Control.Margins.Bottom := Amount;
end;

procedure TFmxLlmChatForm.HandleSendClick(Sender: TObject);
begin
  SendPrompt;
end;

procedure TFmxLlmChatForm.HandleInputEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  if Key <> vkReturn then
    Exit;

  Key := 0;
  KeyChar := #0;
  if FSendButton.Enabled then
    SendPrompt;
end;

procedure TFmxLlmChatForm.SendPrompt;
begin
  const Prompt = Trim(FInputEdit.Text);
  if Prompt = '' then
    Exit;

  AddMessageViewer(UserMessagePrefix + Prompt);
  FInputEdit.Text := '';
  StartStreaming;
end;

function TFmxLlmChatForm.AddMessageViewer(const Markdown: string): TMarkdownViewer;
begin
  Result := TMarkdownViewer.Create(Self);
  Result.Parent := FMessagesBox;
  Result.Align := TAlignLayout.Top;
  SetUniformMargins(Result, MessageMargin);
  Result.Margins.Bottom := 0;
  Result.Height := MinMessageHeight;
  Result.Text := Markdown;

  FMessageViewers.Add(Result);
end;

procedure TFmxLlmChatForm.StartStreaming;
begin
  FStreamingViewer := AddMessageViewer('');
  FStreamPosition := 1;
  FSendButton.Enabled := False;
  FStreamTimer.Interval := MinTickMilliseconds;
  FStreamTimer.Enabled := True;
end;

procedure TFmxLlmChatForm.HandleStreamTimer(Sender: TObject);
begin
  const IsFinished = FStreamPosition > Length(FCannedResponse);
  if IsFinished then
  begin
    FinishStreaming;
    Exit;
  end;

  AppendNextChunk;
end;

procedure TFmxLlmChatForm.AppendNextChunk;
begin
  const Remaining = Length(FCannedResponse) - FStreamPosition + 1;
  const ChunkLength = Min(Remaining, MinChunkLength + Random(MaxChunkLength - MinChunkLength + 1));
  FStreamingViewer.AppendMarkdown(Copy(FCannedResponse, FStreamPosition, ChunkLength));
  Inc(FStreamPosition, ChunkLength);

  FStreamTimer.Interval := MinTickMilliseconds + Random(MaxTickMilliseconds - MinTickMilliseconds + 1);
end;

procedure TFmxLlmChatForm.FinishStreaming;
begin
  FStreamTimer.Enabled := False;
  FStreamingViewer := nil;
  FSendButton.Enabled := True;
  FInputEdit.SetFocus;
end;

procedure TFmxLlmChatForm.HandleLayoutTimer(Sender: TObject);
begin
  SyncMessageHeights;

  if FStreamingViewer <> nil then
    ScrollMessagesToBottom;
end;

procedure TFmxLlmChatForm.SyncMessageHeights;
begin
  for var Viewer in FMessageViewers do
  begin
    const DesiredHeight = Max(MinMessageHeight, Viewer.ContentHeight + MessageHeightPadding);
    if not SameValue(Viewer.Height, DesiredHeight) then
      Viewer.Height := DesiredHeight;
  end;
end;

procedure TFmxLlmChatForm.ScrollMessagesToBottom;
begin
  FMessagesBox.ViewportPosition := PointF(0, FMessagesBox.ContentBounds.Height);
end;

class function TFmxLlmChatForm.BuildCannedResponse: string;
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
    '- [x] FMX viewer'#10#10 +
    'Images stream in asynchronously too:'#10#10 +
    '![Sample photo](https://picsum.photos/seed/llmchat/280/140)'#10#10 +
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

destructor TFmxLlmChatForm.Destroy;
begin
  FMessageViewers.Free;

  inherited Destroy;
end;

end.
