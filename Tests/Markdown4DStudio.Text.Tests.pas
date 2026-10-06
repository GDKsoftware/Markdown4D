unit Markdown4DStudio.Text.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4DStudio.Text;

type
  [TestFixture]
  TPadTextTests = class
  public
    [Test]
    procedure CountCharacters_EmptyText_ReturnsZero;

    [Test]
    procedure CountCharacters_IncludesSpaces;

    [Test]
    procedure CountCharacters_IgnoresLf;

    [Test]
    procedure CountCharacters_IgnoresCrLf;

    [Test]
    procedure CountCharacters_CountsMarkdownSymbols;

    [Test]
    procedure CountCharacters_SurrogatePairCountsAsOne;

    [Test]
    procedure CountCharacters_LoneSurrogateCountsAsOne;

    [Test]
    procedure CountWords_CountsWhitespaceSeparatedWords;
  end;

implementation

procedure TPadTextTests.CountCharacters_EmptyText_ReturnsZero;
begin
  const Actual = TPadText.CountCharacters('');

  Assert.AreEqual(0, Actual);
end;

procedure TPadTextTests.CountCharacters_IncludesSpaces;
begin
  const Actual = TPadText.CountCharacters('Hallo wereld');

  Assert.AreEqual(12, Actual);
end;

procedure TPadTextTests.CountCharacters_IgnoresLf;
begin
  const Actual = TPadText.CountCharacters('Hallo wereld'#10'# Hi');

  Assert.AreEqual(16, Actual);
end;

procedure TPadTextTests.CountCharacters_IgnoresCrLf;
begin
  const Actual = TPadText.CountCharacters('ab'#13#10'cd');

  Assert.AreEqual(4, Actual);
end;

procedure TPadTextTests.CountCharacters_CountsMarkdownSymbols;
begin
  const Actual = TPadText.CountCharacters('**x**');

  Assert.AreEqual(5, Actual);
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
