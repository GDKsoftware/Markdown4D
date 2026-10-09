unit Markdown4D.Fmx.PdfRasterizer;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  FMX.Graphics,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Export.Pagination,
  Markdown4D.Export.Pdf.Interfaces,
  Markdown4D.Fmx.Painter;

type
  // Paints the pages of a PDF export with the same painter the FMX viewer
  // uses, on an offscreen bitmap the size of the content area of a page.
  TMarkdownFmxPdfRasterizer = class(TInterfacedObject, IMarkdownImageSizeProvider, IMarkdownPdfPageRasterizer)
  private
    const
      BytesPerPixel = 3;
      SceneFailedMessage = 'The page bitmap could not be drawn on';
      MapFailedMessage = 'The pixels of the page bitmap could not be read';
    var
      FBitmap: TBitmap;
      FPainter: IPainter;
      FImageResolver: TMarkdownFmxImageResolver;
    procedure RenderSlice(const DisplayList: IMarkdownDisplayList; const Slice: TMarkdownPageSlice;
      const Background: TLayoutColor);
    function ReadPixels: TMarkdownPdfPageImage;
    procedure CopyRow(const Data: TBitmapData; const Row: Integer; const Pixels: TBytes);

  public
    // The resolvers answer what the viewer shows: a loaded image, and whether
    // one failed, so a missing image becomes the same placeholder as there.
    constructor Create(const ImageResolver: TMarkdownFmxImageResolver;
                       const BrokenImageQuery: TMarkdownFmxBrokenImageQuery);
    destructor Destroy; override;
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
    function Measurer: ITextMeasurer;
    function RasterizePage(const DisplayList: IMarkdownDisplayList; const Slice: TMarkdownPageSlice;
      const Background: TLayoutColor): TMarkdownPdfPageImage;
  end;

implementation

uses
  System.UITypes,
  System.Math.Vectors,
  Markdown4D.Layout.Renderer,
  Markdown4D.Export.Pdf.Errors,
  Markdown4D.Export.Pdf.Geometry;

constructor TMarkdownFmxPdfRasterizer.Create(const ImageResolver: TMarkdownFmxImageResolver;
  const BrokenImageQuery: TMarkdownFmxBrokenImageQuery);
begin
  inherited Create;

  FImageResolver := ImageResolver;

  // A bitmap scale of 1 makes one unit of the layout one pixel of the page.
  FBitmap := TBitmap.Create(TMarkdownPdfPageGeometry.ContentWidthPixels, TMarkdownPdfPageGeometry.ContentHeightPixels);
  FBitmap.BitmapScale := 1;

  const Painter = TMarkdownFmxPainter.Create(FBitmap.Canvas);
  Painter.ImageResolver := ImageResolver;
  Painter.BrokenImageQuery := BrokenImageQuery;
  FPainter := Painter;
end;

destructor TMarkdownFmxPdfRasterizer.Destroy;
begin
  FPainter := nil;
  FBitmap.Free;

  inherited Destroy;
end;

function TMarkdownFmxPdfRasterizer.TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
begin
  Size := TLayoutSizeF.Create(0, 0);

  var Bitmap: TBitmap := nil;
  if Assigned(FImageResolver) then
    Bitmap := FImageResolver(Source);

  Result := (Bitmap <> nil) and not Bitmap.IsEmpty;
  if Result then
    Size := TLayoutSizeF.Create(Bitmap.Width, Bitmap.Height);
end;

function TMarkdownFmxPdfRasterizer.Measurer: ITextMeasurer;
begin
  Result := FPainter;
end;

function TMarkdownFmxPdfRasterizer.RasterizePage(const DisplayList: IMarkdownDisplayList;
  const Slice: TMarkdownPageSlice; const Background: TLayoutColor): TMarkdownPdfPageImage;
begin
  RenderSlice(DisplayList, Slice, Background);

  Result := ReadPixels;
end;

// Paper is white below the last line of the document and behind a theme
// colour that is not opaque.
procedure TMarkdownFmxPdfRasterizer.RenderSlice(const DisplayList: IMarkdownDisplayList;
  const Slice: TMarkdownPageSlice; const Background: TLayoutColor);
begin
  const Canvas = FBitmap.Canvas;
  if not Canvas.BeginScene then
    raise EMarkdownPdfExportError.Create(SceneFailedMessage);

  try
    Canvas.Clear(TAlphaColors.White);
    Canvas.SetMatrix(TMatrix.CreateTranslation(0, -Slice.Top));
    try
      const Viewport = TLayoutRectF.Create(0, Slice.Top, FBitmap.Width, Slice.Bottom);
      TMarkdownDisplayListRenderer.Render(DisplayList, FPainter, Viewport, Background);
    finally
      Canvas.SetMatrix(TMatrix.Identity);
    end;
  finally
    Canvas.EndScene;
  end;
end;

function TMarkdownFmxPdfRasterizer.ReadPixels: TMarkdownPdfPageImage;
begin
  var Data: TBitmapData;
  if not FBitmap.Map(TMapAccess.Read, Data) then
    raise EMarkdownPdfExportError.Create(MapFailedMessage);

  try
    Result := TMarkdownPdfPageImage.Create(FBitmap.Width, FBitmap.Height);
    for var Row := 0 to FBitmap.Height - 1 do
    begin
      CopyRow(Data, Row, Result.Pixels);
    end;
  finally
    FBitmap.Unmap(Data);
  end;
end;

procedure TMarkdownFmxPdfRasterizer.CopyRow(const Data: TBitmapData; const Row: Integer; const Pixels: TBytes);
begin
  const RowOffset = Row * FBitmap.Width * BytesPerPixel;

  for var Column := 0 to FBitmap.Width - 1 do
  begin
    const Color = Data.GetPixel(Column, Row);
    const TargetIndex = RowOffset + (Column * BytesPerPixel);
    Pixels[TargetIndex]     := TAlphaColorRec(Color).R;
    Pixels[TargetIndex + 1] := TAlphaColorRec(Color).G;
    Pixels[TargetIndex + 2] := TAlphaColorRec(Color).B;
  end;
end;

end.
