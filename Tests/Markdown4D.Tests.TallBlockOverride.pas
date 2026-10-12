unit Markdown4D.Tests.TallBlockOverride;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.BlockOverride;

type
  // Stands in for a diagram of a known height: draws a ```tall block as a
  // filled box with a label every LabelSpacing, as tall as the number in the
  // block says.
  TTallBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  private
    const
      InfoString = 'tall';
      OverrideName = 'tall';
      LabelSpacing = 50.0;
      LabelFontSize = 13.0;
      LabelText = 'label';
      BoxColor = $FFDDEEFF;
      LabelColor = $FF000000;
    class function TryGetCodeBlock(const Node: IMarkdownNode; out Code: IMarkdownCodeBlock): Boolean; static;

  public
    const
      Priority = 1000;
    class function Fence(const Height: Integer): string; static;
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Layout.Interfaces;

class function TTallBlockOverride.Fence(const Height: Integer): string;
begin
  Result := Format('```%s'#10'%d'#10'```'#10, [InfoString, Height]);
end;

function TTallBlockOverride.GetName: string;
begin
  Result := OverrideName;
end;

function TTallBlockOverride.Handles(const Node: IMarkdownNode): Boolean;
begin
  var Code: IMarkdownCodeBlock;
  Result := TryGetCodeBlock(Node, Code);
end;

function TTallBlockOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
begin
  var Code: IMarkdownCodeBlock;
  TryGetCodeBlock(Node, Code);
  Result := StrToInt(Code.Literal.Trim);

  Context.Canvas.FillRectangle(TLayoutRectF.Create(0, Top, Context.Width, Top + Result), BoxColor);

  const Font = TMarkdownFontStyle.Create('', LabelFontSize);
  var LabelTop := Top;
  while LabelTop + LabelSpacing <= Top + Result do
  begin
    Context.Canvas.DrawText(TLayoutPointF.Create(0, LabelTop), LabelText, Font, LabelColor);
    LabelTop := LabelTop + LabelSpacing;
  end;
end;

class function TTallBlockOverride.TryGetCodeBlock(const Node: IMarkdownNode; out Code: IMarkdownCodeBlock): Boolean;
begin
  Result := Supports(Node, IMarkdownCodeBlock, Code) and (Code.InfoString = InfoString);
end;

end.
