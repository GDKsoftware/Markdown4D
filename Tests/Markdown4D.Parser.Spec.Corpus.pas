unit Markdown4D.Parser.Spec.Corpus;

interface

uses
  System.SysUtils,
  System.JSON,
  Markdown4D.Defines;

type
  ESpecCorpusError = class(Exception);

  TSpecExample = record
    Number: Integer;
    Markdown: string;
    ExpectedHtml: string;
    Section: string;
  end;

  TSpecCorpus = class
  private
    const
      SpecsFolderName = 'specs';
      TestsFolderName = 'Tests';
      ExampleNumberKey = 'example';
      MarkdownKey = 'markdown';
      HtmlKey = 'html';
      SectionKey = 'section';
    var
      FExamples: TArray<TSpecExample>;
    class function ResolveSpecFilePath(const FileName: string): string;
    class function ParseExamples(const Examples: TJSONArray): TArray<TSpecExample>;
    class function TryRunExample(const Example: TSpecExample; const Dialect: TMarkdownDialect; out Detail: string): Boolean;
    class function BuildFailureHeader(const Example: TSpecExample; const ExpectedHtml: string): string;

  public
    const
      CommonMarkCorpusFileName = 'commonmark-0.31.2.json';
      GfmCorpusFileName = 'gfm-0.29.json';
      EmptySectionMessageFormat = 'Section "%s" contains no examples';
      SectionFailuresMessageFormat = '%d of %d examples failed in section "%s". Failing examples: %s. First failure: %s';
    class function LoadExamples(const FileName: string): TArray<TSpecExample>;
    class function FilterBySection(const Examples: TArray<TSpecExample>; const Section: string): TArray<TSpecExample>;
    class function NormalizeLineEndings(const Value: string): string;
    class function JoinNumbers(const Numbers: TArray<Integer>): string;
    constructor Create(const FileName: string);
    function Count: Integer;
    function CheckSection(const Section: string; const Dialect: TMarkdownDialect): string;
  end;

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  Markdown4D;

constructor TSpecCorpus.Create(const FileName: string);
begin
  inherited Create;

  FExamples := LoadExamples(FileName);
end;

class function TSpecCorpus.LoadExamples(const FileName: string): TArray<TSpecExample>;
begin
  const FilePath = ResolveSpecFilePath(FileName);
  const Content = TFile.ReadAllText(FilePath, TEncoding.UTF8);
  const Root = TJSONObject.ParseJSONValue(Content);
  try
    const IsArray = (Root is TJSONArray);
    if not IsArray then
      raise ESpecCorpusError.CreateFmt('Spec file "%s" does not contain a JSON array', [FilePath]);

    Result := ParseExamples(TJSONArray(Root));
  finally
    Root.Free;
  end;
end;

class function TSpecCorpus.ResolveSpecFilePath(const FileName: string): string;
begin
  var Directory := TPath.GetDirectoryName(TPath.GetFullPath(ParamStr(0)));

  while Directory <> '' do
  begin
    const DirectCandidate = TPath.Combine(TPath.Combine(Directory, SpecsFolderName), FileName);
    if TFile.Exists(DirectCandidate) then
      Exit(DirectCandidate);

    const NestedCandidate = TPath.Combine(TPath.Combine(TPath.Combine(Directory, TestsFolderName), SpecsFolderName), FileName);
    if TFile.Exists(NestedCandidate) then
      Exit(NestedCandidate);

    const Parent = TPath.GetDirectoryName(Directory);
    const ReachedRoot = (Parent = Directory);
    if ReachedRoot then
      Break;

    Directory := Parent;
  end;

  raise ESpecCorpusError.CreateFmt('Spec file "%s" was not found in a "%s" folder searching upward from "%s"',
    [FileName, SpecsFolderName, ParamStr(0)]);
end;

