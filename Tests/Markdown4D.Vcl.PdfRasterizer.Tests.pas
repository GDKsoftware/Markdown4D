unit Markdown4D.Vcl.PdfRasterizer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Vcl.Graphics,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Export.Pdf.Interfaces;

type
  [TestFixture]
  TMarkdownVclPdfRasterizerTests = class
  private
    const
      ImageSource = 'red.bmp';
      SampleText = 'Some text.';
      ImageSide = 60;
    var
      FRedImage: TBitmap;
    function ResolveImage(const Source: string): TGraphic;
    function NoImage(const Source: string): TGraphic;
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

    [Test]
    procedure ExportToPdf_File_WritesPdfFile;

    [Test]
    procedure ExportToPdf_FolderMissing_RaisesAndWritesNothing;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  System.Classes,
  System.IOUtils,
  Markdown4D.Theme,
  Markdown4D.Export.Pagination,
  Markdown4D.Export.Pdf,
  Markdown4D.Export.Pdf.Geometry,
  Markdown4D.Vcl.PdfRasterizer,
  Markdown4D.Vcl.Viewer,
  Markdown4D.Tests.PdfReader;

procedure TMarkdownVclPdfRasterizerTests.Setup;
begin
  FRedImage := TBitmap.Create;
  FRedImage.PixelFormat := pf24bit;
  FRedImage.SetSize(ImageSide, ImageSide);
  FRedImage.Canvas.Brush.Color := clRed;
  FRedImage.Canvas.FillRect(Rect(0, 0, ImageSide, ImageSide));
end;

procedure TMarkdownVclPdfRasterizerTests.TearDown;
begin
  FRedImage.Free;
end;

function TMarkdownVclPdfRasterizerTests.ResolveImage(const Source: string): TGraphic;
begin
  if Source = ImageSource then
    Result := FRedImage
  else
    Result := nil;
end;

function TMarkdownVclPdfRasterizerTests.NoImage(const Source: string): TGraphic;
begin
  Result := nil;
end;

function TMarkdownVclPdfRasterizerTests.IsNeverBroken(const Source: string): Boolean;
begin
  Result := False;
end;

function TMarkdownVclPdfRasterizerTests.CreateRasterizer: IMarkdownPdfPageRasterizer;
begin
  Result := TMarkdownVclPdfRasterizer.Create(ResolveImage, IsNeverBroken);
end;

class function TMarkdownVclPdfRasterizerTests.LightBackground: TLayoutColor;
begin
  const Light = TMarkdownTheme.CreateLight;
  try
    Result := Light.BackgroundColor;
  finally
    Light.Free;
  end;
end;

function TMarkdownVclPdfRasterizerTests.RasterizeFirstPage(const Markdown: string): TMarkdownPdfPageImage;
begin
  const Rasterizer = CreateRasterizer;
  const DisplayList = TMarkdownPdfExporter.BuildLayout(Markdown, Rasterizer.Measurer, Rasterizer);
  const Slices = TMarkdownPagination.Paginate(DisplayList, TMarkdownPdfPageGeometry.ContentHeightPixels);

  Result := Rasterizer.RasterizePage(DisplayList, Slices[0], LightBackground);
end;

procedure TMarkdownVclPdfRasterizerTests.RasterizePage_Text_GivesContentSizedRgbPageWithDarkInk;
begin
  const Page = RasterizeFirstPage('# Heading'#10#10'Some **bold** text.');

  Assert.AreEqual(TMarkdownPdfPageGeometry.ContentWidthPixels, Page.Width);
  Assert.AreEqual(TMarkdownPdfPageGeometry.ContentHeightPixels, Page.Height);
  Assert.AreEqual(Page.Width * Page.Height * 3, Integer(Length(Page.Pixels)));
  Assert.IsTrue(TMarkdownTestPdfReader.DarkPixelCount(Page.Pixels) > 0, 'no text was drawn');
end;

procedure TMarkdownVclPdfRasterizerTests.RasterizePage_BelowTheDocument_IsWhite;
begin
  const Page = RasterizeFirstPage('One line.');

  Assert.IsTrue(TMarkdownTestPdfReader.IsWhiteAt(Page.Pixels, Page.Width, Page.Width - 1, Page.Height - 1));
  Assert.IsTrue(TMarkdownTestPdfReader.IsWhiteAt(Page.Pixels, Page.Width, Page.Width div 2, Page.Height div 2));
end;

procedure TMarkdownVclPdfRasterizerTests.RasterizePage_SecondSlice_ShowsTheContentBelowTheFirstPage;
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

procedure TMarkdownVclPdfRasterizerTests.RasterizePage_LoadedImage_IsDrawn;
begin
  const ImageMarkdown = Format('![red](%s)', [ImageSource]);
  const Page = RasterizeFirstPage(ImageMarkdown);

  Assert.IsTrue(TMarkdownTestPdfReader.HasPixel(Page.Pixels, 255, 0, 0, 8), 'the loaded image is missing');
end;

procedure TMarkdownVclPdfRasterizerTests.TryGetImageSize_LoadedImage_AnswersNaturalSize;
begin
  const Rasterizer = CreateRasterizer;

  var Size: TLayoutSizeF;
  const Found = Rasterizer.TryGetImageSize(ImageSource, Size);

  Assert.IsTrue(Found);
  Assert.AreEqual(Single(ImageSide), Size.Width, 0);
  Assert.AreEqual(Single(ImageSide), Size.Height, 0);
end;

procedure TMarkdownVclPdfRasterizerTests.TryGetImageSize_ImageNotLoaded_ReturnsFalse;
begin
  const Rasterizer: IMarkdownPdfPageRasterizer = TMarkdownVclPdfRasterizer.Create(NoImage, IsNeverBroken);

  var Size: TLayoutSizeF;
  const Found = Rasterizer.TryGetImageSize(ImageSource, Size);

  Assert.IsFalse(Found);
end;

procedure TMarkdownVclPdfRasterizerTests.ExportToPdf_DarkViewer_WritesLightPdf;
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

procedure TMarkdownVclPdfRasterizerTests.ExportToPdf_File_WritesPdfFile;
begin
  const PdfName = Format('%s.pdf', [TPath.GetGUIDFileName]);
  const FileName = TPath.Combine(TPath.GetTempPath, PdfName);
  const Viewer = TMarkdownViewer.Create(nil);
  try
    Viewer.Text := SampleText;

    Viewer.ExportToPdf(FileName);

    Assert.IsTrue(TFile.Exists(FileName), 'no file was written');
    const Data = TFile.ReadAllBytes(FileName);
    const PdfText = TMarkdownTestPdfReader.AsText(Data);
    Assert.IsTrue(PdfText.StartsWith('%PDF-1.4'), 'the file is not a PDF');
  finally
    Viewer.Free;
    if TFile.Exists(FileName) then
      TFile.Delete(FileName);
  end;
end;

procedure TMarkdownVclPdfRasterizerTests.ExportToPdf_FolderMissing_RaisesAndWritesNothing;
begin
  const Folder = TPath.Combine(TPath.GetTempPath, TPath.GetGUIDFileName);
  const FileName = TPath.Combine(Folder, 'document.pdf');
  const Viewer = TMarkdownViewer.Create(nil);
  try
    Viewer.Text := SampleText;

    Assert.WillRaise(
      procedure
      begin
        Viewer.ExportToPdf(FileName);
      end,
      EFCreateError);

    Assert.IsFalse(TFile.Exists(FileName));
  finally
    Viewer.Free;
  end;
end;

end.
