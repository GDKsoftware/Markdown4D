unit Markdown4D.Viewer.Clicks;

{$SCOPEDENUMS ON}

interface

type
  // Counts a press as a single, double or triple click. The platform reports
  // the double click, by its own time and distance. No platform reports a
  // third, so a press that follows a double click closely enough is one.
  TMarkdownClickCounter = record
  public
    const
      // Windows' default double-click time and distance, for a platform that
      // does not report its own.
      DefaultIntervalMilliseconds = 500;
      DefaultTolerance = 2.0;
      SingleClick = 1;
      DoubleClick = 2;
      TripleClick = 3;

  private
    FLastCount: Integer;
    FLastTime: Int64;
    FLastX: Single;
    FLastY: Single;
    function FollowsDoubleClick(const TimeMilliseconds: Int64; const X, Y: Single;
      const IntervalMilliseconds: Cardinal; const Tolerance: Single): Boolean;

  public
    function RegisterPress(const TimeMilliseconds: Int64; const X, Y: Single; const IsDoubleClick: Boolean;
      const IntervalMilliseconds: Cardinal; const Tolerance: Single): Integer;
  end;

implementation

function TMarkdownClickCounter.RegisterPress(const TimeMilliseconds: Int64; const X, Y: Single;
  const IsDoubleClick: Boolean; const IntervalMilliseconds: Cardinal; const Tolerance: Single): Integer;
begin
  if FollowsDoubleClick(TimeMilliseconds, X, Y, IntervalMilliseconds, Tolerance) then
    Result := TripleClick
  else if IsDoubleClick then
    Result := DoubleClick
  else
    Result := SingleClick;

  FLastCount := Result;
  FLastTime := TimeMilliseconds;
  FLastX := X;
  FLastY := Y;
end;

function TMarkdownClickCounter.FollowsDoubleClick(const TimeMilliseconds: Int64; const X, Y: Single;
  const IntervalMilliseconds: Cardinal; const Tolerance: Single): Boolean;
begin
  const IsAfterDouble = (FLastCount = DoubleClick);
  const IsSoonEnough = (TimeMilliseconds - FLastTime <= IntervalMilliseconds);
  const IsCloseEnough = ((Abs(X - FLastX) <= Tolerance) and (Abs(Y - FLastY) <= Tolerance));

  Result := IsAfterDouble and IsSoonEnough and IsCloseEnough;
end;

end.
