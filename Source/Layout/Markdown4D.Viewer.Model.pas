unit Markdown4D.Viewer.Model;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.SourceLineMap,
  Markdown4D.Layout.TextAnchor,
  Markdown4D.Layout.TextSearch,
  Markdown4D.Theme;

type
  TMarkdownImageSlotState = (Unknown, Requested, Loaded, Failed);

  TMarkdownFoundRange = record
    ItemIndex: Integer;
    StartCharacter: Integer;
    CharacterCount: Integer;
    class function Create(const ItemIndex, StartCharacter, CharacterCount: Integer): TMarkdownFoundRange; static;
  end;

  TMarkdownCodeBlockRegion = record
    Rect: TLayoutRectF;
    Text: string;
    class function Create(const Rect: TLayoutRectF; const Text: string): TMarkdownCodeBlockRegion; static;
  end;

  // Raised when a block override or a document processor fails. The document
  // shows without what that extension would have drawn or added.
  TMarkdownExtensionErrorEvent = procedure(const Sender: TObject; const Extension: string;
    const Error: Exception) of object;

  TMarkdownViewerModel = class(TNoRefCountObject, IMarkdownImageSizeProvider, IMarkdownExtensionErrorSink,
    IMarkdownDisclosureState)
  private
    type
      TTextPosition = TMarkdownTextPosition;
      TImageSlot = record
        State: TMarkdownImageSlotState;
        Size: TLayoutSizeF;
      end;
      TTextRange = record
        StartPosition: TTextPosition;
        EndPosition: TTextPosition;
      end;
      TSelectionAnchors = record
        Anchor: TMarkdownTextAnchor;
        Extent: TMarkdownTextAnchor;
        UnitStart: TMarkdownTextAnchor;
        UnitEnd: TMarkdownTextAnchor;
      end;
      // What a press and a drag select by: characters after a single click,
      // whole words after a double click, whole lines after a triple click.
      TSelectionUnit = (Character, Word, Line);
      TCharacterClass = (WordCharacter, Space, Other);
      // One stretch of a selection: the characters CharFrom to CharTo of the
      // run at ItemIndex, set apart from the stretch before it as JoinRun is.
      TSelectedPiece = record
        ItemIndex: Integer;
        Run: IDisplayTextRun;
        JoinRun: IDisplayTextRun;
        CharFrom: Integer;
        CharTo: Integer;
      end;
    const
      DefaultFlushIntervalMilliseconds = 100;
      BottomEpsilon = 0.5;
      LineTopEpsilon = 0.5;
      CopiedIndentWidth = 2;
      CopiedSpace = ' ';
      CopiedTab = #9;
      AnchorMark = '#';
      MathAlphanumericFirst = $1D400;
      MathAlphanumericLast = $1D7FF;
      FormulaCellEnd = '&';
      FormulaRowEnd = '\\';
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FText: string;
      FPendingMarkdown: string;
      FDirty: Boolean;
      FDirtySince: Int64;
      FFlushIntervalMilliseconds: Cardinal;
      FViewportWidth: Single;
      FViewportHeight: Single;
      FScrollOffset: Single;
      FDisplayList: IMarkdownDisplayList;
      FDocument: IMarkdownDocument;
      FLayoutCount: Integer;
      FLastLayoutMilliseconds: Int64;
      FShouldAutoFollow: Boolean;
      FSelectionActive: Boolean;
      FAnchor: TTextPosition;
      FExtent: TTextPosition;
      FSelectionUnit: TSelectionUnit;
      FUnitRange: TTextRange;
      FHighlightNeedle: string;
      FHighlightOptions: TMarkdownFindOptions;
      FHighlightRects: TArray<TLayoutRectF>;
      FImageSlots: TDictionary<string, TImageSlot>;
      FImageSlotOrder: TList<string>;
      FOnExtensionError: TMarkdownExtensionErrorEvent;
      FZoom: Integer;
      FZoomedTheme: TMarkdownTheme;
      // The <details> sections the reader opened or closed, by the source
      // offset of their opening block; every other section shows as its tag asks.
      FToggledDisclosures: TList<Integer>;
      FScrollerOffsets: TDictionary<Integer, Single>;
      FScrollers: TArray<Integer>;
      FDraggedScroller: Integer;
      FThumbGrab: Single;
      FSourceLines: TMarkdownSourceLineMap;
      // The layout the source line map was built for; it is built again on
      // first use after the next layout.
      FSourceLinesLayoutCount: Integer;
    procedure Relayout;
    procedure RefreshSourceLines;
    function ZoomFactor: Single;
    function LayoutTheme: TMarkdownTheme;
    procedure RefreshZoomedTheme;
    function TryCaptureTopLine(out TopLine: TMarkdownTextAnchor; out Inset: Single): Boolean;
    procedure ScrollToTopLine(const TopLine: TMarkdownTextAnchor; const Inset: Single);
    function TryCaptureSelection(out Selection: TSelectionAnchors): Boolean;
    function TryRestoreSelection(const Selection: TSelectionAnchors): Boolean;
    procedure RegisterImageSlots;
    function TryFindTextRunBounds(out FirstIndex, LastIndex: Integer): Boolean;
    function TryGetEverythingRange(out Range: TTextRange): Boolean;
    function IsEverythingSelected: Boolean;
    function TryResolvePosition(const Point: TLayoutPointF; out Position: TTextPosition): Boolean;
    function NearestCharacterBoundary(const Run: IDisplayTextRun; const X: Single): Integer;
    function TrySelectableRun(const Index: Integer; out Run: IDisplayTextRun): Boolean;
    function TryResolveCharacter(const Point: TLayoutPointF; out Position: TTextPosition): Boolean;
    function CharacterUnderX(const Run: IDisplayTextRun; const X: Single): Integer;
    function SelectUnitAt(const Point: TLayoutPointF; const SelectionUnit: TSelectionUnit): Boolean;
    procedure ExtendUnitSelection(const Position: TTextPosition);
    function UnitRangeAt(const Position: TTextPosition): TTextRange;
    function WordRangeAt(const Position: TTextPosition): TTextRange;
    function WordStartFrom(const Position: TTextPosition): TTextPosition;
    function WordEndFrom(const Position: TTextPosition): TTextPosition;
    function LineRangeAt(const Position: TTextPosition): TTextRange;
    function LineOriginIndex(const ItemIndex: Integer): Integer;
    function LineStartIndexFrom(const ItemIndex: Integer): Integer;
    function LineEndIndexFrom(const ItemIndex: Integer): Integer;
    function TryAdjacentRun(const ItemIndex, Direction: Integer; out AdjacentIndex: Integer;
      out Run: IDisplayTextRun): Boolean;
    class function ContinuesWord(const Run, Before: IDisplayTextRun): Boolean; static;
    class function ContinuesLine(const Run, Before: IDisplayTextRun): Boolean; static;
    class function CharacterClassOf(const Character: Char): TCharacterClass; static;
    class function IsAtomicRun(const Run: IDisplayTextRun): Boolean; static;
    class function RunCharacterClass(const Run: IDisplayTextRun; const Index: Integer): TCharacterClass; static;
    class function IsGlyphOf(const Run: IDisplayTextRun; const Formula: IMarkdownNode): Boolean; static;
    procedure FindFormulaGlyphs(const Index: Integer; out FirstGlyph, LastGlyph: Integer; out Left, Right: Single);
    procedure SnapToFormulaEdge(const Point: TLayoutPointF; var Position: TTextPosition);
    function TryGetWholeFormula(const Glyph: Integer; const Range: TTextRange; out SourceIndex: Integer): Boolean;
    function SelectedPieces(const Range: TTextRange): TArray<TSelectedPiece>;
    class function SeparatorBetween(const Previous, Piece: TSelectedPiece; const StartsBlock: Boolean;
      const PreviousTop: Single): string; static;
    class function TableBreakBetween(const Before, After: IDisplayTextRun): string; static;
    function TryFindScrollerAt(const Point: TLayoutPointF; out Index: Integer): Boolean;
    function TryFindScrollerOf(const ItemIndex: Integer; out Index: Integer): Boolean;
    function IsOverScrollerTrack(const Point: TLayoutPointF): Boolean;
    procedure SetScrollerOffset(const Index: Integer; const Offset: Single);
    procedure RestoreScrollerOffsets;
    procedure RevealInScroller(const ItemIndex: Integer);
    function ClipToScroller(const ItemIndex: Integer; const Rect: TLayoutRectF): TLayoutRectF;
    function NextMatchAfterSelection(const Matches: TArray<TMarkdownFoundRange>): TMarkdownFoundRange;
    function PreviousMatchBeforeSelection(const Matches: TArray<TMarkdownFoundRange>): TMarkdownFoundRange;
    function TryGetMatchAhead(const Matches: TArray<TMarkdownFoundRange>; out Match: TMarkdownFoundRange): Boolean;
    function TryGetMatchBehind(const Matches: TArray<TMarkdownFoundRange>; out Match: TMarkdownFoundRange): Boolean;
    procedure OpenSectionsBeforeNextMatch(const Needle: string; const Options: TMarkdownFindOptions);
    procedure OpenSectionsBeforePreviousMatch(const Needle: string; const Options: TMarkdownFindOptions);
    function TryOpenSectionBeforeNextMatch(const Needle: string; const Options: TMarkdownFindOptions): Boolean;
    function TryOpenSectionBeforePreviousMatch(const Needle: string; const Options: TMarkdownFindOptions): Boolean;
    function SectionsHolding(const Needle: string; const Options: TMarkdownFindOptions): TArray<Integer>;
    function TryGetDisclosureItem(const Key: Integer; out ItemIndex: Integer): Boolean;
    procedure OpenSectionAt(const ItemIndex: Integer);
    function CaretItemIndex(const WithoutCaret: Integer): Integer;
    function TryFindAnchorHeading(const Anchor: string; out Heading: IMarkdownHeading): Boolean;
    procedure FlipDisclosure(const Key: Integer);
    function HasCaret: Boolean;
    procedure SelectMatch(const Match: TMarkdownFoundRange);
    function RangeOfMatch(const Match: TMarkdownFoundRange): TTextRange;
    function RangeInRun(const Run: IDisplayTextRun; const Match: TMarkdownFoundRange): TTextRange;
    function MatchRun(const Match: TMarkdownFoundRange): IDisplayTextRun;
    function DistinctMatches(const Matches: TArray<TMarkdownFoundRange>): TArray<TMarkdownFoundRange>;
    procedure RefreshHighlights;
    function BoundsInRun(const Run: IDisplayTextRun; const Range: TTextRange): TLayoutRectF;
    function MatchBounds(const Match: TMarkdownFoundRange): TLayoutRectF;
    function IsWithinViewport(const Bounds: TLayoutRectF): Boolean;
    function NormalizeSelection: TTextRange;
    class function ComparePositions(const Left, Right: TTextPosition): Integer;
    function SelectedCharacterRange(const Run: IDisplayTextRun; const ItemIndex: Integer;
      const StartPosition, EndPosition: TTextPosition; out CharFrom, CharTo: Integer): Boolean;
    function BlockIndexOfItem(const ItemIndex: Integer): Integer;
    class function SeparatorBefore(const Run: IDisplayTextRun; const StartsBlock: Boolean;
      const PreviousTop: Single): string; static;
    class function FallbackSeparator(const Run: IDisplayTextRun; const StartsBlock: Boolean;
      const PreviousTop: Single): string; static;
    function TryFindSelectionEdges(out FirstRun, LastRun: IDisplayTextRun;
                                   out FirstCharacter, LastCharacter: Integer): Boolean;
    function PrefixWidth(const Run: IDisplayTextRun; const CharacterCount: Integer): Single;
    class function CodeTextOf(const Code: IMarkdownCodeBlock): string; static;
    function GetText: string;
    procedure SetText(const Value: string);
    function GetPendingText: string;
    function GetFullText: string;
    function GetDisplayList: IMarkdownDisplayList;
    function GetLayoutCount: Integer;
    function GetIsDirty: Boolean;
    function GetShouldAutoFollow: Boolean;
    function GetFlushIntervalMilliseconds: Cardinal;
    procedure SetFlushIntervalMilliseconds(const Value: Cardinal);
    function GetScrollOffset: Single;
    procedure SetZoom(const Value: Integer);
    procedure SetScrollOffset(const Value: Single);

  public
    constructor Create(const Theme: TMarkdownTheme; const Measurer: ITextMeasurer);
    destructor Destroy; override;
    procedure SetViewport(const Width, Height: Single);
    procedure ApplyTheme(const Theme: TMarkdownTheme);
    procedure RefreshLayout;
    function IsScrolledToBottom: Boolean;
    procedure AppendMarkdown(const Markdown: string; const NowMilliseconds: Int64);
    function TryFlush(const NowMilliseconds: Int64): Boolean;
    procedure SetSelectionAnchor(const Point: TLayoutPointF);
    procedure SetSelectionExtent(const Point: TLayoutPointF);
    procedure ClearSelection;
    function SelectAll: Boolean;
    // Select the word or the line under the point, and make a drag that
    // follows extend the selection by whole words or lines. False when there
    // is no text to select.
    function SelectWordAt(const Point: TLayoutPointF): Boolean;
    function SelectLineAt(const Point: TLayoutPointF): Boolean;
    function HasSelectableText: Boolean;
    function HasSelection: Boolean;
    function SelectionRects: TArray<TLayoutRectF>;
    function SelectedText: string;
    // Answers the stretch of markdown source the selection was rendered from,
    // so a formatting command can change exactly those characters. False when
    // there is no selection, or when the runs it covers carry no source of
    // their own, as happens inside a diagram an extension drew.
    function TryGetSelectionSourceSegment(out Segment: TMarkdownSegment): Boolean;
    // The markdown behind the selection, for Copy as Markdown; empty without a
    // selection. A selection of everything gives the whole source, including
    // lines that render nothing.
    function SelectedMarkdown: string;
    // The scroll offset that brings the heading a link like #getting-started
    // points at to the top of the view. The anchor may be percent-encoded.
    function TryGetAnchorOffset(const Anchor: string; out Offset: Single): Boolean;
    // Opens the closed <details> sections around the heading an anchor points
    // at, as a browser does when it follows a link there, and lays out again.
    // True when a section opened.
    function RevealAnchor(const Anchor: string): Boolean;
    // Where a line of Text shows, as the scroll offset that brings it to the
    // top of the view, and which line shows at an offset. Lines count from 0.
    // A line that renders nothing of its own, such as a blank line, falls
    // between its neighbours.
    function SourceLineToScrollOffset(const SourceLine: Integer): Single;
    function ScrollOffsetToSourceLine(const Offset: Single): Integer;
    function PendingImageSources: TArray<string>;
    procedure NotifyImageArrived(const Source: string; const Size: TLayoutSizeF);
    procedure NotifyImageFailed(const Source: string);
    function ImageSlotState(const Source: string): TMarkdownImageSlotState;
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
    procedure ExtensionFailed(const Extension: string; const Error: Exception);
    function FindText(const Needle: string): TArray<TMarkdownFoundRange>; overload;
    function FindText(const Needle: string; const Options: TMarkdownFindOptions): TArray<TMarkdownFoundRange>; overload;
    // How many stops a walk with TrySelectNextMatch makes: a formula counts
    // once, however often the needle occurs in its source.
    function MatchCount(const Needle: string): Integer; overload;
    function MatchCount(const Needle: string; const Options: TMarkdownFindOptions): Integer; overload;
    // Which of those stops the selection covers, counted from 0; -1 when the
    // selection is not a match.
    function MatchIndex(const Needle: string; const Options: TMarkdownFindOptions): Integer;
    // Select the first match after the start of the current selection, or
    // from the caret when nothing is selected, or else the first match in the
    // document, so a repeated search walks through every match. A match in a
    // formula selects the whole formula. When the next match lies in a closed
    // <details> section, the section opens first, as find in a browser does;
    // LayoutCount then changes. False when the needle does not occur; the
    // selection is then left as is.
    function TrySelectNextMatch(const Needle: string; out Match: TMarkdownFoundRange): Boolean; overload;
    function TrySelectNextMatch(const Needle: string; const Options: TMarkdownFindOptions;
                                out Match: TMarkdownFoundRange): Boolean; overload;
    // The same walk backwards: the last match before the start of the
    // selection or the caret, or the last match in the document.
    function TrySelectPreviousMatch(const Needle: string; out Match: TMarkdownFoundRange): Boolean; overload;
    function TrySelectPreviousMatch(const Needle: string; const Options: TMarkdownFindOptions;
                                    out Match: TMarkdownFoundRange): Boolean; overload;
    // Mark every match of the needle, independently of the selection. The
    // marks follow the document through every relayout until they are
    // cleared or the needle is empty. A formula is marked once, however often
    // the needle occurs in its source.
    procedure HighlightMatches(const Needle: string); overload;
    procedure HighlightMatches(const Needle: string; const Options: TMarkdownFindOptions); overload;
    procedure ClearHighlights;
    function HighlightCount: Integer;
    function HighlightRectsWithin(const Viewport: TLayoutRectF): TArray<TLayoutRectF>;
    // The scroll offset that brings the match to the middle of the view, with
    // the lines around it, as a browser does. False when it is in view
    // already, so stepping through the matches on one screen does not make the
    // content jump.
    function TryGetScrollTarget(const Match: TMarkdownFoundRange; out Offset: Single): Boolean;
    function CodeBlockRegions: TArray<TMarkdownCodeBlockRegion>;
    // A display formula wider than the column scrolls sideways in its band.
    // ScrollSideways moves the one under Point by Delta (positive to the
    // right) and is False when there is none there. A press on its track
    // starts dragging the thumb, which DragScrollerThumb follows until
    // EndScrollerDrag.
    function ScrollSideways(const Point: TLayoutPointF; const Delta: Single): Boolean;
    function TryBeginScrollerDrag(const Point: TLayoutPointF): Boolean;
    procedure DragScrollerThumb(const Point: TLayoutPointF);
    procedure EndScrollerDrag;
    function IsDraggingScroller: Boolean;
    function TryGetCodeBlockAt(const Point: TLayoutPointF; out Region: TMarkdownCodeBlockRegion): Boolean;
    // The <details> section whose summary line is under the point. Key
    // identifies the section to ToggleDisclosure.
    function TryGetDisclosureAt(const Point: TLayoutPointF; out Key: Integer): Boolean;
    // Opens a closed section or closes an open one, and lays out again. Setting
    // Text shows every section as its tag asks once more.
    procedure ToggleDisclosure(const Key: Integer);
    function IsDisclosureOpen(const Key: Integer; const OpenByDefault: Boolean): Boolean;
    property Text: string read GetText write SetText;
    property PendingText: string read GetPendingText;
    property FullText: string read GetFullText;
    property DisplayList: IMarkdownDisplayList read GetDisplayList;
    property LayoutCount: Integer read GetLayoutCount;
    // How long the last layout took, so a host can pace work that lays out again.
    property LastLayoutMilliseconds: Int64 read FLastLayoutMilliseconds;
    property IsDirty: Boolean read GetIsDirty;
    property ShouldAutoFollow: Boolean read GetShouldAutoFollow;
    property FlushIntervalMilliseconds: Cardinal read GetFlushIntervalMilliseconds write SetFlushIntervalMilliseconds;
    property ScrollOffset: Single read GetScrollOffset write SetScrollOffset;
    // In percent. Every font, length and image of the theme grows with it;
    // the line at the top of the view stays there.
    property Zoom: Integer read FZoom write SetZoom;
    property OnExtensionError: TMarkdownExtensionErrorEvent read FOnExtensionError write FOnExtensionError;
  end;

