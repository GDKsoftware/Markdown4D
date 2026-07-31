unit Markdown4D.Layout.Engine;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Theme;

type
  TLayoutBlockRange = record
    FirstBlockIndex: Integer;
    OldBlockCount: Integer;
    NewBlockCount: Integer;
    class function Create(const FirstBlockIndex, OldBlockCount, NewBlockCount: Integer): TLayoutBlockRange; static;
  end;

  TMarkdownLayoutEngine = class
  private
    class procedure ValidateLayoutArguments(const Document: IMarkdownDocument; const AvailableWidth: Single;
      const Theme: TMarkdownTheme; const Measurer: ITextMeasurer);
    class procedure ValidateChangedRange(const ChangedRange: TLayoutBlockRange; const PreviousBlockCount: Integer);

  public
    class function LayoutDocument(const Document: IMarkdownDocument; const AvailableWidth: Single;
      const Theme: TMarkdownTheme; const Measurer: ITextMeasurer;
      const ImageSizes: IMarkdownImageSizeProvider = nil): IMarkdownDisplayList;
    class function UpdateLayout(const Previous: IMarkdownDisplayList; const Document: IMarkdownDocument;
      const ChangedRange: TLayoutBlockRange; const Theme: TMarkdownTheme; const Measurer: ITextMeasurer;
      const ImageSizes: IMarkdownImageSizeProvider = nil): IMarkdownDisplayList;
    class procedure RegisterBlockOverride(const Handler: ILayoutBlockOverride; const Priority: Integer);
    class procedure ClearBlockOverrides;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  Markdown4D.Defines,
  Markdown4D.Parser.Inlines,
  Markdown4D.Highlighter.Interfaces,
  Markdown4D.Layout.ExtensionCanvas,
  Markdown4D.Layout.Primitives;

type
  TMarkdownFontStyleHelper = record helper for TMarkdownFontStyle
    function Equals(const Other: TMarkdownFontStyle): Boolean;
  end;

  TInlineAtomKind = (WordToken, SpaceToken, HardBreakToken, ImageToken);

  TInlineAtom = record
    Kind: TInlineAtomKind;
    Text: string;
    Font: TMarkdownFontStyle;
    Color: TLayoutColor;
    Node: IMarkdownNode;
    StartOffset: Integer;
    Width: Single;
    Height: Single;
    Source: string;
    AltText: string;
    CodeSpan: Boolean;
  end;

  TInlineStyle = record
    Font: TMarkdownFontStyle;
    Color: TLayoutColor;
    Attribution: IMarkdownNode;
  end;

  TInlineFrame = record
    Node: IMarkdownNode;
    ChildIndex: Integer;
    Style: TInlineStyle;
  end;

  TInlineWrapper = class
  private
    const
      FitEpsilon = 0.01;
      CodeSpanChipPadding = 3.0;
    var
      FMeasurer: ITextMeasurer;
      FItems: TList<IDisplayItem>;
      FLeft: Single;
      FStartTop: Single;
      FLineTop: Single;
      FAvailableWidth: Single;
      FBaseFont: TMarkdownFontStyle;
      FCodeSpanBackground: TLayoutColor;
      FCommitted: TList<TInlineAtom>;
      FPending: TList<TInlineAtom>;
      FLineWidth: Single;
      FPendingWidth: Single;
      FLineBaseline: Single;
      FCursor: Single;
      FGroupOpen: Boolean;
      FGroupText: string;
      FGroupWidth: Single;
      FGroupFont: TMarkdownFontStyle;
      FGroupColor: TLayoutColor;
      FGroupNode: IMarkdownNode;
      FGroupStartOffset: Integer;
      FGroupCodeSpan: Boolean;
    procedure AddWordLike(const Atom: TInlineAtom);
    procedure ForceBreakWord(const Atom: TInlineAtom);
    function MaxCharsFitting(const Text: string; const Font: TMarkdownFontStyle): Integer;
    procedure CommitPending;
    procedure CommitAtom(const Atom: TInlineAtom);
    procedure FlushLine;
    function LineAdvance: Single;
    function LineBaseline: Single;
    procedure EmitLineItems;
    procedure EmitLineAtom(const Atom: TInlineAtom);
    procedure OpenGroup(const Atom: TInlineAtom);
    procedure AppendToGroup(const Atom: TInlineAtom);
    procedure CloseGroup;
    procedure EmitCodeSpanChip(const RunBounds: TLayoutRectF);
    function SameRunStyle(const Atom: TInlineAtom): Boolean;
    procedure EmitImageItem(const Atom: TInlineAtom);

  public
    constructor Create(const Measurer: ITextMeasurer; const Items: TList<IDisplayItem>;
      const Left, Top, AvailableWidth: Single; const BaseFont: TMarkdownFontStyle;
      const CodeSpanBackground: TLayoutColor);
    destructor Destroy; override;
    procedure AddAtom(const Atom: TInlineAtom);
    function Finish: Single;
  end;

  TLayoutBlockContext = class(TInterfacedObject, ILayoutBlockContext)
  private
    FMeasurer: ITextMeasurer;
    FTheme: TMarkdownTheme;
    FWidth: Single;
    FItems: TList<IDisplayItem>;
    FNode: IMarkdownNode;
    FCanvas: IExtensionCanvas;
    function GetMeasurer: ITextMeasurer;
    function GetTheme: TMarkdownTheme;
    function GetWidth: Single;
    function GetCanvas: IExtensionCanvas;

  public
    constructor Create(const Measurer: ITextMeasurer; const Theme: TMarkdownTheme; const Width: Single;
      const Items: TList<IDisplayItem>; const Node: IMarkdownNode);
  end;

  TLayoutCommandKind = (Block, Gap, QuoteBar, ListItem);

  TLayoutCommand = record
    Kind: TLayoutCommandKind;
    Node: IMarkdownNode;
    X: Single;
    TextColor: TLayoutColor;
    GapAmount: Single;
    InsertIndex: Integer;
    StartY: Single;
    MarkerText: string;
    Tight: Boolean;
  end;

  TInlineAtomCollector = class
  private
    FMeasurer: ITextMeasurer;
    FTheme: TMarkdownTheme;
    FImageSizes: IMarkdownImageSizeProvider;
    FContentRight: Single;
    procedure HandleInlineChild(const Atoms: TList<TInlineAtom>; const Frames: TList<TInlineFrame>;
      const Child: IMarkdownNode; const Style: TInlineStyle);
    procedure AppendTextAtoms(const Atoms: TList<TInlineAtom>; const Text: string; const Style: TInlineStyle;
      const Leaf: IMarkdownNode);
    procedure AppendCodeSpanAtoms(const Atoms: TList<TInlineAtom>; const Child: IMarkdownNode;
      const Style: TInlineStyle);
    procedure AppendHardBreakAtom(const Atoms: TList<TInlineAtom>);
    procedure AppendImageAtom(const Atoms: TList<TInlineAtom>; const Child: IMarkdownNode;
      const Style: TInlineStyle);
    procedure HandleCustomInline(const Atoms: TList<TInlineAtom>; const Frames: TList<TInlineFrame>;
      const Child: IMarkdownNode; const Style: TInlineStyle);
    class procedure PushStyledFrame(const Frames: TList<TInlineFrame>; const Node: IMarkdownNode;
      const Style: TInlineStyle);
    class function CollectPlainText(const Node: IMarkdownNode): string;

  public
    constructor Create(const Measurer: ITextMeasurer; const Theme: TMarkdownTheme;
      const ImageSizes: IMarkdownImageSizeProvider; const ContentRight: Single);
    function Collect(const Container: IMarkdownNode; const BaseFont: TMarkdownFontStyle;
      const BaseColor: TLayoutColor): TList<TInlineAtom>;
  end;

  TTableLayout = class
  private
    const
      LineEpsilon = 0.01;
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FItems: TList<IDisplayItem>;
      FCollector: TInlineAtomCollector;
      FCurrentY: Single;
    function MeasureTableCells(const Command: TLayoutCommand; const ColumnCount: Integer;
      const Cells: TObjectList<TList<TInlineAtom>>): TArray<Single>;
    function ComputeColumnWidths(const NaturalWidths: TArray<Single>;
      const AvailableWidth: Single): TArray<Single>;
    procedure PlaceTableRows(const Command: TLayoutCommand; const ColumnCount: Integer;
      const Cells: TObjectList<TList<TInlineAtom>>; const ColumnWidths: TArray<Single>);
    procedure PlaceTableRow(const Command: TLayoutCommand; const RowIndex, ColumnCount: Integer;
      const Cells: TObjectList<TList<TInlineAtom>>; const ColumnWidths: TArray<Single>; const TableWidth: Single);
    function PlaceTableCell(const Row: IMarkdownNode; const ColumnIndex: Integer; const Atoms: TList<TInlineAtom>;
      const CellLeft, RowTop, ColumnWidth: Single; const RowFont: TMarkdownFontStyle): Single;
    procedure AlignCellItems(const FirstIndex, LastIndex: Integer; const Alignment: TMarkdownTableColumnAlignment;
      const ContentRightEdge: Single);
    function MaxRightOnLine(const FirstIndex, LastIndex: Integer; const Reference: TLayoutRectF): Single;
    function TableRowFont(const Row: IMarkdownNode): TMarkdownFontStyle;
    class function NaturalWidthOf(const Atoms: TList<TInlineAtom>): Single;

  public
    constructor Create(const Theme: TMarkdownTheme; const Measurer: ITextMeasurer;
      const Items: TList<IDisplayItem>; const Collector: TInlineAtomCollector);
    function Layout(const Command: TLayoutCommand; const StartY, AvailableWidth: Single): Single;
  end;

  TLayoutWorker = class
  private
    const
      BulletMarkerText = #$2022;
      OrderedMarkerFormat = '%d.';
      ShiftEpsilon = 0.0001;
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FWidth: Single;
      FItems: TList<IDisplayItem>;
      FImageSizes: IMarkdownImageSizeProvider;
      FCommands: TList<TLayoutCommand>;
      FCollector: TInlineAtomCollector;
      FCurrentY: Single;
    procedure ProcessCommand(const Command: TLayoutCommand);
    procedure ProcessBlock(const Command: TLayoutCommand);
    procedure ApplyBlockOverride(const Command: TLayoutCommand; const Handler: ILayoutBlockOverride);
    procedure ProcessListItem(const Command: TLayoutCommand);
    procedure EmitListMarker(const Command: TLayoutCommand);
    procedure EmitTaskCheckbox(const Command: TLayoutCommand; const Marker: IMarkdownCustomInline);
    procedure PushBlockQuote(const Command: TLayoutCommand);
    procedure EmitQuoteBar(const Command: TLayoutCommand);
    procedure PushList(const Command: TLayoutCommand);
    class function TryFindTaskMarker(const ListItem: IMarkdownNode; out Marker: IMarkdownCustomInline): Boolean;
    procedure PushContainerChildren(const Container: IMarkdownNode; const X: Single; const TextColor: TLayoutColor);
    procedure PushBlock(const Node: IMarkdownNode; const X: Single; const TextColor: TLayoutColor);
    procedure PushGap(const Amount: Single);
    procedure LayoutInlineBlock(const Container: IMarkdownNode; const X: Single; const BaseFont: TMarkdownFontStyle;
      const TextColor: TLayoutColor);
    procedure EmitCodeBlock(const Command: TLayoutCommand);
    procedure EmitCodeLines(const Command: TLayoutCommand; const Code: IMarkdownCodeBlock; const Lines: TArray<string>;
      const LineHeight, Padding: Single);
    function EmitHighlightedCodeLine(const Command: TLayoutCommand; const Highlighter: IMarkdownSyntaxHighlighter;
      const LineText: string; const Top, LineHeight: Single; const LineStart, State: Integer): Integer;
    procedure EmitPlainCodeLine(const Command: TLayoutCommand; const LineText: string; const Top, LineHeight: Single;
      const LineStart: Integer);
    class function CodeLanguageOf(const Code: IMarkdownCodeBlock): string;
    procedure EmitHtmlBlock(const Command: TLayoutCommand);
    procedure EmitThematicBreak(const Command: TLayoutCommand);
    procedure LayoutTable(const Command: TLayoutCommand);
    function CollectInlineAtoms(const Container: IMarkdownNode; const BaseFont: TMarkdownFontStyle;
      const BaseColor: TLayoutColor): TList<TInlineAtom>;
    class function SplitCodeLines(const Literal: string): TArray<string>;
    class function ShiftedItem(const Item: IDisplayItem; const DeltaX, DeltaY: Single): IDisplayItem;
    function ContentRight: Single;

  public
    constructor Create(const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Width: Single;
      const Items: TList<IDisplayItem>; const ImageSizes: IMarkdownImageSizeProvider);
    destructor Destroy; override;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single): Single;
    function RecomputeBlock(const Node: IMarkdownNode; const Index: Integer; var Y: Single;
      const PreviousBelow: Single): TLayoutBlockInfo;
    function ReusePreviousBlock(const Previous: IMarkdownDisplayList; const ChangedRange: TLayoutBlockRange;
      const Index: Integer; var Y: Single; const PreviousBelow: Single): TLayoutBlockInfo;
    function SpacingAboveOf(const Node: IMarkdownNode): Single;
    function SpacingBelowOf(const Node: IMarkdownNode): Single;
    procedure AppendPreviousBlock(const Previous: IMarkdownDisplayList; const Info: TLayoutBlockInfo;
      const DeltaY: Single);
    function ContentWidth: Single;
  end;

