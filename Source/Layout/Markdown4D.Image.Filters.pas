unit Markdown4D.Image.Filters;

{$SCOPEDENUMS ON}

// The pixel operations an SVG filter is built from. Each one takes a raster and
// gives back another, so a filter chain is these applied in order.
//
// The blur is three box passes rather than a true Gaussian: that is what the
// specification itself prescribes for a standard deviation, and it costs a few
// additions per pixel instead of a kernel multiply.

interface

uses
  Markdown4D.Layout.Interfaces,
  Markdown4D.Image.Rasterizer;

type
  TMarkdownRasterFilters = class
  private
    const
      BytesPerPixel = 4;
      OpaqueAlpha = 255;
      // The specification's own conversion from a standard deviation to the
      // three box widths that approximate it.
      BoxesPerBlur = 3;
    class function BoxRadius(const Deviation: Single): Integer; static;
    class procedure BlurHorizontally(var Raster: TMarkdownPixelRaster; const Radius: Integer); static;
    class procedure BlurVertically(var Raster: TMarkdownPixelRaster; const Radius: Integer); static;

  public
    class function Blurred(const Source: TMarkdownPixelRaster;
      const DeviationX, DeviationY: Single): TMarkdownPixelRaster; static;
    class function Offset(const Source: TMarkdownPixelRaster;
      const DeltaX, DeltaY: Integer): TMarkdownPixelRaster; static;
    class function Flooded(const Width, Height: Integer; const Color: TLayoutColor): TMarkdownPixelRaster; static;
    // Source-over: the top keeps its own coverage and what is under it survives
    // in proportion to the transparency left over.
    class function Over(const Top, Bottom: TMarkdownPixelRaster): TMarkdownPixelRaster; static;
    // Keeps the colour of the first raster where the second is opaque, which is
    // how a flood is cut to the shape it is meant to colour.
    class function InsideOf(const Source, Shape: TMarkdownPixelRaster): TMarkdownPixelRaster; static;
    // Coverage weighted by how bright each pixel is, which is what a luminance
    // mask holds a shape to.
    class function LuminanceMask(const Source: TMarkdownPixelRaster): TMarkdownClipMask; static;
    class function AlphaMask(const Source: TMarkdownPixelRaster): TMarkdownClipMask; static;
  end;

implementation

uses
  System.Math;

class function TMarkdownRasterFilters.BoxRadius(const Deviation: Single): Integer;
begin
  if Deviation <= 0 then
    Exit(0);

  Result := Max(1, Round(Deviation * 3 * Sqrt(2 * Pi) / 4 / 2));
end;

// A running sum over the window, so the cost per pixel does not grow with the
// radius. Premultiplied channels blur on their own, which is the whole reason
// the buffer keeps them that way.
class procedure TMarkdownRasterFilters.BlurHorizontally(var Raster: TMarkdownPixelRaster; const Radius: Integer);
begin
  if (Radius <= 0) or (Raster.Width = 0) then
    Exit;

  const Window = Radius * 2 + 1;
  var Row: TArray<Byte>;
  SetLength(Row, Raster.Width * BytesPerPixel);

  for var Y := 0 to Raster.Height - 1 do
  begin
    const Start = Y * Raster.Width * BytesPerPixel;
    Move(Raster.Pixels[Start], Row[0], Length(Row));

    for var Channel := 0 to BytesPerPixel - 1 do
    begin
      var Total := 0;
      for var Offset := -Radius to Radius do
      begin
        Total := Total + Row[EnsureRange(Offset, 0, Raster.Width - 1) * BytesPerPixel + Channel];
      end;

      for var X := 0 to Raster.Width - 1 do
      begin
        Raster.Pixels[Start + X * BytesPerPixel + Channel] := Total div Window;

        const Leaving = EnsureRange(X - Radius, 0, Raster.Width - 1);
        const Arriving = EnsureRange(X + Radius + 1, 0, Raster.Width - 1);
        Total := Total - Row[Leaving * BytesPerPixel + Channel] + Row[Arriving * BytesPerPixel + Channel];
      end;
    end;
  end;
end;

class procedure TMarkdownRasterFilters.BlurVertically(var Raster: TMarkdownPixelRaster; const Radius: Integer);
begin
  if (Radius <= 0) or (Raster.Height = 0) then
    Exit;

  const Window = Radius * 2 + 1;
  const Stride = Raster.Width * BytesPerPixel;
  var Column: TArray<Byte>;
  SetLength(Column, Raster.Height * BytesPerPixel);

  for var X := 0 to Raster.Width - 1 do
  begin
    for var Y := 0 to Raster.Height - 1 do
    begin
      Move(Raster.Pixels[Y * Stride + X * BytesPerPixel], Column[Y * BytesPerPixel], BytesPerPixel);
    end;

    for var Channel := 0 to BytesPerPixel - 1 do
    begin
      var Total := 0;
      for var Offset := -Radius to Radius do
      begin
        Total := Total + Column[EnsureRange(Offset, 0, Raster.Height - 1) * BytesPerPixel + Channel];
      end;

      for var Y := 0 to Raster.Height - 1 do
      begin
        Raster.Pixels[Y * Stride + X * BytesPerPixel + Channel] := Total div Window;

        const Leaving = EnsureRange(Y - Radius, 0, Raster.Height - 1);
        const Arriving = EnsureRange(Y + Radius + 1, 0, Raster.Height - 1);
        Total := Total - Column[Leaving * BytesPerPixel + Channel] + Column[Arriving * BytesPerPixel + Channel];
      end;
    end;
  end;