implementation

uses
  System.Math,
  System.Diagnostics,
  System.Character,
  System.NetEncoding,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Layout.Disclosure,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.HitTest,
  Markdown4D.Layout.SourceMapping,
  Markdown4D.Layout.SelectedMarkdown,
  Markdown4D.Math.Layout,
  Markdown4D.Toc,
  Markdown4D.Layout.Zoom;

class function TMarkdownFoundRange.Create(const ItemIndex, StartCharacter,
  CharacterCount: Integer): TMarkdownFoundRange;
begin
  Result.ItemIndex := ItemIndex;
  Result.StartCharacter := StartCharacter;
  Result.CharacterCount := CharacterCount;
end;

class function TMarkdownCodeBlockRegion.Create(const Rect: TLayoutRectF;
  const Text: string): TMarkdownCodeBlockRegion;
begin
  Result.Rect := Rect;
  Result.Text := Text;
end;

constructor TMarkdownViewerModel.Create(const Theme: TMarkdownTheme; const Measurer: ITextMeasurer);
begin
  inherited Create;

  FTheme := Theme;
  FMeasurer := Measurer;
  FFlushIntervalMilliseconds := DefaultFlushIntervalMilliseconds;
  FZoom := TMarkdownZoom.DefaultPercent;
  FImageSlots := TDictionary<string, TImageSlot>.Create;
  FImageSlotOrder := TList<string>.Create;
  FToggledDisclosures := TList<Integer>.Create;
  FScrollerOffsets := TDictionary<Integer, Single>.Create;
  FDraggedScroller := -1;
  FSourceLines := TMarkdownSourceLineMap.Create;
  FSourceLinesLayoutCount := -1;
end;

destructor TMarkdownViewerModel.Destroy;
begin
  FSourceLines.Free;
  FScrollerOffsets.Free;
  FToggledDisclosures.Free;
  FZoomedTheme.Free;
  FImageSlotOrder.Free;
  FImageSlots.Free;

  inherited Destroy;
end;

procedure TMarkdownViewerModel.SetViewport(const Width, Height: Single);
begin
  const WidthChanged = not SameValue(FViewportWidth, Width);
  FViewportWidth := Width;
  FViewportHeight := Height;

  const HasPendingContent = (FText <> '') or (FPendingMarkdown <> '');
  const NeedsRelayout = WidthChanged and (Width > 0) and ((FDisplayList <> nil) or HasPendingContent);
  if NeedsRelayout then
    Relayout;
end;

procedure TMarkdownViewerModel.ApplyTheme(const Theme: TMarkdownTheme);
begin
  FTheme := Theme;
  RefreshLayout;
end;

procedure TMarkdownViewerModel.RefreshLayout;
begin
  if FDisplayList <> nil then
    Relayout;
end;

function TMarkdownViewerModel.IsScrolledToBottom: Boolean;
begin
  if FDisplayList = nil then
  begin
    Result := True;
    Exit;
  end;

  Result := (FScrollOffset + FViewportHeight) >= (FDisplayList.Height - BottomEpsilon);
end;

procedure TMarkdownViewerModel.AppendMarkdown(const Markdown: string; const NowMilliseconds: Int64);
begin
  if Markdown = '' then
    Exit;

  if not FDirty then
    FDirtySince := NowMilliseconds;

  FPendingMarkdown := FPendingMarkdown + Markdown;
  FDirty := True;
end;

function TMarkdownViewerModel.TryFlush(const NowMilliseconds: Int64): Boolean;
begin
  if not FDirty then
  begin
    Result := False;
    Exit;
  end;

  const IsTooEarly = ((NowMilliseconds - FDirtySince) < FFlushIntervalMilliseconds);
  if IsTooEarly then
  begin
    Result := False;
    Exit;
  end;

  FShouldAutoFollow := IsScrolledToBottom;
  FText := FText + FPendingMarkdown;
  FPendingMarkdown := '';
  FDirty := False;
  Relayout;

  Result := True;
end;

procedure TMarkdownViewerModel.SetSelectionAnchor(const Point: TLayoutPointF);
begin
  FSelectionUnit := TSelectionUnit.Character;
  FSelectionActive := TryResolvePosition(Point, FAnchor);
  FExtent := FAnchor;
end;

procedure TMarkdownViewerModel.SetSelectionExtent(const Point: TLayoutPointF);
begin
  if not FSelectionActive then
    Exit;

  if FSelectionUnit = TSelectionUnit.Character then
  begin
    var Position: TTextPosition;
    if TryResolvePosition(Point, Position) then
      FExtent := Position;
    Exit;
  end;

  var Character: TTextPosition;
  if TryResolveCharacter(Point, Character) then
    ExtendUnitSelection(Character);
end;

function TMarkdownViewerModel.SelectWordAt(const Point: TLayoutPointF): Boolean;
begin
  Result := SelectUnitAt(Point, TSelectionUnit.Word);
end;

function TMarkdownViewerModel.SelectLineAt(const Point: TLayoutPointF): Boolean;
begin
  Result := SelectUnitAt(Point, TSelectionUnit.Line);
end;

