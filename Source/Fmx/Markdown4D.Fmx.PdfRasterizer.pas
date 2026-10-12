unit Markdown4D.Fmx.PdfRasterizer;

{$SCOPEDENUMS ON}

// Paints the pages of a PDF export with the FMX painter into an offscreen
// bitmap. Text is measured at the reference resolution; the export scales
// every page up to 200 dpi itself.

interface

uses
  System.SysUtils,
  FMX.Types,
  FMX.Graphics,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Export.Pdf.Interfaces,
  Markdown4D.Fmx.Painter;

type
  TMarkdownFmxPdfRasterizer = class(TInterfacedObject, IMarkdownImageSizeProvider, IMarkdownPdfPageRasterizer)
  private
    const
      SourceBytesPerPixel = 4;
      LastColorOffset = 2;
      UnmappableMessage = 'The PDF page bitmap could not be read';
      UnsupportedFormatMessage = 'The PDF page bitmap has an unsupported pixel format: %d';
    var
      FImageResolver: TMarkdownFmxImageResolver;
      FMeasureBitmap: TBitmap;
      FMeasurer: IPainter;
      FPageBitmap: TBitmap;
      FIsPainting: Boolean;
    function IsImageBroken(const Source: string): Boolean;
    procedure FinishScene;
    function ReadPixels: TBytes;
    class procedure CopyRowAsRgb(const SourceRow: TBytes; const Format: TPixelFormat; const Pixels: TBytes;
      const Offset: Integer); static;
    class function RedOffsetOf(const Format: TPixelFormat): Integer; static;

  public
    // The resolver answers the images the viewer has loaded; an image it does
    // not know is drawn as a frame with a cross.
    constructor Create(const ImageResolver: TMarkdownFmxImageResolver);
    destructor Destroy; override;
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
    function Measurer: ITextMeasurer;
    function BeginPage(const Background: TLayoutColor): IPainter;
    function EndPage: TMarkdownPdfPageImage;
  end;

implementation

uses
  Markdown4D.Export.Pdf.Errors,
  Markdown4D.Export.Pdf.Geometry,
  Markdown4D.Export.ScaledPainter;

constructor TMarkdownFmxPdfRasterizer.Create(const ImageResolver: TMarkdownFmxImageResolver);
begin
  inherited Create;

  FImageResolver := ImageResolver;

  FMeasureBitmap := TBitmap.Create(1, 1);
  // Words are measured at the size they are printed, so the layout leaves the
  // room the printed glyphs take; hinting makes widths at 96 dpi differ.
  const InnerMeasurer: IPainter = TMarkdownFmxPainter.Create(FMeasureBitmap.Canvas);
  FMeasurer := TMarkdownScaledPainter.Create(InnerMeasurer, 0, TMarkdownPdfPageGeometry.RasterScale);

  FPageBitmap := TBitmap.Create(TMarkdownPdfPageGeometry.RasterWidthPixels,
    TMarkdownPdfPageGeometry.RasterHeightPixels);
end;

destructor TMarkdownFmxPdfRasterizer.Destroy;
begin
  if FPageBitmap <> nil then
    FinishScene;

  FMeasurer := nil;
  FMeasureBitmap.Free;
  FPageBitmap.Free;

  inherited Destroy;
end;

function TMarkdownFmxPdfRasterizer.TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
begin
  Size := Default(TLayoutSizeF);

  var Bitmap: TBitmap := nil;
  if Assigned(FImageResolver) then
    Bitmap := FImageResolver(Source);

  Result := (Bitmap <> nil) and not Bitmap.IsEmpty;
  if Result then
    Size := TLayoutSizeF.Create(Bitmap.Width, Bitmap.Height);
end;

function TMarkdownFmxPdfRasterizer.Measurer: ITextMeasurer;
begin
  Result := FMeasurer;
end;

function TMarkdownFmxPdfRasterizer.BeginPage(const Background: TLayoutColor): IPainter;
begin
  FinishScene;
  FIsPainting := FPageBitmap.Canvas.BeginScene;

  const Painter = TMarkdownFmxPainter.Create(FPageBitmap.Canvas);
  Painter.ImageResolver := FImageResolver;
  Painter.BrokenImageQuery := IsImageBroken;
  Result := Painter;

  const PageBounds = TLayoutRectF.Create(0, 0, FPageBitmap.Width, FPageBitmap.Height);
  Result.FillRect(PageBounds, Background);
end;

// The painter asks only for an image it could not resolve. The export waited
// for every image before it started, so what is missing now will not come.
function TMarkdownFmxPdfRasterizer.IsImageBroken(const Source: string): Boolean;
begin
  Result := True;
end;

procedure TMarkdownFmxPdfRasterizer.FinishScene;
begin
  if not FIsPainting then
    Exit;

  FPageBitmap.Canvas.EndScene;
  FIsPainting := False;
end;

function TMarkdownFmxPdfRasterizer.EndPage: TMarkdownPdfPageImage;
begin
  FinishScene;

  const Pixels = ReadPixels;
  Result := TMarkdownPdfPageImage.Create(FPageBitmap.Width, FPageBitmap.Height, Pixels);
end;

function TMarkdownFmxPdfRasterizer.ReadPixels: TBytes;
begin
  const Width = FPageBitmap.Width;
  const Height = FPageBitmap.Height;
  const RowByteCount = Width * TMarkdownPdfPageImage.BytesPerPixel;
  SetLength(Result, RowByteCount * Height);

  var Data: TBitmapData;
  if not FPageBitmap.Map(TMapAccess.Read, Data) then
    raise EMarkdownPdfExportError.Create(UnmappableMessage);

  try
    var SourceRow: TBytes;
    SetLength(SourceRow, Width * SourceBytesPerPixel);

    for var Row := 0 to Height - 1 do
    begin
      const Scanline: PByte = Data.GetScanline(Row);
      Move(Scanline^, SourceRow[0], Length(SourceRow));
      CopyRowAsRgb(SourceRow, Data.PixelFormat, Result, Row * RowByteCount);
    end;
  finally
    FPageBitmap.Unmap(Data);
  end;
end;

class procedure TMarkdownFmxPdfRasterizer.CopyRowAsRgb(const SourceRow: TBytes; const Format: TPixelFormat;
  const Pixels: TBytes; const Offset: Integer);
begin
  const RedOffset = RedOffsetOf(Format);
  const GreenOffset = 1;
  const BlueOffset = LastColorOffset - RedOffset;
  const PixelCount = Length(SourceRow) div SourceBytesPerPixel;
  for var Pixel := 0 to PixelCount - 1 do
  begin
    const Source = Pixel * SourceBytesPerPixel;
    const Target = Offset + (Pixel * TMarkdownPdfPageImage.BytesPerPixel);
    Pixels[Target]     := SourceRow[Source + RedOffset];
    Pixels[Target + 1] := SourceRow[Source + GreenOffset];
    Pixels[Target + 2] := SourceRow[Source + BlueOffset];
  end;
end;

// Red and blue swap places between the two layouts; green sits in the middle.
class function TMarkdownFmxPdfRasterizer.RedOffsetOf(const Format: TPixelFormat): Integer;
begin
  case Format of
    TPixelFormat.BGRA : Result := LastColorOffset;
    TPixelFormat.RGBA : Result := 0;
  else
    raise EMarkdownPdfExportError.CreateFmt(UnsupportedFormatMessage, [Ord(Format)]);
  end;
end;

end.
