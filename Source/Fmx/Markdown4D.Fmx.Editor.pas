unit Markdown4D.Fmx.Editor;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.Types,
  System.UITypes,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  FMX.Menus,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Theme,
  Markdown4D.Editor.Model,
  Markdown4D.Editor.Keys,
  Markdown4D.Editor.ContextMenu,
  Markdown4D.Editor.Highlights,
  Markdown4D.Editor.Highlighter,
  Markdown4D.Editor.Sync,
  Markdown4D.Viewer.Lifetime,
  Markdown4D.Fmx.Painter,
  Markdown4D.Fmx.Viewer;

type
  // Fired whenever either pane scrolls while a preview is linked, reporting the
  // source line now at the top. Hosts use it to keep an outline/ToC in sync.
  TMarkdownSyncScrollEvent = procedure(Sender: TObject; const SourceLine: Integer) of object;

  TMarkdownEditor = class(TControl)
  private
    const
      DefaultControlWidth = 400;
      DefaultControlHeight = 300;
      SelectionFillColor = TLayoutColor($402F81F7);
      MatchFillColor = TLayoutColor($55E3B341);
      CaretBlinkIntervalMilliseconds = 500;
      DoubleClickWindowMilliseconds = 500;
      DoubleClickSlopDips = 4;
      MinimumWrapWidthDips = 48;
      FoldMarkerWidthDips = 14;
      DeleteChar = #127;
      DefaultIndentWidth = 2;
      DragThresholdPx = 4;
    type
      // One on-screen line from soft-wrapping a source line. Offsets are absolute
      // into the model text and the range excludes the trailing line break.
      TVisualRow = record
        LineIndex: Integer;
        StartOffset: Integer;
        EndOffset: Integer;
        IsFirst: Boolean;
      end;
    var
      FLifetime: IMarkdownViewerLifetime;
      FModel: TMarkdownEditorModel;
      FHighlighter: TMarkdownSourceHighlighter;
      FMatches: TMarkdownEditorHighlights;
      FTheme: TMarkdownTheme;
      FOwnsTheme: Boolean;
      FThemePreset: TMarkdownThemePreset;
      FDesignSampleActive: Boolean;
      FMeasureBitmap: TBitmap;
      FMeasurePainter: TMarkdownFmxPainter;
      FMeasurePainterLifetime: IPainter;
      FScrollOffset: Single;
      FIndentWidth: Integer;
      FShowLineNumbers: Boolean;
      FSelecting: Boolean;
      FSelectionAnchor: Integer;
      FDragPending: Boolean;
      FDraggingSelection: Boolean;
      FDragOriginX: Single;
      FDragOriginY: Single;
      FDragOffset: Integer;
      FContextMenu: TPopupMenu;
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
      FSync: TMarkdownEditorSync;
      FSyncScroll: Boolean;
      FSyncing: Boolean;
      FRows: TArray<TVisualRow>;
      FWrapWidth: Single;
      FOnChange: TNotifyEvent;
      FOnScroll: TNotifyEvent;
      FOnSyncScroll: TMarkdownSyncScrollEvent;
    procedure CreateCaretTimer;
    procedure CreatePreviewTimer;
    procedure CreateAutoScrollTimer;
    procedure HandleModelChange(const Sender: TObject; const Range: TEditorReplaceRange);
    procedure HandleCaretTimer(Sender: TObject);
    procedure HandlePreviewTimer(Sender: TObject);
    procedure HandleAutoScrollTimer(Sender: TObject);
    function ClickCountAt(const X, Y: Single; const Shift: TShiftState; const Ticks: Cardinal): Integer;
    procedure RecordClick(const X, Y: Single; const Ticks: Cardinal);
    procedure UpdateSelectionToPoint(const X, Y: Single);
    procedure UpdateAutoScroll(const X, Y: Single);
    procedure SchedulePreviewUpdate;
    procedure SetPreview(const Value: TMarkdownViewer);
    procedure UnhookPreviewScroll;
    procedure HandleInternalPreviewScroll(Sender: TObject);
    procedure SyncPreviewToEditor;
    procedure RestorePreviewScroll(const PreviousOffset: Single);
    procedure UpdateSync;
    procedure DoSyncScroll(const SourceLine: Integer);
    procedure RenderContent(const Target: TCanvas; const TargetWidth, TargetHeight, ScrollY: Single;
      const DrawCaret: Boolean);
    procedure RebuildRows;
    procedure AppendWrappedRows(const Rows: TList<TVisualRow>; const LineIndex: Integer);
    function MakeRow(const LineIndex, StartOffset, EndOffset: Integer; const IsFirst: Boolean): TVisualRow;
    function NextWrapLength(const LineText: string; const StartCol: Integer): Integer;
    function LastSpaceWithin(const LineText: string; const StartCol, MaxLength: Integer): Integer;
    function WrapWidthPx: Single;
    function RowCount: Integer;
    function RowIndexOfOffset(const Offset: Integer): Integer;
    function OffsetAtRowX(const RowIndex: Integer; const TargetX: Single): Integer;
    function RowText(const Row: TVisualRow): string;
    procedure DrawRowSelection(const Painter: IPainter; const Row: TVisualRow;
      const TextLeft, Top, TargetWidth: Single);
    procedure DrawRowMatches(const Painter: IPainter; const Row: TVisualRow; const TextLeft, Top: Single);
    procedure DrawRowTokens(const Painter: IPainter; const Row: TVisualRow; const LineText: string;
      const Tokens: TArray<TMarkdownSourceToken>; const TextLeft, Top: Single);
    procedure DrawGutterNumber(const Painter: IPainter; const LineIndex: Integer; const GutterWidth, Top: Single);
    procedure DrawFoldMarker(const Painter: IPainter; const GutterWidth, Top: Single; const Collapsed: Boolean);
    function HandleFoldClick(const X, Y: Single): Boolean;
    function BeginSelectionDrag(const X, Y: Single; const Offset: Integer): Boolean;
    procedure UpdateSelectionDrag(const X, Y: Single);
    function FinishSelectionDrag(const X, Y: Single): Boolean;
    procedure PopupContextMenu(const X, Y: Single);
    procedure HandleContextItemClick(Sender: TObject);
    function ClipboardHasText: Boolean;
    function FoldGutterWidthPx: Single;
    function TokenColor(const Kind: TMarkdownSourceTokenKind): TLayoutColor;
    function GutterWidthPx(const Painter: IPainter): Single;
    function CodeFont: TMarkdownFontStyle;
    function LineHeightPx: Single;
    function VisibleLineCount: Integer;
    function TextLeftPx: Single;
    function CaretWidthPx: Single;
    function LineTextAt(const LineIndex: Integer): string;
    function LineStartOffset(const LineIndex: Integer): Integer;
    function OffsetFromPoint(const X, Y: Single): Integer;
    function CurrentAnchor: Integer;
    function CaretPixelPos(const ScrollY: Single): TLayoutPointF;
    function ContentHeightPx: Single;
    function MaxScrollOffset: Single;
    procedure SetScrollOffset(const Value: Single);
    procedure ScrollCaretIntoView;
    procedure RedrawContent;
    procedure RevealSelection;
    procedure RefreshAfterEdit;
    procedure RestartCaretBlink;
    procedure MoveVertical(const RowDelta: Integer; const Extend: Boolean);
    procedure SetCaretTo(const Offset: Integer; const Extend: Boolean);
    function CopyToClipboard: Boolean;
    procedure CutToClipboard;
    procedure PasteFromClipboard;
    function HandleKey(const Key: Word; const Shift: TShiftState): Boolean;
    function ApplyKeyStroke(const Stroke: TEditorKeyStroke): Boolean;
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
    // Takes over Value as the new content through the smallest possible edit, so
    // undo history, caret and selection survive. Returns False when the text was
    // already identical.
    function MergeText(const Value: string): Boolean;
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
    procedure ScrollToSourceLine(const LineIndex: Integer);
    function SaveEditState: IMarkdownEditorState;
    procedure LoadEditState(const State: IMarkdownEditorState);
    // Paints every occurrence of Needle, so a find bar can show all hits at
    // once. The marks follow later edits until they are cleared.
    procedure HighlightMatches(const Needle: string); overload;
    procedure HighlightMatches(const Needle: string; const Options: TMarkdownFindOptions); overload;
    procedure ClearHighlights;
    function HighlightCount: Integer;
    function FindMatchCount(const Needle: string): Integer; overload;
    function FindMatchCount(const Needle: string; const Options: TMarkdownFindOptions): Integer; overload;
    function FindNext(const Needle: string): Boolean; overload;
    function FindNext(const Needle: string; const Options: TMarkdownFindOptions): Boolean; overload;
    function FindPrevious(const Needle: string; const Options: TMarkdownFindOptions): Boolean;
    function ReplaceCurrent(const Needle, Replacement: string; const Options: TMarkdownFindOptions): Boolean;
    function ReplaceAll(const Needle, Replacement: string; const Options: TMarkdownFindOptions): Integer;
    property CaretPosition: Integer read GetCaretPosition write SetCaretPosition;
    property SelectedText: string read GetSelectedText;
    property Theme: TMarkdownTheme read FTheme write SetTheme;

  published
    property Text: string read GetText write SetText stored IsTextStored;
    property ThemePreset: TMarkdownThemePreset read FThemePreset write SetThemePreset
      default TMarkdownThemePreset.Light;
    property ShowLineNumbers: Boolean read FShowLineNumbers write SetShowLineNumbers default False;
    // Spaces inserted by Tab and removed by Shift+Tab.
    property IndentWidth: Integer read FIndentWidth write FIndentWidth default DefaultIndentWidth;
    // Link an editor to a viewer at design time to get a live preview and, when
    // SyncScroll is on, two-way scroll synchronisation between the panes.
    property Preview: TMarkdownViewer read FPreview write SetPreview;
    property SyncScroll: Boolean read FSyncScroll write FSyncScroll default True;
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
    property OnSyncScroll: TMarkdownSyncScrollEvent read FOnSyncScroll write FOnSyncScroll;
  end;

