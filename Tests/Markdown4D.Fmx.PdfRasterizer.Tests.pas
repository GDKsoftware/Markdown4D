unit Markdown4D.Fmx.PdfRasterizer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  FMX.Graphics,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Export.Pdf.Interfaces;

type
  [TestFixture]
  TMarkdownFmxPdfRasterizerTests = class
  private
    const
      ImageSource = 'red.png';
      ImageSide = 60;
    var
      FRedImage: TBitmap;
    function ResolveImage(const Source: string): TBitmap;
    function NoImage(const Source: string): TBitmap;
    function IsNeverBroken(const Source: string): Boolean;
    function CreateRasterizer: IMarkdownPdfPageRasterizer;
    class function LightBackground: TLayoutColor; static;
    function RasterizeFirstPage(const Markdown: string): TMarkdownPdfPageImage;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure RasterizePage_Text_GivesContentSizedRgbPageWithDarkInk;

    [Test]
    procedure RasterizePage_BelowTheDocument_IsWhite;

    [Test]
    procedure RasterizePage_SecondSlice_ShowsTheContentBelowTheFirstPage;

    [Test]
    procedure RasterizePage_LoadedImage_IsDrawn;

    [Test]
    procedure TryGetImageSize_LoadedImage_AnswersNaturalSize;

    [Test]
    procedure TryGetImageSize_ImageNotLoaded_ReturnsFalse;

    [Test]
    procedure ExportToPdf_DarkViewer_WritesLightPdf;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Markdown4D.Theme,
  Markdown4D.Export.Pagination,
  Markdown4D.Export.Pdf,
  Markdown4D.Export.Pdf.Geometry,
  Markdown4D.Fmx.PdfRasterizer,
  Markdown4D.Fmx.Viewer,
  Markdown4D.Tests.PdfReader;

procedure TMarkdownFmxPdfRasterizerTests.Setup;
begin
  FRedImage := TBitmap.Create(ImageSide, ImageSide);
  FRedImage.Clear(TAlphaColors.Red);
end;

procedure TMarkdownFmxPdfRasterizerTests.TearDown;
begin
  FRedImage.Free;
end;

function TMarkdownFmxPdfRasterizerTests.ResolveImage(const Source: string): TBitmap;
begin
  if Source = ImageSource then
    Result := FRedImage
  else
    Result := nil;
end;

function TMarkdownFmxPdfRasterizerTests.NoImage(const Source: string): TBitmap;
begin
  Result := nil;
end;

function TMarkdownFmxPdfRasterizerTests.IsNeverBroken(const Source: string): Boolean;
begin
  Result := False;
end;

function TMarkdownFmxPdfRasterizerTests.CreateRasterizer: IMarkdownPdfPageRasterizer;
begin
  Result := TMarkdownFmxPdfRasterizer.Create(ResolveImage, IsNeverBroken);
end;

class function TMarkdownFmxPdfRasterizerTests.LightBackground: TLayoutColor;
begin
  const Light = TMarkdownTheme.CreateLight;
  try
    Result := Light.BackgroundColor;
  finally
    Light.Free;
  end;
end;

function TMarkdownFmxPdfRasterizerTests.RasterizeFirstPage(const Markdown: string): TMarkdownPdfPageImage;
begin
  const Rasterizer = CreateRasterizer;
  const DisplayList = TMarkdownPdfExporter.BuildLayout(Markdown, Rasterizer.Measurer, Rasterizer);
  const Slices = TMarkdownPagination.Paginate(DisplayList, TMarkdownPdfPageGeometry.ContentHeightPixels);

  Result := Rasterizer.RasterizePage(DisplayList, Slices[0], LightBackground);
end;

