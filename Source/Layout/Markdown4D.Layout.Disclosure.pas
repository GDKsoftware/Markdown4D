unit Markdown4D.Layout.Disclosure;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces;

type
  // A closed section whose summary is in view, with the source of what it
  // hides: markdown for a section written as a run of blocks, HTML for a
  // whole section.
  TMarkdownClosedSection = record
    Opener: IMarkdownNode;
    HiddenSource: string;
  end;

  // A <details> section written the way GitHub and GitLab need it, with blank
  // lines around its markdown, is not one node but a run of siblings: an HTML
  // block that opens it and holds the summary, the blocks of its content, and
  // an HTML block that closes it. This finds those runs and says which blocks
  // a closed section hides. A section written as one HTML block, closing tag
  // included, is a whole section: its summary and its content are the parts
  // of that block before and after </summary>. A section without a summary
  // shows DefaultDetailsSummary, as a browser does.
  TMarkdownDisclosures = class
  private
    const
      OpenerTag = '<details';
      CloserTag = '</details';
      SummaryOpenerTag = '<summary';
      SummaryCloserTag = '</summary>';
      OpenAttribute = 'open';
      KeyDataName = 'markdown4d.disclosure.key';
    class function TryGetHtmlLiteral(const Node: IMarkdownNode; out Literal: string): Boolean; static;
    class function StartsWithTag(const Text, Tag: string): Boolean; static;
    class function HasOpenAttribute(const Literal: string): Boolean; static;
    class function HasSummary(const Literal: string): Boolean; static;
    class function DefaultSummaryHtml: string; static;
    class function SummaryEnd(const Literal: string): Integer; static;
    class procedure CollectKeys(const Container: IMarkdownNode;
      const Occurrences: TDictionary<string, Integer>); static;
    class function SummarySource(const Section: IMarkdownNode): string; static;
    class function KeyFor(const Summary: string; const Occurrence: Integer): Integer; static;
    class function IsContainer(const Node: IMarkdownNode): Boolean; static;
    class procedure CollectClosedSections(const Container: IMarkdownNode; const Source: string;
      const State: IMarkdownDisclosureState; const Sections: TList<TMarkdownClosedSection>); static;
    class function TryGetClosedSection(const Container: IMarkdownNode; const Index: Integer; const Source: string;
      const State: IMarkdownDisclosureState; out Section: TMarkdownClosedSection): Boolean; static;
    class function RunHiddenSource(const Container: IMarkdownNode; const OpenerIndex: Integer;
      const Source: string): string; static;
    class function CollectSectionsAround(const Container, Node: IMarkdownNode;
      const Openers: TList<IMarkdownNode>): Boolean; static;
    class function IsSameNode(const Left, Right: IMarkdownNode): Boolean; static;
    class function Encloses(const Outer, Inner: IMarkdownNode): Boolean; static;

  public
    class function IsOpener(const Node: IMarkdownNode; out OpenByDefault: Boolean): Boolean; static;
    class function IsCloser(const Node: IMarkdownNode): Boolean; static;
    class function IsWholeSection(const Node: IMarkdownNode; out OpenByDefault: Boolean): Boolean; static;
    // The HTML of the block that opens a section, with the default summary
    // after the opening tag when it has none.
    class function OpenerHtml(const Node: IMarkdownNode): string; static;
    // The HTML of a whole section up to and including </summary>; without a
    // summary, the opening tag and the default summary.
    class function SummaryHtml(const Node: IMarkdownNode): string; static;
    // The HTML of a whole section between </summary> and its closing tag.
    class function ContentHtml(const Node: IMarkdownNode): string; static;
    // Gives every section in Document the key a reader's choice to open or
    // close it is kept under: its summary, and which section with that summary
    // it is. Typing elsewhere leaves the key as it is, so an opened section
    // stays open while the text around it changes.
    class procedure AssignKeys(const Document: IMarkdownNode); static;
    // The key AssignKeys gave the section; before that, the key of the first
    // section with its summary.
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
    // The closed sections whose summary is in view, in document order, also
    // inside block quotes and list items. Source is the text Document was
    // parsed from. A closed section inside a closed one is left out: its
    // source is part of the outer one's.
    class function ClosedSections(const Document: IMarkdownNode; const Source: string;
      const State: IMarkdownDisclosureState): TArray<TMarkdownClosedSection>; static;
    // The blocks that open the sections around Node, outermost first.
    class function SectionsAround(const Document, Node: IMarkdownNode): TArray<IMarkdownNode>; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Hash,
  Markdown4D.Consts;

