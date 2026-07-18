unit Markdown4D.Fmx.Editor;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.UITypes,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Theme,
  Markdown4D.Editor.Model,
  Markdown4D.Editor.Highlighter,
  Markdown4D.Viewer.Lifetime,
  Markdown4D.Fmx.Painter,
  Markdown4D.Fmx.Viewer;

type
  TMarkdownEditor = class(TControl)
  private
    const
      DefaultControlWidth = 400;
      DefaultControlHeight = 300;
      CaretBlinkIntervalMilliseconds = 500;
      DoubleClickWindowMilliseconds = 500;
      DoubleClickSlopDips = 4;
    var
      FLifetime: IMarkdownViewerLifetime;
      FModel: TMarkdownEditorModel;
      FHighlighter: TMarkdownSourceHighlighter;
      FTheme: TMarkdownTheme;
      FOwnsTheme: Boolean;
      FThemePreset: TMarkdownThemePreset;
      FDesignSampleActive: Boolean;
      FMeasureBitmap: TBitmap;
      FMeasurePainter: TMarkdownFmxPainter;
      FMeasurePainterLifetime: IPainter;
      FScrollOffset: Single;
      FShowLineNumbers: Boolean;
      FSelecting: Boolean;
      FSelectionAnchor: Integer;
      FClickCount: Integer;
      FLastClickTicks: Cardinal;
      FLastClickX: Single;
      FLastClickY: Single;
      FDragX: Single;
      FDragY: Single;
      FAutoScrollTimer: TTimer;
      FCaretTimer: TTimer;
      FCaretVisible: Boolean;
      FPreview: TMarkdownViewer;
      FPreviewTimer: TTimer;
      FPreviewDirty: Boolean;
      FUpdatingPreview: Boolean;
      FOnChange: TNotifyEvent;
      FOnScroll: TNotifyEvent;
    procedure CreateCaretTimer;
    procedure CreatePreviewTimer;
    procedure CreateAutoScrollTimer;
    procedure HandleModelChange(const Sender: TObject; const Range: TEditorReplaceRange);
    procedure HandleCaretTimer(Sender: TObject);
    procedure HandlePreviewTimer(Sender: TObject);
    procedure HandleAutoScrollTimer(Sender: TObject);
    function NextClickCount(const X, Y: Single; const Shift: TShiftState): Integer;
    procedure UpdateSelectionToPoint(const X, Y: Single);
    procedure UpdateAutoScroll(const X, Y: Single);
    procedure SchedulePreviewUpdate;
    procedure RenderContent(const Target: TCanvas; const TargetWidth, TargetHeight, ScrollY: Single;
      const DrawCaret: Boolean);
    procedure DrawLineTokens(const Painter: IPainter; const LineText: string;
      const Tokens: TArray<TMarkdownSourceToken>; const TextLeft, Top: Single);
    procedure DrawGutterNumber(const Painter: IPainter; const LineIndex: Integer; const GutterWidth, Top: Single);
    function TokenColor(const Kind: TMarkdownSourceTokenKind): TLayoutColor;
    function GutterWidthPx(const Painter: IPainter): Single;
    function CodeFont: TMarkdownFontStyle;
    function LineHeightPx: Single;
    function VisibleLineCount: Integer;
    function TextLeftPx: Single;
    function CaretWidthPx: Single;
    function LineTextAt(const LineIndex: Integer): string;
    function LineStartOffset(const LineIndex: Integer): Integer;
    function LineEndOffset(const LineIndex: Integer): Integer;
    function OffsetAtLineX(const LineIndex: Integer; const TargetX: Single): Integer;
    function OffsetFromPoint(const X, Y: Single): Integer;
    function CurrentAnchor: Integer;
    function CaretPixelPos(const ScrollY: Single): TLayoutPointF;
    function ContentHeightPx: Single;
    function MaxScrollOffset: Single;
    procedure SetScrollOffset(const Value: Single);
    procedure ScrollCaretIntoView;
    procedure RedrawContent;
    procedure RefreshAfterEdit;
    procedure RestartCaretBlink;
    procedure MoveVertical(const LineDelta: Integer; const Extend: Boolean);
    procedure SetCaretTo(const Offset: Integer; const Extend: Boolean);
    function CopyToClipboard: Boolean;
    procedure CutToClipboard;
    procedure PasteFromClipboard;
    function HandleKey(const Key: Word; const Shift: TShiftState): Boolean;
    function HandleControlKey(const Key: Word; const Shift: TShiftState): Boolean;
    function HandleNavigationKey(const Key: Word; const Shift: TShiftState): Boolean;
    function GetText: string;
    procedure SetText(const Value: string);
    function IsTextStored: Boolean;
    procedure SetThemePreset(const Value: TMarkdownThemePreset);
    procedure EnsureDesignSample;
    function GetCaretPosition: Integer;
    procedure SetCaretPosition(const Value: Integer);
    function GetSelectedText: string;
    procedure SetTheme(const Value: TMarkdownTheme);
    procedure SetShowLineNumbers(const Value: Boolean);

  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Paint; override;
    procedure Resize; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;

  public
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
    procedure ExecuteCommand(const Command: TEditorCommand);
    procedure Undo;
    procedure Redo;
    function CanUndo: Boolean;
    function CanRedo: Boolean;
    procedure AttachPreview(const Viewer: TMarkdownViewer);
    procedure DetachPreview;
    procedure FlushPreview;
    procedure PaintTo(const Bitmap: TBitmap);
    function FirstVisibleSourceLine: Integer;
    function SourceLineStartOffset(const LineIndex: Integer): Integer;
    property CaretPosition: Integer read GetCaretPosition write SetCaretPosition;
    property SelectedText: string read GetSelectedText;
    property Theme: TMarkdownTheme read FTheme write SetTheme;

  published
    property Text: string read GetText write SetText stored IsTextStored;
    property ThemePreset: TMarkdownThemePreset read FThemePreset write SetThemePreset
      default TMarkdownThemePreset.Light;
    property ShowLineNumbers: Boolean read FShowLineNumbers write SetShowLineNumbers default False;
    property Align;
    property Anchors;
    property Cursor;
    property Enabled;
    property Height;
    property HitTest;
    property Margins;
    property Opacity;
    property Padding;
    property PopupMenu;
    property Position;
    property Size;
    property TabOrder;
    property Visible;
    property Width;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnScroll: TNotifyEvent read FOnScroll write FOnScroll;
  end;

