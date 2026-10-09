unit Markdown4D.Export.Pdf.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Export.Pagination,
  Markdown4D.Export.Pdf.Interfaces;

type
  [TestFixture]
  TMarkdownPdfExporterTests = class
  private
    const
      ImageMarkdown = '![picture](picture.png)';
      ImageSource = 'picture.png';
      ScaleTolerance = 0.01;
    var
      FMeasurer: ITextMeasurer;
    class function FirstItemOfKind(const DisplayList: IMarkdownDisplayList;
      const Kind: TDisplayItemKind): IDisplayItem; static;
    class function CountOfKind(const DisplayList: IMarkdownDisplayList; const Kind: TDisplayItemKind): Integer; static;
    class function HasDrawingRun(const DisplayList: IMarkdownDisplayList): Boolean; static;
    class function LongDocument: string; static;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Geometry_A4MinusTwoCentimetreMargins_At200Dpi;

    [Test]
    procedure BuildLayout_AlwaysLightTheme_UsesLightTextColorAndNoPadding;

    [Test]
    procedure BuildLayout_ScalesFontsWithRasterDpi;

    [Test]
    procedure BuildLayout_KnownImageSize_ScalesNaturalSize;

    [Test]
    procedure BuildLayout_WideImage_IsCappedToContentWidth;

    [Test]
    procedure BuildLayout_UnknownImage_GivesPlaceholderSlot;

    [Test]
    procedure BuildLayout_ChartAndMermaid_DrawTheirShapes;

    [Test]
    procedure BuildLayout_Formula_DrawsItsGlyphs;

    [Test]
    procedure Export_FakeRasterizer_RasterizesOncePerSliceAndWritesPdf;

    [Test]
    procedure Export_NilRasterizer_RaisesEMarkdownPdfExportError;

    [Test]
    procedure Export_NilStream_RaisesEMarkdownPdfExportError;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Theme,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Extensions.Chart,
  Markdown4D.Extensions.Chart.BlockOverride,
  Markdown4D.Extensions.Mermaid,
  Markdown4D.Extensions.Mermaid.BlockOverride,
  Markdown4D.Export.Pdf,
  Markdown4D.Export.Pdf.Errors,
  Markdown4D.Export.Pdf.Geometry,
  Markdown4D.Tests.PdfReader,
  Markdown4D.Tests.FakeImageSizes,
  Markdown4D.Tests.FakePdfRasterizer;

procedure TMarkdownPdfExporterTests.Setup;
begin
  FMeasurer := TFakeTextMeasurer.Create;
end;

procedure TMarkdownPdfExporterTests.TearDown;
begin
  FMeasurer := nil;
end;

class function TMarkdownPdfExporterTests.FirstItemOfKind(const DisplayList: IMarkdownDisplayList;
  const Kind: TDisplayItemKind): IDisplayItem;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    if DisplayList.Items[Index].Kind = Kind then
    begin
      Result := DisplayList.Items[Index];
      Exit;
    end;
  end;

  Result := nil;
end;

class function TMarkdownPdfExporterTests.CountOfKind(const DisplayList: IMarkdownDisplayList;
  const Kind: TDisplayItemKind): Integer;
begin
  Result := 0;
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    if DisplayList.Items[Index].Kind = Kind then
      Inc(Result);
  end;
end;

class function TMarkdownPdfExporterTests.HasDrawingRun(const DisplayList: IMarkdownDisplayList): Boolean;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const IsDrawing = (Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and
                       (Run.Role = TDisplayTextRunRole.Drawing));
    if IsDrawing then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class function TMarkdownPdfExporterTests.LongDocument: string;
