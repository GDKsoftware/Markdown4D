unit Markdown4D.Export.Pdf.Writer;

{$SCOPEDENUMS ON}

// A minimal PDF 1.4 writer: every page is one RGB image, compressed with
// Flate, that covers an A4 page: the content set in white margins. Each page goes to the
// stream as soon as it is added, so only one raw page is ever held in memory.

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Markdown4D.Export.Pdf.Interfaces;

type
  TMarkdownPdfWriter = class
  private
    const
      PagesObjectNumber = 1;
      CatalogObjectNumber = 2;
      FirstPageObjectNumber = 3;
      Header = '%PDF-1.4'#10;
      EndObject = #10'endobj'#10;
      MissingStreamMessage = 'A PDF writer needs a stream to write to';
      FinishedMessage = 'The PDF is finished; no page can be added any more';
      EmptyPageMessage = 'A PDF page needs a width and a height above zero, not %d x %d';
      PixelCountMessage = 'A PDF page of %d x %d pixels needs %d bytes of RGB, not %d';
      NoPagesMessage = 'A PDF needs at least one page';
    var
      FStream: TStream;
      FObjectOffsets: TDictionary<Integer, Int64>;
      FPageObjectNumbers: TList<Integer>;
      FNextObjectNumber: Integer;
      FIsFinished: Boolean;
    procedure GuardStream(const Stream: TStream);
    procedure WriteBinaryMarker;
    procedure GuardNotFinished;
    procedure GuardPageImage(const Image: TMarkdownPdfPageImage);
    procedure GuardHasPages;
    function ReserveObjectNumber: Integer;
    procedure WriteImageObject(const ObjectNumber: Integer; const Image: TMarkdownPdfPageImage);
    procedure WriteContentObject(const ObjectNumber: Integer);
    procedure WritePageObject(const ObjectNumber, ImageObjectNumber, ContentObjectNumber: Integer);
    procedure WritePagesObject;
    procedure WriteCatalogObject;
    procedure WriteCrossReference;
    procedure BeginObject(const ObjectNumber: Integer);
    procedure WriteStreamObject(const ObjectNumber: Integer; const Dictionary: string; const Data: TBytes);
    procedure WriteFormatted(const Pattern: string; const Arguments: array of const);
    procedure WriteText(const Text: string);
    procedure WriteBytes(const Data: TBytes);
    function PageKids: string;
    class function Number(const Value: Double): string; static;
    class function PixelsWithMargins(const Image: TMarkdownPdfPageImage): TBytes; static;

  public
    constructor Create(const Stream: TStream);
    destructor Destroy; override;
    procedure AddPage(const Image: TMarkdownPdfPageImage);
    procedure Finish;
  end;

implementation

uses
  System.ZLib,
  Markdown4D.Export.Pdf.Errors,
  Markdown4D.Export.Pdf.Geometry;

constructor TMarkdownPdfWriter.Create(const Stream: TStream);
begin
  inherited Create;

  GuardStream(Stream);

  FStream := Stream;
  FObjectOffsets := TDictionary<Integer, Int64>.Create;
  FPageObjectNumbers := TList<Integer>.Create;
  FNextObjectNumber := FirstPageObjectNumber;

  WriteText(Header);
  WriteBinaryMarker;
end;

destructor TMarkdownPdfWriter.Destroy;
begin
  FPageObjectNumbers.Free;
  FObjectOffsets.Free;

  inherited Destroy;
end;

procedure TMarkdownPdfWriter.GuardStream(const Stream: TStream);
begin
  if Stream = nil then
    raise EMarkdownPdfExportError.Create(MissingStreamMessage);
end;

// A comment of bytes above 127 tells a reader the file holds binary data.
procedure TMarkdownPdfWriter.WriteBinaryMarker;
begin
  WriteBytes([$25, $E2, $E3, $CF, $D3, $0A]);
end;

