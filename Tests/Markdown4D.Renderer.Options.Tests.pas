unit Markdown4D.Renderer.Options.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRendererOptionsTests = class
  private
    const
      OmittedHtmlComment = '<!-- raw HTML omitted -->';
      HtmlBlockSource = '<div>hidden</div>';
      FilteredTagNames: array[0..8] of string = (
        'title', 'textarea', 'style', 'xmp', 'iframe', 'noembed', 'noframes', 'script', 'plaintext');
    class function RenderDefault(const Source: string): string;
    class function RenderXhtml(const Source: string): string;
    class function RenderUnsafe(const Source: string): string;
    class function RenderTagFiltered(const Source: string): string;
    class function RenderEscaped(const Source: string): string;
    class function RenderWebSchemesOnly(const Source: string): string;
    class function RenderNoOpener(const Source: string): string;

  public
    [Test]
    procedure XhtmlOutput_ThematicBreak_RendersSelfClosingTag;

    [Test]
    procedure XhtmlOutput_HardLineBreak_RendersSelfClosingTag;

    [Test]
    procedure XhtmlOutput_Image_RendersSelfClosingTag;

    [Test]
    procedure ToHtml_DefaultSafeMode_ReplacesHtmlBlockWithOmittedComment;

    [Test]
    procedure ToHtml_DefaultSafeMode_ReplacesInlineHtmlWithOmittedComment;

    [Test]
    procedure UnsafeHtml_HtmlBlock_PassesRawHtmlThrough;

    [Test]
    procedure UnsafeHtml_RawHtml_MatchesFacadeOutput;

    [Test]
    procedure TagFilter_FilteredTags_EscapesLeadingBracket;

    [Test]
    procedure TagFilter_UppercaseTag_EscapesCaseInsensitively;

    [Test]
    procedure TagFilter_ClosingTag_EscapesLeadingBracket;

    [Test]
    procedure TagFilter_AllowedTag_PassesRawHtmlThrough;

    [Test]
    procedure AltText_InlineHtml_IsEscapedInSafeMode;

    [Test]
    procedure AltText_InlineHtml_IsEscapedInUnsafeMode;

    [Test]
    procedure AltText_QuoteInInlineHtml_CannotEndTheAttribute;

    [Test]
    procedure AltText_SoftLineBreak_BecomesSpace;

    [Test]
    [TestCase('Generic type', 'use a TList<T> here|<p>use a TList&lt;T&gt; here</p>', '|')]
    [TestCase('Image with handler', 'x <img src=x onerror=alert(1)>|<p>x &lt;img src=x onerror=alert(1)&gt;</p>', '|')]
    procedure EscapeRawHtml_InlineHtml_ShowsAsText(const Source, Expected: string);

    [Test]
    [TestCase('Script', '<script>alert(1)</script>|<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>', '|')]
    [TestCase('Comment', '<!-- note -->|<p>&lt;!-- note --&gt;</p>', '|')]
    procedure EscapeRawHtml_HtmlBlock_ShowsAsTextInParagraph(const Source, Expected: string);

    [Test]
    procedure EscapeRawHtml_AfterUnsafeHtml_StillEscapes;

    [Test]
    procedure EscapeRawHtml_GfmTagFilter_StillEscapesEveryTag;

    [Test]
    procedure EscapeRawHtml_InTableCell_ShowsAsText;

    [Test]
    [TestCase('https', '[a](https://example.com)|https://example.com', '|')]
    [TestCase('relative path', '[a](docs/readme.md)|docs/readme.md', '|')]
    [TestCase('fragment', '[a](#section)|#section', '|')]
    [TestCase('absolute path', '[a](/path)|/path', '|')]
    [TestCase('ftp', '[a](ftp://example.com)|#', '|')]
    [TestCase('mailto', '[a](mailto:x@example.com)|#', '|')]
    [TestCase('mixed case javascript', '[a](JaVaScRiPt:alert(1))|#', '|')]
    [TestCase('entity encoded letter', '[a](&#106;avascript:alert(1))|#', '|')]
    [TestCase('percent encoded tab is a relative path', '[a](java&#9;script:x)|java%09script:x', '|')]
    [TestCase('autolink with other scheme', '<ftp://example.com>|#', '|')]
    [TestCase('reference definition', '[a][r]'#10#10'[r]: ftp://example.com|#', '|')]
    procedure AllowUrlSchemes_Link_KeepsOrRejectsHref(const Source, ExpectedHref: string);

    [Test]
    [TestCase('email', 'mail foo@bar.example|#', '|')]
    [TestCase('www', 'see www.example.com|http://www.example.com', '|')]
    procedure AllowUrlSchemes_GfmAutolink_KeepsOrRejectsHref(const Source, ExpectedHref: string);

    [Test]
    [TestCase('https', '![i](https://example.com/i.png)|https://example.com/i.png', '|')]
    [TestCase('ftp', '![i](ftp://example.com/i.png)|', '|')]
    [TestCase('png data', '![i](data:image/png;base64,iVBORw0KGgo=)|', '|')]
    procedure AllowUrlSchemes_Image_KeepsOrRejectsSource(const Source, ExpectedSource: string);

    [Test]
    procedure AllowUrlSchemes_EmptyList_KeepsOnlyRelativeLinks;

    [Test]
    procedure AllowUrlSchemes_SecondCall_ReplacesTheList;

    [Test]
    procedure AllowUrlSchemes_AfterUnsafeLinks_StillRejects;

    [Test]
    procedure AllowUrlSchemes_UpperCaseWithColon_MatchesScheme;

    [Test]
    procedure AllowUrlSchemes_InvalidSchemeName_RaisesMarkdownError;

    [Test]
    procedure AllowUrlSchemes_CallThatRaises_KeepsThePreviousList;

    [Test]
    [TestCase('link with title', '[a](https://example.com "T")|<a href="https://example.com" title="T" rel="noopener noreferrer">', '|')]
    [TestCase('autolink', '<https://example.com>|<a href="https://example.com" rel="noopener noreferrer">', '|')]
    procedure NoOpenerLinks_Link_GetsRelAttribute(const Source, ExpectedAnchor: string);

    [Test]
    procedure NoOpenerLinks_Image_GetsNoRelAttribute;

    [Test]
    [TestCase('Generic type', 'use a TList<T> here|<p>use a TList<!-- raw HTML omitted --> here</p>', '|')]
    [TestCase('Tag and other scheme', 'x <b>y</b> [a](ftp://example.com)|<p>x <!-- raw HTML omitted -->y<!-- raw HTML omitted --> <a href="ftp://example.com">a</a></p>', '|')]
    procedure ToHtml_DefaultOptions_OmitsHtmlAndKeepsOtherSchemes(const Source, Expected: string);
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Pipeline,
  Markdown4D.Defines,
  Markdown4D;

procedure TRendererOptionsTests.XhtmlOutput_ThematicBreak_RendersSelfClosingTag;
begin
  Assert.AreEqual('<hr />'#10, RenderXhtml('---'));
end;

procedure TRendererOptionsTests.XhtmlOutput_HardLineBreak_RendersSelfClosingTag;
begin
  Assert.AreEqual('<p>a<br />'#10'b</p>'#10, RenderXhtml('a\'#10'b'));
end;

procedure TRendererOptionsTests.XhtmlOutput_Image_RendersSelfClosingTag;
begin
  Assert.AreEqual('<p><img src="/logo.png" alt="alt" /></p>'#10, RenderXhtml('![alt](/logo.png)'));
end;

procedure TRendererOptionsTests.ToHtml_DefaultSafeMode_ReplacesHtmlBlockWithOmittedComment;
begin
  Assert.AreEqual(OmittedHtmlComment + #10, RenderDefault(HtmlBlockSource));
end;

procedure TRendererOptionsTests.ToHtml_DefaultSafeMode_ReplacesInlineHtmlWithOmittedComment;
begin
  const Expected = Format('<p>a %sbold%s c</p>'#10, [OmittedHtmlComment, OmittedHtmlComment]);

  Assert.AreEqual(Expected, RenderDefault('a <b>bold</b> c'));
end;

procedure TRendererOptionsTests.UnsafeHtml_HtmlBlock_PassesRawHtmlThrough;
begin
  Assert.AreEqual(HtmlBlockSource + #10, RenderUnsafe(HtmlBlockSource));
end;

procedure TRendererOptionsTests.UnsafeHtml_RawHtml_MatchesFacadeOutput;
begin
  const Source = '<div>'#10'*raw*'#10'</div>';

  Assert.AreEqual(TMarkdown.ToUnsafeHtml(Source), RenderUnsafe(Source));
end;

procedure TRendererOptionsTests.TagFilter_FilteredTags_EscapesLeadingBracket;
begin
  for var TagName in FilteredTagNames do
  begin
    const Source = Format('x <%s>', [TagName]);
    const Expected = Format('<p>x &lt;%s></p>'#10, [TagName]);
    Assert.AreEqual(Expected, RenderTagFiltered(Source), Format('Tag <%s> must be filtered', [TagName]));
  end;
end;

procedure TRendererOptionsTests.TagFilter_UppercaseTag_EscapesCaseInsensitively;
begin
  Assert.AreEqual('<p>x &lt;SCRIPT></p>'#10, RenderTagFiltered('x <SCRIPT>'));
end;

procedure TRendererOptionsTests.TagFilter_ClosingTag_EscapesLeadingBracket;
begin
  Assert.AreEqual('<p>x &lt;/xmp></p>'#10, RenderTagFiltered('x </xmp>'));
end;

procedure TRendererOptionsTests.TagFilter_AllowedTag_PassesRawHtmlThrough;
begin
  Assert.AreEqual('<p>x <strong></p>'#10, RenderTagFiltered('x <strong>'));
end;

procedure TRendererOptionsTests.AltText_InlineHtml_IsEscapedInSafeMode;
begin
  Assert.AreEqual('<p><img src="/u.png" alt="a&lt;b&gt;c" /></p>'#10, RenderDefault('![a<b>c](/u.png)'));
end;

// Alt text is an attribute value, so raw HTML is escaped there even when the
// renderer is allowed to pass it through everywhere else.
procedure TRendererOptionsTests.AltText_InlineHtml_IsEscapedInUnsafeMode;
begin
  Assert.AreEqual('<p><img src="/u.png" alt="a&lt;b&gt;c" /></p>'#10, RenderUnsafe('![a<b>c](/u.png)'));
end;

procedure TRendererOptionsTests.AltText_QuoteInInlineHtml_CannotEndTheAttribute;
begin
  const Rendered = RenderUnsafe('![a<b title=">">c](/u.png)');

  Assert.AreEqual('<p><img src="/u.png" alt="a&lt;b title=&quot;&gt;&quot;&gt;c" /></p>'#10, Rendered);
end;

procedure TRendererOptionsTests.AltText_SoftLineBreak_BecomesSpace;
begin
  Assert.AreEqual('<p><img src="/u.png" alt="a b" /></p>'#10, RenderDefault('![a'#10'b](/u.png)'));
end;

procedure TRendererOptionsTests.EscapeRawHtml_InlineHtml_ShowsAsText(const Source, Expected: string);
begin
  const Rendered = RenderEscaped(Source);

  const ExpectedLine = Expected + #10;
  Assert.AreEqual(ExpectedLine, Rendered);
end;

procedure TRendererOptionsTests.EscapeRawHtml_HtmlBlock_ShowsAsTextInParagraph(const Source, Expected: string);
begin
  const Rendered = RenderEscaped(Source);

  const ExpectedLine = Expected + #10;
  Assert.AreEqual(ExpectedLine, Rendered);
end;

procedure TRendererOptionsTests.EscapeRawHtml_AfterUnsafeHtml_StillEscapes;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.UnsafeHtml.EscapeRawHtml.Build;

  const Rendered = Pipeline.ToHtml('a <b>bold</b> c');

  Assert.AreEqual('<p>a &lt;b&gt;bold&lt;/b&gt; c</p>'#10, Rendered);
end;

procedure TRendererOptionsTests.EscapeRawHtml_GfmTagFilter_StillEscapesEveryTag;
begin
  const Pipeline = TMarkdownPipeline.Create.UseGfm.UnsafeHtml.TagFilter.EscapeRawHtml.Build;

  const Rendered = Pipeline.ToHtml('x <strong>y</strong> <script>');

  Assert.AreEqual('<p>x &lt;strong&gt;y&lt;/strong&gt; &lt;script&gt;</p>'#10, Rendered);
end;

procedure TRendererOptionsTests.EscapeRawHtml_InTableCell_ShowsAsText;
begin
  const Pipeline = TMarkdownPipeline.Create.UseGfm.EscapeRawHtml.Build;

  const Rendered = Pipeline.ToHtml('| a |'#10'|---|'#10'| <b>x</b> |');

  Assert.Contains(Rendered, '<td>&lt;b&gt;x&lt;/b&gt;</td>');
end;

procedure TRendererOptionsTests.AllowUrlSchemes_Link_KeepsOrRejectsHref(const Source, ExpectedHref: string);
begin
  const Rendered = RenderWebSchemesOnly(Source);

  const ExpectedAnchor = Format('<a href="%s">', [ExpectedHref]);
  Assert.Contains(Rendered, ExpectedAnchor);
end;

procedure TRendererOptionsTests.AllowUrlSchemes_GfmAutolink_KeepsOrRejectsHref(const Source, ExpectedHref: string);
begin
  const Pipeline = TMarkdownPipeline.Create.UseGfm.AllowUrlSchemes(['http', 'https']).Build;

  const Rendered = Pipeline.ToHtml(Source);

  const ExpectedAnchor = Format('<a href="%s">', [ExpectedHref]);
  Assert.Contains(Rendered, ExpectedAnchor);
end;

procedure TRendererOptionsTests.AllowUrlSchemes_Image_KeepsOrRejectsSource(const Source, ExpectedSource: string);
begin
  const Rendered = RenderWebSchemesOnly(Source);

  const ExpectedImage = Format('<img src="%s"', [ExpectedSource]);
  Assert.Contains(Rendered, ExpectedImage);
end;

procedure TRendererOptionsTests.AllowUrlSchemes_EmptyList_KeepsOnlyRelativeLinks;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.AllowUrlSchemes([]).Build;

  const Rendered = Pipeline.ToHtml('[a](https://example.com) [b](/path)');

  Assert.AreEqual('<p><a href="#">a</a> <a href="/path">b</a></p>'#10, Rendered);
end;

procedure TRendererOptionsTests.AllowUrlSchemes_SecondCall_ReplacesTheList;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.AllowUrlSchemes(['ftp']).AllowUrlSchemes(['https']).Build;

  const Rendered = Pipeline.ToHtml('[a](ftp://example.com) [b](https://example.com)');

  Assert.AreEqual('<p><a href="#">a</a> <a href="https://example.com">b</a></p>'#10, Rendered);
end;

procedure TRendererOptionsTests.AllowUrlSchemes_AfterUnsafeLinks_StillRejects;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.UnsafeLinks.AllowUrlSchemes(['https']).Build;

  const Rendered = Pipeline.ToHtml('[a](javascript:alert(1))');

  Assert.AreEqual('<p><a href="#">a</a></p>'#10, Rendered);
end;

procedure TRendererOptionsTests.AllowUrlSchemes_UpperCaseWithColon_MatchesScheme;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.AllowUrlSchemes(['HTTPS:']).Build;

  const Rendered = Pipeline.ToHtml('[a](https://example.com)');

  Assert.AreEqual('<p><a href="https://example.com">a</a></p>'#10, Rendered);
end;

procedure TRendererOptionsTests.AllowUrlSchemes_InvalidSchemeName_RaisesMarkdownError;
begin
  const Builder = TMarkdownPipeline.Create.UseCommonMark;

  Assert.WillRaise(
    procedure
    begin
      Builder.AllowUrlSchemes(['https://']);
    end, EMarkdownError);
end;

procedure TRendererOptionsTests.AllowUrlSchemes_CallThatRaises_KeepsThePreviousList;
begin
  const Builder = TMarkdownPipeline.Create.UseCommonMark.AllowUrlSchemes(['https']);
  Assert.WillRaise(
    procedure
    begin
      Builder.AllowUrlSchemes(['ftp', 'https://']);
    end, EMarkdownError);

  const Pipeline = Builder.Build;
  const Rendered = Pipeline.ToHtml('[a](ftp://example.com) [b](https://example.com)');

  Assert.AreEqual('<p><a href="#">a</a> <a href="https://example.com">b</a></p>'#10, Rendered);
end;

procedure TRendererOptionsTests.NoOpenerLinks_Link_GetsRelAttribute(const Source, ExpectedAnchor: string);
begin
  const Rendered = RenderNoOpener(Source);

  Assert.Contains(Rendered, ExpectedAnchor);
end;

procedure TRendererOptionsTests.NoOpenerLinks_Image_GetsNoRelAttribute;
begin
  const Rendered = RenderNoOpener('![i](https://example.com/i.png)');

  Assert.DoesNotContain(Rendered, 'rel=');
end;

procedure TRendererOptionsTests.ToHtml_DefaultOptions_OmitsHtmlAndKeepsOtherSchemes(const Source, Expected: string);
begin
  const Rendered = RenderDefault(Source);

  const ExpectedLine = Expected + #10;
  Assert.AreEqual(ExpectedLine, Rendered);
end;

class function TRendererOptionsTests.RenderDefault(const Source: string): string;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.Build;

  Result := Pipeline.ToHtml(Source);
end;

class function TRendererOptionsTests.RenderXhtml(const Source: string): string;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.XhtmlOutput.Build;

  Result := Pipeline.ToHtml(Source);
end;

class function TRendererOptionsTests.RenderUnsafe(const Source: string): string;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.UnsafeHtml.Build;

  Result := Pipeline.ToHtml(Source);
end;

class function TRendererOptionsTests.RenderTagFiltered(const Source: string): string;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.UnsafeHtml.TagFilter.Build;

  Result := Pipeline.ToHtml(Source);
end;

class function TRendererOptionsTests.RenderEscaped(const Source: string): string;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.EscapeRawHtml.Build;

  Result := Pipeline.ToHtml(Source);
end;

class function TRendererOptionsTests.RenderWebSchemesOnly(const Source: string): string;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.AllowUrlSchemes(['http', 'https']).Build;

  Result := Pipeline.ToHtml(Source);
end;

class function TRendererOptionsTests.RenderNoOpener(const Source: string): string;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.NoOpenerLinks.Build;

  Result := Pipeline.ToHtml(Source);
end;

end.
