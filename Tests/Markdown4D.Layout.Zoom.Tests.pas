unit Markdown4D.Layout.Zoom.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Zoom;

type
  [TestFixture]
  TMarkdownZoomTests = class
  public
    [Test]
    [TestCase('FromDefault', '100,110')]
    [TestCase('BetweenLevels', '105,110')]
    [TestCase('LargerStep', '200,250')]
    [TestCase('AtMaximum', '500,500')]
    procedure StepIn_Percent_ReturnsNextLevelUp(const Percent, Expected: Integer);

    [Test]
    [TestCase('FromDefault', '100,90')]
    [TestCase('BetweenLevels', '105,100')]
    [TestCase('SmallerStep', '50,33')]
    [TestCase('AtMinimum', '25,25')]
    procedure StepOut_Percent_ReturnsNextLevelDown(const Percent, Expected: Integer);

    [Test]
    [TestCase('BelowMinimum', '10,25')]
    [TestCase('AboveMaximum', '600,500')]
    [TestCase('InRange', '150,150')]
    procedure Clamp_Percent_StaysWithinMinimumAndMaximum(const Percent, Expected: Integer);

    [Test]
    [TestCase('PlusMainKeyboard', '187,StepIn')]
    [TestCase('PlusNumericKeypad', '107,StepIn')]
    [TestCase('MinusMainKeyboard', '189,StepOut')]
    [TestCase('MinusNumericKeypad', '109,StepOut')]
    [TestCase('ZeroMainKeyboard', '48,Reset')]
    [TestCase('ZeroNumericKeypad', '96,Reset')]
    [TestCase('OtherKey', '65,None')]
    procedure ActionOfKey_Key_ReturnsZoomAction(const Key: Word; const Expected: TMarkdownZoomAction);
  end;

implementation

procedure TMarkdownZoomTests.StepIn_Percent_ReturnsNextLevelUp(const Percent, Expected: Integer);
begin
  const Actual = TMarkdownZoom.StepIn(Percent);

  Assert.AreEqual(Expected, Actual);
end;

procedure TMarkdownZoomTests.StepOut_Percent_ReturnsNextLevelDown(const Percent, Expected: Integer);
begin
  const Actual = TMarkdownZoom.StepOut(Percent);

  Assert.AreEqual(Expected, Actual);
end;

procedure TMarkdownZoomTests.Clamp_Percent_StaysWithinMinimumAndMaximum(const Percent, Expected: Integer);
begin
  const Actual = TMarkdownZoom.Clamp(Percent);

  Assert.AreEqual(Expected, Actual);
end;

procedure TMarkdownZoomTests.ActionOfKey_Key_ReturnsZoomAction(const Key: Word;
  const Expected: TMarkdownZoomAction);
begin
  const Actual = TMarkdownZoom.ActionOfKey(Key);

  Assert.AreEqual<TMarkdownZoomAction>(Expected, Actual);
end;

end.
