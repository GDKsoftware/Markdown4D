unit Markdown4D.Extensions.Chart.Layout;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Extensions.Chart;

type
  TChartLayouter = class
  public
    const
      AspectRatioWidth = 16.0;
      AspectRatioHeight = 9.0;
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
  Markdown4D.Layout.Primitives;

type
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
      GridStrokeWidth = 1.0;
      LineStrokeWidth = 2.0;
      MinLabelSweepDegrees = 18.0;
      PieRadiusFactor = 0.9;
      DoughnutInnerFactor = 0.55;
      TickLabelFormat = '%g';
    var
      FModel: IChartModel;
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FNode: IMarkdownNode;
      FItems: TList<IDisplayItem>;
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
    procedure LayoutAxes;
    procedure LayoutBars(const PlotLeft, PlotTop, PlotRight, PlotBottom, AxisMin, AxisMax: Single);
    procedure LayoutLine(const PlotLeft, PlotTop, PlotRight, PlotBottom, AxisMin, AxisMax: Single);
    procedure LayoutPie;
    function NiceNum(const Value: Double; const RoundResult: Boolean): Double;
    procedure BuildValueAxis(const RawMin, RawMax: Double; out AxisMin, AxisMax: Double; out Ticks: TArray<Double>);
    procedure CollectValueRange(out RawMin, RawMax: Double);

  public
    constructor Create(const Model: IChartModel; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
      const Measurer: ITextMeasurer; const Node: IMarkdownNode);
    destructor Destroy; override;
    function Build: TArray<IDisplayItem>;
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
  const Builder = TChartLayoutBuilder.Create(Model, Bounds, Theme, Measurer, Node);
  try
    Result := Builder.Build;
  finally
    Builder.Free;
  end;
end;

constructor TChartLayoutBuilder.Create(const Model: IChartModel; const Bounds: TLayoutRectF;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Node: IMarkdownNode);
begin
  inherited Create;

  FModel := Model;
  FTheme := Theme;
  FMeasurer := Measurer;
  FNode := Node;
  FItems := TList<IDisplayItem>.Create;

  const ClampedHeight = Min(Bounds.Height, TChartLayouter.PreferredHeight(Bounds.Width, Theme));

  FLeft := Bounds.Left + Padding;
  FTop := Bounds.Top + Padding;
  FRight := Bounds.Left + Bounds.Width - Padding;
  FBottom := Bounds.Top + ClampedHeight - Padding;
end;

destructor TChartLayoutBuilder.Destroy;
begin
  FItems.Free;

  inherited Destroy;
end;

function TChartLayoutBuilder.Build: TArray<IDisplayItem>;
begin
  LayoutTitle;
  LayoutLegend;

  const HasPlotArea = (FRight > FLeft) and (FBottom > FTop);
  if HasPlotArea then
  begin
    case FModel.ChartKind of
      TChartKind.Bar, TChartKind.Line:
        LayoutAxes;
      TChartKind.Pie, TChartKind.Doughnut:
        LayoutPie;
    end;
  end;

  Result := FItems.ToArray;
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
  FItems.Add(TDisplayRectangle.Create(Bounds, FNode, FillColor, StrokeColor, StrokeWidth));
end;

procedure TChartLayoutBuilder.EmitText(const Text: string; const X, Y: Single; const Font: TMarkdownFontStyle;
  const Color: TLayoutColor);
begin
  if Text = '' then
    Exit;

  const Size = FMeasurer.MeasureText(Text, Font);
  const Bounds = TLayoutRectF.Create(X, Y, X + Size.Width, Y + Size.Height);
  FItems.Add(TDisplayTextRun.Create(Bounds, FNode, Text, Font, Color, FMeasurer.Baseline(Font), 0));
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
  const StartPoint = TLayoutPointF.Create(X1, Y1);
  const EndPoint = TLayoutPointF.Create(X2, Y2);
  const Bounds = TLayoutRectF.Create(Min(X1, X2), Min(Y1, Y2), Max(X1, X2), Max(Y1, Y2));
  FItems.Add(TDisplayLine.Create(Bounds, FNode, StartPoint, EndPoint, Color, StrokeWidth));
