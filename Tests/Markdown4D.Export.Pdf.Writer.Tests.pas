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
    var
      FStream: TMemoryStream;
    function SamplePage: TMarkdownPdfPageImage;
    function WrittenText: string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure AddPage_CompressedStream_RoundTrips;

    [Test]
    procedure Finish_TwoPages_HasHeaderXrefAndEof;

    [Test]
    procedure Finish_Page_IsA4WithTheImageInsideTwoCentimetreMargins;

    [Test]
    procedure AddPage_PixelCountMismatch_RaisesEMarkdownPdfExportError;

    [Test]
    procedure AddPage_AfterFinish_RaisesEMarkdownPdfExportError;

    [Test]
    procedure AddPage_ZeroSizedPage_RaisesEMarkdownPdfExportError;

    [Test]
    procedure Finish_WithoutPages_RaisesEMarkdownPdfExportError;

    [Test]
    procedure Create_NilStream_RaisesEMarkdownPdfExportError;
  end;

implementation

uses
  Markdown4D.Export.Pdf.Errors,
  Markdown4D.Export.Pdf.Writer,
  Markdown4D.Tests.PdfReader;

procedure TMarkdownPdfWriterTests.Setup;
begin
  FStream := TMemoryStream.Create;
end;

procedure TMarkdownPdfWriterTests.TearDown;
begin
  FStream.Free;
end;

function TMarkdownPdfWriterTests.SamplePage: TMarkdownPdfPageImage;
begin
  Result := TMarkdownPdfPageImage.Create(PageWidth, PageHeight);
  for var Index := 0 to High(Result.Pixels) do
  begin
    Result.Pixels[Index] := Byte(Index * 7);
  end;
end;

function TMarkdownPdfWriterTests.WrittenText: string;
begin
  Result := TMarkdownTestPdfReader.AsText(TMarkdownTestPdfReader.BytesOf(FStream));
end;

procedure TMarkdownPdfWriterTests.AddPage_CompressedStream_RoundTrips;
begin
  const Page = SamplePage;

  const Writer = TMarkdownPdfWriter.Create(FStream);
  try
    Writer.AddPage(Page);
    Writer.Finish;
  finally
    Writer.Free;
  end;

  var Width: Integer;
  var Height: Integer;
  const Pixels = TMarkdownTestPdfReader.FirstImage(TMarkdownTestPdfReader.BytesOf(FStream), Width, Height);
  Assert.AreEqual(PageWidth, Width);
  Assert.AreEqual(PageHeight, Height);
  Assert.AreEqual(Integer(Length(Page.Pixels)), Integer(Length(Pixels)));
  Assert.IsTrue(CompareMem(@Page.Pixels[0], @Pixels[0], Length(Pixels)), 'the pixels did not survive compression');
end;

procedure TMarkdownPdfWriterTests.Finish_TwoPages_HasHeaderXrefAndEof;
begin
  const Writer = TMarkdownPdfWriter.Create(FStream);
  try
    Writer.AddPage(SamplePage);
    Writer.AddPage(SamplePage);
    Writer.Finish;
  finally
    Writer.Free;
  end;

  const Text = WrittenText;
  Assert.IsTrue(Text.StartsWith('%PDF-1.4'#10), 'header missing');
  Assert.IsTrue(Text.EndsWith('%%EOF'#10), 'end marker missing');
  Assert.AreEqual(2, TMarkdownTestPdfReader.PageCount(TMarkdownTestPdfReader.BytesOf(FStream)));

  const StartXrefAt = Text.LastIndexOf('startxref'#10) + Length('startxref'#10);
  const XrefOffset = StrToInt(Text.Substring(StartXrefAt, Text.IndexOf(#10, StartXrefAt) - StartXrefAt));
  Assert.IsTrue(Text.Substring(XrefOffset).StartsWith('xref'#10'0 '), 'startxref does not point at the table');

  // The table lists objects 1 to 8 after the free entry; each one must point
  // at the start of that very object.
  const Lines = Text.Substring(XrefOffset).Split([#10]);
  const ObjectCount = StrToInt(Lines[1].Substring(2));
  Assert.AreEqual(9, ObjectCount);
  for var ObjectNumber := 1 to ObjectCount - 1 do
  begin
    const Offset = StrToInt(Lines[2 + ObjectNumber].Substring(0, 10));
    const Expected = Format('%d 0 obj', [ObjectNumber]);
    Assert.IsTrue(Text.Substring(Offset).StartsWith(Expected), Format('xref entry %d is off', [ObjectNumber]));
  end;
end;

procedure TMarkdownPdfWriterTests.Finish_Page_IsA4WithTheImageInsideTwoCentimetreMargins;
begin
  const Writer = TMarkdownPdfWriter.Create(FStream);
  try
    Writer.AddPage(SamplePage);
    Writer.Finish;
  finally
    Writer.Free;
  end;

  const Text = WrittenText;
  Assert.IsTrue(Text.Contains('/MediaBox [0 0 595.28 841.89]'), 'the page is not A4');
  Assert.IsTrue(Text.Contains('q 481.89 0 0 728.50 56.69 56.69 cm /Im0 Do Q'), 'the image is not inside the margins');
end;

procedure TMarkdownPdfWriterTests.AddPage_PixelCountMismatch_RaisesEMarkdownPdfExportError;
begin
  var Page := SamplePage;
  SetLength(Page.Pixels, Length(Page.Pixels) - 1);

  const Writer = TMarkdownPdfWriter.Create(FStream);
  try
    Assert.WillRaise(
      procedure
      begin
        Writer.AddPage(Page);
      end,
      EMarkdownPdfExportError,
      'GuardPage must refuse pixels that do not fill the page');
  finally
    Writer.Free;
  end;
end;

procedure TMarkdownPdfWriterTests.AddPage_AfterFinish_RaisesEMarkdownPdfExportError;
begin
  const Writer = TMarkdownPdfWriter.Create(FStream);
  try
    Writer.AddPage(SamplePage);
    Writer.Finish;

    Assert.WillRaise(
      procedure
      begin
        Writer.AddPage(SamplePage);
      end,
      EMarkdownPdfExportError,
      'GuardNotFinished must refuse a page after Finish');
  finally
    Writer.Free;
  end;
end;

procedure TMarkdownPdfWriterTests.AddPage_ZeroSizedPage_RaisesEMarkdownPdfExportError;
begin
  const Page = TMarkdownPdfPageImage.Create(0, 0);

  const Writer = TMarkdownPdfWriter.Create(FStream);
  try
    Assert.WillRaise(
      procedure
      begin
        Writer.AddPage(Page);
      end,
      EMarkdownPdfExportError,
      'GuardPage must refuse a page without pixels');
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
      EMarkdownPdfExportError,
      'GuardHasPages must refuse a PDF without pages');
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
    EMarkdownPdfExportError,
    'GuardStream must refuse a missing stream');
end;

end.
