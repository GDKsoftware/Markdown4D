unit MarkdownPad.Controller;

// Framework-agnostic orchestration for the Markdown4D Pad demo: owns the
// document model (workspace/session/file-watcher) and the application logic
// shared by the VCL and FMX forms. It reaches the live editor/preview through
// IPadEditorView and the chrome/dialogs through IPadShell, so it never touches
// a VCL or FMX control directly.

interface

uses
  Markdown4D.Toc,
  MarkdownPad.Workspace.Interfaces,
  MarkdownPad.Session,
  MarkdownPad.FileWatcher,
  MarkdownPad.EditorView,
  MarkdownPad.Commands,
  MarkdownPad.CommandSet,
  MarkdownPad.Shell;

type
  TPadController = class
  private
    FEditor: IPadEditorView;
    FShell: IPadShell;
    FWorkspace: IPadWorkspace;
    FSession: TPadSession;
    FWatcher: TPadFileWatcher;
    FActiveDoc: IPadDocument;
    FMapDirty: Boolean;
    FSwapping: Boolean;
    FLastCaret: Integer;
    FCommands: TPadCommandRegistry;
    FActions: TPadCommandActions;
    FPaletteMatches: TArray<TPadCommandMatch>;
    FTocEntries: TArray<IMarkdownTocEntry>;
    procedure UpdateTitle;
    procedure UpdateStatusBar;
    procedure DoFileChanged(const Document: IPadDocument);
  public
    constructor Create(const Editor: IPadEditorView; const Shell: IPadShell;
      const SessionFileName: string);
    destructor Destroy; override;

    // Document lifecycle.
    procedure NewDocument;
    procedure OpenViaDialog;
    procedure OpenPath(const FileName: string);
    procedure Save;
    procedure SaveAs;
    function SaveActiveDocument: Boolean;
    procedure SaveToFile(const FileName: string);
    procedure SwitchToDocument(const Index: Integer);
    procedure CloseActiveDocument;
    procedure CloseDocumentAt(const Index: Integer);
    procedure RestoreSession;
    procedure SaveSession;

    // Command palette: the form supplies the action closures (they target its
    // own methods) and renders the list; the controller owns the registry, the
    // recent-file assembly and the matcher.
    procedure InitCommandRegistry(const Actions: TPadCommandActions);
    procedure RebuildPaletteCommands;
    procedure RefreshMatches(const Query: string);
    function PaletteMatchCount: Integer;
    procedure InvokePaletteCommand(const Index: Integer);

    // Editing loop: the form's event handlers and find bar delegate here; the
    // controller owns the state and drives the chrome through IPadShell and the
    // editor through IPadEditorView.
    procedure NotifyEditorChanged;
    procedure Tick;
    procedure RebuildSyncAndToc;
    procedure UpdateActiveTocEntry(const SourceLine: Integer);
    function TocEntryCount: Integer;
    function TocSourceLine(const Index: Integer): Integer;
    procedure FindInEditor;
    procedure UpdateFindCount;
    procedure ExecuteFind;
    procedure ExportHtml;
    procedure CopyHtml;
    function QueryClose: Boolean;

    // Model state the form reads back through its own accessors.
    property Workspace: IPadWorkspace read FWorkspace;
    property Session: TPadSession read FSession;
    property Watcher: TPadFileWatcher read FWatcher;
    property ActiveDocument: IPadDocument read FActiveDoc;
    property MapDirty: Boolean read FMapDirty write FMapDirty;
    property Swapping: Boolean read FSwapping write FSwapping;
    property LastCaret: Integer read FLastCaret write FLastCaret;
    property PaletteMatches: TArray<TPadCommandMatch> read FPaletteMatches;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Markdown4D,
  Markdown4D.Defines,
  MarkdownPad.CommandLine,
  MarkdownPad.Defines,
  MarkdownPad.Text,
  MarkdownPad.Outline,
  MarkdownPad.HtmlExport,
  MarkdownPad.Workspace,
  MarkdownPad.SessionSync;

constructor TPadController.Create(const Editor: IPadEditorView; const Shell: IPadShell;
  const SessionFileName: string);
