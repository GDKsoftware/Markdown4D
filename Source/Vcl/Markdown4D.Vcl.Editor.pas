unit Markdown4D.Vcl.Editor;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.Types,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Theme,
  Markdown4D.Editor.Model,
  Markdown4D.Editor.Highlighter,
  Markdown4D.Viewer.Lifetime,
  Markdown4D.Vcl.Painter,
  Markdown4D.Vcl.Viewer;

type
  TMarkdownEditor = class(TCustomControl)
  private
    const
      DefaultControlWidth = 400;
      DefaultControlHeight = 300;
      ReferencePixelsPerInch = 96;
      PreviewDebounceIntervalMilliseconds = 60;
      AutoScrollIntervalMilliseconds = 50;
      TextLeftPaddingDips = 6;
      GutterPaddingDips = 8;
      CaretWidthDips = 1;
      WheelLinesPerNotch = 3;
    var
      FLifetime: IMarkdownViewerLifetime;
      FModel: TMarkdownEditorModel;
      FHighlighter: TMarkdownSourceHighlighter;
      FTheme: TMarkdownTheme;
      FOwnsTheme: Boolean;
      FThemePreset: TMarkdownThemePreset;
      FDesignSampleActive: Boolean;
      FMeasureBitmap: TBitmap;
      FMeasurePainter: TMarkdownVclPainter;
      FMeasurePainterLifetime: IPainter;
      FBuffer: TBitmap;
      FScrollOffset: Integer;
      FShowLineNumbers: Boolean;
      FSelecting: Boolean;
      FSelectionAnchor: Integer;
      FClickCount: Integer;
      FLastClickTicks: Cardinal;
      FLastClickPos: TPoint;
      FDragPoint: TPoint;
      FAutoScrollTimer: TTimer;
      FPreview: TMarkdownViewer;
      FPreviewTimer: TTimer;
      FPreviewDirty: Boolean;
      FUpdatingPreview: Boolean;
      FOnChange: TNotifyEvent;
      FOnScroll: TNotifyEvent;
    procedure HandleModelChange(const Sender: TObject; const Range: TEditorReplaceRange);
    procedure HandlePreviewTimer(Sender: TObject);
    procedure HandleAutoScrollTimer(Sender: TObject);
    function NextClickCount(const X, Y: Integer): Integer;
    procedure UpdateSelectionToPoint(const X, Y: Integer);
    procedure UpdateAutoScroll(const X, Y: Integer);
    procedure SchedulePreviewUpdate;
    procedure RenderContent(const Canvas: TCanvas; const TargetWidth, TargetHeight, PixelsPerInch,
      ScrollY: Integer);
    procedure DrawLineTokens(const Painter: IPainter; const LineText: string;
      const Tokens: TArray<TMarkdownSourceToken>; const TextLeft, Top: Integer);
    procedure DrawGutterNumber(const Painter: IPainter; const LineIndex, GutterWidth, Top: Integer);
    function TokenColor(const Kind: TMarkdownSourceTokenKind): TLayoutColor;
    function GutterWidthPx(const Painter: IPainter; const PixelsPerInch: Integer): Integer;
    function CodeFont: TMarkdownFontStyle;
    function LineHeightPx: Integer;
    function VisibleLineCount: Integer;
    function TextLeftPx: Integer;
    function CaretWidthPx: Integer;
    function LineTextAt(const LineIndex: Integer): string;
    function LineStartOffset(const LineIndex: Integer): Integer;
    function LineEndOffset(const LineIndex: Integer): Integer;
    function OffsetAtLineX(const LineIndex, TargetX: Integer): Integer;
    function OffsetFromPoint(const X, Y: Integer): Integer;
    function CurrentAnchor: Integer;
    function ContentHeightPx: Integer;
    function MaxScrollOffset: Integer;
    procedure SetScrollOffset(const Value: Integer);
    procedure ScrollCaretIntoView;
    procedure UpdateScrollBar;
    procedure UpdateCaret;
    function CaretPixelPos: TPoint;
    procedure RecreateCaret;
    procedure RefreshAfterEdit;
    procedure MoveVertical(const LineDelta: Integer; const Extend: Boolean);
    procedure SetCaretTo(const Offset: Integer; const Extend: Boolean);
    procedure CopyToClipboard;
    procedure CutToClipboard;
    procedure PasteFromClipboard;
    procedure EnsureBufferSize;
    procedure RecomputeMetrics;
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
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;

  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure Resize; override;
    procedure ChangeScale(Multiplier, Divider: Integer; IsDpiChange: Boolean); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;

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
    property Constraints;
    property Enabled;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnScroll: TNotifyEvent read FOnScroll write FOnScroll;
  end;

