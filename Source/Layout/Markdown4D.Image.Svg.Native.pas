unit Markdown4D.Image.Svg.Native;

{$SCOPEDENUMS ON}

// Draws an SVG with the parser, the flattener and the polygon rasterizer of
// this project, so a plain drawing needs no graphics library underneath it.
//
// What it covers: the shape elements, groups, transforms, the viewBox, solid
// fills and strokes, opacity, and both fill rules. What it does not: text,
// gradients, patterns, filters, clip paths, masks, embedded images and <use>.
// A document reaching for any of those is handed to the fallback rasterizer
// rather than drawn wrong, because half a drawing is worse than none.

interface

uses
  Markdown4D.Image.Svg;

// Takes over the viewer's SVG hook, keeping whatever was registered before as
// the fallback for documents this engine will not draw.
procedure RegisterNativeSvgRasterizer;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Math,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Image.Rasterizer,
  Markdown4D.Image.Svg.Xml,
  Markdown4D.Image.Svg.Path,
  Markdown4D.Image.Svg.Image32;

type
  TSvgMatrix = record
    A, B, C, D, E, F: Single;
    class function Identity: TSvgMatrix; static;
    class function Translation(const X, Y: Single): TSvgMatrix; static;
    class function Scaling(const X, Y: Single): TSvgMatrix; static;
    class function Rotation(const Degrees: Single): TSvgMatrix; static;
    class function SkewX(const Degrees: Single): TSvgMatrix; static;
    class function SkewY(const Degrees: Single): TSvgMatrix; static;
    function Multiply(const Other: TSvgMatrix): TSvgMatrix;
    function Apply(const Point: TLayoutPointF): TLayoutPointF;
    function AverageScale: Single;
  end;

  TSvgStyle = record
    FillColor: TLayoutColor;
    HasFill: Boolean;
    StrokeColor: TLayoutColor;
    HasStroke: Boolean;
    StrokeWidth: Single;
    FillRule: TMarkdownFillRule;
    Opacity: Single;
    FillOpacity: Single;
    StrokeOpacity: Single;
    RoundCaps: Boolean;
    RoundJoins: Boolean;
    class function Initial: TSvgStyle; static;
  end;

  TSvgFrame = record
    Matrix: TSvgMatrix;
    Style: TSvgStyle;
    Depth: Integer;
  end;

  ESvgUnsupported = class(Exception);

  TNativeSvgRenderer = class
  private
    const
      DefaultViewportSize = 300.0;
      MinimumStrokeWidth = 0.1;
      JoinSegments = 12;
      // Past this ratio of miter length to stroke width a sharp corner grows a
      // spike, which is where the specification says to cut it off square.
      MiterLimit = 4.0;
      RadiansPerDegree = Pi / 180;
      OpaqueAlpha = $FF000000;
      SkippedElements: array[0..3] of string = ('defs', 'clippath', 'mask', 'marker');
      UnsupportedElements: array[0..5] of string = ('text', 'image', 'use', 'filter', 'lineargradient',
        'radialgradient');
    var
      FRaster: TMarkdownPixelRaster;
      FStack: TArray<TSvgFrame>;
      FDepth: Integer;
      FSkipUntilDepth: Integer;
      FSkipping: Boolean;
    function Frame: TSvgFrame;
    procedure Push(const Element: TSvgXmlElement);
    procedure Pop;
    procedure DrawElement(const Element: TSvgXmlElement);
    procedure DrawSubPaths(const SubPaths: TArray<TSvgSubPath>; const Style: TSvgStyle; const Matrix: TSvgMatrix);
    procedure FillSubPaths(const SubPaths: TArray<TSvgSubPath>; const Style: TSvgStyle; const Matrix: TSvgMatrix);
    procedure StrokeSubPaths(const SubPaths: TArray<TSvgSubPath>; const Style: TSvgStyle; const Matrix: TSvgMatrix);
    class function Transformed(const Points: TArray<TLayoutPointF>; const Matrix: TSvgMatrix): TArray<TLayoutPointF>; static;
    class function StrokeContours(const Points: TArray<TLayoutPointF>; const Closed: Boolean;
      const HalfWidth: Single; const Style: TSvgStyle): TArray<TArray<TLayoutPointF>>; static;
    class function JoinContours(const Previous, Corner, Next: TLayoutPointF;
      const HalfWidth: Single): TArray<TArray<TLayoutPointF>>; static;
    class function Disc(const Centre: TLayoutPointF; const Radius: Single): TArray<TLayoutPointF>; static;
    class function Anticlockwise(const Points: TArray<TLayoutPointF>): TArray<TLayoutPointF>; static;
    class function RectanglePath(const Left, Top, Width, Height, RadiusX, RadiusY: Single): TArray<TSvgSubPath>; static;
    class function EllipsePath(const CentreX, CentreY, RadiusX, RadiusY: Single): TArray<TSvgSubPath>; static;
    class function PointsPath(const Data: string; const Closed: Boolean): TArray<TSvgSubPath>; static;

  public
    function Render(const Svg: string; const MaxWidth, MaxHeight: Single): TMarkdownSvgRaster;
  end;

