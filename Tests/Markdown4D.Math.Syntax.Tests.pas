unit Markdown4D.Math.Syntax.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Math.Syntax;

type
  [TestFixture]
  TMathSyntaxTests = class
  private
    class function Parse(const Source: string): IMathNode;

  public
    [Test]
    procedure Parse_LettersAndPlus_YieldsClassifiedSymbols;

    [Test]
    procedure Parse_Digits_MergeIntoOneUprightSymbol;

    [Test]
    procedure Parse_Fraction_HoldsNumeratorAndDenominator;

    [Test]
    procedure Parse_SubscriptAndSuperscript_FillBothScriptSlots;

    [Test]
    procedure Parse_Prime_BecomesSuperscript;

    [Test]
    procedure Parse_RadicalWithIndex_KeepsIndex;

    [Test]
    procedure Parse_LeftRight_YieldsDelimitedGroup;

    [Test]
    procedure Parse_UnclosedGroup_ClosesAtEnd;

    [Test]
    procedure Parse_StrayClosingBrace_IsDropped;

    [Test]
    procedure Parse_UnknownCommand_BecomesErrorSymbol;

    [Test]
    procedure Parse_GreekCommand_MapsToUnicode;

    [Test]
    procedure Parse_Sum_TakesLimitsAndIsLarge;

    [Test]
    procedure Parse_Integral_IsLargeWithoutLimits;

    [Test]
    procedure Parse_TextCommand_KeepsSpaces;

    [Test]
    procedure Parse_MatrixEnvironment_YieldsRowsCellsAndDelimiters;

    [Test]
    procedure Parse_CasesEnvironment_AlignsLeft;

    [Test]
    procedure Parse_AlignedEnvironment_AlternatesAlignment;

    [Test]
    procedure Parse_TopLevelLineBreak_YieldsColumnOfLines;

    [Test]
    procedure Parse_ThinSpace_YieldsSpaceNode;

    [Test]
    procedure Parse_Mathbb_YieldsStyledDoubleStruck;

    [Test]
    procedure Parse_EmptySource_YieldsEmptyRow;
  end;

implementation

uses
  System.SysUtils;

class function TMathSyntaxTests.Parse(const Source: string): IMathNode;
begin
  Result := TMathParser.Parse(Source);
end;

procedure TMathSyntaxTests.Parse_LettersAndPlus_YieldsClassifiedSymbols;
begin
  const Row = Parse('x+y');

  Assert.AreEqual(3, Row.ChildCount);
  Assert.AreEqual<TMathAtomClass>(TMathAtomClass.Ordinary, Row.Children[0].AtomClass);
  Assert.AreEqual<TMathAtomClass>(TMathAtomClass.Binary, Row.Children[1].AtomClass);
  Assert.AreEqual<TMathFontVariant>(TMathFontVariant.Italic, Row.Children[0].Variant);
  Assert.AreEqual<TMathFontVariant>(TMathFontVariant.Upright, Row.Children[1].Variant);
end;

procedure TMathSyntaxTests.Parse_Digits_MergeIntoOneUprightSymbol;
begin
  const Row = Parse('123x');

  Assert.AreEqual(2, Row.ChildCount);
  Assert.AreEqual('123', Row.Children[0].Text);
  Assert.AreEqual<TMathFontVariant>(TMathFontVariant.Upright, Row.Children[0].Variant);
end;

procedure TMathSyntaxTests.Parse_Fraction_HoldsNumeratorAndDenominator;
begin
  const Row = Parse('\frac{a+b}{2}');

  const Fraction = Row.Children[0];
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Fraction, Fraction.Kind);
  Assert.AreEqual(3, Fraction.Children[0].ChildCount);
  Assert.AreEqual('2', Fraction.Children[1].Children[0].Text);
  Assert.IsTrue(Fraction.HasRule);
end;

procedure TMathSyntaxTests.Parse_SubscriptAndSuperscript_FillBothScriptSlots;
begin
  const Row = Parse('x_i^2');

  const Script = Row.Children[0];
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Script, Script.Kind);
  Assert.AreEqual('x', Script.Children[0].Text);
  Assert.AreEqual('2', Script.Children[1].Text);
  Assert.AreEqual('i', Script.Children[2].Text);
end;

procedure TMathSyntaxTests.Parse_Prime_BecomesSuperscript;
begin
  const Row = Parse('f''(x)');

  const Script = Row.Children[0];
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Script, Script.Kind);
  Assert.AreEqual(#$2032, Script.Children[1].Text);
  Assert.IsTrue(Script.Children[2].IsEmpty);
end;

procedure TMathSyntaxTests.Parse_RadicalWithIndex_KeepsIndex;
begin
  const Row = Parse('\sqrt[3]{x}');

  const Radical = Row.Children[0];
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Radical, Radical.Kind);
  Assert.AreEqual('x', Radical.Children[0].Children[0].Text);
  Assert.AreEqual('3', Radical.Children[1].Children[0].Text);
end;

procedure TMathSyntaxTests.Parse_LeftRight_YieldsDelimitedGroup;
begin
  const Row = Parse('\left( \frac{a}{b} \right]');

  const Delimited = Row.Children[0];
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Delimited, Delimited.Kind);
  Assert.AreEqual('(', Delimited.LeftDelimiter);
  Assert.AreEqual(']', Delimited.RightDelimiter);
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Fraction, Delimited.Children[0].Children[0].Kind);
end;

