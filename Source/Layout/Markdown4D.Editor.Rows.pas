unit Markdown4D.Editor.Rows;

{$SCOPEDENUMS ON}

// Soft-wrapping the source into the rows an editor puts on screen. The only
// thing a framework has to supply is how wide a piece of text is, so the
// wrapping itself, the cache in front of it and the lookups between an offset
// and a row live here rather than in each component.

interface

uses
  System.Generics.Collections,
  Markdown4D.Editor.Model;

type
  // One on-screen line from soft-wrapping a source line. Offsets are absolute
  // into the model text and the range excludes the trailing line break.
  TVisualRow = record
    LineIndex: Integer;
    StartOffset: Integer;
    EndOffset: Integer;
    IsFirst: Boolean;
  end;

  // How wide the text is in the font the editor draws its source in.
  TMarkdownRowTextWidth = reference to function(const Text: string): Single;

  TMarkdownEditorRows = class
  private
    type
      // Where one source line wraps, cached per line so an edit only
      // re-measures the line that actually changed instead of the whole
      // document.
      TWrapCacheEntry = record
        Text: string;
        WrapWidth: Single;
        Breaks: TArray<Integer>;
      end;
    var
      FModel: TMarkdownEditorModel;
      FMeasure: TMarkdownRowTextWidth;
      FItems: TArray<TVisualRow>;
      FWrapCache: TArray<TWrapCacheEntry>;
      FWrapWidth: Single;
    procedure AppendWrappedRows(const Rows: TList<TVisualRow>; const LineIndex: Integer);
    function WrapBreaksFor(const LineIndex: Integer; const LineText: string): TArray<Integer>;
    function ComputeWrapBreaks(const LineText: string): TArray<Integer>;
    function NextWrapLength(const LineText: string; const StartCol: Integer): Integer;
    class function LastSpaceWithin(const LineText: string; const StartCol, MaxLength: Integer): Integer; static;
    class function MakeRow(const LineIndex, StartOffset, EndOffset: Integer; const IsFirst: Boolean): TVisualRow; static;

  public
    constructor Create(const Model: TMarkdownEditorModel; const Measure: TMarkdownRowTextWidth);
    procedure Rebuild(const WrapWidth: Single);
    function Count: Integer;
    function TextOf(const Row: TVisualRow): string;
    function IndexOfOffset(const Offset: Integer): Integer;
    // The offset in the row whose left edge sits closest to TargetX.
    function OffsetAtX(const RowIndex: Integer; const TargetX: Single): Integer;
    function LineTextAt(const LineIndex: Integer): string;
    function LineStartOffset(const LineIndex: Integer): Integer;
    property Items: TArray<TVisualRow> read FItems;
  end;

implementation

uses
  System.Math;

constructor TMarkdownEditorRows.Create(const Model: TMarkdownEditorModel; const Measure: TMarkdownRowTextWidth);
begin
  inherited Create;

  FModel := Model;
  FMeasure := Measure;
end;

procedure TMarkdownEditorRows.Rebuild(const WrapWidth: Single);
begin
  FWrapWidth := WrapWidth;

  const Rows = TList<TVisualRow>.Create;
  try
    const LineCount = FModel.LineCount;
    if Length(FWrapCache) < LineCount then
      SetLength(FWrapCache, LineCount);

    for var LineIndex := 0 to LineCount - 1 do
    begin
      if FModel.IsLineHidden(LineIndex) then
        Continue;

      AppendWrappedRows(Rows, LineIndex);
    end;

    FItems := Rows.ToArray;
  finally
    Rows.Free;
  end;
end;

procedure TMarkdownEditorRows.AppendWrappedRows(const Rows: TList<TVisualRow>; const LineIndex: Integer);
begin
  const LineText = LineTextAt(LineIndex);
  const LineStart = LineStartOffset(LineIndex);

  const LineIsEmpty = Length(LineText) = 0;
  if LineIsEmpty then
  begin
    Rows.Add(MakeRow(LineIndex, LineStart, LineStart, True));
    Exit;
  end;

  var Consumed := 0;
  for var Index in WrapBreaksFor(LineIndex, LineText) do
  begin
    Rows.Add(MakeRow(LineIndex, LineStart + Consumed, LineStart + Index, Consumed = 0));
    Consumed := Index;
  end;
end;

function TMarkdownEditorRows.WrapBreaksFor(const LineIndex: Integer; const LineText: string): TArray<Integer>;
begin
  const Reusable = (LineIndex <= High(FWrapCache)) and (FWrapCache[LineIndex].WrapWidth = FWrapWidth) and
    (FWrapCache[LineIndex].Text = LineText);
  if Reusable then
    Exit(FWrapCache[LineIndex].Breaks);

  Result := ComputeWrapBreaks(LineText);

  if LineIndex > High(FWrapCache) then
    SetLength(FWrapCache, LineIndex + 1);

  FWrapCache[LineIndex].Text := LineText;
  FWrapCache[LineIndex].WrapWidth := FWrapWidth;
  FWrapCache[LineIndex].Breaks := Result;
