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
    procedure Gfm_Tables_MatchesSpec;

    [Test]
    procedure Gfm_TaskListItems_MatchesSpec;

    [Test]
    procedure Gfm_Strikethrough_MatchesSpec;

    [Test]
    procedure Gfm_Autolinks_MatchesSpec;

    [Test]
    procedure Gfm_DisallowedRawHtml_MatchesSpec;
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

procedure TGfmSpecTests.Gfm_Tables_MatchesSpec;
begin
  VerifySection('Tables (extension)');
end;

procedure TGfmSpecTests.Gfm_TaskListItems_MatchesSpec;
begin
  VerifySection('Task list items (extension)');
end;

procedure TGfmSpecTests.Gfm_Strikethrough_MatchesSpec;
begin
  VerifySection('Strikethrough (extension)');
end;

procedure TGfmSpecTests.Gfm_Autolinks_MatchesSpec;
begin
  VerifySection('Autolinks (extension)');
end;

procedure TGfmSpecTests.Gfm_DisallowedRawHtml_MatchesSpec;
begin
  VerifySection('Disallowed Raw HTML (extension)');
end;

procedure TGfmSpecTests.VerifySection(const Section: string);
begin
  const Failures = FCorpus.CheckSection(Section, TMarkdownDialect.Gfm);
  const HasFailures = (Failures <> '');
  if HasFailures then
    Assert.Fail(Failures);
end;

end.