implementation

uses
  Markdown4D.DesignSample,
  System.SysUtils,
  System.Math,
  System.Rtti,
  FMX.Platform,
  Markdown4D,
  Markdown4D.Defines,
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
  FMatches := TMarkdownEditorHighlights.Create;
  FSync := TMarkdownEditorSync.Create;
  FSyncScroll := True;
  FIndentWidth := DefaultIndentWidth;

  FMeasureBitmap := TBitmap.Create(1, 1);
  FMeasurePainter := TMarkdownFmxPainter.Create(FMeasureBitmap.Canvas);
  FMeasurePainterLifetime := FMeasurePainter;

  FCaretVisible := True;
  CreateCaretTimer;
  CreatePreviewTimer;
  CreateAutoScrollTimer;

  RebuildRows;
end;

destructor TMarkdownEditor.Destroy;
begin
  FLifetime.Shutdown;
  FPreview := nil;
  if FPreviewTimer <> nil then
    FPreviewTimer.Enabled := False;
  if FCaretTimer <> nil then
    FCaretTimer.Enabled := False;
  if FAutoScrollTimer <> nil then
    FAutoScrollTimer.Enabled := False;

  FHighlighter.Free;
  FMatches.Free;
  FModel.Free;
  FSync.Free;
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

function TMarkdownEditor.MergeText(const Value: string): Boolean;
begin
  FDesignSampleActive := False;

  Result := FModel.MergeText(Value);
  if not Result then
    Exit;

  RebuildRows;
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

