unit Markdown4D.Vcl.PdfRasterizer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Export.Pdf.Interfaces;

type
  [TestFixture]
  TMarkdownVclPdfRasterizerTests = class
  private
    const
      WhitePage = TLayoutColor($FFFFFFFF);
      RedFill = TLayoutColor($FFFF0000);
      FullChannel = $FF;
      FilledLeft = 10;
      FilledTop = 20;
      FilledSize = 30;
      ImageSource = 'square.bmp';
      ImageWidth = 30;
      ImageHeight = 20;
      LongDocumentParagraphs = 150;
      GreenSquareSize = 60;
      MissingImageSource = 'missing.png';
      MissingFrameSize = 100;
      MissingFrameCenter = 50;
    var
      FImage: TBitmap;
      FImageFileName: string;
    function ResolveImage(const Source: string): TGraphic;
    class function PixelAt(const Page: TMarkdownPdfPageImage; const X, Y: Integer): TBytes; static;
    class function HasPureGreenPixel(const Pixels: TBytes): Boolean; static;
    class function LongDocument: string; static;
    procedure WriteGreenSquare;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure EndPage_WhiteBackground_IsWhiteRgbOfRasterSize;

    [Test]
    procedure EndPage_RedFill_ConvertsBgrToRgb;

    [Test]
    procedure TryGetImageSize_ResolvedImage_AnswersItsPixelSize;

    [Test]
    procedure BeginPage_ImageNotResolved_DrawsFrameWithCross;

    [Test]
    procedure ExportToPdf_LongDocument_WritesMoreThanOnePage;

    [Test]
    procedure ExportToPdf_LocalImageNotYetLoaded_LoadsItBeforeRasterizing;
  end;

implementation

uses
  System.IOUtils,
  Markdown4D.Vcl.PdfRasterizer,
  Markdown4D.Vcl.Viewer,
  Markdown4D.Export.Pdf.Geometry,
  Markdown4D.Tests.PdfReader;

procedure TMarkdownVclPdfRasterizerTests.Setup;
begin
  FImage := TBitmap.Create;
  FImage.SetSize(ImageWidth, ImageHeight);
  FImageFileName := TPath.Combine(TPath.GetTempPath, Format('%s.bmp', [TPath.GetGUIDFileName]));
end;

procedure TMarkdownVclPdfRasterizerTests.TearDown;
begin
  FImage.Free;
  if TFile.Exists(FImageFileName) then
    TFile.Delete(FImageFileName);
end;

function TMarkdownVclPdfRasterizerTests.ResolveImage(const Source: string): TGraphic;
begin
  Result := nil;
  if Source = ImageSource then
    Result := FImage;
end;

class function TMarkdownVclPdfRasterizerTests.PixelAt(const Page: TMarkdownPdfPageImage; const X, Y: Integer): TBytes;
begin
  const Offset = ((Y * Page.Width) + X) * TMarkdownPdfPageImage.BytesPerPixel;
  Result := Copy(Page.Pixels, Offset, TMarkdownPdfPageImage.BytesPerPixel);
end;

class function TMarkdownVclPdfRasterizerTests.HasPureGreenPixel(const Pixels: TBytes): Boolean;
begin
  var Offset := 0;
  while Offset + 2 < Length(Pixels) do
  begin
    const IsGreen = ((Pixels[Offset] = 0) and (Pixels[Offset + 1] = FullChannel) and (Pixels[Offset + 2] = 0));
    if IsGreen then
    begin
      Result := True;
      Exit;
    end;

    Inc(Offset, TMarkdownPdfPageImage.BytesPerPixel);
  end;

  Result := False;
end;

