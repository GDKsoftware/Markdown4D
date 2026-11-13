unit Markdown4D.Vcl.Clipboard;

interface

type
  // Text to and from the clipboard for the VCL controls. The clipboard belongs
  // to the whole machine and any process may hold it for a moment. A control
  // that raised over that would put a dialog in front of a reader who only
  // pressed a key, so a clipboard that stays busy is a copy or a paste that
  // did not happen and nothing more.
  TMarkdownVclClipboard = record
  public
    class function TryWriteText(const Value: string): Boolean; static;
    // False as well when the clipboard holds no text.
    class function TryReadText(out Value: string): Boolean; static;
  end;

implementation

uses
  Winapi.Windows,
  Vcl.Clipbrd,
  Markdown4D.Clipboard.Retry;

class function TMarkdownVclClipboard.TryWriteText(const Value: string): Boolean;
begin
  Result := TMarkdownClipboardRetry.TryRepeatedly(
    function: Boolean
    begin
      try
        Clipboard.AsText := Value;
        Result := True;
      except
        on EClipboardException do
          Result := False;
      end;
    end);
end;

class function TMarkdownVclClipboard.TryReadText(out Value: string): Boolean;
begin
  var Text := '';
  var HasText := False;

  TMarkdownClipboardRetry.TryRepeatedly(
    function: Boolean
    begin
      try
        const IsText = Clipboard.HasFormat(CF_UNICODETEXT);
        if IsText then
          Text := Clipboard.AsText;

        HasText := IsText;
        Result := True;
      except
        on EClipboardException do
          Result := False;
      end;
    end);

  Value := Text;
  Result := HasText;
end;

end.
