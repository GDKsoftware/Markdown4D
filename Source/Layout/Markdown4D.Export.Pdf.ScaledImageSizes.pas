unit Markdown4D.Export.Pdf.ScaledImageSizes;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Layout.Interfaces;

type
  // Grows the natural size of every image by Factor, the way the viewer grows
  // it with its zoom, so an image keeps its size next to the text around it.
  TMarkdownPdfScaledImageSizes = class(TInterfacedObject, IMarkdownImageSizeProvider)
  private
    FInner: IMarkdownImageSizeProvider;
    FFactor: Single;

  public
    constructor Create(const Inner: IMarkdownImageSizeProvider; const Factor: Single);
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
  end;

implementation

constructor TMarkdownPdfScaledImageSizes.Create(const Inner: IMarkdownImageSizeProvider; const Factor: Single);
begin
  inherited Create;

  FInner := Inner;
  FFactor := Factor;
end;

function TMarkdownPdfScaledImageSizes.TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
begin
  Size := TLayoutSizeF.Create(0, 0);

  const HasInner = (FInner <> nil);
  if not HasInner then
  begin
    Result := False;
    Exit;
  end;

  var NaturalSize: TLayoutSizeF;
  Result := FInner.TryGetImageSize(Source, NaturalSize);
  if Result then
    Size := TLayoutSizeF.Create(NaturalSize.Width * FFactor, NaturalSize.Height * FFactor);
end;

end.