var
  FallbackRasterizer: TMarkdownSvgRasterizer;

class function TSvgMatrix.Identity: TSvgMatrix;
begin
  Result.A := 1;
  Result.B := 0;
  Result.C := 0;
  Result.D := 1;
  Result.E := 0;
  Result.F := 0;
end;

class function TSvgMatrix.Translation(const X, Y: Single): TSvgMatrix;
begin
  Result := Identity;
  Result.E := X;
  Result.F := Y;
end;

class function TSvgMatrix.Scaling(const X, Y: Single): TSvgMatrix;
begin
  Result := Identity;
  Result.A := X;
  Result.D := Y;
end;

class function TSvgMatrix.Rotation(const Degrees: Single): TSvgMatrix;
begin
  const Angle = Degrees * Pi / 180;

  Result := Identity;
  Result.A := Cos(Angle);
  Result.B := Sin(Angle);
  Result.C := -Sin(Angle);
  Result.D := Cos(Angle);
end;

class function TSvgMatrix.SkewX(const Degrees: Single): TSvgMatrix;
begin
  Result := Identity;
  Result.C := Tan(Degrees * Pi / 180);
end;

class function TSvgMatrix.SkewY(const Degrees: Single): TSvgMatrix;
begin
  Result := Identity;
  Result.B := Tan(Degrees * Pi / 180);
end;

// Self first, then Other, which is the order a transform list applies in.
function TSvgMatrix.Multiply(const Other: TSvgMatrix): TSvgMatrix;
begin
  Result.A := A * Other.A + C * Other.B;
  Result.B := B * Other.A + D * Other.B;
  Result.C := A * Other.C + C * Other.D;
  Result.D := B * Other.C + D * Other.D;
  Result.E := A * Other.E + C * Other.F + E;
  Result.F := B * Other.E + D * Other.F + F;
end;

function TSvgMatrix.Apply(const Point: TLayoutPointF): TLayoutPointF;
begin
  Result := TLayoutPointF.Create(A * Point.X + C * Point.Y + E, B * Point.X + D * Point.Y + F);
end;

// What a stroke width becomes after the transform. A stroke under an uneven
// scale is an ellipse rather than a circle, which this rounds off to one width.
function TSvgMatrix.AverageScale: Single;
begin
  Result := (Sqrt(A * A + B * B) + Sqrt(C * C + D * D)) / 2;
end;

class function TSvgStyle.Initial: TSvgStyle;
begin
  Result.FillColor := $FF000000;
  Result.HasFill := True;
  Result.StrokeColor := $FF000000;
  Result.HasStroke := False;
  Result.StrokeWidth := 1;
  Result.FillRule := TMarkdownFillRule.NonZero;
  Result.Opacity := 1;
  Result.FillOpacity := 1;
  Result.StrokeOpacity := 1;
  Result.RoundCaps := False;
  Result.RoundJoins := False;
end;

function TryParseLength(const Text: string; out Value: Single): Boolean;
const
  Suffixes: array[0..6] of string = ('px', 'pt', 'pc', 'mm', 'cm', 'in', '%');
begin
  var Trimmed := Text.Trim;
  if Trimmed = '' then
    Exit(False);

  for var Suffix in Suffixes do
  begin
    if Trimmed.EndsWith(Suffix, True) then
    begin
      Trimmed := Copy(Trimmed, 1, Length(Trimmed) - Length(Suffix)).Trim;
      Break;
    end;
  end;

  Result := TryStrToFloat(Trimmed, Value, TFormatSettings.Invariant);
end;

function TryParseColor(const Text: string; out Color: TLayoutColor): Boolean;
const
  Named: array[0..15] of record Name: string; Value: Cardinal; end = (
    (Name: 'black'; Value: $FF000000), (Name: 'white'; Value: $FFFFFFFF),
    (Name: 'red'; Value: $FFFF0000), (Name: 'lime'; Value: $FF00FF00),
    (Name: 'blue'; Value: $FF0000FF), (Name: 'yellow'; Value: $FFFFFF00),
    (Name: 'cyan'; Value: $FF00FFFF), (Name: 'aqua'; Value: $FF00FFFF),
    (Name: 'magenta'; Value: $FFFF00FF), (Name: 'fuchsia'; Value: $FFFF00FF),
    (Name: 'silver'; Value: $FFC0C0C0), (Name: 'gray'; Value: $FF808080),
    (Name: 'grey'; Value: $FF808080), (Name: 'maroon'; Value: $FF800000),
    (Name: 'green'; Value: $FF008000), (Name: 'navy'; Value: $FF000080));
