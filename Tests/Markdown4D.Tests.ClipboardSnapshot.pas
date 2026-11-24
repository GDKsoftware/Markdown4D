unit Markdown4D.Tests.ClipboardSnapshot;

{$SCOPEDENUMS ON}

interface

{$IFDEF MSWINDOWS}
uses
  System.SysUtils;

type
  // What the real clipboard held before a test that writes it, to put back
  // afterwards. The clipboard of Windows only exists there, so the unit is
  // empty elsewhere.
  TClipboardSnapshot = record
  private
    FChangeCount: Cardinal;
    FHasText: Boolean;
    FText: string;
    class function TryReadText(out Value: string): Boolean; static;
    class function TryEmpty: Boolean; static;
    class function TryPutText(const Text: string): Boolean; static;

  public
    // False when another process kept the clipboard to itself, so there is
    // nothing to put back.
    class function TryTake(out Snapshot: TClipboardSnapshot): Boolean; static;
    // Runs Action, which writes the real clipboard, and puts back what the
    // clipboard held. A test that cannot take the snapshot passes untested,
    // so it never leaves the clipboard of the developer changed.
    class procedure RunPreserving(const Action: TProc); static;
    // Leaves a clipboard nothing changed alone, whatever it holds, and puts
    // the text back on one a test changed.
    procedure Restore;
  end;
{$ENDIF}

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows,
  DUnitX.TestFramework,
  Markdown4D.Viewer.Clipboard,
  Markdown4D.Tests.ClipboardRetry,
  Markdown4D.Tests.ClipboardHold;

class function TClipboardSnapshot.TryTake(out Snapshot: TClipboardSnapshot): Boolean;
begin
  Snapshot.FChangeCount := GetClipboardSequenceNumber;
  Snapshot.FHasText := IsClipboardFormatAvailable(CF_UNICODETEXT);
  Snapshot.FText := '';

  if not Snapshot.FHasText then
  begin
    Result := True;
    Exit;
  end;

  var Text := '';
  Result := TTestClipboardRetry.TryRepeatedly(
    function: Boolean
    begin
      Result := TryReadText(Text);
    end);

  Snapshot.FText := Text;
end;

class procedure TClipboardSnapshot.RunPreserving(const Action: TProc);
begin
  var Saved: TClipboardSnapshot;
  if not TryTake(Saved) then
    Assert.Pass(TClipboardHold.HeldMessage);

  try
    Action;
  finally
    Saved.Restore;
  end;
end;

class function TClipboardSnapshot.TryReadText(out Value: string): Boolean;
begin
  Value := '';

  Result := OpenClipboard(0);
  if not Result then
    Exit;

  try
    const Data = GetClipboardData(CF_UNICODETEXT);
    const HasData = (Data <> 0);
    if not HasData then
      Exit;

    const Locked = GlobalLock(Data);
    try
      Value := PChar(Locked);
    finally
      GlobalUnlock(Data);
    end;
  finally
    CloseClipboard;
  end;
end;

// Content other than text that a test overwrote cannot come back; the
// clipboard is left empty then.
procedure TClipboardSnapshot.Restore;
begin
  const IsUnchanged = (GetClipboardSequenceNumber = FChangeCount);
  if IsUnchanged then
    Exit;

  const Text = FText;
  const HasText = FHasText;
  TTestClipboardRetry.TryRepeatedly(
    function: Boolean
    begin
      if HasText then
        Result := TryPutText(Text)
      else
        Result := TryEmpty;
    end);
end;

class function TClipboardSnapshot.TryPutText(const Text: string): Boolean;
begin
  Result := TMarkdownMathClipboard.TryPutTextWithMath(Text, '', '');
end;

class function TClipboardSnapshot.TryEmpty: Boolean;
begin
  Result := OpenClipboard(0);
  if not Result then
    Exit;

  try
    Result := EmptyClipboard;
  finally
    CloseClipboard;
  end;
end;
{$ENDIF}

end.
