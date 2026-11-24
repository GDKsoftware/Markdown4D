unit Markdown4D.Viewer.NestedSections.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Theme,
  Markdown4D.Viewer.Model;

type
  // The <details> sections in documents that block overrides lay out: boxes,
  // columns, and a box in a list, in a block quote and in another box.
  [TestFixture]
  TViewerNestedSectionTests = class
  private
    type
      // A text, the section opened in it, and an edit after which the viewer
      // lays out again, with what the opened section shows then.
      TSectionEdit = record
        Before: string;
        After: string;
        OpenedSection: Integer;
        ContentAfter: string;
        IsOpenAfter: Boolean;
      end;
    const
      ViewportWidth = 480.0;
      ViewportHeight = 360.0;
      FirstContent = 'First';
      SecondContent = 'Second';
      OutsideContent = 'Outside';
      AddedBoxContent = 'Added';
      TrailingParagraph = 'Trailing';
      LeadingParagraph = 'Leading';
      TypedText = 'typed';
      ThirdContent = 'Third';
      OuterSummary = 'Outer';
      PlainCodeBlock = '```'#10'code'#10'```';
      OuterBoxFence = '````';
      AddedHtmlBlock = '<div>Added</div>';
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
    function NewModel(const Text: string): TMarkdownViewerModel;
    procedure AssertLaysOutAsAFullLayout(const Model: TMarkdownViewerModel);
    class function Section(const Content: string): string; static;
    class function Box(const Content: string): string; static;
    class function OneBlockSection(const Content: string): string; static;
    class function PlainBox(const Content: string): string; static;
    class function HtmlBox(const Content: string): string; static;
    class function Joined(const Values: TArray<Integer>): string; static;
    class function Blocks(const Parts: array of string): string; static;
    class function Prefixed(const Text, FirstPrefix, Prefix: string): string; static;
    class function ListItem(const Text: string): string; static;
    class function Quoted(const Text: string): string; static;
    class function Edit(const Scenario: Integer): TSectionEdit; static;
    class function EditOf(const Before, After: string; const OpenedSection: Integer; const ContentAfter: string;
      const IsOpenAfter: Boolean): TSectionEdit; static;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure LayoutNested_SectionToggledInTheViewer_Opens;

    [Test]
    procedure LayoutNested_SectionWithTheSummaryOfOneOutside_OpensOnItsOwn;

    [Test]
    procedure LayoutNested_SameSectionInTwoBoxes_HasTwoKeys;

    [Test]
    procedure LayoutNested_SameSectionInTwoColumnsOfOneBlock_OpensOnItsOwn;

    // The content of an HTML block is parsed apart, so its blocks start at
    // offset 0 just like the first block of the document.
    [Test]
    procedure LayoutNested_BoxesInTheDocumentAndInHtmlBlocks_OpenOnTheirOwn;

    [Test]
    procedure Edit_BoxAddedBeforeAnOpenSectionWithBoxes_LaysOutUpToTheLastBox;

    // An edit only looks for moved boxes after the changed blocks when one of
    // those blocks laid out a document of its own.
    [Test]
    procedure HoldsHostsFrom_AfterALayout_FindsOnlyTheBlocksThatLaidOutABox;

    [Test]
    procedure RecordNestedScope_BlockOfAnotherDocument_RaisesMarkdownError;

    // The sections of the edited text laid out from scratch with the same
    // sections opened: same keys, same text, and the opened section open or
    // closed as IsOpenAfter says.
    [Test]
    [TestCase('BoxAddedBeforeTheBox', '0')]
    [TestCase('CodeBlockAddedBeforeTheBox', '1')]
    [TestCase('BoxRemovedBeforeTheBox', '2')]
    [TestCase('BoxAddedBeforeABoxInAList', '3')]
    [TestCase('BoxAddedBeforeABoxInAQuote', '4')]
    [TestCase('BoxAddedBeforeABoxInABox', '5')]
    [TestCase('BoxAddedBeforeColumns', '6')]
    [TestCase('TextTypedBeforeTheBox', '7')]
    [TestCase('TextTypedInsideTheBox', '8')]
    [TestCase('HtmlBlockAddedBeforeABoxInHtml', '9')]
    [TestCase('BoxAddedBeforeABoxInHtml', '10')]
    [TestCase('PlainBoxAddedBeforeAPlainBox', '11')]
    procedure Edit_AfterOpeningANestedSection_LaysOutAsAFullLayout(const Scenario: Integer);
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.Disclosure,
  Markdown4D.Layout.NestedScope,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Tests.BoxOverride,
  Markdown4D.Tests.ColumnsOverride,
  Markdown4D.Tests.DisplayList.Helpers;

