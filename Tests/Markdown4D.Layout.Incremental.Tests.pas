unit Markdown4D.Layout.Incremental.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.Engine,
  Markdown4D.Theme;

type
  [TestFixture]
  TMarkdownLayoutIncrementalTests = class
  private
    const
      BaseFamilyName = 'Test Sans';
      BaseFontSize = 16.0;
      ParagraphSpacingValue = 8.0;
      FirstParagraph = 'first paragraph words';
      SecondParagraph = 'second paragraph words';
      ThirdParagraph = 'third paragraph words';
      InsertedParagraph = 'inserted paragraph words';
      LongerSecondParagraph = 'second paragraph words grown considerably longer so this block wraps onto extra lines';
      ParagraphSeparator = #10#10;
      OriginalSource = FirstParagraph + ParagraphSeparator + SecondParagraph + ParagraphSeparator + ThirdParagraph;
      EditedSource = FirstParagraph + ParagraphSeparator + LongerSecondParagraph + ParagraphSeparator + ThirdParagraph;
      InsertSource = FirstParagraph + ParagraphSeparator + InsertedParagraph + ParagraphSeparator + SecondParagraph +
        ParagraphSeparator + ThirdParagraph;
      DeleteSource = FirstParagraph + ParagraphSeparator + ThirdParagraph;
      ThirdPrefix = 'third';
      LayoutWidth = 200.0;
      SingleTolerance = 0.05;
    class function CreateTestTheme: TMarkdownTheme;
    class function LayoutSource(const Source: string): IMarkdownDisplayList;
    class function UpdateSource(const OriginalMarkdown, EditedMarkdown: string;
      const ChangedRange: TLayoutBlockRange): IMarkdownDisplayList;
    class function TextRunsOf(const DisplayList: IMarkdownDisplayList): TArray<IDisplayTextRun>;
    class function FindRunByPrefix(const Runs: TArray<IDisplayTextRun>; const Prefix: string): IDisplayTextRun;
    class procedure AssertEquivalent(const Expected, Actual: IMarkdownDisplayList);
    class procedure AssertSingle(const Expected, Actual: Single);

  public
    [Test]
    procedure UpdateLayout_ChangedBlock_RecomputesOnlyThatBlock;

    [Test]
    procedure UpdateLayout_ChangedBlock_ShiftsFollowingBlocksToFreshPositions;

    [Test]
    procedure UpdateLayout_ChangedBlock_TotalHeightMatchesFreshLayout;

    [Test]
    procedure UpdateLayout_ChangedBlock_DisplayListEquivalentToFreshLayout;

    [Test]
    procedure UpdateLayout_InsertedBlock_RecomputesInsertedBlockAndMatchesFreshLayout;

    [Test]
    procedure UpdateLayout_RemovedBlock_RecomputesNothingAndMatchesFreshLayout;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.FakeMeasurer;

procedure TMarkdownLayoutIncrementalTests.UpdateLayout_ChangedBlock_RecomputesOnlyThatBlock;
begin
  const Updated = UpdateSource(OriginalSource, EditedSource, TLayoutBlockRange.Create(1, 1, 1));

  const Indexes = Updated.RecomputedBlockIndexes;
  Assert.AreEqual(1, Integer(Length(Indexes)));
  Assert.AreEqual(1, Indexes[0]);
end;

procedure TMarkdownLayoutIncrementalTests.UpdateLayout_ChangedBlock_ShiftsFollowingBlocksToFreshPositions;
begin
  const Previous = LayoutSource(OriginalSource);
  const PreviousThird = FindRunByPrefix(TextRunsOf(Previous), ThirdPrefix);
  Assert.IsNotNull(PreviousThird);

  const Updated = UpdateSource(OriginalSource, EditedSource, TLayoutBlockRange.Create(1, 1, 1));
  const UpdatedThird = FindRunByPrefix(TextRunsOf(Updated), ThirdPrefix);
  Assert.IsNotNull(UpdatedThird);

  const Fresh = LayoutSource(EditedSource);
  const FreshThird = FindRunByPrefix(TextRunsOf(Fresh), ThirdPrefix);
  Assert.IsNotNull(FreshThird);

  AssertSingle(FreshThird.Bounds.Top, UpdatedThird.Bounds.Top);

  const HasShiftedDown = (UpdatedThird.Bounds.Top > PreviousThird.Bounds.Top);
  Assert.IsTrue(HasShiftedDown);
end;

procedure TMarkdownLayoutIncrementalTests.UpdateLayout_ChangedBlock_TotalHeightMatchesFreshLayout;
begin
  const Updated = UpdateSource(OriginalSource, EditedSource, TLayoutBlockRange.Create(1, 1, 1));

  const Fresh = LayoutSource(EditedSource);
  AssertSingle(Fresh.Height, Updated.Height);
end;

procedure TMarkdownLayoutIncrementalTests.UpdateLayout_ChangedBlock_DisplayListEquivalentToFreshLayout;
begin
  const Updated = UpdateSource(OriginalSource, EditedSource, TLayoutBlockRange.Create(1, 1, 1));

  const Fresh = LayoutSource(EditedSource);
  AssertEquivalent(Fresh, Updated);
