unit Markdown4D.Extensions.Toc.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces;

type
  [TestFixture]
  TTocExtensionTests = class
  private
    const
      Headings = '# One'#10#10'## Two';
    class function FirstParagraphContents(const Markdown: string; out Contents: IMarkdownNode): Boolean; static;
    class function LinkOf(const Item: IMarkdownNode): IMarkdownLink; static;

  public
    [Test]
    [TestCase('Underscores', '[[_TOC_]]')]
    [TestCase('Short', '[TOC]')]
    procedure Parse_TocMarker_StandsInAListOfLinksToTheHeadings(const Marker: string);

    [Test]
    procedure Parse_MarkerInsideText_AttachesNothing;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Extensions.Toc;

procedure TTocExtensionTests.Parse_TocMarker_StandsInAListOfLinksToTheHeadings(const Marker: string);
begin
  var Contents: IMarkdownNode;
  const IsMarker = FirstParagraphContents(Marker + #10#10 + Headings, Contents);

  Assert.IsTrue(IsMarker);
  Assert.AreEqual(TMarkdownNodeKind.List, Contents.Kind);
  const OneItem = Contents.Children[0];
  Assert.AreEqual('#one', LinkOf(OneItem).Destination);

  const NestedList = OneItem.Children[1];
  Assert.AreEqual('#two', LinkOf(NestedList.Children[0]).Destination);
end;

procedure TTocExtensionTests.Parse_MarkerInsideText_AttachesNothing;
begin
  var Contents: IMarkdownNode;
  const IsMarker = FirstParagraphContents('See [TOC] here'#10#10 + Headings, Contents);

  Assert.IsFalse(IsMarker);
end;

class function TTocExtensionTests.FirstParagraphContents(const Markdown: string;
  out Contents: IMarkdownNode): Boolean;
begin
  const Document = TMarkdown.Parse(Markdown, TMarkdownDialect.Gfm);
  Result := TMarkdownTocMarkers.TryGetContents(Document.Children[0], Contents);
end;

// An entry is an item holding a paragraph with the link, and its sub-entries
// as a nested list after it.
class function TTocExtensionTests.LinkOf(const Item: IMarkdownNode): IMarkdownLink;
begin
  const Paragraph = Item.Children[0];
  Result := Paragraph.Children[0] as IMarkdownLink;
end;

end.
