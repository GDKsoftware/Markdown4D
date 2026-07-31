unit Markdown4D.Image.Svg.Path;

{$SCOPEDENUMS ON}

// Turns SVG path data into polylines. Curves and arcs are flattened here, so
// everything downstream only ever deals with straight segments and the
// rasterizer needs to know nothing about Beziers.

interface

uses
  System.SysUtils,
  Markdown4D.Layout.Interfaces;

type
  TSvgSubPath = record
    Points: TArray<TLayoutPointF>;
    IsClosed: Boolean;
  end;

  // Reads the numbers of a path or a points list, where separators are optional
  // and a sign can be all that stands between two of them.
  TSvgNumberReader = record
  private
    FText: string;
    FIndex: Integer;
  public
    class function Create(const Text: string): TSvgNumberReader; static;
    procedure SkipSeparators;
    function AtEnd: Boolean;
    function PeekCommand(out Command: Char): Boolean;
    function TakeCommand: Char;
    function TryReadNumber(out Value: Single): Boolean;
    function ReadNumber: Single;
    function TryReadFlag(out Value: Boolean): Boolean;
  end;

  TSvgPathParser = class
  private
    const
      // Longest chord a flattened curve segment may span before it is cut in
      // two. Well under a pixel at the scale a drawing is rasterized at.
      FlatteningStep = 3.0;
      MinCurveSegments = 2;
      MaxCurveSegments = 96;
      MinArcSegments = 4;
      MaxArcSegments = 180;
      DegreesPerArcSegment = 4.0;
      RadiansPerDegree = Pi / 180;
    type
      TPathState = record
        Current: TLayoutPointF;
        Start: TLayoutPointF;
        LastCubicControl: TLayoutPointF;
        LastQuadraticControl: TLayoutPointF;
        HadCubic: Boolean;
        HadQuadratic: Boolean;
      end;
    var
      FPaths: TArray<TSvgSubPath>;
      FCurrent: TSvgSubPath;
      FHasCurrent: Boolean;
      FState: TPathState;
      FReader: TSvgNumberReader;
    class function SegmentsFor(const ChordLength: Single): Integer; static;
    class function CubicPoints(const Start, ControlOne, ControlTwo, Stop: TLayoutPointF): TArray<TLayoutPointF>; static;
    class function QuadraticPoints(const Start, Control, Stop: TLayoutPointF): TArray<TLayoutPointF>; static;
    class function ArcPoints(const Start, Stop: TLayoutPointF; const RadiusX, RadiusY, RotationDegrees: Single;
      const LargeArc, Sweep: Boolean): TArray<TLayoutPointF>; static;
    procedure Flush;
    procedure Add(const Point: TLayoutPointF);
    procedure AddMany(const Points: TArray<TLayoutPointF>);
    function TryMoveTo(const Origin: TLayoutPointF): Boolean;
    function TryLineTo(const Origin: TLayoutPointF): Boolean;
    function TryHorizontalTo(const Origin: TLayoutPointF): Boolean;
    function TryVerticalTo(const Origin: TLayoutPointF): Boolean;
    function TryCubicTo(const Origin: TLayoutPointF): Boolean;
    function TrySmoothCubicTo(const Origin: TLayoutPointF): Boolean;
    function TryQuadraticTo(const Origin: TLayoutPointF): Boolean;
    function TrySmoothQuadraticTo(const Origin: TLayoutPointF): Boolean;
    function TryArcTo(const Origin: TLayoutPointF): Boolean;
    procedure ClosePath;
    function TryRunCommand(const Command: Char; const Origin: TLayoutPointF): Boolean;
    procedure Run(const Data: string);

  public
    class function Parse(const Data: string): TArray<TSvgSubPath>; static;
  end;

implementation

uses
  System.Math;

class function TSvgNumberReader.Create(const Text: string): TSvgNumberReader;
begin
  Result.FText := Text;
  Result.FIndex := 1;
end;

function TSvgNumberReader.AtEnd: Boolean;
begin
  SkipSeparators;
  Result := FIndex > Length(FText);
end;

procedure TSvgNumberReader.SkipSeparators;
begin
  while FIndex <= Length(FText) do
  begin
    const Current = FText[FIndex];
    if (Current > ' ') and (Current <> ',') then
      Exit;

    Inc(FIndex);
  end;
end;