begin
  Color := $FF000000;
  const Trimmed = Text.Trim.ToLowerInvariant;
  if Trimmed = '' then
    Exit(False);

  if Trimmed.StartsWith('#') then
  begin
    const Digits = Copy(Trimmed, 2, MaxInt);
    var Value := 0;

    if Length(Digits) = 3 then
    begin
      if not TryStrToInt('$' + Digits[1] + Digits[1] + Digits[2] + Digits[2] + Digits[3] + Digits[3], Value) then
        Exit(False);
    end
    else if Length(Digits) = 6 then
    begin
      if not TryStrToInt('$' + Digits, Value) then
        Exit(False);
    end
    else
      Exit(False);

    Color := TLayoutColor(Cardinal(Value) or $FF000000);
    Exit(True);
  end;

  if Trimmed.StartsWith('rgb(') and Trimmed.EndsWith(')') then
  begin
    const Inner = Copy(Trimmed, 5, Length(Trimmed) - 5);
    var Reader := TSvgNumberReader.Create(Inner);

    var Red: Single;
    var Green: Single;
    var Blue: Single;
    if not (Reader.TryReadNumber(Red) and Reader.TryReadNumber(Green) and Reader.TryReadNumber(Blue)) then
      Exit(False);

    Color := TLayoutColor($FF000000 or (Cardinal(Round(EnsureRange(Red, 0, 255))) shl 16) or
      (Cardinal(Round(EnsureRange(Green, 0, 255))) shl 8) or Cardinal(Round(EnsureRange(Blue, 0, 255))));
    Exit(True);
  end;

  for var Entry in Named do
  begin
    if Entry.Name = Trimmed then
    begin
      Color := TLayoutColor(Entry.Value);
      Exit(True);
    end;
  end;

  Result := False;
end;

function StyleValue(const Style, Name: string): string;
begin
  Result := '';
  if Style = '' then
    Exit;

  for var Part in Style.Split([';']) do
  begin
    const Separator = Pos(':', Part);
    if Separator = 0 then
      Continue;

    if SameText(Copy(Part, 1, Separator - 1).Trim, Name) then
      Exit(Copy(Part, Separator + 1, MaxInt).Trim);
  end;
end;

// An attribute and its counterpart inside a style attribute say the same thing,
// with the style winning, so both are read through one lookup.
function PresentationValue(const Element: TSvgXmlElement; const Name: string): string;
begin
  const Style = Element.Attribute('style');

  Result := StyleValue(Style, Name);
  if Result = '' then
    Result := Element.Attribute(Name);
end;

function ParseTransform(const Text: string): TSvgMatrix;
begin
  Result := TSvgMatrix.Identity;
  if Text.Trim = '' then
    Exit;

  var Index := 1;
  while Index <= Length(Text) do
  begin
    const Open = Pos('(', Text, Index);
    if Open = 0 then
      Exit;

    const Close = Pos(')', Text, Open);
    if Close = 0 then
      Exit;

    const Name = Copy(Text, Index, Open - Index).Trim.Replace(',', '').ToLowerInvariant;
    var Reader := TSvgNumberReader.Create(Copy(Text, Open + 1, Close - Open - 1));

    var Values: TArray<Single> := nil;
    var Value: Single;
    while Reader.TryReadNumber(Value) do
    begin
      Values := Values + [Value];
    end;

    var Step := TSvgMatrix.Identity;

    if (Name = 'translate') and (Length(Values) >= 1) then
    begin
      var OffsetY := 0.0;
      if Length(Values) >= 2 then
        OffsetY := Values[1];
      Step := TSvgMatrix.Translation(Values[0], OffsetY);
    end
    else if (Name = 'scale') and (Length(Values) >= 1) then
    begin
      var ScaleY := Values[0];
      if Length(Values) >= 2 then
        ScaleY := Values[1];
      Step := TSvgMatrix.Scaling(Values[0], ScaleY);
    end
    else if (Name = 'rotate') and (Length(Values) >= 1) then
    begin
      if Length(Values) >= 3 then
        Step := TSvgMatrix.Translation(Values[1], Values[2])
          .Multiply(TSvgMatrix.Rotation(Values[0]))
          .Multiply(TSvgMatrix.Translation(-Values[1], -Values[2]))
      else
        Step := TSvgMatrix.Rotation(Values[0]);
    end
    else if (Name = 'skewx') and (Length(Values) >= 1) then
      Step := TSvgMatrix.SkewX(Values[0])
    else if (Name = 'skewy') and (Length(Values) >= 1) then
      Step := TSvgMatrix.SkewY(Values[0])
    else if (Name = 'matrix') and (Length(Values) >= 6) then
    begin
      Step.A := Values[0];
      Step.B := Values[1];
      Step.C := Values[2];
      Step.D := Values[3];
      Step.E := Values[4];
      Step.F := Values[5];
    end;

    Result := Result.Multiply(Step);
    Index := Close + 1;
  end;
end;

