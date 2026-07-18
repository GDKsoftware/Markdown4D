unit Markdown4D.Layout.ExtensionCanvas;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.BlockOverride;

type
  TDisplayListExtensionCanvas = class(TInterfacedObject, IExtensionCanvas)
  private
    FMeasurer: ITextMeasurer;
    FItems: TList<IDisplayItem>;
    FNode: IMarkdownNode;
    class function BoundingRect(const Points: TArray<TLayoutPointF>): TLayoutRectF; static;

  public
    constructor Create(const Measurer: ITextMeasurer; const Items: TList<IDisplayItem>; const Node: IMarkdownNode);
    function MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
    procedure DrawText(const TopLeft: TLayoutPointF; const Text: string; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor);
    procedure DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure DrawDashedLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
      const StrokeWidth: Single);
    procedure FillRectangle(const Bounds: TLayoutRectF; const Color: TLayoutColor);
    procedure DrawRectangle(const Bounds: TLayoutRectF; const StrokeColor: TLayoutColor; const StrokeWidth: Single);
    procedure FillAndStrokeRectangle(const Bounds: TLayoutRectF; const FillColor, StrokeColor: TLayoutColor;
      const StrokeWidth: Single);
    procedure FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
    procedure FillWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const Color: TLayoutColor);
    procedure DrawImage(const Bounds: TLayoutRectF; const Source, AltText: string);
    procedure SaveState;
    procedure SetClip(const Bounds: TLayoutRectF);
    procedure RestoreState;
  end;

implementation

uses
  System.Math,
  Markdown4D.Layout.Primitives;

constructor TDisplayListExtensionCanvas.Create(const Measurer: ITextMeasurer; const Items: TList<IDisplayItem>;
  const Node: IMarkdownNode);
begin
  inherited Create;

  FMeasurer := Measurer;
  FItems := Items;
  FNode := Node;
end;

class function TDisplayListExtensionCanvas.BoundingRect(const Points: TArray<TLayoutPointF>): TLayoutRectF;
begin
  var Left := Points[0].X;
  var Top := Points[0].Y;
  var Right := Points[0].X;
  var Bottom := Points[0].Y;

  for var Index := 1 to High(Points) do
  begin
    Left := Min(Left, Points[Index].X);
    Top := Min(Top, Points[Index].Y);
    Right := Max(Right, Points[Index].X);
    Bottom := Max(Bottom, Points[Index].Y);
  end;

  Result := TLayoutRectF.Create(Left, Top, Right, Bottom);
end;

function TDisplayListExtensionCanvas.MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
begin
  Result := FMeasurer.MeasureText(Text, Font);
end;

procedure TDisplayListExtensionCanvas.DrawText(const TopLeft: TLayoutPointF; const Text: string;
  const Font: TMarkdownFontStyle; const Color: TLayoutColor);
begin
  const Size = FMeasurer.MeasureText(Text, Font);
  const Bounds = TLayoutRectF.CreateFromOrigin(TopLeft, Size);

  FItems.Add(TDisplayTextRun.Create(Bounds, FNode, Text, Font, Color, FMeasurer.Baseline(Font), 0));
end;

procedure TDisplayListExtensionCanvas.DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  const Bounds = TLayoutRectF.Create(Min(StartPoint.X, EndPoint.X), Min(StartPoint.Y, EndPoint.Y),
    Max(StartPoint.X, EndPoint.X), Max(StartPoint.Y, EndPoint.Y));

  FItems.Add(TDisplayLine.Create(Bounds, FNode, StartPoint, EndPoint, Color, StrokeWidth));
end;

procedure TDisplayListExtensionCanvas.DrawDashedLine(const StartPoint, EndPoint: TLayoutPointF;
  const Color: TLayoutColor; const StrokeWidth: Single);
begin
  DrawLine(StartPoint, EndPoint, Color, StrokeWidth);
end;

procedure TDisplayListExtensionCanvas.FillRectangle(const Bounds: TLayoutRectF; const Color: TLayoutColor);
begin
  FItems.Add(TDisplayRectangle.Create(Bounds, FNode, Color, 0, 0));
end;

procedure TDisplayListExtensionCanvas.DrawRectangle(const Bounds: TLayoutRectF; const StrokeColor: TLayoutColor;
  const StrokeWidth: Single);
begin
  FItems.Add(TDisplayRectangle.Create(Bounds, FNode, 0, StrokeColor, StrokeWidth));
end;

procedure TDisplayListExtensionCanvas.FillAndStrokeRectangle(const Bounds: TLayoutRectF;
  const FillColor, StrokeColor: TLayoutColor; const StrokeWidth: Single);
begin
  FItems.Add(TDisplayRectangle.Create(Bounds, FNode, FillColor, StrokeColor, StrokeWidth));
end;

procedure TDisplayListExtensionCanvas.FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
begin
  if Length(Points) = 0 then
    Exit;

  FItems.Add(TDisplayPolygon.Create(BoundingRect(Points), FNode, Points, Color));
end;

procedure TDisplayListExtensionCanvas.FillWedge(const Center: TLayoutPointF;
  const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single; const Color: TLayoutColor);
begin
  const Bounds = TLayoutRectF.Create(Center.X - OuterRadius, Center.Y - OuterRadius, Center.X + OuterRadius,
    Center.Y + OuterRadius);

  FItems.Add(TDisplayWedge.Create(Bounds, FNode, Center, OuterRadius, InnerRadius, StartAngle, SweepAngle, Color));
end;

procedure TDisplayListExtensionCanvas.DrawImage(const Bounds: TLayoutRectF; const Source, AltText: string);
begin
  FItems.Add(TDisplayImage.Create(Bounds, FNode, Source, AltText));
end;

procedure TDisplayListExtensionCanvas.SaveState;
begin
end;

procedure TDisplayListExtensionCanvas.SetClip(const Bounds: TLayoutRectF);
begin
end;

procedure TDisplayListExtensionCanvas.RestoreState;
begin
end;

end.