implementation

uses
  Markdown4D.DesignSample,
  System.SysUtils,
  System.Math,
  System.UITypes,
  Vcl.Clipbrd;

constructor TMarkdownEditor.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  FLifetime := TMarkdownViewerLifetime.Create;

  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse];
  Width := DefaultControlWidth;
  Height := DefaultControlHeight;
  TabStop := True;

  FTheme := TMarkdownTheme.CreateLight;
  FOwnsTheme := True;

  FModel := TMarkdownEditorModel.Create;
  FModel.OnChange := HandleModelChange;
  FHighlighter := TMarkdownSourceHighlighter.Create;

  FMeasureBitmap := TBitmap.Create;
  FMeasureBitmap.SetSize(1, 1);
  FMeasurePainter := TMarkdownVclPainter.Create(FMeasureBitmap.Canvas, CurrentPPI);
  FMeasurePainterLifetime := FMeasurePainter;

  FBuffer := TBitmap.Create;

  FPreviewTimer := TTimer.Create(Self);
  FPreviewTimer.Enabled := False;
  FPreviewTimer.Interval := PreviewDebounceIntervalMilliseconds;
  FPreviewTimer.OnTimer := HandlePreviewTimer;

  FAutoScrollTimer := TTimer.Create(Self);
  FAutoScrollTimer.Enabled := False;
  FAutoScrollTimer.Interval := AutoScrollIntervalMilliseconds;
  FAutoScrollTimer.OnTimer := HandleAutoScrollTimer;
end;

destructor TMarkdownEditor.Destroy;
begin
  FLifetime.Kill;
  FPreview := nil;
  if FPreviewTimer <> nil then
    FPreviewTimer.Enabled := False;
  if FAutoScrollTimer <> nil then
    FAutoScrollTimer.Enabled := False;

  FHighlighter.Free;
  FModel.Free;
  FMeasurePainter := nil;
  FMeasurePainterLifetime := nil;
  FMeasureBitmap.Free;
  FBuffer.Free;
  if FOwnsTheme then
    FTheme.Free;

  inherited Destroy;
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
  FPreviewTimer.Enabled := False;
end;

procedure TMarkdownEditor.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);

  if (Operation = TOperation.opRemove) and (AComponent = FPreview) then
  begin
    FPreview := nil;
    FPreviewDirty := False;
    FPreviewTimer.Enabled := False;
  end;
end;

procedure TMarkdownEditor.FlushPreview;
begin
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
  RenderContent(Bitmap.Canvas, Bitmap.Width, Bitmap.Height, CurrentPPI, 0);
end;

function TMarkdownEditor.FirstVisibleSourceLine: Integer;
begin
  Result := FScrollOffset div LineHeightPx;
end;

function TMarkdownEditor.SourceLineStartOffset(const LineIndex: Integer): Integer;
begin
  Result := FModel.OffsetOfLineStart(LineIndex);
end;

procedure TMarkdownEditor.HandleModelChange(const Sender: TObject; const Range: TEditorReplaceRange);
begin
  UpdateScrollBar;
  ScrollCaretIntoView;
  UpdateCaret;
  Invalidate;
  SchedulePreviewUpdate;

  if Assigned(FOnChange) then
    FOnChange(Self);
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
  FPreviewTimer.Enabled := False;
  FPreviewTimer.Enabled := True;
end;

procedure TMarkdownEditor.Paint;
begin
  EnsureDesignSample;
  EnsureBufferSize;
  RenderContent(FBuffer.Canvas, Max(1, ClientWidth), Max(1, ClientHeight), CurrentPPI, FScrollOffset);
  Canvas.Draw(0, 0, FBuffer);
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
  UpdateScrollBar;
end;

procedure TMarkdownEditor.RenderContent(const Canvas: TCanvas; const TargetWidth, TargetHeight, PixelsPerInch,
  ScrollY: Integer);
begin
  const Painter = TMarkdownVclPainter.Create(Canvas, PixelsPerInch);
  const PainterLifetime: IPainter = Painter;

  Painter.FillRect(TLayoutRectF.Create(0, 0, TargetWidth, TargetHeight), FTheme.BackgroundColor);

  var LineHeight := Round(Painter.LineHeight(CodeFont));
  if LineHeight < 1 then
    LineHeight := 1;

  const GutterWidth = GutterWidthPx(PainterLifetime, PixelsPerInch);
  const TextLeft = GutterWidth + MulDiv(TextLeftPaddingDips, PixelsPerInch, ReferencePixelsPerInch);

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
end;

