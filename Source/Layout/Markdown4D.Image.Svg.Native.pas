unit Markdown4D.Image.Svg.Native;

{$SCOPEDENUMS ON}

// Draws an SVG with the parser, the flattener and the polygon rasterizer of
// this project, so a plain drawing needs no graphics library underneath it.
//
// What it covers: the shape elements, groups, transforms, the viewBox, solid
// fills, gradients, strokes with miter and round joins, opacity, both fill
// rules, clip paths, and text through the glyph seam. What it does not:
// patterns, filters, masks, embedded images and <use>. A document reaching for
// one of those is refused whole rather than drawn wrong, because half a
// drawing is worse than none.

interface

uses
  System.SysUtils,
  Markdown4D.Image.Svg;

// Takes this engine into the viewer's SVG hook.
procedure RegisterNativeSvgRasterizer;

// Draws with this engine alone, reporting False for anything it will not draw
// rather than passing it on. For a host that wants no fallback, and for tests
// that need to know which engine answered.
function TryRasterizeSvgNatively(const Svg: TBytes; const MaxWidth, MaxHeight: Single;
  out Raster: TMarkdownSvgRaster): Boolean;

implementation

uses
  System.StrUtils,
  System.Math,
  System.NetEncoding,
  System.Generics.Collections,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Image.Rasterizer,
  Markdown4D.Image.Filters,
  Markdown4D.Image.Decoder,
  Markdown4D.Image.Glyphs,
  Markdown4D.Image.Svg.Xml,
  Markdown4D.Image.Svg.Path,
  // The Windows font engine, which answers where it can. Everywhere else the
  // FMX layer registers its own, because a cross-platform application is
  // already there.
  Markdown4D.Image.Glyphs.Gdi;

const
  // What a document without a font size of its own is drawn at.
  DefaultFontSize = 16.0;

  // The attribute names read more than once, so a typo cannot make one spelling
  // silently disagree with another.
  IdAttribute = 'id';
  WidthAttribute = 'width';
  HeightAttribute = 'height';
  LeftAttribute = 'x';
  TopAttribute = 'y';
  RadiusXAttribute = 'rx';
  RadiusYAttribute = 'ry';
  CentreXAttribute = 'cx';
  CentreYAttribute = 'cy';
  FilterAttribute = 'filter';
  InputAttribute = 'in';
  ZeroLength = '0';
  FilterElement = 'filter';

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

  TSvgGradient = record
    Kind: TMarkdownPaintKind;
    // The four numbers of a linear gradient, or the centre and radius of a
    // radial one, in the units the definition asked for.
    First: TLayoutPointF;
    Second: TLayoutPointF;
    Radius: Single;
    OnBoundingBox: Boolean;
    Stops: TArray<TMarkdownGradientStop>;
  end;

  TSvgFilterKind = (Blur, Offset, Flood, Composite, Merge);

  TSvgFilterStep = record
    Kind: TSvgFilterKind;
    Input: string;
    SecondInput: string;
    ResultName: string;
    DeviationX: Single;
    DeviationY: Single;
    DeltaX: Single;
    DeltaY: Single;
    Color: TLayoutColor;
    Operation: string;
    MergeInputs: TArray<string>;
  end;

  TSvgFilter = TArray<TSvgFilterStep>;

  TSvgStyle = record
    FillColor: TLayoutColor;
    FillPaintId: string;
    HasFill: Boolean;
    StrokeColor: TLayoutColor;
    StrokePaintId: string;
    HasStroke: Boolean;
    StrokeWidth: Single;
    FillRule: TMarkdownFillRule;
    Opacity: Single;
    FillOpacity: Single;
    StrokeOpacity: Single;
    RoundCaps: Boolean;
    RoundJoins: Boolean;
    FontFamily: string;
    FontSize: Single;
    Bold: Boolean;
    Italic: Boolean;
    Anchor: string;
    class function Initial: TSvgStyle; static;
  end;

  TSvgFrame = record
    Matrix: TSvgMatrix;
    Style: TSvgStyle;
    Mask: TMarkdownClipMask;
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
      // A reference pointing back at what already contains it would go on for
      // ever, so the nesting is bounded.
      MaxFragmentDepth = 8;
      RadiansPerDegree = Pi / 180;
      OpaqueAlpha = $FF000000;
      SkippedElements: array[0..6] of string = ('defs', 'clippath', 'mask', 'marker', FilterElement, 'style',
        'pattern');
      UnsupportedElements: array[0..0] of string = ('foreignobject');
    var
      FRaster: TMarkdownPixelRaster;
      FGradients: TDictionary<string, TSvgGradient>;
      FClipPaths: TDictionary<string, TArray<TSvgSubPath>>;
      FFilters: TDictionary<string, TSvgFilter>;
      // The markup of every element carrying an id, so a reference to it can be
      // drawn again wherever it is pointed at.
      FDefinitions: TDictionary<string, string>;
      FFragmentDepth: Integer;
      // Layers a filtered element is drawn into, and the filter waiting to be
      // applied to each of them when it closes.
      FLayers: TArray<TMarkdownPixelRaster>;
      FPendingFilters: TArray<TSvgFilter>;
      FLayerDepths: TArray<Integer>;
      FStack: TArray<TSvgFrame>;
      FDepth: Integer;
      FSkipUntilDepth: Integer;
      FSkipping: Boolean;
    function Frame: TSvgFrame;
    procedure Push(const Element: TSvgXmlElement);
    procedure Pop;
    procedure DrawElement(const Element: TSvgXmlElement);
    procedure DrawText(const Element: TSvgXmlElement);
    procedure DrawImage(const Element: TSvgXmlElement);
    class function TryDecodeDataUri(const Reference: string; out Data: TBytes): Boolean; static;
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
    class function SubPathsFor(const Element: TSvgXmlElement): TArray<TSvgSubPath>; static;
    class function BoundsOf(const Contours: TArray<TArray<TLayoutPointF>>): TLayoutRectF; static;
    procedure CollectDefinitions(const Svg: string);
    function PaintFor(const PaintId: string; const Color: TLayoutColor; const Opacity: Single;
      const Contours: TArray<TArray<TLayoutPointF>>; const Matrix: TSvgMatrix): TMarkdownPaint;
    function ClipMaskFor(const Reference: string; const Matrix: TSvgMatrix;
      const Parent: TMarkdownClipMask): TMarkdownClipMask;
    procedure DrawFragment(const Svg: string);
    procedure DrawUse(const Element: TSvgXmlElement);
    function MaskFor(const Reference: string; const Parent: TMarkdownClipMask): TMarkdownClipMask;
    function TryTilePaint(const Reference: string; const Contours: TArray<TArray<TLayoutPointF>>;
      const Matrix: TSvgMatrix; out Paint: TMarkdownPaint): Boolean;
    procedure CollectMarkup(const Svg: string);
    class function InnerMarkup(const Markup: string): string; static;
    procedure BeginLayer(const Filter: TSvgFilter);
    procedure EndLayer;
    function ApplyFilter(const Filter: TSvgFilter; const Source: TMarkdownPixelRaster): TMarkdownPixelRaster;
    class function SourceAlphaOf(const Source: TMarkdownPixelRaster): TMarkdownPixelRaster; static;

  public
    constructor Create;
    destructor Destroy; override;
    function Render(const Svg: string; const MaxWidth, MaxHeight: Single): TMarkdownSvgRaster;
  end;

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

