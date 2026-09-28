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
    const
      MinusGlyph = #$2212;
      AsteriskGlyph = #$2217;
      CentredDotGlyph = #$22C5;
      EllipsisGlyph = #$2026;
      DeepNesting = 1000;
      ShallowTreeDepth = 100;
    class function Parse(const Source: string): IMathNode;
    class function Chemistry(const Source: string): IMathNode;
    class function StyledLetters(const Node: IMathNode): string;
    class function FindText(const Node: IMathNode; const Text: string): IMathNode;
    class function TreeDepth(const Node: IMathNode): Integer;

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

    [Test]
    procedure Parse_ChemistryFormula_SubscriptsElementCounts;

    [Test]
    procedure Parse_ChemistryCoefficient_StaysALeadingNumber;

    [Test]
    procedure Parse_ChemistryCoefficient_KeepsADecimalPoint;

    [Test]
    procedure Parse_ChemistryCharge_SuperscriptsTheLastAtom;

    [Test]
    procedure Parse_ChemistryGroupCount_SubscriptsTheGroup;

    [Test]
    procedure Parse_ChemistryBracketCharge_SuperscriptsTheGroup;

    [Test]
    procedure Parse_ChemistryIsotope_StandsBeforeTheElement;

    [Test]
    procedure Parse_ChemistryIsotope_StacksMassOverAtomicNumber;

    [Test]
    procedure Parse_ChemistryUnbracedLetterScript_KeepsTheSubscript;

    [Test]
    procedure Parse_ChemistryScriptCommand_KeepsTheCommand;

    [Test]
    procedure Parse_ChemistryReaction_UsesAnArrow;

    [Test]
    procedure Parse_ChemistryReaction_LeavesSpacingToTheLayouter;

    [Test]
    procedure Parse_ChemistryReverseReaction_UsesALeftArrow;

    [Test]
    procedure Parse_ChemistryResonance_UsesADoubleArrow;

    [Test]
    procedure Parse_ChemistryEquilibrium_UsesAnEquilibriumArrow;

    [Test]
    procedure Parse_ChemistrySingleBond_StaysAnUprightHyphen;

    [Test]
    procedure Parse_ChemistryDoubleBond_StaysAnUprightEquals;

    [Test]
    procedure Parse_ChemistryTripleBond_BecomesAnOrdinaryEquivalence;

    [Test]
    procedure Parse_ChemistryState_StaysUprightText;

    [Test]
    procedure Parse_ChemistryIonWithState_KeepsTheCharge;

    [Test]
    procedure Parse_ChemistryCapitalInParentheses_StaysAGroup;

    [Test]
    procedure Parse_ChemistryHydrateDot_UsesACentredDot;

    [Test]
    procedure Parse_ChemistryHydrateAsterisk_UsesACentredDot;

    [Test]
    procedure Parse_ChemistryEscapedBrace_StaysBalanced;

    [Test]
    procedure Parse_ChemistryUnknownCommand_BecomesErrorSymbol;

    [Test]
    procedure Parse_ChemistryInsideFormula_JoinsTheRow;

    [Test]
    procedure Parse_ChemistryUnclosedGroup_KeepsTheFormula;

    [Test]
    procedure Parse_ChemistryEmptyGroup_YieldsEmptyRow;

    [Test]
    procedure Parse_ChemistryInsideChemistry_LowersBoth;

    [Test]
    procedure Parse_ChemistryDeepGroups_StopAtTheCap;

    [Test]
    procedure Parse_ChemistryDeepCommands_StopAtTheCap;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.StrUtils;

class function TMathSyntaxTests.Parse(const Source: string): IMathNode;
begin
  Result := TMathParser.Parse(Source);
end;

class function TMathSyntaxTests.Chemistry(const Source: string): IMathNode;
begin
  Result := Parse('\ce{' + Source + '}').Children[0];
end;

