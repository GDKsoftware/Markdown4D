unit Markdown4D.Extensions.Chart.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Charts.Corpus;

type
  [TestFixture]
  TChartExtensionTests = class
  private
    const
      ExpectedCaseCount = 31;
      InlineCaseName = 'inline-code-chart';
    var
      FCorpus: TChartCorpus;

  public
    [SetupFixture]
    procedure SetupFixture;

    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure Corpus_LoadsAllCases;

    [Test]
    procedure Detection_DetectedCases_ExposeModelViaChannel;

    [Test]
    procedure Detection_FallbackCases_ProduceNoModel;

    [Test]
    procedure Model_ResolvesTypeSeriesAndLabels;

    [Test]
    procedure Model_HorizontalBar_SetsHorizontalFlag;

    [Test]
    procedure Model_AreaDataset_SetsFillFlag;

    [Test]
    procedure Model_Radar_ResolvesKindAndValues;

    [Test]
    procedure Model_Scatter_ResolvesPointData;

    [Test]
    procedure Html_FencedCases_RenderPlainCodeBlock;

    [Test]
    procedure Writer_RoundTrip_PreservesChartJson;

    [Test]
    procedure OptIn_WithoutExtension_HtmlIsUnchanged;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Pipeline,
  Markdown4D.Extensions.Chart;

function ChartPipeline: IMarkdownPipeline;
begin
  Result := TMarkdownPipeline.Create.UseGfm.Use(TChartExtension.Create).UnsafeHtml.Build;
end;

function PlainPipeline: IMarkdownPipeline;
begin
  Result := TMarkdownPipeline.Create.UseGfm.UnsafeHtml.Build;
end;

function FindFirstCodeBlock(const Document: IMarkdownDocument; out Code: IMarkdownCodeBlock): Boolean;
begin
  Code := nil;

  for var Index := 0 to Document.ChildCount - 1 do
  begin
    const Child = Document.Children[Index];
    if Child.Kind = TMarkdownNodeKind.CodeBlock then
    begin
      Code := Child as IMarkdownCodeBlock;
      Exit(True);
    end;
  end;

  Result := False;
end;

procedure TChartExtensionTests.SetupFixture;
begin
  FCorpus := TChartCorpus.Create;
end;

procedure TChartExtensionTests.TearDownFixture;
begin
  FreeAndNil(FCorpus);
end;

procedure TChartExtensionTests.Corpus_LoadsAllCases;
begin
  Assert.AreEqual(ExpectedCaseCount, FCorpus.Count,
    Format('%s must contain %d cases', [TChartCorpus.CorpusFileName, ExpectedCaseCount]));
end;

procedure TChartExtensionTests.Detection_DetectedCases_ExposeModelViaChannel;
begin
  for var Index := 0 to FCorpus.Count - 1 do
  begin
    const Item = FCorpus[Index];
    if not Item.Detected then
      Continue;

    const Document = ChartPipeline.Parse(Item.Markdown);

    var Code: IMarkdownCodeBlock;
    Assert.IsTrue(FindFirstCodeBlock(Document, Code), Format('Case "%s" must expose a code block', [Item.Name]));

    var Model: IChartModel;
    Assert.IsTrue(TChartExtension.TryGetModel(Code, Model),
      Format('Case "%s" must expose a chart model via the extension-data channel', [Item.Name]));
    Assert.IsNotNull(Model, Format('Case "%s" model must not be nil', [Item.Name]));
  end;
end;

procedure TChartExtensionTests.Detection_FallbackCases_ProduceNoModel;
begin
  for var Index := 0 to FCorpus.Count - 1 do
  begin
    const Item = FCorpus[Index];
    if Item.Detected or (Item.Name = InlineCaseName) then
      Continue;

    const Document = ChartPipeline.Parse(Item.Markdown);

    var Code: IMarkdownCodeBlock;
    if not FindFirstCodeBlock(Document, Code) then
      Continue;

    var Model: IChartModel;
    Assert.IsFalse(TChartExtension.TryGetModel(Code, Model),
      Format('Fallback case "%s" must not produce a chart model', [Item.Name]));
  end;
end;

procedure TChartExtensionTests.Model_ResolvesTypeSeriesAndLabels;
begin
  const Item = FCorpus.FindCase('bar-multi-grouped');
  const Document = ChartPipeline.Parse(Item.Markdown);

  var Code: IMarkdownCodeBlock;
  Assert.IsTrue(FindFirstCodeBlock(Document, Code));

  var Model: IChartModel;
  Assert.IsTrue(TChartExtension.TryParse(Code, Model));
  Assert.AreEqual(Ord(TChartKind.Bar), Ord(Model.ChartKind));
  Assert.AreEqual(2, Model.DatasetCount);
  Assert.AreEqual(2, Model.LabelCount);
  Assert.AreEqual(Double(1), Model.Datasets[0].Values[0], 0.001);
  Assert.AreEqual('North', Model.Datasets[0].Caption);
