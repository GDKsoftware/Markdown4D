unit Markdown4D.Tests.ColumnsOverride;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.BlockOverride;

type
  // Draws a fence with the info string columns: the parts of its content
  // around a line ColumnBreak side by side, each laid out as markdown of its
  // own.
  TColumnsBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  public
    const
      OverrideName = 'markdown4d.test.columns';
      InfoString = 'columns';
      Priority = 100;
      ColumnBreak = '|||';
    class function Markdown(const Left, Right: string): string; static;
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D,
  Markdown4D.Defines;

class function TColumnsBlockOverride.Markdown(const Left, Right: string): string;
begin
  Result := Format('```%s'#10'%s'#10'%s'#10'%s'#10'```', [InfoString, Left, ColumnBreak, Right]);
end;

function TColumnsBlockOverride.GetName: string;
begin
  Result := OverrideName;
end;

function TColumnsBlockOverride.Handles(const Node: IMarkdownNode): Boolean;
begin
  var Code: IMarkdownCodeBlock;
  Result := (Supports(Node, IMarkdownCodeBlock, Code) and (Code.InfoString = InfoString));
end;

function TColumnsBlockOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
begin
  const Code = Node as IMarkdownCodeBlock;
  const Separator = Format(#10'%s'#10, [ColumnBreak]);
  const Columns = Code.Literal.Split([Separator]);
  const ColumnWidth = Context.Width / Length(Columns);

  Result := 0;
  for var Index := 0 to High(Columns) do
  begin
    const Content = TMarkdown.Parse(Columns[Index], TMarkdownDialect.Gfm);
    const Column = Context.LayoutNested(Content, ColumnWidth);
    Context.AppendNested(Column, Index * ColumnWidth, Top);
    Result := Max(Result, Column.Height);
  end;
end;

end.
