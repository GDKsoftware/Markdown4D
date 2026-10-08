unit Markdown4DStudio.PdfExport;

{$SCOPEDENUMS ON}

// Framework-neutral PDF export of the studio: lays the document out on the
// printable width of an A4 page in the light theme, cuts the layout into
// pages, lets the host framework rasterise every page and writes the rasters
// into a minimal PDF without depending on a printer driver.

interface

uses
  System.SysUtils,
  System.Classes,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList;

const
  PdfRasterDpi = 200;

type
  // A4 with a margin of 2 cm on every side; the content is rasterised at
  // PdfRasterDpi.
  TPadPdfGeometry = class
  private
    const
      PageWidthMm = 210.0;
      PageHeightMm = 297.0;
      MarginMm = 20.0;
      MillimetresPerInch = 25.4;
      PointsPerInch = 72.0;
    class function MillimetresToPixels(const Millimetres: Double): Integer; static;
    class function MillimetresToPoints(const Millimetres: Double): Double; static;

  public
    class function ContentWidthPx: Integer; static;
    class function ContentHeightPx: Integer; static;
    // How much larger the PDF layout is than the preview at 100 percent.
    class function ImageScale: Single; static;
    class function PageWidthPt: Double; static;
    class function PageHeightPt: Double; static;
    class function MarginPt: Double; static;
    class function ContentWidthPt: Double; static;
  end;

  // The vertical stretch of the layout one page shows.
  TPadPdfPageSlice = record
    Top: Single;
    Bottom: Single;
    class function Create(const Top, Bottom: Single): TPadPdfPageSlice; static;
  end;

  // RGB, 3 bytes per pixel, row by row from top to bottom.
  TPadPdfPageImage = record
    Width: Integer;
    Height: Integer;
    Pixels: TBytes;
  end;

  // The Flate-compressed pixels of one page.
  TPadPdfPageStream = record
    Width: Integer;
    Height: Integer;
    Data: TBytes;
  end;

  // Implemented by the host form with its own painter. TryGetImageSize answers
  // the natural, unscaled pixel size of an image the preview has loaded; the
  // layout scales it to the raster resolution itself.
  IPadPdfPageRenderer = interface(IMarkdownImageSizeProvider)
    ['{6B1E3F2A-8C47-4D95-A0B3-5E2D7C9F1A48}']
    function Measurer: ITextMeasurer;
    function RenderPage(const DisplayList: IMarkdownDisplayList; const Slice: TPadPdfPageSlice;
      const BackgroundColor: TLayoutColor): TPadPdfPageImage;
  end;

  TPadPdfLayout = class
  public
    // Always the light theme, whatever theme the studio shows, without the
    // content padding of the preview so the page margin is exactly 2 cm.
    class function Build(const Markdown: string; const Measurer: ITextMeasurer;
      const ImageSizes: IMarkdownImageSizeProvider): IMarkdownDisplayList; static;
  end;

  TPadPdfPagination = class
  private
    const
      Tolerance = 0.01;
    class function FindBreak(const DisplayList: IMarkdownDisplayList; const Top, PageHeight: Single): Single; static;
    class function TryFindCrossingBlock(const DisplayList: IMarkdownDisplayList; const Y: Single;
      out Block: TLayoutBlockInfo): Boolean; static;
    class function LargestFreeY(const DisplayList: IMarkdownDisplayList; const Limit: Single): Single; static;
    class function IsBreakingItem(const Item: IDisplayItem): Boolean; static;

  public
    // Prefers block boundaries; a block taller than a page is cut between its
    // text lines or rows, and where no such place exists, hard at the page
    // height. An empty document gives one empty page.
    class function Paginate(const DisplayList: IMarkdownDisplayList;
      const PageHeight: Single): TArray<TPadPdfPageSlice>; static;
  end;

  TPadPdfWriter = class
  private
    const
      CatalogObject = 1;
      PagesObject = 2;
      FirstPageObject = 3;
      ObjectsPerPage = 3;
    var
      FStream: TBytesStream;
      FOffsets: TArray<Int64>;
    class function PageObject(const PageIndex: Integer): Integer; static;
    class function FormatNumber(const Value: Double): string; static;
    constructor Create(const PageCount: Integer);
    procedure WriteDocument(const Pages: TArray<TPadPdfPageStream>);
    procedure WriteHeader;
    procedure WriteCatalog;
    procedure WritePageTree(const PageCount: Integer);
    procedure WritePage(const PageIndex: Integer; const Page: TPadPdfPageStream);
    procedure WriteContent(const ObjectNumber: Integer; const Page: TPadPdfPageStream);
    procedure WriteImage(const ObjectNumber: Integer; const Page: TPadPdfPageStream);
    procedure WriteCrossReference;
    procedure WriteDictionaryObject(const ObjectNumber: Integer; const Dictionary: string);
    procedure WriteStreamObject(const ObjectNumber: Integer; const Dictionary: string; const Data: TBytes);
    procedure BeginObject(const ObjectNumber: Integer);
    procedure EndObject;
    procedure WriteText(const Text: string);
    procedure WriteBytes(const Data: TBytes);
    function DocumentBytes: TBytes;

  public
    class function CompressPage(const Image: TPadPdfPageImage): TPadPdfPageStream; static;
    class function Write(const Pages: TArray<TPadPdfPageStream>): TBytes; static;
    destructor Destroy; override;
  end;

  TPadPdfExport = class
  private
    const
      PageBackgroundColor = TLayoutColor($FFFFFFFF);

  public
    // Renders and compresses one page at a time, so never more than one raw
    // page raster is held in memory.
    class function BuildDocument(const Markdown: string; const Renderer: IPadPdfPageRenderer): TBytes; static;
  end;

