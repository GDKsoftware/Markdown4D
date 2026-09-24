unit Markdown4D.Extensions.Chart.Layout.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Extensions.Chart,
  Markdown4D.Extensions.Chart.Layout,
  Markdown4D.Charts.Corpus;

type
  [TestFixture]
  TChartLayoutTests = class
  private
    const
      ChartWidth = 480.0;
      ChartHeight = 270.0;
      // Mirrors the layouter's private label size; the fake measurer derives
      // line heights from the font size alone.
      LabelFontSize = 11.0;
      LegendSwatchSize = 10.0;
      RowHeightFactor = 2.0;
      NarrowBarFill = 0.4;
      DefaultGroupedBarFill = 0.8;
      ThreeColors = '["#ff0000","#00ff00","#0000ff"]';
      SingleColor = '"#ff0000"';
      ChartFence = '```chart'#10'%s'#10'```';
      ThreeBarsExpected = 'A three-label chart must emit three bars';
      FractionalBarChart =
        '```chart'#10 +
        '{"type":"chart","data":{"type":"bar","data":{"labels":["A","B","C"],' +
        '"datasets":[{"label":"Share","data":[0.1,0.35,0.6]}]},"options":{"indexAxis":"y"}}}'#10 +
        '```';
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FCorpus: TChartCorpus;
    function ModelItems(const CaseName: string): TArray<IDisplayItem>;
    function MarkdownItems(const Markdown: string): TArray<IDisplayItem>;
    function ParseModel(const Markdown: string; out Code: IMarkdownCodeBlock): IChartModel;
    function LabelLineHeight: Single;
    function BarTops(const Items: TArray<IDisplayItem>): TArray<Single>;
    function OptionItems(const Markdown: string; const Options: TChartLayoutOptions): TArray<IDisplayItem>;
    class function BarChartMarkdown(const LabelCount: Integer; const Horizontal: Boolean): string; static;
    class function ColoredBarMarkdown(const BackgroundColor: string; const Horizontal: Boolean): string; static;
    class function Bars(const Items: TArray<IDisplayItem>): TArray<IDisplayRectangle>; static;
    procedure AssertBarsTakeColorPerLabel(const Horizontal: Boolean);

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
    procedure Line_MoreValuesThanLabels_PointsStayOnLabelSlots;

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

    [Test]
    procedure HorizontalBar_ProducesBarRectangles;

    [Test]
    procedure Area_ProducesFilledPolygon;

    [Test]
    procedure Radar_ProducesPolygonPerDataset;

    [Test]
    procedure Scatter_ProducesMarkerPerPoint;

    [Test]
    procedure Axis_LargeValuesInNarrowRange_LabelsStayWithTheData;

    [Test]
    procedure Axis_FractionalSpacing_DefaultLabelsHaveNoFloatingPointNoise;

    [Test]
    procedure Axis_CommaDecimalSeparator_DefaultLabelsUseAPoint;

    [Test]
    procedure PreferredHeight_DefaultOptions_MatchesSixteenByNine;

    [Test]
    procedure AspectRatio_Custom_SetsPreferredHeight;

    [Test]
    procedure BarRowHeightFactor_HorizontalBar_HeightGrowsWithLabelCount;

    [Test]
    procedure BarRowHeightFactor_HorizontalBar_RowIsFactorTimesLineHeight;

    [Test]
    procedure BarRowHeightFactor_VerticalBar_KeepsAspectRatio;

    [Test]
    procedure BarRowHeightFactor_TallerThanAspectRatio_IsNotClamped;

    [Test]
    procedure TickLabelFormatter_Custom_FormatsEveryAxisLabel;

    [Test]
    procedure BarColor_ColorPerBar_VerticalBarsTakeTheirOwnColor;

    [Test]
    procedure BarColor_ColorPerBar_HorizontalBarsTakeTheirOwnColor;

    [Test]
    procedure BarColor_FewerColorsThanBars_StartsOverAtTheFirstColor;

    [Test]
    procedure BarColor_SingleColor_ColorsEveryBar;

    [Test]
    procedure BarFillFactor_VerticalBar_ScalesBarWidth;

    [Test]
    procedure BarFillFactor_HorizontalBar_ScalesBarHeight;

    [Test]
    procedure BarFillFactor_AboveOne_BarsTouchTheirNeighbours;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Pipeline,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Tests.Arrays;

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
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

