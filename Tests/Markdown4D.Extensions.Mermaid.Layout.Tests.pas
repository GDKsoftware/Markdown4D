unit Markdown4D.Extensions.Mermaid.Layout.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Mermaid.Corpus;

type
  [TestFixture]
  TMermaidLayoutTests = class
  private
    const
      DiagramWidth = 480.0;
      DiagramHeight = 360.0;
      ShapedCaption = 'Stage One Two Three';
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FCorpus: TMermaidCorpus;
    function ModelItems(const CaseName: string): TArray<IDisplayItem>;
    function ItemsForDiagram(const Diagram: string): TArray<IDisplayItem>;

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
    procedure Flowchart_Cycle_ProducesItemsWithoutHanging;

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
    procedure Sequence_EmitsVerticalLifelines;

    [Test]
    procedure Sequence_EmitsMessageSegments;

    [Test]
    procedure Pie_EmitsWedgePerSlice;

    [Test]
    procedure Deterministic_SameInputProducesIdenticalPrimitiveKinds;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Pipeline,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Extensions.Mermaid,
  Markdown4D.Extensions.Mermaid.Layout;

function MermaidPipeline: IMarkdownPipeline;
begin
  Result := TMarkdownPipeline.Create.UseGfm.Use(TMermaidExtension.Create).UnsafeHtml.Build;
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

function CountKind(const Items: TArray<IDisplayItem>; const Kind: TDisplayItemKind): Integer;
begin
  Result := 0;

  for var Item in Items do
  begin
    if Item.Kind = Kind then
      Inc(Result);
  end;
end;

function RectanglesOverlap(const A, B: TLayoutRectF): Boolean;
begin
  Result := (A.Left < B.Right) and (B.Left < A.Right) and (A.Top < B.Bottom) and (B.Top < A.Bottom);
end;

function FindFirstPolygon(const Items: TArray<IDisplayItem>; out Polygon: IDisplayPolygon): Boolean;
begin
  Polygon := nil;

  for var Item in Items do
  begin
    if Supports(Item, IDisplayPolygon, Polygon) then
      Exit(True);
  end;

  Result := False;
end;

function FindFirstRectangle(const Items: TArray<IDisplayItem>; out Rectangle: IDisplayRectangle): Boolean;
begin
  Rectangle := nil;

  for var Item in Items do
  begin
    if Supports(Item, IDisplayRectangle, Rectangle) then
      Exit(True);
  end;

  Result := False;
end;

function FindFirstWedge(const Items: TArray<IDisplayItem>; out Wedge: IDisplayWedge): Boolean;
begin
  Wedge := nil;

  for var Item in Items do
  begin
    if Supports(Item, IDisplayWedge, Wedge) then
      Exit(True);
  end;

  Result := False;
end;

function FirstNodeShapeWidth(const Items: TArray<IDisplayItem>): Single;
begin
  for var Item in Items do
  begin
    if (Item.Kind = TDisplayItemKind.Rectangle) or (Item.Kind = TDisplayItemKind.Polygon) then
      Exit(Item.Bounds.Width);
  end;

  Result := 0;
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
  Assert.IsTrue(FindFirstCodeBlock(Document, Code), Format('Case "%s" must expose a code block', [CaseName]));

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
  Assert.IsTrue(FindFirstCodeBlock(Document, Code), 'Diagram must expose a code block');

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

procedure TMermaidLayoutTests.Flowchart_Cycle_ProducesItemsWithoutHanging;
begin
  const Items = ModelItems('flowchart-cycle');
  Assert.IsTrue(Length(Items) > 0, 'A cyclic flowchart must fall back to a grid layout and still emit items');
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

end.