procedure TMarkdownEditor.SetPreview(const Value: TMarkdownViewer);
begin
  if Value = FPreview then
    Exit;

  AttachPreview(Value);
end;

procedure TMarkdownEditor.UnhookPreviewScroll;
begin
  if FPreview = nil then
    Exit;

  var Ours: TNotifyEvent := HandleInternalPreviewScroll;
  if (TMethod(FPreview.OnScroll).Code = TMethod(Ours).Code) and
     (TMethod(FPreview.OnScroll).Data = TMethod(Ours).Data) then
    FPreview.OnScroll := nil;
end;

procedure TMarkdownEditor.AttachPreview(const Viewer: TMarkdownViewer);
begin
  if FPreview <> nil then
  begin
    FPreview.RemoveFreeNotification(Self);
    UnhookPreviewScroll;
  end;

  FPreview := Viewer;
  if FPreview <> nil then
  begin
    FPreview.FreeNotification(Self);
    FPreview.OnScroll := HandleInternalPreviewScroll;
  end;

  FPreviewDirty := True;
  FlushPreview;
end;

procedure TMarkdownEditor.DetachPreview;
begin
  if FPreview <> nil then
  begin
    FPreview.RemoveFreeNotification(Self);
    UnhookPreviewScroll;
  end;

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

  const PreviousOffset = FPreview.ScrollOffset;

  FUpdatingPreview := True;
  try
    FPreview.Text := FModel.Text;
  finally
    FUpdatingPreview := False;
  end;

  UpdateSync;
  RestorePreviewScroll(PreviousOffset);
end;

procedure TMarkdownEditor.RestorePreviewScroll(const PreviousOffset: Single);
begin
  // Re-rendering the preview parks it back at the top, which would yank the
  // reader away on every keystroke. Linked panes follow the editor; an unlinked
  // preview keeps the offset it had.
  if FSyncScroll then
  begin
    SyncPreviewToEditor;
    Exit;
  end;

  FPreview.ScrollOffset := PreviousOffset;
end;

procedure TMarkdownEditor.UpdateSync;
begin
  if FPreview = nil then
    Exit;

  const Document = TMarkdown.Parse(FModel.Text, TMarkdownDialect.Gfm);
  FSync.Update(Document, FPreview.DisplayList, FModel.Text);
end;

procedure TMarkdownEditor.HandleInternalPreviewScroll(Sender: TObject);
begin
  if (not FSyncScroll) or FSyncing or (FPreview = nil) then
    Exit;

  FSyncing := True;
  try
    const SourceLine = FSync.PreviewOffsetToSourceLine(FPreview.ScrollOffset);
    ScrollToSourceLine(SourceLine);
    DoSyncScroll(SourceLine);
  finally
    FSyncing := False;
  end;
end;

procedure TMarkdownEditor.SyncPreviewToEditor;
begin
  if (not FSyncScroll) or FSyncing or (FPreview = nil) then
    Exit;

  FSyncing := True;
  try
    const SourceLine = FirstVisibleSourceLine;
    FPreview.ScrollOffset := FSync.SourceLineToPreviewOffset(SourceLine);
    DoSyncScroll(SourceLine);
  finally
    FSyncing := False;
  end;
end;

procedure TMarkdownEditor.DoSyncScroll(const SourceLine: Integer);
begin
  if Assigned(FOnSyncScroll) then
    FOnSyncScroll(Self, SourceLine);
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
  if Length(FRows) = 0 then
    Exit(0);

  const RowIndex = EnsureRange(Trunc(FScrollOffset / LineHeightPx), 0, High(FRows));
  Result := FRows[RowIndex].LineIndex;
end;

function TMarkdownEditor.SourceLineStartOffset(const LineIndex: Integer): Integer;
begin
  Result := FModel.OffsetOfLineStart(LineIndex);
end;

procedure TMarkdownEditor.ScrollToSourceLine(const LineIndex: Integer);
begin
  for var Index := 0 to High(FRows) do
  begin
    const IsTargetLine = FRows[Index].LineIndex = LineIndex;
    if IsTargetLine then
    begin
      SetScrollOffset(Index * LineHeightPx);
      Exit;
    end;
  end;
end;

function TMarkdownEditor.SaveEditState: IMarkdownEditorState;
begin
  Result := FModel.CaptureState;
end;

procedure TMarkdownEditor.LoadEditState(const State: IMarkdownEditorState);
begin
  FDesignSampleActive := False;
  FModel.RestoreState(State);

  FScrollOffset := 0;
  RebuildRows;
  ScrollCaretIntoView;
  RedrawContent;
  SchedulePreviewUpdate;
end;

procedure TMarkdownEditor.HighlightMatches(const Needle: string);
begin
  HighlightMatches(Needle, Default(TMarkdownFindOptions));
end;

procedure TMarkdownEditor.HighlightMatches(const Needle: string; const Options: TMarkdownFindOptions);
begin
  FMatches.SetNeedle(FModel, Needle, Options);
  RedrawContent;
end;

