unit Markdown4D.Export.Pagination.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Export.Pagination;

type
  [TestFixture]
  TMarkdownPaginationTests = class
  private
    const
      PageHeight = 400.0;
      PixelTolerance = 1.0;
      SingleTolerance = 0.01;
      LongDocumentParagraphs = 60;
      ThreeLineParagraphs = 30;
      CodeLines = 60;
      ListItems = 20;
      TallDiagramHeight = 1000;
      ListDiagramHeight = 150;
    var
      FMeasurer: ITextMeasurer;
    function Layout(const Markdown: string): IMarkdownDisplayList;
    class function NumberedParagraphs(const Count: Integer; const Words: string): string; static;
    class function CodeBlock(const LineCount: Integer): string; static;
    class function ListWithDiagram: string; static;
    class function Breaks(const Slices: TArray<TMarkdownPageSlice>): TArray<Single>; static;
    class function BlockTopNear(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean; static;
    class function TextRunCutBy(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean; static;
    class function RectangleSpans(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean; static;
    class procedure AssertContiguous(const DisplayList: IMarkdownDisplayList;
      const Slices: TArray<TMarkdownPageSlice>); static;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Paginate_ShortDocument_GivesOnePage;

    [Test]
    procedure Paginate_EmptyOrNilDocument_GivesOneEmptyPage;

    [Test]
    procedure Paginate_LongDocument_BreaksOnBlockBoundaries;

    [Test]
    procedure Paginate_BlockFitsOnNextPage_MovesWholeBlock;

    [Test]
    procedure Paginate_CodeBlockTallerThanPage_BreaksBetweenTextRuns;

    [Test]
    procedure Paginate_DiagramTallerThanPage_ShrinksOnOwnPage;

    [Test]
    procedure Paginate_DiagramInLongList_IsNeverCut;

    [Test]
    procedure Paginate_NonPositivePageHeight_RaisesEMarkdownPdfExportError;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Export.Pdf,
  Markdown4D.Export.Pdf.Errors,
  Markdown4D.Tests.TallBlockOverride;

procedure TMarkdownPaginationTests.Setup;
begin
  FMeasurer := TFakeTextMeasurer.Create;
  TMarkdownLayoutEngine.RegisterBlockOverride(TTallBlockOverride.Create, TTallBlockOverride.Priority);
end;

procedure TMarkdownPaginationTests.TearDown;
begin
  TMarkdownLayoutEngine.ClearBlockOverrides;
  FMeasurer := nil;
end;

function TMarkdownPaginationTests.Layout(const Markdown: string): IMarkdownDisplayList;
begin
  Result := TMarkdownPdfExporter.BuildLayout(Markdown, FMeasurer, nil);
end;

class function TMarkdownPaginationTests.NumberedParagraphs(const Count: Integer; const Words: string): string;
begin
  Result := '';
  for var Index := 1 to Count do
  begin
    Result := Result + Format('Paragraph %d %s'#10#10, [Index, Words]);
  end;
end;

class function TMarkdownPaginationTests.CodeBlock(const LineCount: Integer): string;
begin
  Result := '```'#10;
  for var Index := 1 to LineCount do
  begin
    Result := Result + Format('line %d'#10, [Index]);
  end;
  Result := Result + '```'#10;
end;

class function TMarkdownPaginationTests.ListWithDiagram: string;
begin
  Result := '';
  for var Index := 1 to ListItems do
  begin
    Result := Result + Format('- item %d'#10#10, [Index]);
    if Index = ListItems div 2 then
      Result := Result + '  ' + TTallBlockOverride.Fence(ListDiagramHeight).Replace(#10, #10'  ') + #10;
  end;
end;

class function TMarkdownPaginationTests.Breaks(const Slices: TArray<TMarkdownPageSlice>): TArray<Single>;
begin
  Result := [];
  for var Index := 0 to High(Slices) - 1 do
  begin
    Result := Result + [Slices[Index].Bottom];
  end;
end;

class function TMarkdownPaginationTests.BlockTopNear(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean;
begin
  for var Index := 0 to DisplayList.BlockCount - 1 do
  begin
    const IsNear = (Abs(DisplayList.BlockInfos[Index].Top - Y) <= PixelTolerance);
    if IsNear then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class function TMarkdownPaginationTests.TextRunCutBy(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    const Item = DisplayList.Items[Index];
    const IsCut = ((Item.Kind = TDisplayItemKind.TextRun) and (Item.Bounds.Top < Y - 0.01) and
                   (Item.Bounds.Bottom > Y + 0.01));
    if IsCut then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class function TMarkdownPaginationTests.RectangleSpans(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    const Item = DisplayList.Items[Index];
    const Spans = ((Item.Kind = TDisplayItemKind.Rectangle) and (Item.Bounds.Top < Y) and (Item.Bounds.Bottom > Y));
    if Spans then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class procedure TMarkdownPaginationTests.AssertContiguous(const DisplayList: IMarkdownDisplayList;
  const Slices: TArray<TMarkdownPageSlice>);
begin
  Assert.AreEqual(0.0, Slices[0].Top, SingleTolerance, 'the first page starts at the top');
  for var Index := 1 to High(Slices) do
  begin
    Assert.AreEqual(Slices[Index - 1].Bottom, Slices[Index].Top, SingleTolerance,
      'a page starts where the one before ended');
  end;
  Assert.AreEqual(DisplayList.Height, Slices[High(Slices)].Bottom, SingleTolerance, 'the last page ends at the bottom');
end;

procedure TMarkdownPaginationTests.Paginate_ShortDocument_GivesOnePage;
begin
  const DisplayList = Layout('# Title'#10#10'Some text');

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  Assert.AreEqual(1, Integer(Length(Slices)));
  AssertContiguous(DisplayList, Slices);
  Assert.AreEqual(1.0, Slices[0].Scale, SingleTolerance);
end;

procedure TMarkdownPaginationTests.Paginate_EmptyOrNilDocument_GivesOneEmptyPage;
begin
  const EmptyList = Layout('');

  const ForNil = TMarkdownPagination.Paginate(nil, PageHeight);
  const ForEmpty = TMarkdownPagination.Paginate(EmptyList, PageHeight);

  Assert.AreEqual(1, Integer(Length(ForNil)));
  Assert.AreEqual(1, Integer(Length(ForEmpty)));
  Assert.AreEqual(0.0, ForNil[0].Top, SingleTolerance);
  Assert.AreEqual(0.0, ForEmpty[0].Top, SingleTolerance);
end;

procedure TMarkdownPaginationTests.Paginate_LongDocument_BreaksOnBlockBoundaries;
begin
  const DisplayList = Layout(NumberedParagraphs(LongDocumentParagraphs, ''));

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  Assert.IsTrue(Length(Slices) > 1, 'a long document needs more than one page');
  AssertContiguous(DisplayList, Slices);
  for var Slice in Slices do
  begin
    Assert.IsTrue(Slice.Height <= PageHeight, 'no page is taller than the page height');
    Assert.AreEqual(1.0, Slice.Scale, SingleTolerance);
  end;
end;

procedure TMarkdownPaginationTests.Paginate_BlockFitsOnNextPage_MovesWholeBlock;
begin
  const ThreeLines = StringOfChar('w', 60) + ' ' + StringOfChar('w', 60) + ' ' + StringOfChar('w', 60);
  const DisplayList = Layout(NumberedParagraphs(ThreeLineParagraphs, ThreeLines));

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  Assert.IsTrue(Length(Slices) > 1, 'the paragraphs need more than one page');
  for var BreakY in Breaks(Slices) do
  begin
    Assert.IsTrue(BlockTopNear(DisplayList, BreakY), Format('the break at %g is not at the top of a block', [BreakY]));
  end;
end;

procedure TMarkdownPaginationTests.Paginate_CodeBlockTallerThanPage_BreaksBetweenTextRuns;
begin
  const DisplayList = Layout(CodeBlock(CodeLines));
  Assert.IsTrue(DisplayList.Height > PageHeight, 'the code block must be taller than a page');

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  Assert.IsTrue(Length(Slices) > 1, 'the code block runs over more than one page');
  AssertContiguous(DisplayList, Slices);
  for var BreakY in Breaks(Slices) do
  begin
    Assert.IsFalse(TextRunCutBy(DisplayList, BreakY), Format('the break at %g cuts a line of code', [BreakY]));
    Assert.IsTrue(RectangleSpans(DisplayList, BreakY), 'the code background carries on over the break');
  end;
end;

procedure TMarkdownPaginationTests.Paginate_DiagramTallerThanPage_ShrinksOnOwnPage;
begin
  const Markdown = 'Before'#10#10 + TTallBlockOverride.Fence(TallDiagramHeight) + #10'After';
  const DisplayList = Layout(Markdown);

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  var ShrunkCount := 0;
  for var Slice in Slices do
  begin
    Assert.IsTrue(Slice.Height * Slice.Scale <= PageHeight + 0.01, 'every page fits after shrinking');
    if Slice.Scale < 1 then
    begin
      Inc(ShrunkCount);
      Assert.AreEqual(Double(TallDiagramHeight), Slice.Height, PixelTolerance, 'the diagram has the page alone');
      Assert.AreEqual(PageHeight / TallDiagramHeight, Slice.Scale, 0.01, 'the diagram keeps its proportions');
    end;
  end;
  Assert.AreEqual(1, ShrunkCount, 'exactly the diagram is shrunk');
  AssertContiguous(DisplayList, Slices);
end;

procedure TMarkdownPaginationTests.Paginate_DiagramInLongList_IsNeverCut;
begin
  const DisplayList = Layout(ListWithDiagram);
  Assert.IsTrue(DisplayList.Height > PageHeight, 'the list must be taller than a page');

  var DiagramTop := MaxSingle;
  var DiagramBottom := -MaxSingle;
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    const Item = DisplayList.Items[Index];
    var Code: IMarkdownCodeBlock;
    if not Supports(Item.Node, IMarkdownCodeBlock, Code) then
      Continue;

    DiagramTop := Min(DiagramTop, Item.Bounds.Top);
    DiagramBottom := Max(DiagramBottom, Item.Bounds.Bottom);
  end;

  Assert.IsTrue(DiagramBottom > DiagramTop, 'the diagram must be found in the display list');

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  Assert.IsTrue(Length(Slices) > 1, 'the list must run over more than one page');
  for var BreakY in Breaks(Slices) do
  begin
    const CutsDiagram = (BreakY > DiagramTop + 0.01) and (BreakY < DiagramBottom - 0.01);
    Assert.IsFalse(CutsDiagram, Format('the break at %g cuts the diagram', [BreakY]));
    Assert.IsFalse(TextRunCutBy(DisplayList, BreakY), Format('the break at %g cuts a line', [BreakY]));
  end;
end;

procedure TMarkdownPaginationTests.Paginate_NonPositivePageHeight_RaisesEMarkdownPdfExportError;
begin
  Assert.WillRaise(
    procedure
    begin
      TMarkdownPagination.Paginate(nil, 0);
    end,
    EMarkdownPdfExportError);
end;

end.
