unit Markdown4D.Extensions.Mermaid.Layout.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Mermaid.Corpus,
  Markdown4D.Extensions.Interfaces;

type
  [TestFixture]
  TMermaidLayoutTests = class
  private
    const
      DiagramWidth = 480.0;
      DiagramHeight = 360.0;
      ShapedCaption = 'Stage One Two Three';
      ShopClassDiagram = 'class-diagram-shop';
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FCorpus: TMermaidCorpus;
    function ModelItems(const CaseName: string): TArray<IDisplayItem>;
    function ItemsForDiagram(const Diagram: string): TArray<IDisplayItem>;
    class function MermaidPipeline: IMarkdownPipeline;
    class function CountKind(const Items: TArray<IDisplayItem>; const Kind: TDisplayItemKind): Integer;
    class function DistinctValueCount(const Values: TArray<Single>; const Tolerance: Single): Integer;
    class function RectanglesOverlap(const A, B: TLayoutRectF): Boolean;
    class function FindFirstPolygon(const Items: TArray<IDisplayItem>; out Polygon: IDisplayPolygon): Boolean;
    class function FindFirstRectangle(const Items: TArray<IDisplayItem>; out Rectangle: IDisplayRectangle): Boolean;
    class function FindFirstWedge(const Items: TArray<IDisplayItem>; out Wedge: IDisplayWedge): Boolean;
    class function FirstNodeShapeWidth(const Items: TArray<IDisplayItem>): Single;
    class function ClassBoxes(const Items: TArray<IDisplayItem>): TArray<TLayoutRectF>;
    class function FindText(const Items: TArray<IDisplayItem>; const Text: string; out Run: IDisplayTextRun): Boolean;
    class function BoxOfText(const Items: TArray<IDisplayItem>; const Text: string): TLayoutRectF;
    class function Polygons(const Items: TArray<IDisplayItem>; const PointCount: Integer): TArray<IDisplayPolygon>;
    class procedure AssertNoOverlap(const Boxes: TArray<TLayoutRectF>);

  public
    [SetupFixture]
    procedure SetupFixture;

    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure Flowchart_NodesHaveNonOverlappingBounds;

    [Test]
    procedure Flowchart_EmitsEdgeSegments;

    [Test]
    procedure Flowchart_AntiParallelEdges_DoNotOverlap;

    [Test]
    procedure Flowchart_TopDown_SourceRanksAboveTarget;

    [Test]
    procedure Flowchart_Cycle_BreaksBackEdgeAndLaysOutAsChain;

    [Test]
    procedure Flowchart_DecisionWithRetryEdge_NodesFormAChainNotAGrid;

    [Test]
    procedure Flowchart_DecisionWithRetryEdge_BackEdgeStillDrawnBackward;

    [Test]
    procedure Flowchart_RoundedAndStadiumNodes_AreWiderThanRectangle;

    [Test]
    procedure Flowchart_StadiumNode_EmitsPolygonPrimitive;

    [Test]
    procedure Flowchart_RoundedNode_EmitsPolygonPrimitive;

    [Test]
    procedure Flowchart_CircleNode_EmitsWedgePrimitive;

    [Test]
    procedure Flowchart_DiamondNode_EmitsFourPointPolygon;

    [Test]
    procedure Flowchart_PolygonNodeShapes_HaveAVisibleBorder;

    [Test]
    procedure Flowchart_CircleNode_BorderMatchesRectangleNodeBorder;

    [Test]
    procedure Flowchart_LabelledEdge_KeepsLineVisibleAroundLabel;

    [Test]
    procedure Sequence_EmitsVerticalLifelines;

    [Test]
    procedure Sequence_EmitsMessageSegments;

    [Test]
    procedure Pie_EmitsWedgePerSlice;
    [Test]
    procedure Pie_PercentageLabel_SitsInsideItsOwnSlice;

    [Test]
    procedure Deterministic_SameInputProducesIdenticalPrimitiveKinds;

    [Test]
    procedure ClassDiagram_IssueExample_DrawsABoxPerClass;

    [Test]
    procedure ClassDiagram_IssueExample_BoxesDoNotOverlap;

    [Test]
    procedure ClassDiagram_ManyClasses_BoxesDoNotOverlap;

    [Test]
    procedure ClassDiagram_SameInput_ProducesIdenticalLayout;

    [Test]
    procedure ClassDiagram_Association_SourceSitsAboveTarget;

    [Test]
    [TestCase('ParentFirst', 'Animal <|-- Duck')]
    [TestCase('ChildFirst', 'Duck --|> Animal')]
    [TestCase('RealizationParentFirst', 'Animal <|.. Duck')]
    [TestCase('RealizationChildFirst', 'Duck ..|> Animal')]
    procedure ClassDiagram_Inheritance_ParentSitsAboveChild(const Relation: string);

    [Test]
    procedure ClassDiagram_LeftToRight_ParentSitsLeftOfChild;

    [Test]
    procedure ClassDiagram_BottomToTop_ParentSitsBelowChild;

    [Test]
    procedure ClassDiagram_Box_HasThreeCompartments;

    [Test]
    procedure ClassDiagram_Annotation_SitsAboveBoldName;

    [Test]
    procedure ClassDiagram_IssueExample_DrawsCardinalitiesAndLabels;

    [Test]
    procedure ClassDiagram_Composition_DrawsFilledDiamondAtWhole;

    [Test]
    procedure ClassDiagram_Aggregation_DrawsHollowDiamond;

    [Test]
    procedure ClassDiagram_Inheritance_DrawsHollowTriangleAtParent;

    [Test]
    procedure ClassDiagram_Association_DrawsOpenArrowAtTarget;

    [Test]
    procedure ClassDiagram_DashedRelation_DrawsDashes;

    [Test]
    procedure ClassDiagram_StaticAndAbstractMembers_UseUnderlineAndItalic;

    [Test]
    procedure ClassDiagram_PreferredHeight_CoversEveryBox;

    [Test]
    procedure ClassDiagram_SelfRelation_DrawsLoopBesideBox;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Pipeline,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Extensions.Mermaid,
  Markdown4D.Extensions.Mermaid.Layout,
  Markdown4D.Tests.Pipeline.Helpers,
  Markdown4D.Tests.Arrays;

