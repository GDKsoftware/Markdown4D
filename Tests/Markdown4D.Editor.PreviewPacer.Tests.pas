unit Markdown4D.Editor.PreviewPacer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.PreviewPacer;

type
  [TestFixture]
  TMarkdownPreviewPacerTests = class
  public
    [Test]
    [TestCase('NoUpdateYet', '0,60')]
    [TestCase('QuickUpdate', '5,60')]
    [TestCase('MediumUpdate', '100,400')]
    [TestCase('SlowUpdate', '1000,1500')]
    procedure DelayAfter_Update_IsFourTimesItsDurationWithinBounds(const UpdateMilliseconds, Expected: Integer);
  end;

implementation

procedure TMarkdownPreviewPacerTests.DelayAfter_Update_IsFourTimesItsDurationWithinBounds(const UpdateMilliseconds,
  Expected: Integer);
begin
  const Actual = TMarkdownPreviewPacer.DelayAfter(UpdateMilliseconds);

  Assert.AreEqual(Expected, Actual);
end;

end.
