unit Markdown4D.Fmx.Polygon.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.UITypes,
  FMX.Graphics,
  Markdown4D.Layout.Interfaces;

type
  [TestFixture]
  TMarkdownFmxPolygonTests = class
  private
    const
      BitmapWidth = 200;
      BitmapHeight = 200;
      ClipInside = 40.0;
      ProbeX = 150;
      ProbeY = 20;
      StrongChannelFloor = 200;
    class function ReadPixel(const Bitmap: TBitmap; const X, Y: Integer): TAlphaColor;
    class function DistinctColorCount(const Bitmap: TBitmap): Integer;
    class function IsWhite(const Color: TAlphaColor): Boolean;
    class function Triangle: TArray<TLayoutPointF>;
    class function Diamond: TArray<TLayoutPointF>;

  public
    [Test]
    procedure FillPolygon_Triangle_ProducesNonBlankPixels;

    [Test]
    procedure FillPolygon_Diamond_ProducesNonBlankPixels;

    [Test]
    procedure FillPolygon_OutsideClip_LeavesPixelsUntouched;
  end;

implementation

uses
  System.Generics.Collections,
  Markdown4D.Fmx.Painter;

class function TMarkdownFmxPolygonTests.ReadPixel(const Bitmap: TBitmap; const X, Y: Integer): TAlphaColor;
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

class function TMarkdownFmxPolygonTests.DistinctColorCount(const Bitmap: TBitmap): Integer;
begin
  const Seen = TDictionary<TAlphaColor, Boolean>.Create;
  try
    var Data: TBitmapData;
    if not Bitmap.Map(TMapAccess.Read, Data) then
      Exit(0);

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

class function TMarkdownFmxPolygonTests.IsWhite(const Color: TAlphaColor): Boolean;
begin
  const Channels = TAlphaColorRec(Color);
  Result := (Channels.R >= StrongChannelFloor) and (Channels.G >= StrongChannelFloor) and
    (Channels.B >= StrongChannelFloor);
end;

class function TMarkdownFmxPolygonTests.Triangle: TArray<TLayoutPointF>;
begin
  Result := [TLayoutPointF.Create(100, 20), TLayoutPointF.Create(180, 180), TLayoutPointF.Create(20, 180)];
end;

class function TMarkdownFmxPolygonTests.Diamond: TArray<TLayoutPointF>;
begin
  Result := [TLayoutPointF.Create(100, 20), TLayoutPointF.Create(180, 100), TLayoutPointF.Create(100, 180),
    TLayoutPointF.Create(20, 100)];
end;

procedure TMarkdownFmxPolygonTests.FillPolygon_Triangle_ProducesNonBlankPixels;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.SetSize(BitmapWidth, BitmapHeight);
    Bitmap.Clear(TAlphaColorRec.White);

    var Painter: IPainter := TMarkdownFmxPainter.Create(Bitmap.Canvas);

    Bitmap.Canvas.BeginScene;
    try
      Painter.FillPolygon(Triangle, TLayoutColor($FF0000FF));
    finally
      Bitmap.Canvas.EndScene;
    end;

    Assert.IsTrue(DistinctColorCount(Bitmap) > 1, 'A filled triangle must paint non-blank pixels');
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownFmxPolygonTests.FillPolygon_Diamond_ProducesNonBlankPixels;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.SetSize(BitmapWidth, BitmapHeight);
    Bitmap.Clear(TAlphaColorRec.White);

    var Painter: IPainter := TMarkdownFmxPainter.Create(Bitmap.Canvas);

    Bitmap.Canvas.BeginScene;
    try
      Painter.FillPolygon(Diamond, TLayoutColor($FF00AA00));
    finally
      Bitmap.Canvas.EndScene;
    end;

    Assert.IsTrue(DistinctColorCount(Bitmap) > 1, 'A filled diamond must paint non-blank pixels');
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownFmxPolygonTests.FillPolygon_OutsideClip_LeavesPixelsUntouched;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.SetSize(BitmapWidth, BitmapHeight);
    Bitmap.Clear(TAlphaColorRec.White);

    var Painter: IPainter := TMarkdownFmxPainter.Create(Bitmap.Canvas);

    Bitmap.Canvas.BeginScene;
    try
      Painter.SaveState;
      try
        Painter.SetClip(TLayoutRectF.Create(0, 0, ClipInside, ClipInside));
        Painter.FillPolygon(Triangle, TLayoutColor($FF0000FF));
      finally
        Painter.RestoreState;
      end;
    finally
      Bitmap.Canvas.EndScene;
    end;

    Assert.IsTrue(IsWhite(ReadPixel(Bitmap, ProbeX, ProbeY)),
      'Polygon pixels outside the clip region must remain untouched');
  finally
    Bitmap.Free;
  end;
end;

end.
