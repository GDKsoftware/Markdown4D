unit Markdown4D.Image.Svg.Image32;

{$SCOPEDENUMS ON}

interface

// Registers an Image32-backed SVG rasterizer with the viewer SVG hook. Add this
// unit to a project (the VCL and FMX viewers pull it in automatically) to render
// SVG images such as shields.io badges. Image32 is pure Object Pascal with no
// runtime DLL; it is bundled under ThirdParty/Image32 (Boost Software License).
// The unit self-registers on load; the explicit entry point exists for tests.

procedure RegisterImage32SvgRasterizer;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Math,
  Img32,
  Img32.SVG.Reader,
  Markdown4D.Image.Svg;

function ScaledSize(const Intrinsic: TSize; const MaxWidth, MaxHeight: Single): TSize;
begin
  Result := Intrinsic;

  const ExceedsMaxWidth = (MaxWidth > 0) and (Result.cx > MaxWidth);
  if ExceedsMaxWidth then
  begin
    const Scale = MaxWidth / Result.cx;
    Result.cx := Round(MaxWidth);
    Result.cy := Max(1, Round(Result.cy * Scale));
  end;

  const ExceedsMaxHeight = (MaxHeight > 0) and (Result.cy > MaxHeight);
  if ExceedsMaxHeight then
  begin
    const Scale = MaxHeight / Result.cy;
    Result.cy := Round(MaxHeight);
    Result.cx := Max(1, Round(Result.cx * Scale));
  end;
end;

procedure CopyPremultiplied(const Image: TImage32; out Raster: TMarkdownSvgRaster);
begin
  Raster.Width := Image.Width;
  Raster.Height := Image.Height;
  SetLength(Raster.Pixels, Image.Width * Image.Height * 4);

  const Source = Image.Pixels;
  for var Index := 0 to Length(Source) - 1 do
  begin
    const Argb = TARGB(Source[Index]);
    const Alpha = Argb.A;
    const Base = Index * 4;
    Raster.Pixels[Base + 0] := Byte(Argb.B * Alpha div 255);
    Raster.Pixels[Base + 1] := Byte(Argb.G * Alpha div 255);
    Raster.Pixels[Base + 2] := Byte(Argb.R * Alpha div 255);
    Raster.Pixels[Base + 3] := Alpha;
  end;
end;

function RasterizeSvg(const Svg: TBytes; const MaxWidth, MaxHeight: Single;
  out Raster: TMarkdownSvgRaster): Boolean;
begin
  Raster := Default(TMarkdownSvgRaster);

  const Reader = TSvgReader.Create;
  try
    const Stream = TBytesStream.Create(Svg);
    try
      if not Reader.LoadFromStream(Stream) then
        Exit(False);
    finally
      Stream.Free;
    end;

    const Intrinsic = Reader.GetImageSize;
    const HasIntrinsicSize = (Intrinsic.cx > 0) and (Intrinsic.cy > 0);
    if not HasIntrinsicSize then
      Exit(False);

    const Target = ScaledSize(Intrinsic, MaxWidth, MaxHeight);

    const Image = TImage32.Create(Target.cx, Target.cy);
    try
      Reader.DrawImage(Image, True);
      CopyPremultiplied(Image, Raster);
    finally
      Image.Free;
    end;
  finally
    Reader.Free;
  end;

  Result := True;
end;

procedure RegisterImage32SvgRasterizer;
begin
  TMarkdownSvgSupport.RegisterRasterizer(RasterizeSvg);
end;

initialization
  RegisterImage32SvgRasterizer;

end.
