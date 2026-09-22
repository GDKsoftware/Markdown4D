unit Markdown4D.Layout.SourceMapping;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces;

type
  // Which side of a selection a position sits on. A node the selection cannot
  // point inside, such as a code span, is taken whole: its leading edge is its
  // first character and its trailing edge the one after its last.
  TMarkdownSourceEdge = (Leading, Trailing);

  // Turns a position in the text the reader sees into the position of the
  // character it was rendered from, so a formatting command can change exactly
  // the markdown behind a selection.
  TMarkdownSourceMapper = class
  private
    type
      // One step through the source: the characters it reads and the ones it
      // writes, which differ for an escape and for an entity.
      TSourceStep = record
        SourceWidth: Integer;
        LiteralWidth: Integer;
      end;
    class function IsTakenWhole(const Node: IMarkdownNode): Boolean; static;
    class function IsSegmentInside(const Source: string; const Segment: TMarkdownSegment): Boolean; static;
    class function OffsetInLiteral(const Source: string; const Segment: TMarkdownSegment;
                                   const LiteralOffset: Integer): Integer; static;
    class function StepAt(const Source: string; const Index, Limit: Integer): TSourceStep; static;

  public
    // LiteralOffset counts characters into Node's literal from 0, and answers
    // the 1-based offset in Source of the character at that position. False
    // when the node carries no source of its own, as happens inside a diagram
    // an extension drew.
    class function TryMapLiteralOffset(const Source: string; const Node: IMarkdownNode;
                                       const LiteralOffset: Integer; const Edge: TMarkdownSourceEdge;
                                       out Offset: Integer): Boolean; static;
  end;

implementation

uses
  Markdown4D.Defines,
  Markdown4D.Text.Unescape;

class function TMarkdownSourceMapper.TryMapLiteralOffset(const Source: string; const Node: IMarkdownNode;
  const LiteralOffset: Integer; const Edge: TMarkdownSourceEdge; out Offset: Integer): Boolean;
begin
  Offset := 0;
  if Node = nil then
  begin
    Result := False;
    Exit;
  end;

  const Segment = Node.Segment;
  if not IsSegmentInside(Source, Segment) then
  begin
    Result := False;
    Exit;
  end;

  if IsTakenWhole(Node) then
  begin
    if Edge = TMarkdownSourceEdge.Leading then
      Offset := Segment.StartOffset
    else
      Offset := Segment.EndOffset;
  end
  else
  begin
    Offset := OffsetInLiteral(Source, Segment, LiteralOffset);
  end;

  Result := True;
end;

// Only plain text keeps its characters in the order the source spells them, so
// only there does a position inside the node mean anything. Every other inline
// node writes something else than it reads.
class function TMarkdownSourceMapper.IsTakenWhole(const Node: IMarkdownNode): Boolean;
begin
  Result := (Node.Kind <> TMarkdownNodeKind.Text);
end;

class function TMarkdownSourceMapper.IsSegmentInside(const Source: string;
  const Segment: TMarkdownSegment): Boolean;
begin
  const PastEnd = Length(Source) + 1;

  Result := (Segment.StartOffset >= 1) and (Segment.EndOffset >= Segment.StartOffset) and
    (Segment.EndOffset <= PastEnd);
end;

// Replays the source of the node until it has produced LiteralOffset
// characters. An escape or an entity spells one character with several, so the
// two only run in step as long as neither appears.
class function TMarkdownSourceMapper.OffsetInLiteral(const Source: string; const Segment: TMarkdownSegment;
  const LiteralOffset: Integer): Integer;
begin
  var Position := Segment.StartOffset;
  var Produced := 0;

  while (Produced < LiteralOffset) and (Position < Segment.EndOffset) do
  begin
    const Step = StepAt(Source, Position, Segment.EndOffset);

    Position := Position + Step.SourceWidth;
    Produced := Produced + Step.LiteralWidth;
  end;

  Result := Position;
end;

class function TMarkdownSourceMapper.StepAt(const Source: string; const Index, Limit: Integer): TSourceStep;
begin
  Result.SourceWidth := 1;
  Result.LiteralWidth := 1;

  const Current = Source[Index];

  const IsEscape = (Current = Backslash) and (Index + 1 < Limit) and
    TMarkdownUnescape.IsAsciiPunctuation(Source[Index + 1]);
  if IsEscape then
  begin
    Result.SourceWidth := 2;
    Exit;
  end;

  if Current <> Ampersand then
    Exit;

  var Decoded: string;
  var Consumed: Integer;

  const IsEntity = TMarkdownUnescape.TryDecodeEntityAt(Source, Index, Decoded, Consumed) and
    (Index + Consumed <= Limit);
  if not IsEntity then
    Exit;

  Result.SourceWidth := Consumed;
  Result.LiteralWidth := Length(Decoded);
end;

end.
