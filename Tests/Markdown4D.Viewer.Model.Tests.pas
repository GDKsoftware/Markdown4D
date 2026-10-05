unit Markdown4D.Viewer.Model.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Theme,
  Markdown4D.Viewer.Model;

type
  [TestFixture]
  TMarkdownViewerModelTests = class
  private
    const
      DefaultWidth = 300.0;
      DefaultHeight = 200.0;
      SmallHeight = 100.0;
      WrapWidthCharacters = 12;
      SmallerCodeFontSize = 14.0;
      BaseCharWidth = 10.0;
      BaseLineHeight = 22.4;
      BlockSpacingValue = 16.0;
      FlushIntervalValue = 100;
      StartTime = 1000;
      SingleTolerance = 0.05;
      TallParagraphCount = 10;
      ImageMarkdown = '![alt](img.png)';
      ImageSource = 'img.png';
      LoadedImageWidth = 200.0;
      LoadedImageHeight = 100.0;
      Fence = '```';
      FirstLineY = 10.0;
      SecondLineY = 33.0;
      ThirdLineY = 55.0;
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FModel: TMarkdownViewerModel;
      FReportedSender: TObject;
      FReportedExtension: string;
      FReportedMessage: string;
    class function BuildTallMarkdown: string;
    procedure RecordExtensionError(const Sender: TObject; const Extension: string; const Error: Exception);
    class procedure AssertSingle(const Expected, Actual: Single);
    procedure SelectFromTo(const AnchorX, AnchorY, ExtentX, ExtentY: Single);
    procedure LoadImageDocument;
    function AllHighlightRects: TArray<TLayoutRectF>;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure SetText_LayoutsDocumentOnce;

    [Test]
    procedure Selection_WithinSingleRun_ProducesSingleRectAndText;

    [Test]
    procedure Selection_AcrossWrappedLines_ProducesRectPerLine;

    [Test]
    procedure Selection_AcrossParagraphs_JoinsTextWithBlankLine;

    [Test]
    procedure Selection_Backwards_NormalizesToSameText;

    [Test]
    procedure ClearSelection_RemovesSelectionState;

    [Test]
    procedure SelectAll_AcrossBlocks_SelectsWholeDocument;

    [Test]
    [TestCase('BulletList', '- one'#10'- two~'#$2022' one'#13#10#$2022' two', '~', False)]
    [TestCase('OrderedList', '1. one'#10'2. two~1. one'#13#10'2. two', '~', False)]
    [TestCase('NestedList', '- one'#10'  - two~'#$2022' one'#13#10'  '#$2022' two', '~', False)]
    [TestCase('TaskList', '- [x] done'#10'- [ ] open~done'#13#10'open', '~', False)]
    [TestCase('Table', '| A | B |'#10'|---|---|'#10'| a1 | b1 |~A'#9'B'#13#10'a1'#9'b1', '~', False)]
    [TestCase('FencedCode', '```'#10'code 1'#10'code 2'#10'```~code 1'#13#10'code 2', '~', False)]
    [TestCase('HardBreak', 'one\'#10'two~one'#13#10'two', '~', False)]
    [TestCase('HeadingAndParagraph', '# Title'#10'Body~Title'#13#10#13#10'Body', '~', False)]
    [TestCase('TwoHeadings', '# One'#10'## Two~One'#13#10#13#10'Two', '~', False)]
    [TestCase('TwoLists', '- one'#10#10'1. two~'#$2022' one'#13#10#13#10'1. two', '~', False)]
    [TestCase('InlineCode', 'Ein Satz mit `Code` und **fett** hier.~Ein Satz mit Code und fett hier.', '~', False)]
    [TestCase('InlineCodeInQuote', '> Zitat mit `Code`.~Zitat mit Code.', '~', False)]
    [TestCase('SecondBlockOfListItem', '- one'#10#10'  two~'#$2022' one'#13#10#13#10'  two', '~', False)]
    [TestCase('TextAfterNestedList', '- one'#10#10'  - two'#10#10'  three~'#$2022' one'#13#10#13#10'  '#$2022' two'#13#10#13#10'  three', '~', False)]
    procedure SelectAll_BlockWithSeveralLines_KeepsLinesMarkersAndCells(const Markdown, Expected: string);

    [Test]
    [TestCase('InsideWord', 'alpha beta gamma~75~beta', '~', False)]
    [TestCase('OnSpace', 'alpha beta~55~ ', '~', False)]
    [TestCase('OnPunctuation', 'one, two~35~,', '~', False)]
    [TestCase('WithUnderscoreAndDigit', 'call foo_bar2 now~80~foo_bar2', '~', False)]
    [TestCase('AcrossStyledRuns', '**Mark**down~60~Markdown', '~', False)]
    procedure SelectWordAt_PointInFirstLine_SelectsWordUnderPointer(const Markdown: string; const X: Single;
      const Expected: string);

    [Test]
    [TestCase('WrappedParagraph', 'alpha beta gamma~120~10~33~alpha beta gamma', '~', False)]
    [TestCase('ListItem', '- one'#10'- two~300~40~33~two', '~', False)]
    [TestCase('TableRow', '| A | B |'#10'|---|---|'#10'| a1 | b1 |~300~12~33~a1'#9'b1', '~', False)]
    [TestCase('Heading', '# Title'#10'Body~300~10~10~Title', '~', False)]
    [TestCase('ParagraphWithHardBreak', 'one\'#10'two~300~10~33~one'#13#10'two', '~', False)]
    [TestCase('CodeLine', '```'#10'code 1'#10'code 2'#10'```~300~18~35~code 2', '~', False)]
    procedure SelectLineAt_Point_SelectsLineOrBlockUnderPointer(const Markdown: string; const Width, X, Y: Single;
      const Expected: string);

    [Test]
    procedure SelectAll_CodeSpanInSmallerFont_CopiesSingleSpaces;

    [Test]
    [TestCase('BracketBeforeCodeSpan', 'gross (`OnDblClick` des Frames)~gross (OnDblClick des Frames)', '~', False)]
    [TestCase('WordWiderThanLine', 'Donaudampfschiff fahrt~Donaudampfschiff fahrt', '~', False)]
    procedure SelectAll_LineWrapsWithoutSpace_CopiesNoSpace(const Markdown, Expected: string);

    [Test]
    procedure SetSelectionExtent_AfterWordSelection_ExtendsByWholeWords;

    [Test]
    procedure SetSelectionExtent_AfterLineSelection_ExtendsByWholeLines;

    [Test]
    procedure SetSelectionAnchor_AfterWordSelection_SelectsByCharacterAgain;

    [Test]
    procedure SelectWordAt_EmptyDocument_ReturnsFalse;

    [Test]
    procedure SelectAll_EmptyDocument_LeavesSelectionEmpty;

    [Test]
    procedure HasSelectableText_FollowsDocumentContent;

    [Test]
    procedure AppendMarkdown_MarksDirtyWithoutRelayout;

    [Test]
    procedure TryFlush_BeforeInterval_ReturnsFalse;

    [Test]
    procedure TryFlush_AfterInterval_AppliesPendingMarkdown;

    [Test]
    procedure TryFlush_IntervalMeasuredFromFirstAppend;

    [Test]
    procedure TryFlush_WhenClean_ReturnsFalse;

    [Test]
    procedure TryFlush_WhenScrolledToBottom_SetsShouldAutoFollow;

    [Test]
    procedure TryFlush_WhenScrolledUp_DoesNotAutoFollow;

    [Test]
    procedure ImageSlot_AfterLayout_IsRequestedWithPendingRequest;

    [Test]
    procedure ImageArrived_TriggersRelayoutExactlyOnce;

    [Test]
    procedure ImageFailed_MarksSlotFailed;

    [Test]
    procedure ImageSlot_SurvivesDocumentUpdate_WhenUrlUnchanged;

    [Test]
    procedure ImageSlotState_UnknownSource_ReturnsUnknown;

    [Test]
    procedure FindText_IsCaseInsensitive_ReturnsRangesWithinRun;

    [Test]
    procedure FindText_AcrossBlocks_ReturnsRangePerBlock;

    [Test]
    procedure FindText_NoMatch_ReturnsEmpty;

    [Test]
    procedure FindText_EmptyNeedle_ReturnsEmpty;

    [Test]
    procedure FindText_NonAsciiNeedle_KeepsSourceOffsets;

    [Test]
    procedure TrySelectNextMatch_FirstSearch_SelectsFirstMatch;

    [Test]
    procedure TrySelectNextMatch_RepeatedSearch_SelectsNextMatch;

    [Test]
    procedure TrySelectNextMatch_AfterLastMatch_WrapsToFirstMatch;

    [Test]
    procedure TrySelectNextMatch_SelectionInsideDocument_SelectsMatchAfterSelection;

    [Test]
    procedure TrySelectNextMatch_NoMatch_ReturnsFalseAndKeepsSelection;

    [Test]
    procedure TrySelectNextMatch_AfterClick_SelectsMatchAfterCaret;

    [Test]
    procedure TrySelectNextMatch_CaretAtMatchStart_SelectsThatMatch;

    [Test]
    procedure TrySelectPreviousMatch_AfterClick_SelectsMatchBeforeCaret;

    [Test]
    procedure TrySelectPreviousMatch_NoSelection_SelectsLastMatch;

    [Test]
    procedure TrySelectPreviousMatch_AfterNextMatch_SelectsMatchBefore;

    [Test]
    procedure HighlightMatches_SeveralMatches_ReturnsRectPerMatch;

    [Test]
    procedure HighlightMatches_EmptyNeedle_HighlightsNothing;

    [Test]
    procedure HighlightMatches_TextChanges_FollowsNewText;

    [Test]
    procedure ClearHighlights_AfterHighlight_RemovesRects;

    [Test]
    procedure HighlightRectsWithin_Viewport_ReturnsOnlyVisibleMarks;

    [Test]
    procedure CodeBlockRegions_Empty_WhenNoCode;

    [Test]
    procedure TryGetCodeBlockAt_InsideCodeBlock_ReturnsTextAndRect;

    [Test]
    procedure TryGetCodeBlockAt_MultiLineCode_KeepsInternalNewlines;

    [Test]
    procedure TryGetCodeBlockAt_OverParagraph_ReturnsFalse;

    [Test]
    procedure TryGetCodeBlockAt_OverHeading_ReturnsFalse;

    [Test]
    procedure CodeBlockRegions_TwoBlocks_ReturnsTwo;

    [Test]
    procedure CodeBlockRegions_OverriddenBlock_IsExcluded;

    [Test]
    procedure SetText_FailingBlockOverride_ShowsWholeDocument;

    [Test]
    procedure SetText_FailingDocumentProcessor_ShowsWholeDocument;

    [Test]
    procedure SetText_FailingBlockOverride_ReportsExtensionError;

    [Test]
    procedure SetText_FailingDocumentProcessor_ReportsExtensionError;
  end;

implementation

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Tests.FailingExtensions;

type
  // Stands in for the chart/mermaid overrides: claims every code block and
  // draws it as a rectangle so the block renders as graphics, not source.
  TFakeCodeBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  public
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single;
      const Context: ILayoutBlockContext): Single;
  end;

function TFakeCodeBlockOverride.GetName: string;
begin
  Result := 'fake';
end;

function TFakeCodeBlockOverride.Handles(const Node: IMarkdownNode): Boolean;
var
  Code: IMarkdownCodeBlock;
begin
  Result := Supports(Node, IMarkdownCodeBlock, Code);
end;

function TFakeCodeBlockOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
const
  BlockHeight = 30.0;
begin
  Context.Canvas.FillRectangle(TLayoutRectF.Create(0, Top, Context.Width, Top + BlockHeight), $FF000000);
  Result := BlockHeight;
end;

procedure TMarkdownViewerModelTests.Setup;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FTheme.ContentPadding := 0;
  FMeasurer := TFakeTextMeasurer.Create;
  FModel := TMarkdownViewerModel.Create(FTheme, FMeasurer);
end;

procedure TMarkdownViewerModelTests.TearDown;
begin
  FModel.Free;
  FModel := nil;

  FMeasurer := nil;

  FTheme.Free;
  FTheme := nil;
end;

procedure TMarkdownViewerModelTests.SetText_LayoutsDocumentOnce;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha';

  Assert.AreEqual(1, FModel.LayoutCount);
  Assert.AreEqual('alpha', FModel.Text);
  Assert.IsNotNull(FModel.DisplayList);
  AssertSingle(BaseLineHeight, FModel.DisplayList.Height);
end;

procedure TMarkdownViewerModelTests.Selection_WithinSingleRun_ProducesSingleRectAndText;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta';

  SelectFromTo(1, 10, 48, 10);

  Assert.IsTrue(FModel.HasSelection);
  Assert.AreEqual('alpha', FModel.SelectedText);

  const Rects = FModel.SelectionRects;
  Assert.AreEqual(1, Integer(Length(Rects)));
  AssertSingle(0, Rects[0].Left);
  AssertSingle(0, Rects[0].Top);
  AssertSingle(5 * BaseCharWidth, Rects[0].Right);
  AssertSingle(BaseLineHeight, Rects[0].Bottom);
end;

procedure TMarkdownViewerModelTests.Selection_AcrossWrappedLines_ProducesRectPerLine;
begin
  FModel.SetViewport(WrapWidthCharacters * BaseCharWidth, DefaultHeight);
  FModel.Text := 'alpha beta gamma';

  SelectFromTo(1, 10, 30, 33);

  Assert.AreEqual('alpha beta gam', FModel.SelectedText);

  const Rects = FModel.SelectionRects;
  Assert.AreEqual(2, Integer(Length(Rects)));
  AssertSingle(0, Rects[0].Left);
  AssertSingle(0, Rects[0].Top);
  AssertSingle(10 * BaseCharWidth, Rects[0].Right);
  AssertSingle(BaseLineHeight, Rects[0].Bottom);
  AssertSingle(0, Rects[1].Left);
  AssertSingle(BaseLineHeight, Rects[1].Top);
  AssertSingle(3 * BaseCharWidth, Rects[1].Right);
  AssertSingle(2 * BaseLineHeight, Rects[1].Bottom);
end;

procedure TMarkdownViewerModelTests.Selection_AcrossParagraphs_JoinsTextWithBlankLine;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'one'#10#10'two';

  SelectFromTo(1, 10, 30, 40);

  Assert.AreEqual('one' + sLineBreak + sLineBreak + 'two', FModel.SelectedText);

  const Rects = FModel.SelectionRects;
  Assert.AreEqual(2, Integer(Length(Rects)));
  AssertSingle(0, Rects[0].Left);
  AssertSingle(3 * BaseCharWidth, Rects[0].Right);
  AssertSingle(BaseLineHeight + BlockSpacingValue, Rects[1].Top);
  AssertSingle(3 * BaseCharWidth, Rects[1].Right);
end;

procedure TMarkdownViewerModelTests.Selection_Backwards_NormalizesToSameText;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta';

  SelectFromTo(48, 10, 1, 10);

  Assert.AreEqual('alpha', FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.ClearSelection_RemovesSelectionState;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta';
  SelectFromTo(1, 10, 48, 10);

  FModel.ClearSelection;

  Assert.IsFalse(FModel.HasSelection);
  Assert.AreEqual('', FModel.SelectedText);
  Assert.AreEqual(0, Integer(Length(FModel.SelectionRects)));
end;

procedure TMarkdownViewerModelTests.SelectAll_AcrossBlocks_SelectsWholeDocument;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'one'#10#10'two';

  Assert.IsTrue(FModel.SelectAll);
  Assert.IsTrue(FModel.HasSelection);
  Assert.AreEqual('one' + sLineBreak + sLineBreak + 'two', FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.SelectAll_BlockWithSeveralLines_KeepsLinesMarkersAndCells(const Markdown,
  Expected: string);
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := Markdown;

  FModel.SelectAll;

  Assert.AreEqual(Expected, FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.SelectWordAt_PointInFirstLine_SelectsWordUnderPointer(const Markdown: string;
  const X: Single; const Expected: string);
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := Markdown;

  const Selected = FModel.SelectWordAt(TLayoutPointF.Create(X, FirstLineY));

  Assert.IsTrue(Selected);
  Assert.AreEqual(Expected, FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.SelectLineAt_Point_SelectsLineOrBlockUnderPointer(const Markdown: string;
  const Width, X, Y: Single; const Expected: string);
begin
  FModel.SetViewport(Width, DefaultHeight);
  FModel.Text := Markdown;

  const Selected = FModel.SelectLineAt(TLayoutPointF.Create(X, Y));

  Assert.IsTrue(Selected);
  Assert.AreEqual(Expected, FModel.SelectedText);
end;

// A smaller code font sits lower on the shared baseline, so its run starts
// below the text around it while it is still on the same line.
procedure TMarkdownViewerModelTests.SelectAll_CodeSpanInSmallerFont_CopiesSingleSpaces;
begin
  FTheme.CodeFont := TMarkdownFontStyle.Create(FTheme.CodeFont.FamilyName, SmallerCodeFontSize);
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'Mit `Code` und **fett**.';

  FModel.SelectAll;

  Assert.AreEqual('Mit Code und fett.', FModel.SelectedText);
end;

// The line wraps where the source has no space: between a bracket and the code
// span after it, or inside a word too wide for the line.
procedure TMarkdownViewerModelTests.SelectAll_LineWrapsWithoutSpace_CopiesNoSpace(const Markdown, Expected: string);
begin
  FModel.SetViewport(WrapWidthCharacters * BaseCharWidth, DefaultHeight);
  FModel.Text := Markdown;

  FModel.SelectAll;

  Assert.AreEqual(Expected, FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.SetSelectionExtent_AfterWordSelection_ExtendsByWholeWords;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta gamma';
  FModel.SelectWordAt(TLayoutPointF.Create(75, FirstLineY));

  FModel.SetSelectionExtent(TLayoutPointF.Create(125, FirstLineY));
  Assert.AreEqual('beta gamma', FModel.SelectedText);

  FModel.SetSelectionExtent(TLayoutPointF.Create(15, FirstLineY));
  Assert.AreEqual('alpha beta', FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.SetSelectionExtent_AfterLineSelection_ExtendsByWholeLines;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '- one'#10'- two'#10'- three';
  FModel.SelectLineAt(TLayoutPointF.Create(40, SecondLineY));

  FModel.SetSelectionExtent(TLayoutPointF.Create(40, ThirdLineY));

  Assert.AreEqual('two' + sLineBreak + #$2022' three', FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.SetSelectionAnchor_AfterWordSelection_SelectsByCharacterAgain;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta gamma';
  FModel.SelectWordAt(TLayoutPointF.Create(75, FirstLineY));

  SelectFromTo(60, FirstLineY, 120, FirstLineY);

  Assert.AreEqual('beta g', FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.SelectWordAt_EmptyDocument_ReturnsFalse;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '';

  const Selected = FModel.SelectWordAt(TLayoutPointF.Create(10, FirstLineY));

  Assert.IsFalse(Selected);
  Assert.IsFalse(FModel.HasSelection);
end;

procedure TMarkdownViewerModelTests.SelectAll_EmptyDocument_LeavesSelectionEmpty;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '';

  Assert.IsFalse(FModel.SelectAll);
  Assert.IsFalse(FModel.HasSelection);
  Assert.AreEqual('', FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.HasSelectableText_FollowsDocumentContent;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);

  FModel.Text := '';
  Assert.IsFalse(FModel.HasSelectableText);

  FModel.Text := 'alpha';
  Assert.IsTrue(FModel.HasSelectableText);
end;

procedure TMarkdownViewerModelTests.AppendMarkdown_MarksDirtyWithoutRelayout;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'one';

  FModel.AppendMarkdown(' two', StartTime);

  Assert.IsTrue(FModel.IsDirty);
  Assert.AreEqual(1, FModel.LayoutCount);
  Assert.AreEqual('one', FModel.Text);
end;

procedure TMarkdownViewerModelTests.TryFlush_BeforeInterval_ReturnsFalse;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.FlushIntervalMilliseconds := FlushIntervalValue;
  FModel.Text := 'one';
  FModel.AppendMarkdown(' two', StartTime);

  Assert.IsFalse(FModel.TryFlush(StartTime + FlushIntervalValue - 1));
  Assert.IsTrue(FModel.IsDirty);
  Assert.AreEqual(1, FModel.LayoutCount);
end;

procedure TMarkdownViewerModelTests.TryFlush_AfterInterval_AppliesPendingMarkdown;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.FlushIntervalMilliseconds := FlushIntervalValue;
  FModel.Text := 'one';
  FModel.AppendMarkdown(' two', StartTime);

  Assert.IsTrue(FModel.TryFlush(StartTime + FlushIntervalValue));
  Assert.IsFalse(FModel.IsDirty);
  Assert.AreEqual('one two', FModel.Text);
  Assert.AreEqual(2, FModel.LayoutCount);
end;

procedure TMarkdownViewerModelTests.TryFlush_IntervalMeasuredFromFirstAppend;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.FlushIntervalMilliseconds := FlushIntervalValue;
  FModel.Text := 'x';
  FModel.AppendMarkdown('a', StartTime);
  FModel.AppendMarkdown('b', StartTime + 80);

  Assert.IsTrue(FModel.TryFlush(StartTime + FlushIntervalValue));
  Assert.AreEqual('xab', FModel.Text);
end;

procedure TMarkdownViewerModelTests.TryFlush_WhenClean_ReturnsFalse;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'one';

  Assert.IsFalse(FModel.TryFlush(StartTime));
  Assert.AreEqual(1, FModel.LayoutCount);
end;

procedure TMarkdownViewerModelTests.TryFlush_WhenScrolledToBottom_SetsShouldAutoFollow;
begin
  FModel.SetViewport(DefaultWidth, SmallHeight);
  FModel.FlushIntervalMilliseconds := FlushIntervalValue;
  FModel.Text := BuildTallMarkdown;
  FModel.ScrollOffset := FModel.DisplayList.Height - SmallHeight;

  Assert.IsTrue(FModel.IsScrolledToBottom);

  FModel.AppendMarkdown(#10#10'tail', StartTime);
  Assert.IsTrue(FModel.TryFlush(StartTime + FlushIntervalValue));
  Assert.IsTrue(FModel.ShouldAutoFollow);
end;

procedure TMarkdownViewerModelTests.TryFlush_WhenScrolledUp_DoesNotAutoFollow;
begin
  FModel.SetViewport(DefaultWidth, SmallHeight);
  FModel.FlushIntervalMilliseconds := FlushIntervalValue;
  FModel.Text := BuildTallMarkdown;
  FModel.ScrollOffset := 0;

  Assert.IsFalse(FModel.IsScrolledToBottom);

  FModel.AppendMarkdown(#10#10'tail', StartTime);
  Assert.IsTrue(FModel.TryFlush(StartTime + FlushIntervalValue));
  Assert.IsFalse(FModel.ShouldAutoFollow);
end;

procedure TMarkdownViewerModelTests.ImageSlot_AfterLayout_IsRequestedWithPendingRequest;
begin
  LoadImageDocument;

  const IsRequested = (FModel.ImageSlotState(ImageSource) = TMarkdownImageSlotState.Requested);
  Assert.IsTrue(IsRequested);

  const Pending = FModel.PendingImageSources;
  Assert.AreEqual(1, Integer(Length(Pending)));
  Assert.AreEqual(ImageSource, Pending[0]);
end;

procedure TMarkdownViewerModelTests.ImageArrived_TriggersRelayoutExactlyOnce;
begin
  LoadImageDocument;
  Assert.AreEqual(1, FModel.LayoutCount);

  FModel.NotifyImageArrived(ImageSource, TLayoutSizeF.Create(LoadedImageWidth, LoadedImageHeight));

  Assert.AreEqual(2, FModel.LayoutCount);
  const IsLoaded = (FModel.ImageSlotState(ImageSource) = TMarkdownImageSlotState.Loaded);
  Assert.IsTrue(IsLoaded);

  var Size: TLayoutSizeF;
  Assert.IsTrue(FModel.TryGetImageSize(ImageSource, Size));
  AssertSingle(LoadedImageWidth, Size.Width);
  AssertSingle(LoadedImageHeight, Size.Height);

  FModel.NotifyImageArrived(ImageSource, TLayoutSizeF.Create(LoadedImageWidth, LoadedImageHeight));
  Assert.AreEqual(2, FModel.LayoutCount);
  Assert.AreEqual(0, Integer(Length(FModel.PendingImageSources)));
end;

procedure TMarkdownViewerModelTests.ImageFailed_MarksSlotFailed;
begin
  LoadImageDocument;

  FModel.NotifyImageFailed(ImageSource);

  const IsFailed = (FModel.ImageSlotState(ImageSource) = TMarkdownImageSlotState.Failed);
  Assert.IsTrue(IsFailed);

  var Size: TLayoutSizeF;
  Assert.IsFalse(FModel.TryGetImageSize(ImageSource, Size));
  Assert.AreEqual(0, Integer(Length(FModel.PendingImageSources)));
end;

procedure TMarkdownViewerModelTests.ImageSlot_SurvivesDocumentUpdate_WhenUrlUnchanged;
begin
  LoadImageDocument;
  FModel.NotifyImageArrived(ImageSource, TLayoutSizeF.Create(LoadedImageWidth, LoadedImageHeight));

  FModel.Text := '# Title'#10#10 + ImageMarkdown;

  const StaysLoaded = (FModel.ImageSlotState(ImageSource) = TMarkdownImageSlotState.Loaded);
  Assert.IsTrue(StaysLoaded);

  var Size: TLayoutSizeF;
  Assert.IsTrue(FModel.TryGetImageSize(ImageSource, Size));
  Assert.AreEqual(0, Integer(Length(FModel.PendingImageSources)));
end;

procedure TMarkdownViewerModelTests.ImageSlotState_UnknownSource_ReturnsUnknown;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'plain';

  const IsUnknown = (FModel.ImageSlotState('missing.png') = TMarkdownImageSlotState.Unknown);
  Assert.IsTrue(IsUnknown);
end;

procedure TMarkdownViewerModelTests.FindText_IsCaseInsensitive_ReturnsRangesWithinRun;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'Alpha beta ALPHA';

  const Ranges = FModel.FindText('alpha');

  Assert.AreEqual(2, Integer(Length(Ranges)));
  Assert.AreEqual(Ranges[0].ItemIndex, Ranges[1].ItemIndex);
  Assert.AreEqual(1, Ranges[0].StartCharacter);
  Assert.AreEqual(5, Ranges[0].CharacterCount);
  Assert.AreEqual(12, Ranges[1].StartCharacter);
  Assert.AreEqual(5, Ranges[1].CharacterCount);

  var Run: IDisplayTextRun;
  Assert.IsTrue(Supports(FModel.DisplayList.Items[Ranges[0].ItemIndex], IDisplayTextRun, Run));
  Assert.IsTrue(SameText('alpha', Copy(Run.Text, Ranges[0].StartCharacter, Ranges[0].CharacterCount)));
end;

procedure TMarkdownViewerModelTests.FindText_AcrossBlocks_ReturnsRangePerBlock;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'one'#10#10'gone';

  const Ranges = FModel.FindText('one');

  Assert.AreEqual(2, Integer(Length(Ranges)));
  const ItemsDiffer = (Ranges[0].ItemIndex <> Ranges[1].ItemIndex);
  Assert.IsTrue(ItemsDiffer);
  Assert.AreEqual(1, Ranges[0].StartCharacter);
  Assert.AreEqual(2, Ranges[1].StartCharacter);
end;

procedure TMarkdownViewerModelTests.FindText_NoMatch_ReturnsEmpty;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta';

  const Matches = FModel.FindText('zulu');
  Assert.AreEqual(0, Integer(Length(Matches)));
end;

procedure TMarkdownViewerModelTests.FindText_EmptyNeedle_ReturnsEmpty;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta';

  const Matches = FModel.FindText('');
  Assert.AreEqual(0, Integer(Length(Matches)));
end;

procedure TMarkdownViewerModelTests.FindText_NonAsciiNeedle_KeepsSourceOffsets;
begin
  const Sharp = #$00DF;
  const AccentLower = #$00E9;
  const AccentUpper = #$00C9;
  const LowerWord = 'caf' + AccentLower;

  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'gro' + Sharp + ' ' + LowerWord;

  const Ranges = FModel.FindText('CAF' + AccentUpper);

  Assert.AreEqual(1, Integer(Length(Ranges)));
  Assert.AreEqual(6, Ranges[0].StartCharacter);
  Assert.AreEqual(4, Ranges[0].CharacterCount);

  var Run: IDisplayTextRun;
  Assert.IsTrue(Supports(FModel.DisplayList.Items[Ranges[0].ItemIndex], IDisplayTextRun, Run));
  Assert.AreEqual(LowerWord, Copy(Run.Text, Ranges[0].StartCharacter, Ranges[0].CharacterCount));
end;

procedure TMarkdownViewerModelTests.TrySelectNextMatch_FirstSearch_SelectsFirstMatch;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'Alpha beta alpha';

  var Match: TMarkdownFoundRange;
  const Found = FModel.TrySelectNextMatch('alpha', Match);

  Assert.IsTrue(Found);
  Assert.AreEqual(1, Match.StartCharacter);
  Assert.AreEqual('Alpha', FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.TrySelectNextMatch_RepeatedSearch_SelectsNextMatch;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'Alpha beta alpha';

  var Match: TMarkdownFoundRange;
  FModel.TrySelectNextMatch('alpha', Match);
  FModel.TrySelectNextMatch('alpha', Match);

  Assert.AreEqual(12, Match.StartCharacter);
  Assert.AreEqual('alpha', FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.TrySelectNextMatch_AfterLastMatch_WrapsToFirstMatch;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'one'#10#10'gone';

  var Match: TMarkdownFoundRange;
  FModel.TrySelectNextMatch('one', Match);
  const FirstItemIndex = Match.ItemIndex;
  FModel.TrySelectNextMatch('one', Match);
  FModel.TrySelectNextMatch('one', Match);

  Assert.AreEqual(FirstItemIndex, Match.ItemIndex);
  Assert.AreEqual(1, Match.StartCharacter);
end;

procedure TMarkdownViewerModelTests.TrySelectNextMatch_SelectionInsideDocument_SelectsMatchAfterSelection;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta alpha';
  FModel.SelectWordAt(TLayoutPointF.Create(75, FirstLineY));

  var Match: TMarkdownFoundRange;
  FModel.TrySelectNextMatch('alpha', Match);

  Assert.AreEqual(12, Match.StartCharacter);
end;

procedure TMarkdownViewerModelTests.TrySelectNextMatch_NoMatch_ReturnsFalseAndKeepsSelection;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta';

  var Match: TMarkdownFoundRange;
  FModel.TrySelectNextMatch('beta', Match);
  const Found = FModel.TrySelectNextMatch('zulu', Match);

  Assert.IsFalse(Found);
  Assert.AreEqual('beta', FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.TrySelectNextMatch_AfterClick_SelectsMatchAfterCaret;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta alpha';
  FModel.SetSelectionAnchor(TLayoutPointF.Create(75, FirstLineY));

  var Match: TMarkdownFoundRange;
  FModel.TrySelectNextMatch('alpha', Match);

  Assert.AreEqual(12, Match.StartCharacter);
end;

procedure TMarkdownViewerModelTests.TrySelectNextMatch_CaretAtMatchStart_SelectsThatMatch;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta alpha';
  FModel.SetSelectionAnchor(TLayoutPointF.Create(110, FirstLineY));

  var Match: TMarkdownFoundRange;
  FModel.TrySelectNextMatch('alpha', Match);

  Assert.AreEqual(12, Match.StartCharacter);
end;

procedure TMarkdownViewerModelTests.TrySelectPreviousMatch_AfterClick_SelectsMatchBeforeCaret;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta alpha';
  FModel.SetSelectionAnchor(TLayoutPointF.Create(75, FirstLineY));

  var Match: TMarkdownFoundRange;
  FModel.TrySelectPreviousMatch('alpha', Match);

  Assert.AreEqual(1, Match.StartCharacter);
end;

procedure TMarkdownViewerModelTests.TrySelectPreviousMatch_NoSelection_SelectsLastMatch;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'Alpha beta alpha';

  var Match: TMarkdownFoundRange;
  const Found = FModel.TrySelectPreviousMatch('alpha', Match);

  Assert.IsTrue(Found);
  Assert.AreEqual(12, Match.StartCharacter);
  Assert.AreEqual('alpha', FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.TrySelectPreviousMatch_AfterNextMatch_SelectsMatchBefore;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'Alpha beta alpha';

  var Match: TMarkdownFoundRange;
  FModel.TrySelectNextMatch('alpha', Match);
  FModel.TrySelectNextMatch('alpha', Match);
  FModel.TrySelectPreviousMatch('alpha', Match);

  Assert.AreEqual(1, Match.StartCharacter);
  Assert.AreEqual('Alpha', FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.HighlightMatches_SeveralMatches_ReturnsRectPerMatch;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta alpha';

  FModel.HighlightMatches('alpha');

  const Rects = AllHighlightRects;
  Assert.AreEqual(2, FModel.HighlightCount);
  Assert.AreEqual(2, Integer(Length(Rects)));
  AssertSingle(Rects[0].Top, Rects[1].Top);
  AssertSingle(Rects[0].Width, Rects[1].Width);
  const IsSecondToTheRight = (Rects[1].Left >= Rects[0].Right);
  Assert.IsTrue(IsSecondToTheRight);
end;

procedure TMarkdownViewerModelTests.HighlightMatches_EmptyNeedle_HighlightsNothing;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta alpha';

  FModel.HighlightMatches('');

  Assert.AreEqual(0, FModel.HighlightCount);
  Assert.AreEqual(0, Integer(Length(AllHighlightRects)));
end;

procedure TMarkdownViewerModelTests.HighlightMatches_TextChanges_FollowsNewText;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha';
  FModel.HighlightMatches('alpha');

  FModel.Text := 'alpha beta alpha gamma alpha';

  Assert.AreEqual(3, FModel.HighlightCount);
end;

procedure TMarkdownViewerModelTests.ClearHighlights_AfterHighlight_RemovesRects;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta alpha';
  FModel.HighlightMatches('alpha');

  FModel.ClearHighlights;
  FModel.Text := 'alpha again';

  Assert.AreEqual(0, FModel.HighlightCount);
  Assert.AreEqual(0, Integer(Length(AllHighlightRects)));
end;

procedure TMarkdownViewerModelTests.HighlightRectsWithin_Viewport_ReturnsOnlyVisibleMarks;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := BuildTallMarkdown + #10#10'needle';
  FModel.HighlightMatches('Paragraph');

  const FirstRect = AllHighlightRects[0];
  const Viewport = TLayoutRectF.Create(0, FirstRect.Top, DefaultWidth, FirstRect.Bottom);
  const Visible = FModel.HighlightRectsWithin(Viewport);

  Assert.AreEqual(1, Integer(Length(Visible)));
  AssertSingle(FirstRect.Top, Visible[0].Top);
end;

procedure TMarkdownViewerModelTests.CodeBlockRegions_Empty_WhenNoCode;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'plain paragraph';

  Assert.AreEqual(0, Integer(Length(FModel.CodeBlockRegions)));
end;

procedure TMarkdownViewerModelTests.TryGetCodeBlockAt_InsideCodeBlock_ReturnsTextAndRect;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := Fence + #10 + 'alpha' + #10 + Fence;

  const Regions = FModel.CodeBlockRegions;
  Assert.AreEqual(1, Integer(Length(Regions)));
  const FirstRegion = Regions[0];

  var Region: TMarkdownCodeBlockRegion;
  const Center = TLayoutPointF.Create((FirstRegion.Rect.Left + FirstRegion.Rect.Right) / 2, (FirstRegion.Rect.Top + FirstRegion.Rect.Bottom) / 2);
  Assert.IsTrue(FModel.TryGetCodeBlockAt(Center, Region));
  Assert.AreEqual('alpha', Region.Text);
  AssertSingle(FirstRegion.Rect.Left, Region.Rect.Left);
  AssertSingle(FirstRegion.Rect.Top, Region.Rect.Top);
  AssertSingle(FirstRegion.Rect.Right, Region.Rect.Right);
  AssertSingle(FirstRegion.Rect.Bottom, Region.Rect.Bottom);
end;

procedure TMarkdownViewerModelTests.TryGetCodeBlockAt_MultiLineCode_KeepsInternalNewlines;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := Fence + #10 + 'alpha'#10'beta' + #10 + Fence;

  const Regions = FModel.CodeBlockRegions;
  Assert.AreEqual(1, Integer(Length(Regions)));
  const FirstRegion = Regions[0];

  var Region: TMarkdownCodeBlockRegion;
  const Center = TLayoutPointF.Create((FirstRegion.Rect.Left + FirstRegion.Rect.Right) / 2, (FirstRegion.Rect.Top + FirstRegion.Rect.Bottom) / 2);
  Assert.IsTrue(FModel.TryGetCodeBlockAt(Center, Region));
  Assert.AreEqual('alpha'#10'beta', Region.Text);
end;

procedure TMarkdownViewerModelTests.TryGetCodeBlockAt_OverParagraph_ReturnsFalse;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'para'#10#10 + Fence + #10 + 'code' + #10 + Fence;

  var Region: TMarkdownCodeBlockRegion;
  Assert.IsFalse(FModel.TryGetCodeBlockAt(TLayoutPointF.Create(1, 0.5), Region));

  const Regions = FModel.CodeBlockRegions;
  Assert.AreEqual(1, Integer(Length(Regions)));
  const FirstRegion = Regions[0];
  const Center = TLayoutPointF.Create((FirstRegion.Rect.Left + FirstRegion.Rect.Right) / 2, (FirstRegion.Rect.Top + FirstRegion.Rect.Bottom) / 2);
  Assert.IsTrue(FModel.TryGetCodeBlockAt(Center, Region));
end;

procedure TMarkdownViewerModelTests.TryGetCodeBlockAt_OverHeading_ReturnsFalse;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '# Heading'#10#10 + Fence + #10 + 'code' + #10 + Fence;

  var Region: TMarkdownCodeBlockRegion;
  Assert.IsFalse(FModel.TryGetCodeBlockAt(TLayoutPointF.Create(1, 0.5), Region));
end;

procedure TMarkdownViewerModelTests.CodeBlockRegions_TwoBlocks_ReturnsTwo;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := Fence + #10 + 'a' + #10 + Fence + #10#10 + 'mid' + #10#10 + Fence + #10 + 'b' + #10 + Fence;

  const Regions = FModel.CodeBlockRegions;
  Assert.AreEqual(2, Integer(Length(Regions)));
  Assert.IsTrue(Regions[0].Rect.Top < Regions[1].Rect.Top);
end;

procedure TMarkdownViewerModelTests.CodeBlockRegions_OverriddenBlock_IsExcluded;
begin
  TLayoutBlockOverrideRegistry.Register(TFakeCodeBlockOverride.Create, 0);
  try
    FModel.SetViewport(DefaultWidth, DefaultHeight);
    FModel.Text := Fence + #10 + 'x' + #10 + Fence;

    Assert.AreEqual(0, Integer(Length(FModel.CodeBlockRegions)));
  finally
    TLayoutBlockOverrideRegistry.Clear;
  end;
end;

procedure TMarkdownViewerModelTests.SetText_FailingBlockOverride_ShowsWholeDocument;
begin
  TLayoutBlockOverrideRegistry.Register(TFailingCodeBlockOverride.Create, 100);
  try
    FModel.SetViewport(DefaultWidth, DefaultHeight);
    FModel.Text := '# Title'#10#10 + Fence + #10 + 'code' + #10 + Fence + #10#10 + 'After';

    FModel.SelectAll;

    Assert.AreEqual('Title'#13#10#13#10'code'#13#10#13#10'After', FModel.SelectedText);
  finally
    TLayoutBlockOverrideRegistry.Clear;
  end;
end;

procedure TMarkdownViewerModelTests.SetText_FailingDocumentProcessor_ShowsWholeDocument;
begin
  TLayoutDocumentProcessorRegistry.Register(TFailingDocumentProcessor.ProcessorName, TFailingDocumentProcessor.Create);
  try
    FModel.SetViewport(DefaultWidth, DefaultHeight);
    FModel.Text := '# Title'#10#10'After';

    FModel.SelectAll;

    Assert.AreEqual('Title'#13#10#13#10'After', FModel.SelectedText);
  finally
    TLayoutDocumentProcessorRegistry.Clear;
  end;
end;

procedure TMarkdownViewerModelTests.SetText_FailingBlockOverride_ReportsExtensionError;
begin
  TLayoutBlockOverrideRegistry.Register(TFailingCodeBlockOverride.Create, 100);
  try
    FModel.OnExtensionError := RecordExtensionError;
    FModel.SetViewport(DefaultWidth, DefaultHeight);

    FModel.Text := Fence + #10 + 'code' + #10 + Fence;

    Assert.AreSame(FModel, FReportedSender);
    Assert.AreEqual(TFailingCodeBlockOverride.OverrideName, FReportedExtension);
    Assert.AreEqual(TFailingCodeBlockOverride.FailureMessage, FReportedMessage);
  finally
    TLayoutBlockOverrideRegistry.Clear;
  end;
end;

procedure TMarkdownViewerModelTests.SetText_FailingDocumentProcessor_ReportsExtensionError;
begin
  TLayoutDocumentProcessorRegistry.Register(TFailingDocumentProcessor.ProcessorName, TFailingDocumentProcessor.Create);
  try
    FModel.OnExtensionError := RecordExtensionError;
    FModel.SetViewport(DefaultWidth, DefaultHeight);

    FModel.Text := 'text';

    Assert.AreEqual(TFailingDocumentProcessor.ProcessorName, FReportedExtension);
    Assert.AreEqual(TFailingDocumentProcessor.FailureMessage, FReportedMessage);
  finally
    TLayoutDocumentProcessorRegistry.Clear;
  end;
end;

procedure TMarkdownViewerModelTests.RecordExtensionError(const Sender: TObject; const Extension: string;
  const Error: Exception);
begin
  FReportedSender := Sender;
  FReportedExtension := Extension;
  FReportedMessage := Error.Message;
end;

class function TMarkdownViewerModelTests.BuildTallMarkdown: string;
begin
  Result := '';

  for var Index := 1 to TallParagraphCount do
  begin
    if Result <> '' then
      Result := Result + #10#10;
    Result := Result + Format('paragraph%d', [Index]);
  end;
end;

function TMarkdownViewerModelTests.AllHighlightRects: TArray<TLayoutRectF>;
begin
  const WholeDocument = TLayoutRectF.Create(0, 0, DefaultWidth, FModel.DisplayList.Height);
  Result := FModel.HighlightRectsWithin(WholeDocument);
end;

class procedure TMarkdownViewerModelTests.AssertSingle(const Expected, Actual: Single);
begin
  Assert.AreEqual(Double(Expected), Double(Actual), SingleTolerance);
end;

procedure TMarkdownViewerModelTests.SelectFromTo(const AnchorX, AnchorY, ExtentX, ExtentY: Single);
begin
  FModel.SetSelectionAnchor(TLayoutPointF.Create(AnchorX, AnchorY));
  FModel.SetSelectionExtent(TLayoutPointF.Create(ExtentX, ExtentY));
end;

procedure TMarkdownViewerModelTests.LoadImageDocument;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := ImageMarkdown;
end;

end.
