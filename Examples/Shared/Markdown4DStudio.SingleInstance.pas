unit Markdown4DStudio.SingleInstance;

{$SCOPEDENUMS ON}

// One studio instance per flavour: a later start hands its document to the running
// instance over WM_COPYDATA and exits, so "Open with" lands in a tab instead of
// a second window. The channel is a message-only window whose class name
// doubles as the discovery key.

interface

uses
  Winapi.Windows,
  System.SysUtils;

type
  TPadDocumentReceived = reference to procedure(const FileName: string);

  TPadSingleInstance = class
  strict private
    const
      // ASFW_ANY: any process may take the foreground after our hand-off.
      AllowAnyProcess = DWORD(-1);
    class var
      FWindow: HWND;
      FChannelName: string;
      FOnDocument: TPadDocumentReceived;
    class function ChannelWndProc(Wnd: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall; static;
    class function FindChannel(const ChannelName: string): HWND; static;

  public
    class function TryHandOff(const ChannelName, FileName: string): Boolean; static;
    class procedure OpenChannel(const ChannelName: string; const OnDocument: TPadDocumentReceived); static;
    class procedure CloseChannel; static;
  end;

implementation

uses
  Winapi.Messages;

class function TPadSingleInstance.ChannelWndProc(Wnd: HWND; Msg: UINT; WParam: WPARAM;
  LParam: LPARAM): LRESULT;
begin
  if Msg = WM_COPYDATA then
  begin
    const Data = PCopyDataStruct(LParam);

    var FileName := '';
    if (Data <> nil) and (Data.cbData > 0) then
      SetString(FileName, PChar(Data.lpData), Data.cbData div SizeOf(Char));
    FileName := FileName.TrimRight([#0]);

    if Assigned(FOnDocument) then
      FOnDocument(FileName);

    Exit(1);
  end;

  Result := DefWindowProc(Wnd, Msg, WParam, LParam);
end;

// Message-only windows never show up in a plain FindWindow sweep; they are
// found by asking the message-window list explicitly.
class function TPadSingleInstance.FindChannel(const ChannelName: string): HWND;
begin
  Result := FindWindowEx(HWND_MESSAGE, 0, PChar(ChannelName), nil);
end;

class function TPadSingleInstance.TryHandOff(const ChannelName, FileName: string): Boolean;
begin
  const Channel = FindChannel(ChannelName);
  if Channel = 0 then
    Exit(False);

  var Data := Default(TCopyDataStruct);
  Data.cbData := Length(FileName) * SizeOf(Char);
  Data.lpData := PChar(FileName);

  AllowSetForegroundWindow(AllowAnyProcess);
  SendMessage(Channel, WM_COPYDATA, 0, LPARAM(@Data));
  Result := True;
end;

class procedure TPadSingleInstance.OpenChannel(const ChannelName: string;
  const OnDocument: TPadDocumentReceived);
begin
  CloseChannel;

  FChannelName := ChannelName;
  FOnDocument := OnDocument;

  var WindowClass := Default(TWndClass);
  WindowClass.lpfnWndProc := @ChannelWndProc;
  WindowClass.hInstance := HInstance;
  WindowClass.lpszClassName := PChar(FChannelName);
  Winapi.Windows.RegisterClass(WindowClass);

  FWindow := CreateWindowEx(0, PChar(FChannelName), nil, 0, 0, 0, 0, 0, HWND_MESSAGE, 0, HInstance, nil);
end;

class procedure TPadSingleInstance.CloseChannel;
begin
  if FWindow <> 0 then
  begin
    DestroyWindow(FWindow);
    FWindow := 0;
  end;

  if FChannelName <> '' then
  begin
    Winapi.Windows.UnregisterClass(PChar(FChannelName), HInstance);
    FChannelName := '';
  end;

  FOnDocument := nil;
end;

end.
