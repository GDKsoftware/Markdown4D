unit Markdown4D.Extensions.Mermaid.ClassDiagram.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Mermaid.Corpus,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Extensions.Mermaid;

type
  [TestFixture]
  TMermaidClassDiagramTests = class
  private
    const
      IssueExampleCase = 'class-diagram-shop';
    var
      FCorpus: TMermaidCorpus;
    function IssueExample: IMermaidClassDiagram;
    class function MermaidPipeline: IMarkdownPipeline;
    class function TryParseMarkdown(const Markdown: string; out Diagram: IMermaidClassDiagram): Boolean;
    class function TryParseDiagram(const Source: string; out Diagram: IMermaidClassDiagram): Boolean;
    class function ParseDiagram(const Source: string): IMermaidClassDiagram;
    class function FindClass(const Diagram: IMermaidClassDiagram; const Id: string): IMermaidClass;
    class function ClassIndex(const Diagram: IMermaidClassDiagram; const Id: string): Integer;

  public
    [SetupFixture]
    procedure SetupFixture;

    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure Parse_IssueExample_IsClassDiagramModel;

    [Test]
    procedure Parse_IssueExample_HasFourClassesInDeclarationOrder;

    [Test]
    procedure Parse_IssueExample_SplitsMembersIntoAttributesAndMethods;

    [Test]
    procedure Parse_IssueExample_ReadsAnnotationInsideClassBlock;

    [Test]
    procedure Parse_IssueExample_HasThreeRelationsWithCardinalitiesAndLabels;

    [Test]
    [TestCase('Inheritance', '<|--,1,0,0')]
    [TestCase('InheritanceReversed', '--|>,0,1,0')]
    [TestCase('Composition', '*--,2,0,0')]
    [TestCase('CompositionReversed', '--*,0,2,0')]
    [TestCase('Aggregation', 'o--,3,0,0')]
    [TestCase('AggregationReversed', '--o,0,3,0')]
    [TestCase('Association', '-->,0,4,0')]
    [TestCase('AssociationReversed', '<--,4,0,0')]
    [TestCase('Link', '--,0,0,0')]
    [TestCase('Dependency', '..>,0,4,1')]
    [TestCase('DependencyReversed', '<..,4,0,1')]
    [TestCase('Realization', '..|>,0,1,1')]
    [TestCase('RealizationReversed', '<|..,1,0,1')]
    [TestCase('DashedLink', '..,0,0,1')]
    [TestCase('TwoWayInheritance', '<|--|>,1,1,0')]
    [TestCase('TwoWayAssociation', '<-->,4,4,0')]
    procedure Parse_RelationArrow_ResolvesEndsAndLine(const Arrow: string; const SourceEnd, TargetEnd, Line: Integer);

    [Test]
    procedure Parse_RelationWithoutSpaces_ResolvesBothClasses;

    [Test]
    procedure Parse_RelationOnly_CreatesClassesImplicitly;

    [Test]
    procedure Parse_GenericClass_CaptionUsesAngleBrackets;

    [Test]
    [TestCase('Simple', 'List~int~ position,List<int> position')]
    [TestCase('Nested', 'List~List~int~~ grid,List<List<int>> grid')]
    [TestCase('Parameter', 'setPoints(List~int~ points),setPoints(List<int> points)')]
    [TestCase('Unbalanced', 'odd~value,odd~value')]
    procedure Parse_GenericMember_UsesAngleBrackets(const Member, Expected: string);

    [Test]
    procedure Parse_OneLineMembers_AddToClass;

    [Test]
    [TestCase('Public', '+String name,1')]
    [TestCase('Private', '-String name,2')]
    [TestCase('Protected', '#String name,3')]
    [TestCase('Package', '~String name,4')]
    [TestCase('None', 'String name,0')]
    procedure Parse_MemberVisibility_IsRecognised(const Member: string; const Expected: Integer);

    [Test]
    [TestCase('StaticMethod', 'count()$,count(),,1')]
    [TestCase('AbstractMethod', 'draw()*,draw(),,2')]
    [TestCase('AbstractMethodWithReturnType', 'area() double*,area(),double,2')]
    [TestCase('StaticMethodBeforeReturnType', 'count()$ int,count(),int,1')]
    [TestCase('StaticAttribute', 'String id$,String id,,1')]
    [TestCase('ReturnTypeWithColon', 'total() : Money,total(),Money,0')]
    procedure Parse_MemberClassifier_IsRecognised(const Member, Signature, ReturnType: string; const Expected: Integer);

    [Test]
    procedure Parse_AnnotationStatement_AppliesToClass;

    [Test]
    procedure Parse_ClassLabel_BecomesCaption;

    [Test]
    procedure Parse_SingleLineClassBlock_AddsMember;

    [Test]
    [TestCase('TopToBottom', 'TB,0')]
    [TestCase('TopDown', 'TD,1')]
    [TestCase('LeftToRight', 'LR,2')]
    [TestCase('BottomToTop', 'BT,3')]
    [TestCase('RightToLeft', 'RL,4')]
    procedure Parse_Direction_IsApplied(const Value: string; const Expected: Integer);

    [Test]
    procedure Parse_NoDirection_DefaultsToTopToBottom;

    [Test]
    procedure Parse_Comments_AreIgnored;

    [Test]
    procedure Parse_StylingInteractionAndAccessibility_AreIgnored;

    [Test]
    procedure Parse_VersionTwoHeader_IsAccepted;

    [Test]
    procedure Parse_BacktickClassName_KeepsSpaces;

    [Test]
    [TestCase('UnclosedBlock', 'class A {|  +int x')]
    [TestCase('StrayClosingBrace', '}')]
    [TestCase('UnknownArrow', 'A ~~ B')]
    [TestCase('MissingTarget', 'A -->')]
    [TestCase('Lollipop', 'A ()-- B')]
    [TestCase('Note', 'note for A "a note"')]
    [TestCase('Namespace', 'namespace Shapes {|  class A|}')]
    [TestCase('UnterminatedCardinality', 'A "1 --> B')]
    [TestCase('TrailingGarbage', 'A --> B C')]
    [TestCase('EmptyMember', 'A :')]
    [TestCase('BadDirection', 'direction XY')]
    [TestCase('Garbage', '!!! nonsense')]
    procedure Parse_InvalidBody_FallsBack(const Body: string);

    [Test]
    procedure Parse_HeaderWithTrailingText_FallsBack;

    [Test]
    procedure Parse_TooManyClasses_FallsBack;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Pipeline,
  Markdown4D.Tests.Pipeline.Helpers;

