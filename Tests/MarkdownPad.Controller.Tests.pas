unit MarkdownPad.Controller.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.Model,
  MarkdownPad.Session,
  MarkdownPad.Shell,
  MarkdownPad.EditorView,
  MarkdownPad.Controller;

type
  // Stands in for the live editor/preview pair. It runs a real editor model, so
  // the merge semantics the controller relies on are exercised for real.
  TFakeEditorView = class(TInterfacedObject, IPadEditorView)
  strict private
    FModel: TMarkdownEditorModel;
    FPreviewScrollOffset: Single;
    FFirstVisibleSourceLine: Integer;
    FFlushCount: Integer;
    FSwapDepth: Integer;
    FHighlightedNeedle: string;
    function GetEditorText: string;
    procedure SetEditorText(const Value: string);
    function MergeEditorText(const Value: string): Boolean;
    function GetEditorCaret: Integer;
    procedure SetEditorCaret(const Value: Integer);
    function GetPreviewScrollOffset: Single;
    procedure SetPreviewScrollOffset(const Value: Single);
    function FirstVisibleSourceLine: Integer;
    procedure ScrollToSourceLine(const LineIndex: Integer);
    function SaveEditState: IMarkdownEditorState;
    procedure LoadEditState(const State: IMarkdownEditorState);
    procedure FlushPreview;
    procedure EditorFindNext(const Needle: string);
    function EditorFindMatchCount(const Needle: string): Integer;
    procedure EditorHighlightMatches(const Needle: string);
    function EditorReplaceCurrent(const Needle, Replacement: string): Boolean;
    function EditorReplaceAll(const Needle, Replacement: string): Integer;
    procedure PreviewFindText(const Needle: string);
    procedure BeginSwap;
    procedure EndSwap;

  public
    constructor Create;
    destructor Destroy; override;
    property FlushCount: Integer read FFlushCount;
    property HighlightedNeedle: string read FHighlightedNeedle;
    property VisibleLine: Integer read FFirstVisibleSourceLine write FFirstVisibleSourceLine;
  end;

  // Records what the controller asked the chrome to do and replays canned
  // answers for the dialogs.
  TFakeShell = class(TInterfacedObject, IPadShell)
  strict private
    FTitle: string;
    FRebuildTabsCount: Integer;
    FConflictChoice: TPadConflictChoice;
    FConflictPromptCount: Integer;
    FSaveErrorCount: Integer;
    FFindNeedle: string;
    FReplaceValue: string;
    FCloseChoice: TPadCloseChoice;
    procedure RebuildTabs;
    procedure SetDocumentTitle(const Name: string);
    procedure SetStatus(const PositionText, WordsText: string);
    procedure ApplyRestoredViewMode(const Mode: TPadViewMode);
    procedure SetTocCaptions(const Captions: TArray<string>);
    procedure SetActiveTocIndex(const Index: Integer);
    function EditorFindNeedle: string;
    function EditorReplaceValue: string;
    function PreviewFindNeedle: string;
    procedure SetFindCount(const Value: string);
    function SampleMarkdown: string;
    function DarkThemeActive: Boolean;
    function EffectiveViewMode: TPadViewMode;
    function PromptOpenFile(out FileName: string): Boolean;
    function PromptSaveFile(const SuggestedName: string; out FileName: string): Boolean;
    function PromptExportHtml(const SuggestedName: string; out FileName: string): Boolean;
    function ConfirmClose: TPadCloseChoice;
    function ConfirmCloseDocument(const DocName: string): TPadCloseChoice;
    function ConfirmSaveOverChangedFile(const DocName: string): TPadConflictChoice;
    procedure ShowOpenError(const FileName, ErrorMessage: string);
    procedure ShowSaveError(const FileName, ErrorMessage: string);
    procedure CopyHtmlToClipboard(const Fragment: string);
    procedure CloseApplication;

  public
    constructor Create;
    property Title: string read FTitle;
    property RebuildTabsCount: Integer read FRebuildTabsCount;
    property SaveErrorCount: Integer read FSaveErrorCount;
    property ConflictChoice: TPadConflictChoice read FConflictChoice write FConflictChoice;
    property ConflictPromptCount: Integer read FConflictPromptCount;
    property CloseChoice: TPadCloseChoice read FCloseChoice write FCloseChoice;
    property FindNeedle: string read FFindNeedle write FFindNeedle;
    property ReplaceValue: string read FReplaceValue write FReplaceValue;
  end;

  [TestFixture]
  TPadControllerTests = class
  private
    const
      OriginalText = 'first line'#10'second line'#10'third line';
      ExternalText = 'first line'#10'second line'#10'third line'#10'fourth line';
    var
      FEditorView: TFakeEditorView;
      FShell: TFakeShell;
      FView: IPadEditorView;
      FShellRef: IPadShell;
      FController: TPadController;
      FFileName: string;
      FSessionName: string;
    procedure WriteExternal(const Text: string);
    procedure OpenSampleFile;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure ExternalChange_CleanBuffer_MergesAndKeepsCaret;

    [Test]
    procedure ExternalChange_IdenticalContent_LeavesBufferUntouched;

    [Test]
    procedure ExternalChange_ModifiedBuffer_FlagsConflictWithoutPrompting;

    [Test]
    procedure Save_WithConflict_Overwrite_WritesBufferAndClearsFlag;

    [Test]
    procedure Save_WithConflict_Cancel_LeavesFileAndFlagAlone;

    [Test]
    procedure Save_WithConflict_Reload_TakesDiskTextAndSkipsWrite;

    [Test]
    procedure Save_WithoutConflict_DoesNotPrompt;

    [Test]
    procedure Reopen_AfterClose_RestoresRememberedCaret;

    [Test]
    procedure Reopen_SessionPositionFromEarlierRun_IsApplied;

    [Test]
    procedure Find_HighlightsEveryMatch;

    [Test]
    procedure Replace_ReplacesTheSelectedMatch;

    [Test]
    procedure ReplaceAll_ReplacesEveryMatch;

    [Test]
    procedure Save_CrlfDocument_KeepsCrlfOnDisk;

    [Test]
    procedure Save_Utf8WithoutBom_StaysWithoutBom;

    [Test]
    procedure Save_ReadOnlyFile_ReportsErrorAndKeepsDocumentModified;

    [Test]
    procedure DeletedFile_MarksDocumentAndKeepsBuffer;

    [Test]
    procedure DeletedFile_SaveRecreatesFileAndClearsFlag;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.DateUtils;