// The letters under \mathrm, looking through a script to its base.
class function TMathSyntaxTests.StyledLetters(const Node: IMathNode): string;
begin
  Result := '';

  if Node.Kind = TMathNodeKind.Script then
  begin
    Result := StyledLetters(Node.Children[0]);
    Exit;
  end;

  if Node.Kind <> TMathNodeKind.Styled then
    Exit;

  const Body = Node.Children[0];
  for var Index := 0 to Body.ChildCount - 1 do
    Result := Result + Body.Children[Index].Text;
end;

class function TMathSyntaxTests.FindText(const Node: IMathNode; const Text: string): IMathNode;
begin
  if Node.Text = Text then
  begin
    Result := Node;
    Exit;
  end;

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    Result := FindText(Node.Children[Index], Text);
    if Result <> nil then
      Exit;
  end;

  Result := nil;
end;

class function TMathSyntaxTests.TreeDepth(const Node: IMathNode): Integer;
begin
  Result := 1;
  for var Index := 0 to Node.ChildCount - 1 do
    Result := Max(Result, 1 + TreeDepth(Node.Children[Index]));
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

procedure TMathSyntaxTests.Parse_ChemistryFormula_SubscriptsElementCounts;
begin
  const Row = Chemistry('H2O');

  Assert.AreEqual(2, Row.ChildCount);
  Assert.AreEqual('H', StyledLetters(Row.Children[0]));
  Assert.AreEqual('2', Row.Children[0].Children[2].Children[0].Text);
  Assert.AreEqual('O', StyledLetters(Row.Children[1]));
  Assert.IsFalse(Row.Children[0].IsError);
end;

procedure TMathSyntaxTests.Parse_ChemistryCoefficient_StaysALeadingNumber;
begin
  const Row = Chemistry('2H2O');

  Assert.AreEqual('2', Row.Children[0].Text);
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Space, Row.Children[1].Kind);
  Assert.AreEqual('H', StyledLetters(Row.Children[2]));
  Assert.AreEqual('2', Row.Children[2].Children[2].Children[0].Text);
end;

procedure TMathSyntaxTests.Parse_ChemistryCoefficient_KeepsADecimalPoint;
begin
  const Row = Chemistry('2.5H2O');

  Assert.AreEqual('2', Row.Children[0].Text);
  Assert.IsNotNull(FindText(Row, '.'));
  Assert.IsNull(FindText(Row, CentredDotGlyph));
end;

procedure TMathSyntaxTests.Parse_ChemistryCharge_SuperscriptsTheLastAtom;
begin
  const Row = Chemistry('SO4^2-');

  const Oxygen = Row.Children[1];
  Assert.AreEqual('O', StyledLetters(Oxygen));
  Assert.AreEqual('4', Oxygen.Children[2].Children[0].Text);
  Assert.AreEqual('2', Oxygen.Children[1].Children[0].Text);
  Assert.AreEqual(MinusGlyph, Oxygen.Children[1].Children[1].Text);
end;

procedure TMathSyntaxTests.Parse_ChemistryGroupCount_SubscriptsTheGroup;
begin
  const Row = Chemistry('Ca3(PO4)2');

  const Group = Row.Children[1];
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Script, Group.Kind);
  Assert.AreEqual('(', Group.Children[0].Children[0].Text);
  Assert.AreEqual('2', Group.Children[2].Children[0].Text);
end;

procedure TMathSyntaxTests.Parse_ChemistryBracketCharge_SuperscriptsTheGroup;
begin
  const Row = Chemistry('[AgCl2]-');

  Assert.AreEqual(1, Row.ChildCount);
  const Complex = Row.Children[0];
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Script, Complex.Kind);
  Assert.AreEqual('[', Complex.Children[0].Children[0].Text);
  Assert.AreEqual(MinusGlyph, Complex.Children[1].Children[0].Text);
end;

procedure TMathSyntaxTests.Parse_ChemistryIsotope_StandsBeforeTheElement;
begin
  const Row = Chemistry('^{14}C');

  const Isotope = Row.Children[0];
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Script, Isotope.Kind);
  Assert.IsTrue(Isotope.Children[0].IsEmpty);
  Assert.AreEqual('14', Isotope.Children[1].Children[0].Text);
  Assert.AreEqual('C', StyledLetters(Row.Children[1]));
end;

