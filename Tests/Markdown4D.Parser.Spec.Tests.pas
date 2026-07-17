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
    procedure CommonMark_Tabs_MatchesSpec;

    [Test]
    procedure CommonMark_BackslashEscapes_MatchesSpec;

    [Test]
    procedure CommonMark_EntityAndNumericCharacterReferences_MatchesSpec;

    [Test]
    procedure CommonMark_Precedence_MatchesSpec;

    [Test]
    procedure CommonMark_ThematicBreaks_MatchesSpec;

    [Test]
    procedure CommonMark_AtxHeadings_MatchesSpec;

    [Test]
    procedure CommonMark_SetextHeadings_MatchesSpec;

    [Test]
    procedure CommonMark_IndentedCodeBlocks_MatchesSpec;

    [Test]
    procedure CommonMark_FencedCodeBlocks_MatchesSpec;

    [Test]
    procedure CommonMark_HtmlBlocks_MatchesSpec;

    [Test]
    procedure CommonMark_LinkReferenceDefinitions_MatchesSpec;

    [Test]
    procedure CommonMark_Paragraphs_MatchesSpec;

    [Test]
    procedure CommonMark_BlankLines_MatchesSpec;

    [Test]
    procedure CommonMark_BlockQuotes_MatchesSpec;

    [Test]
    procedure CommonMark_ListItems_MatchesSpec;

    [Test]
    procedure CommonMark_Lists_MatchesSpec;

    [Test]
    procedure CommonMark_Inlines_MatchesSpec;

    [Test]
    procedure CommonMark_CodeSpans_MatchesSpec;

    [Test]
    procedure CommonMark_EmphasisAndStrongEmphasis_MatchesSpec;

    [Test]
    procedure CommonMark_Links_MatchesSpec;

    [Test]
    procedure CommonMark_Images_MatchesSpec;

    [Test]
    procedure CommonMark_Autolinks_MatchesSpec;

    [Test]
    procedure CommonMark_RawHtml_MatchesSpec;

    [Test]
    procedure CommonMark_HardLineBreaks_MatchesSpec;

    [Test]
    procedure CommonMark_SoftLineBreaks_MatchesSpec;

    [Test]
    procedure CommonMark_TextualContent_MatchesSpec;
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

procedure TCommonMarkSpecTests.CommonMark_Tabs_MatchesSpec;
begin
  VerifySection('Tabs');
end;

procedure TCommonMarkSpecTests.CommonMark_BackslashEscapes_MatchesSpec;
begin
  VerifySection('Backslash escapes');
end;

procedure TCommonMarkSpecTests.CommonMark_EntityAndNumericCharacterReferences_MatchesSpec;
begin
  VerifySection('Entity and numeric character references');
end;

procedure TCommonMarkSpecTests.CommonMark_Precedence_MatchesSpec;
begin
  VerifySection('Precedence');
end;

procedure TCommonMarkSpecTests.CommonMark_ThematicBreaks_MatchesSpec;
begin
  VerifySection('Thematic breaks');
end;

procedure TCommonMarkSpecTests.CommonMark_AtxHeadings_MatchesSpec;
begin
  VerifySection('ATX headings');
end;

procedure TCommonMarkSpecTests.CommonMark_SetextHeadings_MatchesSpec;
begin
  VerifySection('Setext headings');
end;

procedure TCommonMarkSpecTests.CommonMark_IndentedCodeBlocks_MatchesSpec;
begin
  VerifySection('Indented code blocks');
end;

procedure TCommonMarkSpecTests.CommonMark_FencedCodeBlocks_MatchesSpec;
begin
  VerifySection('Fenced code blocks');
end;

procedure TCommonMarkSpecTests.CommonMark_HtmlBlocks_MatchesSpec;
begin
  VerifySection('HTML blocks');
end;

procedure TCommonMarkSpecTests.CommonMark_LinkReferenceDefinitions_MatchesSpec;
begin
  VerifySection('Link reference definitions');
end;

procedure TCommonMarkSpecTests.CommonMark_Paragraphs_MatchesSpec;
begin
  VerifySection('Paragraphs');
end;

procedure TCommonMarkSpecTests.CommonMark_BlankLines_MatchesSpec;
begin
  VerifySection('Blank lines');
end;

procedure TCommonMarkSpecTests.CommonMark_BlockQuotes_MatchesSpec;
begin
  VerifySection('Block quotes');
end;

procedure TCommonMarkSpecTests.CommonMark_ListItems_MatchesSpec;
begin
  VerifySection('List items');
end;

procedure TCommonMarkSpecTests.CommonMark_Lists_MatchesSpec;
begin
  VerifySection('Lists');
end;

procedure TCommonMarkSpecTests.CommonMark_Inlines_MatchesSpec;
begin
  VerifySection('Inlines');
end;

procedure TCommonMarkSpecTests.CommonMark_CodeSpans_MatchesSpec;
begin
  VerifySection('Code spans');
end;

procedure TCommonMarkSpecTests.CommonMark_EmphasisAndStrongEmphasis_MatchesSpec;
begin
  VerifySection('Emphasis and strong emphasis');
end;

procedure TCommonMarkSpecTests.CommonMark_Links_MatchesSpec;
begin
  VerifySection('Links');
end;

procedure TCommonMarkSpecTests.CommonMark_Images_MatchesSpec;
begin
  VerifySection('Images');
end;

procedure TCommonMarkSpecTests.CommonMark_Autolinks_MatchesSpec;
begin
  VerifySection('Autolinks');
end;

procedure TCommonMarkSpecTests.CommonMark_RawHtml_MatchesSpec;
begin
  VerifySection('Raw HTML');
end;

procedure TCommonMarkSpecTests.CommonMark_HardLineBreaks_MatchesSpec;
begin
  VerifySection('Hard line breaks');
end;

procedure TCommonMarkSpecTests.CommonMark_SoftLineBreaks_MatchesSpec;
begin
  VerifySection('Soft line breaks');
end;

procedure TCommonMarkSpecTests.CommonMark_TextualContent_MatchesSpec;
begin
  VerifySection('Textual content');
end;

procedure TCommonMarkSpecTests.VerifySection(const Section: string);
begin
  const Failures = FCorpus.CheckSection(Section, TMarkdownDialect.CommonMark);
  const HasFailures = (Failures <> '');
  if HasFailures then
    Assert.Fail(Failures);
end;

end.
