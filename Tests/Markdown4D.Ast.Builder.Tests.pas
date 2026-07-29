unit Markdown4D.Ast.Builder.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Ast.Builder;

type
  [TestFixture]
  TMarkdownAstBuilderTests = class
  private
    const
      DeepNestingDepth = 100;
    class function RoundTripHtml(const Document: IMarkdownDocument;
                                 const Dialect: TMarkdownDialect = TMarkdownDialect.CommonMark): string;

  public
    [Test]
    procedure Build_Headings_RenderAtxHeadingHtml;

    [Test]
    procedure Build_HeadingWithStyledCaption_RendersInlineFormatting;

    [Test]
    procedure Build_ParagraphWithBoldAndItalic_RendersStrongAndEmphasis;

    [Test]
    procedure Build_BoldNestedInsideItalic_RendersNestedEmphasis;

    [Test]
    procedure Build_CodeSpanContainingMarkdownDelimiters_RendersLiteralCode;

    [Test]
    procedure Build_LinkWithTitle_RendersAnchorWithTitle;

    [Test]
    procedure Build_LinkWithStyledCaption_RendersAnchorWithInlineContent;

    [Test]
    procedure Build_ImageWithTitle_RendersImgTag;

    [Test]
    procedure Build_HardLineBreak_RendersBrTag;

    [Test]
    procedure Build_SoftLineBreak_RendersLineEnding;

    [Test]
    procedure Build_TightBulletList_RendersItemsWithoutParagraphs;

    [Test]
    procedure Build_LooseBulletList_RendersItemsWithParagraphs;

    [Test]
    procedure Build_OrderedListWithStartNumber_RendersStartAttribute;

    [Test]
    procedure Build_NestedBulletList_RendersSublistInsideItem;

    [Test]
    procedure Build_BlockQuoteWithParagraph_RendersBlockQuote;

    [Test]
    procedure Build_FencedCodeBlockWithInfoString_RendersLanguageClass;

    [Test]
    procedure Build_CodeBlockWithoutTrailingNewline_NormalizesTrailingLineEnding;

    [Test]
    procedure Build_ThematicBreakBetweenParagraphs_RendersHrTag;

    [Test]
    procedure Build_TableWithAlignments_RendersHeadAndBody;

    [Test]
    procedure Build_TableWithStyledCell_RendersInlineContentInCell;

    [Test]
    procedure Build_Strikethrough_RendersDelTag;

    [Test]
    procedure Build_TaskListItems_RenderCheckboxInputs;

    [Test]
    procedure Build_TextWithEmphasisMarkers_EscapesAsterisksAndUnderscores;

    [Test]
    procedure Build_TextWithBracketsAndParentheses_DoesNotCreateLink;

    [Test]
    procedure Build_TextWithBackticks_DoesNotCreateCodeSpan;

    [Test]
    procedure Build_TextWithLeadingHash_DoesNotCreateHeading;

    [Test]
    procedure Build_TextWithLeadingGreaterThan_DoesNotCreateBlockQuote;

    [Test]
    procedure Build_EmptyDocument_WritesEmptyMarkdownAndHtml;

    [Test]
    procedure Build_HundredNestedBlockQuotes_RendersEveryLevel;
  end;

implementation

uses
  Markdown4D.Parser.Spec.Corpus,
  Markdown4D;

