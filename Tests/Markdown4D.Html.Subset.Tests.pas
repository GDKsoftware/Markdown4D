unit Markdown4D.Html.Subset.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownHtmlSubsetTests = class
  private
    procedure AssertConverts(const Html, Expected: string);
  public
    [Test]
    procedure Convert_PlainText_IsKept;

    [Test]
    procedure Convert_UnknownTag_DropsTagKeepsContent;

    [Test]
    procedure Convert_Script_DropsContentToo;

    [Test]
    procedure Convert_Style_DropsContentToo;

    [Test]
    procedure Convert_Comment_IsDropped;

    [Test]
    procedure Convert_Strong_BecomesDoubleAsterisks;

    [Test]
    procedure Convert_Emphasis_BecomesSingleAsterisk;

    [Test]
    procedure Convert_Code_BecomesBackticks;

    [Test]
    procedure Convert_Strikethrough_BecomesTildes;

    [Test]
    procedure Convert_Image_BecomesImageLink;

    [Test]
    procedure Convert_ImageWithoutSource_IsDropped;

    [Test]
    procedure Convert_Anchor_BecomesLink;

    [Test]
    procedure Convert_AnchorWithoutHref_KeepsTextOnly;

    [Test]
    procedure Convert_Heading_BecomesHashes;

    [Test]
    procedure Convert_HorizontalRule_BecomesThematicBreak;

    [Test]
    procedure Convert_LineBreak_BecomesHardBreak;

    [Test]
    procedure Convert_UnorderedList_BecomesDashes;

    [Test]
    procedure Convert_OrderedList_BecomesNumbers;

    [Test]
    procedure Convert_BlockQuote_BecomesQuotePrefix;

    [Test]
    procedure Convert_Details_PutsSummaryInBold;

    [Test]
    procedure Convert_Preformatted_BecomesFencedBlock;

    [Test]
    procedure Convert_Entities_AreDecoded;

    [Test]
    procedure Convert_MarkdownCharactersInText_AreEscaped;

    [Test]
    procedure Convert_CentredParagraphWithTwoImages_KeepsBoth;

    [Test]
    procedure Convert_UnbalancedTag_DoesNotHang;

    [Test]
    procedure Convert_WhitespaceOnly_ReturnsEmpty;

    [Test]
    procedure IsEmpty_MarkupWithoutContent_IsTrue;

    [Test]
    procedure IsEmpty_MarkupWithContent_IsFalse;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Html.Subset;

procedure TMarkdownHtmlSubsetTests.AssertConverts(const Html, Expected: string);
begin
  Assert.AreEqual(Expected, TMarkdownHtmlSubset.ToMarkdown(Html));
end;

procedure TMarkdownHtmlSubsetTests.Convert_PlainText_IsKept;
begin
  AssertConverts('<p>Hello there</p>', 'Hello there');
end;

procedure TMarkdownHtmlSubsetTests.Convert_UnknownTag_DropsTagKeepsContent;
begin
  AssertConverts('<span class="x">visible</span>', 'visible');
end;

procedure TMarkdownHtmlSubsetTests.Convert_Script_DropsContentToo;
begin
  AssertConverts('<p>before</p><script>alert(1)</script>', 'before');
end;

procedure TMarkdownHtmlSubsetTests.Convert_Style_DropsContentToo;
begin
  AssertConverts('<style>p { color: red }</style><p>after</p>', 'after');
end;

procedure TMarkdownHtmlSubsetTests.Convert_Comment_IsDropped;
begin
  AssertConverts('<!-- badges --><p>text</p>', 'text');
end;

procedure TMarkdownHtmlSubsetTests.Convert_Strong_BecomesDoubleAsterisks;
begin
  AssertConverts('<strong>bold</strong>', '**bold**');
  AssertConverts('<b>bold</b>', '**bold**');
end;

procedure TMarkdownHtmlSubsetTests.Convert_Emphasis_BecomesSingleAsterisk;
begin
  AssertConverts('<em>slanted</em>', '*slanted*');
  AssertConverts('<i>slanted</i>', '*slanted*');
end;

procedure TMarkdownHtmlSubsetTests.Convert_Code_BecomesBackticks;
begin
  AssertConverts('<code>Result</code>', '`Result`');
  AssertConverts('<kbd>Ctrl</kbd>', '`Ctrl`');
end;

procedure TMarkdownHtmlSubsetTests.Convert_Strikethrough_BecomesTildes;
begin
  AssertConverts('<del>gone</del>', '~~gone~~');
end;

procedure TMarkdownHtmlSubsetTests.Convert_Image_BecomesImageLink;
begin
  AssertConverts('<img src="docs/shot.png" alt="A shot">', '![A shot](docs/shot.png)');
end;

procedure TMarkdownHtmlSubsetTests.Convert_ImageWithoutSource_IsDropped;
begin
  AssertConverts('<img alt="nothing">', '');