const
  Header = 'classDiagram';
  BodyLineSeparator = '|';

class function TMermaidClassDiagramTests.MermaidPipeline: IMarkdownPipeline;
begin
  Result := TMarkdownPipeline.Create.UseGfm.Use(TMermaidExtension.Create).UnsafeHtml.Build;
end;

procedure TMermaidClassDiagramTests.SetupFixture;
begin
  FCorpus := TMermaidCorpus.Create;
end;

procedure TMermaidClassDiagramTests.TearDownFixture;
begin
  FreeAndNil(FCorpus);
end;

function TMermaidClassDiagramTests.IssueExample: IMermaidClassDiagram;
begin
  const Item = FCorpus.FindCase(IssueExampleCase);
  Assert.IsTrue(TryParseMarkdown(Item.Markdown, Result), 'The class diagram from the issue must parse into a model');
end;

class function TMermaidClassDiagramTests.TryParseMarkdown(const Markdown: string;
  out Diagram: IMermaidClassDiagram): Boolean;
begin
  Diagram := nil;

  const Document = MermaidPipeline.Parse(Markdown);

  var Code: IMarkdownCodeBlock;
  Assert.IsTrue(TMarkdownTestPipelineHelpers.FindFirstCodeBlock(Document, Code), 'The fence must parse as a code block');

  var Model: IMermaidModel;
  Result := TMermaidExtension.TryParse(Code, Model) and Supports(Model, IMermaidClassDiagram, Diagram);
end;

class function TMermaidClassDiagramTests.TryParseDiagram(const Source: string;
  out Diagram: IMermaidClassDiagram): Boolean;
begin
  const Markdown = Format('```mermaid%s%s%s```%s', [LineFeed, Source, LineFeed, LineFeed]);
  Result := TryParseMarkdown(Markdown, Diagram);
end;

class function TMermaidClassDiagramTests.ParseDiagram(const Source: string): IMermaidClassDiagram;
begin
  Assert.IsTrue(TryParseDiagram(Source, Result), 'The class diagram must parse into a model');
end;