class function TLayoutBlockRange.Create(const FirstBlockIndex, OldBlockCount, NewBlockCount: Integer): TLayoutBlockRange;
begin
  Result.FirstBlockIndex := FirstBlockIndex;
  Result.OldBlockCount := OldBlockCount;
  Result.NewBlockCount := NewBlockCount;
end;

class function TMarkdownLayoutEngine.LayoutDocument(const Document: IMarkdownDocument; const AvailableWidth: Single;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer;
  const ImageSizes: IMarkdownImageSizeProvider): IMarkdownDisplayList;
begin
  ValidateLayoutArguments(Document, AvailableWidth, Theme, Measurer);

  const Items = TList<IDisplayItem>.Create;
  try
    const Worker = TLayoutWorker.Create(Theme, Measurer, AvailableWidth, Items, ImageSizes);
    try
      const BlockCount = Document.ChildCount;
      var Blocks: TArray<TLayoutBlockInfo>;
      SetLength(Blocks, BlockCount);

      var Recomputed: TArray<Integer>;
      SetLength(Recomputed, BlockCount);

      var Y := Theme.ContentPadding;
      var PreviousBelow := 0.0;

      for var Index := 0 to BlockCount - 1 do
      begin
        const Node = Document.Children[Index];
        const Above = Worker.SpacingAboveOf(Node);
        const Below = Worker.SpacingBelowOf(Node);

        if Index > 0 then
          Y := Y + PreviousBelow + Above;

        const FirstItemIndex = Items.Count;
        const Height = Worker.LayoutBlock(Node, Y);

        Blocks[Index] := TLayoutBlockInfo.Create(FirstItemIndex, Items.Count - FirstItemIndex, Y, Height, Above, Below);
        Recomputed[Index] := Index;
        Y := Y + Height;
        PreviousBelow := Below;
      end;

      Y := Y + Theme.ContentPadding;

      Result := TMarkdownDisplayList.Create(Items.ToArray, Blocks, AvailableWidth, Worker.ContentWidth, Y, Recomputed);
    finally
      Worker.Free;
    end;
  finally
    Items.Free;
  end;
end;

class function TMarkdownLayoutEngine.UpdateLayout(const Previous: IMarkdownDisplayList;
  const Document: IMarkdownDocument; const ChangedRange: TLayoutBlockRange; const Theme: TMarkdownTheme;
  const Measurer: ITextMeasurer; const ImageSizes: IMarkdownImageSizeProvider): IMarkdownDisplayList;
begin
  if Previous = nil then
    raise EMarkdownError.Create('Previous display list is required for incremental layout');

  ValidateLayoutArguments(Document, Previous.Width, Theme, Measurer);

  ValidateChangedRange(ChangedRange, Previous.BlockCount);

  const TotalBlockCount = Previous.BlockCount - ChangedRange.OldBlockCount + ChangedRange.NewBlockCount;
  const MatchesDocument = (TotalBlockCount = Document.ChildCount);
  if not MatchesDocument then
    raise EMarkdownError.CreateFmt('Document has %d blocks but the changed range expects %d',
      [Document.ChildCount, TotalBlockCount]);

  const Items = TList<IDisplayItem>.Create;
  try
    const Worker = TLayoutWorker.Create(Theme, Measurer, Previous.Width, Items, ImageSizes);
    try
      var Blocks: TArray<TLayoutBlockInfo>;
      SetLength(Blocks, TotalBlockCount);

      var Recomputed: TArray<Integer>;
      SetLength(Recomputed, ChangedRange.NewBlockCount);

      var Y: Single := Theme.ContentPadding;
      var PreviousBelow: Single := 0.0;

      for var Index := 0 to TotalBlockCount - 1 do
      begin
        const IsRecomputed = (Index >= ChangedRange.FirstBlockIndex) and
          (Index < ChangedRange.FirstBlockIndex + ChangedRange.NewBlockCount);

        var Info := Default(TLayoutBlockInfo);
        if IsRecomputed then
        begin
          Info := Worker.RecomputeBlock(Document.Children[Index], Index, Y, PreviousBelow);
          Recomputed[Index - ChangedRange.FirstBlockIndex] := Index;
        end
        else
          Info := Worker.ReusePreviousBlock(Previous, ChangedRange, Index, Y, PreviousBelow);

        Blocks[Index] := Info;
        Y := Y + Info.Height;
        PreviousBelow := Info.SpacingBelow;
      end;

      Y := Y + Theme.ContentPadding;

      Result := TMarkdownDisplayList.Create(Items.ToArray, Blocks, Previous.Width, Worker.ContentWidth, Y, Recomputed);
    finally
      Worker.Free;
    end;
  finally
    Items.Free;
  end;
