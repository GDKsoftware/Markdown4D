unit Markdown4D.Layout.Engine.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme;

type
  [TestFixture]
  TMarkdownLayoutEngineTests = class
  private
    const
      BaseFamilyName = 'Test Sans';
      CodeFamilyName = 'Test Mono';
      BulletMarkerText = #$2022;
      OriginalFragment = 'steadyfill';
      EditedFragment = 'editedfill';
      BaseFontSize = 16.0;
      BaseCharWidth = 10.0;
      BoldCharWidth = 12.0;
      BaseLineHeight = 22.4;
      BaseBaseline = 12.8;
      HeadingOneFontSize = 32.0;
      HeadingOneCharWidth = 24.0;
      HeadingOneLineHeight = 44.8;
      ParagraphSpacingValue = 8.0;
      HeadingOneSpacingAbove = 20.0;
      HeadingOneSpacingBelow = 12.0;
      ListIndentValue = 30.0;
      ListMarkerWidthValue = 20.0;
      BlockQuoteBarWidthValue = 4.0;
      BlockQuoteInsetValue = 16.0;
      CodePaddingValue = 0.0;
      TableCellPaddingValue = 5.0;
      TableMinColumnWidthValue = 40.0;
      TableMaxColumnWidthValue = 200.0;
      ImagePlaceholderWidthValue = 80.0;
      ImagePlaceholderHeightValue = 60.0;
      CheckboxSizeValue = 14.0;
      ThematicBreakThicknessValue = 2.0;
      ContentPaddingValue = 16.0;
      TextColorValue = $FF202020;
      LinkColorValue = $FF0A66C2;
      CodeBackgroundColorValue = $FFF0F0F0;
      CodeSpanBackgroundColorValue = $FFEEEEEE;
      CodeSpanChipPaddingValue = 3.0;
      BlockQuoteBarColorValue = $FFC0C0C0;
      TableHeaderBackgroundColorValue = $FFE8E8E8;
      ThematicBreakColorValue = $FFB0B0B0;
      DefaultWidth = 300.0;
      SingleTolerance = 0.05;
      FullLayoutBudgetMilliseconds = 200;
      IncrementalLayoutBudgetMilliseconds = 10;
      PerformanceWidth = 800.0;
      LargeDocumentMinimumLength = 100 * 1024;
      PerformanceParagraphCount = 1500;
    class function CreateTestTheme: TMarkdownTheme;
    class function LayoutMarkdown(const Source: string; const AvailableWidth: Single): IMarkdownDisplayList;
    class function LayoutMarkdownUncapped(const Source: string; const AvailableWidth: Single): IMarkdownDisplayList;
    class function LayoutMarkdownWithPadding(const Source: string;
      const AvailableWidth, Padding: Single): IMarkdownDisplayList;
    class function TextRunsOf(const DisplayList: IMarkdownDisplayList): TArray<IDisplayTextRun>;
    class function RunsWithText(const Runs: TArray<IDisplayTextRun>; const Text: string): TArray<IDisplayTextRun>;
    class function FindRunByPrefix(const Runs: TArray<IDisplayTextRun>; const Prefix: string): IDisplayTextRun;
    class function FirstRectangleWithFill(const DisplayList: IMarkdownDisplayList;
      const FillColor: TLayoutColor): IDisplayRectangle;
    class function RectanglesWithFill(const DisplayList: IMarkdownDisplayList;
      const FillColor: TLayoutColor): TArray<IDisplayRectangle>;
    class function IndexOfFirstRectangleWithFill(const DisplayList: IMarkdownDisplayList;
      const FillColor: TLayoutColor): Integer;
    class function IndexOfFirstRunWithPrefix(const DisplayList: IMarkdownDisplayList; const Prefix: string): Integer;
    class function FirstImageOf(const DisplayList: IMarkdownDisplayList): IDisplayImage;
    class function FirstLineOf(const DisplayList: IMarkdownDisplayList): IDisplayLine;
    class function CheckboxesOf(const DisplayList: IMarkdownDisplayList): TArray<IDisplayCheckbox>;
    class function BuildLargeDocumentSource: string;
    class function BuildUniformParagraphs: TArray<string>;
    class function JoinParagraphs(const Paragraphs: TArray<string>): string;
    class procedure AssertSingle(const Expected, Actual: Single);
    class procedure AssertColor(const Expected, Actual: TLayoutColor);

  public
    [Test]
    procedure Layout_EmptyDocument_ReturnsEmptyDisplayListWithZeroHeight;

    [Test]
    procedure Layout_ContentPadding_OffsetsOriginShrinksWrapAndAddsBottomPadding;

    [Test]
    procedure Layout_Paragraph_WrapsWordsAtAvailableWidth;

    [Test]
    procedure Layout_Paragraph_CollapsesTrailingSpaceAtLineBreak;

    [Test]
    procedure Layout_Paragraph_ForcesBreakInsideLongWord;

    [Test]
    procedure Layout_Paragraphs_AppliesBlockSpacingBetweenBlocks;

    [Test]
    procedure Layout_Heading_UsesThemeFontAndSpacing;

    [Test]
    procedure Layout_NestedList_IndentsMarkersAndContentPerLevel;

    [Test]
    procedure Layout_OrderedList_RendersSequentialMarkerText;

    [Test]
    procedure Layout_BlockQuote_EmitsBarRectAndInsetsContent;

    [Test]
    procedure Layout_FencedCode_EmitsBackgroundAndMonospaceRunsWithoutWrapping;

    [Test]
    procedure Layout_Table_ComputesColumnWidthsWithMinClampAndAlignment;

    [Test]
    procedure Layout_Table_ClampsColumnToMaxWidthAndWrapsCell;

    [Test]
    procedure Layout_Table_UncappedColumn_SizesToContentWithoutWrapping;

    [Test]
    procedure Layout_Table_UncappedColumns_ShrinkToAvailableWidth;

    [Test]
    procedure Layout_Image_EmitsPlaceholderWithSourceUrl;

    [Test]
    procedure Layout_ThematicBreak_EmitsLinePrimitive;

    [Test]
    procedure Layout_TaskListItems_EmitCheckboxPrimitives;

    [Test]
    procedure Layout_BoldRuns_ShiftWrapPositions;

    [Test]
    procedure Layout_ItalicRun_UsesItalicFont;

    [Test]
    procedure Layout_CodeSpanInHeading_AlignsRunBaselines;

    [Test]
    procedure Layout_CodeSpan_EmitsBackgroundChipBehindRunWithPadding;

    [Test]
    procedure Layout_WrappedCodeSpan_EmitsChipPerLine;

    [Test]
    procedure Layout_LargeDocument_CompletesWithinBudget;

    [Test]
    procedure UpdateLayout_SmallEdit_CompletesWithinBudget;
  end;