function TMarkdownViewerModel.SelectUnitAt(const Point: TLayoutPointF; const SelectionUnit: TSelectionUnit): Boolean;
begin
  var Character: TTextPosition;
  Result := TryResolveCharacter(Point, Character);
  FSelectionActive := Result;
  if not Result then
    Exit;

  FSelectionUnit := SelectionUnit;
  FUnitRange := UnitRangeAt(Character);
  FAnchor := FUnitRange.StartPosition;
  FExtent := FUnitRange.EndPosition;
end;

// The word or line picked first stays selected; the selection grows from it
// to the whole unit under the pointer, on whichever side the pointer is.
procedure TMarkdownViewerModel.ExtendUnitSelection(const Position: TTextPosition);
begin
  const Range = UnitRangeAt(Position);

  const IsBefore = (ComparePositions(Range.StartPosition, FUnitRange.StartPosition) < 0);
  if IsBefore then
  begin
    FAnchor := FUnitRange.EndPosition;
    FExtent := Range.StartPosition;
  end
  else
  begin
    FAnchor := FUnitRange.StartPosition;
    FExtent := Range.EndPosition;
  end;
end;

function TMarkdownViewerModel.UnitRangeAt(const Position: TTextPosition): TTextRange;
begin
  case FSelectionUnit of
    TSelectionUnit.Word : Result := WordRangeAt(Position);
    TSelectionUnit.Line : Result := LineRangeAt(Position);
  else
    raise EMarkdownError.CreateFmt('Unhandled selection unit: %d', [Ord(FSelectionUnit)]);
  end;
end;

// A word is a run of letters, digits and underscores, and carries on into the
// next run when the formatting changes mid-word. Spaces select as spaces, any
// other character on its own.
function TMarkdownViewerModel.WordRangeAt(const Position: TTextPosition): TTextRange;
begin
  var Run: IDisplayTextRun;
  TrySelectableRun(Position.ItemIndex, Run);

  Result.StartPosition := Position;
  Result.EndPosition := Position;

  const IsSource = (Run.Role = TDisplayTextRunRole.Source);
  if IsSource then
  begin
    Result.StartPosition.CharacterIndex := 0;
    Result.EndPosition.CharacterIndex := Length(Run.Text);
    Exit;
  end;

  const CharacterClass = RunCharacterClass(Run, Position.CharacterIndex);
  if CharacterClass = TCharacterClass.Other then
  begin
    Result.EndPosition.CharacterIndex := Position.CharacterIndex + 1;
    const IsAtomic = IsAtomicRun(Run);
    if IsAtomic then
    begin
      Result.StartPosition.CharacterIndex := 0;
      Result.EndPosition.CharacterIndex := Length(Run.Text);
    end;
    Exit;
  end;

  Result.StartPosition := WordStartFrom(Position);
  Result.EndPosition := WordEndFrom(Position);
end;

function TMarkdownViewerModel.WordStartFrom(const Position: TTextPosition): TTextPosition;
begin
  var Run: IDisplayTextRun;
  TrySelectableRun(Position.ItemIndex, Run);
  const CharacterClass = RunCharacterClass(Run, Position.CharacterIndex);

  Result := Position;
  while True do
  begin
    while (Result.CharacterIndex > 0) and (RunCharacterClass(Run, Result.CharacterIndex - 1) = CharacterClass) do
      Result.CharacterIndex := Result.CharacterIndex - 1;

    const ReachedRunStart = (Result.CharacterIndex = 0);
    var PreviousIndex: Integer;
    var Previous: IDisplayTextRun;
    const CanContinue = (ReachedRunStart and (CharacterClass = TCharacterClass.WordCharacter) and
                         TryAdjacentRun(Result.ItemIndex, -1, PreviousIndex, Previous) and ContinuesWord(Run, Previous));
    if not CanContinue then
      Exit;

    Run := Previous;
    Result.ItemIndex := PreviousIndex;
    Result.CharacterIndex := Length(Run.Text);
  end;
end;

function TMarkdownViewerModel.WordEndFrom(const Position: TTextPosition): TTextPosition;
begin
  var Run: IDisplayTextRun;
  TrySelectableRun(Position.ItemIndex, Run);
  const CharacterClass = RunCharacterClass(Run, Position.CharacterIndex);

  Result := Position;
  while True do
  begin
    while (Result.CharacterIndex < Length(Run.Text)) and
          (RunCharacterClass(Run, Result.CharacterIndex) = CharacterClass) do
      Result.CharacterIndex := Result.CharacterIndex + 1;

    const ReachedRunEnd = (Result.CharacterIndex = Length(Run.Text));
    var NextIndex: Integer;
    var Next: IDisplayTextRun;
    const CanContinue = (ReachedRunEnd and (CharacterClass = TCharacterClass.WordCharacter) and
                         TryAdjacentRun(Result.ItemIndex, 1, NextIndex, Next) and ContinuesWord(Next, Run));
    if not CanContinue then
      Exit;

    Run := Next;
    Result.ItemIndex := NextIndex;
    Result.CharacterIndex := 0;
  end;
end;

// A line is what a browser selects on a triple click: a paragraph with all
// its lines, a list item without its marker, a table row, a code line.
function TMarkdownViewerModel.LineRangeAt(const Position: TTextPosition): TTextRange;
begin
  const OriginIndex = LineOriginIndex(Position.ItemIndex);
  const EndIndex = LineEndIndexFrom(OriginIndex);

  var EndRun: IDisplayTextRun;
  TrySelectableRun(EndIndex, EndRun);

  Result.StartPosition.ItemIndex := LineStartIndexFrom(OriginIndex);
  Result.StartPosition.CharacterIndex := 0;
  Result.EndPosition.ItemIndex := EndIndex;
  Result.EndPosition.CharacterIndex := Length(EndRun.Text);
end;

// A click on a list marker selects the item's line, which starts after it.
function TMarkdownViewerModel.LineOriginIndex(const ItemIndex: Integer): Integer;
begin
  Result := ItemIndex;

  var Run: IDisplayTextRun;
  TrySelectableRun(ItemIndex, Run);

  var ContentIndex: Integer;
  var Content: IDisplayTextRun;
  const IsOnMarker = ((Run.Role = TDisplayTextRunRole.Marker) and TryAdjacentRun(ItemIndex, 1, ContentIndex, Content));
  if IsOnMarker then
    Result := ContentIndex;
end;

function TMarkdownViewerModel.LineStartIndexFrom(const ItemIndex: Integer): Integer;
begin
  Result := ItemIndex;

  var Run: IDisplayTextRun;
  TrySelectableRun(Result, Run);

  var PreviousIndex: Integer;
  var Previous: IDisplayTextRun;
  while TryAdjacentRun(Result, -1, PreviousIndex, Previous) and ContinuesLine(Run, Previous) do
  begin
    Result := PreviousIndex;
    Run := Previous;
  end;
end;

function TMarkdownViewerModel.LineEndIndexFrom(const ItemIndex: Integer): Integer;
begin
  Result := ItemIndex;

  var Run: IDisplayTextRun;
  TrySelectableRun(Result, Run);

  var NextIndex: Integer;
  var Next: IDisplayTextRun;
  while TryAdjacentRun(Result, 1, NextIndex, Next) and ContinuesLine(Next, Run) do
  begin
    Result := NextIndex;
    Run := Next;
  end;
end;

function TMarkdownViewerModel.TryAdjacentRun(const ItemIndex, Direction: Integer; out AdjacentIndex: Integer;
  out Run: IDisplayTextRun): Boolean;
begin
  AdjacentIndex := ItemIndex + Direction;

  while (AdjacentIndex >= 0) and (AdjacentIndex < FDisplayList.ItemCount) do
  begin
    if TrySelectableRun(AdjacentIndex, Run) then
    begin
      Result := True;
      Exit;
    end;

    AdjacentIndex := AdjacentIndex + Direction;
  end;

  Run := nil;
  Result := False;
end;

// Two runs make one word when the second follows the first directly on the
// same line, as a change of formatting in the middle of a word does. In a
// formula the glyphs on one baseline make a word, so a double click takes the
// letters of a name like ac or the digits and letter of 2a, but not a power.
class function TMarkdownViewerModel.ContinuesWord(const Run, Before: IDisplayTextRun): Boolean;
begin
  const IsDirectlyAfter = ((Run.Join = TDisplayTextJoin.Adjacent) or
                           ((Run.Join = TDisplayTextJoin.None) and
                            SameValue(Run.Bounds.Top, Before.Bounds.Top, LineTopEpsilon)));
  const BothAreText = ((Run.Role = TDisplayTextRunRole.Text) and (Before.Role = TDisplayTextRunRole.Text));
  const AreOneFormulaLine = (IsGlyphOf(Run, Before.SourceNode) and IsGlyphOf(Before, Run.SourceNode) and
                             SameValue(Run.Bounds.Top + Run.Baseline, Before.Bounds.Top + Before.Baseline,
                                       LineTopEpsilon) and
                             SameValue(Run.Font.Size, Before.Font.Size, LineTopEpsilon));
  const MeetAtWordCharacters = ((Run.Text <> '') and (Before.Text <> '') and
                                (RunCharacterClass(Run, 0) = TCharacterClass.WordCharacter) and
                                (RunCharacterClass(Before, Length(Before.Text) - 1) = TCharacterClass.WordCharacter));

  Result := IsDirectlyAfter and (BothAreText or AreOneFormulaLine) and MeetAtWordCharacters;
end;

class function TMarkdownViewerModel.ContinuesLine(const Run, Before: IDisplayTextRun): Boolean;
begin
  const StaysOnLine = (Run.Join in [TDisplayTextJoin.None, TDisplayTextJoin.Adjacent, TDisplayTextJoin.Space,
                                    TDisplayTextJoin.Tab, TDisplayTextJoin.HardBreak]);
  const NeitherIsMarker = ((Run.Role <> TDisplayTextRunRole.Marker) and (Before.Role <> TDisplayTextRunRole.Marker));

  Result := StaysOnLine and NeitherIsMarker;
end;

class function TMarkdownViewerModel.CharacterClassOf(const Character: Char): TCharacterClass;
begin
  const IsWordCharacter = (Character.IsLetterOrDigit or (Character = '_'));
  if IsWordCharacter then
    Result := TCharacterClass.WordCharacter
  else if Character.IsWhiteSpace then
    Result := TCharacterClass.Space
  else
    Result := TCharacterClass.Other;
end;

// A source run is selected whole. So is a glyph of a formula that is one
// character beyond the basic plane, a letter of the mathematical alphabets,
// which a selection must not split; any other glyph selects character by
// character like text.
class function TMarkdownViewerModel.IsAtomicRun(const Run: IDisplayTextRun): Boolean;
begin
  const IsSource = (Run.Role = TDisplayTextRunRole.Source);
  const IsSurrogatePair = ((Length(Run.Text) = 2) and Run.Text[1].IsHighSurrogate);
  const IsWholeGlyph = ((Run.Role = TDisplayTextRunRole.Formula) and IsSurrogatePair);

  Result := IsSource or IsWholeGlyph;
end;

// The class of the character at Index of a run, counted from 0. A letter of
// the mathematical alphabets takes two characters and is a letter all the same.
class function TMarkdownViewerModel.RunCharacterClass(const Run: IDisplayTextRun;
  const Index: Integer): TCharacterClass;
begin
  const IsWholeGlyph = ((Run.Role = TDisplayTextRunRole.Formula) and IsAtomicRun(Run));
  if not IsWholeGlyph then
  begin
    Result := CharacterClassOf(Run.Text[Index + 1]);
    Exit;
  end;

  const CodePoint = Char.ConvertToUtf32(Run.Text[1], Run.Text[2]);
  const IsMathAlphanumeric = ((CodePoint >= MathAlphanumericFirst) and (CodePoint <= MathAlphanumericLast));
  if IsMathAlphanumeric then
    Result := TCharacterClass.WordCharacter
  else
    Result := TCharacterClass.Other;
end;

class function TMarkdownViewerModel.IsGlyphOf(const Run: IDisplayTextRun; const Formula: IMarkdownNode): Boolean;
begin
  Result := ((Run.Role = TDisplayTextRunRole.Formula) and (Run.SourceNode = Formula));
end;

// The glyphs of a formula follow one another among the selectable runs, with
// its bars and drawn delimiters between them and its source run after them.
// Left and Right are the edges of the ink of all of them.
procedure TMarkdownViewerModel.FindFormulaGlyphs(const Index: Integer; out FirstGlyph, LastGlyph: Integer;
  out Left, Right: Single);
