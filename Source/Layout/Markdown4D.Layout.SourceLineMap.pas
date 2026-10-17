unit Markdown4D.Layout.SourceLineMap;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.DisplayList;

type
  // Where a line of the markdown source shows in a laid-out document, and which
  // line shows at a given height. Lines count from 0. Every display item that
  // carries its source gives a point, so the map follows the rendered lines
  // inside a long list, table or code block too, and it does not depend on how
  // a document processor arranged the blocks. Between points it interpolates.
  TMarkdownSourceLineMap = class
  strict private
    type
      TMappingPoint = record
        SourceLine: Integer;
        Offset: Single;
      end;
      // The lines a top-level block spans in the source. An item of the block
      // whose offsets point outside them was laid out from text parsed apart
      // from the document, as a block of HTML is, and would pull the map out
      // of order.
      TLineSpan = record
        FirstLine: Integer;
        LastLine: Integer;
      end;
    var
      FPoints: TArray<TMappingPoint>;
    const
      // Absorbs the rounding of a height that lies exactly on the top of a line.
      LineEpsilon = 0.001;
    procedure AddBlockPoints(const Points: TList<TMappingPoint>; const Block: IMarkdownNode;
      const Info: TLayoutBlockInfo; const DisplayList: IMarkdownDisplayList; const SourceText: string;
      const LineStarts: TArray<Integer>);
    procedure AddPoint(const Points: TList<TMappingPoint>; const SourceLine: Integer; const Offset: Single);
    class function SourceNodeOf(const Item: IDisplayItem; out LiteralOffset: Integer): IMarkdownNode; static;
    class function TryGetSourceLine(const Node: IMarkdownNode; const LiteralOffset: Integer;
      const SourceText: string; const LineStarts: TArray<Integer>; out SourceLine: Integer): Boolean; static;
    class function CodeLineOf(const Code: IMarkdownCodeBlock; const LiteralOffset: Integer;
      const LineStarts: TArray<Integer>): Integer; static;
    class function BlockSpanOf(const Block: IMarkdownNode; const LineStarts: TArray<Integer>): TLineSpan; static;
    class function BuildLineStarts(const Text: string): TArray<Integer>; static;
    class function LineOfOffset(const LineStarts: TArray<Integer>; const Offset: Integer): Integer; static;
    function FindBySourceLine(const SourceLine: Integer): Integer;
    function FindByOffset(const Offset: Single): Integer;
    // The largest index whose value is <= Target, or 0 when none qualifies.
    class function BinarySearchFloor(const Count: Integer; const Target: Double;
      const ValueAt: TFunc<Integer, Double>): Integer; static;

  public
    procedure Build(const Document: IMarkdownDocument; const DisplayList: IMarkdownDisplayList;
      const SourceText: string);
    // The height in the document at which SourceLine starts: the scroll offset
    // that brings it to the top of the view.
    function SourceLineToOffset(const SourceLine: Integer): Single;
    // The line that shows at that height, so a height inside a tall image
    // answers the line of the image, not the line after it.
    function OffsetToSourceLine(const Offset: Single): Integer;
  end;

implementation

uses
  System.Math,
  Markdown4D.Layout.SourceMapping;

procedure TMarkdownSourceLineMap.Build(const Document: IMarkdownDocument; const DisplayList: IMarkdownDisplayList;
  const SourceText: string);
begin
  FPoints := nil;

  const HasInput = (Document <> nil) and (DisplayList <> nil);
  if not HasInput then
    Exit;

  const LineStarts = BuildLineStarts(SourceText);
  const Points = TList<TMappingPoint>.Create;
  try
    const BlockCount = Min(Document.ChildCount, DisplayList.BlockCount);
    for var BlockIndex := 0 to BlockCount - 1 do
    begin
      AddBlockPoints(Points, Document.Children[BlockIndex], DisplayList.BlockInfos[BlockIndex], DisplayList,
        SourceText, LineStarts);
    end;

    if Points.Count = 0 then
      AddPoint(Points, 0, 0);

    // Past the last point the lines run on to the bottom of the document.
    AddPoint(Points, Length(LineStarts), DisplayList.Height);

    FPoints := Points.ToArray;
  finally
    Points.Free;
  end;
