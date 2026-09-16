unit Markdown4D.Editor.Sync;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.DisplayList;

type
  TMarkdownEditorSync = class
  strict private
    type
      TMappingPoint = record
        SourceLine: Integer;
        PreviewOffset: Single;
      end;
    var
      FPoints: TArray<TMappingPoint>;
      FAverageLineHeight: Single;
    procedure AddPoint(const Points: TList<TMappingPoint>; const SourceLine: Integer; const PreviewOffset: Single);
    function FindBySourceLine(const SourceLine: Integer): Integer;
    function FindByPreviewOffset(const Offset: Single): Integer;
    class function BuildLineStarts(const Text: string): TArray<Integer>; static;
    class function LineOfOffset(const LineStarts: TArray<Integer>; const Offset: Integer): Integer; static;
    // Shared floor-search: the largest index whose value is <= Target, or 0 when
    // none qualifies. LineOfOffset, FindBySourceLine and FindByPreviewOffset all
    // searched a sorted sequence with this exact shape but over different arrays
    // and fields; ValueAt lets them share one implementation.
    class function BinarySearchFloor(const Count: Integer; const Target: Double;
      const ValueAt: TFunc<Integer, Double>): Integer; static;

  public
    procedure Update(const Document: IMarkdownDocument; const DisplayList: IMarkdownDisplayList;
      const SourceText: string);
    procedure ShiftAfter(const SourceLine, LineDelta: Integer);
    function SourceLineToPreviewOffset(const SourceLine: Integer): Single;
    function PreviewOffsetToSourceLine(const Offset: Single): Integer;
    function MappedLineCount: Integer;
  end;

implementation

uses
  System.Math;

procedure TMarkdownEditorSync.Update(const Document: IMarkdownDocument; const DisplayList: IMarkdownDisplayList;
  const SourceText: string);
begin
  FPoints := nil;
  FAverageLineHeight := 0;

  const HasInput = (Document <> nil) and (DisplayList <> nil);
  if not HasInput then
    Exit;

  // Points accumulate one per top-level block, so a TList avoids the O(n^2)
  // cost of growing an array one element at a time on a large document.
  const Points = TList<TMappingPoint>.Create;
  try
    // Map every top-level block (not just headings) to its rendered top, so
    // scrolling stays in step inside long sections instead of snapping between
    // headings. Interpolating between these points keeps the sync continuous.
    const LineStarts = BuildLineStarts(SourceText);
    const BlockCount = DisplayList.BlockCount;
    var MaxSourceLine := 0;
    var LastLine := -1;
    for var Index := 0 to Document.ChildCount - 1 do
    begin
      if Index >= BlockCount then
        Break;

      const Node = Document.Children[Index];
      const Top = DisplayList.BlockInfos[Index].Top;
      const Line = LineOfOffset(LineStarts, Node.Segment.StartOffset);

      // Blocks are in document order, so lines only advance; skip repeats to keep
      // the mapping strictly increasing for interpolation.
      if Line > LastLine then
      begin
        AddPoint(Points, Line, Top);
        LastLine := Line;
        MaxSourceLine := Max(MaxSourceLine, Line);
      end;
    end;

    if Points.Count = 0 then
      AddPoint(Points, 0, 0);

    // Anchor the tail so scrolling past the last block still interpolates smoothly
    // to the bottom of the preview.
    const TotalLines = Length(LineStarts);
    const LastPoint = Points[Points.Count - 1];
    if (TotalLines > LastPoint.SourceLine) and (DisplayList.Height > LastPoint.PreviewOffset) then
    begin
      AddPoint(Points, TotalLines, DisplayList.Height);
      MaxSourceLine := Max(MaxSourceLine, TotalLines);
    end;

    FPoints := Points.ToArray;

    if DisplayList.Height > 0 then
      FAverageLineHeight := DisplayList.Height / (MaxSourceLine + 1);
  finally
    Points.Free;
  end;
end;

class function TMarkdownEditorSync.BuildLineStarts(const Text: string): TArray<Integer>;
begin
  // Line-start offsets grow with document size, so a TList avoids the O(n^2)
  // cost of growing an array one element at a time.
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

