unit Markdown4D.Layout.ChangedBlocks.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces;

type
  [TestFixture]
  TMarkdownChangedBlocksTests = class
  private
    const
      First = 'one';
      Second = 'two';
      Third = 'three';
      Separator = #10#10;
      ThreeBlocks = First + Separator + Second + Separator + Third;
      SecondEdited = First + Separator + Second + ' more' + Separator + Third;
    class function Parse(const Source: string): IMarkdownDocument; static;
    class function SourceOf(const Text: string; const Node: IMarkdownNode): string; static;

  public
    [Test]
    procedure TryReuse_EditInMiddleBlock_RangeIsThatBlock;

    [Test]
    procedure TryReuse_BlockAfterEdit_IsPreviousNodeAtItsNewPlace;

    [Test]
    procedure TryReuse_TextInBlockAfterEdit_IsAtItsNewPlace;

    [Test]
    procedure TryReuse_HeadingAfterInsertedLines_HasItsNewLine;

    [Test]
    procedure TryReuse_BlockInserted_RangeHoldsOnlyTheNewBlock;

    [Test]
    [TestCase('LinkDefinition', '[site]: https://example.com')]
    [TestCase('Footnote', 'See[^1].')]
    procedure TryReuse_EditThatChangesOtherBlocks_ReturnsFalse(const Added: string);

    [Test]
    procedure TryReuse_DocumentWithTableOfContents_ReturnsFalse;

    [Test]
    procedure TryReuse_SectionThatNoLongerCloses_ReturnsFalse;

    [Test]
    procedure TryReuse_AlignedElementThatNoLongerCloses_ReturnsFalse;

    [Test]
    procedure TryReuse_EveryBlockChanged_ReturnsFalse;
  end;

implementation

uses
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.ChangedBlocks;

procedure TMarkdownChangedBlocksTests.TryReuse_EditInMiddleBlock_RangeIsThatBlock;
begin
  const Previous = Parse(ThreeBlocks);
  const Current = Parse(SecondEdited);

  var Range: TLayoutBlockRange;
  const Reused = TMarkdownChangedBlocks.TryReuse(Previous, ThreeBlocks, Current, SecondEdited, nil, Range);

  Assert.IsTrue(Reused);
  Assert.AreEqual(1, Range.FirstBlockIndex);
  Assert.AreEqual(1, Range.OldBlockCount);
  Assert.AreEqual(1, Range.NewBlockCount);
end;

procedure TMarkdownChangedBlocksTests.TryReuse_BlockAfterEdit_IsPreviousNodeAtItsNewPlace;
begin
  const Previous = Parse(ThreeBlocks);
  const Current = Parse(SecondEdited);
  const PreviousThird = Previous.Children[2];

  var Range: TLayoutBlockRange;
  TMarkdownChangedBlocks.TryReuse(Previous, ThreeBlocks, Current, SecondEdited, nil, Range);

  const CurrentThird = Current.Children[2];
  Assert.IsTrue(CurrentThird = PreviousThird, 'the block keeps its node, and so its layout');
  Assert.AreEqual(Third, SourceOf(SecondEdited, CurrentThird));
end;

procedure TMarkdownChangedBlocksTests.TryReuse_TextInBlockAfterEdit_IsAtItsNewPlace;
begin
  const Previous = Parse(ThreeBlocks);
  const Current = Parse(SecondEdited);

  var Range: TLayoutBlockRange;
  TMarkdownChangedBlocks.TryReuse(Previous, ThreeBlocks, Current, SecondEdited, nil, Range);

  const ThirdBlock = Current.Children[2];
  const ThirdText = ThirdBlock.Children[0];
  Assert.AreEqual(Third, SourceOf(SecondEdited, ThirdText));
end;

procedure TMarkdownChangedBlocksTests.TryReuse_HeadingAfterInsertedLines_HasItsNewLine;
begin
  const PreviousText = First + Separator + '## Title';
  const CurrentText = First + ' and'#10'more' + Separator + '## Title';
  const Previous = Parse(PreviousText);
  const Current = Parse(CurrentText);
  const Fresh = Parse(CurrentText);

  var Range: TLayoutBlockRange;
  TMarkdownChangedBlocks.TryReuse(Previous, PreviousText, Current, CurrentText, nil, Range);

  const Heading = Current.Children[1] as IMarkdownHeading;
  const FreshHeading = Fresh.Children[1] as IMarkdownHeading;
  Assert.AreEqual(FreshHeading.SourceLine, Heading.SourceLine);
