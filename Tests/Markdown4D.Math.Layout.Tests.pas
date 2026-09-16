unit Markdown4D.Math.Layout.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Math.Layout;

type
  [TestFixture]
  TMathLayoutTests = class
  private
    const
      FontSize = 16.0;
      CharWidth = 10.0;
      TextColor = $FF102030;
      ErrorColor = $FFCC0000;
      Tolerance = 0.01;
    var
      FMeasurer: ITextMeasurer;
    function Layout(const Source: string; const IsDisplay: Boolean): IMathLayout;
    function Items(const Source: string; const IsDisplay: Boolean; const Left: Single = 0;
      const Baseline: Single = 0): TArray<IDisplayItem>;
    class function RunWithText(const Items: TArray<IDisplayItem>; const Text: string): IDisplayTextRun;
    class function CountOfKind(const Items: TArray<IDisplayItem>; const Kind: TDisplayItemKind): Integer;
    class function BaselineOf(const Run: IDisplayTextRun): Single;

  public
    [SetupFixture]
    procedure SetupFixture;

    [Test]
    procedure Layout_Letters_AreItalicGlyphsAtBaseSize;

    [Test]
    procedure Layout_BinaryOperator_GetsMediumSpacing;

    [Test]
    procedure Layout_Relation_GetsThickSpacing;

    [Test]
    procedure Layout_UnaryMinus_GetsNoSpacing;

    [Test]
    procedure Layout_Superscript_IsSmallerAndRaised;

    [Test]
    procedure Layout_Subscript_IsLowered;

    [Test]
    procedure Layout_ScriptStyle_DropsOperatorSpacing;

    [Test]
    procedure Layout_Fraction_StacksAroundRule;

    [Test]
    procedure Layout_Radical_DrawsRuleAndSign;

    [Test]
    procedure Layout_TallDelimiters_AreDrawnAsShapes;

    [Test]
    procedure Layout_ShortDelimiters_AreGlyphs;

    [Test]
    procedure Layout_DisplaySum_PutsLimitsAboveAndBelow;

    [Test]
    procedure Layout_InlineSum_PutsLimitsBeside;

    [Test]
    procedure Layout_Matrix_AlignsColumnsAndRows;

    [Test]
    procedure Layout_AlignedRows_LineUpOnTheEqualsSign;

    [Test]
    procedure Layout_DoubleStruck_MapsToUnicodeGlyph;

    [Test]
    procedure Layout_UnknownCommand_UsesErrorColor;

    [Test]
    procedure Layout_Extent_CoversEveryPart;

    [Test]
    procedure Draw_AtOrigin_ShiftsEveryItem;

    [Test]
    procedure Layout_UnclosedInput_StillProducesItems;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Math,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Layout.ExtensionCanvas,
  Markdown4D.Layout.FakeMeasurer;

procedure TMathLayoutTests.SetupFixture;
begin
  FMeasurer := TFakeTextMeasurer.Create;
end;

function TMathLayoutTests.Layout(const Source: string; const IsDisplay: Boolean): IMathLayout;
begin
  const Font = TMarkdownFontStyle.Create('Test', FontSize);
  const Options = TMathLayoutOptions.Create(Font, TextColor, ErrorColor, IsDisplay);

  Result := TMathLayouter.Layout(Source, Options, FMeasurer);
end;

function TMathLayoutTests.Items(const Source: string; const IsDisplay: Boolean; const Left: Single;
  const Baseline: Single): TArray<IDisplayItem>;
begin
  const Formula = Layout(Source, IsDisplay);
  const Collected = TList<IDisplayItem>.Create;
  try
    const Canvas: IExtensionCanvas = TDisplayListExtensionCanvas.Create(FMeasurer, Collected, nil);
    Formula.Draw(Canvas, Left, Baseline);

    Result := Collected.ToArray;
  finally
    Collected.Free;
  end;
end;

