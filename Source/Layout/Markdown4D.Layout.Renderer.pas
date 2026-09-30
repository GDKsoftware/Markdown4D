unit Markdown4D.Layout.Renderer;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList;

type
  TMarkdownDisplayListRenderer = class
  private
    const
      CheckboxBorderColor = TLayoutColor($FF8C959F);
      CheckboxMarkColor = TLayoutColor($FF1F883D);
      CheckboxBorderStrokeWidthFactor = 0.0625;
      CheckboxMinimumBorderStrokeWidth = 1;
      CheckboxMarkStrokeWidthFactor = 0.125;
      CheckboxMarkCapSegments = 8;
      CheckboxMarkStartXFactor = 0.22;
      CheckboxMarkStartYFactor = 0.55;
      CheckboxMarkMiddleXFactor = 0.42;
      CheckboxMarkMiddleYFactor = 0.74;
      CheckboxMarkEndXFactor = 0.78;
      CheckboxMarkEndYFactor = 0.3;
      UnhandledItemKindMessage = 'Unhandled display item kind: %d';
    class function AlphaOf(const Color: TLayoutColor): Byte;
    class function IsVisible(const Bounds, Viewport: TLayoutRectF): Boolean;
    class procedure RenderItem(const Item: IDisplayItem; const Painter: IPainter);
    class procedure RenderTextRun(const Run: IDisplayTextRun; const Painter: IPainter);
    class procedure RenderRectangle(const Rectangle: IDisplayRectangle; const Painter: IPainter);
    class procedure RenderLine(const Line: IDisplayLine; const Painter: IPainter);
    class procedure RenderImage(const Image: IDisplayImage; const Painter: IPainter);
    class procedure RenderCheckbox(const Checkbox: IDisplayCheckbox; const Painter: IPainter);
    class function PixelAlignedBox(const Bounds: TLayoutRectF): TLayoutRectF;
    class function BorderStrokeWidth(const Box: TLayoutRectF): Single;
    class function CheckMarkOutline(const Box: TLayoutRectF): TArray<TLayoutPointF>;
    class function PointInBox(const Box: TLayoutRectF; const XFactor, YFactor: Single): TLayoutPointF;
    class function BentStrokeOutline(const StartPoint, CornerPoint, EndPoint: TLayoutPointF;
      const HalfWidth: Single): TArray<TLayoutPointF>;
    class function DirectionOf(const FromPoint, ToPoint: TLayoutPointF): Single;
    class function TurnBetween(const IncomingAngle, OutgoingAngle: Single): Single;
    class function RoundCap(const Center: TLayoutPointF; const StartAngle, Radius: Single): TArray<TLayoutPointF>;
    class function PointAt(const Origin: TLayoutPointF; const Angle, Distance: Single): TLayoutPointF;
    class procedure RenderWedge(const Wedge: IDisplayWedge; const Painter: IPainter);
    class procedure RenderPolygon(const Polygon: IDisplayPolygon; const Painter: IPainter);

  public
    class procedure Render(const DisplayList: IMarkdownDisplayList; const Painter: IPainter;
      const Viewport: TLayoutRectF; const BackgroundColor: TLayoutColor);
  end;

implementation

uses
  System.Math,
  Markdown4D.Defines;

class procedure TMarkdownDisplayListRenderer.Render(const DisplayList: IMarkdownDisplayList; const Painter: IPainter;
  const Viewport: TLayoutRectF; const BackgroundColor: TLayoutColor);
begin
  if AlphaOf(BackgroundColor) > 0 then
    Painter.FillRect(Viewport, BackgroundColor);

  if DisplayList = nil then
    Exit;

  Painter.SaveState;
  try
    Painter.SetClip(Viewport);

    for var Index := 0 to DisplayList.ItemCount - 1 do
    begin
      const Item = DisplayList.Items[Index];
      if IsVisible(Item.Bounds, Viewport) then
        RenderItem(Item, Painter);
    end;
  finally
    Painter.RestoreState;
  end;
end;

class function TMarkdownDisplayListRenderer.AlphaOf(const Color: TLayoutColor): Byte;
begin
  Result := Color shr 24;
end;

class function TMarkdownDisplayListRenderer.IsVisible(const Bounds, Viewport: TLayoutRectF): Boolean;
begin
  Result := (Bounds.Bottom >= Viewport.Top) and (Bounds.Top <= Viewport.Bottom);
end;

