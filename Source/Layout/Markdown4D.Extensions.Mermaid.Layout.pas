unit Markdown4D.Extensions.Mermaid.Layout;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Theme,
  Markdown4D.Extensions.Mermaid;

type
  TMermaidLayouter = class
  public
    class procedure Draw(const Model: IMermaidModel; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
      const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
    class function BuildDisplayItems(const Model: IMermaidModel; const Bounds: TLayoutRectF;
      const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Node: IMarkdownNode): TArray<IDisplayItem>;
    class function PreferredHeight(const Model: IMermaidModel; const AvailableWidth: Single;
      const Theme: TMarkdownTheme; const Measurer: ITextMeasurer): Single;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  Markdown4D.Defines,
  Markdown4D.Image.Rasterizer,
  Markdown4D.Layout.ExtensionCanvas;

type
  TMermaidNodeBox = record
    X: Single;
    Y: Single;
    Width: Single;
    Height: Single;
    Rank: Integer;
  end;

  TMermaidBaryKey = record
    Bary: Double;
    Node: Integer;
    Ordinal: Integer;
  end;

  TMermaidLayeredMetrics = record
    RankMainStart: TArray<Single>;
    RankMainSize: TArray<Single>;
    RankCrossWidth: TArray<Single>;
    TotalMain: Single;
    TotalCross: Single;
  end;

  TMermaidBuilderBase = class
  protected
    const
      DashLength = 7.0;
      DashGap = 4.0;
    var
      FModel: IMermaidModel;
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FCanvas: IExtensionCanvas;
    procedure EmitRectangle(const Bounds: TLayoutRectF; const FillColor, StrokeColor: TLayoutColor;
      const StrokeWidth: Single);
    procedure EmitPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
    procedure EmitFilledAndStrokedPolygon(const Points: TArray<TLayoutPointF>; const FillColor, StrokeColor: TLayoutColor;
      const StrokeWidth: Single);
    procedure EmitFilledAndStrokedWedge(const Center: TLayoutPointF; const Radius: Single;
      const FillColor, StrokeColor: TLayoutColor; const StrokeWidth: Single);
    procedure EmitLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure EmitDashedLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
      const StrokeWidth: Single);
    procedure EmitText(const Text: string; const X, Top: Single; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor);
    procedure EmitCenteredText(const Text: string; const CenterX, Top: Single; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor);

  public
    constructor Create(const Model: IMermaidModel; const Theme: TMarkdownTheme; const Measurer: ITextMeasurer;
      const Canvas: IExtensionCanvas);
  end;

  TMermaidFlowchartBuilder = class(TMermaidBuilderBase)
  private
    const
      LabelFontSize = 13.0;
      NodePaddingX = 14.0;
      NodePaddingY = 10.0;
      MinNodeWidth = 40.0;
      MinNodeHeight = 30.0;
      RankGap = 46.0;
      SiblingGap = 30.0;
      DiagramMargin = 10.0;
      MaxLabelChars = 20;
      SolidStrokeWidth = 1.5;
      ThickStrokeWidth = 3.0;
      NodeBorderWidth = 1.5;
      ArrowLength = 11.0;
      ArrowHalfWidth = 5.0;
      DiamondWidthFactor = 1.5;
      DiamondHeightFactor = 1.9;
      RoundedCornerPadding = 6.0;
      OrderingSweeps = 2;
      EdgeLabelPadding = 3.0;
      ParallelEdgeSpacing = 16.0;
    var
      FBounds: TLayoutRectF;
      FBoxes: TArray<TMermaidNodeBox>;
      FLabelLines: TArray<TArray<string>>;
      FSuccessors: TArray<TArray<Integer>>;
      FPredecessors: TArray<TArray<Integer>>;
      FContentWidth: Single;
      FContentHeight: Single;
    function LabelFont: TMarkdownFontStyle;
    function NodeFillColor: TLayoutColor;
    function NodeBorderColor: TLayoutColor;
    function EdgeColor: TLayoutColor;
    function LabelColor: TLayoutColor;
    function IsHorizontal: Boolean;
    function IsReversed: Boolean;
    function WrapCaption(const Caption: string): TArray<string>;
    procedure MeasureNodes;
    procedure BuildAdjacency;
    function TryRank(out MaxRank: Integer): Boolean;
    procedure LayoutLayered(const MaxRank: Integer);
    function BuildRankMembers(const Members: TObjectList<TList<Integer>>;
      const MaxRank: Integer): TArray<TList<Integer>>;
    function ComputeRankMainSizes(const Members: TArray<TList<Integer>>; const MaxRank: Integer;
      const Horizontal: Boolean): TArray<Single>;
    function ComputeRankMainStarts(const RankMainSize: TArray<Single>; const MaxRank: Integer;
      out TotalMain: Single): TArray<Single>;
    function ComputeRankCrossWidths(const Members: TArray<TList<Integer>>; const MaxRank: Integer;
      const Horizontal: Boolean; out TotalCross: Single): TArray<Single>;
    procedure PlaceLayeredNodes(const Members: TArray<TList<Integer>>; const MaxRank: Integer;
      const Horizontal: Boolean; const Metrics: TMermaidLayeredMetrics);
    procedure OrderRanks(const Members: TArray<TList<Integer>>; const MaxRank: Integer);
    procedure SortRankByAdjacent(const Members: TArray<TList<Integer>>; const Rank, ReferenceRank: Integer;
      const UsePredecessors: Boolean);
    function BuildReferencePositions(const Reference: TList<Integer>): TArray<Integer>;
    function ComputeBarycenterKeys(const Current: TList<Integer>; const ReferencePosition: TArray<Integer>;
      const UsePredecessors: Boolean): TArray<TMermaidBaryKey>;
    procedure LayoutGrid;
    procedure EmitNodes;
    procedure EmitNodeShape(const Index: Integer);
    procedure EmitRectangleNode(const Box: TMermaidNodeBox);
    procedure EmitRoundedNode(const Box: TMermaidNodeBox);
    procedure EmitStadiumNode(const Box: TMermaidNodeBox);
    procedure EmitCircleNode(const Box: TMermaidNodeBox);
    procedure EmitDiamondNode(const Box: TMermaidNodeBox);
    class function BuildRoundedRectanglePoints(const Bounds: TLayoutRectF;
      const CornerRadius: Single): TArray<TLayoutPointF>; static;
    procedure EmitNodeLabel(const Index: Integer);
    procedure EmitEdges;
    procedure EmitArrowHead(const Tip, Direction: TLayoutPointF);
    procedure EmitEdgeLabel(const Caption: string; const Center: TLayoutPointF);
    function ParallelEdgeShift(const EdgeIndex: Integer): TLayoutPointF;
    class function NodeCenter(const Box: TMermaidNodeBox): TLayoutPointF; static;
    class function BorderPoint(const Box: TMermaidNodeBox; const Toward: TLayoutPointF): TLayoutPointF; static;
    class function MainSize(const Box: TMermaidNodeBox; const Horizontal: Boolean): Single; static;
    class function CrossSize(const Box: TMermaidNodeBox; const Horizontal: Boolean): Single; static;

  public
    constructor Create(const Model: IMermaidModel; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
      const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
    procedure Build;
    function ContentHeight: Single;
  end;

  TMermaidActivationBar = record
    Participant: Integer;
    StartY: Single;
    EndY: Single;
  end;

  TMermaidSequenceBuilder = class(TMermaidBuilderBase)
  private
    const
      LabelFontSize = 13.0;
      BoxPaddingX = 12.0;
      BoxPaddingY = 8.0;
      MinBoxWidth = 60.0;
      BaseColumnGap = 60.0;
      LabelColumnPadding = 24.0;
      DiagramMargin = 10.0;
      LifelineTopGap = 12.0;
      LifelineBottomGap = 16.0;
      MessageGap = 40.0;
      MessageLabelGap = 5.0;
      ActivationWidth = 10.0;
      ArrowLength = 10.0;
      ArrowHalfWidth = 4.0;
      CrossHalf = 4.0;
      MessageStrokeWidth = 1.5;
      LifelineStrokeWidth = 1.0;
      ActivationBorderWidth = 1.0;
      NotePaddingX = 8.0;
      NotePaddingY = 6.0;
      NoteGap = 14.0;
      NoteMargin = 16.0;
      SelfLoopWidth = 34.0;
      SelfLoopHalfHeight = 8.0;
    var
      FBounds: TLayoutRectF;
      FBars: TList<TMermaidActivationBar>;
      FWidths: TArray<Single>;
      FCenters: TArray<Single>;
      FMessageY: TArray<Single>;
      FNoteTop: TArray<Single>;
      FNoteHeight: TArray<Single>;
      FBoxTop: Single;
      FBoxBottom: Single;
      FLifelineBottom: Single;
      FContentHeight: Single;
    function LabelFont: TMarkdownFontStyle;
    function BoxFillColor: TLayoutColor;
    function BoxBorderColor: TLayoutColor;
    function LifelineColor: TLayoutColor;
    function MessageColor: TLayoutColor;
    function NoteFillColor: TLayoutColor;
    function LabelColor: TLayoutColor;
    procedure MeasureParticipants;
    procedure LayoutColumns;
    procedure LayoutRows;
    procedure ComputeActivations;
    procedure EmitLifelines;
    procedure EmitParticipants;
    procedure EmitActivations;
    procedure EmitMessages;
    procedure EmitMessage(const Index: Integer);
    procedure EmitSelfMessage(const Index: Integer);
    procedure EmitMessageHead(const TipX, TipY, Direction: Single; const Head: TMermaidMessageHead);
    procedure EmitNotes;
    procedure EmitNote(const Index: Integer);
    procedure EmitConnector(const StartPoint, EndPoint: TLayoutPointF; const Line: TMermaidMessageLine;
      const StrokeWidth: Single);

  public
    constructor Create(const Model: IMermaidModel; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
      const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
    destructor Destroy; override;
    procedure Build;
    function ContentHeight: Single;
  end;

  TMermaidPieBuilder = class(TMermaidBuilderBase)
  private
    const
      LabelFontSize = 11.0;
      TitleFontSize = 16.0;
      Padding = 8.0;
      SwatchSize = 10.0;
      SwatchGap = 4.0;
      PieRadiusFactor = 0.9;
      MinLabelSweepDegrees = 18.0;
      AspectRatioWidth = 4.0;
      AspectRatioHeight = 3.0;
    var
      FLeft: Single;
      FTop: Single;
      FRight: Single;
      FBottom: Single;
      FContentHeight: Single;
    function LabelFont: TMarkdownFontStyle;
    function TitleFont: TMarkdownFontStyle;
    function SliceColor(const Index: Integer): TLayoutColor;
    procedure LayoutTitle;
    procedure LayoutLegend;
    procedure LayoutWedges;
    procedure EmitWedge(const CenterX, CenterY, OuterRadius, StartAngle, SweepAngle: Single; const Color: TLayoutColor);

  public
    constructor Create(const Model: IMermaidModel; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
      const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
    class function PreferredHeightForWidth(const AvailableWidth: Single): Single; static;
    procedure Build;
    function ContentHeight: Single;
  end;

class function TMermaidLayouter.BuildDisplayItems(const Model: IMermaidModel; const Bounds: TLayoutRectF;
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

class procedure TMermaidLayouter.Draw(const Model: IMermaidModel; const Bounds: TLayoutRectF;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
begin
  case Model.DiagramKind of
    TMermaidDiagramKind.Sequence:
      begin
        const Builder = TMermaidSequenceBuilder.Create(Model, Bounds, Theme, Measurer, Canvas);
        try
          Builder.Build;
        finally
          Builder.Free;
        end;
      end;
    TMermaidDiagramKind.Pie:
      begin
        const Builder = TMermaidPieBuilder.Create(Model, Bounds, Theme, Measurer, Canvas);
        try
          Builder.Build;
        finally
          Builder.Free;
        end;
      end;
  else
    begin
      const Builder = TMermaidFlowchartBuilder.Create(Model, Bounds, Theme, Measurer, Canvas);
      try
        Builder.Build;
      finally
        Builder.Free;
      end;
    end;
  end;
end;

class function TMermaidLayouter.PreferredHeight(const Model: IMermaidModel; const AvailableWidth: Single;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer): Single;
begin
  const Items = TList<IDisplayItem>.Create;
  try
    var Canvas: IExtensionCanvas := TDisplayListExtensionCanvas.Create(Measurer, Items, nil);
    const Bounds = TLayoutRectF.Create(0, 0, AvailableWidth, AvailableWidth);

    case Model.DiagramKind of
      TMermaidDiagramKind.Sequence:
        begin
          const Builder = TMermaidSequenceBuilder.Create(Model, Bounds, Theme, Measurer, Canvas);
          try
            Builder.Build;
            Result := Builder.ContentHeight;
          finally
            Builder.Free;
          end;
        end;
      TMermaidDiagramKind.Pie:
        begin
          const PieBounds = TLayoutRectF.Create(0, 0, AvailableWidth, TMermaidPieBuilder.PreferredHeightForWidth(AvailableWidth));
          const Builder = TMermaidPieBuilder.Create(Model, PieBounds, Theme, Measurer, Canvas);
          try
            Builder.Build;
            Result := Builder.ContentHeight;
          finally
            Builder.Free;
          end;
        end;
    else
      begin
        const Builder = TMermaidFlowchartBuilder.Create(Model, Bounds, Theme, Measurer, Canvas);
        try
          Builder.Build;
          Result := Builder.ContentHeight;
        finally
          Builder.Free;
        end;
      end;
    end;
  finally
    Items.Free;
  end;
end;

constructor TMermaidBuilderBase.Create(const Model: IMermaidModel; const Theme: TMarkdownTheme;
  const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
begin
  inherited Create;

  FModel := Model;
  FTheme := Theme;
  FMeasurer := Measurer;
  FCanvas := Canvas;
end;

procedure TMermaidBuilderBase.EmitRectangle(const Bounds: TLayoutRectF; const FillColor, StrokeColor: TLayoutColor;
  const StrokeWidth: Single);
begin
  FCanvas.FillAndStrokeRectangle(Bounds, FillColor, StrokeColor, StrokeWidth);
end;

procedure TMermaidBuilderBase.EmitPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
begin
  FCanvas.FillPolygon(Points, Color);
end;

procedure TMermaidBuilderBase.EmitFilledAndStrokedPolygon(const Points: TArray<TLayoutPointF>;
  const FillColor, StrokeColor: TLayoutColor; const StrokeWidth: Single);
begin
  FCanvas.FillAndStrokePolygon(Points, FillColor, StrokeColor, StrokeWidth);
end;

procedure TMermaidBuilderBase.EmitFilledAndStrokedWedge(const Center: TLayoutPointF; const Radius: Single;
  const FillColor, StrokeColor: TLayoutColor; const StrokeWidth: Single);
begin
  FCanvas.FillAndStrokeWedge(Center, Radius, 0, 0, 360, FillColor, StrokeColor, StrokeWidth);
end;

procedure TMermaidBuilderBase.EmitLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  FCanvas.DrawLine(StartPoint, EndPoint, Color, StrokeWidth);
end;

procedure TMermaidBuilderBase.EmitDashedLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  const DeltaX = EndPoint.X - StartPoint.X;
  const DeltaY = EndPoint.Y - StartPoint.Y;
  const Distance = Sqrt(DeltaX * DeltaX + DeltaY * DeltaY);
  if Distance <= 0 then
    Exit;

  const DirectionX = DeltaX / Distance;
  const DirectionY = DeltaY / Distance;

  var Position := 0.0;
  while Position < Distance do
  begin
    const SegmentEndDistance = Min(Position + DashLength, Distance);
    const SegmentStart = TLayoutPointF.Create(StartPoint.X + DirectionX * Position,
      StartPoint.Y + DirectionY * Position);
    const SegmentEnd = TLayoutPointF.Create(StartPoint.X + DirectionX * SegmentEndDistance,
      StartPoint.Y + DirectionY * SegmentEndDistance);
    EmitLine(SegmentStart, SegmentEnd, Color, StrokeWidth);
    Position := SegmentEndDistance + DashGap;
  end;
end;

procedure TMermaidBuilderBase.EmitText(const Text: string; const X, Top: Single; const Font: TMarkdownFontStyle;
  const Color: TLayoutColor);
begin
  if Text = '' then
    Exit;

  FCanvas.DrawText(TLayoutPointF.Create(X, Top), Text, Font, Color);
end;

procedure TMermaidBuilderBase.EmitCenteredText(const Text: string; const CenterX, Top: Single;
  const Font: TMarkdownFontStyle; const Color: TLayoutColor);
begin
  if Text = '' then
    Exit;

  const Size = FMeasurer.MeasureText(Text, Font);
  EmitText(Text, CenterX - Size.Width / 2, Top, Font, Color);
end;

constructor TMermaidFlowchartBuilder.Create(const Model: IMermaidModel; const Bounds: TLayoutRectF;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
begin
  inherited Create(Model, Theme, Measurer, Canvas);

  FBounds := Bounds;
end;

procedure TMermaidFlowchartBuilder.Build;
begin
  const NodeCount = FModel.NodeCount;
  if NodeCount = 0 then
    Exit;

  MeasureNodes;
  BuildAdjacency;

  var MaxRank: Integer;
  if TryRank(MaxRank) then
    LayoutLayered(MaxRank)
  else
    LayoutGrid;

  EmitNodes;
  EmitEdges;
end;

function TMermaidFlowchartBuilder.ContentHeight: Single;
begin
  Result := FContentHeight + 2 * DiagramMargin;
end;

function TMermaidFlowchartBuilder.LabelFont: TMarkdownFontStyle;
begin
  Result := TMarkdownFontStyle.Create(FTheme.BaseFont.FamilyName, LabelFontSize);
end;

function TMermaidFlowchartBuilder.NodeFillColor: TLayoutColor;
begin
  Result := FTheme.CodeBackgroundColor;
end;

function TMermaidFlowchartBuilder.NodeBorderColor: TLayoutColor;
begin
  Result := FTheme.ChartTextColor;
end;

function TMermaidFlowchartBuilder.EdgeColor: TLayoutColor;
begin
  Result := FTheme.ChartTextColor;
end;

function TMermaidFlowchartBuilder.LabelColor: TLayoutColor;
begin
  Result := FTheme.TextColor;
end;

function TMermaidFlowchartBuilder.IsHorizontal: Boolean;
begin
  Result := (FModel.Direction = TMermaidDirection.LR) or (FModel.Direction = TMermaidDirection.RL);
end;

function TMermaidFlowchartBuilder.IsReversed: Boolean;
begin
  Result := (FModel.Direction = TMermaidDirection.BT) or (FModel.Direction = TMermaidDirection.RL);
end;

function TMermaidFlowchartBuilder.WrapCaption(const Caption: string): TArray<string>;
begin
  const Trimmed = Trim(Caption);
  if Trimmed = '' then
  begin
    Result := [''];
    Exit;
  end;

  const Words = Trimmed.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
  if Length(Words) = 0 then
  begin
    Result := [Trimmed];
    Exit;
  end;

  const Collected = TList<string>.Create;
  try
    var Current := '';
    for var Token in Words do
    begin
      if Current = '' then
        Current := Token
      else if Length(Current) + 1 + Length(Token) <= MaxLabelChars then
        Current := Current + ' ' + Token
      else
      begin
        Collected.Add(Current);
        Current := Token;
      end;
    end;

    if Current <> '' then
      Collected.Add(Current);

    Result := Collected.ToArray;
  finally
    Collected.Free;
  end;
end;

procedure TMermaidFlowchartBuilder.MeasureNodes;
begin
  const NodeCount = FModel.NodeCount;
  SetLength(FBoxes, NodeCount);
  SetLength(FLabelLines, NodeCount);

  const Font = LabelFont;
  const LineHeight = FMeasurer.LineHeight(Font);

  for var Index := 0 to NodeCount - 1 do
  begin
    const MermaidNode = FModel.Nodes[Index];
    const Lines = WrapCaption(MermaidNode.Caption);
    FLabelLines[Index] := Lines;

    var TextWidth := 0.0;
    for var Line in Lines do
    begin
      TextWidth := Max(TextWidth, FMeasurer.MeasureText(Line, Font).Width);
    end;

    const TextHeight = Length(Lines) * LineHeight;

    var Width := Max(MinNodeWidth, TextWidth + 2 * NodePaddingX);
    var Height := Max(MinNodeHeight, TextHeight + 2 * NodePaddingY);

    case MermaidNode.Shape of
      TMermaidNodeShape.Diamond:
        begin
          Width := Max(MinNodeWidth, TextWidth * DiamondWidthFactor + 2 * NodePaddingX);
          Height := Max(MinNodeHeight, TextHeight * DiamondHeightFactor + 2 * NodePaddingY);
        end;
      TMermaidNodeShape.Circle:
        begin
          const Diameter = Max(TextWidth, TextHeight) + 2 * Max(NodePaddingX, NodePaddingY);
          Width := Max(MinNodeHeight, Diameter);
          Height := Width;
        end;
      TMermaidNodeShape.Stadium:
        Width := Max(MinNodeWidth, TextWidth + 2 * NodePaddingX + Height);
      TMermaidNodeShape.Rounded:
        Width := Max(MinNodeWidth, TextWidth + 2 * NodePaddingX + 2 * RoundedCornerPadding);
      TMermaidNodeShape.Rectangle:
        ;
    else
      raise EMarkdownError.CreateFmt('Unhandled node shape: %d', [Ord(MermaidNode.Shape)]);
    end;

    FBoxes[Index].Width := Width;
    FBoxes[Index].Height := Height;
    FBoxes[Index].Rank := 0;
  end;
end;

procedure TMermaidFlowchartBuilder.BuildAdjacency;
begin
  const NodeCount = FModel.NodeCount;
  const SuccessorLists = TObjectList<TList<Integer>>.Create(True);
  const PredecessorLists = TObjectList<TList<Integer>>.Create(True);
  try
    for var Index := 0 to NodeCount - 1 do
    begin
      SuccessorLists.Add(TList<Integer>.Create);
      PredecessorLists.Add(TList<Integer>.Create);
    end;

    for var Index := 0 to FModel.EdgeCount - 1 do
    begin
      const Edge = FModel.Edges[Index];
      const Source = Edge.SourceIndex;
      const Target = Edge.TargetIndex;

      const IsValid = (Source >= 0) and (Source < NodeCount) and (Target >= 0) and (Target < NodeCount) and
        (Source <> Target);
      if not IsValid then
        Continue;

      SuccessorLists[Source].Add(Target);
      PredecessorLists[Target].Add(Source);
    end;

    SetLength(FSuccessors, NodeCount);
    SetLength(FPredecessors, NodeCount);

    for var Index := 0 to NodeCount - 1 do
    begin
      FSuccessors[Index] := SuccessorLists[Index].ToArray;
      FPredecessors[Index] := PredecessorLists[Index].ToArray;
    end;
  finally
    PredecessorLists.Free;
    SuccessorLists.Free;
  end;
end;

function TMermaidFlowchartBuilder.TryRank(out MaxRank: Integer): Boolean;
begin
  MaxRank := 0;

  const NodeCount = FModel.NodeCount;

  var Indegree: TArray<Integer>;
  SetLength(Indegree, NodeCount);
  for var Index := 0 to NodeCount - 1 do
  begin
    Indegree[Index] := Length(FPredecessors[Index]);
  end;

  const Order = TList<Integer>.Create;
  const Ready = TQueue<Integer>.Create;
  try
    for var Index := 0 to NodeCount - 1 do
    begin
      if Indegree[Index] = 0 then
        Ready.Enqueue(Index);
    end;

    while Ready.Count > 0 do
    begin
      const Current = Ready.Dequeue;
      Order.Add(Current);

      for var Next in FSuccessors[Current] do
      begin
        Dec(Indegree[Next]);
        if Indegree[Next] = 0 then
          Ready.Enqueue(Next);
      end;
    end;

    if Order.Count < NodeCount then
      Exit(False);

    for var Current in Order do
    begin
      for var Next in FSuccessors[Current] do
      begin
        if FBoxes[Current].Rank + 1 > FBoxes[Next].Rank then
          FBoxes[Next].Rank := FBoxes[Current].Rank + 1;
      end;
    end;

    for var Index := 0 to NodeCount - 1 do
    begin
      MaxRank := Max(MaxRank, FBoxes[Index].Rank);
    end;

    Result := True;
  finally
    Ready.Free;
    Order.Free;
  end;
end;

procedure TMermaidFlowchartBuilder.LayoutLayered(const MaxRank: Integer);
begin
  const Horizontal = IsHorizontal;

  const Members = TObjectList<TList<Integer>>.Create(True);
  try
    const MemberArray = BuildRankMembers(Members, MaxRank);

    OrderRanks(MemberArray, MaxRank);

    var Metrics: TMermaidLayeredMetrics;
    Metrics.RankMainSize := ComputeRankMainSizes(MemberArray, MaxRank, Horizontal);
    Metrics.RankMainStart := ComputeRankMainStarts(Metrics.RankMainSize, MaxRank, Metrics.TotalMain);
    Metrics.RankCrossWidth := ComputeRankCrossWidths(MemberArray, MaxRank, Horizontal, Metrics.TotalCross);

    PlaceLayeredNodes(MemberArray, MaxRank, Horizontal, Metrics);
  finally
    Members.Free;
  end;
end;

function TMermaidFlowchartBuilder.BuildRankMembers(const Members: TObjectList<TList<Integer>>;
  const MaxRank: Integer): TArray<TList<Integer>>;
begin
  for var Rank := 0 to MaxRank do
  begin
    Members.Add(TList<Integer>.Create);
  end;

  SetLength(Result, MaxRank + 1);
  for var Rank := 0 to MaxRank do
  begin
    Result[Rank] := Members[Rank];
  end;

  const NodeCount = FModel.NodeCount;
  for var Index := 0 to NodeCount - 1 do
  begin
    Result[FBoxes[Index].Rank].Add(Index);
  end;
end;

function TMermaidFlowchartBuilder.ComputeRankMainSizes(const Members: TArray<TList<Integer>>;
  const MaxRank: Integer; const Horizontal: Boolean): TArray<Single>;
begin
  SetLength(Result, MaxRank + 1);
  for var Rank := 0 to MaxRank do
  begin
    var Value := 0.0;
    for var NodeIndex in Members[Rank] do
    begin
      Value := Max(Value, MainSize(FBoxes[NodeIndex], Horizontal));
    end;
    Result[Rank] := Value;
  end;
end;

function TMermaidFlowchartBuilder.ComputeRankMainStarts(const RankMainSize: TArray<Single>;
  const MaxRank: Integer; out TotalMain: Single): TArray<Single>;
begin
  SetLength(Result, MaxRank + 1);
  var MainCursor := 0.0;
  for var Rank := 0 to MaxRank do
  begin
    Result[Rank] := MainCursor;
    MainCursor := MainCursor + RankMainSize[Rank] + RankGap;
  end;
  TotalMain := MainCursor - RankGap;

  if IsReversed then
  begin
    for var Rank := 0 to MaxRank do
    begin
      Result[Rank] := TotalMain - Result[Rank] - RankMainSize[Rank];
    end;
  end;
end;

function TMermaidFlowchartBuilder.ComputeRankCrossWidths(const Members: TArray<TList<Integer>>;
  const MaxRank: Integer; const Horizontal: Boolean; out TotalCross: Single): TArray<Single>;
begin
  SetLength(Result, MaxRank + 1);
  TotalCross := 0.0;
  for var Rank := 0 to MaxRank do
  begin
    var Width := 0.0;
    for var NodeIndex in Members[Rank] do
    begin
      Width := Width + CrossSize(FBoxes[NodeIndex], Horizontal) + SiblingGap;
    end;
    if Width > 0 then
      Width := Width - SiblingGap;
    Result[Rank] := Width;
    TotalCross := Max(TotalCross, Width);
  end;
end;

procedure TMermaidFlowchartBuilder.PlaceLayeredNodes(const Members: TArray<TList<Integer>>;
  const MaxRank: Integer; const Horizontal: Boolean; const Metrics: TMermaidLayeredMetrics);
begin
  if Horizontal then
  begin
    FContentWidth := Metrics.TotalMain;
    FContentHeight := Metrics.TotalCross;
  end
  else
  begin
    FContentWidth := Metrics.TotalCross;
    FContentHeight := Metrics.TotalMain;
  end;

  const OriginX = FBounds.Left + Max(0.0, (FBounds.Width - FContentWidth) / 2);
  const OriginY = FBounds.Top + DiagramMargin;

  var OriginMain := OriginY;
  var OriginCross := OriginX;
  if Horizontal then
  begin
    OriginMain := OriginX;
    OriginCross := OriginY;
  end;

  for var Rank := 0 to MaxRank do
  begin
    const Offset = (Metrics.TotalCross - Metrics.RankCrossWidth[Rank]) / 2;
    var CrossCursor := 0.0;

    for var NodeIndex in Members[Rank] do
    begin
      const CrossPos = OriginCross + Offset + CrossCursor;
      const MainPos = OriginMain + Metrics.RankMainStart[Rank] +
        (Metrics.RankMainSize[Rank] - MainSize(FBoxes[NodeIndex], Horizontal)) / 2;

      if Horizontal then
      begin
        FBoxes[NodeIndex].X := MainPos;
        FBoxes[NodeIndex].Y := CrossPos;
      end
      else
      begin
        FBoxes[NodeIndex].X := CrossPos;
        FBoxes[NodeIndex].Y := MainPos;
      end;

      CrossCursor := CrossCursor + CrossSize(FBoxes[NodeIndex], Horizontal) + SiblingGap;
    end;
  end;
end;

procedure TMermaidFlowchartBuilder.OrderRanks(const Members: TArray<TList<Integer>>; const MaxRank: Integer);
begin
  for var Sweep := 1 to OrderingSweeps do
  begin
    for var Rank := 1 to MaxRank do
    begin
      SortRankByAdjacent(Members, Rank, Rank - 1, True);
    end;

    for var Rank := MaxRank - 1 downto 0 do
    begin
      SortRankByAdjacent(Members, Rank, Rank + 1, False);
    end;
  end;
end;

procedure TMermaidFlowchartBuilder.SortRankByAdjacent(const Members: TArray<TList<Integer>>;
  const Rank, ReferenceRank: Integer; const UsePredecessors: Boolean);
begin
  const Current = Members[Rank];
  if Current.Count <= 1 then
    Exit;

  const ReferencePosition = BuildReferencePositions(Members[ReferenceRank]);
  var Keys := ComputeBarycenterKeys(Current, ReferencePosition, UsePredecessors);

  TArray.Sort<TMermaidBaryKey>(Keys, TComparer<TMermaidBaryKey>.Construct(
    function(const Left, Right: TMermaidBaryKey): Integer
    begin
      Result := CompareValue(Left.Bary, Right.Bary);
      if Result = 0 then
        Result := Left.Ordinal - Right.Ordinal;
    end));

  for var Index := 0 to Current.Count - 1 do
  begin
    Current[Index] := Keys[Index].Node;
  end;
end;

function TMermaidFlowchartBuilder.BuildReferencePositions(const Reference: TList<Integer>): TArray<Integer>;
begin
  SetLength(Result, FModel.NodeCount);
  for var Index := 0 to High(Result) do
  begin
    Result[Index] := -1;
  end;

  for var Position := 0 to Reference.Count - 1 do
  begin
    Result[Reference[Position]] := Position;
  end;
end;

function TMermaidFlowchartBuilder.ComputeBarycenterKeys(const Current: TList<Integer>;
  const ReferencePosition: TArray<Integer>; const UsePredecessors: Boolean): TArray<TMermaidBaryKey>;
begin
  SetLength(Result, Current.Count);

  for var Index := 0 to Current.Count - 1 do
  begin
    const NodeIndex = Current[Index];

    var Neighbors: TArray<Integer>;
    if UsePredecessors then
      Neighbors := FPredecessors[NodeIndex]
    else
      Neighbors := FSuccessors[NodeIndex];

    var Sum := 0.0;
    var Count := 0;
    for var Neighbor in Neighbors do
    begin
      if ReferencePosition[Neighbor] >= 0 then
      begin
        Sum := Sum + ReferencePosition[Neighbor];
        Inc(Count);
      end;
    end;

    if Count > 0 then
      Result[Index].Bary := Sum / Count
    else
      Result[Index].Bary := Index;

    Result[Index].Node := NodeIndex;
    Result[Index].Ordinal := Index;
  end;
end;

procedure TMermaidFlowchartBuilder.LayoutGrid;
begin
  const NodeCount = FModel.NodeCount;
  const Columns = Max(1, Ceil(Sqrt(NodeCount)));
  const Rows = Ceil(NodeCount / Columns);

  var MaxWidth := 0.0;
  var MaxHeight := 0.0;
  for var Index := 0 to NodeCount - 1 do
  begin
    MaxWidth := Max(MaxWidth, FBoxes[Index].Width);
    MaxHeight := Max(MaxHeight, FBoxes[Index].Height);
  end;

  const CellWidth = MaxWidth + SiblingGap;
  const CellHeight = MaxHeight + RankGap;

  FContentWidth := Columns * MaxWidth + (Columns - 1) * SiblingGap;
  FContentHeight := Rows * MaxHeight + (Rows - 1) * RankGap;

  const OriginX = FBounds.Left + Max(0.0, (FBounds.Width - FContentWidth) / 2);
  const OriginY = FBounds.Top + DiagramMargin;

  for var Index := 0 to NodeCount - 1 do
  begin
    const Column = Index mod Columns;
    const Row = Index div Columns;

    const CellLeft = OriginX + Column * CellWidth;
    const CellTop = OriginY + Row * CellHeight;

    FBoxes[Index].X := CellLeft + (MaxWidth - FBoxes[Index].Width) / 2;
    FBoxes[Index].Y := CellTop + (MaxHeight - FBoxes[Index].Height) / 2;
  end;
end;

procedure TMermaidFlowchartBuilder.EmitNodes;
begin
  for var Index := 0 to FModel.NodeCount - 1 do
  begin
    EmitNodeShape(Index);
    EmitNodeLabel(Index);
  end;
end;

procedure TMermaidFlowchartBuilder.EmitNodeShape(const Index: Integer);
begin
  const Box = FBoxes[Index];

  case FModel.Nodes[Index].Shape of
    TMermaidNodeShape.Rectangle:
      EmitRectangleNode(Box);
    TMermaidNodeShape.Rounded:
      EmitRoundedNode(Box);
    TMermaidNodeShape.Stadium:
      EmitStadiumNode(Box);
    TMermaidNodeShape.Circle:
      EmitCircleNode(Box);
    TMermaidNodeShape.Diamond:
      EmitDiamondNode(Box);
  else
    raise EMarkdownError.CreateFmt('Unhandled node shape: %d', [Ord(FModel.Nodes[Index].Shape)]);
  end;
end;

procedure TMermaidFlowchartBuilder.EmitRectangleNode(const Box: TMermaidNodeBox);
begin
  const Bounds = TLayoutRectF.Create(Box.X, Box.Y, Box.X + Box.Width, Box.Y + Box.Height);
  EmitRectangle(Bounds, NodeFillColor, NodeBorderColor, NodeBorderWidth);
end;

procedure TMermaidFlowchartBuilder.EmitRoundedNode(const Box: TMermaidNodeBox);
begin
  const Bounds = TLayoutRectF.Create(Box.X, Box.Y, Box.X + Box.Width, Box.Y + Box.Height);
  const Points = BuildRoundedRectanglePoints(Bounds, RoundedCornerPadding);
  EmitFilledAndStrokedPolygon(Points, NodeFillColor, NodeBorderColor, NodeBorderWidth);
end;

procedure TMermaidFlowchartBuilder.EmitStadiumNode(const Box: TMermaidNodeBox);
begin
  const Bounds = TLayoutRectF.Create(Box.X, Box.Y, Box.X + Box.Width, Box.Y + Box.Height);
  const Points = BuildRoundedRectanglePoints(Bounds, Box.Height / 2);
  EmitFilledAndStrokedPolygon(Points, NodeFillColor, NodeBorderColor, NodeBorderWidth);
end;

procedure TMermaidFlowchartBuilder.EmitCircleNode(const Box: TMermaidNodeBox);
begin
  EmitFilledAndStrokedWedge(NodeCenter(Box), Min(Box.Width, Box.Height) / 2, NodeFillColor, NodeBorderColor,
    NodeBorderWidth);
end;

procedure TMermaidFlowchartBuilder.EmitDiamondNode(const Box: TMermaidNodeBox);
begin
  const Center = NodeCenter(Box);
  var Points: TArray<TLayoutPointF>;
  Points := [TLayoutPointF.Create(Center.X, Box.Y), TLayoutPointF.Create(Box.X + Box.Width, Center.Y),
    TLayoutPointF.Create(Center.X, Box.Y + Box.Height), TLayoutPointF.Create(Box.X, Center.Y)];
  EmitFilledAndStrokedPolygon(Points, NodeFillColor, NodeBorderColor, NodeBorderWidth);
end;

class function TMermaidFlowchartBuilder.BuildRoundedRectanglePoints(const Bounds: TLayoutRectF;
  const CornerRadius: Single): TArray<TLayoutPointF>;
begin
  const MaxRadius = Min(Bounds.Width, Bounds.Height) / 2;
  const Radius = Min(CornerRadius, MaxRadius);

  var CornerCenters: TArray<TLayoutPointF>;
  CornerCenters := [TLayoutPointF.Create(Bounds.Right - Radius, Bounds.Top + Radius),
    TLayoutPointF.Create(Bounds.Right - Radius, Bounds.Bottom - Radius),
    TLayoutPointF.Create(Bounds.Left + Radius, Bounds.Bottom - Radius),
    TLayoutPointF.Create(Bounds.Left + Radius, Bounds.Top + Radius)];

  // A quarter turn per corner, so each corner gets the same chord-length
  // smoothness a full circle of this radius would (TMarkdownPolygonRasterizer
  // scales its own segment count as an arc grows, and a rounded rectangle's
  // corner faces the same problem at a wide box or a large corner radius).
  const CornerSegments = Max(1, TMarkdownPolygonRasterizer.SegmentsForRadius(Radius) div 4);

  var Points: TArray<TLayoutPointF> := nil;
  for var CornerIndex := 0 to High(CornerCenters) do
  begin
    const CornerCenter = CornerCenters[CornerIndex];
    const StartAngle = CornerIndex * 90.0 - 90.0;

    for var Step := 0 to CornerSegments do
    begin
      const Angle = DegToRad(StartAngle + Step * 90.0 / CornerSegments);
      Points := Points + [TLayoutPointF.Create(CornerCenter.X + Radius * Cos(Angle),
        CornerCenter.Y + Radius * Sin(Angle))];
    end;
  end;

  Result := Points;
end;

procedure TMermaidFlowchartBuilder.EmitNodeLabel(const Index: Integer);
begin
  const Box = FBoxes[Index];
  const Lines = FLabelLines[Index];
  const Font = LabelFont;
  const LineHeight = FMeasurer.LineHeight(Font);
  const TotalHeight = Length(Lines) * LineHeight;

  var Top := Box.Y + (Box.Height - TotalHeight) / 2;
  const CenterX = Box.X + Box.Width / 2;

  for var Line in Lines do
  begin
    EmitCenteredText(Line, CenterX, Top, Font, LabelColor);
    Top := Top + LineHeight;
  end;
end;

procedure TMermaidFlowchartBuilder.EmitEdges;
begin
  const NodeCount = FModel.NodeCount;

  for var Index := 0 to FModel.EdgeCount - 1 do
  begin
    const Edge = FModel.Edges[Index];
    const Source = Edge.SourceIndex;
    const Target = Edge.TargetIndex;

    const IsValid = (Source >= 0) and (Source < NodeCount) and (Target >= 0) and (Target < NodeCount) and
      (Source <> Target);
    if not IsValid then
      Continue;

    const SourceCenter = NodeCenter(FBoxes[Source]);
    const TargetCenter = NodeCenter(FBoxes[Target]);

    const Shift = ParallelEdgeShift(Index);
    const RawStart = BorderPoint(FBoxes[Source], TargetCenter);
    const RawEnd = BorderPoint(FBoxes[Target], SourceCenter);
    const StartPoint = TLayoutPointF.Create(RawStart.X + Shift.X, RawStart.Y + Shift.Y);
    const EndPoint = TLayoutPointF.Create(RawEnd.X + Shift.X, RawEnd.Y + Shift.Y);

    var StrokeWidth := SolidStrokeWidth;
    if Edge.Stroke = TMermaidEdgeStroke.Thick then
      StrokeWidth := ThickStrokeWidth;

    var LineEnd := EndPoint;

    if Edge.HasArrowHead then
    begin
      const DeltaX = EndPoint.X - StartPoint.X;
      const DeltaY = EndPoint.Y - StartPoint.Y;
      const Distance = Sqrt(DeltaX * DeltaX + DeltaY * DeltaY);

      if Distance > 0 then
      begin
        const Direction = TLayoutPointF.Create(DeltaX / Distance, DeltaY / Distance);
        LineEnd := TLayoutPointF.Create(EndPoint.X - Direction.X * ArrowLength, EndPoint.Y - Direction.Y * ArrowLength);
        EmitArrowHead(EndPoint, Direction);
      end;
    end;

    if Edge.Stroke = TMermaidEdgeStroke.Dashed then
      EmitDashedLine(StartPoint, LineEnd, EdgeColor, StrokeWidth)
    else
      EmitLine(StartPoint, LineEnd, EdgeColor, StrokeWidth);

    if Edge.Caption <> '' then
    begin
      const Midpoint = TLayoutPointF.Create((StartPoint.X + LineEnd.X) / 2, (StartPoint.Y + LineEnd.Y) / 2);
      EmitEdgeLabel(Edge.Caption, Midpoint);
    end;
  end;
end;

function TMermaidFlowchartBuilder.ParallelEdgeShift(const EdgeIndex: Integer): TLayoutPointF;
begin
  const Edge = FModel.Edges[EdgeIndex];
  const PairLow = Min(Edge.SourceIndex, Edge.TargetIndex);
  const PairHigh = Max(Edge.SourceIndex, Edge.TargetIndex);

  // Fan out every edge that connects the same node pair (parallel and
  // anti-parallel edges) so they no longer draw on top of each other. The
  // offset uses the pair's canonical low->high direction, so a back-edge lands
  // on the opposite side of the forward edge instead of cancelling it out.
  var Count := 0;
  var Position := 0;
  for var Other := 0 to FModel.EdgeCount - 1 do
  begin
    const OtherEdge = FModel.Edges[Other];
    if (Min(OtherEdge.SourceIndex, OtherEdge.TargetIndex) = PairLow) and
      (Max(OtherEdge.SourceIndex, OtherEdge.TargetIndex) = PairHigh) then
    begin
      if Other < EdgeIndex then
        Inc(Position);
      Inc(Count);
    end;
  end;

  if Count <= 1 then
    Exit(TLayoutPointF.Create(0, 0));

  const Offset = (Position - (Count - 1) / 2) * ParallelEdgeSpacing;

  const LowCenter = NodeCenter(FBoxes[PairLow]);
  const HighCenter = NodeCenter(FBoxes[PairHigh]);
  const DeltaX = HighCenter.X - LowCenter.X;
  const DeltaY = HighCenter.Y - LowCenter.Y;
  const Distance = Sqrt(DeltaX * DeltaX + DeltaY * DeltaY);
  if Distance = 0 then
    Exit(TLayoutPointF.Create(0, 0));

  Result := TLayoutPointF.Create(-DeltaY / Distance * Offset, DeltaX / Distance * Offset);
end;

procedure TMermaidFlowchartBuilder.EmitArrowHead(const Tip, Direction: TLayoutPointF);
begin
  const BaseX = Tip.X - Direction.X * ArrowLength;
  const BaseY = Tip.Y - Direction.Y * ArrowLength;
  const PerpX = -Direction.Y;
  const PerpY = Direction.X;

  var Points: TArray<TLayoutPointF>;
  Points := [Tip, TLayoutPointF.Create(BaseX + PerpX * ArrowHalfWidth, BaseY + PerpY * ArrowHalfWidth),
    TLayoutPointF.Create(BaseX - PerpX * ArrowHalfWidth, BaseY - PerpY * ArrowHalfWidth)];

  EmitPolygon(Points, EdgeColor);
end;

procedure TMermaidFlowchartBuilder.EmitEdgeLabel(const Caption: string; const Center: TLayoutPointF);
begin
  const Font = LabelFont;
  const Size = FMeasurer.MeasureText(Caption, Font);

  const Bounds = TLayoutRectF.Create(Center.X - Size.Width / 2 - EdgeLabelPadding,
    Center.Y - Size.Height / 2 - EdgeLabelPadding, Center.X + Size.Width / 2 + EdgeLabelPadding,
    Center.Y + Size.Height / 2 + EdgeLabelPadding);

  EmitRectangle(Bounds, FTheme.BackgroundColor, 0, 0);
  EmitCenteredText(Caption, Center.X, Center.Y - Size.Height / 2, Font, LabelColor);
end;

class function TMermaidFlowchartBuilder.NodeCenter(const Box: TMermaidNodeBox): TLayoutPointF;
begin
  Result := TLayoutPointF.Create(Box.X + Box.Width / 2, Box.Y + Box.Height / 2);
end;

class function TMermaidFlowchartBuilder.BorderPoint(const Box: TMermaidNodeBox;
  const Toward: TLayoutPointF): TLayoutPointF;
begin
  const CenterX = Box.X + Box.Width / 2;
  const CenterY = Box.Y + Box.Height / 2;
  const DeltaX = Toward.X - CenterX;
  const DeltaY = Toward.Y - CenterY;

  if (DeltaX = 0) and (DeltaY = 0) then
    Exit(TLayoutPointF.Create(CenterX, CenterY));

  const HalfWidth = Box.Width / 2;
  const HalfHeight = Box.Height / 2;

  var Scale := MaxSingle;
  if DeltaX <> 0 then
    Scale := Min(Scale, HalfWidth / Abs(DeltaX));
  if DeltaY <> 0 then
    Scale := Min(Scale, HalfHeight / Abs(DeltaY));

  Result := TLayoutPointF.Create(CenterX + DeltaX * Scale, CenterY + DeltaY * Scale);
end;

class function TMermaidFlowchartBuilder.MainSize(const Box: TMermaidNodeBox; const Horizontal: Boolean): Single;
begin
  if Horizontal then
    Result := Box.Width
  else
    Result := Box.Height;
end;

class function TMermaidFlowchartBuilder.CrossSize(const Box: TMermaidNodeBox; const Horizontal: Boolean): Single;
begin
  if Horizontal then
    Result := Box.Height
  else
    Result := Box.Width;
end;

constructor TMermaidSequenceBuilder.Create(const Model: IMermaidModel; const Bounds: TLayoutRectF;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
begin
  inherited Create(Model, Theme, Measurer, Canvas);

  FBounds := Bounds;
  FBars := TList<TMermaidActivationBar>.Create;
end;

destructor TMermaidSequenceBuilder.Destroy;
begin
  FBars.Free;

  inherited Destroy;
end;

procedure TMermaidSequenceBuilder.Build;
begin
  if FModel.ParticipantCount = 0 then
    Exit;

  MeasureParticipants;
  LayoutColumns;
  LayoutRows;
  ComputeActivations;

  EmitLifelines;
  EmitParticipants;
  EmitActivations;
  EmitMessages;
  EmitNotes;
end;

function TMermaidSequenceBuilder.ContentHeight: Single;
begin
  Result := FContentHeight + 2 * DiagramMargin;
end;

function TMermaidSequenceBuilder.LabelFont: TMarkdownFontStyle;
begin
  Result := TMarkdownFontStyle.Create(FTheme.BaseFont.FamilyName, LabelFontSize);
end;

function TMermaidSequenceBuilder.BoxFillColor: TLayoutColor;
begin
  Result := FTheme.CodeBackgroundColor;
end;

function TMermaidSequenceBuilder.BoxBorderColor: TLayoutColor;
begin
  Result := FTheme.ChartTextColor;
end;

function TMermaidSequenceBuilder.LifelineColor: TLayoutColor;
begin
  Result := FTheme.ChartGridLineColor;
end;

function TMermaidSequenceBuilder.MessageColor: TLayoutColor;
begin
  Result := FTheme.ChartTextColor;
end;

function TMermaidSequenceBuilder.NoteFillColor: TLayoutColor;
begin
  Result := FTheme.CodeBackgroundColor;
end;

function TMermaidSequenceBuilder.LabelColor: TLayoutColor;
begin
  Result := FTheme.TextColor;
end;

procedure TMermaidSequenceBuilder.MeasureParticipants;
begin
  const Count = FModel.ParticipantCount;
  SetLength(FWidths, Count);

  const Font = LabelFont;

  for var Index := 0 to Count - 1 do
  begin
    const Participant = FModel.Participants[Index];
    var Caption := Participant.Caption;
    if Caption = '' then
      Caption := Participant.Id;

    const TextWidth = FMeasurer.MeasureText(Caption, Font).Width;
    FWidths[Index] := Max(MinBoxWidth, TextWidth + 2 * BoxPaddingX);
  end;
end;

procedure TMermaidSequenceBuilder.LayoutColumns;
begin
  const Count = FModel.ParticipantCount;
  const Font = LabelFont;

  var MaxLabelWidth := 0.0;
  for var Index := 0 to FModel.MessageCount - 1 do
  begin
    const Caption = FModel.Messages[Index].Caption;
    if Caption <> '' then
      MaxLabelWidth := Max(MaxLabelWidth, FMeasurer.MeasureText(Caption, Font).Width);
  end;

  const ColumnGap = Max(BaseColumnGap, MaxLabelWidth + LabelColumnPadding);

  SetLength(FCenters, Count);
  var Cursor := FWidths[0] / 2;
  FCenters[0] := Cursor;

  for var Index := 1 to Count - 1 do
  begin
    Cursor := Cursor + FWidths[Index - 1] / 2 + ColumnGap + FWidths[Index] / 2;
    FCenters[Index] := Cursor;
  end;

  const TotalWidth = FCenters[Count - 1] + FWidths[Count - 1] / 2;
  const OriginX = FBounds.Left + Max(DiagramMargin, (FBounds.Width - TotalWidth) / 2);

  for var Index := 0 to Count - 1 do
  begin
    FCenters[Index] := FCenters[Index] + OriginX;
  end;
end;

procedure TMermaidSequenceBuilder.LayoutRows;
begin
  const Font = LabelFont;
  const LineHeight = FMeasurer.LineHeight(Font);
  const OriginY = FBounds.Top + DiagramMargin;

  FBoxTop := OriginY;
  const BoxHeight = LineHeight + 2 * BoxPaddingY;
  FBoxBottom := FBoxTop + BoxHeight;

  var Cursor := FBoxBottom + LifelineTopGap;

  const MessageCount = FModel.MessageCount;
  SetLength(FMessageY, MessageCount);
  for var Index := 0 to MessageCount - 1 do
  begin
    Cursor := Cursor + MessageGap;
    FMessageY[Index] := Cursor;
  end;

  const NoteCount = FModel.NoteCount;
  SetLength(FNoteTop, NoteCount);
  SetLength(FNoteHeight, NoteCount);
  const NoteBoxHeight = LineHeight + 2 * NotePaddingY;
  for var Index := 0 to NoteCount - 1 do
  begin
    Cursor := Cursor + NoteGap;
    FNoteTop[Index] := Cursor;
    FNoteHeight[Index] := NoteBoxHeight;
    Cursor := Cursor + NoteBoxHeight;
  end;

  FLifelineBottom := Cursor + LifelineBottomGap;
  FContentHeight := FLifelineBottom - OriginY;
end;

procedure TMermaidSequenceBuilder.ComputeActivations;
begin
  const Count = FModel.ParticipantCount;

  var Active: TArray<Boolean>;
  var StartY: TArray<Single>;
  SetLength(Active, Count);
  SetLength(StartY, Count);

  for var Index := 0 to FModel.MessageCount - 1 do
  begin
    const Message = FModel.Messages[Index];
    const Y = FMessageY[Index];
    const Source = Message.SourceIndex;
    const Target = Message.TargetIndex;

    if Message.Activate and (Target >= 0) and (Target < Count) then
    begin
      Active[Target] := True;
      StartY[Target] := Y;
    end;

    if Message.Deactivate and (Source >= 0) and (Source < Count) and Active[Source] then
    begin
      var Bar: TMermaidActivationBar;
      Bar.Participant := Source;
      Bar.StartY := StartY[Source];
      Bar.EndY := Y;
      FBars.Add(Bar);
      Active[Source] := False;
    end;
  end;

  for var Index := 0 to Count - 1 do
  begin
    if Active[Index] then
    begin
      var Bar: TMermaidActivationBar;
      Bar.Participant := Index;
      Bar.StartY := StartY[Index];
      Bar.EndY := FLifelineBottom;
      FBars.Add(Bar);
    end;
  end;
end;

procedure TMermaidSequenceBuilder.EmitLifelines;
begin
  for var Index := 0 to FModel.ParticipantCount - 1 do
  begin
    const CenterX = FCenters[Index];
    EmitLine(TLayoutPointF.Create(CenterX, FBoxBottom), TLayoutPointF.Create(CenterX, FLifelineBottom),
      LifelineColor, LifelineStrokeWidth);
  end;
end;

procedure TMermaidSequenceBuilder.EmitParticipants;
begin
  const Font = LabelFont;
  const LineHeight = FMeasurer.LineHeight(Font);
  const TextTop = FBoxTop + (FBoxBottom - FBoxTop - LineHeight) / 2;

  for var Index := 0 to FModel.ParticipantCount - 1 do
  begin
    const CenterX = FCenters[Index];
    const HalfWidth = FWidths[Index] / 2;
    const Bounds = TLayoutRectF.Create(CenterX - HalfWidth, FBoxTop, CenterX + HalfWidth, FBoxBottom);
    EmitRectangle(Bounds, BoxFillColor, BoxBorderColor, ActivationBorderWidth);

    var Caption := FModel.Participants[Index].Caption;
    if Caption = '' then
      Caption := FModel.Participants[Index].Id;

    EmitCenteredText(Caption, CenterX, TextTop, Font, LabelColor);
  end;
end;

procedure TMermaidSequenceBuilder.EmitActivations;
begin
  for var Bar in FBars do
  begin
    const CenterX = FCenters[Bar.Participant];
    const Bounds = TLayoutRectF.Create(CenterX - ActivationWidth / 2, Bar.StartY, CenterX + ActivationWidth / 2,
      Bar.EndY);
    EmitRectangle(Bounds, BoxFillColor, BoxBorderColor, ActivationBorderWidth);
  end;
end;

procedure TMermaidSequenceBuilder.EmitMessages;
begin
  for var Index := 0 to FModel.MessageCount - 1 do
  begin
    EmitMessage(Index);
  end;
end;

procedure TMermaidSequenceBuilder.EmitMessage(const Index: Integer);
begin
  const Message = FModel.Messages[Index];
  const Count = FModel.ParticipantCount;
  const Source = Message.SourceIndex;
  const Target = Message.TargetIndex;

  if (Source < 0) or (Source >= Count) or (Target < 0) or (Target >= Count) then
    Exit;

  if Source = Target then
  begin
    EmitSelfMessage(Index);
    Exit;
  end;

  const Y = FMessageY[Index];
  const StartX = FCenters[Source];
  const EndX = FCenters[Target];

  var Direction := 1.0;
  if EndX < StartX then
    Direction := -1.0;

  var LineEnd := EndX;
  if Message.Head <> TMermaidMessageHead.Cross then
    LineEnd := EndX - Direction * ArrowLength;

  EmitConnector(TLayoutPointF.Create(StartX, Y), TLayoutPointF.Create(LineEnd, Y), Message.Line, MessageStrokeWidth);
  EmitMessageHead(EndX, Y, Direction, Message.Head);

  if Message.Caption <> '' then
  begin
    const Font = LabelFont;
    const TextHeight = FMeasurer.MeasureText(Message.Caption, Font).Height;
    EmitCenteredText(Message.Caption, (StartX + EndX) / 2, Y - MessageLabelGap - TextHeight, Font, LabelColor);
  end;
end;

procedure TMermaidSequenceBuilder.EmitSelfMessage(const Index: Integer);
begin
  const Message = FModel.Messages[Index];
  const Y = FMessageY[Index];
  const X = FCenters[Message.SourceIndex];
  const RightX = X + SelfLoopWidth;
  const TopY = Y - SelfLoopHalfHeight;
  const BottomY = Y + SelfLoopHalfHeight;

  var LineEnd := X;
  if Message.Head <> TMermaidMessageHead.Cross then
    LineEnd := X + ArrowLength;

  EmitConnector(TLayoutPointF.Create(X, TopY), TLayoutPointF.Create(RightX, TopY), Message.Line, MessageStrokeWidth);
  EmitConnector(TLayoutPointF.Create(RightX, TopY), TLayoutPointF.Create(RightX, BottomY), Message.Line,
    MessageStrokeWidth);
  EmitConnector(TLayoutPointF.Create(RightX, BottomY), TLayoutPointF.Create(LineEnd, BottomY), Message.Line,
    MessageStrokeWidth);
  EmitMessageHead(X, BottomY, -1.0, Message.Head);

  if Message.Caption <> '' then
  begin
    const Font = LabelFont;
    const TextHeight = FMeasurer.MeasureText(Message.Caption, Font).Height;
    EmitCenteredText(Message.Caption, (X + RightX) / 2, TopY - MessageLabelGap - TextHeight, Font, LabelColor);
  end;
end;

procedure TMermaidSequenceBuilder.EmitMessageHead(const TipX, TipY, Direction: Single; const Head: TMermaidMessageHead);
begin
  const BaseX = TipX - Direction * ArrowLength;

  case Head of
    TMermaidMessageHead.Arrow:
      begin
        var Points: TArray<TLayoutPointF>;
        Points := [TLayoutPointF.Create(TipX, TipY), TLayoutPointF.Create(BaseX, TipY - ArrowHalfWidth),
          TLayoutPointF.Create(BaseX, TipY + ArrowHalfWidth)];
        EmitPolygon(Points, MessageColor);
      end;
    TMermaidMessageHead.Open:
      begin
        EmitLine(TLayoutPointF.Create(TipX, TipY), TLayoutPointF.Create(BaseX, TipY - ArrowHalfWidth), MessageColor,
          MessageStrokeWidth);
        EmitLine(TLayoutPointF.Create(TipX, TipY), TLayoutPointF.Create(BaseX, TipY + ArrowHalfWidth), MessageColor,
          MessageStrokeWidth);
      end;
    TMermaidMessageHead.Cross:
      begin
        EmitLine(TLayoutPointF.Create(TipX - CrossHalf, TipY - CrossHalf),
          TLayoutPointF.Create(TipX + CrossHalf, TipY + CrossHalf), MessageColor, MessageStrokeWidth);
        EmitLine(TLayoutPointF.Create(TipX - CrossHalf, TipY + CrossHalf),
          TLayoutPointF.Create(TipX + CrossHalf, TipY - CrossHalf), MessageColor, MessageStrokeWidth);
      end;
  else
    raise EMarkdownError.CreateFmt('Unhandled message head: %d', [Ord(Head)]);
  end;
end;

procedure TMermaidSequenceBuilder.EmitNotes;
begin
  for var Index := 0 to FModel.NoteCount - 1 do
  begin
    EmitNote(Index);
  end;
end;

procedure TMermaidSequenceBuilder.EmitNote(const Index: Integer);
begin
  const Note = FModel.Notes[Index];
  const Count = FModel.ParticipantCount;
  const FromIndex = Note.FromIndex;
  const ToIndex = Note.ToIndex;

  if (FromIndex < 0) or (FromIndex >= Count) or (ToIndex < 0) or (ToIndex >= Count) then
    Exit;

  const Font = LabelFont;
  const TextWidth = FMeasurer.MeasureText(Note.Text, Font).Width;
  const Top = FNoteTop[Index];
  const Bottom = Top + FNoteHeight[Index];

  var BoxWidth := TextWidth + 2 * NotePaddingX;
  var Left: Single;

  case Note.Placement of
    TMermaidNotePlacement.LeftOf:
      Left := FCenters[FromIndex] - NoteMargin - BoxWidth;
    TMermaidNotePlacement.RightOf:
      Left := FCenters[FromIndex] + NoteMargin;
    TMermaidNotePlacement.Over:
      begin
        const CenterFrom = FCenters[FromIndex];
        const CenterTo = FCenters[ToIndex];
        const Span = Abs(CenterTo - CenterFrom);
        BoxWidth := Max(BoxWidth, Span + 2 * NotePaddingX);
        Left := (CenterFrom + CenterTo) / 2 - BoxWidth / 2;
      end;
  else
    raise EMarkdownError.CreateFmt('Unhandled note placement: %d', [Ord(Note.Placement)]);
  end;

  const Right = Left + BoxWidth;
  EmitRectangle(TLayoutRectF.Create(Left, Top, Right, Bottom), NoteFillColor, BoxBorderColor, ActivationBorderWidth);
  EmitCenteredText(Note.Text, (Left + Right) / 2, Top + NotePaddingY, Font, LabelColor);
end;

procedure TMermaidSequenceBuilder.EmitConnector(const StartPoint, EndPoint: TLayoutPointF;
  const Line: TMermaidMessageLine; const StrokeWidth: Single);
begin
  if Line = TMermaidMessageLine.Dashed then
    EmitDashedLine(StartPoint, EndPoint, MessageColor, StrokeWidth)
  else
    EmitLine(StartPoint, EndPoint, MessageColor, StrokeWidth);
end;

constructor TMermaidPieBuilder.Create(const Model: IMermaidModel; const Bounds: TLayoutRectF;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
begin
  inherited Create(Model, Theme, Measurer, Canvas);

  const ClampedHeight = Min(Bounds.Height, PreferredHeightForWidth(Bounds.Width));

  FLeft := Bounds.Left + Padding;
  FTop := Bounds.Top + Padding;
  FRight := Bounds.Left + Bounds.Width - Padding;
  FBottom := Bounds.Top + ClampedHeight - Padding;
  FContentHeight := ClampedHeight;
end;

class function TMermaidPieBuilder.PreferredHeightForWidth(const AvailableWidth: Single): Single;
begin
  Result := AvailableWidth * AspectRatioHeight / AspectRatioWidth;
end;

procedure TMermaidPieBuilder.Build;
begin
  LayoutTitle;
  LayoutLegend;

  const HasPlotArea = (FRight > FLeft) and (FBottom > FTop);
  if HasPlotArea then
    LayoutWedges;
end;

function TMermaidPieBuilder.ContentHeight: Single;
begin
  Result := FContentHeight;
end;

function TMermaidPieBuilder.LabelFont: TMarkdownFontStyle;
begin
  Result := TMarkdownFontStyle.Create(FTheme.BaseFont.FamilyName, LabelFontSize);
end;

function TMermaidPieBuilder.TitleFont: TMarkdownFontStyle;
begin
  Result := TMarkdownFontStyle.Create(FTheme.BaseFont.FamilyName, TitleFontSize, True);
end;

function TMermaidPieBuilder.SliceColor(const Index: Integer): TLayoutColor;
begin
  const Palette = FTheme.ChartPalette;
  const Count = Length(Palette);
  if Count = 0 then
    Exit(FTheme.ChartTextColor);

  Result := Palette[Index mod Count];
end;

procedure TMermaidPieBuilder.LayoutTitle;
begin
  if FModel.Title = '' then
    Exit;

  const Font = TitleFont;
  const Height = FMeasurer.LineHeight(Font);
  EmitCenteredText(FModel.Title, (FLeft + FRight) / 2, FTop, Font, FTheme.ChartTextColor);
  FTop := FTop + Height + Padding;
end;

procedure TMermaidPieBuilder.LayoutLegend;
begin
  const SliceCount = FModel.SliceCount;
  if SliceCount = 0 then
    Exit;

  const Font = LabelFont;
  const RowHeight = Max(FMeasurer.LineHeight(Font), SwatchSize);

  var ColumnWidth := 0.0;
  for var Index := 0 to SliceCount - 1 do
  begin
    const Width = SwatchSize + SwatchGap + FMeasurer.MeasureText(FModel.Slices[Index].Caption, Font).Width;
    ColumnWidth := Max(ColumnWidth, Width);
  end;

  const ColumnX = FRight - ColumnWidth;

  var RowY := FTop;
  for var Index := 0 to SliceCount - 1 do
  begin
    const SwatchTop = RowY + (RowHeight - SwatchSize) / 2;
    EmitRectangle(TLayoutRectF.Create(ColumnX, SwatchTop, ColumnX + SwatchSize, SwatchTop + SwatchSize),
      SliceColor(Index), 0, 0);
    EmitText(FModel.Slices[Index].Caption, ColumnX + SwatchSize + SwatchGap, RowY, Font, FTheme.ChartTextColor);
    RowY := RowY + RowHeight;
  end;

  FRight := FRight - ColumnWidth - Padding;
end;

procedure TMermaidPieBuilder.LayoutWedges;
begin
  const SliceCount = FModel.SliceCount;
  if SliceCount = 0 then
    Exit;

  var Total := 0.0;
  for var Index := 0 to SliceCount - 1 do
  begin
    Total := Total + Max(0, FModel.Slices[Index].Value);
  end;

  const PlotWidth = FRight - FLeft;
  const PlotHeight = FBottom - FTop;
  const CenterX = (FLeft + FRight) / 2;
  const CenterY = (FTop + FBottom) / 2;

  var OuterRadius := Min(PlotWidth, PlotHeight) / 2 * PieRadiusFactor;
  if OuterRadius <= 0 then
    OuterRadius := 1;

  const Font = LabelFont;
  const LabelRadius = OuterRadius / 2;

  var StartAngle := 0.0;
  for var Index := 0 to SliceCount - 1 do
  begin
    const Value = Max(0, FModel.Slices[Index].Value);

    var Sweep := 360 / SliceCount;
    if Total > 0 then
      Sweep := Value / Total * 360;

    EmitWedge(CenterX, CenterY, OuterRadius, StartAngle, Sweep, SliceColor(Index));

    if (Sweep >= MinLabelSweepDegrees) and (Total > 0) then
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

procedure TMermaidPieBuilder.EmitWedge(const CenterX, CenterY, OuterRadius, StartAngle, SweepAngle: Single;
  const Color: TLayoutColor);
begin
  FCanvas.FillWedge(TLayoutPointF.Create(CenterX, CenterY), OuterRadius, 0, StartAngle, SweepAngle, Color);
end;

end.
