unit Markdown4D.Math.Linear.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMathLinearFormatTests = class
  public
    [Test]
    [TestCase('Letters and operators', 'a+b=c,a+b=c')]
    [TestCase('Fraction of atoms', '\frac{a}{b},a/b')]
    [TestCase('Fraction of sums', '\frac{a+1}{b-1},(a+1)/(b'#$2212'1)')]
    [TestCase('Power of digits', 'x^2,x'#$00B2)]
    [TestCase('Power of a number', 'x^{10},x'#$00B9#$2070)]
    [TestCase('Negative power', 'x^{-1},x'#$207B#$00B9)]
    [TestCase('Power of a sum', 'e^{i\pi},e^(i'#$03C0')')]
    [TestCase('Index of digits', 'a_1,a'#$2081)]
    [TestCase('Index and power', 'a_i^2,a_i'#$00B2)]
    [TestCase('Square root', '\sqrt{x},'#$221A'x')]
    [TestCase('Root of a sum', '\sqrt{x+1},'#$221A'(x+1)')]
    [TestCase('Cube root', '\sqrt[3]{x},'#$221B'x')]
    [TestCase('Root with index', '\sqrt[n]{x},'#$221A'(n&x)')]
    [TestCase('Greek', '\alpha\beta,'#$03B1#$03B2)]
    [TestCase('Prime', 'f'',f'#$2032)]
    procedure FromSource_WritesUnicodeMath(const Source, Expected: string);

    [Test]
    procedure FromSource_Sum_WritesLimitsAsScripts;

    [Test]
    procedure FromSource_OperatorName_KeepsSpaceBeforeArgument;

    [Test]
    procedure FromSource_Binomial_StacksWithBrokenBar;

    [Test]
    procedure FromSource_Matrix_WritesRowsAndCells;

    [Test]
    procedure FromSource_LinesOfDisplayFormula_StayLines;

    [Test]
    procedure FromSource_Href_WritesShownTextOnly;

    [Test]
    procedure FromSource_Url_WritesAddressOnce;

    [Test]
    procedure FromSource_Text_KeepsWords;

    [Test]
    procedure FromSource_Accent_UsesCombiningMark;

    [Test]
    procedure PlainText_MathematicalAlphabets_FoldToLetters;

    [Test]
    procedure PlainText_LetterlikeSymbols_FoldToLetters;
  end;

implementation

uses
  Markdown4D.Math.Linear;

procedure TMathLinearFormatTests.FromSource_WritesUnicodeMath(const Source, Expected: string);
begin
  Assert.AreEqual(Expected, TMathLinearFormat.FromSource(Source));
end;

procedure TMathLinearFormatTests.FromSource_Sum_WritesLimitsAsScripts;
begin
  Assert.AreEqual(#$2211'_(i=1)^n i', TMathLinearFormat.FromSource('\sum_{i=1}^{n} i'));
end;

procedure TMathLinearFormatTests.FromSource_OperatorName_KeepsSpaceBeforeArgument;
begin
  Assert.AreEqual('sin x', TMathLinearFormat.FromSource('\sin x'));
end;

procedure TMathLinearFormatTests.FromSource_Binomial_StacksWithBrokenBar;
begin
  Assert.AreEqual('(n'#$00A6'k)', TMathLinearFormat.FromSource('\binom{n}{k}'));
end;

procedure TMathLinearFormatTests.FromSource_Matrix_WritesRowsAndCells;
begin
  Assert.AreEqual('('#$25A0'(a&b@c&d))', TMathLinearFormat.FromSource('\begin{pmatrix}a&b\\c&d\end{pmatrix}'));
end;

procedure TMathLinearFormatTests.FromSource_LinesOfDisplayFormula_StayLines;
begin
  Assert.AreEqual('a=1'#10'b=2', TMathLinearFormat.FromSource('a=1\\b=2'));
end;

procedure TMathLinearFormatTests.FromSource_Href_WritesShownTextOnly;
begin
  Assert.AreEqual('a+x', TMathLinearFormat.FromSource('a+\href{https://example.com}{x}'));
end;

procedure TMathLinearFormatTests.FromSource_Url_WritesAddressOnce;
begin
  Assert.AreEqual('example.com', TMathLinearFormat.FromSource('\url{example.com}'));
end;

procedure TMathLinearFormatTests.FromSource_Text_KeepsWords;
begin
  Assert.AreEqual('x if y', TMathLinearFormat.FromSource('x \text{ if } y'));
end;

procedure TMathLinearFormatTests.FromSource_Accent_UsesCombiningMark;
begin
  Assert.AreEqual('x'#$0302, TMathLinearFormat.FromSource('\hat{x}'));
end;

procedure TMathLinearFormatTests.PlainText_MathematicalAlphabets_FoldToLetters;
begin
  // Bold A, italic x, double-struck 1, monospace z, bold alpha.
  Assert.AreEqual('Ax1z'#$03B1,
    TMathLinearFormat.PlainText(#$D835#$DC00#$D835#$DC65#$D835#$DFD9#$D835#$DEA3#$D835#$DEC2));
end;

procedure TMathLinearFormatTests.PlainText_LetterlikeSymbols_FoldToLetters;
begin
  Assert.AreEqual('RCh', TMathLinearFormat.PlainText(#$211D#$2102#$210E));
end;

end.
