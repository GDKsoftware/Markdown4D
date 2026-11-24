unit Markdown4D.Tests.VclClipboard;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  // The real clipboard, read and written with the patience of the tests,
  // because another process may hold it open for a moment.
  TVclTestClipboard = record
  private
    class function TryRepeatedly(const Action: TProc): Boolean; static;

  public
    class function IsAccessible: Boolean; static;
    class function TryGetText(out Value: string): Boolean; static;
    class function TrySetText(const Value: string): Boolean; static;
    class function TryClear: Boolean; static;
  end;

implementation

uses
  Vcl.Clipbrd,
  Markdown4D.Tests.ClipboardRetry;

class function TVclTestClipboard.TryRepeatedly(const Action: TProc): Boolean;
begin
  Result := TTestClipboardRetry.TryRepeatedly(
    function: Boolean
    begin
      try
        Action;
        Result := True;
      except
        on EClipboardException do
          Result := False;
      end;
    end);
end;

class function TVclTestClipboard.IsAccessible: Boolean;
begin
  Result := TryRepeatedly(
    procedure
    begin
      Clipboard.Open;
      Clipboard.Close;
    end);
end;

class function TVclTestClipboard.TryGetText(out Value: string): Boolean;
begin
  var Text := '';

  Result := TryRepeatedly(
    procedure
    begin
      Text := Clipboard.AsText;
    end);

  Value := Text;
end;

class function TVclTestClipboard.TrySetText(const Value: string): Boolean;
begin
  Result := TryRepeatedly(
    procedure
    begin
      Clipboard.AsText := Value;
    end);
end;

class function TVclTestClipboard.TryClear: Boolean;
begin
  Result := TryRepeatedly(
    procedure
    begin
      Clipboard.Clear;
    end);
end;

end.
