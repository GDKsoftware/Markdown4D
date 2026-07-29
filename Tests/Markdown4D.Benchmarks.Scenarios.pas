unit Markdown4D.Benchmarks.Scenarios;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  Markdown4D.Defines;

type
  TBenchmarkScenarios = class
  private
    const
      LineBreak = #10;
      DocumentSectionFormat =
        '## Section %0:d heading' + LineBreak +
        LineBreak +
        'Paragraph %0:d with *emphasis*, **strong text**, `inline code`, and a [link](https://example.com/page-%0:d).' + LineBreak +
        LineBreak +
        '- unordered item one for section %0:d' + LineBreak +
        '- unordered item two with *nested emphasis*' + LineBreak +
        '- unordered item three with `a code span`' + LineBreak +
        LineBreak +
        '1. ordered item one for section %0:d' + LineBreak +
        '2. ordered item two for section %0:d' + LineBreak +
        LineBreak +
        '| Name | Value |' + LineBreak +
        '| ---- | ----- |' + LineBreak +
        '| row %0:d alpha | *alpha* value |' + LineBreak +
        '| row %0:d beta | `beta` value |' + LineBreak +
        LineBreak +
        '```pascal' + LineBreak +
        'function Sample%0:d: Integer;' + LineBreak +
        'begin' + LineBreak +
        '  Result := %0:d;' + LineBreak +
        'end;' + LineBreak +
        '```' + LineBreak +
        LineBreak;
      OneMegabyteLength = 1024 * 1024;
      HundredKilobyteLength = 100 * 1024;
      BenchmarkChunkLength = 200;
      BenchmarkReplacePositionCount = 100;
      FullParseRuns = 5;
      EmphasisRuns = 3;
      ClosedEmphasisDelimiterCount = 10000;
      UnclosedEmphasisOpenerCount = 5000;
      AlternatingEmphasisUnit = '*a*';
      NestedListMarkerUnit = '- ';
      UnclosedEmphasisUnit = '**a';
      ReplacementText = '0123456789';
      ReplacedCharacterCount = 10;
      MinimumMedianMilliseconds = 0.0001;
      FullParseScenarioName = 'full-parse-1mb';
      AppendChunkScenarioName = 'append-chunk';
      ReplaceSmallInHundredKbScenarioName = 'replace-small-in-100kb';
      ReplaceSmallInLargeScenarioName = 'replace-small-in-large';
      ReplaceScalingScenarioName = 'replace-scaling';
      EmphasisScenarioName = 'emphasis-pathological';
      EmphasisClosedScenarioName = 'emphasis-pathological-closed';
      EmphasisUnclosedScenarioName = 'emphasis-pathological-unclosed';
      ValueLineFormat = 'BENCH %s %.3f';
      ErrorLineFormat = 'BENCH %s ERROR %s: %s';
    class procedure ReportFullParseScenario(const Source: string);
    class procedure ReportAppendScenario(const Source: string);
    class procedure ReportReplaceScenarios(const SmallSource, LargeSource: string);
    class procedure ReportEmphasisScenarios;
    class procedure PrintValue(const Name: string; const Value: Double);
    class procedure PrintError(const Name: string; const Error: Exception);
    class function MedianOf(const Values: TArray<Double>): Double;

  public
    class procedure RunAll;
    class function GenerateDocument(const TargetLength: Integer): string;
    class function BuildAlternatingEmphasis(const DelimiterCount: Integer): string;
    class function BuildUnclosedEmphasis(const OpenerCount: Integer): string;
    class function BuildNestedListMarkers(const MarkerCount: Integer): string;
    class function MeasureFullParseMedian(const Source: string; const Dialect: TMarkdownDialect; const Runs: Integer): Double;
    class function MeasureAppendChunkMedian(const Source: string; const Dialect: TMarkdownDialect; const ChunkLength: Integer): Double;
    class function MeasureReplaceMedian(const Source: string; const Dialect: TMarkdownDialect; const PositionCount: Integer): Double;
    class function ScalingRatio(const SmallMedian, LargeMedian: Double): Double;
  end;

