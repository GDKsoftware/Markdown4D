unit Markdown4D.Tests.FakePdfRasterizer;

interface

uses
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Export.Pagination,
  Markdown4D.Export.Pdf.Interfaces;

type
  TFakePdfRasterizer = class(TInterfacedObject, IMarkdownImageSizeProvider, IMarkdownPdfPageRasterizer)
  private
    FMeasurer: ITextMeasurer;
    FPageCount: Integer;
    FBackground: TLayoutColor;

  public
    constructor Create;
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
    function Measurer: ITextMeasurer;
    function RasterizePage(const DisplayList: IMarkdownDisplayList; const Slice: TMarkdownPageSlice;
      const Background: TLayoutColor): TMarkdownPdfPageImage;
    property PageCount: Integer read FPageCount;
    property Background: TLayoutColor read FBackground;
  end;

implementation

uses
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Export.Pdf.Geometry;

constructor TFakePdfRasterizer.Create;
begin
  inherited Create;

  FMeasurer := TFakeTextMeasurer.Create;
end;

function TFakePdfRasterizer.TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
begin
  Size := TLayoutSizeF.Create(0, 0);
  Result := False;
end;

function TFakePdfRasterizer.Measurer: ITextMeasurer;
begin
  Result := FMeasurer;
end;

function TFakePdfRasterizer.RasterizePage(const DisplayList: IMarkdownDisplayList; const Slice: TMarkdownPageSlice;
  const Background: TLayoutColor): TMarkdownPdfPageImage;
begin
  Inc(FPageCount);
  FBackground := Background;
  Result := TMarkdownPdfPageImage.Create(TMarkdownPdfPageGeometry.ContentWidthPixels,
                                         TMarkdownPdfPageGeometry.ContentHeightPixels);
end;

end.