class function TMathLayoutTests.RunWithText(const Items: TArray<IDisplayItem>; const Text: string): IDisplayTextRun;
begin
  for var Item in Items do
  begin
    var Run: IDisplayTextRun;
    const Matches = Supports(Item, IDisplayTextRun, Run) and (Run.Text = Text);
    if Matches then
    begin
      Result := Run;
      Exit;
    end;
  end;

  raise Exception.CreateFmt('No text run "%s" in the display items', [Text]);
end;

class function TMathLayoutTests.CountOfKind(const Items: TArray<IDisplayItem>; const Kind: TDisplayItemKind): Integer;
begin
  Result := 0;

  for var Item in Items do
  begin
    if Item.Kind = Kind then
      Inc(Result);
  end;
end;

class function TMathLayoutTests.BaselineOf(const Run: IDisplayTextRun): Single;
begin
  Result := Run.Bounds.Top + Run.Baseline;
end;

procedure TMathLayoutTests.Layout_Letters_AreItalicGlyphsAtBaseSize;
begin
  const Drawn = Items('xy', False);

  const Run = RunWithText(Drawn, 'x');
  Assert.IsTrue(Run.Font.Italic);
  Assert.AreEqual(FontSize, Run.Font.Size, Tolerance);
  Assert.AreEqual(CharWidth, RunWithText(Drawn, 'y').Bounds.Left, Tolerance);
end;

procedure TMathLayoutTests.Layout_BinaryOperator_GetsMediumSpacing;
begin
  const Formula = Layout('a+b', False);

  const MediumSpace = 4 / 18 * FontSize;
  Assert.AreEqual(3 * CharWidth + 2 * MediumSpace, Formula.Width, Tolerance);
end;

procedure TMathLayoutTests.Layout_Relation_GetsThickSpacing;
begin
  const Formula = Layout('a=b', False);

  const ThickSpace = 5 / 18 * FontSize;
  Assert.AreEqual(3 * CharWidth + 2 * ThickSpace, Formula.Width, Tolerance);
end;

procedure TMathLayoutTests.Layout_UnaryMinus_GetsNoSpacing;
begin
  const Formula = Layout('-x', False);

  Assert.AreEqual(2 * CharWidth, Formula.Width, Tolerance);
end;

procedure TMathLayoutTests.Layout_Superscript_IsSmallerAndRaised;
begin
  const Drawn = Items('x^2', False);

  const Base = RunWithText(Drawn, 'x');
  const Exponent = RunWithText(Drawn, '2');
  Assert.AreEqual(FontSize * 0.7, Exponent.Font.Size, Tolerance);
  Assert.IsTrue(BaselineOf(Exponent) < BaselineOf(Base), 'the exponent must sit above the base line');
  Assert.IsTrue(Exponent.Bounds.Left > Base.Bounds.Left, 'the exponent must follow the base');
end;

procedure TMathLayoutTests.Layout_Subscript_IsLowered;
begin
  const Drawn = Items('x_i', False);

  const Base = RunWithText(Drawn, 'x');
  const Index = RunWithText(Drawn, 'i');
  Assert.IsTrue(BaselineOf(Index) > BaselineOf(Base), 'the index must sit below the base line');
end;

procedure TMathLayoutTests.Layout_ScriptStyle_DropsOperatorSpacing;
begin
  const Drawn = Items('x^{a+b}', False);

  const ScriptCharWidth = CharWidth * 0.7;
  const A = RunWithText(Drawn, 'a');
  const B = RunWithText(Drawn, 'b');
  Assert.AreEqual(2 * ScriptCharWidth, B.Bounds.Left - A.Bounds.Left, Tolerance);
end;