constructor TFakeEditorView.Create;
begin
  inherited Create;

  FModel := TMarkdownEditorModel.Create;
end;

destructor TFakeEditorView.Destroy;
begin
  FModel.Free;

  inherited Destroy;
end;

function TFakeEditorView.GetEditorText: string;
begin
  Result := FModel.Text;
end;

procedure TFakeEditorView.SetEditorText(const Value: string);
begin
  FModel.LoadText(Value);
end;

function TFakeEditorView.MergeEditorText(const Value: string): Boolean;
begin
  Result := FModel.MergeText(Value);
end;

function TFakeEditorView.GetEditorCaret: Integer;
begin
  Result := FModel.CaretPosition;
end;

procedure TFakeEditorView.SetEditorCaret(const Value: Integer);
begin
  FModel.CaretPosition := Value;
end;

function TFakeEditorView.GetPreviewScrollOffset: Single;
begin
  Result := FPreviewScrollOffset;
end;

procedure TFakeEditorView.SetPreviewScrollOffset(const Value: Single);
begin
  FPreviewScrollOffset := Value;
end;

function TFakeEditorView.FirstVisibleSourceLine: Integer;
begin
  Result := FFirstVisibleSourceLine;
end;

procedure TFakeEditorView.ScrollToSourceLine(const LineIndex: Integer);
begin
  FFirstVisibleSourceLine := LineIndex;
end;

function TFakeEditorView.SaveEditState: IMarkdownEditorState;
begin
  Result := FModel.CaptureState;
end;

procedure TFakeEditorView.LoadEditState(const State: IMarkdownEditorState);
begin
  FModel.RestoreState(State);
end;

procedure TFakeEditorView.FlushPreview;
begin
  Inc(FFlushCount);
end;

procedure TFakeEditorView.EditorFindNext(const Needle: string);
begin
  FModel.FindNext(Needle, FModel.CaretPosition);
end;

function TFakeEditorView.EditorFindMatchCount(const Needle: string): Integer;
begin
  Result := FModel.FindText(Needle);
end;

procedure TFakeEditorView.EditorHighlightMatches(const Needle: string);
begin
  FHighlightedNeedle := Needle;
end;

function TFakeEditorView.EditorReplaceCurrent(const Needle, Replacement: string): Boolean;
begin
  Result := FModel.ReplaceCurrent(Needle, Replacement, Default(TMarkdownFindOptions));
end;

function TFakeEditorView.EditorReplaceAll(const Needle, Replacement: string): Integer;
begin
  Result := FModel.ReplaceAll(Needle, Replacement, Default(TMarkdownFindOptions));
end;

procedure TFakeEditorView.PreviewFindText(const Needle: string);
begin
  // The preview is not part of these tests.
