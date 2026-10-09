unit Markdown4D.Vcl.PdfRasterizer;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  Vcl.Graphics,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Export.Pagination,
  Markdown4D.Export.Pdf.Interfaces,
  Markdown4D.Vcl.Painter;

type
  // Paints the pages of a PDF export with the same GDI painter the viewer
  // uses, on an offscreen bitmap the size of the content area of a page.
  TMarkdownVclPdfRasterizer = class(TInterfacedObject, IMarkdownImageSizeProvider, IMarkdownPdfPageRasterizer)
  private
    const
      BytesPerPixel = 3;
    var
      FBitmap: TBitmap;
      FPainter: IPainter;
      FImageResolver: TMarkdownVclImageResolver;
    procedure ClearPage;
    procedure RenderSlice(const DisplayList: IMarkdownDisplayList; const Slice: TMarkdownPageSlice;
      const Background: TLayoutColor);
    function ReadPixels: TMarkdownPdfPageImage;
    procedure CopyRow(const Row: Integer; const Pixels: TBytes);

  public
    // The resolvers answer what the viewer shows: a loaded image, and whether
    // one failed, so a missing image becomes the same placeholder as there.
    constructor Create(const ImageResolver: TMarkdownVclImageResolver;
                       const BrokenImageQuery: TMarkdownVclBrokenImageQuery);
    destructor Destroy; override;
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
    function Measurer: ITextMeasurer;
    function RasterizePage(const DisplayList: IMarkdownDisplayList; const Slice: TMarkdownPageSlice;
      const Background: TLayoutColor): TMarkdownPdfPageImage;
  end;

implementation

uses
  System.Types,
  Winapi.Windows,
  Markdown4D.Layout.Defaults,
  Markdown4D.Layout.Renderer,
  Markdown4D.Export.Pdf.Geometry;

constructor TMarkdownVclPdfRasterizer.Create(const ImageResolver: TMarkdownVclImageResolver;
  const BrokenImageQuery: TMarkdownVclBrokenImageQuery);
begin
  inherited Create;

  FImageResolver := ImageResolver;

  FBitmap := Vcl.Graphics.TBitmap.Create;
  FBitmap.PixelFormat := pf24bit;
  FBitmap.SetSize(TMarkdownPdfPageGeometry.ContentWidthPixels, TMarkdownPdfPageGeometry.ContentHeightPixels);

  // The layout is already scaled to the raster resolution, so the painter
  // takes its sizes as pixels.
  const Painter = TMarkdownVclPainter.Create(FBitmap.Canvas, ReferencePixelsPerInch);
  Painter.ImageResolver := ImageResolver;
  Painter.BrokenImageQuery := BrokenImageQuery;
  FPainter := Painter;
end;

destructor TMarkdownVclPdfRasterizer.Destroy;
begin
  FPainter := nil;
  FBitmap.Free;

  inherited Destroy;
end;

function TMarkdownVclPdfRasterizer.TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
begin
  Size := TLayoutSizeF.Create(0, 0);

  var Graphic: TGraphic := nil;
  if Assigned(FImageResolver) then
    Graphic := FImageResolver(Source);

  Result := (Graphic <> nil) and not Graphic.Empty;
  if Result then
    Size := TLayoutSizeF.Create(Graphic.Width, Graphic.Height);
end;

function TMarkdownVclPdfRasterizer.Measurer: ITextMeasurer;
begin
  Result := FPainter;
end;

function TMarkdownVclPdfRasterizer.RasterizePage(const DisplayList: IMarkdownDisplayList;
  const Slice: TMarkdownPageSlice; const Background: TLayoutColor): TMarkdownPdfPageImage;
begin
  ClearPage;
  RenderSlice(DisplayList, Slice, Background);

  Result := ReadPixels;
end;

// Paper is white below the last line of the document and behind a theme
// colour that is not opaque.
procedure TMarkdownVclPdfRasterizer.ClearPage;
begin
  FBitmap.Canvas.Brush.Style := bsSolid;
  FBitmap.Canvas.Brush.Color := clWhite;
  FBitmap.Canvas.FillRect(TRect.Create(0, 0, FBitmap.Width, FBitmap.Height));
end;

procedure TMarkdownVclPdfRasterizer.RenderSlice(const DisplayList: IMarkdownDisplayList;
  const Slice: TMarkdownPageSlice; const Background: TLayoutColor);
begin
  const Handle = FBitmap.Canvas.Handle;
  SetWindowOrgEx(Handle, 0, Round(Slice.Top), nil);
  try
    const Viewport = TLayoutRectF.Create(0, Slice.Top, FBitmap.Width, Slice.Bottom);
    TMarkdownDisplayListRenderer.Render(DisplayList, FPainter, Viewport, Background);
  finally
    SetWindowOrgEx(Handle, 0, 0, nil);
  end;
end;

function TMarkdownVclPdfRasterizer.ReadPixels: TMarkdownPdfPageImage;
begin
  GdiFlush;

  Result := TMarkdownPdfPageImage.Create(FBitmap.Width, FBitmap.Height);
  for var Row := 0 to FBitmap.Height - 1 do
  begin
    CopyRow(Row, Result.Pixels);
  end;
end;

// A 24-bit DIB row holds blue, green, red; the PDF wants red, green, blue.
procedure TMarkdownVclPdfRasterizer.CopyRow(const Row: Integer; const Pixels: TBytes);
begin
  const Source: PByte = FBitmap.ScanLine[Row];
  const RowOffset = Row * FBitmap.Width * BytesPerPixel;

  for var Column := 0 to FBitmap.Width - 1 do
  begin
    const SourceIndex = Column * BytesPerPixel;
    const TargetIndex = RowOffset + SourceIndex;
    Pixels[TargetIndex]     := Source[SourceIndex + 2];
    Pixels[TargetIndex + 1] := Source[SourceIndex + 1];
    Pixels[TargetIndex + 2] := Source[SourceIndex];
  end;
end;

end.
