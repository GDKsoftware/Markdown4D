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
  Markdown4D.Fmx.Painter,
  Markdown4D.Tests.Fmx.BitmapHelpers;

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

    Assert.IsTrue(TMarkdownFmxTestBitmapHelpers.DistinctColorCount(Bitmap) > 1, 'A filled triangle must paint non-blank pixels');
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

    Assert.IsTrue(TMarkdownFmxTestBitmapHelpers.DistinctColorCount(Bitmap) > 1, 'A filled diamond must paint non-blank pixels');
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

    const Probe = TMarkdownFmxTestBitmapHelpers.ReadPixel(Bitmap, ProbeX, ProbeY);
    Assert.IsTrue(TMarkdownFmxTestBitmapHelpers.IsWhite(Probe),
      'Polygon pixels outside the clip region must remain untouched');
  finally
    Bitmap.Free;
  end;
end;

end.
