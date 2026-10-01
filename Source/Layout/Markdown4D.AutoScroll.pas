unit Markdown4D.AutoScroll;

{$SCOPEDENUMS ON}

interface

type
  // Which way the pointer points from the origin: inside the dead zone both
  // ways are still open.
  TMarkdownAutoScrollDirection = (Both, Up, Down);

  // Pressed: the middle button is down and the pointer has not left the dead
  // zone yet. Releasing it there keeps scrolling until the next click
  // (Toggled); dragging out first and releasing ends it (Holding).
  TMarkdownAutoScrollState = (Idle, Pressed, Toggled, Holding);

  // What a viewer or an editor offers its autoscroller.
  IMarkdownAutoScrollTarget = interface
    ['{6E2B9F41-3C57-4D8A-9B16-A4F07C25E8D3}']
    function CanAutoScroll: Boolean;
    procedure AutoScrollBy(const Delta: Single);
    procedure AutoScrollChanged;
  end;

  // Middle-click autoscroll without a framework: where it started, how fast
  // it goes and when it stops. The speed follows Firefox: nothing within
  // twelve pixels of the origin, beyond that (d/12)^1.5 - 1 pixels per 20 ms,
  // in pixels at 96 dpi.
  TMarkdownAutoScroll = record
  public
    const
      DeadZone = 12.0;
      FrameMilliseconds = 20;
      // A timer that stalls does not make the content jump when it catches up.
      MaxStepMilliseconds = 100;

  private
    FState: TMarkdownAutoScrollState;
    FOriginX: Single;
    FOriginY: Single;
    FScale: Single;
    FLastTime: Int64;
    function LogicalDistance(const Pointer, Origin: Single): Single;
    class function Accelerate(const Distance: Single): Single; static;

  public
    procedure Start(const OriginX, OriginY, Scale: Single; const TimeMilliseconds: Int64);
    procedure Stop;
    function IsActive: Boolean;
    procedure PointerMoved(const X, Y: Single);
    // The middle button came up. True when that ends autoscroll.
    function Release: Boolean;
    // Pixels to scroll since the last step, positive downwards.
    function Step(const TimeMilliseconds: Int64; const PointerY: Single): Single;
    function Direction(const PointerY: Single): TMarkdownAutoScrollDirection;
    property State: TMarkdownAutoScrollState read FState;
    property OriginX: Single read FOriginX;
    property OriginY: Single read FOriginY;
  end;

implementation

uses
  System.Math;

procedure TMarkdownAutoScroll.Start(const OriginX, OriginY, Scale: Single; const TimeMilliseconds: Int64);
begin
  FState := TMarkdownAutoScrollState.Pressed;
  FOriginX := OriginX;
  FOriginY := OriginY;
  FScale := Max(Scale, 1);
  FLastTime := TimeMilliseconds;
end;

procedure TMarkdownAutoScroll.Stop;
begin
  FState := TMarkdownAutoScrollState.Idle;
end;

function TMarkdownAutoScroll.IsActive: Boolean;
begin
  Result := (FState <> TMarkdownAutoScrollState.Idle);
end;

procedure TMarkdownAutoScroll.PointerMoved(const X, Y: Single);
begin
  if FState <> TMarkdownAutoScrollState.Pressed then
    Exit;

  const LeftDeadZone = ((Abs(LogicalDistance(X, FOriginX)) > DeadZone) or
                        (Abs(LogicalDistance(Y, FOriginY)) > DeadZone));
  if LeftDeadZone then
    FState := TMarkdownAutoScrollState.Holding;
end;

function TMarkdownAutoScroll.Release: Boolean;
begin
  if FState = TMarkdownAutoScrollState.Pressed then
    FState := TMarkdownAutoScrollState.Toggled
  else if FState = TMarkdownAutoScrollState.Holding then
    FState := TMarkdownAutoScrollState.Idle;

  Result := not IsActive;
end;

function TMarkdownAutoScroll.Step(const TimeMilliseconds: Int64; const PointerY: Single): Single;
begin
  if not IsActive then
  begin
    Result := 0;
    Exit;
  end;

  const Elapsed = Min(TimeMilliseconds - FLastTime, MaxStepMilliseconds);
  FLastTime := TimeMilliseconds;

  const Speed = Accelerate(LogicalDistance(PointerY, FOriginY));
  Result := Speed * FScale * Max(Elapsed, 0) / FrameMilliseconds;
end;

function TMarkdownAutoScroll.Direction(const PointerY: Single): TMarkdownAutoScrollDirection;
begin
  const Distance = LogicalDistance(PointerY, FOriginY);

  if Distance > DeadZone then
    Result := TMarkdownAutoScrollDirection.Down
  else if Distance < -DeadZone then
    Result := TMarkdownAutoScrollDirection.Up
  else
    Result := TMarkdownAutoScrollDirection.Both;
end;

function TMarkdownAutoScroll.LogicalDistance(const Pointer, Origin: Single): Single;
begin
  Result := (Pointer - Origin) / FScale;
end;

class function TMarkdownAutoScroll.Accelerate(const Distance: Single): Single;
begin
  const Units = Distance / DeadZone;

  if Units > 1 then
    Result := Units * Sqrt(Units) - 1
  else if Units < -1 then
    Result := Units * Sqrt(-Units) + 1
  else
    Result := 0;
end;

end.