end;

function TMarkdownEditorRows.ComputeWrapBreaks(const LineText: string): TArray<Integer>;
begin
  Result := [];

  const Len = Length(LineText);
  var Consumed := 0;
  while Consumed < Len do
  begin
    Consumed := Consumed + NextWrapLength(LineText, Consumed);
    Result := Result + [Consumed];
  end;
end;

function TMarkdownEditorRows.NextWrapLength(const LineText: string; const StartCol: Integer): Integer;
begin
  const Remaining = Length(LineText) - StartCol;

  const RemainderWidth = FMeasure(Copy(LineText, StartCol + 1, Remaining));
  const FitsWholeRemainder = RemainderWidth <= FWrapWidth;
  if FitsWholeRemainder then
    Exit(Remaining);

  var LowerBound := 1;
  var UpperBound := Remaining;
  var BestFit := 1;
  while LowerBound <= UpperBound do
  begin
    const Candidate = (LowerBound + UpperBound) div 2;
    const CandidateWidth = FMeasure(Copy(LineText, StartCol + 1, Candidate));
    const CandidateFits = CandidateWidth <= FWrapWidth;
    if CandidateFits then
    begin
      BestFit := Candidate;
      LowerBound := Candidate + 1;
    end
    else
    begin
      UpperBound := Candidate - 1;
    end;
  end;

  const WordBreak = LastSpaceWithin(LineText, StartCol, BestFit);
  const CanBreakAtWord = WordBreak > 0;
  if CanBreakAtWord then
    Result := WordBreak
  else
    Result := BestFit;
end;

class function TMarkdownEditorRows.LastSpaceWithin(const LineText: string; const StartCol, MaxLength: Integer): Integer;
begin
  for var Offset := MaxLength downto 1 do
  begin
    const IsSpace = LineText[StartCol + Offset] = ' ';
    if IsSpace then
      Exit(Offset);
  end;

  Result := 0;
end;

class function TMarkdownEditorRows.MakeRow(const LineIndex, StartOffset, EndOffset: Integer;
  const IsFirst: Boolean): TVisualRow;
begin
  Result.LineIndex := LineIndex;
  Result.StartOffset := StartOffset;
  Result.EndOffset := EndOffset;
  Result.IsFirst := IsFirst;
end;

function TMarkdownEditorRows.Count: Integer;
begin
  Result := Length(FItems);
end;

function TMarkdownEditorRows.TextOf(const Row: TVisualRow): string;
begin
  Result := Copy(FModel.Text, Row.StartOffset + 1, Row.EndOffset - Row.StartOffset);
end;

function TMarkdownEditorRows.IndexOfOffset(const Offset: Integer): Integer;
begin
  if Length(FItems) = 0 then
    Exit(0);

  for var Index := 0 to High(FItems) do
  begin
    const Row = FItems[Index];
    if Offset <= Row.EndOffset then
    begin
      const AtWrapBoundary = (Offset = Row.EndOffset) and (Index < High(FItems)) and
        (FItems[Index + 1].LineIndex = Row.LineIndex);
      if AtWrapBoundary then
        Exit(Index + 1);

      Exit(Index);
    end;
  end;

  Result := High(FItems);
end;

function TMarkdownEditorRows.OffsetAtX(const RowIndex: Integer; const TargetX: Single): Integer;
begin
  if Length(FItems) = 0 then
    Exit(0);

  const Row = FItems[EnsureRange(RowIndex, 0, High(FItems))];
  const RowStr = TextOf(Row);

  var BestColumn := 0;
  var BestDistance := Abs(TargetX);
  for var PrefixLength := 1 to Length(RowStr) do
  begin
    const Width = FMeasure(Copy(RowStr, 1, PrefixLength));
    const Distance = Abs(TargetX - Width);
    if Distance < BestDistance then
    begin
      BestDistance := Distance;
      BestColumn := PrefixLength;
    end;
  end;

  Result := Row.StartOffset + BestColumn;
end;

function TMarkdownEditorRows.LineTextAt(const LineIndex: Integer): string;
begin
  const Source = FModel.Text;
  const StartOffset = FModel.OffsetOfLineStart(LineIndex);
  var EndOffset: Integer;
  if LineIndex < FModel.LineCount - 1 then
    EndOffset := FModel.OffsetOfLineStart(LineIndex + 1) - 1
  else
    EndOffset := Length(Source);

  Result := Copy(Source, StartOffset + 1, EndOffset - StartOffset);
end;

function TMarkdownEditorRows.LineStartOffset(const LineIndex: Integer): Integer;
begin
  Result := FModel.OffsetOfLineStart(LineIndex);
end;

end.
