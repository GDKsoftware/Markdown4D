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

end.
