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
  Markdown4D.Vcl.Painter,
  Markdown4D.Tests.Vcl.BitmapHelpers;

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
    TMarkdownVclTestBitmapHelpers.FillWhite(Bitmap);

    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    Painter.FillPolygon(Triangle, TLayoutColor($FF0000FF));

    Assert.IsTrue(TMarkdownVclTestBitmapHelpers.DistinctColorCount(Bitmap) > 1, 'A filled triangle must paint non-blank pixels');
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
    TMarkdownVclTestBitmapHelpers.FillWhite(Bitmap);

    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    Painter.FillPolygon(Diamond, TLayoutColor($FF00AA00));

    Assert.IsTrue(TMarkdownVclTestBitmapHelpers.DistinctColorCount(Bitmap) > 1, 'A filled diamond must paint non-blank pixels');
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
    TMarkdownVclTestBitmapHelpers.FillWhite(Bitmap);

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