// Self first, then Other: a point goes through this matrix and then through
// the one handed in, which is how a shape reaches its group and its group
// reaches the page.
function TSvgMatrix.Multiply(const Other: TSvgMatrix): TSvgMatrix;
begin
  Result.A := A * Other.A + B * Other.C;
  Result.B := A * Other.B + B * Other.D;
  Result.C := C * Other.A + D * Other.C;
  Result.D := C * Other.B + D * Other.D;
  Result.E := E * Other.A + F * Other.C + Other.E;
  Result.F := E * Other.B + F * Other.D + Other.F;
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
  Result.FillPaintId := '';
  Result.HasFill := True;
  Result.StrokeColor := $FF000000;
  Result.StrokePaintId := '';
  Result.HasStroke := False;
  Result.StrokeWidth := 1;
  Result.FillRule := TMarkdownFillRule.NonZero;
  Result.Opacity := 1;
  Result.FillOpacity := 1;
  Result.StrokeOpacity := 1;
  Result.RoundCaps := False;
  Result.RoundJoins := False;
  Result.FontFamily := '';
  Result.FontSize := DefaultFontSize;
  Result.Bold := False;
  Result.Italic := False;
  Result.Anchor := '';
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

function TryParseFraction(const Text: string; out Value: Single): Boolean;
begin
  Value := 0;

  const Trimmed = Text.Trim;
  if Trimmed = '' then
    Exit(False);

  if Trimmed.EndsWith('%') then
  begin
    Result := TryStrToFloat(Copy(Trimmed, 1, Length(Trimmed) - 1).Trim, Value, TFormatSettings.Invariant);
    Value := Value / 100;
    Exit;
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