implementation

uses
  System.SysUtils,
  System.Diagnostics,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.FakeMeasurer;

procedure TMarkdownLayoutEngineTests.Layout_EmptyDocument_ReturnsEmptyDisplayListWithZeroHeight;
begin
  const DisplayList = LayoutMarkdown('', DefaultWidth);

  Assert.AreEqual(0, DisplayList.ItemCount);
  Assert.AreEqual(0, DisplayList.BlockCount);
  AssertSingle(0, DisplayList.Height);
end;

procedure TMarkdownLayoutEngineTests.Layout_ContentPadding_OffsetsOriginShrinksWrapAndAddsBottomPadding;
begin
  const Word = StringOfChar('a', 10);
  const Source = Word + ' ' + Word + ' ' + Word + ' bbbb';
  const DisplayList = LayoutMarkdownWithPadding(Source, 400, ContentPaddingValue);

  const Runs = TextRunsOf(DisplayList);
  Assert.AreEqual(2, Length(Runs));

  const ExpectedFirstLine = Word + ' ' + Word + ' ' + Word;
  Assert.AreEqual(ExpectedFirstLine, Runs[0].Text);
  AssertSingle(ContentPaddingValue, Runs[0].Bounds.Left);
  AssertSingle(ContentPaddingValue, Runs[0].Bounds.Top);
  AssertSingle(32 * BaseCharWidth, Runs[0].Bounds.Width);

  Assert.AreEqual('bbbb', Runs[1].Text);
  AssertSingle(ContentPaddingValue, Runs[1].Bounds.Left);
  AssertSingle(ContentPaddingValue + BaseLineHeight, Runs[1].Bounds.Top);

  AssertSingle(2 * ContentPaddingValue + 2 * BaseLineHeight, DisplayList.Height);
end;

procedure TMarkdownLayoutEngineTests.Layout_Paragraph_WrapsWordsAtAvailableWidth;
begin
  const DisplayList = LayoutMarkdown('alpha beta gamma', 12 * BaseCharWidth);

  const Runs = TextRunsOf(DisplayList);
  Assert.AreEqual(2, Length(Runs));

  Assert.AreEqual('alpha beta', Runs[0].Text);
  AssertSingle(0, Runs[0].Bounds.Left);
  AssertSingle(0, Runs[0].Bounds.Top);
  AssertSingle(10 * BaseCharWidth, Runs[0].Bounds.Width);
  AssertSingle(BaseBaseline, Runs[0].Baseline);

  Assert.AreEqual('gamma', Runs[1].Text);
  AssertSingle(0, Runs[1].Bounds.Left);
  AssertSingle(BaseLineHeight, Runs[1].Bounds.Top);
  AssertSingle(5 * BaseCharWidth, Runs[1].Bounds.Width);

  AssertSingle(2 * BaseLineHeight, DisplayList.Height);

  Assert.IsNotNull(Runs[0].Node);
  const IsTextNode = (Runs[0].Node.Kind = TMarkdownNodeKind.Text);
  Assert.IsTrue(IsTextNode);
end;

procedure TMarkdownLayoutEngineTests.Layout_Paragraph_CollapsesTrailingSpaceAtLineBreak;
begin
  const DisplayList = LayoutMarkdown('alpha beta', 5 * BaseCharWidth);

  const Runs = TextRunsOf(DisplayList);
  Assert.AreEqual(2, Length(Runs));

  Assert.AreEqual('alpha', Runs[0].Text);
  AssertSingle(5 * BaseCharWidth, Runs[0].Bounds.Width);

  Assert.AreEqual('beta', Runs[1].Text);
  AssertSingle(BaseLineHeight, Runs[1].Bounds.Top);
end;