end;

class procedure TMarkdownLayoutEngine.RegisterBlockOverride(const Handler: ILayoutBlockOverride;
  const Priority: Integer);
begin
  TLayoutBlockOverrideRegistry.Register(Handler, Priority);
end;

class procedure TMarkdownLayoutEngine.ClearBlockOverrides;
begin
  TLayoutBlockOverrideRegistry.Clear;
  TLayoutDocumentProcessorRegistry.Clear;
end;

class procedure TMarkdownLayoutEngine.ValidateLayoutArguments(const Document: IMarkdownDocument;
  const AvailableWidth: Single; const Theme: TMarkdownTheme; const Measurer: ITextMeasurer);
begin
  if Document = nil then
    raise EMarkdownError.Create('Document is required for layout');

  if Theme = nil then
    raise EMarkdownError.Create('Theme is required for layout');

  if Measurer = nil then
    raise EMarkdownError.Create('Text measurer is required for layout');

  const HasUsableWidth = (not IsNan(AvailableWidth)) and (not IsInfinite(AvailableWidth)) and (AvailableWidth >= 0);
  if not HasUsableWidth then
    raise EMarkdownError.CreateFmt('Available width %g must be a finite non-negative value', [AvailableWidth]);
end;

class procedure TMarkdownLayoutEngine.ValidateChangedRange(const ChangedRange: TLayoutBlockRange;
  const PreviousBlockCount: Integer);
begin
  const IsValidRange = (ChangedRange.FirstBlockIndex >= 0) and (ChangedRange.OldBlockCount >= 0) and
    (ChangedRange.NewBlockCount >= 0) and
    (ChangedRange.FirstBlockIndex + ChangedRange.OldBlockCount <= PreviousBlockCount);
  if not IsValidRange then
    raise EMarkdownError.CreateFmt('Changed range (first %d, old %d, new %d) is invalid for %d previous blocks',
      [ChangedRange.FirstBlockIndex, ChangedRange.OldBlockCount, ChangedRange.NewBlockCount, PreviousBlockCount]);
end;

constructor TLayoutWorker.Create(const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Width: Single;
  const Items: TList<IDisplayItem>; const ImageSizes: IMarkdownImageSizeProvider);
begin
  inherited Create;

  FTheme := Theme;
  FMeasurer := Measurer;
  FWidth := Width;
  FItems := Items;
  FImageSizes := ImageSizes;
  FCommands := TList<TLayoutCommand>.Create;
  FCollector := TInlineAtomCollector.Create(FMeasurer, FTheme, FImageSizes, ContentRight);
end;

destructor TLayoutWorker.Destroy;
begin
  FCollector.Free;
  FCommands.Free;

  inherited Destroy;
end;

function TLayoutWorker.LayoutBlock(const Node: IMarkdownNode; const Top: Single): Single;
begin
  FCurrentY := Top;

  PushBlock(Node, FTheme.ContentPadding, FTheme.TextColor);

  while FCommands.Count > 0 do
  begin
    const LastIndex = FCommands.Count - 1;
    const Command = FCommands[LastIndex];
    FCommands.Delete(LastIndex);

    ProcessCommand(Command);
  end;

  Result := FCurrentY - Top;
end;

function TLayoutWorker.RecomputeBlock(const Node: IMarkdownNode; const Index: Integer; var Y: Single;
  const PreviousBelow: Single): TLayoutBlockInfo;
begin
  const Above = SpacingAboveOf(Node);

  if Index > 0 then
    Y := Y + PreviousBelow + Above;

  const FirstItemIndex = FItems.Count;
  const Height = LayoutBlock(Node, Y);

  Result := TLayoutBlockInfo.Create(FirstItemIndex, FItems.Count - FirstItemIndex, Y, Height, Above,
    SpacingBelowOf(Node));
end;

function TLayoutWorker.ReusePreviousBlock(const Previous: IMarkdownDisplayList; const ChangedRange: TLayoutBlockRange;
  const Index: Integer; var Y: Single; const PreviousBelow: Single): TLayoutBlockInfo;
begin
  var OldIndex := Index;
  const IsAfterRange = (Index >= ChangedRange.FirstBlockIndex + ChangedRange.NewBlockCount);
  if IsAfterRange then
    OldIndex := Index - ChangedRange.NewBlockCount + ChangedRange.OldBlockCount;

  Result := Previous.BlockInfos[OldIndex];

  if Index > 0 then
    Y := Y + PreviousBelow + Result.SpacingAbove;

  const FirstItemIndex = FItems.Count;
  AppendPreviousBlock(Previous, Result, Y - Result.Top);
  Result.FirstItemIndex := FirstItemIndex;
  Result.Top := Y;
end;

function TLayoutWorker.SpacingAboveOf(const Node: IMarkdownNode): Single;
begin
  const IsHeading = (Node.Kind = TMarkdownNodeKind.Heading);
  if IsHeading then
    Result := FTheme.HeadingSpacingAbove[(Node as IMarkdownHeading).Level]
  else
    Result := 0;
end;

function TLayoutWorker.SpacingBelowOf(const Node: IMarkdownNode): Single;
begin
  const IsHeading = (Node.Kind = TMarkdownNodeKind.Heading);
  if IsHeading then
    Result := FTheme.HeadingSpacingBelow[(Node as IMarkdownHeading).Level]
  else
    Result := FTheme.ParagraphSpacing;
end;

procedure TLayoutWorker.AppendPreviousBlock(const Previous: IMarkdownDisplayList; const Info: TLayoutBlockInfo;
  const DeltaY: Single);
begin
  const NeedsShift = (Abs(DeltaY) > ShiftEpsilon);

  for var Index := Info.FirstItemIndex to Info.FirstItemIndex + Info.ItemCount - 1 do
  begin
    const Item = Previous.Items[Index];
    if NeedsShift then
      FItems.Add(ShiftedItem(Item, 0, DeltaY))
    else
      FItems.Add(Item);
  end;
end;

function TLayoutWorker.ContentWidth: Single;
begin
  Result := 0;

  for var Item in FItems do
  begin
    Result := Max(Result, Item.Bounds.Right);
  end;
end;

function TLayoutWorker.ContentRight: Single;
begin
  Result := FWidth - FTheme.ContentPadding;
end;

procedure TLayoutWorker.ProcessCommand(const Command: TLayoutCommand);
begin
  case Command.Kind of
    TLayoutCommandKind.Block:
      ProcessBlock(Command);
    TLayoutCommandKind.Gap:
      FCurrentY := FCurrentY + Command.GapAmount;
    TLayoutCommandKind.QuoteBar:
      EmitQuoteBar(Command);
    TLayoutCommandKind.ListItem:
      ProcessListItem(Command);
  else
    raise EMarkdownError.CreateFmt('Unhandled layout command kind: %d', [Ord(Command.Kind)]);
  end;
end;

procedure TLayoutWorker.ProcessBlock(const Command: TLayoutCommand);
begin
  var Handler: ILayoutBlockOverride;
  if TLayoutBlockOverrideRegistry.TryFind(Command.Node, Handler) then
  begin
    ApplyBlockOverride(Command, Handler);
    Exit;
  end;

  case Command.Node.Kind of
    TMarkdownNodeKind.Paragraph:
      LayoutInlineBlock(Command.Node, Command.X, FTheme.BaseFont, Command.TextColor);
    TMarkdownNodeKind.Heading:
      LayoutInlineBlock(Command.Node, Command.X, FTheme.HeadingFonts[(Command.Node as IMarkdownHeading).Level],
        Command.TextColor);
    TMarkdownNodeKind.CodeBlock:
      EmitCodeBlock(Command);
    TMarkdownNodeKind.HtmlBlock:
      EmitHtmlBlock(Command);
    TMarkdownNodeKind.ThematicBreak:
      EmitThematicBreak(Command);
    TMarkdownNodeKind.BlockQuote:
      PushBlockQuote(Command);
    TMarkdownNodeKind.List:
      PushList(Command);
    TMarkdownNodeKind.Table:
      LayoutTable(Command);
  else
  end;
end;