procedure TMathSyntaxTests.Parse_UnclosedGroup_ClosesAtEnd;
begin
  const Row = Parse('{a+b');

  Assert.AreEqual(1, Row.ChildCount);
  Assert.AreEqual(3, Row.Children[0].ChildCount);
end;

procedure TMathSyntaxTests.Parse_StrayClosingBrace_IsDropped;
begin
  const Row = Parse('a}b');

  Assert.AreEqual(2, Row.ChildCount);
  Assert.AreEqual('b', Row.Children[1].Text);
end;

procedure TMathSyntaxTests.Parse_UnknownCommand_BecomesErrorSymbol;
begin
  const Row = Parse('\nosuchthing');

  Assert.IsTrue(Row.Children[0].IsError);
  Assert.AreEqual('\nosuchthing', Row.Children[0].Text);
end;

procedure TMathSyntaxTests.Parse_GreekCommand_MapsToUnicode;
begin
  const Row = Parse('\alpha\Omega');

  Assert.AreEqual(#$03B1, Row.Children[0].Text);
  Assert.AreEqual<TMathFontVariant>(TMathFontVariant.Italic, Row.Children[0].Variant);
  Assert.AreEqual(#$03A9, Row.Children[1].Text);
  Assert.AreEqual<TMathFontVariant>(TMathFontVariant.Upright, Row.Children[1].Variant);
end;

procedure TMathSyntaxTests.Parse_Sum_TakesLimitsAndIsLarge;
begin
  const Row = Parse('\sum_{i=1}^n');

  const Base = Row.Children[0].Children[0];
  Assert.AreEqual(#$2211, Base.Text);
  Assert.IsTrue(Base.TakesLimits);
  Assert.IsTrue(Base.IsLarge);
end;

procedure TMathSyntaxTests.Parse_Integral_IsLargeWithoutLimits;
begin
  const Row = Parse('\int');

  Assert.IsTrue(Row.Children[0].IsLarge);
  Assert.IsFalse(Row.Children[0].TakesLimits);
end;

procedure TMathSyntaxTests.Parse_TextCommand_KeepsSpaces;
begin
  const Row = Parse('\text{for all }x');

  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Text, Row.Children[0].Kind);
  Assert.AreEqual('for all ', Row.Children[0].Text);
end;

procedure TMathSyntaxTests.Parse_MatrixEnvironment_YieldsRowsCellsAndDelimiters;
begin
  const Row = Parse('\begin{pmatrix} a & b \\ c & d \end{pmatrix}');

  const Matrix = Row.Children[0];
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Matrix, Matrix.Kind);
  Assert.AreEqual(2, Matrix.ChildCount);
  Assert.AreEqual(2, Matrix.Children[1].ChildCount);
  Assert.AreEqual('d', Matrix.Children[1].Children[1].Children[0].Text);
  Assert.AreEqual('(', Matrix.LeftDelimiter);
  Assert.AreEqual(')', Matrix.RightDelimiter);
end;

procedure TMathSyntaxTests.Parse_CasesEnvironment_AlignsLeft;
begin
  const Row = Parse('\begin{cases} x & x > 0 \\ 0 & \text{otherwise} \end{cases}');

  const Matrix = Row.Children[0];
  Assert.AreEqual<TMathColumnAlignment>(TMathColumnAlignment.Left, Matrix.Alignment);
  Assert.AreEqual('{', Matrix.LeftDelimiter);
  Assert.AreEqual('', Matrix.RightDelimiter);
end;

procedure TMathSyntaxTests.Parse_AlignedEnvironment_AlternatesAlignment;
begin
  const Row = Parse('\begin{aligned} a &= b \\ cc &= d \end{aligned}');

  const Matrix = Row.Children[0];
  Assert.AreEqual<TMathColumnAlignment>(TMathColumnAlignment.Alternate, Matrix.Alignment);
  Assert.AreEqual(2, Matrix.ChildCount);
end;

procedure TMathSyntaxTests.Parse_TopLevelLineBreak_YieldsColumnOfLines;
begin
  const Column = Parse('a = b \\ c = d');

  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Matrix, Column.Kind);
  Assert.AreEqual(2, Column.ChildCount);
  Assert.AreEqual(3, Column.Children[0].Children[0].ChildCount);
end;

procedure TMathSyntaxTests.Parse_ThinSpace_YieldsSpaceNode;
begin
  const Row = Parse('a\,b');

  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Space, Row.Children[1].Kind);
  Assert.AreEqual(3 / 18, Row.Children[1].SpaceWidth, 0.0001);
end;

procedure TMathSyntaxTests.Parse_Mathbb_YieldsStyledDoubleStruck;
begin
  const Row = Parse('\mathbb{R}');

  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Styled, Row.Children[0].Kind);
  Assert.AreEqual<TMathFontVariant>(TMathFontVariant.DoubleStruck, Row.Children[0].Variant);
  Assert.AreEqual('R', Row.Children[0].Children[0].Children[0].Text);
end;

procedure TMathSyntaxTests.Parse_EmptySource_YieldsEmptyRow;
begin
  const Row = Parse('');

  Assert.IsTrue(Row.IsEmpty);
end;

end.
