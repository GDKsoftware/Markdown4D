unit Markdown4D.Extensions.Chart.BlockOverride;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Extensions.Chart,
  Markdown4D.Extensions.Chart.Layout;

type
  TChartBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  strict private
    var FOptions: TChartLayoutOptions;
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
    class function TryResolveModel(const Node: IMarkdownNode; out Model: IChartModel): Boolean;
    class function IsRegistered: Boolean;
    class procedure RegisterWith(const Options: TChartLayoutOptions);
  public
    const
      OverrideName = 'markdown4d.chart';
      OverridePriority = TMarkdownPriorities.ExtensionLayoutOverride;
    class procedure RegisterOverride; overload;
    class procedure RegisterOverride(const Options: TChartLayoutOptions); overload;
    constructor Create; overload;
    constructor Create(const Options: TChartLayoutOptions); overload;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Defines,
  Markdown4D.Layout.Engine;

class procedure TChartBlockOverride.RegisterOverride;
begin
  if IsRegistered then
    Exit;

  RegisterWith(Default(TChartLayoutOptions));
end;

class procedure TChartBlockOverride.RegisterOverride(const Options: TChartLayoutOptions);
begin
  // The registry keeps the first handler of equal priority, so options passed
  // after the first registration would otherwise be dropped without a word.
  if IsRegistered then
    raise EMarkdownError.Create('The chart override is already registered; pass the layout options to the first ' +
      'RegisterOverride call, or register a TChartBlockOverride with a higher priority');

  RegisterWith(Options);
end;

class function TChartBlockOverride.IsRegistered: Boolean;
begin
  Result := TLayoutBlockOverrideRegistry.IsRegistered(OverrideName, OverridePriority);
end;

class procedure TChartBlockOverride.RegisterWith(const Options: TChartLayoutOptions);
begin
  TMarkdownLayoutEngine.RegisterBlockOverride(TChartBlockOverride.Create(Options), OverridePriority);
  TLayoutDocumentProcessorRegistry.Register(TChartExtension.CreateDocumentProcessor);
end;

constructor TChartBlockOverride.Create;
begin
  Create(Default(TChartLayoutOptions));
end;

constructor TChartBlockOverride.Create(const Options: TChartLayoutOptions);
begin
  inherited Create;

  FOptions := Options;
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
  begin
    Result := 0;
    Exit;
  end;

  const Height = TChartLayouter.PreferredHeight(Model, Context.Width, Context.Theme, Context.Measurer, FOptions);
  const Bounds = TLayoutRectF.Create(0, Top, Context.Width, Top + Height);
  TChartLayouter.Draw(Model, Bounds, Context.Theme, Context.Measurer, Context.Canvas, FOptions);

  Result := Height;
end;

end.
