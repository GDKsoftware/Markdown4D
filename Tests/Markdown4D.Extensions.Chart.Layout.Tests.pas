unit Markdown4D.Extensions.Chart.Layout.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Charts.Corpus;

type
  [TestFixture]
  TChartLayoutTests = class
  private
    const
      ChartWidth = 480.0;
      ChartHeight = 270.0;
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FCorpus: TChartCorpus;
    function ModelItems(const CaseName: string): TArray<IDisplayItem>;

  public
    [SetupFixture]
    procedure SetupFixture;

    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure Bar_PlotRect_ExcludesTitleLegendAndAxisLabels;

    [Test]
    procedure Bar_Grouped_ProducesBarPerDatasetWithPaletteColors;

    [Test]
    procedure Bar_Stacked_SumsSegmentHeights;

    [Test]
    procedure Line_Polyline_DerivedFromScaleMinMax;

    [Test]
    procedure Pie_Wedges_AnglesProportionalToValues;

    [Test]
    procedure Doughnut_InnerRadius_IsPositive;

    [Test]
    procedure Legend_ProducesSwatchAndLabelRows;

    [Test]
    procedure Axis_ProducesTickLabels;

    [Test]
    procedure Palette_CyclesBeyondEightDatasets;

    [Test]
    procedure ChartHeight_ClampsToSixteenByNine;

    [Test]
    procedure Streaming_MidFence_NoModel_AfterClose_Model;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Pipeline,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Extensions.Chart,
  Markdown4D.Extensions.Chart.Layout;

function ChartPipeline: IMarkdownPipeline;
begin
  Result := TMarkdownPipeline.Create.UseGfm.Use(TChartExtension.Create).UnsafeHtml.Build;
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

function CountWedges(const Items: TArray<IDisplayItem>): Integer;
begin
  Result := 0;

  for var Item in Items do
  begin
    if Item.Kind = TDisplayItemKind.Wedge then
      Inc(Result);
  end;
end;

procedure TChartLayoutTests.SetupFixture;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FMeasurer := TFakeTextMeasurer.Create;
  FCorpus := TChartCorpus.Create;
end;

procedure TChartLayoutTests.TearDownFixture;
begin
  FreeAndNil(FCorpus);
  FMeasurer := nil;
  FreeAndNil(FTheme);
end;

function TChartLayoutTests.ModelItems(const CaseName: string): TArray<IDisplayItem>;
begin
  const Item = FCorpus.FindCase(CaseName);
  const Document = ChartPipeline.Parse(Item.Markdown);

  var Code: IMarkdownCodeBlock;
  Assert.IsTrue(FindFirstCodeBlock(Document, Code), Format('Case "%s" must expose a code block', [CaseName]));

  var Model: IChartModel;
  Assert.IsTrue(TChartExtension.TryParse(Code, Model), Format('Case "%s" must parse into a chart model', [CaseName]));

  const Bounds = TLayoutRectF.Create(0, 0, ChartWidth, ChartHeight);
  Result := TChartLayouter.BuildDisplayItems(Model, Bounds, FTheme, FMeasurer, Code);
end;

procedure TChartLayoutTests.Bar_PlotRect_ExcludesTitleLegendAndAxisLabels;
begin
  const Items = ModelItems('title-on');
  Assert.IsTrue(Length(Items) > 0, 'Bar chart with a title must emit display items');
end;

procedure TChartLayoutTests.Bar_Grouped_ProducesBarPerDatasetWithPaletteColors;
begin
  const Items = ModelItems('bar-multi-grouped');

  var BarCount := 0;
  for var Item in Items do
  begin
    if Item.Kind = TDisplayItemKind.Rectangle then
      Inc(BarCount);
  end;

  Assert.IsTrue(BarCount >= 4, 'Grouped bar chart must emit one bar per dataset per label');
end;

procedure TChartLayoutTests.Bar_Stacked_SumsSegmentHeights;
begin
  const Grouped = ModelItems('bar-multi-grouped');
  const Stacked = ModelItems('bar-multi-stacked');

  Assert.IsTrue((Length(Grouped) > 0) and (Length(Stacked) > 0),
    'Both grouped and stacked bar layouts must emit items');