end;

procedure TMarkdownSourceLineMap.AddBlockPoints(const Points: TList<TMappingPoint>; const Block: IMarkdownNode;
  const Info: TLayoutBlockInfo; const DisplayList: IMarkdownDisplayList; const SourceText: string;
  const LineStarts: TArray<Integer>);
begin
  const Span = BlockSpanOf(Block, LineStarts);
  AddPoint(Points, Span.FirstLine, Info.Top);

  for var ItemIndex := Info.FirstItemIndex to Info.FirstItemIndex + Info.ItemCount - 1 do
  begin
    const Item = DisplayList.Items[ItemIndex];

    var LiteralOffset: Integer;
    const Node = SourceNodeOf(Item, LiteralOffset);
    if Node = nil then
      Continue;

    var SourceLine: Integer;
    const IsMapped = TryGetSourceLine(Node, LiteralOffset, SourceText, LineStarts, SourceLine);
    const IsInsideBlock = (IsMapped and (SourceLine >= Span.FirstLine) and (SourceLine <= Span.LastLine));
    if IsInsideBlock then
      AddPoint(Points, SourceLine, Item.Bounds.Top);
  end;
end;

// Points only ever move down the source and down the page, so interpolation
// between neighbours works both ways. The first item of a source line gives
// its top; a later item on that line, or a line that joins the same rendered
// line as the one before, adds nothing.
procedure TMarkdownSourceLineMap.AddPoint(const Points: TList<TMappingPoint>; const SourceLine: Integer;
  const Offset: Single);
begin
  if Points.Count > 0 then
  begin
    const Last = Points.Last;
    const MovesOn = ((SourceLine > Last.SourceLine) and (Offset > Last.Offset));
    if not MovesOn then
      Exit;
  end;

  var Point := Default(TMappingPoint);
  Point.SourceLine := SourceLine;
  Point.Offset := Offset;
  Points.Add(Point);
end;

class function TMarkdownSourceLineMap.SourceNodeOf(const Item: IDisplayItem; out LiteralOffset: Integer): IMarkdownNode;
begin
  LiteralOffset := 0;
  Result := Item.Node;

  var Run: IDisplayTextRun;
  if not Supports(Item, IDisplayTextRun, Run) then
    Exit;

  LiteralOffset := Run.StartOffset;
  if Run.SourceNode <> nil then
    Result := Run.SourceNode;
end;

class function TMarkdownSourceLineMap.TryGetSourceLine(const Node: IMarkdownNode; const LiteralOffset: Integer;
  const SourceText: string; const LineStarts: TArray<Integer>; out SourceLine: Integer): Boolean;
begin
  SourceLine := 0;

  var Code: IMarkdownCodeBlock;
  if Supports(Node, IMarkdownCodeBlock, Code) then
  begin
    SourceLine := CodeLineOf(Code, LiteralOffset, LineStarts);
    Result := True;
    Exit;
  end;

  var SourceOffset: Integer;
  Result := TMarkdownSourceMapper.TryMapLiteralOffset(SourceText, Node, LiteralOffset, TMarkdownSourceEdge.Leading,
    SourceOffset);
  if Result then
    SourceLine := LineOfOffset(LineStarts, SourceOffset);
end;

// A code block keeps its lines as the source spells them, so the line a run
// sits on inside the literal is the source line counted from the first line
// of code: the one after the opening fence, or the first indented line.
class function TMarkdownSourceLineMap.CodeLineOf(const Code: IMarkdownCodeBlock; const LiteralOffset: Integer;
  const LineStarts: TArray<Integer>): Integer;