implementation

uses
  System.StrUtils,
  System.Math,
  System.Diagnostics,
  System.Generics.Collections,
  Markdown4D.Parser.Interfaces,
  Markdown4D;

class procedure TBenchmarkScenarios.RunAll;
begin
  const OneMegabyteDocument = GenerateDocument(OneMegabyteLength);
  const HundredKilobyteDocument = GenerateDocument(HundredKilobyteLength);

  ReportFullParseScenario(OneMegabyteDocument);

  ReportAppendScenario(OneMegabyteDocument);

  ReportReplaceScenarios(HundredKilobyteDocument, OneMegabyteDocument);

  ReportEmphasisScenarios;
end;

class function TBenchmarkScenarios.GenerateDocument(const TargetLength: Integer): string;
begin
  const Builder = TStringBuilder.Create;
  try
    var SectionIndex := 0;

    while Builder.Length < TargetLength do
    begin
      Inc(SectionIndex);
      Builder.Append(Format(DocumentSectionFormat, [SectionIndex]));
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class procedure TBenchmarkScenarios.ReportFullParseScenario(const Source: string);
begin
  try
    PrintValue(FullParseScenarioName, MeasureFullParseMedian(Source, TMarkdownDialect.Gfm, FullParseRuns));
  except
    on E: Exception do
      PrintError(FullParseScenarioName, E);
  end;
end;

class procedure TBenchmarkScenarios.ReportAppendScenario(const Source: string);
begin
  try
    PrintValue(AppendChunkScenarioName, MeasureAppendChunkMedian(Source, TMarkdownDialect.Gfm, BenchmarkChunkLength));
  except
    on E: Exception do
      PrintError(AppendChunkScenarioName, E);
  end;
end;

class procedure TBenchmarkScenarios.ReportReplaceScenarios(const SmallSource, LargeSource: string);
begin
  try
    const SmallMedian = MeasureReplaceMedian(SmallSource, TMarkdownDialect.Gfm, BenchmarkReplacePositionCount);
    const LargeMedian = MeasureReplaceMedian(LargeSource, TMarkdownDialect.Gfm, BenchmarkReplacePositionCount);

    PrintValue(ReplaceSmallInHundredKbScenarioName, SmallMedian);
    PrintValue(ReplaceSmallInLargeScenarioName, LargeMedian);
    PrintValue(ReplaceScalingScenarioName, ScalingRatio(SmallMedian, LargeMedian));
  except
    on E: Exception do
    begin
      PrintError(ReplaceSmallInHundredKbScenarioName, E);
      PrintError(ReplaceSmallInLargeScenarioName, E);
      PrintError(ReplaceScalingScenarioName, E);
    end;
  end;
end;

class procedure TBenchmarkScenarios.ReportEmphasisScenarios;
begin
  try
    const ClosedMedian = MeasureFullParseMedian(BuildAlternatingEmphasis(ClosedEmphasisDelimiterCount), TMarkdownDialect.CommonMark, EmphasisRuns);
    const UnclosedMedian = MeasureFullParseMedian(BuildUnclosedEmphasis(UnclosedEmphasisOpenerCount), TMarkdownDialect.CommonMark, EmphasisRuns);

    PrintValue(EmphasisClosedScenarioName, ClosedMedian);
    PrintValue(EmphasisUnclosedScenarioName, UnclosedMedian);
    PrintValue(EmphasisScenarioName, ClosedMedian + UnclosedMedian);
  except
    on E: Exception do
    begin
      PrintError(EmphasisClosedScenarioName, E);
      PrintError(EmphasisUnclosedScenarioName, E);
      PrintError(EmphasisScenarioName, E);
    end;
  end;
end;