type
  // The key of a section, kept on its node as extension data.
  IDisclosureKey = interface
    ['{6E1B2C47-9A3D-4F58-B0C2-7D4E8A19F356}']
    function Value: Integer;
  end;

  TDisclosureKey = class(TInterfacedObject, IDisclosureKey)
  private
    FValue: Integer;

  public
    constructor Create(const Value: Integer);
    function Value: Integer;
  end;

constructor TDisclosureKey.Create(const Value: Integer);
begin
  inherited Create;
  FValue := Value;
end;

function TDisclosureKey.Value: Integer;
begin
  Result := FValue;
end;

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

class function TMarkdownDisclosures.IsWholeSection(const Node: IMarkdownNode; out OpenByDefault: Boolean): Boolean;
begin
  OpenByDefault := False;
  Result := False;

  var Literal: string;
  if not TryGetHtmlLiteral(Node, Literal) then
    Exit;

  const Trimmed = Literal.TrimRight;
  const IsSection = (StartsWithTag(Literal, OpenerTag) and EndsText(CloserTag + '>', Trimmed));
  if not IsSection then
    Exit;

  OpenByDefault := HasOpenAttribute(Literal);
  Result := True;
end;

class function TMarkdownDisclosures.OpenerHtml(const Node: IMarkdownNode): string;
begin
  var Literal: string;
  if not TryGetHtmlLiteral(Node, Literal) then
    Exit('');

  if HasSummary(Literal) then
    Exit(Literal);

  const TagEnd = Pos('>', Literal);
  const OpeningTag = Copy(Literal, 1, TagEnd);
  const Rest = Copy(Literal, TagEnd + 1, MaxInt);
  Result := Format('%s%s%s', [OpeningTag, DefaultSummaryHtml, Rest]);
end;

class function TMarkdownDisclosures.SummaryHtml(const Node: IMarkdownNode): string;
begin
  var Literal: string;
  if not TryGetHtmlLiteral(Node, Literal) then
    Exit('');

  const Summary = Copy(Literal, 1, SummaryEnd(Literal));
  if HasSummary(Literal) then
    Exit(Summary);

  Result := Format('%s%s', [Summary, DefaultSummaryHtml]);
end;

class function TMarkdownDisclosures.ContentHtml(const Node: IMarkdownNode): string;
begin
  var Literal: string;
  if not TryGetHtmlLiteral(Node, Literal) then
    Exit('');

  const ContentStart = SummaryEnd(Literal) + 1;
  const ContentEnd = LastDelimiter('<', Literal.TrimRight);
  Result := Copy(Literal, ContentStart, ContentEnd - ContentStart);
end;

class procedure TMarkdownDisclosures.AssignKeys(const Document: IMarkdownNode);
begin
  const Occurrences = TDictionary<string, Integer>.Create;
  try
    CollectKeys(Document, Occurrences);
  finally
    Occurrences.Free;
  end;
end;

class procedure TMarkdownDisclosures.CollectKeys(const Container: IMarkdownNode;
  const Occurrences: TDictionary<string, Integer>);
begin
  for var Index := 0 to Container.ChildCount - 1 do
  begin
    const Child = Container.Children[Index];

    var OpenByDefault: Boolean;
    const IsSection = (IsOpener(Child, OpenByDefault) or IsWholeSection(Child, OpenByDefault));
    if IsSection then
    begin
      const Summary = SummarySource(Child);
      var Occurrence := 0;
      Occurrences.TryGetValue(Summary, Occurrence);
      Inc(Occurrence);
      Occurrences.AddOrSetValue(Summary, Occurrence);

      const Key = KeyFor(Summary, Occurrence);
      const StoredKey: IDisclosureKey = TDisclosureKey.Create(Key);
      Child.SetExtensionData(KeyDataName, StoredKey);
      Continue;
    end;

    if IsContainer(Child) then
      CollectKeys(Child, Occurrences);
  end;
