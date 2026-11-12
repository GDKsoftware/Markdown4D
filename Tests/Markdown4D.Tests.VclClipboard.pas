unit Markdown4D.Tests.VclClipboard;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.SyncObjs;

type
  // The real clipboard, read and written with a few attempts, because another
  // process may hold it open for a moment.
  TVclTestClipboard = record
  private
    const
      Attempts = 20;
      PauseMilliseconds = 25;

  public
    class function IsAccessible: Boolean; static;
    class function TryGetText(out Value: string): Boolean; static;
    class function TrySetText(const Value: string): Boolean; static;
  end;

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
  System.SysUtils,
  Vcl.Clipbrd;

class function TVclTestClipboard.IsAccessible: Boolean;
begin
  for var Attempt := 1 to Attempts do
  begin
    try
      Clipboard.Open;
      Clipboard.Close;
      Result := True;
      Exit;
    except
      on EClipboardException do
        Sleep(PauseMilliseconds);
    end;
  end;

  Result := False;
end;

class function TVclTestClipboard.TryGetText(out Value: string): Boolean;
begin
  Value := '';

  for var Attempt := 1 to Attempts do
  begin
    try
      Value := Clipboard.AsText;
      Result := True;
      Exit;
    except
      on EClipboardException do
        Sleep(PauseMilliseconds);
    end;
  end;

  Result := False;
end;

class function TVclTestClipboard.TrySetText(const Value: string): Boolean;
begin
  for var Attempt := 1 to Attempts do
  begin
    try
      Clipboard.AsText := Value;
      Result := True;
      Exit;
    except
      on EClipboardException do
        Sleep(PauseMilliseconds);
    end;
  end;

  Result := False;
end;

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
