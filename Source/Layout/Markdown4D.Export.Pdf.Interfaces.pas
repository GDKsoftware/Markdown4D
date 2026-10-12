unit Markdown4D.Export.Pdf.Interfaces;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  Markdown4D.Layout.Interfaces;

type
  // One rasterised page: RGB, three bytes per pixel, rows from top to bottom.
  TMarkdownPdfPageImage = record
  public
    const
      BytesPerPixel = 3;
    var
      Width: Integer;
      Height: Integer;
      Pixels: TBytes;
    class function Create(const Width, Height: Integer; const Pixels: TBytes): TMarkdownPdfPageImage; static;
    function ExpectedByteCount: Int64;
  end;

  // The framework side of a PDF export. It measures text for the layout,
  // answers the size of every image it can draw, and paints one page at a time
  // into a bitmap of TMarkdownPdfPageGeometry.RasterWidthPixels by
  // RasterHeightPixels.
  IMarkdownPdfPageRasterizer = interface(IMarkdownImageSizeProvider)
    ['{5B0E8C3A-6F14-4D27-9A61-C2D83E7F4B19}']
    function Measurer: ITextMeasurer;
    function BeginPage(const Background: TLayoutColor): IPainter;
    function EndPage: TMarkdownPdfPageImage;
  end;

implementation

class function TMarkdownPdfPageImage.Create(const Width, Height: Integer; const Pixels: TBytes): TMarkdownPdfPageImage;
begin
  Result.Width := Width;
  Result.Height := Height;
  Result.Pixels := Pixels;
end;

function TMarkdownPdfPageImage.ExpectedByteCount: Int64;
begin
  Result := Int64(Width) * Height * BytesPerPixel;
end;

end.
