unit Markdown4D.Charts.Corpus;

interface

uses
  System.SysUtils;

type
  EChartCorpusError = class(Exception);

  TChartCorpusCase = record
    Name: string;
    Markdown: string;
    Detected: Boolean;
    ChartType: string;
    DatasetCount: Integer;
    LabelCount: Integer;
  end;

  TChartCorpus = class
  private
    const
      SpecsFolderName = 'specs';
      TestsFolderName = 'Tests';
      NameKey = 'name';
      MarkdownKey = 'markdown';
      DetectedKey = 'detected';
      ChartTypeKey = 'chartType';
      DatasetCountKey = 'datasetCount';
      LabelCountKey = 'labelCount';
    var
      FCases: TArray<TChartCorpusCase>;
    class function ResolveSpecFilePath(const FileName: string): string;

  public
    const
      CorpusFileName = 'charts.json';
    constructor Create;
    function Count: Integer;
    function GetCase(const Index: Integer): TChartCorpusCase;
    function FindCase(const Name: string): TChartCorpusCase;
    property Cases[const Index: Integer]: TChartCorpusCase read GetCase; default;
  end;

implementation

uses
  System.IOUtils,
  System.Generics.Collections,
  System.JSON;

constructor TChartCorpus.Create;
begin
  inherited Create;

  const FilePath = ResolveSpecFilePath(CorpusFileName);
  const Content = TFile.ReadAllText(FilePath, TEncoding.UTF8);
  const Root = TJSONObject.ParseJSONValue(Content);
  try
    const IsArray = (Root is TJSONArray);
    if not IsArray then
      raise EChartCorpusError.CreateFmt('Chart corpus "%s" does not contain a JSON array', [FilePath]);

    const Items = TJSONArray(Root);
    SetLength(FCases, Items.Count);

    for var Index := 0 to Items.Count - 1 do
    begin
      const Item = Items.Items[Index] as TJSONObject;
      FCases[Index].Name := Item.GetValue<string>(NameKey);
      FCases[Index].Markdown := Item.GetValue<string>(MarkdownKey);
      FCases[Index].Detected := Item.GetValue<Boolean>(DetectedKey);
      FCases[Index].ChartType := Item.GetValue<string>(ChartTypeKey, '');
      FCases[Index].DatasetCount := Item.GetValue<Integer>(DatasetCountKey, -1);
      FCases[Index].LabelCount := Item.GetValue<Integer>(LabelCountKey, -1);
    end;
  finally
    Root.Free;
  end;
end;

class function TChartCorpus.ResolveSpecFilePath(const FileName: string): string;
begin
  var Directory := TPath.GetDirectoryName(TPath.GetFullPath(ParamStr(0)));

  while Directory <> '' do
  begin
    const DirectCandidate = TPath.Combine(TPath.Combine(Directory, SpecsFolderName), FileName);
    if TFile.Exists(DirectCandidate) then
      Exit(DirectCandidate);

    const NestedCandidate = TPath.Combine(TPath.Combine(TPath.Combine(Directory, TestsFolderName), SpecsFolderName),
      FileName);
    if TFile.Exists(NestedCandidate) then
      Exit(NestedCandidate);

    const Parent = TPath.GetDirectoryName(Directory);
    const ReachedRoot = (Parent = Directory);
    if ReachedRoot then
      Break;

    Directory := Parent;
  end;

  raise EChartCorpusError.CreateFmt('Chart corpus "%s" was not found in a "%s" folder searching upward from "%s"',
    [FileName, SpecsFolderName, ParamStr(0)]);
end;

function TChartCorpus.Count: Integer;
begin
  Result := Length(FCases);
end;

function TChartCorpus.GetCase(const Index: Integer): TChartCorpusCase;
begin
  Result := FCases[Index];
end;

function TChartCorpus.FindCase(const Name: string): TChartCorpusCase;
begin
  for var Item in FCases do
  begin
    if Item.Name = Name then
      Exit(Item);
  end;

  raise EChartCorpusError.CreateFmt('Chart corpus does not contain a case named "%s"', [Name]);
end;

end.
