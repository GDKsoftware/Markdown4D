unit Markdown4D.Math.Layout;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Math.Syntax;

type
  TMathLayoutOptions = record
    // Family and size of the formula font. Bold and italic are decided per
    // symbol by the layouter, so the flags on this font are ignored.
    Font: TMarkdownFontStyle;
    TextColor: TLayoutColor;
    // Unknown commands are drawn by name in this colour so the author sees
    // what did not resolve.
    ErrorColor: TLayoutColor;
    // Display style sets fractions and limits at full size with the limits
    // above and below; text style is the compact form for inline formulas.
    IsDisplay: Boolean;
    class function Create(const Font: TMarkdownFontStyle; const TextColor, ErrorColor: TLayoutColor;
      const IsDisplay: Boolean): TMathLayoutOptions; static;
  end;

  // A laid-out formula: its extent around the baseline, and the ability to
  // draw itself at any position. Every measure is in the units of the
  // measurer, which is pixels for the viewers.
  IMathLayout = interface
    ['{7C3D1A58-9E24-4B6F-8A07-2F5B6D9C1E43}']
    function GetWidth: Single;
    function GetAscent: Single;
    function GetDescent: Single;
    procedure Draw(const Canvas: IExtensionCanvas; const Left, Baseline: Single);
    property Width: Single read GetWidth;
    property Ascent: Single read GetAscent;
    property Descent: Single read GetDescent;
  end;

  TMathLayouter = class
  public
    class function Layout(const Source: string; const Options: TMathLayoutOptions;
      const Measurer: ITextMeasurer): IMathLayout;
    class function LayoutNode(const Node: IMathNode; const Options: TMathLayoutOptions;
      const Measurer: ITextMeasurer): IMathLayout;
  end;

implementation

uses
  System.Math,
  System.Character;

type
  TMathStyle = (Display, Text, Script, ScriptScript);

  TMathBoxKind = (Group, Glyph, Rule, Polygon);

  TMathBox = class;

  TMathPlacement = record
    Box: TMathBox;
    Handle: IMathLayout;
    DX: Single;
    DY: Single;
  end;

  // The box model of the layout: a glyph, a filled rule, a filled polygon,
  // or a group placing other boxes relative to its own origin. The origin of
  // every box is its left edge on the baseline; y grows downward, so the
  // ascent lies above at negative y.
  TMathBox = class(TInterfacedObject, IMathLayout)
  private
    FKind: TMathBoxKind;
    FWidth: Single;
    FAscent: Single;
    FDescent: Single;
    FText: string;
    FFont: TMarkdownFontStyle;
    FColor: TLayoutColor;
    FFontBaseline: Single;
    FRule: TLayoutRectF;
    FPoints: TArray<TLayoutPointF>;
    FChildren: TList<TMathPlacement>;
    procedure DrawGroup(const Canvas: IExtensionCanvas; const Left, Baseline: Single);
    procedure DrawPolygon(const Canvas: IExtensionCanvas; const Left, Baseline: Single);

  public
    constructor Create(const Kind: TMathBoxKind);
    destructor Destroy; override;
    function GetWidth: Single;
    function GetAscent: Single;
    function GetDescent: Single;
    procedure Draw(const Canvas: IExtensionCanvas; const Left, Baseline: Single);
    procedure Place(const Child: TMathBox; const DX, DY: Single);
    // Grows the group so the placed child fits; the group's extent is never
    // smaller than its parts.
    procedure Enclose(const Child: TMathBox; const DX, DY: Single);
    property Width: Single read FWidth write FWidth;
    property Ascent: Single read FAscent write FAscent;
    property Descent: Single read FDescent write FDescent;
    property Text: string read FText write FText;
    property Font: TMarkdownFontStyle read FFont write FFont;
    property Color: TLayoutColor read FColor write FColor;
    property FontBaseline: Single read FFontBaseline write FFontBaseline;
    property Rule: TLayoutRectF read FRule write FRule;
    property Points: TArray<TLayoutPointF> read FPoints write FPoints;
  end;

  TGlyphExtent = record
    AscentEm: Single;
    DescentEm: Single;
    class function Create(const AscentEm, DescentEm: Single): TGlyphExtent; static;
  end;

  TMathGlyphMapper = class
  private
    class function MapLetter(const Letter: Char; const UpperBase, LowerBase: Integer): Integer; static;
    class function MapDigit(const Digit: Char; const DigitBase: Integer): Integer; static;
    class function DoubleStruck(const Value: Char): Integer; static;
    class function ScriptLetter(const Value: Char): Integer; static;
    class function Fraktur(const Value: Char): Integer; static;
    class function SansSerif(const Value: Char): Integer; static;
    class function Monospace(const Value: Char): Integer; static;

  public
    // Letters and digits move to the Unicode mathematical alphanumeric block
    // of the variant; everything else stays. Bold and italic are font
    // attributes, so they pass through untouched.
    class function Apply(const Text: string; const Variant: TMathFontVariant): string;
  end;

  TMathBoxBuilder = class
  private
    const
      ScriptScale = 0.7;
      ScriptScriptScale = 0.5;
      LargeOperatorScale = 1.4;
      AxisHeightEm = 0.25;
      XHeightEm = 0.45;
      RuleThicknessEm = 0.06;
      SuperscriptShiftUpEm = 0.36;
      SuperscriptBottomMinEm = 0.11;
      SubscriptShiftDownEm = 0.2;
      SubscriptTopMaxEm = 0.36;
      SubSuperscriptGapMinEm = 0.2;
      ScriptSpaceEm = 0.05;
      FractionGapDisplayEm = 0.18;
      FractionGapTextEm = 0.06;
      FractionNumeratorShiftDisplayEm = 0.68;
      FractionNumeratorShiftTextEm = 0.44;
      FractionDenominatorShiftDisplayEm = 0.69;
      FractionDenominatorShiftTextEm = 0.34;
      FractionPaddingEm = 0.1;
      RadicalGapDisplayEm = 0.2;
      RadicalGapTextEm = 0.1;
      RadicalExtraAscenderEm = 0.06;
      RadicalSignWidthEm = 0.55;
      RadicalIndexRaiseEm = 0.55;
      RadicalStrokeEm = 0.05;
      LimitGapEm = 0.12;
      AccentGapEm = 0.05;
      AccentGlyphBottomEm = 0.55;
      AccentGlyphTopEm = 0.75;
      ArrowAccentScale = 0.6;
      ArrowAccentBottomEm = 0.02;
      ArrowAccentTopEm = 0.3;
      OverlineGapEm = 0.12;
      DelimiterWidthEm = 0.45;
      DelimiterStrokeEm = 0.075;
      DelimiterGlyphHeightEm = 1.05;
      NullDelimiterSpaceEm = 0.12;
      MatrixRowGapEm = 0.5;
      MatrixColumnGapEm = 0.9;
      ParenthesisSegments = 12;
      MuPerEm = 18;
      ArrowGlyph = #$2192;
      DoubleBarGlyph = #$2016;
      LeftAngleGlyph = #$27E8;
      RightAngleGlyph = #$27E9;
      LeftFloorGlyph = #$230A;
      RightFloorGlyph = #$230B;
      LeftCeilingGlyph = #$2308;
      RightCeilingGlyph = #$2309;
      IntegralGlyph = #$222B;
      // TeX's inter-atom spacing, in mu, indexed by the class on the left and
      // on the right. The second table marks the entries that vanish in
      // script styles.
      SpacingMu: array[TMathAtomClass, TMathAtomClass] of Integer = (
        (0, 3, 4, 5, 0, 0, 0, 3),
        (3, 3, 0, 5, 0, 0, 0, 3),
        (4, 4, 0, 0, 4, 0, 0, 4),
        (5, 5, 0, 0, 5, 0, 0, 5),
        (0, 0, 0, 0, 0, 0, 0, 0),
        (0, 3, 4, 5, 0, 0, 0, 3),
        (3, 3, 0, 3, 3, 3, 3, 3),
        (3, 3, 4, 5, 3, 0, 3, 3));
      SpacingTextOnly: array[TMathAtomClass, TMathAtomClass] of Boolean = (
        (False, False, True, True, False, False, False, True),
        (False, False, False, True, False, False, False, True),
        (True, True, False, False, True, False, False, True),
        (True, True, False, False, True, False, False, True),
        (False, False, False, False, False, False, False, False),
        (False, False, True, True, False, False, False, True),
        (True, True, False, True, True, True, True, True),
        (True, False, True, True, True, False, True, True));
    var
      FMeasurer: ITextMeasurer;
      FOptions: TMathLayoutOptions;
    function Build(const Node: IMathNode; const Style: TMathStyle; const Variant: TMathFontVariant): TMathBox;
    function BuildRow(const Node: IMathNode; const Style: TMathStyle; const Variant: TMathFontVariant): TMathBox;
    function BuildSymbol(const Node: IMathNode; const Style: TMathStyle; const Variant: TMathFontVariant): TMathBox;
    function BuildText(const Node: IMathNode; const Style: TMathStyle): TMathBox;
    function BuildSpace(const Node: IMathNode; const Style: TMathStyle): TMathBox;
    function BuildFraction(const Node: IMathNode; const Style: TMathStyle; const Variant: TMathFontVariant): TMathBox;
    function BuildScript(const Node: IMathNode; const Style: TMathStyle; const Variant: TMathFontVariant): TMathBox;
    function BuildLimits(const Base: TMathBox; const Node: IMathNode; const Style: TMathStyle;
      const Variant: TMathFontVariant): TMathBox;
    function BuildRadical(const Node: IMathNode; const Style: TMathStyle; const Variant: TMathFontVariant): TMathBox;
    function BuildDelimited(const Node: IMathNode; const Style: TMathStyle; const Variant: TMathFontVariant): TMathBox;
    function BuildAccent(const Node: IMathNode; const Style: TMathStyle; const Variant: TMathFontVariant): TMathBox;
    function BuildMatrix(const Node: IMathNode; const Style, CellStyle: TMathStyle;
      const Variant: TMathFontVariant): TMathBox;
    class function ColumnInset(const Alignment: TMathColumnAlignment; const ColumnIndex: Integer;
      const Slack: Single): Single; static;
    function WrapWithDelimiters(const Body: TMathBox; const Left, Right: string; const Style: TMathStyle): TMathBox;
    function BuildDelimiter(const Delimiter: string; const RequiredAscent, RequiredDescent: Single;
      const Style: TMathStyle): TMathBox;
    function BuildStretchedDelimiter(const Delimiter: string; const Ascent, Descent: Single;
      const Style: TMathStyle): TMathBox;
    procedure AddParenthesis(const Group: TMathBox; const Ascent, Descent, Width, Stroke: Single;
      const OpensLeft: Boolean);
    procedure AddBracket(const Group: TMathBox; const Ascent, Descent, Width, Stroke: Single;
      const OpensLeft: Boolean);
    procedure AddBrace(const Group: TMathBox; const Ascent, Descent, Width, Stroke: Single; const OpensLeft: Boolean);
    procedure AddBar(const Group: TMathBox; const Ascent, Descent, X, Stroke: Single);
    procedure AddAngle(const Group: TMathBox; const Ascent, Descent, Width, Stroke: Single; const OpensLeft: Boolean);
    procedure AddFloorOrCeiling(const Group: TMathBox; const Ascent, Descent, Width, Stroke: Single;
      const OpensLeft, TickAtTop: Boolean);
    procedure AddPolyline(const Group: TMathBox; const Points: TArray<TLayoutPointF>; const Stroke: Single);
    function GlyphBox(const Text: string; const Font: TMarkdownFontStyle; const Color: TLayoutColor;
      const Extent: TGlyphExtent): TMathBox;
    function RuleBox(const Width, Thickness: Single): TMathBox;
    function SegmentBox(const StartPoint, EndPoint: TLayoutPointF; const Thickness: Single): TMathBox;
    class function EmptyBox: TMathBox; static;
    function FontFor(const Style: TMathStyle; const Variant: TMathFontVariant): TMarkdownFontStyle;
    function EmSize(const Style: TMathStyle): Single;
    class function SubStyle(const Style: TMathStyle): TMathStyle; static;
    class function FractionStyle(const Style: TMathStyle): TMathStyle; static;
    class function IsScriptStyle(const Style: TMathStyle): Boolean; static;
    class function ResolveVariant(const Own, Context: TMathFontVariant): TMathFontVariant; static;
    class function GlyphExtent(const Text: string): TGlyphExtent; static;
    class function AtomClassOf(const Node: IMathNode): TMathAtomClass; static;
    class function ResolveAtomClasses(const Node: IMathNode): TArray<TMathAtomClass>; static;
    function SpacingBetween(const Left, Right: TMathAtomClass; const Style: TMathStyle): Single;
    class function IsLargeOperator(const Node: IMathNode): Boolean; static;

  public
    constructor Create(const Options: TMathLayoutOptions; const Measurer: ITextMeasurer);
    function BuildRoot(const Node: IMathNode): TMathBox;
  end;

