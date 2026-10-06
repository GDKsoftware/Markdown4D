unit Markdown4D.Tests.VclClipboard;

{$SCOPEDENUMS ON}

interface

type
  // The real clipboard, read and written with a few attempts, because another
  // process may hold it open for a moment.
  TVclTestClipboard = record
  private
    const
      Attempts = 20;
      PauseMilliseconds = 25;

  public
    class function IsAccessible: Boolean; static;
    class function TryGetText(out Value: string): Boolean; static;
    class function TrySetText(const Value: string): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  Vcl.Clipbrd;

class function TVclTestClipboard.IsAccessible: Boolean;
begin
  for var Attempt := 1 to Attempts do
  begin
    try
      Clipboard.Open;
      Clipboard.Close;
      Result := True;
      Exit;
    except
      on EClipboardException do
        Sleep(PauseMilliseconds);
    end;
  end;

  Result := False;
end;

class function TVclTestClipboard.TryGetText(out Value: string): Boolean;
begin
  Value := '';

  for var Attempt := 1 to Attempts do
  begin
    try
      Value := Clipboard.AsText;
      Result := True;
      Exit;
    except
      on EClipboardException do
        Sleep(PauseMilliseconds);
    end;
  end;

  Result := False;
end;

class function TVclTestClipboard.TrySetText(const Value: string): Boolean;
begin
  for var Attempt := 1 to Attempts do
  begin
    try
      Clipboard.AsText := Value;
      Result := True;
      Exit;
    except
      on EClipboardException do
        Sleep(PauseMilliseconds);
    end;
  end;

  Result := False;
end;

end.