begin
  var Glyph: IDisplayTextRun;
  TrySelectableRun(Index, Glyph);
  const Formula = Glyph.SourceNode;

  FirstGlyph := Index;
  Left := Glyph.Bounds.Left;
  var Before: IDisplayTextRun;
  var BeforeIndex: Integer;
  while TryAdjacentRun(FirstGlyph, -1, BeforeIndex, Before) and IsGlyphOf(Before, Formula) do
  begin
    FirstGlyph := BeforeIndex;
    Left := Min(Left, Before.Bounds.Left);
  end;

  LastGlyph := Index;
  Right := Glyph.Bounds.Right;
  var Next: IDisplayTextRun;
  var NextIndex: Integer;
  while TryAdjacentRun(LastGlyph, 1, NextIndex, Next) and IsGlyphOf(Next, Formula) do
  begin
    LastGlyph := NextIndex;
    Right := Max(Right, Next.Bounds.Right);
  end;
end;

// Beside a formula the pointer means its edge: past its right side the end of
// its last glyph, before its left side the start of its first, even where the
// glyph nearest to the pointer is a numerator or a power.
procedure TMarkdownViewerModel.SnapToFormulaEdge(const Point: TLayoutPointF; var Position: TTextPosition);
begin
  var FirstGlyph, LastGlyph: Integer;
  var Left, Right: Single;
  FindFormulaGlyphs(Position.ItemIndex, FirstGlyph, LastGlyph, Left, Right);

  const IsPastRight = (Point.X >= Right);
  const IsBeforeLeft = (Point.X <= Left);
  if IsPastRight then
  begin
    var Last: IDisplayTextRun;
    TrySelectableRun(LastGlyph, Last);
    Position.ItemIndex := LastGlyph;
    Position.CharacterIndex := Length(Last.Text);
  end
  else if IsBeforeLeft then
  begin
    Position.ItemIndex := FirstGlyph;
    Position.CharacterIndex := 0;
  end;
end;

// The selection holds the whole formula when it reaches from before its first
// glyph to after its last; the formula then copies as its source run.
function TMarkdownViewerModel.TryGetWholeFormula(const Glyph: Integer; const Range: TTextRange;
  out SourceIndex: Integer): Boolean;
begin
  var FirstGlyph, LastGlyph: Integer;
  var Left, Right: Single;
  FindFormulaGlyphs(Glyph, FirstGlyph, LastGlyph, Left, Right);

  var First, Last: IDisplayTextRun;
  TrySelectableRun(FirstGlyph, First);
  TrySelectableRun(LastGlyph, Last);

  var FormulaStart: TTextPosition;
  FormulaStart.ItemIndex := FirstGlyph;
  FormulaStart.CharacterIndex := 0;
  var FormulaEnd: TTextPosition;
  FormulaEnd.ItemIndex := LastGlyph;
  FormulaEnd.CharacterIndex := Length(Last.Text);

  const HoldsFormula = ((ComparePositions(Range.StartPosition, FormulaStart) <= 0) and
                        (ComparePositions(Range.EndPosition, FormulaEnd) >= 0));

  var Source: IDisplayTextRun;
  const HasSource = (TryAdjacentRun(LastGlyph, 1, SourceIndex, Source) and
                     (Source.Role = TDisplayTextRunRole.Source) and (Source.SourceNode = First.SourceNode));

  Result := HoldsFormula and HasSource;
end;

// What a selection holds, piece by piece. A formula is in the display list
// twice: as the glyphs it shows, then as its source run, its markdown. A
// selection that holds the whole formula reads the source run, so the formula
// copies as markdown and pastes back as the same formula; one that holds part
// of it reads the glyphs. The source run counts on its own only where the
// selection starts at it, as after find selected the formula.
function TMarkdownViewerModel.SelectedPieces(const Range: TTextRange): TArray<TSelectedPiece>;
begin
  Result := [];

  var Index := Range.StartPosition.ItemIndex;
  while Index <= Range.EndPosition.ItemIndex do
  begin
    var NextIndex := Index + 1;
    var Piece := Default(TSelectedPiece);
    Piece.ItemIndex := Index;
    const IsSelected = (TrySelectableRun(Index, Piece.Run) and
                        SelectedCharacterRange(Piece.Run, Index, Range.StartPosition, Range.EndPosition,
                                               Piece.CharFrom, Piece.CharTo));
    if IsSelected then
    begin
      Piece.JoinRun := Piece.Run;

      var SourceIndex: Integer;
      const IsGlyph = (Piece.Run.Role = TDisplayTextRunRole.Formula);
      const IsSource = (Piece.Run.Role = TDisplayTextRunRole.Source);
      if IsGlyph and TryGetWholeFormula(Index, Range, SourceIndex) then
      begin
        TrySelectableRun(SourceIndex, Piece.Run);
        Piece.ItemIndex := SourceIndex;
        Piece.CharFrom := 0;
        Piece.CharTo := Length(Piece.Run.Text);
        NextIndex := SourceIndex + 1;
        Result := Result + [Piece];
      end
      else if IsSource then
      begin
        const StartsHere = ((Index = Range.StartPosition.ItemIndex) and (Piece.CharFrom = 0));
        if StartsHere then
          Result := Result + [Piece];
      end
      else
      begin
        Result := Result + [Piece];
      end;
    end;

    Index := NextIndex;
  end;
end;

procedure TMarkdownViewerModel.ClearSelection;
begin
  FSelectionActive := False;
end;

// The first and the last text run bracket everything the reader can see, so
// selecting all covers the same range a drag from above the document to below
// it would produce. Runs without characters are skipped: they would leave the
// selection collapsed on an edge and copy nothing.
function TMarkdownViewerModel.TryFindTextRunBounds(out FirstIndex, LastIndex: Integer): Boolean;
begin
  FirstIndex := -1;
  LastIndex := -1;
  if FDisplayList = nil then
  begin
    Result := False;
    Exit;
  end;

  for var Index := 0 to FDisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    if not TrySelectableRun(Index, Run) then
      Continue;

    if Run.Text = '' then
      Continue;

    if FirstIndex < 0 then
      FirstIndex := Index;
    LastIndex := Index;
  end;

  Result := FirstIndex >= 0;
end;

function TMarkdownViewerModel.HasSelectableText: Boolean;
begin
  var FirstIndex, LastIndex: Integer;
  Result := TryFindTextRunBounds(FirstIndex, LastIndex);
end;

function TMarkdownViewerModel.SelectAll: Boolean;
begin
  var Range: TTextRange;
  Result := TryGetEverythingRange(Range);
  if not Result then
    Exit;

  FAnchor := Range.StartPosition;
  FExtent := Range.EndPosition;
  FSelectionActive := True;
end;

// From the first character of the first run to the last character of the last.
function TMarkdownViewerModel.TryGetEverythingRange(out Range: TTextRange): Boolean;
begin
  Range := Default(TTextRange);

  var FirstIndex, LastIndex: Integer;
  Result := TryFindTextRunBounds(FirstIndex, LastIndex);
  if not Result then
    Exit;

  var LastRun: IDisplayTextRun;
  Result := TrySelectableRun(LastIndex, LastRun);
  if not Result then
    Exit;

  Range.StartPosition.ItemIndex := FirstIndex;
  Range.StartPosition.CharacterIndex := 0;
  Range.EndPosition.ItemIndex := LastIndex;
  Range.EndPosition.CharacterIndex := Length(LastRun.Text);
end;

function TMarkdownViewerModel.HasSelection: Boolean;
begin
  Result := HasCaret and (ComparePositions(FAnchor, FExtent) <> 0);
end;

function TMarkdownViewerModel.SelectionRects: TArray<TLayoutRectF>;
begin
  Result := [];
  if not HasSelection then
    Exit;

  for var Piece in SelectedPieces(NormalizeSelection) do
  begin
    const Run = Piece.Run;
    const RunRect = ClipToScroller(Piece.ItemIndex, TLayoutRectF.Create(Run.Bounds.Left + PrefixWidth(Run,
      Piece.CharFrom), Run.Bounds.Top, Run.Bounds.Left + PrefixWidth(Run, Piece.CharTo), Run.Bounds.Bottom));
    if RunRect.Right <= RunRect.Left then
      Continue;

    const LastIndex = High(Result);
    const MergesWithLast = (LastIndex >= 0) and SameValue(Result[LastIndex].Top, RunRect.Top, LineTopEpsilon);
    if MergesWithLast then
    begin
      Result[LastIndex].Left := Min(Result[LastIndex].Left, RunRect.Left);
      Result[LastIndex].Right := Max(Result[LastIndex].Right, RunRect.Right);
      Result[LastIndex].Bottom := Max(Result[LastIndex].Bottom, RunRect.Bottom);
    end
    else
      Result := Result + [RunRect];
  end;
end;

function TMarkdownViewerModel.SelectedText: string;
begin
  Result := '';
  if not HasSelection then
    Exit;

  var HasPrevious := False;
  var PreviousTop := 0.0;
  var PreviousBlock := 0;

  var Previous := Default(TSelectedPiece);

  for var Piece in SelectedPieces(NormalizeSelection) do
  begin
    var Segment := Copy(Piece.Run.Text, Piece.CharFrom + 1, Piece.CharTo - Piece.CharFrom);

    // Part of a formula copies as the characters it shows, a letter of the
    // mathematical alphabets as the plain letter a reader would type.
    const IsGlyph = (Piece.Run.Role = TDisplayTextRunRole.Formula);
    if IsGlyph then
      Segment := TMathLayouter.PlainText(Segment);

    const BlockIndex = BlockIndexOfItem(Piece.ItemIndex);
    if HasPrevious then
      Result := Result + SeparatorBetween(Previous, Piece, BlockIndex <> PreviousBlock, PreviousTop);

    Result := Result + Segment;

    HasPrevious := True;
    Previous := Piece;
    PreviousTop := Piece.Run.Bounds.Top;
    PreviousBlock := BlockIndex;
  end;
end;

// Two glyphs of one formula follow on directly, except where a cell or a row
// of a table ends between them; anything else is set apart as its run says.
class function TMarkdownViewerModel.SeparatorBetween(const Previous, Piece: TSelectedPiece;
  const StartsBlock: Boolean; const PreviousTop: Single): string;
begin
  const AreGlyphsOfOneFormula = (IsGlyphOf(Previous.Run, Piece.Run.SourceNode) and
                                 IsGlyphOf(Piece.Run, Previous.Run.SourceNode));
  if AreGlyphsOfOneFormula then
    Result := TableBreakBetween(Previous.Run, Piece.Run)
  else
    Result := SeparatorBefore(Piece.JoinRun, StartsBlock, PreviousTop);
end;

// The TeX between two glyphs tells where a cell of an array, a matrix or a
// tabular ends, at an &, and where a row ends, at a \\. The glyphs then copy
// as a table copies from a browser: cells apart by tabs, rows by line breaks.
class function TMarkdownViewerModel.TableBreakBetween(const Before, After: IDisplayTextRun): string;
begin
  Result := '';

  var Math: IMarkdownMath;
  if not Supports(After.SourceNode, IMarkdownMath, Math) then
    Exit;

  const GapStart = Before.StartOffset + Before.SourceLength;
  const Gap = Copy(Math.Literal, GapStart + 1, After.StartOffset - GapStart);
  const EndsRow = Gap.Contains(FormulaRowEnd);
  const EndsCell = Gap.Contains(FormulaCellEnd);
  if EndsRow then
    Result := sLineBreak
  else if EndsCell then
    Result := CopiedTab;
end;

// A run the layout gave a join copies with that join. One without, drawn by an
// extension for instance, falls back on where it sits: a new block starts a
// new line, a new line within a block is a space.
class function TMarkdownViewerModel.SeparatorBefore(const Run: IDisplayTextRun; const StartsBlock: Boolean;
  const PreviousTop: Single): string;
begin
  const Indent = StringOfChar(CopiedSpace, Run.IndentLevel * CopiedIndentWidth);

  case Run.Join of
    TDisplayTextJoin.None      : Result := FallbackSeparator(Run, StartsBlock, PreviousTop);
    TDisplayTextJoin.Adjacent  : Result := '';
    TDisplayTextJoin.Space     : Result := CopiedSpace;
    TDisplayTextJoin.Tab       : Result := CopiedTab;
    TDisplayTextJoin.HardBreak,
    TDisplayTextJoin.LineBreak : Result := sLineBreak + Indent;
    TDisplayTextJoin.BlankLine : Result := sLineBreak + sLineBreak + Indent;
  else
    raise EMarkdownError.CreateFmt('Unhandled text join: %d', [Ord(Run.Join)]);
  end;