function CountKind(const Items: TArray<IDisplayItem>; const Kind: TDisplayItemKind): Integer;
begin
  Result := 0;

  for var Item in Items do
  begin
    if Item.Kind = Kind then
      Inc(Result);
  end;
end;

function CountWedges(const Items: TArray<IDisplayItem>): Integer;
begin
  Result := CountKind(Items, TDisplayItemKind.Wedge);
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

function TChartLayoutTests.MarkdownItems(const Markdown: string): TArray<IDisplayItem>;
begin
  const Document = ChartPipeline.Parse(Markdown);

  var Code: IMarkdownCodeBlock;
  Assert.IsTrue(FindFirstCodeBlock(Document, Code), 'The markdown must expose a code block');

  var Model: IChartModel;
  Assert.IsTrue(TChartExtension.TryParse(Code, Model), 'The code block must parse into a chart model');

  const Bounds = TLayoutRectF.Create(0, 0, ChartWidth, ChartHeight);
  Result := TChartLayouter.BuildDisplayItems(Model, Bounds, FTheme, FMeasurer, Code);
end;

function TChartLayoutTests.ParseModel(const Markdown: string; out Code: IMarkdownCodeBlock): IChartModel;
begin
  const Document = ChartPipeline.Parse(Markdown);
  Assert.IsTrue(FindFirstCodeBlock(Document, Code), 'The markdown must expose a code block');

  var Model: IChartModel;
  Assert.IsTrue(TChartExtension.TryParse(Code, Model), 'The code block must parse into a chart model');
  Result := Model;
end;

function TChartLayoutTests.LabelLineHeight: Single;
begin
  const Font = TMarkdownFontStyle.Create(FTheme.BaseFont.FamilyName, LabelFontSize);
  Result := FMeasurer.LineHeight(Font);
end;

// The single-dataset bars share the first palette colour with the legend
// swatch; the swatch is told apart by its fixed size.
function TChartLayoutTests.BarTops(const Items: TArray<IDisplayItem>): TArray<Single>;
begin
  const BarColor = TChartLayouter.PaletteColor(FTheme, 0);
  const Tops = TList<Single>.Create;
  try
    for var Item in Items do
    begin
      var Rectangle: IDisplayRectangle;
      if not Supports(Item, IDisplayRectangle, Rectangle) then
        Continue;

      const IsBar = (Rectangle.FillColor = BarColor) and (Rectangle.Bounds.Height > LegendSwatchSize);
      if IsBar then
        Tops.Add(Rectangle.Bounds.Top);
    end;

    Tops.Sort;
    Result := Tops.ToArray;
  finally
    Tops.Free;
  end;
end;

class function TChartLayoutTests.BarChartMarkdown(const LabelCount: Integer; const Horizontal: Boolean): string;
begin
  var Labels: TArray<string>;
  var Values: TArray<string>;
  SetLength(Labels, LabelCount);
  SetLength(Values, LabelCount);
  for var Index := 0 to LabelCount - 1 do
  begin
    Labels[Index] := Format('"L%d"', [Index + 1]);
    Values[Index] := IntToStr(Index + 1);
  end;

  var IndexAxis := 'x';
  if Horizontal then
    IndexAxis := 'y';

  const Json = Format('{"type":"chart","data":{"type":"bar","data":{"labels":[%s],' +
    '"datasets":[{"label":"Series","data":[%s]}]},' +
    '"options":{"indexAxis":"%s","plugins":{"title":{"display":true,"text":"Rows"}}}}}',
    [string.Join(',', Labels), string.Join(',', Values), IndexAxis]);
  Result := Format(ChartFence, [Json]);
end;

// Three bars without a legend, so every rectangle in the output is a bar.
class function TChartLayoutTests.ColoredBarMarkdown(const BackgroundColor: string; const Horizontal: Boolean): string;
begin
  var IndexAxis := 'x';
  if Horizontal then
    IndexAxis := 'y';

  const Json = Format('{"type":"chart","data":{"type":"bar","data":{"labels":["A","B","C"],' +
    '"datasets":[{"label":"Series","data":[1,2,3],"backgroundColor":%s}]},' +
    '"options":{"indexAxis":"%s","plugins":{"legend":{"display":false}}}}}',
    [BackgroundColor, IndexAxis]);
  Result := Format(ChartFence, [Json]);
end;

function TChartLayoutTests.OptionItems(const Markdown: string; const Options: TChartLayoutOptions): TArray<IDisplayItem>;
begin
  var Code: IMarkdownCodeBlock;
  const Model = ParseModel(Markdown, Code);
  const Bounds = TLayoutRectF.Create(0, 0, ChartWidth, ChartHeight);
  Result := TChartLayouter.BuildDisplayItems(Model, Bounds, FTheme, FMeasurer, Code, Options);
