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
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FCorpus: TMermaidCorpus;
    function ModelItems(const CaseName: string): TArray<IDisplayItem>;

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
    procedure Flowchart_TopDown_SourceRanksAboveTarget;

    [Test]
    procedure Flowchart_Cycle_ProducesItemsWithoutHanging;

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
