unit Markdown4D.Editor.InlineStyle.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.InlineStyle;

type
  [TestFixture]
  TMarkdownInlineStyleNormalizerTests = class
  private
    function Normalize(const Text, SourceSlice: string; const Style: TMarkdownInlineStyle): string;
    function Strong(const Text, SourceSlice: string): string;
    function Emphasis(const Text, SourceSlice: string): string;

  public
    [Test]
    [TestCase('PlainWord', 'plain text here,text,plain **text** here')]
    [TestCase('SpacesAtTheEdges', 'a bb c, bb ,a **bb** c')]
    [TestCase('WholeParagraph', 'all of it,all of it,**all of it**')]
    procedure Strong_RangeOutsideAnyMarks_WrapsTheRange(const Text, Slice, Expected: string);

    // The reader points at the back half of a bold word and the plain text
    // after it. Markers cannot cross like that, so the bold that was there is
    // taken in and the whole stretch ends up bold.
    [Test]
    procedure Strong_RangeHalfOverExistingStrong_TakesTheWholeStretchIn;

    [Test]
    procedure Strong_RangeOverTwoStrongs_JoinsThemIntoOne;

    [Test]
    [TestCase('WholeContent', '**bold**,bold,bold')]
    [TestCase('TailOfContent', '**bold text**,text,**bold** text')]
    [TestCase('HeadOfContent', '**bold text**,bold,bold **text**')]
    [TestCase('MiddleOfContent', '**a b c**,b,**a** b **c**')]
    procedure Strong_RangeInsideExistingStrong_TakesTheMarksOff(const Text, Slice, Expected: string);

    // Pressing Bold twice over the same words leaves the text as it was, rather
    // than nesting a second pair of markers inside the first.
    [Test]
    procedure Strong_AppliedTwiceOverTheSameWords_LeavesTheTextAsItWas;

    // A stretch that already carries the same style twice reads as one stretch,
    // and the command writes one pair per stretch.
    [Test]
    procedure Strong_NestedInsideTheSameStyle_NormalizesToOnePairPerStretch;

    [Test]
    procedure Strong_InsideSurroundingEmphasis_LeavesTheEmphasisStanding;

    [Test]
    procedure Strong_OnContentOfBothStyles_TakesOffOnlyTheStrong;

    [Test]
    procedure Strong_NextToACodeSpanHoldingAsterisks_LeavesTheCodeAlone;

    [Test]
    procedure Strong_RangeHalfOverACodeSpan_TakesTheWholeSpanIn;

    [Test]
    procedure Strong_RangeInsideALinkLabel_PutsTheMarksInsideTheLabel;

    [Test]
    procedure Strong_RangeHalfOverALink_TakesTheWholeLinkIn;

    [Test]
    [TestCase('AcrossParagraphs', 'one'#10#10'two,one'#10#10'two')]
    [TestCase('InsideACodeBlock', '```'#10'a word'#10'```,word')]
    [TestCase('InsideATableCell', '| head |'#10'| ---- |'#10'| cell |,cell')]
    procedure Strong_RangeWithoutOneInlineContext_ChangesNothing(const Text, Slice: string);

    [Test]
    procedure Strong_Range_LeavesTheSelectionOnTheSameCharacters;

    [Test]
    procedure Emphasis_RangeHalfOverExistingEmphasis_TakesTheWholeStretchIn;

    [Test]
    [TestCase('PlainWord', 'plain text,text,plain *text*')]
    [TestCase('InsideExistingEmphasis', '*text*,text,text')]
    [TestCase('InsideStrong', '**a b**,a,***a* b**')]
    procedure Emphasis_Range_TogglesOnlyTheEmphasis(const Text, Slice, Expected: string);
  end;

implementation

uses
  System.SysUtils;

// Runs the command over the stretch of markdown that Slice spells, so a test
// reads as the source it works on rather than as a pair of offsets.
function TMarkdownInlineStyleNormalizerTests.Normalize(const Text, SourceSlice: string;
  const Style: TMarkdownInlineStyle): string;
begin
  const Found = Pos(SourceSlice, Text);
  Assert.IsTrue(Found > 0, Format('The text does not carry "%s"', [SourceSlice]));

  var Edit: TMarkdownInlineStyleEdit;
  if not TMarkdownInlineStyleNormalizer.TryNormalize(Text, Found - 1, Length(SourceSlice), Style, Edit) then
  begin
    Result := Text;
    Exit;
  end;

  const Before = Copy(Text, 1, Edit.Start);
  const After = Copy(Text, Edit.Start + Edit.Length + 1, MaxInt);

  Result := Before + Edit.Replacement + After;
end;

function TMarkdownInlineStyleNormalizerTests.Strong(const Text, SourceSlice: string): string;
begin
  Result := Normalize(Text, SourceSlice, TMarkdownInlineStyle.Strong);
end;

function TMarkdownInlineStyleNormalizerTests.Emphasis(const Text, SourceSlice: string): string;
begin
  Result := Normalize(Text, SourceSlice, TMarkdownInlineStyle.Emphasis);
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_RangeOutsideAnyMarks_WrapsTheRange(
  const Text, Slice, Expected: string);
begin
  Assert.AreEqual(Expected, Strong(Text, Slice));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_RangeHalfOverExistingStrong_TakesTheWholeStretchIn;
begin
  Assert.AreEqual('**bold te**xt', Strong('**bold** text', 'ld** te'));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_RangeOverTwoStrongs_JoinsThemIntoOne;
begin
  Assert.AreEqual('**a and b**', Strong('**a** and **b**', 'a** and **b'));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_RangeInsideExistingStrong_TakesTheMarksOff(
  const Text, Slice, Expected: string);
begin
  Assert.AreEqual(Expected, Strong(Text, Slice));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_AppliedTwiceOverTheSameWords_LeavesTheTextAsItWas;
begin
  const Original = 'plain text here';

  const Once = Strong(Original, 'text');
  Assert.AreEqual('plain **text** here', Once);

  Assert.AreEqual(Original, Strong(Once, 'text'));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_NestedInsideTheSameStyle_NormalizesToOnePairPerStretch;
begin
  Assert.AreEqual('**a** b **c**', Strong('**a **b** c**', 'b'));
end;

procedure TMarkdownInlineStyleNormalizerTests.Emphasis_RangeHalfOverExistingEmphasis_TakesTheWholeStretchIn;
begin
  Assert.AreEqual('*a b*', Emphasis('*a* b', 'a* b'));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_InsideSurroundingEmphasis_LeavesTheEmphasisStanding;
begin
  Assert.AreEqual('***a b** c*', Strong('*a **b** c*', 'a **b'));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_OnContentOfBothStyles_TakesOffOnlyTheStrong;
begin
  Assert.AreEqual('*abc*', Strong('***abc***', 'abc'));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_NextToACodeSpanHoldingAsterisks_LeavesTheCodeAlone;
begin
  Assert.AreEqual('`**x**` **text**', Strong('`**x**` text', 'text'));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_RangeHalfOverACodeSpan_TakesTheWholeSpanIn;
begin
  Assert.AreEqual('see **`code`** now', Strong('see `code` now', 'co'));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_RangeInsideALinkLabel_PutsTheMarksInsideTheLabel;
begin
  Assert.AreEqual('see [**the** docs](u) now', Strong('see [the docs](u) now', 'the '));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_RangeHalfOverALink_TakesTheWholeLinkIn;
begin
  Assert.AreEqual('see **[the docs](u) no**w', Strong('see [the docs](u) now', 'docs](u) no'));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_RangeWithoutOneInlineContext_ChangesNothing(
  const Text, Slice: string);
begin
  Assert.AreEqual(Text, Strong(Text, Slice));
end;

procedure TMarkdownInlineStyleNormalizerTests.Strong_Range_LeavesTheSelectionOnTheSameCharacters;
begin
  const Text = 'plain text here';
  const Found = Pos('text', Text);

  var Edit: TMarkdownInlineStyleEdit;
  Assert.IsTrue(TMarkdownInlineStyleNormalizer.TryNormalize(Text, Found - 1, 4,
    TMarkdownInlineStyle.Strong, Edit));

  const Written = Copy(Text, 1, Edit.Start) + Edit.Replacement + Copy(Text, Edit.Start + Edit.Length + 1, MaxInt);

  Assert.AreEqual('text', Copy(Written, Edit.SelectionStart + 1, Edit.SelectionLength));
end;

procedure TMarkdownInlineStyleNormalizerTests.Emphasis_Range_TogglesOnlyTheEmphasis(
  const Text, Slice, Expected: string);
begin
  Assert.AreEqual(Expected, Emphasis(Text, Slice));
end;

end.