procedure TMathSyntaxTests.Parse_ChemistryIsotope_StacksMassOverAtomicNumber;
begin
  const Row = Chemistry('^{227}_{90}Th');

  const Isotope = Row.Children[0];
  Assert.IsTrue(Isotope.Children[0].IsEmpty);
  Assert.AreEqual('227', Isotope.Children[1].Children[0].Text);
  Assert.AreEqual('90', Isotope.Children[2].Children[0].Text);
  Assert.AreEqual('Th', StyledLetters(Row.Children[1]));
end;

procedure TMathSyntaxTests.Parse_ChemistryUnbracedLetterScript_KeepsTheSubscript;
begin
  const Row = Chemistry('Fe_xO');

  Assert.AreEqual(2, Row.ChildCount);
  Assert.AreEqual('Fe', StyledLetters(Row.Children[0]));
  Assert.AreEqual('x', StyledLetters(Row.Children[0].Children[2].Children[0]));
end;

procedure TMathSyntaxTests.Parse_ChemistryScriptCommand_KeepsTheCommand;
begin
  const Formula = Parse('\ce{X^{\bullet}}');

  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Row, Formula.Kind);
  const Species = Formula.Children[0].Children[0];
  Assert.AreEqual(#$2219, Species.Children[1].Children[0].Text);
  Assert.IsFalse(Species.Children[1].Children[0].IsError);
end;

procedure TMathSyntaxTests.Parse_ChemistryReaction_UsesAnArrow;
begin
  const Arrow = FindText(Chemistry('2H2 + O2 -> 2H2O'), #$2192);

  Assert.IsNotNull(Arrow);
  Assert.AreEqual<TMathAtomClass>(TMathAtomClass.Relation, Arrow.AtomClass);
end;

procedure TMathSyntaxTests.Parse_ChemistryReaction_LeavesSpacingToTheLayouter;
begin
  const Row = Chemistry('A + B');

  Assert.AreEqual(3, Row.ChildCount);
  Assert.AreEqual<TMathAtomClass>(TMathAtomClass.Binary, Row.Children[1].AtomClass);
end;

procedure TMathSyntaxTests.Parse_ChemistryReverseReaction_UsesALeftArrow;
begin
  Assert.IsNotNull(FindText(Chemistry('2NH3 <- N2 + 3H2'), #$2190));
end;

procedure TMathSyntaxTests.Parse_ChemistryResonance_UsesADoubleArrow;
begin
  Assert.IsNotNull(FindText(Chemistry('A <-> B'), #$2194));
end;

procedure TMathSyntaxTests.Parse_ChemistryEquilibrium_UsesAnEquilibriumArrow;
begin
  Assert.IsNotNull(FindText(Chemistry('H2 <=> H + H'), #$21CC));
end;

procedure TMathSyntaxTests.Parse_ChemistrySingleBond_StaysAnUprightHyphen;
begin
  const Row = Chemistry('CH3-CH2-OH');

  const Bond = FindText(Row, '-');
  Assert.IsNotNull(Bond);
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Text, Bond.Kind);
  Assert.IsNull(FindText(Row, MinusGlyph));
end;

procedure TMathSyntaxTests.Parse_ChemistryDoubleBond_StaysAnUprightEquals;
begin
  const Bond = FindText(Chemistry('C=C'), '=');

  Assert.IsNotNull(Bond);
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Text, Bond.Kind);
end;

procedure TMathSyntaxTests.Parse_ChemistryTripleBond_BecomesAnOrdinaryEquivalence;
begin
  const Bond = FindText(Chemistry('C#N'), #$2261);

  Assert.IsNotNull(Bond);
  Assert.AreEqual<TMathAtomClass>(TMathAtomClass.Ordinary, Bond.AtomClass);
end;

procedure TMathSyntaxTests.Parse_ChemistryState_StaysUprightText;
begin
  const State = FindText(Chemistry('NaCl(aq)'), '(aq)');

  Assert.IsNotNull(State);
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Text, State.Kind);
end;

procedure TMathSyntaxTests.Parse_ChemistryIonWithState_KeepsTheCharge;
begin
  const Row = Chemistry('Cl-(aq)');

  Assert.AreEqual('Cl', StyledLetters(Row.Children[0]));
  Assert.AreEqual(MinusGlyph, Row.Children[0].Children[1].Children[0].Text);
  Assert.IsNotNull(FindText(Row, '(aq)'));
end;

procedure TMathSyntaxTests.Parse_ChemistryCapitalInParentheses_StaysAGroup;
begin
  const Row = Chemistry('Fe(S)');

  Assert.IsNull(FindText(Row, '(S)'));
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Row, Row.Children[1].Kind);
  Assert.AreEqual('(', Row.Children[1].Children[0].Text);
end;

procedure TMathSyntaxTests.Parse_ChemistryHydrateDot_UsesACentredDot;
begin
  Assert.IsNotNull(FindText(Chemistry('CuSO4.5H2O'), CentredDotGlyph));
end;

procedure TMathSyntaxTests.Parse_ChemistryHydrateAsterisk_UsesACentredDot;
begin
  const Row = Chemistry('CuSO4*5H2O');

  Assert.IsNotNull(FindText(Row, CentredDotGlyph));
  Assert.IsNull(FindText(Row, AsteriskGlyph));
end;

procedure TMathSyntaxTests.Parse_ChemistryEscapedBrace_StaysBalanced;
begin
  const Row = Chemistry('\{x\}');

  Assert.AreEqual(3, Row.ChildCount);
  Assert.AreEqual('{', Row.Children[0].Text);
  Assert.AreEqual('x', StyledLetters(Row.Children[1]));
  Assert.AreEqual('}', Row.Children[2].Text);
end;

procedure TMathSyntaxTests.Parse_ChemistryUnknownCommand_BecomesErrorSymbol;
begin
  const Row = Chemistry('\nope');

  Assert.IsTrue(Row.Children[0].IsError);
  Assert.AreEqual('\nope', Row.Children[0].Text);
end;

procedure TMathSyntaxTests.Parse_ChemistryInsideFormula_JoinsTheRow;
begin
  const Row = Parse('x + \ce{H2O}');

  Assert.AreEqual(3, Row.ChildCount);
  Assert.AreEqual<TMathNodeKind>(TMathNodeKind.Row, Row.Children[2].Kind);
  Assert.AreEqual('H', StyledLetters(Row.Children[2].Children[0]));
end;

procedure TMathSyntaxTests.Parse_ChemistryUnclosedGroup_KeepsTheFormula;
begin
  const Row = Parse('\ce{H2').Children[0];

  Assert.AreEqual('H', StyledLetters(Row.Children[0]));
  Assert.AreEqual('2', Row.Children[0].Children[2].Children[0].Text);
end;

procedure TMathSyntaxTests.Parse_ChemistryEmptyGroup_YieldsEmptyRow;
begin
  Assert.IsTrue(Chemistry('').IsEmpty);
end;

procedure TMathSyntaxTests.Parse_ChemistryInsideChemistry_LowersBoth;
begin
  const Inner = Chemistry('\ce{H2O}').Children[0];

  Assert.AreEqual('H', StyledLetters(Inner.Children[0]));
  Assert.AreEqual('O', StyledLetters(Inner.Children[1]));
end;

procedure TMathSyntaxTests.Parse_ChemistryDeepGroups_StopAtTheCap;
begin
  const Row = Chemistry(StringOfChar('(', DeepNesting) + 'H' + StringOfChar(')', DeepNesting));

  Assert.IsTrue(TreeDepth(Row) < ShallowTreeDepth);
  Assert.IsNotNull(FindText(Row, EllipsisGlyph));
end;

procedure TMathSyntaxTests.Parse_ChemistryDeepCommands_StopAtTheCap;
begin
  const Formula = Parse(DupeString('\ce{', DeepNesting) + 'H' + DupeString('}', DeepNesting));

  Assert.IsTrue(TreeDepth(Formula) < ShallowTreeDepth);
  const Cut = FindText(Formula, '\ce');
  Assert.IsNotNull(Cut);
  Assert.IsTrue(Cut.IsError);
end;

end.