end;

procedure TFakeEditorView.BeginSwap;
begin
  Inc(FSwapDepth);
end;

procedure TFakeEditorView.EndSwap;
begin
  Dec(FSwapDepth);
end;

constructor TFakeShell.Create;
begin
  inherited Create;

  FConflictChoice := TPadConflictChoice.Cancel;
  FCloseChoice := TPadCloseChoice.Discard;
end;

procedure TFakeShell.RebuildTabs;
begin
  Inc(FRebuildTabsCount);
end;

procedure TFakeShell.SetDocumentTitle(const Name: string);
begin
  FTitle := Name;
end;

procedure TFakeShell.SetStatus(const PositionText, WordsText: string);
begin
  // Status text is not asserted on.
end;

procedure TFakeShell.ApplyRestoredViewMode(const Mode: TPadViewMode);
begin
  // View mode is owned by the form.
end;

procedure TFakeShell.SetTocCaptions(const Captions: TArray<string>);
begin
  // The outline list is owned by the form.
end;

procedure TFakeShell.SetActiveTocIndex(const Index: Integer);
begin
  // The outline list is owned by the form.
end;

function TFakeShell.EditorFindNeedle: string;
begin
  Result := FFindNeedle;
end;

function TFakeShell.EditorReplaceValue: string;
begin
  Result := FReplaceValue;
end;

function TFakeShell.PreviewFindNeedle: string;
begin
  Result := '';
end;

procedure TFakeShell.SetFindCount(const Value: string);
begin
  // The find label is not asserted on.
end;

function TFakeShell.SampleMarkdown: string;
begin
  Result := '# Sample';
end;

function TFakeShell.DarkThemeActive: Boolean;
begin
  Result := False;
end;

function TFakeShell.EffectiveViewMode: TPadViewMode;
begin
  Result := TPadViewMode.Split;
end;

function TFakeShell.PromptOpenFile(out FileName: string): Boolean;
begin
  FileName := '';
  Result := False;
end;

function TFakeShell.PromptSaveFile(const SuggestedName: string; out FileName: string): Boolean;
begin
  FileName := '';
  Result := False;
end;

function TFakeShell.PromptExportHtml(const SuggestedName: string; out FileName: string): Boolean;
begin
  FileName := '';
  Result := False;
end;

function TFakeShell.ConfirmClose: TPadCloseChoice;
begin
  Result := FCloseChoice;
end;

function TFakeShell.ConfirmCloseDocument(const DocName: string): TPadCloseChoice;
begin
  Result := FCloseChoice;
end;

function TFakeShell.ConfirmSaveOverChangedFile(const DocName: string): TPadConflictChoice;
begin
  Inc(FConflictPromptCount);
  Result := FConflictChoice;
end;

procedure TFakeShell.ShowOpenError(const FileName, ErrorMessage: string);
begin
  // Open errors are not part of these tests.
end;

procedure TFakeShell.ShowSaveError(const FileName, ErrorMessage: string);
begin
  Inc(FSaveErrorCount);
end;

procedure TFakeShell.CopyHtmlToClipboard(const Fragment: string);
begin
  // The clipboard is not part of these tests.
end;

procedure TFakeShell.CloseApplication;
begin
  // Closing the app is not part of these tests.
end;

procedure TPadControllerTests.Setup;
begin
  FEditorView := TFakeEditorView.Create;
  FView := FEditorView;

  FShell := TFakeShell.Create;
  FShellRef := FShell;

  FSessionName := Format('MarkdownPad.ControllerTests.%s.json', [TPath.GetGUIDFileName]);
  FController := TPadController.Create(FView, FShellRef, FSessionName);

  FFileName := TPath.Combine(TPath.GetTempPath, Format('%s.md', [TPath.GetGUIDFileName]));
  TFile.WriteAllText(FFileName, OriginalText);
end;

procedure TPadControllerTests.TearDown;
begin
  FController.Free;

  FView := nil;
  FShellRef := nil;

  if TFile.Exists(FFileName) then
    TFile.Delete(FFileName);

  const SessionPath = TPadSession.ResolvePath(FSessionName);
  if TFile.Exists(SessionPath) then
    TFile.Delete(SessionPath);
end;

procedure TPadControllerTests.WriteExternal(const Text: string);
begin
  TFile.WriteAllText(FFileName, Text);

  // Poll compares timestamps, so a same-second rewrite has to be aged by hand.
  TFile.SetLastWriteTimeUtc(FFileName, IncMinute(TFile.GetLastWriteTimeUtc(FFileName), 1));
end;