class function TMermaidLayoutTests.MermaidPipeline: IMarkdownPipeline;
begin
  Result := TMarkdownPipeline.Create.UseGfm.Use(TMermaidExtension.Create).UnsafeHtml.Build;
end;

class function TMermaidLayoutTests.CountKind(const Items: TArray<IDisplayItem>; const Kind: TDisplayItemKind): Integer;
begin
  Result := 0;

  for var Item in Items do
  begin
    if Item.Kind = Kind then
      Inc(Result);
  end;
end;

class function TMermaidLayoutTests.DistinctValueCount(const Values: TArray<Single>; const Tolerance: Single): Integer;
begin
  Result := 0;

  for var Index := 0 to High(Values) do
  begin
    var IsDistinct := True;
    for var Earlier := 0 to Index - 1 do
    begin
      if Abs(Values[Index] - Values[Earlier]) < Tolerance then
        IsDistinct := False;
    end;

    if IsDistinct then
      Inc(Result);
  end;
end;

class function TMermaidLayoutTests.RectanglesOverlap(const A, B: TLayoutRectF): Boolean;
begin
  Result := (A.Left < B.Right) and (B.Left < A.Right) and (A.Top < B.Bottom) and (B.Top < A.Bottom);
end;

class function TMermaidLayoutTests.FindFirstPolygon(const Items: TArray<IDisplayItem>; out Polygon: IDisplayPolygon): Boolean;
begin
  Polygon := nil;

  for var Item in Items do
  begin
    if Supports(Item, IDisplayPolygon, Polygon) then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class function TMermaidLayoutTests.FindFirstRectangle(const Items: TArray<IDisplayItem>; out Rectangle: IDisplayRectangle): Boolean;
begin
  Rectangle := nil;

  for var Item in Items do
  begin
    if Supports(Item, IDisplayRectangle, Rectangle) then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class function TMermaidLayoutTests.FindFirstWedge(const Items: TArray<IDisplayItem>; out Wedge: IDisplayWedge): Boolean;
begin
  Wedge := nil;

  for var Item in Items do
  begin
    if Supports(Item, IDisplayWedge, Wedge) then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class function TMermaidLayoutTests.FirstNodeShapeWidth(const Items: TArray<IDisplayItem>): Single;
begin
  for var Item in Items do
  begin
    if (Item.Kind = TDisplayItemKind.Rectangle) or (Item.Kind = TDisplayItemKind.Polygon) then
    begin
      Result := Item.Bounds.Width;
      Exit;
    end;
  end;

  Result := 0;
end;

class function TMermaidLayoutTests.ClassBoxes(const Items: TArray<IDisplayItem>): TArray<TLayoutRectF>;
begin
  Result := nil;

  for var Item in Items do
  begin
    var Rectangle: IDisplayRectangle;
    const IsBorderedRectangle = Supports(Item, IDisplayRectangle, Rectangle) and (Rectangle.StrokeWidth > 0);
    if IsBorderedRectangle then
      Result := Result + [Item.Bounds];
  end;
end;

class function TMermaidLayoutTests.FindText(const Items: TArray<IDisplayItem>; const Text: string;
  out Run: IDisplayTextRun): Boolean;
begin
  Run := nil;

  for var Item in Items do
  begin
    if Supports(Item, IDisplayTextRun, Run) and (Run.Text = Text) then
    begin
      Result := True;
      Exit;
    end;
  end;

  Run := nil;
  Result := False;
end;

class function TMermaidLayoutTests.BoxOfText(const Items: TArray<IDisplayItem>; const Text: string): TLayoutRectF;
begin
  var Run: IDisplayTextRun;
  Assert.IsTrue(FindText(Items, Text, Run), Format('The diagram must draw the text "%s"', [Text]));

  const Center = TLayoutPointF.Create((Run.Bounds.Left + Run.Bounds.Right) / 2, (Run.Bounds.Top + Run.Bounds.Bottom) / 2);
  for var Box in ClassBoxes(Items) do
  begin
    if Box.Contains(Center) then
    begin
      Result := Box;
      Exit;
    end;
  end;

  Assert.Fail(Format('The text "%s" must sit inside a class box', [Text]));
end;

class function TMermaidLayoutTests.Polygons(const Items: TArray<IDisplayItem>;
  const PointCount: Integer): TArray<IDisplayPolygon>;
begin
  Result := nil;

  for var Item in Items do
  begin
    var Polygon: IDisplayPolygon;
    if Supports(Item, IDisplayPolygon, Polygon) and (Polygon.PointCount = PointCount) then
      Result := Result + [Polygon];
  end;
end;

class procedure TMermaidLayoutTests.AssertNoOverlap(const Boxes: TArray<TLayoutRectF>);
begin
  for var I := 0 to High(Boxes) do
  begin
    for var J := I + 1 to High(Boxes) do
    begin
      Assert.IsFalse(RectanglesOverlap(Boxes[I], Boxes[J]), Format('Class boxes %d and %d must not overlap', [I, J]));
    end;
  end;
end;

procedure TMermaidLayoutTests.SetupFixture;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FMeasurer := TFakeTextMeasurer.Create;
  FCorpus := TMermaidCorpus.Create;
end;

