unit Markdown4D.Emoji.Segments.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Emoji.Segments;

type
  [TestFixture]
  TEmojiSegmentsTests = class
  private
    const
      SmileEmoji = #$D83D#$DE04;
      RocketEmoji = #$D83D#$DE80;
      WomanTechnologistEmoji = #$D83D#$DC69#$200D#$D83D#$DCBB;
      NetherlandsFlagEmoji = #$D83C#$DDF3#$D83C#$DDF1;
      HashKeycapEmoji = '#'#$FE0F#$20E3;
      SunWithSelectorEmoji = #$2600#$FE0F;
      HighVoltageEmoji = #$26A1;
      DevanagariWithJoiner = #$0915#$094D#$200D#$0937;
      PlainTextWithArrow = 'tijd 10:30 '#$2192' klaar';
    class function Describe(const Segments: TArray<TEmojiSegment>): string; static;

  public
    [Test]
    procedure Split_EmptyText_ReturnsNoSegments;

    [Test]
    procedure Split_PlainText_ReturnsSingleTextSegment;

    [Test]
    procedure Split_EmojiBetweenText_SeparatesEmojiSegment;

    [Test]
    procedure Split_AdjacentEmoji_ShareOneSegment;

    [Test]
    procedure Split_JoinerSequence_StaysOneEmojiSegment;

    [Test]
    procedure Split_FlagSequence_StaysOneEmojiSegment;

    [Test]
    procedure Split_KeycapSequence_StaysOneEmojiSegment;

    [Test]
    procedure Split_TextCharacterWithEmojiSelector_IsEmoji;

    [Test]
    procedure Split_DefaultEmojiPresentationCharacter_IsEmoji;

    [Test]
    procedure ContainsEmoji_JoinerInDevanagari_ReturnsFalse;

    [Test]
    procedure ContainsEmoji_PlainTextWithArrow_ReturnsFalse;

    [Test]
    procedure ContainsEmoji_TextWithEmoji_ReturnsTrue;
  end;

implementation

uses
  System.SysUtils;

class function TEmojiSegmentsTests.Describe(const Segments: TArray<TEmojiSegment>): string;
begin
  Result := '';
  for var Segment in Segments do
  begin
    if Segment.IsEmoji then
      Result := Result + Format('E[%s]', [Segment.Text])
    else
      Result := Result + Format('T[%s]', [Segment.Text]);
  end;
end;

procedure TEmojiSegmentsTests.Split_EmptyText_ReturnsNoSegments;
begin
  const Segments = TEmojiSegments.Split('');

  Assert.AreEqual('', Describe(Segments));
end;

procedure TEmojiSegmentsTests.Split_PlainText_ReturnsSingleTextSegment;
begin
  const Segments = TEmojiSegments.Split(PlainTextWithArrow);

  Assert.AreEqual(Format('T[%s]', [PlainTextWithArrow]), Describe(Segments));
end;

procedure TEmojiSegmentsTests.Split_EmojiBetweenText_SeparatesEmojiSegment;
begin
  const Text = Format('a %s b', [SmileEmoji]);

  const Segments = TEmojiSegments.Split(Text);

  Assert.AreEqual(Format('T[a ]E[%s]T[ b]', [SmileEmoji]), Describe(Segments));
end;

procedure TEmojiSegmentsTests.Split_AdjacentEmoji_ShareOneSegment;
begin
  const Text = SmileEmoji + RocketEmoji;

  const Segments = TEmojiSegments.Split(Text);

  Assert.AreEqual(Format('E[%s]', [Text]), Describe(Segments));
end;

procedure TEmojiSegmentsTests.Split_JoinerSequence_StaysOneEmojiSegment;
begin
  const Text = Format('%s!', [WomanTechnologistEmoji]);

  const Segments = TEmojiSegments.Split(Text);

  Assert.AreEqual(Format('E[%s]T[!]', [WomanTechnologistEmoji]), Describe(Segments));
end;

procedure TEmojiSegmentsTests.Split_FlagSequence_StaysOneEmojiSegment;
begin
  const Text = Format('NL %s', [NetherlandsFlagEmoji]);

  const Segments = TEmojiSegments.Split(Text);

  Assert.AreEqual(Format('T[NL ]E[%s]', [NetherlandsFlagEmoji]), Describe(Segments));
end;

procedure TEmojiSegmentsTests.Split_KeycapSequence_StaysOneEmojiSegment;
begin
  const Text = Format('%s 1', [HashKeycapEmoji]);

  const Segments = TEmojiSegments.Split(Text);

  Assert.AreEqual(Format('E[%s]T[ 1]', [HashKeycapEmoji]), Describe(Segments));
end;

procedure TEmojiSegmentsTests.Split_TextCharacterWithEmojiSelector_IsEmoji;
begin
  const Text = Format('x%s', [SunWithSelectorEmoji]);

  const Segments = TEmojiSegments.Split(Text);

  Assert.AreEqual(Format('T[x]E[%s]', [SunWithSelectorEmoji]), Describe(Segments));
end;

procedure TEmojiSegmentsTests.Split_DefaultEmojiPresentationCharacter_IsEmoji;
begin
  const Text = Format('%s x', [HighVoltageEmoji]);

  const Segments = TEmojiSegments.Split(Text);

  Assert.AreEqual(Format('E[%s]T[ x]', [HighVoltageEmoji]), Describe(Segments));
end;

procedure TEmojiSegmentsTests.ContainsEmoji_JoinerInDevanagari_ReturnsFalse;
begin
  const HasEmoji = TEmojiSegments.ContainsEmoji(DevanagariWithJoiner);

  Assert.IsFalse(HasEmoji, 'A joiner that shapes Devanagari is not an emoji sequence');
end;

procedure TEmojiSegmentsTests.ContainsEmoji_PlainTextWithArrow_ReturnsFalse;
begin
  const HasEmoji = TEmojiSegments.ContainsEmoji(PlainTextWithArrow);

  Assert.IsFalse(HasEmoji, 'Text, digits, colons and an arrow keep their GDI rendering');
end;

procedure TEmojiSegmentsTests.ContainsEmoji_TextWithEmoji_ReturnsTrue;
begin
  const HasEmoji = TEmojiSegments.ContainsEmoji(Format('Regel met %s en %s', [SmileEmoji, RocketEmoji]));

  Assert.IsTrue(HasEmoji);
end;

end.