class function TMathLayoutOptions.Create(const Font: TMarkdownFontStyle; const TextColor, ErrorColor: TLayoutColor;
  const IsDisplay: Boolean): TMathLayoutOptions;
begin
  Result.Font := Font;
  Result.TextColor := TextColor;
  Result.ErrorColor := ErrorColor;
  Result.IsDisplay := IsDisplay;
end;

class function TGlyphExtent.Create(const AscentEm, DescentEm: Single): TGlyphExtent;
begin
  Result.AscentEm := AscentEm;
  Result.DescentEm := DescentEm;
end;

class function TMathLayouter.Layout(const Source: string; const Options: TMathLayoutOptions;
  const Measurer: ITextMeasurer): IMathLayout;
begin
  Result := LayoutNode(TMathParser.Parse(Source), Options, Measurer);
end;

class function TMathLayouter.LayoutNode(const Node: IMathNode; const Options: TMathLayoutOptions;
  const Measurer: ITextMeasurer): IMathLayout;
begin
  const Builder = TMathBoxBuilder.Create(Options, Measurer);
  try
    Result := Builder.BuildRoot(Node);
  finally
    Builder.Free;
  end;
end;

constructor TMathBox.Create(const Kind: TMathBoxKind);
begin
  inherited Create;

  FKind := Kind;
  FChildren := TList<TMathPlacement>.Create;
end;

destructor TMathBox.Destroy;
begin
  FChildren.Free;

  inherited Destroy;
end;

function TMathBox.GetWidth: Single;
begin
  Result := FWidth;
end;

function TMathBox.GetAscent: Single;
begin
  Result := FAscent;
end;

function TMathBox.GetDescent: Single;
begin
  Result := FDescent;
end;

procedure TMathBox.Place(const Child: TMathBox; const DX, DY: Single);
begin
  var Placement: TMathPlacement;
  Placement.Box := Child;
  Placement.Handle := Child;
  Placement.DX := DX;
  Placement.DY := DY;

  FChildren.Add(Placement);
end;

procedure TMathBox.Enclose(const Child: TMathBox; const DX, DY: Single);
begin
  Place(Child, DX, DY);

  FWidth := Max(FWidth, DX + Child.Width);
  FAscent := Max(FAscent, Child.Ascent - DY);
  FDescent := Max(FDescent, Child.Descent + DY);
end;

