unit Markdown4D.Layout.HtmlAlignment;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Html.Subset;

type
  // An aligned element written the way README files need it, with blank lines
  // around its markdown, is not one node but a run of siblings: an HTML block
  // that only opens it, such as <div align="center">, the blocks of its
  // content, and an HTML block that only closes it. This finds those runs and
  // says how each child of a container lines up. An element without align of
  // its own inside an aligned one lines up as the outer one does, as in a
  // browser.
  TMarkdownHtmlAlignments = class
  private
    const
      OpeningOnlyPattern = '^\s*<(div|p|center|section|article)\b[^>]*>\s*$';
      ClosingOnlyPattern = '^\s*</(div|p|center|section|article)\s*>\s*$';
    class function TryGetHtmlLiteral(const Node: IMarkdownNode; out Literal: string): Boolean; static;

  public
    class function ChildAlignments(const Container: IMarkdownNode): TArray<TMarkdownHtmlAlignment>; static;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  System.RegularExpressions;

class function TMarkdownHtmlAlignments.ChildAlignments(const Container: IMarkdownNode): TArray<TMarkdownHtmlAlignment>;
begin
  SetLength(Result, Container.ChildCount);

  const OpenAlignments = TList<TMarkdownHtmlAlignment>.Create;
  try
    for var Index := 0 to Container.ChildCount - 1 do
    begin
      var Current := TMarkdownHtmlAlignment.None;
      const IsInsideElement = (OpenAlignments.Count > 0);
      if IsInsideElement then
        Current := OpenAlignments.Last;

      Result[Index] := Current;

      var Literal: string;
      if not TryGetHtmlLiteral(Container.Children[Index], Literal) then
        Continue;

      const OnlyOpens = TRegEx.IsMatch(Literal, OpeningOnlyPattern, [roIgnoreCase]);
      const OnlyCloses = TRegEx.IsMatch(Literal, ClosingOnlyPattern, [roIgnoreCase]);
      if OnlyOpens then
      begin
        const Own = TMarkdownHtmlSubset.BlockAlignment(Literal);
        const HasOwn = (Own <> TMarkdownHtmlAlignment.None);
        if HasOwn then
          OpenAlignments.Add(Own)
        else
          OpenAlignments.Add(Current);
      end
      else if OnlyCloses and IsInsideElement then
      begin
        OpenAlignments.Delete(OpenAlignments.Count - 1);
      end;
    end;
  finally
    OpenAlignments.Free;
  end;
end;

class function TMarkdownHtmlAlignments.TryGetHtmlLiteral(const Node: IMarkdownNode; out Literal: string): Boolean;
begin
  Literal := '';

  var Html: IMarkdownText;
  Result := ((Node.Kind = TMarkdownNodeKind.HtmlBlock) and Supports(Node, IMarkdownText, Html));
  if Result then
    Literal := Html.Literal;
end;

end.