class function TMermaidClassDiagramTests.ClassIndex(const Diagram: IMermaidClassDiagram; const Id: string): Integer;
begin
  for var Index := 0 to Diagram.ClassCount - 1 do
  begin
    if Diagram.Classes[Index].Id = Id then
    begin
      Result := Index;
      Exit;
    end;
  end;

  Result := -1;
end;

class function TMermaidClassDiagramTests.FindClass(const Diagram: IMermaidClassDiagram; const Id: string): IMermaidClass;
begin
  const Index = ClassIndex(Diagram, Id);
  Assert.IsTrue(Index >= 0, Format('The diagram must contain class "%s"', [Id]));

  Result := Diagram.Classes[Index];
end;

procedure TMermaidClassDiagramTests.Parse_IssueExample_IsClassDiagramModel;
begin
  const Item = FCorpus.FindCase(IssueExampleCase);
  const Document = MermaidPipeline.Parse(Item.Markdown);

  var Code: IMarkdownCodeBlock;
  Assert.IsTrue(TMarkdownTestPipelineHelpers.FindFirstCodeBlock(Document, Code));

  var Model: IMermaidModel;
  Assert.IsTrue(TMermaidExtension.TryGetModel(Code, Model), 'A closed classDiagram fence must expose a mermaid model');
  Assert.AreEqual(Ord(TMermaidDiagramKind.ClassDiagram), Ord(Model.DiagramKind));
end;

procedure TMermaidClassDiagramTests.Parse_IssueExample_HasFourClassesInDeclarationOrder;
begin
  const Diagram = IssueExample;

  Assert.AreEqual(4, Diagram.ClassCount);
  Assert.AreEqual('Customer', Diagram.Classes[0].Id);
  Assert.AreEqual('Order', Diagram.Classes[1].Id);
  Assert.AreEqual('LineItem', Diagram.Classes[2].Id);
  Assert.AreEqual('Payment', Diagram.Classes[3].Id);
  Assert.AreEqual('Customer', Diagram.Classes[0].Caption);
end;

procedure TMermaidClassDiagramTests.Parse_IssueExample_SplitsMembersIntoAttributesAndMethods;
begin
  const Diagram = IssueExample;

  const Customer = FindClass(Diagram, 'Customer');
  Assert.AreEqual(2, Customer.AttributeCount);
  Assert.AreEqual(0, Customer.MethodCount);
  Assert.AreEqual('+String name', Customer.Attributes[0].DisplayText);
  Assert.AreEqual('+String email', Customer.Attributes[1].DisplayText);

  const Order = FindClass(Diagram, 'Order');
  Assert.AreEqual(2, Order.AttributeCount);
  Assert.AreEqual(1, Order.MethodCount);
  Assert.AreEqual('+Date placedAt', Order.Attributes[1].DisplayText);
  Assert.AreEqual('total()', Order.Methods[0].Signature);
  Assert.AreEqual('Money', Order.Methods[0].ReturnType);
  Assert.AreEqual('+total() : Money', Order.Methods[0].DisplayText);

  const LineItem = FindClass(Diagram, 'LineItem');
  Assert.AreEqual(1, LineItem.AttributeCount);
  Assert.AreEqual(0, LineItem.MethodCount);

  const Payment = FindClass(Diagram, 'Payment');
  Assert.AreEqual(0, Payment.AttributeCount);
  Assert.AreEqual(1, Payment.MethodCount);
  Assert.AreEqual('+authorise() : bool', Payment.Methods[0].DisplayText);
end;

procedure TMermaidClassDiagramTests.Parse_IssueExample_ReadsAnnotationInsideClassBlock;
begin
  const Diagram = IssueExample;

  Assert.AreEqual('interface', FindClass(Diagram, 'Payment').Annotation);
  Assert.AreEqual('', FindClass(Diagram, 'Order').Annotation);
end;