implementation

uses
  Markdown4D.DesignSample,
  System.SysUtils,
  System.Math,
  System.Rtti,
  FMX.Platform,
  Markdown4D.Layout.Defaults;

constructor TMarkdownEditor.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  FLifetime := TMarkdownViewerLifetime.Create;

  Width := DefaultControlWidth;
  Height := DefaultControlHeight;
  HitTest := True;
  CanFocus := True;
  AutoCapture := True;
  TabStop := True;

  FTheme := TMarkdownTheme.CreateLight;
  FOwnsTheme := True;

  FModel := TMarkdownEditorModel.Create;
  FModel.OnChange := HandleModelChange;
  FHighlighter := TMarkdownSourceHighlighter.Create;

  FMeasureBitmap := TBitmap.Create(1, 1);
  FMeasurePainter := TMarkdownFmxPainter.Create(FMeasureBitmap.Canvas);
  FMeasurePainterLifetime := FMeasurePainter;

  FCaretVisible := True;
  CreateCaretTimer;
  CreatePreviewTimer;
  CreateAutoScrollTimer;
end;

destructor TMarkdownEditor.Destroy;
begin
  FLifetime.Kill;
  FPreview := nil;
  if FPreviewTimer <> nil then
    FPreviewTimer.Enabled := False;
  if FCaretTimer <> nil then
    FCaretTimer.Enabled := False;
  if FAutoScrollTimer <> nil then
    FAutoScrollTimer.Enabled := False;

  FHighlighter.Free;
  FModel.Free;
  FMeasurePainter := nil;
  FMeasurePainterLifetime := nil;
  FMeasureBitmap.Free;
  if FOwnsTheme then
    FTheme.Free;

  inherited Destroy;
end;

procedure TMarkdownEditor.CreateCaretTimer;
begin
  var TimerService: IFMXTimerService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXTimerService, TimerService) then
    Exit;

  FCaretTimer := TTimer.Create(Self);
  FCaretTimer.Enabled := False;
  FCaretTimer.Interval := CaretBlinkIntervalMilliseconds;
  FCaretTimer.OnTimer := HandleCaretTimer;
end;

procedure TMarkdownEditor.CreatePreviewTimer;
begin
  var TimerService: IFMXTimerService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXTimerService, TimerService) then
    Exit;

  FPreviewTimer := TTimer.Create(Self);
  FPreviewTimer.Enabled := False;
  FPreviewTimer.Interval := PreviewDebounceIntervalMilliseconds;
  FPreviewTimer.OnTimer := HandlePreviewTimer;
