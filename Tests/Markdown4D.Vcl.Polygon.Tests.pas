unit Markdown4D.Vcl.Polygon.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Vcl.Graphics,
  Markdown4D.Layout.Interfaces;

type
  [TestFixture]
  TMarkdownVclPolygonTests = class
  private
    const
      BitmapWidth = 200;
      BitmapHeight = 200;
      ClipInside = 40.0;
      ProbeX = 150;
      ProbeY = 20;
    class procedure FillWhite(const Bitmap: TBitmap);
    class function DistinctColorCount(const Bitmap: TBitmap): Integer;
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
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
  Markdown4D.Vcl.Painter;

class procedure TMarkdownVclPolygonTests.FillWhite(const Bitmap: TBitmap);
begin
  Bitmap.Canvas.Brush.Style := bsSolid;
  Bitmap.Canvas.Brush.Color := clWhite;
  Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
end;

class function TMarkdownVclPolygonTests.DistinctColorCount(const Bitmap: TBitmap): Integer;
begin
  const Seen = TDictionary<TColor, Boolean>.Create;
  try
    for var Y := 0 to Bitmap.Height - 1 do
    begin
      for var X := 0 to Bitmap.Width - 1 do
      begin
        Seen.AddOrSetValue(Bitmap.Canvas.Pixels[X, Y], True);
      end;
    end;

    Result := Seen.Count;
  finally
    Seen.Free;
  end;
end;

class function TMarkdownVclPolygonTests.Triangle: TArray<TLayoutPointF>;
begin
  Result := [TLayoutPointF.Create(100, 20), TLayoutPointF.Create(180, 180), TLayoutPointF.Create(20, 180)];
end;

class function TMarkdownVclPolygonTests.Diamond: TArray<TLayoutPointF>;
begin
  Result := [TLayoutPointF.Create(100, 20), TLayoutPointF.Create(180, 100), TLayoutPointF.Create(100, 180),
    TLayoutPointF.Create(20, 100)];
end;

procedure TMarkdownVclPolygonTests.FillPolygon_Triangle_ProducesNonBlankPixels;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(BitmapWidth, BitmapHeight);
    FillWhite(Bitmap);

    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    Painter.FillPolygon(Triangle, TLayoutColor($FF0000FF));

    Assert.IsTrue(DistinctColorCount(Bitmap) > 1, 'A filled triangle must paint non-blank pixels');
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclPolygonTests.FillPolygon_Diamond_ProducesNonBlankPixels;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(BitmapWidth, BitmapHeight);
    FillWhite(Bitmap);

    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    Painter.FillPolygon(Diamond, TLayoutColor($FF00AA00));

    Assert.IsTrue(DistinctColorCount(Bitmap) > 1, 'A filled diamond must paint non-blank pixels');
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclPolygonTests.FillPolygon_OutsideClip_LeavesPixelsUntouched;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(BitmapWidth, BitmapHeight);
    FillWhite(Bitmap);

    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    Painter.SaveState;
    try
      Painter.SetClip(TLayoutRectF.Create(0, 0, ClipInside, ClipInside));
      Painter.FillPolygon(Triangle, TLayoutColor($FF0000FF));
    finally
      Painter.RestoreState;
    end;

    Assert.AreEqual(clWhite, Bitmap.Canvas.Pixels[ProbeX, ProbeY],
      'Polygon pixels outside the clip region must remain untouched');
  finally
    Bitmap.Free;
  end;
end;

end.