end;

procedure TMarkdownChangedBlocksTests.TryReuse_BlockInserted_RangeHoldsOnlyTheNewBlock;
begin
  const CurrentText = First + Separator + 'inserted' + Separator + Second + Separator + Third;
  const Previous = Parse(ThreeBlocks);
  const Current = Parse(CurrentText);

  var Range: TLayoutBlockRange;
  const Reused = TMarkdownChangedBlocks.TryReuse(Previous, ThreeBlocks, Current, CurrentText, nil, Range);

  Assert.IsTrue(Reused);
  Assert.AreEqual(1, Range.FirstBlockIndex);
  Assert.AreEqual(0, Range.OldBlockCount);
  Assert.AreEqual(1, Range.NewBlockCount);
end;

procedure TMarkdownChangedBlocksTests.TryReuse_EditThatChangesOtherBlocks_ReturnsFalse(const Added: string);
begin
  const CurrentText = First + Separator + Added + Separator + Second + Separator + Third;
  const Previous = Parse(ThreeBlocks);
  const Current = Parse(CurrentText);

  var Range: TLayoutBlockRange;
  const Reused = TMarkdownChangedBlocks.TryReuse(Previous, ThreeBlocks, Current, CurrentText, nil, Range);

  Assert.IsFalse(Reused);
end;

procedure TMarkdownChangedBlocksTests.TryReuse_DocumentWithTableOfContents_ReturnsFalse;
begin
  const PreviousText = '[TOC]' + Separator + '## ' + First + Separator + Second;
  const CurrentText = '[TOC]' + Separator + '## ' + First + Separator + Second + ' more';
  const Previous = Parse(PreviousText);
  const Current = Parse(CurrentText);

  var Range: TLayoutBlockRange;
  const Reused = TMarkdownChangedBlocks.TryReuse(Previous, PreviousText, Current, CurrentText, nil, Range);

  Assert.IsFalse(Reused);
end;

procedure TMarkdownChangedBlocksTests.TryReuse_SectionThatNoLongerCloses_ReturnsFalse;
begin
  const Opening = '<details>'#10'<summary>More</summary>';
  const PreviousText = Opening + Separator + First + Separator + '</details>' + Separator + Third;
  const CurrentText = Opening + Separator + First + Separator + Third;
  const Previous = Parse(PreviousText);
  const Current = Parse(CurrentText);

  var Range: TLayoutBlockRange;
  const Reused = TMarkdownChangedBlocks.TryReuse(Previous, PreviousText, Current, CurrentText, nil, Range);

  Assert.IsFalse(Reused, 'the block after the section was shown and is hidden now');
end;

procedure TMarkdownChangedBlocksTests.TryReuse_AlignedElementThatNoLongerCloses_ReturnsFalse;
begin
  const Opening = '<div align="center">';
  const PreviousText = Opening + Separator + First + Separator + '</div>' + Separator + Third;
  const CurrentText = Opening + Separator + First + Separator + Third;
  const Previous = Parse(PreviousText);
  const Current = Parse(CurrentText);

  var Range: TLayoutBlockRange;
  const Reused = TMarkdownChangedBlocks.TryReuse(Previous, PreviousText, Current, CurrentText, nil, Range);

  Assert.IsFalse(Reused, 'the block after the element was at the left and is centred now');
end;

procedure TMarkdownChangedBlocksTests.TryReuse_EveryBlockChanged_ReturnsFalse;
begin
  const CurrentText = 'other';
  const Previous = Parse(ThreeBlocks);
  const Current = Parse(CurrentText);

  var Range: TLayoutBlockRange;
  const Reused = TMarkdownChangedBlocks.TryReuse(Previous, ThreeBlocks, Current, CurrentText, nil, Range);

  Assert.IsFalse(Reused);
end;

class function TMarkdownChangedBlocksTests.Parse(const Source: string): IMarkdownDocument;
begin
  Result := TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
end;

class function TMarkdownChangedBlocksTests.SourceOf(const Text: string; const Node: IMarkdownNode): string;
begin
  const Segment = Node.Segment;
  Result := Copy(Text, Segment.StartOffset, Segment.Length);
end;

end.
