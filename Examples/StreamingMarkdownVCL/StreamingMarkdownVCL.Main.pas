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
  Markdown4D.Vcl.Viewer,
  StreamingMarkdown.Demo;

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
      FStreamer: TMarkdownStreamer;
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
  FCannedResponse := BuildStreamingSampleAnswer;
  FStreamer := TMarkdownStreamer.Create;

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
  FStreamer.Reset(FCannedResponse);
  FSendButton.Enabled := False;
  FStreamTimer.Interval := MinTickMilliseconds;
  FStreamTimer.Enabled := True;
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

destructor TStreamingMarkdownVCLForm.Destroy;
begin
  FStreamer.Free;
  FMessageViewers.Free;

  inherited Destroy;
end;

end.