procedure TLayoutWorker.ApplyBlockOverride(const Command: TLayoutCommand; const Handler: ILayoutBlockOverride);
begin
  const AvailableWidth = ContentRight - Command.X;
  var Context: ILayoutBlockContext := TLayoutBlockContext.Create(FMeasurer, FTheme, AvailableWidth, FItems, Command.Node);

  const Height = Handler.LayoutBlock(Command.Node, FCurrentY, Context);

  FCurrentY := FCurrentY + Height;
end;

procedure TLayoutWorker.ProcessListItem(const Command: TLayoutCommand);
begin
  var TaskMarker: IMarkdownCustomInline;
  if TryFindTaskMarker(Command.Node, TaskMarker) then
    EmitTaskCheckbox(Command, TaskMarker)
  else
    EmitListMarker(Command);

  const HasContent = (Command.Node.ChildCount > 0);
  if not HasContent then
  begin
    FCurrentY := FCurrentY + FMeasurer.LineHeight(FTheme.BaseFont);
    Exit;
  end;

  const ContentX = Command.X + FTheme.ListMarkerWidth;

  for var Index := Command.Node.ChildCount - 1 downto 0 do
  begin
    const Child = Command.Node.Children[Index];

    var ChildX := ContentX;
    const IsNestedList = (Child.Kind = TMarkdownNodeKind.List);
    if IsNestedList then
      ChildX := Command.X + FTheme.ListIndent;

    PushBlock(Child, ChildX, Command.TextColor);

    const NeedsGap = (Index > 0) and not Command.Tight;
    if NeedsGap then
      PushGap(SpacingBelowOf(Command.Node.Children[Index - 1]) + SpacingAboveOf(Child));
  end;
end;

procedure TLayoutWorker.EmitListMarker(const Command: TLayoutCommand);
begin
  const MarkerSize = FMeasurer.MeasureText(Command.MarkerText, FTheme.BaseFont);
  const MarkerHeight = FMeasurer.LineHeight(FTheme.BaseFont);
  const Bounds = TLayoutRectF.Create(Command.X, FCurrentY, Command.X + MarkerSize.Width, FCurrentY + MarkerHeight);

  FItems.Add(TDisplayTextRun.Create(Bounds, Command.Node, Command.MarkerText, FTheme.BaseFont, Command.TextColor,
    FMeasurer.Baseline(FTheme.BaseFont), 0));
end;

procedure TLayoutWorker.EmitTaskCheckbox(const Command: TLayoutCommand; const Marker: IMarkdownCustomInline);
begin
  // The checkbox takes the marker column a bullet would have occupied; the gap
  // before the text falls out of ListMarkerWidth already being wider than
  // CheckboxSize, so no separate spacing setting is needed.
  const Checked = (Marker.NodeName = TGfmInlineParser.TaskCheckedNodeName);
  const LineHeight = FMeasurer.LineHeight(FTheme.BaseFont);
  const Top = FCurrentY + Max(0, (LineHeight - FTheme.CheckboxSize) / 2);
  const Bounds = TLayoutRectF.Create(Command.X, Top, Command.X + FTheme.CheckboxSize, Top + FTheme.CheckboxSize);

  FItems.Add(TDisplayCheckbox.Create(Bounds, Marker, Checked));
end;

procedure TLayoutWorker.PushBlockQuote(const Command: TLayoutCommand);
begin
  var BarCommand := Default(TLayoutCommand);
  BarCommand.Kind := TLayoutCommandKind.QuoteBar;
  BarCommand.Node := Command.Node;
  BarCommand.X := Command.X;
  BarCommand.StartY := FCurrentY;
  BarCommand.InsertIndex := FItems.Count;
  FCommands.Add(BarCommand);

  PushContainerChildren(Command.Node, Command.X + FTheme.BlockQuoteInset, FTheme.BlockQuoteTextColor);
end;

procedure TLayoutWorker.EmitQuoteBar(const Command: TLayoutCommand);
begin
  const Height = FCurrentY - Command.StartY;
  if Height <= 0 then
    Exit;

  const Bounds = TLayoutRectF.Create(Command.X, Command.StartY, Command.X + FTheme.BlockQuoteBarWidth,
    Command.StartY + Height);
  FItems.Insert(Command.InsertIndex, TDisplayRectangle.Create(Bounds, Command.Node, FTheme.BlockQuoteBarColor, 0, 0));
end;

procedure TLayoutWorker.PushList(const Command: TLayoutCommand);
begin
  const List = Command.Node as IMarkdownList;

  var ItemGap := FTheme.ParagraphSpacing;
  if List.IsTight then
    ItemGap := 0;

  for var Index := Command.Node.ChildCount - 1 downto 0 do
  begin
    var ItemCommand := Default(TLayoutCommand);
    ItemCommand.Kind := TLayoutCommandKind.ListItem;
    ItemCommand.Node := Command.Node.Children[Index];
    ItemCommand.X := Command.X;
    ItemCommand.TextColor := Command.TextColor;
    ItemCommand.Tight := List.IsTight;

    var TaskMarker: IMarkdownCustomInline;
    const IsTaskItem = TryFindTaskMarker(ItemCommand.Node, TaskMarker);
    if not IsTaskItem then
    begin
      if List.IsOrdered then
        ItemCommand.MarkerText := Format(OrderedMarkerFormat, [List.StartNumber + Index])
      else
        ItemCommand.MarkerText := BulletMarkerText;
    end;

    FCommands.Add(ItemCommand);

    if Index > 0 then
      PushGap(ItemGap);
  end;
end;

class function TLayoutWorker.TryFindTaskMarker(const ListItem: IMarkdownNode; out Marker: IMarkdownCustomInline): Boolean;
begin
  Marker := nil;

  const HasFirstBlock = (ListItem.ChildCount > 0);
  if not HasFirstBlock then
    Exit(False);

  const FirstBlock = ListItem.Children[0];
  const IsParagraph = (FirstBlock.Kind = TMarkdownNodeKind.Paragraph);
  const HasFirstInline = (FirstBlock.ChildCount > 0);
  if not (IsParagraph and HasFirstInline) then
    Exit(False);

  const FirstInline = FirstBlock.Children[0];
  const IsCustomInline = (FirstInline.Kind = TMarkdownNodeKind.CustomInline);
  if not IsCustomInline then
    Exit(False);

  const Candidate = FirstInline as IMarkdownCustomInline;
  const IsCheckedTask = (Candidate.NodeName = TGfmInlineParser.TaskCheckedNodeName);
  const IsUncheckedTask = (Candidate.NodeName = TGfmInlineParser.TaskUncheckedNodeName);

  Result := IsCheckedTask or IsUncheckedTask;
  if Result then
    Marker := Candidate;
end;

procedure TLayoutWorker.PushContainerChildren(const Container: IMarkdownNode; const X: Single;
  const TextColor: TLayoutColor);
begin
  for var Index := Container.ChildCount - 1 downto 0 do
  begin
    const Child = Container.Children[Index];

    PushBlock(Child, X, TextColor);

    if Index > 0 then
      PushGap(SpacingBelowOf(Container.Children[Index - 1]) + SpacingAboveOf(Child));
  end;
end;

procedure TLayoutWorker.PushBlock(const Node: IMarkdownNode; const X: Single; const TextColor: TLayoutColor);
begin
  var Command := Default(TLayoutCommand);
  Command.Kind := TLayoutCommandKind.Block;
  Command.Node := Node;
  Command.X := X;
  Command.TextColor := TextColor;

  FCommands.Add(Command);
end;

procedure TLayoutWorker.PushGap(const Amount: Single);
begin
  var Command := Default(TLayoutCommand);
  Command.Kind := TLayoutCommandKind.Gap;
  Command.GapAmount := Amount;

  FCommands.Add(Command);
end;

procedure TLayoutWorker.LayoutInlineBlock(const Container: IMarkdownNode; const X: Single;
  const BaseFont: TMarkdownFontStyle; const TextColor: TLayoutColor);
begin
  const Atoms = CollectInlineAtoms(Container, BaseFont, TextColor);
  try
    const Wrapper = TInlineWrapper.Create(FMeasurer, FItems, X, FCurrentY, ContentRight - X, BaseFont,
      FTheme.CodeSpanBackgroundColor);
    try
      for var Atom in Atoms do
      begin
        Wrapper.AddAtom(Atom);
      end;

      FCurrentY := FCurrentY + Wrapper.Finish;
    finally
      Wrapper.Free;
    end;
  finally
    Atoms.Free;
  end;
end;

procedure TLayoutWorker.EmitCodeBlock(const Command: TLayoutCommand);
begin
  const Code = Command.Node as IMarkdownCodeBlock;
  const Lines = SplitCodeLines(Code.Literal);
  const LineHeight = FMeasurer.LineHeight(FTheme.CodeFont);
  const Padding = FTheme.CodePadding;
  const Height = Length(Lines) * LineHeight + 2 * Padding;

  const Background = TLayoutRectF.Create(Command.X, FCurrentY, ContentRight, FCurrentY + Height);
  FItems.Add(TDisplayRectangle.Create(Background, Command.Node, FTheme.CodeBackgroundColor, 0, 0));

  EmitCodeLines(Command, Code, Lines, LineHeight, Padding);

  FCurrentY := FCurrentY + Height;
