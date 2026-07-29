unit Markdown4D.Writer.RoundTrip.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Defines,
  Markdown4D.Parser.Spec.Corpus;

type
  [TestFixture]
  TRoundTripTests = class
  private
    FCommonMarkExamples: TArray<TSpecExample>;
    FGfmExamples: TArray<TSpecExample>;
    class procedure AssertSection(const Examples: TArray<TSpecExample>; const Section: string; const Dialect: TMarkdownDialect);
    class function TryRoundTripExample(const Example: TSpecExample; const Dialect: TMarkdownDialect; out FailureDetail: string): Boolean;

  public
    [SetupFixture]
    procedure SetupFixture;

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
    procedure ToMarkdown_CommonMarkSection_RoundTripsToEquivalentHtml(const Section: string);

    [Test]
    [TestCase('Tables (extension)', 'Tables (extension)')]
    [TestCase('Task list items (extension)', 'Task list items (extension)')]
    [TestCase('Strikethrough (extension)', 'Strikethrough (extension)')]
    [TestCase('Autolinks (extension)', 'Autolinks (extension)')]
    [TestCase('Disallowed Raw HTML (extension)', 'Disallowed Raw HTML (extension)')]
    procedure ToMarkdown_GfmSection_RoundTripsToEquivalentHtml(const Section: string);
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces,
  Markdown4D;

procedure TRoundTripTests.SetupFixture;
begin
  FCommonMarkExamples := TSpecCorpus.LoadExamples(TSpecCorpus.CommonMarkCorpusFileName);
  FGfmExamples := TSpecCorpus.LoadExamples(TSpecCorpus.GfmCorpusFileName);
end;

procedure TRoundTripTests.ToMarkdown_CommonMarkSection_RoundTripsToEquivalentHtml(const Section: string);
begin
  AssertSection(FCommonMarkExamples, Section, TMarkdownDialect.CommonMark);
end;

procedure TRoundTripTests.ToMarkdown_GfmSection_RoundTripsToEquivalentHtml(const Section: string);
begin
  AssertSection(FGfmExamples, Section, TMarkdownDialect.Gfm);
end;

class procedure TRoundTripTests.AssertSection(const Examples: TArray<TSpecExample>; const Section: string; const Dialect: TMarkdownDialect);
begin
  const SectionExamples = TSpecCorpus.FilterBySection(Examples, Section);
  const SectionIsEmpty = (Length(SectionExamples) = 0);
  if SectionIsEmpty then
    Assert.Fail(Format(TSpecCorpus.EmptySectionMessageFormat, [Section]));

  const FailingNumbers = TList<Integer>.Create;
  try
    var FirstFailureDetail := '';

    for var Example in SectionExamples do
    begin
      var FailureDetail: string;
      const Passed = TryRoundTripExample(Example, Dialect, FailureDetail);
      if not Passed then
      begin
        FailingNumbers.Add(Example.Number);

        const IsFirstFailure = (FailingNumbers.Count = 1);
        if IsFirstFailure then
          FirstFailureDetail := Format('example %d: %s', [Example.Number, FailureDetail]);
      end;
    end;

    const HasFailures = (FailingNumbers.Count > 0);
    if HasFailures then
      Assert.Fail(Format(TSpecCorpus.SectionFailuresMessageFormat,
        [FailingNumbers.Count, Length(SectionExamples), Section, TSpecCorpus.JoinNumbers(FailingNumbers.ToArray), FirstFailureDetail]));
  finally
    FailingNumbers.Free;
  end;
end;

class function TRoundTripTests.TryRoundTripExample(const Example: TSpecExample; const Dialect: TMarkdownDialect; out FailureDetail: string): Boolean;
begin
  FailureDetail := '';

  try
    const DirectHtml = TSpecCorpus.NormalizeLineEndings(TMarkdown.ToUnsafeHtml(Example.Markdown, Dialect));
    const SpecHtml = TSpecCorpus.NormalizeLineEndings(Example.ExpectedHtml);
    const MatchesSpec = (DirectHtml = SpecHtml);
    if not MatchesSpec then
    begin
      FailureDetail := Format('direct HTML differs from the spec expected HTML. Expected: <%s>, direct: <%s>', [SpecHtml, DirectHtml]);
      Exit(False);
    end;

    const Document = TMarkdown.Parse(Example.Markdown, Dialect);
    const Rewritten = TMarkdown.ToMarkdown(Document);
    const RoundTripHtml = TSpecCorpus.NormalizeLineEndings(TMarkdown.ToUnsafeHtml(Rewritten, Dialect));
    Result := (RoundTripHtml = DirectHtml);
    if not Result then
      FailureDetail := Format('round-trip HTML differs from direct HTML. Rewritten markdown: <%s>, direct HTML: <%s>, round-trip HTML: <%s>',
        [Rewritten, DirectHtml, RoundTripHtml]);
  except
    on E: Exception do
    begin
      FailureDetail := Format('%s: %s', [E.ClassName, E.Message]);
      Result := False;
    end;
  end;
end;

end.
