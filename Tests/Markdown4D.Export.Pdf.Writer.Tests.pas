unit Markdown4D.Export.Pdf.Writer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  Markdown4D.Export.Pdf.Interfaces;

type
  [TestFixture]
  TMarkdownPdfWriterTests = class
  private
    const
      PageWidth = 4;
      PageHeight = 3;
      GreyChannel = $80;
    var
      FStream: TBytesStream;
    class function PageImage: TMarkdownPdfPageImage; static;
    function WritePages(const PageCount: Integer): string;
    function WrittenBytes: TBytes;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Finish_OnePage_WritesHeaderTrailerAndEof;

    [Test]
    [TestCase('One', '1')]
    [TestCase('Three', '3')]
    procedure Finish_Pages_CountsEveryPageOnA4(const PageCount: Integer);

    [Test]
    procedure AddPage_Image_CoversWholePageWithWhiteMargins;

    [Test]
    procedure AddPage_Pixels_AreFlateCompressedAndRoundTrip;

    [Test]
    procedure Finish_CrossReference_PointsAtEveryObject;

    [Test]
    procedure AddPage_WrongPixelCount_RaisesEMarkdownPdfExportError;

    [Test]
    procedure Finish_WithoutPages_RaisesEMarkdownPdfExportError;

    [Test]
    procedure Create_NilStream_RaisesEMarkdownPdfExportError;
  end;

implementation

uses
  System.RegularExpressions,
  Markdown4D.Export.Pdf.Errors,
  Markdown4D.Export.Pdf.Geometry,
  Markdown4D.Export.Pdf.Writer,
  Markdown4D.Tests.PdfReader;

procedure TMarkdownPdfWriterTests.Setup;
begin
  FStream := TBytesStream.Create;
end;

procedure TMarkdownPdfWriterTests.TearDown;
begin
  FStream.Free;
end;

class function TMarkdownPdfWriterTests.PageImage: TMarkdownPdfPageImage;
begin
  var Pixels: TBytes;
  SetLength(Pixels, PageWidth * PageHeight * TMarkdownPdfPageImage.BytesPerPixel);
  FillChar(Pixels[0], Length(Pixels), GreyChannel);
  Result := TMarkdownPdfPageImage.Create(PageWidth, PageHeight, Pixels);
end;

function TMarkdownPdfWriterTests.WritePages(const PageCount: Integer): string;
begin
  const Writer = TMarkdownPdfWriter.Create(FStream);
  try
    for var Index := 1 to PageCount do
    begin
      Writer.AddPage(PageImage);
    end;
    Writer.Finish;
  finally
    Writer.Free;
  end;

  const Bytes = WrittenBytes;
  Result := TMarkdownTestPdfReader.AsText(Bytes);
end;

function TMarkdownPdfWriterTests.WrittenBytes: TBytes;
begin
  Result := Copy(FStream.Bytes, 0, FStream.Size);
end;