function ReadStyle(const Element: TSvgXmlElement; const Parent: TSvgStyle): TSvgStyle;
begin
  Result := Parent;

  const Fill = PresentationValue(Element, 'fill');
  if Fill <> '' then
  begin
    if SameText(Fill.Trim, 'none') then
      Result.HasFill := False
    else if TryParseColor(Fill, Result.FillColor) then
      Result.HasFill := True
    else if not SameText(Fill.Trim, 'currentcolor') then
      raise ESvgUnsupported.CreateFmt('fill "%s"', [Fill]);
  end;

  const Stroke = PresentationValue(Element, 'stroke');
  if Stroke <> '' then
  begin
    if SameText(Stroke.Trim, 'none') then
      Result.HasStroke := False
    else if TryParseColor(Stroke, Result.StrokeColor) then
      Result.HasStroke := True
    else if not SameText(Stroke.Trim, 'currentcolor') then
      raise ESvgUnsupported.CreateFmt('stroke "%s"', [Stroke]);
  end;

  var Value: Single;
  if TryParseLength(PresentationValue(Element, 'stroke-width'), Value) then
    Result.StrokeWidth := Value;

  if TryParseLength(PresentationValue(Element, 'opacity'), Value) then
    Result.Opacity := Result.Opacity * EnsureRange(Value, 0, 1);

  if TryParseLength(PresentationValue(Element, 'fill-opacity'), Value) then
    Result.FillOpacity := EnsureRange(Value, 0, 1);

  if TryParseLength(PresentationValue(Element, 'stroke-opacity'), Value) then
    Result.StrokeOpacity := EnsureRange(Value, 0, 1);

  if SameText(PresentationValue(Element, 'fill-rule').Trim, 'evenodd') then
    Result.FillRule := TMarkdownFillRule.EvenOdd
  else if SameText(PresentationValue(Element, 'fill-rule').Trim, 'nonzero') then
    Result.FillRule := TMarkdownFillRule.NonZero;

  Result.RoundCaps := SameText(PresentationValue(Element, 'stroke-linecap').Trim, 'round');

  const Join = PresentationValue(Element, 'stroke-linejoin').Trim;
  if Join <> '' then
    Result.RoundJoins := SameText(Join, 'round');
end;

function WithOpacity(const Color: TLayoutColor; const Opacity: Single): TLayoutColor;
begin
  const Alpha = Round((Color shr 24) * EnsureRange(Opacity, 0, 1));

  Result := TLayoutColor((Color and $00FFFFFF) or (Cardinal(Alpha) shl 24));
end;

function TNativeSvgRenderer.Frame: TSvgFrame;
begin
  Result := FStack[High(FStack)];
end;

procedure TNativeSvgRenderer.Push(const Element: TSvgXmlElement);
begin
  var Next := Frame;
  Next.Depth := FDepth;
  Next.Style := ReadStyle(Element, Next.Style);
  Next.Matrix := ParseTransform(Element.Attribute('transform')).Multiply(Next.Matrix);

  FStack := FStack + [Next];
end;

procedure TNativeSvgRenderer.Pop;
begin
  if Length(FStack) > 1 then
    SetLength(FStack, Length(FStack) - 1);
end;

class function TNativeSvgRenderer.Transformed(const Points: TArray<TLayoutPointF>;
  const Matrix: TSvgMatrix): TArray<TLayoutPointF>;
begin
  SetLength(Result, Length(Points));

  for var Index := 0 to High(Points) do
  begin
    Result[Index] := Matrix.Apply(Points[Index]);
  end;
end;

// Every piece of a stroke has to wind the same way. Two overlapping pieces that
// wind against each other cancel out under the non-zero rule, which leaves a
// hole exactly where the band should be at its thickest.
class function TNativeSvgRenderer.Anticlockwise(const Points: TArray<TLayoutPointF>): TArray<TLayoutPointF>;
begin
  Result := Points;
  if Length(Points) < 3 then
    Exit;

  var Area := 0.0;
  for var Index := 0 to High(Points) do
  begin
    var NextIndex := Index + 1;
    if NextIndex > High(Points) then
      NextIndex := 0;

    Area := Area + Points[Index].X * Points[NextIndex].Y - Points[NextIndex].X * Points[Index].Y;
  end;

  if Area >= 0 then
    Exit;

  // Into a buffer of its own: assigning a dynamic array shares it, so writing
  // the reversal in place would overwrite the points still to be read.
  var Reversed: TArray<TLayoutPointF>;
  SetLength(Reversed, Length(Points));
  for var Index := 0 to High(Points) do
  begin
    Reversed[Index] := Points[High(Points) - Index];
  end;

  Result := Reversed;
end;

class function TNativeSvgRenderer.Disc(const Centre: TLayoutPointF; const Radius: Single): TArray<TLayoutPointF>;
begin
  SetLength(Result, JoinSegments);

  for var Step := 0 to JoinSegments - 1 do
  begin
    const Angle = 2 * Pi * Step / JoinSegments;
    Result[Step] := TLayoutPointF.Create(Centre.X + Radius * Cos(Angle), Centre.Y + Radius * Sin(Angle));
  end;
end;

// A stroke becomes a quad per segment plus a join at every corner, filled as
// one figure with the non-zero rule so the pieces read as a single band.
class function TNativeSvgRenderer.StrokeContours(const Points: TArray<TLayoutPointF>; const Closed: Boolean;
  const HalfWidth: Single; const Style: TSvgStyle): TArray<TArray<TLayoutPointF>>;