procedure TMarkdownEditor.DrawLineTokens(const Painter: IPainter; const LineText: string;
  const Tokens: TArray<TMarkdownSourceToken>; const TextLeft, Top: Integer);
begin
  for var Token in Tokens do
  begin
    const Segment = Copy(LineText, Token.Start, Token.Length);
    if Segment = '' then
      Continue;

    const Prefix = Copy(LineText, 1, Token.Start - 1);
    const OffsetX = Round(Painter.MeasureText(Prefix, CodeFont).Width);
    Painter.DrawTextRun(TLayoutPointF.Create(TextLeft + OffsetX, Top), Segment, CodeFont, TokenColor(Token.Kind));
  end;
end;

procedure TMarkdownEditor.DrawGutterNumber(const Painter: IPainter; const LineIndex, GutterWidth, Top: Integer);
begin
  const Number = IntToStr(LineIndex + 1);
  const Padding = MulDiv(GutterPaddingDips, CurrentPPI, ReferencePixelsPerInch);
  const NumberWidth = Round(Painter.MeasureText(Number, CodeFont).Width);
  const NumberLeft = GutterWidth - Padding - NumberWidth;
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

function TMarkdownEditor.GutterWidthPx(const Painter: IPainter; const PixelsPerInch: Integer): Integer;
begin
  if not FShowLineNumbers then
    Exit(0);

  const Digits = Length(IntToStr(Max(1, FModel.LineCount)));
  const Sample = StringOfChar('0', Digits);
  const Padding = MulDiv(GutterPaddingDips, PixelsPerInch, ReferencePixelsPerInch);
  Result := Round(Painter.MeasureText(Sample, CodeFont).Width) + 2 * Padding;
end;

function TMarkdownEditor.CodeFont: TMarkdownFontStyle;
begin
  Result := FTheme.CodeFont;
end;

function TMarkdownEditor.LineHeightPx: Integer;
begin
  Result := Round(FMeasurePainter.LineHeight(CodeFont));
  if Result < 1 then
    Result := 1;
end;

function TMarkdownEditor.VisibleLineCount: Integer;
begin
  Result := Max(1, ClientHeight div LineHeightPx);
end;

function TMarkdownEditor.TextLeftPx: Integer;
begin
  Result := GutterWidthPx(FMeasurePainterLifetime, CurrentPPI) +
    MulDiv(TextLeftPaddingDips, CurrentPPI, ReferencePixelsPerInch);
end;

function TMarkdownEditor.CaretWidthPx: Integer;
begin
  Result := Max(1, MulDiv(CaretWidthDips, CurrentPPI, ReferencePixelsPerInch));
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

function TMarkdownEditor.OffsetAtLineX(const LineIndex, TargetX: Integer): Integer;
begin
  const LineText = LineTextAt(LineIndex);
  const Start = LineStartOffset(LineIndex);

  var BestColumn := 0;
  var BestDistance := Abs(TargetX);
  for var Count := 1 to Length(LineText) do
  begin
    const Width = Round(FMeasurePainter.MeasureText(Copy(LineText, 1, Count), CodeFont).Width);
    const Distance = Abs(TargetX - Width);
    if Distance < BestDistance then
    begin
      BestDistance := Distance;
      BestColumn := Count;
    end;
  end;

  Result := Start + BestColumn;
end;

function TMarkdownEditor.OffsetFromPoint(const X, Y: Integer): Integer;
begin
  const Line = EnsureRange((Y + FScrollOffset) div LineHeightPx, 0, FModel.LineCount - 1);
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

function TMarkdownEditor.ContentHeightPx: Integer;
begin
  Result := FModel.LineCount * LineHeightPx;
end;

function TMarkdownEditor.MaxScrollOffset: Integer;
begin
  Result := Max(0, ContentHeightPx - ClientHeight);
end;

procedure TMarkdownEditor.SetScrollOffset(const Value: Integer);
begin
  if not HandleAllocated then
    Exit;

  const Clamped = EnsureRange(Value, 0, MaxScrollOffset);
  if Clamped = FScrollOffset then
    Exit;

  FScrollOffset := Clamped;
  UpdateScrollBar;
  UpdateCaret;
  Invalidate;

  if Assigned(FOnScroll) then
    FOnScroll(Self);
end;