implementation

uses
  System.Math,
  System.ZLib,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Theme,
  Markdown4D.Layout.Defaults,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Layout.Engine;

type
  // Scales the natural image sizes of the renderer to the raster resolution,
  // the way the viewer model scales them with its zoom factor.
  TPadPdfScaledImageSizes = class(TInterfacedObject, IMarkdownImageSizeProvider)
  private
    FNaturalSizes: IMarkdownImageSizeProvider;

  public
    constructor Create(const NaturalSizes: IMarkdownImageSizeProvider);
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
  end;

constructor TPadPdfScaledImageSizes.Create(const NaturalSizes: IMarkdownImageSizeProvider);
begin
  inherited Create;
  FNaturalSizes := NaturalSizes;
end;

function TPadPdfScaledImageSizes.TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
begin
  Result := FNaturalSizes.TryGetImageSize(Source, Size);
  if not Result then
    Exit;

  const Scale = TPadPdfGeometry.ImageScale;
  Size := TLayoutSizeF.Create(Size.Width * Scale, Size.Height * Scale);
end;

{ TPadPdfGeometry }

class function TPadPdfGeometry.ContentWidthPx: Integer;
begin
  Result := MillimetresToPixels(PageWidthMm - 2 * MarginMm);
end;

class function TPadPdfGeometry.ContentHeightPx: Integer;
begin
  Result := MillimetresToPixels(PageHeightMm - 2 * MarginMm);
end;

class function TPadPdfGeometry.ImageScale: Single;
begin
  Result := PdfRasterDpi / ReferencePixelsPerInch;
end;

class function TPadPdfGeometry.PageWidthPt: Double;
begin
  Result := MillimetresToPoints(PageWidthMm);
end;

class function TPadPdfGeometry.PageHeightPt: Double;
begin
  Result := MillimetresToPoints(PageHeightMm);
end;

class function TPadPdfGeometry.MarginPt: Double;
begin
  Result := MillimetresToPoints(MarginMm);
end;

class function TPadPdfGeometry.ContentWidthPt: Double;
begin
  Result := MillimetresToPoints(PageWidthMm - 2 * MarginMm);
end;

class function TPadPdfGeometry.MillimetresToPixels(const Millimetres: Double): Integer;
begin
  Result := Round(Millimetres / MillimetresPerInch * PdfRasterDpi);
end;

class function TPadPdfGeometry.MillimetresToPoints(const Millimetres: Double): Double;
begin
  Result := Millimetres / MillimetresPerInch * PointsPerInch;
end;

{ TPadPdfPageSlice }

class function TPadPdfPageSlice.Create(const Top, Bottom: Single): TPadPdfPageSlice;
begin
  Result.Top := Top;
  Result.Bottom := Bottom;
end;

{ TPadPdfLayout }

class function TPadPdfLayout.Build(const Markdown: string; const Measurer: ITextMeasurer;
  const ImageSizes: IMarkdownImageSizeProvider): IMarkdownDisplayList;