end;

procedure TMarkdownEditor.CreateAutoScrollTimer;
begin
  var TimerService: IFMXTimerService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXTimerService, TimerService) then
    Exit;

  FAutoScrollTimer := TTimer.Create(Self);
  FAutoScrollTimer.Enabled := False;
  FAutoScrollTimer.Interval := AutoScrollIntervalMilliseconds;
  FAutoScrollTimer.OnTimer := HandleAutoScrollTimer;
end;

procedure TMarkdownEditor.ExecuteCommand(const Command: TEditorCommand);
begin
  FModel.ExecuteCommand(Command);
  RefreshAfterEdit;
end;

procedure TMarkdownEditor.Undo;
begin
  FModel.Undo;
  RefreshAfterEdit;
end;

procedure TMarkdownEditor.Redo;
begin
  FModel.Redo;
  RefreshAfterEdit;
end;

function TMarkdownEditor.CanUndo: Boolean;
begin
  Result := FModel.CanUndo;
end;

function TMarkdownEditor.CanRedo: Boolean;
begin
  Result := FModel.CanRedo;
end;

procedure TMarkdownEditor.AttachPreview(const Viewer: TMarkdownViewer);
begin
  if FPreview <> nil then
    FPreview.RemoveFreeNotification(Self);

  FPreview := Viewer;
  if FPreview <> nil then
    FPreview.FreeNotification(Self);

  FPreviewDirty := True;
  FlushPreview;
end;

procedure TMarkdownEditor.DetachPreview;
begin
  if FPreview <> nil then
    FPreview.RemoveFreeNotification(Self);

  FPreview := nil;
  FPreviewDirty := False;
  if FPreviewTimer <> nil then
    FPreviewTimer.Enabled := False;
end;

procedure TMarkdownEditor.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);

  if (Operation = TOperation.opRemove) and (AComponent = FPreview) then
  begin
    FPreview := nil;
    FPreviewDirty := False;
    if FPreviewTimer <> nil then
      FPreviewTimer.Enabled := False;
  end;
end;

procedure TMarkdownEditor.FlushPreview;
begin
  if FPreviewTimer <> nil then
    FPreviewTimer.Enabled := False;
  FPreviewDirty := False;
  if FPreview = nil then
    Exit;

  FUpdatingPreview := True;
  try
    FPreview.Text := FModel.Text;
  finally
    FUpdatingPreview := False;
  end;
end;

procedure TMarkdownEditor.PaintTo(const Bitmap: TBitmap);
begin
  Bitmap.Canvas.BeginScene;
  try
    RenderContent(Bitmap.Canvas, Bitmap.Width, Bitmap.Height, 0, False);
  finally
    Bitmap.Canvas.EndScene;
  end;
end;

function TMarkdownEditor.FirstVisibleSourceLine: Integer;
begin
  Result := Trunc(FScrollOffset / LineHeightPx);
end;

function TMarkdownEditor.SourceLineStartOffset(const LineIndex: Integer): Integer;
begin
  Result := FModel.OffsetOfLineStart(LineIndex);
end;

procedure TMarkdownEditor.HandleModelChange(const Sender: TObject; const Range: TEditorReplaceRange);
begin
  FCaretVisible := True;
  ScrollCaretIntoView;
  RedrawContent;
  SchedulePreviewUpdate;

  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TMarkdownEditor.HandleCaretTimer(Sender: TObject);
begin
  if not FLifetime.IsAlive then
    Exit;

  FCaretVisible := not FCaretVisible;
  RedrawContent;
end;

procedure TMarkdownEditor.HandlePreviewTimer(Sender: TObject);
begin
  FPreviewTimer.Enabled := False;
  if not FLifetime.IsAlive then
    Exit;

  if FPreviewDirty then
    FlushPreview;
end;

procedure TMarkdownEditor.SchedulePreviewUpdate;
begin
  if (FPreview = nil) or FUpdatingPreview then
    Exit;

  FPreviewDirty := True;
  if FPreviewTimer = nil then
  begin
    FlushPreview;
    Exit;
  end;

  FPreviewTimer.Enabled := False;
  FPreviewTimer.Enabled := True;
end;

procedure TMarkdownEditor.Paint;
begin
  EnsureDesignSample;

  const DrawCaret = IsFocused and FCaretVisible;
  RenderContent(Canvas, Width, Height, FScrollOffset, DrawCaret);