class function TSpecCorpus.ParseExamples(const Examples: TJSONArray): TArray<TSpecExample>;
begin
  SetLength(Result, Examples.Count);

  for var Index := 0 to Examples.Count - 1 do
  begin
    const Item = Examples.Items[Index] as TJSONObject;
    Result[Index].Number := Item.GetValue<Integer>(ExampleNumberKey);
    Result[Index].Markdown := Item.GetValue<string>(MarkdownKey);
    Result[Index].ExpectedHtml := Item.GetValue<string>(HtmlKey);
    Result[Index].Section := Item.GetValue<string>(SectionKey);
  end;
end;

function TSpecCorpus.Count: Integer;
begin
  Result := Length(FExamples);
end;

function TSpecCorpus.CheckSection(const Section: string; const Dialect: TMarkdownDialect): string;
begin
  const SectionExamples = FilterBySection(FExamples, Section);
  const HasExamples = (Length(SectionExamples) > 0);
  if not HasExamples then
    Exit(Format(EmptySectionMessageFormat, [Section]));

  var FailingNumbers: TArray<Integer> := [];
  var FirstFailureDetail := '';

  for var Example in SectionExamples do
  begin
    var Detail: string;
    const Passed = TryRunExample(Example, Dialect, Detail);
    if Passed then
      Continue;

    FailingNumbers := FailingNumbers + [Example.Number];

    const IsFirstFailure = (Length(FailingNumbers) = 1);
    if IsFirstFailure then
      FirstFailureDetail := Detail;
  end;

  const HasFailures = (Length(FailingNumbers) > 0);
  if not HasFailures then
    Exit('');

  Result := Format(SectionFailuresMessageFormat,
    [Length(FailingNumbers), Length(SectionExamples), Section, JoinNumbers(FailingNumbers), FirstFailureDetail]);
end;

class function TSpecCorpus.FilterBySection(const Examples: TArray<TSpecExample>; const Section: string): TArray<TSpecExample>;
begin
  const Filtered = TList<TSpecExample>.Create;
  try
    for var Example in Examples do
    begin
      const MatchesSection = (Example.Section = Section);
      if MatchesSection then
        Filtered.Add(Example);
    end;

    Result := Filtered.ToArray;
  finally
    Filtered.Free;
  end;
end;

class function TSpecCorpus.TryRunExample(const Example: TSpecExample; const Dialect: TMarkdownDialect;
                                         out Detail: string): Boolean;
begin
  Detail := '';

  try
    // The conformance suites describe what the specification prescribes, which
    // includes raw HTML and destinations the safe renderer strips, so they are
    // checked against the unsafe rendering path on purpose.
    const ActualHtml = NormalizeLineEndings(TMarkdown.ToUnsafeHtml(Example.Markdown, Dialect));
    const ExpectedHtml = NormalizeLineEndings(Example.ExpectedHtml);
    Result := (ActualHtml = ExpectedHtml);
    if not Result then
      Detail := string.Join(sLineBreak, [BuildFailureHeader(Example, ExpectedHtml), 'Actual html:', ActualHtml]);
  except
    on Error: Exception do
    begin
      Result := False;
      Detail := string.Join(sLineBreak, [BuildFailureHeader(Example, NormalizeLineEndings(Example.ExpectedHtml)),
        Format('Raised %s with message "%s"', [Error.ClassName, Error.Message])]);
    end;
  end;
end;

class function TSpecCorpus.NormalizeLineEndings(const Value: string): string;
begin
  const WithoutCrLf = StringReplace(Value, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(WithoutCrLf, #13, #10, [rfReplaceAll]);
end;

class function TSpecCorpus.BuildFailureHeader(const Example: TSpecExample; const ExpectedHtml: string): string;
begin
  Result := string.Join(sLineBreak, [
    Format('Example %d', [Example.Number]),
    'Markdown:',
    Example.Markdown,
    'Expected html:',
    ExpectedHtml]);
end;

class function TSpecCorpus.JoinNumbers(const Numbers: TArray<Integer>): string;
begin
  var Parts: TArray<string>;
  SetLength(Parts, Length(Numbers));

  for var Index := 0 to High(Numbers) do
  begin
    Parts[Index] := IntToStr(Numbers[Index]);
  end;

  Result := string.Join(', ', Parts);
end;

end.
