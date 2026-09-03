unit Markdown4DStudio.Session;

{$SCOPEDENUMS ON}

interface

type
  TPadViewMode = (EditorOnly, Split, PreviewOnly);

  // Where the user left off in a file: caret offset, the source line that was at
  // the top of the editor, and the preview's scroll offset. Kept per path so
  // reopening a file lands on the same spot, even across app restarts.
  TPadFilePosition = record
    FileName: string;
    Caret: Integer;
    EditorLine: Integer;
    PreviewOffset: Single;
    class function Create(const FileName: string; const Caret, EditorLine: Integer;
      const PreviewOffset: Single): TPadFilePosition; static;
  end;

  TPadSession = class
  strict private
    const
      MaxRecentFiles = 10;
      MaxFilePositions = 50;
    var
      FFilePath: string;
      FOpenFiles: TArray<string>;
      FActiveIndex: Integer;
      FRecentFiles: TArray<string>;
      FFilePositions: TArray<TPadFilePosition>;
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
    procedure StoreFilePosition(const Position: TPadFilePosition);
    function TryFilePosition(const FileName: string; out Position: TPadFilePosition): Boolean;
    property FilePath: string read FFilePath;
    property FilePositions: TArray<TPadFilePosition> read FFilePositions;
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
  FilePositionsKey = 'filePositions';
  PositionPathKey = 'path';
  PositionCaretKey = 'caret';
  PositionLineKey = 'line';
  PositionPreviewKey = 'preview';
  DarkThemeKey = 'darkTheme';
  ViewModeKey = 'viewMode';
  ViewModeEditorText = 'editor';
  ViewModeSplitText = 'split';
  ViewModePreviewText = 'preview';

class function TPadFilePosition.Create(const FileName: string; const Caret, EditorLine: Integer;
  const PreviewOffset: Single): TPadFilePosition;
begin
  Result.FileName := FileName;
  Result.Caret := Caret;
  Result.EditorLine := EditorLine;
  Result.PreviewOffset := PreviewOffset;
end;

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
  FFilePositions := [];
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

    var PositionArray: TJSONArray := nil;
    if Obj.TryGetValue<TJSONArray>(FilePositionsKey, PositionArray) then
    begin
      FFilePositions := [];

      for var Element in PositionArray do
      begin
        if Length(FFilePositions) >= MaxFilePositions then
          Break;

        if not (Element is TJSONObject) then
          Continue;

        const Entry = TJSONObject(Element);

        var Path: string;
        if not Entry.TryGetValue<string>(PositionPathKey, Path) or (Path = '') then
          Continue;

        var Caret := 0;
        Entry.TryGetValue<Integer>(PositionCaretKey, Caret);

        var Line := 0;
        Entry.TryGetValue<Integer>(PositionLineKey, Line);

        var Preview := Single(0);
        var PreviewNumber: TJSONNumber := nil;
        if Entry.TryGetValue<TJSONNumber>(PositionPreviewKey, PreviewNumber) then
          Preview := PreviewNumber.AsDouble;

        FFilePositions := FFilePositions + [TPadFilePosition.Create(Path, Caret, Line, Preview)];
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

    var PositionArray: TJSONArray := TJSONArray.Create;
    for var Position in FFilePositions do
    begin
      if PositionArray.Count >= MaxFilePositions then
        Break;

      var Entry: TJSONObject := TJSONObject.Create;
      Entry.AddPair(PositionPathKey, Position.FileName);
      Entry.AddPair(PositionCaretKey, TJSONNumber.Create(Position.Caret));
      Entry.AddPair(PositionLineKey, TJSONNumber.Create(Position.EditorLine));
      Entry.AddPair(PositionPreviewKey, TJSONNumber.Create(Position.PreviewOffset));
      PositionArray.Add(Entry);
    end;
    Root.AddPair(FilePositionsKey, PositionArray);

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

procedure TPadSession.StoreFilePosition(const Position: TPadFilePosition);
begin
  if Position.FileName = '' then
    Exit;

  var Updated: TArray<TPadFilePosition> := [Position];

  for var Existing in FFilePositions do
  begin
    if Length(Updated) >= MaxFilePositions then
      Break;

    if not SameText(Existing.FileName, Position.FileName) then
      Updated := Updated + [Existing];
  end;

  FFilePositions := Updated;
end;

function TPadSession.TryFilePosition(const FileName: string; out Position: TPadFilePosition): Boolean;
begin
  for var Existing in FFilePositions do
  begin
    if SameText(Existing.FileName, FileName) then
    begin
      Position := Existing;
      Exit(True);
    end;
  end;

  Position := Default(TPadFilePosition);
  Result := False;
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
