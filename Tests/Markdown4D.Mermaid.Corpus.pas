unit Markdown4D.Mermaid.Corpus;

interface

uses
  System.SysUtils;

type
  EMermaidCorpusError = class(Exception);

  TMermaidCorpusCase = record
    Name: string;
    Markdown: string;
    Detected: Boolean;
    DiagramKind: string;
    Direction: string;
    Title: string;
    NodeCount: Integer;
    EdgeCount: Integer;
    ParticipantCount: Integer;
    MessageCount: Integer;
    NoteCount: Integer;
    SliceCount: Integer;
  end;

  TMermaidCorpus = class
  private
    const
      SpecsFolderName = 'specs';
      TestsFolderName = 'Tests';
      NameKey = 'name';
      MarkdownKey = 'markdown';
      DetectedKey = 'detected';
      DiagramKindKey = 'diagramKind';
      DirectionKey = 'direction';
      TitleKey = 'title';
      NodeCountKey = 'nodeCount';
      EdgeCountKey = 'edgeCount';
      ParticipantCountKey = 'participantCount';
      MessageCountKey = 'messageCount';
      NoteCountKey = 'noteCount';
      SliceCountKey = 'sliceCount';
    var
      FCases: TArray<TMermaidCorpusCase>;
    class function ResolveSpecFilePath(const FileName: string): string;

  public
    const
      CorpusFileName = 'mermaid.json';
    constructor Create;
    function Count: Integer;
    function GetCase(const Index: Integer): TMermaidCorpusCase;
    function FindCase(const Name: string): TMermaidCorpusCase;
    property Cases[const Index: Integer]: TMermaidCorpusCase read GetCase; default;
  end;

implementation

uses
  System.IOUtils,
  System.Generics.Collections,
  System.JSON;

constructor TMermaidCorpus.Create;
begin
  inherited Create;

  const FilePath = ResolveSpecFilePath(CorpusFileName);
  const Content = TFile.ReadAllText(FilePath, TEncoding.UTF8);
  const Root = TJSONObject.ParseJSONValue(Content);
  try
    const IsArray = (Root is TJSONArray);
    if not IsArray then
      raise EMermaidCorpusError.CreateFmt('Mermaid corpus "%s" does not contain a JSON array', [FilePath]);

    const Items = TJSONArray(Root);
    SetLength(FCases, Items.Count);

    for var Index := 0 to Items.Count - 1 do
    begin
      const Item = Items.Items[Index] as TJSONObject;
      FCases[Index].Name := Item.GetValue<string>(NameKey);
      FCases[Index].Markdown := Item.GetValue<string>(MarkdownKey);
      FCases[Index].Detected := Item.GetValue<Boolean>(DetectedKey);
      FCases[Index].DiagramKind := Item.GetValue<string>(DiagramKindKey, '');
      FCases[Index].Direction := Item.GetValue<string>(DirectionKey, '');
      FCases[Index].Title := Item.GetValue<string>(TitleKey, '');
      FCases[Index].NodeCount := Item.GetValue<Integer>(NodeCountKey, -1);
      FCases[Index].EdgeCount := Item.GetValue<Integer>(EdgeCountKey, -1);
      FCases[Index].ParticipantCount := Item.GetValue<Integer>(ParticipantCountKey, -1);
      FCases[Index].MessageCount := Item.GetValue<Integer>(MessageCountKey, -1);
      FCases[Index].NoteCount := Item.GetValue<Integer>(NoteCountKey, -1);
      FCases[Index].SliceCount := Item.GetValue<Integer>(SliceCountKey, -1);
    end;
  finally
    Root.Free;
  end;
end;

class function TMermaidCorpus.ResolveSpecFilePath(const FileName: string): string;
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

  raise EMermaidCorpusError.CreateFmt('Mermaid corpus "%s" was not found in a "%s" folder searching upward from "%s"',
    [FileName, SpecsFolderName, ParamStr(0)]);
end;

function TMermaidCorpus.Count: Integer;
begin
  Result := Length(FCases);
end;

function TMermaidCorpus.GetCase(const Index: Integer): TMermaidCorpusCase;
begin
  Result := FCases[Index];
end;

function TMermaidCorpus.FindCase(const Name: string): TMermaidCorpusCase;
begin
  for var Item in FCases do
  begin
    if Item.Name = Name then
      Exit(Item);
  end;

  raise EMermaidCorpusError.CreateFmt('Mermaid corpus does not contain a case named "%s"', [Name]);
end;

end.