begin
  Result := nil;
  if System.Length(Points) < 2 then
    Exit;

  var LastSegment := High(Points) - 1;
  if Closed then
    LastSegment := High(Points);

  for var Index := 0 to LastSegment do
  begin
    const Start = Points[Index];
    var StopIndex := Index + 1;
    if StopIndex > High(Points) then
      StopIndex := 0;
    const Stop = Points[StopIndex];

    const DeltaX = Stop.X - Start.X;
    const DeltaY = Stop.Y - Start.Y;
    const Span = Sqrt(DeltaX * DeltaX + DeltaY * DeltaY);
    if Span = 0 then
      Continue;

    const NormalX = -DeltaY / Span * HalfWidth;
    const NormalY = DeltaX / Span * HalfWidth;

    Result := Result + [Anticlockwise([
      TLayoutPointF.Create(Start.X + NormalX, Start.Y + NormalY),
      TLayoutPointF.Create(Stop.X + NormalX, Stop.Y + NormalY),
      TLayoutPointF.Create(Stop.X - NormalX, Stop.Y - NormalY),
      TLayoutPointF.Create(Start.X - NormalX, Start.Y - NormalY)])];
  end;

  var FirstCorner := 1;
  var LastCorner := High(Points) - 1;
  if Closed then
  begin
    FirstCorner := 0;
    LastCorner := High(Points);
  end;

  for var Corner := FirstCorner to LastCorner do
  begin
    var PreviousIndex := Corner - 1;
    if PreviousIndex < 0 then
      PreviousIndex := High(Points);
    var NextIndex := Corner + 1;
    if NextIndex > High(Points) then
      NextIndex := 0;

    if Style.RoundJoins then
      Result := Result + [Anticlockwise(Disc(Points[Corner], HalfWidth))]
    else
      Result := Result + JoinContours(Points[PreviousIndex], Points[Corner], Points[NextIndex], HalfWidth);
  end;

  if Closed or (not Style.RoundCaps) then
    Exit;

  Result := Result + [Anticlockwise(Disc(Points[0], HalfWidth))];
  Result := Result + [Anticlockwise(Disc(Points[High(Points)], HalfWidth))];
end;

// Closes the wedge two segments leave between them. The bevel triangle covers
// the corner itself; the miter tip extends it to the point the two edges would
// meet at, unless that point runs away from the corner.
class function TNativeSvgRenderer.JoinContours(const Previous, Corner, Next: TLayoutPointF;
  const HalfWidth: Single): TArray<TArray<TLayoutPointF>>;
begin
  Result := nil;

  const InX = Corner.X - Previous.X;
  const InY = Corner.Y - Previous.Y;
  const OutX = Next.X - Corner.X;
  const OutY = Next.Y - Corner.Y;

  const InLength = Sqrt(InX * InX + InY * InY);
  const OutLength = Sqrt(OutX * OutX + OutY * OutY);
  if (InLength = 0) or (OutLength = 0) then
    Exit;

  const InNormalX = -InY / InLength * HalfWidth;
  const InNormalY = InX / InLength * HalfWidth;
  const OutNormalX = -OutY / OutLength * HalfWidth;
  const OutNormalY = OutX / OutLength * HalfWidth;

  for var Side in [1, -1] do
  begin
    const FromX = Corner.X + Side * InNormalX;
    const FromY = Corner.Y + Side * InNormalY;
    const ToX = Corner.X + Side * OutNormalX;
    const ToY = Corner.Y + Side * OutNormalY;

    Result := Result + [Anticlockwise([Corner, TLayoutPointF.Create(FromX, FromY),
      TLayoutPointF.Create(ToX, ToY)])];

    // Where the two offset edges cross is the tip of the miter.
    const Denominator = InX / InLength * (OutY / OutLength) - InY / InLength * (OutX / OutLength);
    if Abs(Denominator) < 0.0001 then
      Continue;

    const GapX = ToX - FromX;
    const GapY = ToY - FromY;
    const Travel = (GapX * (OutY / OutLength) - GapY * (OutX / OutLength)) / Denominator;

    const TipX = FromX + InX / InLength * Travel;
    const TipY = FromY + InY / InLength * Travel;

    const Reach = Sqrt(Sqr(TipX - Corner.X) + Sqr(TipY - Corner.Y));
    if Reach > MiterLimit * HalfWidth then
      Continue;

    Result := Result + [Anticlockwise([TLayoutPointF.Create(FromX, FromY),
      TLayoutPointF.Create(TipX, TipY), TLayoutPointF.Create(ToX, ToY)])];
  end;
end;

procedure TNativeSvgRenderer.FillSubPaths(const SubPaths: TArray<TSvgSubPath>; const Style: TSvgStyle;
  const Matrix: TSvgMatrix);
