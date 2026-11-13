unit Markdown4D.Viewer.Clipboard;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  // Puts copied text with formulas on the clipboard in the forms Word and
  // LibreOffice paste as editable equations: HTML with a MathML element for
  // each formula, and for a selection of one whole formula the formats MathML
  // and MathML Presentation as well. Every other program takes the text.
  // Neither viewer's clipboard offers that on its own, FMX's empties the
  // clipboard for every format it writes, so on Windows the clipboard is
  // written here directly, opened for a window of its own as Windows asks.
  // Elsewhere TryPutTextWithMath is False and the viewer puts the text alone.
  TMarkdownMathClipboard = record
  private
    const
      HtmlFormat = 'HTML Format';
      MathMLFormat = 'MathML';
      MathMLPresentationFormat = 'MathML Presentation';
      HtmlHeader = 'Version:0.9'#13#10'StartHTML:%.10d'#13#10'EndHTML:%.10d'#13#10 +
                   'StartFragment:%.10d'#13#10'EndFragment:%.10d'#13#10;
      HtmlBeforeFragment = '<html><body><!--StartFragment-->';
      HtmlAfterFragment = '<!--EndFragment--></body></html>';
      OwnerWindowClass = 'STATIC';
{$IFDEF MSWINDOWS}
    class function TryOpen(const OwnerWindow: NativeUInt): Boolean; static;
    class function TryPutFormats(const Text, Html, MathML: string): Boolean; static;
    class function TryPutData(const ClipboardFormat: Cardinal; const Data: TBytes): Boolean; static;
    class function TryPutNamedData(const FormatName: string; const Data: TBytes): Boolean; static;
    class function TryPutMathML(const MathML: string): Boolean; static;
{$ENDIF}

  public
    // Html and MathML may be empty; the formats for them are then left out.
    class function TryPutTextWithMath(const Text, Html, MathML: string): Boolean; static;
    // How often the clipboard has changed, to hand to HasChangedSince.
    class function ChangeCount: Cardinal; static;
    // True when the clipboard has changed since Count was read, or when the
    // platform keeps no count. A caller tells by it whether a write got there
    // when the write itself does not say, as the one of the FMX clipboard
    // service on Windows.
    class function HasChangedSince(const Count: Cardinal): Boolean; static;
    // Text ends in a null character, as CF_UNICODETEXT requires.
    class function TextData(const Text: string): TBytes; static;
    // The HTML Format: a header with the byte offsets of the document and the
    // fragment in it, then the document, all in UTF-8.
    class function HtmlData(const Fragment: string): TBytes; static;
    // MathML in UTF-16LE, as Word writes and reads it on the clipboard. It has
    // no null character at the end: Word pastes plain text when it finds one.
    class function MathMLData(const MathML: string): TBytes; static;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows,
  Markdown4D.Clipboard.Retry;
{$ENDIF}

{$IFDEF MSWINDOWS}
// SetClipboardData fails after OpenClipboard without a window, so the clipboard
// is opened for a message-only window that lives as long as the copy, as the
// VCL's TClipboard does with a window it allocates.
class function TMarkdownMathClipboard.TryPutTextWithMath(const Text, Html, MathML: string): Boolean;
begin
  Result := False;

  const OwnerWindow = CreateWindowEx(0, OwnerWindowClass, nil, 0, 0, 0, 0, 0, HWND_MESSAGE, 0, HInstance, nil);
  const IsCreated = (OwnerWindow <> 0);
  if not IsCreated then
    Exit;

  try
    const IsOpened = TryOpen(OwnerWindow);
    if not IsOpened then
      Exit;

    try
      Result := TryPutFormats(Text, Html, MathML);
    finally
      CloseClipboard;
    end;
  finally
    DestroyWindow(OwnerWindow);
  end;
end;

// Opening is tried again while another program holds the clipboard, or the
// formulas of a copy made in that moment are lost.
class function TMarkdownMathClipboard.TryOpen(const OwnerWindow: NativeUInt): Boolean;
begin
  Result := TMarkdownClipboardRetry.TryRepeatedly(
    function: Boolean
    begin
      Result := OpenClipboard(OwnerWindow);
    end);
end;

class function TMarkdownMathClipboard.ChangeCount: Cardinal;
begin
  Result := GetClipboardSequenceNumber;
end;

class function TMarkdownMathClipboard.HasChangedSince(const Count: Cardinal): Boolean;
begin
  Result := (GetClipboardSequenceNumber <> Count);
end;

class function TMarkdownMathClipboard.TryPutFormats(const Text, Html, MathML: string): Boolean;
begin
  EmptyClipboard;

  const Data = TextData(Text);
  Result := TryPutData(CF_UNICODETEXT, Data);

  const HasHtml = (Html <> '');
  if Result and HasHtml then
  begin
    const Document = HtmlData(Html);
    Result := TryPutNamedData(HtmlFormat, Document);
  end;

  const HasMathML = (MathML <> '');
  if Result and HasMathML then
    Result := TryPutMathML(MathML);
end;

// Word reads the one format, LibreOffice the other.
class function TMarkdownMathClipboard.TryPutMathML(const MathML: string): Boolean;
begin
  const Document = MathMLData(MathML);
  Result := (TryPutNamedData(MathMLFormat, Document) and TryPutNamedData(MathMLPresentationFormat, Document));
end;

class function TMarkdownMathClipboard.TryPutNamedData(const FormatName: string; const Data: TBytes): Boolean;
begin
  const ClipboardFormat = RegisterClipboardFormat(PChar(FormatName));
  Result := TryPutData(ClipboardFormat, Data);
end;
{$ELSE}
class function TMarkdownMathClipboard.TryPutTextWithMath(const Text, Html, MathML: string): Boolean;
begin
  Result := False;
end;

class function TMarkdownMathClipboard.ChangeCount: Cardinal;
begin
  Result := 0;
end;

class function TMarkdownMathClipboard.HasChangedSince(const Count: Cardinal): Boolean;
begin
  Result := True;
end;
{$ENDIF}

class function TMarkdownMathClipboard.TextData(const Text: string): TBytes;
begin
  Result := TEncoding.Unicode.GetBytes(Text + #0);
end;

class function TMarkdownMathClipboard.HtmlData(const Fragment: string): TBytes;
begin
  const EmptyHeader = Format(HtmlHeader, [0, 0, 0, 0]);
  const FragmentLength = TEncoding.UTF8.GetByteCount(Fragment);

  const StartHtml = Length(EmptyHeader);
  const StartFragment = StartHtml + Length(HtmlBeforeFragment);
  const EndFragment = StartFragment + FragmentLength;
  const EndHtml = EndFragment + Length(HtmlAfterFragment);

  const Header = Format(HtmlHeader, [StartHtml, EndHtml, StartFragment, EndFragment]);
  Result := TEncoding.UTF8.GetBytes(Header + HtmlBeforeFragment + Fragment + HtmlAfterFragment + #0);
end;

class function TMarkdownMathClipboard.MathMLData(const MathML: string): TBytes;
begin
  Result := TEncoding.Unicode.GetBytes(MathML);
end;

{$IFDEF MSWINDOWS}
// The clipboard owns the memory once it takes it; until then it is freed here.
class function TMarkdownMathClipboard.TryPutData(const ClipboardFormat: Cardinal; const Data: TBytes): Boolean;
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

  const ClipboardData = SetClipboardData(ClipboardFormat, Memory);
  Result := (ClipboardData <> 0);
  if not Result then
    GlobalFree(Memory);
end;
{$ENDIF}

end.
