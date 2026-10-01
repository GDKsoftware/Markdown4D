unit Markdown4D.Fmx.AutoScroll;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.Types,
  System.UITypes,
  FMX.Types,
  FMX.Controls,
  Markdown4D.Layout.Interfaces,
  Markdown4D.AutoScroll;

type
  // Middle-click autoscroll for an FMX control: it holds the mouse, steps the
  // scrolling on a timer from wherever the pointer is, also outside the
  // window, and shows the pan cursor the platform has for the direction. FMX
  // coordinates are already independent of the screen density, so the speed
  // needs no scaling.
  TMarkdownFmxAutoScroller = class
  private
    const
      TickMilliseconds = 16;
      LogicalScale = 1.0;
    var
      FControl: TControl;
      FTarget: IMarkdownAutoScrollTarget;
      FAutoScroll: TMarkdownAutoScroll;
      FTimer: TTimer;
      FSavedCursor: TCursor;
      FEnabled: Boolean;
    procedure HandleTimer(Sender: TObject);
    procedure SetEnabled(const Value: Boolean);
    function TryStart(const X, Y: Single): Boolean;
    function PointerInControl: TPointF;
    procedure ShowCursor(const PointerY: Single);
    procedure CaptureMouse;
    procedure ReleaseMouse;
    procedure RestoreCursor;

  public
    constructor Create(const Control: TControl; const Target: IMarkdownAutoScrollTarget);
    destructor Destroy; override;
    function IsActive: Boolean;
    // A press while autoscrolling only ends it; a middle press starts it.
    // True when the press is taken.
    function TryHandlePress(const Button: TMouseButton; const X, Y: Single): Boolean;
    procedure HandleMove(const X, Y: Single);
    procedure HandleMiddleUp;
    procedure Stop;
    procedure PaintOrigin(const Painter: IPainter; const BackgroundColor, TextColor: TLayoutColor);
    property Enabled: Boolean read FEnabled write SetEnabled;
  end;

implementation

uses
  FMX.Forms,
  FMX.Platform,
  Markdown4D.AutoScroll.Icon,
  Markdown4D.AutoScroll.Cursors,
  Markdown4D.Fmx.AutoScroll.LinuxCursors;

constructor TMarkdownFmxAutoScroller.Create(const Control: TControl; const Target: IMarkdownAutoScrollTarget);
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

destructor TMarkdownFmxAutoScroller.Destroy;
begin
  FTimer.Free;

  inherited Destroy;
end;

function TMarkdownFmxAutoScroller.IsActive: Boolean;
begin
  Result := FAutoScroll.IsActive;
end;

procedure TMarkdownFmxAutoScroller.SetEnabled(const Value: Boolean);
begin
  FEnabled := Value;
  if not Value then
    Stop;
end;

function TMarkdownFmxAutoScroller.TryHandlePress(const Button: TMouseButton; const X, Y: Single): Boolean;
begin
  if IsActive then
  begin
    Stop;
    Result := True;
    Exit;
  end;

  Result := (Button = TMouseButton.mbMiddle) and FEnabled;
  if not Result then
    Exit;

  if FControl.CanFocus and (FControl.Scene <> nil) then
    FControl.SetFocus;

  TryStart(X, Y);
end;

function TMarkdownFmxAutoScroller.TryStart(const X, Y: Single): Boolean;
begin
  Result := FEnabled and FTarget.CanAutoScroll;
  if not Result then
    Exit;

  FAutoScroll.Start(X, Y, LogicalScale, TThread.GetTickCount64);
  CaptureMouse;
  FTimer.Enabled := True;

  // The up-down arrow is the platform's own cursor everywhere; Windows and
  // Linux replace it with one per direction.
  FSavedCursor := FControl.Cursor;
  FControl.Cursor := crSizeNS;
  ShowCursor(Y);
  FTarget.AutoScrollChanged;
end;

procedure TMarkdownFmxAutoScroller.HandleMove(const X, Y: Single);
begin
  if not IsActive then
    Exit;

  FAutoScroll.PointerMoved(X, Y);
  ShowCursor(Y);
end;

procedure TMarkdownFmxAutoScroller.HandleMiddleUp;
begin
  if not IsActive then
    Exit;

  const Stopped = FAutoScroll.Release;
  if Stopped then
    Stop;
end;

procedure TMarkdownFmxAutoScroller.Stop;
begin
  const WasActive = IsActive;

  FAutoScroll.Stop;
  FTimer.Enabled := False;
  if not WasActive then
    Exit;

  ReleaseMouse;
  FControl.Cursor := FSavedCursor;
  RestoreCursor;
  FTarget.AutoScrollChanged;
end;

// The pan cursor was set past FMX, so FMX does not know to replace it. Linux
// drops the cursor from the window; then the cursor service applies the
// control's own, after a different one so it does not skip the same value.
procedure TMarkdownFmxAutoScroller.RestoreCursor;
begin
  if FControl.Root <> nil then
    TMarkdownLinuxAutoScrollCursors.Clear(FControl.Root.GetObject as TCommonCustomForm);

  var CursorService: IFMXCursorService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXCursorService, CursorService) then
    Exit;

  const IsOverControl = FControl.LocalRect.Contains(PointerInControl);
  if not IsOverControl then
    Exit;

  CursorService.SetCursor(crDefault);
  CursorService.SetCursor(FControl.InheritedCursor);
end;

procedure TMarkdownFmxAutoScroller.PaintOrigin(const Painter: IPainter;
  const BackgroundColor, TextColor: TLayoutColor);
begin
  if not IsActive then
    Exit;

  const Origin = TLayoutPointF.Create(FAutoScroll.OriginX, FAutoScroll.OriginY);
  TMarkdownAutoScrollIcon.Paint(Painter, Origin, LogicalScale, BackgroundColor, TextColor);
end;

procedure TMarkdownFmxAutoScroller.HandleTimer(Sender: TObject);
begin
  if not IsActive then
  begin
    FTimer.Enabled := False;
    Exit;
  end;

  const Pointer = PointerInControl;
  ShowCursor(Pointer.Y);

  const Delta = FAutoScroll.Step(TThread.GetTickCount64, Pointer.Y);
  if Delta <> 0 then
    FTarget.AutoScrollBy(Delta);
end;

// TControl.Capture and ReleaseCapture are protected; they do no more than this.
procedure TMarkdownFmxAutoScroller.CaptureMouse;
begin
  if FControl.Root <> nil then
    FControl.Root.Captured := FControl;
end;

procedure TMarkdownFmxAutoScroller.ReleaseMouse;
begin
  const Root = FControl.Root;
  const HoldsMouse = ((Root <> nil) and (Root.Captured <> nil) and (Root.Captured.GetObject = FControl));
  if HoldsMouse then
    Root.Captured := nil;
end;

function TMarkdownFmxAutoScroller.PointerInControl: TPointF;
begin
  Result := FControl.ScreenToLocal(Screen.MousePos);
end;

procedure TMarkdownFmxAutoScroller.ShowCursor(const PointerY: Single);
begin
  const Direction = FAutoScroll.Direction(PointerY);

  if TMarkdownAutoScrollCursors.TryApply(Direction) then
    Exit;

  if FControl.Root = nil then
    Exit;

  const Form = FControl.Root.GetObject as TCommonCustomForm;
  TMarkdownLinuxAutoScrollCursors.TryApply(Form, Direction);
end;

end.