procedure TMarkdownPdfWriter.AddPage(const Image: TMarkdownPdfPageImage);
begin
  GuardNotFinished;
  GuardPageImage(Image);

  const ImageObjectNumber = ReserveObjectNumber;
  const ContentObjectNumber = ReserveObjectNumber;
  const PageObjectNumber = ReserveObjectNumber;

  WriteImageObject(ImageObjectNumber, Image);
  WriteContentObject(ContentObjectNumber);
  WritePageObject(PageObjectNumber, ImageObjectNumber, ContentObjectNumber);

  FPageObjectNumbers.Add(PageObjectNumber);
end;

procedure TMarkdownPdfWriter.GuardNotFinished;
begin
  if FIsFinished then
    raise EMarkdownPdfExportError.Create(FinishedMessage);
end;

procedure TMarkdownPdfWriter.GuardPageImage(const Image: TMarkdownPdfPageImage);
begin
  const IsEmpty = (Image.Width <= 0) or (Image.Height <= 0);
  if IsEmpty then
    raise EMarkdownPdfExportError.CreateFmt(EmptyPageMessage, [Image.Width, Image.Height]);

  const ActualByteCount = Length(Image.Pixels);
  const HasExpectedByteCount = (ActualByteCount = Image.ExpectedByteCount);
  if not HasExpectedByteCount then
    raise EMarkdownPdfExportError.CreateFmt(PixelCountMessage,
      [Image.Width, Image.Height, Image.ExpectedByteCount, ActualByteCount]);
end;

function TMarkdownPdfWriter.ReserveObjectNumber: Integer;
begin
  Result := FNextObjectNumber;
  Inc(FNextObjectNumber);
end;

// The content is set in white margins inside one image that covers the whole
// page, so the page has no visible edge between margin and content.
procedure TMarkdownPdfWriter.WriteImageObject(const ObjectNumber: Integer; const Image: TMarkdownPdfPageImage);
begin
  const PageWidth = Image.Width + (2 * TMarkdownPdfPageGeometry.MarginPixels);
  const PageHeight = Image.Height + (2 * TMarkdownPdfPageGeometry.MarginPixels);

  var Compressed: TBytes;
  ZCompress(PixelsWithMargins(Image), Compressed);

  const Dictionary = Format('/Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB ' +
    '/BitsPerComponent 8 /Filter /FlateDecode', [PageWidth, PageHeight]);
  WriteStreamObject(ObjectNumber, Dictionary, Compressed);
end;

class function TMarkdownPdfWriter.PixelsWithMargins(const Image: TMarkdownPdfPageImage): TBytes;
begin
  const Margin = TMarkdownPdfPageGeometry.MarginPixels;
  const PageWidth = Image.Width + (2 * Margin);
  const PageHeight = Image.Height + (2 * Margin);
  const RowByteCount = Image.Width * TMarkdownPdfPageImage.BytesPerPixel;
  const PageRowByteCount = PageWidth * TMarkdownPdfPageImage.BytesPerPixel;

  SetLength(Result, PageRowByteCount * PageHeight);
  FillChar(Result[0], Length(Result), $FF);

  for var Row := 0 to Image.Height - 1 do
  begin
    const Target = ((Row + Margin) * PageRowByteCount) + (Margin * TMarkdownPdfPageImage.BytesPerPixel);
    Move(Image.Pixels[Row * RowByteCount], Result[Target], RowByteCount);
  end;
end;

procedure TMarkdownPdfWriter.WriteContentObject(const ObjectNumber: Integer);
begin
  const Width = Number(TMarkdownPdfPageGeometry.PageWidthPoints);
  const Height = Number(TMarkdownPdfPageGeometry.PageHeightPoints);
  const Content = Format('q %s 0 0 %s 0 0 cm /Im0 Do Q', [Width, Height]);
  const ContentBytes = TEncoding.ASCII.GetBytes(Content);

  WriteStreamObject(ObjectNumber, '', ContentBytes);
end;