procedure TMarkdownEditor.ClearHighlights;
begin
  FMatches.Clear;
  RedrawContent;
end;

function TMarkdownEditor.HighlightCount: Integer;
begin
  Result := FMatches.Count;
end;

function TMarkdownEditor.FindMatchCount(const Needle: string): Integer;
begin
  Result := FModel.FindText(Needle);
end;

function TMarkdownEditor.FindMatchCount(const Needle: string; const Options: TMarkdownFindOptions): Integer;
begin
  Result := FModel.FindText(Needle, Options);
end;

function TMarkdownEditor.FindNext(const Needle: string): Boolean;
begin
  Result := FindNext(Needle, Default(TMarkdownFindOptions));
end;

function TMarkdownEditor.FindNext(const Needle: string; const Options: TMarkdownFindOptions): Boolean;
begin
  if Needle = '' then
    Exit(False);

  const StartAfter = FModel.SelectionStart + FModel.SelectionLength - 1;
  const Offset = FModel.FindNext(Needle, StartAfter, Options);
  if Offset < 0 then
    Exit(False);

  FModel.SetSelection(Offset, Length(Needle));
  RevealSelection;

  Result := True;
end;

function TMarkdownEditor.FindPrevious(const Needle: string; const Options: TMarkdownFindOptions): Boolean;
begin
  if Needle = '' then
    Exit(False);

  const Offset = FModel.FindPrevious(Needle, FModel.SelectionStart, Options);
  if Offset < 0 then
    Exit(False);

  FModel.SetSelection(Offset, Length(Needle));
  RevealSelection;

  Result := True;
end;

function TMarkdownEditor.ReplaceCurrent(const Needle, Replacement: string;
  const Options: TMarkdownFindOptions): Boolean;
begin
  if Needle = '' then
    Exit(False);

  Result := FModel.ReplaceCurrent(Needle, Replacement, Options);
  RevealSelection;
end;

function TMarkdownEditor.ReplaceAll(const Needle, Replacement: string;
  const Options: TMarkdownFindOptions): Integer;
begin
  if Needle = '' then
    Exit(0);

  Result := FModel.ReplaceAll(Needle, Replacement, Options);
  RevealSelection;
end;

procedure TMarkdownEditor.RevealSelection;
begin
  FModel.ExpandAt(FModel.SelectionStart);
  RebuildRows;
  ScrollCaretIntoView;
  RestartCaretBlink;
  RedrawContent;
end;

procedure TMarkdownEditor.HandleModelChange(const Sender: TObject; const Range: TEditorReplaceRange);
begin
  FMatches.Refresh(FModel);

  FCaretVisible := True;
  RebuildRows;
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
  RebuildRows;
end;

procedure TMarkdownEditor.RenderContent(const Target: TCanvas; const TargetWidth, TargetHeight, ScrollY: Single;
  const DrawCaret: Boolean);
begin
  const Painter = TMarkdownFmxPainter.Create(Target);
  const PainterLifetime: IPainter = Painter;

  // Clip every draw to the control's own bounds so a partially scrolled top or
  // bottom row can never bleed above the editor (e.g. over the toolbar).
  Painter.SaveState;
  Painter.SetClip(TLayoutRectF.Create(0, 0, TargetWidth, TargetHeight));
  try

  Painter.FillRect(TLayoutRectF.Create(0, 0, TargetWidth, TargetHeight), FTheme.BackgroundColor);

  const LineHeight = LineHeightPx;
  const GutterWidth = GutterWidthPx(PainterLifetime);
  const TextLeft = GutterWidth + TextLeftPaddingDips;

  const CaretRow = RowIndexOfOffset(FModel.CaretPosition);
  const ActiveTop = CaretRow * LineHeight - ScrollY;
  Painter.FillRect(TLayoutRectF.Create(0, ActiveTop, TargetWidth, ActiveTop + LineHeight),
    FTheme.CodeBackgroundColor);

  var State := FHighlighter.InitialState;
  var RowIndex := 0;
  var BelowViewport := False;
  const LineCount = FModel.LineCount;
  for var LineIndex := 0 to LineCount - 1 do
  begin
    if BelowViewport then
      Break;

    const LineText = LineTextAt(LineIndex);
    const Tokenized = FHighlighter.TokenizeLine(LineText, State);

    while (RowIndex <= High(FRows)) and (FRows[RowIndex].LineIndex = LineIndex) do
    begin
      const Row = FRows[RowIndex];
      const Top = RowIndex * LineHeight - ScrollY;
      if Top > TargetHeight then
      begin
        BelowViewport := True;
        Break;
      end;

      const IsVisible = (Top + LineHeight) > 0;
      if IsVisible then
      begin
        DrawRowMatches(PainterLifetime, Row, TextLeft, Top);
        DrawRowSelection(PainterLifetime, Row, TextLeft, Top, TargetWidth);
        if FShowLineNumbers and Row.IsFirst then
          DrawGutterNumber(PainterLifetime, LineIndex, GutterWidth, Top);
        if Row.IsFirst and FModel.IsFoldHeader(LineIndex) then
          DrawFoldMarker(PainterLifetime, GutterWidth, Top, FModel.IsRegionCollapsed(LineIndex));
        DrawRowTokens(PainterLifetime, Row, LineText, Tokenized.Tokens, TextLeft, Top);
      end;

      Inc(RowIndex);
    end;

    State := Tokenized.NextState;
  end;

  if DrawCaret then
  begin
    const CaretPos = CaretPixelPos(ScrollY);
    Painter.FillRect(TLayoutRectF.Create(CaretPos.X, CaretPos.Y, CaretPos.X + CaretWidthPx,
      CaretPos.Y + LineHeight), FTheme.TextColor);
  end;

  finally
    Painter.RestoreState;
  end;
