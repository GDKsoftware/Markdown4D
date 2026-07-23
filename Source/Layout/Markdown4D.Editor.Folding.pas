unit Markdown4D.Editor.Folding;

{$SCOPEDENUMS ON}

// Framework-neutral fold-region derivation for the source editor. A fold region
// has a visible header line that carries the toggle and a run of following lines
// that disappear when the region is collapsed. Two kinds are recognised: fenced
// code blocks (fence line to matching close) and heading sections (a heading down
// to the line before the next heading of equal or higher level).

interface

type
  TFoldRegion = record
    HeaderLine: Integer;
    StartLine: Integer;
    EndLine: Integer;
    class function Create(const HeaderLine, StartLine, EndLine: Integer): TFoldRegion; static;
    function Contains(const LineIndex: Integer): Boolean;
  end;

  TMarkdownFoldComputer = record
    class function ComputeRegions(const Lines: TArray<string>): TArray<TFoldRegion>; static;
  private
    const
      MaxHeadingLevel = 6;
      MinFenceLength = 3;
    type
      TOpenHeading = record
        Line: Integer;
        Level: Integer;
      end;
    class function IsFenceOpen(const Line: string; out FenceChar: Char; out FenceLength: Integer): Boolean; static;
    class function IsFenceClose(const Line: string; const FenceChar: Char; const FenceLength: Integer): Boolean; static;
    class function HeadingLevel(const Line: string): Integer; static;
    class function LeadingRun(const Text: string; const Ch: Char): Integer; static;
  end;

implementation

uses
  System.SysUtils;

class function TFoldRegion.Create(const HeaderLine, StartLine, EndLine: Integer): TFoldRegion;
begin
  Result.HeaderLine := HeaderLine;
  Result.StartLine := StartLine;
  Result.EndLine := EndLine;
end;

function TFoldRegion.Contains(const LineIndex: Integer): Boolean;
begin
  Result := (LineIndex >= StartLine) and (LineIndex <= EndLine);
end;

class function TMarkdownFoldComputer.ComputeRegions(const Lines: TArray<string>): TArray<TFoldRegion>;
begin
  Result := [];

  var OpenHeadings: TArray<TOpenHeading> := [];
  const LineCount = Length(Lines);

  var Index := 0;
  while Index < LineCount do
  begin
    var FenceChar: Char;
    var FenceLength: Integer;
    if IsFenceOpen(Lines[Index], FenceChar, FenceLength) then
    begin
      var CloseLine := -1;
      var Scan := Index + 1;
      while Scan < LineCount do
      begin
        if IsFenceClose(Lines[Scan], FenceChar, FenceLength) then
        begin
          CloseLine := Scan;
          Break;
        end;
        Inc(Scan);
      end;

      var EndLine := CloseLine;
      if EndLine < 0 then
        EndLine := LineCount - 1;

      if EndLine > Index then
        Result := Result + [TFoldRegion.Create(Index, Index + 1, EndLine)];

      Index := EndLine + 1;
      Continue;
    end;

    const Level = HeadingLevel(Lines[Index]);
    if Level > 0 then
    begin
      while (Length(OpenHeadings) > 0) and (OpenHeadings[High(OpenHeadings)].Level >= Level) do
      begin
        const Top = OpenHeadings[High(OpenHeadings)];
        SetLength(OpenHeadings, Length(OpenHeadings) - 1);
        if Index - 1 >= Top.Line + 1 then
          Result := Result + [TFoldRegion.Create(Top.Line, Top.Line + 1, Index - 1)];
      end;

      var Opened := Default(TOpenHeading);
      Opened.Line := Index;
      Opened.Level := Level;
      OpenHeadings := OpenHeadings + [Opened];
    end;

    Inc(Index);
  end;

  while Length(OpenHeadings) > 0 do
  begin
    const Top = OpenHeadings[High(OpenHeadings)];
    SetLength(OpenHeadings, Length(OpenHeadings) - 1);
    if LineCount - 1 >= Top.Line + 1 then
      Result := Result + [TFoldRegion.Create(Top.Line, Top.Line + 1, LineCount - 1)];
  end;
end;

class function TMarkdownFoldComputer.IsFenceOpen(const Line: string; out FenceChar: Char;
  out FenceLength: Integer): Boolean;
begin
  FenceChar := #0;
  FenceLength := 0;

  const Trimmed = TrimLeft(Line);
  if Trimmed = '' then
    Exit(False);

  const First = Trimmed[1];
  if (First <> '`') and (First <> '~') then
    Exit(False);

  const Run = LeadingRun(Trimmed, First);
  if Run < MinFenceLength then
    Exit(False);

  FenceChar := First;
  FenceLength := Run;
  Result := True;
end;

class function TMarkdownFoldComputer.IsFenceClose(const Line: string; const FenceChar: Char;
  const FenceLength: Integer): Boolean;
begin
  const Trimmed = Trim(Line);
  if Trimmed = '' then
    Exit(False);

  const Run = LeadingRun(Trimmed, FenceChar);
  Result := (Run >= FenceLength) and (Run = Length(Trimmed));
end;

class function TMarkdownFoldComputer.HeadingLevel(const Line: string): Integer;
begin
  const Trimmed = TrimLeft(Line);
  const Hashes = LeadingRun(Trimmed, '#');

  const IsHeading = (Hashes >= 1) and (Hashes <= MaxHeadingLevel) and
    ((Length(Trimmed) = Hashes) or (Trimmed[Hashes + 1] = ' '));
  if IsHeading then
    Result := Hashes
  else
    Result := 0;
end;

class function TMarkdownFoldComputer.LeadingRun(const Text: string; const Ch: Char): Integer;
begin
  Result := 0;
  while (Result < Length(Text)) and (Text[Result + 1] = Ch) do
    Inc(Result);
end;

end.
