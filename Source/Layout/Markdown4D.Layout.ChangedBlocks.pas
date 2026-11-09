unit Markdown4D.Layout.ChangedBlocks;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.Engine;

type
  // A block is compared together with the text up to the next block, so a
  // closing fence, a link definition or a blank line after it counts as part
  // of it; the first block also takes the text before it. Equal blocks at the
  // start and at the end then mean that the text before and after the change
  // is the same, character for character.
  TMarkdownChangedBlocks = class
  private
    const
      DefinitionPattern = '(?m)^ {0,3}\[[^\]]+\]:';
      FootnotePattern = '\[\^';
    class function SpanStart(const Document: IMarkdownDocument; const Index: Integer): Integer; static;
    class function SpanEnd(const Document: IMarkdownDocument; const Text: string; const Index: Integer): Integer;
      static;
    class function Span(const Document: IMarkdownDocument; const Text: string; const FirstIndex,
      Count: Integer): string; static;
    class function IsSameBlock(const Previous: IMarkdownDocument; const PreviousText: string;
      const PreviousIndex: Integer; const Current: IMarkdownDocument; const CurrentText: string;
      const CurrentIndex: Integer): Boolean; static;
    class function CommonPrefixCount(const Previous: IMarkdownDocument; const PreviousText: string;
      const Current: IMarkdownDocument; const CurrentText: string): Integer; static;
    class function CommonSuffixCount(const Previous: IMarkdownDocument; const PreviousText: string;
      const Current: IMarkdownDocument; const CurrentText: string; const PrefixCount: Integer): Integer; static;
    class function ChangesOtherBlocks(const ChangedText: string): Boolean; static;
    class function HasTableOfContents(const Document: IMarkdownDocument): Boolean; static;
    class function HasSameHiddenBlocks(const Previous, Current: IMarkdownDocument;
      const State: IMarkdownDisclosureState; const Range: TLayoutBlockRange): Boolean; static;
    class procedure ReusePreviousNodes(const Previous, Current: IMarkdownDocument; const Range: TLayoutBlockRange;
      const OffsetShift, LineShift: Integer); static;
    class procedure ShiftNode(const Node: IMarkdownNode; const OffsetShift, LineShift: Integer); static;
    class function LineCount(const Text: string): Integer; static;

  public
    // Gives Current the nodes of Previous around the blocks that changed;
    // False when the whole document has to be laid out.
    class function TryReuse(const Previous: IMarkdownDocument; const PreviousText: string;
      const Current: IMarkdownDocument; const CurrentText: string; const State: IMarkdownDisclosureState;
      out Range: TLayoutBlockRange): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.RegularExpressions,
  Markdown4D.Ast,
  Markdown4D.Extensions.Toc,
  Markdown4D.Layout.Disclosure;

class function TMarkdownChangedBlocks.TryReuse(const Previous: IMarkdownDocument; const PreviousText: string;
  const Current: IMarkdownDocument; const CurrentText: string; const State: IMarkdownDisclosureState;
  out Range: TLayoutBlockRange): Boolean;
begin
  Range := Default(TLayoutBlockRange);
  Result := False;

  const HasBoth = ((Previous <> nil) and (Current <> nil));
  if not HasBoth then
    Exit;

  const PrefixCount = CommonPrefixCount(Previous, PreviousText, Current, CurrentText);
  const SuffixCount = CommonSuffixCount(Previous, PreviousText, Current, CurrentText, PrefixCount);
  const HasNothingToReuse = ((PrefixCount = 0) and (SuffixCount = 0));
  if HasNothingToReuse then
    Exit;

  Range := TLayoutBlockRange.Create(PrefixCount, Previous.ChildCount - PrefixCount - SuffixCount,
                                    Current.ChildCount - PrefixCount - SuffixCount);

  const PreviousChange = Span(Previous, PreviousText, PrefixCount, Range.OldBlockCount);
  const CurrentChange = Span(Current, CurrentText, PrefixCount, Range.NewBlockCount);
  const AffectsOthers = (ChangesOtherBlocks(PreviousChange) or ChangesOtherBlocks(CurrentChange) or
                         HasTableOfContents(Current));
  if AffectsOthers then
    Exit;

  TMarkdownDisclosures.AssignKeys(Previous);
  TMarkdownDisclosures.AssignKeys(Current);
  if not HasSameHiddenBlocks(Previous, Current, State, Range) then
    Exit;

  const OffsetShift = Length(CurrentText) - Length(PreviousText);
  const LineShift = LineCount(CurrentText) - LineCount(PreviousText);
  ReusePreviousNodes(Previous, Current, Range, OffsetShift, LineShift);
  Result := True;
