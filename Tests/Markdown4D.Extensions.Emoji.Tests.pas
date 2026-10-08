unit Markdown4D.Extensions.Emoji.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TEmojiShortcodeExtensionTests = class
  private
    const
      Smile = #$D83D#$DE04;
      Rocket = #$D83D#$DE80;
      Tada = #$D83C#$DF89;
    class function Html(const Source: string): string;
    class function Paragraph(const Content: string): string;

  public
    [Test]
    procedure ToHtml_KnownShortcodes_RendersEmoji;

    [Test]
    [TestCase('Smile', 'smile,1F604')]
    [TestCase('Rocket', 'rocket,1F680')]
    [TestCase('Tada', 'tada,1F389')]
    [TestCase('ThumbsUp', '+1,1F44D')]
    [TestCase('ThumbsDown', '-1,1F44E')]
    [TestCase('Hundred', '100,1F4AF')]
    [TestCase('Sparkles', 'sparkles,2728')]
    [TestCase('Heart', 'heart,2764 FE0F')]
    [TestCase('Warning', 'warning,26A0 FE0F')]
    [TestCase('Bug', 'bug,1F41B')]
    [TestCase('Accordion', 'accordion,1FA97')]
    [TestCase('Keycap', 'hash,0023 FE0F 20E3')]
    [TestCase('Flag', 'netherlands,1F1F3 1F1F1')]
    [TestCase('ZwjSequence', 'woman_technologist,1F469 200D 1F4BB')]
    [TestCase('Family', 'family_man_woman_girl_boy,1F468 200D 1F469 200D 1F467 200D 1F466')]
    [TestCase('TagSequence', 'scotland,1F3F4 E0067 E0062 E0073 E0063 E0074 E007F')]
    procedure ToHtml_KnownShortcode_RendersMatchingEmoji(const Name, CodePoints: string);

    [Test]
    procedure ToHtml_ShortcodeInHeading_RendersEmoji;

    [Test]
    procedure ToHtml_AdjacentShortcodes_RendersBoth;

    [Test]
    [TestCase('AtStart', ':smile: first')]
    [TestCase('InParentheses', '(:smile:)')]
    [TestCase('AfterSpace', 'say :smile:')]
    [TestCase('BeforePunctuation', ':smile:!')]
    procedure ToHtml_ShortcodeAtWordBoundary_RendersEmoji(const Source: string);

    [Test]
    procedure ToHtml_ShortcodeAfterNonAsciiLetter_RendersEmoji;

    [Test]
    [TestCase('Unknown', ':doesnotexist:')]
    [TestCase('CustomWithoutUnicode', ':octocat:')]
    [TestCase('UpperCase', ':Smile:')]
    [TestCase('AfterLetters', 'abc:smile:')]
    [TestCase('AfterDigit', '1:smile:')]
    [TestCase('UnknownThenKnown', ':foo:smile:')]
    [TestCase('Ratio', '12:100:5')]
    [TestCase('Time', '10:30:00')]
    [TestCase('Words', 'a:b:c')]
    [TestCase('Unclosed', ':smile')]
    [TestCase('EmptyName', '::')]
    [TestCase('LeadingSpace', ': smile:')]
    [TestCase('InnerSpace', ':smi le:')]
    [TestCase('Mixed', ':doesnotexist: and abc:smile: at 10:30:00')]
    procedure ToHtml_NotAShortcode_KeepsText(const Source: string);

    [Test]
    procedure ToHtml_ShortcodeAcrossLineBreak_KeepsText;

    [Test]
    procedure ToHtml_ShortcodeInCodeSpan_KeepsLiteralText;

    [Test]
    procedure ToHtml_ShortcodeInUrl_KeepsLiteralText;

    [Test]
    procedure ToHtml_CommonMarkDialect_KeepsShortcode;

    [Test]
    procedure Parse_Shortcode_TextNodeSegmentCoversShortcode;
  end;

  [TestFixture]
  TEmojiShortcodeTableTests = class
  private
    class function FromCodePoints(const CodePoints: string): string;
    class function IsWellFormedUtf16(const Value: string): Boolean;

  public
    [Test]
    procedure Table_IsSortedOrdinalAndUnique;

    [Test]
    procedure Table_ValuesAreWellFormedUtf16;

    [Test]
    procedure Table_HasFullGitHubList;

    [Test]
    [TestCase('Smile', 'smile,1F604')]
    [TestCase('Zzz', 'zzz,1F4A4')]
    [TestCase('Mahjong', 'mahjong,1F004')]
    [TestCase('Koko', 'koko,1F201')]
    [TestCase('BlueSquare', 'blue_square,1F7E6')]
    [TestCase('Copyright', 'copyright,00A9 FE0F')]
    [TestCase('KeycapZero', 'zero,0030 FE0F 20E3')]
    [TestCase('Afghanistan', 'afghanistan,1F1E6 1F1EB')]
    [TestCase('Zimbabwe', 'zimbabwe,1F1FF 1F1FC')]
    [TestCase('PirateFlag', 'pirate_flag,1F3F4 200D 2620 FE0F')]
    [TestCase('RainbowFlag', 'rainbow_flag,1F3F3 FE0F 200D 1F308')]
    [TestCase('England', 'england,1F3F4 E0067 E0062 E0065 E006E E0067 E007F')]
    [TestCase('Wales', 'wales,1F3F4 E0067 E0062 E0077 E006C E0073 E007F')]
    [TestCase('CoupleKiss', 'couplekiss_man_man,1F468 200D 2764 FE0F 200D 1F48B 200D 1F468')]
    [TestCase('HoldingHands', 'people_holding_hands,1F9D1 200D 1F91D 200D 1F9D1')]
    [TestCase('Lowest', '+1,1F44D')]
    procedure TryDecode_KnownName_ReturnsGemojiCharacter(const Name, CodePoints: string);

    [Test]
    [TestCase('Octocat', 'octocat')]
    [TestCase('Shipit', 'shipit')]
    [TestCase('Unknown', 'doesnotexist')]
    [TestCase('Empty', '')]
    procedure TryDecode_NameWithoutCharacter_ReturnsFalse(const Name: string);
  end;

