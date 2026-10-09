unit Markdown4D.Export.Pdf.Geometry;

{$SCOPEDENUMS ON}

interface

type
  // An A4 page with a margin of 2 cm all round. The content area is 170 by
  // 257 mm, rasterized at RasterDpi; PDF measures in points of 1/72 inch.
  TMarkdownPdfPageGeometry = record
  public
    const
      PageWidthPoints = 595.28;
      PageHeightPoints = 841.89;
      MarginPoints = 56.69;
      ContentWidthPoints = 481.89;
      ContentHeightPoints = 728.50;
      RasterDpi = 200;
      ContentWidthPixels = 1339;
      ContentHeightPixels = 2024;
    // How much larger than on screen the document is laid out, so a font of
    // 16 pixels at 96 dpi keeps its physical size on paper.
    class function LayoutScale: Single; static;
  end;

implementation

uses
  Markdown4D.Layout.Defaults;

class function TMarkdownPdfPageGeometry.LayoutScale: Single;
begin
  Result := RasterDpi / ReferencePixelsPerInch;
end;

end.