// "url(#name)" points at a definition elsewhere in the document.
function TryParseReference(const Text: string; out Reference: string): Boolean;
begin
  Reference := '';

  const Trimmed = Text.Trim;
  if not (Trimmed.StartsWith('url(', True) and Trimmed.EndsWith(')')) then
    Exit(False);

  var Inner := Copy(Trimmed, 5, Length(Trimmed) - 5).Trim;
  if Inner.StartsWith('#') then
    Inner := Copy(Inner, 2, MaxInt);

  Reference := Inner.Trim(['''', '"']);
  Result := Reference <> '';
end;

function FirstFamilyName(const Families: string): string;
begin
  for var Family in Families.Split([',']) do
  begin
    const Trimmed = Family.Trim.Trim(['''', '"']);
    if Trimmed = '' then
      Continue;

    if SameText(Trimmed, 'sans-serif') then
      Exit('Segoe UI');
    if SameText(Trimmed, 'serif') then
      Exit('Times New Roman');
    if SameText(Trimmed, 'monospace') then
      Exit('Consolas');

    Exit(Trimmed);
  end;

  Result := 'Segoe UI';
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
      // Rotating about a point means moving that point to the origin first and
      // putting it back afterwards.
      if Length(Values) >= 3 then
        Step := TSvgMatrix.Translation(-Values[1], -Values[2])
          .Multiply(TSvgMatrix.Rotation(Values[0]))
          .Multiply(TSvgMatrix.Translation(Values[1], Values[2]))
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

    // The list reads outermost first, so each transform runs before the ones
    // already collected to its left.
    Result := Step.Multiply(Result);
    Index := Close + 1;
  end;
end;

function ReadStyle(const Element: TSvgXmlElement; const Parent: TSvgStyle): TSvgStyle;
begin
  Result := Parent;

  const Fill = PresentationValue(Element, 'fill');
  if Fill <> '' then
  begin
    var Reference := '';
    if SameText(Fill.Trim, 'none') then
      Result.HasFill := False
    else if TryParseReference(Fill, Reference) then
    begin
      Result.FillPaintId := Reference;
      Result.HasFill := True;
    end
    else if TryParseColor(Fill, Result.FillColor) then
    begin
      Result.FillPaintId := '';
      Result.HasFill := True;
    end
    else if not SameText(Fill.Trim, 'currentcolor') then
      raise ESvgUnsupported.CreateFmt('fill "%s"', [Fill]);
  end;

  const Stroke = PresentationValue(Element, 'stroke');
  if Stroke <> '' then
  begin
    var Reference := '';
    if SameText(Stroke.Trim, 'none') then
      Result.HasStroke := False
    else if TryParseReference(Stroke, Reference) then
    begin
      Result.StrokePaintId := Reference;
      Result.HasStroke := True;
    end
    else if TryParseColor(Stroke, Result.StrokeColor) then
    begin
      Result.StrokePaintId := '';
      Result.HasStroke := True;
    end
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

  // Font properties are inherited, and a document that sets them on a group
  // expects the text inside it to pick them up.
  const Family = PresentationValue(Element, 'font-family');
  if Family <> '' then
    Result.FontFamily := Family;

  if TryParseLength(PresentationValue(Element, 'font-size'), Value) then
    Result.FontSize := Value;

  const Weight = PresentationValue(Element, 'font-weight').Trim;
  if Weight <> '' then
    Result.Bold := SameText(Weight, 'bold') or SameText(Weight, 'bolder') or (Weight = '700') or
      (Weight = '800') or (Weight = '900');

  const Slant = PresentationValue(Element, 'font-style').Trim;
  if Slant <> '' then
    Result.Italic := SameText(Slant, 'italic') or SameText(Slant, 'oblique');

  const Anchor = PresentationValue(Element, 'text-anchor').Trim;
  if Anchor <> '' then
    Result.Anchor := Anchor;
end;

function WithOpacity(const Color: TLayoutColor; const Opacity: Single): TLayoutColor;
begin
  const Alpha = Round((Color shr 24) * EnsureRange(Opacity, 0, 1));

  Result := TLayoutColor((Color and $00FFFFFF) or (Cardinal(Alpha) shl 24));
end;

constructor TNativeSvgRenderer.Create;
begin
  inherited Create;

  FGradients := TDictionary<string, TSvgGradient>.Create;
  FClipPaths := TDictionary<string, TArray<TSvgSubPath>>.Create;
  FFilters := TDictionary<string, TSvgFilter>.Create;
  FDefinitions := TDictionary<string, string>.Create;
end;

destructor TNativeSvgRenderer.Destroy;
begin
  FDefinitions.Free;
  FFilters.Free;
  FClipPaths.Free;
  FGradients.Free;

  inherited Destroy;
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

  var Reference := '';
  if TryParseReference(PresentationValue(Element, 'clip-path'), Reference) then
    Next.Mask := ClipMaskFor(Reference, Next.Matrix, Next.Mask);

  FStack := FStack + [Next];
  try
    if TryParseReference(PresentationValue(Element, 'mask'), Reference) then
      Next.Mask := MaskFor(Reference, Next.Mask);
  finally
    Pop;
  end;

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

  const Paint = PaintFor(Style.FillPaintId, Style.FillColor, Style.Opacity * Style.FillOpacity,
    Contours, Matrix);

  TMarkdownPolygonRasterizer.FillPaintedContoursInto(FRaster, Contours, Paint, Style.FillRule, Frame.Mask);
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

  const Paint = PaintFor(Style.StrokePaintId, Style.StrokeColor, Style.Opacity * Style.StrokeOpacity,
    Contours, Matrix);

  TMarkdownPolygonRasterizer.FillPaintedContoursInto(FRaster, Contours, Paint, TMarkdownFillRule.NonZero,
    Frame.Mask);
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

class function TNativeSvgRenderer.SubPathsFor(const Element: TSvgXmlElement): TArray<TSvgSubPath>;
begin
  Result := nil;

  const Name = Element.Name.ToLowerInvariant;

  var Left: Single;
  var Top: Single;
  var Width: Single;
  var Height: Single;

  if Name = 'path' then
    Exit(TSvgPathParser.Parse(Element.Attribute('d')));

  if Name = 'rect' then
  begin
    if not TryParseLength(Element.Attribute(LeftAttribute, ZeroLength), Left) then
      Left := 0;
    if not TryParseLength(Element.Attribute(TopAttribute, ZeroLength), Top) then
      Top := 0;
    if not (TryParseLength(Element.Attribute(WidthAttribute), Width) and
      TryParseLength(Element.Attribute(HeightAttribute), Height)) then
      Exit;

    var RadiusX: Single := 0;
    var RadiusY: Single := 0;
    TryParseLength(Element.Attribute(RadiusXAttribute, ZeroLength), RadiusX);
    if not TryParseLength(Element.Attribute(RadiusYAttribute, ZeroLength), RadiusY) then
      RadiusY := RadiusX;
    if RadiusY = 0 then
      RadiusY := RadiusX;
    if RadiusX = 0 then
      RadiusX := RadiusY;

    Exit(RectanglePath(Left, Top, Width, Height, RadiusX, RadiusY));
  end;

  if Name = 'circle' then
  begin
    var Radius: Single;
    if not TryParseLength(Element.Attribute('r'), Radius) then
      Exit;
    if not TryParseLength(Element.Attribute(CentreXAttribute, ZeroLength), Left) then
      Left := 0;
    if not TryParseLength(Element.Attribute(CentreYAttribute, ZeroLength), Top) then
      Top := 0;

    Exit(EllipsePath(Left, Top, Radius, Radius));
  end;

  if Name = 'ellipse' then
  begin
    var RadiusX: Single;
    var RadiusY: Single;
    if not (TryParseLength(Element.Attribute(RadiusXAttribute), RadiusX) and
      TryParseLength(Element.Attribute(RadiusYAttribute), RadiusY)) then
      Exit;
    if not TryParseLength(Element.Attribute(CentreXAttribute, ZeroLength), Left) then
      Left := 0;
    if not TryParseLength(Element.Attribute(CentreYAttribute, ZeroLength), Top) then
      Top := 0;

    Exit(EllipsePath(Left, Top, RadiusX, RadiusY));
  end;

  if Name = 'line' then
  begin
    if not (TryParseLength(Element.Attribute('x1', '0'), Left) and
      TryParseLength(Element.Attribute('y1', '0'), Top) and
      TryParseLength(Element.Attribute('x2', '0'), Width) and
      TryParseLength(Element.Attribute('y2', '0'), Height)) then
      Exit;

    var SubPath: TSvgSubPath;
    SubPath.Points := [TLayoutPointF.Create(Left, Top), TLayoutPointF.Create(Width, Height)];
    SubPath.IsClosed := False;

    Result := [SubPath];
    Exit;
  end;

  if Name = 'polyline' then
    Exit(PointsPath(Element.Attribute('points'), False));

  if Name = 'polygon' then
    Exit(PointsPath(Element.Attribute('points'), True));
end;

procedure TNativeSvgRenderer.DrawElement(const Element: TSvgXmlElement);
begin
  if SameText(Element.Name, 'text') then
  begin
    DrawText(Element);
    Exit;
  end;

  if SameText(Element.Name, 'image') then
  begin
    DrawImage(Element);
    Exit;
  end;

  const SubPaths = SubPathsFor(Element);
  if Length(SubPaths) = 0 then
    Exit;

  var Style := Frame.Style;

  // A line or an open polyline has no inside to fill, whatever the style says.
  const Name = Element.Name.ToLowerInvariant;
  if (Name = 'line') or (Name = 'polyline') then
    Style.HasFill := False;

  DrawSubPaths(SubPaths, Style, Frame.Matrix);
end;

// A text element is drawn from its own outlines: the system hands over the
// curves of the letters, and from there it is a fill like any other.
procedure TNativeSvgRenderer.DrawText(const Element: TSvgXmlElement);
begin
  const Content = Element.Text.Trim;
  if Content = '' then
    Exit;

  const Style = Frame.Style;
  const Family = FirstFamilyName(Style.FontFamily);

  var Run: TMarkdownGlyphRun;
  if not TMarkdownGlyphSupport.TryOutline(Family, Style.FontSize, Style.Bold, Style.Italic, Content, Run) then
    raise ESvgUnsupported.Create('text outlines');

  var Left: Single;
  var Baseline: Single;
  if not TryParseLength(Element.Attribute(LeftAttribute, ZeroLength), Left) then
    Left := 0;
  if not TryParseLength(Element.Attribute(TopAttribute, ZeroLength), Baseline) then
    Baseline := 0;

  // A run asked to occupy a given width is stretched to it, which is how a
  // badge keeps its text inside its own box whatever font is installed.
  var Stretch: Single := 1;
  var Wanted: Single;
  if TryParseLength(Element.Attribute('textLength'), Wanted) and (Run.Advance > 0) then
    Stretch := Wanted / Run.Advance;

  const Width = Run.Advance * Stretch;
  const Anchor = Style.Anchor;
  if SameText(Anchor, 'middle') then
    Left := Left - Width / 2
  else if SameText(Anchor, 'end') then
    Left := Left - Width;

  const Placement = TSvgMatrix.Scaling(Stretch, 1)
    .Multiply(TSvgMatrix.Translation(Left, Baseline))
    .Multiply(Frame.Matrix);


  var Contours: TArray<TArray<TLayoutPointF>> := nil;
  for var Contour in Run.Contours do
  begin
    Contours := Contours + [Transformed(Contour, Placement)];
  end;

  if Length(Contours) = 0 then
    Exit;

  const Paint = PaintFor(Style.FillPaintId, Style.FillColor, Style.Opacity * Style.FillOpacity,
    Contours, Placement);

  TMarkdownPolygonRasterizer.FillPaintedContoursInto(FRaster, Contours, Paint, TMarkdownFillRule.NonZero,
    Frame.Mask);
end;

// An image is carried inside the document as a data URI. Anything else points
// outside it, which is the host's business rather than this engine's.
class function TNativeSvgRenderer.TryDecodeDataUri(const Reference: string; out Data: TBytes): Boolean;
begin
  Data := nil;

  const Trimmed = Reference.Trim;
  if not Trimmed.StartsWith('data:', True) then
    Exit(False);

  const Separator = Pos(',', Trimmed);
  if Separator = 0 then
    Exit(False);

  const Header = Copy(Trimmed, 1, Separator - 1);
  if not Header.ToLowerInvariant.Contains('base64') then
    Exit(False);

  try
    Data := TNetEncoding.Base64.DecodeStringToBytes(Copy(Trimmed, Separator + 1, MaxInt));
    Result := Length(Data) > 0;
  except
    on Exception do
      Result := False;
  end;
end;

// Walks the pixels the image lands on and asks, for each of them, which pixel
// of the image it came from. That way a rotated or scaled image needs no
// special case: the matrix is simply read backwards.
procedure TNativeSvgRenderer.DrawImage(const Element: TSvgXmlElement);
begin
  var Reference := Element.Attribute('href');
  if Reference = '' then
    Reference := Element.Attribute('xlink:href');

  var Data: TBytes;
  if not TryDecodeDataUri(Reference, Data) then
    raise ESvgUnsupported.Create('image source');

  var Source: TMarkdownPixelRaster;
  if not TMarkdownImageDecoding.TryDecode(Data, Source) then
    raise ESvgUnsupported.Create('image format');

  var Left: Single;
  var Top: Single;
  var Width: Single;
  var Height: Single;
  if not TryParseLength(Element.Attribute(LeftAttribute, ZeroLength), Left) then
    Left := 0;
  if not TryParseLength(Element.Attribute(TopAttribute, ZeroLength), Top) then
    Top := 0;
  if not TryParseLength(Element.Attribute(WidthAttribute), Width) then
    Width := Source.Width;
  if not TryParseLength(Element.Attribute(HeightAttribute), Height) then
    Height := Source.Height;

  if (Width <= 0) or (Height <= 0) then
    Exit;

  const Style = Frame.Style;
  const Placement = TSvgMatrix.Scaling(Width / Source.Width, Height / Source.Height)
    .Multiply(TSvgMatrix.Translation(Left, Top))
    .Multiply(Frame.Matrix);

  const Determinant = Placement.A * Placement.D - Placement.B * Placement.C;
  if Abs(Determinant) < 0.000001 then
    Exit;

  var Backwards := Default(TSvgMatrix);
  Backwards.A := Placement.D / Determinant;
  Backwards.B := -Placement.B / Determinant;
  Backwards.C := -Placement.C / Determinant;
  Backwards.D := Placement.A / Determinant;
  Backwards.E := (Placement.C * Placement.F - Placement.D * Placement.E) / Determinant;
  Backwards.F := (Placement.B * Placement.E - Placement.A * Placement.F) / Determinant;

  const Corners: TArray<TLayoutPointF> = [Placement.Apply(TLayoutPointF.Create(0, 0)),
    Placement.Apply(TLayoutPointF.Create(Source.Width, 0)),
    Placement.Apply(TLayoutPointF.Create(Source.Width, Source.Height)),
    Placement.Apply(TLayoutPointF.Create(0, Source.Height))];

  const Bounds = BoundsOf([Corners]);
  const FirstColumn = Max(0, Floor(Bounds.Left));
  const LastColumn = Min(FRaster.Width - 1, Ceil(Bounds.Right));
  const FirstRow = Max(0, Floor(Bounds.Top));
  const LastRow = Min(FRaster.Height - 1, Ceil(Bounds.Bottom));

  const Opacity = EnsureRange(Style.Opacity, 0, 1);
  const HasMask = Length(Frame.Mask) = FRaster.Width * FRaster.Height;

  for var Row := FirstRow to LastRow do
  begin
    for var Column := FirstColumn to LastColumn do
    begin
      const Origin = Backwards.Apply(TLayoutPointF.Create(Column + 0.5, Row + 0.5));
      const SourceColumn = Trunc(Origin.X);
      const SourceRow = Trunc(Origin.Y);

      const Outside = (Origin.X < 0) or (Origin.Y < 0) or (SourceColumn >= Source.Width) or
        (SourceRow >= Source.Height);
      if Outside then
        Continue;

      const From = (SourceRow * Source.Width + SourceColumn) * 4;
      var Weight := Opacity;
      if HasMask then
        Weight := Weight * Frame.Mask[Row * FRaster.Width + Column] / 255;

      const Arriving = Source.Pixels[From + 3] / 255 * Weight;
      if Arriving <= 0 then
        Continue;

      const Onto = (Row * FRaster.Width + Column) * 4;
      const Remaining = 1 - Arriving;
      for var Channel := 0 to 3 do
      begin
        FRaster.Pixels[Onto + Channel] :=
          Round(Source.Pixels[From + Channel] * Weight + FRaster.Pixels[Onto + Channel] * Remaining);
      end;
    end;
  end;
end;

// The box a shape occupies, which is what a gradient in bounding box units is
// measured against.
class function TNativeSvgRenderer.BoundsOf(const Contours: TArray<TArray<TLayoutPointF>>): TLayoutRectF;
begin
  Result := TLayoutRectF.Create(0, 0, 0, 0);

  var Started := False;
  for var Contour in Contours do
  begin
    for var Point in Contour do
    begin
      if not Started then
      begin
        Result := TLayoutRectF.Create(Point.X, Point.Y, Point.X, Point.Y);
        Started := True;
        Continue;
      end;

      Result.Left := Min(Result.Left, Point.X);
      Result.Top := Min(Result.Top, Point.Y);
      Result.Right := Max(Result.Right, Point.X);
      Result.Bottom := Max(Result.Bottom, Point.Y);
    end;
  end;
end;

// A pattern is a small drawing repeated over the shape. It is rendered once at
// the size it occupies on the page, and the rasterizer repeats it from there.
function TNativeSvgRenderer.TryTilePaint(const Reference: string;
  const Contours: TArray<TArray<TLayoutPointF>>; const Matrix: TSvgMatrix; out Paint: TMarkdownPaint): Boolean;
begin
  Paint := Default(TMarkdownPaint);

  var Definition := '';
  if not FDefinitions.TryGetValue(Reference, Definition) then
    Exit(False);

  const Scanner = TSvgXmlScanner.Create(Definition);
  var Wrapper: TSvgXmlElement;
  try
    if not Scanner.ReadElement(Wrapper) then
      Exit(False);
  finally
    Scanner.Free;
  end;

  if not SameText(Wrapper.Name, 'pattern') then
    Exit(False);

  var Left: Single := 0;
  var Top: Single := 0;
  var Width: Single := 0;
  var Height: Single := 0;
  TryParseFraction(Wrapper.Attribute(LeftAttribute, ZeroLength), Left);
  TryParseFraction(Wrapper.Attribute(TopAttribute, ZeroLength), Top);
  if not (TryParseFraction(Wrapper.Attribute(WidthAttribute), Width) and
    TryParseFraction(Wrapper.Attribute(HeightAttribute), Height)) then
    Exit(False);

  const OnBoundingBox = not SameText(Wrapper.Attribute('patternUnits', 'objectBoundingBox'), 'userSpaceOnUse');
  const Bounds = BoundsOf(Contours);

  var TileWidth: Single;
  var TileHeight: Single;
  var OriginX: Single;
  var OriginY: Single;

  if OnBoundingBox then
  begin
    TileWidth := Width * (Bounds.Right - Bounds.Left);
    TileHeight := Height * (Bounds.Bottom - Bounds.Top);
    OriginX := Bounds.Left + Left * (Bounds.Right - Bounds.Left);
    OriginY := Bounds.Top + Top * (Bounds.Bottom - Bounds.Top);
  end
  else
  begin
    const Scale = Matrix.AverageScale;
    TileWidth := Width * Scale;
    TileHeight := Height * Scale;
    const Placed = Matrix.Apply(TLayoutPointF.Create(Left, Top));
    OriginX := Placed.X;
    OriginY := Placed.Y;
  end;

  const PixelWidth = Round(TileWidth);
  const PixelHeight = Round(TileHeight);
  if (PixelWidth <= 0) or (PixelHeight <= 0) then
    Exit(False);

  const Markup = InnerMarkup(Definition);
  if Markup = '' then
    Exit(False);

  const Beneath = FRaster;
  FRaster := TMarkdownPixelRaster.Create(PixelWidth, PixelHeight);
  var Tile: TMarkdownPixelRaster;
  try
    var Cell := Default(TSvgFrame);
    Cell.Style := Frame.Style;
    Cell.Style.FillPaintId := '';
    Cell.Matrix := TSvgMatrix.Scaling(PixelWidth / Width, PixelHeight / Height);
    FStack := FStack + [Cell];
    try
      DrawFragment(Markup);
    finally
      Pop;
    end;
  finally
    Tile := FRaster;
    FRaster := Beneath;
  end;

  Paint := TMarkdownPaint.Tiled(TLayoutPointF.Create(OriginX, OriginY), PixelWidth, PixelHeight, Tile.Pixels);
  Result := True;
end;

function TNativeSvgRenderer.PaintFor(const PaintId: string; const Color: TLayoutColor; const Opacity: Single;
  const Contours: TArray<TArray<TLayoutPointF>>; const Matrix: TSvgMatrix): TMarkdownPaint;
begin
  if PaintId <> '' then
  begin
    var Tile: TMarkdownPaint;
    if TryTilePaint(PaintId, Contours, Matrix, Tile) then
      Exit(Tile);
  end;

  var Gradient: TSvgGradient;
  if (PaintId = '') or (not FGradients.TryGetValue(PaintId, Gradient)) then
    Exit(TMarkdownPaint.SolidColor(WithOpacity(Color, Opacity)));

  var Stops := Gradient.Stops;
  for var Index := 0 to High(Stops) do
  begin
    Stops[Index].Color := WithOpacity(Stops[Index].Color, Opacity);
  end;

  // In bounding box units the numbers are fractions of the shape itself, so
  // they only become positions once the shape is known.
  var First := Gradient.First;
  var Second := Gradient.Second;
  var Radius := Gradient.Radius;

  if Gradient.OnBoundingBox then
  begin
    const Bounds = BoundsOf(Contours);
    const Width = Bounds.Right - Bounds.Left;
    const Height = Bounds.Bottom - Bounds.Top;

    First := TLayoutPointF.Create(Bounds.Left + First.X * Width, Bounds.Top + First.Y * Height);
    Second := TLayoutPointF.Create(Bounds.Left + Second.X * Width, Bounds.Top + Second.Y * Height);
    Radius := Radius * Max(Width, Height);
  end
  else
  begin
    First := Matrix.Apply(First);
    Second := Matrix.Apply(Second);
    Radius := Radius * Matrix.AverageScale;
  end;

  if Gradient.Kind = TMarkdownPaintKind.RadialGradient then
    Exit(TMarkdownPaint.Radial(First, Radius, Stops));

  Result := TMarkdownPaint.Linear(First, Second, Stops);
end;

function TNativeSvgRenderer.ClipMaskFor(const Reference: string; const Matrix: TSvgMatrix;
  const Parent: TMarkdownClipMask): TMarkdownClipMask;
begin
  Result := Parent;

  var SubPaths: TArray<TSvgSubPath>;
  if not FClipPaths.TryGetValue(Reference, SubPaths) then
    Exit;

  var Contours: TArray<TArray<TLayoutPointF>> := nil;
  for var SubPath in SubPaths do
  begin
    if Length(SubPath.Points) >= 3 then
      Contours := Contours + [Transformed(SubPath.Points, Matrix)];
  end;

  if Length(Contours) = 0 then
    Exit;

  const Coverage = TMarkdownPolygonRasterizer.CoverageOf(Contours, FRaster.Width, FRaster.Height,
    TMarkdownFillRule.NonZero);

  if Length(Parent) <> Length(Coverage) then
    Exit(Coverage);

  // Two clips in force at once hold a shape to what they have in common.
  var Combined: TMarkdownClipMask;
  SetLength(Combined, Length(Coverage));
  for var Index := 0 to High(Combined) do
  begin
    Combined[Index] := Parent[Index] * Coverage[Index] div 255;
  end;

  Result := Combined;
end;

// Walks a piece of markup and draws it, starting from whatever frame is on the
// stack. The document body is one such piece, and so is anything a reference
// points at.
procedure TNativeSvgRenderer.DrawFragment(const Svg: string);
begin
  if FFragmentDepth >= MaxFragmentDepth then
    raise ESvgUnsupported.Create('nested references');

  Inc(FFragmentDepth);
  const Scanner = TSvgXmlScanner.Create(Svg);
  try
    const BaseDepth = FDepth;
    var Element: TSvgXmlElement;
    while Scanner.ReadElement(Element) do
    begin
      const Name = Element.Name.ToLowerInvariant;

      if Element.IsClosing then
      begin
        Dec(FDepth);

        // An element that was skipped never pushed a frame, so its closing tag
        // must not pop one either: doing so would unwind the styles of
        // everything around it.
        if FSkipping then
        begin
          if FDepth < FSkipUntilDepth then
            FSkipping := False;
        end
        else
        begin
          const ClosesLayer = (Length(FLayerDepths) > 0) and (FDepth < FLayerDepths[High(FLayerDepths)]);
          if ClosesLayer then
            EndLayer;

          Pop;
        end;

        if SameText(Name, 'svg') or (FDepth < BaseDepth) then
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

      if Name = 'use' then
      begin
        Push(Element);
        DrawUse(Element);
        if Element.IsSelfClosing then
        begin
          Pop;
          Dec(FDepth);
        end;
        Continue;
      end;

      if MatchStr(Name, UnsupportedElements) then
        raise ESvgUnsupported.Create(Name);

      // A filtered element is drawn on a layer of its own, which the filter is
      // applied to when the element closes.
      var Reference := '';
      var Filter: TSvgFilter := nil;
      const IsFiltered = TryParseReference(PresentationValue(Element, FilterAttribute), Reference) and
        FFilters.TryGetValue(Reference, Filter);
      if IsFiltered then
        BeginLayer(Filter);

      Push(Element);
      DrawElement(Element);

      if Element.IsSelfClosing then
      begin
        if IsFiltered then
          EndLayer;

        Pop;
        Dec(FDepth);
      end;
    end;
  finally
    Scanner.Free;
    Dec(FFragmentDepth);
  end;
end;

// A use element draws what it points at, moved to where it was put.
procedure TNativeSvgRenderer.DrawUse(const Element: TSvgXmlElement);
begin
  var Reference := Element.Attribute('href');
  if Reference = '' then
    Reference := Element.Attribute('xlink:href');

  Reference := Reference.Trim;
  if Reference.StartsWith('#') then
    Reference := Copy(Reference, 2, MaxInt);

  var Markup := '';
  if (Reference = '') or (not FDefinitions.TryGetValue(Reference, Markup)) then
    Exit;

  var Left: Single;
  var Top: Single;
  if not TryParseLength(Element.Attribute(LeftAttribute, ZeroLength), Left) then
    Left := 0;
  if not TryParseLength(Element.Attribute(TopAttribute, ZeroLength), Top) then
    Top := 0;

  var Moved := Frame;
  Moved.Matrix := TSvgMatrix.Translation(Left, Top).Multiply(Moved.Matrix);
  FStack := FStack + [Moved];
  try
    DrawFragment(Markup);
  finally
    Pop;
  end;
end;

// What a definition holds, without the element wrapping it. A mask or a
// pattern is drawn from its contents; the wrapper itself is not a shape and is
// stepped over by the drawing loop.
class function TNativeSvgRenderer.InnerMarkup(const Markup: string): string;
begin
  const Opening = Pos('>', Markup);
  const Closing = Markup.LastIndexOf('<') + 1;

  if (Opening = 0) or (Closing <= Opening) then
    Exit('');

  Result := Copy(Markup, Opening + 1, Closing - Opening - 1);
end;

// A mask is a drawing of its own: how bright it is at each pixel decides how
// much of what it masks survives there.
function TNativeSvgRenderer.MaskFor(const Reference: string; const Parent: TMarkdownClipMask): TMarkdownClipMask;
begin
  Result := Parent;

  var Definition := '';
  if not FDefinitions.TryGetValue(Reference, Definition) then
    Exit;

  const Markup = InnerMarkup(Definition);
  if Markup = '' then
    Exit;

  const Beneath = FRaster;
  FRaster := TMarkdownPixelRaster.Create(Beneath.Width, Beneath.Height);
  var Painted: TMarkdownPixelRaster;
  try
    var Frameless := Frame;
    Frameless.Mask := nil;
    FStack := FStack + [Frameless];
    try
      DrawFragment(Markup);
    finally
      Pop;
    end;
  finally
    Painted := FRaster;
    FRaster := Beneath;
  end;

  const Coverage = TMarkdownRasterFilters.LuminanceMask(Painted);

  if Length(Parent) <> Length(Coverage) then
    Exit(Coverage);

  var Combined: TMarkdownClipMask;
  SetLength(Combined, Length(Coverage));
  for var Index := 0 to High(Combined) do
  begin
    Combined[Index] := Parent[Index] * Coverage[Index] div 255;
  end;

  Result := Combined;
end;

// Every element carrying an id is remembered whole, because a reference to it
// may appear before or after the definition itself.
procedure TNativeSvgRenderer.CollectMarkup(const Svg: string);
begin
  const Scanner = TSvgXmlScanner.Create(Svg);
  try
    var Pending: TArray<string> := nil;
    var Starts: TArray<Integer> := nil;
    var Depths: TArray<Integer> := nil;
    var Depth := 0;

    var Element: TSvgXmlElement;
    while Scanner.ReadElement(Element) do
    begin
      if Element.IsClosing then
      begin
        Dec(Depth);

        while (Length(Depths) > 0) and (Depths[High(Depths)] > Depth) do
        begin
          FDefinitions.AddOrSetValue(Pending[High(Pending)],
            Copy(Svg, Starts[High(Starts)], Element.Stop - Starts[High(Starts)]));

          SetLength(Pending, Length(Pending) - 1);
          SetLength(Starts, Length(Starts) - 1);
          SetLength(Depths, Length(Depths) - 1);
        end;

        Continue;
      end;

      Inc(Depth);

      const Identifier = Element.Attribute(IdAttribute);
      if Identifier <> '' then
      begin
        if Element.IsSelfClosing then
          FDefinitions.AddOrSetValue(Identifier, Copy(Svg, Element.Start, Element.Stop - Element.Start))
        else
        begin
          Pending := Pending + [Identifier];
          Starts := Starts + [Element.Start];
          Depths := Depths + [Depth];
        end;
      end;

      if Element.IsSelfClosing then
        Dec(Depth);
    end;
  finally
    Scanner.Free;
  end;
end;

// A filtered element is drawn on a layer of its own, so the filter has
// something to work on that holds nothing but that element.
procedure TNativeSvgRenderer.BeginLayer(const Filter: TSvgFilter);
begin
  FLayers := FLayers + [FRaster];
  FPendingFilters := FPendingFilters + [Filter];
  FLayerDepths := FLayerDepths + [FDepth];

  FRaster := TMarkdownPixelRaster.Create(FRaster.Width, FRaster.Height);
end;

procedure TNativeSvgRenderer.EndLayer;
begin
  if Length(FLayers) = 0 then
    Exit;

  const Filtered = ApplyFilter(FPendingFilters[High(FPendingFilters)], FRaster);
  const Beneath = FLayers[High(FLayers)];

  SetLength(FLayers, Length(FLayers) - 1);
  SetLength(FPendingFilters, Length(FPendingFilters) - 1);
  SetLength(FLayerDepths, Length(FLayerDepths) - 1);

  FRaster := TMarkdownRasterFilters.Over(Filtered, Beneath);
end;

// The shape of the source without its colours, which is what a drop shadow is
// built from.
class function TNativeSvgRenderer.SourceAlphaOf(const Source: TMarkdownPixelRaster): TMarkdownPixelRaster;
begin
  Result := TMarkdownPixelRaster.Create(Source.Width, Source.Height);

  for var Index := 0 to High(Result.Pixels) div 4 do
  begin
    Result.Pixels[Index * 4 + 3] := Source.Pixels[Index * 4 + 3];
  end;
end;

function TNativeSvgRenderer.ApplyFilter(const Filter: TSvgFilter;
  const Source: TMarkdownPixelRaster): TMarkdownPixelRaster;
begin
  Result := Source;
  if Length(Filter) = 0 then
    Exit;

  const Named = TDictionary<string, TMarkdownPixelRaster>.Create;
  try
    Named.AddOrSetValue('SourceGraphic', Source);
    Named.AddOrSetValue('SourceAlpha', SourceAlphaOf(Source));

    var Current := Source;

    for var Step in Filter do
    begin
      var Input := Current;
      if (Step.Input <> '') and (not Named.TryGetValue(Step.Input, Input)) then
        Input := Current;

      case Step.Kind of
        TSvgFilterKind.Blur:
          Current := TMarkdownRasterFilters.Blurred(Input, Step.DeviationX, Step.DeviationY);
        TSvgFilterKind.Offset:
          Current := TMarkdownRasterFilters.Offset(Input, Round(Step.DeltaX), Round(Step.DeltaY));
        TSvgFilterKind.Flood:
          Current := TMarkdownRasterFilters.Flooded(Source.Width, Source.Height, Step.Color);
        TSvgFilterKind.Composite:
          begin
            var Second := Source;
            if (Step.SecondInput <> '') and (not Named.TryGetValue(Step.SecondInput, Second)) then
              Second := Source;

            if SameText(Step.Operation, 'in') then
              Current := TMarkdownRasterFilters.InsideOf(Input, Second)
            else
              Current := TMarkdownRasterFilters.Over(Input, Second);
          end;
        TSvgFilterKind.Merge:
          begin
            var Merged := TMarkdownPixelRaster.Create(Source.Width, Source.Height);
            for var Name in Step.MergeInputs do
            begin
              var Layer := Source;
              if Named.TryGetValue(Name, Layer) or (Name = '') then
                Merged := TMarkdownRasterFilters.Over(Layer, Merged);
            end;

            Current := Merged;
          end;
      else
      end;

      if Step.ResultName <> '' then
        Named.AddOrSetValue(Step.ResultName, Current);
    end;

    Result := Current;
  finally
    Named.Free;
  end;
end;

// Definitions are read first, because a shape may point at a gradient, a clip
// path or a filter written further down the document.
procedure TNativeSvgRenderer.CollectDefinitions(const Svg: string);
begin
  const Scanner = TSvgXmlScanner.Create(Svg);
  try
    var Gradient := Default(TSvgGradient);
    var GradientId := '';
    var ClipId := '';
    var ClipPaths: TArray<TSvgSubPath> := nil;
    var FilterId := '';
    var Filter: TSvgFilter := nil;
    var MergeInputs: TArray<string> := nil;
    var InMerge := False;

    var Element: TSvgXmlElement;
    while Scanner.ReadElement(Element) do
    begin
      const Name = Element.Name.ToLowerInvariant;

      if Element.IsClosing then
      begin
        if (Name = 'lineargradient') or (Name = 'radialgradient') then
        begin
          if (GradientId <> '') and (Length(Gradient.Stops) > 0) then
            FGradients.AddOrSetValue(GradientId, Gradient);
          GradientId := '';
        end
        else if Name = 'clippath' then
        begin
          if (ClipId <> '') and (Length(ClipPaths) > 0) then
            FClipPaths.AddOrSetValue(ClipId, ClipPaths);
          ClipId := '';
          ClipPaths := nil;
        end
        else if Name = FilterElement then
        begin
          if (FilterId <> '') and (Length(Filter) > 0) then
            FFilters.AddOrSetValue(FilterId, Filter);
          FilterId := '';
          Filter := nil;
        end
        else if Name = 'femerge' then
        begin
          var Step := Default(TSvgFilterStep);
          Step.Kind := TSvgFilterKind.Merge;
          Step.MergeInputs := MergeInputs;
          Filter := Filter + [Step];
          MergeInputs := nil;
          InMerge := False;
        end;

        Continue;
      end;

      if (Name = 'lineargradient') or (Name = 'radialgradient') then
      begin
        Gradient := Default(TSvgGradient);
        GradientId := Element.Attribute(IdAttribute);
        Gradient.OnBoundingBox := not SameText(Element.Attribute('gradientUnits', 'objectBoundingBox'),
          'userSpaceOnUse');

        var Value: Single;
        if Name = 'lineargradient' then
        begin
          Gradient.Kind := TMarkdownPaintKind.LinearGradient;
          Gradient.First := TLayoutPointF.Create(0, 0);
          Gradient.Second := TLayoutPointF.Create(1, 0);
          if TryParseFraction(Element.Attribute('x1'), Value) then
            Gradient.First.X := Value;
          if TryParseFraction(Element.Attribute('y1'), Value) then
            Gradient.First.Y := Value;
          if TryParseFraction(Element.Attribute('x2'), Value) then
            Gradient.Second.X := Value;
          if TryParseFraction(Element.Attribute('y2'), Value) then
            Gradient.Second.Y := Value;
        end
        else
        begin
          Gradient.Kind := TMarkdownPaintKind.RadialGradient;
          Gradient.First := TLayoutPointF.Create(0.5, 0.5);
          Gradient.Radius := 0.5;
          if TryParseFraction(Element.Attribute(CentreXAttribute), Value) then
            Gradient.First.X := Value;
          if TryParseFraction(Element.Attribute(CentreYAttribute), Value) then
            Gradient.First.Y := Value;
          if TryParseFraction(Element.Attribute('r'), Value) then
            Gradient.Radius := Value;
        end;

        Continue;
      end;

      if (Name = 'stop') and (GradientId <> '') then
      begin
        var Stop := Default(TMarkdownGradientStop);
        var Value: Single;
        if TryParseFraction(PresentationValue(Element, 'offset'), Value) then
          Stop.Offset := EnsureRange(Value, 0, 1);

        var Color: TLayoutColor := $FF000000;
        TryParseColor(PresentationValue(Element, 'stop-color'), Color);

        var Alpha: Single := 1;
        if TryParseLength(PresentationValue(Element, 'stop-opacity'), Alpha) then
          Color := WithOpacity(Color, EnsureRange(Alpha, 0, 1));

        Stop.Color := Color;
        Gradient.Stops := Gradient.Stops + [Stop];
        Continue;
      end;

      if Name = 'clippath' then
      begin
        ClipId := Element.Attribute(IdAttribute);
        ClipPaths := nil;
        Continue;
      end;

      if Name = FilterElement then
      begin
        FilterId := Element.Attribute(IdAttribute);
        Filter := nil;
        Continue;
      end;

      if FilterId <> '' then
      begin
        if Name = 'femerge' then
        begin
          InMerge := True;
          MergeInputs := nil;
          Continue;
        end;

        if (Name = 'femergenode') and InMerge then
        begin
          MergeInputs := MergeInputs + [Element.Attribute(InputAttribute)];
          Continue;
        end;

        var Step := Default(TSvgFilterStep);
        Step.Input := Element.Attribute(InputAttribute);
        Step.SecondInput := Element.Attribute('in2');
        Step.ResultName := Element.Attribute('result');

        var Value: Single;

        if Name = 'fegaussianblur' then
        begin
          Step.Kind := TSvgFilterKind.Blur;

          var Deviations := TSvgNumberReader.Create(Element.Attribute('stdDeviation', '0'));
          Step.DeviationX := Deviations.ReadNumber;
          if Deviations.TryReadNumber(Value) then
            Step.DeviationY := Value
          else
            Step.DeviationY := Step.DeviationX;
        end
        else if Name = 'feoffset' then
        begin
          Step.Kind := TSvgFilterKind.Offset;
          if TryParseLength(Element.Attribute('dx', '0'), Value) then
            Step.DeltaX := Value;
          if TryParseLength(Element.Attribute('dy', '0'), Value) then
            Step.DeltaY := Value;
        end
        else if Name = 'feflood' then
        begin
          Step.Kind := TSvgFilterKind.Flood;
          Step.Color := $FF000000;
          TryParseColor(PresentationValue(Element, 'flood-color'), Step.Color);
          if TryParseLength(PresentationValue(Element, 'flood-opacity'), Value) then
            Step.Color := WithOpacity(Step.Color, EnsureRange(Value, 0, 1));
        end
        else if Name = 'fecomposite' then
        begin
          Step.Kind := TSvgFilterKind.Composite;
          Step.Operation := Element.Attribute('operator', 'over');
        end
        else
          // A primitive this engine has no answer for would quietly change the
          // result, so the whole document goes back rather than half a filter.
          raise ESvgUnsupported.Create(Name);

        Filter := Filter + [Step];
        Continue;
      end;

      if ClipId <> '' then
        ClipPaths := ClipPaths + SubPathsFor(Element);
    end;
  finally
    Scanner.Free;
  end;
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
    TryParseLength(Root.Attribute(WidthAttribute), DeclaredWidth);
    TryParseLength(Root.Attribute(HeightAttribute), DeclaredHeight);

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
    CollectDefinitions(Svg);
    CollectMarkup(Svg);

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

    DrawFragment(Copy(Svg, Root.Stop, MaxInt));
    Result.Width := FRaster.Width;
    Result.Height := FRaster.Height;
    Result.Pixels := FRaster.Pixels;
  finally
    Scanner.Free;
  end;
end;

function TryRasterizeSvgNatively(const Svg: TBytes; const MaxWidth, MaxHeight: Single;
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
end;

procedure RegisterNativeSvgRasterizer;
begin
  TMarkdownSvgSupport.RegisterRasterizer(TryRasterizeSvgNatively);
end;

initialization
  RegisterNativeSvgRasterizer;

end.
