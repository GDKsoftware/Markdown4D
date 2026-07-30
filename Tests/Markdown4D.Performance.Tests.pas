unit Markdown4D.Performance.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TPerformanceBudgetTests = class
  private
    const
      HundredKilobyteLength = 100 * 1024;
      FourHundredKilobyteLength = 400 * 1024;
      AppendChunkLength = 200;
      ReplaceSamplePositionCount = 25;
      EmphasisDelimiterCount = 2500;
      SingleRun = 1;
      AppendMedianBudgetMilliseconds = 5.0;
      ReplaceMedianBudgetMilliseconds = 10.0;
      ReplaceScalingRatioBudget = 2.5;
      EmphasisBudgetMilliseconds = 500.0;
      NestedListMarkerCount = 10000;
      NestedListMarkerScalingCount = 20000;
      NestedListBudgetMilliseconds = 500.0;
      NestedListScalingRatioBudget = 3.0;
      AngleBracketCount = 20000;
      AngleBracketScalingCount = 40000;
      AngleBracketBudgetMilliseconds = 500.0;
      AngleBracketScalingRatioBudget = 3.0;
    var
      FHundredKilobyteDocument: string;
      FFourHundredKilobyteDocument: string;

  public
    [SetupFixture]
    procedure SetupFixture;

    [Test]
    procedure Append_HundredKilobyteDocumentInChunks_MedianStaysUnderBudget;

    [Test]
    procedure ReplaceRange_SmallEditInHundredKilobyteDocument_MedianStaysUnderBudget;

    [Test]
    procedure ReplaceRange_HundredKilobyteVersusFourHundredKilobyte_ScalingRatioStaysUnderBudget;

    [Test]
    procedure Parse_AlternatingEmphasisDelimiters_StaysUnderBudget;

    [Test]
    procedure Parse_UnclosedEmphasisOpeners_StaysUnderBudget;

    [Test]
    procedure Parse_NestedListMarkers_StaysUnderBudget;

    [Test]
    procedure Parse_NestedListMarkers_ScalingRatioStaysUnderBudget;

    [Test]
    procedure Parse_AngleBracketRun_StaysUnderBudget;

    [Test]
    procedure Parse_AngleBracketRun_ScalingRatioStaysUnderBudget;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Defines,
  Markdown4D.Benchmarks.Scenarios;

procedure TPerformanceBudgetTests.SetupFixture;
begin
  FHundredKilobyteDocument := TBenchmarkScenarios.GenerateDocument(HundredKilobyteLength);
  FFourHundredKilobyteDocument := TBenchmarkScenarios.GenerateDocument(FourHundredKilobyteLength);
end;

procedure TPerformanceBudgetTests.Append_HundredKilobyteDocumentInChunks_MedianStaysUnderBudget;
begin
  const Median = TBenchmarkScenarios.MeasureAppendChunkMedian(FHundredKilobyteDocument, TMarkdownDialect.Gfm, AppendChunkLength);

  const WithinBudget = (Median < AppendMedianBudgetMilliseconds);
  Assert.IsTrue(WithinBudget, Format('Median Append latency of %.3f ms exceeds the %.1f ms budget', [Median, AppendMedianBudgetMilliseconds]));
end;

procedure TPerformanceBudgetTests.ReplaceRange_SmallEditInHundredKilobyteDocument_MedianStaysUnderBudget;
begin
  const Median = TBenchmarkScenarios.MeasureReplaceMedian(FHundredKilobyteDocument, TMarkdownDialect.Gfm, ReplaceSamplePositionCount);

  const WithinBudget = (Median < ReplaceMedianBudgetMilliseconds);
  Assert.IsTrue(WithinBudget, Format('Median ReplaceRange latency of %.3f ms exceeds the %.1f ms budget', [Median, ReplaceMedianBudgetMilliseconds]));
end;

procedure TPerformanceBudgetTests.ReplaceRange_HundredKilobyteVersusFourHundredKilobyte_ScalingRatioStaysUnderBudget;
begin
  const SmallMedian = TBenchmarkScenarios.MeasureReplaceMedian(FHundredKilobyteDocument, TMarkdownDialect.Gfm, ReplaceSamplePositionCount);
  const LargeMedian = TBenchmarkScenarios.MeasureReplaceMedian(FFourHundredKilobyteDocument, TMarkdownDialect.Gfm, ReplaceSamplePositionCount);

  const Ratio = TBenchmarkScenarios.ScalingRatio(SmallMedian, LargeMedian);
  const WithinBudget = (Ratio < ReplaceScalingRatioBudget);
  Assert.IsTrue(WithinBudget, Format('ReplaceRange scaling ratio of %.3f (small median %.3f ms, large median %.3f ms) exceeds the %.1f budget', [Ratio, SmallMedian, LargeMedian, ReplaceScalingRatioBudget]));
end;

