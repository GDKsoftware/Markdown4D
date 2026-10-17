unit Markdown4D.Layout.Disclosure.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme;

type
  [TestFixture]
  TMarkdownDisclosureTests = class
  private
    const
      BaseFamilyName = 'Test Sans';
      BaseFontSize = 16.0;
      DefaultWidth = 300.0;
      SummaryLineY = 10.0;
      MissY = 300.0;
      SingleTolerance = 0.05;
      SummaryText = 'More';
      ContentText = 'Body';
      AfterText = 'After';
      ClosedSection = '<details>'#10'<summary>' + SummaryText + '</summary>'#10#10 + ContentText + #10#10'</details>';
      OpenSection = '<details open>'#10'<summary>' + SummaryText + '</summary>'#10#10 + ContentText + #10#10'</details>';
    class function Parse(const Source: string): IMarkdownDocument;
    class function CreateTestTheme: TMarkdownTheme;
    class function LayoutMarkdown(const Source: string;
      const Disclosures: IMarkdownDisclosureState = nil): IMarkdownDisplayList;
    class function DisclosuresOf(const DisplayList: IMarkdownDisplayList): TArray<IDisplayDisclosure>;
    class procedure AssertFlags(const Expected: array of Boolean; const Actual: TArray<Boolean>);

  public
    [Test]
    procedure IsOpener_DetailsBlockWithSummary_IsClosedByDefault;

    [Test]
    [TestCase('Bare', '<details open>')]
    [TestCase('UpperCase', '<DETAILS OPEN>')]
    [TestCase('AfterOtherAttribute', '<details class="note" open>')]
    [TestCase('EmptyValue', '<details open="">')]
    procedure IsOpener_OpenAttribute_IsOpenByDefault(const OpeningTag: string);

    [Test]
    procedure IsOpener_WholeSectionInOneBlock_ReturnsFalse;

    [Test]
    procedure IsOpener_TagThatOnlyStartsWithDetails_ReturnsFalse;

    [Test]
    procedure IsCloser_ClosingTag_ReturnsTrue;

    [Test]
    procedure HiddenChildren_ClosedSection_HidesContentAndCloser;

    [Test]
    procedure HiddenChildren_OpenSection_HidesOnlyCloser;

    [Test]
    procedure HiddenChildren_ClosedSectionInOpenSection_HidesInnerContentAndClosers;

    [Test]
    procedure HiddenChildren_ClosedSectionAroundOpenSection_HidesBoth;

    [Test]
    procedure HiddenChildren_SectionWithoutCloser_HidesRestOfContainer;

    [Test]
    procedure HiddenChildren_StateOpensSection_HidesOnlyCloser;

    [Test]
    procedure Layout_ClosedSection_ShowsSummaryOnly;

    [Test]
    procedure Layout_OpenAttribute_ShowsContent;

    [Test]
    procedure Layout_StateOpensSection_ShowsContent;

    [Test]
    procedure Layout_ClosedSection_AddsClosedDisclosure;

    [Test]
    procedure Layout_TwoSections_GivesEachItsOwnKey;

    [Test]
    procedure Layout_SameTextAgain_KeepsKeys;

    [Test]
    procedure Layout_ClosedSection_PutsFollowingTextBelowSummary;

    [Test]
    procedure Layout_OpenSection_LeavesOneGapBeforeFollowingText;

    [Test]
    procedure Layout_Summary_StartsPastMarker;

    [Test]
    procedure Layout_ClosedSectionInBlockQuote_HidesContent;

    [Test]
    procedure Layout_ClosedSectionInListItem_HidesContent;

    [Test]
    procedure Layout_WholeSectionInOneBlock_ShowsEverythingWithoutDisclosure;

    [Test]
    procedure Layout_ClosedSection_KeepsOneBlockInfoPerChild;

    [Test]
    procedure TryFindDisclosure_PointOnSummaryLine_ReturnsDisclosure;

    [Test]
    procedure TryFindDisclosure_PointBelowSummary_ReturnsFalse;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.Disclosure,
  Markdown4D.Layout.HitTest,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Tests.DisplayList.Helpers;