end;

class function TMarkdownViewerModel.FallbackSeparator(const Run: IDisplayTextRun; const StartsBlock: Boolean;
  const PreviousTop: Single): string;
begin
  const StartsLine = not SameValue(Run.Bounds.Top, PreviousTop, LineTopEpsilon);

  if StartsBlock then
    Result := sLineBreak
  else if StartsLine then
    Result := CopiedSpace
  else
    Result := '';
end;

function TMarkdownViewerModel.SourceLineToScrollOffset(const SourceLine: Integer): Single;
begin
  RefreshSourceLines;
  Result := FSourceLines.SourceLineToOffset(SourceLine);
end;

function TMarkdownViewerModel.ScrollOffsetToSourceLine(const Offset: Single): Integer;
begin
  RefreshSourceLines;
  Result := FSourceLines.OffsetToSourceLine(Offset);
end;

procedure TMarkdownViewerModel.RefreshSourceLines;
begin
  const IsCurrent = (FSourceLinesLayoutCount = FLayoutCount);
  if IsCurrent then
    Exit;

  FSourceLines.Build(FDocument, FDisplayList, FText);
  FSourceLinesLayoutCount := FLayoutCount;
end;

function TMarkdownViewerModel.TryGetAnchorOffset(const Anchor: string; out Offset: Single): Boolean;
begin
  Offset := 0;
  Result := False;
  if FDisplayList = nil then
    Exit;

  var Heading: IMarkdownHeading;
  if not TryFindAnchorHeading(Anchor, Heading) then
    Exit;

  const Segment = Heading.Segment;
  for var Index := 0 to FDisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    if not TrySelectableRun(Index, Run) then
      Continue;

    const Start = Run.SourceNode.Segment.StartOffset;
    const IsInHeading = ((Start >= Segment.StartOffset) and (Start < Segment.EndOffset));
    if IsInHeading then
    begin
      Offset := Run.Bounds.Top;
      Result := True;
      Exit;
    end;
  end;
end;

function TMarkdownViewerModel.RevealAnchor(const Anchor: string): Boolean;
begin
  Result := False;

  var Heading: IMarkdownHeading;
  if not TryFindAnchorHeading(Anchor, Heading) then
    Exit;

  const Openers = TMarkdownDisclosures.SectionsAround(FDocument, Heading);
  for var Opener in Openers do
  begin
    var OpenByDefault: Boolean;
    TMarkdownDisclosures.IsOpener(Opener, OpenByDefault);
    if TMarkdownDisclosures.IsOpen(Self, Opener, OpenByDefault) then
      Continue;

    const Key = TMarkdownDisclosures.KeyOf(Opener);
    FlipDisclosure(Key);
    Result := True;
  end;

  if Result then
    RefreshLayout;
end;

function TMarkdownViewerModel.TryFindAnchorHeading(const Anchor: string; out Heading: IMarkdownHeading): Boolean;
begin
  Heading := nil;
  if FDocument = nil then
    Exit(False);

  const Name = TNetEncoding.URL.Decode(Anchor.TrimLeft([AnchorMark]));
  Result := TMarkdownToc.TryFindHeading(FDocument, Name, Heading);
end;

function TMarkdownViewerModel.SelectedMarkdown: string;
begin
  Result := '';
  if not HasSelection then
    Exit;

  if IsEverythingSelected then
  begin
    Result := TMarkdownSelectedSource.WithPlatformLineBreaks(FText);
    Exit;
  end;

  var Segment: TMarkdownSegment;
  if TryGetSelectionSourceSegment(Segment) then
    Result := TMarkdownSelectedSource.Extract(FText, FDocument, Segment);
end;

function TMarkdownViewerModel.IsEverythingSelected: Boolean;
begin
  var Everything: TTextRange;
  Result := TryGetEverythingRange(Everything);
  if not Result then
    Exit;

  const Selection = NormalizeSelection;
  Result := ((ComparePositions(Selection.StartPosition, Everything.StartPosition) = 0) and
             (ComparePositions(Selection.EndPosition, Everything.EndPosition) = 0));
end;

function TMarkdownViewerModel.TryGetSelectionSourceSegment(out Segment: TMarkdownSegment): Boolean;
begin
  Segment := Default(TMarkdownSegment);
  Result := False;

  var FirstRun, LastRun: IDisplayTextRun;
  var FirstCharacter, LastCharacter: Integer;
  if not TryFindSelectionEdges(FirstRun, LastRun, FirstCharacter, LastCharacter) then
    Exit;

  var StartOffset, EndOffset: Integer;
  const IsStartMapped = TMarkdownSourceMapper.TryMapLiteralOffset(FText, FirstRun.SourceNode,
    FirstRun.StartOffset + FirstCharacter, TMarkdownSourceEdge.Leading, StartOffset);
  const IsEndMapped = TMarkdownSourceMapper.TryMapLiteralOffset(FText, LastRun.SourceNode,
    LastRun.StartOffset + LastCharacter, TMarkdownSourceEdge.Trailing, EndOffset);

  const CoversCharacters = IsStartMapped and IsEndMapped and (EndOffset > StartOffset);
  if not CoversCharacters then
    Exit;

  Segment := TMarkdownSegment.Create(StartOffset, EndOffset);
  Result := True;
end;

// The runs between the two ends of the selection follow one another in the
// source as well, so the first and the last of them bracket the whole stretch.
function TMarkdownViewerModel.TryFindSelectionEdges(out FirstRun, LastRun: IDisplayTextRun;
  out FirstCharacter, LastCharacter: Integer): Boolean;
begin
  FirstRun := nil;
  LastRun := nil;
  FirstCharacter := 0;
  LastCharacter := 0;

  if not HasSelection then
  begin
    Result := False;
    Exit;
  end;

  const Range = NormalizeSelection;

  for var Index := Range.StartPosition.ItemIndex to Range.EndPosition.ItemIndex do
  begin
    var Run: IDisplayTextRun;
    if not TrySelectableRun(Index, Run) then
      Continue;

    var CharFrom, CharTo: Integer;
    if not SelectedCharacterRange(Run, Index, Range.StartPosition, Range.EndPosition, CharFrom, CharTo) then
      Continue;

    if FirstRun = nil then
    begin
      FirstRun := Run;
      FirstCharacter := CharFrom;
    end;

    LastRun := Run;
    LastCharacter := CharTo;
  end;

  Result := (FirstRun <> nil);
end;

function TMarkdownViewerModel.PendingImageSources: TArray<string>;
begin
  Result := [];

  for var Source in FImageSlotOrder do
  begin
    if FImageSlots[Source].State = TMarkdownImageSlotState.Requested then
      Result := Result + [Source];
  end;
end;

procedure TMarkdownViewerModel.NotifyImageArrived(const Source: string; const Size: TLayoutSizeF);
begin
  var Slot: TImageSlot;
  if not FImageSlots.TryGetValue(Source, Slot) then
    Exit;

  if Slot.State = TMarkdownImageSlotState.Loaded then
    Exit;

  Slot.State := TMarkdownImageSlotState.Loaded;
  Slot.Size := Size;
  FImageSlots[Source] := Slot;
  Relayout;
end;

procedure TMarkdownViewerModel.NotifyImageFailed(const Source: string);
begin
  var Slot: TImageSlot;
  if not FImageSlots.TryGetValue(Source, Slot) then
    Exit;

  if Slot.State = TMarkdownImageSlotState.Loaded then
    Exit;

  Slot.State := TMarkdownImageSlotState.Failed;
  FImageSlots[Source] := Slot;
end;

function TMarkdownViewerModel.ImageSlotState(const Source: string): TMarkdownImageSlotState;
begin
  var Slot: TImageSlot;
  if FImageSlots.TryGetValue(Source, Slot) then
  begin
    Result := Slot.State;
    Exit;
  end;

  Result := TMarkdownImageSlotState.Unknown;
end;

function TMarkdownViewerModel.TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
begin
  Size := Default(TLayoutSizeF);

  var Slot: TImageSlot;
  Result := FImageSlots.TryGetValue(Source, Slot) and (Slot.State = TMarkdownImageSlotState.Loaded);
  if Result then
    Size := TLayoutSizeF.Create(Slot.Size.Width * ZoomFactor, Slot.Size.Height * ZoomFactor);
end;

procedure TMarkdownViewerModel.ExtensionFailed(const Extension: string; const Error: Exception);
begin
  if Assigned(FOnExtensionError) then
    FOnExtensionError(Self, Extension, Error);
end;

function TMarkdownViewerModel.FindText(const Needle: string): TArray<TMarkdownFoundRange>;
begin
  Result := FindText(Needle, Default(TMarkdownFindOptions));
end;

function TMarkdownViewerModel.FindText(const Needle: string;
  const Options: TMarkdownFindOptions): TArray<TMarkdownFoundRange>;
begin
  Result := [];

  const IsSearchable = (Needle <> '') and (FDisplayList <> nil);
  if not IsSearchable then
    Exit;

  const NeedleLength = Length(Needle);

  for var Index := 0 to FDisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    if not TrySelectableRun(Index, Run) then
      Continue;

    // A formula is found in its TeX, which its source run holds, not in the
    // glyphs it shows.
    const IsGlyph = (Run.Role = TDisplayTextRunRole.Formula);
    if IsGlyph then
      Continue;

    const RunText = Run.Text;
    var Offset := 1;
    var Found := TMarkdownTextSearch.IndexOf(Needle, RunText, Offset, Options);

    while Found > 0 do
    begin
      Result := Result + [TMarkdownFoundRange.Create(Index, Found, NeedleLength)];
      Offset := Found + NeedleLength;
      Found := TMarkdownTextSearch.IndexOf(Needle, RunText, Offset, Options);
    end;
  end;
end;

function TMarkdownViewerModel.TrySelectNextMatch(const Needle: string; out Match: TMarkdownFoundRange): Boolean;
begin
  Result := TrySelectNextMatch(Needle, Default(TMarkdownFindOptions), Match);
end;

function TMarkdownViewerModel.TrySelectNextMatch(const Needle: string; const Options: TMarkdownFindOptions;
  out Match: TMarkdownFoundRange): Boolean;
begin
  Match := Default(TMarkdownFoundRange);
  OpenSectionsBeforeNextMatch(Needle, Options);

  const Matches = FindText(Needle, Options);
  Result := (Length(Matches) > 0);
  if not Result then
    Exit;

  Match := NextMatchAfterSelection(Matches);
  SelectMatch(Match);
end;

function TMarkdownViewerModel.TrySelectPreviousMatch(const Needle: string; out Match: TMarkdownFoundRange): Boolean;
begin
  Result := TrySelectPreviousMatch(Needle, Default(TMarkdownFindOptions), Match);
end;

function TMarkdownViewerModel.TrySelectPreviousMatch(const Needle: string; const Options: TMarkdownFindOptions;
  out Match: TMarkdownFoundRange): Boolean;
begin
  Match := Default(TMarkdownFoundRange);
  OpenSectionsBeforePreviousMatch(Needle, Options);

  const Matches = FindText(Needle, Options);
  Result := (Length(Matches) > 0);
  if not Result then
    Exit;

  Match := PreviousMatchBeforeSelection(Matches);
  SelectMatch(Match);
end;

function TMarkdownViewerModel.NextMatchAfterSelection(const Matches: TArray<TMarkdownFoundRange>): TMarkdownFoundRange;
begin
  if not TryGetMatchAhead(Matches, Result) then
    Result := Matches[0];
end;

function TMarkdownViewerModel.PreviousMatchBeforeSelection(
  const Matches: TArray<TMarkdownFoundRange>): TMarkdownFoundRange;
begin
  if not TryGetMatchBehind(Matches, Result) then
    Result := Matches[High(Matches)];
end;

// A bare caret sits between two characters, so a match that starts right at
// it is still ahead; a selection is past its own start. Without a caret the
// first match is ahead.
function TMarkdownViewerModel.TryGetMatchAhead(const Matches: TArray<TMarkdownFoundRange>;
  out Match: TMarkdownFoundRange): Boolean;
