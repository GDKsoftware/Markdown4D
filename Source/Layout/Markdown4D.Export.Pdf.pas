unit Markdown4D.Export.Pdf;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Export.Pdf.Interfaces;

type
  // Turns a markdown document into an A4 PDF. The document is laid out in the
  // built-in light theme at 100 %, scaled to the raster resolution, whatever
  // theme or zoom the viewer shows; a framework paints the pages.
  TMarkdownPdfExporter = class
  private
    const
      MissingRasterizerMessage = 'A PDF export needs a page rasterizer';
      MissingStreamMessage = 'A PDF export needs a stream to write to';
    class procedure GuardRasterizer(const Rasterizer: IMarkdownPdfPageRasterizer); static;
    class procedure GuardStream(const Stream: TStream); static;
    class function CreateExportTheme: TMarkdownTheme; static;
    class function LayoutDocument(const Markdown: string; const Theme: TMarkdownTheme; const Measurer: ITextMeasurer;
      const ImageSizes: IMarkdownImageSizeProvider;
      const ExtensionErrors: IMarkdownExtensionErrorSink): IMarkdownDisplayList; static;
    class procedure WritePages(const DisplayList: IMarkdownDisplayList; const Rasterizer: IMarkdownPdfPageRasterizer;
      const Background: TLayoutColor; const Stream: TStream); static;

  public
    // The display list the PDF shows: the content width of the page in pixels
    // at the raster resolution, without padding around the content. ImageSizes
    // answers natural sizes; they are scaled along with the text.
    class function BuildLayout(const Markdown: string; const Measurer: ITextMeasurer;
      const ImageSizes: IMarkdownImageSizeProvider): IMarkdownDisplayList; static;
    // Writes the PDF from the current position of Stream. ExtensionErrors hears
    // of a block override or document processor that failed, as the viewer
    // does; without one such a failure raises.
    class procedure Export(const Markdown: string; const Rasterizer: IMarkdownPdfPageRasterizer;
      const Stream: TStream; const ExtensionErrors: IMarkdownExtensionErrorSink = nil); static;
  end;

implementation

uses
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Layout.Engine,
  Markdown4D.Export.Pagination,
  Markdown4D.Export.Pdf.Errors,
  Markdown4D.Export.Pdf.Geometry,
  Markdown4D.Export.Pdf.ScaledImageSizes,
  Markdown4D.Export.Pdf.Writer;

class function TMarkdownPdfExporter.BuildLayout(const Markdown: string; const Measurer: ITextMeasurer;
  const ImageSizes: IMarkdownImageSizeProvider): IMarkdownDisplayList;
begin
  const Theme = CreateExportTheme;
  try
    Result := LayoutDocument(Markdown, Theme, Measurer, ImageSizes, nil);
  finally
    Theme.Free;
  end;
end;

class procedure TMarkdownPdfExporter.Export(const Markdown: string; const Rasterizer: IMarkdownPdfPageRasterizer;
  const Stream: TStream; const ExtensionErrors: IMarkdownExtensionErrorSink);
begin
  GuardRasterizer(Rasterizer);
  GuardStream(Stream);

  const Theme = CreateExportTheme;
  try
    const DisplayList = LayoutDocument(Markdown, Theme, Rasterizer.Measurer, Rasterizer, ExtensionErrors);
    WritePages(DisplayList, Rasterizer, Theme.BackgroundColor, Stream);
  finally
    Theme.Free;
  end;
end;

class procedure TMarkdownPdfExporter.GuardRasterizer(const Rasterizer: IMarkdownPdfPageRasterizer);
begin
  const IsMissing = (Rasterizer = nil);
  if IsMissing then
    raise EMarkdownPdfExportError.Create(MissingRasterizerMessage);
end;

class procedure TMarkdownPdfExporter.GuardStream(const Stream: TStream);
begin
  const IsMissing = (Stream = nil);
  if IsMissing then
    raise EMarkdownPdfExportError.Create(MissingStreamMessage);
end;

// Paper is the same whatever the screen shows: the preset, not the host's
// theme, and the page carries no padding of its own besides its margins.
class function TMarkdownPdfExporter.CreateExportTheme: TMarkdownTheme;
begin
  const Light = TMarkdownTheme.CreateLight;
  try
    Result := Light.Scaled(TMarkdownPdfPageGeometry.LayoutScale);
  finally
    Light.Free;
  end;

  Result.ContentPadding := 0;
end;

class function TMarkdownPdfExporter.LayoutDocument(const Markdown: string; const Theme: TMarkdownTheme;
  const Measurer: ITextMeasurer; const ImageSizes: IMarkdownImageSizeProvider;
  const ExtensionErrors: IMarkdownExtensionErrorSink): IMarkdownDisplayList;
begin
  const Document = TMarkdown.Parse(Markdown, TMarkdownDialect.Gfm);
  TLayoutDocumentProcessorRegistry.Process(Document, ExtensionErrors);

  const ScaledSizes: IMarkdownImageSizeProvider = TMarkdownPdfScaledImageSizes.Create(ImageSizes,
                                                                                     TMarkdownPdfPageGeometry.LayoutScale);
  Result := TMarkdownLayoutEngine.LayoutDocument(Document, TMarkdownPdfPageGeometry.ContentWidthPixels, Theme,
                                                 Measurer, ScaledSizes, ExtensionErrors);
end;

class procedure TMarkdownPdfExporter.WritePages(const DisplayList: IMarkdownDisplayList;
  const Rasterizer: IMarkdownPdfPageRasterizer; const Background: TLayoutColor; const Stream: TStream);
begin
  const Slices = TMarkdownPagination.Paginate(DisplayList, TMarkdownPdfPageGeometry.ContentHeightPixels);

  const Writer = TMarkdownPdfWriter.Create(Stream);
  try
    for var Slice in Slices do
    begin
      Writer.AddPage(Rasterizer.RasterizePage(DisplayList, Slice, Background));
    end;

    Writer.Finish;
  finally
    Writer.Free;
  end;
end;

end.
