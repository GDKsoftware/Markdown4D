unit Markdown4D.Image.Decoder.Skia;

{$SCOPEDENUMS ON}

// Decodes the image formats an SVG can embed through Skia, which ships with
// RAD Studio and reads PNG, JPEG, WebP and GIF the same way on every platform.
//
// Where the Skia library is missing, registration quietly does nothing and an
// SVG carrying an image is refused rather than drawn without it.

interface

procedure RegisterSkiaImageDecoder;

implementation

{$IFNDEF MSWINDOWS}

uses
  System.SysUtils,
  System.Skia,
  Markdown4D.Image.Rasterizer,
  Markdown4D.Image.Decoder;

function DecodeImage(const Data: TBytes; out Raster: TMarkdownPixelRaster): Boolean;
begin
  Raster := Default(TMarkdownPixelRaster);

  try
    var Image: ISkImage := TSkImage.MakeFromEncoded(Data);
    if Image = nil then
      Exit(False);

    Raster := TMarkdownPixelRaster.Create(Image.Width, Image.Height);
    if Raster.IsEmpty then
      Exit(False);

    // Straight into the shape the rasterizer works in: premultiplied BGRA,
    // packed tightly, top down.
    const Wanted = TSkImageInfo.Create(Image.Width, Image.Height, TSkColorType.BGRA8888,
      TSkAlphaType.Premul);

    Result := Image.ReadPixels(Wanted, @Raster.Pixels[0], NativeUInt(Image.Width) * 4);
  except
    on Exception do
      Result := False;
  end;
end;

procedure RegisterSkiaImageDecoder;
begin
  if TMarkdownImageDecoding.IsAvailable then
    Exit;

  TMarkdownImageDecoding.RegisterDecoder(DecodeImage);
end;

initialization
  RegisterSkiaImageDecoder;

{$ELSE}

// On Windows the font engine and the imaging library of the system already
// answer, and linking Skia here would make every application carry its
// library whether it draws an SVG or not: the Skia objects load it as the
// program starts, not when something is first asked of them.
procedure RegisterSkiaImageDecoder;
begin
end;

{$ENDIF}

end.
