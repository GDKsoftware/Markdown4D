unit Markdown4D.Export.Pdf.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Tests.FakePdfRasterizer,
  Markdown4D.Tests.RecordingPainter;

type
  [TestFixture]
  TMarkdownPdfExporterTests = class
  private
    const
      Tolerance = 0.01;
      LongDocumentParagraphs = 120;
      WhitePage = TLayoutColor($FFFFFFFF);
      BulletText = #$2022;
      ParagraphText = 'Paragraph';
      DiagramLabel = 'Start';
      MermaidDiagram =
        ParagraphText + #10#10 +
        '```mermaid'#10 +
        'graph TD'#10 +
        '  A[' + DiagramLabel + '] --> B[Finish]'#10 +
        '```'#10;
      NestedList =
        '- one'#10 +
        '  - two'#10 +
        '  - three'#10 +
        '- four'#10;
      ImageSource = 'picture.png';
      ImageWidth = 200.0;
      ImageHeight = 100.0;
      SettlesAfterChecks = 3;
    var
      FRasterizer: TFakePdfRasterizer;
      FRasterizerLifetime: IInterface;
      FStream: TBytesStream;
    function Export(const Markdown: string): string;
    function Layout(const Markdown: string): IMarkdownDisplayList;
    class function LongDocument: string; static;
    class function FindTextRun(const DisplayList: IMarkdownDisplayList; const Text: string): IDisplayTextRun; static;
    class function FindRecordedRun(const Page: TRecordingPainter; const Text: string): TRecordedPrimitive; static;

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
    procedure BuildLayout_LaysOutAt96Dpi_SameFontSizesAsPreviewAt100Percent;

    [Test]
    procedure ImageSources_DocumentWithImages_ReturnsUniqueSourcesInOrder;

    [Test]
    procedure Export_FakeRasterizer_BeginsAndEndsOncePerSliceAndWritesPdf;

    [Test]
    procedure Export_LongDocument_WritesMoreThanOnePage;

    [Test]
    procedure Export_MermaidDiagram_KeepsLabelToTextRatio;

    [Test]
    procedure Export_NestedList_DrawsOneBulletPerItem;

    [Test]
    procedure Export_FillsWholeRasterWithLightBackground;

    [Test]
    procedure Export_LoadedImage_IsDrawnAtItsSizeAt200Dpi;

    [Test]
    procedure ExportWithImages_DocumentWithImages_RequestsUniqueSourcesAndPumpsUntilSettled;

    [Test]
    procedure ExportWithImages_DocumentWithoutImages_RequestsNothing;

    [Test]
    procedure ExportWithImages_NilRasterizer_RaisesEMarkdownPdfExportError;

    [Test]
    procedure Export_NilRasterizer_RaisesEMarkdownPdfExportError;
  end;

implementation

uses
  Markdown4D.Theme,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Extensions.Mermaid,
  Markdown4D.Extensions.Mermaid.BlockOverride,
  Markdown4D.Export.Pdf,
  Markdown4D.Export.Pdf.Errors,
  Markdown4D.Export.Pdf.Geometry,
  Markdown4D.Tests.PdfReader;

procedure TMarkdownPdfExporterTests.Setup;
begin
  FRasterizer := TFakePdfRasterizer.Create;
  FRasterizerLifetime := FRasterizer;
  FStream := TBytesStream.Create;
end;

procedure TMarkdownPdfExporterTests.TearDown;
begin
  TMarkdownLayoutEngine.ClearBlockOverrides;
  TLayoutDocumentProcessorRegistry.Clear;

  FStream.Free;
  FRasterizer := nil;
  FRasterizerLifetime := nil;
end;

function TMarkdownPdfExporterTests.Export(const Markdown: string): string;
begin
  TMarkdownPdfExporter.Export(Markdown, FRasterizer, FStream);

  const Bytes = Copy(FStream.Bytes, 0, FStream.Size);
  Result := TMarkdownTestPdfReader.AsText(Bytes);
end;

