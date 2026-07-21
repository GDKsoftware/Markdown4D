unit Markdown4D.Image.Svg;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math;

type
  // A rasterized SVG as a tightly packed, top-down, premultiplied BGRA pixel
  // buffer (stride = Width * 4). This format drops straight into both a VCL
  // 32-bit TBitmap and an FMX TBitmapData without per-pixel conversion.
  TMarkdownSvgRaster = record
    Width: Integer;
    Height: Integer;
    Pixels: TBytes;
  end;

  // Renders SVG bytes into a raster. MaxWidth/MaxHeight are upper bounds in
  // pixels; pass 0 to render at the document's intrinsic size. Returns False
  // when the bytes cannot be rendered.
  TMarkdownSvgRasterizer = reference to function(const Svg: TBytes;
    const MaxWidth, MaxHeight: Single; out Raster: TMarkdownSvgRaster): Boolean;

  // Optional SVG support for the viewers. The core stays dependency-free: a
  // rasterizer engine registers itself here, and the viewers route SVG image
  // bytes through it when one is present.
  TMarkdownSvgSupport = class
  strict private
    class var FRasterizer: TMarkdownSvgRasterizer;
  public
    class procedure RegisterRasterizer(const Rasterizer: TMarkdownSvgRasterizer); static;
    class function IsAvailable: Boolean; static;
    class function LooksLikeSvg(const Data: TBytes): Boolean; static;
    class function TryRasterize(const Svg: TBytes; const MaxWidth, MaxHeight: Single;
      out Raster: TMarkdownSvgRaster): Boolean; static;
  end;

implementation

const
  SvgSniffByteCount = 1024;
  SvgRootTag = '<svg';

class procedure TMarkdownSvgSupport.RegisterRasterizer(const Rasterizer: TMarkdownSvgRasterizer);
begin
  FRasterizer := Rasterizer;
end;

class function TMarkdownSvgSupport.IsAvailable: Boolean;
begin
  Result := Assigned(FRasterizer);
end;

class function TMarkdownSvgSupport.LooksLikeSvg(const Data: TBytes): Boolean;
begin
  const Available = Length(Data);
  if Available = 0 then
    Exit(False);

  const SniffLength = Min(Available, SvgSniffByteCount);
  var Ascii := '';
  SetLength(Ascii, SniffLength);
  for var Index := 0 to SniffLength - 1 do
    Ascii[Index + 1] := Char(Data[Index]);

  Result := Ascii.ToLowerInvariant.Contains(SvgRootTag);
end;

class function TMarkdownSvgSupport.TryRasterize(const Svg: TBytes; const MaxWidth, MaxHeight: Single;
  out Raster: TMarkdownSvgRaster): Boolean;
begin
  Raster := Default(TMarkdownSvgRaster);
  if not Assigned(FRasterizer) then
    Exit(False);

  try
    Result := FRasterizer(Svg, MaxWidth, MaxHeight, Raster);
  except
    Result := False;
  end;

  const HasPixels = (Raster.Width > 0) and (Raster.Height > 0) and
    (Length(Raster.Pixels) >= Raster.Width * Raster.Height * 4);
  Result := Result and HasPixels;
end;

end.
