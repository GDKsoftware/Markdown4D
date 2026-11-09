unit Markdown4D.Tests.BoxOverride;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.BlockOverride;

type
  // How tall the bar of a box is in one viewer, kept in its extension data.
  IBoxHeight = interface
    ['{B0283CC2-EEBC-47D0-9864-96CF7DA7DD8A}']
    function Height: Single;
  end;

  TBoxHeight = class(TInterfacedObject, IBoxHeight)
  private
    FHeight: Single;

  public
    constructor Create(const Height: Single);
    function Height: Single;
  end;

  // Draws a fence with the info string box: a bar as tall as the viewer's
  // extension data says, and below it the content of the fence laid out as
  // markdown of its own, indented by NestedLeft.
  TBoxBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  private
    class function BarHeightIn(const Data: IMarkdownExtensionData): Single; static;

  public
    const
      OverrideName = 'markdown4d.test.box';
      InfoString = 'box';
      Priority = 100;
      DefaultBarHeight = 10.0;
      NestedLeft = 30.0;
      BarColor = TLayoutColor($FF808080);
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines;

constructor TBoxHeight.Create(const Height: Single);
begin
  inherited Create;

  FHeight := Height;
end;

function TBoxHeight.Height: Single;
begin
  Result := FHeight;
end;

class function TBoxBlockOverride.BarHeightIn(const Data: IMarkdownExtensionData): Single;
begin
  Result := DefaultBarHeight;
  if Data = nil then
    Exit;

  var Value: IInterface;
  var Box: IBoxHeight;
  const HasHeight = (Data.TryGetValue(OverrideName, Value) and Supports(Value, IBoxHeight, Box));
  if HasHeight then
    Result := Box.Height;
end;

function TBoxBlockOverride.GetName: string;
begin
  Result := OverrideName;
end;

function TBoxBlockOverride.Handles(const Node: IMarkdownNode): Boolean;
begin
  var Code: IMarkdownCodeBlock;
  Result := (Supports(Node, IMarkdownCodeBlock, Code) and (Code.InfoString = InfoString));
end;

function TBoxBlockOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
begin
  const BarHeight = BarHeightIn(Context.ExtensionData);
  const Bar = TLayoutRectF.Create(0, Top, Context.Width, Top + BarHeight);
  Context.Canvas.FillRectangle(Bar, BarColor);

  const Code = Node as IMarkdownCodeBlock;
  const Content = TMarkdown.Parse(Code.Literal, TMarkdownDialect.Gfm);
  const Nested = Context.LayoutNested(Content, Context.Width - NestedLeft);
  Context.AppendNested(Nested, NestedLeft, Top + BarHeight);

  Result := BarHeight + Nested.Height;
end;

end.
