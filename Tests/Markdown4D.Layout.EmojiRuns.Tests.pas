unit Markdown4D.Layout.EmojiRuns.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownEmojiRunsTests = class
  private
    const
      Smile = #$D83D#$DE04;
      Rocket = #$D83D#$DE80;
      Technologist = #$D83D#$DC69#$200D#$D83D#$DCBB;
      KeycapOne = '1'#$FE0F#$20E3;
      RedHeart = #$2764#$FE0F;
      HighVoltage = #$26A1;
      WhiteSmilingFace = #$263A;
      ThumbsUpMediumSkin = #$D83D#$DC4D#$D83C#$DFFD;
      FlagNetherlands = #$D83C#$DDF3#$D83C#$DDF1;
      UmbrellaAsText = #$2614#$FE0E;
      Sequences: array[0..6] of string = (Smile, Technologist, KeycapOne, RedHeart, ThumbsUpMediumSkin,
        FlagNetherlands, UmbrellaAsText);

  public
    [Test]
    procedure Split_PlainText_ReturnsSingleTextRun;

    [Test]
    procedure Split_EmptyText_ReturnsSingleEmptyRun;

    [Test]
    procedure Split_TextWithEmoji_SeparatesEmojiFromText;

    [Test]
    procedure Split_AdjacentEmoji_FormOneEmojiRun;

    [Test]
    procedure Split_ZwjSequence_StaysOneEmojiRun;

    [Test]
    procedure Split_SkinToneAndFlag_StayOneEmojiRun;

    [Test]
    procedure Split_KeycapAndVariationSelector_AreEmoji;

    [Test]
    procedure Split_BmpEmojiPresentation_IsEmoji;

    [Test]
    procedure Split_BmpSymbolWithoutSelector_StaysText;

    [Test]
    procedure Split_TextPresentationSelector_StaysText;

    [Test]
    procedure Split_AccentedAndCjkText_StaysText;

    [Test]
    procedure IsCharacterBoundary_PlainText_EveryIndexIsBoundary;

    [Test]
    [TestCase('SurrogatePair', '0')]
    [TestCase('ZwjSequence', '1')]
    [TestCase('Keycap', '2')]
    [TestCase('VariationSelector', '3')]
    [TestCase('SkinTone', '4')]
    [TestCase('Flag', '5')]
    [TestCase('TextPresentation', '6')]
    procedure IsCharacterBoundary_InsideSequence_ReturnsFalse(const SequenceIndex: Integer);

    [Test]
    procedure IsCharacterBoundary_BetweenTwoFlags_ReturnsTrue;

    [Test]
    procedure NextCharacterBoundary_AtSequenceStart_SkipsWholeSequence;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Layout.EmojiRuns;

procedure TMarkdownEmojiRunsTests.Split_PlainText_ReturnsSingleTextRun;
begin
  const Runs = TMarkdownEmojiRuns.Split('Start :smile: en 10:30:00');

  Assert.AreEqual(1, Integer(Length(Runs)));
  Assert.AreEqual('Start :smile: en 10:30:00', Runs[0].Text);
  Assert.IsFalse(Runs[0].IsEmoji);
end;

procedure TMarkdownEmojiRunsTests.Split_EmptyText_ReturnsSingleEmptyRun;
begin
  const Runs = TMarkdownEmojiRuns.Split('');

  Assert.AreEqual(1, Integer(Length(Runs)));
  Assert.AreEqual('', Runs[0].Text);
  Assert.IsFalse(Runs[0].IsEmoji);
end;

procedure TMarkdownEmojiRunsTests.Split_TextWithEmoji_SeparatesEmojiFromText;
begin
  const Runs = TMarkdownEmojiRuns.Split('Start ' + Smile + ' en ' + Rocket);

  Assert.AreEqual(4, Integer(Length(Runs)));
  Assert.AreEqual('Start ', Runs[0].Text);
  Assert.IsFalse(Runs[0].IsEmoji);
  Assert.AreEqual(Smile, Runs[1].Text);
  Assert.IsTrue(Runs[1].IsEmoji);
  Assert.AreEqual(' en ', Runs[2].Text);
  Assert.IsFalse(Runs[2].IsEmoji);
  Assert.AreEqual(Rocket, Runs[3].Text);
  Assert.IsTrue(Runs[3].IsEmoji);
end;

procedure TMarkdownEmojiRunsTests.Split_AdjacentEmoji_FormOneEmojiRun;
begin
  const Runs = TMarkdownEmojiRuns.Split(Smile + Rocket);

  Assert.AreEqual(1, Integer(Length(Runs)));
  Assert.AreEqual(Smile + Rocket, Runs[0].Text);
  Assert.IsTrue(Runs[0].IsEmoji);
end;

procedure TMarkdownEmojiRunsTests.Split_ZwjSequence_StaysOneEmojiRun;
begin
  const Runs = TMarkdownEmojiRuns.Split('a' + Technologist + 'b');

  Assert.AreEqual(3, Integer(Length(Runs)));
  Assert.AreEqual(Technologist, Runs[1].Text);
  Assert.IsTrue(Runs[1].IsEmoji);
