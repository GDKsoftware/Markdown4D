unit Markdown4D.Tests.Fmx.BitmapHelpers;

interface

uses
  FMX.Graphics,
  System.UITypes;

type
  TMarkdownFmxTestBitmapHelpers = class
  private
    const
      StrongChannelFloor = 200;

  public
    class function ReadPixel(const Bitmap: TBitmap; const X, Y: Integer): TAlphaColor;
    class function DistinctColorCount(const Bitmap: TBitmap): Integer;
    class function IsWhite(const Color: TAlphaColor): Boolean;
    class procedure FillWhite(const Bitmap: TBitmap);
  end;

implementation

uses
  System.Generics.Collections;

class function TMarkdownFmxTestBitmapHelpers.ReadPixel(const Bitmap: TBitmap; const X, Y: Integer): TAlphaColor;
begin
  Result := TAlphaColorRec.Null;

  var Data: TBitmapData;
  if not Bitmap.Map(TMapAccess.Read, Data) then
    Exit;

  try
    Result := Data.GetPixel(X, Y);
  finally
    Bitmap.Unmap(Data);
  end;
end;

class function TMarkdownFmxTestBitmapHelpers.DistinctColorCount(const Bitmap: TBitmap): Integer;
begin
  const Seen = TDictionary<TAlphaColor, Boolean>.Create;
  try
    var Data: TBitmapData;
    if not Bitmap.Map(TMapAccess.Read, Data) then
    begin
      Result := 0;
      Exit;
    end;

    try
      for var Y := 0 to Bitmap.Height - 1 do
      begin
        for var X := 0 to Bitmap.Width - 1 do
        begin
          Seen.AddOrSetValue(Data.GetPixel(X, Y), True);
        end;
      end;
    finally
      Bitmap.Unmap(Data);
    end;

    Result := Seen.Count;
  finally
    Seen.Free;
  end;
end;

class function TMarkdownFmxTestBitmapHelpers.IsWhite(const Color: TAlphaColor): Boolean;
begin
  const Channels = TAlphaColorRec(Color);
  Result := (Channels.R >= StrongChannelFloor) and (Channels.G >= StrongChannelFloor) and
    (Channels.B >= StrongChannelFloor);
end;

class procedure TMarkdownFmxTestBitmapHelpers.FillWhite(const Bitmap: TBitmap);
begin
  Bitmap.Clear(TAlphaColorRec.White);
end;

end.