class function TBenchmarkScenarios.MeasureFullParseMedian(const Source: string; const Dialect: TMarkdownDialect; const Runs: Integer): Double;
begin
  var Durations: TArray<Double>;
  SetLength(Durations, Runs);

  for var Index := 0 to Runs - 1 do
  begin
    const Stopwatch = TStopwatch.StartNew;
    TMarkdown.ToHtml(Source, Dialect);
    Durations[Index] := Stopwatch.Elapsed.TotalMilliseconds;
  end;

  Result := MedianOf(Durations);
end;

class function TBenchmarkScenarios.MeasureAppendChunkMedian(const Source: string; const Dialect: TMarkdownDialect; const ChunkLength: Integer): Double;
begin
  const Parser = TMarkdown.CreateIncrementalParser(Dialect);
  const ChunkCount = (Length(Source) + ChunkLength - 1) div ChunkLength;

  var Durations: TArray<Double>;
  SetLength(Durations, ChunkCount);

  var Position := 1;
  for var Index := 0 to ChunkCount - 1 do
  begin
    const Chunk = Copy(Source, Position, ChunkLength);
    const Stopwatch = TStopwatch.StartNew;
    Parser.Append(Chunk);
    Durations[Index] := Stopwatch.Elapsed.TotalMilliseconds;
    Inc(Position, ChunkLength);
  end;

  Result := MedianOf(Durations);
end;

class function TBenchmarkScenarios.MeasureReplaceMedian(const Source: string; const Dialect: TMarkdownDialect; const PositionCount: Integer): Double;
begin
  const Parser = TMarkdown.CreateIncrementalParser(Dialect);
  Parser.Append(Source);
  Parser.ToHtml;

  const RegionStart = Max(1, Length(Source) div 4);
  const Step = Max(1, (Length(Source) div 2) div PositionCount);

  var Durations: TArray<Double>;
  SetLength(Durations, PositionCount);

  for var Index := 0 to PositionCount - 1 do
  begin
    const StartIndex = RegionStart + (Index * Step);
    const Stopwatch = TStopwatch.StartNew;
    Parser.ReplaceRange(StartIndex, ReplacedCharacterCount, ReplacementText);
    Durations[Index] := Stopwatch.Elapsed.TotalMilliseconds;
  end;

  Result := MedianOf(Durations);
end;

class function TBenchmarkScenarios.BuildAlternatingEmphasis(const DelimiterCount: Integer): string;
begin
  Result := DupeString(AlternatingEmphasisUnit, DelimiterCount);
end;

class function TBenchmarkScenarios.BuildUnclosedEmphasis(const OpenerCount: Integer): string;
begin
  Result := DupeString(UnclosedEmphasisUnit, OpenerCount);
end;

// A single line of list markers opens one list per marker, which is the shape
// that used to make block parsing quadratic in the length of the line.
class function TBenchmarkScenarios.BuildNestedListMarkers(const MarkerCount: Integer): string;
begin
  Result := DupeString(NestedListMarkerUnit, MarkerCount) + 'x';
end;

class function TBenchmarkScenarios.ScalingRatio(const SmallMedian, LargeMedian: Double): Double;
begin
  Result := LargeMedian / Max(SmallMedian, MinimumMedianMilliseconds);
end;

class procedure TBenchmarkScenarios.PrintValue(const Name: string; const Value: Double);
begin
  Writeln(Format(ValueLineFormat, [Name, Value], TFormatSettings.Invariant));
end;

class procedure TBenchmarkScenarios.PrintError(const Name: string; const Error: Exception);
begin
  Writeln(Format(ErrorLineFormat, [Name, Error.ClassName, Error.Message]));
end;

class function TBenchmarkScenarios.MedianOf(const Values: TArray<Double>): Double;
begin
  const Count = Length(Values);
  if Count = 0 then
    Exit(0);

  var Sorted := Copy(Values, 0, Count);
  TArray.Sort<Double>(Sorted);

  const MiddleIndex = Count div 2;
  const HasEvenCount = ((Count mod 2) = 0);
  if HasEvenCount then
    Result := (Sorted[MiddleIndex - 1] + Sorted[MiddleIndex]) / 2
  else
    Result := Sorted[MiddleIndex];
end;

end.
