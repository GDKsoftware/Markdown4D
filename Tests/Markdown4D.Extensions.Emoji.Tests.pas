unit Markdown4D.Extensions.Emoji.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces;

type
  [TestFixture]
  TMarkdownEmojiTests = class
  private
    const
      Smile = #$D83D#$DE04;
      Rocket = #$D83D#$DE80;
      Tada = #$D83C#$DF89;
      ThumbsUp = #$D83D#$DC4D;
      ThumbsDown = #$D83D#$DC4E;
    class function Html(const Source: string): string;
    class function Paragraph(const Text: string): string;
    class function FindFirst(const Root: IMarkdownNode; const Kind: TMarkdownNodeKind): IMarkdownNode;

  public
    [Test]
    procedure ToHtml_KnownShortcodes_RendersEmoji;

    [Test]
    [TestCase('Unknown', ':nietbestaand:')]
    [TestCase('UnknownInSentence', 'Hallo :nietbestaand: daar')]
    [TestCase('CustomWithoutUnicode', ':octocat:')]
    procedure ToHtml_UnknownShortcode_KeepsLiteralText(const Source: string);

    [Test]
    procedure ToHtml_ShortcodeInHeading_RendersEmoji;

    [Test]
    procedure ToHtml_ShortcodeInCodeSpan_KeepsLiteralText;

    [Test]
    [TestCase('AtStart', ':smile: begin,%s begin')]
    [TestCase('InParentheses', '(:smile:),(%s)')]
    [TestCase('AfterNonAsciiLetter', #$00E9':smile:,'#$00E9'%s')]
    procedure ToHtml_ShortcodeAtStartOrAfterPunctuation_RendersEmoji(const Source, ExpectedFormat: string);

    [Test]
    [TestCase('AfterLetters', 'abc:smile:')]
    [TestCase('AfterDigit', '1:smile:')]
    procedure ToHtml_ShortcodeAfterAsciiLetterOrDigit_KeepsText(const Source: string);

    [Test]
    procedure ToHtml_AdjacentShortcodes_RendersBoth;

    [Test]
    procedure ToHtml_UnknownThenKnown_KeepsText;

    [Test]
    [TestCase('NumberRange', '12:100:5')]
    [TestCase('Time', 'om 10:30:00')]
    [TestCase('Letters', 'a:b:c')]
    procedure ToHtml_ColonsInTimeAndWords_KeepsText(const Source: string);

    [Test]
    procedure ToHtml_ShortcodeInsideUrl_KeepsText;

    [Test]
    [TestCase('NoCloser', ':smile')]
    [TestCase('SpaceAfterOpener', ': smile:')]
    [TestCase('SpaceInName', ':smi le:')]
    [TestCase('UpperCase', ':SMILE:')]
    procedure ToHtml_IncompleteOrSpaced_KeepsText(const Source: string);

    [Test]
    procedure ToHtml_ShortcodeAcrossLineBreak_KeepsText;

    [Test]
    procedure ToHtml_PlusOneAndMinusOne_RendersEmoji;

    [Test]
    procedure ToHtml_CommonMarkDialect_KeepsShortcode;

    [Test]
    procedure Parse_Shortcode_TextNodeSegmentCoversShortcode;

    [Test]
    procedure TEmojiShortcodes_Table_IsSortedOrdinalAndUnique;

    [Test]
    procedure TEmojiShortcodes_TryDecode_OctocatNotPresent;

    [Test]
    procedure TEmojiShortcodes_Table_HasFullGitHubList;

    [Test]
    [TestCase('Zzz', 'zzz')]
    [TestCase('Smile', 'smile')]
    [TestCase('Rocket', 'rocket')]
    [TestCase('PlusOne', '+1')]
    procedure TEmojiShortcodes_TryDecode_GitHubShortcode_ReturnsTrue(const Name: string);

    [Test]
    procedure TEmojiShortcodes_TryDecode_ZwjSequence_ReturnsAllCodePoints;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Emoji.Shortcodes;

const
  MinimumGitHubShortcodeCount = 1800;

class function TMarkdownEmojiTests.Html(const Source: string): string;
begin
  Result := TMarkdown.ToHtml(Source, TMarkdownDialect.Gfm);
end;

class function TMarkdownEmojiTests.Paragraph(const Text: string): string;
begin
  Result := Format('<p>%s</p>'#10, [Text]);
end;

class function TMarkdownEmojiTests.FindFirst(const Root: IMarkdownNode; const Kind: TMarkdownNodeKind): IMarkdownNode;
begin
  if Root.Kind = Kind then
  begin
    Result := Root;
    Exit;
  end;

  for var Index := 0 to Root.ChildCount - 1 do
  begin
    const Found = FindFirst(Root.Children[Index], Kind);
    if Found <> nil then
    begin
      Result := Found;
      Exit;
    end;
  end;

  Result := nil;
end;

procedure TMarkdownEmojiTests.ToHtml_KnownShortcodes_RendersEmoji;
begin
  const Expected = Paragraph(Format('Hallo %s en %s', [Smile, Rocket]));

  const Actual = Html('Hallo :smile: en :rocket:');

  Assert.AreEqual(Expected, Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_UnknownShortcode_KeepsLiteralText(const Source: string);
begin
  const Actual = Html(Source);

  Assert.AreEqual(Paragraph(Source), Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_ShortcodeInHeading_RendersEmoji;
begin
  const Expected = Format('<h1>Klaar %s</h1>'#10, [Tada]);

  const Actual = Html('# Klaar :tada:');

  Assert.AreEqual(Expected, Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_ShortcodeInCodeSpan_KeepsLiteralText;
begin
  const Actual = Html('`:smile:`');

  Assert.AreEqual(Paragraph('<code>:smile:</code>'), Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_ShortcodeAtStartOrAfterPunctuation_RendersEmoji(const Source,
  ExpectedFormat: string);
begin
  const Expected = Paragraph(Format(ExpectedFormat, [Smile]));

  const Actual = Html(Source);

  Assert.AreEqual(Expected, Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_ShortcodeAfterAsciiLetterOrDigit_KeepsText(const Source: string);
begin
  const Actual = Html(Source);

  Assert.AreEqual(Paragraph(Source), Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_AdjacentShortcodes_RendersBoth;
begin
  const Expected = Paragraph(Smile + Rocket);

  const Actual = Html(':smile::rocket:');

  Assert.AreEqual(Expected, Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_UnknownThenKnown_KeepsText;
begin
  const Source = ':foo:smile:';

  const Actual = Html(Source);

  Assert.AreEqual(Paragraph(Source), Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_ColonsInTimeAndWords_KeepsText(const Source: string);
begin
  const Actual = Html(Source);

  Assert.AreEqual(Paragraph(Source), Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_ShortcodeInsideUrl_KeepsText;
begin
  const Expected = Paragraph('<a href="https://example.com/:smile">https://example.com/:smile</a>:');

  const Actual = Html('https://example.com/:smile:');

  Assert.AreEqual(Expected, Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_IncompleteOrSpaced_KeepsText(const Source: string);
begin
  const Actual = Html(Source);

  Assert.AreEqual(Paragraph(Source), Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_ShortcodeAcrossLineBreak_KeepsText;
begin
  const Source = ':smi'#10'le:';

  const Actual = Html(Source);

  Assert.AreEqual(Paragraph(Source), Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_PlusOneAndMinusOne_RendersEmoji;
begin
  const Expected = Paragraph(Format('%s %s', [ThumbsUp, ThumbsDown]));

  const Actual = Html(':+1: :-1:');

  Assert.AreEqual(Expected, Actual);
end;

procedure TMarkdownEmojiTests.ToHtml_CommonMarkDialect_KeepsShortcode;
begin
  const Source = 'Hallo :smile:';

  const Actual = TMarkdown.ToHtml(Source, TMarkdownDialect.CommonMark);

  Assert.AreEqual(Paragraph(Source), Actual);
end;

procedure TMarkdownEmojiTests.Parse_Shortcode_TextNodeSegmentCoversShortcode;
begin
  const Source = ':smile:';

  const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
  const Text = FindFirst(Document, TMarkdownNodeKind.Text);

  Assert.IsNotNull(Text, 'Text node was not found');
  Assert.AreEqual(Smile, (Text as IMarkdownText).Literal);
  Assert.AreEqual(Source, Copy(Source, Text.Segment.StartOffset, Text.Segment.Length));
end;

procedure TMarkdownEmojiTests.TEmojiShortcodes_Table_IsSortedOrdinalAndUnique;
begin
  for var Index := 1 to TEmojiShortcodes.Count - 1 do
  begin
    const Previous = TEmojiShortcodes.NameAt(Index - 1);
    const Current = TEmojiShortcodes.NameAt(Index);
    const IsStrictlyAscending = (CompareStr(Previous, Current) < 0);

    Assert.IsTrue(IsStrictlyAscending, Format('Shortcode "%s" must sort before "%s"', [Previous, Current]));
  end;
end;

procedure TMarkdownEmojiTests.TEmojiShortcodes_TryDecode_OctocatNotPresent;
begin
  var Emoji: string;

  const Found = TEmojiShortcodes.TryDecode('octocat', Emoji);

  Assert.IsFalse(Found);
  Assert.AreEqual('', Emoji);
end;

procedure TMarkdownEmojiTests.TEmojiShortcodes_Table_HasFullGitHubList;
begin
  const Count = TEmojiShortcodes.Count;

  const HasFullList = (Count > MinimumGitHubShortcodeCount);

  Assert.IsTrue(HasFullList, Format('Only %d shortcodes in the table', [Count]));
end;

procedure TMarkdownEmojiTests.TEmojiShortcodes_TryDecode_GitHubShortcode_ReturnsTrue(const Name: string);
begin
  var Emoji: string;

  const Found = TEmojiShortcodes.TryDecode(Name, Emoji);

  Assert.IsTrue(Found, Format('Shortcode "%s" is missing', [Name]));
  Assert.IsNotEmpty(Emoji);
end;

procedure TMarkdownEmojiTests.TEmojiShortcodes_TryDecode_ZwjSequence_ReturnsAllCodePoints;
begin
  const Expected = #$D83D#$DC68#$200D#$D83D#$DCBB;

  var Emoji: string;
  const Found = TEmojiShortcodes.TryDecode('man_technologist', Emoji);

  Assert.IsTrue(Found);
  Assert.AreEqual(Expected, Emoji);
end;

end.