procedure TMathLayoutTests.Layout_Fraction_StacksAroundRule;
begin
  const Drawn = Items('\frac{a}{b}', True);

  Assert.AreEqual(1, CountOfKind(Drawn, TDisplayItemKind.Rectangle));
  const Numerator = RunWithText(Drawn, 'a');
  const Denominator = RunWithText(Drawn, 'b');

  var Rule: IDisplayRectangle := nil;
  for var Item in Drawn do
  begin
    Supports(Item, IDisplayRectangle, Rule);
  end;

  Assert.IsTrue(BaselineOf(Numerator) < Rule.Bounds.Top, 'the numerator must sit above the rule');
  Assert.IsTrue(BaselineOf(Denominator) - Denominator.Baseline > Rule.Bounds.Bottom,
    'the denominator must sit below the rule');
  Assert.AreEqual(Numerator.Bounds.Left, Denominator.Bounds.Left, Tolerance);
end;

procedure TMathLayoutTests.Layout_Radical_DrawsRuleAndSign;
begin
  const Drawn = Items('\sqrt{x}', False);

  Assert.AreEqual(1, CountOfKind(Drawn, TDisplayItemKind.Rectangle));
  Assert.AreEqual(2, CountOfKind(Drawn, TDisplayItemKind.Polygon));
  Assert.AreEqual(1, CountOfKind(Drawn, TDisplayItemKind.TextRun));
end;

procedure TMathLayoutTests.Layout_TallDelimiters_AreDrawnAsShapes;
begin
  const Drawn = Items('\left( \frac{a}{b} \right)', True);

  Assert.IsTrue(CountOfKind(Drawn, TDisplayItemKind.Polygon) >= 2, 'both parentheses must be drawn as shapes');
  for var Item in Drawn do
  begin
    var Run: IDisplayTextRun;
    const IsParenthesis = Supports(Item, IDisplayTextRun, Run) and ((Run.Text = '(') or (Run.Text = ')'));
    Assert.IsFalse(IsParenthesis, 'a stretched parenthesis is not a glyph');
  end;
end;

procedure TMathLayoutTests.Layout_ShortDelimiters_AreGlyphs;
begin
  const Drawn = Items('\left( x \right)', False);

  Assert.AreEqual(0, CountOfKind(Drawn, TDisplayItemKind.Polygon));
  RunWithText(Drawn, '(');
  RunWithText(Drawn, ')');
end;