class function TMarkdownEditorSync.LineOfOffset(const LineStarts: TArray<Integer>; const Offset: Integer): Integer;
begin
  const ValueAt: TFunc<Integer, Double> =
    function(Index: Integer): Double
    begin
      Result := LineStarts[Index];
    end;

  Result := BinarySearchFloor(Length(LineStarts), Offset, ValueAt);
end;

procedure TMarkdownEditorSync.ShiftAfter(const SourceLine, LineDelta: Integer);
begin
  for var Index := 0 to High(FPoints) do
  begin
    if FPoints[Index].SourceLine > SourceLine then
    begin
      FPoints[Index].SourceLine := FPoints[Index].SourceLine + LineDelta;
      FPoints[Index].PreviewOffset := FPoints[Index].PreviewOffset + LineDelta * FAverageLineHeight;
    end;
  end;
end;

function TMarkdownEditorSync.SourceLineToPreviewOffset(const SourceLine: Integer): Single;
begin
  if Length(FPoints) = 0 then
  begin
    Result := 0;
    Exit;
  end;

  const Last = High(FPoints);
  if SourceLine <= FPoints[0].SourceLine then
  begin
    Result := FPoints[0].PreviewOffset;
    Exit;
  end;
  if SourceLine >= FPoints[Last].SourceLine then
  begin
    Result := FPoints[Last].PreviewOffset;
    Exit;
  end;

  const Index = FindBySourceLine(SourceLine);
  const Lower = FPoints[Index];
  const Upper = FPoints[Index + 1];
  const Span = Upper.SourceLine - Lower.SourceLine;
  if Span <= 0 then
  begin
    Result := Lower.PreviewOffset;
    Exit;
  end;

  const Fraction = (SourceLine - Lower.SourceLine) / Span;
  Result := Lower.PreviewOffset + (Upper.PreviewOffset - Lower.PreviewOffset) * Fraction;
end;

function TMarkdownEditorSync.PreviewOffsetToSourceLine(const Offset: Single): Integer;
begin
  if Length(FPoints) = 0 then
  begin
    Result := 0;
    Exit;
  end;

  const Last = High(FPoints);
  if Offset <= FPoints[0].PreviewOffset then
  begin
    Result := FPoints[0].SourceLine;
    Exit;
  end;
  if Offset >= FPoints[Last].PreviewOffset then
  begin
    Result := FPoints[Last].SourceLine;
    Exit;
  end;

  const Index = FindByPreviewOffset(Offset);
  const Lower = FPoints[Index];
  const Upper = FPoints[Index + 1];
  const Span = Upper.PreviewOffset - Lower.PreviewOffset;
  if Span <= 0 then
  begin
    Result := Lower.SourceLine;
    Exit;
  end;

  const Fraction = (Offset - Lower.PreviewOffset) / Span;
  Result := Round(Lower.SourceLine + (Upper.SourceLine - Lower.SourceLine) * Fraction);
end;

function TMarkdownEditorSync.MappedLineCount: Integer;
begin
  Result := Length(FPoints);
end;

procedure TMarkdownEditorSync.AddPoint(const Points: TList<TMappingPoint>; const SourceLine: Integer;
  const PreviewOffset: Single);
begin
  var Point := Default(TMappingPoint);
  Point.SourceLine := SourceLine;
  Point.PreviewOffset := PreviewOffset;
  Points.Add(Point);
end;

function TMarkdownEditorSync.FindBySourceLine(const SourceLine: Integer): Integer;
begin
  const ValueAt: TFunc<Integer, Double> =
    function(Index: Integer): Double
    begin
      Result := FPoints[Index].SourceLine;
    end;

  Result := BinarySearchFloor(Length(FPoints), SourceLine, ValueAt);
end;

function TMarkdownEditorSync.FindByPreviewOffset(const Offset: Single): Integer;
begin
  const ValueAt: TFunc<Integer, Double> =
    function(Index: Integer): Double
    begin
      Result := FPoints[Index].PreviewOffset;
    end;

  Result := BinarySearchFloor(Length(FPoints), Offset, ValueAt);
end;

class function TMarkdownEditorSync.BinarySearchFloor(const Count: Integer; const Target: Double;
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