procedure TPadControllerTests.OpenSampleFile;
begin
  FController.OpenPath(FFileName);
end;

procedure TPadControllerTests.ExternalChange_CleanBuffer_MergesAndKeepsCaret;
begin
  OpenSampleFile;
  FView.EditorCaret := 6;
  FEditorView.VisibleLine := 2;

  WriteExternal(ExternalText);
  FController.Tick;

  Assert.AreEqual(ExternalText, FView.EditorText);
  Assert.AreEqual(6, FView.EditorCaret);
  Assert.AreEqual(2, FEditorView.VisibleLine);
  Assert.IsFalse(FController.ActiveDocument.Modified);
  Assert.IsFalse(FController.ActiveDocument.DiskConflict);
end;

procedure TPadControllerTests.ExternalChange_IdenticalContent_LeavesBufferUntouched;
begin
  OpenSampleFile;
  const FlushesAfterOpen = FEditorView.FlushCount;

  WriteExternal(OriginalText);
  FController.Tick;

  Assert.AreEqual(OriginalText, FView.EditorText);
  Assert.AreEqual(FlushesAfterOpen, FEditorView.FlushCount);
end;

procedure TPadControllerTests.ExternalChange_ModifiedBuffer_FlagsConflictWithoutPrompting;
begin
  OpenSampleFile;
  FView.EditorText := 'my own version';
  FController.NotifyEditorChanged;

  WriteExternal(ExternalText);
  FController.Tick;

  Assert.IsTrue(FController.ActiveDocument.DiskConflict);
  Assert.AreEqual('my own version', FView.EditorText);
  Assert.AreEqual(0, FShell.ConflictPromptCount);
  Assert.IsTrue(FShell.Title.Contains('(!)'));
end;

procedure TPadControllerTests.Save_WithConflict_Overwrite_WritesBufferAndClearsFlag;
begin
  OpenSampleFile;
  FView.EditorText := 'my own version';
  FController.NotifyEditorChanged;

  WriteExternal(ExternalText);
  FController.Tick;

  FShell.ConflictChoice := TPadConflictChoice.Overwrite;
  Assert.IsTrue(FController.SaveActiveDocument);

  Assert.AreEqual(1, FShell.ConflictPromptCount);
  Assert.AreEqual('my own version', TFile.ReadAllText(FFileName));
  Assert.IsFalse(FController.ActiveDocument.DiskConflict);
  Assert.IsFalse(FController.ActiveDocument.Modified);
end;

procedure TPadControllerTests.Save_WithConflict_Cancel_LeavesFileAndFlagAlone;
begin
  OpenSampleFile;
  FView.EditorText := 'my own version';
  FController.NotifyEditorChanged;

  WriteExternal(ExternalText);
  FController.Tick;

  FShell.ConflictChoice := TPadConflictChoice.Cancel;
  Assert.IsFalse(FController.SaveActiveDocument);

  Assert.AreEqual(ExternalText, TFile.ReadAllText(FFileName));
  Assert.IsTrue(FController.ActiveDocument.DiskConflict);
  Assert.AreEqual('my own version', FView.EditorText);
end;

procedure TPadControllerTests.Save_WithConflict_Reload_TakesDiskTextAndSkipsWrite;
begin
  OpenSampleFile;
  FView.EditorText := 'my own version';
  FController.NotifyEditorChanged;

  WriteExternal(ExternalText);
  FController.Tick;

  FShell.ConflictChoice := TPadConflictChoice.Reload;
  Assert.IsFalse(FController.SaveActiveDocument);

  Assert.AreEqual(ExternalText, TFile.ReadAllText(FFileName));
  Assert.AreEqual(ExternalText, FView.EditorText);
  Assert.IsFalse(FController.ActiveDocument.DiskConflict);
  Assert.IsFalse(FController.ActiveDocument.Modified);
end;

procedure TPadControllerTests.Save_WithoutConflict_DoesNotPrompt;
begin
  OpenSampleFile;
  FView.EditorText := 'edited without any external change';
  FController.NotifyEditorChanged;

  Assert.IsTrue(FController.SaveActiveDocument);

  Assert.AreEqual(0, FShell.ConflictPromptCount);
  Assert.AreEqual('edited without any external change', TFile.ReadAllText(FFileName));
end;

procedure TPadControllerTests.Reopen_AfterClose_RestoresRememberedCaret;
begin
  OpenSampleFile;
  FView.EditorCaret := 17;
  FEditorView.VisibleLine := 1;

  FController.CloseDocumentAt(FController.Workspace.ActiveIndex);
  OpenSampleFile;

  Assert.AreEqual(17, FView.EditorCaret);
  Assert.AreEqual(1, FEditorView.VisibleLine);