type
  // Opens the sections that are closed by default and closes the open ones,
  // as a reader would by clicking every summary.
  TToggledDisclosureState = class(TInterfacedObject, IMarkdownDisclosureState)
  public
    function IsDisclosureOpen(const Key: Integer; const OpenByDefault: Boolean): Boolean;
  end;

function TToggledDisclosureState.IsDisclosureOpen(const Key: Integer; const OpenByDefault: Boolean): Boolean;
begin
  Result := not OpenByDefault;
end;

procedure TMarkdownDisclosureTests.IsOpener_DetailsBlockWithSummary_IsClosedByDefault;
begin
  const Document = Parse(ClosedSection);

  var OpenByDefault: Boolean;
  const IsOpener = TMarkdownDisclosures.IsOpener(Document.Children[0], OpenByDefault);

  Assert.IsTrue(IsOpener);
  Assert.IsFalse(OpenByDefault);
end;

procedure TMarkdownDisclosureTests.IsOpener_OpenAttribute_IsOpenByDefault(const OpeningTag: string);
begin
  const Document = Parse(OpeningTag + #10'<summary>' + SummaryText + '</summary>'#10#10 + ContentText);

  var OpenByDefault: Boolean;
  const IsOpener = TMarkdownDisclosures.IsOpener(Document.Children[0], OpenByDefault);

  Assert.IsTrue(IsOpener);
  Assert.IsTrue(OpenByDefault);
end;

procedure TMarkdownDisclosureTests.IsOpener_WholeSectionInOneBlock_ReturnsFalse;
begin
  const Document = Parse('<details><summary>' + SummaryText + '</summary>' + ContentText + '</details>');

  var OpenByDefault: Boolean;
  const IsOpener = TMarkdownDisclosures.IsOpener(Document.Children[0], OpenByDefault);

  Assert.IsFalse(IsOpener);
end;

procedure TMarkdownDisclosureTests.IsOpener_TagThatOnlyStartsWithDetails_ReturnsFalse;
begin
  const Document = Parse('<detailsx>'#10#10 + ContentText);

  var OpenByDefault: Boolean;
  const IsOpener = TMarkdownDisclosures.IsOpener(Document.Children[0], OpenByDefault);

  Assert.IsFalse(IsOpener);
end;

procedure TMarkdownDisclosureTests.IsCloser_ClosingTag_ReturnsTrue;
begin
  const Document = Parse(ClosedSection);
  const LastChild = Document.Children[Document.ChildCount - 1];

  Assert.IsTrue(TMarkdownDisclosures.IsCloser(LastChild));
  Assert.IsFalse(TMarkdownDisclosures.IsCloser(Document.Children[0]));
end;

procedure TMarkdownDisclosureTests.HiddenChildren_ClosedSection_HidesContentAndCloser;
begin
  const Document = Parse(ClosedSection + #10#10 + AfterText);

  const Hidden = TMarkdownDisclosures.HiddenChildren(Document, nil);

  AssertFlags([False, True, True, False], Hidden);
end;

procedure TMarkdownDisclosureTests.HiddenChildren_OpenSection_HidesOnlyCloser;
begin
  const Document = Parse(OpenSection);

  const Hidden = TMarkdownDisclosures.HiddenChildren(Document, nil);

  AssertFlags([False, False, True], Hidden);
end;

procedure TMarkdownDisclosureTests.HiddenChildren_ClosedSectionInOpenSection_HidesInnerContentAndClosers;
begin
  const Document = Parse('<details open>'#10'<summary>Outer</summary>'#10#10'A'#10#10 + ClosedSection +
    #10#10'C'#10#10'</details>');

  const Hidden = TMarkdownDisclosures.HiddenChildren(Document, nil);

  AssertFlags([False, False, False, True, True, False, True], Hidden);
end;

procedure TMarkdownDisclosureTests.HiddenChildren_ClosedSectionAroundOpenSection_HidesBoth;
begin
  const Document = Parse('<details>'#10'<summary>Outer</summary>'#10#10'A'#10#10 + OpenSection +
    #10#10'C'#10#10'</details>');

  const Hidden = TMarkdownDisclosures.HiddenChildren(Document, nil);

  AssertFlags([False, True, True, True, True, True, True], Hidden);
end;

procedure TMarkdownDisclosureTests.HiddenChildren_SectionWithoutCloser_HidesRestOfContainer;
begin
  const Document = Parse('<details>'#10'<summary>' + SummaryText + '</summary>'#10#10'A'#10#10'B');

  const Hidden = TMarkdownDisclosures.HiddenChildren(Document, nil);

  AssertFlags([False, True, True], Hidden);
end;

procedure TMarkdownDisclosureTests.HiddenChildren_StateOpensSection_HidesOnlyCloser;
begin
  const Document = Parse(ClosedSection);
  const State: IMarkdownDisclosureState = TToggledDisclosureState.Create;

  const Hidden = TMarkdownDisclosures.HiddenChildren(Document, State);

  AssertFlags([False, False, True], Hidden);
end;

procedure TMarkdownDisclosureTests.Layout_ClosedSection_ShowsSummaryOnly;
begin
  const DisplayList = LayoutMarkdown(ClosedSection);

  Assert.IsTrue(TMarkdownTestDisplayListHelpers.ShowsText(DisplayList, SummaryText));
  Assert.IsFalse(TMarkdownTestDisplayListHelpers.ShowsText(DisplayList, ContentText));
end;

procedure TMarkdownDisclosureTests.Layout_OpenAttribute_ShowsContent;
begin
  const DisplayList = LayoutMarkdown(OpenSection);

  Assert.IsTrue(TMarkdownTestDisplayListHelpers.ShowsText(DisplayList, SummaryText));
  Assert.IsTrue(TMarkdownTestDisplayListHelpers.ShowsText(DisplayList, ContentText));
end;

procedure TMarkdownDisclosureTests.Layout_StateOpensSection_ShowsContent;
begin
  const State: IMarkdownDisclosureState = TToggledDisclosureState.Create;

  const DisplayList = LayoutMarkdown(ClosedSection, State);

  const Disclosures = DisclosuresOf(DisplayList);
  Assert.IsTrue(TMarkdownTestDisplayListHelpers.ShowsText(DisplayList, ContentText));
  Assert.IsTrue(Disclosures[0].IsOpen);
end;

procedure TMarkdownDisclosureTests.Layout_ClosedSection_AddsClosedDisclosure;
begin
  const Disclosures = DisclosuresOf(LayoutMarkdown(ClosedSection));

  Assert.AreEqual(1, Integer(Length(Disclosures)));
  Assert.IsFalse(Disclosures[0].IsOpen);
end;

procedure TMarkdownDisclosureTests.Layout_TwoSections_GivesEachItsOwnKey;
begin
  const Disclosures = DisclosuresOf(LayoutMarkdown(ClosedSection + #10#10 + ClosedSection));

  Assert.AreEqual(2, Integer(Length(Disclosures)));
  Assert.AreNotEqual(Disclosures[0].Key, Disclosures[1].Key);
end;

procedure TMarkdownDisclosureTests.Layout_SameTextAgain_KeepsKeys;
begin
  const Source = AfterText + #10#10 + ClosedSection;

  const FirstLayout = LayoutMarkdown(Source);
  const SecondLayout = LayoutMarkdown(Source);

  const FirstDisclosures = DisclosuresOf(FirstLayout);
  const SecondDisclosures = DisclosuresOf(SecondLayout);
  Assert.AreEqual(FirstDisclosures[0].Key, SecondDisclosures[0].Key);
end;

procedure TMarkdownDisclosureTests.Layout_ClosedSection_PutsFollowingTextBelowSummary;
begin
  const Source = ClosedSection + #10#10 + AfterText;

  const State: IMarkdownDisclosureState = TToggledDisclosureState.Create;

  const ClosedLayout = LayoutMarkdown(Source);
  const OpenLayout = LayoutMarkdown(Source, State);

  const Summary = TMarkdownTestDisplayListHelpers.TextRunShowing(ClosedLayout, SummaryText);
  const AfterInClosed = TMarkdownTestDisplayListHelpers.TextRunShowing(ClosedLayout, AfterText);
  const AfterInOpen = TMarkdownTestDisplayListHelpers.TextRunShowing(OpenLayout, AfterText);
  Assert.IsTrue(AfterInClosed.Bounds.Top >= Summary.Bounds.Bottom, 'text after the section starts below its summary');
  Assert.IsTrue(AfterInClosed.Bounds.Top < AfterInOpen.Bounds.Top, 'a closed section takes less room than an open one');
end;

procedure TMarkdownDisclosureTests.Layout_OpenSection_LeavesOneGapBeforeFollowingText;
begin
  const SectionLayout = LayoutMarkdown(OpenSection + #10#10 + AfterText);
  const PlainLayout = LayoutMarkdown(ContentText + #10#10 + AfterText);

  const SectionContent = TMarkdownTestDisplayListHelpers.TextRunShowing(SectionLayout, ContentText);
  const SectionAfter = TMarkdownTestDisplayListHelpers.TextRunShowing(SectionLayout, AfterText);
  const PlainContent = TMarkdownTestDisplayListHelpers.TextRunShowing(PlainLayout, ContentText);
  const PlainAfter = TMarkdownTestDisplayListHelpers.TextRunShowing(PlainLayout, AfterText);

  const SectionGap = SectionAfter.Bounds.Top - SectionContent.Bounds.Bottom;
  const PlainGap = PlainAfter.Bounds.Top - PlainContent.Bounds.Bottom;
  Assert.AreEqual(PlainGap, SectionGap, SingleTolerance, 'the end of a section adds no gap of its own');
end;

procedure TMarkdownDisclosureTests.Layout_Summary_StartsPastMarker;
begin
  const DisplayList = LayoutMarkdown(ClosedSection);

  const Disclosures = DisclosuresOf(DisplayList);
  const Disclosure = Disclosures[0];
  const Summary = TMarkdownTestDisplayListHelpers.TextRunShowing(DisplayList, SummaryText);

  Assert.AreEqual(0.0, Disclosure.Marker.Left, SingleTolerance);
  Assert.IsTrue(Summary.Bounds.Left >= Disclosure.Marker.Right, 'the summary starts after the triangle');
  Assert.IsTrue(Disclosure.Bounds.Contains(TLayoutPointF.Create(Summary.Bounds.Left + 1, Summary.Bounds.Top + 1)),
    'the clickable line covers the summary');
end;

procedure TMarkdownDisclosureTests.Layout_ClosedSectionInBlockQuote_HidesContent;
begin
  const DisplayList = LayoutMarkdown('> <details>'#10'> <summary>' + SummaryText + '</summary>'#10'>'#10'> ' +
    ContentText + #10'>'#10'> </details>');

  const Disclosures = DisclosuresOf(DisplayList);
  Assert.IsTrue(TMarkdownTestDisplayListHelpers.ShowsText(DisplayList, SummaryText));
  Assert.IsFalse(TMarkdownTestDisplayListHelpers.ShowsText(DisplayList, ContentText));
  Assert.AreEqual(1, Integer(Length(Disclosures)));
end;

procedure TMarkdownDisclosureTests.Layout_ClosedSectionInListItem_HidesContent;
begin
  const DisplayList = LayoutMarkdown('- <details>'#10'  <summary>' + SummaryText + '</summary>'#10#10'  ' + ContentText +
    #10#10'  </details>');

  const Disclosures = DisclosuresOf(DisplayList);
  Assert.IsTrue(TMarkdownTestDisplayListHelpers.ShowsText(DisplayList, SummaryText));
  Assert.IsFalse(TMarkdownTestDisplayListHelpers.ShowsText(DisplayList, ContentText));
  Assert.AreEqual(1, Integer(Length(Disclosures)));
end;

procedure TMarkdownDisclosureTests.Layout_WholeSectionInOneBlock_ShowsEverythingWithoutDisclosure;
begin
  const DisplayList = LayoutMarkdown('<details><summary>' + SummaryText + '</summary><p>' + ContentText +
    '</p></details>');

  const Disclosures = DisclosuresOf(DisplayList);
  Assert.IsTrue(TMarkdownTestDisplayListHelpers.ShowsText(DisplayList, SummaryText));
  Assert.IsTrue(TMarkdownTestDisplayListHelpers.ShowsText(DisplayList, ContentText));
  Assert.AreEqual(0, Integer(Length(Disclosures)));
end;

procedure TMarkdownDisclosureTests.Layout_ClosedSection_KeepsOneBlockInfoPerChild;
begin
  const DisplayList = LayoutMarkdown(ClosedSection);

  Assert.AreEqual(3, DisplayList.BlockCount);
  Assert.AreEqual(0.0, DisplayList.BlockInfos[1].Height, SingleTolerance, 'a hidden block takes no room');
end;

procedure TMarkdownDisclosureTests.TryFindDisclosure_PointOnSummaryLine_ReturnsDisclosure;
begin
  const DisplayList = LayoutMarkdown(ClosedSection);

  var Disclosure: IDisplayDisclosure;
  const Found = TMarkdownHitTester.TryFindDisclosure(DisplayList, TLayoutPointF.Create(DefaultWidth / 2, SummaryLineY),
    Disclosure);

  Assert.IsTrue(Found);
  Assert.IsFalse(Disclosure.IsOpen);
end;

procedure TMarkdownDisclosureTests.TryFindDisclosure_PointBelowSummary_ReturnsFalse;
begin
  const DisplayList = LayoutMarkdown(OpenSection);

  var Disclosure: IDisplayDisclosure;
  const Found = TMarkdownHitTester.TryFindDisclosure(DisplayList, TLayoutPointF.Create(DefaultWidth / 2, MissY),
    Disclosure);

  Assert.IsFalse(Found);
end;

class function TMarkdownDisclosureTests.Parse(const Source: string): IMarkdownDocument;
begin
  Result := TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
end;

class function TMarkdownDisclosureTests.CreateTestTheme: TMarkdownTheme;
begin
  Result := TMarkdownTheme.CreateLight;

  Result.BaseFont := TMarkdownFontStyle.Create(BaseFamilyName, BaseFontSize);
  Result.ContentPadding := 0;
end;

class function TMarkdownDisclosureTests.LayoutMarkdown(const Source: string;
  const Disclosures: IMarkdownDisclosureState): IMarkdownDisplayList;
begin
  const Theme = CreateTestTheme;
  try
    const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
    const Measurer: ITextMeasurer = TFakeTextMeasurer.Create;

    Result := TMarkdownLayoutEngine.LayoutDocument(Document, DefaultWidth, Theme, Measurer, nil, nil, Disclosures);
  finally
    Theme.Free;
  end;
end;

class function TMarkdownDisclosureTests.DisclosuresOf(const DisplayList: IMarkdownDisplayList): TArray<IDisplayDisclosure>;
begin
  Result := nil;

  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Disclosure: IDisplayDisclosure;
    if Supports(DisplayList.Items[Index], IDisplayDisclosure, Disclosure) then
      Result := Result + [Disclosure];
  end;
end;

class procedure TMarkdownDisclosureTests.AssertFlags(const Expected: array of Boolean; const Actual: TArray<Boolean>);
begin
  Assert.AreEqual(Length(Expected), Length(Actual), 'one flag per child');

  for var Index := 0 to High(Expected) do
  begin
    Assert.AreEqual(Expected[Index], Actual[Index], Format('flag of child %d', [Index]));
  end;
end;

end.