end;

procedure TChartLayoutBuilder.EmitWedge(const CenterX, CenterY, OuterRadius, InnerRadius, StartAngle,
  SweepAngle: Single; const Color: TLayoutColor);
begin
  const Center = TLayoutPointF.Create(CenterX, CenterY);
  const Bounds = TLayoutRectF.Create(CenterX - OuterRadius, CenterY - OuterRadius, CenterX + OuterRadius,
    CenterY + OuterRadius);
  FItems.Add(TDisplayWedge.Create(Bounds, FNode, Center, OuterRadius, InnerRadius, StartAngle, SweepAngle, Color));
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
      const SwatchTop = RowY + (RowHeight - SwatchSize) / 2;
      EmitRectangle(TLayoutRectF.Create(ColumnX, SwatchTop, ColumnX + SwatchSize, SwatchTop + SwatchSize),
        EntryColor(Index), 0, 0);
      EmitText(EntryCaption(Index), ColumnX + SwatchSize + SwatchGap, RowY, Font, FTheme.ChartTextColor);
      RowY := RowY + RowHeight;
    end;

    if FModel.LegendPosition = TChartLegendPosition.Right then
      FRight := FRight - ColumnWidth - Padding
    else
      FLeft := FLeft + ColumnWidth + Padding;

    Exit;
  end;

  var RowY := FTop;
  if FModel.LegendPosition = TChartLegendPosition.Bottom then
    RowY := FBottom - RowHeight;

  var EntryX := FLeft;
  for var Index := 0 to EntryCount - 1 do
  begin
    const Caption = EntryCaption(Index);
    const CaptionWidth = FMeasurer.MeasureText(Caption, Font).Width;
    const SwatchTop = RowY + (RowHeight - SwatchSize) / 2;
    EmitRectangle(TLayoutRectF.Create(EntryX, SwatchTop, EntryX + SwatchSize, SwatchTop + SwatchSize),
      EntryColor(Index), 0, 0);
    EmitText(Caption, EntryX + SwatchSize + SwatchGap, RowY, Font, FTheme.ChartTextColor);
    EntryX := EntryX + SwatchSize + SwatchGap + CaptionWidth + EntryGap;
  end;

  if FModel.LegendPosition = TChartLegendPosition.Bottom then
    FBottom := FBottom - RowHeight - Padding
  else
    FTop := FTop + RowHeight + Padding;
end;

procedure TChartLayoutBuilder.CollectValueRange(out RawMin, RawMax: Double);
begin
  RawMin := 0;
  RawMax := 0;
  var HasValue := False;

  if FModel.Stacked then
  begin
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
      RawMax := Max(RawMax, PositiveSum);
      RawMin := Min(RawMin, NegativeSum);
    end;
  end
  else
  begin
    for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
    begin
      const Dataset = FModel.Datasets[DatasetIndex];
      for var ValueIndex := 0 to Dataset.ValueCount - 1 do
      begin
        const Value = Dataset.Values[ValueIndex];
        if not HasValue then
        begin
          RawMin := Value;
          RawMax := Value;
          HasValue := True;
        end
        else
        begin
          RawMin := Min(RawMin, Value);
          RawMax := Max(RawMax, Value);
        end;
      end;
    end;
  end;

  if not HasValue then
    RawMax := 1;

  if FModel.ChartKind = TChartKind.Bar then
    RawMin := Min(RawMin, 0);
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

procedure TChartLayoutBuilder.BuildValueAxis(const RawMin, RawMax: Double; out AxisMin, AxisMax: Double;
  out Ticks: TArray<Double>);