end;

procedure TMarkdownEditor.EnsureDesignSample;
begin
  if not (csDesigning in ComponentState) then
    Exit;

  if FDesignSampleActive then
    Exit;

  if FModel.Text <> '' then
    Exit;

  FDesignSampleActive := True;
  FModel.LoadText(TMarkdownDesignSample.Markdown);
end;

procedure TMarkdownEditor.RenderContent(const Target: TCanvas; const TargetWidth, TargetHeight, ScrollY: Single;
  const DrawCaret: Boolean);
begin
  const Painter = TMarkdownFmxPainter.Create(Target);
  const PainterLifetime: IPainter = Painter;

  Painter.FillRect(TLayoutRectF.Create(0, 0, TargetWidth, TargetHeight), FTheme.BackgroundColor);

  const LineHeight = LineHeightPx;
  const GutterWidth = GutterWidthPx(PainterLifetime);
  const TextLeft = GutterWidth + TextLeftPaddingDips;

  const CaretLine = FModel.LineIndexOfOffset(FModel.CaretPosition);
  const ActiveTop = CaretLine * LineHeight - ScrollY;
  Painter.FillRect(TLayoutRectF.Create(0, ActiveTop, TargetWidth, ActiveTop + LineHeight),
    FTheme.CodeBackgroundColor);

  var State := FHighlighter.InitialState;
  const LineCount = FModel.LineCount;
  for var LineIndex := 0 to LineCount - 1 do
  begin
    const Top = LineIndex * LineHeight - ScrollY;
    if Top > TargetHeight then
      Break;

    const LineText = LineTextAt(LineIndex);
    const Tokenized = FHighlighter.TokenizeLine(LineText, State);

    const IsVisible = (Top + LineHeight) > 0;
    if IsVisible then
    begin
      if FShowLineNumbers then
        DrawGutterNumber(PainterLifetime, LineIndex, GutterWidth, Top);
      DrawLineTokens(PainterLifetime, LineText, Tokenized.Tokens, TextLeft, Top);
    end;

    State := Tokenized.NextState;
  end;

  if DrawCaret then
  begin
    const CaretPos = CaretPixelPos(ScrollY);
    Painter.FillRect(TLayoutRectF.Create(CaretPos.X, CaretPos.Y, CaretPos.X + CaretWidthPx,
      CaretPos.Y + LineHeight), FTheme.TextColor);
  end;
end;

procedure TMarkdownEditor.DrawLineTokens(const Painter: IPainter; const LineText: string;
  const Tokens: TArray<TMarkdownSourceToken>; const TextLeft, Top: Single);
begin
  for var Token in Tokens do
  begin
    const Segment = Copy(LineText, Token.Start, Token.Length);
    if Segment = '' then
      Continue;

    const Prefix = Copy(LineText, 1, Token.Start - 1);
    const OffsetX = Painter.MeasureText(Prefix, CodeFont).Width;
    Painter.DrawTextRun(TLayoutPointF.Create(TextLeft + OffsetX, Top), Segment, CodeFont, TokenColor(Token.Kind));
  end;
end;

procedure TMarkdownEditor.DrawGutterNumber(const Painter: IPainter; const LineIndex: Integer;
  const GutterWidth, Top: Single);
begin
  const Number = IntToStr(LineIndex + 1);
  const NumberWidth = Painter.MeasureText(Number, CodeFont).Width;
  const NumberLeft = GutterWidth - GutterPaddingDips - NumberWidth;
  Painter.DrawTextRun(TLayoutPointF.Create(NumberLeft, Top), Number, CodeFont, FTheme.BlockQuoteTextColor);
end;

function TMarkdownEditor.TokenColor(const Kind: TMarkdownSourceTokenKind): TLayoutColor;
begin
  case Kind of
    TMarkdownSourceTokenKind.HeadingMarker,
    TMarkdownSourceTokenKind.EmphasisDelimiter,
    TMarkdownSourceTokenKind.CodeSpanDelimiter,
    TMarkdownSourceTokenKind.BlockQuoteMarker,
    TMarkdownSourceTokenKind.ListMarker,
    TMarkdownSourceTokenKind.LinkBracket:
      Result := FTheme.BlockQuoteTextColor;
    TMarkdownSourceTokenKind.CodeSpanText,
    TMarkdownSourceTokenKind.FenceLine,
    TMarkdownSourceTokenKind.FenceContent:
      Result := FTheme.CodeTextColor;
    TMarkdownSourceTokenKind.LinkText,
    TMarkdownSourceTokenKind.LinkUrl:
      Result := FTheme.LinkColor;
  else
    Result := FTheme.TextColor;
  end;
