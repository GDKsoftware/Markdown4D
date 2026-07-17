unit Markdown4D.Extensions.Chart.BlockOverride;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Extensions.Chart;

type
  TChartBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  public
    const
      OverrideName = 'markdown4d.chart';
      OverridePriority = 100;
    class var
      FRegistered: Boolean;
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
    class function TryResolveModel(const Node: IMarkdownNode; out Model: IChartModel): Boolean;
    class procedure RegisterOverride;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.Engine,
  Markdown4D.Extensions.Chart.Layout;

class procedure TChartBlockOverride.RegisterOverride;
begin
  if FRegistered then
    Exit;

  TMarkdownLayoutEngine.RegisterBlockOverride(TChartBlockOverride.Create, OverridePriority);
  FRegistered := True;
end;

function TChartBlockOverride.GetName: string;
begin
  Result := OverrideName;
end;

class function TChartBlockOverride.TryResolveModel(const Node: IMarkdownNode; out Model: IChartModel): Boolean;
begin
  Model := nil;

  if TChartExtension.TryGetModel(Node, Model) then
    Exit(True);

  var Code: IMarkdownCodeBlock;
  if not Supports(Node, IMarkdownCodeBlock, Code) or not Code.IsFenced then
    Exit(False);

  Result := TChartExtension.TryParse(Code, Model);
end;

function TChartBlockOverride.Handles(const Node: IMarkdownNode): Boolean;
begin
  var Model: IChartModel;
  Result := TryResolveModel(Node, Model);
end;

function TChartBlockOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
begin
  var Model: IChartModel;
  if not TryResolveModel(Node, Model) then
    Exit(0);

  const Height = TChartLayouter.PreferredHeight(Context.Width, Context.Theme);
  const Bounds = TLayoutRectF.Create(0, Top, Context.Width, Top + Height);
  const Items = TChartLayouter.BuildDisplayItems(Model, Bounds, Context.Theme, Context.Measurer, Node);

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
    end;
  end;

  Result := Height;
end;

end.
