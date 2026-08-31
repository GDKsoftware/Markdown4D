unit StreamingMarkdownVCL.Main;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.Types,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Markdown4D.Vcl.Viewer,
  StreamingMarkdown.Demo;

type
  TStreamingMarkdownVCLForm = class(TForm)
    sbxMessages: TScrollBox;
    pnlInput: TPanel;
    edtPrompt: TEdit;
    btnSend: TButton;
    tmrStream: TTimer;
    tmrLayout: TTimer;
    procedure HandleShow(Sender: TObject);
    procedure HandleSendClick(Sender: TObject);
    procedure HandlePromptKeyPress(Sender: TObject; var Key: Char);
    procedure HandleMessagesWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
      var Handled: Boolean);
    procedure HandleStreamTimer(Sender: TObject);
    procedure HandleLayoutTimer(Sender: TObject);
  private
    const
      MessageMargin = 8;
      MessageHeightPadding = 12;
      MinMessageHeight = 40;
      MinChunkLength = 30;
      MaxChunkLength = 80;
      MinTickMilliseconds = 30;
      MaxTickMilliseconds = 60;
      StackToBottomTop = 1000000;
      UserMessagePrefix = '**You:**'#10#10;
    var
      FMessageViewers: TList<TMarkdownViewer>;
      FStreamingViewer: TMarkdownViewer;
      FCannedResponse: string;
      FStreamer: TMarkdownStreamer;
    procedure SendPrompt;
    function AddMessageViewer(const Markdown: string): TMarkdownViewer;
    procedure StartStreaming;
    procedure AppendNextChunk;
    procedure FinishStreaming;
    procedure SyncMessageHeights;
    procedure ScrollMessagesToBottom;

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

{$R *.dfm}

constructor TStreamingMarkdownVCLForm.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  TChartBlockOverride.RegisterOverride;
  TMermaidBlockOverride.RegisterOverride;

  Randomize;
  FMessageViewers := TList<TMarkdownViewer>.Create;
  FCannedResponse := BuildStreamingSampleAnswer;
  FStreamer := TMarkdownStreamer.Create;
end;

// A chat demo should demonstrate itself: the first show streams the canned
// answer without waiting for a prompt.
procedure TStreamingMarkdownVCLForm.HandleShow(Sender: TObject);
begin
  const IsFirstShow = (FMessageViewers.Count = 0);
  if IsFirstShow then
    StartStreaming;
end;

procedure TStreamingMarkdownVCLForm.HandleSendClick(Sender: TObject);
begin
  SendPrompt;
end;

// Wheel input that no child claims lands on the form; the conversation is the
// only thing left to scroll, wherever the cursor happens to hover.
procedure TStreamingMarkdownVCLForm.HandleMessagesWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  sbxMessages.VertScrollBar.Position := sbxMessages.VertScrollBar.Position - WheelDelta;
  Handled := True;
end;

procedure TStreamingMarkdownVCLForm.HandlePromptKeyPress(Sender: TObject; var Key: Char);
begin
  if Key <> #13 then
    Exit;

  Key := #0;
  if btnSend.Enabled then
    SendPrompt;
end;

procedure TStreamingMarkdownVCLForm.SendPrompt;
begin
  const Prompt = Trim(edtPrompt.Text);
  if Prompt = '' then
    Exit;

  AddMessageViewer(UserMessagePrefix + Prompt);
  edtPrompt.Text := '';
  StartStreaming;
end;

function TStreamingMarkdownVCLForm.AddMessageViewer(const Markdown: string): TMarkdownViewer;
begin
  Result := TMarkdownViewer.Create(Self);
  Result.Parent := sbxMessages;
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
  FStreamer.Reset(FCannedResponse);
  btnSend.Enabled := False;
  tmrStream.Interval := MinTickMilliseconds;
  tmrStream.Enabled := True;
end;

procedure TStreamingMarkdownVCLForm.HandleStreamTimer(Sender: TObject);
begin
  if not FStreamer.HasMore then
  begin
    FinishStreaming;
    Exit;
  end;

  AppendNextChunk;
end;

procedure TStreamingMarkdownVCLForm.AppendNextChunk;
begin
  const RequestedLength = MinChunkLength + Random(MaxChunkLength - MinChunkLength + 1);
  FStreamingViewer.AppendMarkdown(FStreamer.NextChunk(RequestedLength));

  tmrStream.Interval := MinTickMilliseconds + Random(MaxTickMilliseconds - MinTickMilliseconds + 1);
end;

procedure TStreamingMarkdownVCLForm.FinishStreaming;
begin
  tmrStream.Enabled := False;
  FStreamingViewer := nil;
  btnSend.Enabled := True;
  edtPrompt.SetFocus;
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
  sbxMessages.VertScrollBar.Position := sbxMessages.VertScrollBar.Range;
end;

destructor TStreamingMarkdownVCLForm.Destroy;
begin
  FStreamer.Free;
  FMessageViewers.Free;

  inherited Destroy;
end;

end.