procedure TMathBox.Draw(const Canvas: IExtensionCanvas; const Left, Baseline: Single);
begin
  case FKind of
    TMathBoxKind.Group:
      DrawGroup(Canvas, Left, Baseline);
    TMathBoxKind.Glyph:
      Canvas.DrawText(TLayoutPointF.Create(Left, Baseline - FFontBaseline), FText, FFont, FColor);
    TMathBoxKind.Rule:
      Canvas.FillRectangle(TLayoutRectF.Create(Left + FRule.Left, Baseline + FRule.Top, Left + FRule.Right,
        Baseline + FRule.Bottom), FColor);
    TMathBoxKind.Polygon:
      DrawPolygon(Canvas, Left, Baseline);
  else
    raise EMathSyntaxError.CreateFmt('Unhandled math box kind: %d', [Ord(FKind)]);
  end;
end;

procedure TMathBox.DrawGroup(const Canvas: IExtensionCanvas; const Left, Baseline: Single);
begin
  for var Placement in FChildren do
  begin
    Placement.Box.Draw(Canvas, Left + Placement.DX, Baseline + Placement.DY);
  end;
end;

procedure TMathBox.DrawPolygon(const Canvas: IExtensionCanvas; const Left, Baseline: Single);
begin
  var Moved: TArray<TLayoutPointF>;
  SetLength(Moved, Length(FPoints));

  for var Index := 0 to High(FPoints) do
  begin
    Moved[Index] := TLayoutPointF.Create(Left + FPoints[Index].X, Baseline + FPoints[Index].Y);
  end;

  Canvas.FillPolygon(Moved, FColor);
end;

class function TMathGlyphMapper.Apply(const Text: string; const Variant: TMathFontVariant): string;
begin
  const NeedsMapping = (Variant = TMathFontVariant.DoubleStruck) or (Variant = TMathFontVariant.Script) or
    (Variant = TMathFontVariant.Fraktur) or (Variant = TMathFontVariant.SansSerif) or
    (Variant = TMathFontVariant.Monospace);
  if not NeedsMapping then
  begin
    Result := Text;
    Exit;
  end;

  const Builder = TStringBuilder.Create;
  try
    for var Value in Text do
    begin
      var CodePoint: Integer;

      case Variant of
        TMathFontVariant.DoubleStruck:
          CodePoint := DoubleStruck(Value);
        TMathFontVariant.Script:
          CodePoint := ScriptLetter(Value);
        TMathFontVariant.Fraktur:
          CodePoint := Fraktur(Value);
        TMathFontVariant.SansSerif:
          CodePoint := SansSerif(Value);
        TMathFontVariant.Monospace:
          CodePoint := Monospace(Value);
      else
        CodePoint := 0;
      end;

      if CodePoint = 0 then
        Builder.Append(Value)
      else
        Builder.Append(Char.ConvertFromUtf32(CodePoint));
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TMathGlyphMapper.MapLetter(const Letter: Char; const UpperBase, LowerBase: Integer): Integer;
begin
  if CharInSet(Letter, ['A'..'Z']) then
  begin
    Result := UpperBase + Ord(Letter) - Ord('A');
    Exit;
  end;

  if CharInSet(Letter, ['a'..'z']) then
  begin
    Result := LowerBase + Ord(Letter) - Ord('a');
    Exit;
  end;

  Result := 0;
end;

class function TMathGlyphMapper.MapDigit(const Digit: Char; const DigitBase: Integer): Integer;
begin
  if CharInSet(Digit, ['0'..'9']) then
  begin
    Result := DigitBase + Ord(Digit) - Ord('0');
    Exit;
  end;

  Result := 0;
end;

class function TMathGlyphMapper.DoubleStruck(const Value: Char): Integer;
begin
  case Value of
    'C': Result := $2102;
    'H': Result := $210D;
    'N': Result := $2115;
    'P': Result := $2119;
    'Q': Result := $211A;
    'R': Result := $211D;
    'Z': Result := $2124;
  else
    Result := MapLetter(Value, $1D538, $1D552);
    if Result = 0 then
      Result := MapDigit(Value, $1D7D8);
  end;
end;

class function TMathGlyphMapper.ScriptLetter(const Value: Char): Integer;
begin
  case Value of
    'B': Result := $212C;
    'E': Result := $2130;
    'F': Result := $2131;
    'H': Result := $210B;
    'I': Result := $2110;
    'L': Result := $2112;
    'M': Result := $2133;
    'R': Result := $211B;
    'e': Result := $212F;
    'g': Result := $210A;
    'o': Result := $2134;
  else
    Result := MapLetter(Value, $1D49C, $1D4B6);
  end;
end;

class function TMathGlyphMapper.Fraktur(const Value: Char): Integer;
begin
  case Value of
    'C': Result := $212D;
    'H': Result := $210C;
    'I': Result := $2111;
    'R': Result := $211C;
    'Z': Result := $2128;
  else
    Result := MapLetter(Value, $1D504, $1D51E);
  end;
end;

class function TMathGlyphMapper.SansSerif(const Value: Char): Integer;
begin
  Result := MapLetter(Value, $1D5A0, $1D5BA);
  if Result = 0 then
    Result := MapDigit(Value, $1D7E2);
end;

class function TMathGlyphMapper.Monospace(const Value: Char): Integer;
begin
  Result := MapLetter(Value, $1D670, $1D68A);
  if Result = 0 then
    Result := MapDigit(Value, $1D7F6);
end;

constructor TMathBoxBuilder.Create(const Options: TMathLayoutOptions; const Measurer: ITextMeasurer);
begin
  inherited Create;

  FOptions := Options;
  FMeasurer := Measurer;
end;

function TMathBoxBuilder.BuildRoot(const Node: IMathNode): TMathBox;
begin
  var Style := TMathStyle.Text;
  if FOptions.IsDisplay then
    Style := TMathStyle.Display;

  // A column of lines at the root keeps the display style per line; a matrix
  // inside a formula sets its cells in text style, as TeX does.
  const IsLineColumn = (Node.Kind = TMathNodeKind.Matrix) and (Node.LeftDelimiter = '') and
    (Node.RightDelimiter = '');
  if IsLineColumn then
  begin
    Result := BuildMatrix(Node, Style, Style, TMathFontVariant.Italic);
    Exit;
  end;

  Result := Build(Node, Style, TMathFontVariant.Italic);
end;

function TMathBoxBuilder.Build(const Node: IMathNode; const Style: TMathStyle;
  const Variant: TMathFontVariant): TMathBox;
begin
  case Node.Kind of
    TMathNodeKind.Row:
      Result := BuildRow(Node, Style, Variant);
    TMathNodeKind.Symbol:
      Result := BuildSymbol(Node, Style, Variant);
    TMathNodeKind.Text:
      Result := BuildText(Node, Style);
    TMathNodeKind.Space:
      Result := BuildSpace(Node, Style);
    TMathNodeKind.Fraction:
      Result := BuildFraction(Node, Style, Variant);
    TMathNodeKind.Script:
      Result := BuildScript(Node, Style, Variant);
    TMathNodeKind.Radical:
      Result := BuildRadical(Node, Style, Variant);
    TMathNodeKind.Delimited:
      Result := BuildDelimited(Node, Style, Variant);
    TMathNodeKind.Accent:
      Result := BuildAccent(Node, Style, Variant);
    TMathNodeKind.Matrix:
      Result := BuildMatrix(Node, Style, TMathStyle.Text, Variant);
    TMathNodeKind.Styled:
      Result := Build(Node.Children[0], Style, Node.Variant);
  else
    raise EMathSyntaxError.CreateFmt('Unhandled math node kind: %d', [Ord(Node.Kind)]);
  end;
end;

