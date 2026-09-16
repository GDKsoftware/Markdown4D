unit Markdown4D.Tests.Pipeline.Helpers;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces;

type
  TMarkdownTestPipelineHelpers = class
  public
    class function FindFirstCodeBlock(const Document: IMarkdownDocument; out Code: IMarkdownCodeBlock): Boolean;
    class function ManyParagraphs(const Count: Integer): string;
  end;

implementation

uses
  System.SysUtils;

class function TMarkdownTestPipelineHelpers.FindFirstCodeBlock(const Document: IMarkdownDocument; out Code: IMarkdownCodeBlock): Boolean;
begin
  Code := nil;

  for var Index := 0 to Document.ChildCount - 1 do
  begin
    const Child = Document.Children[Index];
    if Child.Kind = TMarkdownNodeKind.CodeBlock then
    begin
      Code := Child as IMarkdownCodeBlock;
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class function TMarkdownTestPipelineHelpers.ManyParagraphs(const Count: Integer): string;
begin
  var Builder := '';
  for var Index := 0 to Count - 1 do
  begin
    if Index > 0 then
      Builder := Builder + #10#10;
    Builder := Builder + Format('Paragraph %.2d', [Index]);
  end;
  Result := Builder;
end;

end.
