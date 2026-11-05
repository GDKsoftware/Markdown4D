unit Markdown4D.Layout.SelectedMarkdown;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces;

type
  // The markdown a reader means when copying a selection as markdown: within one
  // line the selected source with the markup directly around it, over several
  // lines whole source lines, a table always whole, and a display formula with
  // the line that closes it.
  TMarkdownSelectedSource = record
  private
    const
      LineFeed = #10;
      CarriageReturn = #13;
      Delimiters = ['*', '_', '~', '`'];
      DisplayMathMarker = '$$';
      ContainerPrefix = [' ', #9, '>'];
      Backslash = '\';
      OpenBrace = '{';
      CloseBrace = '}';
    class function WidenOverMathBlocks(const Source: string; const Node: IMarkdownNode;
                                       const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function WidenOverTables(const Node: IMarkdownNode; const Range: TMarkdownSegment): TMarkdownSegment; static;
    // Where a display formula block ends in Source together with the line that
    // closes it; a block left open ends where its segment does.
    class function MathBlockEnd(const Source: string; const Block: IMarkdownNode): Integer; static;
    class function Overlaps(const Left, Right: TMarkdownSegment): Boolean; static;
    class function SpansLines(const Source: string; const Range: TMarkdownSegment): Boolean; static;
    class function WholeLines(const Source: string; const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function WidenOverMarkup(const Source: string; const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function WidenedOnce(const Source: string; const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function WidenedOverLink(const Source: string; const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function WholeFormula(const Source: string; const Math: IMarkdownNode;
                                const IsBlock: Boolean): TMarkdownSegment; static;
    class function TryFindMath(const Node: IMarkdownNode; const Range: TMarkdownSegment; out Math: IMarkdownMath;
                               out IsBlock: Boolean): Boolean; static;
    class function IsBlockContainer(const Node: IMarkdownNode): Boolean; static;
    class function TryWidenInsideMath(const Source: string; const Document: IMarkdownNode;
                                      const Range: TMarkdownSegment; out Widened: TMarkdownSegment): Boolean; static;
    class function WidenedTeX(const Source: string; const Range, Literal: TMarkdownSegment): TMarkdownSegment; static;
    class function WidenedOverMathLink(const Source: string;
                                       const Range, Literal: TMarkdownSegment): TMarkdownSegment; static;
    class function MatchingBrace(const Source: string; const Index, Direction: Integer;
                                 const Literal: TMarkdownSegment): Integer; static;
    class function IsLetterAt(const Source: string; const Index: Integer): Boolean; static;
    class function IsBraceAt(const Source: string; const Index: Integer; const Brace: Char): Boolean; static;

  public
    // Selection is the stretch of Source the selected text was rendered from.
    // Line ends come out as the platform writes them.
    class function Extract(const Source: string; const Document: IMarkdownNode;
                           const Selection: TMarkdownSegment): string; static;
    class function WithPlatformLineBreaks(const Text: string): string; static;
    // Whether Math is a display formula block of Document rather than a
    // formula inside a paragraph, a heading or a table cell.
    class function IsMathBlock(const Document, Math: IMarkdownNode): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D.Layout.SourceMapping;

class function TMarkdownSelectedSource.Extract(const Source: string; const Document: IMarkdownNode;
  const Selection: TMarkdownSegment): string;
begin
  var Range: TMarkdownSegment;
  if TryWidenInsideMath(Source, Document, Selection, Range) then
  begin
    Result := WithPlatformLineBreaks(Copy(Source, Range.StartOffset, Range.Length));
    Exit;
  end;

  Range := WidenOverTables(Document, Selection);
  Range := WidenOverMathBlocks(Source, Document, Range);

  if SpansLines(Source, Range) then
    Range := WholeLines(Source, Range)
  else
    Range := WidenOverMarkup(Source, Range);

  const Selected = Copy(Source, Range.StartOffset, Range.Length);
  Result := WithPlatformLineBreaks(Selected);
end;

// A formula with its markers, a display formula block with the line that
// closes it.
class function TMarkdownSelectedSource.WholeFormula(const Source: string; const Math: IMarkdownNode;
  const IsBlock: Boolean): TMarkdownSegment;
begin
  Result := Math.Segment;
  if IsBlock then
    Result := TMarkdownSegment.Create(Result.StartOffset, MathBlockEnd(Source, Math));
end;

// The formula that holds all of Range. A table is copied whole whatever part
// of it is selected, so a formula in one is not looked for.
class function TMarkdownSelectedSource.TryFindMath(const Node: IMarkdownNode; const Range: TMarkdownSegment;
  out Math: IMarkdownMath; out IsBlock: Boolean): Boolean;
begin
  Math := nil;
  IsBlock := False;
  Result := False;

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    const Child = Node.Children[Index];
    const Segment = Child.Segment;
    const Encloses = ((Segment.StartOffset <= Range.StartOffset) and (Range.EndOffset <= Segment.EndOffset));
    if (not Encloses) or (Child.Kind = TMarkdownNodeKind.Table) then
      Continue;

    if Supports(Child, IMarkdownMath, Math) then
    begin
      IsBlock := IsBlockContainer(Node);
      Result := True;
      Exit;
    end;

    Result := TryFindMath(Child, Range, Math, IsBlock);
    Exit;
  end;
end;

class function TMarkdownSelectedSource.IsBlockContainer(const Node: IMarkdownNode): Boolean;
begin
  Result := (Node.Kind in [TMarkdownNodeKind.Document, TMarkdownNodeKind.BlockQuote, TMarkdownNodeKind.List,
                           TMarkdownNodeKind.ListItem]);
end;

class function TMarkdownSelectedSource.IsMathBlock(const Document, Math: IMarkdownNode): Boolean;
begin
  Result := False;
  if (Document = nil) or not IsBlockContainer(Document) then
    Exit;

  for var Index := 0 to Document.ChildCount - 1 do
  begin
    const Child = Document.Children[Index];
    if (Child = Math) or IsMathBlock(Child, Math) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

// Within one formula a reader copies TeX that still works: a command whole,
// braces balanced, a command with the groups it reads. All of the formula
// copies as the formula, markers included.
class function TMarkdownSelectedSource.TryWidenInsideMath(const Source: string; const Document: IMarkdownNode;
  const Range: TMarkdownSegment; out Widened: TMarkdownSegment): Boolean;
begin
  Widened := Range;

  var Math: IMarkdownMath;
  var IsBlock: Boolean;
  if (Document = nil) or not TryFindMath(Document, Range, Math, IsBlock) then
  begin
    Result := False;
    Exit;
  end;

  Result := True;

  var LiteralStart: Integer;
  if not TMarkdownSourceMapper.TryMathLiteralStart(Source, Math, LiteralStart) then
  begin
    Widened := WholeFormula(Source, Math, IsBlock);
    Exit;
  end;

  const LiteralEnd = LiteralStart + Length(Math.Literal);
  const Literal = TMarkdownSegment.Create(LiteralStart, LiteralEnd);
  const Inner = TMarkdownSegment.Create(Max(Range.StartOffset, LiteralStart), Min(Range.EndOffset, LiteralEnd));
  Widened := WidenedOverMathLink(Source, WidenedTeX(Source, Inner, Literal), Literal);

  const IsWholeFormula = ((Widened.StartOffset <= LiteralStart) and (Widened.EndOffset >= LiteralEnd));
  if IsWholeFormula then
    Widened := WholeFormula(Source, Math, IsBlock);
end;

class function TMarkdownSelectedSource.WidenedTeX(const Source: string;
  const Range, Literal: TMarkdownSegment): TMarkdownSegment;
begin
  var Start := Range.StartOffset;
  var Stop := Range.EndOffset;

  while True do
  begin
    const PreviousStart = Start;
    const PreviousStop = Stop;

    // A command cut at either end still names a command once it is whole.
    var Index := Start;
    while (Index > Literal.StartOffset) and IsLetterAt(Source, Index - 1) do
      Dec(Index);
    if (Index > Literal.StartOffset) and (Source[Index - 1] = Backslash) and
       (IsLetterAt(Source, Start) or (Index = Start)) then
      Start := Index - 1;

    Index := Stop - 1;
    while (Index >= Start) and IsLetterAt(Source, Index) do
      Dec(Index);
    const EndsInCommand = ((Index >= Start) and (Source[Index] = Backslash));
    if EndsInCommand then
    begin
      while (Stop < Literal.EndOffset) and IsLetterAt(Source, Stop) do
        Inc(Stop);
    end;

    // A brace the range closes or opens without its partner would break the
    // pasted TeX, so the range reaches out to the partner.
    var Open := 0;
    var Unopened := 0;
    for var Position := Start to Stop - 1 do
    begin
      if IsBraceAt(Source, Position, OpenBrace) then
        Inc(Open)
      else if IsBraceAt(Source, Position, CloseBrace) then
      begin
        if Open > 0 then
          Dec(Open)
        else
          Inc(Unopened);
      end;
    end;

    while (Unopened > 0) and (Start > Literal.StartOffset) do
    begin
      Dec(Start);
      if IsBraceAt(Source, Start, CloseBrace) then
        Inc(Unopened)
      else if IsBraceAt(Source, Start, OpenBrace) then
        Dec(Unopened);
    end;

    while (Open > 0) and (Stop < Literal.EndOffset) do
    begin
      if IsBraceAt(Source, Stop, OpenBrace) then
        Inc(Open)
      else if IsBraceAt(Source, Stop, CloseBrace) then
        Dec(Open);
      Inc(Stop);
    end;

    // A group starting the range belongs to the command in front of it, and a
    // command takes the groups that follow it.
    if IsBraceAt(Source, Start, OpenBrace) and (Start > Literal.StartOffset) and IsLetterAt(Source, Start - 1) then
    begin
      Index := Start - 1;
      while (Index > Literal.StartOffset) and IsLetterAt(Source, Index - 1) do
        Dec(Index);
      if (Index > Literal.StartOffset) and (Source[Index - 1] = Backslash) then
        Start := Index - 1;
    end;

    const StartsWithCommand = ((Start < Stop) and (Source[Start] = Backslash) and IsLetterAt(Source, Start + 1));
    if StartsWithCommand and IsBraceAt(Source, Stop, OpenBrace) then
    begin
      var Depth := 0;
      repeat
        if IsBraceAt(Source, Stop, OpenBrace) then
          Inc(Depth)
        else if IsBraceAt(Source, Stop, CloseBrace) then
          Dec(Depth);
        Inc(Stop);
      until (Depth = 0) or (Stop >= Literal.EndOffset);
    end;

    const IsSettled = ((Start = PreviousStart) and (Stop = PreviousStop));
    if IsSettled then
      Break;
  end;

  Result := TMarkdownSegment.Create(Start, Stop);
end;

// Like the text of a markdown link, the text of \href or the address of \url
// copies as the whole command, so the link survives the copy.
class function TMarkdownSelectedSource.WidenedOverMathLink(const Source: string;
  const Range, Literal: TMarkdownSegment): TMarkdownSegment;
begin
  Result := Range;

  var Depth := 0;
  var Index := Range.StartOffset - 1;
  while Index >= Literal.StartOffset do
  begin
    if IsBraceAt(Source, Index, CloseBrace) then
      Inc(Depth)
    else if IsBraceAt(Source, Index, OpenBrace) and (Depth > 0) then
      Dec(Depth)
    else if IsBraceAt(Source, Index, OpenBrace) then
    begin
      // Index opens a group around the range: the address of \url, or the
      // text of \href when a group comes right before it.
      const FollowsGroup = ((Index > Literal.StartOffset) and IsBraceAt(Source, Index - 1, CloseBrace));
      var CommandEnd := Index;
      if FollowsGroup then
        CommandEnd := MatchingBrace(Source, Index - 1, -1, Literal);

      const IsHref = (FollowsGroup and (CommandEnd > 0) and (Copy(Source, CommandEnd - 5, 5) = '\href'));
      const IsUrl = ((not FollowsGroup) and (Copy(Source, Index - 4, 4) = '\url'));
      const Close = MatchingBrace(Source, Index, 1, Literal);
      if (IsHref or IsUrl) and (Close > 0) then
      begin
        var Start := Index - 4;
        if IsHref then
          Start := CommandEnd - 5;
        Result := TMarkdownSegment.Create(Min(Start, Result.StartOffset), Max(Close + 1, Result.EndOffset));
      end;
    end;

    Dec(Index);
  end;
end;

// The brace that closes (Direction 1) or opens (Direction -1) the one at
// Index, or 0 when the formula leaves it unmatched.
class function TMarkdownSelectedSource.MatchingBrace(const Source: string; const Index, Direction: Integer;
  const Literal: TMarkdownSegment): Integer;
begin
  var Depth := 0;
  var Position := Index;
  while (Position >= Literal.StartOffset) and (Position < Literal.EndOffset) do
  begin
    if IsBraceAt(Source, Position, OpenBrace) then
      Inc(Depth, Direction)
    else if IsBraceAt(Source, Position, CloseBrace) then
      Dec(Depth, Direction);

    if Depth = 0 then
    begin
      Result := Position;
      Exit;
    end;

    Inc(Position, Direction);
  end;

  Result := 0;
end;

class function TMarkdownSelectedSource.IsLetterAt(const Source: string; const Index: Integer): Boolean;
begin
  Result := (Index >= 1) and (Index <= Length(Source)) and CharInSet(Source[Index], ['a'..'z', 'A'..'Z']);
end;

// An escaped brace, \{, is a character of the formula, not a group.
class function TMarkdownSelectedSource.IsBraceAt(const Source: string; const Index: Integer;
  const Brace: Char): Boolean;
begin
  Result := (Index >= 1) and (Index <= Length(Source)) and (Source[Index] = Brace) and
            not ((Index > 1) and (Source[Index - 1] = Backslash));
end;

class function TMarkdownSelectedSource.WithPlatformLineBreaks(const Text: string): string;
begin
  const LineFeedsOnly = Text.Replace(CarriageReturn + LineFeed, LineFeed);
  Result := LineFeedsOnly.Replace(LineFeed, sLineBreak);
end;

// The segment of a display formula block ends with its last line, before the
// $$ that closes it; pasted without that line, the formula would swallow
// everything after it.
class function TMarkdownSelectedSource.WidenOverMathBlocks(const Source: string; const Node: IMarkdownNode;
  const Range: TMarkdownSegment): TMarkdownSegment;
begin
  Result := Range;
  if Node = nil then
    Exit;

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    const Child = Node.Children[Index];
    const IsEndOfMathBlock = ((Child.Kind = TMarkdownNodeKind.Math) and Overlaps(Child.Segment, Result) and
                              (Result.EndOffset >= Child.Segment.EndOffset));
    const IsContainer = (Child.Kind in [TMarkdownNodeKind.BlockQuote, TMarkdownNodeKind.List,
                                        TMarkdownNodeKind.ListItem]);
    if IsEndOfMathBlock then
      Result := TMarkdownSegment.Create(Result.StartOffset, Max(Result.EndOffset, MathBlockEnd(Source, Child)))
    else if IsContainer then
      Result := WidenOverMathBlocks(Source, Child, Result);
  end;
end;

// The segment stops at the line break of the block's last line; the next line
// holds $$ after the indentation or the quote markers of the container the
// block sits in.
class function TMarkdownSelectedSource.MathBlockEnd(const Source: string; const Block: IMarkdownNode): Integer;
begin
  Result := Block.Segment.EndOffset;

  var Position := Result;
  if (Position <= Length(Source)) and (Source[Position] = CarriageReturn) then
    Inc(Position);
  if (Position <= Length(Source)) and (Source[Position] = LineFeed) then
    Inc(Position);

  while (Position <= Length(Source)) and CharInSet(Source[Position], ContainerPrefix) do
    Inc(Position);

  const IsClosed = (Copy(Source, Position, Length(DisplayMathMarker)) = DisplayMathMarker);
  if not IsClosed then
    Exit;

  Position := Position + Length(DisplayMathMarker);
  while (Position <= Length(Source)) and not CharInSet(Source[Position], [CarriageReturn, LineFeed]) do
    Inc(Position);

  Result := Position;
end;

// The cells of a table have no source of their own worth copying apart, so a
// selection that touches one takes the table whole, wherever it is nested.
class function TMarkdownSelectedSource.WidenOverTables(const Node: IMarkdownNode;
  const Range: TMarkdownSegment): TMarkdownSegment;
begin
  Result := Range;
  if Node = nil then
    Exit;

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    const Child = Node.Children[Index];
    const IsTouchedTable = ((Child.Kind = TMarkdownNodeKind.Table) and Overlaps(Child.Segment, Result));
    if IsTouchedTable then
    begin
      const Table = Child.Segment;
      Result := TMarkdownSegment.Create(Min(Result.StartOffset, Table.StartOffset),
                                        Max(Result.EndOffset, Table.EndOffset));
    end
    else
    begin
      Result := WidenOverTables(Child, Result);
    end;
  end;
end;

class function TMarkdownSelectedSource.Overlaps(const Left, Right: TMarkdownSegment): Boolean;
begin
  Result := (Left.StartOffset < Right.EndOffset) and (Right.StartOffset < Left.EndOffset);
end;

class function TMarkdownSelectedSource.SpansLines(const Source: string; const Range: TMarkdownSegment): Boolean;
begin
  const Selected = Copy(Source, Range.StartOffset, Range.Length);
  const WithoutTrailingBreak = Selected.TrimRight([LineFeed, CarriageReturn]);
  Result := WithoutTrailingBreak.Contains(LineFeed);
end;

// From the start of the first line to the end of the last, without the line
// break that ends it, so list markers, quote markers and indentation come along.
class function TMarkdownSelectedSource.WholeLines(const Source: string;
  const Range: TMarkdownSegment): TMarkdownSegment;
begin
  var Start := Range.StartOffset;
  while (Start > 1) and (Source[Start - 1] <> LineFeed) do
    Dec(Start);

  var Finish := Range.EndOffset;
  const EndsOnLineBreak = ((Finish > Range.StartOffset) and (Source[Finish - 1] = LineFeed));
  if EndsOnLineBreak then
    Dec(Finish);

  while (Finish <= Length(Source)) and (Source[Finish] <> LineFeed) do
    Inc(Finish);

  const HasCarriageReturn = ((Finish > Start) and (Source[Finish - 1] = CarriageReturn));
  if HasCarriageReturn then
    Dec(Finish);

  Result := TMarkdownSegment.Create(Start, Finish);
end;

class function TMarkdownSelectedSource.WidenOverMarkup(const Source: string;
  const Range: TMarkdownSegment): TMarkdownSegment;
begin
  Result := Range;

  while True do
  begin
    const Wider = WidenedOnce(Source, Result);
    const IsUnchanged = ((Wider.StartOffset = Result.StartOffset) and (Wider.EndOffset = Result.EndOffset));
    if IsUnchanged then
      Exit;

    Result := Wider;
  end;
end;

// One step outwards: a pair of matching emphasis, strikethrough or code marks
// right around the range, or the link or image the range is the text of.
class function TMarkdownSelectedSource.WidenedOnce(const Source: string;
  const Range: TMarkdownSegment): TMarkdownSegment;
begin
  Result := Range;

  const Before = Range.StartOffset - 1;
  const After = Range.EndOffset;
  const IsInside = ((Before >= 1) and (After <= Length(Source)));
  if not IsInside then
    Exit;

  const IsBetweenMarks = (CharInSet(Source[Before], Delimiters) and (Source[After] = Source[Before]));
  if IsBetweenMarks then
  begin
    Result := TMarkdownSegment.Create(Before, After + 1);
    Exit;
  end;

  Result := WidenedOverLink(Source, Range);
end;

class function TMarkdownSelectedSource.WidenedOverLink(const Source: string;
  const Range: TMarkdownSegment): TMarkdownSegment;
begin
  Result := Range;

  const Opening = Range.StartOffset - 1;
  const Closing = Range.EndOffset;
  const IsLinkText = ((Closing + 1 <= Length(Source)) and (Source[Opening] = '[') and (Source[Closing] = ']') and
                      (Source[Closing + 1] = '('));
  if not IsLinkText then
    Exit;

  const DestinationEnd = Pos(')', Source, Closing + 2);
  if DestinationEnd = 0 then
    Exit;

  var Start := Opening;
  const IsImage = ((Start > 1) and (Source[Start - 1] = '!'));
  if IsImage then
    Dec(Start);

  Result := TMarkdownSegment.Create(Start, DestinationEnd + 1);
end;

end.