end;

class function TMarkdownDisclosures.KeyOf(const Opener: IMarkdownNode): Integer;
begin
  var Stored: IInterface;
  var Key: IDisclosureKey;
  const IsAssigned = (Opener.TryGetExtensionData(KeyDataName, Stored) and Supports(Stored, IDisclosureKey, Key));
  if IsAssigned then
    Exit(Key.Value);

  const Summary = SummarySource(Opener);
  Result := KeyFor(Summary, 1);
end;

// The opening tag and the summary as written, so that a change anywhere
// else keeps the key.
class function TMarkdownDisclosures.SummarySource(const Section: IMarkdownNode): string;
begin
  var Literal: string;
  if not TryGetHtmlLiteral(Section, Literal) then
    Exit('');

  const Summary = Copy(Literal, 1, SummaryEnd(Literal));
  Result := Summary.Trim;
end;

class function TMarkdownDisclosures.KeyFor(const Summary: string; const Occurrence: Integer): Integer;
begin
  const Identity = Format('%s#%d', [Summary, Occurrence]);
  Result := THashBobJenkins.GetHashValue(Identity);
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

class function TMarkdownDisclosures.ClosedSections(const Document: IMarkdownNode; const Source: string;
  const State: IMarkdownDisclosureState): TArray<TMarkdownClosedSection>;
begin
  const Sections = TList<TMarkdownClosedSection>.Create;
  try
    CollectClosedSections(Document, Source, State, Sections);
    Result := Sections.ToArray;
  finally
    Sections.Free;
  end;
end;

class procedure TMarkdownDisclosures.CollectClosedSections(const Container: IMarkdownNode; const Source: string;
  const State: IMarkdownDisclosureState; const Sections: TList<TMarkdownClosedSection>);
begin
  const Hidden = HiddenChildren(Container, State);

  for var Index := 0 to Container.ChildCount - 1 do
  begin
    if Hidden[Index] then
      Continue;

    var Section: TMarkdownClosedSection;
    if TryGetClosedSection(Container, Index, Source, State, Section) then
    begin
      Sections.Add(Section);
      Continue;
    end;

    const Child = Container.Children[Index];
    if IsContainer(Child) then
      CollectClosedSections(Child, Source, State, Sections);
  end;
end;

class function TMarkdownDisclosures.TryGetClosedSection(const Container: IMarkdownNode; const Index: Integer;
  const Source: string; const State: IMarkdownDisclosureState; out Section: TMarkdownClosedSection): Boolean;
begin
  Section := Default(TMarkdownClosedSection);
  Section.Opener := Container.Children[Index];

  var OpenByDefault: Boolean;
  if IsWholeSection(Section.Opener, OpenByDefault) then
  begin
    Section.HiddenSource := ContentHtml(Section.Opener);
    Result := not IsOpen(State, Section.Opener, OpenByDefault);
    Exit;
  end;

  if IsOpener(Section.Opener, OpenByDefault) then
  begin
    Section.HiddenSource := RunHiddenSource(Container, Index, Source);
    Result := not IsOpen(State, Section.Opener, OpenByDefault);
    Exit;
  end;

  Result := False;
end;

// The source from the end of the opening block to the block that closes the
// section, or to the end of the container when nothing closes it.
class function TMarkdownDisclosures.RunHiddenSource(const Container: IMarkdownNode; const OpenerIndex: Integer;
  const Source: string): string;