// Atoms sit side by side with TeX's inter-atom spacing between them. Spaces
// are transparent: they add their width and leave the spacing between the
// atoms around them alone.
function TMathBoxBuilder.BuildRow(const Node: IMathNode; const Style: TMathStyle;
  const Variant: TMathFontVariant): TMathBox;
begin
  Result := TMathBox.Create(TMathBoxKind.Group);

  const Classes = ResolveAtomClasses(Node);
  var Cursor: Single := 0;
  var HasPrevious := False;
  var PreviousClass := TMathAtomClass.Ordinary;

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    const Child = Node.Children[Index];
    const Box = Build(Child, Style, Variant);

    const IsSpace = (Child.Kind = TMathNodeKind.Space);
    if IsSpace then
    begin
      Result.Enclose(Box, Cursor, 0);
      Cursor := Cursor + Box.Width;
      Continue;
    end;

    if HasPrevious then
      Cursor := Cursor + SpacingBetween(PreviousClass, Classes[Index], Style);

    Result.Enclose(Box, Cursor, 0);
    Cursor := Cursor + Box.Width;
    PreviousClass := Classes[Index];
    HasPrevious := True;
  end;

  Result.Width := Cursor;
end;

// A binary operator with nothing to bind on one side is an ordinary symbol:
// the minus in "-x" or after an equals sign gets no operator spacing.
class function TMathBoxBuilder.ResolveAtomClasses(const Node: IMathNode): TArray<TMathAtomClass>;
begin
  SetLength(Result, Node.ChildCount);

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    Result[Index] := AtomClassOf(Node.Children[Index]);
  end;

  var PreviousClass := TMathAtomClass.Opening;

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    const IsSpace = (Node.Children[Index].Kind = TMathNodeKind.Space);
    if IsSpace then
      Continue;

    if Result[Index] = TMathAtomClass.Binary then
    begin
      var NextClass := TMathAtomClass.Closing;
      for var Ahead := Index + 1 to Node.ChildCount - 1 do
      begin
        const AheadIsSpace = (Node.Children[Ahead].Kind = TMathNodeKind.Space);
        if not AheadIsSpace then
        begin
          NextClass := Result[Ahead];
          Break;
        end;
      end;

      const LacksLeftOperand = (PreviousClass = TMathAtomClass.Binary) or (PreviousClass = TMathAtomClass.Operator) or
        (PreviousClass = TMathAtomClass.Relation) or (PreviousClass = TMathAtomClass.Opening) or
        (PreviousClass = TMathAtomClass.Punctuation);
      const LacksRightOperand = (NextClass = TMathAtomClass.Relation) or (NextClass = TMathAtomClass.Closing) or
        (NextClass = TMathAtomClass.Punctuation);
      if LacksLeftOperand or LacksRightOperand then
        Result[Index] := TMathAtomClass.Ordinary;
    end;

    PreviousClass := Result[Index];
  end;
end;

class function TMathBoxBuilder.AtomClassOf(const Node: IMathNode): TMathAtomClass;
begin
  case Node.Kind of
    TMathNodeKind.Symbol, TMathNodeKind.Script, TMathNodeKind.Fraction, TMathNodeKind.Delimited,
    TMathNodeKind.Matrix:
      Result := Node.AtomClass;
    TMathNodeKind.Row:
      begin
        // A group of one atom keeps that atom's class, so {x} + {y} spaces
        // like x + y; a longer group is an ordinary atom, as in TeX.
        const IsSingleton = (Node.ChildCount = 1);
        if IsSingleton then
          Result := AtomClassOf(Node.Children[0])
        else
          Result := TMathAtomClass.Ordinary;
      end;
  else
    Result := TMathAtomClass.Ordinary;
  end;
end;

function TMathBoxBuilder.SpacingBetween(const Left, Right: TMathAtomClass; const Style: TMathStyle): Single;
begin
  const VanishesHere = SpacingTextOnly[Left, Right] and IsScriptStyle(Style);
  if VanishesHere then
  begin
    Result := 0;
    Exit;
  end;

  Result := SpacingMu[Left, Right] * EmSize(Style) / MuPerEm;
end;

function TMathBoxBuilder.BuildSymbol(const Node: IMathNode; const Style: TMathStyle;
  const Variant: TMathFontVariant): TMathBox;
begin
  const Effective = ResolveVariant(Node.Variant, Variant);
  var Font := FontFor(Style, Effective);
  const Text = TMathGlyphMapper.Apply(Node.Text, Effective);

  var Color := FOptions.TextColor;
  if Node.IsError then
    Color := FOptions.ErrorColor;

  var Extent := GlyphExtent(Node.Text);

  const DrawsLarge = IsLargeOperator(Node) and (Style = TMathStyle.Display);
  if not DrawsLarge then
  begin
    Result := GlyphBox(Text, Font, Color, Extent);
    Exit;
  end;

  // A large operator in display style grows and centres on the math axis,
  // so a sum sits level with the fraction bars around it.
  Font.Size := Font.Size * LargeOperatorScale;
  Extent.AscentEm := Extent.AscentEm * LargeOperatorScale;
  Extent.DescentEm := Extent.DescentEm * LargeOperatorScale;

  const Glyph = GlyphBox(Text, Font, Color, Extent);
  const GlyphCentre = (Glyph.Ascent - Glyph.Descent) / 2;
  const Shift = GlyphCentre - AxisHeightEm * EmSize(Style);

  Result := TMathBox.Create(TMathBoxKind.Group);
  Result.Enclose(Glyph, 0, Shift);
end;

class function TMathBoxBuilder.IsLargeOperator(const Node: IMathNode): Boolean;
begin
  Result := (Node.Kind = TMathNodeKind.Symbol) and Node.IsLarge;
end;

function TMathBoxBuilder.BuildText(const Node: IMathNode; const Style: TMathStyle): TMathBox;
begin
  const Font = FontFor(Style, Node.Variant);

  Result := GlyphBox(Node.Text, Font, FOptions.TextColor, GlyphExtent(Node.Text));
end;

function TMathBoxBuilder.BuildSpace(const Node: IMathNode; const Style: TMathStyle): TMathBox;
begin
  Result := EmptyBox;
  Result.Width := Node.SpaceWidth * EmSize(Style);
end;

function TMathBoxBuilder.BuildFraction(const Node: IMathNode; const Style: TMathStyle;
  const Variant: TMathFontVariant): TMathBox;
begin
  const PartStyle = FractionStyle(Style);
  const Numerator = Build(Node.Children[0], PartStyle, Variant);
  const Denominator = Build(Node.Children[1], PartStyle, Variant);

  const Em = EmSize(Style);
  const Axis = AxisHeightEm * Em;
  const IsDisplayStyle = (Style = TMathStyle.Display);

  var Thickness := RuleThicknessEm * Em;
  var Gap := FractionGapTextEm * Em;
  var NumeratorShift := FractionNumeratorShiftTextEm * Em;
  var DenominatorShift := FractionDenominatorShiftTextEm * Em;
  if IsDisplayStyle then
  begin
    Gap := FractionGapDisplayEm * Em;
    NumeratorShift := FractionNumeratorShiftDisplayEm * Em;
    DenominatorShift := FractionDenominatorShiftDisplayEm * Em;
  end;

  if not Node.HasRule then
  begin
    Gap := Gap + Thickness;
    Thickness := 0;
  end;

  const NumeratorBaseline = -Max(NumeratorShift, Axis + Thickness / 2 + Gap + Numerator.Descent);
  const DenominatorBaseline = Max(DenominatorShift, -Axis + Thickness / 2 + Gap + Denominator.Ascent);

  const Padding = FractionPaddingEm * Em;
  const InnerWidth = Max(Numerator.Width, Denominator.Width);

  Result := TMathBox.Create(TMathBoxKind.Group);
  Result.Enclose(Numerator, Padding + (InnerWidth - Numerator.Width) / 2, NumeratorBaseline);
  Result.Enclose(Denominator, Padding + (InnerWidth - Denominator.Width) / 2, DenominatorBaseline);

  if Node.HasRule then
  begin
    const Bar = RuleBox(InnerWidth + 2 * Padding, Thickness);
    Result.Enclose(Bar, 0, -Axis);
  end;

  Result.Width := InnerWidth + 2 * Padding;
