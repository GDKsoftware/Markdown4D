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
    procedure DelayMilliseconds_BeforeAnyUpdate_IsTheShortestPause;

    [Test]
    [TestCase('QuickUpdate', '5,60')]
    [TestCase('MediumUpdate', '100,400')]
    [TestCase('SlowUpdate', '1000,1500')]
    procedure DelayMilliseconds_AfterUpdate_IsFourTimesItsDurationWithinBounds(const UpdateMilliseconds,
                                                                                  Expected: Integer);
  end;

implementation

procedure TMarkdownPreviewPacerTests.DelayMilliseconds_BeforeAnyUpdate_IsTheShortestPause;
begin
  const Pacer = Default(TMarkdownPreviewPacer);

  Assert.AreEqual(TMarkdownPreviewPacer.ShortestDelayMilliseconds, Pacer.DelayMilliseconds);
end;

procedure TMarkdownPreviewPacerTests.DelayMilliseconds_AfterUpdate_IsFourTimesItsDurationWithinBounds(
  const UpdateMilliseconds, Expected: Integer);
begin
  var Pacer := Default(TMarkdownPreviewPacer);

  Pacer.UpdateTook(UpdateMilliseconds);

  Assert.AreEqual(Expected, Pacer.DelayMilliseconds);
end;

end.
