unit Markdown4D.Parser.SourceMap;

// Maps a position in a block's assembled inline content back to the character it
// came from in the original markdown.
//
// A block's content is not a slice of the source. Lines arrive one at a time
// with their markers stripped, a block quote losing its '> ' and a list item its
// bullet, and the result is trimmed before the inline parser sees it. So the map
// is kept as runs: each run is one stretch of content that is contiguous in the
// source, and the gaps between runs are exactly the characters that never made
// it into the content.

interface

type
  TMarkdownSourceSpan = record
    StartOffset: Integer;
    Length: Integer;
    class function Create(const StartOffset, Length: Integer): TMarkdownSourceSpan; static;
  end;

  TMarkdownSourceMapRun = record
    ContentStart: Integer;
    SourceStart: Integer;
    Length: Integer;
  end;

  TMarkdownSourceMap = record
  private
    FRuns: TArray<TMarkdownSourceMapRun>;
    function IndexOfRun(const ContentIndex: Integer): Integer;
  public
    class function Create: TMarkdownSourceMap; static;

    /// <summary>
    ///   Records that Length characters of content, starting at ContentStart,
    ///   came from the source starting at SourceStart. Both indexes are 1 based.
    /// </summary>
    procedure Add(const ContentStart, SourceStart, Length: Integer);

    /// <summary>
    ///   Drops the first Count characters of content, as the block parser does
    ///   when it trims the assembled content before parsing inlines.
    /// </summary>
    procedure DropLeading(const Count: Integer);

    /// <summary>
    ///   Source offset the content character at ContentIndex came from.
    /// </summary>
    function TryMap(const ContentIndex: Integer; out SourceOffset: Integer): Boolean;

    /// <summary>
    ///   Source span for a stretch of content. Fails when the stretch is not
    ///   contiguous in the source, which is what happens across a line break or
    ///   over characters the markers removed.
    /// </summary>
    function TryMapRange(const ContentIndex, Length: Integer;
      out Span: TMarkdownSourceSpan): Boolean;

    function IsEmpty: Boolean;
  end;

implementation

class function TMarkdownSourceSpan.Create(const StartOffset, Length: Integer): TMarkdownSourceSpan;
begin
  Result.StartOffset := StartOffset;
  Result.Length := Length;
end;

class function TMarkdownSourceMap.Create: TMarkdownSourceMap;
begin
  Result.FRuns := nil;
end;

procedure TMarkdownSourceMap.Add(const ContentStart, SourceStart, Length: Integer);
begin
  if Length <= 0 then
    Exit;

  // A run that continues the previous one in both content and source is simply
  // the same stretch, so keep the map as short as the text allows.
  const Last = High(FRuns);
  if (Last >= 0) and
     (FRuns[Last].ContentStart + FRuns[Last].Length = ContentStart) and
     (FRuns[Last].SourceStart + FRuns[Last].Length = SourceStart) then
  begin
    Inc(FRuns[Last].Length, Length);
    Exit;
  end;

  SetLength(FRuns, System.Length(FRuns) + 1);
  FRuns[High(FRuns)].ContentStart := ContentStart;
  FRuns[High(FRuns)].SourceStart := SourceStart;
  FRuns[High(FRuns)].Length := Length;
end;

procedure TMarkdownSourceMap.DropLeading(const Count: Integer);
begin
  if Count <= 0 then
    Exit;

  var Kept: TArray<TMarkdownSourceMapRun> := nil;

  for var Run in FRuns do
  begin
    const RunEnd = Run.ContentStart + Run.Length - 1;
    if RunEnd <= Count then
      Continue;

    var Shifted := Run;

    if Run.ContentStart <= Count then
    begin
      // The cut falls inside this run, so it keeps only its tail.
      const Removed = Count - Run.ContentStart + 1;
      Shifted.ContentStart := 1;
      Shifted.SourceStart := Run.SourceStart + Removed;
      Shifted.Length := Run.Length - Removed;
    end
    else
      Shifted.ContentStart := Run.ContentStart - Count;

    SetLength(Kept, System.Length(Kept) + 1);
    Kept[High(Kept)] := Shifted;
  end;

  FRuns := Kept;
end;

function TMarkdownSourceMap.IndexOfRun(const ContentIndex: Integer): Integer;
begin
  for var Index := Low(FRuns) to High(FRuns) do
  begin
    if (ContentIndex >= FRuns[Index].ContentStart) and
       (ContentIndex < FRuns[Index].ContentStart + FRuns[Index].Length) then
      Exit(Index);
  end;

  Result := -1;
end;

function TMarkdownSourceMap.TryMap(const ContentIndex: Integer; out SourceOffset: Integer): Boolean;
begin
  SourceOffset := 0;

  const Index = IndexOfRun(ContentIndex);
  Result := Index >= 0;
  if not Result then
    Exit;

  SourceOffset := FRuns[Index].SourceStart + (ContentIndex - FRuns[Index].ContentStart);
end;

function TMarkdownSourceMap.TryMapRange(const ContentIndex, Length: Integer;
  out Span: TMarkdownSourceSpan): Boolean;
begin
  Span := TMarkdownSourceSpan.Create(0, 0);

  if Length <= 0 then
    Exit(False);

  const Index = IndexOfRun(ContentIndex);
  if Index < 0 then
    Exit(False);

  // Only a stretch that stays inside one run is contiguous in the source.
  const OffsetInRun = ContentIndex - FRuns[Index].ContentStart;
  if OffsetInRun + Length > FRuns[Index].Length then
    Exit(False);

  Span := TMarkdownSourceSpan.Create(FRuns[Index].SourceStart + OffsetInRun, Length);
  Result := True;
end;

function TMarkdownSourceMap.IsEmpty: Boolean;
begin
  Result := System.Length(FRuns) = 0;
end;

end.
