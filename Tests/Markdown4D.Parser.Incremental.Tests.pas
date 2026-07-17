unit Markdown4D.Parser.Incremental.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Defines,
  Markdown4D.Parser.Interfaces,
  Markdown4D.Parser.Spec.Corpus;

type
  [TestFixture]
  TIncrementalEquivalenceTests = class
  private
    type
      TMutationState = record
        Content: string;
        Seed: Cardinal;
      end;
      TEquivalenceMode = (Streaming, Mutations);
    const
      InsertedMarker = '**x**';
      ReplacementMarker = '`y`';
      MaxChunkLength = 8;
      LcgMultiplier: UInt64 = 1664525;
      LcgIncrement: UInt64 = 1013904223;
      LcgMask: UInt64 = $FFFFFFFF;
    var
      FCommonMarkExamples: TArray<TSpecExample>;
      FGfmExamples: TArray<TSpecExample>;
    class procedure AssertSection(const Examples: TArray<TSpecExample>; const Section: string; const Dialect: TMarkdownDialect; const Mode: TEquivalenceMode);
    class function TryExample(const Example: TSpecExample; const Dialect: TMarkdownDialect; const Mode: TEquivalenceMode; out FailureDetail: string): Boolean;
    class function TryStreamingExample(const Example: TSpecExample; const Dialect: TMarkdownDialect; out FailureDetail: string): Boolean;
    class function TryMutationExample(const Example: TSpecExample; const Dialect: TMarkdownDialect; out FailureDetail: string): Boolean;
    class function CheckFullParseMatchesSpec(const Example: TSpecExample; const Dialect: TMarkdownDialect; out FullParseHtml: string; out FailureDetail: string): Boolean;
    class procedure AppendInChunks(const Parser: IMarkdownIncrementalParser; const Source: string; const Seed: Cardinal);
    class function DeleteSlice(const Parser: IMarkdownIncrementalParser; const State: TMutationState): TMutationState;
    class function InsertMarker(const Parser: IMarkdownIncrementalParser; const State: TMutationState): TMutationState;
    class function ReplaceSlice(const Parser: IMarkdownIncrementalParser; const State: TMutationState): TMutationState;
    class function TryVerifyMutation(const Parser: IMarkdownIncrementalParser; const Content: string; const Dialect: TMarkdownDialect; const MutationName: string; out FailureDetail: string): Boolean;
    class function ReplaceSliceInText(const Value: string; const StartIndex, Count: Integer; const Replacement: string): string;
    class function SeedForExample(const Number: Integer): Cardinal;
    class function NextSeed(const Seed: Cardinal): Cardinal;
    class function ValueFromSeed(const Seed: Cardinal; const Range: Integer): Integer;

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
    procedure Append_CommonMarkSectionInChunks_MatchesFullParseHtml(const Section: string);

    [Test]
    [TestCase('Tables (extension)', 'Tables (extension)')]
    [TestCase('Task list items (extension)', 'Task list items (extension)')]
    [TestCase('Strikethrough (extension)', 'Strikethrough (extension)')]
    [TestCase('Autolinks (extension)', 'Autolinks (extension)')]
    [TestCase('Disallowed Raw HTML (extension)', 'Disallowed Raw HTML (extension)')]
    procedure Append_GfmSectionInChunks_MatchesFullParseHtml(const Section: string);

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
    procedure ReplaceRange_CommonMarkSectionMutations_MatchesFullParseHtml(const Section: string);

    [Test]
    [TestCase('Tables (extension)', 'Tables (extension)')]
    [TestCase('Task list items (extension)', 'Task list items (extension)')]
    [TestCase('Strikethrough (extension)', 'Strikethrough (extension)')]
    [TestCase('Autolinks (extension)', 'Autolinks (extension)')]
    [TestCase('Disallowed Raw HTML (extension)', 'Disallowed Raw HTML (extension)')]
    procedure ReplaceRange_GfmSectionMutations_MatchesFullParseHtml(const Section: string);
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  Markdown4D;

procedure TIncrementalEquivalenceTests.SetupFixture;
begin
  FCommonMarkExamples := TSpecCorpus.LoadExamples(TSpecCorpus.CommonMarkCorpusFileName);
  FGfmExamples := TSpecCorpus.LoadExamples(TSpecCorpus.GfmCorpusFileName);
end;

procedure TIncrementalEquivalenceTests.Append_CommonMarkSectionInChunks_MatchesFullParseHtml(const Section: string);
begin
  AssertSection(FCommonMarkExamples, Section, TMarkdownDialect.CommonMark, TEquivalenceMode.Streaming);
end;

