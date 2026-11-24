unit Markdown4D.Fmx.Clipboard;

interface

type
  // Text to and from the clipboard for the FMX controls, through the clipboard
  // service of the platform or the one the application put in its place.
  // Another program may hold the clipboard open for a moment: a clipboard
  // manager or a password manager reads it right after every change. A
  // clipboard that stays busy is a copy or a paste that did not happen and
  // nothing more.
  TMarkdownFmxClipboard = record
  public
    // False when the text did not get there.
    class function TryWriteText(const Value: string): Boolean; static;
    // False as well when the clipboard holds no text.
    class function TryReadText(out Value: string): Boolean; static;
    // True when the clipboard holds text, without waiting for a busy one. With
    // FMX's service for Windows a text format is enough, as in the VCL.
    class function HasText: Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.Rtti,
  FMX.Platform,
  FMX.Clipboard,
  Markdown4D.Clipboard.Retry,
  Markdown4D.Viewer.Clipboard;

// The clipboard service FMX has for Windows does not say when the text did not
// get there, but Windows counts the changes of the clipboard, and the count
// stands still then: the write is tried again. The count stands still as well
// under a service the application put in place of FMX's, which holds the text
// all the same, and other platforms keep no count; either is written once.
class function TMarkdownFmxClipboard.TryWriteText(const Value: string): Boolean;
begin
  Result := False;

  var Clipboard: IFMXClipboardService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clipboard) then
    Exit;

  try
    Result := TMarkdownClipboardRetry.TryRepeatedly(
      function: Boolean
      begin
        const Before = TMarkdownMathClipboard.ChangeCount;
        Clipboard.SetClipboard(Value);

        Result := TMarkdownMathClipboard.HasChangedSince(Before);
        if Result then
          Exit;

        const Held = Clipboard.GetClipboard;
        Result := (Held.ToString = Value);
      end);
  except
    // IFMXClipboardService has a separate implementation per platform, and none
    // of them documents a shared specific exception for a failed write, so the
    // catch stays broad: a clipboard failure must not take the control down.
    on Exception do
      Result := False;
  end;
end;

// The clipboard service FMX has for Windows reads an empty text from a
// clipboard another program holds, so an empty text is read again.
class function TMarkdownFmxClipboard.TryReadText(out Value: string): Boolean;
begin
  Value := '';
  Result := False;

  var Clipboard: IFMXClipboardService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clipboard) then
    Exit;

  var Text := '';
  try
    TMarkdownClipboardRetry.TryRepeatedly(
      function: Boolean
      begin
        const Held = Clipboard.GetClipboard;
        const IsText = Held.IsType<string>(False);
        if IsText then
          Text := Held.AsString;

        Result := (not IsText or (Text <> ''));
      end);
  except
    // The same broad catch as for a write: a paste that fails is no paste.
    on Exception do
      Exit;
  end;

  Value := Text;
  Result := (Text <> '');
end;

// Reading opens the clipboard, which fails while another program holds it.
// FMX's service for Windows also says whether the clipboard holds text, from
// the formats on it and without opening it, as the VCL does; a text format
// counts then, even for an empty text. A service the application put in place
// of FMX's answers for itself: through its own HasText when it offers the
// extended service, as FMX's does, and otherwise with the text, as on every
// other platform.
class function TMarkdownFmxClipboard.HasText: Boolean;
begin
  Result := False;

  var Clipboard: IFMXClipboardService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clipboard) then
    Exit;

{$IFDEF MSWINDOWS}
  var ExtendedClipboard: IFMXExtendedClipboardService;
  if Supports(Clipboard, IFMXExtendedClipboardService, ExtendedClipboard) then
  begin
    Result := ExtendedClipboard.HasText;
    Exit;
  end;
{$ENDIF}

  const Held = Clipboard.GetClipboard;
  const IsText = Held.IsType<string>(False);
  Result := (IsText and (Held.AsString <> ''));
end;

end.
