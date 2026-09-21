unit Markdown4D.Editor.InlineStyle;

{$SCOPEDENUMS ON}

// Putting a style on a stretch of markdown, or taking it off, by reading what
// the markdown already says instead of adding another pair of markers. The
// parser answers where the styles, the code spans and the links are, so the
// result holds for text nobody wrote by hand.

interface

uses
  Markdown4D.Ast.Interfaces;

type
  TMarkdownInlineStyle = (Strong, Emphasis);

  // The one replacement that carries out the command, with where the selection
  // belongs afterwards. Every offset counts from 0, the way the caret does.
  TMarkdownInlineStyleEdit = record
    Start: Integer;
    Length: Integer;
    Replacement: string;
    SelectionStart: Integer;
    SelectionLength: Integer;
  end;

  TMarkdownInlineStyleNormalizer = class
  private
    class function TryTrimRange(const Text: string; const RangeStart, RangeLength: Integer;
                                out Range: TMarkdownSegment): Boolean; static;
    class function TryFindHost(const Document: IMarkdownNode; const Range: TMarkdownSegment;
                               out Host: IMarkdownNode): Boolean; static;
    class function DescendantsOf(const Node: IMarkdownNode): TArray<IMarkdownNode>; static;
    class function AllCarrySource(const Nodes: TArray<IMarkdownNode>): Boolean; static;
    class function KindOf(const Style: TMarkdownInlineStyle): TMarkdownNodeKind; static;
    class function IsKeptWhole(const Kind: TMarkdownNodeKind): Boolean; static;
    class function HoldsStyledTextInside(const Kind: TMarkdownNodeKind): Boolean; static;
    class function ContentSpanOf(const Node: IMarkdownNode): TMarkdownSegment; static;
    class function Overlaps(const Left, Right: TMarkdownSegment): Boolean; static;
    class function Covers(const Outer, Inner: TMarkdownSegment): Boolean; static;
    class function Joined(const Left, Right: TMarkdownSegment): TMarkdownSegment; static;
    class function CoveredByAny(const Spans: TArray<TMarkdownSegment>; const Position: Integer): Boolean; static;
    class function WithoutSplitEscapes(const Text: string; const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function StartsAnEscape(const Text: string; const Index: Integer): Boolean; static;
    class function WidenedOverWholeNodes(const Nodes: TArray<IMarkdownNode>; const TargetKind: TMarkdownNodeKind;
                                         const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function TargetsOverlapping(const Nodes: TArray<IMarkdownNode>; const TargetKind: TMarkdownNodeKind;
                                      const Range: TMarkdownSegment): TArray<IMarkdownNode>; static;
    class function SpanOverAll(const Range: TMarkdownSegment;
                               const Targets: TArray<IMarkdownNode>): TMarkdownSegment; static;
    class function MarkersOf(const Targets: TArray<IMarkdownNode>): TArray<TMarkdownSegment>; static;
    class function ContentsOf(const Targets: TArray<IMarkdownNode>): TArray<TMarkdownSegment>; static;
    class function MarkerFlags(const Affected: TMarkdownSegment;
                               const Markers: TArray<TMarkdownSegment>): TArray<Boolean>; static;
    class function StyledFlags(const Range, Affected: TMarkdownSegment;
                                 const Contents: TArray<TMarkdownSegment>;
                                 const IsTakingOff: Boolean): TArray<Boolean>; static;
    class function IsTakingOff(const Range: TMarkdownSegment;
                               const Markers, Contents: TArray<TMarkdownSegment>): Boolean; static;
    class function WithoutWhitespaceEdges(const Text: string; const Affected: TMarkdownSegment;
                                          const IsMarker, Styled: TArray<Boolean>): TArray<Boolean>; static;
    class function EditFor(const Text: string; const Range, Affected: TMarkdownSegment;
                           const IsMarker, Styled: TArray<Boolean>;
                           const Marker: string): TMarkdownInlineStyleEdit; static;

  public
    // Answers the replacement that makes the whole range carry Style, or, when
    // the range already carries it throughout, the one that takes it off. Marks
    // of the same style that the range only half covers are taken in rather
    // than cut through, and a range that would end inside a code span, a link
    // or a formula is widened to take that whole thing in.
    //
    // False when the range is not one stretch of inline text: across a block
    // boundary, inside a code block, or somewhere that carries no source
    // offsets of its own, such as a table cell.
    class function TryNormalize(const Text: string; const RangeStart, RangeLength: Integer;
                                const Style: TMarkdownInlineStyle;
                                out Edit: TMarkdownInlineStyleEdit): Boolean; static;
    // How the style is spelled in markdown.
    class function MarkerOf(const Style: TMarkdownInlineStyle): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Text.Unescape;

class function TMarkdownInlineStyleNormalizer.TryNormalize(const Text: string;
  const RangeStart, RangeLength: Integer; const Style: TMarkdownInlineStyle;
  out Edit: TMarkdownInlineStyleEdit): Boolean;
begin
  Edit := Default(TMarkdownInlineStyleEdit);
  Result := False;

  var Range: TMarkdownSegment;
  if not TryTrimRange(Text, RangeStart, RangeLength, Range) then
    Exit;

  const Document = TMarkdown.Parse(Text, TMarkdownDialect.Gfm);

  var Host: IMarkdownNode;
  if not TryFindHost(Document, Range, Host) then
    Exit;

  const Inlines = DescendantsOf(Host);
  if not AllCarrySource(Inlines) then
    Exit;

  const TargetKind = KindOf(Style);
  const Whole = WithoutSplitEscapes(Text, Range);
  const Widened = WidenedOverWholeNodes(Inlines, TargetKind, Whole);
  const Targets = TargetsOverlapping(Inlines, TargetKind, Widened);

  const Affected = SpanOverAll(Widened, Targets);
  const Markers = MarkersOf(Targets);
  const Contents = ContentsOf(Targets);

  const TakingOff = IsTakingOff(Widened, Markers, Contents);
  const IsMarker = MarkerFlags(Affected, Markers);
  const Styled = StyledFlags(Widened, Affected, Contents, TakingOff);
  const Trimmed = WithoutWhitespaceEdges(Text, Affected, IsMarker, Styled);

  Edit := EditFor(Text, Widened, Affected, IsMarker, Trimmed, MarkerOf(Style));
  Result := True;
end;

// Markers standing against the whitespace inside them read as ordinary
// characters, so the range is pulled in to the text it really covers.
class function TMarkdownInlineStyleNormalizer.MarkerOf(const Style: TMarkdownInlineStyle): string;
begin
  case Style of
    TMarkdownInlineStyle.Strong   : Result := Asterisk + Asterisk;
    TMarkdownInlineStyle.Emphasis : Result := Asterisk;
  else
    raise ENotSupportedException.CreateFmt('Unsupported inline style: %d', [Ord(Style)]);
  end;
end;

class function TMarkdownInlineStyleNormalizer.TryTrimRange(const Text: string;
  const RangeStart, RangeLength: Integer; out Range: TMarkdownSegment): Boolean;
begin
  Range := Default(TMarkdownSegment);

  const Limit = Length(Text) + 1;

  var First := RangeStart + 1;
  var Last := RangeStart + RangeLength + 1;

  if First < 1 then
    First := 1;
  if Last > Limit then
    Last := Limit;

  while (First < Last) and Text[First].IsWhiteSpace do
  begin
    Inc(First);
  end;

  while (Last > First) and Text[Last - 1].IsWhiteSpace do
  begin
    Dec(Last);
  end;

  Range := TMarkdownSegment.Create(First, Last);
  Result := (Last > First);
end;

// A style lives inside one paragraph or heading; a range that does not sit in
// one of them has no single stretch of inline text to work on.
class function TMarkdownInlineStyleNormalizer.TryFindHost(const Document: IMarkdownNode;
  const Range: TMarkdownSegment; out Host: IMarkdownNode): Boolean;
begin
  Host := nil;

  var Pending: TArray<IMarkdownNode> := [Document];

  while Length(Pending) > 0 do
  begin
    const Node = Pending[High(Pending)];
    SetLength(Pending, Length(Pending) - 1);

    const IsInlineHost = (Node.Kind = TMarkdownNodeKind.Paragraph) or (Node.Kind = TMarkdownNodeKind.Heading);
    if IsInlineHost and Covers(Node.Segment, Range) then
    begin
      Host := Node;
      Result := True;
      Exit;
    end;

    for var Index := 0 to Node.ChildCount - 1 do
    begin
      Pending := Pending + [Node.Children[Index]];
    end;
  end;

  Result := False;
end;

class function TMarkdownInlineStyleNormalizer.DescendantsOf(const Node: IMarkdownNode): TArray<IMarkdownNode>;
begin
  Result := [];

  var Pending: TArray<IMarkdownNode> := [Node];

  while Length(Pending) > 0 do
  begin
    const Current = Pending[High(Pending)];
    SetLength(Pending, Length(Pending) - 1);

    for var Index := 0 to Current.ChildCount - 1 do
    begin
      const Child = Current.Children[Index];
      Result := Result + [Child];
      Pending := Pending + [Child];
    end;
  end;
end;

// A node an extension built, or one inside a table cell, says nothing about
// where it came from. Moving markers around it would be guesswork.
class function TMarkdownInlineStyleNormalizer.AllCarrySource(const Nodes: TArray<IMarkdownNode>): Boolean;
begin
  for var Node in Nodes do
  begin
    const HasSource = (Node.Segment.StartOffset > 0) and (Node.Segment.EndOffset >= Node.Segment.StartOffset);
    if not HasSource then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

class function TMarkdownInlineStyleNormalizer.KindOf(const Style: TMarkdownInlineStyle): TMarkdownNodeKind;
begin
  case Style of
    TMarkdownInlineStyle.Strong   : Result := TMarkdownNodeKind.Strong;
    TMarkdownInlineStyle.Emphasis : Result := TMarkdownNodeKind.Emphasis;
  else
    raise ENotSupportedException.CreateFmt('Unsupported inline style: %d', [Ord(Style)]);
  end;
end;

// Things a marker may not be dropped into: their source spells something other
// than the text it shows.
class function TMarkdownInlineStyleNormalizer.IsKeptWhole(const Kind: TMarkdownNodeKind): Boolean;
begin
  Result := (Kind = TMarkdownNodeKind.CodeSpan) or (Kind = TMarkdownNodeKind.Math) or
    (Kind = TMarkdownNodeKind.InlineHtml) or (Kind = TMarkdownNodeKind.Autolink) or
    (Kind = TMarkdownNodeKind.Link) or (Kind = TMarkdownNodeKind.Image) or
    (Kind = TMarkdownNodeKind.CustomInline) or (Kind = TMarkdownNodeKind.Emphasis) or
    (Kind = TMarkdownNodeKind.Strong);
end;

// A link label and the text inside a style take a style of their own, so a
// range that stays within one of those leaves the node alone.
class function TMarkdownInlineStyleNormalizer.HoldsStyledTextInside(const Kind: TMarkdownNodeKind): Boolean;
begin
  Result := (Kind = TMarkdownNodeKind.Link) or (Kind = TMarkdownNodeKind.Image) or
    (Kind = TMarkdownNodeKind.CustomInline) or (Kind = TMarkdownNodeKind.Emphasis) or
    (Kind = TMarkdownNodeKind.Strong);
end;

// What sits between the markers: from the first child to the last one.
class function TMarkdownInlineStyleNormalizer.ContentSpanOf(const Node: IMarkdownNode): TMarkdownSegment;
begin
  const HasChildren = (Node.ChildCount > 0);
  if not HasChildren then
  begin
    Result := Node.Segment;
    Exit;
  end;

  const First = Node.Children[0].Segment;
  const Last = Node.Children[Node.ChildCount - 1].Segment;

  Result := TMarkdownSegment.Create(First.StartOffset, Last.EndOffset);
end;

class function TMarkdownInlineStyleNormalizer.Overlaps(const Left, Right: TMarkdownSegment): Boolean;
begin
  Result := (Left.StartOffset < Right.EndOffset) and (Right.StartOffset < Left.EndOffset);
end;

class function TMarkdownInlineStyleNormalizer.Covers(const Outer, Inner: TMarkdownSegment): Boolean;
begin
  Result := (Outer.StartOffset <= Inner.StartOffset) and (Outer.EndOffset >= Inner.EndOffset);
end;

class function TMarkdownInlineStyleNormalizer.Joined(const Left, Right: TMarkdownSegment): TMarkdownSegment;
begin
  var First := Left.StartOffset;
  if Right.StartOffset < First then
    First := Right.StartOffset;

  var Last := Left.EndOffset;
  if Right.EndOffset > Last then
    Last := Right.EndOffset;

  Result := TMarkdownSegment.Create(First, Last);
end;

class function TMarkdownInlineStyleNormalizer.CoveredByAny(const Spans: TArray<TMarkdownSegment>;
  const Position: Integer): Boolean;
begin
  for var Span in Spans do
  begin
    const IsInside = (Position >= Span.StartOffset) and (Position < Span.EndOffset);
    if IsInside then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

// A marker dropped between a backslash and the character it protects would be
// escaped itself, so an end that splits an escape steps past it.
class function TMarkdownInlineStyleNormalizer.WithoutSplitEscapes(const Text: string;
  const Range: TMarkdownSegment): TMarkdownSegment;
begin
  var First := Range.StartOffset;
  var Last := Range.EndOffset;

  if StartsAnEscape(Text, First - 1) then
    Dec(First);

  if StartsAnEscape(Text, Last - 1) then
    Inc(Last);

  Result := TMarkdownSegment.Create(First, Last);
end;

class function TMarkdownInlineStyleNormalizer.StartsAnEscape(const Text: string; const Index: Integer): Boolean;
begin
  const IsBackslash = (Index >= 1) and (Index < Length(Text)) and (Text[Index] = Backslash);
  if not IsBackslash then
  begin
    Result := False;
    Exit;
  end;

  if not TMarkdownUnescape.IsAsciiPunctuation(Text[Index + 1]) then
  begin
    Result := False;
    Exit;
  end;

  var Run := 0;
  while (Index - Run >= 1) and (Text[Index - Run] = Backslash) do
  begin
    Inc(Run);
  end;

  Result := Odd(Run);
end;

// A range that ends inside something the parser reads as one piece takes that
// whole piece in, so the markers land outside it.
class function TMarkdownInlineStyleNormalizer.WidenedOverWholeNodes(const Nodes: TArray<IMarkdownNode>;
  const TargetKind: TMarkdownNodeKind; const Range: TMarkdownSegment): TMarkdownSegment;
begin
  Result := Range;

  var Grew := True;

  while Grew do
  begin
    Grew := False;

    for var Node in Nodes do
    begin
      if Node.Kind = TargetKind then
        Continue;

      if not IsKeptWhole(Node.Kind) then
        Continue;

      if not Overlaps(Node.Segment, Result) then
        Continue;

      if Covers(Result, Node.Segment) then
        Continue;

      const Content = ContentSpanOf(Node);
      const StaysInside = HoldsStyledTextInside(Node.Kind) and Covers(Content, Result);
      if StaysInside then
        Continue;

      Result := Joined(Result, Node.Segment);
      Grew := True;
    end;
  end;
end;

class function TMarkdownInlineStyleNormalizer.TargetsOverlapping(const Nodes: TArray<IMarkdownNode>;
  const TargetKind: TMarkdownNodeKind; const Range: TMarkdownSegment): TArray<IMarkdownNode>;
begin
  Result := [];

  for var Node in Nodes do
  begin
    const IsTarget = (Node.Kind = TargetKind) and Overlaps(Node.Segment, Range);
    if IsTarget then
      Result := Result + [Node];
  end;
end;

class function TMarkdownInlineStyleNormalizer.SpanOverAll(const Range: TMarkdownSegment;
  const Targets: TArray<IMarkdownNode>): TMarkdownSegment;
begin
  Result := Range;

  for var Target in Targets do
  begin
    Result := Joined(Result, Target.Segment);
  end;
end;

// The characters that open and close each of the pairs about to be rewritten.
class function TMarkdownInlineStyleNormalizer.MarkersOf(
  const Targets: TArray<IMarkdownNode>): TArray<TMarkdownSegment>;
begin
  Result := [];

  for var Target in Targets do
  begin
    const Content = ContentSpanOf(Target);
    const Opening = TMarkdownSegment.Create(Target.Segment.StartOffset, Content.StartOffset);
    const Closing = TMarkdownSegment.Create(Content.EndOffset, Target.Segment.EndOffset);

    Result := Result + [Opening] + [Closing];
  end;
end;

class function TMarkdownInlineStyleNormalizer.ContentsOf(
  const Targets: TArray<IMarkdownNode>): TArray<TMarkdownSegment>;
begin
  Result := [];

  for var Target in Targets do
  begin
    Result := Result + [ContentSpanOf(Target)];
  end;
end;

class function TMarkdownInlineStyleNormalizer.MarkerFlags(const Affected: TMarkdownSegment;
  const Markers: TArray<TMarkdownSegment>): TArray<Boolean>;
begin
  SetLength(Result, Affected.Length);

  for var Index := 0 to High(Result) do
  begin
    Result[Index] := CoveredByAny(Markers, Affected.StartOffset + Index);
  end;
end;

// Taking the style off leaves it on what the range did not cover; putting it
// on adds the range to what already carried it.
class function TMarkdownInlineStyleNormalizer.StyledFlags(const Range, Affected: TMarkdownSegment;
  const Contents: TArray<TMarkdownSegment>; const IsTakingOff: Boolean): TArray<Boolean>;
begin
  SetLength(Result, Affected.Length);

  for var Index := 0 to High(Result) do
  begin
    const Position = Affected.StartOffset + Index;
    const WasStyled = CoveredByAny(Contents, Position);
    const IsInRange = (Position >= Range.StartOffset) and (Position < Range.EndOffset);

    if IsTakingOff then
      Result[Index] := WasStyled and not IsInRange
    else
      Result[Index] := WasStyled or IsInRange;
  end;
end;

// The command takes the style off when every character it was pointed at
// already carries it, and puts it on otherwise.
class function TMarkdownInlineStyleNormalizer.IsTakingOff(const Range: TMarkdownSegment;
  const Markers, Contents: TArray<TMarkdownSegment>): Boolean;
begin
  var Seen := 0;

  for var Position := Range.StartOffset to Range.EndOffset - 1 do
  begin
    if CoveredByAny(Markers, Position) then
      Continue;

    Inc(Seen);

    if not CoveredByAny(Contents, Position) then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := (Seen > 0);
end;

// Markers may not stand against the whitespace they would enclose, so the
// whitespace at either end of a stretch stays outside them. Markers of the
// style being changed are about to go, so they do not break a stretch in two.
class function TMarkdownInlineStyleNormalizer.WithoutWhitespaceEdges(const Text: string;
  const Affected: TMarkdownSegment; const IsMarker, Styled: TArray<Boolean>): TArray<Boolean>;
begin
  Result := Copy(Styled);

  var RunStart := -1;
  var RunEnd := -1;

  for var Index := 0 to Length(Result) do
  begin
    const IsPastEnd = (Index = Length(Result));
    const Continues = (not IsPastEnd) and (IsMarker[Index] or Result[Index]);

    if Continues then
    begin
      if not IsMarker[Index] then
      begin
        if RunStart < 0 then
          RunStart := Index;

        RunEnd := Index;
      end;

      Continue;
    end;

    while (RunStart >= 0) and (RunStart <= RunEnd) and Text[Affected.StartOffset + RunStart].IsWhiteSpace do
    begin
      Result[RunStart] := False;
      Inc(RunStart);
    end;

    while (RunStart >= 0) and (RunEnd >= RunStart) and Text[Affected.StartOffset + RunEnd].IsWhiteSpace do
    begin
      Result[RunEnd] := False;
      Dec(RunEnd);
    end;

    RunStart := -1;
    RunEnd := -1;
  end;
end;

class function TMarkdownInlineStyleNormalizer.EditFor(const Text: string; const Range, Affected: TMarkdownSegment;
  const IsMarker, Styled: TArray<Boolean>; const Marker: string): TMarkdownInlineStyleEdit;
begin
  Result := Default(TMarkdownInlineStyleEdit);
  Result.Start := Affected.StartOffset - 1;
  Result.Length := Affected.Length;

  const Builder = TStringBuilder.Create;
  try
    var IsOpen := False;
    var SelectionFrom := -1;
    var SelectionTo := 0;

    for var Index := 0 to Length(Styled) - 1 do
    begin
      if IsMarker[Index] then
        Continue;

      if Styled[Index] <> IsOpen then
      begin
        Builder.Append(Marker);
        IsOpen := Styled[Index];
      end;

      const Position = Affected.StartOffset + Index;
      const IsInRange = (Position >= Range.StartOffset) and (Position < Range.EndOffset);

      if IsInRange and (SelectionFrom < 0) then
        SelectionFrom := Builder.Length;

      Builder.Append(Text[Position]);

      if IsInRange then
        SelectionTo := Builder.Length;
    end;

    if IsOpen then
      Builder.Append(Marker);

    Result.Replacement := Builder.ToString;

    if SelectionFrom < 0 then
      SelectionFrom := 0;

    Result.SelectionStart := Result.Start + SelectionFrom;
    Result.SelectionLength := SelectionTo - SelectionFrom;
  finally
    Builder.Free;
  end;
end;

end.
