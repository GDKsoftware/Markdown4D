unit Markdown4D.Image.Rasterizer;

{$SCOPEDENUMS ON}

// Fills a polygon with anti-aliased edges into a pixel buffer, so a painter on
// a canvas without anti-aliasing of its own can still draw smooth shapes such
// as pie and doughnut wedges.
//
// Coverage is exact horizontally and sampled vertically: every pixel row is cut
// into sub-scanlines, each sub-scanline is intersected with the polygon edges,
// and the resulting spans add their exact horizontal overlap to the pixels they
// touch. That keeps a near-horizontal edge as smooth as a near-vertical one
// without the cost of sampling in both directions.

interface

uses
  System.SysUtils,
  Markdown4D.Layout.Interfaces;

type
  TMarkdownFillRule = (NonZero, EvenOdd);

  TMarkdownPaintKind = (Solid, LinearGradient, RadialGradient, Tile);

  TMarkdownGradientStop = record
    Offset: Single;
    Color: TLayoutColor;
  end;

  // What a shape is filled with: one colour, or a colour that varies with the
  // position of the pixel. The geometry is in the same space as the contours,
  // so the caller transforms it before handing it over.
  TMarkdownPaint = record
    Kind: TMarkdownPaintKind;
    Color: TLayoutColor;
    StartPoint: TLayoutPointF;
    StopPoint: TLayoutPointF;
    Radius: Single;
    Stops: TArray<TMarkdownGradientStop>;
    // A tile is repeated from its origin in both directions, which is what a
    // pattern fill is.
    TilePixels: TBytes;
    TileWidth: Integer;
    TileHeight: Integer;
    class function SolidColor(const Color: TLayoutColor): TMarkdownPaint; static;
    class function Linear(const StartPoint, StopPoint: TLayoutPointF;
      const Stops: TArray<TMarkdownGradientStop>): TMarkdownPaint; static;
    class function Radial(const Centre: TLayoutPointF; const Radius: Single;
      const Stops: TArray<TMarkdownGradientStop>): TMarkdownPaint; static;
    class function Tiled(const Origin: TLayoutPointF; const Width, Height: Integer;
      const Pixels: TBytes): TMarkdownPaint; static;
    function ColorAt(const X, Y: Single): TLayoutColor;
  end;

  // Per-pixel coverage a fill is multiplied by, so a shape can be held inside
  // another one. Empty means no clipping.
  TMarkdownClipMask = TArray<Byte>;

  // A tightly packed, top-down, premultiplied BGRA buffer (stride = Width * 4),
  // the same shape the SVG rasterizer produces, so both drop into a VCL or FMX
  // bitmap without a per-pixel conversion.
  TMarkdownPixelRaster = record
    Width: Integer;
    Height: Integer;
    Pixels: TBytes;
    class function Create(const Width, Height: Integer): TMarkdownPixelRaster; static;
    function IsEmpty: Boolean;
  end;

  TMarkdownPolygonRasterizer = class
  private
    const
      // Sub-scanlines per pixel row. Four steps of coverage in the vertical
      // direction is where the eye stops seeing a staircase on an arc.
      SubScanlines = 4;
      BytesPerPixel = 4;
      FullCoverage = 1.0;
      OpaqueAlpha = 255;
    type
      TEdgeCrossing = record
        X: Single;
        Direction: Integer;
      end;
      // Counts its way along a scanline and says, at each gap between two
      // crossings, whether that gap lies inside the shape.
      TWindingCounter = record
        Total: Integer;
        function Accepts(const Crossing: TEdgeCrossing; const Rule: TMarkdownFillRule): Boolean;
      end;
    class function CollectCrossings(const Contours: TArray<TArray<TLayoutPointF>>; const SampleY: Single;
      var Crossings: TArray<TEdgeCrossing>): Integer; static;
    class function CrossingCapacity(const Contours: TArray<TArray<TLayoutPointF>>): Integer; static;
    class procedure SortCrossings(var Crossings: TArray<TEdgeCrossing>; const Count: Integer); static;
    class procedure AddSpan(var Coverage: TArray<Single>; const Left, Right, Weight: Single); static;

  public
    // Fills into a fresh buffer of the given size.
    class function Fill(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor;
      const Width, Height: Integer;
      const Rule: TMarkdownFillRule = TMarkdownFillRule.NonZero): TMarkdownPixelRaster; static;
    // Composites onto what the buffer already holds, so a drawing built from
    // many shapes ends up as one image with its overlaps blended.
    class procedure FillInto(var Raster: TMarkdownPixelRaster; const Points: TArray<TLayoutPointF>;
      const Color: TLayoutColor; const Rule: TMarkdownFillRule = TMarkdownFillRule.NonZero); static;
    // Fills several contours as one shape, which is how a ring, a letter with a
    // counter, or a stroke built from many pieces stays a single figure: the
    // fill rule decides between them, and an overlap is covered once.
    class procedure FillContoursInto(var Raster: TMarkdownPixelRaster;
      const Contours: TArray<TArray<TLayoutPointF>>; const Color: TLayoutColor;
      const Rule: TMarkdownFillRule = TMarkdownFillRule.NonZero); static;
    // The full form: any paint, and an optional mask the coverage is held to.
    class procedure FillPaintedContoursInto(var Raster: TMarkdownPixelRaster;
      const Contours: TArray<TArray<TLayoutPointF>>; const Paint: TMarkdownPaint;
      const Rule: TMarkdownFillRule; const Mask: TMarkdownClipMask); static;
    // Coverage of the contours on their own, for use as a mask.
    class function CoverageOf(const Contours: TArray<TArray<TLayoutPointF>>;
      const Width, Height: Integer; const Rule: TMarkdownFillRule): TMarkdownClipMask; static;
  end;