end;

procedure TPadControllerTests.Reopen_SessionPositionFromEarlierRun_IsApplied;
begin
  FController.Session.StoreFilePosition(TPadFilePosition.Create(FFileName, 12, 2, 0));

  OpenSampleFile;

  Assert.AreEqual(12, FView.EditorCaret);
  Assert.AreEqual(2, FEditorView.VisibleLine);
end;

procedure TPadControllerTests.Find_HighlightsEveryMatch;
begin
  OpenSampleFile;
  FShell.FindNeedle := 'line';

  FController.UpdateFindCount;

  Assert.AreEqual('line', FEditorView.HighlightedNeedle);
end;

procedure TPadControllerTests.Replace_ReplacesTheSelectedMatch;
begin
  OpenSampleFile;
  FShell.FindNeedle := 'second';
  FShell.ReplaceValue := 'SECOND';

  FController.FindInEditor;
  FController.ReplaceInEditor;

  Assert.AreEqual('first line'#10'SECOND line'#10'third line', FView.EditorText);
end;

procedure TPadControllerTests.ReplaceAll_ReplacesEveryMatch;
begin
  OpenSampleFile;
  FShell.FindNeedle := 'line';
  FShell.ReplaceValue := 'row';

  FController.ReplaceAllInEditor;

  Assert.AreEqual('first row'#10'second row'#10'third row', FView.EditorText);
end;

procedure TPadControllerTests.Save_CrlfDocument_KeepsCrlfOnDisk;
begin
  TFile.WriteAllBytes(FFileName, TEncoding.UTF8.GetBytes('first line'#13#10'second line'));

  OpenSampleFile;
  FView.EditorText := 'first line'#10'second line'#10'third line';
  FController.NotifyEditorChanged;

  Assert.IsTrue(FController.SaveActiveDocument);

  const OnDisk = TEncoding.UTF8.GetString(TFile.ReadAllBytes(FFileName));
  Assert.AreEqual('first line'#13#10'second line'#13#10'third line', OnDisk);
end;

procedure TPadControllerTests.Save_Utf8WithoutBom_StaysWithoutBom;
begin
  TFile.WriteAllBytes(FFileName, TEncoding.UTF8.GetBytes('caf'#$00E9));

  OpenSampleFile;
  Assert.AreEqual('caf'#$00E9, FView.EditorText);

  FView.EditorText := 'caf'#$00E9' au lait';
  FController.NotifyEditorChanged;
  Assert.IsTrue(FController.SaveActiveDocument);

  const Bytes = TFile.ReadAllBytes(FFileName);
  Assert.AreNotEqual($EF, Integer(Bytes[0]));
  Assert.AreEqual('caf'#$00E9' au lait', TEncoding.UTF8.GetString(Bytes));
end;

procedure TPadControllerTests.Save_ReadOnlyFile_ReportsErrorAndKeepsDocumentModified;
begin
  OpenSampleFile;
  FView.EditorText := 'edited';
  FController.NotifyEditorChanged;

  // An exclusive lock stands in for the everyday cases: a sync client holding
  // the file, an antivirus scan, or a read-only copy.
  const Lock = TFileStream.Create(FFileName, fmOpenRead or fmShareExclusive);
  try
    Assert.IsFalse(FController.SaveActiveDocument);
  finally
    Lock.Free;
  end;

  Assert.AreEqual(1, FShell.SaveErrorCount);
  Assert.IsTrue(FController.ActiveDocument.Modified);
  Assert.AreEqual(OriginalText, TFile.ReadAllText(FFileName));
end;

procedure TPadControllerTests.DeletedFile_MarksDocumentAndKeepsBuffer;
begin
  OpenSampleFile;

  TFile.Delete(FFileName);
  FController.Tick;

  Assert.IsTrue(FController.ActiveDocument.DiskMissing);
  Assert.IsTrue(FController.ActiveDocument.Modified);
  Assert.AreEqual(OriginalText, FView.EditorText);
  Assert.IsTrue(FShell.Title.Contains('deleted'));
end;

procedure TPadControllerTests.DeletedFile_SaveRecreatesFileAndClearsFlag;
begin
  OpenSampleFile;

  TFile.Delete(FFileName);
  FController.Tick;

  Assert.IsTrue(FController.SaveActiveDocument);

  Assert.IsTrue(TFile.Exists(FFileName));
  Assert.IsFalse(FController.ActiveDocument.DiskMissing);
  Assert.IsFalse(FController.ActiveDocument.Modified);
end;

end.