end;

function ParseModel(const Markdown: string): IChartModel;
begin
  const Document = ChartPipeline.Parse(Markdown);

  var Code: IMarkdownCodeBlock;
  Assert.IsTrue(FindFirstCodeBlock(Document, Code), 'Case must expose a code block');
  Assert.IsTrue(TChartExtension.TryParse(Code, Result), 'Case must parse into a chart model');
end;

procedure TChartExtensionTests.Model_HorizontalBar_SetsHorizontalFlag;
begin
  const Model = ParseModel(FCorpus.FindCase('bar-horizontal').Markdown);
  Assert.AreEqual(Ord(TChartKind.Bar), Ord(Model.ChartKind));
  Assert.IsTrue(Model.Horizontal, 'indexAxis "y" must set the horizontal flag');
end;

procedure TChartExtensionTests.Model_AreaDataset_SetsFillFlag;
begin
  const Model = ParseModel(FCorpus.FindCase('line-area').Markdown);
  Assert.AreEqual(Ord(TChartKind.Line), Ord(Model.ChartKind));
  Assert.IsTrue(Model.Datasets[0].Fill, 'A dataset with fill:true must set the fill flag');
end;

procedure TChartExtensionTests.Model_Radar_ResolvesKindAndValues;
begin
  const Model = ParseModel(FCorpus.FindCase('radar-minimal').Markdown);
  Assert.AreEqual(Ord(TChartKind.Radar), Ord(Model.ChartKind));
  Assert.AreEqual(3, Model.LabelCount);
  Assert.AreEqual(Double(5), Model.Datasets[0].Values[1], 0.001);
end;

procedure TChartExtensionTests.Model_Scatter_ResolvesPointData;
begin
  const Model = ParseModel(FCorpus.FindCase('scatter-minimal').Markdown);
  Assert.AreEqual(Ord(TChartKind.Scatter), Ord(Model.ChartKind));
  Assert.AreEqual(3, Model.Datasets[0].PointCount);
  Assert.AreEqual(Double(5), Model.Datasets[0].PointsX[2], 0.001);
  Assert.AreEqual(Double(1), Model.Datasets[0].PointsY[2], 0.001);
end;

procedure TChartExtensionTests.Html_FencedCases_RenderPlainCodeBlock;
begin
  const Pipeline = ChartPipeline;

  for var Index := 0 to FCorpus.Count - 1 do
  begin
    const Item = FCorpus[Index];
    if Item.Name = InlineCaseName then
      Continue;

    const Html = Pipeline.ToHtml(Item.Markdown);
    Assert.IsTrue(Html.Contains('<pre><code'),
      Format('Case "%s" must still render as a fenced code block in HTML', [Item.Name]));
  end;
end;

procedure TChartExtensionTests.Writer_RoundTrip_PreservesChartJson;
begin
  const ChartPipe = ChartPipeline;

  for var Index := 0 to FCorpus.Count - 1 do
  begin
    const Item = FCorpus[Index];
    if Item.Name = InlineCaseName then
      Continue;

    const Document = ChartPipe.Parse(Item.Markdown);

    var Code: IMarkdownCodeBlock;
    if not FindFirstCodeBlock(Document, Code) then
      Continue;

    const OriginalLiteral = Code.Literal;
    const Rewritten = TMarkdown.ToMarkdown(Document);
    const Reparsed = ChartPipe.Parse(Rewritten);

    var ReparsedCode: IMarkdownCodeBlock;
    Assert.IsTrue(FindFirstCodeBlock(Reparsed, ReparsedCode),
      Format('Case "%s" must round-trip to a code block', [Item.Name]));
    Assert.AreEqual(OriginalLiteral, ReparsedCode.Literal,
      Format('Case "%s" chart JSON must survive the writer byte-for-byte', [Item.Name]));
  end;
end;

procedure TChartExtensionTests.OptIn_WithoutExtension_HtmlIsUnchanged;
begin
  const ChartPipe = ChartPipeline;
  const PlainPipe = PlainPipeline;

  for var Index := 0 to FCorpus.Count - 1 do
  begin
    const Item = FCorpus[Index];
    Assert.AreEqual(PlainPipe.ToHtml(Item.Markdown), ChartPipe.ToHtml(Item.Markdown),
      Format('Case "%s" HTML must be identical with and without the chart extension', [Item.Name]));
  end;
end;

end.