function TSvgNumberReader.PeekCommand(out Command: Char): Boolean;
begin
  SkipSeparators;
  if FIndex > Length(FText) then
  begin
    Command := #0;
    Exit(False);
  end;

  Command := FText[FIndex];
  Result := CharInSet(Command, ['A'..'Z', 'a'..'z']);
end;

function TSvgNumberReader.TakeCommand: Char;
begin
  SkipSeparators;
  Result := FText[FIndex];
  Inc(FIndex);
end;

function TSvgNumberReader.TryReadNumber(out Value: Single): Boolean;
begin
  Value := 0;
  SkipSeparators;

  const Start = FIndex;
  if FIndex > Length(FText) then
    Exit(False);

  if CharInSet(FText[FIndex], ['+', '-']) then
    Inc(FIndex);

  var Digits := 0;
  while (FIndex <= Length(FText)) and CharInSet(FText[FIndex], ['0'..'9']) do
  begin
    Inc(FIndex);
    Inc(Digits);
  end;

  if (FIndex <= Length(FText)) and (FText[FIndex] = '.') then
  begin
    Inc(FIndex);
    while (FIndex <= Length(FText)) and CharInSet(FText[FIndex], ['0'..'9']) do
    begin
      Inc(FIndex);
      Inc(Digits);
    end;
  end;

  if Digits = 0 then
  begin
    FIndex := Start;
    Exit(False);
  end;

  const HasExponent = (FIndex <= Length(FText)) and CharInSet(FText[FIndex], ['e', 'E']);
  if HasExponent then
  begin
    const ExponentStart = FIndex;
    Inc(FIndex);
    if (FIndex <= Length(FText)) and CharInSet(FText[FIndex], ['+', '-']) then
      Inc(FIndex);

    var ExponentDigits := 0;
    while (FIndex <= Length(FText)) and CharInSet(FText[FIndex], ['0'..'9']) do
    begin
      Inc(FIndex);
      Inc(ExponentDigits);
    end;

    if ExponentDigits = 0 then
      FIndex := ExponentStart;
  end;

  Result := TryStrToFloat(Copy(FText, Start, FIndex - Start), Value, TFormatSettings.Invariant);
  if not Result then
    FIndex := Start;
end;

function TSvgNumberReader.ReadNumber: Single;
begin
  if not TryReadNumber(Result) then
    Result := 0;
end;

// The large-arc and sweep flags are single digits that may be written without
// any separator at all, so they cannot go through the number reader.
function TSvgNumberReader.TryReadFlag(out Value: Boolean): Boolean;
begin
  Value := False;
  SkipSeparators;

  if FIndex > Length(FText) then
    Exit(False);

  if not CharInSet(FText[FIndex], ['0', '1']) then
    Exit(False);

  Value := FText[FIndex] = '1';
  Inc(FIndex);
  Result := True;
end;

class function TSvgPathParser.SegmentsFor(const ChordLength: Single): Integer;
begin
  Result := Ceil(ChordLength / FlatteningStep);
  Result := Min(MaxCurveSegments, Max(MinCurveSegments, Result));
end;

class function TSvgPathParser.CubicPoints(const Start, ControlOne, ControlTwo,
  Stop: TLayoutPointF): TArray<TLayoutPointF>;
begin
  const Rough = Abs(ControlOne.X - Start.X) + Abs(ControlOne.Y - Start.Y) +
    Abs(ControlTwo.X - ControlOne.X) + Abs(ControlTwo.Y - ControlOne.Y) +
    Abs(Stop.X - ControlTwo.X) + Abs(Stop.Y - ControlTwo.Y);
  const Segments = SegmentsFor(Rough);

  SetLength(Result, Segments);
  for var Step := 1 to Segments do
  begin
    const T = Step / Segments;
    const Inverse = 1 - T;
    const A = Inverse * Inverse * Inverse;
    const B = 3 * Inverse * Inverse * T;
    const C = 3 * Inverse * T * T;
    const D = T * T * T;

    Result[Step - 1] := TLayoutPointF.Create(
      A * Start.X + B * ControlOne.X + C * ControlTwo.X + D * Stop.X,
      A * Start.Y + B * ControlOne.Y + C * ControlTwo.Y + D * Stop.Y);
  end;
end;