class procedure TMarkdownDisplayListRenderer.RenderItem(const Item: IDisplayItem; const Painter: IPainter);
begin
  case Item.Kind of
    TDisplayItemKind.TextRun:
      RenderTextRun(Item as IDisplayTextRun, Painter);
    TDisplayItemKind.Rectangle:
      RenderRectangle(Item as IDisplayRectangle, Painter);
    TDisplayItemKind.Line:
      RenderLine(Item as IDisplayLine, Painter);
    TDisplayItemKind.Image:
      RenderImage(Item as IDisplayImage, Painter);
    TDisplayItemKind.Checkbox:
      RenderCheckbox(Item as IDisplayCheckbox, Painter);
    TDisplayItemKind.Wedge:
      RenderWedge(Item as IDisplayWedge, Painter);
    TDisplayItemKind.Polygon:
      RenderPolygon(Item as IDisplayPolygon, Painter);
  else
    raise EMarkdownError.CreateFmt(UnhandledItemKindMessage, [Ord(Item.Kind)]);
  end;
end;

class procedure TMarkdownDisplayListRenderer.RenderTextRun(const Run: IDisplayTextRun; const Painter: IPainter);
begin
  // A source run exists for selection and copy; the drawing it stands for is
  // painted by the runs around it.
  const IsSource = (Run.Role = TDisplayTextRunRole.Source);
  if IsSource then
    Exit;

  const TopY = Run.Bounds.Top + Run.Baseline - Painter.Baseline(Run.Font);
  Painter.DrawTextRun(TLayoutPointF.Create(Run.Bounds.Left, TopY), Run.Text, Run.Font, Run.Color);
end;

class procedure TMarkdownDisplayListRenderer.RenderRectangle(const Rectangle: IDisplayRectangle;
  const Painter: IPainter);
begin
  if AlphaOf(Rectangle.FillColor) > 0 then
    Painter.FillRect(Rectangle.Bounds, Rectangle.FillColor);

  const HasStroke = (Rectangle.StrokeWidth > 0) and (AlphaOf(Rectangle.StrokeColor) > 0);
  if HasStroke then
    Painter.DrawRect(Rectangle.Bounds, Rectangle.StrokeColor, Rectangle.StrokeWidth);
end;

class procedure TMarkdownDisplayListRenderer.RenderLine(const Line: IDisplayLine; const Painter: IPainter);
begin
  Painter.DrawLine(Line.StartPoint, Line.EndPoint, Line.Color, Line.StrokeWidth);
end;

class procedure TMarkdownDisplayListRenderer.RenderImage(const Image: IDisplayImage; const Painter: IPainter);
begin
  Painter.SaveState;
  try
    Painter.SetClip(Image.Bounds);
    Painter.DrawImage(Image.Bounds, Image.Source, TLayoutRectF.Create(0, 0, 0, 0));
  finally
    Painter.RestoreState;
  end;
end;

class procedure TMarkdownDisplayListRenderer.RenderCheckbox(const Checkbox: IDisplayCheckbox;
  const Painter: IPainter);
begin
  const Box = PixelAlignedBox(Checkbox.Bounds);
  const BorderWidth = BorderStrokeWidth(Box);
  Painter.DrawRect(Box, CheckboxBorderColor, BorderWidth);

  const HasMark = (Checkbox.Checked and (Box.Width > 0) and (Box.Height > 0));
  if not HasMark then
    Exit;

  const Outline = CheckMarkOutline(Box);
  Painter.FillPolygon(Outline, CheckboxMarkColor);
end;

class function TMarkdownDisplayListRenderer.PixelAlignedBox(const Bounds: TLayoutRectF): TLayoutRectF;
begin
  const Left = Round(Bounds.Left);
  const Top = Round(Bounds.Top);
  const Width = Round(Bounds.Width);
  const Height = Round(Bounds.Height);
  Result := TLayoutRectF.Create(Left, Top, Left + Width, Top + Height);
end;

class function TMarkdownDisplayListRenderer.BorderStrokeWidth(const Box: TLayoutRectF): Single;
begin
  const ScaledWidth = Round(Box.Width * CheckboxBorderStrokeWidthFactor);
  Result := Max(CheckboxMinimumBorderStrokeWidth, ScaledWidth);
end;

class function TMarkdownDisplayListRenderer.CheckMarkOutline(const Box: TLayoutRectF): TArray<TLayoutPointF>;
begin
  const StartPoint = PointInBox(Box, CheckboxMarkStartXFactor, CheckboxMarkStartYFactor);
  const MiddlePoint = PointInBox(Box, CheckboxMarkMiddleXFactor, CheckboxMarkMiddleYFactor);
  const EndPoint = PointInBox(Box, CheckboxMarkEndXFactor, CheckboxMarkEndYFactor);
  const HalfWidth = Box.Width * CheckboxMarkStrokeWidthFactor / 2;

  Result := BentStrokeOutline(StartPoint, MiddlePoint, EndPoint, HalfWidth);
