unit Markdown4D.Export.Pagination.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Export.Pagination;

type
  [TestFixture]
  TMarkdownPaginationTests = class
  private
    const
      LayoutWidth = 400.0;
      PageHeight = 300.0;
      // A break may run through the blank bottom edge of a line box, never
      // through the line itself.
      CutTolerance = 1.0;
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
    function Layout(const Markdown: string; const ImageSizes: IMarkdownImageSizeProvider = nil): IMarkdownDisplayList;
    class function Paragraphs(const Count: Integer): string; static;
    class function CodeBlock(const LineCount: Integer): string; static;
    class function Table(const RowCount: Integer): string; static;
    class function SplitsBlock(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean; static;
    class function CutsTextRun(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean; static;
    class function RectangleRunsThrough(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean; static;
    procedure AssertContiguous(const DisplayList: IMarkdownDisplayList; const Slices: TArray<TMarkdownPageSlice>);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Paginate_ShortDocument_GivesOnePage;

    [Test]
    procedure Paginate_EmptyDocument_GivesOneEmptyPage;

    [Test]
    procedure Paginate_NilDisplayList_GivesOneEmptyPage;

    [Test]
    procedure Paginate_LongDocument_BreaksOnBlockBoundaries;

    [Test]
    procedure Paginate_BlockFitsOnNextPage_MovesWholeBlock;

    [Test]
    procedure Paginate_CodeBlockTallerThanPage_BreaksBetweenTextRuns;

    [Test]
    procedure Paginate_TableTallerThanPage_BreaksBetweenRows;

    [Test]
    procedure Paginate_ItemTallerThanPage_CutsHardAndTerminates;

    [Test]
    procedure Paginate_Boundaries_AreWholePixels;

    [Test]
    procedure Paginate_PageHeightBelowOnePixel_RaisesEMarkdownPdfExportError;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Export.Pdf.Errors,
  Markdown4D.Tests.FakeImageSizes;

procedure TMarkdownPaginationTests.Setup;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FTheme.ContentPadding := 0;
  FMeasurer := TFakeTextMeasurer.Create;
end;

procedure TMarkdownPaginationTests.TearDown;
begin
  FMeasurer := nil;
  FTheme.Free;
end;

function TMarkdownPaginationTests.Layout(const Markdown: string;
  const ImageSizes: IMarkdownImageSizeProvider): IMarkdownDisplayList;
begin
  const Document = TMarkdown.Parse(Markdown, TMarkdownDialect.Gfm);
  Result := TMarkdownLayoutEngine.LayoutDocument(Document, LayoutWidth, FTheme, FMeasurer, ImageSizes);
end;

class function TMarkdownPaginationTests.Paragraphs(const Count: Integer): string;
begin
  var Lines: TArray<string>;
  for var Index := 1 to Count do
  begin
    Lines := Lines + [Format('Paragraph %d', [Index])];
  end;

  Result := string.Join(#10#10, Lines);
end;

class function TMarkdownPaginationTests.CodeBlock(const LineCount: Integer): string;
begin
  var Lines: TArray<string> := ['```'];
  for var Index := 1 to LineCount do
  begin
    Lines := Lines + [Format('line %d', [Index])];
  end;

  Result := string.Join(#10, Lines + ['```']);
end;

class function TMarkdownPaginationTests.Table(const RowCount: Integer): string;
begin
  var Lines: TArray<string> := ['| Name | Value |', '| --- | --- |'];
  for var Index := 1 to RowCount do
  begin
    Lines := Lines + [Format('| row %d | %d |', [Index, Index * 10])];
  end;

  Result := string.Join(#10, Lines);
end;

class function TMarkdownPaginationTests.SplitsBlock(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean;
begin
  for var Index := 0 to DisplayList.BlockCount - 1 do
  begin
    const Block = DisplayList.BlockInfos[Index];
    const IsSplit = ((Block.Top < Y) and (Block.Top + Block.Height > Y + CutTolerance));
    if IsSplit then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class function TMarkdownPaginationTests.CutsTextRun(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    const Item = DisplayList.Items[Index];
    const IsCut = ((Item.Kind = TDisplayItemKind.TextRun) and
                   (Item.Bounds.Top < Y) and
                   (Item.Bounds.Bottom > Y + CutTolerance));
    if IsCut then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class function TMarkdownPaginationTests.RectangleRunsThrough(const DisplayList: IMarkdownDisplayList;
  const Y: Single): Boolean;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    const Item = DisplayList.Items[Index];
    const RunsThrough = ((Item.Kind = TDisplayItemKind.Rectangle) and
                         (Item.Bounds.Top < Y) and
                         (Item.Bounds.Bottom > Y));
    if RunsThrough then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

procedure TMarkdownPaginationTests.AssertContiguous(const DisplayList: IMarkdownDisplayList;
  const Slices: TArray<TMarkdownPageSlice>);
begin
  Assert.IsTrue(Length(Slices) > 0, 'no pages');
  Assert.AreEqual(Single(0), Slices[0].Top, 0);
  Assert.AreEqual(Single(Ceil(DisplayList.Height)), Slices[High(Slices)].Bottom, 0);

  for var Index := 0 to High(Slices) do
  begin
    Assert.IsTrue(Slices[Index].Height > 0, Format('page %d is empty', [Index]));
    Assert.IsTrue(Slices[Index].Height <= PageHeight, Format('page %d is taller than a page', [Index]));
    if Index > 0 then
      Assert.AreEqual(Slices[Index - 1].Bottom, Slices[Index].Top, 0, 'pages must meet');
  end;
end;

procedure TMarkdownPaginationTests.Paginate_ShortDocument_GivesOnePage;
begin
  const DisplayList = Layout('# Title'#10#10'Some text.');

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  Assert.AreEqual(1, Integer(Length(Slices)));
  AssertContiguous(DisplayList, Slices);
end;

procedure TMarkdownPaginationTests.Paginate_EmptyDocument_GivesOneEmptyPage;
begin
  const DisplayList = Layout('');

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  Assert.AreEqual(1, Integer(Length(Slices)));
  Assert.AreEqual(Single(0), Slices[0].Top, 0);
  Assert.AreEqual(Single(0), Slices[0].Bottom, 0);
end;

procedure TMarkdownPaginationTests.Paginate_NilDisplayList_GivesOneEmptyPage;
begin
  const Slices = TMarkdownPagination.Paginate(nil, PageHeight);

  Assert.AreEqual(1, Integer(Length(Slices)));
  Assert.AreEqual(Single(0), Slices[0].Height, 0);
end;

procedure TMarkdownPaginationTests.Paginate_LongDocument_BreaksOnBlockBoundaries;
begin
  const DisplayList = Layout(Paragraphs(60));

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  Assert.IsTrue(Length(Slices) > 1, 'the document should need several pages');
  AssertContiguous(DisplayList, Slices);
  for var Index := 0 to High(Slices) - 1 do
  begin
    Assert.IsFalse(SplitsBlock(DisplayList, Slices[Index].Bottom), Format('page %d ends inside a block', [Index]));
  end;
end;

procedure TMarkdownPaginationTests.Paginate_BlockFitsOnNextPage_MovesWholeBlock;
begin
  const OpeningParagraphCount = 8;
  const DisplayList = Layout(Paragraphs(OpeningParagraphCount) + #10#10 + CodeBlock(6) + #10#10'Closing paragraph.');
  const Block = DisplayList.BlockInfos[OpeningParagraphCount];
  const PageThroughBlock = Ceil(Block.Top + (Block.Height / 2));
  Assert.IsTrue(Block.Height <= PageThroughBlock, 'the code block must fit on a page for this test');

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageThroughBlock);

  Assert.AreEqual(Single(Floor(Block.Top)), Slices[0].Bottom, 0, 'the first page should stop above the block');
  Assert.IsTrue(Slices[1].Bottom >= Block.Top + Block.Height, 'the block should be whole on the second page');
end;

procedure TMarkdownPaginationTests.Paginate_CodeBlockTallerThanPage_BreaksBetweenTextRuns;
begin
  const DisplayList = Layout(CodeBlock(60));

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  Assert.IsTrue(Length(Slices) > 1, 'the code block should need several pages');
  AssertContiguous(DisplayList, Slices);
  for var Index := 0 to High(Slices) - 1 do
  begin
    const Boundary = Slices[Index].Bottom;
    Assert.IsFalse(CutsTextRun(DisplayList, Boundary), Format('page %d cuts through a line of code', [Index]));
    Assert.IsTrue(RectangleRunsThrough(DisplayList, Boundary),
                  Format('the code background should run on past page %d', [Index]));
  end;
end;

procedure TMarkdownPaginationTests.Paginate_TableTallerThanPage_BreaksBetweenRows;
begin
  const DisplayList = Layout(Table(60));

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  Assert.IsTrue(Length(Slices) > 1, 'the table should need several pages');
  AssertContiguous(DisplayList, Slices);
  for var Index := 0 to High(Slices) - 1 do
  begin
    Assert.IsFalse(CutsTextRun(DisplayList, Slices[Index].Bottom), Format('page %d cuts through a row', [Index]));
  end;
end;

procedure TMarkdownPaginationTests.Paginate_ItemTallerThanPage_CutsHardAndTerminates;
begin
  const DisplayList = Layout('![tall](tall.png)', TFakeImageSizes.Create(100, 1000));

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  Assert.IsTrue(Length(Slices) >= 4, 'an image of 1000 pixels needs four pages of 300');
  AssertContiguous(DisplayList, Slices);
  Assert.AreEqual(Single(PageHeight), Slices[0].Height, 0, 'an image that cannot be broken is cut at the page end');
end;

procedure TMarkdownPaginationTests.Paginate_Boundaries_AreWholePixels;
begin
  const DisplayList = Layout(Paragraphs(30) + #10#10 + CodeBlock(40) + #10#10 + Table(30));

  const Slices = TMarkdownPagination.Paginate(DisplayList, PageHeight);

  for var Slice in Slices do
  begin
    Assert.IsTrue(Frac(Slice.Top) = 0, 'a page must start on a whole pixel');
    Assert.IsTrue(Frac(Slice.Bottom) = 0, 'a page must end on a whole pixel');
  end;
end;

procedure TMarkdownPaginationTests.Paginate_PageHeightBelowOnePixel_RaisesEMarkdownPdfExportError;
begin
  const DisplayList = Layout('Text');
  const TooLowPageHeight = 0.5;

  Assert.WillRaise(
    procedure
    begin
      const Slices = TMarkdownPagination.Paginate(DisplayList, TooLowPageHeight);
      Assert.Fail(Format('%d pages for a page of half a pixel', [Length(Slices)]));
    end,
    EMarkdownPdfExportError,
    'GuardPageHeight must refuse a page that holds no pixel');
end;

end.