procedure TPerformanceBudgetTests.Parse_AlternatingEmphasisDelimiters_StaysUnderBudget;
begin
  const Source = TBenchmarkScenarios.BuildAlternatingEmphasis(EmphasisDelimiterCount);

  const ElapsedMilliseconds = TBenchmarkScenarios.MeasureFullParseMedian(Source, TMarkdownDialect.CommonMark, SingleRun);
  const WithinBudget = (ElapsedMilliseconds < EmphasisBudgetMilliseconds);
  Assert.IsTrue(WithinBudget, Format('Parsing %d alternating emphasis delimiters took %.3f ms which exceeds the %.1f ms budget', [EmphasisDelimiterCount, ElapsedMilliseconds, EmphasisBudgetMilliseconds]));
end;

procedure TPerformanceBudgetTests.Parse_UnclosedEmphasisOpeners_StaysUnderBudget;
begin
  const Source = TBenchmarkScenarios.BuildUnclosedEmphasis(EmphasisDelimiterCount);

  const ElapsedMilliseconds = TBenchmarkScenarios.MeasureFullParseMedian(Source, TMarkdownDialect.CommonMark, SingleRun);
  const WithinBudget = (ElapsedMilliseconds < EmphasisBudgetMilliseconds);
  Assert.IsTrue(WithinBudget, Format('Parsing %d unclosed emphasis openers took %.3f ms which exceeds the %.1f ms budget', [EmphasisDelimiterCount, ElapsedMilliseconds, EmphasisBudgetMilliseconds]));
end;

procedure TPerformanceBudgetTests.Parse_NestedListMarkers_StaysUnderBudget;
begin
  const Source = TBenchmarkScenarios.BuildNestedListMarkers(NestedListMarkerCount);

  const ElapsedMilliseconds = TBenchmarkScenarios.MeasureFullParseMedian(Source, TMarkdownDialect.CommonMark, SingleRun);
  const WithinBudget = (ElapsedMilliseconds < NestedListBudgetMilliseconds);
  Assert.IsTrue(WithinBudget, Format('Parsing %d nested list markers took %.3f ms which exceeds the %.1f ms budget', [NestedListMarkerCount, ElapsedMilliseconds, NestedListBudgetMilliseconds]));
end;

// Guards the shape rather than the clock: doubling the markers on one line may
// double the work, not quadruple it.
procedure TPerformanceBudgetTests.Parse_NestedListMarkers_ScalingRatioStaysUnderBudget;
begin
  const SmallSource = TBenchmarkScenarios.BuildNestedListMarkers(NestedListMarkerCount);
  const LargeSource = TBenchmarkScenarios.BuildNestedListMarkers(NestedListMarkerScalingCount);

  const SmallMedian = TBenchmarkScenarios.MeasureFullParseMedian(SmallSource, TMarkdownDialect.CommonMark, SingleRun);
  const LargeMedian = TBenchmarkScenarios.MeasureFullParseMedian(LargeSource, TMarkdownDialect.CommonMark, SingleRun);

  const Ratio = TBenchmarkScenarios.ScalingRatio(SmallMedian, LargeMedian);
  const WithinBudget = (Ratio < NestedListScalingRatioBudget);
  Assert.IsTrue(WithinBudget, Format('Nested list marker scaling ratio of %.3f (%d markers %.3f ms, %d markers %.3f ms) exceeds the %.1f budget', [Ratio, NestedListMarkerCount, SmallMedian, NestedListMarkerScalingCount, LargeMedian, NestedListScalingRatioBudget]));
end;

procedure TPerformanceBudgetTests.Parse_AngleBracketRun_StaysUnderBudget;
begin
  const Source = TBenchmarkScenarios.BuildAngleBracketRun(AngleBracketCount);

  const ElapsedMilliseconds = TBenchmarkScenarios.MeasureFullParseMedian(Source, TMarkdownDialect.CommonMark, SingleRun);
  const WithinBudget = (ElapsedMilliseconds < AngleBracketBudgetMilliseconds);
  Assert.IsTrue(WithinBudget, Format('Parsing %d angle brackets took %.3f ms which exceeds the %.1f ms budget', [AngleBracketCount, ElapsedMilliseconds, AngleBracketBudgetMilliseconds]));
end;

// Guards the shape rather than the clock: doubling the brackets in one
// paragraph may double the work, not quadruple it.
procedure TPerformanceBudgetTests.Parse_AngleBracketRun_ScalingRatioStaysUnderBudget;
begin
  const SmallSource = TBenchmarkScenarios.BuildAngleBracketRun(AngleBracketCount);
  const LargeSource = TBenchmarkScenarios.BuildAngleBracketRun(AngleBracketScalingCount);

  const SmallMedian = TBenchmarkScenarios.MeasureFullParseMedian(SmallSource, TMarkdownDialect.CommonMark, SingleRun);
  const LargeMedian = TBenchmarkScenarios.MeasureFullParseMedian(LargeSource, TMarkdownDialect.CommonMark, SingleRun);

  const Ratio = TBenchmarkScenarios.ScalingRatio(SmallMedian, LargeMedian);
  const WithinBudget = (Ratio < AngleBracketScalingRatioBudget);
  Assert.IsTrue(WithinBudget, Format('Angle bracket scaling ratio of %.3f (%d brackets %.3f ms, %d brackets %.3f ms) exceeds the %.1f budget', [Ratio, AngleBracketCount, SmallMedian, AngleBracketScalingCount, LargeMedian, AngleBracketScalingRatioBudget]));
end;

end.