end;

function TMathBoxBuilder.BuildScript(const Node: IMathNode; const Style: TMathStyle;
  const Variant: TMathFontVariant): TMathBox;
begin
  const BaseNode = Node.Children[0];
  const Base = Build(BaseNode, Style, Variant);

  const PutsLimits = (Style = TMathStyle.Display) and (BaseNode.Kind = TMathNodeKind.Symbol) and BaseNode.TakesLimits;
  if PutsLimits then
  begin
    Result := BuildLimits(Base, Node, Style, Variant);
    Exit;
  end;

  const ScriptStyle = SubStyle(Style);
  const HasSuperscript = not Node.Children[1].IsEmpty;
  const HasSubscript = not Node.Children[2].IsEmpty;
  const Em = EmSize(Style);

  Result := TMathBox.Create(TMathBoxKind.Group);
  Result.Enclose(Base, 0, 0);

  const ScriptLeft = Base.Width + ScriptSpaceEm * Em;
  var ScriptWidth: Single := 0;

  var SuperscriptRise: Single := 0;
  var Superscript: TMathBox := nil;
  if HasSuperscript then
  begin
    Superscript := Build(Node.Children[1], ScriptStyle, Variant);
    SuperscriptRise := Max(SuperscriptShiftUpEm * Em, Base.Ascent - XHeightEm * Em);
    SuperscriptRise := Max(SuperscriptRise, Superscript.Descent + SuperscriptBottomMinEm * Em);
    ScriptWidth := Superscript.Width;
  end;

  if HasSubscript then
  begin
    const Subscript = Build(Node.Children[2], ScriptStyle, Variant);
    var SubscriptDrop := Max(SubscriptShiftDownEm * Em, Base.Descent + XHeightEm * Em / 2);
    SubscriptDrop := Max(SubscriptDrop, Subscript.Ascent - SubscriptTopMaxEm * Em);

    if HasSuperscript then
    begin
      const SuperscriptBottom = -SuperscriptRise + Superscript.Descent;
      const SubscriptTop = SubscriptDrop - Subscript.Ascent;
      const Clearance = SubscriptTop - SuperscriptBottom;
      const MinimumClearance = SubSuperscriptGapMinEm * Em;
      if Clearance < MinimumClearance then
        SubscriptDrop := SubscriptDrop + (MinimumClearance - Clearance);
    end;

    Result.Enclose(Subscript, ScriptLeft, SubscriptDrop);
    ScriptWidth := Max(ScriptWidth, Subscript.Width);
  end;

  if HasSuperscript then
    Result.Enclose(Superscript, ScriptLeft, -SuperscriptRise);

  Result.Width := ScriptLeft + ScriptWidth + ScriptSpaceEm * Em;
end;

function TMathBoxBuilder.BuildLimits(const Base: TMathBox; const Node: IMathNode; const Style: TMathStyle;
  const Variant: TMathFontVariant): TMathBox;
begin
  const ScriptStyle = SubStyle(Style);
  const Gap = LimitGapEm * EmSize(Style);
  const HasUpper = not Node.Children[1].IsEmpty;
  const HasLower = not Node.Children[2].IsEmpty;

  var Upper: TMathBox := nil;
  var Lower: TMathBox := nil;
  var Width := Base.Width;

  if HasUpper then
  begin
    Upper := Build(Node.Children[1], ScriptStyle, Variant);
    Width := Max(Width, Upper.Width);
  end;

  if HasLower then
  begin
    Lower := Build(Node.Children[2], ScriptStyle, Variant);
    Width := Max(Width, Lower.Width);
  end;

  Result := TMathBox.Create(TMathBoxKind.Group);
  Result.Enclose(Base, (Width - Base.Width) / 2, 0);

  if HasUpper then
    Result.Enclose(Upper, (Width - Upper.Width) / 2, -(Base.Ascent + Gap + Upper.Descent));

  if HasLower then
    Result.Enclose(Lower, (Width - Lower.Width) / 2, Base.Descent + Gap + Lower.Ascent);

  Result.Width := Width;
end;

function TMathBoxBuilder.BuildRadical(const Node: IMathNode; const Style: TMathStyle;
  const Variant: TMathFontVariant): TMathBox;
begin
  const Radicand = Build(Node.Children[0], Style, Variant);
  const Em = EmSize(Style);
  const Thickness = RuleThicknessEm * Em;

  var Gap := RadicalGapTextEm * Em;
  if Style = TMathStyle.Display then
    Gap := RadicalGapDisplayEm * Em;

  const RuleTop = -(Radicand.Ascent + Gap + Thickness);
  const SignBottom = Radicand.Descent + Thickness;
  const SignWidth = RadicalSignWidthEm * Em;
  const Stroke = RadicalStrokeEm * Em;

  Result := TMathBox.Create(TMathBoxKind.Group);

  var IndexBox: TMathBox := nil;
  var IndexWidth: Single := 0;
  const HasIndex = not Node.Children[1].IsEmpty;
  if HasIndex then
  begin
    IndexBox := Build(Node.Children[1], TMathStyle.ScriptScript, Variant);
    IndexWidth := Max(0, IndexBox.Width - SignWidth * 0.4);
  end;

  // The sign is a short tick, a long stroke up to the rule, and the rule
  // over the radicand, all drawn as filled shapes so they scale with the
  // radicand rather than with a glyph the font may not stretch.
  const TickStart = TLayoutPointF.Create(IndexWidth, RuleTop * 0.45 + SignBottom * 0.55);
  const TickEnd = TLayoutPointF.Create(IndexWidth + SignWidth * 0.35, SignBottom);
  const StrokeEnd = TLayoutPointF.Create(IndexWidth + SignWidth, RuleTop + Thickness / 2);
  Result.Enclose(SegmentBox(TickStart, TickEnd, Stroke), 0, 0);
  Result.Enclose(SegmentBox(TickEnd, StrokeEnd, Stroke * 1.3), 0, 0);

  const RadicandLeft = IndexWidth + SignWidth;
  const Rule = RuleBox(Radicand.Width + Gap, Thickness);
  Result.Enclose(Rule, RadicandLeft, RuleTop);
  Result.Enclose(Radicand, RadicandLeft + Gap / 2, 0);

  if HasIndex then
    Result.Enclose(IndexBox, 0, RuleTop + RadicalIndexRaiseEm * Em - IndexBox.Descent);

  Result.Ascent := Result.Ascent + RadicalExtraAscenderEm * Em;
  Result.Width := RadicandLeft + Gap + Radicand.Width;
end;

function TMathBoxBuilder.BuildDelimited(const Node: IMathNode; const Style: TMathStyle;
  const Variant: TMathFontVariant): TMathBox;
begin
  const Body = Build(Node.Children[0], Style, Variant);

  Result := WrapWithDelimiters(Body, Node.LeftDelimiter, Node.RightDelimiter, Style);
end;

function TMathBoxBuilder.WrapWithDelimiters(const Body: TMathBox; const Left, Right: string;
  const Style: TMathStyle): TMathBox;