begin
  Match := Default(TMarkdownFoundRange);
  Result := (Length(Matches) > 0);
  if not Result then
    Exit;

  Match := Matches[0];
  if not HasCaret then
    Exit;

  const Selection = NormalizeSelection;
  const IsBareCaret = (not HasSelection);

  for var Candidate in Matches do
  begin
    const CandidateRange = RangeOfMatch(Candidate);
    const Order = ComparePositions(CandidateRange.StartPosition, Selection.StartPosition);
    const IsAhead = ((Order > 0) or (IsBareCaret and (Order = 0)));
    if IsAhead then
    begin
      Match := Candidate;
      Exit;
    end;
  end;

  Result := False;
end;

// Without a caret the last match is behind.
function TMarkdownViewerModel.TryGetMatchBehind(const Matches: TArray<TMarkdownFoundRange>;
  out Match: TMarkdownFoundRange): Boolean;
begin
  Match := Default(TMarkdownFoundRange);
  Result := (Length(Matches) > 0);
  if not Result then
    Exit;

  Match := Matches[High(Matches)];
  if not HasCaret then
    Exit;

  const Selection = NormalizeSelection;
  Result := False;

  for var Candidate in Matches do
  begin
    const CandidateRange = RangeOfMatch(Candidate);
    const IsBeforeSelectionStart = (ComparePositions(CandidateRange.StartPosition, Selection.StartPosition) < 0);
    if not IsBeforeSelectionStart then
      Break;

    Match := Candidate;
    Result := True;
  end;
end;

// Each pass opens at most one section, and a section inside it may hold the
// match, so this repeats until the next match is in view.
procedure TMarkdownViewerModel.OpenSectionsBeforeNextMatch(const Needle: string;
  const Options: TMarkdownFindOptions);
begin
  var Opened := TryOpenSectionBeforeNextMatch(Needle, Options);
  while Opened do
    Opened := TryOpenSectionBeforeNextMatch(Needle, Options);
end;

procedure TMarkdownViewerModel.OpenSectionsBeforePreviousMatch(const Needle: string;
  const Options: TMarkdownFindOptions);
begin
  var Opened := TryOpenSectionBeforePreviousMatch(Needle, Options);
  while Opened do
    Opened := TryOpenSectionBeforePreviousMatch(Needle, Options);
end;

// A closed section holding the needle that comes after the caret and before
// the next match in view; when the walk wraps to the start of the document,
// the first such section before the first match.
function TMarkdownViewerModel.TryOpenSectionBeforeNextMatch(const Needle: string;
  const Options: TMarkdownFindOptions): Boolean;
begin
  const Sections = SectionsHolding(Needle, Options);
  const HasSections = (Length(Sections) > 0);
  if not HasSections then
    Exit(False);

  const Matches = FindText(Needle, Options);
  var Ahead: TMarkdownFoundRange;
  const HasMatchAhead = TryGetMatchAhead(Matches, Ahead);
  const From = CaretItemIndex(-1);

  for var Section in Sections do
  begin
    const IsBeforeMatch = ((not HasMatchAhead) or (Section < Ahead.ItemIndex));
    const IsAfterCaret = (Section > From);
    if IsAfterCaret and IsBeforeMatch then
    begin
      OpenSectionAt(Section);
      Exit(True);
    end;
  end;

  const IsBeforeFirstMatch = ((Length(Matches) = 0) or (Sections[0] < Matches[0].ItemIndex));
  Result := ((not HasMatchAhead) and IsBeforeFirstMatch);
  if Result then
    OpenSectionAt(Sections[0]);
end;

function TMarkdownViewerModel.TryOpenSectionBeforePreviousMatch(const Needle: string;
  const Options: TMarkdownFindOptions): Boolean;
begin
  const Sections = SectionsHolding(Needle, Options);
  const HasSections = (Length(Sections) > 0);
  if not HasSections then
    Exit(False);

  const Matches = FindText(Needle, Options);
  var Behind: TMarkdownFoundRange;
  const HasMatchBehind = TryGetMatchBehind(Matches, Behind);
  const From = CaretItemIndex(MaxInt);

  for var Index := High(Sections) downto 0 do
  begin
    const Section = Sections[Index];
    const IsAfterMatch = ((not HasMatchBehind) or (Section > Behind.ItemIndex));
    const IsBeforeCaret = (Section < From);
    if IsBeforeCaret and IsAfterMatch then
    begin
      OpenSectionAt(Section);
      Exit(True);
    end;
  end;

  const LastSection = Sections[High(Sections)];
  const IsAfterLastMatch = ((Length(Matches) = 0) or (LastSection > Matches[High(Matches)].ItemIndex));
  Result := ((not HasMatchBehind) and IsAfterLastMatch);
  if Result then
    OpenSectionAt(LastSection);
end;

// The display items of the closed sections whose hidden source holds the
// needle, in document order. The source can hold markup the reader does not
// see, so a section can open without a match in it; the walk then goes on.
function TMarkdownViewerModel.SectionsHolding(const Needle: string;
  const Options: TMarkdownFindOptions): TArray<Integer>;
begin
  Result := nil;
  const IsSearchable = ((Needle <> '') and (FDocument <> nil) and (FDisplayList <> nil));
  if not IsSearchable then
    Exit;

  const Sections = TMarkdownDisclosures.ClosedSections(FDocument, FText, Self);
  for var Section in Sections do
  begin
    const Position = TMarkdownTextSearch.IndexOf(Needle, Section.HiddenSource, 1, Options);
    const HoldsNeedle = (Position > 0);
    if not HoldsNeedle then
      Continue;

    const Key = TMarkdownDisclosures.KeyOf(Section.Opener);
    var ItemIndex: Integer;
    if TryGetDisclosureItem(Key, ItemIndex) then
      Result := Result + [ItemIndex];
  end;
end;

function TMarkdownViewerModel.TryGetDisclosureItem(const Key: Integer; out ItemIndex: Integer): Boolean;
begin
  for var Index := 0 to FDisplayList.ItemCount - 1 do
  begin
    var Disclosure: IDisplayDisclosure;
    const IsSection = (Supports(FDisplayList.Items[Index], IDisplayDisclosure, Disclosure) and
                       (Disclosure.Key = Key));
    if IsSection then
    begin
      ItemIndex := Index;
      Exit(True);
    end;
  end;

  ItemIndex := -1;
  Result := False;
end;

procedure TMarkdownViewerModel.OpenSectionAt(const ItemIndex: Integer);
begin
  const Disclosure = FDisplayList.Items[ItemIndex] as IDisplayDisclosure;
  ToggleDisclosure(Disclosure.Key);
end;

// The display item the selection starts in, or WithoutCaret when there is
// no caret.
function TMarkdownViewerModel.CaretItemIndex(const WithoutCaret: Integer): Integer;
begin
  if not HasCaret then
    Exit(WithoutCaret);

  const Selection = NormalizeSelection;
  Result := Selection.StartPosition.ItemIndex;
end;

function TMarkdownViewerModel.HasCaret: Boolean;
begin
  if not FSelectionActive or (FDisplayList = nil) then
  begin
    Result := False;
    Exit;
  end;

  Result := (FAnchor.ItemIndex < FDisplayList.ItemCount) and
            (FExtent.ItemIndex < FDisplayList.ItemCount);
end;

procedure TMarkdownViewerModel.SelectMatch(const Match: TMarkdownFoundRange);
begin
  const Range = RangeOfMatch(Match);
  FSelectionUnit := TSelectionUnit.Character;
  FAnchor := Range.StartPosition;
  FExtent := Range.EndPosition;
  FSelectionActive := True;
  RevealInScroller(Match.ItemIndex);
end;

// The source of a formula is selected whole or not at all, the same rule a
// click on it follows, so a match inside it covers the whole run.
function TMarkdownViewerModel.RangeOfMatch(const Match: TMarkdownFoundRange): TTextRange;
begin
  const Run = MatchRun(Match);
  Result := RangeInRun(Run, Match);
end;

function TMarkdownViewerModel.RangeInRun(const Run: IDisplayTextRun; const Match: TMarkdownFoundRange): TTextRange;
begin
  Result.StartPosition.ItemIndex := Match.ItemIndex;
  Result.EndPosition.ItemIndex := Match.ItemIndex;

  const IsAtomic = (Run.Role = TDisplayTextRunRole.Source);
  if IsAtomic then
  begin
    Result.StartPosition.CharacterIndex := 0;
    Result.EndPosition.CharacterIndex := Length(Run.Text);
    Exit;
  end;

  Result.StartPosition.CharacterIndex := Match.StartCharacter - 1;
  Result.EndPosition.CharacterIndex := Result.StartPosition.CharacterIndex + Match.CharacterCount;
end;

function TMarkdownViewerModel.MatchRun(const Match: TMarkdownFoundRange): IDisplayTextRun;
begin
  const Item = FDisplayList.Items[Match.ItemIndex];
  Result := Item as IDisplayTextRun;
end;

function TMarkdownViewerModel.MatchCount(const Needle: string): Integer;
begin
  Result := MatchCount(Needle, Default(TMarkdownFindOptions));
end;

function TMarkdownViewerModel.MatchCount(const Needle: string; const Options: TMarkdownFindOptions): Integer;
begin
  const Matches = FindText(Needle, Options);
  const Stops = DistinctMatches(Matches);
  Result := Length(Stops);
end;

function TMarkdownViewerModel.MatchIndex(const Needle: string; const Options: TMarkdownFindOptions): Integer;
begin
  Result := -1;
  if not HasSelection then
    Exit;

  const Selection = NormalizeSelection;
  const Matches = FindText(Needle, Options);
  const Stops = DistinctMatches(Matches);

  for var Index := 0 to High(Stops) do
  begin
    const Range = RangeOfMatch(Stops[Index]);
    const IsSelected = ((ComparePositions(Range.StartPosition, Selection.StartPosition) = 0) and
                        (ComparePositions(Range.EndPosition, Selection.EndPosition) = 0));
    if IsSelected then
    begin
      Result := Index;
      Exit;
    end;
  end;
end;

// Matches that select the same range, as several hits in one formula do,
// collapse into the first of them.
function TMarkdownViewerModel.DistinctMatches(
  const Matches: TArray<TMarkdownFoundRange>): TArray<TMarkdownFoundRange>;
begin
  SetLength(Result, Length(Matches));

  var DistinctCount := 0;
  var PreviousStart := Default(TTextPosition);

  for var Match in Matches do
  begin
    const Range = RangeOfMatch(Match);
    const RepeatsPrevious = ((DistinctCount > 0) and (ComparePositions(Range.StartPosition, PreviousStart) = 0));
    if RepeatsPrevious then
      Continue;

    Result[DistinctCount] := Match;
    PreviousStart := Range.StartPosition;
    Inc(DistinctCount);
  end;

  SetLength(Result, DistinctCount);
end;

procedure TMarkdownViewerModel.HighlightMatches(const Needle: string);
begin
  HighlightMatches(Needle, Default(TMarkdownFindOptions));
end;

procedure TMarkdownViewerModel.HighlightMatches(const Needle: string; const Options: TMarkdownFindOptions);
begin
  FHighlightNeedle := Needle;
  FHighlightOptions := Options;
  RefreshHighlights;
end;

procedure TMarkdownViewerModel.ClearHighlights;
begin
  HighlightMatches('');
end;

function TMarkdownViewerModel.HighlightCount: Integer;
begin
  Result := Length(FHighlightRects);
end;

function TMarkdownViewerModel.HighlightRectsWithin(const Viewport: TLayoutRectF): TArray<TLayoutRectF>;
begin
  SetLength(Result, Length(FHighlightRects));

  var VisibleCount := 0;

  for var HighlightRect in FHighlightRects do
  begin
    const IsVisible = ((HighlightRect.Bottom >= Viewport.Top) and (HighlightRect.Top <= Viewport.Bottom));
    if not IsVisible then
      Continue;

    Result[VisibleCount] := HighlightRect;
    Inc(VisibleCount);
  end;

  SetLength(Result, VisibleCount);
end;

function TMarkdownViewerModel.TryGetScrollTarget(const Match: TMarkdownFoundRange; out Offset: Single): Boolean;
begin
  const Bounds = MatchBounds(Match);
  Offset := Bounds.Top - (FViewportHeight - Bounds.Height) / 2;
  Result := not IsWithinViewport(Bounds);
end;

// The rectangles are measured once per layout rather than on every paint,
// so scrolling through a document full of matches stays cheap.
procedure TMarkdownViewerModel.RefreshHighlights;
begin
  const Matches = FindText(FHighlightNeedle, FHighlightOptions);
  const Marks = DistinctMatches(Matches);
  SetLength(FHighlightRects, Length(Marks));

  for var Index := 0 to High(Marks) do
  begin
    const Run = MatchRun(Marks[Index]);
    const Range = RangeInRun(Run, Marks[Index]);
    FHighlightRects[Index] := ClipToScroller(Marks[Index].ItemIndex, BoundsInRun(Run, Range));
  end;