procedure TMermaidClassDiagramTests.Parse_IssueExample_HasThreeRelationsWithCardinalitiesAndLabels;
begin
  const Diagram = IssueExample;
  const Customer = ClassIndex(Diagram, 'Customer');
  const Order = ClassIndex(Diagram, 'Order');
  const LineItem = ClassIndex(Diagram, 'LineItem');
  const Payment = ClassIndex(Diagram, 'Payment');

  Assert.AreEqual(3, Diagram.RelationCount);

  const Places = Diagram.Relations[0];
  Assert.AreEqual(Customer, Places.SourceIndex);
  Assert.AreEqual(Order, Places.TargetIndex);
  Assert.AreEqual(Ord(TMermaidRelationEnd.None), Ord(Places.SourceEnd));
  Assert.AreEqual(Ord(TMermaidRelationEnd.Arrow), Ord(Places.TargetEnd));
  Assert.AreEqual(Ord(TMermaidRelationLine.Solid), Ord(Places.Line));
  Assert.AreEqual('1', Places.SourceCardinality);
  Assert.AreEqual('*', Places.TargetCardinality);
  Assert.AreEqual('places', Places.Caption);

  const Contains = Diagram.Relations[1];
  Assert.AreEqual(Order, Contains.SourceIndex);
  Assert.AreEqual(LineItem, Contains.TargetIndex);
  Assert.AreEqual(Ord(TMermaidRelationEnd.Composition), Ord(Contains.SourceEnd));
  Assert.AreEqual(Ord(TMermaidRelationEnd.None), Ord(Contains.TargetEnd));
  Assert.AreEqual('1', Contains.SourceCardinality);
  Assert.AreEqual('*', Contains.TargetCardinality);
  Assert.AreEqual('contains', Contains.Caption);

  const SettledBy = Diagram.Relations[2];
  Assert.AreEqual(Order, SettledBy.SourceIndex);
  Assert.AreEqual(Payment, SettledBy.TargetIndex);
  Assert.AreEqual(Ord(TMermaidRelationEnd.Arrow), Ord(SettledBy.TargetEnd));
  Assert.AreEqual('', SettledBy.SourceCardinality);
  Assert.AreEqual('', SettledBy.TargetCardinality);
  Assert.AreEqual('settled by', SettledBy.Caption);
end;

procedure TMermaidClassDiagramTests.Parse_RelationArrow_ResolvesEndsAndLine(const Arrow: string;
  const SourceEnd, TargetEnd, Line: Integer);
begin
  const Diagram = ParseDiagram(Format('%s%s  Animal %s Duck', [Header, LineFeed, Arrow]));

  Assert.AreEqual(2, Diagram.ClassCount);
  Assert.AreEqual(1, Diagram.RelationCount);

  const Relation = Diagram.Relations[0];
  Assert.AreEqual(0, Relation.SourceIndex, 'The class left of the arrow is the source');
  Assert.AreEqual(1, Relation.TargetIndex, 'The class right of the arrow is the target');
  Assert.AreEqual(SourceEnd, Integer(Ord(Relation.SourceEnd)), 'Source end');
  Assert.AreEqual(TargetEnd, Integer(Ord(Relation.TargetEnd)), 'Target end');
  Assert.AreEqual(Line, Integer(Ord(Relation.Line)), 'Line style');
end;

procedure TMermaidClassDiagramTests.Parse_RelationWithoutSpaces_ResolvesBothClasses;
begin
  const Diagram = ParseDiagram(Format('%s%s  Animal<|--Duck', [Header, LineFeed]));

  Assert.AreEqual(2, Diagram.ClassCount);
  Assert.AreEqual('Animal', Diagram.Classes[0].Id);
  Assert.AreEqual('Duck', Diagram.Classes[1].Id);
  Assert.AreEqual(Ord(TMermaidRelationEnd.Inheritance), Ord(Diagram.Relations[0].SourceEnd));
end;

procedure TMermaidClassDiagramTests.Parse_RelationOnly_CreatesClassesImplicitly;
begin
  const Diagram = ParseDiagram(Format('%s%s  Animal <|-- Duck%s  Animal <|-- Fish', [Header, LineFeed, LineFeed]));

  Assert.AreEqual(3, Diagram.ClassCount);
  Assert.AreEqual(2, Diagram.RelationCount);
  Assert.AreEqual('Fish', Diagram.Classes[2].Caption);
  Assert.AreEqual(0, Diagram.Classes[2].AttributeCount);
  Assert.AreEqual(0, Diagram.Classes[2].MethodCount);
end;

procedure TMermaidClassDiagramTests.Parse_GenericClass_CaptionUsesAngleBrackets;
begin
  const Lines: TArray<string> = [
    Header,
    '  class Square~Shape~ {',
    '    int id',
    '  }',
    '  Square <|-- Tile'];

  const Diagram = ParseDiagram(string.Join(LineFeed, Lines));

  Assert.AreEqual(2, Diagram.ClassCount, 'A relation must find the generic class by its plain name');
  Assert.AreEqual('Square', Diagram.Classes[0].Id);
  Assert.AreEqual('Square<Shape>', Diagram.Classes[0].Caption);
