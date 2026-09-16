unit Markdown4D.Tests.Vcl.BitmapHelpers;

interface

uses
  System.Types,
  Vcl.Graphics;

type
  TMarkdownVclTestBitmapHelpers = class
  public
    class procedure FillWhite(const Bitmap: TBitmap);
    class function DistinctColorCount(const Bitmap: TBitmap): Integer;
  end;

implementation

uses
  System.Generics.Collections;

class procedure TMarkdownVclTestBitmapHelpers.FillWhite(const Bitmap: TBitmap);
begin
  Bitmap.Canvas.Brush.Style := bsSolid;
  Bitmap.Canvas.Brush.Color := clWhite;
  Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
end;

class function TMarkdownVclTestBitmapHelpers.DistinctColorCount(const Bitmap: TBitmap): Integer;
begin
  const Seen = TDictionary<TColor, Boolean>.Create;
  try
    for var YIndex := 0 to Bitmap.Height - 1 do
    begin
      for var XIndex := 0 to Bitmap.Width - 1 do
      begin
        Seen.AddOrSetValue(Bitmap.Canvas.Pixels[XIndex, YIndex], True);
      end;
    end;

    Result := Seen.Count;
  finally
    Seen.Free;
  end;
end;

end.