end;

class function TMarkdownChangedBlocks.CommonPrefixCount(const Previous: IMarkdownDocument;
  const PreviousText: string; const Current: IMarkdownDocument; const CurrentText: string): Integer;
begin
  const Limit = Min(Previous.ChildCount, Current.ChildCount);

  Result := 0;
  while Result < Limit do
  begin
    const IsSame = IsSameBlock(Previous, PreviousText, Result, Current, CurrentText, Result);
    if not IsSame then
      Break;

    Inc(Result);
  end;
end;

class function TMarkdownChangedBlocks.CommonSuffixCount(const Previous: IMarkdownDocument;
  const PreviousText: string; const Current: IMarkdownDocument; const CurrentText: string;
  const PrefixCount: Integer): Integer;
begin
  const Limit = Min(Previous.ChildCount, Current.ChildCount) - PrefixCount;

  Result := 0;
  while Result < Limit do
  begin
    const PreviousIndex = Previous.ChildCount - 1 - Result;
    const CurrentIndex = Current.ChildCount - 1 - Result;
    const IsSame = IsSameBlock(Previous, PreviousText, PreviousIndex, Current, CurrentText, CurrentIndex);
    if not IsSame then
      Break;

    Inc(Result);
  end;
end;

class function TMarkdownChangedBlocks.IsSameBlock(const Previous: IMarkdownDocument; const PreviousText: string;
  const PreviousIndex: Integer; const Current: IMarkdownDocument; const CurrentText: string;
  const CurrentIndex: Integer): Boolean;
begin
  const PreviousBlock = Previous.Children[PreviousIndex];
  const CurrentBlock = Current.Children[CurrentIndex];
  const IsSameKind = (PreviousBlock.Kind = CurrentBlock.Kind);
  if not IsSameKind then
    Exit(False);

  const PreviousSpan = Span(Previous, PreviousText, PreviousIndex, 1);
  const CurrentSpan = Span(Current, CurrentText, CurrentIndex, 1);
  Result := (PreviousSpan = CurrentSpan);
end;

// The text of Count blocks from FirstIndex, with what follows them up to the
// next block; empty for no blocks.
class function TMarkdownChangedBlocks.Span(const Document: IMarkdownDocument; const Text: string;
  const FirstIndex, Count: Integer): string;
begin
  const IsEmpty = (Count = 0);
  if IsEmpty then
    Exit('');

  const Start = SpanStart(Document, FirstIndex);
  const Finish = SpanEnd(Document, Text, FirstIndex + Count - 1);
  Result := Copy(Text, Start, Finish - Start);
end;

class function TMarkdownChangedBlocks.SpanStart(const Document: IMarkdownDocument; const Index: Integer): Integer;
begin
  const IsFirst = (Index = 0);
  if IsFirst then
    Exit(1);

  const Block = Document.Children[Index];
  Result := Block.Segment.StartOffset;
end;

class function TMarkdownChangedBlocks.SpanEnd(const Document: IMarkdownDocument; const Text: string;
  const Index: Integer): Integer;
begin
  const IsLast = (Index = Document.ChildCount - 1);
  if IsLast then
    Exit(Length(Text) + 1);

  const NextBlock = Document.Children[Index + 1];
  Result := NextBlock.Segment.StartOffset;
end;

// A link definition or a footnote changes how blocks elsewhere render.
class function TMarkdownChangedBlocks.ChangesOtherBlocks(const ChangedText: string): Boolean;
begin
  const HasDefinition = TRegEx.IsMatch(ChangedText, DefinitionPattern);
  const HasFootnote = TRegEx.IsMatch(ChangedText, FootnotePattern);
  Result := (HasDefinition or HasFootnote);
end;