procedure TMarkdownLayoutEngineTests.Layout_Paragraph_ForcesBreakInsideLongWord;
begin
  const DisplayList = LayoutMarkdown(StringOfChar('a', 30), 10 * BaseCharWidth);

  const Runs = TextRunsOf(DisplayList);
  Assert.AreEqual(3, Length(Runs));

  const ExpectedLineText = StringOfChar('a', 10);
  for var Index := 0 to Length(Runs) - 1 do
  begin
    Assert.AreEqual(ExpectedLineText, Runs[Index].Text);
    AssertSingle(0, Runs[Index].Bounds.Left);
    AssertSingle(Index * BaseLineHeight, Runs[Index].Bounds.Top);
  end;

  AssertSingle(3 * BaseLineHeight, DisplayList.Height);
end;

procedure TMarkdownLayoutEngineTests.Layout_Paragraphs_AppliesBlockSpacingBetweenBlocks;
begin
  const DisplayList = LayoutMarkdown('one'#10#10'two', DefaultWidth);

  const Runs = TextRunsOf(DisplayList);
  Assert.AreEqual(2, Length(Runs));

  AssertSingle(0, Runs[0].Bounds.Top);
  AssertSingle(BaseLineHeight + ParagraphSpacingValue, Runs[1].Bounds.Top);
  AssertSingle(2 * BaseLineHeight + ParagraphSpacingValue, DisplayList.Height);
end;

procedure TMarkdownLayoutEngineTests.Layout_Heading_UsesThemeFontAndSpacing;
begin
  const DisplayList = LayoutMarkdown('# Title'#10#10'Body', DefaultWidth);

  const Runs = TextRunsOf(DisplayList);
  Assert.AreEqual(2, Length(Runs));

  Assert.AreEqual('Title', Runs[0].Text);
  Assert.AreEqual(BaseFamilyName, Runs[0].Font.FamilyName);
  AssertSingle(HeadingOneFontSize, Runs[0].Font.Size);
  Assert.IsTrue(Runs[0].Font.Bold);
  AssertSingle(0, Runs[0].Bounds.Top);
  AssertSingle(5 * HeadingOneCharWidth, Runs[0].Bounds.Width);

  const BodyTop = HeadingOneLineHeight + HeadingOneSpacingBelow;
  Assert.AreEqual('Body', Runs[1].Text);
  AssertSingle(BodyTop, Runs[1].Bounds.Top);
  AssertSingle(BodyTop + BaseLineHeight, DisplayList.Height);
end;

procedure TMarkdownLayoutEngineTests.Layout_NestedList_IndentsMarkersAndContentPerLevel;
begin
  const DisplayList = LayoutMarkdown('- one'#10'  - two', DefaultWidth);

  const Runs = TextRunsOf(DisplayList);
  const Markers = RunsWithText(Runs, BulletMarkerText);
  Assert.AreEqual(2, Length(Markers));

  AssertSingle(0, Markers[0].Bounds.Left);
  AssertSingle(ListIndentValue, Markers[1].Bounds.Left);

  const OuterContent = FindRunByPrefix(Runs, 'one');
  Assert.IsNotNull(OuterContent);
  AssertSingle(ListMarkerWidthValue, OuterContent.Bounds.Left);
  AssertSingle(0, OuterContent.Bounds.Top);

  const NestedContent = FindRunByPrefix(Runs, 'two');
  Assert.IsNotNull(NestedContent);
  AssertSingle(ListIndentValue + ListMarkerWidthValue, NestedContent.Bounds.Left);
  AssertSingle(BaseLineHeight, NestedContent.Bounds.Top);
end;

procedure TMarkdownLayoutEngineTests.Layout_OrderedList_RendersSequentialMarkerText;
begin
  const DisplayList = LayoutMarkdown('3. three'#10'4. four', DefaultWidth);

  const Runs = TextRunsOf(DisplayList);
  const FirstMarker = FindRunByPrefix(Runs, '3.');
  Assert.IsNotNull(FirstMarker);
  AssertSingle(0, FirstMarker.Bounds.Left);
  AssertSingle(0, FirstMarker.Bounds.Top);

  const SecondMarker = FindRunByPrefix(Runs, '4.');
  Assert.IsNotNull(SecondMarker);
  AssertSingle(BaseLineHeight, SecondMarker.Bounds.Top);

  const FirstContent = FindRunByPrefix(Runs, 'three');
  Assert.IsNotNull(FirstContent);
  AssertSingle(ListMarkerWidthValue, FirstContent.Bounds.Left);
end;

procedure TMarkdownLayoutEngineTests.Layout_BlockQuote_EmitsBarRectAndInsetsContent;
begin
  const DisplayList = LayoutMarkdown('> quote', DefaultWidth);

  const Bar = FirstRectangleWithFill(DisplayList, BlockQuoteBarColorValue);
  Assert.IsNotNull(Bar);
  AssertSingle(0, Bar.Bounds.Left);
  AssertSingle(BlockQuoteBarWidthValue, Bar.Bounds.Width);
  AssertSingle(BaseLineHeight, Bar.Bounds.Height);

  const QuoteRun = FindRunByPrefix(TextRunsOf(DisplayList), 'quote');
  Assert.IsNotNull(QuoteRun);
  AssertSingle(BlockQuoteInsetValue, QuoteRun.Bounds.Left);
end;

procedure TMarkdownLayoutEngineTests.Layout_FencedCode_EmitsBackgroundAndMonospaceRunsWithoutWrapping;
begin
  const Source = '```'#10 + StringOfChar('a', 40) + #10'ok'#10'```';
  const AvailableWidth = 20 * BaseCharWidth;
  const DisplayList = LayoutMarkdown(Source, AvailableWidth);

  const Background = FirstRectangleWithFill(DisplayList, CodeBackgroundColorValue);
  Assert.IsNotNull(Background);
  AssertSingle(0, Background.Bounds.Left);
  AssertSingle(AvailableWidth, Background.Bounds.Width);
  AssertSingle(2 * BaseLineHeight, Background.Bounds.Height);

  const Runs = TextRunsOf(DisplayList);
  Assert.AreEqual(2, Length(Runs));

  Assert.AreEqual(CodeFamilyName, Runs[0].Font.FamilyName);
  AssertSingle(40 * BaseCharWidth, Runs[0].Bounds.Width);

  Assert.AreEqual('ok', Runs[1].Text);
  AssertSingle(BaseLineHeight, Runs[1].Bounds.Top);

  AssertSingle(40 * BaseCharWidth, DisplayList.ContentWidth);
  AssertSingle(AvailableWidth, DisplayList.Width);
end;

procedure TMarkdownLayoutEngineTests.Layout_Table_ComputesColumnWidthsWithMinClampAndAlignment;
begin
  const Source = '| a | bbbbbbbb |'#10'|:---|---:|'#10'| c | dd |';
  const DisplayList = LayoutMarkdown(Source, DefaultWidth);

  const FirstColumnWidth = TableMinColumnWidthValue;
  const SecondColumnWidth = 8 * BoldCharWidth + 2 * TableCellPaddingValue;

  const Header = FirstRectangleWithFill(DisplayList, TableHeaderBackgroundColorValue);
  Assert.IsNotNull(Header);
  AssertSingle(0, Header.Bounds.Left);
  AssertSingle(FirstColumnWidth + SecondColumnWidth, Header.Bounds.Width);
  AssertSingle(BaseLineHeight, Header.Bounds.Height);

  const Runs = TextRunsOf(DisplayList);
  const HeaderCell = FindRunByPrefix(Runs, 'bbbbbbbb');
  Assert.IsNotNull(HeaderCell);
  Assert.IsTrue(HeaderCell.Font.Bold);
  AssertSingle(FirstColumnWidth + SecondColumnWidth - TableCellPaddingValue - 8 * BoldCharWidth, HeaderCell.Bounds.Left);

  const LeftCell = FindRunByPrefix(Runs, 'c');
  Assert.IsNotNull(LeftCell);
  Assert.IsFalse(LeftCell.Font.Bold);
  AssertSingle(TableCellPaddingValue, LeftCell.Bounds.Left);
  AssertSingle(BaseLineHeight, LeftCell.Bounds.Top);

  const RightCell = FindRunByPrefix(Runs, 'dd');
  Assert.IsNotNull(RightCell);
  AssertSingle(FirstColumnWidth + SecondColumnWidth - TableCellPaddingValue - 2 * BaseCharWidth, RightCell.Bounds.Left);
end;

procedure TMarkdownLayoutEngineTests.Layout_Table_ClampsColumnToMaxWidthAndWrapsCell;
begin
  const Source = '| ' + StringOfChar('b', 30) + ' |'#10'|---|'#10'| x |';
  const DisplayList = LayoutMarkdown(Source, 400);

  const Header = FirstRectangleWithFill(DisplayList, TableHeaderBackgroundColorValue);
  Assert.IsNotNull(Header);
  AssertSingle(TableMaxColumnWidthValue, Header.Bounds.Width);
  AssertSingle(2 * BaseLineHeight, Header.Bounds.Height);

  const Runs = TextRunsOf(DisplayList);
  Assert.AreEqual(3, Length(Runs));

  Assert.AreEqual(StringOfChar('b', 15), Runs[0].Text);
  Assert.AreEqual(StringOfChar('b', 15), Runs[1].Text);
  AssertSingle(BaseLineHeight, Runs[1].Bounds.Top);

  Assert.AreEqual('x', Runs[2].Text);
  AssertSingle(2 * BaseLineHeight, Runs[2].Bounds.Top);
end;

procedure TMarkdownLayoutEngineTests.Layout_Table_UncappedColumn_SizesToContentWithoutWrapping;
begin
  const Source = '| ' + StringOfChar('b', 30) + ' |'#10'|---|'#10'| x |';
  const DisplayList = LayoutMarkdownUncapped(Source, 500);

  const Header = FirstRectangleWithFill(DisplayList, TableHeaderBackgroundColorValue);
  Assert.IsNotNull(Header);
  AssertSingle(30 * BoldCharWidth + 2 * TableCellPaddingValue, Header.Bounds.Width);
  AssertSingle(BaseLineHeight, Header.Bounds.Height);

  const Runs = TextRunsOf(DisplayList);
  const HeaderRun = FindRunByPrefix(Runs, 'b');
  Assert.IsNotNull(HeaderRun);
  Assert.AreEqual(StringOfChar('b', 30), HeaderRun.Text);
end;

procedure TMarkdownLayoutEngineTests.Layout_Table_UncappedColumns_ShrinkToAvailableWidth;
begin
  const Cell = StringOfChar('b', 30);
  const Source = '| ' + Cell + ' | ' + Cell + ' |'#10'|---|---|'#10'| x | y |';
  const AvailableWidth = 400.0;
  const DisplayList = LayoutMarkdownUncapped(Source, AvailableWidth);

  const Header = FirstRectangleWithFill(DisplayList, TableHeaderBackgroundColorValue);
  Assert.IsNotNull(Header);
  AssertSingle(AvailableWidth, Header.Bounds.Width);
end;

procedure TMarkdownLayoutEngineTests.Layout_Image_EmitsPlaceholderWithSourceUrl;
begin
  const ImageUrl = 'http://example.com/pic.png';
  const DisplayList = LayoutMarkdown('![diagram](' + ImageUrl + ')', DefaultWidth);

  const Image = FirstImageOf(DisplayList);
  Assert.IsNotNull(Image);
  Assert.AreEqual(ImageUrl, Image.Source);
  Assert.AreEqual('diagram', Image.AltText);
  AssertSingle(ImagePlaceholderWidthValue, Image.Bounds.Width);
  AssertSingle(ImagePlaceholderHeightValue, Image.Bounds.Height);

  Assert.IsNotNull(Image.Node);
  const IsImageNode = (Image.Node.Kind = TMarkdownNodeKind.Image);
  Assert.IsTrue(IsImageNode);
end;

procedure TMarkdownLayoutEngineTests.Layout_ThematicBreak_EmitsLinePrimitive;
begin
  const DisplayList = LayoutMarkdown('---', DefaultWidth);

  const Line = FirstLineOf(DisplayList);
  Assert.IsNotNull(Line);
  AssertSingle(0, Line.StartPoint.X);
  AssertSingle(DefaultWidth, Line.EndPoint.X);
  AssertSingle(Line.StartPoint.Y, Line.EndPoint.Y);
  AssertColor(ThematicBreakColorValue, Line.Color);
  AssertSingle(ThematicBreakThicknessValue, Line.StrokeWidth);

  Assert.IsNotNull(Line.Node);
  const IsThematicBreakNode = (Line.Node.Kind = TMarkdownNodeKind.ThematicBreak);
  Assert.IsTrue(IsThematicBreakNode);
end;

procedure TMarkdownLayoutEngineTests.Layout_TaskListItems_EmitCheckboxPrimitives;
begin
  const DisplayList = LayoutMarkdown('- [x] done'#10'- [ ] later', DefaultWidth);

  const Checkboxes = CheckboxesOf(DisplayList);
  Assert.AreEqual(2, Length(Checkboxes));

  Assert.IsTrue(Checkboxes[0].Checked);
  Assert.IsFalse(Checkboxes[1].Checked);
  AssertSingle(CheckboxSizeValue, Checkboxes[0].Bounds.Width);
  AssertSingle(CheckboxSizeValue, Checkboxes[0].Bounds.Height);

  Assert.IsNotNull(Checkboxes[0].Node);
  const IsCustomInlineNode = (Checkboxes[0].Node.Kind = TMarkdownNodeKind.CustomInline);
  Assert.IsTrue(IsCustomInlineNode);

  const DoneRun = FindRunByPrefix(TextRunsOf(DisplayList), 'done');
  Assert.IsNotNull(DoneRun);
  const StartsAfterCheckbox = (DoneRun.Bounds.Left >= Checkboxes[0].Bounds.Right);
  Assert.IsTrue(StartsAfterCheckbox);
end;

procedure TMarkdownLayoutEngineTests.Layout_BoldRuns_ShiftWrapPositions;
begin
  const WrapWidth = 145.0;

  const PlainList = LayoutMarkdown('aaaa bbbb cccc', WrapWidth);
  const PlainRuns = TextRunsOf(PlainList);
  Assert.AreEqual(1, Length(PlainRuns));
  AssertSingle(BaseLineHeight, PlainList.Height);

  const BoldList = LayoutMarkdown('aaaa **bbbb** cccc', WrapWidth);
  const BoldRuns = TextRunsOf(BoldList);

  const BoldRun = FindRunByPrefix(BoldRuns, 'bbbb');
  Assert.IsNotNull(BoldRun);
  Assert.IsTrue(BoldRun.Font.Bold);
  AssertSingle(5 * BaseCharWidth, BoldRun.Bounds.Left);
  AssertSingle(4 * BoldCharWidth, BoldRun.Bounds.Width);

  const WrappedRun = FindRunByPrefix(BoldRuns, 'cccc');
  Assert.IsNotNull(WrappedRun);
  AssertSingle(BaseLineHeight, WrappedRun.Bounds.Top);
  AssertSingle(2 * BaseLineHeight, BoldList.Height);
end;

procedure TMarkdownLayoutEngineTests.Layout_ItalicRun_UsesItalicFont;
begin
  const DisplayList = LayoutMarkdown('*abc*', DefaultWidth);

  const Run = FindRunByPrefix(TextRunsOf(DisplayList), 'abc');
  Assert.IsNotNull(Run);
  Assert.IsTrue(Run.Font.Italic);
  Assert.IsFalse(Run.Font.Bold);
  AssertSingle(3 * BaseCharWidth, Run.Bounds.Width);
end;

procedure TMarkdownLayoutEngineTests.Layout_CodeSpanInHeading_AlignsRunBaselines;
begin
  const DisplayList = LayoutMarkdown('# Hi `x`', DefaultWidth);

  const Runs = TextRunsOf(DisplayList);
  const HeadingRun = FindRunByPrefix(Runs, 'Hi');
  Assert.IsNotNull(HeadingRun);
  AssertSingle(HeadingOneFontSize, HeadingRun.Font.Size);
  AssertSingle(0, HeadingRun.Bounds.Top);

  const CodeRun = FindRunByPrefix(Runs, 'x');
  Assert.IsNotNull(CodeRun);
  Assert.AreEqual(CodeFamilyName, CodeRun.Font.FamilyName);

  const HeadingBaselineY = HeadingRun.Bounds.Top + HeadingRun.Baseline;
  const CodeBaselineY = CodeRun.Bounds.Top + CodeRun.Baseline;
  AssertSingle(HeadingBaselineY, CodeBaselineY);

  const ExpectedCodeTop = HeadingBaselineY - CodeRun.Baseline;
  AssertSingle(ExpectedCodeTop, CodeRun.Bounds.Top);
  const CodeIsShiftedDown = (CodeRun.Bounds.Top > HeadingRun.Bounds.Top);
  Assert.IsTrue(CodeIsShiftedDown);
end;

procedure TMarkdownLayoutEngineTests.Layout_CodeSpan_EmitsBackgroundChipBehindRunWithPadding;
begin
  const DisplayList = LayoutMarkdown('ab `cd`', DefaultWidth);

  const CodeRun = FindRunByPrefix(TextRunsOf(DisplayList), 'cd');
  Assert.IsNotNull(CodeRun);

  const Chip = FirstRectangleWithFill(DisplayList, CodeSpanBackgroundColorValue);
  Assert.IsNotNull(Chip);
  AssertSingle(CodeRun.Bounds.Left - CodeSpanChipPaddingValue, Chip.Bounds.Left);
  AssertSingle(CodeRun.Bounds.Right + CodeSpanChipPaddingValue, Chip.Bounds.Right);
  AssertSingle(CodeRun.Bounds.Top, Chip.Bounds.Top);
  AssertSingle(CodeRun.Bounds.Bottom, Chip.Bounds.Bottom);

  Assert.IsNotNull(Chip.Node);
  const CarriesCodeSpanNode = (Chip.Node.Kind = TMarkdownNodeKind.CodeSpan);
  Assert.IsTrue(CarriesCodeSpanNode);

  const ChipIndex = IndexOfFirstRectangleWithFill(DisplayList, CodeSpanBackgroundColorValue);
  const RunIndex = IndexOfFirstRunWithPrefix(DisplayList, 'cd');
  const ChipPaintsFirst = (ChipIndex >= 0) and (RunIndex >= 0) and (ChipIndex < RunIndex);
  Assert.IsTrue(ChipPaintsFirst);
end;

procedure TMarkdownLayoutEngineTests.Layout_WrappedCodeSpan_EmitsChipPerLine;
begin
  const WrapWidth = 4.5 * BaseCharWidth;
  const DisplayList = LayoutMarkdown('`aaaa bbbb`', WrapWidth);

  const Runs = TextRunsOf(DisplayList);
  Assert.AreEqual(2, Length(Runs));
  Assert.AreEqual('aaaa', Runs[0].Text);
  Assert.AreEqual('bbbb', Runs[1].Text);

  const Chips = RectanglesWithFill(DisplayList, CodeSpanBackgroundColorValue);
  Assert.AreEqual(2, Length(Chips));

  AssertSingle(Runs[0].Bounds.Top, Chips[0].Bounds.Top);
  AssertSingle(Runs[0].Bounds.Left - CodeSpanChipPaddingValue, Chips[0].Bounds.Left);
  AssertSingle(Runs[0].Bounds.Right + CodeSpanChipPaddingValue, Chips[0].Bounds.Right);

  AssertSingle(BaseLineHeight, Chips[1].Bounds.Top);
  AssertSingle(Runs[1].Bounds.Left - CodeSpanChipPaddingValue, Chips[1].Bounds.Left);
  AssertSingle(Runs[1].Bounds.Right + CodeSpanChipPaddingValue, Chips[1].Bounds.Right);
end;

procedure TMarkdownLayoutEngineTests.Layout_LargeDocument_CompletesWithinBudget;
begin
  const Source = BuildLargeDocumentSource;
  const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);

  const Theme = CreateTestTheme;
  try
    const Measurer: ITextMeasurer = TFakeTextMeasurer.Create;
    const Watch = TStopwatch.StartNew;
    TMarkdownLayoutEngine.LayoutDocument(Document, PerformanceWidth, Theme, Measurer);
    const ElapsedMilliseconds = Watch.ElapsedMilliseconds;

    const WithinBudget = (ElapsedMilliseconds < FullLayoutBudgetMilliseconds);
    Assert.IsTrue(WithinBudget, Format('Full layout took %d ms which exceeds the %d ms budget',
      [ElapsedMilliseconds, FullLayoutBudgetMilliseconds]));
  finally
    Theme.Free;
  end;
end;

procedure TMarkdownLayoutEngineTests.UpdateLayout_SmallEdit_CompletesWithinBudget;
begin
  const Paragraphs = BuildUniformParagraphs;
  const OriginalSource = JoinParagraphs(Paragraphs);
  const Previous = LayoutMarkdown(OriginalSource, PerformanceWidth);

  const MiddleIndex = Length(Paragraphs) div 2;
  var EditedParagraphs := Copy(Paragraphs);
  EditedParagraphs[MiddleIndex] := StringReplace(EditedParagraphs[MiddleIndex], OriginalFragment, EditedFragment, []);
  const EditedSource = JoinParagraphs(EditedParagraphs);
  const EditedDocument = TMarkdown.Parse(EditedSource, TMarkdownDialect.Gfm);

  const Theme = CreateTestTheme;
  try
    const Measurer: ITextMeasurer = TFakeTextMeasurer.Create;
    const ChangedRange = TLayoutBlockRange.Create(MiddleIndex, 1, 1);
    const Watch = TStopwatch.StartNew;
    TMarkdownLayoutEngine.UpdateLayout(Previous, EditedDocument, ChangedRange, Theme, Measurer);
    const ElapsedMilliseconds = Watch.ElapsedMilliseconds;

    const WithinBudget = (ElapsedMilliseconds < IncrementalLayoutBudgetMilliseconds);
    Assert.IsTrue(WithinBudget, Format('Incremental layout took %d ms which exceeds the %d ms budget',
      [ElapsedMilliseconds, IncrementalLayoutBudgetMilliseconds]));
  finally
    Theme.Free;
  end;
end;

class function TMarkdownLayoutEngineTests.CreateTestTheme: TMarkdownTheme;
begin
  Result := TMarkdownTheme.CreateLight;

  Result.BaseFont := TMarkdownFontStyle.Create(BaseFamilyName, BaseFontSize);
  Result.CodeFont := TMarkdownFontStyle.Create(CodeFamilyName, BaseFontSize);
  Result.HeadingFonts[1] := TMarkdownFontStyle.Create(BaseFamilyName, HeadingOneFontSize, True);
  Result.HeadingSpacingAbove[1] := HeadingOneSpacingAbove;
  Result.HeadingSpacingBelow[1] := HeadingOneSpacingBelow;
  Result.ParagraphSpacing := ParagraphSpacingValue;
  Result.ListIndent := ListIndentValue;
  Result.ListMarkerWidth := ListMarkerWidthValue;
  Result.BlockQuoteBarWidth := BlockQuoteBarWidthValue;
  Result.BlockQuoteInset := BlockQuoteInsetValue;
  Result.CodePadding := CodePaddingValue;
  Result.TableCellPadding := TableCellPaddingValue;
  Result.TableMinColumnWidth := TableMinColumnWidthValue;
  Result.TableMaxColumnWidth := TableMaxColumnWidthValue;
  Result.ImagePlaceholderWidth := ImagePlaceholderWidthValue;
  Result.ImagePlaceholderHeight := ImagePlaceholderHeightValue;
  Result.CheckboxSize := CheckboxSizeValue;
  Result.ThematicBreakThickness := ThematicBreakThicknessValue;
  Result.TextColor := TextColorValue;
  Result.LinkColor := LinkColorValue;
  Result.CodeBackgroundColor := CodeBackgroundColorValue;
  Result.BlockQuoteBarColor := BlockQuoteBarColorValue;
  Result.TableHeaderBackgroundColor := TableHeaderBackgroundColorValue;
  Result.ThematicBreakColor := ThematicBreakColorValue;
  Result.CodeSpanBackgroundColor := CodeSpanBackgroundColorValue;
  Result.ContentPadding := 0;
end;

class function TMarkdownLayoutEngineTests.LayoutMarkdown(const Source: string;
  const AvailableWidth: Single): IMarkdownDisplayList;
begin
  const Theme = CreateTestTheme;
  try
    const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
    const Measurer: ITextMeasurer = TFakeTextMeasurer.Create;

    Result := TMarkdownLayoutEngine.LayoutDocument(Document, AvailableWidth, Theme, Measurer);
  finally
    Theme.Free;
  end;
end;

class function TMarkdownLayoutEngineTests.LayoutMarkdownUncapped(const Source: string;
  const AvailableWidth: Single): IMarkdownDisplayList;
begin
  const Theme = CreateTestTheme;
  try
    Theme.TableMaxColumnWidth := 0;

    const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
    const Measurer: ITextMeasurer = TFakeTextMeasurer.Create;

    Result := TMarkdownLayoutEngine.LayoutDocument(Document, AvailableWidth, Theme, Measurer);
  finally
    Theme.Free;
  end;
end;

class function TMarkdownLayoutEngineTests.LayoutMarkdownWithPadding(const Source: string;
  const AvailableWidth, Padding: Single): IMarkdownDisplayList;
begin
  const Theme = CreateTestTheme;
  try
    Theme.ContentPadding := Padding;

    const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
    const Measurer: ITextMeasurer = TFakeTextMeasurer.Create;

    Result := TMarkdownLayoutEngine.LayoutDocument(Document, AvailableWidth, Theme, Measurer);
  finally
    Theme.Free;
  end;
end;

class function TMarkdownLayoutEngineTests.TextRunsOf(const DisplayList: IMarkdownDisplayList): TArray<IDisplayTextRun>;
begin
  Result := nil;

  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const IsTextRun = Supports(DisplayList.Items[Index], IDisplayTextRun, Run);
    if IsTextRun then
      Result := Result + [Run];
  end;
end;

class function TMarkdownLayoutEngineTests.RunsWithText(const Runs: TArray<IDisplayTextRun>;
  const Text: string): TArray<IDisplayTextRun>;
begin
  Result := nil;

  for var Run in Runs do
  begin
    const Matches = (Run.Text = Text);
    if Matches then
      Result := Result + [Run];
  end;
end;

class function TMarkdownLayoutEngineTests.FindRunByPrefix(const Runs: TArray<IDisplayTextRun>;
  const Prefix: string): IDisplayTextRun;
begin
  for var Run in Runs do
  begin
    const Matches = Run.Text.StartsWith(Prefix);
    if Matches then
      Exit(Run);
  end;

  Result := nil;
end;

class function TMarkdownLayoutEngineTests.FirstRectangleWithFill(const DisplayList: IMarkdownDisplayList;
  const FillColor: TLayoutColor): IDisplayRectangle;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Rectangle: IDisplayRectangle;
    const HasExpectedFill = Supports(DisplayList.Items[Index], IDisplayRectangle, Rectangle) and
      (Rectangle.FillColor = FillColor);
    if HasExpectedFill then
      Exit(Rectangle);
  end;

  Result := nil;
end;

class function TMarkdownLayoutEngineTests.RectanglesWithFill(const DisplayList: IMarkdownDisplayList;
  const FillColor: TLayoutColor): TArray<IDisplayRectangle>;
begin
  Result := nil;

  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Rectangle: IDisplayRectangle;
    const HasExpectedFill = Supports(DisplayList.Items[Index], IDisplayRectangle, Rectangle) and
      (Rectangle.FillColor = FillColor);
    if HasExpectedFill then
      Result := Result + [Rectangle];
  end;
end;

class function TMarkdownLayoutEngineTests.IndexOfFirstRectangleWithFill(const DisplayList: IMarkdownDisplayList;
  const FillColor: TLayoutColor): Integer;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Rectangle: IDisplayRectangle;
    const HasExpectedFill = Supports(DisplayList.Items[Index], IDisplayRectangle, Rectangle) and
      (Rectangle.FillColor = FillColor);
    if HasExpectedFill then
      Exit(Index);
  end;

  Result := -1;
end;

class function TMarkdownLayoutEngineTests.IndexOfFirstRunWithPrefix(const DisplayList: IMarkdownDisplayList;
  const Prefix: string): Integer;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const Matches = Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and Run.Text.StartsWith(Prefix);
    if Matches then
      Exit(Index);
  end;

  Result := -1;
end;

class function TMarkdownLayoutEngineTests.FirstImageOf(const DisplayList: IMarkdownDisplayList): IDisplayImage;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Image: IDisplayImage;
    const IsImage = Supports(DisplayList.Items[Index], IDisplayImage, Image);
    if IsImage then
      Exit(Image);
  end;

  Result := nil;
end;

class function TMarkdownLayoutEngineTests.FirstLineOf(const DisplayList: IMarkdownDisplayList): IDisplayLine;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Line: IDisplayLine;
    const IsLine = Supports(DisplayList.Items[Index], IDisplayLine, Line);
    if IsLine then
      Exit(Line);
  end;

  Result := nil;
end;

class function TMarkdownLayoutEngineTests.CheckboxesOf(const DisplayList: IMarkdownDisplayList): TArray<IDisplayCheckbox>;
begin
  Result := nil;

  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Checkbox: IDisplayCheckbox;
    const IsCheckbox = Supports(DisplayList.Items[Index], IDisplayCheckbox, Checkbox);
    if IsCheckbox then
      Result := Result + [Checkbox];
  end;
end;

class function TMarkdownLayoutEngineTests.BuildLargeDocumentSource: string;
begin
  var Builder := TStringBuilder.Create;
  try
    var Index := 0;

    while Builder.Length < LargeDocumentMinimumLength do
    begin
      Builder.Append(Format('Paragraph %d with a steady stream of sample words that wrap across lines.'#10#10, [Index]));
      Inc(Index);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TMarkdownLayoutEngineTests.BuildUniformParagraphs: TArray<string>;
begin
  SetLength(Result, PerformanceParagraphCount);

  for var Index := 0 to PerformanceParagraphCount - 1 do
  begin
    Result[Index] := Format('Paragraph %.4d filled with %s words for layout.', [Index, OriginalFragment]);
  end;
end;

class function TMarkdownLayoutEngineTests.JoinParagraphs(const Paragraphs: TArray<string>): string;
begin
  Result := string.Join(#10#10, Paragraphs);
end;

class procedure TMarkdownLayoutEngineTests.AssertSingle(const Expected, Actual: Single);
begin
  Assert.AreEqual(Double(Expected), Double(Actual), SingleTolerance);
end;

class procedure TMarkdownLayoutEngineTests.AssertColor(const Expected, Actual: TLayoutColor);
begin
  const AreSame = (Expected = Actual);
  Assert.IsTrue(AreSame, Format('Expected color %.8x but found %.8x', [Int64(Expected), Int64(Actual)]));
end;

end.