begin
  inherited Create;

  FEditor := Editor;
  FShell := Shell;

  FWorkspace := TPadWorkspace.Create;
  FSession := TPadSession.Create(TPadSession.ResolvePath(SessionFileName));
  FSession.Load;
  FWatcher := TPadFileWatcher.Create(FWorkspace, DoFileChanged);
end;

destructor TPadController.Destroy;
begin
  FCommands.Free;
  FWatcher.Free;
  FSession.Free;

  inherited Destroy;
end;

procedure TPadController.NewDocument;
begin
  FWorkspace.NewDocument;
  SwitchToDocument(FWorkspace.ActiveIndex);
end;

procedure TPadController.OpenViaDialog;
begin
  var FileName: string;
  if FShell.PromptOpenFile(FileName) then
    OpenPath(FileName);
end;

procedure TPadController.OpenPath(const FileName: string);
begin
  if not TFile.Exists(FileName) then
    Exit;

  var Document: IPadDocument;
  try
    Document := FWorkspace.OpenFile(FileName);
  except
    on E: Exception do
    begin
      FShell.ShowOpenError(FileName, E.Message);
      Exit;
    end;
  end;

  FWatcher.Reset(Document);
  FSession.AddRecentFile(FileName);

  FShell.RebuildTabs;
  SwitchToDocument(FWorkspace.ActiveIndex);
end;

procedure TPadController.Save;
begin
  if FActiveDoc = nil then
    Exit;

  if FActiveDoc.IsUntitled then
    SaveAs
  else
    SaveToFile(FActiveDoc.FileName);
end;

procedure TPadController.SaveAs;
begin
  if FActiveDoc = nil then
    Exit;

  var Suggested := '';
  if not FActiveDoc.IsUntitled then
    Suggested := FActiveDoc.FileName;

  var FileName: string;
  if FShell.PromptSaveFile(Suggested, FileName) then
    SaveToFile(FileName);
end;

function TPadController.SaveActiveDocument: Boolean;
begin
  if FActiveDoc = nil then
    Exit(False);

  FActiveDoc.Text := FEditor.EditorText;

  if FActiveDoc.IsUntitled then
  begin
    var FileName: string;
    if not FShell.PromptSaveFile('', FileName) then
      Exit(False);

    SaveToFile(FileName);
  end
  else
    SaveToFile(FActiveDoc.FileName);

  Result := True;
end;

procedure TPadController.SaveToFile(const FileName: string);
begin
  FActiveDoc.Text := FEditor.EditorText;

  TFile.WriteAllText(FileName, FActiveDoc.Text);

  FActiveDoc.FileName := FileName;
  FActiveDoc.Modified := False;

  FWatcher.Reset(FActiveDoc);
  FSession.AddRecentFile(FileName);

  FShell.RebuildTabs;
  UpdateTitle;
end;

procedure TPadController.SwitchToDocument(const Index: Integer);
begin
  if FSwapping then
    Exit;

  FActiveDoc := TPadDocumentSwitch.Execute(FWorkspace, FEditor, FActiveDoc, Index);

  if FActiveDoc = nil then
    Exit;

  FLastCaret := -1;
  FMapDirty := True;

  FShell.RebuildTabs;
  UpdateTitle;
end;

procedure TPadController.CloseActiveDocument;
begin
  CloseDocumentAt(FWorkspace.ActiveIndex);
end;

procedure TPadController.CloseDocumentAt(const Index: Integer);
begin
  if (Index < 0) or (Index >= FWorkspace.Count) then
    Exit;

  if Index <> FWorkspace.ActiveIndex then
    SwitchToDocument(Index);

  if FActiveDoc = nil then
    Exit;

  if FActiveDoc.Modified then
  begin
    const Choice = FShell.ConfirmClose;

    if Choice = TPadCloseChoice.Cancel then
      Exit;

    if (Choice = TPadCloseChoice.Save) and not SaveActiveDocument then
      Exit;
  end;

  const ClosingIndex = FWorkspace.ActiveIndex;
  FActiveDoc := nil;
  FWorkspace.CloseDocument(ClosingIndex);

  if FWorkspace.Count = 0 then
  begin
    FShell.CloseApplication;
    Exit;
  end;

  FShell.RebuildTabs;
  SwitchToDocument(FWorkspace.ActiveIndex);