end;

procedure TMarkdownEditor.DrawRowSelection(const Painter: IPainter; const Row: TVisualRow;
  const TextLeft, Top, TargetWidth: Single);
begin
  if not FModel.HasSelection then
    Exit;

  const SelStart = FModel.SelectionStart;
  const SelEnd = SelStart + FModel.SelectionLength;

  const OutsideSelection = (SelEnd <= Row.StartOffset) or (SelStart > Row.EndOffset);
  if OutsideSelection then
    Exit;

  const RowStr = RowText(Row);
  const SegStart = Max(SelStart, Row.StartOffset) - Row.StartOffset;
  const SegEnd = Min(SelEnd, Row.EndOffset) - Row.StartOffset;

  const LeftX = TextLeft + FMeasurePainter.MeasureText(Copy(RowStr, 1, SegStart), CodeFont).Width;

  const SelectionSpansLineBreak = SelEnd > Row.EndOffset;
  var RightX: Single;
  if SelectionSpansLineBreak then
    RightX := TargetWidth
  else
    RightX := TextLeft + FMeasurePainter.MeasureText(Copy(RowStr, 1, SegEnd), CodeFont).Width;

  Painter.FillRect(TLayoutRectF.Create(LeftX, Top, Max(LeftX, RightX), Top + LineHeightPx), SelectionFillColor);
end;

procedure TMarkdownEditor.DrawRowMatches(const Painter: IPainter; const Row: TVisualRow;
  const TextLeft, Top: Single);
begin
  if not FMatches.IsActive then
    Exit;

  const RowStr = RowText(Row);

  for var Span in FMatches.SpansWithin(Row.StartOffset, Row.EndOffset) do
  begin
    const LeftX = TextLeft + FMeasurePainter.MeasureText(
      Copy(RowStr, 1, Span.StartOffset - Row.StartOffset), CodeFont).Width;
    const RightX = TextLeft + FMeasurePainter.MeasureText(
      Copy(RowStr, 1, Span.EndOffset - Row.StartOffset), CodeFont).Width;

    Painter.FillRect(TLayoutRectF.Create(LeftX, Top, Max(LeftX, RightX), Top + LineHeightPx), MatchFillColor);
  end;
end;

procedure TMarkdownEditor.DrawRowTokens(const Painter: IPainter; const Row: TVisualRow; const LineText: string;
  const Tokens: TArray<TMarkdownSourceToken>; const TextLeft, Top: Single);
begin
  const LineStart = LineStartOffset(Row.LineIndex);
  const RowStartCol = Row.StartOffset - LineStart;
  const RowEndCol = Row.EndOffset - LineStart;

  for var Token in Tokens do
  begin
    const TokenStartCol = Token.Start - 1;
    const TokenEndCol = TokenStartCol + Token.Length;
    const SegStartCol = Max(TokenStartCol, RowStartCol);
    const SegEndCol = Min(TokenEndCol, RowEndCol);

    const HasVisibleSegment = SegEndCol > SegStartCol;
    if not HasVisibleSegment then
      Continue;

    const Segment = Copy(LineText, SegStartCol + 1, SegEndCol - SegStartCol);
    const PrefixWithinRow = Copy(LineText, RowStartCol + 1, SegStartCol - RowStartCol);
    const OffsetX = Painter.MeasureText(PrefixWithinRow, CodeFont).Width;
    Painter.DrawTextRun(TLayoutPointF.Create(TextLeft + OffsetX, Top), Segment, CodeFont, TokenColor(Token.Kind));
  end;
end;

procedure TMarkdownEditor.RebuildRows;
begin
  const NotReady = (FModel = nil) or (FMeasurePainter = nil);
  if NotReady then
    Exit;

  FWrapWidth := WrapWidthPx;

  const Rows = TList<TVisualRow>.Create;
  try
    const LineCount = FModel.LineCount;
    for var LineIndex := 0 to LineCount - 1 do
    begin
      if FModel.IsLineHidden(LineIndex) then
        Continue;

      AppendWrappedRows(Rows, LineIndex);
    end;

    FRows := Rows.ToArray;
  finally
    Rows.Free;
  end;
end;

procedure TMarkdownEditor.AppendWrappedRows(const Rows: TList<TVisualRow>; const LineIndex: Integer);
begin
  const LineText = LineTextAt(LineIndex);
  const LineStart = LineStartOffset(LineIndex);
  const Len = Length(LineText);

  const LineIsEmpty = Len = 0;
  if LineIsEmpty then
  begin
    Rows.Add(MakeRow(LineIndex, LineStart, LineStart, True));
    Exit;
  end;

  var Consumed := 0;
  var IsFirst := True;
  while Consumed < Len do
  begin
    const Take = NextWrapLength(LineText, Consumed);
    Rows.Add(MakeRow(LineIndex, LineStart + Consumed, LineStart + Consumed + Take, IsFirst));

    Consumed := Consumed + Take;
    IsFirst := False;
  end;
end;

function TMarkdownEditor.MakeRow(const LineIndex, StartOffset, EndOffset: Integer;
  const IsFirst: Boolean): TVisualRow;
begin
  Result.LineIndex := LineIndex;
  Result.StartOffset := StartOffset;
  Result.EndOffset := EndOffset;
  Result.IsFirst := IsFirst;
end;