procedure TMermaidLayoutTests.TearDownFixture;
begin
  FreeAndNil(FCorpus);
  FMeasurer := nil;
  FreeAndNil(FTheme);
end;

function TMermaidLayoutTests.ModelItems(const CaseName: string): TArray<IDisplayItem>;
begin
  const Item = FCorpus.FindCase(CaseName);
  const Document = MermaidPipeline.Parse(Item.Markdown);

  var Code: IMarkdownCodeBlock;
  Assert.IsTrue(TMarkdownTestPipelineHelpers.FindFirstCodeBlock(Document, Code), Format('Case "%s" must expose a code block', [CaseName]));

  var Model: IMermaidModel;
  Assert.IsTrue(TMermaidExtension.TryParse(Code, Model), Format('Case "%s" must parse into a mermaid model', [CaseName]));

  const Bounds = TLayoutRectF.Create(0, 0, DiagramWidth, DiagramHeight);
  Result := TMermaidLayouter.BuildDisplayItems(Model, Bounds, FTheme, FMeasurer, Code);
end;

function TMermaidLayoutTests.ItemsForDiagram(const Diagram: string): TArray<IDisplayItem>;
begin
  const Markdown = '```mermaid' + LineFeed + Diagram + LineFeed + '```' + LineFeed;
  const Document = MermaidPipeline.Parse(Markdown);

  var Code: IMarkdownCodeBlock;
  Assert.IsTrue(TMarkdownTestPipelineHelpers.FindFirstCodeBlock(Document, Code), 'Diagram must expose a code block');

  var Model: IMermaidModel;
  Assert.IsTrue(TMermaidExtension.TryParse(Code, Model), 'Diagram must parse into a mermaid model');

  const Bounds = TLayoutRectF.Create(0, 0, DiagramWidth, DiagramHeight);
  Result := TMermaidLayouter.BuildDisplayItems(Model, Bounds, FTheme, FMeasurer, Code);
end;

procedure TMermaidLayoutTests.Flowchart_NodesHaveNonOverlappingBounds;
begin
  const Items = ModelItems('flowchart-simple-chain');

  var Rectangles: TArray<TLayoutRectF> := nil;
  for var Item in Items do
  begin
    if Item.Kind = TDisplayItemKind.Rectangle then
      Rectangles := Rectangles + [Item.Bounds];
  end;

  Assert.IsTrue(Length(Rectangles) >= 3, 'A three-node flowchart must emit a rectangle per node');

  for var I := 0 to High(Rectangles) do
  begin
    for var J := I + 1 to High(Rectangles) do
    begin
      Assert.IsFalse(RectanglesOverlap(Rectangles[I], Rectangles[J]),
        Format('Node rectangles %d and %d must not overlap', [I, J]));
    end;
  end;
end;

procedure TMermaidLayoutTests.Flowchart_EmitsEdgeSegments;
begin
  const Items = ModelItems('flowchart-simple-chain');
  Assert.IsTrue(CountKind(Items, TDisplayItemKind.Line) >= 2, 'A two-edge flowchart must emit edge line segments');
end;

procedure TMermaidLayoutTests.Flowchart_AntiParallelEdges_DoNotOverlap;
begin
  const Items = ItemsForDiagram('flowchart LR' + LineFeed + '  A --> B' + LineFeed + '  B --> A');

  var Lines: TArray<IDisplayLine> := nil;
  for var Item in Items do
  begin
    var Line: IDisplayLine;
    if Supports(Item, IDisplayLine, Line) then
      Lines := Lines + [Line];
  end;

  Assert.AreEqual(2, Integer(Length(Lines)), 'Two edges between the same nodes must emit two segments');

  const MidY0 = (Lines[0].StartPoint.Y + Lines[0].EndPoint.Y) / 2;
  const MidY1 = (Lines[1].StartPoint.Y + Lines[1].EndPoint.Y) / 2;
  Assert.IsTrue(Abs(MidY0 - MidY1) > 1.0,
    'Anti-parallel edges must be fanned apart instead of drawn on top of each other');
end;

procedure TMermaidLayoutTests.Flowchart_TopDown_SourceRanksAboveTarget;
begin
  const Items = ModelItems('flowchart-simple-chain');

  var FirstTop := MaxSingle;
  var LastTop := -MaxSingle;
  for var Item in Items do
  begin
    if Item.Kind <> TDisplayItemKind.Rectangle then
      Continue;
    FirstTop := Min(FirstTop, Item.Bounds.Top);
    LastTop := Max(LastTop, Item.Bounds.Top);
  end;

  Assert.IsTrue(LastTop > FirstTop, 'In a top-down flowchart later ranks must sit below earlier ranks');
end;

procedure TMermaidLayoutTests.Flowchart_Cycle_BreaksBackEdgeAndLaysOutAsChain;
begin
  const Items = ModelItems('flowchart-cycle');

  var Tops: TArray<Single> := nil;
  for var Item in Items do
  begin
    if Item.Kind = TDisplayItemKind.Rectangle then
      Tops := Tops + [Item.Bounds.Top];
  end;

  Assert.AreEqual(3, Integer(Length(Tops)), 'A three-node cycle must still emit a rectangle per node');
  Assert.AreEqual(3, DistinctValueCount(Tops, 1.0),
    'Breaking the cycle''s back edge for ranking must let each node take its own rank, ' +
    'not fold three nodes into a shared grid row');
end;