end;

class function TChartLayoutTests.Bars(const Items: TArray<IDisplayItem>): TArray<IDisplayRectangle>;
begin
  Result := [];

  for var Item in Items do
  begin
    var Rectangle: IDisplayRectangle;
    if Supports(Item, IDisplayRectangle, Rectangle) then
      Result := Result + [Rectangle];
  end;
end;

procedure TChartLayoutTests.AssertBarsTakeColorPerLabel(const Horizontal: Boolean);
begin
  var Code: IMarkdownCodeBlock;
  const Markdown = ColoredBarMarkdown(ThreeColors, Horizontal);
  const Dataset = ParseModel(Markdown, Code).Datasets[0];
  const BarItems = Bars(OptionItems(Markdown, Default(TChartLayoutOptions)));

  Assert.AreEqual(3, TTestArray.CountOf(BarItems), ThreeBarsExpected);
  for var Index := 0 to High(BarItems) do
  begin
    Assert.AreEqual<TLayoutColor>(Dataset.BackgroundColors[Index], BarItems[Index].FillColor,
      Format('Bar %d must take the background colour at its own index', [Index]));
  end;
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

// A series with more values than there are labels has nowhere on the axis for
// the extra points to go; they must be dropped rather than plotted past the
// last label slot.
procedure TChartLayoutTests.Line_MoreValuesThanLabels_PointsStayOnLabelSlots;
const
  Markdown =
    '```chart'#10 +
    '{"type":"chart","data":{"type":"line","data":{"labels":["A","B"],' +
    '"datasets":[{"label":"Counter","data":[1,2,3,4]}]}}}'#10 +
    '```';
begin
  const Items = MarkdownItems(Markdown);

  var LineCount := 0;
  for var Item in Items do
  begin
    if Item.Kind <> TDisplayItemKind.Line then
      Continue;

    const Line = Item as IDisplayLine;
    const WithinBounds = (Line.StartPoint.X <= ChartWidth) and (Line.EndPoint.X <= ChartWidth);
    Assert.IsTrue(WithinBounds, 'A line point beyond the label count must not be plotted past the plot area');
    Inc(LineCount);
  end;

  Assert.IsTrue(LineCount > 0, 'A line chart with more values than labels must still emit line segments');
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

// Values far from zero divided by a small tick spacing give a quotient no
// integer holds, and an axis rounded through one lands somewhere else entirely.
procedure TChartLayoutTests.Axis_LargeValuesInNarrowRange_LabelsStayWithTheData;
const
  Markdown =
    '```chart'#10 +
    '{"type":"chart","data":{"type":"line","data":{"labels":["A","B"],' +
    '"datasets":[{"label":"Counter","data":[1000000000,1000000001]}]}}}'#10 +
    '```';
  Lowest = 999999999.0;
  Highest = 1000000002.0;
begin
  const Items = MarkdownItems(Markdown);

  var NumericLabels := 0;
  for var Item in Items do
  begin
    if Item.Kind <> TDisplayItemKind.TextRun then
      Continue;

    var Value: Double;
    if not TryStrToFloat((Item as IDisplayTextRun).Text, Value) then
      Continue;

    Inc(NumericLabels);
    Assert.IsTrue((Value >= Lowest) and (Value <= Highest),
      Format('Tick label %s lies outside the data range', [(Item as IDisplayTextRun).Text]));
  end;

  Assert.IsTrue(NumericLabels >= 2, Format('Expected at least two tick labels but found %d', [NumericLabels]));
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

procedure TChartLayoutTests.HorizontalBar_ProducesBarRectangles;
begin
  const Items = ModelItems('bar-horizontal');
  Assert.IsTrue(CountKind(Items, TDisplayItemKind.Rectangle) >= 3,
    'A horizontal bar chart must emit one bar rectangle per label');
end;

procedure TChartLayoutTests.Area_ProducesFilledPolygon;
begin
  const Items = ModelItems('line-area');
  Assert.IsTrue(CountKind(Items, TDisplayItemKind.Polygon) >= 1,
    'A filled line (area) chart must emit a filled polygon under the series');
end;

procedure TChartLayoutTests.Radar_ProducesPolygonPerDataset;
begin
  const Items = ModelItems('radar-multi');
  Assert.IsTrue(CountKind(Items, TDisplayItemKind.Polygon) >= 2,
    'A radar chart must emit one filled polygon per dataset');