function TMarkdownEditor.NextWrapLength(const LineText: string; const StartCol: Integer): Integer;
begin
  const Remaining = Length(LineText) - StartCol;

  const RemainderWidth = FMeasurePainter.MeasureText(Copy(LineText, StartCol + 1, Remaining), CodeFont).Width;
  const FitsWholeRemainder = RemainderWidth <= FWrapWidth;
  if FitsWholeRemainder then
    Exit(Remaining);

  var LowerBound := 1;
  var UpperBound := Remaining;
  var BestFit := 1;
  while LowerBound <= UpperBound do
  begin
    const Candidate = (LowerBound + UpperBound) div 2;
    const CandidateWidth = FMeasurePainter.MeasureText(Copy(LineText, StartCol + 1, Candidate), CodeFont).Width;
    const CandidateFits = CandidateWidth <= FWrapWidth;
    if CandidateFits then
    begin
      BestFit := Candidate;
      LowerBound := Candidate + 1;
    end
    else
    begin
      UpperBound := Candidate - 1;
    end;
  end;

  const WordBreak = LastSpaceWithin(LineText, StartCol, BestFit);
  const CanBreakAtWord = WordBreak > 0;
  if CanBreakAtWord then
    Result := WordBreak
  else
    Result := BestFit;
end;

function TMarkdownEditor.LastSpaceWithin(const LineText: string; const StartCol, MaxLength: Integer): Integer;
begin
  for var Offset := MaxLength downto 1 do
  begin
    const IsSpace = LineText[StartCol + Offset] = ' ';
    if IsSpace then
      Exit(Offset);
  end;

  Result := 0;
end;

function TMarkdownEditor.WrapWidthPx: Single;
begin
  const Available = Width - TextLeftPx - CaretWidthPx;
  const MinimumWidth: Single = MinimumWrapWidthDips;
  Result := Max(Available, MinimumWidth);
end;

function TMarkdownEditor.RowCount: Integer;
begin
  Result := Length(FRows);
end;

function TMarkdownEditor.RowText(const Row: TVisualRow): string;
begin
  Result := Copy(FModel.Text, Row.StartOffset + 1, Row.EndOffset - Row.StartOffset);
end;

function TMarkdownEditor.RowIndexOfOffset(const Offset: Integer): Integer;
begin
  if Length(FRows) = 0 then
    Exit(0);

  for var Index := 0 to High(FRows) do
  begin
    const Row = FRows[Index];
    if Offset <= Row.EndOffset then
    begin
      const AtWrapBoundary = (Offset = Row.EndOffset) and (Index < High(FRows)) and
        (FRows[Index + 1].LineIndex = Row.LineIndex);
      if AtWrapBoundary then
        Exit(Index + 1);

      Exit(Index);
    end;
  end;

  Result := High(FRows);
end;

function TMarkdownEditor.OffsetAtRowX(const RowIndex: Integer; const TargetX: Single): Integer;
begin
  if Length(FRows) = 0 then
    Exit(0);

  const Row = FRows[EnsureRange(RowIndex, 0, High(FRows))];
  const RowStr = RowText(Row);

  var BestColumn := 0;
  var BestDistance := Abs(TargetX);
  for var PrefixLength := 1 to Length(RowStr) do
  begin
    const Width = FMeasurePainter.MeasureText(Copy(RowStr, 1, PrefixLength), CodeFont).Width;
    const Distance = Abs(TargetX - Width);
    if Distance < BestDistance then
    begin
      BestDistance := Distance;
      BestColumn := PrefixLength;
    end;
  end;

  Result := Row.StartOffset + BestColumn;
end;

procedure TMarkdownEditor.DrawGutterNumber(const Painter: IPainter; const LineIndex: Integer;
  const GutterWidth, Top: Single);
begin
  const Number = IntToStr(LineIndex + 1);
  const NumberWidth = Painter.MeasureText(Number, CodeFont).Width;
  const NumberLeft = GutterWidth - FoldGutterWidthPx - GutterPaddingDips - NumberWidth;
  Painter.DrawTextRun(TLayoutPointF.Create(NumberLeft, Top), Number, CodeFont, FTheme.BlockQuoteTextColor);
end;

procedure TMarkdownEditor.DrawFoldMarker(const Painter: IPainter; const GutterWidth, Top: Single;
  const Collapsed: Boolean);
begin
  const FoldWidth = FoldGutterWidthPx;
  if FoldWidth <= 0 then
    Exit;

  const ColumnLeft = GutterWidth - FoldWidth;
  const CenterX = ColumnLeft + FoldWidth / 2;
  const CenterY = Top + LineHeightPx / 2;
  const Half = Min(FoldWidth, LineHeightPx) * 0.3;
  const Color = FTheme.BlockQuoteTextColor;

  if Half <= 0 then
    Exit;

  if Collapsed then
    Painter.FillPolygon([TLayoutPointF.Create(CenterX - Half * 0.7, CenterY - Half),
      TLayoutPointF.Create(CenterX + Half * 0.9, CenterY),
      TLayoutPointF.Create(CenterX - Half * 0.7, CenterY + Half)], Color)
  else
    Painter.FillPolygon([TLayoutPointF.Create(CenterX - Half, CenterY - Half * 0.7),
      TLayoutPointF.Create(CenterX + Half, CenterY - Half * 0.7),
      TLayoutPointF.Create(CenterX, CenterY + Half * 0.9)], Color);
end;

function TMarkdownEditor.BeginSelectionDrag(const X, Y: Single; const Offset: Integer): Boolean;
begin
  // A press inside the selection may become a drag, so the selection is left
  // untouched until the mouse either moves far enough or is released in place.
  Result := FModel.OffsetInSelection(Offset);
  if not Result then
    Exit;

  FDragPending := True;
  FDraggingSelection := False;
  FDragOriginX := X;
  FDragOriginY := Y;
  FDragOffset := Offset;