end;

procedure TPadController.RestoreSession;
begin
  // A file passed on the command line (Explorer opening a .md with the pad) is
  // added on top of the restored session and becomes the active tab. It also
  // replaces the sample document: starting from Explorer should show the file,
  // not the welcome text.
  const StartupFile = TPadCommandLine.DocumentPath;

  if not TPadSessionSync.RestoreOpenFiles(FWorkspace, FSession) and (StartupFile = '') then
  begin
    const Document = FWorkspace.NewDocument;
    Document.Text := FShell.SampleMarkdown;
  end;

  for var Index := 0 to FWorkspace.Count - 1 do
    FWatcher.Reset(FWorkspace.Documents[Index]);

  FShell.RebuildTabs;
  SwitchToDocument(FWorkspace.ActiveIndex);

  FShell.ApplyRestoredViewMode(FSession.ViewMode);

  if StartupFile <> '' then
    OpenPath(StartupFile);
end;

procedure TPadController.SaveSession;
begin
  if FActiveDoc <> nil then
    FActiveDoc.Text := FEditor.EditorText;

  var FilteredActive: Integer;
  const Titled = TPadSessionSync.CollectOpenFiles(FWorkspace, FilteredActive);

  FSession.SetOpenFiles(Titled, FilteredActive);
  FSession.DarkTheme := FShell.DarkThemeActive;
  FSession.ViewMode := FShell.EffectiveViewMode;

  FSession.Save;
end;

procedure TPadController.InitCommandRegistry(const Actions: TPadCommandActions);
begin
  FCommands := TPadCommandRegistry.Create;
  FActions := Actions;

  RegisterStaticPadCommands(FCommands, FActions);
end;

procedure TPadController.RebuildPaletteCommands;
begin
  FCommands.Clear;
  RegisterStaticPadCommands(FCommands, FActions);

  for var Path in FSession.RecentFiles do
  begin
    const RecentPath = Path;
    FCommands.Register(RecentPath, CatRecent, RecentShortcut,
      procedure
      begin
        OpenPath(RecentPath);
      end);
  end;
end;

procedure TPadController.RefreshMatches(const Query: string);
begin
  FPaletteMatches := FCommands.Match(Query);
end;

function TPadController.PaletteMatchCount: Integer;
begin
  Result := Length(FPaletteMatches);
end;

procedure TPadController.InvokePaletteCommand(const Index: Integer);
begin
  if (Index < 0) or (Index > High(FPaletteMatches)) then
    Exit;

  const Action = FPaletteMatches[Index].Command.Action;
  if Assigned(Action) then
    Action();
end;

procedure TPadController.UpdateTitle;
begin
  var Name := UntitledName;

  if FActiveDoc <> nil then
  begin
    Name := FActiveDoc.DisplayName;
    if FActiveDoc.Modified then
      Name := Name + ModifiedMarker;
  end;

  FShell.SetDocumentTitle(Name);
end;

procedure TPadController.UpdateStatusBar;
begin
  const Caret = FEditor.EditorCaret;
  if Caret = FLastCaret then
    Exit;

  FLastCaret := Caret;

  const Text = FEditor.EditorText;

  var Line, Column: Integer;
  TPadText.ComputeLineColumn(Text, Caret, Line, Column);

  const PositionText = Format(StatusPositionFormat, [Line, Column]);
  const WordsText = Format(StatusWordsFormat, [TPadText.CountWords(Text)]);

  FShell.SetStatus(PositionText, WordsText);
end;

procedure TPadController.NotifyEditorChanged;
begin
  if FSwapping then
    Exit;

  const WasModified = (FActiveDoc <> nil) and FActiveDoc.Modified;

  if FActiveDoc <> nil then
    FActiveDoc.Modified := True;

  FMapDirty := True;

  if not WasModified then
    FShell.RebuildTabs;

  UpdateTitle;
end;

procedure TPadController.Tick;
begin
  if FMapDirty then
    RebuildSyncAndToc;

  UpdateStatusBar;

  FWatcher.Poll;
end;

