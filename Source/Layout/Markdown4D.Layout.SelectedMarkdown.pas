unit Markdown4D.Layout.SelectedMarkdown;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces;

type
  // The markdown a reader means when copying a selection as markdown: within one
  // line the selected source with the markup directly around it, over several
  // lines whole source lines, an inline element the selection starts or ends in
  // whole, a table always whole, and a display formula with the line that closes it.
  TMarkdownSelectedSource = record
  private
    const
      LineFeed = #10;
      CarriageReturn = #13;
      Delimiters = ['*', '_', '~', '`'];
      DisplayMathMarker = '$$';
      ContainerPrefix = [' ', #9, '>'];
      InlineElements = [TMarkdownNodeKind.Emphasis, TMarkdownNodeKind.Strong, TMarkdownNodeKind.CodeSpan,
                        TMarkdownNodeKind.Link, TMarkdownNodeKind.Image, TMarkdownNodeKind.Autolink,
                        TMarkdownNodeKind.CustomInline];
    class function WidenOverMathBlocks(const Source: string; const Node: IMarkdownNode;
                                       const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function WidenOverTables(const Node: IMarkdownNode; const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function WidenOverCutInlines(const Node: IMarkdownNode;
                                       const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function IsCut(const Element, Range: TMarkdownSegment): Boolean; static;
    // Where a display formula block ends in Source together with the line that
    // closes it; a block left open ends where its segment does.
    class function MathBlockEnd(const Source: string; const Block: IMarkdownNode): Integer; static;
    class function Overlaps(const Left, Right: TMarkdownSegment): Boolean; static;
    class function SpansLines(const Source: string; const Range: TMarkdownSegment): Boolean; static;
    class function WholeLines(const Source: string; const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function WidenOverMarkup(const Source: string; const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function WidenedOnce(const Source: string; const Range: TMarkdownSegment): TMarkdownSegment; static;
    class function WidenedOverLink(const Source: string; const Range: TMarkdownSegment): TMarkdownSegment; static;

  public
    // Selection is the stretch of Source the selected text was rendered from.
    // Line ends come out as the platform writes them.
    class function Extract(const Source: string; const Document: IMarkdownNode;
                           const Selection: TMarkdownSegment): string; static;
    class function WithPlatformLineBreaks(const Text: string): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math;

class function TMarkdownSelectedSource.Extract(const Source: string; const Document: IMarkdownNode;
  const Selection: TMarkdownSegment): string;
begin
  var Range := WidenOverTables(Document, Selection);
  Range := WidenOverMathBlocks(Source, Document, Range);
  Range := WidenOverCutInlines(Document, Range);

  if SpansLines(Source, Range) then
    Range := WholeLines(Source, Range)
  else
    Range := WidenOverMarkup(Source, Range);

  const Selected = Copy(Source, Range.StartOffset, Range.Length);
  Result := WithPlatformLineBreaks(Selected);
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

// Pasted with only one of its delimiters, an element would format the text
// after it as well, so a selection that starts or ends inside one takes it whole.
// Outer elements come before the ones nested in them, so one pass is enough.
class function TMarkdownSelectedSource.WidenOverCutInlines(const Node: IMarkdownNode;
  const Range: TMarkdownSegment): TMarkdownSegment;
begin
  Result := Range;
  if Node = nil then
    Exit;

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    const Child = Node.Children[Index];
    const Element = Child.Segment;
    const IsCutElement = ((Child.Kind in InlineElements) and IsCut(Element, Result));
    if IsCutElement then
      Result := TMarkdownSegment.Create(Min(Result.StartOffset, Element.StartOffset),
                                        Max(Result.EndOffset, Element.EndOffset));

    Result := WidenOverCutInlines(Child, Result);
  end;
end;

// The range covers part of the element and something outside it.
class function TMarkdownSelectedSource.IsCut(const Element, Range: TMarkdownSegment): Boolean;
begin
  const IsMapped = (Element.StartOffset > 0);
  const IsInside = ((Range.StartOffset >= Element.StartOffset) and (Range.EndOffset <= Element.EndOffset));
  const IsWhole = ((Range.StartOffset <= Element.StartOffset) and (Range.EndOffset >= Element.EndOffset));
  Result := (IsMapped and Overlaps(Element, Range) and not IsInside and not IsWhole);
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