procedure TMathLayoutTests.Layout_DisplaySum_PutsLimitsAboveAndBelow;
begin
  const Drawn = Items('\sum_{i=1}^{n} i', True);

  const Sum = RunWithText(Drawn, #$2211);
  const Upper = RunWithText(Drawn, 'n');
  const Lower = RunWithText(Drawn, '1');
  Assert.IsTrue(BaselineOf(Upper) < BaselineOf(Sum) - FontSize / 2, 'the upper limit must sit above the sum');
  Assert.IsTrue(BaselineOf(Lower) > BaselineOf(Sum) + FontSize / 2, 'the lower limit must sit below the sum');
  Assert.IsTrue(Upper.Bounds.Left < Sum.Bounds.Right, 'the upper limit must sit over the sum, not beside it');
  Assert.AreEqual(FontSize * 1.4, Sum.Font.Size, Tolerance);
end;

procedure TMathLayoutTests.Layout_InlineSum_PutsLimitsBeside;
begin
  const Drawn = Items('\sum_{i=1}^{n} i', False);

  const Sum = RunWithText(Drawn, #$2211);
  const Upper = RunWithText(Drawn, 'n');
  Assert.IsTrue(Upper.Bounds.Left >= Sum.Bounds.Right - Tolerance, 'inline limits follow the sum');
  Assert.AreEqual(FontSize, Sum.Font.Size, Tolerance);
end;

procedure TMathLayoutTests.Layout_Matrix_AlignsColumnsAndRows;
begin
  const Drawn = Items('\begin{pmatrix} a & 12 \\ 345 & d \end{pmatrix}', True);

  const A = RunWithText(Drawn, 'a');
  const B = RunWithText(Drawn, '12');
  const C = RunWithText(Drawn, '345');
  const D = RunWithText(Drawn, 'd');
  Assert.AreEqual(BaselineOf(A), BaselineOf(B), Tolerance);
  Assert.AreEqual(BaselineOf(C), BaselineOf(D), Tolerance);
  Assert.IsTrue(BaselineOf(C) > BaselineOf(A), 'the second row sits below the first');
  Assert.AreEqual(C.Bounds.Left + CharWidth, A.Bounds.Left, Tolerance);
  Assert.AreEqual(B.Bounds.Left + CharWidth / 2, D.Bounds.Left, Tolerance);
  Assert.IsTrue(B.Bounds.Left > A.Bounds.Right, 'the second column follows the first');
end;

procedure TMathLayoutTests.Layout_AlignedRows_LineUpOnTheEqualsSign;
begin
  const Drawn = Items('\begin{aligned} a &= b \\ 111 &= d \end{aligned}', True);

  const ShortLeft = RunWithText(Drawn, 'a');
  const LongLeft = RunWithText(Drawn, '111');
  const ShortRight = RunWithText(Drawn, 'b');
  const LongRight = RunWithText(Drawn, 'd');
  Assert.AreEqual(LongLeft.Bounds.Right, ShortLeft.Bounds.Right, Tolerance);
  Assert.AreEqual(ShortRight.Bounds.Left, LongRight.Bounds.Left, Tolerance);
end;

procedure TMathLayoutTests.Layout_DoubleStruck_MapsToUnicodeGlyph;
begin
  const Drawn = Items('\mathbb{R}', False);

  RunWithText(Drawn, #$211D);
end;

procedure TMathLayoutTests.Layout_UnknownCommand_UsesErrorColor;
begin
  const Drawn = Items('\nosuchthing', False);

  const Run = RunWithText(Drawn, '\nosuchthing');
  Assert.AreEqual<TLayoutColor>(ErrorColor, Run.Color);
  Assert.IsFalse(Run.Font.Italic);
end;

procedure TMathLayoutTests.Layout_Extent_CoversEveryPart;
begin
  const Formula = Layout('\frac{a}{b}', True);
  const Drawn = Items('\frac{a}{b}', True);

  // Text runs report the font's line box, which is taller than the ink, so
  // they are held to their baseline; rules and shapes to their full bounds.
  for var Item in Drawn do
  begin
    var Run: IDisplayTextRun;
    if Supports(Item, IDisplayTextRun, Run) then
    begin
      Assert.IsTrue(BaselineOf(Run) >= -Formula.Ascent - Tolerance, 'no baseline may rise above the ascent');
      Assert.IsTrue(BaselineOf(Run) <= Formula.Descent + Tolerance, 'no baseline may drop below the descent');
    end
    else
    begin
      Assert.IsTrue(Item.Bounds.Top >= -Formula.Ascent - Tolerance, 'no shape may rise above the ascent');
      Assert.IsTrue(Item.Bounds.Bottom <= Formula.Descent + Tolerance, 'no shape may drop below the descent');
    end;

    Assert.IsTrue(Item.Bounds.Right <= Formula.Width + Tolerance, 'no item may pass the width');
  end;

  Assert.IsTrue(Formula.Descent > 0, 'a fraction reaches below the baseline');
end;

procedure TMathLayoutTests.Draw_AtOrigin_ShiftsEveryItem;
begin
  const Drawn = Items('x', False, 100, 200);

  const Run = RunWithText(Drawn, 'x');
  Assert.AreEqual(100.0, Run.Bounds.Left, Tolerance);
  Assert.AreEqual(200.0, BaselineOf(Run), Tolerance);
end;

procedure TMathLayoutTests.Layout_UnclosedInput_StillProducesItems;
begin
  const Drawn = Items('\frac{a}{\sqrt{b', True);

  RunWithText(Drawn, 'a');
  RunWithText(Drawn, 'b');
end;

end.
