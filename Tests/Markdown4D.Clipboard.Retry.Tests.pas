unit Markdown4D.Clipboard.Retry.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownClipboardRetryTests = class
  private
    const
      LongPauseMilliseconds = 1000;
      ReadText = 'alpha';

  public
    [Test]
    procedure TryRepeatedly_AttemptThatComesThrough_IsTriedOnce;

    [Test]
    procedure TryRepeatedly_AttemptThatComesThroughLater_IsTriedUntilThen;

    [Test]
    procedure TryRepeatedly_AttemptThatNeverComesThrough_IsFalseAfterEveryAttempt;

    [Test]
    procedure TryRepeatedly_LastAttemptFails_DoesNotWaitAfterIt;

    [Test]
    procedure TryReadText_ReadThatNeedsAnother_ReadsAgain;

    [Test]
    procedure TryReadText_EmptyTextAnswer_IsFalseAfterOneRead;
  end;

implementation

uses
  System.Diagnostics,
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

procedure TMarkdownClipboardRetryTests.TryRepeatedly_LastAttemptFails_DoesNotWaitAfterIt;
begin
  const Watch = TStopwatch.StartNew;

  TMarkdownClipboardRetry.TryRepeatedly(
    function: Boolean
    begin
      Result := False;
    end,
    1,
    LongPauseMilliseconds);

  const HasWaited = (Watch.ElapsedMilliseconds >= LongPauseMilliseconds);
  Assert.IsFalse(HasWaited);
end;

procedure TMarkdownClipboardRetryTests.TryReadText_ReadThatNeedsAnother_ReadsAgain;
begin
  var Reads := 0;

  var Text: string;
  const IsRead = TMarkdownClipboardRetry.TryReadText(
    function(out Value: string): Boolean
    begin
      Inc(Reads);
      Result := (Reads = 2);
      if Result then
        Value := ReadText
      else
        Value := '';
    end,
    Text);

  Assert.IsTrue(IsRead);
  Assert.AreEqual(ReadText, Text);
  Assert.AreEqual(2, Reads);
end;

procedure TMarkdownClipboardRetryTests.TryReadText_EmptyTextAnswer_IsFalseAfterOneRead;
begin
  var Reads := 0;

  var Text: string;
  const IsRead = TMarkdownClipboardRetry.TryReadText(
    function(out Value: string): Boolean
    begin
      Inc(Reads);
      Value := '';
      Result := True;
    end,
    Text);

  Assert.IsFalse(IsRead);
  Assert.AreEqual('', Text);
  Assert.AreEqual(1, Reads);
end;

end.
