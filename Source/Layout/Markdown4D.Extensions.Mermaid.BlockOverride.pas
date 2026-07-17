unit Markdown4D.Extensions.Mermaid.BlockOverride;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Extensions.Mermaid;

type
  TMermaidBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  public
    const
      OverrideName = 'markdown4d.mermaid';
      OverridePriority = 100;
    class var
      FRegistered: Boolean;
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
    class function TryResolveModel(const Node: IMarkdownNode; out Model: IMermaidModel): Boolean;
    class procedure RegisterOverride;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.Engine,
  Markdown4D.Extensions.Mermaid.Layout;

class procedure TMermaidBlockOverride.RegisterOverride;
begin
  if FRegistered then
    Exit;

  TMarkdownLayoutEngine.RegisterBlockOverride(TMermaidBlockOverride.Create, OverridePriority);
  FRegistered := True;
end;

function TMermaidBlockOverride.GetName: string;
begin
  Result := OverrideName;
end;

class function TMermaidBlockOverride.TryResolveModel(const Node: IMarkdownNode; out Model: IMermaidModel): Boolean;
begin
  Model := nil;

  if TMermaidExtension.TryGetModel(Node, Model) then
    Exit(True);

  var Code: IMarkdownCodeBlock;
  if not Supports(Node, IMarkdownCodeBlock, Code) or not TMermaidExtension.IsMermaidCodeBlock(Node) then
    Exit(False);

  Result := TMermaidExtension.TryParse(Code, Model);
end;

function TMermaidBlockOverride.Handles(const Node: IMarkdownNode): Boolean;
begin
  var Model: IMermaidModel;
  Result := TryResolveModel(Node, Model);
end;

function TMermaidBlockOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
begin
  var Model: IMermaidModel;
  if not TryResolveModel(Node, Model) then
    Exit(0);

  const Height = TMermaidLayouter.PreferredHeight(Model, Context.Width, Context.Theme, Context.Measurer);
  const Bounds = TLayoutRectF.Create(0, Top, Context.Width, Top + Height);
  const Items = TMermaidLayouter.BuildDisplayItems(Model, Bounds, Context.Theme, Context.Measurer, Node);

  for var Item in Items do
  begin
    case Item.Kind of
      TDisplayItemKind.Rectangle:
        begin
          const Rectangle = Item as IDisplayRectangle;
          Context.EmitRectangle(Rectangle.Bounds, Rectangle.FillColor, Rectangle.StrokeColor, Rectangle.StrokeWidth);
        end;
      TDisplayItemKind.TextRun:
        begin
          const Run = Item as IDisplayTextRun;
          Context.EmitTextRun(TLayoutPointF.Create(Run.Bounds.Left, Run.Bounds.Top), Run.Text, Run.Font, Run.Color);
        end;
      TDisplayItemKind.Line:
        begin
          const Line = Item as IDisplayLine;
          Context.EmitLine(Line.StartPoint, Line.EndPoint, Line.Color, Line.StrokeWidth);
        end;
      TDisplayItemKind.Wedge:
        begin
          const Wedge = Item as IDisplayWedge;
          Context.EmitWedge(Wedge.Center, Wedge.OuterRadius, Wedge.InnerRadius, Wedge.StartAngle, Wedge.SweepAngle,
            Wedge.FillColor);
        end;
      TDisplayItemKind.Polygon:
        begin
          const Polygon = Item as IDisplayPolygon;

          var Points: TArray<TLayoutPointF>;
          SetLength(Points, Polygon.PointCount);
          for var Index := 0 to Polygon.PointCount - 1 do
          begin
            Points[Index] := Polygon.Points[Index];
          end;

          Context.EmitPolygon(Points, Polygon.FillColor);
        end;
    end;
  end;

  Result := Height;
end;

end.
