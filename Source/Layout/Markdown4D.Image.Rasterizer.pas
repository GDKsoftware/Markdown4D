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
    class function CollectCrossings(const Points: TArray<TLayoutPointF>; const SampleY: Single;
      var Crossings: TArray<TEdgeCrossing>): Integer; static;
    class procedure SortCrossings(var Crossings: TArray<TEdgeCrossing>; const Count: Integer); static;
    class procedure AddSpan(var Coverage: TArray<Single>; const Left, Right, Weight: Single); static;
    class function SpanIsInside(const Crossing: TEdgeCrossing; const Rule: TMarkdownFillRule;
      var Winding: Integer): Boolean; static;

  public
    class function Fill(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor;
      const Width, Height: Integer;
      const Rule: TMarkdownFillRule = TMarkdownFillRule.NonZero): TMarkdownPixelRaster; static;
  end;

implementation

uses
  System.Math;

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
class function TMarkdownPolygonRasterizer.CollectCrossings(const Points: TArray<TLayoutPointF>;
  const SampleY: Single; var Crossings: TArray<TEdgeCrossing>): Integer;
begin
  Result := 0;

  for var Index := 0 to High(Points) do
  begin
    const Current = Points[Index];
    var NextIndex := Index + 1;
    if NextIndex > High(Points) then
      NextIndex := 0;
    const Next = Points[NextIndex];

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

// Decides whether the gap that starts at Index is inside the shape, keeping the
// winding count the caller carries from one gap to the next.
class function TMarkdownPolygonRasterizer.SpanIsInside(const Crossing: TEdgeCrossing;
  const Rule: TMarkdownFillRule; var Winding: Integer): Boolean;
begin
  if Rule = TMarkdownFillRule.EvenOdd then
  begin
    Winding := Winding + 1;
    Exit(Odd(Winding));
  end;

  Winding := Winding + Crossing.Direction;
  Result := Winding <> 0;
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
  if Result.IsEmpty or (Length(Points) < 3) then
    Exit;

  const Alpha = Color shr 24;
  if Alpha = 0 then
    Exit;

  const Red = (Color shr 16) and $FF;
  const Green = (Color shr 8) and $FF;
  const Blue = Color and $FF;
  const AlphaFactor = Alpha / OpaqueAlpha;
  const SampleWeight = FullCoverage / SubScanlines;

  var Crossings: TArray<TEdgeCrossing>;
  SetLength(Crossings, Length(Points) + 1);

  var Coverage: TArray<Single>;
  SetLength(Coverage, Result.Width);

  for var Row := 0 to Result.Height - 1 do
  begin
    FillChar(Coverage[0], Length(Coverage) * SizeOf(Single), 0);

    for var Sample := 0 to SubScanlines - 1 do
    begin
      const SampleY = Row + (Sample + 0.5) / SubScanlines;
      const Count = CollectCrossings(Points, SampleY, Crossings);
      if Count < 2 then
        Continue;

      SortCrossings(Crossings, Count);

      var Winding := 0;
      for var Index := 0 to Count - 2 do
      begin
        if SpanIsInside(Crossings[Index], Rule, Winding) then
          AddSpan(Coverage, Crossings[Index].X, Crossings[Index + 1].X, SampleWeight);
      end;
    end;

    var Offset := Row * Result.Width * BytesPerPixel;
    for var Column := 0 to Result.Width - 1 do
    begin
      const Covered = Min(FullCoverage, Max(0.0, Coverage[Column])) * AlphaFactor;
      if Covered > 0 then
      begin
        // Premultiplied: the colour channels carry the coverage they were drawn
        // with, which is what an alpha blend expects to receive.
        Result.Pixels[Offset] := Round(Blue * Covered);
        Result.Pixels[Offset + 1] := Round(Green * Covered);
        Result.Pixels[Offset + 2] := Round(Red * Covered);
        Result.Pixels[Offset + 3] := Round(OpaqueAlpha * Covered);
      end;

      Inc(Offset, BytesPerPixel);
    end;
  end;
end;

end.