begin
  const Document = TMarkdown.Parse(Markdown, TMarkdownDialect.Gfm);
  TLayoutDocumentProcessorRegistry.Process(Document);

  var ScaledSizes: IMarkdownImageSizeProvider := nil;
  if ImageSizes <> nil then
    ScaledSizes := TPadPdfScaledImageSizes.Create(ImageSizes);

  const LightTheme = TMarkdownTheme.CreateLight;
  try
    const Theme = LightTheme.Scaled(TPadPdfGeometry.ImageScale);
    try
      Theme.ContentPadding := 0;
      Result := TMarkdownLayoutEngine.LayoutDocument(Document, TPadPdfGeometry.ContentWidthPx, Theme, Measurer,
                                                     ScaledSizes);
    finally
      Theme.Free;
    end;
  finally
    LightTheme.Free;
  end;
end;

{ TPadPdfPagination }

class function TPadPdfPagination.Paginate(const DisplayList: IMarkdownDisplayList;
  const PageHeight: Single): TArray<TPadPdfPageSlice>;
begin
  Result := [];

  const DocumentHeight = DisplayList.Height;
  var Top: Single := 0;
  while Top < DocumentHeight - Tolerance do
  begin
    const IsLastPage = (Top + PageHeight >= DocumentHeight);
    var Bottom := DocumentHeight;
    if not IsLastPage then
      Bottom := FindBreak(DisplayList, Top, PageHeight);

    Result := Result + [TPadPdfPageSlice.Create(Top, Bottom)];
    Top := Bottom;
  end;

  const IsEmpty = (Length(Result) = 0);
  if IsEmpty then
    Result := [TPadPdfPageSlice.Create(0, 0)];
end;

// A block that crosses the page end but fits on an empty page moves to the
// next page whole; otherwise the page ends at the lowest place no text line,
// image or checkbox runs through, and failing that, hard at the page height.
class function TPadPdfPagination.FindBreak(const DisplayList: IMarkdownDisplayList;
  const Top, PageHeight: Single): Single;
begin
  const Limit = Top + PageHeight;

  var Block: TLayoutBlockInfo;
  const HasCrossingBlock = TryFindCrossingBlock(DisplayList, Limit, Block);
  const CanMoveBlock = (HasCrossingBlock and
                        (Block.Top > Top + Tolerance) and
                        (Block.Height <= PageHeight));
  if CanMoveBlock then
  begin
    Result := Block.Top;
    Exit;
  end;

  Result := LargestFreeY(DisplayList, Limit);
  const HasProgress = (Result > Top + Tolerance);
  if not HasProgress then
    Result := Limit;
end;

class function TPadPdfPagination.TryFindCrossingBlock(const DisplayList: IMarkdownDisplayList; const Y: Single;
  out Block: TLayoutBlockInfo): Boolean;
begin
  for var Index := 0 to DisplayList.BlockCount - 1 do
  begin
    Block := DisplayList.BlockInfos[Index];
    const IsCrossing = ((Block.Top < Y - Tolerance) and (Block.Top + Block.Height > Y + Tolerance));
    if IsCrossing then
    begin
      Result := True;
      Exit;
    end;
  end;

  Block := Default(TLayoutBlockInfo);
  Result := False;
end;

// Moves up from Limit to the top of every breaking item that runs through the
// candidate until none does; every step lowers the candidate, so it ends.
class function TPadPdfPagination.LargestFreeY(const DisplayList: IMarkdownDisplayList; const Limit: Single): Single;
begin
  Result := Limit;

  var HasMoved: Boolean;
  repeat
    HasMoved := False;
    for var Index := 0 to DisplayList.ItemCount - 1 do
    begin
      const Item = DisplayList.Items[Index];
      if not IsBreakingItem(Item) then
        Continue;

      const Bounds = Item.Bounds;
      const IsCrossing = ((Bounds.Top < Result - Tolerance) and (Bounds.Bottom > Result + Tolerance));
      if IsCrossing then
      begin
        Result := Bounds.Top;
        HasMoved := True;
      end;
    end;
  until not HasMoved;
end;

