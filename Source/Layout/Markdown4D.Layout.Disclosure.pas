unit Markdown4D.Layout.Disclosure;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces;

type
  // A <details> section written the way GitHub and GitLab need it, with blank
  // lines around its markdown, is not one node but a run of siblings: an HTML
  // block that opens it and holds the summary, the blocks of its content, and
  // an HTML block that closes it. This finds those runs and says which blocks
  // a closed section hides. A section written as one HTML block, closing tag
  // included, is not a run and stays as it is.
  TMarkdownDisclosures = class
  private
    const
      OpenerTag = '<details';
      CloserTag = '</details';
      OpenAttribute = 'open';
    class function TryGetHtmlLiteral(const Node: IMarkdownNode; out Literal: string): Boolean; static;
    class function StartsWithTag(const Text, Tag: string): Boolean; static;
    class function HasOpenAttribute(const Literal: string): Boolean; static;

  public
    class function IsOpener(const Node: IMarkdownNode; out OpenByDefault: Boolean): Boolean; static;
    class function IsCloser(const Node: IMarkdownNode): Boolean; static;
    class function KeyOf(const Opener: IMarkdownNode): Integer; static;
    // A missing state means every section shows the way its tag asks for:
    // closed, unless it carries `open`.
    class function IsOpen(const State: IMarkdownDisclosureState; const Opener: IMarkdownNode;
      const OpenByDefault: Boolean): Boolean; static;
    // One flag per child of Container: True for a child inside a closed
    // section, and for the block that ends a section, which shows nothing but
    // would still add a gap. The opener of a closed section stays visible,
    // because its summary is what the reader clicks.
    class function HiddenChildren(const Container: IMarkdownNode;
      const State: IMarkdownDisclosureState): TArray<Boolean>; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Generics.Collections;

class function TMarkdownDisclosures.IsOpener(const Node: IMarkdownNode; out OpenByDefault: Boolean): Boolean;
begin
  OpenByDefault := False;
  Result := False;

  var Literal: string;
  if not TryGetHtmlLiteral(Node, Literal) then
    Exit;

  if not StartsWithTag(Literal, OpenerTag) then
    Exit;

  const ClosesItself = ContainsText(Literal, CloserTag);
  if ClosesItself then
    Exit;

  OpenByDefault := HasOpenAttribute(Literal);
  Result := True;
end;

class function TMarkdownDisclosures.IsCloser(const Node: IMarkdownNode): Boolean;
begin
  var Literal: string;
  Result := TryGetHtmlLiteral(Node, Literal) and StartsWithTag(Literal, CloserTag);
end;

class function TMarkdownDisclosures.KeyOf(const Opener: IMarkdownNode): Integer;
begin
  Result := Opener.Segment.StartOffset;
end;

class function TMarkdownDisclosures.IsOpen(const State: IMarkdownDisclosureState; const Opener: IMarkdownNode;
  const OpenByDefault: Boolean): Boolean;
begin
  if State = nil then
  begin
    Result := OpenByDefault;
    Exit;
  end;

  const Key = KeyOf(Opener);
  Result := State.IsDisclosureOpen(Key, OpenByDefault);
end;

class function TMarkdownDisclosures.HiddenChildren(const Container: IMarkdownNode;
  const State: IMarkdownDisclosureState): TArray<Boolean>;
begin
  SetLength(Result, Container.ChildCount);

  const OpenSections = TList<Boolean>.Create;
  try
    var ClosedDepth := 0;

    for var Index := 0 to Container.ChildCount - 1 do
    begin
      const Child = Container.Children[Index];
      Result[Index] := (ClosedDepth > 0);

      var OpenByDefault: Boolean;
      if IsOpener(Child, OpenByDefault) then
      begin
        const SectionIsOpen = IsOpen(State, Child, OpenByDefault);
        OpenSections.Add(SectionIsOpen);
        if not SectionIsOpen then
          Inc(ClosedDepth);
      end
      else if IsCloser(Child) and (OpenSections.Count > 0) then
      begin
        Result[Index] := True;

        const ClosingIndex = OpenSections.Count - 1;
        const ClosedSectionEnds = not OpenSections[ClosingIndex];
        OpenSections.Delete(ClosingIndex);
        if ClosedSectionEnds then
          Dec(ClosedDepth);
      end;
    end;
  finally
    OpenSections.Free;
  end;
end;

class function TMarkdownDisclosures.TryGetHtmlLiteral(const Node: IMarkdownNode; out Literal: string): Boolean;
begin
  Literal := '';
  Result := False;

  if (Node = nil) or (Node.Kind <> TMarkdownNodeKind.HtmlBlock) then
    Exit;

  var Html: IMarkdownText;
  if not Supports(Node, IMarkdownText, Html) then
    Exit;

  Literal := Html.Literal;
  Result := True;
end;

// A tag name ends at a space, a line break, a slash or the closing bracket, so
// <detailsx> is not a <details> tag.
class function TMarkdownDisclosures.StartsWithTag(const Text, Tag: string): Boolean;
begin
  const Trimmed = Text.TrimLeft;
  Result := False;

  if not StartsText(Tag, Trimmed) then
    Exit;

  const NextIndex = Length(Tag) + 1;
  if NextIndex > Length(Trimmed) then
    Exit;

  Result := CharInSet(Trimmed[NextIndex], ['>', '/', ' ', #9, #10, #13]);
end;

class function TMarkdownDisclosures.HasOpenAttribute(const Literal: string): Boolean;
begin
  const Trimmed = Literal.TrimLeft;
  const TagEnd = Pos('>', Trimmed);
  const AttributeText = Copy(Trimmed, Length(OpenerTag) + 1, TagEnd - Length(OpenerTag) - 1);
  const Attributes = AttributeText.Split([' ', #9, #10, #13, '/'], TStringSplitOptions.ExcludeEmpty);

  Result := False;
  for var Attribute in Attributes do
  begin
    const NameAndValue = Attribute.Split(['=']);
    const IsOpenAttribute = SameText(NameAndValue[0], OpenAttribute);
    if IsOpenAttribute then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

end.
