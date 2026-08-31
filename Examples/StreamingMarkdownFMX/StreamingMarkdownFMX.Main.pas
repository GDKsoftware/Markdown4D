unit StreamingMarkdownFMX.Main;

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
  Markdown4D.Fmx.Viewer,
  StreamingMarkdown.Demo;

type
  TStreamingMarkdownFMXForm = class(TForm)
    sbxMessages: TVertScrollBox;
    pnlInput: TPanel;
    edtPrompt: TEdit;
    btnSend: TButton;
    tmrStream: TTimer;
    tmrLayout: TTimer;
    procedure HandleShow(Sender: TObject);
    procedure HandleSendClick(Sender: TObject);
    procedure HandlePromptKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
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
      UserMessagePrefix = '**You:**'#10#10;
    var
      FMessageViewers: TList<TMarkdownViewer>;
      FStreamingViewer: TMarkdownViewer;
      FCannedResponse: string;
      FStreamer: TMarkdownStreamer;
    procedure SetUniformMargins(const Control: TControl; const Amount: Single);
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
  StreamingMarkdownFMXForm: TStreamingMarkdownFMXForm;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Types,
  Markdown4D.Extensions.Chart.BlockOverride,
  Markdown4D.Extensions.Mermaid.BlockOverride;

{$R *.fmx}

constructor TStreamingMarkdownFMXForm.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  TChartBlockOverride.RegisterOverride;
  TMermaidBlockOverride.RegisterOverride;

  Randomize;
  FMessageViewers := TList<TMarkdownViewer>.Create;
  FCannedResponse := BuildStreamingSampleAnswer;
  FStreamer := TMarkdownStreamer.Create;
end;

procedure TStreamingMarkdownFMXForm.SetUniformMargins(const Control: TControl; const Amount: Single);
begin
  Control.Margins.Left := Amount;
  Control.Margins.Top := Amount;
  Control.Margins.Right := Amount;
  Control.Margins.Bottom := Amount;
end;

// A chat demo should demonstrate itself: the first show streams the canned
// answer without waiting for a prompt.
procedure TStreamingMarkdownFMXForm.HandleShow(Sender: TObject);
begin
  const IsFirstShow = (FMessageViewers.Count = 0);
  if IsFirstShow then
    StartStreaming;
end;

procedure TStreamingMarkdownFMXForm.HandleSendClick(Sender: TObject);
begin
  SendPrompt;
end;

procedure TStreamingMarkdownFMXForm.HandlePromptKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  if Key <> vkReturn then
    Exit;

  Key := 0;
  KeyChar := #0;
  if btnSend.Enabled then
    SendPrompt;
end;

procedure TStreamingMarkdownFMXForm.SendPrompt;
begin
  const Prompt = Trim(edtPrompt.Text);
  if Prompt = '' then
    Exit;

  AddMessageViewer(UserMessagePrefix + Prompt);
  edtPrompt.Text := '';
  StartStreaming;
end;

function TStreamingMarkdownFMXForm.AddMessageViewer(const Markdown: string): TMarkdownViewer;
begin
  Result := TMarkdownViewer.Create(Self);
  Result.Parent := sbxMessages;
  Result.Align := TAlignLayout.Top;
  SetUniformMargins(Result, MessageMargin);
  Result.Margins.Bottom := 0;
  Result.Height := MinMessageHeight;
  Result.Text := Markdown;

  FMessageViewers.Add(Result);
end;

procedure TStreamingMarkdownFMXForm.StartStreaming;
begin
  FStreamingViewer := AddMessageViewer('');
  FStreamer.Reset(FCannedResponse);
  btnSend.Enabled := False;
  tmrStream.Interval := MinTickMilliseconds;
  tmrStream.Enabled := True;
end;

procedure TStreamingMarkdownFMXForm.HandleStreamTimer(Sender: TObject);
begin
  if not FStreamer.HasMore then
  begin
    FinishStreaming;
    Exit;
  end;

  AppendNextChunk;
end;

procedure TStreamingMarkdownFMXForm.AppendNextChunk;
begin
  const RequestedLength = MinChunkLength + Random(MaxChunkLength - MinChunkLength + 1);
  FStreamingViewer.AppendMarkdown(FStreamer.NextChunk(RequestedLength));

  tmrStream.Interval := MinTickMilliseconds + Random(MaxTickMilliseconds - MinTickMilliseconds + 1);
end;

procedure TStreamingMarkdownFMXForm.FinishStreaming;
begin
  tmrStream.Enabled := False;
  FStreamingViewer := nil;
  btnSend.Enabled := True;
  edtPrompt.SetFocus;
end;

procedure TStreamingMarkdownFMXForm.HandleLayoutTimer(Sender: TObject);
begin
  SyncMessageHeights;

  if FStreamingViewer <> nil then
    ScrollMessagesToBottom;
end;

procedure TStreamingMarkdownFMXForm.SyncMessageHeights;
begin
  for var Viewer in FMessageViewers do
  begin
    const DesiredHeight = Max(MinMessageHeight, Viewer.ContentHeight + MessageHeightPadding);
    if not SameValue(Viewer.Height, DesiredHeight) then
      Viewer.Height := DesiredHeight;
  end;
end;

procedure TStreamingMarkdownFMXForm.ScrollMessagesToBottom;
begin
  sbxMessages.ViewportPosition := PointF(0, sbxMessages.ContentBounds.Height);
end;

destructor TStreamingMarkdownFMXForm.Destroy;
begin
  FStreamer.Free;
  FMessageViewers.Free;

  inherited Destroy;
end;

end.