end;

function TMarkdownViewerModel.MatchBounds(const Match: TMarkdownFoundRange): TLayoutRectF;
begin
  const Run = MatchRun(Match);
  const Range = RangeInRun(Run, Match);
  Result := BoundsInRun(Run, Range);
end;

function TMarkdownViewerModel.BoundsInRun(const Run: IDisplayTextRun; const Range: TTextRange): TLayoutRectF;
begin
  const RunBounds = Run.Bounds;
  const Left = RunBounds.Left + PrefixWidth(Run, Range.StartPosition.CharacterIndex);
  const Right = RunBounds.Left + PrefixWidth(Run, Range.EndPosition.CharacterIndex);

  Result := TLayoutRectF.Create(Left, RunBounds.Top, Right, RunBounds.Bottom);
end;

function TMarkdownViewerModel.IsWithinViewport(const Bounds: TLayoutRectF): Boolean;
begin
  const ViewportBottom = FScrollOffset + FViewportHeight;
  Result := ((Bounds.Top >= FScrollOffset) and (Bounds.Bottom <= ViewportBottom));
end;

function TMarkdownViewerModel.TryGetCodeBlockAt(const Point: TLayoutPointF;
  out Region: TMarkdownCodeBlockRegion): Boolean;
begin
  for var Candidate in CodeBlockRegions do
  begin
    if Candidate.Rect.Contains(Point) then
    begin
      Region := Candidate;
      Result := True;
      Exit;
    end;
  end;

  Region := Default(TMarkdownCodeBlockRegion);
  Result := False;
end;

function TMarkdownViewerModel.TryGetDisclosureAt(const Point: TLayoutPointF; out Key: Integer): Boolean;
begin
  Key := 0;
  Result := False;
  if FDisplayList = nil then
    Exit;

  var Disclosure: IDisplayDisclosure;
  Result := TMarkdownHitTester.TryFindDisclosure(FDisplayList, Point, Disclosure);
  if Result then
    Key := Disclosure.Key;
end;

procedure TMarkdownViewerModel.ToggleDisclosure(const Key: Integer);
begin
  FlipDisclosure(Key);

  RefreshLayout;
  // Closing a section near the end can leave the view scrolled past the
  // shorter document.
  SetScrollOffset(FScrollOffset);
end;

procedure TMarkdownViewerModel.FlipDisclosure(const Key: Integer);
begin
  const WasToggled = FToggledDisclosures.Contains(Key);
  if WasToggled then
    FToggledDisclosures.Remove(Key)
  else
    FToggledDisclosures.Add(Key);
end;

function TMarkdownViewerModel.IsDisclosureOpen(const Key: Integer; const OpenByDefault: Boolean): Boolean;
begin
  const IsToggled = FToggledDisclosures.Contains(Key);
  Result := OpenByDefault xor IsToggled;
end;

function TMarkdownViewerModel.TryFindScrollerAt(const Point: TLayoutPointF; out Index: Integer): Boolean;
begin
  Index := -1;
  Result := False;
  if FDisplayList = nil then
    Exit;

  for var Candidate in FScrollers do
  begin
    if FDisplayList.Items[Candidate].Bounds.Contains(Point) then
    begin
      Index := Candidate;
      Result := True;
      Exit;
    end;
  end;
end;

// The scroller whose content the item at ItemIndex is, if any.
function TMarkdownViewerModel.TryFindScrollerOf(const ItemIndex: Integer; out Index: Integer): Boolean;
begin
  Index := -1;
  Result := False;
  if FDisplayList = nil then
    Exit;

  for var Candidate in FScrollers do
  begin
    const Count = (FDisplayList.Items[Candidate] as IDisplayScroller).ItemCount;
    if (ItemIndex > Candidate) and (ItemIndex <= Candidate + Count) then
    begin
      Index := Candidate;
      Result := True;
      Exit;
    end;
  end;
end;

procedure TMarkdownViewerModel.SetScrollerOffset(const Index: Integer; const Offset: Single);
begin
  const OldOffset = (FDisplayList.Items[Index] as IDisplayScroller).Offset;
  FDisplayList.SetScrollerOffset(Index, Offset);

  const Scroller = FDisplayList.Items[Index] as IDisplayScroller;
  const IsMoved = (Scroller.Offset <> OldOffset);
  if not IsMoved then
    Exit;

  FScrollerOffsets.AddOrSetValue(Scroller.Key, Scroller.Offset);
  RefreshHighlights;
end;

// A new layout draws every scroller unscrolled; each takes back the offset
// the reader left it at.
procedure TMarkdownViewerModel.RestoreScrollerOffsets;
begin
  FScrollers := [];
  for var Index := 0 to FDisplayList.ItemCount - 1 do
  begin
    if FDisplayList.Items[Index].Kind = TDisplayItemKind.Scroller then
      FScrollers := FScrollers + [Index];
  end;

  for var Index in FScrollers do
  begin
    const Scroller = FDisplayList.Items[Index] as IDisplayScroller;

    var Offset: Single;
    if FScrollerOffsets.TryGetValue(Scroller.Key, Offset) then
      SetScrollerOffset(Index, Offset);
  end;
end;

// A match that find selects in a part of a formula out of view scrolls that
// part into view.
procedure TMarkdownViewerModel.RevealInScroller(const ItemIndex: Integer);
begin
  var Index: Integer;
  if not TryFindScrollerOf(ItemIndex, Index) then
    Exit;

  const Bounds = FDisplayList.Items[Index].Bounds;
  const Target = FDisplayList.Items[ItemIndex].Bounds;
  const Scroller = FDisplayList.Items[Index] as IDisplayScroller;
  if Target.Left < Bounds.Left then
    SetScrollerOffset(Index, Scroller.Offset - (Bounds.Left - Target.Left) - Bounds.Width / 4)
  else if Target.Right > Bounds.Right then
    SetScrollerOffset(Index, Scroller.Offset + (Target.Right - Bounds.Right) + Bounds.Width / 4);
end;

function TMarkdownViewerModel.ClipToScroller(const ItemIndex: Integer; const Rect: TLayoutRectF): TLayoutRectF;
begin
  Result := Rect;

  var Index: Integer;
  if not TryFindScrollerOf(ItemIndex, Index) then
    Exit;

  const Bounds = FDisplayList.Items[Index].Bounds;
  Result.Left := Max(Rect.Left, Bounds.Left);
  Result.Right := Min(Rect.Right, Bounds.Right);
end;

function TMarkdownViewerModel.ScrollSideways(const Point: TLayoutPointF; const Delta: Single): Boolean;
begin
  var Index: Integer;
  Result := TryFindScrollerAt(Point, Index);
  if Result then
    SetScrollerOffset(Index, (FDisplayList.Items[Index] as IDisplayScroller).Offset + Delta);
end;

function TMarkdownViewerModel.IsOverScrollerTrack(const Point: TLayoutPointF): Boolean;
begin
  var Index: Integer;
  Result := TryFindScrollerAt(Point, Index) and (FDisplayList.Items[Index] as IDisplayScroller).Track.Contains(Point);
end;

// A press on the thumb grabs it where it was pressed; a press elsewhere on
// the track first brings the thumb under the pointer.
function TMarkdownViewerModel.TryBeginScrollerDrag(const Point: TLayoutPointF): Boolean;
begin
  Result := IsOverScrollerTrack(Point);
  if not Result then
    Exit;

  TryFindScrollerAt(Point, FDraggedScroller);
  const Thumb = (FDisplayList.Items[FDraggedScroller] as IDisplayScroller).Thumb;
  if not Thumb.Contains(Point) then
  begin
    FThumbGrab := Thumb.Width / 2;
    DragScrollerThumb(Point);
    Exit;
  end;

  FThumbGrab := Point.X - Thumb.Left;
end;

procedure TMarkdownViewerModel.DragScrollerThumb(const Point: TLayoutPointF);
begin
  if not IsDraggingScroller then
    Exit;

  const Scroller = FDisplayList.Items[FDraggedScroller] as IDisplayScroller;
  const Track = Scroller.Track;
  const Travel = Track.Width - Scroller.Thumb.Width;
  if Travel <= 0 then
    Exit;

  const ThumbLeft = Point.X - FThumbGrab - Track.Left;
  SetScrollerOffset(FDraggedScroller, ThumbLeft / Travel * Scroller.MaxOffset);
end;

procedure TMarkdownViewerModel.EndScrollerDrag;
begin
  FDraggedScroller := -1;
end;

function TMarkdownViewerModel.IsDraggingScroller: Boolean;
begin
  Result := (FDraggedScroller >= 0) and (FDisplayList <> nil) and (FDraggedScroller < FDisplayList.ItemCount);
end;

function TMarkdownViewerModel.CodeBlockRegions: TArray<TMarkdownCodeBlockRegion>;
begin
  Result := [];
  if FDisplayList = nil then
    Exit;

  for var Index := 0 to FDisplayList.ItemCount - 1 do
  begin
    const Item = FDisplayList.Items[Index];
    if Item.Kind <> TDisplayItemKind.Rectangle then
      Continue;

    var Code: IMarkdownCodeBlock;
    if (Item.Node = nil) or not Supports(Item.Node, IMarkdownCodeBlock, Code) then
      Continue;

    // Skip code blocks that a layout override (chart, mermaid, ...) renders as
    // graphics: their rectangles are the drawing, not copyable source, so the
    // hover copy button must not appear over them.
    var Handler: ILayoutBlockOverride;
    if TLayoutBlockOverrideRegistry.TryFind(Item.Node, Handler) then
      Continue;

    Result := Result + [TMarkdownCodeBlockRegion.Create(Item.Bounds, CodeTextOf(Code))];
  end;
end;

class function TMarkdownViewerModel.CodeTextOf(const Code: IMarkdownCodeBlock): string;
begin
  Result := Code.Literal;
  if Result.EndsWith(LineFeed) then
    SetLength(Result, Length(Result) - 1);
end;

procedure TMarkdownViewerModel.Relayout;
begin
  if FViewportWidth <= 0 then
    Exit;

  var Selection: TSelectionAnchors;
  const CanKeepSelection = TryCaptureSelection(Selection);
  const Watch = TStopwatch.StartNew;
  const Document = TMarkdown.Parse(FText, TMarkdownDialect.Gfm);
  TLayoutDocumentProcessorRegistry.Process(Document, Self);
  FDocument := Document;
  RefreshZoomedTheme;

  FDisplayList := TMarkdownLayoutEngine.LayoutDocument(Document, FViewportWidth, LayoutTheme, FMeasurer, Self,
                                                       Self, Self);
  FLastLayoutMilliseconds := Watch.ElapsedMilliseconds;
  Inc(FLayoutCount);
  FDraggedScroller := -1;
  RestoreScrollerOffsets;

  // A selection whose text the new layout no longer has is dropped, rather
  // than drawn over whatever text now sits at its old place.
  const IsSelectionKept = CanKeepSelection and TryRestoreSelection(Selection);
  if not IsSelectionKept then
    ClearSelection;

  RegisterImageSlots;
  RefreshHighlights;
end;

function TMarkdownViewerModel.TryCaptureSelection(out Selection: TSelectionAnchors): Boolean;
begin
  Selection := Default(TSelectionAnchors);
  Result := False;
  if not HasCaret then
    Exit;

  const Anchors = TMarkdownTextAnchors.Create(FDisplayList);
  try
    if not Anchors.TryAnchorOf(FAnchor, Selection.Anchor) then
      Exit;
    if not Anchors.TryAnchorOf(FExtent, Selection.Extent) then
      Exit;

    const HasUnitRange = (FSelectionUnit <> TSelectionUnit.Character);
    if HasUnitRange then
    begin
      if not Anchors.TryAnchorOf(FUnitRange.StartPosition, Selection.UnitStart) then
        Exit;
      if not Anchors.TryAnchorOf(FUnitRange.EndPosition, Selection.UnitEnd) then
        Exit;
    end;

    Result := True;
  finally
    Anchors.Free;
  end;
end;

