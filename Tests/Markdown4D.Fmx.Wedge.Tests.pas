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
      StrongChannelFloor = 200;
    class function ReadPixel(const Bitmap: TBitmap; const X, Y: Integer): TAlphaColor;
    class function DistinctColorCount(const Bitmap: TBitmap): Integer;
    class function IsWhite(const Color: TAlphaColor): Boolean;

  public
    [Test]
    procedure FillWedge_ProducesNonBlankPixels;

    [Test]
    procedure FillWedge_OutsideClip_LeavesPixelsUntouched;
  end;

implementation

uses
  System.Generics.Collections,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Fmx.Painter;

class function TMarkdownFmxWedgeTests.ReadPixel(const Bitmap: TBitmap; const X, Y: Integer): TAlphaColor;
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

class function TMarkdownFmxWedgeTests.DistinctColorCount(const Bitmap: TBitmap): Integer;
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

class function TMarkdownFmxWedgeTests.IsWhite(const Color: TAlphaColor): Boolean;
begin
  const Channels = TAlphaColorRec(Color);
  Result := (Channels.R >= StrongChannelFloor) and (Channels.G >= StrongChannelFloor) and
    (Channels.B >= StrongChannelFloor);
end;

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

    Assert.IsTrue(DistinctColorCount(Bitmap) > 1, 'A filled wedge must paint non-blank pixels');
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

    Assert.IsTrue(IsWhite(ReadPixel(Bitmap, ProbeX, ProbeY)),
      'Wedge pixels outside the clip region must remain untouched');
  finally
    Bitmap.Free;
  end;
end;

end.