end;

procedure TLayoutWorker.EmitCodeLines(const Command: TLayoutCommand; const Code: IMarkdownCodeBlock;
  const Lines: TArray<string>; const LineHeight, Padding: Single);
begin
  var Highlighter: IMarkdownSyntaxHighlighter;
  const Language = CodeLanguageOf(Code);
  const UseHighlighter = (Language <> '') and THighlighterRegistry.TryGet(Language, Highlighter);

  var TokenizerState := THighlighterRegistry.DefaultState;
  if UseHighlighter then
    TokenizerState := Highlighter.InitialState;

  var LineStart := 0;
  for var Index := 0 to Length(Lines) - 1 do
  begin
    const LineText = Lines[Index];
    const Top = FCurrentY + Padding + Index * LineHeight;

    if UseHighlighter then
      TokenizerState := EmitHighlightedCodeLine(Command, Highlighter, LineText, Top, LineHeight, LineStart,
        TokenizerState)
    else if LineText <> '' then
      EmitPlainCodeLine(Command, LineText, Top, LineHeight, LineStart);

    LineStart := LineStart + Length(LineText) + 1;
  end;
end;

function TLayoutWorker.EmitHighlightedCodeLine(const Command: TLayoutCommand;
  const Highlighter: IMarkdownSyntaxHighlighter; const LineText: string; const Top, LineHeight: Single;
  const LineStart, State: Integer): Integer;
begin
  const Line = Highlighter.TokenizeLine(LineText, State);
  Result := Line.NextState;

  var Left := Command.X + FTheme.CodePadding;
  for var Token in Line.Tokens do
  begin
    const TokenText = Copy(LineText, Token.Start, Token.Length);
    const Size = FMeasurer.MeasureText(TokenText, FTheme.CodeFont);
    const Bounds = TLayoutRectF.Create(Left, Top, Left + Size.Width, Top + LineHeight);

    FItems.Add(TDisplayTextRun.Create(Bounds, Command.Node, TokenText, FTheme.CodeFont,
      FTheme.TokenColors[Token.Kind], FMeasurer.Baseline(FTheme.CodeFont), LineStart + Token.Start - 1));
    Left := Left + Size.Width;
  end;
end;

procedure TLayoutWorker.EmitPlainCodeLine(const Command: TLayoutCommand; const LineText: string;
  const Top, LineHeight: Single; const LineStart: Integer);
begin
  const Padding = FTheme.CodePadding;
  const Size = FMeasurer.MeasureText(LineText, FTheme.CodeFont);
  const Bounds = TLayoutRectF.Create(Command.X + Padding, Top, Command.X + Padding + Size.Width, Top + LineHeight);

  FItems.Add(TDisplayTextRun.Create(Bounds, Command.Node, LineText, FTheme.CodeFont, FTheme.CodeTextColor,
    FMeasurer.Baseline(FTheme.CodeFont), LineStart));
end;