function TMarkdownViewerModel.TryRestoreSelection(const Selection: TSelectionAnchors): Boolean;
begin
  Result := False;

  const Anchors = TMarkdownTextAnchors.Create(FDisplayList);
  try
    if not Anchors.TryPositionOf(Selection.Anchor, FAnchor) then
      Exit;
    if not Anchors.TryPositionOf(Selection.Extent, FExtent) then
      Exit;

    const HasUnitRange = (FSelectionUnit <> TSelectionUnit.Character);
    if HasUnitRange then
    begin
      if not Anchors.TryPositionOf(Selection.UnitStart, FUnitRange.StartPosition) then
        Exit;
      if not Anchors.TryPositionOf(Selection.UnitEnd, FUnitRange.EndPosition) then
        Exit;
    end;

    Result := True;
  finally
    Anchors.Free;
  end;
end;

procedure TMarkdownViewerModel.RegisterImageSlots;
begin
  for var Index := 0 to FDisplayList.ItemCount - 1 do
  begin
    var Image: IDisplayImage;
    if not Supports(FDisplayList.Items[Index], IDisplayImage, Image) then
      Continue;

    if FImageSlots.ContainsKey(Image.Source) then
      Continue;

    var Slot := Default(TImageSlot);
    Slot.State := TMarkdownImageSlotState.Requested;
    FImageSlots.Add(Image.Source, Slot);
    FImageSlotOrder.Add(Image.Source);
  end;
end;

// The pointer lands on the glyphs of a formula, never on its source run, which
// stands for the whole formula only where find selects it.
function TMarkdownViewerModel.TryResolvePosition(const Point: TLayoutPointF; out Position: TTextPosition): Boolean;
begin
  Position := Default(TTextPosition);
  if FDisplayList = nil then
  begin
    Result := False;
    Exit;
  end;

  var BestIndex := -1;
  var BestRun: IDisplayTextRun := nil;
  var BestVertical := MaxSingle;
  var BestHorizontal := MaxSingle;

  for var Index := 0 to FDisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const IsPointable = (TrySelectableRun(Index, Run) and (Run.Role <> TDisplayTextRunRole.Source));
    if not IsPointable then
      Continue;

    const Bounds = Run.Bounds;
    var Vertical := 0.0;
    if Point.Y < Bounds.Top then
      Vertical := Bounds.Top - Point.Y
    else if Point.Y >= Bounds.Bottom then
      Vertical := Point.Y - Bounds.Bottom;

    var Horizontal := 0.0;
    if Point.X < Bounds.Left then
      Horizontal := Bounds.Left - Point.X
    else if Point.X > Bounds.Right then
      Horizontal := Point.X - Bounds.Right;

    const VerticalComparison = CompareValue(Vertical, BestVertical, LineTopEpsilon);
    const IsCloser = (VerticalComparison < 0) or ((VerticalComparison = 0) and (Horizontal < BestHorizontal));
    if IsCloser then
    begin
      BestIndex := Index;
      BestRun := Run;
      BestVertical := Vertical;
      BestHorizontal := Horizontal;
    end;
  end;

  if BestIndex < 0 then
  begin
    Result := False;
    Exit;
  end;

  Position.ItemIndex := BestIndex;
  Position.CharacterIndex := NearestCharacterBoundary(BestRun, Point.X);

  const IsGlyph = (BestRun.Role = TDisplayTextRunRole.Formula);
  if IsGlyph then
    SnapToFormulaEdge(Point, Position);
  Result := True;
end;

// The character the pointer is on, rather than the boundary nearest to it: a
// double click picks the word that character belongs to.
function TMarkdownViewerModel.TryResolveCharacter(const Point: TLayoutPointF; out Position: TTextPosition): Boolean;
begin
  Result := TryResolvePosition(Point, Position);
  if not Result then
    Exit;

  var Run: IDisplayTextRun;
  TrySelectableRun(Position.ItemIndex, Run);
  Result := (Run.Text <> '');
  if Result then
    Position.CharacterIndex := CharacterUnderX(Run, Point.X);
end;

function TMarkdownViewerModel.CharacterUnderX(const Run: IDisplayTextRun; const X: Single): Integer;
begin
  const LocalX = X - Run.Bounds.Left;

  Result := 0;
  for var Count := 1 to Length(Run.Text) - 1 do
  begin
    const IsPastCharacter = (PrefixWidth(Run, Count) <= LocalX);
    if not IsPastCharacter then
      Exit;

    Result := Count;
  end;
end;

function TMarkdownViewerModel.TrySelectableRun(const Index: Integer; out Run: IDisplayTextRun): Boolean;
begin
  Result := TMarkdownTextAnchors.TrySelectableRun(FDisplayList, Index, Run);
end;

// A source run, and a letter of the mathematical alphabets, is selected whole
// or not at all: the pointer picks the edge nearest to it, never a character
// inside.
function TMarkdownViewerModel.NearestCharacterBoundary(const Run: IDisplayTextRun; const X: Single): Integer;
begin
  const LocalX = X - Run.Bounds.Left;

  const IsAtomic = IsAtomicRun(Run);
  if IsAtomic then
  begin
    const PastMiddle = (LocalX > Run.Bounds.Width / 2);
    if PastMiddle then
    begin
      Result := Length(Run.Text);
      Exit;
    end;

    Result := 0;
    Exit;
  end;

  Result := 0;
  var BestDistance := Abs(LocalX);

  for var Count := 1 to Length(Run.Text) do
  begin
    const Distance = Abs(LocalX - PrefixWidth(Run, Count));
    if Distance < BestDistance then
    begin
      BestDistance := Distance;
      Result := Count;
    end;
  end;
end;

function TMarkdownViewerModel.NormalizeSelection: TTextRange;
begin
  if ComparePositions(FAnchor, FExtent) <= 0 then
  begin
    Result.StartPosition := FAnchor;
    Result.EndPosition := FExtent;
    Exit;
  end;

  Result.StartPosition := FExtent;
  Result.EndPosition := FAnchor;
end;

class function TMarkdownViewerModel.ComparePositions(const Left, Right: TTextPosition): Integer;
begin
  Result := CompareValue(Left.ItemIndex, Right.ItemIndex);
  if Result = 0 then
    Result := CompareValue(Left.CharacterIndex, Right.CharacterIndex);
end;

function TMarkdownViewerModel.SelectedCharacterRange(const Run: IDisplayTextRun; const ItemIndex: Integer;
  const StartPosition, EndPosition: TTextPosition; out CharFrom, CharTo: Integer): Boolean;
begin
  CharFrom := 0;
  CharTo := Length(Run.Text);

  if ItemIndex = StartPosition.ItemIndex then
    CharFrom := StartPosition.CharacterIndex;
  if ItemIndex = EndPosition.ItemIndex then
    CharTo := EndPosition.CharacterIndex;

  Result := CharTo > CharFrom;
end;

function TMarkdownViewerModel.BlockIndexOfItem(const ItemIndex: Integer): Integer;
begin
  for var BlockIndex := 0 to FDisplayList.BlockCount - 1 do
  begin
    const Info = FDisplayList.BlockInfos[BlockIndex];
    const IsInsideBlock = (ItemIndex >= Info.FirstItemIndex) and (ItemIndex < Info.FirstItemIndex + Info.ItemCount);
    if IsInsideBlock then
    begin
      Result := BlockIndex;
      Exit;
    end;
  end;

  Result := -1;
end;

function TMarkdownViewerModel.PrefixWidth(const Run: IDisplayTextRun; const CharacterCount: Integer): Single;
begin
  if CharacterCount <= 0 then
  begin
    Result := 0;
    Exit;
  end;

  // The source of a drawing is as wide as the drawing, whatever its text
  // measures, and a letter of the mathematical alphabets as wide as its glyph.
  const IsAtomic = IsAtomicRun(Run);
  if IsAtomic then
  begin
    Result := Run.Bounds.Width;
    Exit;
  end;

  Result := FMeasurer.MeasureText(Copy(Run.Text, 1, CharacterCount), Run.Font).Width;
end;

function TMarkdownViewerModel.GetText: string;
begin
  Result := FText;
end;

procedure TMarkdownViewerModel.SetText(const Value: string);
begin
  FText := Value;
  FPendingMarkdown := '';
  FDirty := False;
  FToggledDisclosures.Clear;
  ClearSelection;
  Relayout;
end;

function TMarkdownViewerModel.GetPendingText: string;
begin
  Result := FPendingMarkdown;
end;

function TMarkdownViewerModel.GetFullText: string;
begin
  Result := FText + FPendingMarkdown;
end;

function TMarkdownViewerModel.GetDisplayList: IMarkdownDisplayList;
begin
  Result := FDisplayList;
end;

function TMarkdownViewerModel.GetLayoutCount: Integer;
begin
  Result := FLayoutCount;
end;

function TMarkdownViewerModel.GetIsDirty: Boolean;
begin
  Result := FDirty;
end;

function TMarkdownViewerModel.GetShouldAutoFollow: Boolean;
begin
  Result := FShouldAutoFollow;
end;

function TMarkdownViewerModel.GetFlushIntervalMilliseconds: Cardinal;
begin
  Result := FFlushIntervalMilliseconds;
end;

procedure TMarkdownViewerModel.SetFlushIntervalMilliseconds(const Value: Cardinal);
begin
  FFlushIntervalMilliseconds := Value;
end;

function TMarkdownViewerModel.GetScrollOffset: Single;
begin
  Result := FScrollOffset;
end;

procedure TMarkdownViewerModel.SetZoom(const Value: Integer);
begin
  const Percent = TMarkdownZoom.Clamp(Value);
  if Percent = FZoom then
    Exit;

  const PreviousFactor = ZoomFactor;
  var TopLine: TMarkdownTextAnchor;
  var Inset: Single;
  const HasTopLine = TryCaptureTopLine(TopLine, Inset);

  FZoom := Percent;
  RefreshLayout;

  if HasTopLine then
    ScrollToTopLine(TopLine, Inset * ZoomFactor / PreviousFactor);
end;

function TMarkdownViewerModel.ZoomFactor: Single;
begin
  Result := FZoom / TMarkdownZoom.DefaultPercent;
end;

function TMarkdownViewerModel.LayoutTheme: TMarkdownTheme;
begin
  Result := FTheme;
  if FZoomedTheme <> nil then
    Result := FZoomedTheme;
end;

// Scaled again before every layout, so a change the application made to its
// theme reaches the zoomed copy too.
procedure TMarkdownViewerModel.RefreshZoomedTheme;
begin
  FreeAndNil(FZoomedTheme);

  const IsZoomed = (FZoom <> TMarkdownZoom.DefaultPercent);
  if IsZoomed then
    FZoomedTheme := FTheme.Scaled(ZoomFactor);
end;

// The first line that still shows at the top of the view, and how far the
// view is scrolled past its top.
function TMarkdownViewerModel.TryCaptureTopLine(out TopLine: TMarkdownTextAnchor; out Inset: Single): Boolean;
begin
  TopLine := Default(TMarkdownTextAnchor);
  Inset := 0;
  Result := False;
  if FDisplayList = nil then
    Exit;

  const Anchors = TMarkdownTextAnchors.Create(FDisplayList);
  try
    for var Index := 0 to FDisplayList.ItemCount - 1 do
    begin
      var Run: IDisplayTextRun;
      if not TrySelectableRun(Index, Run) then
        Continue;

      const IsAboveView = (Run.Bounds.Bottom <= FScrollOffset);
      if IsAboveView then
        Continue;

      var Position: TTextPosition;
      Position.ItemIndex := Index;
      Position.CharacterIndex := 0;
      Inset := FScrollOffset - Run.Bounds.Top;
      Result := Anchors.TryAnchorOf(Position, TopLine);
      Exit;
    end;
  finally
    Anchors.Free;
  end;
end;

procedure TMarkdownViewerModel.ScrollToTopLine(const TopLine: TMarkdownTextAnchor; const Inset: Single);
begin
  const Anchors = TMarkdownTextAnchors.Create(FDisplayList);
  try
    var Position: TTextPosition;
    if not Anchors.TryPositionOf(TopLine, Position) then
      Exit;

    const Run = FDisplayList.Items[Position.ItemIndex];
    SetScrollOffset(Run.Bounds.Top + Inset);
  finally
    Anchors.Free;
  end;
end;

procedure TMarkdownViewerModel.SetScrollOffset(const Value: Single);
begin
  var Clamped: Single := Max(Single(0), Value);
  if FDisplayList <> nil then
  begin
    const MaxOffset = Max(Single(0), FDisplayList.Height - FViewportHeight);
    Clamped := Min(Clamped, MaxOffset);
  end;

  FScrollOffset := Clamped;
end;

end.