end;

procedure TMermaidClassDiagramTests.Parse_GenericMember_UsesAngleBrackets(const Member, Expected: string);
begin
  const Diagram = ParseDiagram(Format('%s%s  Grid : %s', [Header, LineFeed, Member]));

  const Grid = FindClass(Diagram, 'Grid');
  var Actual := '';
  if Grid.AttributeCount > 0 then
    Actual := Grid.Attributes[0].DisplayText
  else if Grid.MethodCount > 0 then
    Actual := Grid.Methods[0].DisplayText;

  Assert.AreEqual(Expected, Actual);
end;

procedure TMermaidClassDiagramTests.Parse_OneLineMembers_AddToClass;
begin
  const Lines: TArray<string> = [
    Header,
    '  BankAccount : +String owner',
    '  BankAccount : +BigDecimal balance',
    '  BankAccount : +deposit(amount) bool',
    '  BankAccount : +withdrawal(amount) int'];

  const Diagram = ParseDiagram(string.Join(LineFeed, Lines));

  Assert.AreEqual(1, Diagram.ClassCount);
  const Account = Diagram.Classes[0];
  Assert.AreEqual(2, Account.AttributeCount);
  Assert.AreEqual(2, Account.MethodCount);
  Assert.AreEqual('+BigDecimal balance', Account.Attributes[1].DisplayText);
  Assert.AreEqual('+deposit(amount) : bool', Account.Methods[0].DisplayText);
end;

procedure TMermaidClassDiagramTests.Parse_MemberVisibility_IsRecognised(const Member: string; const Expected: Integer);
begin
  const Diagram = ParseDiagram(Format('%s%s  Person : %s', [Header, LineFeed, Member]));

  const Attribute = Diagram.Classes[0].Attributes[0];
  Assert.AreEqual(Expected, Integer(Ord(Attribute.Visibility)));
  Assert.AreEqual('String name', Attribute.Signature, 'The visibility marker is not part of the signature');
  Assert.AreEqual(Member, Attribute.DisplayText, 'The display text keeps the marker as written');
end;

procedure TMermaidClassDiagramTests.Parse_MemberClassifier_IsRecognised(const Member, Signature, ReturnType: string;
  const Expected: Integer);
begin
  const Diagram = ParseDiagram(Format('%s%s  Shape : %s', [Header, LineFeed, Member]));

  const Shape = Diagram.Classes[0];
  Assert.AreEqual(1, Shape.AttributeCount + Shape.MethodCount);

  var Parsed: IMermaidClassMember;
  if Shape.MethodCount > 0 then
    Parsed := Shape.Methods[0]
  else
    Parsed := Shape.Attributes[0];

  Assert.AreEqual(Expected, Integer(Ord(Parsed.Classifier)), 'Classifier');
  Assert.AreEqual(Signature, Parsed.Signature, 'Signature');
  Assert.AreEqual(ReturnType, Parsed.ReturnType, 'Return type');
end;

procedure TMermaidClassDiagramTests.Parse_AnnotationStatement_AppliesToClass;
begin
  const Lines: TArray<string> = [
    Header,
    '  <<Interface>> Shape',
    '  Shape <|.. Circle'];

  const Diagram = ParseDiagram(string.Join(LineFeed, Lines));

  Assert.AreEqual(2, Diagram.ClassCount);
  Assert.AreEqual('Interface', FindClass(Diagram, 'Shape').Annotation);
  Assert.AreEqual('', FindClass(Diagram, 'Circle').Annotation);
end;

procedure TMermaidClassDiagramTests.Parse_ClassLabel_BecomesCaption;
begin
  const Diagram = ParseDiagram(Format('%s%s  class Account["Bank account"]%s  Account --> Ledger',
    [Header, LineFeed, LineFeed]));

  Assert.AreEqual('Account', Diagram.Classes[0].Id);
  Assert.AreEqual('Bank account', Diagram.Classes[0].Caption);
  Assert.AreEqual(1, Diagram.RelationCount);
end;