begin
  const LeftBox = BuildDelimiter(Left, Body.Ascent, Body.Descent, Style);
  const RightBox = BuildDelimiter(Right, Body.Ascent, Body.Descent, Style);

  Result := TMathBox.Create(TMathBoxKind.Group);
  Result.Enclose(LeftBox, 0, 0);
  Result.Enclose(Body, LeftBox.Width, 0);
  Result.Enclose(RightBox, LeftBox.Width + Body.Width, 0);
  Result.Width := LeftBox.Width + Body.Width + RightBox.Width;
end;

// A delimiter that fits the body at the font's size is a glyph; a taller
// one is drawn as filled shapes centred on the math axis.
function TMathBoxBuilder.BuildDelimiter(const Delimiter: string; const RequiredAscent, RequiredDescent: Single;
  const Style: TMathStyle): TMathBox;
begin
  const Em = EmSize(Style);

  if Delimiter = '' then
  begin
    Result := EmptyBox;
    Result.Width := NullDelimiterSpaceEm * Em;
    Exit;
  end;

  const Axis = AxisHeightEm * Em;
  const HalfHeight = Max(RequiredAscent - Axis, RequiredDescent + Axis);
  const NeedsStretching = (2 * HalfHeight > DelimiterGlyphHeightEm * Em);
  if not NeedsStretching then
  begin
    const Font = FontFor(Style, TMathFontVariant.Upright);
    Result := GlyphBox(Delimiter, Font, FOptions.TextColor, GlyphExtent(Delimiter));
    Exit;
  end;

  Result := BuildStretchedDelimiter(Delimiter, Axis + HalfHeight, HalfHeight - Axis, Style);
end;

function TMathBoxBuilder.BuildStretchedDelimiter(const Delimiter: string; const Ascent, Descent: Single;
  const Style: TMathStyle): TMathBox;
begin
  const Em = EmSize(Style);
  const Width = DelimiterWidthEm * Em;
  const Stroke = DelimiterStrokeEm * Em;

  Result := TMathBox.Create(TMathBoxKind.Group);
  Result.Width := Width;
  Result.Ascent := Ascent;
  Result.Descent := Descent;

  const Glyph = Delimiter[1];
  case Glyph of
    '(':
      AddParenthesis(Result, Ascent, Descent, Width, Stroke, True);
    ')':
      AddParenthesis(Result, Ascent, Descent, Width, Stroke, False);
    '[':
      AddBracket(Result, Ascent, Descent, Width, Stroke, True);
    ']':
      AddBracket(Result, Ascent, Descent, Width, Stroke, False);
    '{':
      AddBrace(Result, Ascent, Descent, Width, Stroke, True);
    '}':
      AddBrace(Result, Ascent, Descent, Width, Stroke, False);
    '|':
      AddBar(Result, Ascent, Descent, Width / 2, Stroke);
    DoubleBarGlyph:
      begin
        AddBar(Result, Ascent, Descent, Width * 0.3, Stroke);
        AddBar(Result, Ascent, Descent, Width * 0.7, Stroke);
      end;
    LeftAngleGlyph:
      AddAngle(Result, Ascent, Descent, Width, Stroke, True);
    RightAngleGlyph:
      AddAngle(Result, Ascent, Descent, Width, Stroke, False);
    LeftFloorGlyph:
      AddFloorOrCeiling(Result, Ascent, Descent, Width, Stroke, True, False);
    RightFloorGlyph:
      AddFloorOrCeiling(Result, Ascent, Descent, Width, Stroke, False, False);
    LeftCeilingGlyph:
      AddFloorOrCeiling(Result, Ascent, Descent, Width, Stroke, True, True);
    RightCeilingGlyph:
      AddFloorOrCeiling(Result, Ascent, Descent, Width, Stroke, False, True);
    '/':
      AddPolyline(Result, [TLayoutPointF.Create(Width, -Ascent), TLayoutPointF.Create(0, Descent)], Stroke);
    '\':
      AddPolyline(Result, [TLayoutPointF.Create(0, -Ascent), TLayoutPointF.Create(Width, Descent)], Stroke);
  else
    AddBar(Result, Ascent, Descent, Width / 2, Stroke);
  end;
end;

procedure TMathBoxBuilder.AddParenthesis(const Group: TMathBox; const Ascent, Descent, Width, Stroke: Single;
  const OpensLeft: Boolean);
begin
  // The bow is a parabola from the top right down to the left edge and back;
  // the polygon runs down the outer curve and back up the inner one.
  const Height = Ascent + Descent;
  const Bow = Width - Stroke;
  var Outline: TArray<TLayoutPointF>;
  SetLength(Outline, 2 * (ParenthesisSegments + 1));

  for var Index := 0 to ParenthesisSegments do
  begin
    const Fraction = Index / ParenthesisSegments;
    const Y = -Ascent + Fraction * Height;
    var X := Bow * Sqr(2 * Fraction - 1);
    if not OpensLeft then
      X := Width - X;

    Outline[Index] := TLayoutPointF.Create(X, Y);

    var InnerX := X + Stroke;
    if not OpensLeft then
      InnerX := X - Stroke;

    Outline[High(Outline) - Index] := TLayoutPointF.Create(InnerX, Y);
  end;

  const Shape = TMathBox.Create(TMathBoxKind.Polygon);
  Shape.Points := Outline;
  Shape.Color := FOptions.TextColor;
  Shape.Width := Width;
  Shape.Ascent := Ascent;
  Shape.Descent := Descent;
  Group.Place(Shape, 0, 0);
end;

procedure TMathBoxBuilder.AddBracket(const Group: TMathBox; const Ascent, Descent, Width, Stroke: Single;
  const OpensLeft: Boolean);
begin
  var BarX := Stroke / 2;
  var TickEnd := Width;
  if not OpensLeft then
  begin
    BarX := Width - Stroke / 2;
    TickEnd := 0;
  end;

  AddPolyline(Group, [TLayoutPointF.Create(TickEnd, -Ascent + Stroke / 2), TLayoutPointF.Create(BarX, -Ascent + Stroke / 2),
    TLayoutPointF.Create(BarX, Descent - Stroke / 2), TLayoutPointF.Create(TickEnd, Descent - Stroke / 2)], Stroke);
end;

procedure TMathBoxBuilder.AddBrace(const Group: TMathBox; const Ascent, Descent, Width, Stroke: Single;
  const OpensLeft: Boolean);
begin
  const Middle = (Descent - Ascent) / 2;
  const Hook = Width / 2;
  // The hook always bulges to the midpoint between the outer edge and the
  // cusp, whichever side each of those ends up on, so unlike Outer and Cusp
  // it never needs a direction-dependent value.
  const Inner = Width / 2;
  var Outer := Width;
  var Cusp: Single := 0;
  if not OpensLeft then
  begin
    Outer := 0;
    Cusp := Width;
  end;

  AddPolyline(Group, [TLayoutPointF.Create(Outer, -Ascent), TLayoutPointF.Create(Inner, -Ascent + Hook),
    TLayoutPointF.Create(Inner, Middle - Hook), TLayoutPointF.Create(Cusp, Middle),
    TLayoutPointF.Create(Inner, Middle + Hook), TLayoutPointF.Create(Inner, Descent - Hook),
    TLayoutPointF.Create(Outer, Descent)], Stroke);
end;

procedure TMathBoxBuilder.AddBar(const Group: TMathBox; const Ascent, Descent, X, Stroke: Single);
begin
  AddPolyline(Group, [TLayoutPointF.Create(X, -Ascent), TLayoutPointF.Create(X, Descent)], Stroke);
end;

procedure TMathBoxBuilder.AddAngle(const Group: TMathBox; const Ascent, Descent, Width, Stroke: Single;
  const OpensLeft: Boolean);
