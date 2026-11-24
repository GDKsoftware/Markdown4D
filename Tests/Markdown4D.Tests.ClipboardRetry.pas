unit Markdown4D.Tests.ClipboardRetry;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Clipboard.Retry;

type
  // The tests that set up or check the real clipboard wait longer for another
  // process than a control does on the UI thread, so a busy moment does not
  // end a test before it tested anything.
  TTestClipboardRetry = record
  public
    const
      Attempts = 20;
      PauseMilliseconds = 25;

    class function TryRepeatedly(const Attempt: TMarkdownClipboardAttempt): Boolean; static;
  end;

implementation

class function TTestClipboardRetry.TryRepeatedly(const Attempt: TMarkdownClipboardAttempt): Boolean;
begin
  Result := TMarkdownClipboardRetry.TryRepeatedly(Attempt, Attempts, PauseMilliseconds);
end;

end.