procedure TMarkdownPdfWriter.WritePageObject(const ObjectNumber, ImageObjectNumber, ContentObjectNumber: Integer);
begin
  const Width = Number(TMarkdownPdfPageGeometry.PageWidthPoints);
  const Height = Number(TMarkdownPdfPageGeometry.PageHeightPoints);

  BeginObject(ObjectNumber);
  WriteFormatted('<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %s %s] /Resources << /XObject << /Im0 %d 0 R >> >> ' +
    '/Contents %d 0 R >>' + EndObject, [PagesObjectNumber, Width, Height, ImageObjectNumber, ContentObjectNumber]);
end;

procedure TMarkdownPdfWriter.Finish;
begin
  GuardNotFinished;
  GuardHasPages;

  WritePagesObject;
  WriteCatalogObject;
  WriteCrossReference;

  FIsFinished := True;
end;

procedure TMarkdownPdfWriter.GuardHasPages;
begin
  if FPageObjectNumbers.Count = 0 then
    raise EMarkdownPdfExportError.Create(NoPagesMessage);
end;

procedure TMarkdownPdfWriter.WritePagesObject;
begin
  const Kids = PageKids;

  BeginObject(PagesObjectNumber);
  WriteFormatted('<< /Type /Pages /Kids [%s] /Count %d >>' + EndObject, [Kids, FPageObjectNumbers.Count]);
end;

function TMarkdownPdfWriter.PageKids: string;
begin
  const References = TStringList.Create;
  try
    for var PageObjectNumber in FPageObjectNumbers do
    begin
      References.Add(Format('%d 0 R', [PageObjectNumber]));
    end;

    Result := string.Join(' ', References.ToStringArray);
  finally
    References.Free;
  end;
end;

procedure TMarkdownPdfWriter.WriteCatalogObject;
begin
  BeginObject(CatalogObjectNumber);
  WriteFormatted('<< /Type /Catalog /Pages %d 0 R >>' + EndObject, [PagesObjectNumber]);
end;

// Every entry of the table is exactly 20 bytes, as the format demands.
procedure TMarkdownPdfWriter.WriteCrossReference;
begin
  const CrossReferenceOffset = FStream.Position;
  const EntryCount = FNextObjectNumber;

  WriteFormatted('xref'#10'0 %d'#10'0000000000 65535 f '#10, [EntryCount]);
  for var ObjectNumber := 1 to EntryCount - 1 do
  begin
    WriteFormatted('%.10d 00000 n '#10, [FObjectOffsets[ObjectNumber]]);
  end;

  WriteFormatted('trailer'#10'<< /Size %d /Root %d 0 R >>'#10'startxref'#10'%d'#10'%%%%EOF'#10,
    [EntryCount, CatalogObjectNumber, CrossReferenceOffset]);
end;

procedure TMarkdownPdfWriter.BeginObject(const ObjectNumber: Integer);
begin
  FObjectOffsets.AddOrSetValue(ObjectNumber, FStream.Position);
  WriteFormatted('%d 0 obj'#10, [ObjectNumber]);
end;

procedure TMarkdownPdfWriter.WriteStreamObject(const ObjectNumber: Integer; const Dictionary: string;
  const Data: TBytes);
begin
  BeginObject(ObjectNumber);
  WriteFormatted('<< %s /Length %d >>'#10'stream'#10, [Dictionary, Length(Data)]);
  WriteBytes(Data);
  WriteText(#10'endstream' + EndObject);
end;

procedure TMarkdownPdfWriter.WriteFormatted(const Pattern: string; const Arguments: array of const);
begin
  const Text = Format(Pattern, Arguments);
  WriteText(Text);
end;

procedure TMarkdownPdfWriter.WriteText(const Text: string);
begin
  const Data = TEncoding.ASCII.GetBytes(Text);
  WriteBytes(Data);
end;

procedure TMarkdownPdfWriter.WriteBytes(const Data: TBytes);
begin
  if Length(Data) > 0 then
    FStream.WriteBuffer(Data, Length(Data));
end;

class function TMarkdownPdfWriter.Number(const Value: Double): string;
begin
  Result := FormatFloat('0.##', Value, TFormatSettings.Invariant);
end;

end.
