unit Markdown4D.Parser.Math.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Parser.Spec.Corpus;

type
  [TestFixture]
  TMathSpecTests = class
  private
    const
      MathCorpusFileName = 'math.json';
      MathCorpusExampleCount = 34;
    var
      FCorpus: TSpecCorpus;
    procedure VerifySection(const Section: string);
    class function FirstMathNode(const Document: IMarkdownDocument): IMarkdownMath;
    class function CanonicalMarkdown(const Source: string): string;

  public
    [SetupFixture]
    procedure SetupFixture;

    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure Math_Corpus_ContainsAllExamples;

    [Test]
    [TestCase('Inline math', 'Inline math')]
    [TestCase('Display math', 'Display math')]
    [TestCase('Math fence', 'Math fence')]
    procedure Math_Section_MatchesSpec(const Section: string);

    [Test]
    procedure ToHtml_CommonMarkDialect_KeepsDollarsLiteral;

    [Test]
    procedure ToHtml_CommonMarkDialect_KeepsMathFenceAsCode;

    [Test]
    procedure Parse_InlineMath_YieldsInlineNodeWithLiteral;

    [Test]
    procedure Parse_DisplayBlock_YieldsDisplayNode;

    [Test]
    procedure Parse_MathFence_YieldsDisplayNode;

    [Test]
    procedure Parse_InlineDoubleDollar_YieldsDisplayNodeInsideParagraph;

    [Test]
    procedure ToMarkdown_InlineMath_WritesSingleDollars;

    [Test]
    procedure ToMarkdown_InlineDisplayMath_WritesDoubleDollars;

    [Test]
    procedure ToMarkdown_DisplayBlock_WritesDollarFences;

    [Test]
    procedure ToMarkdown_MathFence_WritesDollarFences;

    [Test]
    procedure ToMarkdown_DisplayBlockInBlockQuote_KeepsQuotePrefix;

    [Test]
    procedure ToMarkdown_EscapedDollarInText_RoundTrips;

    [Test]
    procedure ToMarkdown_Corpus_RoundTripsEveryExample;

    [Test]
    procedure Toc_HeadingWithMath_KeepsFormulaSource;

    [Test]
    procedure Builder_Math_RendersInlineSpan;

    [Test]
    procedure Builder_MathBlock_RendersDiv;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Builder,
  Markdown4D.Renderer.Html,
  Markdown4D.Toc;

procedure TMathSpecTests.SetupFixture;
begin
  FCorpus := TSpecCorpus.Create(MathCorpusFileName);
end;

procedure TMathSpecTests.TearDownFixture;
begin
  FreeAndNil(FCorpus);
end;

procedure TMathSpecTests.Math_Corpus_ContainsAllExamples;
begin
  Assert.AreEqual(MathCorpusExampleCount, FCorpus.Count,
    Format('%s must contain %d examples', [MathCorpusFileName, MathCorpusExampleCount]));
end;

procedure TMathSpecTests.Math_Section_MatchesSpec(const Section: string);
begin
  VerifySection(Section);
end;

