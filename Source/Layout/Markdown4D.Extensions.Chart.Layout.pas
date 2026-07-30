unit Markdown4D.Extensions.Chart.Layout;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Theme,
  Markdown4D.Extensions.Chart;

type
  TChartLayouter = class
  public
    const
      AspectRatioWidth = 16.0;
      AspectRatioHeight = 9.0;
    class procedure Draw(const Model: IChartModel; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
      const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
    class function BuildDisplayItems(const Model: IChartModel; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
      const Measurer: ITextMeasurer; const Node: IMarkdownNode): TArray<IDisplayItem>;
    class function PreferredHeight(const AvailableWidth: Single; const Theme: TMarkdownTheme): Single;
    class function PaletteColor(const Theme: TMarkdownTheme; const DatasetIndex: Integer): TLayoutColor;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Defines,
  Markdown4D.Layout.ExtensionCanvas;

type
  TChartValueRange = record
    Minimum: Double;
    Maximum: Double;
  end;

  TChartValueAxis = record
    Minimum: Double;
    Maximum: Double;
    Ticks: TArray<Double>;
  end;

  TChartLayoutBuilder = class
  private
    const
      Padding = 8.0;
      LabelFontSize = 11.0;
      TitleFontSize = 16.0;
      SwatchSize = 10.0;
      SwatchGap = 4.0;
      EntryGap = 12.0;
      AxisGap = 6.0;
      TargetTickCount = 5;
      // A tick count beyond this says the spacing does not fit the range, in
      // which case the axis falls back to its two ends.
      MaxTickCount = 64;
      TickTolerance = 0.001;
      GridStrokeWidth = 1.0;
      LineStrokeWidth = 2.0;
      MinLabelSweepDegrees = 18.0;
      PieRadiusFactor = 0.9;
      DoughnutInnerFactor = 0.55;
      TickLabelFormat = '%g';
      AreaFillAlphaFactor = 0.3;
      RadarRingCount = 4;
      RadarMinAxes = 3;
      MarkerRadius = 3.5;
      FullCircleDegrees = 360.0;
    var
      FModel: IChartModel;
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FCanvas: IExtensionCanvas;
      FLeft: Single;
      FTop: Single;
      FRight: Single;
      FBottom: Single;
    function LabelFont: TMarkdownFontStyle;
    function TitleFont: TMarkdownFontStyle;
    procedure EmitRectangle(const Bounds: TLayoutRectF; const FillColor, StrokeColor: TLayoutColor;
      const StrokeWidth: Single);
    procedure EmitText(const Text: string; const X, Y: Single; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor);
    procedure EmitCenteredText(const Text: string; const CenterX, Y: Single; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor);
    procedure EmitLineSegment(const X1, Y1, X2, Y2: Single; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure EmitWedge(const CenterX, CenterY, OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const Color: TLayoutColor);
    function EntryCount: Integer;
    function EntryColor(const Index: Integer): TLayoutColor;
    function EntryCaption(const Index: Integer): string;
    function DatasetColor(const Index: Integer): TLayoutColor;
    function SliceColor(const Index: Integer): TLayoutColor;
    class function IsColorSet(const Color: TLayoutColor): Boolean; static;
    procedure LayoutTitle;
    procedure LayoutLegend;
    procedure EmitLegendEntry(const Index: Integer; const X, RowY, RowHeight: Single; const Caption: string;
      const Font: TMarkdownFontStyle);
    procedure EmitVerticalLegend(const Font: TMarkdownFontStyle; const RowHeight: Single);
    procedure EmitHorizontalLegend(const Font: TMarkdownFontStyle; const RowHeight: Single);
    procedure LayoutAxes;
    procedure LayoutBars(const PlotLeft, PlotTop, PlotRight, PlotBottom, AxisMin, AxisMax: Single);
    procedure EmitStackedBars(const LabelIndex: Integer; const SlotLeft, SlotWidth, BaseY, AxisSpan, PlotHeight: Single);
    procedure EmitGroupedBars(const LabelIndex: Integer; const SlotLeft, SlotWidth, BaseY, AxisMin, AxisSpan,
      PlotHeight, PlotBottom: Single);
    procedure LayoutLine(const PlotLeft, PlotTop, PlotRight, PlotBottom, AxisMin, AxisMax: Single);
    procedure LayoutPie;
    procedure LayoutHorizontalAxes;
    procedure LayoutHorizontalBars(const PlotLeft, PlotTop, PlotRight, PlotBottom, AxisMin, AxisMax: Single);
    procedure EmitHorizontalStackedBars(const LabelIndex: Integer; const SlotTop, SlotHeight, BaseX, AxisSpan,
      PlotWidth: Single);
    procedure EmitHorizontalGroupedBars(const LabelIndex: Integer; const SlotTop, SlotHeight, BaseX, AxisMin, AxisSpan,
      PlotWidth, PlotLeft: Single);
    procedure LayoutRadar;
    procedure LayoutScatter;
    procedure EmitFilledPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
    class function Translucent(const Color: TLayoutColor; const Factor: Single): TLayoutColor; static;
    function NiceNum(const Value: Double; const RoundResult: Boolean): Double;
    // Rounding a value down or up to a whole number of steps stays in floating
    // point: Floor and Ceil return an integer, and a large value over a small
    // spacing is a quotient no integer holds, which would silently wrap and put
    // the axis somewhere else entirely.
    class function FloorToStep(const Value, Step: Double): Double; static;
    class function CeilToStep(const Value, Step: Double): Double; static;
    function BuildValueAxis(const Range: TChartValueRange): TChartValueAxis;
    function CollectValueRange: TChartValueRange;
    function CollectStackedRange(var HasValue: Boolean): TChartValueRange;
    function CollectUnstackedRange(var HasValue: Boolean): TChartValueRange;

  public
    constructor Create(const Model: IChartModel; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
      const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
    procedure Build;
  end;

class function TChartLayouter.PreferredHeight(const AvailableWidth: Single; const Theme: TMarkdownTheme): Single;
begin
  Result := AvailableWidth * AspectRatioHeight / AspectRatioWidth;
end;

class function TChartLayouter.PaletteColor(const Theme: TMarkdownTheme; const DatasetIndex: Integer): TLayoutColor;
begin
  const Palette = Theme.ChartPalette;
  const Count = Length(Palette);
  if Count = 0 then
    Exit(Theme.ChartTextColor);

  Result := Palette[DatasetIndex mod Count];
end;

class function TChartLayouter.BuildDisplayItems(const Model: IChartModel; const Bounds: TLayoutRectF;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Node: IMarkdownNode): TArray<IDisplayItem>;
begin
  const Items = TList<IDisplayItem>.Create;
  try
    var Canvas: IExtensionCanvas := TDisplayListExtensionCanvas.Create(Measurer, Items, Node);
    Draw(Model, Bounds, Theme, Measurer, Canvas);

    Result := Items.ToArray;
  finally
    Items.Free;
  end;
end;

class procedure TChartLayouter.Draw(const Model: IChartModel; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
  const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
begin
  const Builder = TChartLayoutBuilder.Create(Model, Bounds, Theme, Measurer, Canvas);
  try
    Builder.Build;
  finally
    Builder.Free;
  end;
end;

constructor TChartLayoutBuilder.Create(const Model: IChartModel; const Bounds: TLayoutRectF;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
begin
  inherited Create;

  FModel := Model;
  FTheme := Theme;
  FMeasurer := Measurer;
  FCanvas := Canvas;

  const ClampedHeight = Min(Bounds.Height, TChartLayouter.PreferredHeight(Bounds.Width, Theme));

  FLeft := Bounds.Left + Padding;
  FTop := Bounds.Top + Padding;
  FRight := Bounds.Left + Bounds.Width - Padding;
  FBottom := Bounds.Top + ClampedHeight - Padding;
end;

procedure TChartLayoutBuilder.Build;
begin
  LayoutTitle;
  LayoutLegend;

  const HasPlotArea = (FRight > FLeft) and (FBottom > FTop);
  if not HasPlotArea then
    Exit;

  case FModel.ChartKind of
    TChartKind.Bar:
      if FModel.Horizontal then
        LayoutHorizontalAxes
      else
        LayoutAxes;
    TChartKind.Line:
      LayoutAxes;
    TChartKind.Pie, TChartKind.Doughnut:
      LayoutPie;
    TChartKind.Radar:
      LayoutRadar;
    TChartKind.Scatter:
      LayoutScatter;
  else
    raise EMarkdownError.CreateFmt('Unhandled chart kind: %d', [Ord(FModel.ChartKind)]);
  end;
end;

function TChartLayoutBuilder.LabelFont: TMarkdownFontStyle;
begin
  Result := TMarkdownFontStyle.Create(FTheme.BaseFont.FamilyName, LabelFontSize);
end;

function TChartLayoutBuilder.TitleFont: TMarkdownFontStyle;
begin
  Result := TMarkdownFontStyle.Create(FTheme.BaseFont.FamilyName, TitleFontSize, True);
end;

procedure TChartLayoutBuilder.EmitRectangle(const Bounds: TLayoutRectF; const FillColor, StrokeColor: TLayoutColor;
  const StrokeWidth: Single);
begin
  FCanvas.FillAndStrokeRectangle(Bounds, FillColor, StrokeColor, StrokeWidth);
end;

procedure TChartLayoutBuilder.EmitText(const Text: string; const X, Y: Single; const Font: TMarkdownFontStyle;
  const Color: TLayoutColor);
begin
  if Text = '' then
    Exit;

  FCanvas.DrawText(TLayoutPointF.Create(X, Y), Text, Font, Color);
end;

procedure TChartLayoutBuilder.EmitCenteredText(const Text: string; const CenterX, Y: Single;
  const Font: TMarkdownFontStyle; const Color: TLayoutColor);
begin
  if Text = '' then
    Exit;

  const Size = FMeasurer.MeasureText(Text, Font);
  EmitText(Text, CenterX - Size.Width / 2, Y, Font, Color);
end;

procedure TChartLayoutBuilder.EmitLineSegment(const X1, Y1, X2, Y2: Single; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  FCanvas.DrawLine(TLayoutPointF.Create(X1, Y1), TLayoutPointF.Create(X2, Y2), Color, StrokeWidth);
end;

procedure TChartLayoutBuilder.EmitWedge(const CenterX, CenterY, OuterRadius, InnerRadius, StartAngle,
  SweepAngle: Single; const Color: TLayoutColor);
begin
  FCanvas.FillWedge(TLayoutPointF.Create(CenterX, CenterY), OuterRadius, InnerRadius, StartAngle, SweepAngle, Color);
end;

function TChartLayoutBuilder.EntryCount: Integer;
begin
  case FModel.ChartKind of
    TChartKind.Pie, TChartKind.Doughnut:
      Result := FModel.LabelCount;
  else
    Result := FModel.DatasetCount;
  end;
end;

function TChartLayoutBuilder.EntryColor(const Index: Integer): TLayoutColor;
begin
  case FModel.ChartKind of
    TChartKind.Pie, TChartKind.Doughnut:
      Result := SliceColor(Index);
  else
    Result := DatasetColor(Index);
  end;
end;

function TChartLayoutBuilder.EntryCaption(const Index: Integer): string;
begin
  case FModel.ChartKind of
    TChartKind.Pie, TChartKind.Doughnut:
      Result := FModel.Labels[Index];
  else
    Result := FModel.Datasets[Index].Caption;
  end;
end;

function TChartLayoutBuilder.DatasetColor(const Index: Integer): TLayoutColor;
begin
  const Dataset = FModel.Datasets[Index];

  if (Dataset.BackgroundColorCount > 0) and IsColorSet(Dataset.BackgroundColors[0]) then
    Exit(Dataset.BackgroundColors[0]);

  if (Dataset.BorderColorCount > 0) and IsColorSet(Dataset.BorderColors[0]) then
    Exit(Dataset.BorderColors[0]);

  Result := TChartLayouter.PaletteColor(FTheme, Index);
end;

function TChartLayoutBuilder.SliceColor(const Index: Integer): TLayoutColor;
begin
  if FModel.DatasetCount > 0 then
  begin
    const Dataset = FModel.Datasets[0];
    if (Dataset.BackgroundColorCount > Index) and IsColorSet(Dataset.BackgroundColors[Index]) then
      Exit(Dataset.BackgroundColors[Index]);
  end;

  Result := TChartLayouter.PaletteColor(FTheme, Index);
end;

class function TChartLayoutBuilder.IsColorSet(const Color: TLayoutColor): Boolean;
begin
  Result := (Color shr 24) <> 0;
end;

procedure TChartLayoutBuilder.LayoutTitle;
begin
  if not FModel.TitleVisible or (FModel.Title = '') then
    Exit;

  const Font = TitleFont;
  const Height = FMeasurer.LineHeight(Font);
  EmitCenteredText(FModel.Title, (FLeft + FRight) / 2, FTop, Font, FTheme.ChartTextColor);
  FTop := FTop + Height + Padding;
end;

procedure TChartLayoutBuilder.LayoutLegend;
begin
  if not FModel.LegendVisible or (EntryCount = 0) then
    Exit;

  const Font = LabelFont;
  const RowHeight = Max(FMeasurer.LineHeight(Font), SwatchSize);

  const IsVertical = (FModel.LegendPosition = TChartLegendPosition.Left) or
    (FModel.LegendPosition = TChartLegendPosition.Right);

  if IsVertical then
    EmitVerticalLegend(Font, RowHeight)
  else
    EmitHorizontalLegend(Font, RowHeight);
end;

procedure TChartLayoutBuilder.EmitLegendEntry(const Index: Integer; const X, RowY, RowHeight: Single;
  const Caption: string; const Font: TMarkdownFontStyle);
begin
  const SwatchTop = RowY + (RowHeight - SwatchSize) / 2;
  EmitRectangle(TLayoutRectF.Create(X, SwatchTop, X + SwatchSize, SwatchTop + SwatchSize),
    EntryColor(Index), 0, 0);
  EmitText(Caption, X + SwatchSize + SwatchGap, RowY, Font, FTheme.ChartTextColor);
end;

procedure TChartLayoutBuilder.EmitVerticalLegend(const Font: TMarkdownFontStyle; const RowHeight: Single);
begin
  var ColumnWidth := 0.0;
  for var Index := 0 to EntryCount - 1 do
  begin
    const Width = SwatchSize + SwatchGap + FMeasurer.MeasureText(EntryCaption(Index), Font).Width;
    ColumnWidth := Max(ColumnWidth, Width);
  end;

  var ColumnX := FLeft;
  if FModel.LegendPosition = TChartLegendPosition.Right then
    ColumnX := FRight - ColumnWidth;

  var RowY := FTop;
  for var Index := 0 to EntryCount - 1 do
  begin
    EmitLegendEntry(Index, ColumnX, RowY, RowHeight, EntryCaption(Index), Font);
    RowY := RowY + RowHeight;
  end;

  if FModel.LegendPosition = TChartLegendPosition.Right then
    FRight := FRight - ColumnWidth - Padding
  else
    FLeft := FLeft + ColumnWidth + Padding;
end;

procedure TChartLayoutBuilder.EmitHorizontalLegend(const Font: TMarkdownFontStyle; const RowHeight: Single);
begin
  var RowY := FTop;
  if FModel.LegendPosition = TChartLegendPosition.Bottom then
    RowY := FBottom - RowHeight;

  var EntryX := FLeft;
  for var Index := 0 to EntryCount - 1 do
  begin
    const Caption = EntryCaption(Index);
    const CaptionWidth = FMeasurer.MeasureText(Caption, Font).Width;
    EmitLegendEntry(Index, EntryX, RowY, RowHeight, Caption, Font);
    EntryX := EntryX + SwatchSize + SwatchGap + CaptionWidth + EntryGap;
  end;

  if FModel.LegendPosition = TChartLegendPosition.Bottom then
    FBottom := FBottom - RowHeight - Padding
  else
    FTop := FTop + RowHeight + Padding;
end;

function TChartLayoutBuilder.CollectValueRange: TChartValueRange;
begin
  var HasValue := False;

  if FModel.Stacked then
    Result := CollectStackedRange(HasValue)
  else
    Result := CollectUnstackedRange(HasValue);

  if not HasValue then
    Result.Maximum := 1;

  if FModel.ChartKind = TChartKind.Bar then
    Result.Minimum := Min(Result.Minimum, 0);
end;

function TChartLayoutBuilder.CollectStackedRange(var HasValue: Boolean): TChartValueRange;
begin
  Result.Minimum := 0;
  Result.Maximum := 0;

  for var LabelIndex := 0 to FModel.LabelCount - 1 do
  begin
    var PositiveSum := 0.0;
    var NegativeSum := 0.0;
    for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
    begin
      const Dataset = FModel.Datasets[DatasetIndex];
      if LabelIndex >= Dataset.ValueCount then
        Continue;
      const Value = Dataset.Values[LabelIndex];
      if Value >= 0 then
        PositiveSum := PositiveSum + Value
      else
        NegativeSum := NegativeSum + Value;
      HasValue := True;
    end;
    Result.Maximum := Max(Result.Maximum, PositiveSum);
    Result.Minimum := Min(Result.Minimum, NegativeSum);
  end;
end;

function TChartLayoutBuilder.CollectUnstackedRange(var HasValue: Boolean): TChartValueRange;
begin
  Result.Minimum := 0;
  Result.Maximum := 0;

  for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
  begin
    const Dataset = FModel.Datasets[DatasetIndex];
    for var ValueIndex := 0 to Dataset.ValueCount - 1 do
    begin
      const Value = Dataset.Values[ValueIndex];
      if not HasValue then
      begin
        Result.Minimum := Value;
        Result.Maximum := Value;
        HasValue := True;
      end
      else
      begin
        Result.Minimum := Min(Result.Minimum, Value);
        Result.Maximum := Max(Result.Maximum, Value);
      end;
    end;
  end;
end;

function TChartLayoutBuilder.NiceNum(const Value: Double; const RoundResult: Boolean): Double;
begin
  if Value <= 0 then
    Exit(1);

  const Exponent = Floor(Log10(Value));
  const PowerOfTen = Power(10, Exponent);
  const Fraction = Value / PowerOfTen;
  var NiceFraction: Double;

  if RoundResult then
  begin
    if Fraction < 1.5 then
      NiceFraction := 1
    else if Fraction < 3 then
      NiceFraction := 2
    else if Fraction < 7 then
      NiceFraction := 5
    else
      NiceFraction := 10;
  end
  else
  begin
    if Fraction <= 1 then
      NiceFraction := 1
    else if Fraction <= 2 then
      NiceFraction := 2
    else if Fraction <= 5 then
      NiceFraction := 5
    else
      NiceFraction := 10;
  end;

  Result := NiceFraction * PowerOfTen;
end;

class function TChartLayoutBuilder.FloorToStep(const Value, Step: Double): Double;
begin
  var Steps := Int(Value / Step);
  if Steps * Step > Value then
    Steps := Steps - 1;

  Result := Steps * Step;
end;

class function TChartLayoutBuilder.CeilToStep(const Value, Step: Double): Double;
begin
  var Steps := Int(Value / Step);
  if Steps * Step < Value then
    Steps := Steps + 1;

  Result := Steps * Step;
end;

function TChartLayoutBuilder.BuildValueAxis(const Range: TChartValueRange): TChartValueAxis;
begin
  var Low := Range.Minimum;
  var High := Range.Maximum;

  if FModel.HasScaleMin then
    Low := FModel.ScaleMin;
  if FModel.HasScaleMax then
    High := FModel.ScaleMax;

  if High <= Low then
    High := Low + 1;

  const Span = NiceNum(High - Low, False);
  const Spacing = NiceNum(Span / (TargetTickCount - 1), True);

  if FModel.HasScaleMin then
    Result.Minimum := FModel.ScaleMin
  else
    Result.Minimum := FloorToStep(Low, Spacing);

  if FModel.HasScaleMax then
    Result.Maximum := FModel.ScaleMax
  else
    Result.Maximum := CeilToStep(High, Spacing);

  const Collected = TList<Double>.Create;
  try
    // Each tick is computed from its index rather than added to the previous
    // one, so a long axis cannot drift away from its spacing.
    const FirstTick = CeilToStep(Result.Minimum, Spacing);
    const RawStepCount = (Result.Maximum - FirstTick) / Spacing + TickTolerance;
    const Fits = (RawStepCount >= 0) and (RawStepCount <= MaxTickCount);

    if Fits then
    begin
      for var Index := 0 to Trunc(RawStepCount) do
      begin
        Collected.Add(FirstTick + Index * Spacing);
      end;
    end;

    if Collected.Count = 0 then
    begin
      Collected.Add(Result.Minimum);
      Collected.Add(Result.Maximum);
    end;

    Result.Ticks := Collected.ToArray;
  finally
    Collected.Free;
  end;
end;

procedure TChartLayoutBuilder.LayoutAxes;
begin
  const Range = CollectValueRange;
  const Axis = BuildValueAxis(Range);

  const Font = LabelFont;

  var GutterWidth := 0.0;
  for var Tick in Axis.Ticks do
  begin
    const Text = Format(TickLabelFormat, [Tick]);
    GutterWidth := Max(GutterWidth, FMeasurer.MeasureText(Text, Font).Width);
  end;
  GutterWidth := GutterWidth + AxisGap;

  const BottomGutter = FMeasurer.LineHeight(Font) + AxisGap;

  const PlotLeft = FLeft + GutterWidth;
  const PlotTop = FTop;
  const PlotRight = FRight;
  const PlotBottom = FBottom - BottomGutter;

  if (PlotRight <= PlotLeft) or (PlotBottom <= PlotTop) then
    Exit;

  const AxisSpan = Axis.Maximum - Axis.Minimum;
  for var Tick in Axis.Ticks do
  begin
    const Ratio = (Tick - Axis.Minimum) / AxisSpan;
    const Y = PlotBottom - Ratio * (PlotBottom - PlotTop);
    EmitLineSegment(PlotLeft, Y, PlotRight, Y, FTheme.ChartGridLineColor, GridStrokeWidth);

    const Text = Format(TickLabelFormat, [Tick]);
    const Size = FMeasurer.MeasureText(Text, Font);
    EmitText(Text, PlotLeft - AxisGap - Size.Width, Y - Size.Height / 2, Font, FTheme.ChartTextColor);
  end;

  const SlotWidth = (PlotRight - PlotLeft) / Max(1, FModel.LabelCount);
  for var LabelIndex := 0 to FModel.LabelCount - 1 do
  begin
    const CenterX = PlotLeft + SlotWidth * (LabelIndex + 0.5);
    EmitCenteredText(FModel.Labels[LabelIndex], CenterX, PlotBottom + AxisGap, Font, FTheme.ChartTextColor);
  end;

  if FModel.ChartKind = TChartKind.Bar then
    LayoutBars(PlotLeft, PlotTop, PlotRight, PlotBottom, Axis.Minimum, Axis.Maximum)
  else
    LayoutLine(PlotLeft, PlotTop, PlotRight, PlotBottom, Axis.Minimum, Axis.Maximum);
end;

procedure TChartLayoutBuilder.LayoutBars(const PlotLeft, PlotTop, PlotRight, PlotBottom, AxisMin, AxisMax: Single);
begin
  const AxisSpan = AxisMax - AxisMin;
  if AxisSpan <= 0 then
    Exit;

  const PlotHeight = PlotBottom - PlotTop;
  const SlotWidth = (PlotRight - PlotLeft) / Max(1, FModel.LabelCount);
  const BaseValue = Min(Max(0, AxisMin), AxisMax);
  const BaseY = PlotBottom - (BaseValue - AxisMin) / AxisSpan * PlotHeight;

  for var LabelIndex := 0 to FModel.LabelCount - 1 do
  begin
    const SlotLeft = PlotLeft + SlotWidth * LabelIndex;

    if FModel.Stacked then
      EmitStackedBars(LabelIndex, SlotLeft, SlotWidth, BaseY, AxisSpan, PlotHeight)
    else
      EmitGroupedBars(LabelIndex, SlotLeft, SlotWidth, BaseY, AxisMin, AxisSpan, PlotHeight, PlotBottom);
  end;
end;

procedure TChartLayoutBuilder.EmitStackedBars(const LabelIndex: Integer; const SlotLeft, SlotWidth, BaseY,
  AxisSpan, PlotHeight: Single);
begin
  const BarWidth = SlotWidth * 0.6;
  const BarLeft = SlotLeft + (SlotWidth - BarWidth) / 2;
  var StackTopY := BaseY;
  var StackBottomY := BaseY;

  for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
  begin
    const Dataset = FModel.Datasets[DatasetIndex];
    if LabelIndex >= Dataset.ValueCount then
      Continue;

    const Value = Dataset.Values[LabelIndex];
    const SegmentHeight = Value / AxisSpan * PlotHeight;

    var SegmentTop: Single;
    var SegmentBottom: Single;
    if Value >= 0 then
    begin
      SegmentTop := StackTopY - SegmentHeight;
      SegmentBottom := StackTopY;
      StackTopY := SegmentTop;
    end
    else
    begin
      SegmentTop := StackBottomY;
      SegmentBottom := StackBottomY - SegmentHeight;
      StackBottomY := SegmentBottom;
    end;

    EmitRectangle(TLayoutRectF.Create(BarLeft, Min(SegmentTop, SegmentBottom), BarLeft + BarWidth,
      Max(SegmentTop, SegmentBottom)), DatasetColor(DatasetIndex), 0, 0);
  end;
end;

procedure TChartLayoutBuilder.EmitGroupedBars(const LabelIndex: Integer; const SlotLeft, SlotWidth, BaseY,
  AxisMin, AxisSpan, PlotHeight, PlotBottom: Single);
begin
  const GroupWidth = SlotWidth * 0.8;
  const BarWidth = GroupWidth / Max(1, FModel.DatasetCount);
  const GroupLeft = SlotLeft + (SlotWidth - GroupWidth) / 2;

  for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
  begin
    const Dataset = FModel.Datasets[DatasetIndex];
    if LabelIndex >= Dataset.ValueCount then
      Continue;

    const Value = Dataset.Values[LabelIndex];
    const ValueY = PlotBottom - (Value - AxisMin) / AxisSpan * PlotHeight;
    const BarLeft = GroupLeft + BarWidth * DatasetIndex;

    EmitRectangle(TLayoutRectF.Create(BarLeft, Min(BaseY, ValueY), BarLeft + BarWidth, Max(BaseY, ValueY)),
      DatasetColor(DatasetIndex), 0, 0);
  end;
end;

procedure TChartLayoutBuilder.LayoutLine(const PlotLeft, PlotTop, PlotRight, PlotBottom, AxisMin, AxisMax: Single);
begin
  const AxisSpan = AxisMax - AxisMin;
  if AxisSpan <= 0 then
    Exit;

  const PlotHeight = PlotBottom - PlotTop;
  const SlotWidth = (PlotRight - PlotLeft) / Max(1, FModel.LabelCount);
  const BaseValue = Min(Max(0, AxisMin), AxisMax);
  const BaseY = PlotBottom - (BaseValue - AxisMin) / AxisSpan * PlotHeight;

  for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
  begin
    const Dataset = FModel.Datasets[DatasetIndex];
    const Color = DatasetColor(DatasetIndex);
    const Count = Dataset.ValueCount;
    if Count = 0 then
      Continue;

    var Xs: TArray<Single>;
    var Ys: TArray<Single>;
    SetLength(Xs, Count);
    SetLength(Ys, Count);

    for var ValueIndex := 0 to Count - 1 do
    begin
      Xs[ValueIndex] := PlotLeft + SlotWidth * (ValueIndex + 0.5);
      Ys[ValueIndex] := PlotBottom - (Dataset.Values[ValueIndex] - AxisMin) / AxisSpan * PlotHeight;
    end;

    if Dataset.Fill then
    begin
      var Polygon: TArray<TLayoutPointF>;
      SetLength(Polygon, Count + 2);
      for var Index := 0 to Count - 1 do
        Polygon[Index] := TLayoutPointF.Create(Xs[Index], Ys[Index]);
      Polygon[Count] := TLayoutPointF.Create(Xs[Count - 1], BaseY);
      Polygon[Count + 1] := TLayoutPointF.Create(Xs[0], BaseY);
      EmitFilledPolygon(Polygon, Translucent(Color, AreaFillAlphaFactor));
    end;

    for var Index := 1 to Count - 1 do
      EmitLineSegment(Xs[Index - 1], Ys[Index - 1], Xs[Index], Ys[Index], Color, LineStrokeWidth);
  end;
end;

procedure TChartLayoutBuilder.LayoutPie;
begin
  if FModel.DatasetCount = 0 then
    Exit;

  const Dataset = FModel.Datasets[0];
  const SliceCount = Min(Dataset.ValueCount, FModel.LabelCount);
  if SliceCount = 0 then
    Exit;

  var Total := 0.0;
  for var Index := 0 to SliceCount - 1 do
  begin
    Total := Total + Max(0, Dataset.Values[Index]);
  end;

  if Total <= 0 then
    Exit;

  const PlotWidth = FRight - FLeft;
  const PlotHeight = FBottom - FTop;
  const CenterX = (FLeft + FRight) / 2;
  const CenterY = (FTop + FBottom) / 2;
  const OuterRadius = Min(PlotWidth, PlotHeight) / 2 * PieRadiusFactor;
  if OuterRadius <= 0 then
    Exit;

  var InnerRadius := 0.0;
  if FModel.ChartKind = TChartKind.Doughnut then
    InnerRadius := OuterRadius * DoughnutInnerFactor;

  const Font = LabelFont;
  const LabelRadius = (OuterRadius + InnerRadius) / 2;

  var StartAngle := 0.0;
  for var Index := 0 to SliceCount - 1 do
  begin
    const Value = Max(0, Dataset.Values[Index]);
    const Sweep = Value / Total * 360;
    EmitWedge(CenterX, CenterY, OuterRadius, InnerRadius, StartAngle, Sweep, SliceColor(Index));

    if Sweep >= MinLabelSweepDegrees then
    begin
      // Place the label with the same polar convention the wedge uses (0deg at
      // 3 o'clock, sweeping clockwise) so each percentage sits on its own slice.
      const MidAngle = (StartAngle + Sweep / 2) * Pi / 180;
      const LabelX = CenterX + LabelRadius * Cos(MidAngle);
      const LabelY = CenterY + LabelRadius * Sin(MidAngle);
      const Percent = Format('%.0f%%', [Value / Total * 100]);
      EmitCenteredText(Percent, LabelX, LabelY - FMeasurer.LineHeight(Font) / 2, Font, FTheme.ChartTextColor);
    end;

    StartAngle := StartAngle + Sweep;
  end;
end;

procedure TChartLayoutBuilder.LayoutHorizontalAxes;
begin
  const Range = CollectValueRange;
  const Axis = BuildValueAxis(Range);
  const Font = LabelFont;

  var GutterWidth := 0.0;
  for var LabelIndex := 0 to FModel.LabelCount - 1 do
    GutterWidth := Max(GutterWidth, FMeasurer.MeasureText(FModel.Labels[LabelIndex], Font).Width);
  GutterWidth := GutterWidth + AxisGap;

  const BottomGutter = FMeasurer.LineHeight(Font) + AxisGap;

  const PlotLeft = FLeft + GutterWidth;
  const PlotTop = FTop;
  const PlotRight = FRight;
  const PlotBottom = FBottom - BottomGutter;

  if (PlotRight <= PlotLeft) or (PlotBottom <= PlotTop) then
    Exit;

  const AxisSpan = Axis.Maximum - Axis.Minimum;
  for var Tick in Axis.Ticks do
  begin
    const Ratio = (Tick - Axis.Minimum) / AxisSpan;
    const X = PlotLeft + Ratio * (PlotRight - PlotLeft);
    EmitLineSegment(X, PlotTop, X, PlotBottom, FTheme.ChartGridLineColor, GridStrokeWidth);
    EmitCenteredText(Format(TickLabelFormat, [Tick]), X, PlotBottom + AxisGap, Font, FTheme.ChartTextColor);
  end;

  const SlotHeight = (PlotBottom - PlotTop) / Max(1, FModel.LabelCount);
  for var LabelIndex := 0 to FModel.LabelCount - 1 do
  begin
    const CenterY = PlotTop + SlotHeight * (LabelIndex + 0.5);
    const Size = FMeasurer.MeasureText(FModel.Labels[LabelIndex], Font);
    EmitText(FModel.Labels[LabelIndex], PlotLeft - AxisGap - Size.Width, CenterY - Size.Height / 2, Font,
      FTheme.ChartTextColor);
  end;

  LayoutHorizontalBars(PlotLeft, PlotTop, PlotRight, PlotBottom, Axis.Minimum, Axis.Maximum);
end;

procedure TChartLayoutBuilder.LayoutHorizontalBars(const PlotLeft, PlotTop, PlotRight, PlotBottom, AxisMin,
  AxisMax: Single);
begin
  const AxisSpan = AxisMax - AxisMin;
  if AxisSpan <= 0 then
    Exit;

  const PlotWidth = PlotRight - PlotLeft;
  const SlotHeight = (PlotBottom - PlotTop) / Max(1, FModel.LabelCount);
  const BaseValue = Min(Max(0, AxisMin), AxisMax);
  const BaseX = PlotLeft + (BaseValue - AxisMin) / AxisSpan * PlotWidth;

  for var LabelIndex := 0 to FModel.LabelCount - 1 do
  begin
    const SlotTop = PlotTop + SlotHeight * LabelIndex;

    if FModel.Stacked then
      EmitHorizontalStackedBars(LabelIndex, SlotTop, SlotHeight, BaseX, AxisSpan, PlotWidth)
    else
      EmitHorizontalGroupedBars(LabelIndex, SlotTop, SlotHeight, BaseX, AxisMin, AxisSpan, PlotWidth, PlotLeft);
  end;
end;

procedure TChartLayoutBuilder.EmitHorizontalStackedBars(const LabelIndex: Integer; const SlotTop, SlotHeight, BaseX,
  AxisSpan, PlotWidth: Single);
begin
  const BarHeight = SlotHeight * 0.6;
  const BarTop = SlotTop + (SlotHeight - BarHeight) / 2;
  var StackRightX := BaseX;
  var StackLeftX := BaseX;

  for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
  begin
    const Dataset = FModel.Datasets[DatasetIndex];
    if LabelIndex >= Dataset.ValueCount then
      Continue;

    const Value = Dataset.Values[LabelIndex];
    const SegmentWidth = Value / AxisSpan * PlotWidth;

    var SegmentLeft: Single;
    var SegmentRight: Single;
    if Value >= 0 then
    begin
      SegmentLeft := StackRightX;
      SegmentRight := StackRightX + SegmentWidth;
      StackRightX := SegmentRight;
    end
    else
    begin
      SegmentRight := StackLeftX;
      SegmentLeft := StackLeftX + SegmentWidth;
      StackLeftX := SegmentLeft;
    end;

    EmitRectangle(TLayoutRectF.Create(Min(SegmentLeft, SegmentRight), BarTop, Max(SegmentLeft, SegmentRight),
      BarTop + BarHeight), DatasetColor(DatasetIndex), 0, 0);
  end;
end;

procedure TChartLayoutBuilder.EmitHorizontalGroupedBars(const LabelIndex: Integer; const SlotTop, SlotHeight, BaseX,
  AxisMin, AxisSpan, PlotWidth, PlotLeft: Single);
begin
  const GroupHeight = SlotHeight * 0.8;
  const BarHeight = GroupHeight / Max(1, FModel.DatasetCount);
  const GroupTop = SlotTop + (SlotHeight - GroupHeight) / 2;

  for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
  begin
    const Dataset = FModel.Datasets[DatasetIndex];
    if LabelIndex >= Dataset.ValueCount then
      Continue;

    const Value = Dataset.Values[LabelIndex];
    const ValueX = PlotLeft + (Value - AxisMin) / AxisSpan * PlotWidth;
    const BarTop = GroupTop + BarHeight * DatasetIndex;

    EmitRectangle(TLayoutRectF.Create(Min(BaseX, ValueX), BarTop, Max(BaseX, ValueX), BarTop + BarHeight),
      DatasetColor(DatasetIndex), 0, 0);
  end;
end;

procedure TChartLayoutBuilder.LayoutRadar;
begin
  const AxisCount = FModel.LabelCount;
  if AxisCount < RadarMinAxes then
    Exit;

  var MaxValue := 0.0;
  for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
  begin
    const Dataset = FModel.Datasets[DatasetIndex];
    for var ValueIndex := 0 to Dataset.ValueCount - 1 do
      MaxValue := Max(MaxValue, Dataset.Values[ValueIndex]);
  end;

  if FModel.HasScaleMax then
    MaxValue := FModel.ScaleMax;
  if MaxValue <= 0 then
    MaxValue := 1;

  const CenterX = (FLeft + FRight) / 2;
  const CenterY = (FTop + FBottom) / 2;
  const Radius = Min(FRight - FLeft, FBottom - FTop) / 2 * PieRadiusFactor;
  if Radius <= 0 then
    Exit;

  const Font = LabelFont;
  const LineHeight = FMeasurer.LineHeight(Font);

  var Angles: TArray<Single>;
  SetLength(Angles, AxisCount);
  for var Index := 0 to AxisCount - 1 do
    Angles[Index] := -Pi / 2 + 2 * Pi * Index / AxisCount;

  for var Ring := 1 to RadarRingCount do
  begin
    const RingRadius = Radius * Ring / RadarRingCount;
    for var Index := 0 to AxisCount - 1 do
    begin
      const NextIndex = (Index + 1) mod AxisCount;
      EmitLineSegment(CenterX + RingRadius * Cos(Angles[Index]), CenterY + RingRadius * Sin(Angles[Index]),
        CenterX + RingRadius * Cos(Angles[NextIndex]), CenterY + RingRadius * Sin(Angles[NextIndex]),
        FTheme.ChartGridLineColor, GridStrokeWidth);
    end;
  end;

  for var Index := 0 to AxisCount - 1 do
  begin
    const EdgeX = CenterX + Radius * Cos(Angles[Index]);
    const EdgeY = CenterY + Radius * Sin(Angles[Index]);
    EmitLineSegment(CenterX, CenterY, EdgeX, EdgeY, FTheme.ChartGridLineColor, GridStrokeWidth);
    EmitCenteredText(FModel.Labels[Index], CenterX + (Radius + AxisGap) * Cos(Angles[Index]),
      CenterY + (Radius + AxisGap) * Sin(Angles[Index]) - LineHeight / 2, Font, FTheme.ChartTextColor);
  end;

  for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
  begin
    const Dataset = FModel.Datasets[DatasetIndex];
    const Color = DatasetColor(DatasetIndex);
    const PointCount = Min(Dataset.ValueCount, AxisCount);
    if PointCount < RadarMinAxes then
      Continue;

    var Polygon: TArray<TLayoutPointF>;
    SetLength(Polygon, PointCount);
    for var Index := 0 to PointCount - 1 do
    begin
      const Ratio = Max(0, Dataset.Values[Index]) / MaxValue;
      Polygon[Index] := TLayoutPointF.Create(CenterX + Radius * Ratio * Cos(Angles[Index]),
        CenterY + Radius * Ratio * Sin(Angles[Index]));
    end;

    EmitFilledPolygon(Polygon, Translucent(Color, AreaFillAlphaFactor));

    for var Index := 0 to PointCount - 1 do
    begin
      const NextIndex = (Index + 1) mod PointCount;
      EmitLineSegment(Polygon[Index].X, Polygon[Index].Y, Polygon[NextIndex].X, Polygon[NextIndex].Y, Color,
        LineStrokeWidth);
    end;
  end;
end;

procedure TChartLayoutBuilder.LayoutScatter;
begin
  var MinX := 0.0;
  var MaxX := 0.0;
  var MinY := 0.0;
  var MaxY := 0.0;
  var HasPoint := False;

  for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
  begin
    const Dataset = FModel.Datasets[DatasetIndex];
    for var PointIndex := 0 to Dataset.PointCount - 1 do
    begin
      const X = Dataset.PointsX[PointIndex];
      const Y = Dataset.PointsY[PointIndex];
      if not HasPoint then
      begin
        MinX := X;
        MaxX := X;
        MinY := Y;
        MaxY := Y;
        HasPoint := True;
      end
      else
      begin
        MinX := Min(MinX, X);
        MaxX := Max(MaxX, X);
        MinY := Min(MinY, Y);
        MaxY := Max(MaxY, Y);
      end;
    end;
  end;

  if not HasPoint then
    Exit;

  if MaxX <= MinX then
    MaxX := MinX + 1;
  if MaxY <= MinY then
    MaxY := MinY + 1;

  const Font = LabelFont;
  const BottomGutter = FMeasurer.LineHeight(Font) + AxisGap;
  const GutterWidth = FMeasurer.MeasureText(Format(TickLabelFormat, [MaxY]), Font).Width + AxisGap;

  const PlotLeft = FLeft + GutterWidth;
  const PlotTop = FTop;
  const PlotRight = FRight;
  const PlotBottom = FBottom - BottomGutter;
  if (PlotRight <= PlotLeft) or (PlotBottom <= PlotTop) then
    Exit;

  EmitLineSegment(PlotLeft, PlotTop, PlotLeft, PlotBottom, FTheme.ChartGridLineColor, GridStrokeWidth);
  EmitLineSegment(PlotLeft, PlotBottom, PlotRight, PlotBottom, FTheme.ChartGridLineColor, GridStrokeWidth);

  EmitText(Format(TickLabelFormat, [MinX]), PlotLeft, PlotBottom + AxisGap, Font, FTheme.ChartTextColor);
  EmitCenteredText(Format(TickLabelFormat, [MaxX]), PlotRight, PlotBottom + AxisGap, Font, FTheme.ChartTextColor);
  EmitText(Format(TickLabelFormat, [MaxY]), FLeft, PlotTop, Font, FTheme.ChartTextColor);

  const SpanX = MaxX - MinX;
  const SpanY = MaxY - MinY;

  for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
  begin
    const Dataset = FModel.Datasets[DatasetIndex];
    const Color = DatasetColor(DatasetIndex);
    for var PointIndex := 0 to Dataset.PointCount - 1 do
    begin
      const PlotX = PlotLeft + (Dataset.PointsX[PointIndex] - MinX) / SpanX * (PlotRight - PlotLeft);
      const PlotY = PlotBottom - (Dataset.PointsY[PointIndex] - MinY) / SpanY * (PlotBottom - PlotTop);
      EmitWedge(PlotX, PlotY, MarkerRadius, 0, 0, FullCircleDegrees, Color);
    end;
  end;
end;

procedure TChartLayoutBuilder.EmitFilledPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
begin
  FCanvas.FillPolygon(Points, Color);
end;

class function TChartLayoutBuilder.Translucent(const Color: TLayoutColor; const Factor: Single): TLayoutColor;
begin
  const Alpha = (Cardinal(Color) shr 24) and $FF;
  const NewAlpha = Round(Alpha * Factor);
  Result := TLayoutColor((Cardinal(NewAlpha) shl 24) or (Cardinal(Color) and $00FFFFFF));
end;

end.