implementation

uses
  System.Math;

class function TMarkdownPaint.SolidColor(const Color: TLayoutColor): TMarkdownPaint;
begin
  Result := Default(TMarkdownPaint);
  Result.Kind := TMarkdownPaintKind.Solid;
  Result.Color := Color;
end;

class function TMarkdownPaint.Linear(const StartPoint, StopPoint: TLayoutPointF;
  const Stops: TArray<TMarkdownGradientStop>): TMarkdownPaint;
begin
  Result := Default(TMarkdownPaint);
  Result.Kind := TMarkdownPaintKind.LinearGradient;
  Result.StartPoint := StartPoint;
  Result.StopPoint := StopPoint;
  Result.Stops := Stops;
end;

class function TMarkdownPaint.Radial(const Centre: TLayoutPointF; const Radius: Single;
  const Stops: TArray<TMarkdownGradientStop>): TMarkdownPaint;
begin
  Result := Default(TMarkdownPaint);
  Result.Kind := TMarkdownPaintKind.RadialGradient;
  Result.StartPoint := Centre;
  Result.Radius := Radius;
  Result.Stops := Stops;
end;

class function TMarkdownPaint.Tiled(const Origin: TLayoutPointF; const Width, Height: Integer;
  const Pixels: TBytes): TMarkdownPaint;
begin
  Result := Default(TMarkdownPaint);
  Result.Kind := TMarkdownPaintKind.Tile;
  Result.StartPoint := Origin;
  Result.TileWidth := Width;
  Result.TileHeight := Height;
  Result.TilePixels := Pixels;
end;

