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
      FStreamer: TMarkdownStreamer;
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

constructor TStreamingMarkdownFMXForm.Create(Owner: TComponent);
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
  FCannedResponse := BuildStreamingSampleAnswer;
  FStreamer := TMarkdownStreamer.Create;

  BuildInputPanel;
  BuildMessagesBox;
  BuildTimers;
end;

procedure TStreamingMarkdownFMXForm.BuildMessagesBox;
begin
  FMessagesBox := TVertScrollBox.Create(Self);
  FMessagesBox.Parent := Self;
  FMessagesBox.Align := TAlignLayout.Client;
end;

procedure TStreamingMarkdownFMXForm.BuildInputPanel;
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

procedure TStreamingMarkdownFMXForm.BuildTimers;
begin
  FStreamTimer := TTimer.Create(Self);
  FStreamTimer.Enabled := False;
  FStreamTimer.Interval := MinTickMilliseconds;
  FStreamTimer.OnTimer := HandleStreamTimer;

  FLayoutTimer := TTimer.Create(Self);
  FLayoutTimer.Interval := LayoutTickMilliseconds;
  FLayoutTimer.OnTimer := HandleLayoutTimer;
end;

procedure TStreamingMarkdownFMXForm.SetUniformMargins(const Control: TControl; const Amount: Single);
begin
  Control.Margins.Left := Amount;
  Control.Margins.Top := Amount;
  Control.Margins.Right := Amount;
  Control.Margins.Bottom := Amount;
end;

procedure TStreamingMarkdownFMXForm.HandleSendClick(Sender: TObject);
begin
  SendPrompt;
end;

procedure TStreamingMarkdownFMXForm.HandleInputEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  if Key <> vkReturn then
    Exit;

  Key := 0;
  KeyChar := #0;
  if FSendButton.Enabled then
    SendPrompt;
end;

procedure TStreamingMarkdownFMXForm.SendPrompt;
begin
  const Prompt = Trim(FInputEdit.Text);
  if Prompt = '' then
    Exit;

  AddMessageViewer(UserMessagePrefix + Prompt);
  FInputEdit.Text := '';
  StartStreaming;
end;

function TStreamingMarkdownFMXForm.AddMessageViewer(const Markdown: string): TMarkdownViewer;
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

procedure TStreamingMarkdownFMXForm.StartStreaming;
begin
  FStreamingViewer := AddMessageViewer('');
  FStreamer.Reset(FCannedResponse);
  FSendButton.Enabled := False;
  FStreamTimer.Interval := MinTickMilliseconds;
  FStreamTimer.Enabled := True;
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

  FStreamTimer.Interval := MinTickMilliseconds + Random(MaxTickMilliseconds - MinTickMilliseconds + 1);
end;

procedure TStreamingMarkdownFMXForm.FinishStreaming;
begin
  FStreamTimer.Enabled := False;
  FStreamingViewer := nil;
  FSendButton.Enabled := True;
  FInputEdit.SetFocus;
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
  FMessagesBox.ViewportPosition := PointF(0, FMessagesBox.ContentBounds.Height);
end;

destructor TStreamingMarkdownFMXForm.Destroy;
begin
  FStreamer.Free;
  FMessageViewers.Free;

  inherited Destroy;
end;

end.
