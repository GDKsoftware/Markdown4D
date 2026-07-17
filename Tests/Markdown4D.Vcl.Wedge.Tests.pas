unit Markdown4D.Vcl.Wedge.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Vcl.Graphics;

type
  [TestFixture]
  TMarkdownVclWedgeTests = class
  private
    const
      BitmapWidth = 200;
      BitmapHeight = 200;
      CenterX = 100.0;
      CenterY = 100.0;
      OuterRadius = 80.0;
      InnerRadius = 30.0;
      StartAngle = 0.0;
      SweepAngle = 90.0;
      ClipInside = 40.0;
      ProbeX = 150;
      ProbeY = 20;
    class procedure FillWhite(const Bitmap: TBitmap);
    class function DistinctColorCount(const Bitmap: TBitmap): Integer;

  public
    [Test]
    procedure FillWedge_ProducesNonBlankPixels;

    [Test]
    procedure FillWedge_OutsideClip_LeavesPixelsUntouched;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Vcl.Painter;

class procedure TMarkdownVclWedgeTests.FillWhite(const Bitmap: TBitmap);
begin
  Bitmap.Canvas.Brush.Style := bsSolid;
  Bitmap.Canvas.Brush.Color := clWhite;
  Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
end;

class function TMarkdownVclWedgeTests.DistinctColorCount(const Bitmap: TBitmap): Integer;
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

procedure TMarkdownVclWedgeTests.FillWedge_ProducesNonBlankPixels;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(BitmapWidth, BitmapHeight);
    FillWhite(Bitmap);

    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    Painter.FillWedge(TLayoutPointF.Create(CenterX, CenterY), OuterRadius, InnerRadius, StartAngle, SweepAngle,
      TLayoutColor($FF0000FF));

    Assert.IsTrue(DistinctColorCount(Bitmap) > 1, 'A filled wedge must paint non-blank pixels');
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclWedgeTests.FillWedge_OutsideClip_LeavesPixelsUntouched;
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
      Painter.FillWedge(TLayoutPointF.Create(CenterX, CenterY), OuterRadius, InnerRadius, StartAngle, SweepAngle,
        TLayoutColor($FF0000FF));
    finally
      Painter.RestoreState;
    end;

    Assert.AreEqual(clWhite, Bitmap.Canvas.Pixels[ProbeX, ProbeY],
      'Wedge pixels outside the clip region must remain untouched');
  finally
    Bitmap.Free;
  end;
end;

end.
