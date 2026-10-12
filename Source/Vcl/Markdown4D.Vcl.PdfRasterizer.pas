unit Markdown4D.Vcl.PdfRasterizer;

{$SCOPEDENUMS ON}

// Paints the pages of a PDF export with the VCL painter into a 24-bit bitmap.
// Text is measured at the reference resolution; the export scales every page
// up to 200 dpi itself.

interface

uses
  System.SysUtils,
  Vcl.Graphics,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Export.Pdf.Interfaces,
  Markdown4D.Vcl.Painter;

type
  TMarkdownVclPdfRasterizer = class(TInterfacedObject, IMarkdownImageSizeProvider, IMarkdownPdfPageRasterizer)
  private
    const
      BlueOffset = 0;
      GreenOffset = 1;
      RedOffset = 2;
    var
      FImageResolver: TMarkdownVclImageResolver;
      FMeasureBitmap: TBitmap;
      FMeasurer: IPainter;
      FPageBitmap: TBitmap;
    function IsImageBroken(const Source: string): Boolean;
    function ReadRow(const Row: Integer): TBytes;
    class procedure CopyRowAsRgb(const BgrRow: TBytes; const Pixels: TBytes; const Offset: Integer); static;

  public
    // The resolver answers the images the viewer has loaded; an image it does
    // not know is drawn as a frame with a cross.
    constructor Create(const ImageResolver: TMarkdownVclImageResolver);
    destructor Destroy; override;
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
    function Measurer: ITextMeasurer;
    function BeginPage(const Background: TLayoutColor): IPainter;
    function EndPage: TMarkdownPdfPageImage;
  end;

implementation

uses
  Markdown4D.Export.Pdf.Geometry,
  Markdown4D.Export.ScaledPainter;

constructor TMarkdownVclPdfRasterizer.Create(const ImageResolver: TMarkdownVclImageResolver);
begin
  inherited Create;

  FImageResolver := ImageResolver;

  FMeasureBitmap := TBitmap.Create;
  FMeasureBitmap.SetSize(1, 1);
  // Words are measured at the size they are printed, so the layout leaves the
  // room the printed glyphs take; hinting makes widths at 96 dpi differ.
  const InnerMeasurer: IPainter = TMarkdownVclPainter.Create(FMeasureBitmap.Canvas);
  FMeasurer := TMarkdownScaledPainter.Create(InnerMeasurer, 0, TMarkdownPdfPageGeometry.RasterScale);

  FPageBitmap := TBitmap.Create;
  FPageBitmap.PixelFormat := pf24bit;
  FPageBitmap.SetSize(TMarkdownPdfPageGeometry.RasterWidthPixels, TMarkdownPdfPageGeometry.RasterHeightPixels);
end;

destructor TMarkdownVclPdfRasterizer.Destroy;
begin
  FMeasurer := nil;
  FMeasureBitmap.Free;
  FPageBitmap.Free;

  inherited Destroy;
end;

function TMarkdownVclPdfRasterizer.TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
begin
  Size := Default(TLayoutSizeF);

  var Graphic: TGraphic := nil;
  if Assigned(FImageResolver) then
    Graphic := FImageResolver(Source);

  Result := (Graphic <> nil) and not Graphic.Empty;
  if Result then
    Size := TLayoutSizeF.Create(Graphic.Width, Graphic.Height);
end;

function TMarkdownVclPdfRasterizer.Measurer: ITextMeasurer;
begin
  Result := FMeasurer;
end;

function TMarkdownVclPdfRasterizer.BeginPage(const Background: TLayoutColor): IPainter;
begin
  const Painter = TMarkdownVclPainter.Create(FPageBitmap.Canvas);
  Painter.ImageResolver := FImageResolver;
  Painter.BrokenImageQuery := IsImageBroken;
  Result := Painter;

  const PageBounds = TLayoutRectF.Create(0, 0, FPageBitmap.Width, FPageBitmap.Height);
  Result.FillRect(PageBounds, Background);
end;

// The painter asks only for an image it could not resolve. The export waited
// for every image before it started, so what is missing now will not come.
function TMarkdownVclPdfRasterizer.IsImageBroken(const Source: string): Boolean;
begin
  Result := True;
end;

function TMarkdownVclPdfRasterizer.EndPage: TMarkdownPdfPageImage;
begin
  const Width = FPageBitmap.Width;
  const Height = FPageBitmap.Height;
  const RowByteCount = Width * TMarkdownPdfPageImage.BytesPerPixel;

  var Pixels: TBytes;
  SetLength(Pixels, RowByteCount * Height);

  for var Row := 0 to Height - 1 do
  begin
    const BgrRow = ReadRow(Row);
    CopyRowAsRgb(BgrRow, Pixels, Row * RowByteCount);
  end;

  Result := TMarkdownPdfPageImage.Create(Width, Height, Pixels);
end;

function TMarkdownVclPdfRasterizer.ReadRow(const Row: Integer): TBytes;
begin
  SetLength(Result, FPageBitmap.Width * TMarkdownPdfPageImage.BytesPerPixel);

  const Scanline: PByte = FPageBitmap.ScanLine[Row];
  Move(Scanline^, Result[0], Length(Result));
end;

class procedure TMarkdownVclPdfRasterizer.CopyRowAsRgb(const BgrRow: TBytes; const Pixels: TBytes;
  const Offset: Integer);
begin
  const PixelCount = Length(BgrRow) div TMarkdownPdfPageImage.BytesPerPixel;
  for var Pixel := 0 to PixelCount - 1 do
  begin
    const Source = Pixel * TMarkdownPdfPageImage.BytesPerPixel;
    const Target = Offset + Source;
    Pixels[Target]     := BgrRow[Source + RedOffset];
    Pixels[Target + 1] := BgrRow[Source + GreenOffset];
    Pixels[Target + 2] := BgrRow[Source + BlueOffset];
  end;
end;

end.