end;

class function TMarkdownRasterFilters.Blurred(const Source: TMarkdownPixelRaster;
  const DeviationX, DeviationY: Single): TMarkdownPixelRaster;
begin
  Result := Source;
  SetLength(Result.Pixels, Length(Source.Pixels));
  if Length(Source.Pixels) > 0 then
    Move(Source.Pixels[0], Result.Pixels[0], Length(Source.Pixels));

  const RadiusX = BoxRadius(DeviationX);
  const RadiusY = BoxRadius(DeviationY);

  for var Pass := 1 to BoxesPerBlur do
  begin
    BlurHorizontally(Result, RadiusX);
    BlurVertically(Result, RadiusY);
  end;
end;

class function TMarkdownRasterFilters.Offset(const Source: TMarkdownPixelRaster;
  const DeltaX, DeltaY: Integer): TMarkdownPixelRaster;
begin
  Result := TMarkdownPixelRaster.Create(Source.Width, Source.Height);

  for var Y := 0 to Source.Height - 1 do
  begin
    const From = Y - DeltaY;
    if (From < 0) or (From >= Source.Height) then
      Continue;

    for var X := 0 to Source.Width - 1 do
    begin
      const Column = X - DeltaX;
      if (Column < 0) or (Column >= Source.Width) then
        Continue;

      Move(Source.Pixels[(From * Source.Width + Column) * BytesPerPixel],
        Result.Pixels[(Y * Source.Width + X) * BytesPerPixel], BytesPerPixel);
    end;
  end;
end;

class function TMarkdownRasterFilters.Flooded(const Width, Height: Integer;
  const Color: TLayoutColor): TMarkdownPixelRaster;
begin
  Result := TMarkdownPixelRaster.Create(Width, Height);

  const Alpha = (Color shr 24) and $FF;
  const Weight = Alpha / OpaqueAlpha;
  const Blue = Round((Color and $FF) * Weight);
  const Green = Round(((Color shr 8) and $FF) * Weight);
  const Red = Round(((Color shr 16) and $FF) * Weight);

  var Offset := 0;
  while Offset < Length(Result.Pixels) do
  begin
    Result.Pixels[Offset] := Blue;
    Result.Pixels[Offset + 1] := Green;
    Result.Pixels[Offset + 2] := Red;
    Result.Pixels[Offset + 3] := Alpha;
    Inc(Offset, BytesPerPixel);
  end;
end;

class function TMarkdownRasterFilters.Over(const Top, Bottom: TMarkdownPixelRaster): TMarkdownPixelRaster;
begin
  Result := TMarkdownPixelRaster.Create(Top.Width, Top.Height);
  if Length(Bottom.Pixels) <> Length(Top.Pixels) then
    Exit(Top);

  for var Offset := 0 to High(Result.Pixels) div BytesPerPixel do
  begin
    const Base = Offset * BytesPerPixel;
    const Remaining = (OpaqueAlpha - Top.Pixels[Base + 3]) / OpaqueAlpha;

    for var Channel := 0 to BytesPerPixel - 1 do
    begin
      Result.Pixels[Base + Channel] :=
        Min(OpaqueAlpha, Round(Top.Pixels[Base + Channel] + Bottom.Pixels[Base + Channel] * Remaining));
    end;
  end;
end;

class function TMarkdownRasterFilters.InsideOf(const Source, Shape: TMarkdownPixelRaster): TMarkdownPixelRaster;
begin
  Result := TMarkdownPixelRaster.Create(Source.Width, Source.Height);
  if Length(Shape.Pixels) <> Length(Source.Pixels) then
    Exit(Source);

  for var Offset := 0 to High(Result.Pixels) div BytesPerPixel do
  begin
    const Base = Offset * BytesPerPixel;
    const Weight = Shape.Pixels[Base + 3] / OpaqueAlpha;

    for var Channel := 0 to BytesPerPixel - 1 do
    begin
      Result.Pixels[Base + Channel] := Round(Source.Pixels[Base + Channel] * Weight);
    end;
  end;
end;

class function TMarkdownRasterFilters.LuminanceMask(const Source: TMarkdownPixelRaster): TMarkdownClipMask;
begin
  SetLength(Result, Source.Width * Source.Height);

  for var Index := 0 to High(Result) do
  begin
    const Base = Index * BytesPerPixel;
    // Rec. 709, on premultiplied channels, which already carry the coverage.
    const Luminance = 0.2126 * Source.Pixels[Base + 2] + 0.7152 * Source.Pixels[Base + 1] +
      0.0722 * Source.Pixels[Base];

    Result[Index] := Round(EnsureRange(Luminance, 0, OpaqueAlpha));
  end;
end;

class function TMarkdownRasterFilters.AlphaMask(const Source: TMarkdownPixelRaster): TMarkdownClipMask;
begin
  SetLength(Result, Source.Width * Source.Height);

  for var Index := 0 to High(Result) do
  begin
    Result[Index] := Source.Pixels[Index * BytesPerPixel + 3];
  end;
end;

end.