begin
  var Contours: TArray<TArray<TLayoutPointF>> := nil;

  for var SubPath in SubPaths do
  begin
    if Length(SubPath.Points) >= 3 then
      Contours := Contours + [Transformed(SubPath.Points, Matrix)];
  end;

  if Length(Contours) = 0 then
    Exit;

  const Color = WithOpacity(Style.FillColor, Style.Opacity * Style.FillOpacity);

  TMarkdownPolygonRasterizer.FillContoursInto(FRaster, Contours, Color, Style.FillRule);
end;

procedure TNativeSvgRenderer.StrokeSubPaths(const SubPaths: TArray<TSvgSubPath>; const Style: TSvgStyle;
  const Matrix: TSvgMatrix);
begin
  const HalfWidth = Max(MinimumStrokeWidth, Style.StrokeWidth * Matrix.AverageScale) / 2;

  var Contours: TArray<TArray<TLayoutPointF>> := nil;
  for var SubPath in SubPaths do
  begin
    const Device = Transformed(SubPath.Points, Matrix);
    Contours := Contours + StrokeContours(Device, SubPath.IsClosed, HalfWidth, Style);
  end;

  if Length(Contours) = 0 then
    Exit;

  const Color = WithOpacity(Style.StrokeColor, Style.Opacity * Style.StrokeOpacity);

  TMarkdownPolygonRasterizer.FillContoursInto(FRaster, Contours, Color, TMarkdownFillRule.NonZero);
end;

procedure TNativeSvgRenderer.DrawSubPaths(const SubPaths: TArray<TSvgSubPath>; const Style: TSvgStyle;
  const Matrix: TSvgMatrix);
begin
  if Length(SubPaths) = 0 then
    Exit;

  if Style.HasFill then
    FillSubPaths(SubPaths, Style, Matrix);

  if Style.HasStroke then
    StrokeSubPaths(SubPaths, Style, Matrix);
end;

class function TNativeSvgRenderer.RectanglePath(const Left, Top, Width, Height,
  RadiusX, RadiusY: Single): TArray<TSvgSubPath>;
begin
  if (Width <= 0) or (Height <= 0) then
    Exit(nil);

  const Rx = Min(Max(0, RadiusX), Width / 2);
  const Ry = Min(Max(0, RadiusY), Height / 2);

  var Data := '';
  if (Rx = 0) or (Ry = 0) then
    Data := Format('M %s %s H %s V %s H %s Z',
      [FloatToStr(Left, TFormatSettings.Invariant), FloatToStr(Top, TFormatSettings.Invariant),
       FloatToStr(Left + Width, TFormatSettings.Invariant), FloatToStr(Top + Height, TFormatSettings.Invariant),
       FloatToStr(Left, TFormatSettings.Invariant)])
  else
    Data := Format('M %s %s H %s A %s %s 0 0 1 %s %s V %s A %s %s 0 0 1 %s %s H %s A %s %s 0 0 1 %s %s V %s ' +
      'A %s %s 0 0 1 %s %s Z',
      [FloatToStr(Left + Rx, TFormatSettings.Invariant), FloatToStr(Top, TFormatSettings.Invariant),
       FloatToStr(Left + Width - Rx, TFormatSettings.Invariant),
       FloatToStr(Rx, TFormatSettings.Invariant), FloatToStr(Ry, TFormatSettings.Invariant),
       FloatToStr(Left + Width, TFormatSettings.Invariant), FloatToStr(Top + Ry, TFormatSettings.Invariant),
       FloatToStr(Top + Height - Ry, TFormatSettings.Invariant),
       FloatToStr(Rx, TFormatSettings.Invariant), FloatToStr(Ry, TFormatSettings.Invariant),
       FloatToStr(Left + Width - Rx, TFormatSettings.Invariant), FloatToStr(Top + Height, TFormatSettings.Invariant),
       FloatToStr(Left + Rx, TFormatSettings.Invariant),
       FloatToStr(Rx, TFormatSettings.Invariant), FloatToStr(Ry, TFormatSettings.Invariant),
       FloatToStr(Left, TFormatSettings.Invariant), FloatToStr(Top + Height - Ry, TFormatSettings.Invariant),
       FloatToStr(Top + Ry, TFormatSettings.Invariant),
       FloatToStr(Rx, TFormatSettings.Invariant), FloatToStr(Ry, TFormatSettings.Invariant),
       FloatToStr(Left + Rx, TFormatSettings.Invariant), FloatToStr(Top, TFormatSettings.Invariant)]);

  Result := TSvgPathParser.Parse(Data);
end;

class function TNativeSvgRenderer.EllipsePath(const CentreX, CentreY, RadiusX, RadiusY: Single): TArray<TSvgSubPath>;
const
  Segments = 72;
begin
  if (RadiusX <= 0) or (RadiusY <= 0) then
    Exit(nil);

  var Points: TArray<TLayoutPointF>;
  SetLength(Points, Segments);
  for var Step := 0 to Segments - 1 do
  begin
    const Angle = 2 * Pi * Step / Segments;
    Points[Step] := TLayoutPointF.Create(CentreX + RadiusX * Cos(Angle), CentreY + RadiusY * Sin(Angle));
  end;

  var SubPath: TSvgSubPath;
  SubPath.Points := Points;
  SubPath.IsClosed := True;

  Result := [SubPath];
