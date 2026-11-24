unit Markdown4D.Tests.ClipboardHold;

{$SCOPEDENUMS ON}

interface

{$IFDEF MSWINDOWS}
uses
  System.Classes,
  System.SyncObjs;

type
  // Holds the real clipboard open from a thread of its own, as a clipboard
  // manager or a password manager does for a moment after every change. It
  // opens the clipboard for a window of its own, as another program does:
  // without one Windows lets the test open the clipboard a second time. The
  // clipboard of Windows only exists there, so the unit is empty elsewhere.
  TClipboardHold = class
  private
    const
      WindowClass = 'STATIC';
      StartTimeoutMilliseconds = 2000;
    var
      FThread: TThread;
      FStarted: TEvent;
      FReleased: TEvent;
      FIsOpened: Boolean;
      FIsHeld: Boolean;
    procedure Hold(const Milliseconds: Cardinal);
    function TryOpen(const Window: NativeUInt): Boolean;

  public
    const
      BriefMilliseconds = 30;
      UntilFreed = High(Cardinal);
      HeldMessage = 'The clipboard is held by another process';
      UnavailableMessage = 'The clipboard is unavailable in this test session';
    // Lets go of the clipboard after Milliseconds, or when it is freed.
    constructor Create(const Milliseconds: Cardinal);
    destructor Destroy; override;
    // False when another process kept the clipboard to itself.
    property IsHeld: Boolean read FIsHeld;
  end;
{$ENDIF}

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows,
  Markdown4D.Tests.ClipboardRetry;

constructor TClipboardHold.Create(const Milliseconds: Cardinal);
begin
  inherited Create;

  FStarted := TEvent.Create;
  FReleased := TEvent.Create;
  FThread := TThread.CreateAnonymousThread(
    procedure
    begin
      Hold(Milliseconds);
    end);
  FThread.FreeOnTerminate := False;
  FThread.Start;

  const HasStarted = (FStarted.WaitFor(StartTimeoutMilliseconds) = TWaitResult.wrSignaled);
  FIsHeld := (HasStarted and FIsOpened);
end;

destructor TClipboardHold.Destroy;
begin
  FReleased.SetEvent;
  FThread.WaitFor;
  FThread.Free;
  FReleased.Free;
  FStarted.Free;

  inherited;
end;

procedure TClipboardHold.Hold(const Milliseconds: Cardinal);
begin
  const Window = CreateWindowEx(0, WindowClass, nil, 0, 0, 0, 0, 0, HWND_MESSAGE, 0, HInstance, nil);
  const IsCreated = (Window <> 0);
  if not IsCreated then
  begin
    FStarted.SetEvent;
    Exit;
  end;

  try
    FIsOpened := TryOpen(Window);
    FStarted.SetEvent;
    if not FIsOpened then
      Exit;

    FReleased.WaitFor(Milliseconds);
    CloseClipboard;
  finally
    DestroyWindow(Window);
  end;
end;

function TClipboardHold.TryOpen(const Window: NativeUInt): Boolean;
begin
  Result := TTestClipboardRetry.TryRepeatedly(
    function: Boolean
    begin
      Result := OpenClipboard(Window);
    end);
end;
{$ENDIF}

end.