end;

procedure TMarkdownEditor.UpdateSelectionDrag(const X, Y: Single);
begin
  if FDragPending then
  begin
    const MovedFar = (Abs(X - FDragOriginX) > DragThresholdPx) or (Abs(Y - FDragOriginY) > DragThresholdPx);
    if not MovedFar then
      Exit;

    FDragPending := False;
    FDraggingSelection := True;
  end;

  UpdateAutoScroll(X, Y);
end;

function TMarkdownEditor.FinishSelectionDrag(const X, Y: Single): Boolean;
begin
  Result := FDragPending or FDraggingSelection;
  if not Result then
    Exit;

  const WasDragging = FDraggingSelection;

  FDragPending := False;
  FDraggingSelection := False;

  if WasDragging then
    FModel.MoveSelectionTo(OffsetFromPoint(X, Y))
  else
    FModel.CaretPosition := FDragOffset;

  RefreshAfterEdit;
end;

procedure TMarkdownEditor.PopupContextMenu(const X, Y: Single);
begin
  // A menu assigned by the host wins; the built-in one is the fallback.
  if PopupMenu <> nil then
    Exit;

  if FContextMenu = nil then
    FContextMenu := TPopupMenu.Create(Self);

  FContextMenu.Clear;

  for var Item in TMarkdownEditorContextMenu.Build(FModel, ClipboardHasText) do
  begin
    var Entry := TMenuItem.Create(FContextMenu);
    Entry.Parent := FContextMenu;
    Entry.Text := Item.Caption;
    Entry.Enabled := Item.Enabled;
    Entry.Tag := Ord(Item.Command);
    Entry.OnClick := HandleContextItemClick;
  end;

  const Origin = LocalToAbsolute(TPointF.Create(X, Y));
  const OnScreen = Scene.LocalToScreen(Origin);
  FContextMenu.Popup(OnScreen.X, OnScreen.Y);
end;

procedure TMarkdownEditor.HandleContextItemClick(Sender: TObject);
begin
  const Command = TEditorContextCommand((Sender as TMenuItem).Tag);

  if TMarkdownEditorContextMenu.Execute(FModel, Command) then
  begin
    RefreshAfterEdit;
    Exit;
  end;

  case Command of
    TEditorContextCommand.Cut:
      CutToClipboard;
    TEditorContextCommand.Copy:
      CopyToClipboard;
    TEditorContextCommand.Paste:
      PasteFromClipboard;
  end;

  RefreshAfterEdit;
end;

function TMarkdownEditor.ClipboardHasText: Boolean;
begin
  var Clipboard: IFMXClipboardService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clipboard) then
    Exit(False);

  const Value = Clipboard.GetClipboard;
  Result := not Value.IsEmpty and (Value.ToString <> '');
end;

function TMarkdownEditor.HandleFoldClick(const X, Y: Single): Boolean;
begin
  Result := False;

  const FoldWidth = FoldGutterWidthPx;
  if FoldWidth <= 0 then
    Exit;

  const GutterWidth = GutterWidthPx(FMeasurePainterLifetime);
  if (X < GutterWidth - FoldWidth) or (X >= GutterWidth) then
    Exit;

  const RowIndex = Trunc((Y + FScrollOffset) / LineHeightPx);
  if (RowIndex < 0) or (RowIndex > High(FRows)) then
    Exit;

  const Row = FRows[RowIndex];
  if not (Row.IsFirst and FModel.IsFoldHeader(Row.LineIndex)) then
    Exit;

  FModel.ToggleFold(Row.LineIndex);
  RebuildRows;
  ScrollCaretIntoView;
  RedrawContent;
  Result := True;
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
  Result := FoldGutterWidthPx;

  if not FShowLineNumbers then
    Exit;

  const Digits = Length(IntToStr(Max(1, FModel.LineCount)));
  const Sample = StringOfChar('0', Digits);
  Result := Result + Painter.MeasureText(Sample, CodeFont).Width + 2 * GutterPaddingDips;
end;

function TMarkdownEditor.FoldGutterWidthPx: Single;
begin
  if FModel.HasFoldRegions then
    Result := FoldMarkerWidthDips
  else
    Result := 0;
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

function TMarkdownEditor.OffsetFromPoint(const X, Y: Single): Integer;
begin
  if Length(FRows) = 0 then
    Exit(0);

  const RowIndex = EnsureRange(Trunc((Y + FScrollOffset) / LineHeightPx), 0, High(FRows));
  const LocalX = X - TextLeftPx;
  Result := OffsetAtRowX(RowIndex, Max(0, LocalX));
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
  if Length(FRows) = 0 then
    Exit(TLayoutPointF.Create(TextLeftPx, -ScrollY));

  const RowIndex = RowIndexOfOffset(Caret);
  const Row = FRows[RowIndex];
  const Prefix = Copy(FModel.Text, Row.StartOffset + 1, Caret - Row.StartOffset);
  const OffsetX = FMeasurePainter.MeasureText(Prefix, CodeFont).Width;
  Result := TLayoutPointF.Create(TextLeftPx + OffsetX, RowIndex * LineHeightPx - ScrollY);
end;

function TMarkdownEditor.ContentHeightPx: Single;
begin
  Result := RowCount * LineHeightPx;
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

  SyncPreviewToEditor;
end;