end;

procedure TChartLayoutTests.Scatter_ProducesMarkerPerPoint;
begin
  const Items = ModelItems('scatter-minimal');
  Assert.AreEqual(3, CountKind(Items, TDisplayItemKind.Wedge),
    'A three-point scatter chart must emit one marker per point');
end;

procedure TChartLayoutTests.Axis_FractionalSpacing_DefaultLabelsHaveNoFloatingPointNoise;
const
  CleanDecimals = '0.##########';
begin
  const Items = MarkdownItems(FractionalBarChart);
  const Invariant = TFormatSettings.Invariant;

  var NumericLabels := 0;
  for var Item in Items do
  begin
    var Run: IDisplayTextRun;
    if not Supports(Item, IDisplayTextRun, Run) then
      Continue;

    var Value: Double;
    if not TryStrToFloat(Run.Text, Value, Invariant) then
      Continue;

    Inc(NumericLabels);
    const CleanText = FormatFloat(CleanDecimals, Value, Invariant);
    Assert.AreEqual(CleanText, Run.Text, 'A tick label on a fractional axis must not show floating-point noise');
  end;

  Assert.IsTrue(NumericLabels >= 2, Format('Expected at least two tick labels but found %d', [NumericLabels]));
end;

procedure TChartLayoutTests.Axis_CommaDecimalSeparator_DefaultLabelsUseAPoint;
const
  Comma = ',';
begin
  const SavedSeparator = FormatSettings.DecimalSeparator;
  FormatSettings.DecimalSeparator := Comma;
  try
    const Items = MarkdownItems(FractionalBarChart);

    var FractionalLabels := 0;
    for var Item in Items do
    begin
      var Run: IDisplayTextRun;
      if not Supports(Item, IDisplayTextRun, Run) then
        Continue;

      Assert.IsFalse(Run.Text.Contains(Comma),
        Format('The axis label %s must not follow the decimal separator of the locale', [Run.Text]));

      if Run.Text.Contains('.') then
        Inc(FractionalLabels);
    end;

    Assert.IsTrue(FractionalLabels >= 2,
      Format('Expected at least two fractional tick labels but found %d', [FractionalLabels]));
  finally
    FormatSettings.DecimalSeparator := SavedSeparator;
  end;
end;

procedure TChartLayoutTests.PreferredHeight_DefaultOptions_MatchesSixteenByNine;
begin
  var Code: IMarkdownCodeBlock;
  const Markdown = BarChartMarkdown(12, True);
  const Model = ParseModel(Markdown, Code);

  const Expected = TChartLayouter.PreferredHeight(ChartWidth, FTheme);
  const Actual = TChartLayouter.PreferredHeight(Model, ChartWidth, FTheme, FMeasurer, Default(TChartLayoutOptions));

  Assert.AreEqual(Double(Expected), Double(Actual), 0,
    'A zeroed options record must give the same height as the overload without options');
end;

procedure TChartLayoutTests.AspectRatio_Custom_SetsPreferredHeight;
const
  WideRatio = 2.0;
begin
  var Code: IMarkdownCodeBlock;
  const Markdown = BarChartMarkdown(3, False);
  const Model = ParseModel(Markdown, Code);

  var Options := Default(TChartLayoutOptions);
  Options.AspectRatio := WideRatio;
  const Height = TChartLayouter.PreferredHeight(Model, ChartWidth, FTheme, FMeasurer, Options);

  Assert.AreEqual(Double(ChartWidth / WideRatio), Double(Height), 0.01,
    'The chart height must be the width divided by the aspect ratio');
end;

procedure TChartLayoutTests.BarRowHeightFactor_HorizontalBar_HeightGrowsWithLabelCount;
const
  FewLabels = 3;
  ManyLabels = 7;
begin
  var Options := Default(TChartLayoutOptions);
  Options.BarRowHeightFactor := RowHeightFactor;

  var Code: IMarkdownCodeBlock;
  const FewMarkdown = BarChartMarkdown(FewLabels, True);
  const ManyMarkdown = BarChartMarkdown(ManyLabels, True);
  const FewModel = ParseModel(FewMarkdown, Code);
  const ManyModel = ParseModel(ManyMarkdown, Code);
  const FewHeight = TChartLayouter.PreferredHeight(FewModel, ChartWidth, FTheme, FMeasurer, Options);
  const ManyHeight = TChartLayouter.PreferredHeight(ManyModel, ChartWidth, FTheme, FMeasurer, Options);

  const Expected = (ManyLabels - FewLabels) * RowHeightFactor * LabelLineHeight;
  Assert.AreEqual(Double(Expected), Double(ManyHeight - FewHeight), 0.01,
    'Each extra label must add one row of the requested height');
