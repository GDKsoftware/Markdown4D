unit Markdown4D.Export.Pdf.Writer;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Markdown4D.Export.Pdf.Interfaces;

type
  // Writes a minimal PDF 1.4 straight to a stream: every page is one A4 sheet
  // showing one Flate-compressed RGB image inside the margins. Each page goes
  // out as it is added, so only the page at hand is held in memory.
  TMarkdownPdfWriter = class
  private
    const
      CatalogObjectNumber = 1;
      PagesObjectNumber = 2;
      FirstPageObjectNumber = 3;
      ObjectsPerPage = 3;
      BytesPerPixel = 3;
      NumberFormat = '0.00';
      ImageResourceName = 'Im0';
      MissingStreamMessage = 'A PDF needs a stream to write to';
      InvalidPageMessage = 'A page of %d by %d pixels needs %d bytes of RGB data, not %d';
      NoPagesMessage = 'A PDF needs at least one page';
      FinishedMessage = 'The PDF is already finished';
    var
      FStream: TStream;
      FStartPosition: Int64;
      FObjectOffsets: TDictionary<Integer, Int64>;
      FPageObjectNumbers: TList<Integer>;
      FNextObjectNumber: Integer;
      FIsFinished: Boolean;
    class procedure GuardStream(const Stream: TStream); static;
    procedure GuardNotFinished;
    procedure GuardPage(const Page: TMarkdownPdfPageImage);
    procedure GuardHasPages;
    procedure WriteHeader;
    procedure WriteImageObject(const ObjectNumber: Integer; const Page: TMarkdownPdfPageImage);
    procedure WriteContentObject(const ObjectNumber: Integer);
    procedure WritePageObject(const ObjectNumber, ImageObjectNumber, ContentObjectNumber: Integer);
    procedure WritePagesObject;
    procedure WriteCatalogObject;
    procedure WriteCrossReference;
    procedure BeginObject(const ObjectNumber: Integer);
    procedure WriteStreamObject(const ObjectNumber: Integer; const Dictionary: string; const Data: TBytes);
    procedure EndObject;
    procedure WriteText(const Text: string);
    procedure WriteBytes(const Data: TBytes);
    function KidsText: string;
    class function FormatNumber(const Value: Single): string; static;

  public
    // Writes the header at once, from the current position of Stream.
    constructor Create(const Stream: TStream);
    destructor Destroy; override;
    procedure AddPage(const Page: TMarkdownPdfPageImage);
    // Writes the page tree, the catalog, the cross-reference table and the
    // trailer; the stream holds a complete PDF afterwards.
    procedure Finish;
  end;

implementation

uses
  System.ZLib,
  Markdown4D.Export.Pdf.Errors,
  Markdown4D.Export.Pdf.Geometry;

const
  LineFeed = #10;

class procedure TMarkdownPdfWriter.GuardStream(const Stream: TStream);
begin
  const IsMissing = (Stream = nil);
  if IsMissing then
    raise EMarkdownPdfExportError.Create(MissingStreamMessage);
end;

constructor TMarkdownPdfWriter.Create(const Stream: TStream);
begin
  inherited Create;

  GuardStream(Stream);

  FStream := Stream;
  FStartPosition := Stream.Position;
  FObjectOffsets := TDictionary<Integer, Int64>.Create;
  FPageObjectNumbers := TList<Integer>.Create;
  FNextObjectNumber := FirstPageObjectNumber;

  WriteHeader;
end;

destructor TMarkdownPdfWriter.Destroy;
begin
  FPageObjectNumbers.Free;
  FObjectOffsets.Free;

  inherited Destroy;
end;

procedure TMarkdownPdfWriter.AddPage(const Page: TMarkdownPdfPageImage);
begin
  GuardNotFinished;
  GuardPage(Page);

  const ImageObjectNumber = FNextObjectNumber;
  const ContentObjectNumber = ImageObjectNumber + 1;
  const PageObjectNumber = ImageObjectNumber + 2;
  Inc(FNextObjectNumber, ObjectsPerPage);

  WriteImageObject(ImageObjectNumber, Page);
  WriteContentObject(ContentObjectNumber);
  WritePageObject(PageObjectNumber, ImageObjectNumber, ContentObjectNumber);
  FPageObjectNumbers.Add(PageObjectNumber);
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

procedure TMarkdownPdfWriter.GuardNotFinished;
begin
  if FIsFinished then
    raise EMarkdownPdfExportError.Create(FinishedMessage);
end;

procedure TMarkdownPdfWriter.GuardPage(const Page: TMarkdownPdfPageImage);
begin
  const ExpectedLength = Page.Width * Page.Height * BytesPerPixel;
  const IsValid = ((Page.Width > 0) and (Page.Height > 0) and (Length(Page.Pixels) = ExpectedLength));
  if not IsValid then
    raise EMarkdownPdfExportError.CreateFmt(InvalidPageMessage,
                                            [Page.Width, Page.Height, ExpectedLength, Length(Page.Pixels)]);
end;

procedure TMarkdownPdfWriter.GuardHasPages;
begin
  const HasPages = (FPageObjectNumbers.Count > 0);
  if not HasPages then
    raise EMarkdownPdfExportError.Create(NoPagesMessage);
end;