procedure TMarkdownEditor.ScrollCaretIntoView;
begin
  const RowIndex = RowIndexOfOffset(FModel.CaretPosition);
  const Top = RowIndex * LineHeightPx;
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

procedure TMarkdownEditor.MoveVertical(const RowDelta: Integer; const Extend: Boolean);
begin
  if Length(FRows) = 0 then
    Exit;

  const Caret = FModel.CaretPosition;
  const RowIndex = RowIndexOfOffset(Caret);
  const Row = FRows[RowIndex];
  const Prefix = Copy(FModel.Text, Row.StartOffset + 1, Caret - Row.StartOffset);
  const TargetX = FMeasurePainter.MeasureText(Prefix, CodeFont).Width;
  const TargetRow = EnsureRange(RowIndex + RowDelta, 0, High(FRows));
  SetCaretTo(OffsetAtRowX(TargetRow, TargetX), Extend);
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

  RebuildRows;
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

  if Button = TMouseButton.mbRight then
  begin
    if CanFocus and (Scene <> nil) then
      SetFocus;

    const RightOffset = OffsetFromPoint(X, Y);
    if not FModel.OffsetInSelection(RightOffset) then
    begin
      FModel.CaretPosition := RightOffset;
      RestartCaretBlink;
      RedrawContent;
    end;

    PopupContextMenu(X, Y);
    Exit;
  end;

  if Button <> TMouseButton.mbLeft then
    Exit;

  if CanFocus and (Scene <> nil) then
    SetFocus;
  FModel.BreakUndoCoalescing;

  if HandleFoldClick(X, Y) then
    Exit;

  const Offset = OffsetFromPoint(X, Y);

  if BeginSelectionDrag(X, Y, Offset) then
    Exit;

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

  const Ticks = TThread.GetTickCount;
  FClickCount := ClickCountAt(X, Y, Shift, Ticks);
  RecordClick(X, Y, Ticks);

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

  if FDragPending or FDraggingSelection then
  begin
    UpdateSelectionDrag(X, Y);
    Exit;
  end;

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

  if FinishSelectionDrag(X, Y) then
    Exit;

  FSelecting := False;
  if FAutoScrollTimer <> nil then
    FAutoScrollTimer.Enabled := False;
end;

function TMarkdownEditor.ClickCountAt(const X, Y: Single; const Shift: TShiftState; const Ticks: Cardinal): Integer;
begin
  const WithinTime = (Ticks - FLastClickTicks) <= DoubleClickWindowMilliseconds;
  const WithinDistance = (Abs(X - FLastClickX) <= DoubleClickSlopDips) and
    (Abs(Y - FLastClickY) <= DoubleClickSlopDips);

  const IsRepeat = ((ssDouble in Shift) or (WithinTime and WithinDistance)) and
    (FClickCount >= 1) and (FClickCount < 3);
  if IsRepeat then
    Result := FClickCount + 1
  else
    Result := 1;
end;

procedure TMarkdownEditor.RecordClick(const X, Y: Single; const Ticks: Cardinal);
begin
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

  const Notches = WheelDelta / MouseWheelDeltaPerNotch;
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

  const IsPrintable = (KeyChar >= ' ') and (KeyChar <> DeleteChar);
  if IsPrintable then
  begin
    FModel.Insert(KeyChar);
    KeyChar := #0;
  end;
end;

function TMarkdownEditor.HandleKey(const Key: Word; const Shift: TShiftState): Boolean;
begin
  Result := ApplyKeyStroke(TMarkdownEditorKeymap.Resolve(Key, Shift));

  if Result then
    RefreshAfterEdit;
end;

function TMarkdownEditor.ApplyKeyStroke(const Stroke: TEditorKeyStroke): Boolean;
begin
  if TMarkdownEditorKeyDispatch.Apply(FModel, Stroke, FIndentWidth) then
    Exit(True);

  // What is left needs the wrapped layout on screen or the host clipboard.
  const Extend = Stroke.Extend;
  const Caret = FModel.CaretPosition;
  Result := True;

  case Stroke.Action of
    TEditorKeyAction.MoveUp:
      begin
        FModel.BreakUndoCoalescing;
        MoveVertical(-1, Extend);
      end;
    TEditorKeyAction.MoveDown:
      begin
        FModel.BreakUndoCoalescing;
        MoveVertical(1, Extend);
      end;
    TEditorKeyAction.MovePageUp:
      begin
        FModel.BreakUndoCoalescing;
        MoveVertical(-VisibleLineCount, Extend);
      end;
    TEditorKeyAction.MovePageDown:
      begin
        FModel.BreakUndoCoalescing;
        MoveVertical(VisibleLineCount, Extend);
      end;
    TEditorKeyAction.MoveLineStart:
      begin
        FModel.BreakUndoCoalescing;
        SetCaretTo(FRows[RowIndexOfOffset(Caret)].StartOffset, Extend);
      end;
    TEditorKeyAction.MoveLineEnd:
      begin
        FModel.BreakUndoCoalescing;
        SetCaretTo(FRows[RowIndexOfOffset(Caret)].EndOffset, Extend);
      end;
    TEditorKeyAction.Copy:
      CopyToClipboard;
    TEditorKeyAction.Cut:
      CutToClipboard;
    TEditorKeyAction.Paste:
      PasteFromClipboard;
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
  RebuildRows;
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
  RebuildRows;
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
  RebuildRows;
  RedrawContent;
end;

procedure TMarkdownEditor.SetShowLineNumbers(const Value: Boolean);
begin
  if Value = FShowLineNumbers then
    Exit;

  FShowLineNumbers := Value;
  RebuildRows;
  RedrawContent;
end;

end.