end;

class function TNativeSvgRenderer.PointsPath(const Data: string; const Closed: Boolean): TArray<TSvgSubPath>;
begin
  var Reader := TSvgNumberReader.Create(Data);

  var Points: TArray<TLayoutPointF> := nil;
  var X: Single;
  while Reader.TryReadNumber(X) do
  begin
    Points := Points + [TLayoutPointF.Create(X, Reader.ReadNumber)];
  end;

  if Length(Points) < 2 then
    Exit(nil);

  var SubPath: TSvgSubPath;
  SubPath.Points := Points;
  SubPath.IsClosed := Closed;

  Result := [SubPath];
end;

procedure TNativeSvgRenderer.DrawElement(const Element: TSvgXmlElement);
begin
  const Name = Element.Name.ToLowerInvariant;
  const Style = Frame.Style;
  const Matrix = Frame.Matrix;

  var Left: Single;
  var Top: Single;
  var Width: Single;
  var Height: Single;

  if Name = 'path' then
    DrawSubPaths(TSvgPathParser.Parse(Element.Attribute('d')), Style, Matrix)
  else if Name = 'rect' then
  begin
    if not TryParseLength(Element.Attribute('x', '0'), Left) then
      Left := 0;
    if not TryParseLength(Element.Attribute('y', '0'), Top) then
      Top := 0;
    if not (TryParseLength(Element.Attribute('width'), Width) and TryParseLength(Element.Attribute('height'), Height)) then
      Exit;

    var RadiusX: Single := 0;
    var RadiusY: Single := 0;
    TryParseLength(Element.Attribute('rx', '0'), RadiusX);
    if not TryParseLength(Element.Attribute('ry', '0'), RadiusY) then
      RadiusY := RadiusX;
    if RadiusY = 0 then
      RadiusY := RadiusX;
    if RadiusX = 0 then
      RadiusX := RadiusY;

    DrawSubPaths(RectanglePath(Left, Top, Width, Height, RadiusX, RadiusY), Style, Matrix);
  end
  else if Name = 'circle' then
  begin
    var Radius: Single;
    if not TryParseLength(Element.Attribute('r'), Radius) then
      Exit;
    if not TryParseLength(Element.Attribute('cx', '0'), Left) then
      Left := 0;
    if not TryParseLength(Element.Attribute('cy', '0'), Top) then
      Top := 0;

    DrawSubPaths(EllipsePath(Left, Top, Radius, Radius), Style, Matrix);
  end
  else if Name = 'ellipse' then
  begin
    var RadiusX: Single;
    var RadiusY: Single;
    if not (TryParseLength(Element.Attribute('rx'), RadiusX) and TryParseLength(Element.Attribute('ry'), RadiusY)) then
      Exit;
    if not TryParseLength(Element.Attribute('cx', '0'), Left) then
      Left := 0;
    if not TryParseLength(Element.Attribute('cy', '0'), Top) then
      Top := 0;

    DrawSubPaths(EllipsePath(Left, Top, RadiusX, RadiusY), Style, Matrix);
  end
  else if Name = 'line' then
  begin
    if not (TryParseLength(Element.Attribute('x1', '0'), Left) and TryParseLength(Element.Attribute('y1', '0'), Top) and
      TryParseLength(Element.Attribute('x2', '0'), Width) and TryParseLength(Element.Attribute('y2', '0'), Height)) then
      Exit;

    var SubPath: TSvgSubPath;
    SubPath.Points := [TLayoutPointF.Create(Left, Top), TLayoutPointF.Create(Width, Height)];
    SubPath.IsClosed := False;

    var LineStyle := Style;
    LineStyle.HasFill := False;
    DrawSubPaths([SubPath], LineStyle, Matrix);
  end
  else if Name = 'polyline' then
  begin
    var PolylineStyle := Style;
    PolylineStyle.HasFill := False;
    DrawSubPaths(PointsPath(Element.Attribute('points'), False), PolylineStyle, Matrix);
  end
  else if Name = 'polygon' then
    DrawSubPaths(PointsPath(Element.Attribute('points'), True), Style, Matrix);
end;

