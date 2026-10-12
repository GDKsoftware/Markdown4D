unit Markdown4D.Fmx.PdfRasterizer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Classes,
  FMX.Graphics,
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Export.Pdf.Interfaces;

type
  [TestFixture]
  TMarkdownFmxPdfRasterizerTests = class
  private
    const
      WhitePage = TLayoutColor($FFFFFFFF);
      RedFill = TLayoutColor($FFFF0000);
      FullChannel = $FF;
      FilledLeft = 10;
      FilledTop = 20;
      FilledSize = 30;
      ImageSource = 'square.png';
      ImageWidth = 30;
      ImageHeight = 20;
      LongDocumentParagraphs = 150;
    var
      FImage: TBitmap;
    function ResolveImage(const Source: string): TBitmap;
    class function PixelAt(const Page: TMarkdownPdfPageImage; const X, Y: Integer): TBytes; static;
    class function LongDocument: string; static;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure EndPage_WhiteBackground_IsWhiteRgbOfRasterSize;

    [Test]
    procedure EndPage_RedFill_ConvertsToRgb;

    [Test]
    procedure TryGetImageSize_ResolvedImage_AnswersItsPixelSize;

    [Test]
    procedure ExportToPdf_LongDocument_WritesMoreThanOnePage;
  end;

implementation

uses
  Markdown4D.Fmx.PdfRasterizer,
  Markdown4D.Fmx.Viewer,
  Markdown4D.Export.Pdf.Geometry,
  Markdown4D.Tests.PdfReader;

procedure TMarkdownFmxPdfRasterizerTests.Setup;
begin
  FImage := TBitmap.Create(ImageWidth, ImageHeight);
end;

procedure TMarkdownFmxPdfRasterizerTests.TearDown;
begin
  FImage.Free;
end;

function TMarkdownFmxPdfRasterizerTests.ResolveImage(const Source: string): TBitmap;
begin
  Result := nil;
  if Source = ImageSource then
    Result := FImage;
end;

class function TMarkdownFmxPdfRasterizerTests.PixelAt(const Page: TMarkdownPdfPageImage; const X, Y: Integer): TBytes;
begin
  const Offset = ((Y * Page.Width) + X) * TMarkdownPdfPageImage.BytesPerPixel;
  Result := Copy(Page.Pixels, Offset, TMarkdownPdfPageImage.BytesPerPixel);
end;

class function TMarkdownFmxPdfRasterizerTests.LongDocument: string;
begin
  Result := '';
  for var Index := 1 to LongDocumentParagraphs do
  begin
    Result := Result + Format('Paragraph %d with some words in it'#10#10, [Index]);
  end;
end;

procedure TMarkdownFmxPdfRasterizerTests.EndPage_WhiteBackground_IsWhiteRgbOfRasterSize;
begin
  const Rasterizer: IMarkdownPdfPageRasterizer = TMarkdownFmxPdfRasterizer.Create(nil);

  Rasterizer.BeginPage(WhitePage);
  const Page = Rasterizer.EndPage;

  Assert.AreEqual(TMarkdownPdfPageGeometry.RasterWidthPixels, Page.Width);
  Assert.AreEqual(TMarkdownPdfPageGeometry.RasterHeightPixels, Page.Height);
  const HasEveryPixel = (Length(Page.Pixels) = Page.ExpectedByteCount);
  Assert.IsTrue(HasEveryPixel, 'three bytes for every pixel');

  const Corner = PixelAt(Page, 0, 0);
  const Middle = PixelAt(Page, Page.Width div 2, Page.Height div 2);
  for var Channel := 0 to TMarkdownPdfPageImage.BytesPerPixel - 1 do
  begin
    Assert.AreEqual(FullChannel, Integer(Corner[Channel]), 'the corner is white');
    Assert.AreEqual(FullChannel, Integer(Middle[Channel]), 'the middle is white');
  end;
end;

procedure TMarkdownFmxPdfRasterizerTests.EndPage_RedFill_ConvertsToRgb;
begin
  const Rasterizer: IMarkdownPdfPageRasterizer = TMarkdownFmxPdfRasterizer.Create(nil);
  const Painter = Rasterizer.BeginPage(WhitePage);
  const Filled = TLayoutRectF.Create(FilledLeft, FilledTop, FilledLeft + FilledSize, FilledTop + FilledSize);

  Painter.FillRect(Filled, RedFill);
  const Page = Rasterizer.EndPage;

  const Inside = PixelAt(Page, FilledLeft + (FilledSize div 2), FilledTop + (FilledSize div 2));
  Assert.AreEqual(FullChannel, Integer(Inside[0]), 'red');
  Assert.AreEqual(0, Integer(Inside[1]), 'green');
  Assert.AreEqual(0, Integer(Inside[2]), 'blue');
end;

procedure TMarkdownFmxPdfRasterizerTests.TryGetImageSize_ResolvedImage_AnswersItsPixelSize;
begin
  const Rasterizer: IMarkdownPdfPageRasterizer = TMarkdownFmxPdfRasterizer.Create(ResolveImage);

  var Size: TLayoutSizeF;
  const IsKnown = Rasterizer.TryGetImageSize(ImageSource, Size);
  var UnknownSize: TLayoutSizeF;
  const IsUnknownKnown = Rasterizer.TryGetImageSize('missing.png', UnknownSize);

  Assert.IsTrue(IsKnown);
  Assert.AreEqual(Double(ImageWidth), Size.Width, 0.01);
  Assert.AreEqual(Double(ImageHeight), Size.Height, 0.01);
  Assert.IsFalse(IsUnknownKnown);
end;

procedure TMarkdownFmxPdfRasterizerTests.ExportToPdf_LongDocument_WritesMoreThanOnePage;
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

end.
