unit Markdown4D.Parser.Gfm.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Parser.Spec.Corpus;

type
  [TestFixture]
  TGfmSpecTests = class
  private
    FCorpus: TSpecCorpus;
    procedure VerifySection(const Section: string);

  public
    [SetupFixture]
    procedure SetupFixture;

    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure Gfm_Corpus_ContainsAllExamples;

    [Test]
    [TestCase('Tables (extension)', 'Tables (extension)')]
    [TestCase('Task list items (extension)', 'Task list items (extension)')]
    [TestCase('Strikethrough (extension)', 'Strikethrough (extension)')]
    [TestCase('Autolinks (extension)', 'Autolinks (extension)')]
    [TestCase('Disallowed Raw HTML (extension)', 'Disallowed Raw HTML (extension)')]
    procedure Gfm_Section_MatchesSpec(const Section: string);
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Defines;

procedure TGfmSpecTests.SetupFixture;
begin
  FCorpus := TSpecCorpus.Create(TSpecCorpus.GfmCorpusFileName);
end;

procedure TGfmSpecTests.TearDownFixture;
begin
  FreeAndNil(FCorpus);
end;

procedure TGfmSpecTests.Gfm_Corpus_ContainsAllExamples;
begin
  Assert.AreEqual(24, FCorpus.Count, Format('%s must contain 24 examples', [TSpecCorpus.GfmCorpusFileName]));
end;

procedure TGfmSpecTests.Gfm_Section_MatchesSpec(const Section: string);
begin
  VerifySection(Section);
end;

procedure TGfmSpecTests.VerifySection(const Section: string);
begin
  const Failures = FCorpus.CheckSection(Section, TMarkdownDialect.Gfm);
  const HasFailures = (Failures <> '');
  if HasFailures then
    Assert.Fail(Failures);
end;

end.