end;

procedure TMarkdownHtmlSubsetTests.Convert_Anchor_BecomesLink;
begin
  AssertConverts('<a href="https://example.com">the site</a>', '[the site](https://example.com)');
end;

procedure TMarkdownHtmlSubsetTests.Convert_AnchorWithoutHref_KeepsTextOnly;
begin
  AssertConverts('<a name="anchor">label</a>', 'label');
end;

procedure TMarkdownHtmlSubsetTests.Convert_Heading_BecomesHashes;
begin
  AssertConverts('<h2>Title</h2>', '## Title');
  AssertConverts('<h4>Deeper</h4>', '#### Deeper');
end;

procedure TMarkdownHtmlSubsetTests.Convert_HorizontalRule_BecomesThematicBreak;
begin
  AssertConverts('<hr>', '---');
end;

procedure TMarkdownHtmlSubsetTests.Convert_LineBreak_BecomesHardBreak;
begin
  AssertConverts('one<br>two', 'one  ' + sLineBreak + 'two');
end;

procedure TMarkdownHtmlSubsetTests.Convert_UnorderedList_BecomesDashes;
begin
  AssertConverts('<ul><li>first</li><li>second</li></ul>', '- first' + sLineBreak + '- second');
end;

procedure TMarkdownHtmlSubsetTests.Convert_OrderedList_BecomesNumbers;
begin
  AssertConverts('<ol><li>first</li><li>second</li></ol>', '1. first' + sLineBreak + '1. second');
end;

procedure TMarkdownHtmlSubsetTests.Convert_BlockQuote_BecomesQuotePrefix;
begin
  AssertConverts('<blockquote>quoted</blockquote>', '> quoted');
end;

procedure TMarkdownHtmlSubsetTests.Convert_Details_PutsSummaryInBold;
begin
  const Converted = TMarkdownHtmlSubset.ToMarkdown(
    '<details><summary>Show more</summary><p>The hidden part.</p></details>');

  Assert.IsTrue(Converted.Contains('**Show more**'), 'summary should survive in bold: ' + Converted);
  Assert.IsTrue(Converted.Contains('The hidden part.'), 'body should survive: ' + Converted);
end;

procedure TMarkdownHtmlSubsetTests.Convert_Preformatted_BecomesFencedBlock;
begin
  const Converted = TMarkdownHtmlSubset.ToMarkdown('<pre><code>begin'#10'  Run;'#10'end;</code></pre>');

  Assert.IsTrue(Converted.StartsWith('```'), 'should open a fence: ' + Converted);
  Assert.IsTrue(Converted.Contains('  Run;'), 'should keep indentation: ' + Converted);
  Assert.IsTrue(Converted.TrimRight.EndsWith('```'), 'should close the fence: ' + Converted);
end;

procedure TMarkdownHtmlSubsetTests.Convert_Entities_AreDecoded;
begin
  AssertConverts('<p>Tom &amp; Jerry</p>', 'Tom & Jerry');
  AssertConverts('<p>&#65;BC</p>', 'ABC');
end;

procedure TMarkdownHtmlSubsetTests.Convert_MarkdownCharactersInText_AreEscaped;
begin
  // Without escaping the asterisks would turn into emphasis when the result is
  // parsed back.
  AssertConverts('<p>2 * 3 * 4</p>', '2 \* 3 \* 4');
end;

procedure TMarkdownHtmlSubsetTests.Convert_CentredParagraphWithTwoImages_KeepsBoth;
begin
  const Converted = TMarkdownHtmlSubset.ToMarkdown(
    '<p align="center">'#10 +
    '  <img src="light.png" alt="Light" width="49%">'#10 +
    '  <img src="dark.png" alt="Dark" width="49%">'#10 +
    '</p>');

  Assert.IsTrue(Converted.Contains('![Light](light.png)'), Converted);
  Assert.IsTrue(Converted.Contains('![Dark](dark.png)'), Converted);
end;

procedure TMarkdownHtmlSubsetTests.Convert_UnbalancedTag_DoesNotHang;
begin
  AssertConverts('<strong>open and never closed', '**open and never closed**');
  AssertConverts('</em>closing without opening', 'closing without opening');
end;

procedure TMarkdownHtmlSubsetTests.Convert_WhitespaceOnly_ReturnsEmpty;
begin
  AssertConverts('<p>   </p>', '');
  AssertConverts('<div></div>', '');
end;

procedure TMarkdownHtmlSubsetTests.IsEmpty_MarkupWithoutContent_IsTrue;
begin
  Assert.IsTrue(TMarkdownHtmlSubset.IsEmpty('<div class="only-markup"></div>'));
end;

procedure TMarkdownHtmlSubsetTests.IsEmpty_MarkupWithContent_IsFalse;
begin
  Assert.IsFalse(TMarkdownHtmlSubset.IsEmpty('<div>something</div>'));
end;

end.