procedure TMermaidLayoutTests.Flowchart_DecisionWithRetryEdge_NodesFormAChainNotAGrid;
begin
  const Items = ItemsForDiagram('flowchart LR' + LineFeed +
    '  Edit[Edit source] --> Parse{Parse ok?}' + LineFeed +
    '  Parse -->|yes| Preview([Render preview])' + LineFeed +
    '  Parse -->|no| Edit' + LineFeed +
    '  Preview --> Sync[Scroll sync]');

  // Node shapes are emitted before any edge (EmitNodes, then EmitEdges), so the
  // first four rectangle-or-polygon items are exactly the four nodes, not an
  // edge label background or an arrowhead sharing the same primitive kinds.
  var Lefts: TArray<Single> := nil;
  for var Item in Items do
  begin
    if Length(Lefts) >= 4 then
      Break;
    if (Item.Kind = TDisplayItemKind.Rectangle) or (Item.Kind = TDisplayItemKind.Polygon) then
      Lefts := Lefts + [Item.Bounds.Left];
  end;

  Assert.AreEqual(4, Integer(Length(Lefts)), 'A four-node flowchart must emit a shape per node');
  Assert.AreEqual(4, DistinctValueCount(Lefts, 1.0),
    'A decision with a retry edge back to an earlier step must still read left to right as a chain, ' +
    'not fold into a two-by-two grid');
end;

procedure TMermaidLayoutTests.Flowchart_DecisionWithRetryEdge_BackEdgeStillDrawnBackward;
begin
  const Items = ItemsForDiagram('flowchart LR' + LineFeed +
    '  Edit[Edit source] --> Parse{Parse ok?}' + LineFeed +
    '  Parse -->|yes| Preview([Render preview])' + LineFeed +
    '  Parse -->|no| Edit' + LineFeed +
    '  Preview --> Sync[Scroll sync]');

  var HasBackwardLine := False;
  for var Item in Items do
  begin
    var Line: IDisplayLine;
    if Supports(Item, IDisplayLine, Line) and (Line.EndPoint.X < Line.StartPoint.X - 1.0) then
      HasBackwardLine := True;
  end;

  Assert.IsTrue(HasBackwardLine,
    'The retry edge must still be drawn from Parse back to Edit in its authored direction, not silently reversed');
end;

procedure TMermaidLayoutTests.Flowchart_RoundedAndStadiumNodes_AreWiderThanRectangle;
begin
  const RectangleWidth = FirstNodeShapeWidth(ItemsForDiagram('flowchart TD' + LineFeed + '  A[' + ShapedCaption + ']'));
  const RoundedWidth = FirstNodeShapeWidth(ItemsForDiagram('flowchart TD' + LineFeed + '  A(' + ShapedCaption + ')'));
  const StadiumWidth = FirstNodeShapeWidth(ItemsForDiagram('flowchart TD' + LineFeed + '  A([' + ShapedCaption + '])'));

  Assert.IsTrue(RectangleWidth > 0, 'A rectangle node must emit a rectangle primitive');
  Assert.IsTrue(RoundedWidth > RectangleWidth,
    'A rounded node must be sized wider than a plain rectangle with the same caption');
  Assert.IsTrue(StadiumWidth > RectangleWidth,
    'A stadium node must be sized wider than a plain rectangle to fit its rounded end caps');
end;

procedure TMermaidLayoutTests.Flowchart_StadiumNode_EmitsPolygonPrimitive;
begin
  const Items = ItemsForDiagram('flowchart TD' + LineFeed + '  A([' + ShapedCaption + '])');

  Assert.AreEqual(0, CountKind(Items, TDisplayItemKind.Rectangle),
    'A stadium node must not be drawn as a plain rectangle');

  var Polygon: IDisplayPolygon;
  Assert.IsTrue(FindFirstPolygon(Items, Polygon), 'A stadium node must emit a polygon primitive');
  Assert.IsTrue(Polygon.PointCount > 4,
    'A stadium polygon must have more than four points to show its rounded end caps');
end;

procedure TMermaidLayoutTests.Flowchart_RoundedNode_EmitsPolygonPrimitive;
begin
  const Items = ItemsForDiagram('flowchart TD' + LineFeed + '  A(' + ShapedCaption + ')');

  Assert.AreEqual(0, CountKind(Items, TDisplayItemKind.Rectangle),
    'A rounded node must not be drawn as a plain rectangle');

  var Polygon: IDisplayPolygon;
  Assert.IsTrue(FindFirstPolygon(Items, Polygon), 'A rounded node must emit a polygon primitive');
  Assert.IsTrue(Polygon.PointCount > 4,
    'A rounded polygon must have more than four points to show its rounded corners');
end;

procedure TMermaidLayoutTests.Flowchart_CircleNode_EmitsWedgePrimitive;
begin
  const Items = ItemsForDiagram('flowchart TD' + LineFeed + '  A((' + ShapedCaption + '))');
  Assert.AreEqual(1, CountKind(Items, TDisplayItemKind.Wedge), 'A circle node must emit a single wedge primitive');
end;

procedure TMermaidLayoutTests.Flowchart_DiamondNode_EmitsFourPointPolygon;
begin
  const Items = ItemsForDiagram('flowchart TD' + LineFeed + '  A{' + ShapedCaption + '}');

  var Polygon: IDisplayPolygon;
  Assert.IsTrue(FindFirstPolygon(Items, Polygon), 'A diamond node must emit a polygon primitive');
  Assert.AreEqual(4, Polygon.PointCount, 'A diamond polygon must have exactly four points');
end;