begin
  var Low := RawMin;
  var High := RawMax;

  if FModel.HasScaleMin then
    Low := FModel.ScaleMin;
  if FModel.HasScaleMax then
    High := FModel.ScaleMax;

  if High <= Low then
    High := Low + 1;

  const Range = NiceNum(High - Low, False);
  const Spacing = NiceNum(Range / (TargetTickCount - 1), True);

  if FModel.HasScaleMin then
    AxisMin := FModel.ScaleMin
  else
    AxisMin := Floor(Low / Spacing) * Spacing;

  if FModel.HasScaleMax then
    AxisMax := FModel.ScaleMax
  else
    AxisMax := Ceil(High / Spacing) * Spacing;

  const Collected = TList<Double>.Create;
  try
    var Tick := Ceil(AxisMin / Spacing) * Spacing;
    while Tick <= AxisMax + Spacing * 0.001 do
    begin
      Collected.Add(Tick);
      Tick := Tick + Spacing;
    end;

    if Collected.Count = 0 then
    begin
      Collected.Add(AxisMin);
      Collected.Add(AxisMax);
    end;

    Ticks := Collected.ToArray;
  finally
    Collected.Free;
  end;
end;

procedure TChartLayoutBuilder.LayoutAxes;
begin
  var RawMin: Double;
  var RawMax: Double;
  CollectValueRange(RawMin, RawMax);

  var AxisMin: Double;
  var AxisMax: Double;
  var Ticks: TArray<Double>;
  BuildValueAxis(RawMin, RawMax, AxisMin, AxisMax, Ticks);

  const Font = LabelFont;

  var GutterWidth := 0.0;
  for var Tick in Ticks do
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

  const AxisSpan = AxisMax - AxisMin;
  for var Tick in Ticks do
  begin
    const Ratio = (Tick - AxisMin) / AxisSpan;
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
    LayoutBars(PlotLeft, PlotTop, PlotRight, PlotBottom, AxisMin, AxisMax)
  else
    LayoutLine(PlotLeft, PlotTop, PlotRight, PlotBottom, AxisMin, AxisMax);
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
    end
    else
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
  end;
end;

procedure TChartLayoutBuilder.LayoutLine(const PlotLeft, PlotTop, PlotRight, PlotBottom, AxisMin, AxisMax: Single);
begin
  const AxisSpan = AxisMax - AxisMin;
  if AxisSpan <= 0 then
    Exit;

  const PlotHeight = PlotBottom - PlotTop;
  const SlotWidth = (PlotRight - PlotLeft) / Max(1, FModel.LabelCount);

  for var DatasetIndex := 0 to FModel.DatasetCount - 1 do
  begin
    const Dataset = FModel.Datasets[DatasetIndex];
    const Color = DatasetColor(DatasetIndex);

    var PreviousX := 0.0;
    var PreviousY := 0.0;
    var HasPrevious := False;

    for var ValueIndex := 0 to Dataset.ValueCount - 1 do
    begin
      const CenterX = PlotLeft + SlotWidth * (ValueIndex + 0.5);
      const Value = Dataset.Values[ValueIndex];
      const ValueY = PlotBottom - (Value - AxisMin) / AxisSpan * PlotHeight;

      if HasPrevious then
        EmitLineSegment(PreviousX, PreviousY, CenterX, ValueY, Color, LineStrokeWidth);

      PreviousX := CenterX;
      PreviousY := ValueY;
      HasPrevious := True;
    end;
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
      const MidAngle = (StartAngle + Sweep / 2) * Pi / 180;
      const LabelX = CenterX + LabelRadius * Sin(MidAngle);
      const LabelY = CenterY - LabelRadius * Cos(MidAngle);
      const Percent = Format('%.0f%%', [Value / Total * 100]);
      EmitCenteredText(Percent, LabelX, LabelY - FMeasurer.LineHeight(Font) / 2, Font, FTheme.ChartTextColor);
    end;

    StartAngle := StartAngle + Sweep;
  end;
end;

end.
