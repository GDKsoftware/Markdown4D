unit Markdown4D.Fmx.Wedge.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.UITypes,
  FMX.Graphics;

type
  [TestFixture]
  TMarkdownFmxWedgeTests = class
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
  Markdown4D.Layout.Interfaces,
  Markdown4D.Fmx.Painter,
  Markdown4D.Tests.Fmx.BitmapHelpers;

procedure TMarkdownFmxWedgeTests.FillWedge_ProducesNonBlankPixels;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.SetSize(BitmapWidth, BitmapHeight);
    Bitmap.Clear(TAlphaColorRec.White);

    var Painter: IPainter := TMarkdownFmxPainter.Create(Bitmap.Canvas);

    Bitmap.Canvas.BeginScene;
    try
      Painter.FillWedge(TLayoutPointF.Create(CenterX, CenterY), OuterRadius, InnerRadius, StartAngle, SweepAngle,
        TLayoutColor($FF0000FF));
    finally
      Bitmap.Canvas.EndScene;
    end;

    Assert.IsTrue(TMarkdownFmxTestBitmapHelpers.DistinctColorCount(Bitmap) > 1, 'A filled wedge must paint non-blank pixels');
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownFmxWedgeTests.FillWedge_OutsideClip_LeavesPixelsUntouched;
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
        Painter.FillWedge(TLayoutPointF.Create(CenterX, CenterY), OuterRadius, InnerRadius, StartAngle, SweepAngle,
          TLayoutColor($FF0000FF));
      finally
        Painter.RestoreState;
      end;
    finally
      Bitmap.Canvas.EndScene;
    end;

    const Probe = TMarkdownFmxTestBitmapHelpers.ReadPixel(Bitmap, ProbeX, ProbeY);
    Assert.IsTrue(TMarkdownFmxTestBitmapHelpers.IsWhite(Probe),
      'Wedge pixels outside the clip region must remain untouched');
  finally
    Bitmap.Free;
  end;
end;

end.
