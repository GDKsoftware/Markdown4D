unit Markdown4DStudio.Text.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TPadTextTests = class
  public
    [Test]
    procedure CountCharacters_EmptyText_ReturnsZero;

    [Test]
    [TestCase('Includes spaces', 'Hallo wereld,12')]
    [TestCase('Ignores LF', 'Hallo wereld'#10'# Hi,16')]
    [TestCase('Ignores CRLF', 'ab'#13#10'cd,4')]
    [TestCase('Counts markdown symbols', '**x**,5')]
    procedure CountCharacters_ReturnsExpectedCount(const Text: string; const Expected: Integer);

    [Test]
    procedure CountCharacters_SurrogatePairCountsAsOne;

    [Test]
    procedure CountCharacters_LoneSurrogateCountsAsOne;

    [Test]
    procedure CountWords_CountsWhitespaceSeparatedWords;
  end;

implementation

uses
  Markdown4DStudio.Text;

procedure TPadTextTests.CountCharacters_EmptyText_ReturnsZero;
begin
  const Actual = TPadText.CountCharacters('');

  Assert.AreEqual(0, Actual);
end;

procedure TPadTextTests.CountCharacters_ReturnsExpectedCount(const Text: string; const Expected: Integer);
begin
  const Actual = TPadText.CountCharacters(Text);

  Assert.AreEqual(Expected, Actual);
end;

procedure TPadTextTests.CountCharacters_SurrogatePairCountsAsOne;
begin
  const TextWithEmoji = 'a'#$D83D#$DE00'b';

  const Actual = TPadText.CountCharacters(TextWithEmoji);

  Assert.AreEqual(3, Actual);
end;

procedure TPadTextTests.CountCharacters_LoneSurrogateCountsAsOne;
begin
  const TextWithLoneSurrogate = 'a'#$D83D'b';

  const Actual = TPadText.CountCharacters(TextWithLoneSurrogate);

  Assert.AreEqual(3, Actual);
end;

procedure TPadTextTests.CountWords_CountsWhitespaceSeparatedWords;
begin
  const Actual = TPadText.CountWords('aa bb aa');

  Assert.AreEqual(3, Actual);
end;

end.