// Where the pixel falls along the gradient, and the colour the stops give at
// that distance. Beyond either end the nearest stop simply carries on.
function TMarkdownPaint.ColorAt(const X, Y: Single): TLayoutColor;
begin
  if Kind = TMarkdownPaintKind.Tile then
  begin
    if (TileWidth <= 0) or (TileHeight <= 0) then
      Exit(0);

    var Column := Trunc(X - StartPoint.X) mod TileWidth;
    if Column < 0 then
      Column := Column + TileWidth;
    var Row := Trunc(Y - StartPoint.Y) mod TileHeight;
    if Row < 0 then
      Row := Row + TileHeight;

    const Offset = (Row * TileWidth + Column) * 4;
    const Alpha = TilePixels[Offset + 3];
    if Alpha = 0 then
      Exit(0);

    // The tile is premultiplied and a paint hands back plain colours, so the
    // coverage baked into the channels is taken back out here.
    const Scale = 255 / Alpha;

    Exit(TLayoutColor((Cardinal(Alpha) shl 24) or
      (Cardinal(Min(255, Round(TilePixels[Offset + 2] * Scale))) shl 16) or
      (Cardinal(Min(255, Round(TilePixels[Offset + 1] * Scale))) shl 8) or
      Cardinal(Min(255, Round(TilePixels[Offset] * Scale)))));
  end;

  if (Kind = TMarkdownPaintKind.Solid) or (Length(Stops) = 0) then
    Exit(Color);

  var Position: Single := 0;

  if Kind = TMarkdownPaintKind.LinearGradient then
  begin
    const AxisX = StopPoint.X - StartPoint.X;
    const AxisY = StopPoint.Y - StartPoint.Y;
    const Squared = AxisX * AxisX + AxisY * AxisY;
    if Squared > 0 then
      Position := ((X - StartPoint.X) * AxisX + (Y - StartPoint.Y) * AxisY) / Squared;
  end
  else if Radius > 0 then
    Position := Sqrt(Sqr(X - StartPoint.X) + Sqr(Y - StartPoint.Y)) / Radius;

  if Position <= Stops[0].Offset then
    Exit(Stops[0].Color);

  const Last = High(Stops);
  if Position >= Stops[Last].Offset then
    Exit(Stops[Last].Color);

  for var Index := 1 to Last do
  begin
    if Position > Stops[Index].Offset then
      Continue;

    const Span = Stops[Index].Offset - Stops[Index - 1].Offset;
    var Ratio: Single := 0;
    if Span > 0 then
      Ratio := (Position - Stops[Index - 1].Offset) / Span;

    const From = Stops[Index - 1].Color;
    const Onto = Stops[Index].Color;

    var Blended: Cardinal := 0;
    for var Shift := 0 to 3 do
    begin
      const Bits = Shift * 8;
      // Signed, because one channel darkening towards the next stop is a
      // negative step, and an unsigned one wraps into the channels beside it.
      const FromChannel = Integer((From shr Bits) and $FF);
      const OntoChannel = Integer((Onto shr Bits) and $FF);
      const Channel = EnsureRange(Round(FromChannel + (OntoChannel - FromChannel) * Ratio), 0, 255);

      Blended := Blended or (Cardinal(Channel) shl Bits);
    end;

    Exit(TLayoutColor(Blended));
  end;

  Result := Stops[Last].Color;
end;

class function TMarkdownPixelRaster.Create(const Width, Height: Integer): TMarkdownPixelRaster;
begin
  Result.Width := Max(0, Width);
  Result.Height := Max(0, Height);
  SetLength(Result.Pixels, Result.Width * Result.Height * 4);
end;

function TMarkdownPixelRaster.IsEmpty: Boolean;
begin
  Result := (Width <= 0) or (Height <= 0) or (Length(Pixels) = 0);
end;

// Every edge the sample line passes through contributes one crossing, carrying
// the direction it was crossed in so the non-zero rule can tell a hole from a
// second shape. An edge is treated as closed at its top and open at its bottom,
// so a vertex shared by two edges is counted once.
class function TMarkdownPolygonRasterizer.CollectCrossings(const Contours: TArray<TArray<TLayoutPointF>>;
  const SampleY: Single; var Crossings: TArray<TEdgeCrossing>): Integer;
begin
  Result := 0;

  for var Contour in Contours do
  begin
    for var Index := 0 to High(Contour) do
    begin
      const Current = Contour[Index];
      var NextIndex := Index + 1;
      if NextIndex > High(Contour) then
        NextIndex := 0;
      const Next = Contour[NextIndex];

      const Rises = (Current.Y <= SampleY) and (Next.Y > SampleY);
      const Falls = (Next.Y <= SampleY) and (Current.Y > SampleY);
      if not (Rises or Falls) then
        Continue;

      const Span = Next.Y - Current.Y;
      if Span = 0 then
        Continue;

      Crossings[Result].X := Current.X + (SampleY - Current.Y) / Span * (Next.X - Current.X);
      if Rises then
        Crossings[Result].Direction := 1
      else
        Crossings[Result].Direction := -1;

      Inc(Result);
    end;
  end;