function TMarkdownPdfExporterTests.Layout(const Markdown: string): IMarkdownDisplayList;
begin
  Result := TMarkdownPdfExporter.BuildLayout(Markdown, FRasterizer.Measurer, FRasterizer);
end;

class function TMarkdownPdfExporterTests.LongDocument: string;
begin
  Result := '';
  for var Index := 1 to LongDocumentParagraphs do
  begin
    Result := Result + Format('Paragraph %d'#10#10, [Index]);
  end;
end;

class function TMarkdownPdfExporterTests.FindTextRun(const DisplayList: IMarkdownDisplayList;
  const Text: string): IDisplayTextRun;
begin
  Result := nil;
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    if Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and (Run.Text = Text) then
    begin
      Result := Run;
      Exit;
    end;
  end;

  Assert.Fail(Format('The layout has no text run "%s"', [Text]));
end;

class function TMarkdownPdfExporterTests.FindRecordedRun(const Page: TRecordingPainter;
  const Text: string): TRecordedPrimitive;
begin
  Result := Default(TRecordedPrimitive);
  for var Recorded in Page.OfKind(TRecordedPrimitiveKind.TextRun) do
  begin
    if Recorded.Text = Text then
    begin
      Result := Recorded;
      Exit;
    end;
  end;

  Assert.Fail(Format('The page painted no text "%s"', [Text]));
end;

procedure TMarkdownPdfExporterTests.Geometry_A4MinusTwoCentimetreMargins_At200Dpi;
begin
  const PixelsAcross = TMarkdownPdfPageGeometry.ContentWidthPoints / TMarkdownPdfPageGeometry.PointsPerInch *
    TMarkdownPdfPageGeometry.RasterDpi;
  const PixelsDown = TMarkdownPdfPageGeometry.ContentHeightPoints / TMarkdownPdfPageGeometry.PointsPerInch *
    TMarkdownPdfPageGeometry.RasterDpi;

  Assert.AreEqual(1339, TMarkdownPdfPageGeometry.RasterWidthPixels);
  Assert.AreEqual(2024, TMarkdownPdfPageGeometry.RasterHeightPixels);
  Assert.AreEqual(Double(TMarkdownPdfPageGeometry.RasterWidthPixels), PixelsAcross, 0.5);
  Assert.AreEqual(Double(TMarkdownPdfPageGeometry.RasterHeightPixels), PixelsDown, 0.5);
  Assert.AreEqual(56.69, TMarkdownPdfPageGeometry.MarginPoints, Tolerance);
  Assert.AreEqual(642.72, TMarkdownPdfPageGeometry.LayoutWidth, Tolerance);
  Assert.AreEqual(971.52, TMarkdownPdfPageGeometry.LayoutPageHeight, Tolerance);
end;

procedure TMarkdownPdfExporterTests.BuildLayout_AlwaysLightTheme_UsesLightTextColorAndNoPadding;
begin
  const Light = TMarkdownTheme.CreateLight;
  try
    const DisplayList = Layout(ParagraphText);
    const Run = FindTextRun(DisplayList, ParagraphText);

    Assert.AreEqual<TLayoutColor>(Light.TextColor, Run.Color);
    Assert.AreEqual(0.0, Run.Bounds.Left, Tolerance, 'no padding before the text');
    Assert.AreEqual(Double(TMarkdownPdfPageGeometry.LayoutWidth), DisplayList.Width, Tolerance);
  finally
    Light.Free;
  end;
end;

procedure TMarkdownPdfExporterTests.BuildLayout_LaysOutAt96Dpi_SameFontSizesAsPreviewAt100Percent;
begin
  const Light = TMarkdownTheme.CreateLight;
  try
    const Run = FindTextRun(Layout(ParagraphText), ParagraphText);

    Assert.AreEqual(Light.BaseFont.Size, Run.Font.Size, Tolerance);
  finally
    Light.Free;
  end;
end;

procedure TMarkdownPdfExporterTests.ImageSources_DocumentWithImages_ReturnsUniqueSourcesInOrder;
begin
  const DisplayList = Layout('![a](one.png) ![b](two.png)'#10#10'![c](one.png)');

  const Sources = TMarkdownPdfExporter.ImageSources(DisplayList);

  Assert.AreEqual(2, Integer(Length(Sources)));
  Assert.AreEqual('one.png', Sources[0]);
  Assert.AreEqual('two.png', Sources[1]);
end;

procedure TMarkdownPdfExporterTests.Export_FakeRasterizer_BeginsAndEndsOncePerSliceAndWritesPdf;
begin
  const Pdf = Export('# Title'#10#10 + ParagraphText);

  Assert.AreEqual(1, Integer(Length(FRasterizer.Pages)));
  Assert.AreEqual(1, FRasterizer.EndPageCount);
  Assert.IsTrue(Pdf.StartsWith('%PDF-1.4'), 'a PDF header');
  Assert.IsTrue(Pdf.Contains('/Count 1'), 'one page');
end;

procedure TMarkdownPdfExporterTests.Export_LongDocument_WritesMoreThanOnePage;
begin
  const Pdf = Export(LongDocument);

  const PageCount = Integer(Length(FRasterizer.Pages));
  Assert.IsTrue(PageCount > 1, 'a long document runs over more pages');
  Assert.AreEqual(PageCount, FRasterizer.EndPageCount);
  Assert.IsTrue(Pdf.Contains(Format('/Count %d', [PageCount])), 'every page is in the PDF');
  Assert.AreEqual(PageCount, TMarkdownTestPdfReader.Occurrences(Pdf, TMarkdownTestPdfReader.PageObjectMarker));
end;

procedure TMarkdownPdfExporterTests.Export_MermaidDiagram_KeepsLabelToTextRatio;
begin
  TMarkdownLayoutEngine.RegisterBlockOverride(TMermaidBlockOverride.Create, TMermaidBlockOverride.OverridePriority);
  TLayoutDocumentProcessorRegistry.Register(TMermaidExtension.ExtensionName, TMermaidExtension.CreateDocumentProcessor);

  const DisplayList = Layout(MermaidDiagram);
  const LayoutLabel = FindTextRun(DisplayList, DiagramLabel);
  const LayoutParagraph = FindTextRun(DisplayList, ParagraphText);
  const LayoutRatio = LayoutLabel.Font.Size / LayoutParagraph.Font.Size;

  Export(MermaidDiagram);

  const Page = FRasterizer.Pages[0];
  const PaintedLabel = FindRecordedRun(Page, DiagramLabel);
  const PaintedParagraph = FindRecordedRun(Page, ParagraphText);
  Assert.AreEqual(LayoutRatio, PaintedLabel.Font.Size / PaintedParagraph.Font.Size, Tolerance);
  Assert.AreEqual(TMarkdownPdfPageGeometry.RasterScale * LayoutParagraph.Font.Size, PaintedParagraph.Font.Size,
    Tolerance, 'the page is painted at 200 dpi');
end;

procedure TMarkdownPdfExporterTests.Export_NestedList_DrawsOneBulletPerItem;
begin
  Export(NestedList);

  var BulletCount := 0;
  for var Recorded in FRasterizer.Pages[0].OfKind(TRecordedPrimitiveKind.TextRun) do
  begin
    if Recorded.Text = BulletText then
      Inc(BulletCount);
  end;

  Assert.AreEqual(4, BulletCount);
end;

procedure TMarkdownPdfExporterTests.Export_FillsWholeRasterWithLightBackground;
begin
  Export(LongDocument);

  for var Background in FRasterizer.Backgrounds do
  begin
    Assert.AreEqual<TLayoutColor>(WhitePage, Background);
  end;

  const FirstPageFills = FRasterizer.Pages[0].OfKind(TRecordedPrimitiveKind.FillRect);
  Assert.IsTrue(Length(FirstPageFills) > 0, 'the page is filled');
  Assert.AreEqual<TLayoutColor>(WhitePage, FirstPageFills[0].Color);
  Assert.AreEqual(0.0, FirstPageFills[0].Bounds.Left, Tolerance);
  Assert.AreEqual(0.0, FirstPageFills[0].Bounds.Top, Tolerance);
  Assert.AreEqual(Double(TMarkdownPdfPageGeometry.RasterWidthPixels), FirstPageFills[0].Bounds.Right, 0.5);
end;

procedure TMarkdownPdfExporterTests.Export_LoadedImage_IsDrawnAtItsSizeAt200Dpi;
begin
  FRasterizer.AddImage(ImageSource, TLayoutSizeF.Create(ImageWidth, ImageHeight));

  const Markdown = Format('![photo](%s)', [ImageSource]);
  Export(Markdown);

  const Images = FRasterizer.Pages[0].OfKind(TRecordedPrimitiveKind.Image);
  Assert.AreEqual(1, Integer(Length(Images)));
  Assert.AreEqual(ImageSource, Images[0].Text);
  Assert.AreEqual(ImageWidth * TMarkdownPdfPageGeometry.RasterScale, Images[0].Bounds.Width, Tolerance);
  Assert.AreEqual(ImageHeight * TMarkdownPdfPageGeometry.RasterScale, Images[0].Bounds.Height, Tolerance);
end;

procedure TMarkdownPdfExporterTests.ExportWithImages_DocumentWithImages_RequestsUniqueSourcesAndPumpsUntilSettled;
begin
  var RequestedSources: TArray<string> := [];
  var PumpCount := 0;
  var SettledChecks := 0;
  const Markdown = '![a](one.png) ![b](two.png)'#10#10'![c](one.png)';

  TMarkdownPdfExporter.ExportWithImages(Markdown, FRasterizer, FStream,
    procedure(Sources: TArray<string>)
    begin
      RequestedSources := Sources;
    end,
    function(Sources: TArray<string>): Boolean
    begin
      Inc(SettledChecks);
      Result := (SettledChecks > SettlesAfterChecks);
    end,
    procedure
    begin
      Inc(PumpCount);
    end);

  Assert.AreEqual(2, Integer(Length(RequestedSources)));
  Assert.AreEqual('one.png', RequestedSources[0]);
  Assert.AreEqual('two.png', RequestedSources[1]);
  Assert.AreEqual(SettlesAfterChecks, PumpCount);
  Assert.AreEqual(1, Integer(Length(FRasterizer.Pages)));
end;

procedure TMarkdownPdfExporterTests.ExportWithImages_DocumentWithoutImages_RequestsNothing;
begin
  var WasRequested := False;

  TMarkdownPdfExporter.ExportWithImages(ParagraphText, FRasterizer, FStream,
    procedure(Sources: TArray<string>)
    begin
      WasRequested := True;
    end,
    function(Sources: TArray<string>): Boolean
    begin
      Result := True;
    end,
    procedure
    begin
    end);

  Assert.IsFalse(WasRequested);
  Assert.AreEqual(1, Integer(Length(FRasterizer.Pages)));
end;

procedure TMarkdownPdfExporterTests.ExportWithImages_NilRasterizer_RaisesEMarkdownPdfExportError;
begin
  const Stream = FStream;

  Assert.WillRaise(
    procedure
    begin
      TMarkdownPdfExporter.ExportWithImages(ParagraphText, nil, Stream,
        procedure(Sources: TArray<string>)
        begin
        end,
        function(Sources: TArray<string>): Boolean
        begin
          Result := True;
        end,
        procedure
        begin
        end);
    end,
    EMarkdownPdfExportError);
end;

procedure TMarkdownPdfExporterTests.Export_NilRasterizer_RaisesEMarkdownPdfExportError;
begin
  const Stream = FStream;

  Assert.WillRaise(
    procedure
    begin
      TMarkdownPdfExporter.Export(ParagraphText, nil, Stream);
    end,
    EMarkdownPdfExportError);
end;

end.
