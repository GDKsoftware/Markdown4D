unit Markdown4D.Clipboard.Retry;

interface

type
  // One try at the clipboard; True when it needs no other.
  TMarkdownClipboardAttempt = reference to function: Boolean;

  // One try at reading text from the clipboard; True when it needs no other.
  // Text is what it read, empty when the clipboard held none.
  TMarkdownClipboardRead = reference to function(out Text: string): Boolean;

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
    class function TryRepeatedly(const Attempt: TMarkdownClipboardAttempt): Boolean; overload; static;
    // The same with a patience of the caller's own, for one that can wait
    // longer than a control on the UI thread.
    class function TryRepeatedly(const Attempt: TMarkdownClipboardAttempt;
                                 const MaxAttempts: Integer;
                                 const Pause: Cardinal): Boolean; overload; static;
    // Reads until an attempt needs no other. True with the text when the last
    // read gave a text that is not empty; False, with an empty Value, otherwise.
    class function TryReadText(const Read: TMarkdownClipboardRead; out Value: string): Boolean; static;
  end;

implementation

uses
  System.SysUtils;

class function TMarkdownClipboardRetry.TryRepeatedly(const Attempt: TMarkdownClipboardAttempt): Boolean;
begin
  Result := TryRepeatedly(Attempt, Attempts, PauseMilliseconds);
end;

class function TMarkdownClipboardRetry.TryRepeatedly(const Attempt: TMarkdownClipboardAttempt;
                                                     const MaxAttempts: Integer;
                                                     const Pause: Cardinal): Boolean;
begin
  for var Count := 1 to MaxAttempts do
  begin
    const IsDone = Attempt();
    if IsDone then
    begin
      Result := True;
      Exit;
    end;

    const IsLastAttempt = (Count = MaxAttempts);
    if not IsLastAttempt then
      Sleep(Pause);
  end;

  Result := False;
end;

class function TMarkdownClipboardRetry.TryReadText(const Read: TMarkdownClipboardRead; out Value: string): Boolean;
begin
  var Text := '';

  TryRepeatedly(
    function: Boolean
    begin
      Result := Read(Text);
    end);

  Value := Text;
  Result := (Text <> '');
end;

end.