begin
  const Middle = (Descent - Ascent) / 2;
  var Outer := Width;
  var Tip: Single := 0;
  if not OpensLeft then
  begin
    Outer := 0;
    Tip := Width;
  end;

  AddPolyline(Group, [TLayoutPointF.Create(Outer, -Ascent), TLayoutPointF.Create(Tip, Middle),
    TLayoutPointF.Create(Outer, Descent)], Stroke);
end;

procedure TMathBoxBuilder.AddFloorOrCeiling(const Group: TMathBox; const Ascent, Descent, Width, Stroke: Single;
  const OpensLeft, TickAtTop: Boolean);
begin
  var BarX := Stroke / 2;
  var TickEnd := Width;
  if not OpensLeft then
  begin
    BarX := Width - Stroke / 2;
    TickEnd := 0;
  end;

  var TickY := Descent - Stroke / 2;
  var FarY := -Ascent;
  if TickAtTop then
  begin
    TickY := -Ascent + Stroke / 2;
    FarY := Descent;
  end;

  AddPolyline(Group, [TLayoutPointF.Create(TickEnd, TickY), TLayoutPointF.Create(BarX, TickY),
    TLayoutPointF.Create(BarX, FarY)], Stroke);
end;

procedure TMathBoxBuilder.AddPolyline(const Group: TMathBox; const Points: TArray<TLayoutPointF>;
  const Stroke: Single);
begin
  for var Index := 0 to High(Points) - 1 do
  begin
    Group.Place(SegmentBox(Points[Index], Points[Index + 1], Stroke), 0, 0);
  end;
end;

function TMathBoxBuilder.BuildAccent(const Node: IMathNode; const Style: TMathStyle;
  const Variant: TMathFontVariant): TMathBox;
begin
  const Base = Build(Node.Children[0], Style, Variant);
  const Em = EmSize(Style);

  Result := TMathBox.Create(TMathBoxKind.Group);
  Result.Enclose(Base, 0, 0);

  const IsOverline = (Node.Text = '');
  if IsOverline then
  begin
    const Thickness = RuleThicknessEm * Em;
    const Line = RuleBox(Base.Width, Thickness);
    Result.Enclose(Line, 0, -(Base.Ascent + OverlineGapEm * Em + Thickness));
    Exit;
  end;

  // Accent glyphs sit above the x-height in the font, so an accent over a
  // short letter needs no lift; over a tall one it rises with the letter.
  const IsArrow = (Node.Text = ArrowGlyph);
  var Font := FontFor(Style, TMathFontVariant.Upright);
  var GlyphBottom := AccentGlyphBottomEm * Em;
  var GlyphTop := AccentGlyphTopEm * Em;
  if IsArrow then
  begin
    Font.Size := Font.Size * ArrowAccentScale;
    GlyphBottom := ArrowAccentBottomEm * Em;
    GlyphTop := ArrowAccentTopEm * Em;
  end;

  const Accent = GlyphBox(Node.Text, Font, FOptions.TextColor, TGlyphExtent.Create(0, 0));
  const Lift = Max(Base.Ascent, XHeightEm * Em) + AccentGapEm * Em - GlyphBottom;
  Result.Place(Accent, (Base.Width - Accent.Width) / 2, -Lift);
  Result.Ascent := Max(Result.Ascent, Lift + GlyphTop);
end;

function TMathBoxBuilder.BuildMatrix(const Node: IMathNode; const Style, CellStyle: TMathStyle;
  const Variant: TMathFontVariant): TMathBox;
begin
  const Em = EmSize(Style);
  const RowGap = MatrixRowGapEm * Em;
  const ColumnGap = MatrixColumnGapEm * Em;

  var ColumnCount := 0;
  for var RowIndex := 0 to Node.ChildCount - 1 do
  begin
    ColumnCount := Max(ColumnCount, Node.Children[RowIndex].ChildCount);
  end;

  var Cells: TArray<TArray<TMathBox>>;
  var ColumnWidths: TArray<Single>;
  var RowAscents: TArray<Single>;
  var RowDescents: TArray<Single>;
  SetLength(Cells, Node.ChildCount);
  SetLength(ColumnWidths, ColumnCount);
  SetLength(RowAscents, Node.ChildCount);
  SetLength(RowDescents, Node.ChildCount);

  const Body = TMathBox.Create(TMathBoxKind.Group);

  for var RowIndex := 0 to Node.ChildCount - 1 do
  begin
    const Row = Node.Children[RowIndex];
    SetLength(Cells[RowIndex], Row.ChildCount);

    for var ColumnIndex := 0 to Row.ChildCount - 1 do
    begin
      const Cell = Build(Row.Children[ColumnIndex], CellStyle, Variant);
      Cells[RowIndex][ColumnIndex] := Cell;
      ColumnWidths[ColumnIndex] := Max(ColumnWidths[ColumnIndex], Cell.Width);
      RowAscents[RowIndex] := Max(RowAscents[RowIndex], Cell.Ascent);
      RowDescents[RowIndex] := Max(RowDescents[RowIndex], Cell.Descent);
    end;
  end;

  var TotalHeight: Single := 0;
  for var RowIndex := 0 to Node.ChildCount - 1 do
  begin
    TotalHeight := TotalHeight + RowAscents[RowIndex] + RowDescents[RowIndex];
  end;
  TotalHeight := TotalHeight + RowGap * Max(0, Node.ChildCount - 1);

  var Cursor := -AxisHeightEm * Em - TotalHeight / 2;
  for var RowIndex := 0 to Node.ChildCount - 1 do
  begin
    const RowBaseline = Cursor + RowAscents[RowIndex];
    var X: Single := 0;

    for var ColumnIndex := 0 to High(Cells[RowIndex]) do
    begin
      const Cell = Cells[RowIndex][ColumnIndex];
      const Inset = ColumnInset(Node.Alignment, ColumnIndex, ColumnWidths[ColumnIndex] - Cell.Width);

      Body.Enclose(Cell, X + Inset, RowBaseline);
      X := X + ColumnWidths[ColumnIndex] + ColumnGap;
    end;

    Cursor := Cursor + RowAscents[RowIndex] + RowDescents[RowIndex] + RowGap;
  end;

  var BodyWidth: Single := 0;
  for var ColumnWidth in ColumnWidths do
  begin
    BodyWidth := BodyWidth + ColumnWidth;
  end;
  Body.Width := BodyWidth + ColumnGap * Max(0, ColumnCount - 1);

  Result := WrapWithDelimiters(Body, Node.LeftDelimiter, Node.RightDelimiter, Style);
end;

class function TMathBoxBuilder.ColumnInset(const Alignment: TMathColumnAlignment; const ColumnIndex: Integer;
  const Slack: Single): Single;
begin
  case Alignment of
    TMathColumnAlignment.Centre:
      Result := Slack / 2;
    TMathColumnAlignment.Left:
      Result := 0;
    TMathColumnAlignment.Alternate:
      begin
        const IsRightAligned = (ColumnIndex mod 2 = 0);
        if IsRightAligned then
          Result := Slack
        else
          Result := 0;
      end;
  else
    raise EMathSyntaxError.CreateFmt('Unhandled column alignment: %d', [Ord(Alignment)]);
  end;
end;

function TMathBoxBuilder.GlyphBox(const Text: string; const Font: TMarkdownFontStyle; const Color: TLayoutColor;
  const Extent: TGlyphExtent): TMathBox;
begin
  Result := TMathBox.Create(TMathBoxKind.Glyph);
  Result.Text := Text;
  Result.Font := Font;
  Result.Color := Color;
  Result.FontBaseline := FMeasurer.Baseline(Font);
  Result.Width := FMeasurer.MeasureText(Text, Font).Width;
  Result.Ascent := Extent.AscentEm * Font.Size;
  Result.Descent := Extent.DescentEm * Font.Size;
end;

