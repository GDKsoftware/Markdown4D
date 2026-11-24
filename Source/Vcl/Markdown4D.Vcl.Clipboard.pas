unit Markdown4D.Vcl.Clipboard;

interface

type
  // Text to and from the clipboard for the VCL controls. The clipboard belongs
  // to the whole machine and any process may hold it for a moment. A control
  // that raised over that would put a dialog in front of a reader who only
  // pressed a key, so a clipboard that stays busy is a copy or a paste that
  // did not happen and nothing more. The VCL says the clipboard is busy with
  // EClipboardException, and that is what is tried again.
  TMarkdownVclClipboard = record
  private
    class function TryWriteOnce(const Value: string): Boolean; static;
    class function TryReadOnce(out Value: string): Boolean; static;

  public
    // False when the text did not get there.
    class function TryWriteText(const Value: string): Boolean; static;
    // True with the text when the clipboard holds a text that is not empty;
    // False, with an empty Value, when it holds no text or an empty text, or
    // stays busy. TMarkdownFmxClipboard.TryReadText answers the same.
    class function TryReadText(out Value: string): Boolean; static;
    // True when the clipboard holds text. It looks at the formats on the
    // clipboard without opening it, so it does not wait for a busy one, and a
    // text format counts, even for an empty text.
    class function HasText: Boolean; static;
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
      Result := TryWriteOnce(Value);
    end);
end;

class function TMarkdownVclClipboard.TryWriteOnce(const Value: string): Boolean;
begin
  try
    Clipboard.AsText := Value;
    Result := True;
  except
    on EClipboardException do
      Result := False;
  end;
end;

class function TMarkdownVclClipboard.TryReadText(out Value: string): Boolean;
begin
  Result := TMarkdownClipboardRetry.TryReadText(TryReadOnce, Value);
end;

// A read the VCL lets through is an answer, an empty text included.
class function TMarkdownVclClipboard.TryReadOnce(out Value: string): Boolean;
begin
  Value := '';

  try
    const IsText = Clipboard.HasFormat(CF_UNICODETEXT);
    if IsText then
      Value := Clipboard.AsText;

    Result := True;
  except
    on EClipboardException do
      Result := False;
  end;
end;

class function TMarkdownVclClipboard.HasText: Boolean;
begin
  try
    Result := Clipboard.HasFormat(CF_UNICODETEXT);
  except
    on EClipboardException do
      Result := False;
  end;
end;

end.