procedure TMarkdownPdfWriterTests.Finish_OnePage_WritesHeaderTrailerAndEof;
begin
  const Pdf = WritePages(1);

  Assert.IsTrue(Pdf.StartsWith('%PDF-1.4'#10), 'header');
  Assert.IsTrue(Pdf.Contains('/Type /Catalog /Pages 1 0 R'), 'catalog');
  Assert.IsTrue(Pdf.Contains('trailer'#10'<< /Size '), 'trailer');
  Assert.IsTrue(Pdf.EndsWith('%%EOF'#10), 'end of file marker');
end;

procedure TMarkdownPdfWriterTests.Finish_Pages_CountsEveryPageOnA4(const PageCount: Integer);
begin
  const Pdf = WritePages(PageCount);

  Assert.IsTrue(Pdf.Contains(Format('/Count %d', [PageCount])), 'page count');
  Assert.AreEqual(PageCount, TMarkdownTestPdfReader.Occurrences(Pdf, TMarkdownTestPdfReader.PageObjectMarker));
  Assert.AreEqual(PageCount, TMarkdownTestPdfReader.Occurrences(Pdf, '/MediaBox [0 0 595.28 841.89]'));
end;

procedure TMarkdownPdfWriterTests.AddPage_Image_CoversWholePageWithWhiteMargins;
begin
  const Pdf = WritePages(1);

  Assert.IsTrue(Pdf.Contains('q 595.28 0 0 841.89 0 0 cm /Im0 Do Q'), 'content stream');
  const FullWidth = PageWidth + (2 * TMarkdownPdfPageGeometry.MarginPixels);
  const FullHeight = PageHeight + (2 * TMarkdownPdfPageGeometry.MarginPixels);
  Assert.IsTrue(Pdf.Contains(Format('/Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 ' +
    '/Filter /FlateDecode', [FullWidth, FullHeight])), 'image dictionary');
end;

procedure TMarkdownPdfWriterTests.AddPage_Pixels_AreFlateCompressedAndRoundTrip;
begin
  WritePages(1);

  const Bytes = WrittenBytes;
  const Decompressed = TMarkdownTestPdfReader.FirstPagePixels(Bytes);

  const Margin = TMarkdownPdfPageGeometry.MarginPixels;
  const FullWidth = PageWidth + (2 * Margin);
  const FullHeight = PageHeight + (2 * Margin);
  const BytesPerPixel = TMarkdownPdfPageImage.BytesPerPixel;
  Assert.AreEqual(FullWidth * FullHeight * BytesPerPixel, Integer(Length(Decompressed)));

  const ContentOffset = ((Margin * FullWidth) + Margin) * BytesPerPixel;
  Assert.AreEqual(Integer(GreyChannel), Integer(Decompressed[ContentOffset]), 'content pixel');
  Assert.AreEqual(Integer($FF), Integer(Decompressed[0]), 'margin pixel');
  Assert.AreEqual(Integer($FF), Integer(Decompressed[High(Decompressed)]), 'last margin pixel');
end;

procedure TMarkdownPdfWriterTests.Finish_CrossReference_PointsAtEveryObject;
begin
  const Pdf = WritePages(2);

  const StartXref = TRegEx.Match(Pdf, 'startxref'#10'(\d+)'#10);
  const XrefOffset = StrToInt(StartXref.Groups[1].Value);
  Assert.IsTrue(Copy(Pdf, XrefOffset + 1, 4) = 'xref', 'startxref points at the table');

  const Entries = TRegEx.Matches(Pdf, '(\d{10}) 00000 n '#10);
  Assert.AreEqual(8, Entries.Count, 'pages, catalog and three objects per page');
  for var ObjectNumber := 1 to Entries.Count do
  begin
    const Offset = StrToInt(Entries[ObjectNumber - 1].Groups[1].Value);
    const Expected = Format('%d 0 obj'#10, [ObjectNumber]);
    Assert.AreEqual(Expected, Copy(Pdf, Offset + 1, Length(Expected)));
  end;
end;

procedure TMarkdownPdfWriterTests.AddPage_WrongPixelCount_RaisesEMarkdownPdfExportError;
begin
  const Writer = TMarkdownPdfWriter.Create(FStream);
  try
    const ShortImage = TMarkdownPdfPageImage.Create(PageWidth, PageHeight, [1, 2, 3]);
    Assert.WillRaise(
      procedure
      begin
        Writer.AddPage(ShortImage);
      end,
      EMarkdownPdfExportError);
  finally
    Writer.Free;
  end;
end;

procedure TMarkdownPdfWriterTests.Finish_WithoutPages_RaisesEMarkdownPdfExportError;
begin
  const Writer = TMarkdownPdfWriter.Create(FStream);
  try
    Assert.WillRaise(
      procedure
      begin
        Writer.Finish;
      end,
      EMarkdownPdfExportError);
  finally
    Writer.Free;
  end;
end;

procedure TMarkdownPdfWriterTests.Create_NilStream_RaisesEMarkdownPdfExportError;
begin
  Assert.WillRaise(
    procedure
    begin
      TMarkdownPdfWriter.Create(nil).Free;
    end,
    EMarkdownPdfExportError);
end;

end.
