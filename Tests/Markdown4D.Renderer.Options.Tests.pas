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
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Pipeline,
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

end.