procedure TMarkdownAstBuilderTests.Build_Headings_RenderAtxHeadingHtml;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .Heading(1, 'Title')
    .Heading(3, 'Details')
    .Build;

  Assert.AreEqual('<h1>Title</h1>'#10'<h3>Details</h3>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_HeadingWithStyledCaption_RendersInlineFormatting;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginHeading(2)
    .Text('Getting ')
    .Italic('Started')
    .EndHeading
    .Build;

  Assert.AreEqual('<h2>Getting <em>Started</em></h2>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_ParagraphWithBoldAndItalic_RendersStrongAndEmphasis;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginParagraph
    .Text('Hello ')
    .Bold('brave')
    .Text(' new ')
    .Italic('world')
    .EndParagraph
    .Build;

  Assert.AreEqual('<p>Hello <strong>brave</strong> new <em>world</em></p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_BoldNestedInsideItalic_RendersNestedEmphasis;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginParagraph
    .BeginItalic
    .Text('all ')
    .BeginBold
    .Text('bold')
    .EndBold
    .EndItalic
    .EndParagraph
    .Build;

  Assert.AreEqual('<p><em>all <strong>bold</strong></em></p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_CodeSpanContainingMarkdownDelimiters_RendersLiteralCode;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginParagraph
    .Text('Use ')
    .Code('x := *y* _z_')
    .EndParagraph
    .Build;

  Assert.AreEqual('<p>Use <code>x := *y* _z_</code></p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_LinkWithTitle_RendersAnchorWithTitle;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginParagraph
    .Link('site', 'https://example.com/a', 'The Title')
    .EndParagraph
    .Build;

  Assert.AreEqual('<p><a href="https://example.com/a" title="The Title">site</a></p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_LinkWithStyledCaption_RendersAnchorWithInlineContent;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginParagraph
    .BeginLink('https://example.com')
    .Text('go ')
    .Bold('now')
    .EndLink
    .EndParagraph
    .Build;

  Assert.AreEqual('<p><a href="https://example.com">go <strong>now</strong></a></p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_ImageWithTitle_RendersImgTag;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginParagraph
    .Image('alt text', '/img.png', 'Pic')
    .EndParagraph
    .Build;

  Assert.AreEqual('<p><img src="/img.png" alt="alt text" title="Pic" /></p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_HardLineBreak_RendersBrTag;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginParagraph
    .Text('one')
    .HardLineBreak
    .Text('two')
    .EndParagraph
    .Build;

  Assert.AreEqual('<p>one<br />'#10'two</p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_SoftLineBreak_RendersLineEnding;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginParagraph
    .Text('one')
    .SoftLineBreak
    .Text('two')
    .EndParagraph
    .Build;

  Assert.AreEqual('<p>one'#10'two</p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_TightBulletList_RendersItemsWithoutParagraphs;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginBulletList
    .BeginListItem
    .Paragraph('One')
    .EndListItem
    .BeginListItem
    .Paragraph('Two')
    .EndListItem
    .EndList
    .Build;

  Assert.AreEqual('<ul>'#10'<li>One</li>'#10'<li>Two</li>'#10'</ul>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_LooseBulletList_RendersItemsWithParagraphs;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginBulletList(False)
    .BeginListItem
    .Paragraph('One')
    .EndListItem
    .BeginListItem
    .Paragraph('Two')
    .EndListItem
    .EndList
    .Build;

  Assert.AreEqual('<ul>'#10'<li>'#10'<p>One</p>'#10'</li>'#10'<li>'#10'<p>Two</p>'#10'</li>'#10'</ul>'#10,
    RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_OrderedListWithStartNumber_RendersStartAttribute;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginOrderedList(3)
    .BeginListItem
    .Paragraph('three')
    .EndListItem
    .BeginListItem
    .Paragraph('four')
    .EndListItem
    .EndList
    .Build;

  Assert.AreEqual('<ol start="3">'#10'<li>three</li>'#10'<li>four</li>'#10'</ol>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_NestedBulletList_RendersSublistInsideItem;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginBulletList
    .BeginListItem
    .Paragraph('Parent')
    .BeginBulletList
    .BeginListItem
    .Paragraph('Child')
    .EndListItem
    .EndList
    .EndListItem
    .EndList
    .Build;

  Assert.AreEqual('<ul>'#10'<li>Parent'#10'<ul>'#10'<li>Child</li>'#10'</ul>'#10'</li>'#10'</ul>'#10,
    RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_BlockQuoteWithParagraph_RendersBlockQuote;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginBlockQuote
    .Paragraph('Quoted')
    .EndBlockQuote
    .Build;

  Assert.AreEqual('<blockquote>'#10'<p>Quoted</p>'#10'</blockquote>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_FencedCodeBlockWithInfoString_RendersLanguageClass;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .CodeBlock('writeln(''hi'');'#10'halt;'#10, 'pascal')
    .Build;

  Assert.AreEqual('<pre><code class="language-pascal">writeln(''hi'');'#10'halt;'#10'</code></pre>'#10,
    RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_CodeBlockWithoutTrailingNewline_NormalizesTrailingLineEnding;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .CodeBlock('one'#10'two')
    .Build;

  Assert.AreEqual('<pre><code>one'#10'two'#10'</code></pre>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_ThematicBreakBetweenParagraphs_RendersHrTag;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .Paragraph('above')
    .ThematicBreak
    .Paragraph('below')
    .Build;

  Assert.AreEqual('<p>above</p>'#10'<hr />'#10'<p>below</p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_TableWithAlignments_RendersHeadAndBody;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginTable([TMarkdownTableColumnAlignment.None, TMarkdownTableColumnAlignment.Center])
    .BeginTableRow
    .Cell('Name')
    .Cell('Value')
    .EndTableRow
    .BeginTableRow
    .Cell('left')
    .Cell('mid')
    .EndTableRow
    .EndTable
    .Build;

  Assert.AreEqual('<table>'#10'<thead>'#10'<tr>'#10'<th>Name</th>'#10'<th align="center">Value</th>'#10'</tr>'#10 +
    '</thead>'#10'<tbody>'#10'<tr>'#10'<td>left</td>'#10'<td align="center">mid</td>'#10'</tr>'#10'</tbody>'#10 +
    '</table>'#10, RoundTripHtml(Document, TMarkdownDialect.Gfm));
end;

procedure TMarkdownAstBuilderTests.Build_TableWithStyledCell_RendersInlineContentInCell;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginTable([TMarkdownTableColumnAlignment.None])
    .BeginTableRow
    .Cell('Header')
    .EndTableRow
    .BeginTableRow
    .BeginTableCell
    .Bold('bold')
    .EndTableCell
    .EndTableRow
    .EndTable
    .Build;

  Assert.AreEqual('<table>'#10'<thead>'#10'<tr>'#10'<th>Header</th>'#10'</tr>'#10'</thead>'#10'<tbody>'#10'<tr>'#10 +
    '<td><strong>bold</strong></td>'#10'</tr>'#10'</tbody>'#10'</table>'#10,
    RoundTripHtml(Document, TMarkdownDialect.Gfm));
end;

procedure TMarkdownAstBuilderTests.Build_Strikethrough_RendersDelTag;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginParagraph
    .Text('a ')
    .Strikethrough('gone')
    .Text(' b')
    .EndParagraph
    .Build;

  Assert.AreEqual('<p>a <del>gone</del> b</p>'#10, RoundTripHtml(Document, TMarkdownDialect.Gfm));
end;

procedure TMarkdownAstBuilderTests.Build_TaskListItems_RenderCheckboxInputs;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .BeginBulletList
    .BeginTaskListItem(False)
    .Paragraph('todo')
    .EndListItem
    .BeginTaskListItem(True)
    .Paragraph('done')
    .EndListItem
    .EndList
    .Build;

  Assert.AreEqual('<ul>'#10'<li><input disabled="" type="checkbox"> todo</li>'#10 +
    '<li><input checked="" disabled="" type="checkbox"> done</li>'#10'</ul>'#10,
    RoundTripHtml(Document, TMarkdownDialect.Gfm));
end;

procedure TMarkdownAstBuilderTests.Build_TextWithEmphasisMarkers_EscapesAsterisksAndUnderscores;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .Paragraph('*stars* and _underscores_')
    .Build;

  Assert.AreEqual('<p>*stars* and _underscores_</p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_TextWithBracketsAndParentheses_DoesNotCreateLink;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .Paragraph('[not](a-link)')
    .Build;

  Assert.AreEqual('<p>[not](a-link)</p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_TextWithBackticks_DoesNotCreateCodeSpan;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .Paragraph('a `tick` b')
    .Build;

  Assert.AreEqual('<p>a `tick` b</p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_TextWithLeadingHash_DoesNotCreateHeading;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .Paragraph('# not a heading')
    .Build;

  Assert.AreEqual('<p># not a heading</p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_TextWithLeadingGreaterThan_DoesNotCreateBlockQuote;
begin
  const Document = TMarkdownDocumentBuilder.Create
    .Paragraph('> not a quote')
    .Build;

  Assert.AreEqual('<p>&gt; not a quote</p>'#10, RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_EmptyDocument_WritesEmptyMarkdownAndHtml;
begin
  const Document = TMarkdownDocumentBuilder.Create.Build;

  Assert.AreEqual('', TMarkdown.ToMarkdown(Document));
  Assert.AreEqual('', RoundTripHtml(Document));
end;

procedure TMarkdownAstBuilderTests.Build_HundredNestedBlockQuotes_RendersEveryLevel;
begin
  var Builder := TMarkdownDocumentBuilder.Create;
  for var Level := 1 to DeepNestingDepth do
  begin
    Builder := Builder.BeginBlockQuote;
  end;

  Builder := Builder.Paragraph('Deep');
  for var Level := 1 to DeepNestingDepth do
  begin
    Builder := Builder.EndBlockQuote;
  end;

  var ExpectedHtml := '';
  for var Level := 1 to DeepNestingDepth do
  begin
    ExpectedHtml := ExpectedHtml + '<blockquote>'#10;
  end;
  ExpectedHtml := ExpectedHtml + '<p>Deep</p>'#10;
  for var Level := 1 to DeepNestingDepth do
  begin
    ExpectedHtml := ExpectedHtml + '</blockquote>'#10;
  end;

  Assert.AreEqual(ExpectedHtml, RoundTripHtml(Builder.Build));
end;

class function TMarkdownAstBuilderTests.RoundTripHtml(const Document: IMarkdownDocument;
                                                      const Dialect: TMarkdownDialect): string;
begin
  const Rewritten = TMarkdown.ToMarkdown(Document);

  Result := TSpecCorpus.NormalizeLineEndings(TMarkdown.ToUnsafeHtml(Rewritten, Dialect));
end;

end.