procedure TMermaidLayoutTests.Flowchart_PolygonNodeShapes_HaveAVisibleBorder;
begin
  const StadiumItems = ItemsForDiagram('flowchart TD' + LineFeed + '  A([' + ShapedCaption + '])');
  const RoundedItems = ItemsForDiagram('flowchart TD' + LineFeed + '  A(' + ShapedCaption + ')');
  const DiamondItems = ItemsForDiagram('flowchart TD' + LineFeed + '  A{' + ShapedCaption + '}');

  var StadiumPolygon: IDisplayPolygon;
  Assert.IsTrue(FindFirstPolygon(StadiumItems, StadiumPolygon), 'A stadium node must emit a polygon primitive');
  Assert.IsTrue(StadiumPolygon.StrokeWidth > 0, 'A stadium node must have a border, like every other node shape');

  var RoundedPolygon: IDisplayPolygon;
  Assert.IsTrue(FindFirstPolygon(RoundedItems, RoundedPolygon), 'A rounded node must emit a polygon primitive');
  Assert.IsTrue(RoundedPolygon.StrokeWidth > 0, 'A rounded node must have a border, like every other node shape');

  var DiamondPolygon: IDisplayPolygon;
  Assert.IsTrue(FindFirstPolygon(DiamondItems, DiamondPolygon), 'A diamond node must emit a polygon primitive');
  Assert.IsTrue(DiamondPolygon.StrokeWidth > 0, 'A diamond node must have a border, like every other node shape');
end;

procedure TMermaidLayoutTests.Flowchart_CircleNode_BorderMatchesRectangleNodeBorder;
begin
  const RectangleItems = ItemsForDiagram('flowchart TD' + LineFeed + '  A[' + ShapedCaption + ']');
  const CircleItems = ItemsForDiagram('flowchart TD' + LineFeed + '  A((' + ShapedCaption + '))');

  var Rectangle: IDisplayRectangle;
  Assert.IsTrue(FindFirstRectangle(RectangleItems, Rectangle), 'A rectangle node must emit a rectangle primitive');

  var Wedge: IDisplayWedge;
  Assert.IsTrue(FindFirstWedge(CircleItems, Wedge), 'A circle node must emit a wedge primitive');

  Assert.IsTrue(Wedge.StrokeColor = Rectangle.StrokeColor,
    'A circle border must be the same colour as every other node border, not a shade off');
  Assert.AreEqual(Rectangle.StrokeWidth, Wedge.StrokeWidth, 0.001,
    'A circle border must be the same weight as every other node border, not a pixel heavier or lighter');
end;

procedure TMermaidLayoutTests.Flowchart_LabelledEdge_KeepsLineVisibleAroundLabel;
begin
  const Items = ItemsForDiagram('flowchart LR' + LineFeed +
    '  Prompt[Prompt] --> Model{Model}' + LineFeed +
    '  Model -->|tokens| Stream([Stream chunks])' + LineFeed +
    '  Stream --> Render');

  var LabelBounds := Default(TLayoutRectF);
  var HasLabel := False;
  for var Item in Items do
  begin
    var Run: IDisplayTextRun;
    if Supports(Item, IDisplayTextRun, Run) and (Run.Text = 'tokens') then
    begin
      LabelBounds := Item.Bounds;
      HasLabel := True;
    end;
  end;
  Assert.IsTrue(HasLabel, 'The labelled edge must emit its caption');

  const LabelCenterX = (LabelBounds.Left + LabelBounds.Right) / 2;
  const LabelCenterY = (LabelBounds.Top + LabelBounds.Bottom) / 2;

  var HasEdgeLine := False;
  var LineLeft := 0.0;
  var LineRight := 0.0;
  for var Item in Items do
  begin
    var Line: IDisplayLine;
    if not Supports(Item, IDisplayLine, Line) then
      Continue;

    const IsLevel = (Abs(Line.StartPoint.Y - Line.EndPoint.Y) < 0.5);
    const SpansLabel = (Min(Line.StartPoint.X, Line.EndPoint.X) <= LabelCenterX) and
      (Max(Line.StartPoint.X, Line.EndPoint.X) >= LabelCenterX);
    const SitsOnLabelRow = (Abs(Line.StartPoint.Y - LabelCenterY) < 12.0);
    if IsLevel and SpansLabel and SitsOnLabelRow then
    begin
      HasEdgeLine := True;
      LineLeft := Min(Line.StartPoint.X, Line.EndPoint.X);
      LineRight := Max(Line.StartPoint.X, Line.EndPoint.X);
    end;
  end;
  Assert.IsTrue(HasEdgeLine, 'The labelled edge must emit a line under its caption');

  Assert.IsTrue(LabelBounds.Left - LineLeft >= 6.0,
    'The line must stay visible between the source node and the label');
  Assert.IsTrue(LineRight - LabelBounds.Right >= 6.0,
    'The line must stay visible between the label and the arrowhead');
end;

procedure TMermaidLayoutTests.Sequence_EmitsVerticalLifelines;
begin
  const Items = ModelItems('sequence-two-participants');

  var VerticalLines := 0;
  for var Item in Items do
  begin
    var Line: IDisplayLine;
    if Supports(Item, IDisplayLine, Line) and (Abs(Line.StartPoint.X - Line.EndPoint.X) < 0.5) and
      (Abs(Line.StartPoint.Y - Line.EndPoint.Y) > 0.5) then
      Inc(VerticalLines);
  end;

  Assert.IsTrue(VerticalLines >= 2, 'A two-participant sequence diagram must emit a vertical lifeline per participant');
end;

procedure TMermaidLayoutTests.Sequence_EmitsMessageSegments;
begin
  const Items = ModelItems('sequence-two-participants');
  Assert.IsTrue(CountKind(Items, TDisplayItemKind.Line) >= 2, 'A two-message sequence diagram must emit message segments');
end;

procedure TMermaidLayoutTests.Pie_EmitsWedgePerSlice;
begin
  const Items = ModelItems('pie-title-three-slices');
  Assert.AreEqual(3, CountKind(Items, TDisplayItemKind.Wedge), 'A three-slice pie must emit three wedge primitives');
end;

