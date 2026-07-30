unit Markdown4D.Image.Rasterizer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownPolygonRasterizerTests = class
  private
    const
      RasterWidth = 8;
      RasterHeight = 8;
      OpaqueRed = $FFFF0000;
      OpaqueWhite = $FFFFFFFF;
      TransparentRed = $00FF0000;
      HalfRed = $80FF0000;
      CoverageTolerance = 3;

  public
    [Test]
    procedure Fill_RectangleOnPixelBoundaries_CoversExactlyThosePixels;

    [Test]
    procedure Fill_RectangleEndingMidPixel_CoversThatPixelPartially;

    [Test]
    procedure Fill_Triangle_ProducesPartiallyCoveredEdgePixels;

    [Test]
    procedure Fill_RingWithReversedInnerContour_LeavesTheHoleEmpty;

    [Test]
    procedure Fill_TransparentColour_LeavesTheRasterEmpty;

    [Test]
    procedure Fill_TranslucentColour_ScalesCoverageByAlpha;

    [Test]
    procedure Fill_AnyCoveredPixel_StaysPremultiplied;

    [Test]
    procedure Fill_FewerThanThreePoints_LeavesTheRasterEmpty;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Image.Rasterizer;

function PixelOffset(const Raster: TMarkdownPixelRaster; const X, Y: Integer): Integer;
begin
  Result := (Y * Raster.Width + X) * 4;
end;

function Alpha(const Raster: TMarkdownPixelRaster; const X, Y: Integer): Integer;
begin
  Result := Raster.Pixels[PixelOffset(Raster, X, Y) + 3];
end;

function Rectangle(const Left, Top, Right, Bottom: Single): TArray<TLayoutPointF>;
begin
  Result := [TLayoutPointF.Create(Left, Top), TLayoutPointF.Create(Right, Top),
    TLayoutPointF.Create(Right, Bottom), TLayoutPointF.Create(Left, Bottom)];
end;

procedure TMarkdownPolygonRasterizerTests.Fill_RectangleOnPixelBoundaries_CoversExactlyThosePixels;
begin
  const Raster = TMarkdownPolygonRasterizer.Fill(Rectangle(2, 2, 5, 5), OpaqueRed, RasterWidth, RasterHeight);

  for var Y := 0 to RasterHeight - 1 do
  begin
    for var X := 0 to RasterWidth - 1 do
    begin
      const Inside = (X >= 2) and (X < 5) and (Y >= 2) and (Y < 5);
      var Expected := 0;
      if Inside then
        Expected := 255;

      Assert.AreEqual(Expected, Alpha(Raster, X, Y), Format('Pixel (%d,%d)', [X, Y]));
    end;
  end;
end;

procedure TMarkdownPolygonRasterizerTests.Fill_RectangleEndingMidPixel_CoversThatPixelPartially;
begin
  const Raster = TMarkdownPolygonRasterizer.Fill(Rectangle(1, 1, 3.5, 4), OpaqueRed, RasterWidth, RasterHeight);

  Assert.AreEqual(255, Alpha(Raster, 2, 2), 'A pixel fully inside stays opaque');
  Assert.IsTrue(Abs(Alpha(Raster, 3, 2) - 128) <= CoverageTolerance,
    Format('Half a pixel wide must give about half coverage, got %d', [Alpha(Raster, 3, 2)]));
  Assert.AreEqual(0, Alpha(Raster, 4, 2), 'A pixel beyond the edge stays empty');
end;

procedure TMarkdownPolygonRasterizerTests.Fill_Triangle_ProducesPartiallyCoveredEdgePixels;
begin
  const Triangle: TArray<TLayoutPointF> = [TLayoutPointF.Create(0, 0), TLayoutPointF.Create(8, 0),
    TLayoutPointF.Create(0, 8)];
  const Raster = TMarkdownPolygonRasterizer.Fill(Triangle, OpaqueRed, RasterWidth, RasterHeight);

  var PartialCount := 0;
  for var Y := 0 to RasterHeight - 1 do
  begin
    for var X := 0 to RasterWidth - 1 do
    begin
      const Value = Alpha(Raster, X, Y);
      if (Value > 0) and (Value < 255) then
        Inc(PartialCount);
    end;
  end;

  Assert.IsTrue(PartialCount >= RasterHeight - 1,
    Format('A diagonal edge must leave partially covered pixels, found %d', [PartialCount]));
