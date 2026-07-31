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
      CheckboxBorderStrokeWidth = 1.0;
      CheckboxMarkStrokeWidth = 2.0;
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
    class procedure RenderWedge(const Wedge: IDisplayWedge; const Painter: IPainter);
    class procedure RenderPolygon(const Polygon: IDisplayPolygon; const Painter: IPainter);

  public
    class procedure Render(const DisplayList: IMarkdownDisplayList; const Painter: IPainter;
      const Viewport: TLayoutRectF; const BackgroundColor: TLayoutColor);
  end;

implementation

uses
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
  const Bounds = Checkbox.Bounds;
  Painter.DrawRect(Bounds, CheckboxBorderColor, CheckboxBorderStrokeWidth);

  if not Checkbox.Checked then
    Exit;

  const Width = Bounds.Width;
  const Height = Bounds.Height;
  const StartPoint = TLayoutPointF.Create(Bounds.Left + (CheckboxMarkStartXFactor * Width),
    Bounds.Top + (CheckboxMarkStartYFactor * Height));
  const MiddlePoint = TLayoutPointF.Create(Bounds.Left + (CheckboxMarkMiddleXFactor * Width),
    Bounds.Top + (CheckboxMarkMiddleYFactor * Height));
  const EndPoint = TLayoutPointF.Create(Bounds.Left + (CheckboxMarkEndXFactor * Width),
    Bounds.Top + (CheckboxMarkEndYFactor * Height));
  Painter.DrawLine(StartPoint, MiddlePoint, CheckboxMarkColor, CheckboxMarkStrokeWidth);
  Painter.DrawLine(MiddlePoint, EndPoint, CheckboxMarkColor, CheckboxMarkStrokeWidth);
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
