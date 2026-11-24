unit Markdown4D.Fmx.Clipboard;

interface

uses
  System.SysUtils,
  FMX.Platform;

type
  // Text to and from the clipboard for the FMX controls, through the clipboard
  // service of the platform or the one the application put in its place.
  // Another program may hold the clipboard open for a moment: a clipboard
  // manager or a password manager reads it right after every change. A
  // clipboard that stays busy is a copy or a paste that did not happen and
  // nothing more. IFMXClipboardService has a separate implementation per
  // platform, and none of them says the clipboard is busy with an exception of
  // its own, so an attempt that raises is tried again, unless it raised for a
  // programming error or an abort, which reach the application.
  TMarkdownFmxClipboard = record
  private
    class function TryGetService(out Clipboard: IFMXClipboardService): Boolean; static;
    class function TryWriteOnce(const Clipboard: IFMXClipboardService; const Value: string): Boolean; static;
    class function TryReadOnce(const Clipboard: IFMXClipboardService; out Value: string): Boolean; static;
    class function MustReachApplication(const Error: Exception): Boolean; static;
    class function ClaimsText(const Clipboard: IFMXClipboardService): Boolean; static;

  public
    // False when the text did not get there, at once when there is no
    // clipboard service.
    class function TryWriteText(const Value: string): Boolean; static;
    // True with the text when the clipboard holds a text that is not empty;
    // False, with an empty Value, when it holds no text or an empty text, or
    // stays busy. TMarkdownVclClipboard.TryReadText answers the same. A read
    // that raised is tried again. An empty text is read again only when the
    // service still says it holds text, since FMX's service for Windows reads
    // a held clipboard as an empty text.
    class function TryReadText(out Value: string): Boolean; static;
    // True when the clipboard holds text, without waiting for a busy one.
    class function HasText: Boolean; static;
  end;

implementation

uses
  System.Rtti,
  FMX.Clipboard,
  Markdown4D.Clipboard.Retry,
  Markdown4D.Viewer.Clipboard;

class function TMarkdownFmxClipboard.TryWriteText(const Value: string): Boolean;
begin
  var Clipboard: IFMXClipboardService;
  if not TryGetService(Clipboard) then
  begin
    Result := False;
    Exit;
  end;

  Result := TMarkdownClipboardRetry.TryRepeatedly(
    function: Boolean
    begin
      Result := TryWriteOnce(Clipboard, Value);
    end);
end;

class function TMarkdownFmxClipboard.TryGetService(out Clipboard: IFMXClipboardService): Boolean;
begin
  Result := TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clipboard);
end;

// The clipboard service FMX has for Windows does not say when the text did not
// get there, but Windows counts the changes of the clipboard, and the count
// stands still then: the write is tried again. The count stands still as well
// under a service the application put in place of FMX's, which holds the text
// all the same, and other platforms keep no count; either is written once.
class function TMarkdownFmxClipboard.TryWriteOnce(const Clipboard: IFMXClipboardService;
                                                  const Value: string): Boolean;
begin
  try
    const Before = TMarkdownMathClipboard.ChangeCount;
    Clipboard.SetClipboard(Value);

    Result := TMarkdownMathClipboard.HasChangedSince(Before);
    if Result then
      Exit;

    const Held = Clipboard.GetClipboard;
    Result := (Held.ToString = Value);
  except
    on Error: Exception do
    begin
      if MustReachApplication(Error) then
        raise;

      Result := False;
    end;
  end;
end;

class function TMarkdownFmxClipboard.TryReadText(out Value: string): Boolean;
begin
  Value := '';

  var Clipboard: IFMXClipboardService;
  if not TryGetService(Clipboard) then
  begin
    Result := False;
    Exit;
  end;

  Result := TMarkdownClipboardRetry.TryReadText(
    function(out Text: string): Boolean
    begin
      Result := TryReadOnce(Clipboard, Text);
    end,
    Value);
end;

// An attempt needs no other when the clipboard holds no text, a text that is
// not empty, or an empty text without a text format behind it.
class function TMarkdownFmxClipboard.TryReadOnce(const Clipboard: IFMXClipboardService;
                                                 out Value: string): Boolean;
begin
  Value := '';

  try
    const Held = Clipboard.GetClipboard;
    const IsText = Held.IsType<string>(False);
    if IsText then
      Value := Held.AsString;

    const IsEmptyText = (IsText and (Value = ''));
    Result := (not IsEmptyText or not ClaimsText(Clipboard));
  except
    on Error: Exception do
    begin
      if MustReachApplication(Error) then
        raise;

      Result := False;
    end;
  end;
end;

// Reading opens the clipboard, which fails while another program holds it.
// FMX's service for Windows also says whether the clipboard holds text, from
// the formats on it and without opening it, as the VCL does; a text format
// counts then, even for an empty text. Any service that offers the extended
// interface is asked the same way, on every platform; one that does not is
// asked for its text.
class function TMarkdownFmxClipboard.HasText: Boolean;
begin
  var Clipboard: IFMXClipboardService;
  if not TryGetService(Clipboard) then
  begin
    Result := False;
    Exit;
  end;

  try
    var ExtendedClipboard: IFMXExtendedClipboardService;
    if Supports(Clipboard, IFMXExtendedClipboardService, ExtendedClipboard) then
    begin
      Result := ExtendedClipboard.HasText;
      Exit;
    end;

    const Held = Clipboard.GetClipboard;
    const IsText = Held.IsType<string>(False);
    Result := (IsText and (Held.AsString <> ''));
  except
    on Error: Exception do
    begin
      if MustReachApplication(Error) then
        raise;

      Result := False;
    end;
  end;
end;

// Errors in the program itself rather than in the clipboard, and EAbort,
// which an application raises on purpose to stop what is running: neither is
// a busy clipboard, so neither is tried again or swallowed. EExternal covers
// the faults the processor reports: access violations, stack overflows,
// privileged instructions and integer and floating-point errors.
class function TMarkdownFmxClipboard.MustReachApplication(const Error: Exception): Boolean;
begin
  Result := ((Error is EExternal) or
             (Error is EHeapException) or
             (Error is EAssertionFailed) or
             (Error is EInvalidCast) or
             (Error is EAbstractError) or
             (Error is EAbort));
end;

// FMX's service for Windows reads an empty text while another program holds
// the clipboard, but its HasText asks Windows for the text format without
// opening the clipboard, and that format stays while the clipboard is held. A
// text format next to an empty read therefore means the clipboard was busy,
// whoever held it: a program with a window, one without, or one that let go
// between the read and this check. Asking which window holds the clipboard
// misses the last two. A clipboard without the format answers at once; a
// text that really is empty costs the retries. A service without HasText has
// no such signal, and its empty text is the answer.
class function TMarkdownFmxClipboard.ClaimsText(const Clipboard: IFMXClipboardService): Boolean;
begin
  var ExtendedClipboard: IFMXExtendedClipboardService;
  Result := (Supports(Clipboard, IFMXExtendedClipboardService, ExtendedClipboard) and
             ExtendedClipboard.HasText);
end;

end.
