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
  // MathML and MathML Presentation that Word reads, both an XML document in
  // UTF-8. Elsewhere TryPutTextAndMathML is False and the viewer puts the
  // text alone.
  TMarkdownMathClipboard = record
  private
    const
      XmlDeclaration = '<?xml version="1.0"?>';
      MathMLFormat = 'MathML';
      MathMLPresentationFormat = 'MathML Presentation';
{$IFDEF MSWINDOWS}
    class function TryPutData(const Format: Cardinal; const Data: TBytes): Boolean; static;
{$ENDIF}
  public
    class function TryPutTextAndMathML(const Text, MathML: string): Boolean; static;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;
{$ENDIF}

{$IFDEF MSWINDOWS}
class function TMarkdownMathClipboard.TryPutTextAndMathML(const Text, MathML: string): Boolean;
begin
  Result := False;
  if not OpenClipboard(0) then
    Exit;

  try
    EmptyClipboard;

    const MathMLDocument = TEncoding.UTF8.GetBytes(XmlDeclaration + MathML);
    Result := TryPutData(CF_UNICODETEXT, TEncoding.Unicode.GetBytes(Text)) and
              TryPutData(RegisterClipboardFormat(MathMLFormat), MathMLDocument) and
              TryPutData(RegisterClipboardFormat(MathMLPresentationFormat), MathMLDocument);
  finally
    CloseClipboard;
  end;
end;

// The clipboard owns the memory once it takes it; until then it is freed here.
// Every format ends in a null character, two bytes wide so it also ends text.
class function TMarkdownMathClipboard.TryPutData(const Format: Cardinal; const Data: TBytes): Boolean;
const
  TerminatorSize = 2;
begin
  const Memory = GlobalAlloc(GMEM_MOVEABLE or GMEM_ZEROINIT, Length(Data) + TerminatorSize);
  if Memory = 0 then
  begin
    Result := False;
    Exit;
  end;

  const Target = GlobalLock(Memory);
  if Length(Data) > 0 then
    Move(Data[0], Target^, Length(Data));
  GlobalUnlock(Memory);

  Result := (SetClipboardData(Format, Memory) <> 0);
  if not Result then
    GlobalFree(Memory);
end;
{$ELSE}
class function TMarkdownMathClipboard.TryPutTextAndMathML(const Text, MathML: string): Boolean;
begin
  Result := False;
end;
{$ENDIF}

end.