class function TMarkdownVclPdfRasterizerTests.LongDocument: string;
begin
  Result := '';
  for var Index := 1 to LongDocumentParagraphs do
  begin
    Result := Result + Format('Paragraph %d with some words in it'#10#10, [Index]);
  end;
end;

procedure TMarkdownVclPdfRasterizerTests.WriteGreenSquare;
begin
  const Square = TBitmap.Create;
  try
    Square.PixelFormat := pf24bit;
    Square.SetSize(GreenSquareSize, GreenSquareSize);
    Square.Canvas.Brush.Color := clLime;
    Square.Canvas.FillRect(Rect(0, 0, GreenSquareSize, GreenSquareSize));
    Square.SaveToFile(FImageFileName);
  finally
    Square.Free;
  end;
end;

procedure TMarkdownVclPdfRasterizerTests.EndPage_WhiteBackground_IsWhiteRgbOfRasterSize;
begin
  const Rasterizer: IMarkdownPdfPageRasterizer = TMarkdownVclPdfRasterizer.Create(nil);

  Rasterizer.BeginPage(WhitePage);
  const Page = Rasterizer.EndPage;

  Assert.AreEqual(TMarkdownPdfPageGeometry.RasterWidthPixels, Page.Width);
  Assert.AreEqual(TMarkdownPdfPageGeometry.RasterHeightPixels, Page.Height);
  const HasEveryPixel = (Length(Page.Pixels) = Page.ExpectedByteCount);
  Assert.IsTrue(HasEveryPixel, 'three bytes for every pixel');
  for var Channel in Page.Pixels do
  begin
    if Channel <> FullChannel then
      Assert.Fail('the page has a pixel that is not white');
  end;
end;

procedure TMarkdownVclPdfRasterizerTests.EndPage_RedFill_ConvertsBgrToRgb;
begin
  const Rasterizer: IMarkdownPdfPageRasterizer = TMarkdownVclPdfRasterizer.Create(nil);
  const Painter = Rasterizer.BeginPage(WhitePage);
  const Filled = TLayoutRectF.Create(FilledLeft, FilledTop, FilledLeft + FilledSize, FilledTop + FilledSize);

  Painter.FillRect(Filled, RedFill);
  const Page = Rasterizer.EndPage;

  const Inside = PixelAt(Page, FilledLeft + (FilledSize div 2), FilledTop + (FilledSize div 2));
  Assert.AreEqual(FullChannel, Integer(Inside[0]), 'red');
  Assert.AreEqual(0, Integer(Inside[1]), 'green');
  Assert.AreEqual(0, Integer(Inside[2]), 'blue');

  const Outside = PixelAt(Page, 0, 0);
  Assert.AreEqual(FullChannel, Integer(Outside[2]), 'outside the fill the page stays white');
end;

procedure TMarkdownVclPdfRasterizerTests.TryGetImageSize_ResolvedImage_AnswersItsPixelSize;
begin
  const Rasterizer: IMarkdownPdfPageRasterizer = TMarkdownVclPdfRasterizer.Create(ResolveImage);

  var Size: TLayoutSizeF;
  const IsKnown = Rasterizer.TryGetImageSize(ImageSource, Size);
  var UnknownSize: TLayoutSizeF;
  const IsUnknownKnown = Rasterizer.TryGetImageSize(MissingImageSource, UnknownSize);

  Assert.IsTrue(IsKnown);
  Assert.AreEqual(Double(ImageWidth), Size.Width, 0.01);
  Assert.AreEqual(Double(ImageHeight), Size.Height, 0.01);
  Assert.IsFalse(IsUnknownKnown);
end;

procedure TMarkdownVclPdfRasterizerTests.BeginPage_ImageNotResolved_DrawsFrameWithCross;
begin
  const Rasterizer: IMarkdownPdfPageRasterizer = TMarkdownVclPdfRasterizer.Create(nil);
  const Painter = Rasterizer.BeginPage(WhitePage);
  const Bounds = TLayoutRectF.Create(0, 0, MissingFrameSize, MissingFrameSize);

  Painter.DrawImage(Bounds, MissingImageSource, TLayoutRectF.Create(0, 0, 0, 0));
  const Page = Rasterizer.EndPage;

  const Center = PixelAt(Page, MissingFrameCenter, MissingFrameCenter);
  const IsReddish = (Center[0] > Center[1]) and (Center[0] > Center[2]);
  Assert.IsTrue(IsReddish, 'the cross of a missing image runs through the middle');
end;

procedure TMarkdownVclPdfRasterizerTests.ExportToPdf_LongDocument_WritesMoreThanOnePage;
begin
  const Viewer = TMarkdownViewer.Create(nil);
  const Stream = TBytesStream.Create;
  try
    Viewer.Text := LongDocument;

    Viewer.ExportToPdf(Stream);

    const Bytes = Copy(Stream.Bytes, 0, Stream.Size);
    const Pdf = TMarkdownTestPdfReader.AsText(Bytes);
    Assert.IsTrue(Pdf.StartsWith('%PDF-1.4'), 'a PDF header');
    Assert.IsTrue(TMarkdownTestPdfReader.PageCount(Bytes) > 1, 'a long document runs over more pages');
  finally
    Stream.Free;
    Viewer.Free;
  end;
end;

// A viewer without a parent never lays the document out, as in editor-only
// mode, so the image is not requested until the export asks for it.
procedure TMarkdownVclPdfRasterizerTests.ExportToPdf_LocalImageNotYetLoaded_LoadsItBeforeRasterizing;
begin
  WriteGreenSquare;
  const ImagePath = FImageFileName.Replace('\', '/');
  const Markdown = Format('# Photo'#10#10'![square](<%s>)', [ImagePath]);

  const Viewer = TMarkdownViewer.Create(nil);
  const Stream = TBytesStream.Create;
  try
    Viewer.Text := Markdown;

    Viewer.ExportToPdf(Stream);

    const Bytes = Copy(Stream.Bytes, 0, Stream.Size);
    const Pixels = TMarkdownTestPdfReader.FirstPagePixels(Bytes);
    Assert.IsTrue(HasPureGreenPixel(Pixels), 'the photo itself is on the page, not a placeholder');
  finally
    Stream.Free;
    Viewer.Free;
  end;
end;

end.