class function TSvgPathParser.QuadraticPoints(const Start, Control, Stop: TLayoutPointF): TArray<TLayoutPointF>;
begin
  const Rough = Abs(Control.X - Start.X) + Abs(Control.Y - Start.Y) +
    Abs(Stop.X - Control.X) + Abs(Stop.Y - Control.Y);
  const Segments = SegmentsFor(Rough);

  SetLength(Result, Segments);
  for var Step := 1 to Segments do
  begin
    const T = Step / Segments;
    const Inverse = 1 - T;
    const A = Inverse * Inverse;
    const B = 2 * Inverse * T;
    const C = T * T;

    Result[Step - 1] := TLayoutPointF.Create(
      A * Start.X + B * Control.X + C * Stop.X,
      A * Start.Y + B * Control.Y + C * Stop.Y);
  end;
end;

// Endpoint parameterization to centre parameterization, as the specification's
// implementation notes describe it, and then sampled along the sweep.
class function TSvgPathParser.ArcPoints(const Start, Stop: TLayoutPointF;
  const RadiusX, RadiusY, RotationDegrees: Single; const LargeArc, Sweep: Boolean): TArray<TLayoutPointF>;
begin
  var Rx := Abs(RadiusX);
  var Ry := Abs(RadiusY);

  const Degenerate = (Rx = 0) or (Ry = 0) or ((Start.X = Stop.X) and (Start.Y = Stop.Y));
  if Degenerate then
  begin
    Result := [Stop];
    Exit;
  end;

  const Angle = RotationDegrees * RadiansPerDegree;
  const CosAngle = Cos(Angle);
  const SinAngle = Sin(Angle);

  const HalfDeltaX = (Start.X - Stop.X) / 2;
  const HalfDeltaY = (Start.Y - Stop.Y) / 2;
  const LocalX = CosAngle * HalfDeltaX + SinAngle * HalfDeltaY;
  const LocalY = -SinAngle * HalfDeltaX + CosAngle * HalfDeltaY;

  // Radii too small to reach cannot draw the arc that was asked for, so the
  // specification says to grow both until they just fit.
  const Overshoot = Sqr(LocalX) / Sqr(Rx) + Sqr(LocalY) / Sqr(Ry);
  if Overshoot > 1 then
  begin
    const Growth = Sqrt(Overshoot);
    Rx := Rx * Growth;
    Ry := Ry * Growth;
  end;

  const Numerator = Max(0, Sqr(Rx) * Sqr(Ry) - Sqr(Rx) * Sqr(LocalY) - Sqr(Ry) * Sqr(LocalX));
  const Denominator = Sqr(Rx) * Sqr(LocalY) + Sqr(Ry) * Sqr(LocalX);
  var Factor := 0.0;
  if Denominator > 0 then
    Factor := Sqrt(Numerator / Denominator);
  if LargeArc = Sweep then
    Factor := -Factor;

  const CentreLocalX = Factor * Rx * LocalY / Ry;
  const CentreLocalY = -Factor * Ry * LocalX / Rx;
  const CentreX = CosAngle * CentreLocalX - SinAngle * CentreLocalY + (Start.X + Stop.X) / 2;
  const CentreY = SinAngle * CentreLocalX + CosAngle * CentreLocalY + (Start.Y + Stop.Y) / 2;

  const StartAngle = ArcTan2((LocalY - CentreLocalY) / Ry, (LocalX - CentreLocalX) / Rx);
  const StopAngle = ArcTan2((-LocalY - CentreLocalY) / Ry, (-LocalX - CentreLocalX) / Rx);

  var Sweeping := StopAngle - StartAngle;
  if Sweep and (Sweeping < 0) then
    Sweeping := Sweeping + 2 * Pi
  else if (not Sweep) and (Sweeping > 0) then
    Sweeping := Sweeping - 2 * Pi;

  var Segments := Ceil(Abs(Sweeping) / RadiansPerDegree / DegreesPerArcSegment);
  Segments := Min(MaxArcSegments, Max(MinArcSegments, Segments));

  SetLength(Result, Segments);
  for var Step := 1 to Segments do
  begin
    const Current = StartAngle + Sweeping * Step / Segments;
    const UnitX = Rx * Cos(Current);
    const UnitY = Ry * Sin(Current);

    Result[Step - 1] := TLayoutPointF.Create(
      CosAngle * UnitX - SinAngle * UnitY + CentreX,
      SinAngle * UnitX + CosAngle * UnitY + CentreY);
  end;
