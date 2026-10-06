unit Markdown4D.Layout.SelectedMarkdown;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces;

type
  // The markdown a reader means when copying a selection as markdown: within one
  // line the selected source with the markup directly around it, over several
  // lines whole source lines, and a table always whole.
  TMarkdownSelectedSource = record
  private
    const
      LineFeed = #10;
      CarriageReturn = #13;
      Delimiters = ['*', '_', '~', '`'];
    class function WidenOverTables(const Node: IMarkdownNode; const Range: TMarkdownSegment): TMarkdownSegment; static;
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