begin
  var FirstCodeLine := LineOfOffset(LineStarts, Code.Segment.StartOffset);
  if Code.IsFenced then
    Inc(FirstCodeLine);

  const Preceding = Copy(Code.Literal, 1, LiteralOffset);
  const LinesBefore = Preceding.CountChar(#10);
  Result := FirstCodeLine + LinesBefore;
end;

class function TMarkdownSourceLineMap.BlockSpanOf(const Block: IMarkdownNode;
  const LineStarts: TArray<Integer>): TLineSpan;
begin
  const Segment = Block.Segment;
  const LastCharacter = Max(Segment.StartOffset, Segment.EndOffset - 1);

  Result.FirstLine := LineOfOffset(LineStarts, Segment.StartOffset);
  Result.LastLine := LineOfOffset(LineStarts, LastCharacter);
end;

// The 0-based offset at which each line starts.
class function TMarkdownSourceLineMap.BuildLineStarts(const Text: string): TArray<Integer>;
begin
  const LineStarts = TList<Integer>.Create;
  try
    LineStarts.Add(0);
    for var Index := 1 to Length(Text) do
    begin
      if Text[Index] = #10 then
        LineStarts.Add(Index);
    end;

    Result := LineStarts.ToArray;
  finally
    LineStarts.Free;
  end;
end;

// Offset counts from 1, as segments do.
class function TMarkdownSourceLineMap.LineOfOffset(const LineStarts: TArray<Integer>; const Offset: Integer): Integer;
begin
  const ValueAt: TFunc<Integer, Double> =
    function(Index: Integer): Double
    begin
      Result := LineStarts[Index];
    end;

  Result := BinarySearchFloor(Length(LineStarts), Offset - 1, ValueAt);
end;

function TMarkdownSourceLineMap.SourceLineToOffset(const SourceLine: Integer): Single;
begin
  if Length(FPoints) = 0 then
  begin
    Result := 0;
    Exit;
  end;

  const Last = High(FPoints);
  if SourceLine <= FPoints[0].SourceLine then
  begin
    Result := FPoints[0].Offset;
    Exit;
  end;
  if SourceLine >= FPoints[Last].SourceLine then
  begin
    Result := FPoints[Last].Offset;
    Exit;
  end;

  const Index = FindBySourceLine(SourceLine);
  const Lower = FPoints[Index];
  const Upper = FPoints[Index + 1];
  const Fraction = (SourceLine - Lower.SourceLine) / (Upper.SourceLine - Lower.SourceLine);
  Result := Lower.Offset + (Upper.Offset - Lower.Offset) * Fraction;
end;

function TMarkdownSourceLineMap.OffsetToSourceLine(const Offset: Single): Integer;
begin
  if Length(FPoints) = 0 then
  begin
    Result := 0;
    Exit;
  end;

  const Last = High(FPoints);
  if Offset <= FPoints[0].Offset then
  begin
    Result := FPoints[0].SourceLine;
    Exit;
  end;
  if Offset >= FPoints[Last].Offset then
  begin
    Result := FPoints[Last].SourceLine;
    Exit;
  end;

  const Index = FindByOffset(Offset);
  const Lower = FPoints[Index];
  const Upper = FPoints[Index + 1];
  const Fraction = (Offset - Lower.Offset) / (Upper.Offset - Lower.Offset);
  const LinesIn = (Upper.SourceLine - Lower.SourceLine) * Fraction;
  Result := Lower.SourceLine + Floor(LinesIn + LineEpsilon);
end;

function TMarkdownSourceLineMap.FindBySourceLine(const SourceLine: Integer): Integer;
begin
  const ValueAt: TFunc<Integer, Double> =
    function(Index: Integer): Double
    begin
      Result := FPoints[Index].SourceLine;
    end;

  Result := BinarySearchFloor(Length(FPoints), SourceLine, ValueAt);
end;

function TMarkdownSourceLineMap.FindByOffset(const Offset: Single): Integer;
begin
  const ValueAt: TFunc<Integer, Double> =
    function(Index: Integer): Double
    begin
      Result := FPoints[Index].Offset;
    end;

  Result := BinarySearchFloor(Length(FPoints), Offset, ValueAt);
end;

class function TMarkdownSourceLineMap.BinarySearchFloor(const Count: Integer; const Target: Double;
  const ValueAt: TFunc<Integer, Double>): Integer;
begin
  Result := 0;

  var LowerBound := 0;
  var UpperBound := Count - 1;
  while LowerBound <= UpperBound do
  begin
    const Candidate = (LowerBound + UpperBound) div 2;
    if ValueAt(Candidate) <= Target then
    begin
      Result := Candidate;
      LowerBound := Candidate + 1;
    end
    else
    begin
      UpperBound := Candidate - 1;
    end;
  end;
end;

end.
