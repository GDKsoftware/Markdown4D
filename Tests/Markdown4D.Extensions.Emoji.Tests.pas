unit Markdown4D.Extensions.Emoji.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TEmojiExtensionTests = class
  private
    const
      SmileEmoji = #$D83D#$DE04;
      RocketEmoji = #$D83D#$DE80;
      ParagraphFormat = '<p>%s</p>'#10;
    class function GfmHtml(const Source: string): string;

  public
    [Test]
    procedure ToHtml_KnownShortcodes_RendersEmoji;

    [Test]
    [TestCase('Unknown', ':zzz:')]
    [TestCase('GitHubImageOnly', ':octocat:')]
    [TestCase('EmptyName', '::')]
    [TestCase('SpaceInName', ': smile:')]
    [TestCase('NoClosingColon', ':smile')]
    [TestCase('SingleColon', 'a:b')]
    procedure ToHtml_UnknownShortcode_StaysLiteral(const Source: string);

    [Test]
    procedure ToHtml_UnknownFollowedByKnown_DecodesKnownOnly;

    [Test]
    procedure ToHtml_ShortcodeInHeading_RendersEmojiInHeading;

    [Test]
    procedure Toc_ShortcodeInHeading_AnchorDropsEmoji;

    [Test]
    [TestCase('CodeSpan', '`:smile:`,<p><code>:smile:</code></p>'#10)]
    [TestCase('FencedCodeBlock', '```'#10':smile:'#10'```,<pre><code>:smile:'#10'</code></pre>'#10)]
    procedure ToHtml_ShortcodeInCodeSpanOrCodeBlock_StaysLiteral(const Source, Expected: string);

    [Test]
    [TestCase('LinkDestination', '[x](http://a/:smile:),<p><a href="http://a/:smile:">x</a></p>'#10)]
    [TestCase('ExtendedAutolink', 'https://a.b/:smile:/x,<p><a href="https://a.b/:smile:/x">https://a.b/:smile:/x</a></p>'#10)]
    procedure ToHtml_ShortcodeInLinkDestinationOrAutolink_StaysLiteral(const Source, Expected: string);

    [Test]
    [TestCase('Emphasis', '*:smile:*,<p><em>'#$D83D#$DE04'</em></p>'#10)]
    [TestCase('LinkText', '[:smile:](u),<p><a href="u">'#$D83D#$DE04'</a></p>'#10)]
    procedure ToHtml_ShortcodeInLinkTextAndEmphasis_RendersEmoji(const Source, Expected: string);

    [Test]
    procedure ToHtml_CommonMarkDialect_KeepsShortcode;

    [Test]
    procedure Parse_Shortcode_TextSegmentCoversShortcodeSource;

    [Test]
    [TestCase('Time', 'tijd 10:30')]
    [TestCase('TimeWithSeconds', 'om 12:00:00 uur')]
    [TestCase('ColonAndSpace', 'Let op: tekst')]
    [TestCase('SchemeOnly', 'http:')]
    [TestCase('TableLikeText', '|:-:|')]
    procedure Parse_PlainTextWithColons_Unchanged(const Source: string);
  end;

  [TestFixture]
  TEmojiShortcodesTests = class
  public
    [Test]
    [TestCase('PlusOne', '+1,'#$D83D#$DC4D)]
    [TestCase('MinusOne', '-1,'#$D83D#$DC4E)]
    [TestCase('Hundred', '100,'#$D83D#$DCAF)]
    [TestCase('Smile', 'smile,'#$D83D#$DE04)]
    [TestCase('Rocket', 'rocket,'#$D83D#$DE80)]
    [TestCase('ZipperMouthFace', 'zipper_mouth_face,'#$D83E#$DD10)]
    [TestCase('LastEntry', 'zombie_woman,'#$D83E#$DDDF#$200D#$2640#$FE0F)]
    [TestCase('Flag', 'netherlands,'#$D83C#$DDF3#$D83C#$DDF1)]
    [TestCase('ZwjSequence', 'family_man_woman_boy,'#$D83D#$DC68#$200D#$D83D#$DC69#$200D#$D83D#$DC66)]
    procedure TryDecode_KnownNames_ReturnsEmoji(const Name, Expected: string);

    [Test]
    [TestCase('Unknown', 'zzz')]
    [TestCase('WrongCase', 'Smile')]
    [TestCase('GitHubImageOnly', 'octocat')]
    procedure TryDecode_UnknownOrWrongCase_ReturnsFalse(const Name: string);

    [Test]
    procedure TryDecode_EmptyName_ReturnsFalse;

    [Test]
    procedure Table_IsStrictlyOrdinallySorted;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Toc,
  Markdown4D.Emoji.Shortcodes;

class function TEmojiExtensionTests.GfmHtml(const Source: string): string;
begin
  Result := TMarkdown.ToHtml(Source, TMarkdownDialect.Gfm);
end;

procedure TEmojiExtensionTests.ToHtml_KnownShortcodes_RendersEmoji;
begin
  const Line = Format('Regel met %s en %s', [SmileEmoji, RocketEmoji]);
  const Expected = Format(ParagraphFormat, [Line]);

  const Actual = GfmHtml('Regel met :smile: en :rocket:');

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiExtensionTests.ToHtml_UnknownShortcode_StaysLiteral(const Source: string);
begin
  const Expected = Format(ParagraphFormat, [Source]);

  const Actual = GfmHtml(Source);

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiExtensionTests.ToHtml_UnknownFollowedByKnown_DecodesKnownOnly;
begin
  const Line = Format(':zzz%s', [SmileEmoji]);
  const Expected = Format(ParagraphFormat, [Line]);

  const Actual = GfmHtml(':zzz:smile:');

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiExtensionTests.ToHtml_ShortcodeInHeading_RendersEmojiInHeading;
begin
  const Expected = Format('<h1>Hallo %s</h1>'#10, [SmileEmoji]);

  const Actual = GfmHtml('# Hallo :smile:');

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiExtensionTests.Toc_ShortcodeInHeading_AnchorDropsEmoji;
begin
  const Document = TMarkdown.Parse('# Hallo :smile:', TMarkdownDialect.Gfm);

  const Toc = TMarkdownToc.FromDocument(Document);

  Assert.AreEqual(1, Toc.EntryCount);
  const Entry = Toc.Entries[0];
  Assert.AreEqual('hallo-', Entry.Anchor);
end;

procedure TEmojiExtensionTests.ToHtml_ShortcodeInCodeSpanOrCodeBlock_StaysLiteral(const Source, Expected: string);
begin
  const Actual = GfmHtml(Source);

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiExtensionTests.ToHtml_ShortcodeInLinkDestinationOrAutolink_StaysLiteral(const Source,
                                                                                         Expected: string);
begin
  const Actual = GfmHtml(Source);

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiExtensionTests.ToHtml_ShortcodeInLinkTextAndEmphasis_RendersEmoji(const Source, Expected: string);
begin
  const Actual = GfmHtml(Source);

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiExtensionTests.ToHtml_CommonMarkDialect_KeepsShortcode;
begin
  const Source = ':smile:';
  const Expected = Format(ParagraphFormat, [Source]);

  const Actual = TMarkdown.ToHtml(Source, TMarkdownDialect.CommonMark);

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiExtensionTests.Parse_Shortcode_TextSegmentCoversShortcodeSource;
begin
  const Source = 'a :smile: b';

  const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);

  const Paragraph = Document.Children[0];
  Assert.AreEqual(1, Paragraph.ChildCount, 'The paragraph should hold a single text node');

  const FirstChild = Paragraph.Children[0];
  var Text: IMarkdownText;
  const IsText = Supports(FirstChild, IMarkdownText, Text);
  Assert.IsTrue(IsText, 'The paragraph child should be text');

  const ExpectedLiteral = Format('a %s b', [SmileEmoji]);
  Assert.AreEqual(ExpectedLiteral, Text.Literal);
  Assert.AreEqual(1, Text.Segment.StartOffset);
  Assert.AreEqual(Source.Length + 1, Text.Segment.EndOffset);
end;

procedure TEmojiExtensionTests.Parse_PlainTextWithColons_Unchanged(const Source: string);
begin
  const Expected = TMarkdown.ToHtml(Source, TMarkdownDialect.CommonMark);

  const Actual = GfmHtml(Source);

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiShortcodesTests.TryDecode_KnownNames_ReturnsEmoji(const Name, Expected: string);
begin
  var Decoded: string;

  const Found = TEmojiShortcodes.TryDecode(Name, Decoded);

  const FailureMessage = Format('"%s" should be a known shortcode', [Name]);
  Assert.IsTrue(Found, FailureMessage);
  Assert.AreEqual(Expected, Decoded);
end;

procedure TEmojiShortcodesTests.TryDecode_UnknownOrWrongCase_ReturnsFalse(const Name: string);
begin
  var Decoded: string;

  const Found = TEmojiShortcodes.TryDecode(Name, Decoded);

  Assert.IsFalse(Found);
  Assert.AreEqual('', Decoded);
end;

procedure TEmojiShortcodesTests.TryDecode_EmptyName_ReturnsFalse;
begin
  var Decoded: string;

  const Found = TEmojiShortcodes.TryDecode('', Decoded);

  Assert.IsFalse(Found);
  Assert.AreEqual('', Decoded);
end;

procedure TEmojiShortcodesTests.Table_IsStrictlyOrdinallySorted;
begin
  for var Index := 1 to TEmojiShortcodes.Count - 1 do
  begin
    const Previous = TEmojiShortcodes.NameAt(Index - 1);
    const Current = TEmojiShortcodes.NameAt(Index);
    const IsAscending = (CompareStr(Previous, Current) < 0);
    const FailureMessage = Format('"%s" must sort before "%s"', [Previous, Current]);

    Assert.IsTrue(IsAscending, FailureMessage);
  end;
end;

end.
