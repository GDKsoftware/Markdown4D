unit MarkdownPad.Fmx.WinFrame;

{$SCOPEDENUMS ON}

interface

uses
  FMX.Forms;

type
  /// <summary>
  /// Turns an FMX form on Windows into a borderless custom-frame window: the native
  /// caption is removed (WM_NCCALCSIZE), edge resizing is restored (WM_NCHITTEST),
  /// and a DWM drop shadow is re-applied. The form drives dragging and the window
  /// buttons itself; BeginDrag starts the system move loop so Aero Snap keeps working.
  /// </summary>
  TFmxWinFrame = class
  public
    class function Install(const AForm: TCommonCustomForm): Boolean; static;
    class procedure BeginDrag; static;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.DwmApi,
  Winapi.UxTheme,
  System.Types,
  FMX.Platform.Win;

const
  ResizeBorder = 6;
  ScMoveCaption = $F012; // SC_MOVE or HTCAPTION

var
  GOldProc: Pointer = nil;
  GHandle: HWND = 0;

function FrameProc(Wnd: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
begin
  case Msg of
    WM_NCACTIVATE:
      // Passing -1 keeps DefWindowProc from repainting the (removed) non-client
      // frame when the window activates, which otherwise flashes a grey line.
      Exit(CallWindowProc(GOldProc, Wnd, Msg, WParam, -1));

    WM_NCPAINT:
      Exit(0);

    WM_NCCALCSIZE:
      if WParam <> 0 then
      begin
        if IsZoomed(Wnd) then
        begin
          const FrameX = GetSystemMetrics(SM_CXFRAME) + GetSystemMetrics(SM_CXPADDEDBORDER);
          const FrameY = GetSystemMetrics(SM_CYFRAME) + GetSystemMetrics(SM_CXPADDEDBORDER);
          var Params := PNCCalcSizeParams(LParam);
          Inc(Params^.rgrc[0].Left, FrameX);
          Dec(Params^.rgrc[0].Right, FrameX);
          Dec(Params^.rgrc[0].Bottom, FrameY);
          Inc(Params^.rgrc[0].Top, FrameY);
        end;
        Exit(0);
      end;

    WM_NCHITTEST:
      begin
        if IsZoomed(Wnd) then
          Exit(HTCLIENT);

        var WindowRect: TRect;
        GetWindowRect(Wnd, WindowRect);

        const X = SmallInt(LoWord(DWORD(LParam))) - WindowRect.Left;
        const Y = SmallInt(HiWord(DWORD(LParam))) - WindowRect.Top;
        const OnLeft = X < ResizeBorder;
        const OnRight = X >= WindowRect.Width - ResizeBorder;
        const OnTop = Y < ResizeBorder;
        const OnBottom = Y >= WindowRect.Height - ResizeBorder;

        if OnTop and OnLeft then Exit(HTTOPLEFT);
        if OnTop and OnRight then Exit(HTTOPRIGHT);
        if OnBottom and OnLeft then Exit(HTBOTTOMLEFT);
        if OnBottom and OnRight then Exit(HTBOTTOMRIGHT);
        if OnLeft then Exit(HTLEFT);
        if OnRight then Exit(HTRIGHT);
        if OnTop then Exit(HTTOP);
        if OnBottom then Exit(HTBOTTOM);

        Exit(HTCLIENT);
      end;
  end;

  Result := CallWindowProc(GOldProc, Wnd, Msg, WParam, LParam);
end;

class function TFmxWinFrame.Install(const AForm: TCommonCustomForm): Boolean;
begin
  GHandle := FormToHWND(AForm);
  if GHandle = 0 then
    Exit(False);

  var Style := GetWindowLong(GHandle, GWL_STYLE);
  Style := Style or WS_THICKFRAME or WS_MINIMIZEBOX or WS_MAXIMIZEBOX or WS_CLIPCHILDREN;
  SetWindowLong(GHandle, GWL_STYLE, Style);

  var Margins: TMargins;
  Margins.cxLeftWidth := 0;
  Margins.cxRightWidth := 0;
  Margins.cyTopHeight := 0;
  Margins.cyBottomHeight := 1;
  DwmExtendFrameIntoClientArea(GHandle, Margins);

  GOldProc := Pointer(GetWindowLongPtr(GHandle, GWLP_WNDPROC));
  SetWindowLongPtr(GHandle, GWLP_WNDPROC, LONG_PTR(@FrameProc));

  SetWindowPos(GHandle, 0, 0, 0, 0, 0,
    SWP_FRAMECHANGED or SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER);

  Result := True;
end;

class procedure TFmxWinFrame.BeginDrag;
begin
  if GHandle = 0 then
    Exit;

  ReleaseCapture;
  SendMessage(GHandle, WM_SYSCOMMAND, ScMoveCaption, 0);
end;

end.