end;

class function TMarkdownPolygonRasterizer.CrossingCapacity(const Contours: TArray<TArray<TLayoutPointF>>): Integer;
begin
  Result := 1;

  for var Contour in Contours do
  begin
    Inc(Result, Length(Contour));
  end;
end;

// Insertion sort: a scanline crosses a handful of edges even for a shape built
// from hundreds of segments, and the crossings arrive nearly ordered.
class procedure TMarkdownPolygonRasterizer.SortCrossings(var Crossings: TArray<TEdgeCrossing>;
  const Count: Integer);
begin
  for var Index := 1 to Count - 1 do
  begin
    const Current = Crossings[Index];
    var Position := Index - 1;

    while (Position >= 0) and (Crossings[Position].X > Current.X) do
    begin
      Crossings[Position + 1] := Crossings[Position];
      Dec(Position);
    end;

    Crossings[Position + 1] := Current;
  end;
end;

// The even-odd rule counts crossings and the non-zero rule counts the direction
// they were crossed in, and both are inside the shape whenever the count is not
// back to nothing.
function TMarkdownPolygonRasterizer.TWindingCounter.Accepts(const Crossing: TEdgeCrossing;
  const Rule: TMarkdownFillRule): Boolean;
begin
  if Rule = TMarkdownFillRule.EvenOdd then
  begin
    Total := Total + 1;
    Exit(Odd(Total));
  end;

  Total := Total + Crossing.Direction;
  Result := Total <> 0;
end;

// Adds the exact horizontal overlap of one span to the pixels it touches: the
// two end pixels get their fraction, everything between them gets the lot.
class procedure TMarkdownPolygonRasterizer.AddSpan(var Coverage: TArray<Single>;
  const Left, Right, Weight: Single);
begin
  const Width = Length(Coverage);
  if (Width = 0) or (Right <= Left) then
    Exit;

  const Start = Max(Left, 0.0);
  const Stop = Min(Right, Single(Width));
  if Stop <= Start then
    Exit;

  const FirstPixel = Trunc(Start);
  const LastPixel = Min(Ceil(Stop) - 1, Width - 1);

  if FirstPixel = LastPixel then
  begin
    Coverage[FirstPixel] := Coverage[FirstPixel] + (Stop - Start) * Weight;
    Exit;
  end;

  Coverage[FirstPixel] := Coverage[FirstPixel] + (FirstPixel + 1 - Start) * Weight;

  for var Pixel := FirstPixel + 1 to LastPixel - 1 do
  begin
    Coverage[Pixel] := Coverage[Pixel] + Weight;
  end;

  Coverage[LastPixel] := Coverage[LastPixel] + (Stop - LastPixel) * Weight;
end;

class function TMarkdownPolygonRasterizer.Fill(const Points: TArray<TLayoutPointF>;
  const Color: TLayoutColor; const Width, Height: Integer; const Rule: TMarkdownFillRule): TMarkdownPixelRaster;
begin
  Result := TMarkdownPixelRaster.Create(Width, Height);
  if Length(Points) < 3 then
    Exit;

  FillInto(Result, Points, Color, Rule);
end;

class procedure TMarkdownPolygonRasterizer.FillInto(var Raster: TMarkdownPixelRaster;
  const Points: TArray<TLayoutPointF>; const Color: TLayoutColor; const Rule: TMarkdownFillRule);
begin
  FillContoursInto(Raster, [Points], Color, Rule);
end;

class procedure TMarkdownPolygonRasterizer.FillContoursInto(var Raster: TMarkdownPixelRaster;
  const Contours: TArray<TArray<TLayoutPointF>>; const Color: TLayoutColor; const Rule: TMarkdownFillRule);
