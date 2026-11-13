unit Markdown4D.Math.UnicodeMath.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TUnicodeMathFormatTests = class
  private
    const
      PlusMinus = #$00B1;
      SquareRoot = #$221A;
      CubeRoot = #$221B;
      Sum = #$2211;
      Infinity = #$221E;
      RightArrow = #$2192;
      Prime = #$2032;
      CombiningCircumflex = #$0302;
      Overbar = #$00AF;
      BrokenBar = #$00A6;
      MatrixMark = #$25A0;
      EquationArrayMark = #$2588;
      Tab = #9;
  public
    [Test]
    [TestCase('Letters and signs', 'a+b=c,a+b=c')]
    [TestCase('Minus', 'a-b,a-b')]
    [TestCase('Fraction', '\frac{a}{b},a/b')]
    [TestCase('Fraction of words', '\frac{df}{dx},df/dx')]
    [TestCase('Fraction of more than a word', '\frac{a+b}{c},(a+b)/c')]
    [TestCase('Fraction of powers', '\frac{x^2}{y^2},x^2/y^2')]
    [TestCase('Fraction in a fraction', '\frac{\frac{1}{2}}{3},(1/2)/3')]
    [TestCase('Fraction before a letter', '\frac{1}{2}x,1/2 x')]
    [TestCase('Power', 'x^2,x^2')]
    [TestCase('Power of a word', 'e^{2x},e^2x')]
    [TestCase('Power of more than a word', 'e^{-x},e^(-x)')]
    [TestCase('Power of more than a letter', '{ab}^2,(ab)^2')]
    [TestCase('Power before a letter', 'x^2y,x^2 y')]
    [TestCase('Subscript', 'a_{i+1},a_(i+1)')]
    [TestCase('Subscript and superscript', 'x_i^2,x_i^2')]
    [TestCase('Operator name', '\sin x,sin x')]
    [TestCase('Operator name before a bracket', '\cos(x),cos(x)')]
    [TestCase('Operator name after a letter', 'x\sin x,x sin x')]
    [TestCase('Operator name with a subscript', '\log_2 n,log_2 n')]
    [TestCase('Text', '\text{speed}=v,speed=v')]
    [TestCase('Space', 'a\quad b,a b')]
    [TestCase('Styled letter', '\mathbf{x},x')]
    [TestCase('Coloured letter', '\color{red}{x},x')]
    procedure FromSource_WritesLinearText(const Source, Expected: string);

    [Test]
    procedure FromSource_QuadraticFormula_ReadsAsWordWritesIt;

    [Test]
    procedure FromSource_SquareRoot_CoversAWordOrABracket;

    [Test]
    procedure FromSource_RootWithIndex_HoldsIndexAndRadicand;

    [Test]
    procedure FromSource_CubeRoot_HasItsOwnSign;

    [Test]
    procedure FromSource_Sum_SetsItsLimitsAndWhatItSumsApart;

    [Test]
    procedure FromSource_Limit_SetsWhatItAppliesToApart;

    [Test]
    procedure FromSource_Accent_FollowsItsLetter;

    [Test]
    procedure FromSource_Overline_IsAnOverbarBeforeItsBody;

    [Test]
    procedure FromSource_Prime_FollowsItsBase;

    [Test]
    procedure FromSource_Binomial_StacksWithoutARule;

    [Test]
    procedure FromSource_MatrixInBrackets_IsCellsAndRowsAfterTheMatrixMark;

    [Test]
    procedure FromSource_Cases_IsAnEquationArray;

    [Test]
    procedure FromSource_AlignedEquations_AreAnEquationArray;

    [Test]
    procedure FromSource_DelimiterNotDrawn_WritesNone;

    [Test]
    procedure FromSource_Array_IsItsCellsByTabsAndItsRowsByLines;

    [Test]
    procedure FromSource_ArrayCells_AreLinearText;

    [Test]
    [TestCase('Array', '\begin{array}{lr}a&b\\c&d\end{array},True')]
    [TestCase('Tabular', '\begin{tabular}{lr}a&b\\c&d\end{tabular},True')]
    [TestCase('Matrix', '\begin{matrix}a&b\\c&d\end{matrix},True')]
    [TestCase('Matrix in brackets', '\begin{pmatrix}a&b\\c&d\end{pmatrix},False')]
    [TestCase('Matrix in a formula', 'A=\begin{matrix}a&b\\c&d\end{matrix},False')]
    [TestCase('Array of one column', '\begin{array}{l}a\\b\end{array},True')]
    [TestCase('Matrix of one column', '\begin{matrix}a\\b\end{matrix},False')]
    [TestCase('Aligned equations', '\begin{aligned}x&=1\\y&=2\end{aligned},False')]
    [TestCase('Gathered equations', '\begin{gathered}x=1\\y=2\end{gathered},False')]
    [TestCase('Lines', 'x=1\\y=2,False')]
    [TestCase('No matrix', 'x^2,False')]
    procedure IsTable_OnlyForATableAlone(const Source: string; const Expected: Boolean);
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Math.UnicodeMath;

procedure TUnicodeMathFormatTests.FromSource_WritesLinearText(const Source, Expected: string);
begin
  Assert.AreEqual(Expected, TUnicodeMathFormat.FromSource(Source));
end;