procedure TMarkdownEditor.ScrollCaretIntoView;
begin
  if not HandleAllocated then
    Exit;

  const Line = FModel.LineIndexOfOffset(FModel.CaretPosition);
  const Top = Line * LineHeightPx;
  const Bottom = Top + LineHeightPx;

  var NewOffset := FScrollOffset;
  if Top < NewOffset then
    NewOffset := Top
  else if Bottom > NewOffset + ClientHeight then
    NewOffset := Bottom - ClientHeight;

  SetScrollOffset(NewOffset);
end;

procedure TMarkdownEditor.UpdateScrollBar;
begin
  if not HandleAllocated then
    Exit;

  var Info := Default(TScrollInfo);
  Info.cbSize := SizeOf(Info);
  Info.fMask := SIF_RANGE or SIF_PAGE or SIF_POS;
  Info.nMin := 0;
  Info.nMax := Max(0, ContentHeightPx - 1);
  Info.nPage := ClientHeight;
  Info.nPos := FScrollOffset;
  SetScrollInfo(Handle, SB_VERT, Info, True);
end;

procedure TMarkdownEditor.UpdateCaret;
begin
  if not (Focused and HandleAllocated) then
    Exit;

  const Position = CaretPixelPos;
  Winapi.Windows.SetCaretPos(Position.X, Position.Y);
end;

function TMarkdownEditor.CaretPixelPos: TPoint;
begin
  const Caret = FModel.CaretPosition;
  const Line = FModel.LineIndexOfOffset(Caret);
  const Prefix = Copy(FModel.Text, LineStartOffset(Line) + 1, Caret - LineStartOffset(Line));
  const OffsetX = Round(FMeasurePainter.MeasureText(Prefix, CodeFont).Width);
  Result := TPoint.Create(TextLeftPx + OffsetX, Line * LineHeightPx - FScrollOffset);
end;

procedure TMarkdownEditor.RecreateCaret;
begin
  if not (Focused and HandleAllocated) then
    Exit;

  Winapi.Windows.CreateCaret(Handle, 0, CaretWidthPx, LineHeightPx);
  UpdateCaret;
  Winapi.Windows.ShowCaret(Handle);
end;

procedure TMarkdownEditor.RefreshAfterEdit;
begin
  UpdateScrollBar;
  ScrollCaretIntoView;
  UpdateCaret;
  Invalidate;
end;

procedure TMarkdownEditor.MoveVertical(const LineDelta: Integer; const Extend: Boolean);
begin
  const Caret = FModel.CaretPosition;
  const Line = FModel.LineIndexOfOffset(Caret);
  const Prefix = Copy(FModel.Text, LineStartOffset(Line) + 1, Caret - LineStartOffset(Line));
  const TargetX = Round(FMeasurePainter.MeasureText(Prefix, CodeFont).Width);
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

procedure TMarkdownEditor.CopyToClipboard;
begin
  const Selected = FModel.SelectedText;
  if Selected = '' then
    Exit;

  Clipboard.AsText := Selected;
end;

procedure TMarkdownEditor.CutToClipboard;
begin
  if not FModel.HasSelection then
    Exit;

  CopyToClipboard;
  FModel.DeleteBackward;
end;

procedure TMarkdownEditor.PasteFromClipboard;
begin
  if not Clipboard.HasFormat(CF_UNICODETEXT) then
    Exit;

  const Pasted = Clipboard.AsText;
  if Pasted = '' then
    Exit;

  var Normalized := StringReplace(Pasted, #13#10, #10, [rfReplaceAll]);
  Normalized := StringReplace(Normalized, #13, #10, [rfReplaceAll]);
  FModel.BreakUndoCoalescing;
  FModel.Insert(Normalized);
end;

procedure TMarkdownEditor.EnsureBufferSize;
begin
  const BufferWidth = Max(1, ClientWidth);
  const BufferHeight = Max(1, ClientHeight);
  const SizeChanged = (FBuffer.Width <> BufferWidth) or (FBuffer.Height <> BufferHeight);
  if SizeChanged then
    FBuffer.SetSize(BufferWidth, BufferHeight);
end;

procedure TMarkdownEditor.RecomputeMetrics;
begin
  FMeasurePainter.PixelsPerInch := CurrentPPI;
  UpdateScrollBar;
  RecreateCaret;
  Invalidate;
end;

procedure TMarkdownEditor.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);

  Params.Style := Params.Style or WS_VSCROLL;
end;

procedure TMarkdownEditor.CreateWnd;
begin
  inherited CreateWnd;

  EnsureDesignSample;

  FMeasurePainter.PixelsPerInch := CurrentPPI;
  UpdateScrollBar;
end;

procedure TMarkdownEditor.Resize;
begin
  inherited Resize;

  UpdateScrollBar;
  Invalidate;
end;

procedure TMarkdownEditor.ChangeScale(Multiplier, Divider: Integer; IsDpiChange: Boolean);
begin
  inherited ChangeScale(Multiplier, Divider, IsDpiChange);

  FScrollOffset := MulDiv(FScrollOffset, Multiplier, Divider);
  RecomputeMetrics;
end;

procedure TMarkdownEditor.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);

  if Button <> TMouseButton.mbLeft then
    Exit;

  if CanFocus then
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
    FLastClickTicks := GetTickCount;
    FLastClickPos := TPoint.Create(X, Y);
    UpdateCaret;
    Invalidate;
    Exit;
  end;

  FClickCount := NextClickCount(X, Y);

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

  UpdateCaret;
  Invalidate;