begin
  var Lines: TArray<string>;
  for var Index := 1 to 200 do
  begin
    Lines := Lines + [Format('Paragraph %d of a document that runs over several pages.', [Index])];
  end;

  Result := string.Join(#10#10, Lines);
end;

procedure TMarkdownPdfExporterTests.Geometry_A4MinusTwoCentimetreMargins_At200Dpi;
begin
  Assert.AreEqual(1339, TMarkdownPdfPageGeometry.ContentWidthPixels);
  Assert.AreEqual(2024, TMarkdownPdfPageGeometry.ContentHeightPixels);
  Assert.AreEqual(Double(56.69), Double(TMarkdownPdfPageGeometry.MarginPoints), 0.005);
  Assert.AreEqual(Double(595.28), Double(TMarkdownPdfPageGeometry.PageWidthPoints), 0.005);
  Assert.AreEqual(Double(841.89), Double(TMarkdownPdfPageGeometry.PageHeightPoints), 0.005);
  Assert.AreEqual(Double(200 / 96), Double(TMarkdownPdfPageGeometry.LayoutScale), 0.0001);
end;

procedure TMarkdownPdfExporterTests.BuildLayout_AlwaysLightTheme_UsesLightTextColorAndNoPadding;
begin
  const Light = TMarkdownTheme.CreateLight;
  try
    const DisplayList = TMarkdownPdfExporter.BuildLayout('Plain text', FMeasurer, nil);

    const Run = FirstItemOfKind(DisplayList, TDisplayItemKind.TextRun) as IDisplayTextRun;
    Assert.AreEqual<TLayoutColor>(Light.TextColor, Run.Color);
    Assert.AreEqual(Single(0), DisplayList.BlockInfos[0].Top, 0);
    Assert.AreEqual(Single(0), Run.Bounds.Left, 0);
  finally
    Light.Free;
  end;
end;

procedure TMarkdownPdfExporterTests.BuildLayout_ScalesFontsWithRasterDpi;
begin
  const Theme = TMarkdownTheme.CreateLight;
  try
    Theme.ContentPadding := 0;
    const Document = TMarkdown.Parse('# Heading', TMarkdownDialect.Gfm);
    const Unscaled = TMarkdownLayoutEngine.LayoutDocument(Document, TMarkdownPdfPageGeometry.ContentWidthPixels, Theme,
                                                          FMeasurer);
    const Scaled = TMarkdownPdfExporter.BuildLayout('# Heading', FMeasurer, nil);

    const UnscaledHeight = FirstItemOfKind(Unscaled, TDisplayItemKind.TextRun).Bounds.Height;
    const ScaledHeight = FirstItemOfKind(Scaled, TDisplayItemKind.TextRun).Bounds.Height;
    Assert.AreEqual(Double(TMarkdownPdfPageGeometry.LayoutScale), Double(ScaledHeight / UnscaledHeight),
                    ScaleTolerance);
  finally
    Theme.Free;
  end;
end;

procedure TMarkdownPdfExporterTests.BuildLayout_KnownImageSize_ScalesNaturalSize;
begin
  const Sizes: IMarkdownImageSizeProvider = TFakeImageSizes.CreateForSource(ImageSource, 100, 50);

  const DisplayList = TMarkdownPdfExporter.BuildLayout(ImageMarkdown, FMeasurer, Sizes);

  const Image = FirstItemOfKind(DisplayList, TDisplayItemKind.Image);
  Assert.IsNotNull(Image);
  Assert.AreEqual(Double(100 * 200 / 96), Double(Image.Bounds.Width), 0.1);
  Assert.AreEqual(Double(50 * 200 / 96), Double(Image.Bounds.Height), 0.1);
end;

procedure TMarkdownPdfExporterTests.BuildLayout_WideImage_IsCappedToContentWidth;
begin
  const Sizes: IMarkdownImageSizeProvider = TFakeImageSizes.CreateForSource(ImageSource, 4000, 1000);

  const DisplayList = TMarkdownPdfExporter.BuildLayout(ImageMarkdown, FMeasurer, Sizes);

  const Image = FirstItemOfKind(DisplayList, TDisplayItemKind.Image);
  Assert.IsNotNull(Image);
  Assert.IsTrue(Image.Bounds.Width <= TMarkdownPdfPageGeometry.ContentWidthPixels + 0.5,
                'a wide image must fit the page');
end;

procedure TMarkdownPdfExporterTests.BuildLayout_UnknownImage_GivesPlaceholderSlot;
begin
  const DisplayList = TMarkdownPdfExporter.BuildLayout(ImageMarkdown, FMeasurer, nil);

  const Image = FirstItemOfKind(DisplayList, TDisplayItemKind.Image);
  Assert.IsNotNull(Image, 'an image that is still loading keeps its place');
  Assert.IsTrue(Image.Bounds.Width > 0);
  Assert.IsTrue(Image.Bounds.Height > 0);
end;

procedure TMarkdownPdfExporterTests.BuildLayout_ChartAndMermaid_DrawTheirShapes;
const
  Chart = '```chart'#10 +
          '{"type":"chart","data":{"type":"pie","data":{"labels":["A","B"],"datasets":[{"data":[1,2]}]}}}'#10 +
          '```';
  Mermaid = '```mermaid'#10'pie title Pets'#10'    "Dogs" : 3'#10'    "Cats" : 2'#10'```';
begin
  TMarkdownLayoutEngine.RegisterBlockOverride(TChartBlockOverride.Create, TChartBlockOverride.OverridePriority);
  TLayoutDocumentProcessorRegistry.Register(TChartExtension.ExtensionName, TChartExtension.CreateDocumentProcessor);
  TMarkdownLayoutEngine.RegisterBlockOverride(TMermaidBlockOverride.Create, TMermaidBlockOverride.OverridePriority);
  TLayoutDocumentProcessorRegistry.Register(TMermaidExtension.ExtensionName,
                                            TMermaidExtension.CreateDocumentProcessor);
  try
    const ChartList = TMarkdownPdfExporter.BuildLayout(Chart, FMeasurer, nil);
    const MermaidList = TMarkdownPdfExporter.BuildLayout(Mermaid, FMeasurer, nil);

    Assert.IsTrue(CountOfKind(ChartList, TDisplayItemKind.Wedge) > 0, 'the chart was not drawn');
    Assert.IsTrue(CountOfKind(MermaidList, TDisplayItemKind.Wedge) > 0, 'the diagram was not drawn');
  finally
    TMarkdownLayoutEngine.ClearBlockOverrides;
    TLayoutDocumentProcessorRegistry.Clear;
  end;
end;

procedure TMarkdownPdfExporterTests.BuildLayout_Formula_DrawsItsGlyphs;
begin
  const DisplayList = TMarkdownPdfExporter.BuildLayout('$$'#10'x^2 + y^2'#10'$$', FMeasurer, nil);

  Assert.IsTrue(HasDrawingRun(DisplayList), 'the formula was not drawn');
end;

procedure TMarkdownPdfExporterTests.Export_FakeRasterizer_RasterizesOncePerSliceAndWritesPdf;
begin
  const Rasterizer = TFakePdfRasterizer.Create;
  const RasterizerLifetime: IMarkdownPdfPageRasterizer = Rasterizer;
  const Expected = TMarkdownPagination.Paginate(TMarkdownPdfExporter.BuildLayout(LongDocument, FMeasurer, nil),
                                                TMarkdownPdfPageGeometry.ContentHeightPixels);

  const Stream = TMemoryStream.Create;
  try
    TMarkdownPdfExporter.Export(LongDocument, RasterizerLifetime, Stream);

    const Data = TMarkdownTestPdfReader.BytesOf(Stream);
    Assert.IsTrue(Length(Expected) > 1, 'the document should need several pages');
    Assert.AreEqual(Integer(Length(Expected)), Rasterizer.PageCount);
    Assert.AreEqual(Integer(Length(Expected)), TMarkdownTestPdfReader.PageCount(Data));
    Assert.IsTrue(TMarkdownTestPdfReader.AsText(Data).StartsWith('%PDF-1.4'), 'not a PDF');
  finally
    Stream.Free;
  end;

  const Light = TMarkdownTheme.CreateLight;
  try
    Assert.AreEqual<TLayoutColor>(Light.BackgroundColor, Rasterizer.Background);
  finally
    Light.Free;
  end;
end;

procedure TMarkdownPdfExporterTests.Export_NilRasterizer_RaisesEMarkdownPdfExportError;
begin
  const Stream = TMemoryStream.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        TMarkdownPdfExporter.Export('Text', nil, Stream);
      end,
      EMarkdownPdfExportError,
      'GuardRasterizer must refuse a missing rasterizer');
  finally
    Stream.Free;
  end;
end;

procedure TMarkdownPdfExporterTests.Export_NilStream_RaisesEMarkdownPdfExportError;
begin
  const Rasterizer: IMarkdownPdfPageRasterizer = TFakePdfRasterizer.Create;

  Assert.WillRaise(
    procedure
    begin
      TMarkdownPdfExporter.Export('Text', Rasterizer, nil);
    end,
    EMarkdownPdfExportError,
    'GuardStream must refuse a missing stream');
end;

end.