procedure TMermaidLayoutTests.Pie_PercentageLabel_SitsInsideItsOwnSlice;
begin
  const Items = ModelItems('pie-title-three-slices');

  var Wedges: TArray<IDisplayWedge> := nil;
  var Labels: TArray<IDisplayItem> := nil;
  for var Item in Items do
  begin
    var Wedge: IDisplayWedge;
    if Supports(Item, IDisplayWedge, Wedge) then
    begin
      Wedges := Wedges + [Wedge];
      Continue;
    end;

    var Run: IDisplayTextRun;
    if Supports(Item, IDisplayTextRun, Run) and Run.Text.EndsWith('%') then
      Labels := Labels + [Item];
  end;

  Assert.AreEqual(3, TTestArray.CountOf(Wedges), 'A three-slice pie must emit three wedges');
  Assert.AreEqual(3, TTestArray.CountOf(Labels), 'Every slice wide enough to carry a percentage must show one');

  for var Index := 0 to High(Labels) do
  begin
    const Wedge = Wedges[Index];
    const Bounds = Labels[Index].Bounds;
    const CentreX = (Bounds.Left + Bounds.Right) / 2;
    const CentreY = (Bounds.Top + Bounds.Bottom) / 2;

    // The wedge sweeps clockwise from 0 degrees at 3 o'clock, so the label
    // belongs at the same angle measured the same way.
    var Angle := RadToDeg(ArcTan2(CentreY - Wedge.Center.Y, CentreX - Wedge.Center.X));
    if Angle < 0 then
      Angle := Angle + 360;

    const Start = Wedge.StartAngle;
    const Stop = Start + Wedge.SweepAngle;
    const IsInsideSlice = ((Angle >= Start) and (Angle <= Stop)) or
      ((Angle + 360 >= Start) and (Angle + 360 <= Stop));
    Assert.IsTrue(IsInsideSlice,
      Format('Percentage %d sits at %.1f degrees, outside its slice %.1f..%.1f',
        [Index, Angle, Start, Stop]));
  end;
end;

procedure TMermaidLayoutTests.Deterministic_SameInputProducesIdenticalPrimitiveKinds;
begin
  const First = ModelItems('flowchart-simple-chain');
  const Second = ModelItems('flowchart-simple-chain');

  Assert.AreEqual(Length(First), Length(Second), 'Layout must be deterministic in item count');

  for var Index := 0 to High(First) do
  begin
    Assert.AreEqual(Ord(First[Index].Kind), Ord(Second[Index].Kind),
      Format('Layout item %d kind must be deterministic', [Index]));
  end;
end;

procedure TMermaidLayoutTests.ClassDiagram_IssueExample_DrawsABoxPerClass;
begin
  const Items = ModelItems(ShopClassDiagram);

  Assert.AreEqual(4, TTestArray.CountOf(ClassBoxes(Items)), 'A four-class diagram must draw a bordered box per class');
end;

procedure TMermaidLayoutTests.ClassDiagram_IssueExample_BoxesDoNotOverlap;
begin
  AssertNoOverlap(ClassBoxes(ModelItems(ShopClassDiagram)));
end;

procedure TMermaidLayoutTests.ClassDiagram_ManyClasses_BoxesDoNotOverlap;
begin
  const Lines: TArray<string> = [
    'classDiagram',
    '  Animal <|-- Duck',
    '  Animal <|-- Fish',
    '  Animal <|-- Zebra',
    '  Duck : +swim()',
    '  Duck : +quack()',
    '  Fish : -int sizeInFeet',
    '  Zebra : +bool is_wild',
    '  Zoo "1" o-- "*" Animal : houses',
    '  Keeper --> Zoo : works at',
    '  Keeper ..> Animal : feeds',
    '  Zoo *-- Ticket',
    '  Ticket --> Visitor',
    '  Visitor --> Zoo : visits',
    '  Visitor ..|> Person',
    '  Keeper ..|> Person'];

  const Boxes = ClassBoxes(ItemsForDiagram(string.Join(LineFeed, Lines)));

  Assert.AreEqual(9, TTestArray.CountOf(Boxes), 'Every class, also one only named in a relation, must get a box');
  AssertNoOverlap(Boxes);
end;

procedure TMermaidLayoutTests.ClassDiagram_SameInput_ProducesIdenticalLayout;
begin
  const First = ModelItems(ShopClassDiagram);
  const Second = ModelItems(ShopClassDiagram);

  Assert.AreEqual(Length(First), Length(Second), 'Layout must be deterministic in item count');

  for var Index := 0 to High(First) do
  begin
    Assert.AreEqual(Ord(First[Index].Kind), Ord(Second[Index].Kind), Format('Item %d kind', [Index]));
    Assert.AreEqual(First[Index].Bounds.Left, Second[Index].Bounds.Left, 0.001, Format('Item %d left', [Index]));
    Assert.AreEqual(First[Index].Bounds.Top, Second[Index].Bounds.Top, 0.001, Format('Item %d top', [Index]));
    Assert.AreEqual(First[Index].Bounds.Right, Second[Index].Bounds.Right, 0.001, Format('Item %d right', [Index]));
    Assert.AreEqual(First[Index].Bounds.Bottom, Second[Index].Bounds.Bottom, 0.001, Format('Item %d bottom', [Index]));
  end;
end;

procedure TMermaidLayoutTests.ClassDiagram_Association_SourceSitsAboveTarget;
begin
  const Items = ModelItems(ShopClassDiagram);

  const Customer = BoxOfText(Items, 'Customer');
  const Order = BoxOfText(Items, 'Order');
  const LineItem = BoxOfText(Items, 'LineItem');

  Assert.IsTrue(Customer.Bottom <= Order.Top, 'Customer places orders, so Customer sits above Order');
  Assert.IsTrue(Order.Bottom <= LineItem.Top, 'Order is the whole of its line items, so Order sits above LineItem');
end;

