unit Markdown4DStudio.Outline.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Toc,
  Markdown4DStudio.Outline;

type
  [TestFixture]
  TPadOutlineBuilderTests = class
  private
    const
      SampleDocument =
        '# Introduction'#10 +
        #10 +
        'Intro text.'#10 +
        #10 +
        '## Getting Started'#10 +
        '# Reference'#10;
    class function BuildToc: IMarkdownToc;

  public
    [Test]
    procedure Build_NestedHeadings_FlattensToDepthFirstOrderWithIndentedCaptions;

    [Test]
    procedure Build_DocumentWithoutHeadings_ReturnsEmptyOutline;

    [Test]
    procedure ActiveIndex_LineBeforeFirstEntry_ReturnsMinusOne;

    [Test]
    procedure ActiveIndex_LineAtOrAfterEntry_ReturnsThatEntryIndex;
  end;

implementation

uses
  Markdown4D;

procedure TPadOutlineBuilderTests.Build_NestedHeadings_FlattensToDepthFirstOrderWithIndentedCaptions;
begin
  const Outline = TPadOutlineBuilder.Build(BuildToc);

  Assert.AreEqual(3, Integer(Length(Outline.Entries)));
  Assert.AreEqual('Introduction', Outline.Captions[0]);
  Assert.AreEqual('  Getting Started', Outline.Captions[1]);
  Assert.AreEqual('Reference', Outline.Captions[2]);
end;

procedure TPadOutlineBuilderTests.Build_DocumentWithoutHeadings_ReturnsEmptyOutline;
begin
  const Document = TMarkdown.Parse('plain paragraph, no headings');
  const Toc = TMarkdownToc.FromDocument(Document);

  const Outline = TPadOutlineBuilder.Build(Toc);

  Assert.AreEqual(0, Integer(Length(Outline.Entries)));
  Assert.AreEqual(0, Integer(Length(Outline.Captions)));
end;

procedure TPadOutlineBuilderTests.ActiveIndex_LineBeforeFirstEntry_ReturnsMinusOne;
begin
  const Outline = TPadOutlineBuilder.Build(BuildToc);

  Assert.AreEqual(-1, TPadOutlineBuilder.ActiveIndex(Outline.Entries, -1));
end;

procedure TPadOutlineBuilderTests.ActiveIndex_LineAtOrAfterEntry_ReturnsThatEntryIndex;
begin
  const Outline = TPadOutlineBuilder.Build(BuildToc);

  Assert.AreEqual(0, TPadOutlineBuilder.ActiveIndex(Outline.Entries, 0));
  Assert.AreEqual(1, TPadOutlineBuilder.ActiveIndex(Outline.Entries, 4));
  Assert.AreEqual(2, TPadOutlineBuilder.ActiveIndex(Outline.Entries, 5));
end;

class function TPadOutlineBuilderTests.BuildToc: IMarkdownToc;
begin
  const Document = TMarkdown.Parse(SampleDocument);

  Result := TMarkdownToc.FromDocument(Document);
end;

end.