procedure TPadController.RebuildSyncAndToc;
begin
  FMapDirty := False;

  const Document = TMarkdown.Parse(FEditor.EditorText, TMarkdownDialect.Gfm);
  const Outline = TPadOutlineBuilder.Build(TMarkdownToc.FromDocument(Document));

  FTocEntries := Outline.Entries;

  FShell.SetTocCaptions(Outline.Captions);
end;

procedure TPadController.UpdateActiveTocEntry(const SourceLine: Integer);
begin
  const Best = TPadOutlineBuilder.ActiveIndex(FTocEntries, SourceLine);
  FShell.SetActiveTocIndex(Best);
end;

function TPadController.TocEntryCount: Integer;
begin
  Result := Length(FTocEntries);
end;

function TPadController.TocSourceLine(const Index: Integer): Integer;
begin
  Result := FTocEntries[Index].SourceLine - 1;
end;

procedure TPadController.FindInEditor;
begin
  const Needle = FShell.EditorFindNeedle;
  if Needle = '' then
  begin
    UpdateFindCount;
    Exit;
  end;

  FEditor.EditorFindNext(Needle);

  UpdateFindCount;
end;

procedure TPadController.UpdateFindCount;
begin
  const Needle = FShell.EditorFindNeedle;
  if Needle = '' then
  begin
    FShell.SetFindCount(EmptyFindCaption);
    Exit;
  end;

  const Total = FEditor.EditorFindMatchCount(Needle);

  if Total = 0 then
    FShell.SetFindCount(NoMatchCaption)
  else if Total = 1 then
    FShell.SetFindCount(SingleMatchCaption)
  else
    FShell.SetFindCount(Format(MatchCountFormat, [Total]));
end;

procedure TPadController.ExecuteFind;
begin
  const Needle = FShell.PreviewFindNeedle;
  if Needle = '' then
    Exit;

  FEditor.PreviewFindText(Needle);
end;

procedure TPadController.ExportHtml;
begin
  if FActiveDoc <> nil then
    FActiveDoc.Text := FEditor.EditorText;

  var Title := UntitledName;
  if FActiveDoc <> nil then
    Title := FActiveDoc.DisplayName;

  const SuggestedName = TPath.ChangeExtension(Title, '.' + HtmlExtension);

  var FileName: string;
  if not FShell.PromptExportHtml(SuggestedName, FileName) then
    Exit;

  const Html = TMarkdownHtmlExport.BuildDocument(FEditor.EditorText, Title, FShell.DarkThemeActive);
  TFile.WriteAllText(FileName, Html, TEncoding.UTF8);
end;

procedure TPadController.CopyHtml;
begin
  const Fragment = TMarkdown.ToHtml(FEditor.EditorText, TMarkdownDialect.Gfm);
  FShell.CopyHtmlToClipboard(Fragment);
end;

function TPadController.QueryClose: Boolean;
begin
  for var Index := 0 to FWorkspace.Count - 1 do
  begin
    const Document = FWorkspace.Documents[Index];
    if not Document.Modified then
      Continue;

    SwitchToDocument(Index);

    case FShell.ConfirmCloseDocument(Document.DisplayName) of
      TPadCloseChoice.Cancel:
        Exit(False);
      TPadCloseChoice.Save:
        if not SaveActiveDocument then
          Exit(False);
    end;

    Document.Modified := False;
  end;

  Result := True;
end;

procedure TPadController.DoFileChanged(const Document: IPadDocument);
begin
  if Document.Modified then
  begin
    if not FShell.ConfirmReload then
      Exit;
  end;

  var NewText: string;
  try
    NewText := TFile.ReadAllText(Document.FileName);
  except
    Document.DiskTimestampUtc := 0;
    Exit;
  end;

  Document.Text := NewText;
  Document.Modified := False;

  if Document = FActiveDoc then
  begin
    FSwapping := True;
    try
      FEditor.EditorText := NewText;
      FEditor.FlushPreview;

      if FEditor.EditorCaret > System.Length(NewText) then
        FEditor.EditorCaret := System.Length(NewText);
    finally
      FSwapping := False;
    end;

    FMapDirty := True;
  end;

  FShell.RebuildTabs;
  UpdateTitle;
end;

end.