procedure TMermaidLayoutTests.ClassDiagram_Inheritance_ParentSitsAboveChild(const Relation: string);
begin
  const Items = ItemsForDiagram('classDiagram' + LineFeed + '  ' + Relation);

  const Animal = BoxOfText(Items, 'Animal');
  const Duck = BoxOfText(Items, 'Duck');

  Assert.IsTrue(Animal.Bottom <= Duck.Top, 'The parent sits above its child whichever way the arrow is written');
end;

procedure TMermaidLayoutTests.ClassDiagram_LeftToRight_ParentSitsLeftOfChild;
begin
  const Items = ItemsForDiagram('classDiagram' + LineFeed + '  direction LR' + LineFeed + '  Duck --|> Animal');

  const Animal = BoxOfText(Items, 'Animal');
  const Duck = BoxOfText(Items, 'Duck');

  Assert.IsTrue(Animal.Right <= Duck.Left, 'Left to right puts the parent on the left');
end;

procedure TMermaidLayoutTests.ClassDiagram_BottomToTop_ParentSitsBelowChild;
begin
  const Items = ItemsForDiagram('classDiagram' + LineFeed + '  direction BT' + LineFeed + '  Animal <|-- Duck');

  const Animal = BoxOfText(Items, 'Animal');
  const Duck = BoxOfText(Items, 'Duck');

  Assert.IsTrue(Animal.Top >= Duck.Bottom, 'Bottom to top puts the parent below its child');
end;

procedure TMermaidLayoutTests.ClassDiagram_Box_HasThreeCompartments;
begin
  const Items = ModelItems(ShopClassDiagram);
  const Customer = BoxOfText(Items, 'Customer');

  var Separators := 0;
  for var Item in Items do
  begin
    var Line: IDisplayLine;
    if not Supports(Item, IDisplayLine, Line) then
      Continue;

    const IsLevel = (Abs(Line.StartPoint.Y - Line.EndPoint.Y) < 0.5);
    const IsInsideBox = (Line.StartPoint.Y > Customer.Top + 0.5) and (Line.StartPoint.Y < Customer.Bottom - 0.5);
    const SpansBox = (Abs(Min(Line.StartPoint.X, Line.EndPoint.X) - Customer.Left) < 0.5) and
      (Abs(Max(Line.StartPoint.X, Line.EndPoint.X) - Customer.Right) < 0.5);
    if IsLevel and IsInsideBox and SpansBox then
      Inc(Separators);
  end;

  Assert.AreEqual(2, Separators,
    'A class box has a name, an attribute and a method compartment, also when it has no methods');
end;

procedure TMermaidLayoutTests.ClassDiagram_Annotation_SitsAboveBoldName;
begin
  const Items = ModelItems(ShopClassDiagram);

  var Annotation: IDisplayTextRun;
  Assert.IsTrue(FindText(Items, '<<interface>>', Annotation), 'The annotation must be drawn');

  var Name: IDisplayTextRun;
  Assert.IsTrue(FindText(Items, 'Payment', Name), 'The class name must be drawn');

  Assert.IsTrue(Annotation.Bounds.Bottom <= Name.Bounds.Top + 0.5, 'The annotation sits above the class name');
  Assert.IsTrue(Name.Font.Bold, 'The class name is bold');

  const Payment = BoxOfText(Items, 'Payment');
  Assert.IsTrue(Payment.Contains(TLayoutPointF.Create(Annotation.Bounds.Left, Annotation.Bounds.Top)),
    'The annotation sits inside the class box');
end;

procedure TMermaidLayoutTests.ClassDiagram_IssueExample_DrawsCardinalitiesAndLabels;
begin
  const Items = ModelItems(ShopClassDiagram);

  var OneCount := 0;
  var ManyCount := 0;
  for var Item in Items do
  begin
    var Run: IDisplayTextRun;
    if not Supports(Item, IDisplayTextRun, Run) then
      Continue;

    if Run.Text = '1' then
      Inc(OneCount)
    else if Run.Text = '*' then
      Inc(ManyCount);
  end;

  Assert.AreEqual(2, OneCount, 'Both relations with a "1" end must draw it');
  Assert.AreEqual(2, ManyCount, 'Both relations with a "*" end must draw it');

  var Run: IDisplayTextRun;
  Assert.IsTrue(FindText(Items, 'places', Run), 'The places label must be drawn');
  Assert.IsTrue(FindText(Items, 'contains', Run), 'The contains label must be drawn');
  Assert.IsTrue(FindText(Items, 'settled by', Run), 'The settled by label must be drawn');
end;

procedure TMermaidLayoutTests.ClassDiagram_Composition_DrawsFilledDiamondAtWhole;
begin
  const Items = ItemsForDiagram('classDiagram' + LineFeed + '  Order *-- LineItem');

  const Diamonds = Polygons(Items, 4);
  Assert.AreEqual(1, TTestArray.CountOf(Diamonds), 'A composition draws one diamond');
  Assert.IsTrue(Diamonds[0].FillColor = FTheme.ChartTextColor, 'A composition diamond is filled');

  const Order = BoxOfText(Items, 'Order');
  var TouchesWhole := False;
  for var Index := 0 to Diamonds[0].PointCount - 1 do
  begin
    if Abs(Diamonds[0].Points[Index].Y - Order.Bottom) < 1.0 then
      TouchesWhole := True;
  end;
  Assert.IsTrue(TouchesWhole, 'The diamond sits at the whole, the class written next to it');
end;

procedure TMermaidLayoutTests.ClassDiagram_Aggregation_DrawsHollowDiamond;
begin
  const Items = ItemsForDiagram('classDiagram' + LineFeed + '  Zoo o-- Animal');

  const Diamonds = Polygons(Items, 4);
  Assert.AreEqual(1, TTestArray.CountOf(Diamonds), 'An aggregation draws one diamond');
  Assert.IsTrue(Diamonds[0].FillColor = FTheme.BackgroundColor, 'An aggregation diamond is hollow');
  Assert.IsTrue(Diamonds[0].StrokeWidth > 0, 'A hollow diamond needs an outline');