class function TLayoutWorker.CodeLanguageOf(const Code: IMarkdownCodeBlock): string;
const
  InfoWhitespace = [' ', #9];
begin
  Result := Code.InfoString.Trim;

  for var Index := 1 to Length(Result) do
  begin
    if CharInSet(Result[Index], InfoWhitespace) then
      Exit(Copy(Result, 1, Index - 1));
  end;
end;

procedure TLayoutWorker.EmitHtmlBlock(const Command: TLayoutCommand);
begin
  const Html = Command.Node as IMarkdownText;
  const Lines = SplitCodeLines(Html.Literal);
  const LineHeight = FMeasurer.LineHeight(FTheme.BaseFont);

  var LineStart := 0;
  for var Index := 0 to Length(Lines) - 1 do
  begin
    const LineText = Lines[Index];
    const NextLineStart = LineStart + Length(LineText) + 1;
    if LineText = '' then
    begin
      LineStart := NextLineStart;
      Continue;
    end;

    const Size = FMeasurer.MeasureText(LineText, FTheme.BaseFont);
    const Top = FCurrentY + Index * LineHeight;
    const Bounds = TLayoutRectF.Create(Command.X, Top, Command.X + Size.Width, Top + LineHeight);

    FItems.Add(TDisplayTextRun.Create(Bounds, Command.Node, LineText, FTheme.BaseFont, Command.TextColor,
      FMeasurer.Baseline(FTheme.BaseFont), LineStart));
    LineStart := NextLineStart;
  end;

  FCurrentY := FCurrentY + Length(Lines) * LineHeight;
end;

procedure TLayoutWorker.EmitThematicBreak(const Command: TLayoutCommand);
begin
  const Thickness = FTheme.ThematicBreakThickness;
  const CenterY = FCurrentY + Thickness / 2;
  const StartPoint = TLayoutPointF.Create(Command.X, CenterY);
  const EndPoint = TLayoutPointF.Create(ContentRight, CenterY);
  const Bounds = TLayoutRectF.Create(Command.X, FCurrentY, ContentRight, FCurrentY + Thickness);

  FItems.Add(TDisplayLine.Create(Bounds, Command.Node, StartPoint, EndPoint, FTheme.ThematicBreakColor, Thickness));

  FCurrentY := FCurrentY + Thickness;
end;

procedure TLayoutWorker.LayoutTable(const Command: TLayoutCommand);
begin
  const Table = TTableLayout.Create(FTheme, FMeasurer, FItems, FCollector);
  try
    FCurrentY := Table.Layout(Command, FCurrentY, ContentRight - Command.X);
  finally
    Table.Free;
  end;
end;

constructor TTableLayout.Create(const Theme: TMarkdownTheme; const Measurer: ITextMeasurer;
  const Items: TList<IDisplayItem>; const Collector: TInlineAtomCollector);
begin
  inherited Create;

  FTheme := Theme;
  FMeasurer := Measurer;
  FItems := Items;
  FCollector := Collector;
end;

function TTableLayout.Layout(const Command: TLayoutCommand; const StartY, AvailableWidth: Single): Single;
begin
  FCurrentY := StartY;

  const RowCount = Command.Node.ChildCount;

  var ColumnCount := 0;
  for var Index := 0 to RowCount - 1 do
  begin
    ColumnCount := Max(ColumnCount, Command.Node.Children[Index].ChildCount);
  end;

  const HasCells = (RowCount > 0) and (ColumnCount > 0);
  if HasCells then
  begin
    const Cells = TObjectList<TList<TInlineAtom>>.Create(True);
    try
      const NaturalWidths = MeasureTableCells(Command, ColumnCount, Cells);
      const ColumnWidths = ComputeColumnWidths(NaturalWidths, AvailableWidth);

      PlaceTableRows(Command, ColumnCount, Cells, ColumnWidths);
    finally
      Cells.Free;
    end;
  end;

  Result := FCurrentY;
end;

function TTableLayout.MeasureTableCells(const Command: TLayoutCommand; const ColumnCount: Integer;
  const Cells: TObjectList<TList<TInlineAtom>>): TArray<Single>;
begin
  Result := nil;
  SetLength(Result, ColumnCount);

  for var RowIndex := 0 to Command.Node.ChildCount - 1 do
  begin
    const Row = Command.Node.Children[RowIndex];
    const RowFont = TableRowFont(Row);

    for var ColumnIndex := 0 to ColumnCount - 1 do
    begin
      const HasCell = (ColumnIndex < Row.ChildCount);
      if not HasCell then
      begin
        Cells.Add(nil);
        Continue;
      end;

      const Atoms = FCollector.Collect(Row.Children[ColumnIndex], RowFont, Command.TextColor);
      Cells.Add(Atoms);
      Result[ColumnIndex] := Max(Result[ColumnIndex], NaturalWidthOf(Atoms));
    end;
  end;
end;

function TTableLayout.ComputeColumnWidths(const NaturalWidths: TArray<Single>;
  const AvailableWidth: Single): TArray<Single>;
begin
  const ColumnCount = Length(NaturalWidths);
  const HasMaxCap = FTheme.TableMaxColumnWidth > 0;

  Result := nil;
  SetLength(Result, ColumnCount);

  var Total := 0.0;
  for var Index := 0 to ColumnCount - 1 do
  begin
    var Desired := NaturalWidths[Index] + 2 * FTheme.TableCellPadding;
    if HasMaxCap then
      Desired := Min(Desired, FTheme.TableMaxColumnWidth);
    Desired := Max(Desired, FTheme.TableMinColumnWidth);

    Result[Index] := Desired;
    Total := Total + Desired;
  end;

  const Overflow = Total - AvailableWidth;
  const ContentFitsAvailableWidth = Overflow <= 0;
  if ContentFitsAvailableWidth then
    Exit;

  var SlackTotal := 0.0;
  for var Index := 0 to ColumnCount - 1 do
  begin
    SlackTotal := SlackTotal + (Result[Index] - FTheme.TableMinColumnWidth);
  end;

  const ColumnsAlreadyAtMinimum = SlackTotal <= 0;
  if ColumnsAlreadyAtMinimum then
    Exit;

  const ShrinkRatio = Min(1, Overflow / SlackTotal);
  for var Index := 0 to ColumnCount - 1 do
  begin
    const Slack = Result[Index] - FTheme.TableMinColumnWidth;
    Result[Index] := Result[Index] - Slack * ShrinkRatio;
  end;
end;

procedure TTableLayout.PlaceTableRows(const Command: TLayoutCommand; const ColumnCount: Integer;
  const Cells: TObjectList<TList<TInlineAtom>>; const ColumnWidths: TArray<Single>);
begin
  var TableWidth := 0.0;
  for var Width in ColumnWidths do
  begin
    TableWidth := TableWidth + Width;
  end;

  for var RowIndex := 0 to Command.Node.ChildCount - 1 do
  begin
    PlaceTableRow(Command, RowIndex, ColumnCount, Cells, ColumnWidths, TableWidth);
  end;
end;

procedure TTableLayout.PlaceTableRow(const Command: TLayoutCommand; const RowIndex, ColumnCount: Integer;
  const Cells: TObjectList<TList<TInlineAtom>>; const ColumnWidths: TArray<Single>; const TableWidth: Single);
begin
  const Row = Command.Node.Children[RowIndex];
  const RowFont = TableRowFont(Row);
  const RowTop = FCurrentY;
  const RowItemIndex = FItems.Count;

  var RowHeight := 0.0;
  var CellLeft := Command.X;

  for var ColumnIndex := 0 to ColumnCount - 1 do
  begin
    const Atoms = Cells[RowIndex * ColumnCount + ColumnIndex];
    if Atoms <> nil then
      RowHeight := Max(RowHeight, PlaceTableCell(Row, ColumnIndex, Atoms, CellLeft, RowTop,
        ColumnWidths[ColumnIndex], RowFont));

    CellLeft := CellLeft + ColumnWidths[ColumnIndex];
  end;

  if RowHeight = 0 then
    RowHeight := FMeasurer.LineHeight(RowFont);

  const IsHeader = (Row as IMarkdownTableRow).IsHeader;
  if IsHeader then
  begin
    const HeaderBounds = TLayoutRectF.Create(Command.X, RowTop, Command.X + TableWidth, RowTop + RowHeight);
    FItems.Insert(RowItemIndex, TDisplayRectangle.Create(HeaderBounds, Row, FTheme.TableHeaderBackgroundColor, 0, 0));
  end;

  FCurrentY := RowTop + RowHeight;
end;

function TTableLayout.PlaceTableCell(const Row: IMarkdownNode; const ColumnIndex: Integer;
  const Atoms: TList<TInlineAtom>; const CellLeft, RowTop, ColumnWidth: Single;
  const RowFont: TMarkdownFontStyle): Single;
begin
  const Padding = FTheme.TableCellPadding;
  const FirstItemIndex = FItems.Count;

  const Wrapper = TInlineWrapper.Create(FMeasurer, FItems, CellLeft + Padding, RowTop, ColumnWidth - 2 * Padding,
    RowFont, FTheme.CodeSpanBackgroundColor);
  try
    for var Atom in Atoms do
    begin
      Wrapper.AddAtom(Atom);
    end;

    Result := Wrapper.Finish;
  finally
    Wrapper.Free;
  end;

  const Cell = Row.Children[ColumnIndex] as IMarkdownTableCell;
  AlignCellItems(FirstItemIndex, FItems.Count - 1, Cell.Alignment, CellLeft + ColumnWidth - Padding);
end;

procedure TTableLayout.AlignCellItems(const FirstIndex, LastIndex: Integer;
  const Alignment: TMarkdownTableColumnAlignment; const ContentRightEdge: Single);
begin
  const NeedsShift = Alignment in [TMarkdownTableColumnAlignment.Right, TMarkdownTableColumnAlignment.Center];
  const HasItems = NeedsShift and (LastIndex >= FirstIndex);
  if not HasItems then
    Exit;

  var Deltas: TArray<Single>;
  SetLength(Deltas, LastIndex - FirstIndex + 1);

  for var Index := FirstIndex to LastIndex do
  begin
    const LineRight = MaxRightOnLine(FirstIndex, LastIndex, FItems[Index].Bounds);

    var Delta := ContentRightEdge - LineRight;
    if Alignment = TMarkdownTableColumnAlignment.Center then
      Delta := Delta / 2;

    Deltas[Index - FirstIndex] := Delta;
  end;

  for var Index := FirstIndex to LastIndex do
  begin
    const Delta = Deltas[Index - FirstIndex];
    const ShouldShift = (Delta > LineEpsilon);
    if ShouldShift then
      FItems[Index] := TLayoutWorker.ShiftedItem(FItems[Index], Delta, 0);
  end;
end;

function TTableLayout.MaxRightOnLine(const FirstIndex, LastIndex: Integer; const Reference: TLayoutRectF): Single;
begin
  Result := 0;

  for var Index := FirstIndex to LastIndex do
  begin
    const Candidate = FItems[Index].Bounds;
    const OnSameLine = (Candidate.Top < Reference.Bottom - LineEpsilon) and
      (Candidate.Bottom > Reference.Top + LineEpsilon);
    if OnSameLine then
      Result := Max(Result, Candidate.Right);
  end;
end;

function TTableLayout.TableRowFont(const Row: IMarkdownNode): TMarkdownFontStyle;
begin
  Result := FTheme.BaseFont;

  const IsHeader = (Row as IMarkdownTableRow).IsHeader;
  if IsHeader then
    Result.Bold := True;
end;

class function TTableLayout.NaturalWidthOf(const Atoms: TList<TInlineAtom>): Single;
begin
  Result := 0;

  for var Atom in Atoms do
  begin
    if Atom.Kind <> TInlineAtomKind.HardBreakToken then
      Result := Result + Atom.Width;
  end;
end;

function TLayoutWorker.CollectInlineAtoms(const Container: IMarkdownNode; const BaseFont: TMarkdownFontStyle;
  const BaseColor: TLayoutColor): TList<TInlineAtom>;
begin
  Result := FCollector.Collect(Container, BaseFont, BaseColor);
end;

constructor TInlineAtomCollector.Create(const Measurer: ITextMeasurer; const Theme: TMarkdownTheme;
  const ImageSizes: IMarkdownImageSizeProvider; const ContentRight: Single);
begin
  inherited Create;

  FMeasurer := Measurer;
  FTheme := Theme;
  FImageSizes := ImageSizes;
  FContentRight := ContentRight;
end;

function TInlineAtomCollector.Collect(const Container: IMarkdownNode; const BaseFont: TMarkdownFontStyle;
  const BaseColor: TLayoutColor): TList<TInlineAtom>;
begin
  Result := TList<TInlineAtom>.Create;
  try
    const Frames = TList<TInlineFrame>.Create;
    try
      var RootStyle := Default(TInlineStyle);
      RootStyle.Font := BaseFont;
      RootStyle.Color := BaseColor;
      PushStyledFrame(Frames, Container, RootStyle);

      while Frames.Count > 0 do
      begin
        const LastIndex = Frames.Count - 1;
        var Frame := Frames[LastIndex];

        const Exhausted = (Frame.ChildIndex >= Frame.Node.ChildCount);
        if Exhausted then
        begin
          Frames.Delete(LastIndex);
          Continue;
        end;

        const Child = Frame.Node.Children[Frame.ChildIndex];
        Frame.ChildIndex := Frame.ChildIndex + 1;
        Frames[LastIndex] := Frame;

        HandleInlineChild(Result, Frames, Child, Frame.Style);
      end;
    finally
      Frames.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TInlineAtomCollector.HandleInlineChild(const Atoms: TList<TInlineAtom>; const Frames: TList<TInlineFrame>;
  const Child: IMarkdownNode; const Style: TInlineStyle);
begin
  case Child.Kind of
    TMarkdownNodeKind.Text, TMarkdownNodeKind.InlineHtml:
      AppendTextAtoms(Atoms, (Child as IMarkdownText).Literal, Style, Child);
    TMarkdownNodeKind.CodeSpan:
      AppendCodeSpanAtoms(Atoms, Child, Style);
    TMarkdownNodeKind.SoftLineBreak:
      AppendTextAtoms(Atoms, ' ', Style, Child);
    TMarkdownNodeKind.HardLineBreak:
      AppendHardBreakAtom(Atoms);
    TMarkdownNodeKind.Image:
      AppendImageAtom(Atoms, Child, Style);
    TMarkdownNodeKind.CustomInline:
      HandleCustomInline(Atoms, Frames, Child, Style);
    TMarkdownNodeKind.Emphasis:
      begin
        var ItalicStyle := Style;
        ItalicStyle.Font.Italic := True;
        PushStyledFrame(Frames, Child, ItalicStyle);
      end;
    TMarkdownNodeKind.Strong:
      begin
        var BoldStyle := Style;
        BoldStyle.Font.Bold := True;
        PushStyledFrame(Frames, Child, BoldStyle);
      end;
    TMarkdownNodeKind.Link, TMarkdownNodeKind.Autolink:
      begin
        var LinkStyle := Style;
        LinkStyle.Font.Underline := True;
        LinkStyle.Color := FTheme.LinkColor;
        LinkStyle.Attribution := Child;
        PushStyledFrame(Frames, Child, LinkStyle);
      end;
  else
    if Child.ChildCount > 0 then
      PushStyledFrame(Frames, Child, Style);
  end;
end;

procedure TInlineAtomCollector.AppendTextAtoms(const Atoms: TList<TInlineAtom>; const Text: string;
  const Style: TInlineStyle; const Leaf: IMarkdownNode);
begin
  var Attribution := Style.Attribution;
  if Attribution = nil then
    Attribution := Leaf;

  var Index := 1;
  while Index <= Length(Text) do
  begin
    const IsSpace = (Text[Index] = ' ');
    const Start = Index;

    while (Index <= Length(Text)) and ((Text[Index] = ' ') = IsSpace) do
    begin
      Inc(Index);
    end;

    const Token = Copy(Text, Start, Index - Start);
    var Atom := Default(TInlineAtom);
    if IsSpace then
      Atom.Kind := TInlineAtomKind.SpaceToken
    else
      Atom.Kind := TInlineAtomKind.WordToken;
    Atom.Text := Token;
    Atom.Font := Style.Font;
    Atom.Color := Style.Color;
    Atom.Node := Attribution;
    Atom.StartOffset := Start - 1;
    Atom.Width := FMeasurer.MeasureText(Token, Style.Font).Width;

    Atoms.Add(Atom);
  end;
end;

procedure TInlineAtomCollector.AppendCodeSpanAtoms(const Atoms: TList<TInlineAtom>; const Child: IMarkdownNode;
  const Style: TInlineStyle);
begin
  var CodeStyle := Style;
  CodeStyle.Font := FTheme.CodeFont;
  CodeStyle.Font.Underline := Style.Font.Underline;
  CodeStyle.Font.Strikeout := Style.Font.Strikeout;
  CodeStyle.Color := FTheme.CodeTextColor;

  const FirstAtomIndex = Atoms.Count;
  AppendTextAtoms(Atoms, (Child as IMarkdownText).Literal, CodeStyle, Child);

  for var Index := FirstAtomIndex to Atoms.Count - 1 do
  begin
    var Atom := Atoms[Index];
    Atom.CodeSpan := True;
    Atoms[Index] := Atom;
  end;
end;

procedure TInlineAtomCollector.AppendHardBreakAtom(const Atoms: TList<TInlineAtom>);
begin
  var Atom := Default(TInlineAtom);
  Atom.Kind := TInlineAtomKind.HardBreakToken;

  Atoms.Add(Atom);
end;

procedure TInlineAtomCollector.AppendImageAtom(const Atoms: TList<TInlineAtom>; const Child: IMarkdownNode;
  const Style: TInlineStyle);
begin
  const ImageLink = Child as IMarkdownLink;

  var Attribution := Style.Attribution;
  if Attribution = nil then
    Attribution := Child;

  var Atom := Default(TInlineAtom);
  Atom.Kind := TInlineAtomKind.ImageToken;
  Atom.Node := Attribution;
  Atom.Width := FTheme.ImagePlaceholderWidth;
  Atom.Height := FTheme.ImagePlaceholderHeight;
  Atom.Source := ImageLink.Destination;
  Atom.AltText := CollectPlainText(Child);

  var LoadedSize: TLayoutSizeF;
  const HasLoadedSize = (FImageSizes <> nil) and FImageSizes.TryGetImageSize(Atom.Source, LoadedSize) and
    (LoadedSize.Width > 0) and (LoadedSize.Height > 0);
  if HasLoadedSize then
  begin
    var Scale: Single := 1.0;
    if LoadedSize.Width > FContentRight then
      Scale := FContentRight / LoadedSize.Width;

    Atom.Width := LoadedSize.Width * Scale;
    Atom.Height := LoadedSize.Height * Scale;
  end;

  Atoms.Add(Atom);
end;

procedure TInlineAtomCollector.HandleCustomInline(const Atoms: TList<TInlineAtom>; const Frames: TList<TInlineFrame>;
  const Child: IMarkdownNode; const Style: TInlineStyle);
begin
  const Custom = Child as IMarkdownCustomInline;
  const IsCheckedTask = (Custom.NodeName = TGfmInlineParser.TaskCheckedNodeName);
  const IsUncheckedTask = (Custom.NodeName = TGfmInlineParser.TaskUncheckedNodeName);

  // The list item's marker column already carries the checkbox for this node
  // (see TLayoutWorker.EmitTaskCheckbox); a task marker contributes no inline content.
  if IsCheckedTask or IsUncheckedTask then
    Exit;

  var StrikeStyle := Style;
  StrikeStyle.Font.Strikeout := True;
  PushStyledFrame(Frames, Child, StrikeStyle);
end;

class procedure TInlineAtomCollector.PushStyledFrame(const Frames: TList<TInlineFrame>; const Node: IMarkdownNode;
  const Style: TInlineStyle);
begin
  var Frame := Default(TInlineFrame);
  Frame.Node := Node;
  Frame.ChildIndex := 0;
  Frame.Style := Style;

  Frames.Add(Frame);
end;

class function TInlineAtomCollector.CollectPlainText(const Node: IMarkdownNode): string;
begin
  const Builder = TStringBuilder.Create;
  try
    const Pending = TList<IMarkdownNode>.Create;
    try
      for var Index := Node.ChildCount - 1 downto 0 do
      begin
        Pending.Add(Node.Children[Index]);
      end;

      while Pending.Count > 0 do
      begin
        const LastIndex = Pending.Count - 1;
        const Current = Pending[LastIndex];
        Pending.Delete(LastIndex);

        var Text: IMarkdownText;
        const IsText = Supports(Current, IMarkdownText, Text);
        if IsText then
          Builder.Append(Text.Literal);

        for var Index := Current.ChildCount - 1 downto 0 do
        begin
          Pending.Add(Current.Children[Index]);
        end;
      end;
    finally
      Pending.Free;
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TLayoutWorker.SplitCodeLines(const Literal: string): TArray<string>;
begin
  Result := Literal.Split([#10]);

  const HasTrailingEmptyLine = (Length(Result) > 0) and (Result[High(Result)] = '');
  if HasTrailingEmptyLine then
    SetLength(Result, Length(Result) - 1);
end;

class function TLayoutWorker.ShiftedItem(const Item: IDisplayItem; const DeltaX, DeltaY: Single): IDisplayItem;
begin
  var Shift: IDisplayItemShift;
  const CanShift = Supports(Item, IDisplayItemShift, Shift);
  if not CanShift then
    raise EMarkdownError.Create('Display item does not support shifting');

  Result := Shift.Shifted(DeltaX, DeltaY);
end;

constructor TLayoutBlockContext.Create(const Measurer: ITextMeasurer; const Theme: TMarkdownTheme; const Width: Single;
  const Items: TList<IDisplayItem>; const Node: IMarkdownNode);
begin
  inherited Create;

  FMeasurer := Measurer;
  FTheme := Theme;
  FWidth := Width;
  FItems := Items;
  FNode := Node;
end;

function TLayoutBlockContext.GetMeasurer: ITextMeasurer;
begin
  Result := FMeasurer;
end;

function TLayoutBlockContext.GetTheme: TMarkdownTheme;
begin
  Result := FTheme;
end;

function TLayoutBlockContext.GetWidth: Single;
begin
  Result := FWidth;
end;

function TLayoutBlockContext.GetCanvas: IExtensionCanvas;
begin
  if FCanvas = nil then
    FCanvas := TDisplayListExtensionCanvas.Create(FMeasurer, FItems, FNode);

  Result := FCanvas;
end;

constructor TInlineWrapper.Create(const Measurer: ITextMeasurer; const Items: TList<IDisplayItem>;
  const Left, Top, AvailableWidth: Single; const BaseFont: TMarkdownFontStyle;
  const CodeSpanBackground: TLayoutColor);
begin
  inherited Create;

  FMeasurer := Measurer;
  FItems := Items;
  FLeft := Left;
  FStartTop := Top;
  FLineTop := Top;
  FAvailableWidth := AvailableWidth;
  FBaseFont := BaseFont;
  FCodeSpanBackground := CodeSpanBackground;
  FCommitted := TList<TInlineAtom>.Create;
  FPending := TList<TInlineAtom>.Create;
end;

destructor TInlineWrapper.Destroy;
begin
  FPending.Free;
  FCommitted.Free;

  inherited Destroy;
end;

procedure TInlineWrapper.AddAtom(const Atom: TInlineAtom);
begin
  case Atom.Kind of
    TInlineAtomKind.SpaceToken:
      begin
        const LineIsEmpty = (FCommitted.Count = 0);
        if not LineIsEmpty then
        begin
          FPending.Add(Atom);
          FPendingWidth := FPendingWidth + Atom.Width;
        end;
      end;
    TInlineAtomKind.HardBreakToken:
      FlushLine;
  else
    AddWordLike(Atom);
  end;
end;

function TInlineWrapper.Finish: Single;
begin
  const HasOpenLine = (FCommitted.Count > 0);
  if HasOpenLine then
    FlushLine;

  Result := FLineTop - FStartTop;
end;

procedure TInlineWrapper.AddWordLike(const Atom: TInlineAtom);
begin
  const Fits = (FLineWidth + FPendingWidth + Atom.Width <= FAvailableWidth + FitEpsilon);
  if Fits then
  begin
    CommitPending;
    CommitAtom(Atom);
    Exit;
  end;

  const HasContent = (FCommitted.Count > 0);
  if HasContent then
    FlushLine;

  const NeedsForceBreak = (Atom.Kind = TInlineAtomKind.WordToken) and (Atom.Width > FAvailableWidth + FitEpsilon);
  if NeedsForceBreak then
    ForceBreakWord(Atom)
  else
    CommitAtom(Atom);
end;

procedure TInlineWrapper.ForceBreakWord(const Atom: TInlineAtom);
begin
  var Rest := Atom.Text;
  var RestOffset := Atom.StartOffset;

  while Rest <> '' do
  begin
    const FitCount = MaxCharsFitting(Rest, Atom.Font);

    var Chunk := Atom;
    Chunk.Text := Copy(Rest, 1, FitCount);
    Chunk.StartOffset := RestOffset;
    Chunk.Width := FMeasurer.MeasureText(Chunk.Text, Atom.Font).Width;
    CommitAtom(Chunk);

    RestOffset := RestOffset + FitCount;
    Rest := Copy(Rest, FitCount + 1, Length(Rest));
    if Rest <> '' then
      FlushLine;
  end;
end;

function TInlineWrapper.MaxCharsFitting(const Text: string; const Font: TMarkdownFontStyle): Integer;
begin
  Result := 1;

  for var CharCount := 2 to Length(Text) do
  begin
    const Prefix = Copy(Text, 1, CharCount);
    const PrefixSize = FMeasurer.MeasureText(Prefix, Font);
    const PrefixFits = (PrefixSize.Width <= FAvailableWidth + FitEpsilon);
    if not PrefixFits then
      Exit;

    Result := CharCount;
  end;
end;

procedure TInlineWrapper.CommitPending;
begin
  FCommitted.AddRange(FPending);

  FLineWidth := FLineWidth + FPendingWidth;
  FPending.Clear;
  FPendingWidth := 0;
end;

procedure TInlineWrapper.CommitAtom(const Atom: TInlineAtom);
begin
  FCommitted.Add(Atom);
  FLineWidth := FLineWidth + Atom.Width;
end;

procedure TInlineWrapper.FlushLine;
begin
  const Advance = LineAdvance;

  EmitLineItems;

  FLineTop := FLineTop + Advance;
  FCommitted.Clear;
  FPending.Clear;
  FLineWidth := 0;
  FPendingWidth := 0;
end;

function TInlineWrapper.LineAdvance: Single;
begin
  Result := 0;

  for var Atom in FCommitted do
  begin
    case Atom.Kind of
      TInlineAtomKind.WordToken, TInlineAtomKind.SpaceToken:
        Result := Max(Result, FMeasurer.LineHeight(Atom.Font));
      TInlineAtomKind.ImageToken:
        Result := Max(Result, Atom.Height);
    else
      raise EMarkdownError.CreateFmt('Unhandled inline atom kind: %d', [Ord(Atom.Kind)]);
    end;
  end;

  if Result = 0 then
    Result := FMeasurer.LineHeight(FBaseFont);
end;

function TInlineWrapper.LineBaseline: Single;
begin
  Result := 0;

  for var Atom in FCommitted do
  begin
    const IsText = (Atom.Kind = TInlineAtomKind.WordToken) or (Atom.Kind = TInlineAtomKind.SpaceToken);
    if IsText then
      Result := Max(Result, FMeasurer.Baseline(Atom.Font));
  end;

  if Result = 0 then
    Result := FMeasurer.Baseline(FBaseFont);
end;

procedure TInlineWrapper.EmitLineItems;
begin
  FCursor := FLeft;
  FGroupOpen := False;
  FLineBaseline := LineBaseline;

  for var Atom in FCommitted do
  begin
    EmitLineAtom(Atom);
  end;

  CloseGroup;
end;

procedure TInlineWrapper.EmitLineAtom(const Atom: TInlineAtom);
begin
  case Atom.Kind of
    TInlineAtomKind.SpaceToken:
      if FGroupOpen then
        AppendToGroup(Atom);
    TInlineAtomKind.WordToken:
      begin
        const Joins = FGroupOpen and SameRunStyle(Atom);
        if Joins then
        begin
          AppendToGroup(Atom);
        end
        else
        begin
          CloseGroup;
          OpenGroup(Atom);
        end;
      end;
    TInlineAtomKind.ImageToken:
      begin
        CloseGroup;
        EmitImageItem(Atom);
      end;
  else
    raise EMarkdownError.CreateFmt('Unhandled inline atom kind: %d', [Ord(Atom.Kind)]);
  end;
end;

procedure TInlineWrapper.OpenGroup(const Atom: TInlineAtom);
begin
  FGroupOpen := True;
  FGroupText := Atom.Text;
  FGroupWidth := Atom.Width;
  FGroupFont := Atom.Font;
  FGroupColor := Atom.Color;
  FGroupNode := Atom.Node;
  FGroupStartOffset := Atom.StartOffset;
  FGroupCodeSpan := Atom.CodeSpan;
end;

procedure TInlineWrapper.AppendToGroup(const Atom: TInlineAtom);
begin
  FGroupText := FGroupText + Atom.Text;
  FGroupWidth := FGroupWidth + Atom.Width;
end;

procedure TInlineWrapper.CloseGroup;
begin
  if not FGroupOpen then
    Exit;

  const RunBaseline = FMeasurer.Baseline(FGroupFont);
  const RunHeight = FMeasurer.LineHeight(FGroupFont);
  const Top = FLineTop + (FLineBaseline - RunBaseline);
  const Bounds = TLayoutRectF.Create(FCursor, Top, FCursor + FGroupWidth, Top + RunHeight);

  if FGroupCodeSpan then
    EmitCodeSpanChip(Bounds);

  FItems.Add(TDisplayTextRun.Create(Bounds, FGroupNode, FGroupText, FGroupFont, FGroupColor, RunBaseline,
    FGroupStartOffset));

  FCursor := FCursor + FGroupWidth;
  FGroupOpen := False;
end;

procedure TInlineWrapper.EmitCodeSpanChip(const RunBounds: TLayoutRectF);
begin
  const ChipBounds = TLayoutRectF.Create(RunBounds.Left - CodeSpanChipPadding, RunBounds.Top,
    RunBounds.Right + CodeSpanChipPadding, RunBounds.Bottom);

  FItems.Add(TDisplayRectangle.Create(ChipBounds, FGroupNode, FCodeSpanBackground, 0, 0));
end;

function TInlineWrapper.SameRunStyle(const Atom: TInlineAtom): Boolean;
begin
  Result := FGroupFont.Equals(Atom.Font) and (FGroupColor = Atom.Color) and (FGroupNode = Atom.Node) and
    (FGroupCodeSpan = Atom.CodeSpan);
end;

function TMarkdownFontStyleHelper.Equals(const Other: TMarkdownFontStyle): Boolean;
begin
  Result := (Self.FamilyName = Other.FamilyName) and (Self.Size = Other.Size) and (Self.Bold = Other.Bold) and
    (Self.Italic = Other.Italic) and (Self.Underline = Other.Underline) and (Self.Strikeout = Other.Strikeout);
end;

procedure TInlineWrapper.EmitImageItem(const Atom: TInlineAtom);
begin
  const Bounds = TLayoutRectF.Create(FCursor, FLineTop, FCursor + Atom.Width, FLineTop + Atom.Height);
  FItems.Add(TDisplayImage.Create(Bounds, Atom.Node, Atom.Source, Atom.AltText));

  FCursor := FCursor + Atom.Width;
end;

end.
