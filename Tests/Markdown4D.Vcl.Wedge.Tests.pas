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

  public
    [Test]
    procedure FillWedge_ProducesNonBlankPixels;

    [Test]
    procedure FillWedge_OutsideClip_LeavesPixelsUntouched;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Vcl.Painter,
  Markdown4D.Tests.Vcl.BitmapHelpers;

procedure TMarkdownVclWedgeTests.FillWedge_ProducesNonBlankPixels;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(BitmapWidth, BitmapHeight);
    TMarkdownVclTestBitmapHelpers.FillWhite(Bitmap);

    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    Painter.FillWedge(TLayoutPointF.Create(CenterX, CenterY), OuterRadius, InnerRadius, StartAngle, SweepAngle,
      TLayoutColor($FF0000FF));

    Assert.IsTrue(TMarkdownVclTestBitmapHelpers.DistinctColorCount(Bitmap) > 1, 'A filled wedge must paint non-blank pixels');
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
    TMarkdownVclTestBitmapHelpers.FillWhite(Bitmap);

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
