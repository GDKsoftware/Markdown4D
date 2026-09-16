unit Markdown4D.Parser.Spec.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Parser.Spec.Corpus;

type
  [TestFixture]
  TCommonMarkSpecTests = class
  private
    FCorpus: TSpecCorpus;
    procedure VerifySection(const Section: string);

  public
    [SetupFixture]
    procedure SetupFixture;

    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure CommonMark_Corpus_ContainsAllExamples;

    [Test]
    [TestCase('Tabs', 'Tabs')]
    [TestCase('Backslash escapes', 'Backslash escapes')]
    [TestCase('Entity and numeric character references', 'Entity and numeric character references')]
    [TestCase('Precedence', 'Precedence')]
    [TestCase('Thematic breaks', 'Thematic breaks')]
    [TestCase('ATX headings', 'ATX headings')]
    [TestCase('Setext headings', 'Setext headings')]
    [TestCase('Indented code blocks', 'Indented code blocks')]
    [TestCase('Fenced code blocks', 'Fenced code blocks')]
    [TestCase('HTML blocks', 'HTML blocks')]
    [TestCase('Link reference definitions', 'Link reference definitions')]
    [TestCase('Paragraphs', 'Paragraphs')]
    [TestCase('Blank lines', 'Blank lines')]
    [TestCase('Block quotes', 'Block quotes')]
    [TestCase('List items', 'List items')]
    [TestCase('Lists', 'Lists')]
    [TestCase('Inlines', 'Inlines')]
    [TestCase('Code spans', 'Code spans')]
    [TestCase('Emphasis and strong emphasis', 'Emphasis and strong emphasis')]
    [TestCase('Links', 'Links')]
    [TestCase('Images', 'Images')]
    [TestCase('Autolinks', 'Autolinks')]
    [TestCase('Raw HTML', 'Raw HTML')]
    [TestCase('Hard line breaks', 'Hard line breaks')]
    [TestCase('Soft line breaks', 'Soft line breaks')]
    [TestCase('Textual content', 'Textual content')]
    procedure CommonMark_Section_MatchesSpec(const Section: string);
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Defines;

procedure TCommonMarkSpecTests.SetupFixture;
begin
  FCorpus := TSpecCorpus.Create(TSpecCorpus.CommonMarkCorpusFileName);
end;

procedure TCommonMarkSpecTests.TearDownFixture;
begin
  FreeAndNil(FCorpus);
end;

procedure TCommonMarkSpecTests.CommonMark_Corpus_ContainsAllExamples;
begin
  Assert.AreEqual(652, FCorpus.Count, Format('%s must contain 652 examples', [TSpecCorpus.CommonMarkCorpusFileName]));
end;

procedure TCommonMarkSpecTests.CommonMark_Section_MatchesSpec(const Section: string);
begin
  VerifySection(Section);
end;

procedure TCommonMarkSpecTests.VerifySection(const Section: string);
begin
  const Failures = FCorpus.CheckSection(Section, TMarkdownDialect.CommonMark);
  const HasFailures = (Failures <> '');
  if HasFailures then
    Assert.Fail(Failures);
end;

end.
