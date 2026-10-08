unit Markdown4DStudio.PdfExport.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4DStudio.PdfExport;

type
  // Answers one fixed natural size for every image, or none, and paints every
  // page as a single white pixel while counting the pages it was asked for.
  TFakePdfPageRenderer = class(TInterfacedObject, IMarkdownImageSizeProvider, IPadPdfPageRenderer)
  strict private
    FMeasurer: ITextMeasurer;
    FHasImageSize: Boolean;
    FImageSize: TLayoutSizeF;
    FRenderCount: Integer;
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
    function Measurer: ITextMeasurer;
    function RenderPage(const DisplayList: IMarkdownDisplayList; const Slice: TPadPdfPageSlice;
      const BackgroundColor: TLayoutColor): TPadPdfPageImage;

  public
    constructor Create;
    procedure SetImageSize(const Width, Height: Single);
    property RenderCount: Integer read FRenderCount;
  end;

  [TestFixture]
  TPadPdfExportTests = class
  private
    const
      SizeTolerance = 0.5;
      PositionTolerance = 0.01;
    var
      FRenderer: TFakePdfPageRenderer;
      FRendererRef: IPadPdfPageRenderer;
    function Build(const Markdown: string): IMarkdownDisplayList;
    function FirstItemOfKind(const DisplayList: IMarkdownDisplayList; const Kind: TDisplayItemKind): IDisplayItem;
    class function RepeatedParagraphs(const Count: Integer; const Text: string): string; static;
    class function IsInsideAnyBlock(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean; static;
    class function CrossesAny(const DisplayList: IMarkdownDisplayList; const Y: Single;
      const Kinds: TArray<TDisplayItemKind>): Boolean; static;
    class procedure AssertSlicesCoverDocument(const DisplayList: IMarkdownDisplayList;
      const Slices: TArray<TPadPdfPageSlice>; const PageHeight: Single); static;
    class procedure AssertNoBreakThroughText(const DisplayList: IMarkdownDisplayList;
      const Slices: TArray<TPadPdfPageSlice>); static;
    class function PdfText(const Pdf: TBytes): string; static;
    class function WhitePage(const Width, Height: Integer): TPadPdfPageStream; static;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure ContentSize_A4MinusTwoCentimetreMargins_At200Dpi;

    [Test]
    procedure Build_UsesLightThemeWithoutContentPadding;

    [Test]
    procedure Build_ImageWithKnownSize_ScalesNaturalSizeToRasterDpi;

    [Test]
    procedure Build_WideImage_IsCappedToContentWidth;

    [Test]
    procedure Build_WithoutImageSizes_DoesNotFail;

    [Test]
    procedure Paginate_ShortDocument_GivesOnePage;

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
    procedure Paginate_EmptyDocument_GivesOneEmptyPage;

    [Test]
    procedure CompressPage_RoundTrips;

    [Test]
    procedure Write_TwoPages_HasHeaderXrefAndEof;

    [Test]
    procedure Write_Page_HasA4MediaBoxAndFlateImage;

    [Test]
    procedure BuildDocument_WithFakeRenderer_CallsRenderPageOncePerSlice;
  end;

implementation

uses
  System.Math,
  System.ZLib,
  Markdown4D.Defines,
  Markdown4D.Theme,
  Markdown4D.Layout.FakeMeasurer;

constructor TFakePdfPageRenderer.Create;
begin
  inherited Create;

  FMeasurer := TFakeTextMeasurer.Create;
end;

procedure TFakePdfPageRenderer.SetImageSize(const Width, Height: Single);
begin
  FHasImageSize := True;
  FImageSize := TLayoutSizeF.Create(Width, Height);
end;

function TFakePdfPageRenderer.TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
begin
  Size := FImageSize;
  Result := FHasImageSize;
end;

function TFakePdfPageRenderer.Measurer: ITextMeasurer;
begin
  Result := FMeasurer;
end;

function TFakePdfPageRenderer.RenderPage(const DisplayList: IMarkdownDisplayList; const Slice: TPadPdfPageSlice;
  const BackgroundColor: TLayoutColor): TPadPdfPageImage;
begin
  Inc(FRenderCount);

  Result.Width := 1;
  Result.Height := 1;
  Result.Pixels := [$FF, $FF, $FF];
end;

procedure TPadPdfExportTests.Setup;
begin
  FRenderer := TFakePdfPageRenderer.Create;
  FRendererRef := FRenderer;
end;

procedure TPadPdfExportTests.TearDown;
begin
  FRenderer := nil;
  FRendererRef := nil;
end;

function TPadPdfExportTests.Build(const Markdown: string): IMarkdownDisplayList;
begin
  Result := TPadPdfLayout.Build(Markdown, FRendererRef.Measurer, FRendererRef);
end;

function TPadPdfExportTests.FirstItemOfKind(const DisplayList: IMarkdownDisplayList;
  const Kind: TDisplayItemKind): IDisplayItem;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    Result := DisplayList.Items[Index];
    if Result.Kind = Kind then
      Exit;
  end;

  Result := nil;
end;

class function TPadPdfExportTests.RepeatedParagraphs(const Count: Integer; const Text: string): string;
begin
  var Paragraphs: TArray<string> := [];
  for var Index := 1 to Count do
  begin
    Paragraphs := Paragraphs + [Format('%s %d', [Text, Index])];
  end;

  Result := string.Join(LineFeed + LineFeed, Paragraphs);
end;

class function TPadPdfExportTests.IsInsideAnyBlock(const DisplayList: IMarkdownDisplayList; const Y: Single): Boolean;
begin
  for var Index := 0 to DisplayList.BlockCount - 1 do
  begin
    const Block = DisplayList.BlockInfos[Index];
    const IsInside = ((Block.Top < Y - PositionTolerance) and (Block.Top + Block.Height > Y + PositionTolerance));
    if IsInside then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class function TPadPdfExportTests.CrossesAny(const DisplayList: IMarkdownDisplayList; const Y: Single;
  const Kinds: TArray<TDisplayItemKind>): Boolean;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    const Item = DisplayList.Items[Index];
    var IsWanted := False;
    for var Kind in Kinds do
    begin
      IsWanted := IsWanted or (Item.Kind = Kind);
    end;

    const Bounds = Item.Bounds;
    const IsCrossing = (IsWanted and
                        (Bounds.Top < Y - PositionTolerance) and
                        (Bounds.Bottom > Y + PositionTolerance));
    if IsCrossing then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class procedure TPadPdfExportTests.AssertSlicesCoverDocument(const DisplayList: IMarkdownDisplayList;
  const Slices: TArray<TPadPdfPageSlice>; const PageHeight: Single);
begin
  Assert.IsTrue(Length(Slices) > 0, 'no pages');
  Assert.AreEqual(0.0, Double(Slices[0].Top), PositionTolerance);
  Assert.AreEqual(Double(DisplayList.Height), Double(Slices[High(Slices)].Bottom), PositionTolerance);

  for var Index := 0 to High(Slices) do
  begin
    const Slice = Slices[Index];
    Assert.IsTrue(Slice.Bottom > Slice.Top, Format('page %d is empty', [Index]));
    Assert.IsTrue(Slice.Bottom - Slice.Top <= PageHeight + PositionTolerance,
      Format('page %d is %.1f high, more than %.1f', [Index, Slice.Bottom - Slice.Top, PageHeight]));

    if Index > 0 then
      Assert.AreEqual(Double(Slices[Index - 1].Bottom), Double(Slice.Top), PositionTolerance);
  end;
end;

class procedure TPadPdfExportTests.AssertNoBreakThroughText(const DisplayList: IMarkdownDisplayList;
  const Slices: TArray<TPadPdfPageSlice>);
const
  BreakingKinds: TArray<TDisplayItemKind> = [TDisplayItemKind.TextRun,
                                             TDisplayItemKind.Image,
                                             TDisplayItemKind.Checkbox];
begin
  for var Index := 0 to High(Slices) - 1 do
  begin
    const Boundary = Slices[Index].Bottom;
    Assert.IsFalse(CrossesAny(DisplayList, Boundary, BreakingKinds),
      Format('the end of page %d at %.1f runs through a text line', [Index, Boundary]));
  end;
end;

class function TPadPdfExportTests.PdfText(const Pdf: TBytes): string;
begin
  SetLength(Result, Length(Pdf));
  for var Index := 0 to High(Pdf) do
  begin
    Result[Index + 1] := Char(Pdf[Index]);
  end;
end;

class function TPadPdfExportTests.WhitePage(const Width, Height: Integer): TPadPdfPageStream;
begin
  var Image: TPadPdfPageImage;
  Image.Width := Width;
  Image.Height := Height;
  SetLength(Image.Pixels, Width * Height * 3);
  FillChar(Image.Pixels[0], Length(Image.Pixels), $FF);

  Result := TPadPdfWriter.CompressPage(Image);
end;

procedure TPadPdfExportTests.ContentSize_A4MinusTwoCentimetreMargins_At200Dpi;
begin
  Assert.AreEqual(1339, TPadPdfGeometry.ContentWidthPx);
  Assert.AreEqual(2024, TPadPdfGeometry.ContentHeightPx);
end;

procedure TPadPdfExportTests.Build_UsesLightThemeWithoutContentPadding;
begin
  const LightTheme = TMarkdownTheme.CreateLight;
  try
    const DisplayList = Build('Plain words in a paragraph.');

    const Run = FirstItemOfKind(DisplayList, TDisplayItemKind.TextRun) as IDisplayTextRun;
    Assert.IsNotNull(Run, 'the paragraph produced no text');
    Assert.AreEqual<TLayoutColor>(LightTheme.TextColor, Run.Color);
    Assert.AreEqual(0.0, Double(Run.Bounds.Left), PositionTolerance);
    Assert.AreEqual(0.0, Double(DisplayList.BlockInfos[0].Top), PositionTolerance);
  finally
    LightTheme.Free;
  end;
end;

procedure TPadPdfExportTests.Build_ImageWithKnownSize_ScalesNaturalSizeToRasterDpi;
begin
  FRenderer.SetImageSize(100, 50);

  const DisplayList = Build('![picture](picture.png)');

  const Image = FirstItemOfKind(DisplayList, TDisplayItemKind.Image);
  Assert.IsNotNull(Image, 'the layout has no image');
  Assert.AreEqual(100 * 200 / 96, Double(Image.Bounds.Width), SizeTolerance);
  Assert.AreEqual(50 * 200 / 96, Double(Image.Bounds.Height), SizeTolerance);
end;

procedure TPadPdfExportTests.Build_WideImage_IsCappedToContentWidth;
begin
  FRenderer.SetImageSize(3000, 1500);

  const DisplayList = Build('![wide](wide.png)');

  const Image = FirstItemOfKind(DisplayList, TDisplayItemKind.Image);
  Assert.IsNotNull(Image, 'the layout has no image');
  Assert.IsTrue(Image.Bounds.Width <= TPadPdfGeometry.ContentWidthPx + SizeTolerance,
    Format('image is %.1f wide, wider than the content', [Image.Bounds.Width]));
end;

procedure TPadPdfExportTests.Build_WithoutImageSizes_DoesNotFail;
begin
  const DisplayList = TPadPdfLayout.Build('![missing](missing.png)', FRendererRef.Measurer, nil);

  Assert.IsNotNull(FirstItemOfKind(DisplayList, TDisplayItemKind.Image), 'no placeholder for the image');
end;

procedure TPadPdfExportTests.Paginate_ShortDocument_GivesOnePage;
begin
  const DisplayList = Build('# Title' + LineFeed + LineFeed + 'A short paragraph.');

  const Slices = TPadPdfPagination.Paginate(DisplayList, TPadPdfGeometry.ContentHeightPx);

  Assert.AreEqual(1, Integer(Length(Slices)));
  AssertSlicesCoverDocument(DisplayList, Slices, TPadPdfGeometry.ContentHeightPx);
end;

procedure TPadPdfExportTests.Paginate_LongDocument_BreaksOnBlockBoundaries;
begin
  const PageHeight = 300.0;
  const DisplayList = Build(RepeatedParagraphs(40, 'Paragraph'));

  const Slices = TPadPdfPagination.Paginate(DisplayList, PageHeight);

  Assert.IsTrue(Length(Slices) > 1, 'a long document must span several pages');
  AssertSlicesCoverDocument(DisplayList, Slices, PageHeight);
  for var Index := 0 to High(Slices) - 1 do
  begin
    Assert.IsFalse(IsInsideAnyBlock(DisplayList, Slices[Index].Bottom),
      Format('the end of page %d cuts through a block', [Index]));
  end;
end;

procedure TPadPdfExportTests.Paginate_BlockFitsOnNextPage_MovesWholeBlock;
begin
  var Words: TArray<string> := [];
  for var Index := 1 to 80 do
  begin
    Words := Words + ['word'];
  end;
  const LongText = string.Join(' ', Words);
  const DisplayList = Build(RepeatedParagraphs(2, LongText));
  Assert.AreEqual(2, DisplayList.BlockCount);
  const Second = DisplayList.BlockInfos[1];
  const PageHeight = Second.Top + Second.Height / 2;
  Assert.IsTrue(Second.Height <= PageHeight, 'the second paragraph must fit on an empty page');

  const Slices = TPadPdfPagination.Paginate(DisplayList, PageHeight);

  Assert.IsTrue(Length(Slices) >= 2, 'the second paragraph must go to the next page');
  Assert.AreEqual(Double(Second.Top), Double(Slices[1].Top), PositionTolerance);
end;

procedure TPadPdfExportTests.Paginate_CodeBlockTallerThanPage_BreaksBetweenTextRuns;
begin
  const PageHeight = 500.0;
  var Lines: TArray<string> := [];
  for var Index := 1 to 60 do
  begin
    Lines := Lines + [Format('line %d of the code', [Index])];
  end;
  const DisplayList = Build('```' + LineFeed + string.Join(LineFeed, Lines) + LineFeed + '```');
  Assert.AreEqual(1, DisplayList.BlockCount);
  Assert.IsTrue(DisplayList.BlockInfos[0].Height > PageHeight, 'the code block must be taller than a page');

  const Slices = TPadPdfPagination.Paginate(DisplayList, PageHeight);

  Assert.IsTrue(Length(Slices) > 1, 'the code block must span several pages');
  AssertSlicesCoverDocument(DisplayList, Slices, PageHeight);
  AssertNoBreakThroughText(DisplayList, Slices);
  Assert.IsTrue(Slices[0].Bottom >= PageHeight * 0.85,
    Format('the first page ends at %.1f and leaves too much room unused', [Slices[0].Bottom]));
end;

procedure TPadPdfExportTests.Paginate_TableTallerThanPage_BreaksBetweenRows;
begin
  const PageHeight = 500.0;
  var Rows: TArray<string> := ['| Name | Value |', '| --- | --- |'];
  for var Index := 1 to 50 do
  begin
    Rows := Rows + [Format('| row %d | %d |', [Index, Index * 10])];
  end;
  const DisplayList = Build(string.Join(LineFeed, Rows));

  const Slices = TPadPdfPagination.Paginate(DisplayList, PageHeight);

  Assert.IsTrue(Length(Slices) > 1, 'the table must span several pages');
  AssertSlicesCoverDocument(DisplayList, Slices, PageHeight);
  AssertNoBreakThroughText(DisplayList, Slices);
  const CutsTableLines = CrossesAny(DisplayList, Slices[0].Bottom,
                                    [TDisplayItemKind.Line, TDisplayItemKind.Rectangle]);
  Assert.IsTrue(CutsTableLines, 'the table borders must be cut at the page end');
end;

procedure TPadPdfExportTests.Paginate_ItemTallerThanPage_CutsHardAndTerminates;
begin
  const PageHeight = 1000.0;
  FRenderer.SetImageSize(100, 2000);
  const DisplayList = Build('![tall](tall.png)');
  const Image = FirstItemOfKind(DisplayList, TDisplayItemKind.Image);
  Assert.IsTrue(Image.Bounds.Height > 2 * PageHeight, 'the image must be taller than two pages');

  const Slices = TPadPdfPagination.Paginate(DisplayList, PageHeight);

  AssertSlicesCoverDocument(DisplayList, Slices, PageHeight);
  Assert.AreEqual(Ceil(DisplayList.Height / PageHeight), Integer(Length(Slices)));
  for var Index := 0 to High(Slices) - 1 do
  begin
    Assert.AreEqual(Double(PageHeight), Double(Slices[Index].Bottom - Slices[Index].Top), PositionTolerance);
  end;
end;

procedure TPadPdfExportTests.Paginate_EmptyDocument_GivesOneEmptyPage;
begin
  const DisplayList = Build('');

  const Slices = TPadPdfPagination.Paginate(DisplayList, TPadPdfGeometry.ContentHeightPx);

  Assert.AreEqual(1, Integer(Length(Slices)));
  Assert.AreEqual(0.0, Double(Slices[0].Top), PositionTolerance);
end;

procedure TPadPdfExportTests.CompressPage_RoundTrips;
begin
  var Image: TPadPdfPageImage;
  Image.Width := 2;
  Image.Height := 2;
  Image.Pixels := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

  const Page = TPadPdfWriter.CompressPage(Image);
  var Restored: TBytes;
  ZDecompress(Page.Data, Restored);

  Assert.AreEqual(2, Page.Width);
  Assert.AreEqual(2, Page.Height);
  Assert.AreEqual(Length(Image.Pixels), Length(Restored));
  for var Index := 0 to High(Restored) do
  begin
    Assert.AreEqual(Integer(Image.Pixels[Index]), Integer(Restored[Index]));
  end;
end;

procedure TPadPdfExportTests.Write_TwoPages_HasHeaderXrefAndEof;
begin
  const Pdf = TPadPdfWriter.Write([WhitePage(2, 2), WhitePage(2, 2)]);
  const Text = PdfText(Pdf);

  Assert.IsTrue(Text.StartsWith('%PDF-1.4'), 'missing PDF header');
  Assert.IsTrue(Text.TrimRight.EndsWith('%%EOF'), 'missing end-of-file marker');
  Assert.IsTrue(Text.Contains('/Count 2'), 'the page tree must count two pages');

  const XrefStart = Text.IndexOf(LineFeed + 'xref' + LineFeed);
  Assert.IsTrue(XrefStart > 0, 'missing cross-reference table');
  const Lines = Text.Substring(XrefStart + 1).Split([LineFeed]);
  const ObjectCount = Lines[1].Split([' '])[1].ToInteger;
  Assert.AreEqual(9, ObjectCount, 'catalog, page tree and three objects per page, after the free object 0');

  for var ObjectNumber := 1 to ObjectCount - 1 do
  begin
    const Entry = Lines[2 + ObjectNumber];
    const Offset = Entry.Substring(0, 10).ToInteger;
    const Expected = Format('%d 0 obj', [ObjectNumber]);
    Assert.AreEqual(Expected, Text.Substring(Offset, Length(Expected)),
      Format('the offset of object %d does not point at it', [ObjectNumber]));
  end;
end;

procedure TPadPdfExportTests.Write_Page_HasA4MediaBoxAndFlateImage;
begin
  const Pdf = TPadPdfWriter.Write([WhitePage(3, 2)]);
  const Text = PdfText(Pdf);

  Assert.IsTrue(Text.Contains('/MediaBox [0 0 595.28 841.89]'), 'the page is not A4');
  Assert.IsTrue(Text.Contains('/FlateDecode'), 'the image is not Flate-compressed');
  Assert.IsTrue(Text.Contains('/Width 3 /Height 2'), 'the image size is missing');
end;

procedure TPadPdfExportTests.BuildDocument_WithFakeRenderer_CallsRenderPageOncePerSlice;
begin
  const Markdown = RepeatedParagraphs(200, 'Paragraph');
  const DisplayList = Build(Markdown);
  const Slices = TPadPdfPagination.Paginate(DisplayList, TPadPdfGeometry.ContentHeightPx);
  Assert.IsTrue(Length(Slices) > 1, 'the document must span several pages');

  const Pdf = TPadPdfExport.BuildDocument(Markdown, FRendererRef);

  Assert.AreEqual(Integer(Length(Slices)), FRenderer.RenderCount);
  Assert.IsTrue(PdfText(Pdf).Contains(Format('/Count %d', [Length(Slices)])), 'page count differs');
end;

end.