end;

procedure TMermaidLayoutTests.ClassDiagram_Inheritance_DrawsHollowTriangleAtParent;
begin
  const Items = ItemsForDiagram('classDiagram' + LineFeed + '  Animal <|-- Duck');

  const Triangles = Polygons(Items, 3);
  Assert.AreEqual(1, TTestArray.CountOf(Triangles), 'An inheritance draws one triangle');
  Assert.IsTrue(Triangles[0].FillColor = FTheme.BackgroundColor, 'An inheritance triangle is hollow');
  Assert.IsTrue(Triangles[0].StrokeWidth > 0, 'A hollow triangle needs an outline');

  const Animal = BoxOfText(Items, 'Animal');
  var TipY := MaxSingle;
  for var Index := 0 to Triangles[0].PointCount - 1 do
  begin
    TipY := Min(TipY, Triangles[0].Points[Index].Y);
  end;
  Assert.AreEqual(Animal.Bottom, TipY, 1.0, 'The triangle points at the parent');
end;

procedure TMermaidLayoutTests.ClassDiagram_Association_DrawsOpenArrowAtTarget;
begin
  const Items = ItemsForDiagram('classDiagram' + LineFeed + '  Customer --> Order');

  Assert.AreEqual(0, TTestArray.CountOf(Polygons(Items, 3)), 'An association arrow is open, not a filled triangle');

  const Order = BoxOfText(Items, 'Order');
  const Tip = TLayoutPointF.Create((Order.Left + Order.Right) / 2, Order.Top);

  var LinesAtTip := 0;
  for var Item in Items do
  begin
    var Line: IDisplayLine;
    if not Supports(Item, IDisplayLine, Line) then
      Continue;

    const StartsAtTip = (Abs(Line.StartPoint.X - Tip.X) < 1.0) and (Abs(Line.StartPoint.Y - Tip.Y) < 1.0);
    const EndsAtTip = (Abs(Line.EndPoint.X - Tip.X) < 1.0) and (Abs(Line.EndPoint.Y - Tip.Y) < 1.0);
    if StartsAtTip or EndsAtTip then
      Inc(LinesAtTip);
  end;

  Assert.AreEqual(3, LinesAtTip, 'The relation line and the two strokes of the open arrow meet at the target');
end;

procedure TMermaidLayoutTests.ClassDiagram_DashedRelation_DrawsDashes;
begin
  const SolidLines = CountKind(ItemsForDiagram('classDiagram' + LineFeed + '  Client --> Service'),
    TDisplayItemKind.Line);
  const DashedLines = CountKind(ItemsForDiagram('classDiagram' + LineFeed + '  Client ..> Service'),
    TDisplayItemKind.Line);

  Assert.IsTrue(DashedLines > SolidLines + 1, 'A dependency is drawn as a run of dashes, not one line');
end;

procedure TMermaidLayoutTests.ClassDiagram_StaticAndAbstractMembers_UseUnderlineAndItalic;
begin
  const Items = ItemsForDiagram('classDiagram' + LineFeed + '  class Shape {' + LineFeed + '    +count()$ int' +
    LineFeed + '    +draw()*' + LineFeed + '  }');

  var StaticMember: IDisplayTextRun;
  Assert.IsTrue(FindText(Items, '+count() : int', StaticMember), 'The static method must be drawn');
  Assert.IsTrue(StaticMember.Font.Underline, 'A static member is underlined');

  var AbstractMember: IDisplayTextRun;
  Assert.IsTrue(FindText(Items, '+draw()', AbstractMember), 'The abstract method must be drawn');
  Assert.IsTrue(AbstractMember.Font.Italic, 'An abstract member is italic');
end;

procedure TMermaidLayoutTests.ClassDiagram_PreferredHeight_CoversEveryBox;
begin
  const Item = FCorpus.FindCase(ShopClassDiagram);
  const Document = MermaidPipeline.Parse(Item.Markdown);

  var Code: IMarkdownCodeBlock;
  Assert.IsTrue(TMarkdownTestPipelineHelpers.FindFirstCodeBlock(Document, Code));

  var Model: IMermaidModel;
  Assert.IsTrue(TMermaidExtension.TryParse(Code, Model));

  const Height = TMermaidLayouter.PreferredHeight(Model, DiagramWidth, FTheme, FMeasurer);
  const Bounds = TLayoutRectF.Create(0, 0, DiagramWidth, Height);
  const Items = TMermaidLayouter.BuildDisplayItems(Model, Bounds, FTheme, FMeasurer, Code);

  for var Box in ClassBoxes(Items) do
  begin
    Assert.IsTrue(Box.Bottom <= Height, 'The preferred height must leave room for every class box');
  end;
end;

procedure TMermaidLayoutTests.ClassDiagram_SelfRelation_DrawsLoopBesideBox;
begin
  const Items = ItemsForDiagram('classDiagram' + LineFeed + '  Node --> Node : next');

  const Node = BoxOfText(Items, 'Node');

  var HasLoop := False;
  for var Item in Items do
  begin
    var Line: IDisplayLine;
    if Supports(Item, IDisplayLine, Line) and (Min(Line.StartPoint.X, Line.EndPoint.X) > Node.Right - 0.5) then
      HasLoop := True;
  end;

  Assert.IsTrue(HasLoop, 'A class related to itself gets a loop beside its box');

  var Run: IDisplayTextRun;
  Assert.IsTrue(FindText(Items, 'next', Run), 'The loop carries its label');
end;

end.