begin
  const Opener = Container.Children[OpenerIndex];
  const LastChild = Container.Children[Container.ChildCount - 1];
  var HiddenEnd := LastChild.Segment.EndOffset;
  var Depth := 1;

  for var Index := OpenerIndex + 1 to Container.ChildCount - 1 do
  begin
    const Child = Container.Children[Index];

    var OpenByDefault: Boolean;
    if IsOpener(Child, OpenByDefault) then
      Inc(Depth)
    else if IsCloser(Child) then
      Dec(Depth);

    const IsSectionEnd = (Depth = 0);
    if IsSectionEnd then
    begin
      HiddenEnd := Child.Segment.StartOffset;
      Break;
    end;
  end;

  const HiddenStart = Opener.Segment.EndOffset;
  Result := Copy(Source, HiddenStart, HiddenEnd - HiddenStart);
end;

class function TMarkdownDisclosures.SectionsAround(const Document, Node: IMarkdownNode): TArray<IMarkdownNode>;
begin
  const Openers = TList<IMarkdownNode>.Create;
  try
    if CollectSectionsAround(Document, Node, Openers) then
      Result := Openers.ToArray
    else
      Result := nil;
  finally
    Openers.Free;
  end;
end;

// Walks the siblings the way HiddenChildren does, keeping the openers of the
// sections still running, and goes down into the child that holds Node.
class function TMarkdownDisclosures.CollectSectionsAround(const Container, Node: IMarkdownNode;
  const Openers: TList<IMarkdownNode>): Boolean;
begin
  const OuterCount = Openers.Count;

  for var Index := 0 to Container.ChildCount - 1 do
  begin
    const Child = Container.Children[Index];
    if IsSameNode(Child, Node) then
      Exit(True);

    var OpenByDefault: Boolean;
    if IsOpener(Child, OpenByDefault) then
    begin
      Openers.Add(Child);
      Continue;
    end;

    const ClosesASection = (IsCloser(Child) and (Openers.Count > OuterCount));
    if ClosesASection then
    begin
      Openers.Delete(Openers.Count - 1);
      Continue;
    end;

    if Encloses(Child, Node) then
    begin
      const FoundInside = CollectSectionsAround(Child, Node, Openers);
      Exit(FoundInside);
    end;
  end;

  Result := False;
end;

// The same node can reach here through different interfaces, whose
// references do not compare equal, so it is recognised by kind and place.
class function TMarkdownDisclosures.IsSameNode(const Left, Right: IMarkdownNode): Boolean;
begin
  const LeftSegment = Left.Segment;
  const RightSegment = Right.Segment;
  Result := ((Left.Kind = Right.Kind) and
             (LeftSegment.StartOffset = RightSegment.StartOffset) and
             (LeftSegment.EndOffset = RightSegment.EndOffset));
end;

class function TMarkdownDisclosures.Encloses(const Outer, Inner: IMarkdownNode): Boolean;
begin
  const OuterSegment = Outer.Segment;
  const InnerSegment = Inner.Segment;
  Result := ((InnerSegment.StartOffset >= OuterSegment.StartOffset) and
             (InnerSegment.EndOffset <= OuterSegment.EndOffset));
end;

class function TMarkdownDisclosures.IsContainer(const Node: IMarkdownNode): Boolean;
begin
  Result := (Node.Kind in [TMarkdownNodeKind.BlockQuote, TMarkdownNodeKind.List, TMarkdownNodeKind.ListItem]);
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

// Where the summary of a whole section ends: after </summary>, or after the
// opening tag when there is none.
class function TMarkdownDisclosures.SummaryEnd(const Literal: string): Integer;
begin
  const SummaryCloser = Pos(SummaryCloserTag, LowerCase(Literal));
  if SummaryCloser > 0 then
    Exit(SummaryCloser + Length(SummaryCloserTag) - 1);

  Result := Pos('>', Literal);
end;

class function TMarkdownDisclosures.HasSummary(const Literal: string): Boolean;
begin
  const SummaryStart = Pos(SummaryOpenerTag, LowerCase(Literal));
  const MentionsSummary = (SummaryStart > 0);
  if not MentionsSummary then
    Exit(False);

  const FromSummary = Copy(Literal, SummaryStart, MaxInt);
  Result := StartsWithTag(FromSummary, SummaryOpenerTag);
end;

class function TMarkdownDisclosures.DefaultSummaryHtml: string;
begin
  Result := Format('<summary>%s</summary>', [DefaultDetailsSummary]);
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