function TMathBoxBuilder.RuleBox(const Width, Thickness: Single): TMathBox;
begin
  Result := TMathBox.Create(TMathBoxKind.Rule);
  Result.Rule := TLayoutRectF.Create(0, -Thickness / 2, Width, Thickness / 2);
  Result.Color := FOptions.TextColor;
  Result.Width := Width;
  Result.Ascent := Thickness / 2;
  Result.Descent := Thickness / 2;
end;

// A line segment as a filled quadrilateral, which is the one shape every
// painter draws. Its extent is the bounding box of the two ends.
function TMathBoxBuilder.SegmentBox(const StartPoint, EndPoint: TLayoutPointF; const Thickness: Single): TMathBox;
begin
  const DeltaX = EndPoint.X - StartPoint.X;
  const DeltaY = EndPoint.Y - StartPoint.Y;
  const Length = Max(Sqrt(DeltaX * DeltaX + DeltaY * DeltaY), 0.001);
  const NormalX = -DeltaY / Length * Thickness / 2;
  const NormalY = DeltaX / Length * Thickness / 2;

  Result := TMathBox.Create(TMathBoxKind.Polygon);
  Result.Points := [TLayoutPointF.Create(StartPoint.X + NormalX, StartPoint.Y + NormalY),
    TLayoutPointF.Create(EndPoint.X + NormalX, EndPoint.Y + NormalY),
    TLayoutPointF.Create(EndPoint.X - NormalX, EndPoint.Y - NormalY),
    TLayoutPointF.Create(StartPoint.X - NormalX, StartPoint.Y - NormalY)];
  Result.Color := FOptions.TextColor;
  Result.Width := Max(StartPoint.X, EndPoint.X);
  Result.Ascent := -Min(StartPoint.Y, EndPoint.Y);
  Result.Descent := Max(StartPoint.Y, EndPoint.Y);
end;

class function TMathBoxBuilder.EmptyBox: TMathBox;
begin
  Result := TMathBox.Create(TMathBoxKind.Group);
end;

function TMathBoxBuilder.FontFor(const Style: TMathStyle; const Variant: TMathFontVariant): TMarkdownFontStyle;
begin
  const IsItalic = (Variant = TMathFontVariant.Italic) or (Variant = TMathFontVariant.BoldItalic);
  const IsBold = (Variant = TMathFontVariant.Bold) or (Variant = TMathFontVariant.BoldItalic);

  Result := TMarkdownFontStyle.Create(FOptions.Font.FamilyName, EmSize(Style), IsBold, IsItalic);
end;

function TMathBoxBuilder.EmSize(const Style: TMathStyle): Single;
begin
  case Style of
    TMathStyle.Display, TMathStyle.Text:
      Result := FOptions.Font.Size;
    TMathStyle.Script:
      Result := FOptions.Font.Size * ScriptScale;
    TMathStyle.ScriptScript:
      Result := FOptions.Font.Size * ScriptScriptScale;
  else
    raise EMathSyntaxError.CreateFmt('Unhandled math style: %d', [Ord(Style)]);
  end;
end;

class function TMathBoxBuilder.SubStyle(const Style: TMathStyle): TMathStyle;
begin
  case Style of
    TMathStyle.Display, TMathStyle.Text:
      Result := TMathStyle.Script;
    TMathStyle.Script, TMathStyle.ScriptScript:
      Result := TMathStyle.ScriptScript;
  else
    raise EMathSyntaxError.CreateFmt('Unhandled math style: %d', [Ord(Style)]);
  end;
end;

class function TMathBoxBuilder.FractionStyle(const Style: TMathStyle): TMathStyle;
begin
  case Style of
    TMathStyle.Display:
      Result := TMathStyle.Text;
    TMathStyle.Text:
      Result := TMathStyle.Script;
    TMathStyle.Script, TMathStyle.ScriptScript:
      Result := TMathStyle.ScriptScript;
  else
    raise EMathSyntaxError.CreateFmt('Unhandled math style: %d', [Ord(Style)]);
  end;
end;

class function TMathBoxBuilder.IsScriptStyle(const Style: TMathStyle): Boolean;
begin
  Result := (Style = TMathStyle.Script) or (Style = TMathStyle.ScriptScript);
end;

// A symbol's own variant is italic for letters and upright for the rest;
// inside \mathbf and the like the surrounding variant takes over.
class function TMathBoxBuilder.ResolveVariant(const Own, Context: TMathFontVariant): TMathFontVariant;
begin
  const HasContext = (Context <> TMathFontVariant.Italic);
  const IsPlain = (Own = TMathFontVariant.Italic) or (Own = TMathFontVariant.Upright);
  if HasContext and IsPlain then
  begin
    Result := Context;
    Exit;
  end;

  Result := Own;
end;

// Heights in em for the glyph classes the font families share closely
// enough: the layouter needs ascent and descent, and the measurer only
// reports a line height. The values follow STIX Two Math.
class function TMathBoxBuilder.GlyphExtent(const Text: string): TGlyphExtent;
begin
  if Text = '' then
  begin
    Result := TGlyphExtent.Create(0, 0);
    Exit;
  end;

  const First = Text[1];

  if First.IsDigit then
  begin
    Result := TGlyphExtent.Create(0.68, 0);
    Exit;
  end;

  if First.IsUpper then
  begin
    Result := TGlyphExtent.Create(0.68, 0);
    Exit;
  end;

  if First.IsLower then
  begin
    const Ascends = CharInSet(First, ['b', 'd', 'f', 'h', 'k', 'l', 't', 'i']) or (First = #$03B4) or
      (First = #$03B8) or (First = #$03BB);
    const Descends = CharInSet(First, ['g', 'p', 'q', 'y']) or (First = #$03B3) or (First = #$03B7) or
      (First = #$03BC) or (First = #$03C1) or (First = #$03C6) or (First = #$03C7) or (First = #$03C8) or
      (First = #$03C2) or (First = #$03D5);
    const Both = CharInSet(First, ['j']) or (First = #$03B2) or (First = #$03B6) or (First = #$03BE);

    if Both then
    begin
      Result := TGlyphExtent.Create(0.70, 0.21);
      Exit;
    end;

    if Ascends then
    begin
      Result := TGlyphExtent.Create(0.70, 0);
      Exit;
    end;

    if Descends then
    begin
      Result := TGlyphExtent.Create(0.46, 0.21);
      Exit;
    end;

    Result := TGlyphExtent.Create(0.46, 0);
    Exit;
  end;

  if CharInSet(First, ['(', ')', '[', ']', '{', '}', '|', '/', '\']) or (First = DoubleBarGlyph) or
    (First = LeftAngleGlyph) or (First = RightAngleGlyph) or (First = LeftFloorGlyph) or
    (First = RightFloorGlyph) or (First = LeftCeilingGlyph) or (First = RightCeilingGlyph) then
  begin
    Result := TGlyphExtent.Create(0.75, 0.25);
    Exit;
  end;

  if CharInSet(First, [',', ';']) then
  begin
    Result := TGlyphExtent.Create(0.15, 0.15);
    Exit;
  end;

  if First = '.' then
  begin
    Result := TGlyphExtent.Create(0.12, 0);
    Exit;
  end;

  const IsIntegral = (First >= IntegralGlyph) and (First <= #$222E);
  if IsIntegral then
  begin
    Result := TGlyphExtent.Create(0.85, 0.35);
    Exit;
  end;

  if (First = #$2211) or (First = #$220F) or (First = #$2210) then
  begin
    Result := TGlyphExtent.Create(0.75, 0.25);
    Exit;
  end;

  if First.IsPunctuation or First.IsSymbol then
  begin
    Result := TGlyphExtent.Create(0.55, 0.05);
    Exit;
  end;

  Result := TGlyphExtent.Create(0.68, 0.05);
end;

end.
