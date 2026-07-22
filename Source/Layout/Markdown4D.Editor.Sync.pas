unit Markdown4D.Editor.Sync;

{$SCOPEDENUMS ON}

interface

uses
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
    procedure AddPoint(const SourceLine: Integer; const PreviewOffset: Single);
    function FindBySourceLine(const SourceLine: Integer): Integer;
    function FindByPreviewOffset(const Offset: Single): Integer;
    class function BuildLineStarts(const Text: string): TArray<Integer>; static;
    class function LineOfOffset(const LineStarts: TArray<Integer>; const Offset: Integer): Integer; static;

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
  System.SysUtils,
  System.Math;

procedure TMarkdownEditorSync.Update(const Document: IMarkdownDocument; const DisplayList: IMarkdownDisplayList;
  const SourceText: string);
begin
  FPoints := nil;
  FAverageLineHeight := 0;

  const HasInput = (Document <> nil) and (DisplayList <> nil);
  if not HasInput then
    Exit;

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
      AddPoint(Line, Top);
      LastLine := Line;
      MaxSourceLine := Max(MaxSourceLine, Line);
    end;
  end;

  if Length(FPoints) = 0 then
    AddPoint(0, 0);

  // Anchor the tail so scrolling past the last block still interpolates smoothly
  // to the bottom of the preview.
  const TotalLines = Length(LineStarts);
  const LastPoint = FPoints[High(FPoints)];
  if (TotalLines > LastPoint.SourceLine) and (DisplayList.Height > LastPoint.PreviewOffset) then
  begin
    AddPoint(TotalLines, DisplayList.Height);
    MaxSourceLine := Max(MaxSourceLine, TotalLines);
  end;

  if DisplayList.Height > 0 then
    FAverageLineHeight := DisplayList.Height / (MaxSourceLine + 1);
end;

class function TMarkdownEditorSync.BuildLineStarts(const Text: string): TArray<Integer>;
begin
  Result := [0];
  for var Index := 1 to Length(Text) do
  begin
    if Text[Index] = #10 then
      Result := Result + [Index];
  end;
end;

class function TMarkdownEditorSync.LineOfOffset(const LineStarts: TArray<Integer>; const Offset: Integer): Integer;
begin
  Result := 0;
  var Lo := 0;
  var Hi := High(LineStarts);
  while Lo <= Hi do
  begin
    const Mid = (Lo + Hi) div 2;
    if LineStarts[Mid] <= Offset then
    begin
      Result := Mid;
      Lo := Mid + 1;
    end
    else
      Hi := Mid - 1;
  end;
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
    Exit(0);

  const Last = High(FPoints);
  if SourceLine <= FPoints[0].SourceLine then
    Exit(FPoints[0].PreviewOffset);
  if SourceLine >= FPoints[Last].SourceLine then
    Exit(FPoints[Last].PreviewOffset);

  const Index = FindBySourceLine(SourceLine);
  const Lower = FPoints[Index];
  const Upper = FPoints[Index + 1];
  const Span = Upper.SourceLine - Lower.SourceLine;
  if Span <= 0 then
    Exit(Lower.PreviewOffset);

  const Fraction = (SourceLine - Lower.SourceLine) / Span;
  Result := Lower.PreviewOffset + (Upper.PreviewOffset - Lower.PreviewOffset) * Fraction;
end;

function TMarkdownEditorSync.PreviewOffsetToSourceLine(const Offset: Single): Integer;
begin
  if Length(FPoints) = 0 then
    Exit(0);

  const Last = High(FPoints);
  if Offset <= FPoints[0].PreviewOffset then
    Exit(FPoints[0].SourceLine);
  if Offset >= FPoints[Last].PreviewOffset then
    Exit(FPoints[Last].SourceLine);

  const Index = FindByPreviewOffset(Offset);
  const Lower = FPoints[Index];
  const Upper = FPoints[Index + 1];
  const Span = Upper.PreviewOffset - Lower.PreviewOffset;
  if Span <= 0 then
    Exit(Lower.SourceLine);

  const Fraction = (Offset - Lower.PreviewOffset) / Span;
  Result := Round(Lower.SourceLine + (Upper.SourceLine - Lower.SourceLine) * Fraction);
end;

function TMarkdownEditorSync.MappedLineCount: Integer;
begin
  Result := Length(FPoints);
end;

procedure TMarkdownEditorSync.AddPoint(const SourceLine: Integer; const PreviewOffset: Single);
begin
  var Point := Default(TMappingPoint);
  Point.SourceLine := SourceLine;
  Point.PreviewOffset := PreviewOffset;
  FPoints := FPoints + [Point];
end;

function TMarkdownEditorSync.FindBySourceLine(const SourceLine: Integer): Integer;
begin
  Result := 0;
  var Lo := 0;
  var Hi := High(FPoints);
  while Lo <= Hi do
  begin
    const Mid = (Lo + Hi) div 2;
    if FPoints[Mid].SourceLine <= SourceLine then
    begin
      Result := Mid;
      Lo := Mid + 1;
    end
    else
      Hi := Mid - 1;
  end;
end;

function TMarkdownEditorSync.FindByPreviewOffset(const Offset: Single): Integer;
begin
  Result := 0;
  var Lo := 0;
  var Hi := High(FPoints);
  while Lo <= Hi do
  begin
    const Mid = (Lo + Hi) div 2;
    if FPoints[Mid].PreviewOffset <= Offset then
    begin
      Result := Mid;
      Lo := Mid + 1;
    end
    else
      Hi := Mid - 1;
  end;
end;

end.