end;

procedure TMarkdownEmojiRunsTests.Split_SkinToneAndFlag_StayOneEmojiRun;
begin
  const Runs = TMarkdownEmojiRuns.Split(ThumbsUpMediumSkin + ' ' + FlagNetherlands);

  Assert.AreEqual(3, Integer(Length(Runs)));
  Assert.AreEqual(ThumbsUpMediumSkin, Runs[0].Text);
  Assert.IsTrue(Runs[0].IsEmoji);
  Assert.AreEqual(FlagNetherlands, Runs[2].Text);
  Assert.IsTrue(Runs[2].IsEmoji);
end;

procedure TMarkdownEmojiRunsTests.Split_KeycapAndVariationSelector_AreEmoji;
begin
  const Runs = TMarkdownEmojiRuns.Split('x' + KeycapOne + ' ' + RedHeart);

  Assert.AreEqual(4, Integer(Length(Runs)));
  Assert.AreEqual('x', Runs[0].Text);
  Assert.AreEqual(KeycapOne, Runs[1].Text);
  Assert.IsTrue(Runs[1].IsEmoji);
  Assert.AreEqual(RedHeart, Runs[3].Text);
  Assert.IsTrue(Runs[3].IsEmoji);
end;

procedure TMarkdownEmojiRunsTests.Split_BmpEmojiPresentation_IsEmoji;
begin
  const Runs = TMarkdownEmojiRuns.Split('Snel ' + HighVoltage);

  Assert.AreEqual(2, Integer(Length(Runs)));
  Assert.AreEqual(HighVoltage, Runs[1].Text);
  Assert.IsTrue(Runs[1].IsEmoji);
end;

procedure TMarkdownEmojiRunsTests.Split_BmpSymbolWithoutSelector_StaysText;
begin
  const Runs = TMarkdownEmojiRuns.Split('Blij ' + WhiteSmilingFace + ' ' + #$00A9 + ' ' + #$2192);

  Assert.AreEqual(1, Integer(Length(Runs)));
  Assert.IsFalse(Runs[0].IsEmoji);
end;

procedure TMarkdownEmojiRunsTests.Split_TextPresentationSelector_StaysText;
begin
  const Runs = TMarkdownEmojiRuns.Split('Regen ' + UmbrellaAsText);

  Assert.AreEqual(1, Integer(Length(Runs)));
  Assert.IsFalse(Runs[0].IsEmoji);
end;

procedure TMarkdownEmojiRunsTests.Split_AccentedAndCjkText_StaysText;
begin
  const Runs = TMarkdownEmojiRuns.Split('caf'#$00E9' '#$65E5#$672C#$8A9E' '#$D835#$DD2D);

  Assert.AreEqual(1, Integer(Length(Runs)));
  Assert.IsFalse(Runs[0].IsEmoji);
end;

procedure TMarkdownEmojiRunsTests.IsCharacterBoundary_PlainText_EveryIndexIsBoundary;
begin
  const Text = 'Start 10:30';

  for var Count := 0 to Length(Text) do
  begin
    Assert.IsTrue(TMarkdownEmojiRuns.IsCharacterBoundary(Text, Count), Format('Boundary after %d', [Count]));
  end;
end;

procedure TMarkdownEmojiRunsTests.IsCharacterBoundary_InsideSequence_ReturnsFalse(const SequenceIndex: Integer);
begin
  const Sequence = Sequences[SequenceIndex];
  const Text = 'a' + Sequence + 'b';

  Assert.IsTrue(TMarkdownEmojiRuns.IsCharacterBoundary(Text, 1), 'Boundary before the sequence');
  Assert.IsTrue(TMarkdownEmojiRuns.IsCharacterBoundary(Text, 1 + Length(Sequence)), 'Boundary after the sequence');
  for var Count := 2 to Length(Sequence) do
  begin
    Assert.IsFalse(TMarkdownEmojiRuns.IsCharacterBoundary(Text, Count), Format('Boundary after %d', [Count]));
  end;
end;

procedure TMarkdownEmojiRunsTests.IsCharacterBoundary_BetweenTwoFlags_ReturnsTrue;
begin
  const Text = FlagNetherlands + FlagNetherlands;

  Assert.IsFalse(TMarkdownEmojiRuns.IsCharacterBoundary(Text, 2), 'Inside the first flag');
  Assert.IsTrue(TMarkdownEmojiRuns.IsCharacterBoundary(Text, 4), 'Between the flags');
  Assert.IsFalse(TMarkdownEmojiRuns.IsCharacterBoundary(Text, 6), 'Inside the second flag');
end;

procedure TMarkdownEmojiRunsTests.NextCharacterBoundary_AtSequenceStart_SkipsWholeSequence;
begin
  const Text = 'a' + Technologist + 'b';

  const Actual = TMarkdownEmojiRuns.NextCharacterBoundary(Text, 1);

  Assert.AreEqual(1 + Length(Technologist), Actual);
end;

end.
