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
  end;

implementation

uses
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

end.