procedure TViewerNestedSectionTests.Setup;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FTheme.ContentPadding := 0;
  FMeasurer := TFakeTextMeasurer.Create;
  TMarkdownLayoutEngine.RegisterBlockOverride(TBoxBlockOverride.Create, TBoxBlockOverride.Priority);
  TMarkdownLayoutEngine.RegisterBlockOverride(TBoxBlockOverride.Create(''), TBoxBlockOverride.Priority);
  TMarkdownLayoutEngine.RegisterBlockOverride(TColumnsBlockOverride.Create, TColumnsBlockOverride.Priority);
end;

procedure TViewerNestedSectionTests.TearDown;
begin
  TMarkdownLayoutEngine.ClearBlockOverrides;
  FMeasurer := nil;
  FTheme.Free;
end;

function TViewerNestedSectionTests.NewModel(const Text: string): TMarkdownViewerModel;
begin
  Result := TMarkdownViewerModel.Create(FTheme, FMeasurer);
  Result.SetViewport(ViewportWidth, ViewportHeight);
  Result.Text := Text;
end;

procedure TViewerNestedSectionTests.AssertLaysOutAsAFullLayout(const Model: TMarkdownViewerModel);
begin
  const Full = NewModel(Model.Text);
  try
    Full.ToggledDisclosures := Model.ToggledDisclosures;

    const Keys = TMarkdownTestDisplayListHelpers.DisclosureKeys(Model.DisplayList);
    const FullKeys = TMarkdownTestDisplayListHelpers.DisclosureKeys(Full.DisplayList);
    Assert.AreEqual(Integer(Length(FullKeys)), Integer(Length(Keys)), 'sections');
    for var Index := 0 to High(FullKeys) do
    begin
      Assert.AreEqual(FullKeys[Index], Keys[Index], Format('key of section %d', [Index]));
    end;

    const Runs = TMarkdownTestDisplayListHelpers.TextRuns(Model.DisplayList);
    const FullRuns = TMarkdownTestDisplayListHelpers.TextRuns(Full.DisplayList);
    Assert.AreEqual(string.Join('|', FullRuns), string.Join('|', Runs), 'text shown');
  finally
    Full.Free;
  end;
end;