end;

procedure TMarkdownEditor.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);

  if not FSelecting then
    Exit;

  UpdateSelectionToPoint(X, Y);
  UpdateAutoScroll(X, Y);
end;

procedure TMarkdownEditor.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);

  if Button <> TMouseButton.mbLeft then
    Exit;

  FSelecting := False;
  if FAutoScrollTimer <> nil then
    FAutoScrollTimer.Enabled := False;
end;

function TMarkdownEditor.NextClickCount(const X, Y: Integer): Integer;
begin
  const Ticks = GetTickCount;
  const WithinTime = (Ticks - FLastClickTicks) <= GetDoubleClickTime;
  const WithinDistance = (Abs(X - FLastClickPos.X) <= GetSystemMetrics(SM_CXDOUBLECLK)) and
    (Abs(Y - FLastClickPos.Y) <= GetSystemMetrics(SM_CYDOUBLECLK));

  const IsRepeat = WithinTime and WithinDistance and (FClickCount >= 1) and (FClickCount < 3);
  if IsRepeat then
    Result := FClickCount + 1
  else
    Result := 1;

  FLastClickTicks := Ticks;
  FLastClickPos := TPoint.Create(X, Y);
end;

procedure TMarkdownEditor.UpdateSelectionToPoint(const X, Y: Integer);
begin
  const Offset = OffsetFromPoint(X, Y);
  FModel.SetSelection(FSelectionAnchor, Offset - FSelectionAnchor);
  UpdateCaret;
  Invalidate;
end;

procedure TMarkdownEditor.UpdateAutoScroll(const X, Y: Integer);
begin
  if (FAutoScrollTimer = nil) or not HandleAllocated then
    Exit;

  const Outside = (Y < 0) or (Y > ClientHeight);
  const ShouldScroll = Outside and FSelecting;

  if ShouldScroll then
    FDragPoint := TPoint.Create(X, Y);

  FAutoScrollTimer.Enabled := ShouldScroll;
end;

procedure TMarkdownEditor.HandleAutoScrollTimer(Sender: TObject);
begin
  if not FLifetime.IsAlive then
    Exit;

  if not (FSelecting and HandleAllocated) then
  begin
    FAutoScrollTimer.Enabled := False;
    Exit;
  end;

  if FDragPoint.Y < 0 then
    SetScrollOffset(FScrollOffset - LineHeightPx)
  else
    SetScrollOffset(FScrollOffset + LineHeightPx);

  UpdateSelectionToPoint(FDragPoint.X, FDragPoint.Y);
end;

function TMarkdownEditor.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  const Notches = WheelDelta / WHEEL_DELTA;
  SetScrollOffset(FScrollOffset - Round(Notches * WheelLinesPerNotch * LineHeightPx));
  Result := True;
end;

