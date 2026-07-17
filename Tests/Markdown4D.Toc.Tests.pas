unit Markdown4D.Toc.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Toc;

type
  [TestFixture]
  TMarkdownTocTests = class
  private
    const
      SampleDocument =
        '# Introduction'#10 +
        #10 +
        'Intro text.'#10 +
        #10 +
        '## Getting *Started*'#10 +
        '### Details'#10 +
        '## Getting *Started*'#10 +
        '# Reference'#10 +
        '## Getting *Started*'#10;
      GettingStartedCaption = 'Getting Started';
    class function BuildToc: IMarkdownToc;

  public
    [Test]
    procedure FromDocument_SampleDocument_BuildsNestedHeadingTree;

    [Test]
    procedure FromDocument_HeadingWithEmphasis_StripsInlineFormattingFromCaption;

    [Test]
    procedure FromDocument_Headings_GeneratesLowercaseHyphenatedAnchors;

    [Test]
    procedure FromDocument_DuplicateHeadings_AppendsNumericSuffixesToAnchors;

    [Test]
    procedure FromDocument_Headings_ReportsSourceLines;
  end;

implementation

uses
  Markdown4D;

procedure TMarkdownTocTests.FromDocument_SampleDocument_BuildsNestedHeadingTree;
begin
  const Toc = BuildToc;

  Assert.AreEqual(2, Toc.EntryCount);

  const Introduction = Toc.Entries[0];
  Assert.AreEqual('Introduction', Introduction.Caption);
  Assert.AreEqual(1, Introduction.Level);
  Assert.AreEqual(2, Introduction.ChildCount);

  const FirstGettingStarted = Introduction.Children[0];
  Assert.AreEqual(2, FirstGettingStarted.Level);
  Assert.AreEqual(1, FirstGettingStarted.ChildCount);

  const Details = FirstGettingStarted.Children[0];
  Assert.AreEqual('Details', Details.Caption);
  Assert.AreEqual(3, Details.Level);
  Assert.AreEqual(0, Details.ChildCount);

  const Reference = Toc.Entries[1];
  Assert.AreEqual('Reference', Reference.Caption);
  Assert.AreEqual(1, Reference.Level);
  Assert.AreEqual(1, Reference.ChildCount);
end;

procedure TMarkdownTocTests.FromDocument_HeadingWithEmphasis_StripsInlineFormattingFromCaption;
begin
  const Toc = BuildToc;

  const Introduction = Toc.Entries[0];
  const FirstGettingStarted = Introduction.Children[0];
  Assert.AreEqual(GettingStartedCaption, FirstGettingStarted.Caption);

  const SecondGettingStarted = Introduction.Children[1];
  Assert.AreEqual(GettingStartedCaption, SecondGettingStarted.Caption);
end;

procedure TMarkdownTocTests.FromDocument_Headings_GeneratesLowercaseHyphenatedAnchors;
begin
  const Toc = BuildToc;

  const Introduction = Toc.Entries[0];
  Assert.AreEqual('introduction', Introduction.Anchor);

  const FirstGettingStarted = Introduction.Children[0];
  const Details = FirstGettingStarted.Children[0];
  Assert.AreEqual('details', Details.Anchor);

  const Reference = Toc.Entries[1];
  Assert.AreEqual('reference', Reference.Anchor);
end;

procedure TMarkdownTocTests.FromDocument_DuplicateHeadings_AppendsNumericSuffixesToAnchors;
begin
  const Toc = BuildToc;

  const Introduction = Toc.Entries[0];
  Assert.AreEqual('getting-started', Introduction.Children[0].Anchor);
  Assert.AreEqual('getting-started-1', Introduction.Children[1].Anchor);

  const Reference = Toc.Entries[1];
  Assert.AreEqual('getting-started-2', Reference.Children[0].Anchor);
end;

procedure TMarkdownTocTests.FromDocument_Headings_ReportsSourceLines;
begin
  const Toc = BuildToc;

  const Introduction = Toc.Entries[0];
  Assert.AreEqual(1, Introduction.SourceLine);

  const FirstGettingStarted = Introduction.Children[0];
  Assert.AreEqual(5, FirstGettingStarted.SourceLine);
  Assert.AreEqual(6, FirstGettingStarted.Children[0].SourceLine);
  Assert.AreEqual(7, Introduction.Children[1].SourceLine);

  const Reference = Toc.Entries[1];
  Assert.AreEqual(8, Reference.SourceLine);
  Assert.AreEqual(9, Reference.Children[0].SourceLine);
end;

class function TMarkdownTocTests.BuildToc: IMarkdownToc;
begin
  const Document = TMarkdown.Parse(SampleDocument);

  Result := TMarkdownToc.FromDocument(Document);
end;

end.