end;

class function TSvgPathParser.Parse(const Data: string): TArray<TSvgSubPath>;
begin
  const Parser = TSvgPathParser.Create;
  try
    Parser.Run(Data);

    Result := Parser.FPaths;
  finally
    Parser.Free;
  end;
end;

procedure TSvgPathParser.Flush;
begin
  if FHasCurrent and (Length(FCurrent.Points) > 1) then
    FPaths := FPaths + [FCurrent];

  FCurrent := Default(TSvgSubPath);
  FHasCurrent := False;
end;

procedure TSvgPathParser.Add(const Point: TLayoutPointF);
begin
  FCurrent.Points := FCurrent.Points + [Point];
  FState.Current := Point;
end;

procedure TSvgPathParser.AddMany(const Points: TArray<TLayoutPointF>);
begin
  for var Point in Points do
  begin
    Add(Point);
  end;
end;

function TSvgPathParser.TryMoveTo(const Origin: TLayoutPointF): Boolean;
begin
  var Value: Single;
  Result := FReader.TryReadNumber(Value);
  if not Result then
    Exit;

  const Point = TLayoutPointF.Create(Origin.X + Value, Origin.Y + FReader.ReadNumber);

  Flush;
  FHasCurrent := True;
  FState.Start := Point;
  Add(Point);
end;

function TSvgPathParser.TryLineTo(const Origin: TLayoutPointF): Boolean;
begin
  var Value: Single;
  Result := FReader.TryReadNumber(Value);
  if not Result then
    Exit;

  Add(TLayoutPointF.Create(Origin.X + Value, Origin.Y + FReader.ReadNumber));
end;

function TSvgPathParser.TryHorizontalTo(const Origin: TLayoutPointF): Boolean;
begin
  var Value: Single;
  Result := FReader.TryReadNumber(Value);
  if not Result then
    Exit;

  Add(TLayoutPointF.Create(Origin.X + Value, FState.Current.Y));
end;

function TSvgPathParser.TryVerticalTo(const Origin: TLayoutPointF): Boolean;
begin
  var Value: Single;
  Result := FReader.TryReadNumber(Value);
  if not Result then
    Exit;

  Add(TLayoutPointF.Create(FState.Current.X, Origin.Y + Value));
end;

function TSvgPathParser.TryCubicTo(const Origin: TLayoutPointF): Boolean;
begin
  var Value: Single;
  Result := FReader.TryReadNumber(Value);
  if not Result then
    Exit;

  const ControlOne = TLayoutPointF.Create(Origin.X + Value, Origin.Y + FReader.ReadNumber);
  const ControlTwo = TLayoutPointF.Create(Origin.X + FReader.ReadNumber, Origin.Y + FReader.ReadNumber);
  const Stop = TLayoutPointF.Create(Origin.X + FReader.ReadNumber, Origin.Y + FReader.ReadNumber);

  AddMany(CubicPoints(FState.Current, ControlOne, ControlTwo, Stop));
  FState.LastCubicControl := ControlTwo;
  FState.HadCubic := True;
  FState.HadQuadratic := False;
end;

function TSvgPathParser.TrySmoothCubicTo(const Origin: TLayoutPointF): Boolean;
begin
  var Value: Single;
  Result := FReader.TryReadNumber(Value);
  if not Result then
    Exit;

  const Start = FState.Current;

  // A smooth curve mirrors the control point of the curve before it.
  var ControlOne := Start;
  if FState.HadCubic then
    ControlOne := TLayoutPointF.Create(2 * Start.X - FState.LastCubicControl.X,
      2 * Start.Y - FState.LastCubicControl.Y);

  const ControlTwo = TLayoutPointF.Create(Origin.X + Value, Origin.Y + FReader.ReadNumber);
  const Stop = TLayoutPointF.Create(Origin.X + FReader.ReadNumber, Origin.Y + FReader.ReadNumber);

  AddMany(CubicPoints(Start, ControlOne, ControlTwo, Stop));
  FState.LastCubicControl := ControlTwo;
  FState.HadCubic := True;
  FState.HadQuadratic := False;
end;