end;

class function TMarkdownDisplayListRenderer.PointInBox(const Box: TLayoutRectF;
  const XFactor, YFactor: Single): TLayoutPointF;
begin
  Result := TLayoutPointF.Create(Box.Left + (XFactor * Box.Width), Box.Top + (YFactor * Box.Height));
end;

class function TMarkdownDisplayListRenderer.BentStrokeOutline(const StartPoint, CornerPoint, EndPoint: TLayoutPointF;
  const HalfWidth: Single): TArray<TLayoutPointF>;
begin
  const IncomingAngle = DirectionOf(StartPoint, CornerPoint);
  const OutgoingAngle = DirectionOf(CornerPoint, EndPoint);
  const HalfTurn = TurnBetween(IncomingAngle, OutgoingAngle) / 2;
  const MiterAngle = IncomingAngle + (Pi / 2) + HalfTurn;
  const MiterLength = HalfWidth / Cos(HalfTurn);

  const LeftCorner = PointAt(CornerPoint, MiterAngle, MiterLength);
  const RightCorner = PointAt(CornerPoint, MiterAngle, -MiterLength);
  const StartCap = RoundCap(StartPoint, IncomingAngle - (Pi / 2), HalfWidth);
  const EndCap = RoundCap(EndPoint, OutgoingAngle + (Pi / 2), HalfWidth);

  Result := StartCap + [LeftCorner] + EndCap + [RightCorner];
end;

class function TMarkdownDisplayListRenderer.DirectionOf(const FromPoint, ToPoint: TLayoutPointF): Single;
begin
  Result := ArcTan2(ToPoint.Y - FromPoint.Y, ToPoint.X - FromPoint.X);
end;

class function TMarkdownDisplayListRenderer.TurnBetween(const IncomingAngle, OutgoingAngle: Single): Single;
begin
  const Turn = OutgoingAngle - IncomingAngle;
  const WrapsForward = (Turn > Pi);
  if WrapsForward then
    Exit(Turn - (2 * Pi));

  const WrapsBackward = (Turn <= -Pi);
  if WrapsBackward then
    Exit(Turn + (2 * Pi));

  Result := Turn;
end;

class function TMarkdownDisplayListRenderer.RoundCap(const Center: TLayoutPointF;
  const StartAngle, Radius: Single): TArray<TLayoutPointF>;
begin
  SetLength(Result, CheckboxMarkCapSegments + 1);
  for var Step := 0 to CheckboxMarkCapSegments do
  begin
    const Angle = StartAngle - (Pi * Step / CheckboxMarkCapSegments);
    Result[Step] := PointAt(Center, Angle, Radius);
  end;
end;

class function TMarkdownDisplayListRenderer.PointAt(const Origin: TLayoutPointF;
  const Angle, Distance: Single): TLayoutPointF;
begin
  const OffsetX = Distance * Cos(Angle);
  const OffsetY = Distance * Sin(Angle);
  Result := TLayoutPointF.Create(Origin.X + OffsetX, Origin.Y + OffsetY);
end;

class procedure TMarkdownDisplayListRenderer.RenderWedge(const Wedge: IDisplayWedge; const Painter: IPainter);
begin
  if AlphaOf(Wedge.FillColor) > 0 then
    Painter.FillWedge(Wedge.Center, Wedge.OuterRadius, Wedge.InnerRadius, Wedge.StartAngle, Wedge.SweepAngle,
      Wedge.FillColor);

  const HasStroke = (Wedge.StrokeWidth > 0) and (AlphaOf(Wedge.StrokeColor) > 0);
  if HasStroke then
    Painter.DrawWedge(Wedge.Center, Wedge.OuterRadius, Wedge.InnerRadius, Wedge.StartAngle, Wedge.SweepAngle,
      Wedge.StrokeColor, Wedge.StrokeWidth);
end;

class procedure TMarkdownDisplayListRenderer.RenderPolygon(const Polygon: IDisplayPolygon; const Painter: IPainter);
begin
  const PointCount = Polygon.PointCount;
  var Points: TArray<TLayoutPointF>;
  SetLength(Points, PointCount);
  for var Index := 0 to PointCount - 1 do
  begin
    Points[Index] := Polygon.Points[Index];
  end;

  if AlphaOf(Polygon.FillColor) > 0 then
    Painter.FillPolygon(Points, Polygon.FillColor);

  const HasStroke = (Polygon.StrokeWidth > 0) and (AlphaOf(Polygon.StrokeColor) > 0);
  if HasStroke then
    Painter.DrawPolygon(Points, Polygon.StrokeColor, Polygon.StrokeWidth);
end;

end.
