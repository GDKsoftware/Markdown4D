unit Markdown4D.Fmx.ImageDecoder;

{$SCOPEDENUMS ON}

// Decodes the images an SVG embeds with the bitmap FMX already carries, which
// reads what the platform underneath it reads. The unit registers itself; the
// viewer pulls it in.

interface

procedure RegisterFmxImageDecoder;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  FMX.Graphics,
  FMX.Types,
  Markdown4D.Image.Rasterizer,
  Markdown4D.Image.Decoder;

type
  TFmxImageDecoder = class
  public
    class function TryDecode(const Data: TBytes; out Raster: TMarkdownPixelRaster): Boolean; static;
  end;

class function TFmxImageDecoder.TryDecode(const Data: TBytes; out Raster: TMarkdownPixelRaster): Boolean;
begin
  Raster := Default(TMarkdownPixelRaster);

  try
    const Stream = TBytesStream.Create(Data);
    try
      const Bitmap = TBitmap.Create;
      try
        Bitmap.LoadFromStream(Stream);
        if Bitmap.IsEmpty then
          Exit(False);

        Raster := TMarkdownPixelRaster.Create(Bitmap.Width, Bitmap.Height);
        if Raster.IsEmpty then
          Exit(False);

        var Pixels: TBitmapData;
        if not Bitmap.Map(TMapAccess.Read, Pixels) then
          Exit(False);

        try
          // FMX keeps a bitmap premultiplied, which is the shape the rasterizer
          // composites in, so the rows move across as they are.
          const RowBytes = Bitmap.Width * 4;
          for var Y := 0 to Bitmap.Height - 1 do
          begin
            Move(Pixels.GetScanline(Y)^, Raster.Pixels[Y * RowBytes], RowBytes);
          end;
        finally
          Bitmap.Unmap(Pixels);
        end;

        Result := True;
      finally
        Bitmap.Free;
      end;
    finally
      Stream.Free;
    end;
  except
    // Bytes out of a document are an outside boundary: what cannot be read is
    // one image that does not appear.
    on Exception do
      Result := False;
  end;
end;

procedure RegisterFmxImageDecoder;
begin
  if TMarkdownImageDecoding.IsAvailable then
    Exit;

  TMarkdownImageDecoding.RegisterDecoder(TFmxImageDecoder.TryDecode);
end;

initialization
  RegisterFmxImageDecoder;

end.