end;

function TMarkdownEditor.GutterWidthPx(const Painter: IPainter): Single;
begin
  if not FShowLineNumbers then
    Exit(0);

  const Digits = Length(IntToStr(Max(1, FModel.LineCount)));
  const Sample = StringOfChar('0', Digits);
  Result := Painter.MeasureText(Sample, CodeFont).Width + 2 * GutterPaddingDips;
end;

function TMarkdownEditor.CodeFont: TMarkdownFontStyle;
begin
  Result := FTheme.CodeFont;
end;

function TMarkdownEditor.LineHeightPx: Single;
begin
  Result := FMeasurePainter.LineHeight(CodeFont);
  if Result < 1 then
    Result := 1;
end;

function TMarkdownEditor.VisibleLineCount: Integer;
begin
  Result := Max(1, Trunc(Height / LineHeightPx));
end;

function TMarkdownEditor.TextLeftPx: Single;
begin
  Result := GutterWidthPx(FMeasurePainterLifetime) + TextLeftPaddingDips;
end;

function TMarkdownEditor.CaretWidthPx: Single;
begin
  Result := CaretWidthDips;
end;

function TMarkdownEditor.LineTextAt(const LineIndex: Integer): string;
begin
  const Source = FModel.Text;
  const StartOffset = FModel.OffsetOfLineStart(LineIndex);
  var EndOffset: Integer;
  if LineIndex < FModel.LineCount - 1 then
    EndOffset := FModel.OffsetOfLineStart(LineIndex + 1) - 1
  else
    EndOffset := Length(Source);

  Result := Copy(Source, StartOffset + 1, EndOffset - StartOffset);
end;

function TMarkdownEditor.LineStartOffset(const LineIndex: Integer): Integer;
begin
  Result := FModel.OffsetOfLineStart(LineIndex);
end;

function TMarkdownEditor.LineEndOffset(const LineIndex: Integer): Integer;
begin
  Result := LineStartOffset(LineIndex) + Length(LineTextAt(LineIndex));
end;

function TMarkdownEditor.OffsetAtLineX(const LineIndex: Integer; const TargetX: Single): Integer;
begin
  const LineText = LineTextAt(LineIndex);
  const Start = LineStartOffset(LineIndex);

  var BestColumn := 0;
  var BestDistance := Abs(TargetX);
  for var Count := 1 to Length(LineText) do
  begin
    const Width = FMeasurePainter.MeasureText(Copy(LineText, 1, Count), CodeFont).Width;
    const Distance = Abs(TargetX - Width);
    if Distance < BestDistance then
    begin
      BestDistance := Distance;
      BestColumn := Count;
    end;
  end;

  Result := Start + BestColumn;
end;

function TMarkdownEditor.OffsetFromPoint(const X, Y: Single): Integer;
begin
  const Line = EnsureRange(Trunc((Y + FScrollOffset) / LineHeightPx), 0, FModel.LineCount - 1);
  const LocalX = X - TextLeftPx;
  Result := OffsetAtLineX(Line, Max(0, LocalX));
end;

function TMarkdownEditor.CurrentAnchor: Integer;
begin
  if FModel.CaretPosition = FModel.SelectionStart then
    Result := FModel.SelectionStart + FModel.SelectionLength
  else
    Result := FModel.SelectionStart;
end;

function TMarkdownEditor.CaretPixelPos(const ScrollY: Single): TLayoutPointF;
begin
  const Caret = FModel.CaretPosition;
  const Line = FModel.LineIndexOfOffset(Caret);
  const Prefix = Copy(FModel.Text, LineStartOffset(Line) + 1, Caret - LineStartOffset(Line));
  const OffsetX = FMeasurePainter.MeasureText(Prefix, CodeFont).Width;
  Result := TLayoutPointF.Create(TextLeftPx + OffsetX, Line * LineHeightPx - ScrollY);
end;

function TMarkdownEditor.ContentHeightPx: Single;
begin
  Result := FModel.LineCount * LineHeightPx;
end;

function TMarkdownEditor.MaxScrollOffset: Single;
begin
  Result := Max(0, ContentHeightPx - Height);
end;

