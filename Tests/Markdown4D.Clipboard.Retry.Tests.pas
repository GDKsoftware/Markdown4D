unit Markdown4D.Clipboard.Retry.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownClipboardRetryTests = class
  public
    [Test]
    procedure TryRepeatedly_AttemptThatComesThrough_IsTriedOnce;

    [Test]
    procedure TryRepeatedly_AttemptThatComesThroughLater_IsTriedUntilThen;

    [Test]
    procedure TryRepeatedly_AttemptThatNeverComesThrough_IsFalseAfterEveryAttempt;
  end;

implementation

uses
  Markdown4D.Clipboard.Retry;

procedure TMarkdownClipboardRetryTests.TryRepeatedly_AttemptThatComesThrough_IsTriedOnce;
begin
  var Tries := 0;

  const IsDone = TMarkdownClipboardRetry.TryRepeatedly(
    function: Boolean
    begin
      Inc(Tries);
      Result := True;
    end);

  Assert.IsTrue(IsDone);
  Assert.AreEqual(1, Tries);
end;

procedure TMarkdownClipboardRetryTests.TryRepeatedly_AttemptThatComesThroughLater_IsTriedUntilThen;
begin
  const TriesNeeded = 3;
  var Tries := 0;

  const IsDone = TMarkdownClipboardRetry.TryRepeatedly(
    function: Boolean
    begin
      Inc(Tries);
      Result := (Tries = TriesNeeded);
    end);

  Assert.IsTrue(IsDone);
  Assert.AreEqual(TriesNeeded, Tries);
end;

procedure TMarkdownClipboardRetryTests.TryRepeatedly_AttemptThatNeverComesThrough_IsFalseAfterEveryAttempt;
begin
  var Tries := 0;

  const IsDone = TMarkdownClipboardRetry.TryRepeatedly(
    function: Boolean
    begin
      Inc(Tries);
      Result := False;
    end);

  Assert.IsFalse(IsDone);
  Assert.AreEqual(TMarkdownClipboardRetry.Attempts, Tries);
end;

end.