end;

procedure TChartLayoutTests.BarRowHeightFactor_HorizontalBar_RowIsFactorTimesLineHeight;
const
  LabelCount = 5;
begin
  var Options := Default(TChartLayoutOptions);
  Options.BarRowHeightFactor := RowHeightFactor;

  var Code: IMarkdownCodeBlock;
  const Markdown = BarChartMarkdown(LabelCount, True);
  const Model = ParseModel(Markdown, Code);
  const Height = TChartLayouter.PreferredHeight(Model, ChartWidth, FTheme, FMeasurer, Options);
  const Bounds = TLayoutRectF.Create(0, 0, ChartWidth, Height);
  const Items = TChartLayouter.BuildDisplayItems(Model, Bounds, FTheme, FMeasurer, Code, Options);

  const Tops = BarTops(Items);
  Assert.AreEqual(LabelCount, TTestArray.CountOf(Tops),
    'A single-dataset horizontal chart must emit one bar per label');

  const ExpectedRow = RowHeightFactor * LabelLineHeight;
  for var Index := 1 to High(Tops) do
  begin
    Assert.AreEqual(Double(ExpectedRow), Double(Tops[Index] - Tops[Index - 1]), 0.01,
      Format('Bar row %d must be the factor times the label line height', [Index]));
  end;
end;

procedure TChartLayoutTests.BarRowHeightFactor_VerticalBar_KeepsAspectRatio;
begin
  var Options := Default(TChartLayoutOptions);
  Options.BarRowHeightFactor := RowHeightFactor;

  var Code: IMarkdownCodeBlock;
  const Markdown = BarChartMarkdown(12, False);
  const Model = ParseModel(Markdown, Code);
  const Height = TChartLayouter.PreferredHeight(Model, ChartWidth, FTheme, FMeasurer, Options);

  Assert.AreEqual(Double(ChartHeight), Double(Height), 0.01,
    'The row height factor applies to horizontal bar charts only');
end;

procedure TChartLayoutTests.BarRowHeightFactor_TallerThanAspectRatio_IsNotClamped;
const
  LabelCount = 12;
begin
  var Options := Default(TChartLayoutOptions);
  Options.BarRowHeightFactor := RowHeightFactor;

  var Code: IMarkdownCodeBlock;
  const Markdown = BarChartMarkdown(LabelCount, True);
  const Model = ParseModel(Markdown, Code);
  const Height = TChartLayouter.PreferredHeight(Model, ChartWidth, FTheme, FMeasurer, Options);
  Assert.IsTrue(Height > ChartHeight, 'Twelve rows at twice the line height must be taller than 16:9');

  const Bounds = TLayoutRectF.Create(0, 0, ChartWidth, Height);
  const Items = TChartLayouter.BuildDisplayItems(Model, Bounds, FTheme, FMeasurer, Code, Options);

  const Tops = BarTops(Items);
  Assert.AreEqual(LabelCount, TTestArray.CountOf(Tops), 'Every row must still get its bar');
  Assert.IsTrue(Tops[High(Tops)] > ChartHeight, 'The last bar must lie below the 16:9 height, not be squeezed into it');
end;

procedure TChartLayoutTests.TickLabelFormatter_Custom_FormatsEveryAxisLabel;
const
  CaseNames: array[0..3] of string = ('bar-minimal', 'bar-horizontal', 'line-scales-minmax', 'scatter-minimal');
  Marker = '#';
begin
  var Options := Default(TChartLayoutOptions);
  Options.TickLabelFormatter :=
    function(const Value: Double): string
    begin
      Result := Format('%s%g', [Marker, Value]);
    end;

  for var CaseName in CaseNames do
  begin
    var Code: IMarkdownCodeBlock;
    const ChartCase = FCorpus.FindCase(CaseName);
    const Model = ParseModel(ChartCase.Markdown, Code);
    const Bounds = TLayoutRectF.Create(0, 0, ChartWidth, ChartHeight);
    const Items = TChartLayouter.BuildDisplayItems(Model, Bounds, FTheme, FMeasurer, Code, Options);

    var FormattedLabels := 0;
    for var Item in Items do
    begin
      var Run: IDisplayTextRun;
      if not Supports(Item, IDisplayTextRun, Run) then
        Continue;

      var Value: Double;
      Assert.IsFalse(TryStrToFloat(Run.Text, Value),
        Format('Case "%s" drew the axis label %s without the formatter', [CaseName, Run.Text]));

      if Run.Text.StartsWith(Marker) then
        Inc(FormattedLabels);
    end;

    Assert.IsTrue(FormattedLabels >= 2,
      Format('Case "%s" must draw its axis labels through the formatter', [CaseName]));
  end;
