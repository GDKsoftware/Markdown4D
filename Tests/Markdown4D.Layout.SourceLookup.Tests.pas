unit Markdown4D.Layout.SourceLookup.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Parser.SourceMap;

type
  [TestFixture]
  TMarkdownSourceLookupTests = class
  public
    [Test]
    procedure TryMapCharacter_TextMatchingItsSource_ReturnsTheCharacterOffset;

    [Test]
    procedure TryMapCharacter_RunPartWayThroughTheNode_AddsTheRunOffset;

    [Test]
    procedure TryMapCharacter_RenderedTextShorterThanItsSource_Refuses;

    [Test]
    procedure TryMapCharacter_NodeWithoutASegment_Refuses;

    [Test]
    procedure TryMapCharacter_OffsetOutsideTheNode_Refuses;
  end;

implementation

procedure TMarkdownSourceLookupTests.TryMapCharacter_TextMatchingItsSource_ReturnsTheCharacterOffset;
begin
  // 'Hello' living at source characters 11 to 15.
  const Segment = TMarkdownSegment.Create(11, 16);

  var Offset := 0;
  Assert.IsTrue(TMarkdownSourceLookup.TryMapCharacter(Segment, 5, 0, 0, Offset));
  Assert.AreEqual(11, Offset);

  Assert.IsTrue(TMarkdownSourceLookup.TryMapCharacter(Segment, 5, 0, 4, Offset));
  Assert.AreEqual(15, Offset);
end;

procedure TMarkdownSourceLookupTests.TryMapCharacter_RunPartWayThroughTheNode_AddsTheRunOffset;
begin
  // A wrapped line: this run starts at the third character of the node's text.
  const Segment = TMarkdownSegment.Create(11, 16);

  var Offset := 0;
  Assert.IsTrue(TMarkdownSourceLookup.TryMapCharacter(Segment, 5, 2, 1, Offset));
  Assert.AreEqual(14, Offset);
end;

procedure TMarkdownSourceLookupTests.TryMapCharacter_RenderedTextShorterThanItsSource_Refuses;
begin
  // An escape or an entity makes the rendered text shorter than the characters it
  // came from, so positions inside it cannot be mapped one to one.
  const Segment = TMarkdownSegment.Create(11, 21);

  var Offset := 0;
  Assert.IsFalse(TMarkdownSourceLookup.TryMapCharacter(Segment, 5, 0, 0, Offset));
end;

procedure TMarkdownSourceLookupTests.TryMapCharacter_NodeWithoutASegment_Refuses;
begin
  const Segment = TMarkdownSegment.Create(0, 0);

  var Offset := 0;
  Assert.IsFalse(TMarkdownSourceLookup.TryMapCharacter(Segment, 5, 0, 0, Offset));
end;

procedure TMarkdownSourceLookupTests.TryMapCharacter_OffsetOutsideTheNode_Refuses;
begin
  const Segment = TMarkdownSegment.Create(11, 16);

  var Offset := 0;
  Assert.IsFalse(TMarkdownSourceLookup.TryMapCharacter(Segment, 5, 0, 5, Offset), 'past the end');
  Assert.IsFalse(TMarkdownSourceLookup.TryMapCharacter(Segment, 5, 0, -1, Offset), 'before the start');
end;

end.