procedure TMarkdownFmxPdfRasterizerTests.RasterizePage_Text_GivesContentSizedRgbPageWithDarkInk;
begin
  const Page = RasterizeFirstPage('# Heading'#10#10'Some **bold** text.');

  Assert.AreEqual(TMarkdownPdfPageGeometry.ContentWidthPixels, Page.Width);
  Assert.AreEqual(TMarkdownPdfPageGeometry.ContentHeightPixels, Page.Height);
  Assert.AreEqual(Page.Width * Page.Height * 3, Integer(Length(Page.Pixels)));
  Assert.IsTrue(TMarkdownTestPdfReader.DarkPixelCount(Page.Pixels) > 0, 'no text was drawn');
end;

procedure TMarkdownFmxPdfRasterizerTests.RasterizePage_BelowTheDocument_IsWhite;
begin
  const Page = RasterizeFirstPage('One line.');

  Assert.IsTrue(TMarkdownTestPdfReader.IsWhiteAt(Page.Pixels, Page.Width, Page.Width - 1, Page.Height - 1));
  Assert.IsTrue(TMarkdownTestPdfReader.IsWhiteAt(Page.Pixels, Page.Width, Page.Width div 2, Page.Height div 2));
end;

procedure TMarkdownFmxPdfRasterizerTests.RasterizePage_SecondSlice_ShowsTheContentBelowTheFirstPage;
begin
  var Lines: TArray<string>;
  for var Index := 1 to 120 do
  begin
    Lines := Lines + [Format('Paragraph %d', [Index])];
  end;

  const Rasterizer = CreateRasterizer;
  const Markdown = string.Join(#10#10, Lines);
  const DisplayList = TMarkdownPdfExporter.BuildLayout(Markdown, Rasterizer.Measurer, Rasterizer);
  const Slices = TMarkdownPagination.Paginate(DisplayList, TMarkdownPdfPageGeometry.ContentHeightPixels);
  Assert.IsTrue(Length(Slices) > 1, 'the document should need two pages');

  const Page = Rasterizer.RasterizePage(DisplayList, Slices[1], LightBackground);

  Assert.IsTrue(TMarkdownTestPdfReader.DarkPixelCount(Page.Pixels) > 0, 'the second page is blank');
end;

procedure TMarkdownFmxPdfRasterizerTests.RasterizePage_LoadedImage_IsDrawn;
begin
  const ImageMarkdown = Format('![red](%s)', [ImageSource]);
  const Page = RasterizeFirstPage(ImageMarkdown);

  Assert.IsTrue(TMarkdownTestPdfReader.HasPixel(Page.Pixels, 255, 0, 0, 8), 'the loaded image is missing');
end;

procedure TMarkdownFmxPdfRasterizerTests.TryGetImageSize_LoadedImage_AnswersNaturalSize;
begin
  const Rasterizer = CreateRasterizer;

  var Size: TLayoutSizeF;
  const Found = Rasterizer.TryGetImageSize(ImageSource, Size);

  Assert.IsTrue(Found);
  Assert.AreEqual(Single(ImageSide), Size.Width, 0);
  Assert.AreEqual(Single(ImageSide), Size.Height, 0);
end;

procedure TMarkdownFmxPdfRasterizerTests.TryGetImageSize_ImageNotLoaded_ReturnsFalse;
begin
  const Rasterizer: IMarkdownPdfPageRasterizer = TMarkdownFmxPdfRasterizer.Create(NoImage, IsNeverBroken);

  var Size: TLayoutSizeF;
  const Found = Rasterizer.TryGetImageSize(ImageSource, Size);

  Assert.IsFalse(Found);
end;

procedure TMarkdownFmxPdfRasterizerTests.ExportToPdf_DarkViewer_WritesLightPdf;
begin
  const Viewer = TMarkdownViewer.Create(nil);
  const Stream = TMemoryStream.Create;
  try
    Viewer.ThemePreset := TMarkdownThemePreset.Dark;
    Viewer.Text := '# Heading'#10#10'Some text.';

    Viewer.ExportToPdf(Stream);

    const Data = TMarkdownTestPdfReader.BytesOf(Stream);
    var Width: Integer;
    var Height: Integer;
    const Pixels = TMarkdownTestPdfReader.FirstImage(Data, Width, Height);
    Assert.AreEqual(1, TMarkdownTestPdfReader.PageCount(Data));
    Assert.IsTrue(TMarkdownTestPdfReader.IsWhiteAt(Pixels, Width, Width - 1, 0), 'the paper is not light');
    Assert.IsTrue(TMarkdownTestPdfReader.DarkPixelCount(Pixels) > 0, 'the text is not dark');
  finally
    Stream.Free;
    Viewer.Free;
  end;
end;

end.
