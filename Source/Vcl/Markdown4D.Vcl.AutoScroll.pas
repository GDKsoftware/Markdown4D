unit Markdown4D.Vcl.AutoScroll;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Markdown4D.Layout.Interfaces,
  Markdown4D.AutoScroll;

type
  // Middle-click autoscroll for a VCL control: it holds the mouse, steps the
  // scrolling on a timer from wherever the pointer is, also outside the
  // window, and shows the pan cursor for the direction.
  TMarkdownVclAutoScroller = class
  private
    const
      TickMilliseconds = 16;
      StandardPixelsPerInch = 96;
    var
      FControl: TControl;
      FTarget: IMarkdownAutoScrollTarget;
      FAutoScroll: TMarkdownAutoScroll;
      FTimer: TTimer;
      FEnabled: Boolean;
      FStoppedByRightClick: Boolean;
    procedure HandleTimer(Sender: TObject);
    procedure SetEnabled(const Value: Boolean);
    function TryStart(const X, Y: Integer): Boolean;
    function PointerInControl: TPoint;
    function Scale: Single;
    procedure ShowCursor(const PointerY: Integer);
    procedure RestoreCursor;
    function OwnCursor: TCursor;

  public
    constructor Create(const Control: TControl; const Target: IMarkdownAutoScrollTarget);
    destructor Destroy; override;
    function IsActive: Boolean;
    // A press while autoscrolling only ends it; a middle press starts it.
    // True when the press is taken.
    function TryHandlePress(const Button: TMouseButton; const X, Y: Integer): Boolean;
    // True once after a right click ended autoscroll, so that click opens no
    // context menu either.
    function TakeSuppressedMenu: Boolean;
    procedure HandleMove(const X, Y: Integer);
    procedure HandleMiddleUp;
    procedure Stop;
    procedure PaintOrigin(const Painter: IPainter; const BackgroundColor, TextColor: TLayoutColor);
    property Enabled: Boolean read FEnabled write SetEnabled;
  end;

implementation

uses
  System.UITypes,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Forms,
  Markdown4D.AutoScroll.Icon,
  Markdown4D.AutoScroll.Cursors;

constructor TMarkdownVclAutoScroller.Create(const Control: TControl; const Target: IMarkdownAutoScrollTarget);
begin
  inherited Create;

  FControl := Control;
  FTarget := Target;
  FEnabled := True;

  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.Interval := TickMilliseconds;
  FTimer.OnTimer := HandleTimer;
end;

destructor TMarkdownVclAutoScroller.Destroy;
begin
  FTimer.Free;

  inherited Destroy;
end;

function TMarkdownVclAutoScroller.IsActive: Boolean;
begin
  Result := FAutoScroll.IsActive;
end;

procedure TMarkdownVclAutoScroller.SetEnabled(const Value: Boolean);
begin
  FEnabled := Value;
  if not Value then
    Stop;
end;

function TMarkdownVclAutoScroller.TryHandlePress(const Button: TMouseButton; const X, Y: Integer): Boolean;
begin
  if IsActive then
  begin
    FStoppedByRightClick := (Button = TMouseButton.mbRight);
    Stop;
    Result := True;
    Exit;
  end;

  Result := (Button = TMouseButton.mbMiddle) and FEnabled;
  if not Result then
    Exit;

  const Focusable = FControl as TWinControl;
  if Focusable.CanFocus then
    Focusable.SetFocus;

  TryStart(X, Y);
end;

function TMarkdownVclAutoScroller.TakeSuppressedMenu: Boolean;
begin
  Result := FStoppedByRightClick;
  FStoppedByRightClick := False;
end;

function TMarkdownVclAutoScroller.TryStart(const X, Y: Integer): Boolean;
begin
  Result := FEnabled and FTarget.CanAutoScroll;
  if not Result then
    Exit;

  FAutoScroll.Start(X, Y, Scale, GetTickCount64);
  SetCaptureControl(FControl);
  FTimer.Enabled := True;

  ShowCursor(Y);
  FTarget.AutoScrollChanged;
end;

procedure TMarkdownVclAutoScroller.HandleMove(const X, Y: Integer);
begin
  if not IsActive then
    Exit;

  FAutoScroll.PointerMoved(X, Y);
  ShowCursor(Y);
end;

procedure TMarkdownVclAutoScroller.HandleMiddleUp;
begin
  if not IsActive then
    Exit;

  const Stopped = FAutoScroll.Release;
  if Stopped then
    Stop;
end;

procedure TMarkdownVclAutoScroller.Stop;
begin
  const WasActive = IsActive;

  FAutoScroll.Stop;
  FTimer.Enabled := False;
  if not WasActive then
    Exit;

  if GetCaptureControl = FControl then
    SetCaptureControl(nil);
  RestoreCursor;
  FTarget.AutoScrollChanged;
end;

// The pan cursor was set past the VCL, so the VCL does not know to replace
// it. The control's own cursor goes back first; then the window under the
// pointer sets its cursor again, so a link shows the hand at once.
procedure TMarkdownVclAutoScroller.RestoreCursor;
begin
  var ScreenPoint: TPoint;
  GetCursorPos(ScreenPoint);

  const IsOverControl = FControl.ClientRect.Contains(FControl.ScreenToClient(ScreenPoint));
  if IsOverControl then
    Winapi.Windows.SetCursor(Screen.Cursors[OwnCursor]);

  const Window = WindowFromPoint(ScreenPoint);
  if Window <> 0 then
    SendMessage(Window, WM_SETCURSOR, Window, MakeLParam(HTCLIENT, WM_MOUSEMOVE));
end;

function TMarkdownVclAutoScroller.OwnCursor: TCursor;
begin
  Result := FControl.Cursor;
  if Result = crDefault then
    Result := crArrow;
end;

procedure TMarkdownVclAutoScroller.PaintOrigin(const Painter: IPainter;
  const BackgroundColor, TextColor: TLayoutColor);
begin
  if not IsActive then
    Exit;

  const Origin = TLayoutPointF.Create(FAutoScroll.OriginX, FAutoScroll.OriginY);
  TMarkdownAutoScrollIcon.Paint(Painter, Origin, Scale, BackgroundColor, TextColor);
end;

procedure TMarkdownVclAutoScroller.HandleTimer(Sender: TObject);
begin
  if not IsActive then
  begin
    FTimer.Enabled := False;
    Exit;
  end;

  const Pointer = PointerInControl;
  ShowCursor(Pointer.Y);

  const Delta = FAutoScroll.Step(GetTickCount64, Pointer.Y);
  if Delta <> 0 then
    FTarget.AutoScrollBy(Delta);
end;

function TMarkdownVclAutoScroller.PointerInControl: TPoint;
begin
  var ScreenPoint: TPoint;
  GetCursorPos(ScreenPoint);

  Result := FControl.ScreenToClient(ScreenPoint);
end;

function TMarkdownVclAutoScroller.Scale: Single;
begin
  Result := FControl.CurrentPPI / StandardPixelsPerInch;
end;

procedure TMarkdownVclAutoScroller.ShowCursor(const PointerY: Integer);
begin
  const Direction = FAutoScroll.Direction(PointerY);
  TMarkdownAutoScrollCursors.TryApply(Direction);
end;

end.