begin
  FillPaintedContoursInto(Raster, Contours, TMarkdownPaint.SolidColor(Color), Rule, nil);
end;

class function TMarkdownPolygonRasterizer.CoverageOf(const Contours: TArray<TArray<TLayoutPointF>>;
  const Width, Height: Integer; const Rule: TMarkdownFillRule): TMarkdownClipMask;
begin
  var Raster := TMarkdownPixelRaster.Create(Width, Height);
  FillPaintedContoursInto(Raster, Contours, TMarkdownPaint.SolidColor($FFFFFFFF), Rule, nil);

  SetLength(Result, Width * Height);
  for var Index := 0 to High(Result) do
  begin
    Result[Index] := Raster.Pixels[Index * BytesPerPixel + 3];
  end;
end;

class procedure TMarkdownPolygonRasterizer.FillPaintedContoursInto(var Raster: TMarkdownPixelRaster;
  const Contours: TArray<TArray<TLayoutPointF>>; const Paint: TMarkdownPaint; const Rule: TMarkdownFillRule;
  const Mask: TMarkdownClipMask);
begin
  if Raster.IsEmpty or (Length(Contours) = 0) then
    Exit;

  const IsSolid = Paint.Kind = TMarkdownPaintKind.Solid;
  if IsSolid and (Paint.Color shr 24 = 0) then
    Exit;

  const HasMask = Length(Mask) = Raster.Width * Raster.Height;
  const SampleWeight = FullCoverage / SubScanlines;

  var Crossings: TArray<TEdgeCrossing>;
  SetLength(Crossings, CrossingCapacity(Contours));

  var Coverage: TArray<Single>;
  SetLength(Coverage, Raster.Width);

  for var Row := 0 to Raster.Height - 1 do
  begin
    FillChar(Coverage[0], Length(Coverage) * SizeOf(Single), 0);

    for var Sample := 0 to SubScanlines - 1 do
    begin
      const SampleY = Row + (Sample + 0.5) / SubScanlines;
      const Count = CollectCrossings(Contours, SampleY, Crossings);
      if Count < 2 then
        Continue;

      SortCrossings(Crossings, Count);

      var Winding := Default(TWindingCounter);
      for var Index := 0 to Count - 2 do
      begin
        if Winding.Accepts(Crossings[Index], Rule) then
          AddSpan(Coverage, Crossings[Index].X, Crossings[Index + 1].X, SampleWeight);
      end;
    end;

    var Offset := Row * Raster.Width * BytesPerPixel;
    for var Column := 0 to Raster.Width - 1 do
    begin
      var Covered := Min(FullCoverage, Max(0.0, Coverage[Column]));

      if HasMask then
        Covered := Covered * Mask[Row * Raster.Width + Column] / OpaqueAlpha;

      if Covered > 0 then
      begin
        var Color := Paint.Color;
        if not IsSolid then
          Color := Paint.ColorAt(Column + 0.5, Row + 0.5);

        const Alpha = Color shr 24;
        if Alpha > 0 then
        begin
          const Weight = Covered * Alpha / OpaqueAlpha;

          // Source-over on premultiplied pixels: what arrives keeps the coverage
          // it was drawn with, and what was already there survives in proportion
          // to the transparency left over.
          const Remaining = FullCoverage - Weight;
          Raster.Pixels[Offset] := Round((Color and $FF) * Weight + Raster.Pixels[Offset] * Remaining);
          Raster.Pixels[Offset + 1] :=
            Round(((Color shr 8) and $FF) * Weight + Raster.Pixels[Offset + 1] * Remaining);
          Raster.Pixels[Offset + 2] :=
            Round(((Color shr 16) and $FF) * Weight + Raster.Pixels[Offset + 2] * Remaining);
          Raster.Pixels[Offset + 3] := Round(OpaqueAlpha * Weight + Raster.Pixels[Offset + 3] * Remaining);
        end;
      end;

      Inc(Offset, BytesPerPixel);
    end;
  end;
end;

end.