function TNativeSvgRenderer.Render(const Svg: string; const MaxWidth, MaxHeight: Single): TMarkdownSvgRaster;
begin
  Result := Default(TMarkdownSvgRaster);

  const Scanner = TSvgXmlScanner.Create(Svg);
  try
    var Root: TSvgXmlElement;
    var Found := False;
    while Scanner.ReadElement(Root) do
    begin
      if (not Root.IsClosing) and SameText(Root.Name, 'svg') then
      begin
        Found := True;
        Break;
      end;
    end;

    if not Found then
      raise ESvgUnsupported.Create('no svg element');

    var ViewWidth: Single := 0;
    var ViewHeight: Single := 0;
    var ViewLeft: Single := 0;
    var ViewTop: Single := 0;

    const ViewBox = Root.Attribute('viewBox');
    if ViewBox <> '' then
    begin
      var Reader := TSvgNumberReader.Create(ViewBox);
      ViewLeft := Reader.ReadNumber;
      ViewTop := Reader.ReadNumber;
      ViewWidth := Reader.ReadNumber;
      ViewHeight := Reader.ReadNumber;
    end;

    var DeclaredWidth: Single := 0;
    var DeclaredHeight: Single := 0;
    TryParseLength(Root.Attribute('width'), DeclaredWidth);
    TryParseLength(Root.Attribute('height'), DeclaredHeight);

    if (ViewWidth <= 0) or (ViewHeight <= 0) then
    begin
      ViewWidth := DeclaredWidth;
      ViewHeight := DeclaredHeight;
    end;

    if (ViewWidth <= 0) or (ViewHeight <= 0) then
      raise ESvgUnsupported.Create('no intrinsic size');

    var TargetWidth: Single := DeclaredWidth;
    var TargetHeight: Single := DeclaredHeight;
    if (TargetWidth <= 0) or (TargetHeight <= 0) then
    begin
      TargetWidth := ViewWidth;
      TargetHeight := ViewHeight;
    end;

    var Scale: Single := 1;
    if (MaxWidth > 0) and (TargetWidth * Scale > MaxWidth) then
      Scale := MaxWidth / TargetWidth;
    if (MaxHeight > 0) and (TargetHeight * Scale > MaxHeight) then
      Scale := MaxHeight / TargetHeight;

    const PixelWidth = Max(1, Round(TargetWidth * Scale));
    const PixelHeight = Max(1, Round(TargetHeight * Scale));

    FRaster := TMarkdownPixelRaster.Create(PixelWidth, PixelHeight);

    // viewBox to device: shift the box to the origin, then scale it onto the
    // pixels asked for.
    const Base = TSvgMatrix.Translation(-ViewLeft, -ViewTop)
      .Multiply(TSvgMatrix.Scaling(PixelWidth / ViewWidth, PixelHeight / ViewHeight));

    var Start := Default(TSvgFrame);
    Start.Matrix := Base;
    Start.Style := TSvgStyle.Initial;
    FStack := [Start];
    FDepth := 0;

    Push(Root);
    if Root.IsSelfClosing then
      Exit;

    var Element: TSvgXmlElement;
    while Scanner.ReadElement(Element) do
    begin
      const Name = Element.Name.ToLowerInvariant;

      if Element.IsClosing then
      begin
        if FSkipping and (FDepth <= FSkipUntilDepth) then
          FSkipping := False;

        Dec(FDepth);
        if not FSkipping then
          Pop;

        if SameText(Name, 'svg') then
          Break;

        Continue;
      end;

      Inc(FDepth);

      if FSkipping then
      begin
        if Element.IsSelfClosing then
          Dec(FDepth);
        Continue;
      end;

      if MatchStr(Name, SkippedElements) then
      begin
        if Element.IsSelfClosing then
          Dec(FDepth)
        else
        begin
          FSkipping := True;
          FSkipUntilDepth := FDepth;
        end;
        Continue;
      end;

      if MatchStr(Name, UnsupportedElements) then
        raise ESvgUnsupported.Create(Name);

      Push(Element);
      DrawElement(Element);

      if Element.IsSelfClosing then
      begin
        Pop;
        Dec(FDepth);
      end;
    end;

    Result.Width := FRaster.Width;
    Result.Height := FRaster.Height;
    Result.Pixels := FRaster.Pixels;
  finally
    Scanner.Free;
  end;
end;

function RasterizeNative(const Svg: TBytes; const MaxWidth, MaxHeight: Single;
  out Raster: TMarkdownSvgRaster): Boolean;
begin
  Raster := Default(TMarkdownSvgRaster);

  try
    const Text = TEncoding.UTF8.GetString(Svg);
    const Renderer = TNativeSvgRenderer.Create;
    try
      Raster := Renderer.Render(Text, MaxWidth, MaxHeight);
      Result := (Raster.Width > 0) and (Raster.Height > 0);
    finally
      Renderer.Free;
    end;
  except
    // Anything this engine will not draw goes to the fallback whole, rather
    // than reaching the reader as half a drawing.
    on Exception do
      Result := False;
  end;

  if Result then
    Exit;

  if Assigned(FallbackRasterizer) then
    Result := FallbackRasterizer(Svg, MaxWidth, MaxHeight, Raster);
end;

procedure RegisterNativeSvgRasterizer;
begin
  // The parentheses are load-bearing: assigning to a procedural type without
  // them hands over the function itself rather than what it returns.
  if not Assigned(FallbackRasterizer) then
    FallbackRasterizer := TMarkdownSvgSupport.CurrentRasterizer();

  TMarkdownSvgSupport.RegisterRasterizer(RasterizeNative);
end;

initialization
  RegisterNativeSvgRasterizer;

end.