procedure TIncrementalEquivalenceTests.Append_GfmSectionInChunks_MatchesFullParseHtml(const Section: string);
begin
  AssertSection(FGfmExamples, Section, TMarkdownDialect.Gfm, TEquivalenceMode.Streaming);
end;

procedure TIncrementalEquivalenceTests.ReplaceRange_CommonMarkSectionMutations_MatchesFullParseHtml(const Section: string);
begin
  AssertSection(FCommonMarkExamples, Section, TMarkdownDialect.CommonMark, TEquivalenceMode.Mutations);
end;

procedure TIncrementalEquivalenceTests.ReplaceRange_GfmSectionMutations_MatchesFullParseHtml(const Section: string);
begin
  AssertSection(FGfmExamples, Section, TMarkdownDialect.Gfm, TEquivalenceMode.Mutations);
end;

class procedure TIncrementalEquivalenceTests.AssertSection(const Examples: TArray<TSpecExample>; const Section: string; const Dialect: TMarkdownDialect; const Mode: TEquivalenceMode);
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
      const Passed = TryExample(Example, Dialect, Mode, FailureDetail);
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

class function TIncrementalEquivalenceTests.TryExample(const Example: TSpecExample; const Dialect: TMarkdownDialect; const Mode: TEquivalenceMode; out FailureDetail: string): Boolean;
begin
  case Mode of
    TEquivalenceMode.Streaming:
      Result := TryStreamingExample(Example, Dialect, FailureDetail);
    TEquivalenceMode.Mutations:
      Result := TryMutationExample(Example, Dialect, FailureDetail);
  else
    raise EArgumentOutOfRangeException.CreateFmt('Unsupported equivalence mode %d', [Ord(Mode)]);
  end;
end;

class function TIncrementalEquivalenceTests.TryStreamingExample(const Example: TSpecExample; const Dialect: TMarkdownDialect; out FailureDetail: string): Boolean;
begin
  FailureDetail := '';

  try
    var FullParseHtml: string;
    const FullParseMatchesSpec = CheckFullParseMatchesSpec(Example, Dialect, FullParseHtml, FailureDetail);
    if not FullParseMatchesSpec then
      Exit(False);

    const Parser = TMarkdown.CreateIncrementalParser(Dialect);
    AppendInChunks(Parser, Example.Markdown, SeedForExample(Example.Number));

    const StreamedHtml = TSpecCorpus.NormalizeLineEndings(Parser.ToHtml);
    Result := (StreamedHtml = FullParseHtml);
    if not Result then
      FailureDetail := Format('streamed HTML differs from full-parse HTML. Full-parse: <%s>, streamed: <%s>', [FullParseHtml, StreamedHtml]);
  except
    on E: Exception do
    begin
      FailureDetail := Format('%s: %s', [E.ClassName, E.Message]);
      Result := False;
    end;
  end;
end;

class function TIncrementalEquivalenceTests.TryMutationExample(const Example: TSpecExample; const Dialect: TMarkdownDialect; out FailureDetail: string): Boolean;
begin
  FailureDetail := '';

  try
    var FullParseHtml: string;
    const FullParseMatchesSpec = CheckFullParseMatchesSpec(Example, Dialect, FullParseHtml, FailureDetail);
    if not FullParseMatchesSpec then
      Exit(False);

    const Parser = TMarkdown.CreateIncrementalParser(Dialect);
    Parser.Append(Example.Markdown);

    var State: TMutationState;
    State.Content := Example.Markdown;
    State.Seed := SeedForExample(Example.Number);

    State := DeleteSlice(Parser, State);
    if not TryVerifyMutation(Parser, State.Content, Dialect, 'delete', FailureDetail) then
      Exit(False);

    State := InsertMarker(Parser, State);
    if not TryVerifyMutation(Parser, State.Content, Dialect, 'insert', FailureDetail) then
      Exit(False);

    State := ReplaceSlice(Parser, State);
    if not TryVerifyMutation(Parser, State.Content, Dialect, 'replace', FailureDetail) then
      Exit(False);

    Result := True;
  except
    on E: Exception do
    begin
      FailureDetail := Format('%s: %s', [E.ClassName, E.Message]);
      Result := False;
    end;
  end;
end;

class function TIncrementalEquivalenceTests.CheckFullParseMatchesSpec(const Example: TSpecExample; const Dialect: TMarkdownDialect; out FullParseHtml: string; out FailureDetail: string): Boolean;
begin
  FailureDetail := '';
  FullParseHtml := TSpecCorpus.NormalizeLineEndings(TMarkdown.ToHtml(Example.Markdown, Dialect));

  const SpecHtml = TSpecCorpus.NormalizeLineEndings(Example.ExpectedHtml);
  Result := (FullParseHtml = SpecHtml);
  if not Result then
    FailureDetail := Format('full-parse HTML differs from the spec expected HTML. Expected: <%s>, full-parse: <%s>', [SpecHtml, FullParseHtml]);