procedure TUnicodeMathFormatTests.FromSource_QuadraticFormula_ReadsAsWordWritesIt;
begin
  const Text = TUnicodeMathFormat.FromSource('x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}');

  Assert.AreEqual('x=(-b' + PlusMinus + SquareRoot + '(b^2-4ac))/2a', Text);
end;

procedure TUnicodeMathFormatTests.FromSource_SquareRoot_CoversAWordOrABracket;
begin
  Assert.AreEqual(SquareRoot + '2a', TUnicodeMathFormat.FromSource('\sqrt{2a}'));
  Assert.AreEqual(SquareRoot + '(x+1)', TUnicodeMathFormat.FromSource('\sqrt{x+1}'));
end;

procedure TUnicodeMathFormatTests.FromSource_RootWithIndex_HoldsIndexAndRadicand;
begin
  const Text = TUnicodeMathFormat.FromSource('\sqrt[n]{x+1}');

  Assert.AreEqual(SquareRoot + '(n&x+1)', Text);
end;

procedure TUnicodeMathFormatTests.FromSource_CubeRoot_HasItsOwnSign;
begin
  const Text = TUnicodeMathFormat.FromSource('\sqrt[3]{x}');

  Assert.AreEqual(CubeRoot + 'x', Text);
end;

procedure TUnicodeMathFormatTests.FromSource_Sum_SetsItsLimitsAndWhatItSumsApart;
begin
  const Text = TUnicodeMathFormat.FromSource('\sum_{i=1}^{n} i');

  Assert.AreEqual(Sum + '_(i=1)^n i', Text);
end;

procedure TUnicodeMathFormatTests.FromSource_Limit_SetsWhatItAppliesToApart;
begin
  const Text = TUnicodeMathFormat.FromSource('\lim_{n\to\infty} a_n');

  Assert.AreEqual('lim_(n' + RightArrow + Infinity + ') a_n', Text);
end;

procedure TUnicodeMathFormatTests.FromSource_Accent_FollowsItsLetter;
begin
  const Text = TUnicodeMathFormat.FromSource('\hat{x}');

  Assert.AreEqual('x' + CombiningCircumflex, Text);
end;

procedure TUnicodeMathFormatTests.FromSource_Overline_IsAnOverbarBeforeItsBody;
begin
  const Text = TUnicodeMathFormat.FromSource('\overline{a+b}');

  Assert.AreEqual(Overbar + '(a+b)', Text);
end;

procedure TUnicodeMathFormatTests.FromSource_Prime_FollowsItsBase;
begin
  const Text = TUnicodeMathFormat.FromSource('f''(x)');

  Assert.AreEqual('f' + Prime + '(x)', Text);
end;

procedure TUnicodeMathFormatTests.FromSource_Binomial_StacksWithoutARule;
begin
  const Text = TUnicodeMathFormat.FromSource('\binom{n}{k}');

  Assert.AreEqual('(n' + BrokenBar + 'k)', Text);
end;

procedure TUnicodeMathFormatTests.FromSource_MatrixInBrackets_IsCellsAndRowsAfterTheMatrixMark;
begin
  const Text = TUnicodeMathFormat.FromSource('\begin{pmatrix}a&b\\c&d\end{pmatrix}');

  Assert.AreEqual('(' + MatrixMark + '(a&b@c&d))', Text);
end;

procedure TUnicodeMathFormatTests.FromSource_Cases_IsAnEquationArray;
begin
  const Text = TUnicodeMathFormat.FromSource('\begin{cases}1&x>0\\0&\text{otherwise}\end{cases}');

  Assert.AreEqual('{' + EquationArrayMark + '(1&x>0@0&otherwise)', Text);
end;

procedure TUnicodeMathFormatTests.FromSource_AlignedEquations_AreAnEquationArray;
begin
  const Text = TUnicodeMathFormat.FromSource('\begin{aligned}x&=1\\y&=2\end{aligned}');

  Assert.AreEqual(EquationArrayMark + '(x&=1@y&=2)', Text);
end;

procedure TUnicodeMathFormatTests.FromSource_DelimiterNotDrawn_WritesNone;
begin
  const Text = TUnicodeMathFormat.FromSource('\left.\frac{df}{dx}\right|_{x=0}');

  Assert.AreEqual('df/dx|_(x=0)', Text);
end;

// The rules of the table, in its preamble and as \hline, are not text.
procedure TUnicodeMathFormatTests.FromSource_Array_IsItsCellsByTabsAndItsRowsByLines;
begin
  const Source = '\begin{array}{|l|r|}\hline \text{Item} & \text{Amount} \\ \hline \text{Flour} & 500 \\ \hline' +
                 '\end{array}';

  const Text = TUnicodeMathFormat.FromSource(Source);

  Assert.AreEqual('Item' + Tab + 'Amount' + sLineBreak + 'Flour' + Tab + '500', Text);
end;

procedure TUnicodeMathFormatTests.FromSource_ArrayCells_AreLinearText;
begin
  const Text = TUnicodeMathFormat.FromSource('\begin{array}{cc}\frac{1}{2} & x^2\end{array}');

  Assert.AreEqual('1/2' + Tab + 'x^2', Text);
end;

procedure TUnicodeMathFormatTests.IsTable_OnlyForATableAlone(const Source: string; const Expected: Boolean);
begin
  Assert.AreEqual(Expected, TUnicodeMathFormat.IsTable(Source));
end;

end.
