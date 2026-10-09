unit Markdown4D.Export.Pdf.Interfaces;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Export.Pagination;

type
  // One rasterized page: RGB, three bytes per pixel, row by row from the top.
  TMarkdownPdfPageImage = record
    Width: Integer;
    Height: Integer;
    Pixels: TBytes;
    class function Create(const Width, Height: Integer): TMarkdownPdfPageImage; static;
  end;

  // What a framework supplies to export a document: the measurer the layout
  // uses and a canvas to paint one page on. TryGetImageSize answers the
  // natural size of an image the viewer has loaded, and False for one that is
  // still loading or failed, which then lays out as a placeholder.
  IMarkdownPdfPageRasterizer = interface(IMarkdownImageSizeProvider)
    ['{6B1E3F2A-9C47-4D85-A0E6-3F7B2C91D548}']
    function Measurer: ITextMeasurer;
    function RasterizePage(const DisplayList: IMarkdownDisplayList; const Slice: TMarkdownPageSlice;
      const Background: TLayoutColor): TMarkdownPdfPageImage;
  end;

implementation

class function TMarkdownPdfPageImage.Create(const Width, Height: Integer): TMarkdownPdfPageImage;
const
  BytesPerPixel = 3;
begin
  Result.Width := Width;
  Result.Height := Height;
  SetLength(Result.Pixels, Width * Height * BytesPerPixel);
end;

end.
