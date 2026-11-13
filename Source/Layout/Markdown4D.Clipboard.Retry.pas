unit Markdown4D.Clipboard.Retry;

interface

type
  // One try at the clipboard; True when it needs no other.
  TMarkdownClipboardAttempt = reference to function: Boolean;

  // Another program may hold the clipboard open for a moment: a clipboard
  // manager or a password manager reads it right after every change. What a
  // control does with the clipboard in that moment is tried again here.
  TMarkdownClipboardRetry = record
  public
    const
      // The wait is on the UI thread, so it stays short.
      Attempts = 5;
      PauseMilliseconds = 20;

    // False when no attempt came through.
    class function TryRepeatedly(const Attempt: TMarkdownClipboardAttempt): Boolean; static;
  end;

implementation

uses
  System.SysUtils;

class function TMarkdownClipboardRetry.TryRepeatedly(const Attempt: TMarkdownClipboardAttempt): Boolean;
begin
  for var Count := 1 to Attempts do
  begin
    const IsDone = Attempt();
    if IsDone then
    begin
      Result := True;
      Exit;
    end;

    Sleep(PauseMilliseconds);
  end;

  Result := False;
end;

end.