implementation

uses
  System.SysUtils,
  System.Character,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Emoji.Shortcodes,
  Markdown4D.Pipeline;

const
  CodePointSeparator = ' ';
  HexPrefix = '$';

class function TEmojiShortcodeExtensionTests.Html(const Source: string): string;
begin
  Result := TMarkdown.ToHtml(Source, TMarkdownDialect.Gfm);
end;

class function TEmojiShortcodeExtensionTests.Paragraph(const Content: string): string;
begin
  Result := Format('<p>%s</p>'#10, [Content]);
end;

procedure TEmojiShortcodeExtensionTests.ToHtml_KnownShortcodes_RendersEmoji;
begin
  const Expected = Paragraph(Format('Start %s and %s', [Smile, Rocket]));

  const Actual = Html('Start :smile: and :rocket:');

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiShortcodeExtensionTests.ToHtml_KnownShortcode_RendersMatchingEmoji(const Name, CodePoints: string);
begin
  const Emoji = TEmojiShortcodeTableTests.FromCodePoints(CodePoints);
  const Expected = Paragraph(Format('x %s y', [Emoji]));

  const Actual = Html(Format('x :%s: y', [Name]));

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiShortcodeExtensionTests.ToHtml_ShortcodeInHeading_RendersEmoji;
begin
  const Expected = Format('<h1>Done %s</h1>'#10, [Tada]);

  const Actual = Html('# Done :tada:');

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiShortcodeExtensionTests.ToHtml_AdjacentShortcodes_RendersBoth;
begin
  const Expected = Paragraph(Smile + Rocket);

  const Actual = Html(':smile::rocket:');

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiShortcodeExtensionTests.ToHtml_ShortcodeAtWordBoundary_RendersEmoji(const Source: string);
begin
  const Expected = Paragraph(Source.Replace(':smile:', Smile));

  const Actual = Html(Source);

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiShortcodeExtensionTests.ToHtml_ShortcodeAfterNonAsciiLetter_RendersEmoji;
begin
  const LetterWithAccent = #$00E9;
  const Expected = Paragraph(LetterWithAccent + Smile);

  const Actual = Html(LetterWithAccent + ':smile:');

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiShortcodeExtensionTests.ToHtml_NotAShortcode_KeepsText(const Source: string);
begin
  const Expected = Paragraph(Source);

  const Actual = Html(Source);

  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiShortcodeExtensionTests.ToHtml_ShortcodeAcrossLineBreak_KeepsText;
begin
  const Source = ':smile'#10':';

  const Actual = Html(Source);

  Assert.AreEqual(Paragraph(Source), Actual);
end;

procedure TEmojiShortcodeExtensionTests.ToHtml_ShortcodeInCodeSpan_KeepsLiteralText;
begin
  const Actual = Html('`:smile:`');

  Assert.AreEqual(Paragraph('<code>:smile:</code>'), Actual);
end;

procedure TEmojiShortcodeExtensionTests.ToHtml_ShortcodeInUrl_KeepsLiteralText;
begin
  const Actual = Html('https://example.com/:smile:');

  const HasEmoji = Actual.Contains(Smile);
  Assert.IsFalse(HasEmoji, Actual);
  Assert.IsTrue(Actual.Contains(':smile'), Actual);
end;

procedure TEmojiShortcodeExtensionTests.ToHtml_CommonMarkDialect_KeepsShortcode;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.Build;

  const Actual = Pipeline.ToHtml(':smile:');

  Assert.AreEqual(Paragraph(':smile:'), Actual);
end;

procedure TEmojiShortcodeExtensionTests.Parse_Shortcode_TextNodeSegmentCoversShortcode;
begin
  const Source = ':smile:';

  const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
  const ParagraphNode = Document.Children[0];
  const Text = ParagraphNode.Children[0];

  Assert.AreEqual(Smile, (Text as IMarkdownText).Literal);
  Assert.AreEqual(Source.Length, Text.Segment.Length);
end;

class function TEmojiShortcodeTableTests.FromCodePoints(const CodePoints: string): string;
begin
  Result := '';

  for var HexDigits in CodePoints.Split([CodePointSeparator]) do
  begin
    const CodePoint: UCS4Char = StrToInt(HexPrefix + HexDigits);
    const Character = Char.ConvertFromUtf32(CodePoint);
    Result := Result + Character;
  end;
end;

class function TEmojiShortcodeTableTests.IsWellFormedUtf16(const Value: string): Boolean;
begin
  var Index := 1;

  while Index <= Value.Length do
  begin
    const Current = Value[Index];

    if Current.IsHighSurrogate then
    begin
      const HasLowSurrogate = (Index < Value.Length) and Value[Index + 1].IsLowSurrogate;
      if not HasLowSurrogate then
        Exit(False);

      Inc(Index, 2);
    end
    else if Current.IsLowSurrogate then
    begin
      Exit(False);
    end
    else
    begin
      Inc(Index);
    end;
  end;

  Result := (Value <> '');
end;

procedure TEmojiShortcodeTableTests.Table_IsSortedOrdinalAndUnique;
begin
  for var Index := 1 to TEmojiShortcodes.Count - 1 do
  begin
    const Previous = TEmojiShortcodes.NameAt(Index - 1);
    const Current = TEmojiShortcodes.NameAt(Index);

    const IsAscending = (CompareStr(Previous, Current) < 0);
    Assert.IsTrue(IsAscending, Format('"%s" must sort before "%s"', [Previous, Current]));
  end;
end;

procedure TEmojiShortcodeTableTests.Table_ValuesAreWellFormedUtf16;
begin
  for var Index := 0 to TEmojiShortcodes.Count - 1 do
  begin
    const Name = TEmojiShortcodes.NameAt(Index);
    const Value = TEmojiShortcodes.ValueAt(Index);

    Assert.IsTrue(IsWellFormedUtf16(Value), Format('Value of "%s" is not well-formed UTF-16', [Name]));
  end;
end;

procedure TEmojiShortcodeTableTests.Table_HasFullGitHubList;
begin
  const MinimumGitHubCount = 1800;
  const RequiredNames: TArray<string> = ['zzz', 'smile', 'rocket', '+1'];

  const HasFullList = (TEmojiShortcodes.Count > MinimumGitHubCount);
  Assert.IsTrue(HasFullList, Format('Only %d shortcodes', [TEmojiShortcodes.Count]));

  var Emoji: string;
  for var Name in RequiredNames do
  begin
    Assert.IsTrue(TEmojiShortcodes.TryDecode(Name, Emoji), Name);
  end;
end;

procedure TEmojiShortcodeTableTests.TryDecode_KnownName_ReturnsGemojiCharacter(const Name, CodePoints: string);
begin
  const Expected = FromCodePoints(CodePoints);

  var Actual: string;
  const Found = TEmojiShortcodes.TryDecode(Name, Actual);

  Assert.IsTrue(Found, Name);
  Assert.AreEqual(Expected, Actual);
end;

procedure TEmojiShortcodeTableTests.TryDecode_NameWithoutCharacter_ReturnsFalse(const Name: string);
begin
  var Emoji: string;

  const Found = TEmojiShortcodes.TryDecode(Name, Emoji);

  Assert.IsFalse(Found, Name);
  Assert.AreEqual('', Emoji);
end;

end.