// Backgrounds, rules, borders and chart shapes often span a whole block and
// may be cut; text, images and checkboxes never.
class function TPadPdfPagination.IsBreakingItem(const Item: IDisplayItem): Boolean;
begin
  case Item.Kind of
    TDisplayItemKind.TextRun,
    TDisplayItemKind.Image,
    TDisplayItemKind.Checkbox  : Result := True;
    TDisplayItemKind.Rectangle,
    TDisplayItemKind.Line,
    TDisplayItemKind.Wedge,
    TDisplayItemKind.Polygon   : Result := False;
  else
    raise ENotSupportedException.CreateFmt('Unsupported display item kind: %d', [Ord(Item.Kind)]);
  end;
end;

{ TPadPdfWriter }

class function TPadPdfWriter.CompressPage(const Image: TPadPdfPageImage): TPadPdfPageStream;
begin
  Result.Width := Image.Width;
  Result.Height := Image.Height;
  ZCompress(Image.Pixels, Result.Data);
end;

class function TPadPdfWriter.Write(const Pages: TArray<TPadPdfPageStream>): TBytes;
begin
  const Writer = TPadPdfWriter.Create(Length(Pages));
  try
    Writer.WriteDocument(Pages);
    Result := Writer.DocumentBytes;
  finally
    Writer.Free;
  end;
end;

class function TPadPdfWriter.PageObject(const PageIndex: Integer): Integer;
begin
  Result := FirstPageObject + PageIndex * ObjectsPerPage;
end;

class function TPadPdfWriter.FormatNumber(const Value: Double): string;
begin
  Result := FormatFloat('0.##', Value, TFormatSettings.Invariant);
end;

constructor TPadPdfWriter.Create(const PageCount: Integer);
begin
  inherited Create;
  FStream := TBytesStream.Create;
  SetLength(FOffsets, PageObject(PageCount));
end;

destructor TPadPdfWriter.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

procedure TPadPdfWriter.WriteDocument(const Pages: TArray<TPadPdfPageStream>);
begin
  WriteHeader;
  WriteCatalog;
  WritePageTree(Length(Pages));

  for var Index := 0 to High(Pages) do
  begin
    WritePage(Index, Pages[Index]);
  end;

  WriteCrossReference;
end;

// The comment line with bytes above 127 tells transfer tools the file is binary.
procedure TPadPdfWriter.WriteHeader;
begin
  WriteText('%PDF-1.4' + LineFeed);
  WriteBytes([Ord('%'), $E2, $E3, $CF, $D3, Ord(LineFeed)]);
end;

procedure TPadPdfWriter.WriteCatalog;
begin
  const Dictionary = Format('<< /Type /Catalog /Pages %d 0 R >>', [PagesObject]);
  WriteDictionaryObject(CatalogObject, Dictionary);
end;

procedure TPadPdfWriter.WritePageTree(const PageCount: Integer);
begin
  var Kids: TArray<string> := [];
  for var Index := 0 to PageCount - 1 do
  begin
    Kids := Kids + [Format('%d 0 R', [PageObject(Index)])];
  end;

  const KidList = string.Join(' ', Kids);
  const Dictionary = Format('<< /Type /Pages /Kids [%s] /Count %d >>', [KidList, PageCount]);
  WriteDictionaryObject(PagesObject, Dictionary);
end;

procedure TPadPdfWriter.WritePage(const PageIndex: Integer; const Page: TPadPdfPageStream);
begin
  const PageNumber = PageObject(PageIndex);
  const ContentNumber = PageNumber + 1;
  const ImageNumber = PageNumber + 2;
  const PageWidth = FormatNumber(TPadPdfGeometry.PageWidthPt);
  const PageHeight = FormatNumber(TPadPdfGeometry.PageHeightPt);

  const Dictionary = Format('<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %s %s] ' +
                            '/Resources << /XObject << /Im0 %d 0 R >> >> /Contents %d 0 R >>',
                            [PagesObject, PageWidth, PageHeight, ImageNumber, ContentNumber]);
  WriteDictionaryObject(PageNumber, Dictionary);

  WriteContent(ContentNumber, Page);
  WriteImage(ImageNumber, Page);
end;

