unit Markdown4D.Export.Pdf.Geometry;

{$SCOPEDENUMS ON}

// The page a PDF export prints on: A4 with 2 cm margins, rasterised at 200 dpi.
// The document is laid out at the reference resolution of the preview, so the
// layout width and the page height follow from the raster size.

interface

uses
  Markdown4D.Layout.Defaults;

type
  TMarkdownPdfPageGeometry = record
  public
    const
      PointsPerInch = 72.0;
      PageWidthPoints = 595.28;
      PageHeightPoints = 841.89;
      MarginPoints = 56.69;
      ContentWidthPoints = PageWidthPoints - (2 * MarginPoints);
      ContentHeightPoints = PageHeightPoints - (2 * MarginPoints);
      RasterDpi = 200;
      // ContentWidthPoints and ContentHeightPoints at RasterDpi, rounded.
      RasterWidthPixels = 1339;
      RasterHeightPixels = 2024;
      // MarginPoints at RasterDpi, rounded.
      MarginPixels = 157;
      RasterScale =RasterDpi / ReferencePixelsPerInch;
      LayoutWidth = RasterWidthPixels / RasterScale;
      LayoutPageHeight = RasterHeightPixels / RasterScale;
  end;

implementation

end.