procedure TMarkdownEditor.SetScrollOffset(const Value: Single);
begin
  const Clamped = EnsureRange(Value, 0, MaxScrollOffset);
  if SameValue(Clamped, FScrollOffset) then
    Exit;

  FScrollOffset := Clamped;
  RedrawContent;

  if Assigned(FOnScroll) then
    FOnScroll(Self);
end;

procedure TMarkdownEditor.ScrollCaretIntoView;
begin
  const Line = FModel.LineIndexOfOffset(FModel.CaretPosition);
  const Top = Line * LineHeightPx;
  const Bottom = Top + LineHeightPx;

  var NewOffset := FScrollOffset;
  if Top < NewOffset then
    NewOffset := Top
  else if Bottom > NewOffset + Height then
    NewOffset := Bottom - Height;

  SetScrollOffset(NewOffset);
end;

procedure TMarkdownEditor.RedrawContent;
begin
  if Scene <> nil then
    Repaint;
end;

procedure TMarkdownEditor.RefreshAfterEdit;
begin
  ScrollCaretIntoView;
  RestartCaretBlink;
  RedrawContent;
end;

procedure TMarkdownEditor.RestartCaretBlink;
begin
  FCaretVisible := True;
  if (FCaretTimer <> nil) and IsFocused then
  begin
    FCaretTimer.Enabled := False;
    FCaretTimer.Enabled := True;
  end;
end;

procedure TMarkdownEditor.MoveVertical(const LineDelta: Integer; const Extend: Boolean);
begin
  const Caret = FModel.CaretPosition;
  const Line = FModel.LineIndexOfOffset(Caret);
  const Prefix = Copy(FModel.Text, LineStartOffset(Line) + 1, Caret - LineStartOffset(Line));
  const TargetX = FMeasurePainter.MeasureText(Prefix, CodeFont).Width;
  const TargetLine = EnsureRange(Line + LineDelta, 0, FModel.LineCount - 1);
  SetCaretTo(OffsetAtLineX(TargetLine, TargetX), Extend);
end;

procedure TMarkdownEditor.SetCaretTo(const Offset: Integer; const Extend: Boolean);
begin
  if Extend then
  begin
    const Anchor = CurrentAnchor;
    FModel.SetSelection(Anchor, Offset - Anchor);
  end
  else
    FModel.CaretPosition := Offset;
end;

function TMarkdownEditor.CopyToClipboard: Boolean;
begin
  Result := False;
  const Selected = FModel.SelectedText;
  if Selected = '' then
    Exit;

  var Clipboard: IFMXClipboardService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clipboard) then
  begin
    Clipboard.SetClipboard(Selected);
    Result := True;
  end;
end;

procedure TMarkdownEditor.CutToClipboard;
begin
  if not FModel.HasSelection then
    Exit;

  if CopyToClipboard then
    FModel.DeleteBackward;
end;