end;

class procedure TIncrementalEquivalenceTests.AppendInChunks(const Parser: IMarkdownIncrementalParser; const Source: string; const Seed: Cardinal);
begin
  var CurrentSeed := Seed;
  var Position := 1;

  while Position <= Length(Source) do
  begin
    CurrentSeed := NextSeed(CurrentSeed);
    const Remaining = Length(Source) - Position + 1;
    const ChunkLength = Min(1 + ValueFromSeed(CurrentSeed, MaxChunkLength), Remaining);
    Parser.Append(Copy(Source, Position, ChunkLength));
    Inc(Position, ChunkLength);
  end;
end;

class function TIncrementalEquivalenceTests.DeleteSlice(const Parser: IMarkdownIncrementalParser; const State: TMutationState): TMutationState;
begin
  const ContentLength = Length(State.Content);
  if ContentLength = 0 then
    Exit(State);

  const StartSeed = NextSeed(State.Seed);
  const StartIndex = 1 + ValueFromSeed(StartSeed, ContentLength);
  const CountSeed = NextSeed(StartSeed);
  const Count = 1 + ValueFromSeed(CountSeed, ContentLength - StartIndex + 1);
  Parser.ReplaceRange(StartIndex, Count, '');

  Result.Content := ReplaceSliceInText(State.Content, StartIndex, Count, '');
  Result.Seed := CountSeed;
end;

class function TIncrementalEquivalenceTests.InsertMarker(const Parser: IMarkdownIncrementalParser; const State: TMutationState): TMutationState;
begin
  const StartSeed = NextSeed(State.Seed);
  const StartIndex = 1 + ValueFromSeed(StartSeed, Length(State.Content) + 1);
  Parser.ReplaceRange(StartIndex, 0, InsertedMarker);

  Result.Content := ReplaceSliceInText(State.Content, StartIndex, 0, InsertedMarker);
  Result.Seed := StartSeed;
end;

class function TIncrementalEquivalenceTests.ReplaceSlice(const Parser: IMarkdownIncrementalParser; const State: TMutationState): TMutationState;
begin
  const ContentLength = Length(State.Content);
  if ContentLength = 0 then
    Exit(State);

  const StartSeed = NextSeed(State.Seed);
  const StartIndex = 1 + ValueFromSeed(StartSeed, ContentLength);
  const CountSeed = NextSeed(StartSeed);
  const Count = 1 + ValueFromSeed(CountSeed, ContentLength - StartIndex + 1);
  Parser.ReplaceRange(StartIndex, Count, ReplacementMarker);

  Result.Content := ReplaceSliceInText(State.Content, StartIndex, Count, ReplacementMarker);
  Result.Seed := CountSeed;
end;

class function TIncrementalEquivalenceTests.TryVerifyMutation(const Parser: IMarkdownIncrementalParser; const Content: string; const Dialect: TMarkdownDialect; const MutationName: string; out FailureDetail: string): Boolean;
begin
  FailureDetail := '';

  const ExpectedHtml = TSpecCorpus.NormalizeLineEndings(TMarkdown.ToHtml(Content, Dialect));
  const IncrementalHtml = TSpecCorpus.NormalizeLineEndings(Parser.ToHtml);
  Result := (IncrementalHtml = ExpectedHtml);
  if not Result then
    FailureDetail := Format('after %s mutation the incremental HTML differs from the full-parse HTML. Mutated markdown: <%s>, full-parse: <%s>, incremental: <%s>',
      [MutationName, Content, ExpectedHtml, IncrementalHtml]);
end;

class function TIncrementalEquivalenceTests.ReplaceSliceInText(const Value: string; const StartIndex, Count: Integer; const Replacement: string): string;
begin
  const Prefix = Copy(Value, 1, StartIndex - 1);
  const Suffix = Copy(Value, StartIndex + Count, MaxInt);
  Result := Format('%s%s%s', [Prefix, Replacement, Suffix]);
end;

class function TIncrementalEquivalenceTests.SeedForExample(const Number: Integer): Cardinal;
begin
  Result := NextSeed(NextSeed(Cardinal(Number)));
end;

class function TIncrementalEquivalenceTests.NextSeed(const Seed: Cardinal): Cardinal;
begin
  Result := Cardinal((Seed * LcgMultiplier + LcgIncrement) and LcgMask);
end;

class function TIncrementalEquivalenceTests.ValueFromSeed(const Seed: Cardinal; const Range: Integer): Integer;
begin
  const Mixed = Seed xor (Seed shr 16);
  Result := Integer(Mixed mod Cardinal(Range));
end;

end.
