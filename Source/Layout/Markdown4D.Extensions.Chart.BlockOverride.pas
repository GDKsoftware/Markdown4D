unit Markdown4D.Extensions.Chart.BlockOverride;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Extensions.Chart;

type
  TChartBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  strict private
    class var FRegistered: Boolean;
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
    class function TryResolveModel(const Node: IMarkdownNode; out Model: IChartModel): Boolean;
  public
    const
      OverrideName = 'markdown4d.chart';
      OverridePriority = TMarkdownPriorities.ExtensionLayoutOverride;
    class procedure RegisterOverride;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Layout.Engine,
  Markdown4D.Extensions.Chart.Layout;

class procedure TChartBlockOverride.RegisterOverride;
begin
  if FRegistered then
    Exit;

  TMarkdownLayoutEngine.RegisterBlockOverride(TChartBlockOverride.Create, OverridePriority);
  TLayoutDocumentProcessorRegistry.Register(TChartExtension.CreateDocumentProcessor);
  FRegistered := True;
end;

function TChartBlockOverride.GetName: string;
begin
  Result := OverrideName;
end;

class function TChartBlockOverride.TryResolveModel(const Node: IMarkdownNode; out Model: IChartModel): Boolean;
begin
  Result := TChartExtension.TryGetModel(Node, Model);
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
  TChartLayouter.Draw(Model, Bounds, Context.Theme, Context.Measurer, Context.Canvas);

  Result := Height;
end;

end.