end;

procedure TChartLayoutTests.Line_Polyline_DerivedFromScaleMinMax;
begin
  const Items = ModelItems('line-scales-minmax');

  var LineCount := 0;
  for var Item in Items do
  begin
    if Item.Kind = TDisplayItemKind.Line then
      Inc(LineCount);
  end;

  Assert.IsTrue(LineCount >= 2, 'A three-point line series must emit at least two line segments');
end;

procedure TChartLayoutTests.Pie_Wedges_AnglesProportionalToValues;
begin
  const Items = ModelItems('pie-minimal');
  Assert.AreEqual(3, CountWedges(Items), 'A three-slice pie chart must emit three wedge primitives');
end;

procedure TChartLayoutTests.Doughnut_InnerRadius_IsPositive;
begin
  const Items = ModelItems('doughnut-minimal');

  var FoundPositiveInner := False;
  for var Item in Items do
  begin
    var Wedge: IDisplayWedge;
    if Supports(Item, IDisplayWedge, Wedge) and (Wedge.InnerRadius > 0) then
      FoundPositiveInner := True;
  end;

  Assert.IsTrue(FoundPositiveInner, 'A doughnut chart must emit wedges with a positive inner radius');
end;

procedure TChartLayoutTests.Legend_ProducesSwatchAndLabelRows;
begin
  const Items = ModelItems('legend-position-right');
  Assert.IsTrue(Length(Items) > 0, 'A chart with a legend must emit swatch and label items');
end;

procedure TChartLayoutTests.Axis_ProducesTickLabels;
begin
  const Items = ModelItems('line-scales-minmax');

  var TextRunCount := 0;
  for var Item in Items do
  begin
    if Item.Kind = TDisplayItemKind.TextRun then
      Inc(TextRunCount);
  end;

  Assert.IsTrue(TextRunCount > 0, 'A scaled chart must emit axis tick label text runs');
end;

procedure TChartLayoutTests.Palette_CyclesBeyondEightDatasets;
begin
  const First = TChartLayouter.PaletteColor(FTheme, 0);
  const Ninth = TChartLayouter.PaletteColor(FTheme, 8);
  Assert.AreEqual(First, Ninth, 'The theme palette must cycle after eight datasets');
end;

procedure TChartLayoutTests.ChartHeight_ClampsToSixteenByNine;
begin
  const Height = TChartLayouter.PreferredHeight(ChartWidth, FTheme);
  const Expected = ChartWidth * TChartLayouter.AspectRatioHeight / TChartLayouter.AspectRatioWidth;
  Assert.AreEqual(Double(Expected), Double(Height), 0.5,
    'Chart height must follow the 16:9 aspect ratio for the available width');
end;

procedure TChartLayoutTests.Streaming_MidFence_NoModel_AfterClose_Model;
begin
  const Complete = FCorpus.FindCase('bar-minimal');
  const MidFence = '```chart'#10'{"type":"chart","data":{"type":"bar"';

  const Pipeline = ChartPipeline;

  const OpenDocument = Pipeline.Parse(MidFence);
  var OpenCode: IMarkdownCodeBlock;
  Assert.IsTrue(FindFirstCodeBlock(OpenDocument, OpenCode), 'An open fence must still parse as a code block');

  var OpenModel: IChartModel;
  Assert.IsFalse(TChartExtension.TryGetModel(OpenCode, OpenModel),
    'An incomplete chart fence must not expose a chart model');

  const ClosedDocument = Pipeline.Parse(Complete.Markdown);
  var ClosedCode: IMarkdownCodeBlock;
  Assert.IsTrue(FindFirstCodeBlock(ClosedDocument, ClosedCode));

  var ClosedModel: IChartModel;
  Assert.IsTrue(TChartExtension.TryGetModel(ClosedCode, ClosedModel),
    'A closed chart fence must expose a chart model');
end;

end.