end;

procedure TMarkdownLayoutIncrementalTests.UpdateLayout_InsertedBlock_RecomputesInsertedBlockAndMatchesFreshLayout;
begin
  const Updated = UpdateSource(OriginalSource, InsertSource, TLayoutBlockRange.Create(1, 0, 1));

  const Indexes = Updated.RecomputedBlockIndexes;
  Assert.AreEqual(1, Integer(Length(Indexes)));
  Assert.AreEqual(1, Indexes[0]);

  const Fresh = LayoutSource(InsertSource);
  AssertEquivalent(Fresh, Updated);
end;

procedure TMarkdownLayoutIncrementalTests.UpdateLayout_RemovedBlock_RecomputesNothingAndMatchesFreshLayout;
begin
  const Updated = UpdateSource(OriginalSource, DeleteSource, TLayoutBlockRange.Create(1, 1, 0));

  Assert.AreEqual(0, Integer(Length(Updated.RecomputedBlockIndexes)));

  const Fresh = LayoutSource(DeleteSource);
  AssertEquivalent(Fresh, Updated);
end;

class function TMarkdownLayoutIncrementalTests.CreateTestTheme: TMarkdownTheme;
begin
  Result := TMarkdownTheme.CreateLight;

  Result.BaseFont := TMarkdownFontStyle.Create(BaseFamilyName, BaseFontSize);
  Result.ParagraphSpacing := ParagraphSpacingValue;
end;

class function TMarkdownLayoutIncrementalTests.LayoutSource(const Source: string): IMarkdownDisplayList;
begin
  const Theme = CreateTestTheme;
  try
    const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
    const Measurer: ITextMeasurer = TFakeTextMeasurer.Create;

    Result := TMarkdownLayoutEngine.LayoutDocument(Document, LayoutWidth, Theme, Measurer);
  finally
    Theme.Free;
  end;
end;

class function TMarkdownLayoutIncrementalTests.UpdateSource(const OriginalMarkdown, EditedMarkdown: string;
  const ChangedRange: TLayoutBlockRange): IMarkdownDisplayList;
begin
  const Previous = LayoutSource(OriginalMarkdown);
  const Document = TMarkdown.Parse(EditedMarkdown, TMarkdownDialect.Gfm);

  const Theme = CreateTestTheme;
  try
    const Measurer: ITextMeasurer = TFakeTextMeasurer.Create;

    Result := TMarkdownLayoutEngine.UpdateLayout(Previous, Document, ChangedRange, Theme, Measurer);
  finally
    Theme.Free;
  end;
end;

class function TMarkdownLayoutIncrementalTests.TextRunsOf(const DisplayList: IMarkdownDisplayList): TArray<IDisplayTextRun>;
begin
  Result := nil;

  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const IsTextRun = Supports(DisplayList.Items[Index], IDisplayTextRun, Run);
    if IsTextRun then
      Result := Result + [Run];
  end;
end;

class function TMarkdownLayoutIncrementalTests.FindRunByPrefix(const Runs: TArray<IDisplayTextRun>;
  const Prefix: string): IDisplayTextRun;
begin
  for var Run in Runs do
  begin
    const Matches = Run.Text.StartsWith(Prefix);
    if Matches then
      Exit(Run);
  end;

  Result := nil;
end;

class procedure TMarkdownLayoutIncrementalTests.AssertEquivalent(const Expected, Actual: IMarkdownDisplayList);
begin
  Assert.AreEqual(Expected.ItemCount, Actual.ItemCount);

  for var Index := 0 to Expected.ItemCount - 1 do
  begin
    const ExpectedItem = Expected.Items[Index];
    const ActualItem = Actual.Items[Index];

    const SameKind = (ExpectedItem.Kind = ActualItem.Kind);
    Assert.IsTrue(SameKind, Format('Item %d differs in kind', [Index]));

    AssertSingle(ExpectedItem.Bounds.Left, ActualItem.Bounds.Left);
    AssertSingle(ExpectedItem.Bounds.Top, ActualItem.Bounds.Top);
    AssertSingle(ExpectedItem.Bounds.Right, ActualItem.Bounds.Right);
    AssertSingle(ExpectedItem.Bounds.Bottom, ActualItem.Bounds.Bottom);

    var ExpectedRun: IDisplayTextRun;
    var ActualRun: IDisplayTextRun;
    const BothAreRuns = Supports(ExpectedItem, IDisplayTextRun, ExpectedRun) and
      Supports(ActualItem, IDisplayTextRun, ActualRun);
    if BothAreRuns then
      Assert.AreEqual(ExpectedRun.Text, ActualRun.Text);
  end;

  AssertSingle(Expected.Height, Actual.Height);
end;

class procedure TMarkdownLayoutIncrementalTests.AssertSingle(const Expected, Actual: Single);
begin
  Assert.AreEqual(Double(Expected), Double(Actual), SingleTolerance);
end;

end.
