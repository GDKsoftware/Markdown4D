unit Markdown4D.Export.Pdf;

{$SCOPEDENUMS ON}

// Exports markdown to PDF: lays the document out in the built-in light theme
// at the reference resolution, cuts it into A4 pages, has the framework paint
// every page at 200 dpi and writes the pages as images. The theme and zoom of
// the preview play no part, so a PDF always looks the same.

interface

uses
  System.Classes,
  System.SysUtils,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Export.Pagination,
  Markdown4D.Export.Pdf.Interfaces,
  Markdown4D.Export.Pdf.Writer;

type
  TMarkdownPdfExporter = class
  private
    const
      PageBackgroundColor = TLayoutColor($FFFFFFFF);
      MissingRasterizerMessage = 'A PDF export needs a page rasterizer';
    class procedure GuardRasterizer(const Rasterizer: IMarkdownPdfPageRasterizer); static;
    class procedure RenderSlice(const DisplayList: IMarkdownDisplayList; const Slice: TMarkdownPageSlice;
      const Rasterizer: IMarkdownPdfPageRasterizer; const Writer: TMarkdownPdfWriter); static;

  public
    // The layout the PDF prints, without the pages: a page wide, in the light
    // theme at 100 percent, without the padding the preview keeps around it.
    class function BuildLayout(const Markdown: string; const Measurer: ITextMeasurer;
      const ImageSizes: IMarkdownImageSizeProvider): IMarkdownDisplayList; static;
    // Every image the layout shows, each once, in the order of the document.
    class function ImageSources(const DisplayList: IMarkdownDisplayList): TArray<string>; static;
    class procedure Export(const Markdown: string; const Rasterizer: IMarkdownPdfPageRasterizer;
      const Stream: TStream); static;
    // Asks for the images of the document and waits for them, within the default
    // time-out, before it exports. An image that did not arrive prints as a frame
    // with a cross.
    class procedure ExportWithImages(const Markdown: string; const Rasterizer: IMarkdownPdfPageRasterizer;
      const Stream: TStream; const RequestImages: TProc<TArray<string>>;
      const AreImagesSettled: TFunc<TArray<string>, Boolean>; const Pump: TProc); static;
  end;

implementation

uses
  System.Generics.Collections,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Theme,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.Renderer,
  Markdown4D.Export.Pdf.Errors,
  Markdown4D.Export.Pdf.Geometry,
  Markdown4D.Export.ImageWait,
  Markdown4D.Export.ScaledPainter;

class function TMarkdownPdfExporter.BuildLayout(const Markdown: string; const Measurer: ITextMeasurer;
  const ImageSizes: IMarkdownImageSizeProvider): IMarkdownDisplayList;
begin
  const Document = TMarkdown.Parse(Markdown, TMarkdownDialect.Gfm);
  TLayoutDocumentProcessorRegistry.Process(Document);

  const Theme = TMarkdownTheme.CreateLight;
  try
    Theme.ContentPadding := 0;
    Result := TMarkdownLayoutEngine.LayoutDocument(Document, TMarkdownPdfPageGeometry.LayoutWidth, Theme, Measurer,
      ImageSizes);
  finally
    Theme.Free;
  end;
end;

class function TMarkdownPdfExporter.ImageSources(const DisplayList: IMarkdownDisplayList): TArray<string>;
begin
  Result := [];
  if DisplayList = nil then
    Exit;

  const Seen = TDictionary<string, Boolean>.Create;
  try
    for var Index := 0 to DisplayList.ItemCount - 1 do
    begin
      var Image: IDisplayImage;
      if not Supports(DisplayList.Items[Index], IDisplayImage, Image) then
        Continue;

      if Seen.ContainsKey(Image.Source) then
        Continue;

      Seen.Add(Image.Source, True);
      Result := Result + [Image.Source];
    end;
  finally
    Seen.Free;
  end;
end;

class procedure TMarkdownPdfExporter.Export(const Markdown: string; const Rasterizer: IMarkdownPdfPageRasterizer;
  const Stream: TStream);
begin
  GuardRasterizer(Rasterizer);

  const DisplayList = BuildLayout(Markdown, Rasterizer.Measurer, Rasterizer);
  const Slices = TMarkdownPagination.Paginate(DisplayList, TMarkdownPdfPageGeometry.LayoutPageHeight);

  const Writer = TMarkdownPdfWriter.Create(Stream);
  try
    for var Slice in Slices do
    begin
      RenderSlice(DisplayList, Slice, Rasterizer, Writer);
    end;

    Writer.Finish;
  finally
    Writer.Free;
  end;
end;

class procedure TMarkdownPdfExporter.ExportWithImages(const Markdown: string;
  const Rasterizer: IMarkdownPdfPageRasterizer; const Stream: TStream; const RequestImages: TProc<TArray<string>>;
  const AreImagesSettled: TFunc<TArray<string>, Boolean>; const Pump: TProc);
begin
  GuardRasterizer(Rasterizer);

  const Layout = BuildLayout(Markdown, Rasterizer.Measurer, nil);
  const Sources = ImageSources(Layout);
  const HasImages = (Length(Sources) > 0);
  if HasImages then
  begin
    RequestImages(Sources);
    TMarkdownExportImageWait.WaitUntil(
      function: Boolean
      begin
        Result := AreImagesSettled(Sources);
      end,
      TMarkdownExportImageWait.DefaultImageTimeoutMilliseconds,
      Pump);
  end;

  Export(Markdown, Rasterizer, Stream);
end;

class procedure TMarkdownPdfExporter.GuardRasterizer(const Rasterizer: IMarkdownPdfPageRasterizer);
begin
  if Rasterizer = nil then
    raise EMarkdownPdfExportError.Create(MissingRasterizerMessage);
end;

class procedure TMarkdownPdfExporter.RenderSlice(const DisplayList: IMarkdownDisplayList;
  const Slice: TMarkdownPageSlice; const Rasterizer: IMarkdownPdfPageRasterizer; const Writer: TMarkdownPdfWriter);
begin
  const PagePainter = Rasterizer.BeginPage(PageBackgroundColor);
  const Factor = TMarkdownPdfPageGeometry.RasterScale * Slice.Scale;
  const ScaledPainter: IPainter = TMarkdownScaledPainter.Create(PagePainter, Slice.Top, Factor);
  const Viewport = TLayoutRectF.Create(0, Slice.Top, TMarkdownPdfPageGeometry.LayoutWidth, Slice.Bottom);

  TMarkdownDisplayListRenderer.Render(DisplayList, ScaledPainter, Viewport, PageBackgroundColor);

  const PageImage = Rasterizer.EndPage;
  Writer.AddPage(PageImage);
end;

end.
