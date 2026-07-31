unit Markdown4D.Vcl.ImageDecoder;

{$SCOPEDENUMS ON}

// Decodes the images an SVG embeds with the picture classes the VCL already
// carries, so a Windows application needs nothing beside it. The unit
// registers itself; the viewer pulls it in.

interface

procedure RegisterVclImageDecoder;

implementation

uses
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  Vcl.Imaging.jpeg,
  Markdown4D.Image.Rasterizer,
  Markdown4D.Image.Decoder;

type
  TVclImageDecoder = class
  public
    class function TryDecode(const Data: TBytes; out Raster: TMarkdownPixelRaster): Boolean; static;
  end;

// Draws the picture onto a 32 bit bitmap with its alpha kept, which is the
// shape the rasterizer composites in.
class function TVclImageDecoder.TryDecode(const Data: TBytes; out Raster: TMarkdownPixelRaster): Boolean;
begin
  Raster := Default(TMarkdownPixelRaster);

  try
    const Stream = TBytesStream.Create(Data);
    try
      const Picture = TPicture.Create;
      try
        Picture.LoadFromStream(Stream);

        const Bitmap = TBitmap.Create;
        try
          Bitmap.PixelFormat := pf32bit;
          Bitmap.AlphaFormat := afDefined;
          Bitmap.SetSize(Picture.Width, Picture.Height);
          Bitmap.Canvas.Draw(0, 0, Picture.Graphic);

          Raster := TMarkdownPixelRaster.Create(Bitmap.Width, Bitmap.Height);
          if Raster.IsEmpty then
            Exit(False);

          for var Y := 0 to Bitmap.Height - 1 do
          begin
            const Row: PByte = Bitmap.ScanLine[Y];
            Move(Row^, Raster.Pixels[Y * Bitmap.Width * 4], Bitmap.Width * 4);
          end;

          Result := True;
        finally
          Bitmap.Free;
        end;
      finally
        Picture.Free;
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

procedure RegisterVclImageDecoder;
begin
  if TMarkdownImageDecoding.IsAvailable then
    Exit;

  TMarkdownImageDecoding.RegisterDecoder(TVclImageDecoder.TryDecode);
end;

initialization
  RegisterVclImageDecoder;

end.