procedure TMarkdownEditor.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);

  const Extend = ssShift in Shift;
  const Caret = FModel.CaretPosition;
  const Line = FModel.LineIndexOfOffset(Caret);

  if ssCtrl in Shift then
  begin
    case Key of
      Ord('A'):
        FModel.SelectAll;
      Ord('C'):
        CopyToClipboard;
      Ord('X'):
        CutToClipboard;
      Ord('V'):
        PasteFromClipboard;
      Ord('Z'):
        FModel.Undo;
      Ord('Y'):
        FModel.Redo;
      Ord('B'):
        FModel.ExecuteCommand(TEditorCommand.Bold);
      Ord('I'):
        FModel.ExecuteCommand(TEditorCommand.Italic);
      Ord('K'):
        FModel.ExecuteCommand(TEditorCommand.Link);
      VK_LEFT:
        begin
          FModel.BreakUndoCoalescing;
          FModel.MoveWordLeft(Extend);
        end;
      VK_RIGHT:
        begin
          FModel.BreakUndoCoalescing;
          FModel.MoveWordRight(Extend);
        end;
      VK_HOME:
        begin
          FModel.BreakUndoCoalescing;
          SetCaretTo(0, Extend);
        end;
      VK_END:
        begin
          FModel.BreakUndoCoalescing;
          SetCaretTo(Length(FModel.Text), Extend);
        end;
    else
      Exit;
    end;

    Key := 0;
    RefreshAfterEdit;
    Exit;
  end;

  case Key of
    VK_LEFT:
      begin
        FModel.BreakUndoCoalescing;
        FModel.MoveCaret(-1, Extend);
      end;
    VK_RIGHT:
      begin
        FModel.BreakUndoCoalescing;
        FModel.MoveCaret(1, Extend);
      end;
    VK_UP:
      begin
        FModel.BreakUndoCoalescing;
        MoveVertical(-1, Extend);
      end;
    VK_DOWN:
      begin
        FModel.BreakUndoCoalescing;
        MoveVertical(1, Extend);
      end;
    VK_HOME:
      begin
        FModel.BreakUndoCoalescing;
        SetCaretTo(LineStartOffset(Line), Extend);
      end;
    VK_END:
      begin
        FModel.BreakUndoCoalescing;
        SetCaretTo(LineEndOffset(Line), Extend);
      end;
    VK_PRIOR:
      begin
        FModel.BreakUndoCoalescing;
        MoveVertical(-VisibleLineCount, Extend);
      end;
    VK_NEXT:
      begin
        FModel.BreakUndoCoalescing;
        MoveVertical(VisibleLineCount, Extend);
      end;
    VK_BACK:
      FModel.DeleteBackward;
    VK_DELETE:
      FModel.DeleteForward;
    VK_RETURN:
      FModel.Insert(#10);
  else
    Exit;
  end;

  Key := 0;
  RefreshAfterEdit;
end;

procedure TMarkdownEditor.KeyPress(var Key: Char);
begin
  inherited KeyPress(Key);

  if Key < ' ' then
    Exit;

  FModel.Insert(Key);
  Key := #0;
end;

procedure TMarkdownEditor.WMVScroll(var Message: TWMVScroll);
begin
  case Message.ScrollCode of
    SB_LINEUP:
      SetScrollOffset(FScrollOffset - LineHeightPx);
    SB_LINEDOWN:
      SetScrollOffset(FScrollOffset + LineHeightPx);
    SB_PAGEUP:
      SetScrollOffset(FScrollOffset - ClientHeight);
    SB_PAGEDOWN:
      SetScrollOffset(FScrollOffset + ClientHeight);
    SB_TOP:
      SetScrollOffset(0);
    SB_BOTTOM:
      SetScrollOffset(MaxScrollOffset);
    SB_THUMBPOSITION, SB_THUMBTRACK:
      begin
        var Info := Default(TScrollInfo);
        Info.cbSize := SizeOf(Info);
        Info.fMask := SIF_TRACKPOS;
        if GetScrollInfo(Handle, SB_VERT, Info) then
          SetScrollOffset(Info.nTrackPos);
      end;
  end;

  Message.Result := 0;
end;

procedure TMarkdownEditor.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TMarkdownEditor.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS or DLGC_WANTCHARS;
end;

procedure TMarkdownEditor.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;

  RecreateCaret;
  Invalidate;
end;

procedure TMarkdownEditor.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;

  Winapi.Windows.DestroyCaret;
  Invalidate;
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
  UpdateScrollBar;
  ScrollCaretIntoView;
  UpdateCaret;
  Invalidate;
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
  RecomputeMetrics;
end;

function TMarkdownEditor.GetCaretPosition: Integer;
begin
  Result := FModel.CaretPosition;
end;

procedure TMarkdownEditor.SetCaretPosition(const Value: Integer);
begin
  FModel.CaretPosition := Value;
  ScrollCaretIntoView;
  UpdateCaret;
  Invalidate;
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
  RecomputeMetrics;
end;

procedure TMarkdownEditor.SetShowLineNumbers(const Value: Boolean);
begin
  if Value = FShowLineNumbers then
    Exit;

  FShowLineNumbers := Value;
  UpdateCaret;
  Invalidate;
end;

end.
