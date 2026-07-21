unit MarkdownPad.Session;

{$SCOPEDENUMS ON}

interface

type
  TPadViewMode = (EditorOnly, Split, PreviewOnly);

  TPadSession = class
  strict private
    const
      MaxRecentFiles = 10;
    var
      FFilePath: string;
      FOpenFiles: TArray<string>;
      FActiveIndex: Integer;
      FRecentFiles: TArray<string>;
      FDarkTheme: Boolean;
      FViewMode: TPadViewMode;
    class function ViewModeToText(const Mode: TPadViewMode): string; static;
    class function ViewModeFromText(const Value: string): TPadViewMode; static;

  public
    class function DefaultDirectory: string; static;
    class function ResolvePath(const FileBaseName: string): string; static;
    constructor Create(const FilePath: string);
    procedure Load;
    procedure Save;
    procedure AddRecentFile(const FileName: string);
    procedure SetOpenFiles(const Files: TArray<string>; const ActiveIndex: Integer);
    property FilePath: string read FFilePath;
    property OpenFiles: TArray<string> read FOpenFiles;
    property ActiveIndex: Integer read FActiveIndex write FActiveIndex;
    property RecentFiles: TArray<string> read FRecentFiles;
    property DarkTheme: Boolean read FDarkTheme write FDarkTheme;
    property ViewMode: TPadViewMode read FViewMode write FViewMode;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.JSON;

const
  Markdown4DDirectory = 'Markdown4D';
  AppDataVariable = 'APPDATA';
  OpenFilesKey = 'openFiles';
  ActiveIndexKey = 'activeIndex';
  RecentFilesKey = 'recentFiles';
  DarkThemeKey = 'darkTheme';
  ViewModeKey = 'viewMode';
  ViewModeEditorText = 'editor';
  ViewModeSplitText = 'split';
  ViewModePreviewText = 'preview';

class function TPadSession.DefaultDirectory: string;
begin
  Result := TPath.Combine(GetEnvironmentVariable(AppDataVariable), Markdown4DDirectory);
end;

class function TPadSession.ResolvePath(const FileBaseName: string): string;
begin
  Result := TPath.Combine(DefaultDirectory, FileBaseName);
end;

constructor TPadSession.Create(const FilePath: string);
begin
  inherited Create;

  FFilePath := FilePath;
  FOpenFiles := [];
  FActiveIndex := -1;
  FRecentFiles := [];
  FDarkTheme := False;
  FViewMode := TPadViewMode.Split;
end;

procedure TPadSession.Load;
begin
  if not TFile.Exists(FFilePath) then
    Exit;

  var Root: TJSONValue := TJSONObject.ParseJSONValue(TFile.ReadAllText(FFilePath));
  try
    if not (Root is TJSONObject) then
      Exit;

    const Obj = TJSONObject(Root);

    var OpenArray: TJSONArray := nil;
    if Obj.TryGetValue<TJSONArray>(OpenFilesKey, OpenArray) then
    begin
      FOpenFiles := [];

      for var Element in OpenArray do
      begin
        if Element is TJSONString then
          FOpenFiles := FOpenFiles + [TJSONString(Element).Value];
      end;
    end;

    var RecentArray: TJSONArray := nil;
    if Obj.TryGetValue<TJSONArray>(RecentFilesKey, RecentArray) then
    begin
      FRecentFiles := [];

      for var Element in RecentArray do
      begin
        if Length(FRecentFiles) >= MaxRecentFiles then
          Break;

        if Element is TJSONString then
          FRecentFiles := FRecentFiles + [TJSONString(Element).Value];
      end;
    end;

    var IndexValue: Integer;
    if Obj.TryGetValue<Integer>(ActiveIndexKey, IndexValue) then
      FActiveIndex := IndexValue;

    var DarkValue: Boolean;
    if Obj.TryGetValue<Boolean>(DarkThemeKey, DarkValue) then
      FDarkTheme := DarkValue;

    var ViewValue: string;
    if Obj.TryGetValue<string>(ViewModeKey, ViewValue) then
      FViewMode := ViewModeFromText(ViewValue);
  finally
    Root.Free;
  end;
end;

procedure TPadSession.Save;
begin
  const DirectoryName = TPath.GetDirectoryName(FFilePath);
  if DirectoryName <> '' then
    TDirectory.CreateDirectory(DirectoryName);

  var Root: TJSONObject := TJSONObject.Create;
  try
    var OpenArray: TJSONArray := TJSONArray.Create;
    for var FileName in FOpenFiles do
    begin
      OpenArray.Add(FileName);
    end;
    Root.AddPair(OpenFilesKey, OpenArray);

    Root.AddPair(ActiveIndexKey, TJSONNumber.Create(FActiveIndex));

    var RecentArray: TJSONArray := TJSONArray.Create;
    for var FileName in FRecentFiles do
    begin
      RecentArray.Add(FileName);
    end;
    Root.AddPair(RecentFilesKey, RecentArray);

    Root.AddPair(DarkThemeKey, TJSONBool.Create(FDarkTheme));

    Root.AddPair(ViewModeKey, ViewModeToText(FViewMode));

    TFile.WriteAllText(FFilePath, Root.ToJSON);
  finally
    Root.Free;
  end;
end;

procedure TPadSession.AddRecentFile(const FileName: string);
begin
  if FileName = '' then
    Exit;

  var Updated: TArray<string> := [FileName];

  for var Existing in FRecentFiles do
  begin
    if Length(Updated) >= MaxRecentFiles then
      Break;

    if not SameText(Existing, FileName) then
      Updated := Updated + [Existing];
  end;

  FRecentFiles := Updated;
end;

procedure TPadSession.SetOpenFiles(const Files: TArray<string>; const ActiveIndex: Integer);
begin
  var Kept: TArray<string> := [];

  for var FileName in Files do
  begin
    if FileName <> '' then
      Kept := Kept + [FileName];
  end;

  FOpenFiles := Kept;

  if ActiveIndex < 0 then
    FActiveIndex := -1
  else if ActiveIndex > High(Kept) then
    FActiveIndex := High(Kept)
  else
    FActiveIndex := ActiveIndex;
end;

class function TPadSession.ViewModeToText(const Mode: TPadViewMode): string;
begin
  case Mode of
    TPadViewMode.EditorOnly:
      Result := ViewModeEditorText;
    TPadViewMode.PreviewOnly:
      Result := ViewModePreviewText;
  else
    Result := ViewModeSplitText;
  end;
end;

class function TPadSession.ViewModeFromText(const Value: string): TPadViewMode;
begin
  if Value = ViewModeEditorText then
    Result := TPadViewMode.EditorOnly
  else if Value = ViewModePreviewText then
    Result := TPadViewMode.PreviewOnly
  else
    Result := TPadViewMode.Split;
end;

end.