function TSvgPathParser.TryQuadraticTo(const Origin: TLayoutPointF): Boolean;
begin
  var Value: Single;
  Result := FReader.TryReadNumber(Value);
  if not Result then
    Exit;

  const Control = TLayoutPointF.Create(Origin.X + Value, Origin.Y + FReader.ReadNumber);
  const Stop = TLayoutPointF.Create(Origin.X + FReader.ReadNumber, Origin.Y + FReader.ReadNumber);

  AddMany(QuadraticPoints(FState.Current, Control, Stop));
  FState.LastQuadraticControl := Control;
  FState.HadQuadratic := True;
  FState.HadCubic := False;
end;

function TSvgPathParser.TrySmoothQuadraticTo(const Origin: TLayoutPointF): Boolean;
begin
  var Value: Single;
  Result := FReader.TryReadNumber(Value);
  if not Result then
    Exit;

  const Start = FState.Current;

  var Control := Start;
  if FState.HadQuadratic then
    Control := TLayoutPointF.Create(2 * Start.X - FState.LastQuadraticControl.X,
      2 * Start.Y - FState.LastQuadraticControl.Y);

  const Stop = TLayoutPointF.Create(Origin.X + Value, Origin.Y + FReader.ReadNumber);

  AddMany(QuadraticPoints(Start, Control, Stop));
  FState.LastQuadraticControl := Control;
  FState.HadQuadratic := True;
  FState.HadCubic := False;
end;

function TSvgPathParser.TryArcTo(const Origin: TLayoutPointF): Boolean;
begin
  var Value: Single;
  Result := FReader.TryReadNumber(Value);
  if not Result then
    Exit;

  const RadiusX = Value;
  const RadiusY = FReader.ReadNumber;
  const Rotation = FReader.ReadNumber;

  var LargeArc := False;
  var Sweep := False;
  Result := FReader.TryReadFlag(LargeArc) and FReader.TryReadFlag(Sweep);
  if not Result then
    Exit;

  const Stop = TLayoutPointF.Create(Origin.X + FReader.ReadNumber, Origin.Y + FReader.ReadNumber);

  AddMany(ArcPoints(FState.Current, Stop, RadiusX, RadiusY, Rotation, LargeArc, Sweep));
  FState.HadCubic := False;
  FState.HadQuadratic := False;
end;

procedure TSvgPathParser.ClosePath;
begin
  if FHasCurrent then
  begin
    FCurrent.IsClosed := True;
    Flush;
  end;

  FState.Current := FState.Start;
end;

// False stops the walk: the command is either unknown or its numbers ran out
// halfway, and a path that cannot be read further ends where it got to.
function TSvgPathParser.TryRunCommand(const Command: Char; const Origin: TLayoutPointF): Boolean;
begin
  case UpCase(Command) of
    'M':
      Result := TryMoveTo(Origin);
    'L':
      Result := TryLineTo(Origin);
    'H':
      Result := TryHorizontalTo(Origin);
    'V':
      Result := TryVerticalTo(Origin);
    'C':
      Result := TryCubicTo(Origin);
    'S':
      Result := TrySmoothCubicTo(Origin);
    'Q':
      Result := TryQuadraticTo(Origin);
    'T':
      Result := TrySmoothQuadraticTo(Origin);
    'A':
      Result := TryArcTo(Origin);
    'Z':
      begin
        ClosePath;
        Result := True;
      end;
  else
    Result := False;
  end;
end;

procedure TSvgPathParser.Run(const Data: string);
begin
  if Data.Trim = '' then
    Exit;

  FReader := TSvgNumberReader.Create(Data);
  var Command := #0;

  while not FReader.AtEnd do
  begin
    var Next: Char;
    if FReader.PeekCommand(Next) then
      Command := FReader.TakeCommand
    else if Command = #0 then
      Break
    // A second pair of coordinates after a moveto draws a line, which is what
    // the specification says a repeated M means.
    else if Command = 'M' then
      Command := 'L'
    else if Command = 'm' then
      Command := 'l';

    const Relative = CharInSet(Command, ['a'..'z']);
    var Origin := TLayoutPointF.Create(0, 0);
    if Relative then
      Origin := FState.Current;

    if not TryRunCommand(Command, Origin) then
      Break;

    const StartsNewCurve = CharInSet(UpCase(Command), ['C', 'S', 'Q', 'T', 'A']);
    if not StartsNewCurve then
    begin
      FState.HadCubic := False;
      FState.HadQuadratic := False;
    end;
  end;

  Flush;
end;

end.
