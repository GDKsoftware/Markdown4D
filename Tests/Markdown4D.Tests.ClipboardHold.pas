unit Markdown4D.Tests.ClipboardHold;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.SyncObjs;

type
  // Holds the real clipboard open from a thread of its own, as a clipboard
  // manager or a password manager does for a moment after every change. It
  // opens the clipboard for a window of its own, as another program does:
  // without one Windows lets the test open the clipboard a second time.
  TClipboardHold = class
  private
    const
      Attempts = 20;
      PauseMilliseconds = 25;
      WindowClass = 'STATIC';
    var
      FThread: TThread;
      FStarted: TEvent;
      FReleased: TEvent;
      FIsHeld: Boolean;
    procedure Hold(const Milliseconds: Cardinal);
    function TryOpen(const Window: NativeUInt): Boolean;

  public
    const
      BriefMilliseconds = 30;
      UntilFreed = High(Cardinal);
    // Lets go of the clipboard after Milliseconds, or when it is freed.
    constructor Create(const Milliseconds: Cardinal);
    destructor Destroy; override;
    // False when another process kept the clipboard to itself.
    property IsHeld: Boolean read FIsHeld;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils;

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
  FStarted.WaitFor;
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
  try
    FIsHeld := TryOpen(Window);
    FStarted.SetEvent;
    if not FIsHeld then
      Exit;

    FReleased.WaitFor(Milliseconds);
    CloseClipboard;
  finally
    DestroyWindow(Window);
  end;
end;

function TClipboardHold.TryOpen(const Window: NativeUInt): Boolean;
begin
  for var Attempt := 1 to Attempts do
  begin
    const IsOpened = OpenClipboard(Window);
    if IsOpened then
    begin
      Result := True;
      Exit;
    end;

    Sleep(PauseMilliseconds);
  end;

  Result := False;
end;

end.