end;

// The wedge of a doughnut is one contour: the outer arc runs one way and the
// inner arc back the other, so the non-zero rule has to cancel them out.
procedure TMarkdownPolygonRasterizerTests.Fill_RingWithReversedInnerContour_LeavesTheHoleEmpty;
begin
  const Ring: TArray<TLayoutPointF> = [
    TLayoutPointF.Create(0, 0), TLayoutPointF.Create(8, 0), TLayoutPointF.Create(8, 8), TLayoutPointF.Create(0, 8),
    TLayoutPointF.Create(0, 0),
    TLayoutPointF.Create(3, 3), TLayoutPointF.Create(3, 5), TLayoutPointF.Create(5, 5), TLayoutPointF.Create(5, 3),
    TLayoutPointF.Create(3, 3)];
  const Raster = TMarkdownPolygonRasterizer.Fill(Ring, OpaqueRed, RasterWidth, RasterHeight);

  Assert.AreEqual(255, Alpha(Raster, 1, 1), 'The ring itself stays filled');
  Assert.AreEqual(0, Alpha(Raster, 4, 4), 'The reversed inner contour must punch a hole');
end;

procedure TMarkdownPolygonRasterizerTests.Fill_TransparentColour_LeavesTheRasterEmpty;
begin
  const Raster = TMarkdownPolygonRasterizer.Fill(Rectangle(0, 0, 8, 8), TransparentRed, RasterWidth, RasterHeight);

  Assert.AreEqual(0, Alpha(Raster, 4, 4), 'A fully transparent colour draws nothing');
end;

procedure TMarkdownPolygonRasterizerTests.Fill_TranslucentColour_ScalesCoverageByAlpha;
begin
  const Raster = TMarkdownPolygonRasterizer.Fill(Rectangle(0, 0, 8, 8), HalfRed, RasterWidth, RasterHeight);

  Assert.IsTrue(Abs(Alpha(Raster, 4, 4) - 128) <= CoverageTolerance,
    Format('A half transparent fill must land near 128, got %d', [Alpha(Raster, 4, 4)]));
end;

procedure TMarkdownPolygonRasterizerTests.Fill_AnyCoveredPixel_StaysPremultiplied;
begin
  const Raster = TMarkdownPolygonRasterizer.Fill(Rectangle(1, 1, 3.5, 4), OpaqueWhite, RasterWidth, RasterHeight);

  for var Y := 0 to RasterHeight - 1 do
  begin
    for var X := 0 to RasterWidth - 1 do
    begin
      const Offset = PixelOffset(Raster, X, Y);
      const PixelAlpha = Raster.Pixels[Offset + 3];

      for var Channel := 0 to 2 do
      begin
        Assert.IsTrue(Raster.Pixels[Offset + Channel] <= PixelAlpha,
          Format('Channel %d of pixel (%d,%d) exceeds its alpha', [Channel, X, Y]));
      end;
    end;
  end;
end;

procedure TMarkdownPolygonRasterizerTests.Fill_FewerThanThreePoints_LeavesTheRasterEmpty;
begin
  const Line: TArray<TLayoutPointF> = [TLayoutPointF.Create(0, 0), TLayoutPointF.Create(8, 8)];
  const Raster = TMarkdownPolygonRasterizer.Fill(Line, OpaqueRed, RasterWidth, RasterHeight);

  Assert.IsFalse(Raster.IsEmpty, 'The buffer is still allocated');
  Assert.AreEqual(0, Alpha(Raster, 4, 4), 'Two points enclose no area');
end;

end.