// A table of contents lists the headings of the whole document, so any edit
// can change it.
class function TMarkdownChangedBlocks.HasTableOfContents(const Document: IMarkdownDocument): Boolean;
begin
  for var Index := 0 to Document.ChildCount - 1 do
  begin
    var Contents: IMarkdownNode;
    if TMarkdownTocMarkers.TryGetContents(Document.Children[Index], Contents) then
      Exit(True);
  end;

  Result := False;
end;

// A block the previous layout hid, or showed, has to stay so: its layout is
// reused as it was.
class function TMarkdownChangedBlocks.HasSameHiddenBlocks(const Previous, Current: IMarkdownDocument;
  const State: IMarkdownDisclosureState; const Range: TLayoutBlockRange): Boolean;
begin
  const PreviousHidden = TMarkdownDisclosures.HiddenChildren(Previous, State);
  const CurrentHidden = TMarkdownDisclosures.HiddenChildren(Current, State);
  const SuffixStart = Range.FirstBlockIndex + Range.NewBlockCount;
  const IndexShift = Range.NewBlockCount - Range.OldBlockCount;

  for var Index := 0 to Current.ChildCount - 1 do
  begin
    const IsChanged = ((Index >= Range.FirstBlockIndex) and (Index < SuffixStart));
    if IsChanged then
      Continue;

    var PreviousIndex := Index;
    const IsInSuffix = (Index >= SuffixStart);
    if IsInSuffix then
      PreviousIndex := Index - IndexShift;

    const KeepsVisibility = (PreviousHidden[PreviousIndex] = CurrentHidden[Index]);
    if not KeepsVisibility then
      Exit(False);
  end;

  Result := True;
end;

class procedure TMarkdownChangedBlocks.ReusePreviousNodes(const Previous, Current: IMarkdownDocument;
  const Range: TLayoutBlockRange; const OffsetShift, LineShift: Integer);
begin
  var Blocks: TArray<IMarkdownNode>;
  SetLength(Blocks, Current.ChildCount);

  for var Index := 0 to Current.ChildCount - 1 do
  begin
    Blocks[Index] := Current.Children[Index];
  end;

  for var Index := 0 to Range.FirstBlockIndex - 1 do
  begin
    Blocks[Index] := Previous.Children[Index];
  end;

  const CurrentSuffixStart = Range.FirstBlockIndex + Range.NewBlockCount;
  const PreviousSuffixStart = Range.FirstBlockIndex + Range.OldBlockCount;
  for var Index := CurrentSuffixStart to Current.ChildCount - 1 do
  begin
    const Reused = Previous.Children[PreviousSuffixStart + Index - CurrentSuffixStart];
    ShiftNode(Reused, OffsetShift, LineShift);
    Blocks[Index] := Reused;
  end;

  const Document = Current as TMarkdownAstNode;
  for var Index := Current.ChildCount - 1 downto 0 do
  begin
    Document.DeleteChild(Index);
  end;

  for var Block in Blocks do
  begin
    Document.AddChild(Block);
  end;
end;

// A node the parser made up has no place in the text and keeps none.
class procedure TMarkdownChangedBlocks.ShiftNode(const Node: IMarkdownNode; const OffsetShift, LineShift: Integer);
begin
  const AstNode = Node as TMarkdownAstNode;
  const Segment = Node.Segment;
  const HasPlace = (Segment.EndOffset > 0);
  if HasPlace then
  begin
    const Shifted = TMarkdownSegment.Create(Segment.StartOffset + OffsetShift, Segment.EndOffset + OffsetShift);
    AstNode.SetSegment(Shifted);
  end;

  if AstNode is TMarkdownHeadingNode then
  begin
    const Heading = TMarkdownHeadingNode(AstNode);
    Heading.SetSourceLine(Heading.GetSourceLine + LineShift);
  end;

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    ShiftNode(Node.Children[Index], OffsetShift, LineShift);
  end;
end;

class function TMarkdownChangedBlocks.LineCount(const Text: string): Integer;
begin
  Result := 1;
  for var Character in Text do
  begin
    const IsLineBreak = (Character = #10);
    if IsLineBreak then
      Inc(Result);
  end;
end;

end.
