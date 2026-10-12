unit Markdown4D.Export.ScaledPainter;

{$SCOPEDENUMS ON}

// Paints a stretch of a layout made at the reference resolution onto a painter
// with more pixels per inch. Every coordinate, length, stroke and font size
// grows by the same factor, so a diagram whose labels have a fixed size keeps
// the proportion to the text it has in the preview. A transform on the device
// would not do: the painters blend wedges and polygons in device pixels.

interface

uses
  Markdown4D.Layout.Interfaces;

type
  TMarkdownScaledPainter = class(TInterfacedObject, IPainter)
  private
    const
      NonPositiveFactorMessage = 'The scale factor of a scaled painter must be above zero, not %g';
    var
      FInner: IPainter;
      FOriginY: Single;
      FFactor: Single;
    procedure GuardFactor(const Factor: Single);
    function ScaledFont(const Font: TMarkdownFontStyle): TMarkdownFontStyle;
    function MapPoint(const Point: TLayoutPointF): TLayoutPointF;
    function MapPoints(const Points: TArray<TLayoutPointF>): TArray<TLayoutPointF>;
    function MapRect(const Bounds: TLayoutRectF): TLayoutRectF;

  public
    constructor Create(const Inner: IPainter; const OriginY, Factor: Single);
    function MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
    function LineHeight(const Font: TMarkdownFontStyle): Single;
    function Baseline(const Font: TMarkdownFontStyle): Single;
    procedure DrawTextRun(const TopLeft: TLayoutPointF; const Text: string; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor);
    procedure FillRect(const Bounds: TLayoutRectF; const Color: TLayoutColor);
    procedure DrawRect(const Bounds: TLayoutRectF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure DrawImage(const Bounds: TLayoutRectF; const Source: string; const SourceRect: TLayoutRectF);
    procedure FillWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const Color: TLayoutColor);
    procedure DrawWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const Color: TLayoutColor; const StrokeWidth: Single);
    procedure FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
    procedure DrawPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure SaveState;
    procedure SetClip(const Bounds: TLayoutRectF);
    procedure RestoreState;
  end;

implementation

uses
  Markdown4D.Export.Pdf.Errors;

constructor TMarkdownScaledPainter.Create(const Inner: IPainter; const OriginY, Factor: Single);
begin
  inherited Create;

  GuardFactor(Factor);

  FInner := Inner;
  FOriginY := OriginY;
  FFactor := Factor;
end;

procedure TMarkdownScaledPainter.GuardFactor(const Factor: Single);
begin
  const IsNonPositive = (Factor <= 0);
  if IsNonPositive then
    raise EMarkdownPdfExportError.CreateFmt(NonPositiveFactorMessage, [Factor]);
end;

function TMarkdownScaledPainter.MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
begin
  const Measured = FInner.MeasureText(Text, ScaledFont(Font));
  Result := TLayoutSizeF.Create(Measured.Width / FFactor, Measured.Height / FFactor);
end;

function TMarkdownScaledPainter.LineHeight(const Font: TMarkdownFontStyle): Single;
begin
  Result := FInner.LineHeight(ScaledFont(Font)) / FFactor;
end;

function TMarkdownScaledPainter.Baseline(const Font: TMarkdownFontStyle): Single;
begin
  Result := FInner.Baseline(ScaledFont(Font)) / FFactor;
end;

procedure TMarkdownScaledPainter.DrawTextRun(const TopLeft: TLayoutPointF; const Text: string;
  const Font: TMarkdownFontStyle; const Color: TLayoutColor);
begin
  FInner.DrawTextRun(MapPoint(TopLeft), Text, ScaledFont(Font), Color);
end;

procedure TMarkdownScaledPainter.FillRect(const Bounds: TLayoutRectF; const Color: TLayoutColor);
begin
  FInner.FillRect(MapRect(Bounds), Color);
end;

procedure TMarkdownScaledPainter.DrawRect(const Bounds: TLayoutRectF; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  FInner.DrawRect(MapRect(Bounds), Color, StrokeWidth * FFactor);
end;

procedure TMarkdownScaledPainter.DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  FInner.DrawLine(MapPoint(StartPoint), MapPoint(EndPoint), Color, StrokeWidth * FFactor);
end;

// The source rectangle is in the pixels of the image itself, which do not
// change with the page.
procedure TMarkdownScaledPainter.DrawImage(const Bounds: TLayoutRectF; const Source: string;
  const SourceRect: TLayoutRectF);
begin
  FInner.DrawImage(MapRect(Bounds), Source, SourceRect);
end;

procedure TMarkdownScaledPainter.FillWedge(const Center: TLayoutPointF;
  const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single; const Color: TLayoutColor);
begin
  FInner.FillWedge(MapPoint(Center), OuterRadius * FFactor, InnerRadius * FFactor, StartAngle, SweepAngle, Color);
end;

procedure TMarkdownScaledPainter.DrawWedge(const Center: TLayoutPointF;
  const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  FInner.DrawWedge(MapPoint(Center), OuterRadius * FFactor, InnerRadius * FFactor, StartAngle, SweepAngle, Color,
    StrokeWidth * FFactor);
end;

procedure TMarkdownScaledPainter.FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
begin
  FInner.FillPolygon(MapPoints(Points), Color);
end;

procedure TMarkdownScaledPainter.DrawPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  FInner.DrawPolygon(MapPoints(Points), Color, StrokeWidth * FFactor);
end;

procedure TMarkdownScaledPainter.SaveState;
begin
  FInner.SaveState;
end;

procedure TMarkdownScaledPainter.SetClip(const Bounds: TLayoutRectF);
begin
  FInner.SetClip(MapRect(Bounds));
end;

procedure TMarkdownScaledPainter.RestoreState;
begin
  FInner.RestoreState;
end;

function TMarkdownScaledPainter.ScaledFont(const Font: TMarkdownFontStyle): TMarkdownFontStyle;
begin
  Result := Font;
  Result.Size := Font.Size * FFactor;
end;

function TMarkdownScaledPainter.MapPoint(const Point: TLayoutPointF): TLayoutPointF;
begin
  Result := TLayoutPointF.Create(Point.X * FFactor, (Point.Y - FOriginY) * FFactor);
end;

function TMarkdownScaledPainter.MapPoints(const Points: TArray<TLayoutPointF>): TArray<TLayoutPointF>;
begin
  SetLength(Result, Length(Points));
  for var Index := 0 to High(Points) do
  begin
    Result[Index] := MapPoint(Points[Index]);
  end;
end;

function TMarkdownScaledPainter.MapRect(const Bounds: TLayoutRectF): TLayoutRectF;
begin
  const TopLeft = MapPoint(TLayoutPointF.Create(Bounds.Left, Bounds.Top));
  const BottomRight = MapPoint(TLayoutPointF.Create(Bounds.Right, Bounds.Bottom));
  Result := TLayoutRectF.Create(TopLeft.X, TopLeft.Y, BottomRight.X, BottomRight.Y);
end;

end.
