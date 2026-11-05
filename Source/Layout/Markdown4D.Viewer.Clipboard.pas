unit Markdown4D.Viewer.Clipboard;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  // Puts a copied formula on the clipboard as text and as presentation MathML
  // at once: Word and LibreOffice paste the MathML as an editable equation,
  // every other program takes the text. Neither viewer's clipboard offers
  // that on its own, FMX's empties the clipboard for every format it writes,
  // so on Windows the clipboard is written here directly, in the formats
  // MathML and MathML Presentation that Word reads. Elsewhere
  // TryPutTextAndMathML is False and the viewer puts the text alone.
  TMarkdownMathClipboard = record
  private
    const
      MathMLFormat = 'MathML';
      MathMLPresentationFormat = 'MathML Presentation';
{$IFDEF MSWINDOWS}
    class function TryPutData(const Format: Cardinal; const Data: TBytes): Boolean; static;
{$ENDIF}

  public
    class function TryPutTextAndMathML(const Text, MathML: string): Boolean; static;
    // Text ends in a null character, as CF_UNICODETEXT requires.
    class function TextData(const Text: string): TBytes; static;
    // MathML in UTF-16LE, as Word writes and reads it on the clipboard. It has
    // no null character at the end: Word pastes plain text when it finds one.
    class function MathMLData(const MathML: string): TBytes; static;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;
{$ENDIF}

{$IFDEF MSWINDOWS}
// No window owns the clipboard, as with FMX's own clipboard service; that only
// rules out rendering a format later, and every format is put here at once.
class function TMarkdownMathClipboard.TryPutTextAndMathML(const Text, MathML: string): Boolean;
begin
  Result := False;
  if not OpenClipboard(0) then
    Exit;

  try
    EmptyClipboard;

    const MathMLDocument = MathMLData(MathML);
    Result := TryPutData(CF_UNICODETEXT, TextData(Text));
    if Result then
      Result := TryPutData(RegisterClipboardFormat(MathMLFormat), MathMLDocument);
    if Result then
      Result := TryPutData(RegisterClipboardFormat(MathMLPresentationFormat), MathMLDocument);
  finally
    CloseClipboard;
  end;
end;
{$ELSE}
class function TMarkdownMathClipboard.TryPutTextAndMathML(const Text, MathML: string): Boolean;
begin
  Result := False;
end;
{$ENDIF}

class function TMarkdownMathClipboard.TextData(const Text: string): TBytes;
begin
  Result := TEncoding.Unicode.GetBytes(Text + #0);
end;

class function TMarkdownMathClipboard.MathMLData(const MathML: string): TBytes;
begin
  Result := TEncoding.Unicode.GetBytes(MathML);
end;

{$IFDEF MSWINDOWS}
// The clipboard owns the memory once it takes it; until then it is freed here.
class function TMarkdownMathClipboard.TryPutData(const Format: Cardinal; const Data: TBytes): Boolean;
begin
  Result := False;

  const Memory = GlobalAlloc(GMEM_MOVEABLE, Length(Data));
  const IsAllocated = (Memory <> 0);
  if not IsAllocated then
    Exit;

  const Target = GlobalLock(Memory);
  const IsLocked = (Target <> nil);
  if not IsLocked then
  begin
    GlobalFree(Memory);
    Exit;
  end;

  Move(Data[0], Target^, Length(Data));
  GlobalUnlock(Memory);

  Result := (SetClipboardData(Format, Memory) <> 0);
  if not Result then
    GlobalFree(Memory);
end;
{$ENDIF}

end.