procedure TMermaidClassDiagramTests.Parse_SingleLineClassBlock_AddsMember;
begin
  const Diagram = ParseDiagram(Format('%s%s  class Point { +int x }%s  Point --> Line', [Header, LineFeed, LineFeed]));

  Assert.AreEqual(2, Diagram.ClassCount);
  Assert.AreEqual(1, Diagram.Classes[0].AttributeCount);
  Assert.AreEqual('+int x', Diagram.Classes[0].Attributes[0].DisplayText);
end;

procedure TMermaidClassDiagramTests.Parse_Direction_IsApplied(const Value: string; const Expected: Integer);
begin
  const Diagram = ParseDiagram(Format('%s%s  direction %s%s  A --> B', [Header, LineFeed, Value, LineFeed]));

  Assert.AreEqual(Expected, Integer(Ord(Diagram.Direction)));
end;

procedure TMermaidClassDiagramTests.Parse_NoDirection_DefaultsToTopToBottom;
begin
  const Diagram = IssueExample;

  Assert.AreEqual(Ord(TMermaidDirection.TB), Ord(Diagram.Direction));
end;

procedure TMermaidClassDiagramTests.Parse_Comments_AreIgnored;
begin
  const Lines: TArray<string> = [
    Header,
    '  %% the model of a shop',
    '  class Shop {',
    '    %% a comment inside the block',
    '    +String name',
    '  }',
    '%%Shop --> Ghost'];

  const Diagram = ParseDiagram(string.Join(LineFeed, Lines));

  Assert.AreEqual(1, Diagram.ClassCount);
  Assert.AreEqual(1, Diagram.Classes[0].AttributeCount);
  Assert.AreEqual(0, Diagram.RelationCount);
end;

procedure TMermaidClassDiagramTests.Parse_StylingInteractionAndAccessibility_AreIgnored;
begin
  const Lines: TArray<string> = [
    Header,
    '  class Shop:::highlighted',
    '  Shop --> Order',
    '  style Shop fill:#f9f,stroke:#333',
    '  classDef highlighted fill:#ff0',
    '  cssClass "Order" highlighted',
    '  click Shop href "https://example.com"',
    '  callback Order "showOrder"',
    '  link Order "https://example.com"',
    '  accTitle: Shop model',
    '  accDescr: Shops and their orders'];

  const Diagram = ParseDiagram(string.Join(LineFeed, Lines));

  Assert.AreEqual(2, Diagram.ClassCount);
  Assert.AreEqual(1, Diagram.RelationCount);
end;

procedure TMermaidClassDiagramTests.Parse_VersionTwoHeader_IsAccepted;
begin
  const Diagram = ParseDiagram(Format('classDiagram-v2%s  A <|-- B', [LineFeed]));

  Assert.AreEqual(2, Diagram.ClassCount);
end;

procedure TMermaidClassDiagramTests.Parse_BacktickClassName_KeepsSpaces;
begin
  const Diagram = ParseDiagram(Format('%s%s  `Animal Class` <|-- Duck', [Header, LineFeed]));

  Assert.AreEqual('Animal Class', Diagram.Classes[0].Id);
  Assert.AreEqual('Animal Class', Diagram.Classes[0].Caption);
end;

procedure TMermaidClassDiagramTests.Parse_InvalidBody_FallsBack(const Body: string);
begin
  const Source = Format('%s%s%s', [Header, LineFeed, Body.Replace(BodyLineSeparator, LineFeed)]);

  var Diagram: IMermaidClassDiagram;
  Assert.IsFalse(TryParseDiagram(Source, Diagram), 'A body the parser does not understand must not produce a model');
end;

procedure TMermaidClassDiagramTests.Parse_HeaderWithTrailingText_FallsBack;
begin
  var Diagram: IMermaidClassDiagram;
  Assert.IsFalse(TryParseDiagram(Format('classDiagram TB%s  A --> B', [LineFeed]), Diagram));
end;

procedure TMermaidClassDiagramTests.Parse_TooManyClasses_FallsBack;
begin
  var Lines: TArray<string> := [Header];
  for var Index := 0 to TMermaidExtension.MaxNodeCount do
  begin
    Lines := Lines + [Format('  C%d --> C%d', [Index, Index + 1])];
  end;

  var Diagram: IMermaidClassDiagram;
  Assert.IsFalse(TryParseDiagram(string.Join(LineFeed, Lines), Diagram),
    'A class diagram above the node ceiling must fall back like an oversized flowchart');
end;

end.
