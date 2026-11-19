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
  System.Types,
  System.Generics.Collections,
  Markdown4D.Defines,
  Markdown4D.Image.Rasterizer,
  Markdown4D.Layout.ExtensionCanvas,
  Markdown4D.Extensions.Mermaid.LayeredLayout;

type
  TMermaidBuilderBase = class
  protected
    const
      DashLength = 7.0;
      DashGap = 4.0;
    var
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
    procedure EmitBackedLabel(const Text: string; const Center: TLayoutPointF; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor; const Padding: Single);

  public
    constructor Create(const Theme: TMarkdownTheme; const Measurer: ITextMeasurer;
      const Canvas: IExtensionCanvas);
  end;

  TMermaidFlowchartBuilder = class(TMermaidBuilderBase)
  private
    var
      FModel: IMermaidGraph;
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
      EdgeLabelPadding = 3.0;
      EdgeLabelStub = 10.0;
      ParallelEdgeSpacing = 16.0;
      UnhandledNodeShapeMessage = 'Unhandled node shape: %d';
    var
      FBounds: TLayoutRectF;
      FNodeSizes: TArray<TLayoutSizeF>;
      FLabelLines: TArray<TArray<string>>;
      FLayout: TMermaidLayeredLayout;
      FBoxes: TArray<TMermaidNodeBox>;
      FContentHeight: Single;
    function LabelFont: TMarkdownFontStyle;
    function NodeFillColor: TLayoutColor;
    function NodeBorderColor: TLayoutColor;
    function EdgeColor: TLayoutColor;
    function LabelColor: TLayoutColor;
    function WrapCaption(const Caption: string): TArray<string>;
    procedure MeasureNodes;
    procedure ArrangeNodes;
    function BuildLayeredEdges: TArray<TMermaidLayeredEdge>;
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

  public
    constructor Create(const Model: IMermaidGraph; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
      const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
    destructor Destroy; override;
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
    var
      FModel: IMermaidSequence;
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
    constructor Create(const Model: IMermaidSequence; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
      const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
    destructor Destroy; override;
    procedure Build;
    function ContentHeight: Single;
  end;

  TMermaidPieBuilder = class(TMermaidBuilderBase)
  private
    var
      FModel: IMermaidPie;
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
    constructor Create(const Model: IMermaidPie; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
      const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
    class function PreferredHeightForWidth(const AvailableWidth: Single): Single; static;
    procedure Build;
    function ContentHeight: Single;
  end;

  TMermaidClassCompartments = record
    HeaderHeight: Single;
    AttributesHeight: Single;
    MethodsHeight: Single;
  end;

  // Draws a class diagram on the layered layout the flowchart uses. Ranking
  // follows what a relation means rather than which way it is written: a
  // parent or a whole goes on the earlier rank, so inheritance always points
  // up in a top-down diagram, the way mermaid draws "Animal <|-- Duck" and
  // "Duck --|> Animal" alike. Every other relation ranks its source first.
  TMermaidClassDiagramBuilder = class(TMermaidBuilderBase)
  private
    var
      FModel: IMermaidClassDiagram;
    const
      LabelFontSize = 13.0;
      CardinalityFontSize = 11.0;
      BoxPaddingX = 12.0;
      HeaderPaddingY = 8.0;
      CompartmentPaddingY = 6.0;
      EmptyCompartmentHeight = 12.0;
      MinBoxWidth = 80.0;
      RankGap = 50.0;
      SiblingGap = 40.0;
      DiagramMargin = 10.0;
      BoxBorderWidth = 1.5;
      RelationStrokeWidth = 1.5;
      TriangleLength = 14.0;
      TriangleHalfWidth = 8.0;
      DiamondLength = 18.0;
      DiamondHalfWidth = 6.0;
      ArrowLength = 10.0;
      ArrowHalfWidth = 6.0;
      CardinalityGap = 4.0;
      LabelPadding = 3.0;
      LabelStub = 10.0;
      ParallelRelationSpacing = 18.0;
      SelfLoopWidth = 26.0;
      SelfLoopMaxHeight = 30.0;
      SelfLoopLabelGap = 4.0;
      AnnotationFormat = '<<%s>>';
      UnhandledRelationEndMessage = 'Unhandled relation end: %d';
    var
      FBounds: TLayoutRectF;
      FBoxSizes: TArray<TLayoutSizeF>;
      FCompartments: TArray<TMermaidClassCompartments>;
      FLayout: TMermaidLayeredLayout;
      FBoxes: TArray<TMermaidNodeBox>;
      FContentHeight: Single;
    function LabelFont: TMarkdownFontStyle;
    function NameFont: TMarkdownFontStyle;
    function MemberFont(const Member: IMermaidClassMember): TMarkdownFontStyle;
    function CardinalityFont: TMarkdownFontStyle;
    function BoxFillColor: TLayoutColor;
    function BoxBorderColor: TLayoutColor;
    function RelationColor: TLayoutColor;
    function TextColor: TLayoutColor;
    function IsHorizontal: Boolean;
    function IsValidRelation(const Relation: IMermaidClassRelation): Boolean;
    procedure MeasureClasses;
    procedure MeasureClass(const Index: Integer);
    function WidestMember(const MermaidClass: IMermaidClass): Single;
    function CompartmentHeight(const MemberCount: Integer): Single;
    procedure ArrangeClasses;
    function BuildLayeredEdges: TArray<TMermaidLayeredEdge>;
    function RelationGap(const Relation: IMermaidClassRelation): Single;
    function EndExtent(const Marker: TMermaidRelationEnd; const Cardinality: string): Single;
    function AlongSize(const Text: string; const Font: TMarkdownFontStyle): Single;
    procedure EmitClasses;
    procedure EmitClass(const Index: Integer);
    function EmitClassHeader(const MermaidClass: IMermaidClass; const Box: TMermaidNodeBox): Single;
    procedure EmitSeparator(const Box: TMermaidNodeBox; const Y: Single);
    procedure EmitMember(const Member: IMermaidClassMember; const Box: TMermaidNodeBox; const Top: Single);
    procedure EmitRelations;
    procedure EmitRelation(const Index: Integer);
    procedure EmitSelfRelation(const Relation: IMermaidClassRelation);
    procedure EmitRelationLine(const StartPoint, EndPoint: TLayoutPointF; const Line: TMermaidRelationLine);
    procedure EmitMarker(const Tip, Direction: TLayoutPointF; const Marker: TMermaidRelationEnd);
    procedure EmitTriangle(const Tip, Direction: TLayoutPointF);
    procedure EmitDiamond(const Tip, Direction: TLayoutPointF; const FillColor: TLayoutColor);
    procedure EmitOpenArrow(const Tip, Direction: TLayoutPointF);
    procedure EmitCardinality(const Cardinality: string; const Tip, Direction: TLayoutPointF;
      const Marker: TMermaidRelationEnd);
    class function IsParentEnd(const Marker: TMermaidRelationEnd): Boolean; static;
    class function MarkerLength(const Marker: TMermaidRelationEnd): Single; static;
    class function Offset(const Point, Direction: TLayoutPointF; const Distance: Single): TLayoutPointF; static;

  public
    constructor Create(const Model: IMermaidClassDiagram; const Bounds: TLayoutRectF; const Theme: TMarkdownTheme;
      const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
    destructor Destroy; override;
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
        const Builder = TMermaidSequenceBuilder.Create(Model as IMermaidSequence, Bounds, Theme, Measurer, Canvas);
        try
          Builder.Build;
        finally
          Builder.Free;
        end;
      end;
    TMermaidDiagramKind.Pie:
      begin
        const Builder = TMermaidPieBuilder.Create(Model as IMermaidPie, Bounds, Theme, Measurer, Canvas);
        try
          Builder.Build;
        finally
          Builder.Free;
        end;
      end;
    TMermaidDiagramKind.ClassDiagram:
      begin
        const Builder = TMermaidClassDiagramBuilder.Create(Model as IMermaidClassDiagram, Bounds, Theme, Measurer,
          Canvas);
        try
          Builder.Build;
        finally
          Builder.Free;
        end;
      end;
  else
    begin
      const Builder = TMermaidFlowchartBuilder.Create(Model as IMermaidGraph, Bounds, Theme, Measurer, Canvas);
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
          const Builder = TMermaidSequenceBuilder.Create(Model as IMermaidSequence, Bounds, Theme, Measurer, Canvas);
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
          const Builder = TMermaidPieBuilder.Create(Model as IMermaidPie, PieBounds, Theme, Measurer, Canvas);
          try
            Builder.Build;
            Result := Builder.ContentHeight;
          finally
            Builder.Free;
          end;
        end;
      TMermaidDiagramKind.ClassDiagram:
        begin
          const Builder = TMermaidClassDiagramBuilder.Create(Model as IMermaidClassDiagram, Bounds, Theme, Measurer,
            Canvas);
          try
            Builder.Build;
            Result := Builder.ContentHeight;
          finally
            Builder.Free;
          end;
        end;
    else
      begin
        const Builder = TMermaidFlowchartBuilder.Create(Model as IMermaidGraph, Bounds, Theme, Measurer, Canvas);
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

constructor TMermaidBuilderBase.Create(const Theme: TMarkdownTheme;
  const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
begin
  inherited Create;

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

// A label on a line sits on a patch of the page background, so the line does
// not run through its text.
procedure TMermaidBuilderBase.EmitBackedLabel(const Text: string; const Center: TLayoutPointF;
  const Font: TMarkdownFontStyle; const Color: TLayoutColor; const Padding: Single);
begin
  const Size = FMeasurer.MeasureText(Text, Font);

  const Bounds = TLayoutRectF.Create(Center.X - Size.Width / 2 - Padding, Center.Y - Size.Height / 2 - Padding,
    Center.X + Size.Width / 2 + Padding, Center.Y + Size.Height / 2 + Padding);

  EmitRectangle(Bounds, FTheme.BackgroundColor, 0, 0);
  EmitCenteredText(Text, Center.X, Center.Y - Size.Height / 2, Font, Color);
end;

constructor TMermaidFlowchartBuilder.Create(const Model: IMermaidGraph; const Bounds: TLayoutRectF;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
begin
  inherited Create(Theme, Measurer, Canvas);

  FModel := Model;

  FBounds := Bounds;
end;

destructor TMermaidFlowchartBuilder.Destroy;
begin
  FLayout.Free;

  inherited Destroy;
end;

procedure TMermaidFlowchartBuilder.Build;
begin
  if FModel.NodeCount = 0 then
    Exit;

  MeasureNodes;
  ArrangeNodes;

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

function TMermaidFlowchartBuilder.WrapCaption(const Caption: string): TArray<string>;
begin
  const Trimmed = Trim(Caption);
  if Trimmed = '' then
  begin
    Result := [''];
    Exit;
  end;

  const Words = Trimmed.Split([' ', Tabulator], TStringSplitOptions.ExcludeEmpty);
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
  SetLength(FNodeSizes, NodeCount);
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
      raise EMarkdownError.CreateFmt(UnhandledNodeShapeMessage, [Ord(MermaidNode.Shape)]);
    end;

    FNodeSizes[Index] := TLayoutSizeF.Create(Width, Height);
  end;
end;

procedure TMermaidFlowchartBuilder.ArrangeNodes;
begin
  FLayout := TMermaidLayeredLayout.Create(FNodeSizes, BuildLayeredEdges, FModel.Direction, RankGap, SiblingGap);
  FLayout.Arrange(FBounds, DiagramMargin);

  FBoxes := FLayout.Boxes;
  FContentHeight := FLayout.ContentHeight;
end;

// A labelled edge carries its caption at the midpoint of the line, over an
// opaque background. The gap it crosses has to fit that caption plus visible
// line stubs and the arrowhead, or the label swallows the whole edge and bites
// into the node shapes on either side.
function TMermaidFlowchartBuilder.BuildLayeredEdges: TArray<TMermaidLayeredEdge>;
begin
  const Font = LabelFont;

  SetLength(Result, FModel.EdgeCount);
  for var Index := 0 to FModel.EdgeCount - 1 do
  begin
    const Edge = FModel.Edges[Index];

    var MinimumGap := 0.0;
    if Edge.Caption <> '' then
    begin
      const LabelWidth = FMeasurer.MeasureText(Edge.Caption, Font).Width;
      MinimumGap := LabelWidth + 2 * EdgeLabelPadding + ArrowLength + 2 * EdgeLabelStub;
    end;

    Result[Index] := TMermaidLayeredEdge.Create(Edge.SourceIndex, Edge.TargetIndex, MinimumGap);
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
    raise EMarkdownError.CreateFmt(UnhandledNodeShapeMessage, [Ord(FModel.Nodes[Index].Shape)]);
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
  EmitFilledAndStrokedWedge(Box.Center, Min(Box.Width, Box.Height) / 2, NodeFillColor, NodeBorderColor,
    NodeBorderWidth);
end;

procedure TMermaidFlowchartBuilder.EmitDiamondNode(const Box: TMermaidNodeBox);
begin
  const Center = Box.Center;
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

    const SourceCenter = FBoxes[Source].Center;
    const TargetCenter = FBoxes[Target].Center;

    const Shift = FLayout.ParallelEdgeShift(Index, ParallelEdgeSpacing);
    const RawStart = FBoxes[Source].BorderPoint(TargetCenter);
    const RawEnd = FBoxes[Target].BorderPoint(SourceCenter);
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
  EmitBackedLabel(Caption, Center, LabelFont, LabelColor, EdgeLabelPadding);
end;

constructor TMermaidSequenceBuilder.Create(const Model: IMermaidSequence; const Bounds: TLayoutRectF;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
begin
  inherited Create(Theme, Measurer, Canvas);

  FModel := Model;

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

constructor TMermaidPieBuilder.Create(const Model: IMermaidPie; const Bounds: TLayoutRectF;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
begin
  inherited Create(Theme, Measurer, Canvas);

  FModel := Model;

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
  begin
    Result := FTheme.ChartTextColor;
    Exit;
  end;

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

procedure TMermaidPieBuilder.EmitWedge(const CenterX, CenterY, OuterRadius, StartAngle, SweepAngle: Single;
  const Color: TLayoutColor);
begin
  FCanvas.FillWedge(TLayoutPointF.Create(CenterX, CenterY), OuterRadius, 0, StartAngle, SweepAngle, Color);
end;

constructor TMermaidClassDiagramBuilder.Create(const Model: IMermaidClassDiagram; const Bounds: TLayoutRectF;
  const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Canvas: IExtensionCanvas);
begin
  inherited Create(Theme, Measurer, Canvas);

  FModel := Model;

  FBounds := Bounds;
end;

destructor TMermaidClassDiagramBuilder.Destroy;
begin
  FLayout.Free;

  inherited Destroy;
end;

procedure TMermaidClassDiagramBuilder.Build;
begin
  if FModel.ClassCount = 0 then
    Exit;

  MeasureClasses;
  ArrangeClasses;

  EmitClasses;
  EmitRelations;
end;

function TMermaidClassDiagramBuilder.ContentHeight: Single;
begin
  Result := FContentHeight + 2 * DiagramMargin;
end;

function TMermaidClassDiagramBuilder.LabelFont: TMarkdownFontStyle;
begin
  Result := TMarkdownFontStyle.Create(FTheme.BaseFont.FamilyName, LabelFontSize);
end;

function TMermaidClassDiagramBuilder.NameFont: TMarkdownFontStyle;
begin
  Result := TMarkdownFontStyle.Create(FTheme.BaseFont.FamilyName, LabelFontSize, True);
end;

// UML marks a static member by underlining it and an abstract one by setting
// it in italics; mermaid draws them the same way.
function TMermaidClassDiagramBuilder.MemberFont(const Member: IMermaidClassMember): TMarkdownFontStyle;
begin
  Result := LabelFont;

  case Member.Classifier of
    TMermaidClassClassifier.None:
      ;
    TMermaidClassClassifier.Static:
      Result.Underline := True;
    TMermaidClassClassifier.Abstract:
      Result.Italic := True;
  else
    raise EMarkdownError.CreateFmt('Unhandled member classifier: %d', [Ord(Member.Classifier)]);
  end;
end;

function TMermaidClassDiagramBuilder.CardinalityFont: TMarkdownFontStyle;
begin
  Result := TMarkdownFontStyle.Create(FTheme.BaseFont.FamilyName, CardinalityFontSize);
end;

function TMermaidClassDiagramBuilder.BoxFillColor: TLayoutColor;
begin
  Result := FTheme.CodeBackgroundColor;
end;

function TMermaidClassDiagramBuilder.BoxBorderColor: TLayoutColor;
begin
  Result := FTheme.ChartTextColor;
end;

function TMermaidClassDiagramBuilder.RelationColor: TLayoutColor;
begin
  Result := FTheme.ChartTextColor;
end;

function TMermaidClassDiagramBuilder.TextColor: TLayoutColor;
begin
  Result := FTheme.TextColor;
end;

function TMermaidClassDiagramBuilder.IsHorizontal: Boolean;
begin
  Result := (FModel.Direction = TMermaidDirection.LR) or (FModel.Direction = TMermaidDirection.RL);
end;

function TMermaidClassDiagramBuilder.IsValidRelation(const Relation: IMermaidClassRelation): Boolean;
begin
  Result := (Relation.SourceIndex >= 0) and (Relation.SourceIndex < FModel.ClassCount) and
    (Relation.TargetIndex >= 0) and (Relation.TargetIndex < FModel.ClassCount);
end;

procedure TMermaidClassDiagramBuilder.MeasureClasses;
begin
  SetLength(FBoxSizes, FModel.ClassCount);
  SetLength(FCompartments, FModel.ClassCount);

  for var Index := 0 to FModel.ClassCount - 1 do
  begin
    MeasureClass(Index);
  end;
end;

procedure TMermaidClassDiagramBuilder.MeasureClass(const Index: Integer);
begin
  const MermaidClass = FModel.Classes[Index];
  const LineHeight = FMeasurer.LineHeight(LabelFont);

  var TextWidth := FMeasurer.MeasureText(MermaidClass.Caption, NameFont).Width;
  var HeaderHeight := 2 * HeaderPaddingY + FMeasurer.LineHeight(NameFont);

  if MermaidClass.Annotation <> '' then
  begin
    const AnnotationText = Format(AnnotationFormat, [MermaidClass.Annotation]);
    TextWidth := Max(TextWidth, FMeasurer.MeasureText(AnnotationText, LabelFont).Width);
    HeaderHeight := HeaderHeight + LineHeight;
  end;

  TextWidth := Max(TextWidth, WidestMember(MermaidClass));

  FCompartments[Index].HeaderHeight := HeaderHeight;
  FCompartments[Index].AttributesHeight := CompartmentHeight(MermaidClass.AttributeCount);
  FCompartments[Index].MethodsHeight := CompartmentHeight(MermaidClass.MethodCount);

  const Width = Max(MinBoxWidth, TextWidth + 2 * BoxPaddingX);
  const Height = FCompartments[Index].HeaderHeight + FCompartments[Index].AttributesHeight +
    FCompartments[Index].MethodsHeight;
  FBoxSizes[Index] := TLayoutSizeF.Create(Width, Height);
end;

function TMermaidClassDiagramBuilder.WidestMember(const MermaidClass: IMermaidClass): Single;
begin
  Result := 0;

  for var Index := 0 to MermaidClass.AttributeCount - 1 do
  begin
    const Attribute = MermaidClass.Attributes[Index];
    Result := Max(Result, FMeasurer.MeasureText(Attribute.DisplayText, MemberFont(Attribute)).Width);
  end;

  for var Index := 0 to MermaidClass.MethodCount - 1 do
  begin
    const Method = MermaidClass.Methods[Index];
    Result := Max(Result, FMeasurer.MeasureText(Method.DisplayText, MemberFont(Method)).Width);
  end;
end;

function TMermaidClassDiagramBuilder.CompartmentHeight(const MemberCount: Integer): Single;
begin
  if MemberCount = 0 then
  begin
    Result := EmptyCompartmentHeight;
    Exit;
  end;

  Result := MemberCount * FMeasurer.LineHeight(LabelFont) + 2 * CompartmentPaddingY;
end;

procedure TMermaidClassDiagramBuilder.ArrangeClasses;
begin
  FLayout := TMermaidLayeredLayout.Create(FBoxSizes, BuildLayeredEdges, FModel.Direction, RankGap, SiblingGap);
  FLayout.Arrange(FBounds, DiagramMargin);

  FBoxes := FLayout.Boxes;
  FContentHeight := FLayout.ContentHeight;
end;

function TMermaidClassDiagramBuilder.BuildLayeredEdges: TArray<TMermaidLayeredEdge>;
begin
  SetLength(Result, FModel.RelationCount);

  for var Index := 0 to FModel.RelationCount - 1 do
  begin
    const Relation = FModel.Relations[Index];
    const TargetIsParent = IsParentEnd(Relation.TargetEnd) and not IsParentEnd(Relation.SourceEnd);

    if TargetIsParent then
      Result[Index] := TMermaidLayeredEdge.Create(Relation.TargetIndex, Relation.SourceIndex, RelationGap(Relation))
    else
      Result[Index] := TMermaidLayeredEdge.Create(Relation.SourceIndex, Relation.TargetIndex, RelationGap(Relation));
  end;
end;

// The gap between two ranks has to fit what a relation carries along its
// line: the marker and cardinality at each end and the label in the middle,
// with a visible stretch of line on either side of the label.
function TMermaidClassDiagramBuilder.RelationGap(const Relation: IMermaidClassRelation): Single;
begin
  Result := EndExtent(Relation.SourceEnd, Relation.SourceCardinality) +
    EndExtent(Relation.TargetEnd, Relation.TargetCardinality) + 2 * LabelStub;

  if Relation.Caption <> '' then
    Result := Result + AlongSize(Relation.Caption, LabelFont) + 2 * LabelPadding;
end;

function TMermaidClassDiagramBuilder.EndExtent(const Marker: TMermaidRelationEnd; const Cardinality: string): Single;
begin
  Result := Max(MarkerLength(Marker), ArrowLength);

  if Cardinality <> '' then
    Result := Result + CardinalityGap + AlongSize(Cardinality, CardinalityFont);
end;

function TMermaidClassDiagramBuilder.AlongSize(const Text: string; const Font: TMarkdownFontStyle): Single;
begin
  if IsHorizontal then
    Result := FMeasurer.MeasureText(Text, Font).Width
  else
    Result := FMeasurer.LineHeight(Font);
end;

procedure TMermaidClassDiagramBuilder.EmitClasses;
begin
  for var Index := 0 to FModel.ClassCount - 1 do
  begin
    EmitClass(Index);
  end;
end;

procedure TMermaidClassDiagramBuilder.EmitClass(const Index: Integer);
begin
  const MermaidClass = FModel.Classes[Index];
  const Box = FBoxes[Index];
  const LineHeight = FMeasurer.LineHeight(LabelFont);

  EmitRectangle(Box.Bounds, BoxFillColor, BoxBorderColor, BoxBorderWidth);

  const AttributesTop = EmitClassHeader(MermaidClass, Box);
  const MethodsTop = AttributesTop + FCompartments[Index].AttributesHeight;

  EmitSeparator(Box, AttributesTop);
  EmitSeparator(Box, MethodsTop);

  var Top := AttributesTop + CompartmentPaddingY;
  for var Member := 0 to MermaidClass.AttributeCount - 1 do
  begin
    EmitMember(MermaidClass.Attributes[Member], Box, Top);
    Top := Top + LineHeight;
  end;

  Top := MethodsTop + CompartmentPaddingY;
  for var Member := 0 to MermaidClass.MethodCount - 1 do
  begin
    EmitMember(MermaidClass.Methods[Member], Box, Top);
    Top := Top + LineHeight;
  end;
end;

function TMermaidClassDiagramBuilder.EmitClassHeader(const MermaidClass: IMermaidClass;
  const Box: TMermaidNodeBox): Single;
begin
  const CenterX = Box.X + Box.Width / 2;
  var Top := Box.Y + HeaderPaddingY;

  if MermaidClass.Annotation <> '' then
  begin
    EmitCenteredText(Format(AnnotationFormat, [MermaidClass.Annotation]), CenterX, Top, LabelFont, TextColor);
    Top := Top + FMeasurer.LineHeight(LabelFont);
  end;

  EmitCenteredText(MermaidClass.Caption, CenterX, Top, NameFont, TextColor);

  Result := Top + FMeasurer.LineHeight(NameFont) + HeaderPaddingY;
end;

procedure TMermaidClassDiagramBuilder.EmitSeparator(const Box: TMermaidNodeBox; const Y: Single);
begin
  EmitLine(TLayoutPointF.Create(Box.X, Y), TLayoutPointF.Create(Box.X + Box.Width, Y), BoxBorderColor,
    BoxBorderWidth);
end;

procedure TMermaidClassDiagramBuilder.EmitMember(const Member: IMermaidClassMember; const Box: TMermaidNodeBox;
  const Top: Single);
begin
  EmitText(Member.DisplayText, Box.X + BoxPaddingX, Top, MemberFont(Member), TextColor);
end;

procedure TMermaidClassDiagramBuilder.EmitRelations;
begin
  for var Index := 0 to FModel.RelationCount - 1 do
  begin
    EmitRelation(Index);
  end;
end;

// A relation runs straight between the borders of its two boxes. Each marker
// sits with its tip on the border, and the line stops where the marker
// begins, so a hollow triangle or diamond stays hollow.
procedure TMermaidClassDiagramBuilder.EmitRelation(const Index: Integer);
begin
  const Relation = FModel.Relations[Index];
  if not IsValidRelation(Relation) then
    Exit;

  if Relation.SourceIndex = Relation.TargetIndex then
  begin
    EmitSelfRelation(Relation);
    Exit;
  end;

  const SourceBox = FBoxes[Relation.SourceIndex];
  const TargetBox = FBoxes[Relation.TargetIndex];
  const Shift = FLayout.ParallelEdgeShift(Index, ParallelRelationSpacing);
  const RawStart = SourceBox.BorderPoint(TargetBox.Center);
  const RawEnd = TargetBox.BorderPoint(SourceBox.Center);
  const StartPoint = TLayoutPointF.Create(RawStart.X + Shift.X, RawStart.Y + Shift.Y);
  const EndPoint = TLayoutPointF.Create(RawEnd.X + Shift.X, RawEnd.Y + Shift.Y);

  const DeltaX = EndPoint.X - StartPoint.X;
  const DeltaY = EndPoint.Y - StartPoint.Y;
  const Distance = Sqrt(DeltaX * DeltaX + DeltaY * DeltaY);
  if Distance <= 0 then
    Exit;

  const Forward = TLayoutPointF.Create(DeltaX / Distance, DeltaY / Distance);
  const Backward = TLayoutPointF.Create(-Forward.X, -Forward.Y);

  const LineStart = Offset(StartPoint, Forward, MarkerLength(Relation.SourceEnd));
  const LineEnd = Offset(EndPoint, Backward, MarkerLength(Relation.TargetEnd));
  EmitRelationLine(LineStart, LineEnd, Relation.Line);

  EmitMarker(StartPoint, Backward, Relation.SourceEnd);
  EmitMarker(EndPoint, Forward, Relation.TargetEnd);

  EmitCardinality(Relation.SourceCardinality, StartPoint, Backward, Relation.SourceEnd);
  EmitCardinality(Relation.TargetCardinality, EndPoint, Forward, Relation.TargetEnd);

  if Relation.Caption <> '' then
  begin
    const Midpoint = TLayoutPointF.Create((LineStart.X + LineEnd.X) / 2, (LineStart.Y + LineEnd.Y) / 2);
    EmitBackedLabel(Relation.Caption, Midpoint, LabelFont, TextColor, LabelPadding);
  end;
end;

// A class related to itself gets a loop out of the right side of its box and
// back, with the marker of each end where the loop meets the box.
procedure TMermaidClassDiagramBuilder.EmitSelfRelation(const Relation: IMermaidClassRelation);
begin
  const Box = FBoxes[Relation.SourceIndex];
  const Right = Box.X + Box.Width;
  const LoopHeight = Min(SelfLoopMaxHeight, Box.Height / 2);
  const CenterY = Box.Y + Box.Height / 2;
  const IntoBox = TLayoutPointF.Create(-1, 0);
  const OutOfBox = TLayoutPointF.Create(1, 0);

  const LoopStart = TLayoutPointF.Create(Right, CenterY - LoopHeight / 2);
  const LoopEnd = TLayoutPointF.Create(Right, CenterY + LoopHeight / 2);
  const FarTop = TLayoutPointF.Create(Right + SelfLoopWidth, LoopStart.Y);
  const FarBottom = TLayoutPointF.Create(Right + SelfLoopWidth, LoopEnd.Y);

  EmitRelationLine(Offset(LoopStart, OutOfBox, MarkerLength(Relation.SourceEnd)), FarTop, Relation.Line);
  EmitRelationLine(FarTop, FarBottom, Relation.Line);
  EmitRelationLine(FarBottom, Offset(LoopEnd, OutOfBox, MarkerLength(Relation.TargetEnd)), Relation.Line);

  EmitMarker(LoopStart, IntoBox, Relation.SourceEnd);
  EmitMarker(LoopEnd, IntoBox, Relation.TargetEnd);

  if Relation.Caption <> '' then
  begin
    const LabelTop = CenterY - FMeasurer.LineHeight(LabelFont) / 2;
    EmitText(Relation.Caption, FarTop.X + SelfLoopLabelGap, LabelTop, LabelFont, TextColor);
  end;
end;

procedure TMermaidClassDiagramBuilder.EmitRelationLine(const StartPoint, EndPoint: TLayoutPointF;
  const Line: TMermaidRelationLine);
begin
  case Line of
    TMermaidRelationLine.Solid:
      EmitLine(StartPoint, EndPoint, RelationColor, RelationStrokeWidth);
    TMermaidRelationLine.Dashed:
      EmitDashedLine(StartPoint, EndPoint, RelationColor, RelationStrokeWidth);
  else
    raise EMarkdownError.CreateFmt('Unhandled relation line: %d', [Ord(Line)]);
  end;
end;

// Direction points from the line toward the tip, which sits on the border of
// the class the marker belongs to.
procedure TMermaidClassDiagramBuilder.EmitMarker(const Tip, Direction: TLayoutPointF;
  const Marker: TMermaidRelationEnd);
begin
  case Marker of
    TMermaidRelationEnd.None:
      ;
    TMermaidRelationEnd.Inheritance:
      EmitTriangle(Tip, Direction);
    TMermaidRelationEnd.Composition:
      EmitDiamond(Tip, Direction, RelationColor);
    TMermaidRelationEnd.Aggregation:
      EmitDiamond(Tip, Direction, FTheme.BackgroundColor);
    TMermaidRelationEnd.Arrow:
      EmitOpenArrow(Tip, Direction);
  else
    raise EMarkdownError.CreateFmt(UnhandledRelationEndMessage, [Ord(Marker)]);
  end;
end;

procedure TMermaidClassDiagramBuilder.EmitTriangle(const Tip, Direction: TLayoutPointF);
begin
  const Base = Offset(Tip, Direction, -TriangleLength);
  const Perpendicular = TLayoutPointF.Create(-Direction.Y, Direction.X);

  var Points: TArray<TLayoutPointF>;
  Points := [Tip, Offset(Base, Perpendicular, TriangleHalfWidth), Offset(Base, Perpendicular, -TriangleHalfWidth)];

  EmitFilledAndStrokedPolygon(Points, FTheme.BackgroundColor, RelationColor, RelationStrokeWidth);
end;

procedure TMermaidClassDiagramBuilder.EmitDiamond(const Tip, Direction: TLayoutPointF; const FillColor: TLayoutColor);
begin
  const Middle = Offset(Tip, Direction, -DiamondLength / 2);
  const Back = Offset(Tip, Direction, -DiamondLength);
  const Perpendicular = TLayoutPointF.Create(-Direction.Y, Direction.X);

  var Points: TArray<TLayoutPointF>;
  Points := [Tip, Offset(Middle, Perpendicular, DiamondHalfWidth), Back,
    Offset(Middle, Perpendicular, -DiamondHalfWidth)];

  EmitFilledAndStrokedPolygon(Points, FillColor, RelationColor, RelationStrokeWidth);
end;

procedure TMermaidClassDiagramBuilder.EmitOpenArrow(const Tip, Direction: TLayoutPointF);
begin
  const Base = Offset(Tip, Direction, -ArrowLength);
  const Perpendicular = TLayoutPointF.Create(-Direction.Y, Direction.X);

  EmitLine(Tip, Offset(Base, Perpendicular, ArrowHalfWidth), RelationColor, RelationStrokeWidth);
  EmitLine(Tip, Offset(Base, Perpendicular, -ArrowHalfWidth), RelationColor, RelationStrokeWidth);
end;

// A cardinality sits just past the marker, beside the line rather than on
// it, always on the same side of the direction toward its class. The two
// ends point in opposite directions, so the two numbers land on
// opposite sides of the line, the way mermaid writes "1" left of the start
// and "*" right of the end.
procedure TMermaidClassDiagramBuilder.EmitCardinality(const Cardinality: string; const Tip, Direction: TLayoutPointF;
  const Marker: TMermaidRelationEnd);
begin
  if Cardinality = '' then
    Exit;

  const Font = CardinalityFont;
  const Size = FMeasurer.MeasureText(Cardinality, Font);
  const HalfAlong = Abs(Direction.X) * Size.Width / 2 + Abs(Direction.Y) * Size.Height / 2;
  const HalfAcross = Abs(Direction.Y) * Size.Width / 2 + Abs(Direction.X) * Size.Height / 2;
  const Beside = TLayoutPointF.Create(Direction.Y, -Direction.X);

  const Along = Offset(Tip, Direction, -(Max(MarkerLength(Marker), ArrowLength) + CardinalityGap + HalfAlong));
  const Center = Offset(Along, Beside, HalfAcross + CardinalityGap);

  EmitText(Cardinality, Center.X - Size.Width / 2, Center.Y - Size.Height / 2, Font, TextColor);
end;

class function TMermaidClassDiagramBuilder.IsParentEnd(const Marker: TMermaidRelationEnd): Boolean;
begin
  Result := (Marker = TMermaidRelationEnd.Inheritance) or (Marker = TMermaidRelationEnd.Composition) or
    (Marker = TMermaidRelationEnd.Aggregation);
end;

class function TMermaidClassDiagramBuilder.MarkerLength(const Marker: TMermaidRelationEnd): Single;
begin
  case Marker of
    TMermaidRelationEnd.None, TMermaidRelationEnd.Arrow:
      Result := 0;
    TMermaidRelationEnd.Inheritance:
      Result := TriangleLength;
    TMermaidRelationEnd.Composition, TMermaidRelationEnd.Aggregation:
      Result := DiamondLength;
  else
    raise EMarkdownError.CreateFmt(UnhandledRelationEndMessage, [Ord(Marker)]);
  end;
end;

class function TMermaidClassDiagramBuilder.Offset(const Point, Direction: TLayoutPointF;
  const Distance: Single): TLayoutPointF;
begin
  Result := TLayoutPointF.Create(Point.X + Direction.X * Distance, Point.Y + Direction.Y * Distance);
end;

end.