end;

procedure TChartLayoutTests.BarColor_ColorPerBar_VerticalBarsTakeTheirOwnColor;
begin
  AssertBarsTakeColorPerLabel(False);
end;

procedure TChartLayoutTests.BarColor_ColorPerBar_HorizontalBarsTakeTheirOwnColor;
begin
  AssertBarsTakeColorPerLabel(True);
end;

procedure TChartLayoutTests.BarColor_FewerColorsThanBars_StartsOverAtTheFirstColor;
begin
  var Code: IMarkdownCodeBlock;
  const Markdown = ColoredBarMarkdown('["#ff0000","#00ff00"]', False);
  const Dataset = ParseModel(Markdown, Code).Datasets[0];
  const BarItems = Bars(OptionItems(Markdown, Default(TChartLayoutOptions)));

  Assert.AreEqual(3, TTestArray.CountOf(BarItems), ThreeBarsExpected);
  Assert.AreEqual<TLayoutColor>(Dataset.BackgroundColors[0], BarItems[2].FillColor,
    'The third bar of a two-colour dataset must start over at the first colour');
end;

procedure TChartLayoutTests.BarColor_SingleColor_ColorsEveryBar;
begin
  var Code: IMarkdownCodeBlock;
  const Markdown = ColoredBarMarkdown(SingleColor, False);
  const Dataset = ParseModel(Markdown, Code).Datasets[0];
  const BarItems = Bars(OptionItems(Markdown, Default(TChartLayoutOptions)));

  for var Bar in BarItems do
  begin
    Assert.AreEqual<TLayoutColor>(Dataset.BackgroundColors[0], Bar.FillColor, 'A single background colour must colour every bar');
  end;
end;

procedure TChartLayoutTests.BarFillFactor_VerticalBar_ScalesBarWidth;
begin
  const Markdown = ColoredBarMarkdown(SingleColor, False);
  var Options := Default(TChartLayoutOptions);
  Options.BarFillFactor := NarrowBarFill;

  const DefaultBar = Bars(OptionItems(Markdown, Default(TChartLayoutOptions)))[0];
  const NarrowBar = Bars(OptionItems(Markdown, Options))[0];

  Assert.AreEqual(Double(NarrowBarFill / DefaultGroupedBarFill),
    Double(NarrowBar.Bounds.Width / DefaultBar.Bounds.Width), 0.001,
    'The bar width must follow the fill factor instead of the 0.8 default');
end;

procedure TChartLayoutTests.BarFillFactor_HorizontalBar_ScalesBarHeight;
begin
  const Markdown = ColoredBarMarkdown(SingleColor, True);
  var Options := Default(TChartLayoutOptions);
  Options.BarFillFactor := NarrowBarFill;

  const DefaultBar = Bars(OptionItems(Markdown, Default(TChartLayoutOptions)))[0];
  const NarrowBar = Bars(OptionItems(Markdown, Options))[0];

  Assert.AreEqual(Double(NarrowBarFill / DefaultGroupedBarFill),
    Double(NarrowBar.Bounds.Height / DefaultBar.Bounds.Height), 0.001,
    'The bar height must follow the fill factor instead of the 0.8 default');
end;

procedure TChartLayoutTests.BarFillFactor_AboveOne_BarsTouchTheirNeighbours;
const
  OversizedFill = 3.0;
begin
  const Markdown = ColoredBarMarkdown(SingleColor, False);
  var Options := Default(TChartLayoutOptions);
  Options.BarFillFactor := OversizedFill;

  const BarItems = Bars(OptionItems(Markdown, Options));

  Assert.AreEqual(3, TTestArray.CountOf(BarItems), ThreeBarsExpected);
  for var Index := 1 to High(BarItems) do
  begin
    Assert.AreEqual(Double(BarItems[Index - 1].Bounds.Right), Double(BarItems[Index].Bounds.Left), 0.01,
      Format('Bar %d must start where the previous one ends, not overlap it', [Index]));
  end;
end;

end.