procedure TMathSpecTests.ToHtml_CommonMarkDialect_KeepsDollarsLiteral;
begin
  Assert.AreEqual('<p>$x^2$ and $$y$$</p>'#10, TMarkdown.ToHtml('$x^2$ and $$y$$', TMarkdownDialect.CommonMark));
end;

procedure TMathSpecTests.ToHtml_CommonMarkDialect_KeepsMathFenceAsCode;
begin
  Assert.AreEqual('<pre><code class="language-math">x'#10'</code></pre>'#10,
    TMarkdown.ToHtml('```math'#10'x'#10'```', TMarkdownDialect.CommonMark));
end;

procedure TMathSpecTests.Parse_InlineMath_YieldsInlineNodeWithLiteral;
begin
  const Document = TMarkdown.Parse('The $x^2$ formula', TMarkdownDialect.Gfm);

  const Math = FirstMathNode(Document);

  Assert.IsNotNull(Math);
  Assert.AreEqual('x^2', Math.Literal);
  Assert.IsFalse(Math.IsDisplay);
end;

procedure TMathSpecTests.Parse_DisplayBlock_YieldsDisplayNode;
begin
  const Document = TMarkdown.Parse('$$'#10'\frac{a}{b}'#10'$$', TMarkdownDialect.Gfm);

  const Math = FirstMathNode(Document);

  Assert.IsNotNull(Math);
  Assert.AreEqual('\frac{a}{b}', Math.Literal);
  Assert.IsTrue(Math.IsDisplay);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.Math, Document.Children[0].Kind);
end;

procedure TMathSpecTests.Parse_MathFence_YieldsDisplayNode;
begin
  const Document = TMarkdown.Parse('```math'#10'x + y'#10'```', TMarkdownDialect.Gfm);

  const Math = FirstMathNode(Document);

  Assert.IsNotNull(Math);
  Assert.AreEqual('x + y', Math.Literal);
  Assert.IsTrue(Math.IsDisplay);
end;

procedure TMathSpecTests.Parse_InlineDoubleDollar_YieldsDisplayNodeInsideParagraph;
begin
  const Document = TMarkdown.Parse('See $$E=mc^2$$ here', TMarkdownDialect.Gfm);

  const Math = FirstMathNode(Document);

  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.Paragraph, Document.Children[0].Kind);
  Assert.AreEqual('E=mc^2', Math.Literal);
  Assert.IsTrue(Math.IsDisplay);
end;

procedure TMathSpecTests.ToMarkdown_InlineMath_WritesSingleDollars;
begin
  Assert.AreEqual('The $x^2$ formula'#10, CanonicalMarkdown('The $x^2$ formula'#10));
end;

procedure TMathSpecTests.ToMarkdown_InlineDisplayMath_WritesDoubleDollars;
begin
  Assert.AreEqual('See $$E=mc^2$$ here'#10, CanonicalMarkdown('See $$E=mc^2$$ here'#10));
end;

procedure TMathSpecTests.ToMarkdown_DisplayBlock_WritesDollarFences;
begin
  Assert.AreEqual('$$'#10'\frac{a}{b}'#10'$$'#10, CanonicalMarkdown('$$'#10'\frac{a}{b}'#10'$$'#10));
end;

procedure TMathSpecTests.ToMarkdown_MathFence_WritesDollarFences;
begin
  Assert.AreEqual('$$'#10'x'#10'$$'#10, CanonicalMarkdown('```math'#10'x'#10'```'#10));
end;

procedure TMathSpecTests.ToMarkdown_DisplayBlockInBlockQuote_KeepsQuotePrefix;
begin
  Assert.AreEqual('> $$'#10'> x'#10'> $$'#10, CanonicalMarkdown('> $$'#10'> x'#10'> $$'#10));
end;

procedure TMathSpecTests.ToMarkdown_EscapedDollarInText_RoundTrips;
begin
  const Canonical = CanonicalMarkdown('Pay \$5 now'#10);

  Assert.AreEqual('<p>Pay $5 now</p>'#10, TMarkdown.ToHtml(Canonical, TMarkdownDialect.Gfm));
end;

procedure TMathSpecTests.ToMarkdown_Corpus_RoundTripsEveryExample;
begin
  for var Example in TSpecCorpus.LoadExamples(MathCorpusFileName) do
  begin
    const Expected = TMarkdown.ToUnsafeHtml(Example.Markdown, TMarkdownDialect.Gfm);
    const Rewritten = CanonicalMarkdown(Example.Markdown);
    const Actual = TMarkdown.ToUnsafeHtml(Rewritten, TMarkdownDialect.Gfm);

    Assert.AreEqual(Expected, Actual, Format('Example %d must render the same HTML after a round trip through the writer',
      [Example.Number]));
  end;
end;

procedure TMathSpecTests.Toc_HeadingWithMath_KeepsFormulaSource;
begin
  const Document = TMarkdown.Parse('# The $E=mc^2$ law', TMarkdownDialect.Gfm);

  const Toc = TMarkdownToc.FromDocument(Document);

  Assert.AreEqual('The E=mc^2 law', Toc.Entries[0].Caption);
end;

procedure TMathSpecTests.Builder_Math_RendersInlineSpan;
begin
  const Document = TMarkdownDocumentBuilder.Create.BeginParagraph.Text('Area ').Math('\pi r^2').EndParagraph.Build;

  Assert.AreEqual('<p>Area <span class="math">\(\pi r^2\)</span></p>'#10, TMarkdownHtmlRenderer.RenderDocument(Document));
end;

procedure TMathSpecTests.Builder_MathBlock_RendersDiv;
begin
  const Document = TMarkdownDocumentBuilder.Create.MathBlock('a = b').Build;

  Assert.AreEqual('<div class="math">\['#10'a = b'#10'\]</div>'#10, TMarkdownHtmlRenderer.RenderDocument(Document));
end;

procedure TMathSpecTests.VerifySection(const Section: string);
begin
  const Failures = FCorpus.CheckSection(Section, TMarkdownDialect.Gfm);
  const HasFailures = (Failures <> '');
  if HasFailures then
    Assert.Fail(Failures);
end;

class function TMathSpecTests.FirstMathNode(const Document: IMarkdownDocument): IMarkdownMath;
begin
  Result := nil;

  for var BlockIndex := 0 to Document.ChildCount - 1 do
  begin
    const Block = Document.Children[BlockIndex];
    if Supports(Block, IMarkdownMath, Result) then
      Exit;

    for var InlineIndex := 0 to Block.ChildCount - 1 do
    begin
      if Supports(Block.Children[InlineIndex], IMarkdownMath, Result) then
        Exit;
    end;
  end;
end;

class function TMathSpecTests.CanonicalMarkdown(const Source: string): string;
begin
  Result := TMarkdown.ToMarkdown(TMarkdown.Parse(Source, TMarkdownDialect.Gfm));
end;

end.