class function TViewerNestedSectionTests.Section(const Content: string): string;
begin
  Result := Format('<details>'#10'<summary>More</summary>'#10#10'%s'#10#10'</details>', [Content]);
end;

class function TViewerNestedSectionTests.Box(const Content: string): string;
begin
  Result := TBoxBlockOverride.Markdown(Content);
end;

// A section written as one HTML block, so it fits in a <pre>.
class function TViewerNestedSectionTests.OneBlockSection(const Content: string): string;
begin
  Result := Format('<details><summary>More</summary>%s</details>', [Content]);
end;

class function TViewerNestedSectionTests.PlainBox(const Content: string): string;
begin
  Result := Format('%s'#10'%s'#10'%s', [TBoxBlockOverride.DefaultFence, Content, TBoxBlockOverride.DefaultFence]);
end;

// The <pre> in the HTML block becomes a fence without an info string.
class function TViewerNestedSectionTests.HtmlBox(const Content: string): string;
begin
  const OpenersEscaped = Content.Replace('<', '&lt;', [rfReplaceAll]);
  const Escaped = OpenersEscaped.Replace('>', '&gt;', [rfReplaceAll]);
  Result := Format('<div><pre>%s</pre></div>', [Escaped]);
end;

class function TViewerNestedSectionTests.Joined(const Values: TArray<Integer>): string;
begin
  var Texts: TArray<string>;
  SetLength(Texts, Length(Values));
  for var Index := 0 to High(Values) do
  begin
    Texts[Index] := Values[Index].ToString;
  end;

  Result := string.Join(',', Texts);
end;

class function TViewerNestedSectionTests.Blocks(const Parts: array of string): string;
begin
  Result := string.Join(#10#10, Parts);
end;

class function TViewerNestedSectionTests.Prefixed(const Text, FirstPrefix, Prefix: string): string;
begin
  var Lines := Text.Split([#10]);
  for var Index := 0 to High(Lines) do
  begin
    const IsFirst = (Index = 0);
    if IsFirst then
      Lines[Index] := Format('%s%s', [FirstPrefix, Lines[Index]])
    else
      Lines[Index] := Format('%s%s', [Prefix, Lines[Index]]);
  end;

  Result := string.Join(#10, Lines);
end;

class function TViewerNestedSectionTests.ListItem(const Text: string): string;
begin
  Result := Prefixed(Text, '- ', '  ');
end;

class function TViewerNestedSectionTests.Quoted(const Text: string): string;
begin
  Result := Prefixed(Text, '> ', '> ');
end;

class function TViewerNestedSectionTests.EditOf(const Before, After: string; const OpenedSection: Integer;
  const ContentAfter: string; const IsOpenAfter: Boolean): TSectionEdit;
begin
  Result.Before        := Before;
  Result.After         := After;
  Result.OpenedSection := OpenedSection;
  Result.ContentAfter  := ContentAfter;
  Result.IsOpenAfter   := IsOpenAfter;
end;

// A box added or removed before a box makes it another box, which gives its
// sections other keys, as a layout from scratch does; any other block before
// it, or text typed inside it, keeps them.
class function TViewerNestedSectionTests.Edit(const Scenario: Integer): TSectionEdit;
begin
  const FirstBox = Box(Section(FirstContent));
  const SecondBox = Box(Section(SecondContent));
  const AddedBox = Box(AddedBoxContent);
  const FirstInList = ListItem(FirstBox);
  const FirstInQuote = Quoted(FirstBox);
  const FirstInBox = TBoxBlockOverride.Markdown(FirstBox, OuterBoxFence);
  const Columns = TColumnsBlockOverride.Markdown(Section(FirstContent), Section(SecondContent));
  const TypedContent = Format('%s %s', [FirstContent, TypedText]);
  const TypedParagraph = Format('%s %s', [LeadingParagraph, TypedText]);
  const FirstInHtml = HtmlBox(OneBlockSection(FirstContent));
  const FirstInPlainBox = PlainBox(OneBlockSection(FirstContent));

  case Scenario of
    0: Result := EditOf(Blocks([FirstBox, SecondBox, TrailingParagraph]),
                        Blocks([AddedBox, FirstBox, SecondBox, TrailingParagraph]), 0, FirstContent, False);
    1: Result := EditOf(Blocks([FirstBox, TrailingParagraph]),
                        Blocks([PlainCodeBlock, FirstBox, TrailingParagraph]), 0, FirstContent, True);
    2: Result := EditOf(Blocks([AddedBox, FirstBox, SecondBox, TrailingParagraph]),
                        Blocks([FirstBox, SecondBox, TrailingParagraph]), 0, FirstContent, False);
    3: Result := EditOf(Blocks([FirstInList, TrailingParagraph]),
                        Blocks([AddedBox, FirstInList, TrailingParagraph]), 0, FirstContent, False);
    4: Result := EditOf(Blocks([FirstInQuote, TrailingParagraph]),
                        Blocks([AddedBox, FirstInQuote, TrailingParagraph]), 0, FirstContent, False);
    5: Result := EditOf(Blocks([FirstInBox, TrailingParagraph]),
                        Blocks([AddedBox, FirstInBox, TrailingParagraph]), 0, FirstContent, False);
    6: Result := EditOf(Blocks([Columns, TrailingParagraph]),
                        Blocks([AddedBox, Columns, TrailingParagraph]), 0, FirstContent, True);
    7: Result := EditOf(Blocks([LeadingParagraph, FirstBox, TrailingParagraph]),
                        Blocks([TypedParagraph, FirstBox, TrailingParagraph]), 0, FirstContent, True);
    8: Result := EditOf(Blocks([LeadingParagraph, FirstBox, TrailingParagraph]),
                        Blocks([LeadingParagraph, Box(Section(TypedContent)), TrailingParagraph]), 0, TypedContent,
                        True);
    9: Result := EditOf(Blocks([FirstInHtml, TrailingParagraph]),
                        Blocks([AddedHtmlBlock, FirstInHtml, TrailingParagraph]), 0, FirstContent, False);
    10: Result := EditOf(Blocks([FirstInHtml, TrailingParagraph]),
                         Blocks([AddedBox, FirstInHtml, TrailingParagraph]), 0, FirstContent, True);
    11: Result := EditOf(Blocks([FirstInPlainBox, TrailingParagraph]),
                         Blocks([PlainBox(AddedBoxContent), FirstInPlainBox, TrailingParagraph]), 0, FirstContent,
                         False);
  else
    raise EArgumentOutOfRangeException.CreateFmt('Unknown edit scenario: %d', [Scenario]);
  end;
end;

procedure TViewerNestedSectionTests.LayoutNested_SectionToggledInTheViewer_Opens;
begin
  const Model = NewModel(Box(Section(FirstContent)));
  try
    const Keys = TMarkdownTestDisplayListHelpers.DisclosureKeys(Model.DisplayList);
    Assert.AreEqual(1, Integer(Length(Keys)), 'the section in the box');

    Model.ToggleDisclosure(Keys[0]);

    Assert.IsTrue(TMarkdownTestDisplayListHelpers.ShowsText(Model.DisplayList, FirstContent));
  finally
    Model.Free;
  end;
end;

// Sections get their keys from their summary, so without a key of its own the
// section in the box would open and close with the one outside it.
procedure TViewerNestedSectionTests.LayoutNested_SectionWithTheSummaryOfOneOutside_OpensOnItsOwn;
begin
  const Model = NewModel(Blocks([Section(OutsideContent), Box(Section(FirstContent))]));
  try
    const Keys = TMarkdownTestDisplayListHelpers.DisclosureKeys(Model.DisplayList);
    Assert.AreEqual(2, Integer(Length(Keys)), 'the section outside and the one in the box');
    Assert.AreNotEqual(Keys[0], Keys[1]);

    Model.ToggleDisclosure(Keys[1]);

    Assert.IsTrue(TMarkdownTestDisplayListHelpers.ShowsText(Model.DisplayList, FirstContent), 'the box opened');
    Assert.IsFalse(TMarkdownTestDisplayListHelpers.ShowsText(Model.DisplayList, OutsideContent), 'outside closed');
  finally
    Model.Free;
  end;
end;

procedure TViewerNestedSectionTests.LayoutNested_SameSectionInTwoBoxes_HasTwoKeys;
begin
  const FirstBox = Box(Section(FirstContent));
  const Model = NewModel(Blocks([FirstBox, FirstBox]));
  try
    const Keys = TMarkdownTestDisplayListHelpers.DisclosureKeys(Model.DisplayList);

    Assert.AreEqual(2, Integer(Length(Keys)), 'a section in each box');
    Assert.AreNotEqual(Keys[0], Keys[1]);
  finally
    Model.Free;
  end;
end;

procedure TViewerNestedSectionTests.LayoutNested_SameSectionInTwoColumnsOfOneBlock_OpensOnItsOwn;
begin
  const Model = NewModel(TColumnsBlockOverride.Markdown(Section(FirstContent), Section(SecondContent)));
  try
    const Keys = TMarkdownTestDisplayListHelpers.DisclosureKeys(Model.DisplayList);
    Assert.AreEqual(2, Integer(Length(Keys)), 'a section in each column');
    Assert.AreNotEqual(Keys[0], Keys[1]);

    Model.ToggleDisclosure(Keys[0]);

    Assert.IsTrue(TMarkdownTestDisplayListHelpers.ShowsText(Model.DisplayList, FirstContent), 'first column open');
    Assert.IsFalse(TMarkdownTestDisplayListHelpers.ShowsText(Model.DisplayList, SecondContent), 'second closed');
  finally
    Model.Free;
  end;
end;

procedure TViewerNestedSectionTests.LayoutNested_BoxesInTheDocumentAndInHtmlBlocks_OpenOnTheirOwn;
begin
  const FirstBox = PlainBox(OneBlockSection(FirstContent));
  const SecondBox = HtmlBox(OneBlockSection(SecondContent));
  const ThirdBox = HtmlBox(OneBlockSection(ThirdContent));
  const Model = NewModel(Blocks([FirstBox, SecondBox, ThirdBox]));
  try
    const Keys = TMarkdownTestDisplayListHelpers.DisclosureKeys(Model.DisplayList);
    Assert.AreEqual(3, Integer(Length(Keys)), 'a section in each box');
    Assert.AreNotEqual(Keys[0], Keys[1]);
    Assert.AreNotEqual(Keys[1], Keys[2]);
    Assert.AreNotEqual(Keys[0], Keys[2]);

    Model.ToggleDisclosure(Keys[1]);

    Assert.IsFalse(TMarkdownTestDisplayListHelpers.ShowsText(Model.DisplayList, FirstContent), 'first closed');
    Assert.IsTrue(TMarkdownTestDisplayListHelpers.ShowsText(Model.DisplayList, SecondContent), 'second open');
    Assert.IsFalse(TMarkdownTestDisplayListHelpers.ShowsText(Model.DisplayList, ThirdContent), 'third closed');
  finally
    Model.Free;
  end;
end;

// Only the added box and the blocks up to the last box after it are laid out
// again; the blocks after that box are reused.
procedure TViewerNestedSectionTests.Edit_BoxAddedBeforeAnOpenSectionWithBoxes_LaysOutUpToTheLastBox;
begin
  const Opener = Format('<details>'#10'<summary>%s</summary>', [OuterSummary]);
  const Closer = '</details>';
  const FirstBox = Box(Section(FirstContent));
  const SecondBox = Box(Section(SecondContent));
  const Body = TArray<string>.Create(Opener, LeadingParagraph, FirstBox, SecondBox, Closer, TrailingParagraph,
    TypedText);
  const Model = NewModel(Blocks(Body));
  try
    const Keys = TMarkdownTestDisplayListHelpers.DisclosureKeys(Model.DisplayList);
    Assert.AreEqual(1, Integer(Length(Keys)), 'only the outer section shows while it is closed');
    Model.ToggleDisclosure(Keys[0]);

    Model.Text := Blocks([Box(AddedBoxContent)]) + #10#10 + Blocks(Body);

    const Recomputed = Model.DisplayList.RecomputedBlockIndexes;
    Assert.AreEqual('0,1,2,3,4', Joined(Recomputed), 'up to the second box');
    AssertLaysOutAsAFullLayout(Model);
  finally
    Model.Free;
  end;
end;

procedure TViewerNestedSectionTests.Edit_AfterOpeningANestedSection_LaysOutAsAFullLayout(const Scenario: Integer);
begin
  const SectionEdit = Edit(Scenario);
  const Model = NewModel(SectionEdit.Before);
  try
    const Keys = TMarkdownTestDisplayListHelpers.DisclosureKeys(Model.DisplayList);
    const HasOpenedSection = (SectionEdit.OpenedSection < Length(Keys));
    Assert.IsTrue(HasOpenedSection, 'the section to open is laid out');
    Model.ToggleDisclosure(Keys[SectionEdit.OpenedSection]);

    Model.Text := SectionEdit.After;

    const RecomputedCount = Length(Model.DisplayList.RecomputedBlockIndexes);
    Assert.IsTrue(RecomputedCount < Model.DisplayList.BlockCount, 'laid out incrementally');
    const IsOpen = TMarkdownTestDisplayListHelpers.ShowsText(Model.DisplayList, SectionEdit.ContentAfter);
    Assert.AreEqual(SectionEdit.IsOpenAfter, IsOpen, 'the opened section');
    AssertLaysOutAsAFullLayout(Model);
  finally
    Model.Free;
  end;
end;

procedure TViewerNestedSectionTests.HoldsHostsFrom_AfterALayout_FindsOnlyTheBlocksThatLaidOutABox;
begin
  const UnhandledCode = '```text'#10'code'#10'```';
  const Text = Blocks([LeadingParagraph, Box(Section(FirstContent)), UnhandledCode, TrailingParagraph]);
  const Document = TMarkdown.Parse(Text, TMarkdownDialect.Gfm);

  TMarkdownLayoutEngine.LayoutDocument(Document, ViewportWidth, FTheme, FMeasurer);

  Assert.IsTrue(TMarkdownNestedScopes.HoldsHostsFrom(Document, 0), 'from the start');
  Assert.IsTrue(TMarkdownNestedScopes.HoldsHostsFrom(Document, 1), 'from the box');
  Assert.IsFalse(TMarkdownNestedScopes.HoldsHostsFrom(Document, 2), 'after the box');
end;

procedure TViewerNestedSectionTests.RecordNestedScope_BlockOfAnotherDocument_RaisesMarkdownError;
begin
  const Document = TMarkdown.Parse(LeadingParagraph, TMarkdownDialect.Gfm);
  const Other = TMarkdown.Parse(TrailingParagraph, TMarkdownDialect.Gfm);
  const Scopes = TMarkdownNestedScopes.Create(Document, TMarkdownDisclosures.DocumentScope);
  try
    Assert.WillRaise(
      procedure
      begin
        Scopes.RecordNestedScope(Other.Children[0], 1);
      end,
      EMarkdownError);
  finally
    Scopes.Free;
  end;
end;

end.
