unit Markdown4D.Parser.SourceMap.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Parser.SourceMap;

type
  [TestFixture]
  TMarkdownSourceMapTests = class
  public
    [Test]
    procedure TryMap_SingleRun_ReturnsSourceOffsetForEachCharacter;

    [Test]
    procedure TryMap_SecondRun_SkipsTheGapLeftByStrippedMarkers;

    [Test]
    procedure TryMap_IndexOutsideEveryRun_ReturnsFalse;

    [Test]
    procedure TryMap_EmptyMap_ReturnsFalse;

    [Test]
    procedure DropLeading_TrimmedContent_ShiftsRunsBackAndDropsWhatIsGone;

    [Test]
    procedure TryMapRange_SpanWithinOneRun_ReturnsStartAndLength;
  end;

implementation

procedure TMarkdownSourceMapTests.TryMap_SingleRun_ReturnsSourceOffsetForEachCharacter;
begin
  // One appended line: content 1..5 came from source 11..15.
  var Map := TMarkdownSourceMap.Create;
  Map.Add(1, 11, 5);

  var Offset := 0;
  Assert.IsTrue(Map.TryMap(1, Offset), 'first character');
  Assert.AreEqual(11, Offset);

  Assert.IsTrue(Map.TryMap(5, Offset), 'last character');
  Assert.AreEqual(15, Offset);
end;

procedure TMarkdownSourceMapTests.TryMap_SecondRun_SkipsTheGapLeftByStrippedMarkers;
begin
  // Two lines of a block quote. The '> ' prefix of the second line never reaches
  // the content, so content index 6 resumes further along in the source.
  var Map := TMarkdownSourceMap.Create;
  Map.Add(1, 11, 5);
  Map.Add(6, 25, 4);

  var Offset := 0;
  Assert.IsTrue(Map.TryMap(6, Offset), 'first character of the second line');
  Assert.AreEqual(25, Offset);

  Assert.IsTrue(Map.TryMap(9, Offset), 'last character of the second line');
  Assert.AreEqual(28, Offset);
end;

procedure TMarkdownSourceMapTests.TryMap_IndexOutsideEveryRun_ReturnsFalse;
begin
  var Map := TMarkdownSourceMap.Create;
  Map.Add(1, 11, 5);

  var Offset := 0;
  Assert.IsFalse(Map.TryMap(0, Offset), 'before the first run');
  Assert.IsFalse(Map.TryMap(6, Offset), 'past the last run');
end;

procedure TMarkdownSourceMapTests.TryMap_EmptyMap_ReturnsFalse;
begin
  var Map := TMarkdownSourceMap.Create;

  var Offset := 0;
  Assert.IsFalse(Map.TryMap(1, Offset));
end;

procedure TMarkdownSourceMapTests.DropLeading_TrimmedContent_ShiftsRunsBackAndDropsWhatIsGone;
begin
  // The block parser trims the assembled content before parsing inlines, so the
  // map has to lose the same leading characters.
  var Map := TMarkdownSourceMap.Create;
  Map.Add(1, 11, 5);
  Map.Add(6, 25, 4);

  Map.DropLeading(2);

  var Offset := 0;
  Assert.IsTrue(Map.TryMap(1, Offset), 'content now starts at the third character');
  Assert.AreEqual(13, Offset);

  Assert.IsTrue(Map.TryMap(4, Offset), 'the second run moved back too');
  Assert.AreEqual(25, Offset);
end;

procedure TMarkdownSourceMapTests.TryMapRange_SpanWithinOneRun_ReturnsStartAndLength;
begin
  var Map := TMarkdownSourceMap.Create;
  Map.Add(1, 11, 5);

  var Segment := TMarkdownSourceSpan.Create(0, 0);
  Assert.IsTrue(Map.TryMapRange(2, 3, Segment));
  Assert.AreEqual(12, Segment.StartOffset);
  Assert.AreEqual(3, Segment.Length);
end;

end.
