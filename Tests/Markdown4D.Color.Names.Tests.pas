unit Markdown4D.Color.Names.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownColorNamesTests = class
  public
    [Test]
    [TestCase('Name', 'red,$FFFF0000')]
    [TestCase('NameIgnoresCase', 'LightBlue,$FFADD8E6')]
    [TestCase('NameIgnoresSpaces', ' orange ,$FFFFA500')]
    [TestCase('CssColor4Name', 'rebeccapurple,$FF663399')]
    [TestCase('LongHex', '#1f883d,$FF1F883D')]
    [TestCase('LongHexWithoutHash', '1F883D,$FF1F883D')]
    [TestCase('ShortHex', '#0af,$FF00AAFF')]
    procedure TryParse_KnownColor_ReturnsOpaqueColor(const Value: string; const Expected: Cardinal);

    [Test]
    [TestCase('UnknownName', 'nosuchcolor')]
    [TestCase('TransparentRtlEntry', 'null')]
    [TestCase('NameMissingFirstLetter', 'qua')]
    [TestCase('Empty', '')]
    [TestCase('FourDigits', '#abcd')]
    [TestCase('NonHexDigits', '#12345g')]
    procedure TryParse_UnknownColor_ReturnsFalse(const Value: string);
  end;

implementation

uses
  Markdown4D.Color.Names;

procedure TMarkdownColorNamesTests.TryParse_KnownColor_ReturnsOpaqueColor(const Value: string;
  const Expected: Cardinal);
begin
  var Color: Cardinal;
  const IsKnown = TMarkdownColorNames.TryParse(Value, Color);

  Assert.IsTrue(IsKnown);
  Assert.AreEqual<Cardinal>(Expected, Color);
end;

procedure TMarkdownColorNamesTests.TryParse_UnknownColor_ReturnsFalse(const Value: string);
begin
  var Color: Cardinal;
  const IsKnown = TMarkdownColorNames.TryParse(Value, Color);

  Assert.IsFalse(IsKnown);
end;

end.