// Places the page raster at the top left of the area inside the margins, as
// wide as that area and with the aspect ratio of the raster.
procedure TPadPdfWriter.WriteContent(const ObjectNumber: Integer; const Page: TPadPdfPageStream);
begin
  const Width = TPadPdfGeometry.ContentWidthPt;
  const Height = Width * Page.Height / Max(Page.Width, 1);
  const Left = TPadPdfGeometry.MarginPt;
  const Bottom = TPadPdfGeometry.PageHeightPt - TPadPdfGeometry.MarginPt - Height;
  const Content = Format('q %s 0 0 %s %s %s cm /Im0 Do Q',
                         [FormatNumber(Width), FormatNumber(Height), FormatNumber(Left), FormatNumber(Bottom)]);

  const Data = TEncoding.ASCII.GetBytes(Content);
  const Dictionary = Format('<< /Length %d >>', [Length(Data)]);
  WriteStreamObject(ObjectNumber, Dictionary, Data);
end;

procedure TPadPdfWriter.WriteImage(const ObjectNumber: Integer; const Page: TPadPdfPageStream);
begin
  const Dictionary = Format('<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB ' +
                            '/BitsPerComponent 8 /Filter /FlateDecode /Length %d >>',
                            [Page.Width, Page.Height, Length(Page.Data)]);
  WriteStreamObject(ObjectNumber, Dictionary, Page.Data);
end;

// Every entry is exactly 20 bytes, as the format requires.
procedure TPadPdfWriter.WriteCrossReference;
begin
  const CrossReferenceOffset = FStream.Position;
  const ObjectCount = Length(FOffsets);

  WriteText(Format('xref' + LineFeed + '0 %d' + LineFeed, [ObjectCount]));
  WriteText('0000000000 65535 f ' + LineFeed);
  for var ObjectNumber := 1 to ObjectCount - 1 do
  begin
    WriteText(Format('%.10d 00000 n ', [FOffsets[ObjectNumber]]) + LineFeed);
  end;

  WriteText(Format('trailer' + LineFeed + '<< /Size %d /Root %d 0 R >>' + LineFeed, [ObjectCount, CatalogObject]));
  WriteText(Format('startxref' + LineFeed + '%d' + LineFeed, [CrossReferenceOffset]));
  WriteText('%%EOF' + LineFeed);
end;

procedure TPadPdfWriter.WriteDictionaryObject(const ObjectNumber: Integer; const Dictionary: string);
begin
  BeginObject(ObjectNumber);
  WriteText(Dictionary + LineFeed);
  EndObject;
end;

procedure TPadPdfWriter.WriteStreamObject(const ObjectNumber: Integer; const Dictionary: string;
  const Data: TBytes);
begin
  BeginObject(ObjectNumber);
  WriteText(Dictionary + LineFeed + 'stream' + LineFeed);
  WriteBytes(Data);
  WriteText(LineFeed + 'endstream' + LineFeed);
  EndObject;
end;

procedure TPadPdfWriter.BeginObject(const ObjectNumber: Integer);
begin
  FOffsets[ObjectNumber] := FStream.Position;
  WriteText(Format('%d 0 obj', [ObjectNumber]) + LineFeed);
end;

procedure TPadPdfWriter.EndObject;
begin
  WriteText('endobj' + LineFeed);
end;

procedure TPadPdfWriter.WriteText(const Text: string);
begin
  WriteBytes(TEncoding.ASCII.GetBytes(Text));
end;

procedure TPadPdfWriter.WriteBytes(const Data: TBytes);
begin
  const HasData = (Length(Data) > 0);
  if HasData then
    FStream.WriteBuffer(Data[0], Length(Data));
end;

function TPadPdfWriter.DocumentBytes: TBytes;
begin
  Result := Copy(FStream.Bytes, 0, FStream.Size);
end;

{ TPadPdfExport }

class function TPadPdfExport.BuildDocument(const Markdown: string; const Renderer: IPadPdfPageRenderer): TBytes;
begin
  const DisplayList = TPadPdfLayout.Build(Markdown, Renderer.Measurer, Renderer);
  const Slices = TPadPdfPagination.Paginate(DisplayList, TPadPdfGeometry.ContentHeightPx);

  var Pages: TArray<TPadPdfPageStream>;
  SetLength(Pages, Length(Slices));
  for var Index := 0 to High(Slices) do
  begin
    const Image = Renderer.RenderPage(DisplayList, Slices[Index], PageBackgroundColor);
    Pages[Index] := TPadPdfWriter.CompressPage(Image);
  end;

  Result := TPadPdfWriter.Write(Pages);
end;

end.