// The comment line of bytes above 127 tells transfer tools the file is binary.
procedure TMarkdownPdfWriter.WriteHeader;
begin
  WriteText('%PDF-1.4' + LineFeed);
  WriteBytes([Ord('%'), $E2, $E3, $CF, $D3, Ord(LineFeed)]);
end;

procedure TMarkdownPdfWriter.WriteImageObject(const ObjectNumber: Integer; const Page: TMarkdownPdfPageImage);
begin
  var Compressed: TBytes;
  ZCompress(Page.Pixels, Compressed);

  const Dictionary = Format('<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB ' +
                            '/BitsPerComponent 8 /Filter /FlateDecode /Length %d >>',
                            [Page.Width, Page.Height, Length(Compressed)]);
  WriteStreamObject(ObjectNumber, Dictionary, Compressed);
end;

procedure TMarkdownPdfWriter.WriteContentObject(const ObjectNumber: Integer);
begin
  const Content = Format('q %s 0 0 %s %s %s cm /%s Do Q',
                         [FormatNumber(TMarkdownPdfPageGeometry.ContentWidthPoints),
                          FormatNumber(TMarkdownPdfPageGeometry.ContentHeightPoints),
                          FormatNumber(TMarkdownPdfPageGeometry.MarginPoints),
                          FormatNumber(TMarkdownPdfPageGeometry.MarginPoints),
                          ImageResourceName]);
  const Data = TEncoding.ASCII.GetBytes(Content);

  WriteStreamObject(ObjectNumber, Format('<< /Length %d >>', [Length(Data)]), Data);
end;

procedure TMarkdownPdfWriter.WritePageObject(const ObjectNumber, ImageObjectNumber, ContentObjectNumber: Integer);
begin
  BeginObject(ObjectNumber);
  WriteText(Format('<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %s %s] ' +
                   '/Resources << /XObject << /%s %d 0 R >> >> /Contents %d 0 R >>',
                   [PagesObjectNumber,
                    FormatNumber(TMarkdownPdfPageGeometry.PageWidthPoints),
                    FormatNumber(TMarkdownPdfPageGeometry.PageHeightPoints),
                    ImageResourceName, ImageObjectNumber, ContentObjectNumber]) + LineFeed);
  EndObject;
end;

procedure TMarkdownPdfWriter.WritePagesObject;
begin
  BeginObject(PagesObjectNumber);
  WriteText(Format('<< /Type /Pages /Kids [%s] /Count %d >>', [KidsText, FPageObjectNumbers.Count]) + LineFeed);
  EndObject;
end;

function TMarkdownPdfWriter.KidsText: string;
begin
  var References: TArray<string>;
  for var PageObjectNumber in FPageObjectNumbers do
  begin
    References := References + [Format('%d 0 R', [PageObjectNumber])];
  end;

  Result := string.Join(' ', References);
end;

procedure TMarkdownPdfWriter.WriteCatalogObject;
begin
  BeginObject(CatalogObjectNumber);
  WriteText(Format('<< /Type /Catalog /Pages %d 0 R >>', [PagesObjectNumber]) + LineFeed);
  EndObject;
end;

// Every entry of the table is exactly 20 bytes, as the format demands; the
// offsets count from the header, where this writer started.
procedure TMarkdownPdfWriter.WriteCrossReference;
begin
  const CrossReferenceOffset = FStream.Position - FStartPosition;
  const ObjectCount = FNextObjectNumber;

  WriteText(Format('xref' + LineFeed + '0 %d' + LineFeed, [ObjectCount]));
  WriteText('0000000000 65535 f ' + LineFeed);
  for var ObjectNumber := 1 to ObjectCount - 1 do
  begin
    WriteText(Format('%.10d 00000 n ', [FObjectOffsets[ObjectNumber]]) + LineFeed);
  end;

  WriteText(Format('trailer' + LineFeed + '<< /Size %d /Root %d 0 R >>' + LineFeed, [ObjectCount, CatalogObjectNumber]));
  WriteText(Format('startxref' + LineFeed + '%d' + LineFeed + '%%%%EOF' + LineFeed, [CrossReferenceOffset]));
end;

procedure TMarkdownPdfWriter.BeginObject(const ObjectNumber: Integer);
begin
  FObjectOffsets.AddOrSetValue(ObjectNumber, FStream.Position - FStartPosition);
  WriteText(Format('%d 0 obj', [ObjectNumber]) + LineFeed);
end;

procedure TMarkdownPdfWriter.WriteStreamObject(const ObjectNumber: Integer; const Dictionary: string;
  const Data: TBytes);
begin
  BeginObject(ObjectNumber);
  WriteText(Dictionary + LineFeed + 'stream' + LineFeed);
  WriteBytes(Data);
  WriteText(LineFeed + 'endstream' + LineFeed);
  EndObject;
end;

procedure TMarkdownPdfWriter.EndObject;
begin
  WriteText('endobj' + LineFeed);
end;

procedure TMarkdownPdfWriter.WriteText(const Text: string);
begin
  WriteBytes(TEncoding.ASCII.GetBytes(Text));
end;

procedure TMarkdownPdfWriter.WriteBytes(const Data: TBytes);
begin
  if Length(Data) = 0 then
    Exit;

  FStream.WriteBuffer(Data, Length(Data));
end;

class function TMarkdownPdfWriter.FormatNumber(const Value: Single): string;
begin
  Result := FormatFloat(NumberFormat, Value, TFormatSettings.Invariant);
end;

end.
