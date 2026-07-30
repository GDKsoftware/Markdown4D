unit Markdown4D.Image.Decoder;

{$SCOPEDENUMS ON}

// Where encoded image bytes are turned into pixels. Reading a PNG or a JPEG is
// the second thing drawing an SVG needs from the machine it runs on, so it sits
// behind a seam of its own, next to the one glyph outlines come through.

interface

uses
  System.SysUtils,
  Markdown4D.Image.Rasterizer;

type
  TMarkdownImageDecoder = reference to function(const Data: TBytes; out Raster: TMarkdownPixelRaster): Boolean;

  TMarkdownImageDecoding = class
  strict private
    class var FDecoder: TMarkdownImageDecoder;
  public
    class procedure RegisterDecoder(const Decoder: TMarkdownImageDecoder); static;
    class function IsAvailable: Boolean; static;
    class function TryDecode(const Data: TBytes; out Raster: TMarkdownPixelRaster): Boolean; static;
  end;

implementation

class procedure TMarkdownImageDecoding.RegisterDecoder(const Decoder: TMarkdownImageDecoder);
begin
  FDecoder := Decoder;
end;

class function TMarkdownImageDecoding.IsAvailable: Boolean;
begin
  Result := Assigned(FDecoder);
end;

class function TMarkdownImageDecoding.TryDecode(const Data: TBytes; out Raster: TMarkdownPixelRaster): Boolean;
begin
  Raster := Default(TMarkdownPixelRaster);

  if (not Assigned(FDecoder)) or (Length(Data) = 0) then
    Exit(False);

  Result := FDecoder(Data, Raster);
end;

end.
