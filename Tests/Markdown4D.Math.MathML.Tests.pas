unit Markdown4D.Math.MathML.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMathMLFormatTests = class
  private
    class function Body(const Source: string): string; static;
  public
    [Test]
    [TestCase('Identifier and number', 'x+1,<mi>x</mi><mo>+</mo><mn>1</mn>')]
    [TestCase('Fraction', '\frac{a}{b},<mfrac><mrow><mi>a</mi></mrow><mrow><mi>b</mi></mrow></mfrac>')]
    [TestCase('Power', 'x^2,<msup><mi>x</mi><mrow><mn>2</mn></mrow></msup>')]
    [TestCase('Square root', '\sqrt{x},<msqrt><mrow><mi>x</mi></mrow></msqrt>')]
    [TestCase('Operator name', '\sin x,<mi>sin</mi><mi>x</mi>')]
    [TestCase('Text', '\text{if},<mtext>if</mtext>')]
    procedure FromSource_WritesPresentationMathML(const Source, Expected: string);

    [Test]
    procedure FromSource_Sum_PutsLimitsUnderAndOver;

    [Test]
    procedure FromSource_KeepsTeXAsAnnotation;

    [Test]
    procedure FromSource_Display_SetsBlock;

    [Test]
    procedure FromSource_Href_LinksTheRow;

    [Test]
    procedure FromSource_EscapesMarkup;

    [Test]
    procedure FromSource_Array_WritesAlignmentAndRules;

    [Test]
    procedure FromSource_ArrayRuledAboveAndBelow_EnclosesThoseSides;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Math.MathML;

// What sits between the opening of the formula's row and the annotation.
class function TMathMLFormatTests.Body(const Source: string): string;
begin
  const MathML = TMathMLFormat.FromSource(Source, False);
  const Opening = '<semantics><mrow>';
  const Start = MathML.IndexOf(Opening) + Length(Opening);
  const Stop = MathML.IndexOf('</mrow><annotation');
  Result := MathML.Substring(Start, Stop - Start);
end;

procedure TMathMLFormatTests.FromSource_WritesPresentationMathML(const Source, Expected: string);
begin
  Assert.AreEqual(Expected, Body(Source));
end;

procedure TMathMLFormatTests.FromSource_Sum_PutsLimitsUnderAndOver;
begin
  Assert.StartsWith('<munderover><mo>' + #$2211 + '</mo>', Body('\sum_{i=1}^{n} i'));
end;

procedure TMathMLFormatTests.FromSource_KeepsTeXAsAnnotation;
begin
  Assert.Contains(TMathMLFormat.FromSource('x^2', False),
    '<annotation encoding="application/x-tex">x^2</annotation>');
end;

procedure TMathMLFormatTests.FromSource_Display_SetsBlock;
begin
  Assert.StartsWith('<math xmlns="http://www.w3.org/1998/Math/MathML" display="block">',
    TMathMLFormat.FromSource('x', True));
  Assert.StartsWith('<math xmlns="http://www.w3.org/1998/Math/MathML">', TMathMLFormat.FromSource('x', False));
end;

procedure TMathMLFormatTests.FromSource_Href_LinksTheRow;
begin
  Assert.AreEqual('<mrow href="https://example.com"><mi>x</mi></mrow>', Body('\href{https://example.com}{x}'));
end;

procedure TMathMLFormatTests.FromSource_Array_WritesAlignmentAndRules;
begin
  const MathML = Body('\begin{array}{|l|r|} \hline a & b \\ \hline c & d \\ \hline \end{array}');

  Assert.StartsWith('<mtable columnalign="left right" columnlines="solid" rowlines="solid" frame="solid">', MathML);
  Assert.AreEqual(2, (MathML.Length - MathML.Replace('<mtr>', '').Length) div Length('<mtr>'), 'two rows');
end;

procedure TMathMLFormatTests.FromSource_ArrayRuledAboveAndBelow_EnclosesThoseSides;
begin
  const MathML = Body('\begin{array}{cc} \hline a & b \\ c & d \\ \hline \end{array}');

  Assert.StartsWith('<menclose notation="top bottom"><mtable columnalign="center center"', MathML);
end;

procedure TMathMLFormatTests.FromSource_EscapesMarkup;
begin
  Assert.AreEqual('<mi>a</mi><mo>&lt;</mo><mi>b</mi>', Body('a<b'));
end;

end.