procedure TMarkdownEditor.PasteFromClipboard;
begin
  var Clipboard: IFMXClipboardService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clipboard) then
    Exit;

  const Value = Clipboard.GetClipboard;
  if Value.IsEmpty then
    Exit;

  const Pasted = Value.ToString;
  if Pasted = '' then
    Exit;

  var Normalized := StringReplace(Pasted, #13#10, #10, [rfReplaceAll]);
  Normalized := StringReplace(Normalized, #13, #10, [rfReplaceAll]);
  FModel.BreakUndoCoalescing;
  FModel.Insert(Normalized);
end;

procedure TMarkdownEditor.Resize;
begin
  inherited Resize;

  RedrawContent;
end;

procedure TMarkdownEditor.DoEnter;
begin
  inherited DoEnter;

  FCaretVisible := True;
  if FCaretTimer <> nil then
    FCaretTimer.Enabled := True;
  RedrawContent;
end;

procedure TMarkdownEditor.DoExit;
begin
  inherited DoExit;

  if FCaretTimer <> nil then
    FCaretTimer.Enabled := False;
  FCaretVisible := False;
  RedrawContent;
end;

procedure TMarkdownEditor.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseDown(Button, Shift, X, Y);

  if Button <> TMouseButton.mbLeft then
    Exit;

  if CanFocus and (Scene <> nil) then
    SetFocus;
  FModel.BreakUndoCoalescing;

  const Offset = OffsetFromPoint(X, Y);

  if ssShift in Shift then
  begin
    const Anchor = CurrentAnchor;
    FModel.SetSelection(Anchor, Offset - Anchor);
    FSelectionAnchor := Anchor;
    FSelecting := True;
    FClickCount := 1;
    FLastClickTicks := TThread.GetTickCount;
    FLastClickX := X;
    FLastClickY := Y;
    RestartCaretBlink;
    RedrawContent;
    Exit;
  end;

  FClickCount := NextClickCount(X, Y, Shift);

  case FClickCount of
    2:
      begin
        FModel.SelectWordAt(Offset);
        FSelecting := False;
      end;
    3:
      begin
        FModel.SelectLineAt(Offset);
        FSelecting := False;
      end;
  else
    begin
      FModel.CaretPosition := Offset;
      FSelectionAnchor := Offset;
      FSelecting := True;
    end;
  end;

  RestartCaretBlink;
  RedrawContent;
end;

procedure TMarkdownEditor.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited MouseMove(Shift, X, Y);

  if not FSelecting then
    Exit;

  UpdateSelectionToPoint(X, Y);
  UpdateAutoScroll(X, Y);
end;

procedure TMarkdownEditor.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseUp(Button, Shift, X, Y);

  if Button <> TMouseButton.mbLeft then
    Exit;

  FSelecting := False;
  if FAutoScrollTimer <> nil then
    FAutoScrollTimer.Enabled := False;
end;

function TMarkdownEditor.NextClickCount(const X, Y: Single; const Shift: TShiftState): Integer;
begin
  const Ticks = TThread.GetTickCount;
  const WithinTime = (Ticks - FLastClickTicks) <= DoubleClickWindowMilliseconds;
  const WithinDistance = (Abs(X - FLastClickX) <= DoubleClickSlopDips) and
    (Abs(Y - FLastClickY) <= DoubleClickSlopDips);

  const IsRepeat = ((ssDouble in Shift) or (WithinTime and WithinDistance)) and
    (FClickCount >= 1) and (FClickCount < 3);
  if IsRepeat then
    Result := FClickCount + 1
  else
    Result := 1;

  FLastClickTicks := Ticks;
  FLastClickX := X;
  FLastClickY := Y;
end;

procedure TMarkdownEditor.UpdateSelectionToPoint(const X, Y: Single);
begin
  const Offset = OffsetFromPoint(X, Y);
  FModel.SetSelection(FSelectionAnchor, Offset - FSelectionAnchor);
  RedrawContent;
end;

procedure TMarkdownEditor.UpdateAutoScroll(const X, Y: Single);
begin
  if FAutoScrollTimer = nil then
    Exit;

  const Outside = (Y < 0) or (Y > Height);
  const ShouldScroll = Outside and FSelecting and (Scene <> nil);

  if ShouldScroll then
  begin
    FDragX := X;
    FDragY := Y;
  end;

  FAutoScrollTimer.Enabled := ShouldScroll;
end;

procedure TMarkdownEditor.HandleAutoScrollTimer(Sender: TObject);
begin
  if not FLifetime.IsAlive then
    Exit;

  if not (FSelecting and (Scene <> nil)) then
  begin
    FAutoScrollTimer.Enabled := False;
    Exit;
  end;

  if FDragY < 0 then
    SetScrollOffset(FScrollOffset - LineHeightPx)
  else
    SetScrollOffset(FScrollOffset + LineHeightPx);

  UpdateSelectionToPoint(FDragX, FDragY);
end;

procedure TMarkdownEditor.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited MouseWheel(Shift, WheelDelta, Handled);
  if Handled then
    Exit;

  const Notches = WheelDelta / 120;
  SetScrollOffset(FScrollOffset - (Notches * WheelLinesPerNotch * LineHeightPx));
  Handled := True;
end;

procedure TMarkdownEditor.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  inherited KeyDown(Key, KeyChar, Shift);

  if HandleKey(Key, Shift) then
  begin
    Key := 0;
    KeyChar := #0;
    Exit;
  end;

  const IsPrintable = KeyChar >= ' ';
  if IsPrintable then
  begin
    FModel.Insert(KeyChar);
    KeyChar := #0;
  end;
end;

function TMarkdownEditor.HandleKey(const Key: Word; const Shift: TShiftState): Boolean;
begin
  if ssCtrl in Shift then
    Result := HandleControlKey(Key, Shift)
  else
    Result := HandleNavigationKey(Key, Shift);

  if Result then
    RefreshAfterEdit;
end;

function TMarkdownEditor.HandleControlKey(const Key: Word; const Shift: TShiftState): Boolean;
begin
  const Extend = ssShift in Shift;
  Result := True;
  case Key of
    vkA:
      FModel.SelectAll;
    vkC:
      CopyToClipboard;
    vkX:
      CutToClipboard;
    vkV:
      PasteFromClipboard;
    vkZ:
      FModel.Undo;
    vkY:
      FModel.Redo;
    vkB:
      FModel.ExecuteCommand(TEditorCommand.Bold);
    vkI:
      FModel.ExecuteCommand(TEditorCommand.Italic);
    vkK:
      FModel.ExecuteCommand(TEditorCommand.Link);
    vkLeft:
      begin
        FModel.BreakUndoCoalescing;
        FModel.MoveWordLeft(Extend);
      end;
    vkRight:
      begin
        FModel.BreakUndoCoalescing;
        FModel.MoveWordRight(Extend);
      end;
    vkHome:
      begin
        FModel.BreakUndoCoalescing;
        SetCaretTo(0, Extend);
      end;
    vkEnd:
      begin
        FModel.BreakUndoCoalescing;
        SetCaretTo(Length(FModel.Text), Extend);
      end;
  else
    Result := False;
  end;
end;

function TMarkdownEditor.HandleNavigationKey(const Key: Word; const Shift: TShiftState): Boolean;
begin
  const Extend = ssShift in Shift;
  const Caret = FModel.CaretPosition;
  const Line = FModel.LineIndexOfOffset(Caret);
  Result := True;
  case Key of
    vkLeft:
      begin
        FModel.BreakUndoCoalescing;
        FModel.MoveCaret(-1, Extend);
      end;
    vkRight:
      begin
        FModel.BreakUndoCoalescing;
        FModel.MoveCaret(1, Extend);
      end;
    vkUp:
      begin
        FModel.BreakUndoCoalescing;
        MoveVertical(-1, Extend);
      end;
    vkDown:
      begin
        FModel.BreakUndoCoalescing;
        MoveVertical(1, Extend);
      end;
    vkHome:
      begin
        FModel.BreakUndoCoalescing;
        SetCaretTo(LineStartOffset(Line), Extend);
      end;
    vkEnd:
      begin
        FModel.BreakUndoCoalescing;
        SetCaretTo(LineEndOffset(Line), Extend);
      end;
    vkPrior:
      begin
        FModel.BreakUndoCoalescing;
        MoveVertical(-VisibleLineCount, Extend);
      end;
    vkNext:
      begin
        FModel.BreakUndoCoalescing;
        MoveVertical(VisibleLineCount, Extend);
      end;
    vkBack:
      FModel.DeleteBackward;
    vkDelete:
      FModel.DeleteForward;
    vkReturn:
      FModel.Insert(#10);
  else
    Result := False;
  end;
end;

function TMarkdownEditor.GetText: string;
begin
  Result := FModel.Text;
end;

procedure TMarkdownEditor.SetText(const Value: string);
begin
  FDesignSampleActive := False;
  FModel.LoadText(Value);
  FScrollOffset := 0;
  ScrollCaretIntoView;
  RedrawContent;
  SchedulePreviewUpdate;
end;

function TMarkdownEditor.IsTextStored: Boolean;
begin
  Result := not FDesignSampleActive;
end;

procedure TMarkdownEditor.SetThemePreset(const Value: TMarkdownThemePreset);
begin
  FThemePreset := Value;

  if FOwnsTheme then
    FTheme.Free;

  FTheme := TMarkdownTheme.CreatePreset(Value);
  FOwnsTheme := True;
  RedrawContent;
end;

function TMarkdownEditor.GetCaretPosition: Integer;
begin
  Result := FModel.CaretPosition;
end;

procedure TMarkdownEditor.SetCaretPosition(const Value: Integer);
begin
  FModel.CaretPosition := Value;
  ScrollCaretIntoView;
  RestartCaretBlink;
  RedrawContent;
end;

function TMarkdownEditor.GetSelectedText: string;
begin
  Result := FModel.SelectedText;
end;

procedure TMarkdownEditor.SetTheme(const Value: TMarkdownTheme);
begin
  const IsUnchanged = (Value = nil) or (Value = FTheme);
  if IsUnchanged then
    Exit;

  if FOwnsTheme then
    FTheme.Free;

  FTheme := Value;
  FOwnsTheme := False;
  RedrawContent;
end;

procedure TMarkdownEditor.SetShowLineNumbers(const Value: Boolean);
begin
  if Value = FShowLineNumbers then
    Exit;

  FShowLineNumbers := Value;
  RedrawContent;
end;

end.
