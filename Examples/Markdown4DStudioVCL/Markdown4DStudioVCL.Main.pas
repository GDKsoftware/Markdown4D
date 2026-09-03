unit Markdown4DStudioVCL.Main;

{$SCOPEDENUMS ON}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Classes,
  System.Types,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Buttons,
  Vcl.Graphics,
  Vcl.Menus,
  Vcl.Dialogs,
  Vcl.TitleBarCtrls,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Toc,
  Markdown4D.Editor.Model,
  Markdown4D.Editor.Sync,
  Markdown4D.Theme,
  Markdown4D.Vcl.Editor,
  Markdown4D.Vcl.Viewer,
  Markdown4DStudio.Workspace.Interfaces,
  Markdown4DStudio.EditorView,
  Markdown4DStudio.Session,
  Markdown4DStudio.Commands,
  Markdown4DStudio.CommandSet,
  Markdown4DStudio.TabStrip,
  Markdown4DStudio.FileWatcher,
  Markdown4DStudio.Shell,
  Markdown4DStudio.Controller,
  Markdown4DStudioVCL.Defines;

type
  TMarkdown4DStudioVCLForm = class(TForm, IPadEditorView, IPadShell)
    pnlToolbar: TPanel;
    pnlFind: TPanel;
    pnlStatus: TPanel;
    pnlToc: TPanel;
    splToc: TSplitter;
    splMain: TSplitter;
    lstToc: TListBox;
    dlgOpen: TOpenDialog;
    dlgSave: TSaveDialog;
    dlgSaveHtml: TSaveDialog;
    tmrTick: TTimer;
    popRecent: TPopupMenu;
    mdEditor: TMarkdownEditor;
    mdPreview: TMarkdownViewer;
    lblPos: TLabel;
    lblWords: TLabel;
    edtEditorFind: TEdit;
    lblFindCount: TLabel;
    procedure HandleFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure HandleResize(Sender: TObject);
    procedure HandleEditorChange(Sender: TObject);
    procedure HandleSyncScroll(Sender: TObject; const SourceLine: Integer);
    procedure HandlePreviewLinkClick(const Sender: TObject; const Url: string);
    procedure HandleTocListClick(Sender: TObject);
    procedure HandleTick(Sender: TObject);
    procedure HandleEditorFindChange(Sender: TObject);
  private
    type
      TPadChrome = record
        ToolbarColor: TColor;
        IconColor: TColor;
        SeparatorColor: TColor;
        ActiveTabColor: TColor;
        HoverTabColor: TColor;
      end;
    var
      FIconFontName: string;
      FNewButton: TSpeedButton;
      FOpenButton: TSpeedButton;
      FSaveButton: TSpeedButton;
      FSaveAsButton: TSpeedButton;
      FRecentButton: TSpeedButton;
      FExportButton: TSpeedButton;
      FCopyHtmlButton: TSpeedButton;
      FBoldButton: TSpeedButton;
      FItalicButton: TSpeedButton;
      FLinkButton: TSpeedButton;
      FCodeButton: TSpeedButton;
      FThemeButton: TSpeedButton;
      FTocButton: TSpeedButton;
      FZenButton: TSpeedButton;
      FCommandsButton: TSpeedButton;
      FFindButton: TSpeedButton;
      FFindEdit: TEdit;
      FIconButtons: TArray<TSpeedButton>;
      FSeparators: TArray<TPanel>;
      FLightTheme: TMarkdownTheme;
      FDarkTheme: TMarkdownTheme;
      FDarkThemeActive: Boolean;
      FTitleBar: TTitleBarPanel;
      FTabStrip: TPadTabStrip;
      FUseCustomTitleBar: Boolean;
      FTitleBarColor: TColor;
      FTitleBarWndProc: TWndMethod;
      FController: TPadController;
      FViewMode: TPadViewMode;
      FSplitEditorWidth: Integer;
      FReplaceEdit: TEdit;
      FReplaceButton: TButton;
      FReplaceAllButton: TButton;
      FPalette: TPanel;
      FPaletteEdit: TEdit;
      FPaletteList: TListBox;
      FZenActive: Boolean;
      FPreZenViewMode: TPadViewMode;
      FZenLeftPad: TPanel;
      FZenRightPad: TPanel;
      FZenTocWasVisible: Boolean;
      FZenFindWasVisible: Boolean;
    // Read-through accessors to the controller-owned model state.
    function GetWorkspace: IPadWorkspace;
    function GetSession: TPadSession;
    function GetMapDirty: Boolean;
    procedure SetMapDirty(const Value: Boolean);
    function GetSwapping: Boolean;
    procedure SetSwapping(const Value: Boolean);
    function GetPaletteMatches: TArray<TPadCommandMatch>;
    property FWorkspace: IPadWorkspace read GetWorkspace;
    property FSession: TPadSession read GetSession;
    property FMapDirty: Boolean read GetMapDirty write SetMapDirty;
    property FSwapping: Boolean read GetSwapping write SetSwapping;
    property FPaletteMatches: TArray<TPadCommandMatch> read GetPaletteMatches;
    procedure SetDocumentTitle(const Name: string);
    procedure SetStatus(const PositionText, WordsText: string);
    procedure SetTocCaptions(const Captions: TArray<string>);
    procedure SetActiveTocIndex(const Index: Integer);
    function EditorFindNeedle: string;
    function EditorReplaceValue: string;
    function PreviewFindNeedle: string;
    procedure SetFindCount(const Value: string);
    function SampleMarkdown: string;
    function DarkThemeActive: Boolean;
    function EffectiveViewMode: TPadViewMode;
    procedure ApplyRestoredViewMode(const Mode: TPadViewMode);
    function PromptOpenFile(out FileName: string): Boolean;
    function PromptSaveFile(const SuggestedName: string; out FileName: string): Boolean;
    function PromptExportHtml(const SuggestedName: string; out FileName: string): Boolean;
    function ConfirmClose: TPadCloseChoice;
    function ConfirmCloseDocument(const DocName: string): TPadCloseChoice;
    function ConfirmSaveOverChangedFile(const DocName: string): TPadConflictChoice;
    procedure ShowOpenError(const FileName, ErrorMessage: string);
    procedure ShowSaveError(const FileName, ErrorMessage: string);
    procedure CloseApplication;
    procedure ConfigureControls;
    procedure BuildToolbar;
    function ResolveIconFontName: string;
    function AddIconButton(const Glyph: string; const Hint: string; const Handler: TNotifyEvent): TSpeedButton;
    procedure AddSeparator;
    procedure WMDropFiles(var Message: TMessage); message WM_DROPFILES;
    function TryHandlePaletteKey(const Key: Word; const Shift: TShiftState): Boolean;
    function TryHandleFindBarReturn(const Key: Word): Boolean;
    function TryHandleGlobalKey(const Key: Word): Boolean;
    function TryHandleFormatShortcut(const Key: Word): Boolean;
    function TryHandleCommandShortcut(const Key: Word): Boolean;
    procedure HandleNewClick(Sender: TObject);
    procedure HandleOpenClick(Sender: TObject);
    procedure HandleSaveClick(Sender: TObject);
    procedure HandleSaveAsClick(Sender: TObject);
    procedure HandleRecentClick(Sender: TObject);
    procedure HandleRecentItemClick(Sender: TObject);
    procedure HandleBoldClick(Sender: TObject);
    procedure HandleItalicClick(Sender: TObject);
    procedure HandleLinkClick(Sender: TObject);
    procedure HandleCodeClick(Sender: TObject);
    procedure HandleExportClick(Sender: TObject);
    procedure HandleCopyHtmlClick(Sender: TObject);
    procedure ExecuteFormatCommand(const Command: TEditorCommand);
    procedure DoExportHtml;
    procedure DoCopyHtml;
    procedure CopyHtmlToClipboard(const Fragment: string);
    procedure HandleThemeClick(Sender: TObject);
    procedure HandleTocClick(Sender: TObject);
    procedure HandleZenClick(Sender: TObject);
    procedure HandleCommandsClick(Sender: TObject);
    procedure HandleFindClick(Sender: TObject);
    procedure HandleFindEditKeyPress(Sender: TObject; var Key: Char);
    procedure BuildTitleBar;
    procedure LayoutTitleBar;
    procedure ApplyCaptionColor;
    procedure ApplyTitleBarColors(const ToolbarColor, IconColor, SeparatorColor: TColor);
    procedure HandleTitleBarPaint(Sender: TObject; Canvas: TCanvas; var ARect: TRect);
    procedure HandleTitleBarWndProc(var Message: TMessage);
    procedure HandleTabSelect(Sender: TObject; const Index: Integer);
    procedure HandleTabClose(Sender: TObject; const Index: Integer);
    procedure HandleTabAdd(Sender: TObject);
    procedure HandleTabReorder(Sender: TObject; const FromIndex, ToIndex: Integer);
    function ActiveDocumentFolder: string;
    procedure OpenPath(const FileName: string);
    procedure HandleDocumentHandedOver(const FileName: string);
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
    procedure SwitchToDocument(const Index: Integer);
    procedure CloseActiveDocument;
    procedure CloseDocumentAt(const Index: Integer);
    procedure RestoreSession;
    procedure SaveSession;
    procedure RebuildTabs;
    procedure ApplyTheme;
    function CurrentChrome: TPadChrome;
    procedure ApplyViewerTheme;
    procedure ApplyWindowColor(const Chrome: TPadChrome);
    procedure ApplyToolbarChrome(const Chrome: TPadChrome);
    procedure ApplyTabStripChrome(const Chrome: TPadChrome);
    procedure ApplySidePanelChrome(const Chrome: TPadChrome);
    procedure ToggleDarkTheme;
    procedure ToggleTocPane;
    procedure RebuildSyncAndToc;
    procedure UpdateActiveTocEntry(const SourceLine: Integer);
    procedure ExecuteFind;
    procedure BuildPalette;
    procedure BuildCommandRegistry;
    function BuildCommandActions: TPadCommandActions;
    procedure SetViewMode(const Mode: TPadViewMode);
    procedure ApplyViewMode;
    procedure EnforceTopBarOrder;
    procedure EnforceLeftPaneOrder;
    procedure ShowFindBar;
    procedure ShowReplaceBar;
    procedure CloseFindBar;
    procedure FindInEditor;
    procedure UpdateFindCount;
    procedure HandleReplaceClick(Sender: TObject);
    procedure HandleReplaceAllClick(Sender: TObject);
    procedure BuildReplaceControls;
    procedure ShowPalette;
    procedure ClosePalette;
    procedure RefreshPaletteList;
    procedure HandlePaletteChange(Sender: TObject);
    procedure HandlePaletteDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure HandlePaletteDblClick(Sender: TObject);
    procedure PaletteMoveSelection(const Delta: Integer);
    procedure ExecuteSelectedCommand;
    procedure ToggleZen;
    procedure EnterZen;
    procedure ExitZen;
    procedure UpdateZenPadding;
    class function BuildSampleMarkdown: string;

  protected
    procedure CreateWnd; override;

  public
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
  end;

var
  Markdown4DStudioVCLForm: TMarkdown4DStudioVCLForm;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Character,
  System.IOUtils,
  System.UITypes,
  Winapi.ShellAPI,
  Winapi.DwmApi,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Extensions.Chart.BlockOverride,
  Markdown4D.Extensions.Mermaid.BlockOverride,
  Markdown4DStudio.Defines,
  Markdown4DStudio.SessionSync,
  Markdown4DStudio.Text,
  Markdown4DStudio.Outline,
  Markdown4DStudio.Workspace,
  Markdown4DStudio.LinkPolicy,
  Markdown4DStudio.SingleInstance,
  Markdown4DStudio.HtmlExport;

{$R *.dfm}

constructor TMarkdown4DStudioVCLForm.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  TChartBlockOverride.RegisterOverride;
  TMermaidBlockOverride.RegisterOverride;

  FLightTheme := TMarkdownTheme.CreateLight;
  FDarkTheme := TMarkdownTheme.CreateDark;

  FController := TPadController.Create(Self, Self, SessionFileName);

  ConfigureControls;
  BuildToolbar;
  BuildTitleBar;
  BuildPalette;
  BuildCommandRegistry;

  FSplitEditorWidth := (InitialClientWidth - TocPanelWidth) div 2;
  FViewMode := TPadViewMode.Split;

  FDarkThemeActive := FSession.DarkTheme;
  ApplyTheme;

  RestoreSession;

  tmrTick.Enabled := True;

  TPadSingleInstance.OpenChannel(StudioInstanceChannelVcl, HandleDocumentHandedOver);

  if FUseCustomTitleBar then
  begin
    TThread.ForceQueue(nil,
      procedure
      begin
        LayoutTitleBar;
      end);
  end;
end;

destructor TMarkdown4DStudioVCLForm.Destroy;
begin
  TPadSingleInstance.CloseChannel;

  // The controller is missing when construction failed halfway; there is no
  // session to save then.
  if FController <> nil then
    SaveSession;

  if mdEditor <> nil then
    mdEditor.DetachPreview;

  inherited Destroy;

  FController.Free;
  FDarkTheme.Free;
  FLightTheme.Free;
end;

procedure TMarkdown4DStudioVCLForm.ConfigureControls;
begin
  BuildReplaceControls;
  lblFindCount.Caption := EmptyFindCaption;
end;

procedure TMarkdown4DStudioVCLForm.BuildToolbar;
begin
  FIconFontName := ResolveIconFontName;

  FNewButton := AddIconButton(GlyphNew, HintNew, HandleNewClick);
  FOpenButton := AddIconButton(GlyphOpen, HintOpen, HandleOpenClick);
  FSaveButton := AddIconButton(GlyphSave, HintSave, HandleSaveClick);
  FSaveAsButton := AddIconButton(GlyphSaveAs, HintSaveAs, HandleSaveAsClick);
  FRecentButton := AddIconButton(GlyphRecent, HintRecent, HandleRecentClick);

  AddSeparator;

  FExportButton := AddIconButton(GlyphExport, HintExport, HandleExportClick);
  FCopyHtmlButton := AddIconButton(GlyphCopyHtml, HintCopyHtml, HandleCopyHtmlClick);

  AddSeparator;

  FBoldButton := AddIconButton(GlyphBold, HintBold, HandleBoldClick);
  FItalicButton := AddIconButton(GlyphItalic, HintItalic, HandleItalicClick);
  FLinkButton := AddIconButton(GlyphLink, HintLink, HandleLinkClick);
  FCodeButton := AddIconButton(GlyphCode, HintCode, HandleCodeClick);

  AddSeparator;

  FThemeButton := AddIconButton(GlyphTheme, HintTheme, HandleThemeClick);
  FTocButton := AddIconButton(GlyphToc, HintToc, HandleTocClick);
  FZenButton := AddIconButton(GlyphZen, HintZen, HandleZenClick);
  FCommandsButton := AddIconButton(GlyphCommands, HintCommands, HandleCommandsClick);

  FFindEdit := TEdit.Create(Self);
  FFindEdit.Parent := pnlToolbar;
  FFindEdit.Align := alRight;
  FFindEdit.AlignWithMargins := True;
  FFindEdit.Margins.SetBounds(ButtonSpacing, ButtonSpacing, ButtonSpacing, ButtonSpacing);
  FFindEdit.Width := FindEditWidth;
  FFindEdit.TextHint := FindButtonCaption;
  FFindEdit.OnKeyPress := HandleFindEditKeyPress;

  FFindButton := AddIconButton(GlyphFind, HintFind, HandleFindClick);
  FFindButton.Align := alRight;
end;

function TMarkdown4DStudioVCLForm.ResolveIconFontName: string;
begin
  if Screen.Fonts.IndexOf(FluentIconFontName) >= 0 then
    Result := FluentIconFontName
  else
    Result := Mdl2IconFontName;
end;

function TMarkdown4DStudioVCLForm.AddIconButton(const Glyph: string; const Hint: string;
  const Handler: TNotifyEvent): TSpeedButton;
begin
  const VerticalMargin = (ToolbarHeight - IconButtonSize) div 2;

  Result := TSpeedButton.Create(Self);
  Result.Parent := pnlToolbar;
  Result.Align := alLeft;
  Result.AlignWithMargins := True;
  Result.Margins.SetBounds(2, VerticalMargin, 0, VerticalMargin);
  Result.Width := IconButtonSize;
  Result.Flat := True;
  Result.Font.Name := FIconFontName;
  Result.Font.Size := IconGlyphSize;
  Result.Caption := Glyph;
  Result.Hint := Hint;
  Result.ShowHint := True;
  Result.OnClick := Handler;

  FIconButtons := FIconButtons + [Result];
end;

procedure TMarkdown4DStudioVCLForm.AddSeparator;
begin
  const VerticalMargin = ButtonSpacing + 2;

  const Separator = TPanel.Create(Self);
  Separator.Parent := pnlToolbar;
  Separator.Align := alLeft;
  Separator.AlignWithMargins := True;
  Separator.Margins.SetBounds(ButtonSpacing, VerticalMargin, ButtonSpacing, VerticalMargin);
  Separator.Width := SeparatorWidth;
  Separator.BevelOuter := bvNone;
  Separator.ShowCaption := False;
  Separator.ParentBackground := False;

  FSeparators := FSeparators + [Separator];
end;

procedure TMarkdown4DStudioVCLForm.CreateWnd;
begin
  inherited CreateWnd;

  DragAcceptFiles(Handle, True);
end;

procedure TMarkdown4DStudioVCLForm.WMDropFiles(var Message: TMessage);
begin
  const Drop = HDROP(Message.WParam);

  const Count = DragQueryFile(Drop, $FFFFFFFF, nil, 0);
  for var Index := 0 to Integer(Count) - 1 do
  begin
    const PathLength = DragQueryFile(Drop, Index, nil, 0);

    var FileName: string;
    SetLength(FileName, PathLength);
    DragQueryFile(Drop, Index, PChar(FileName), PathLength + 1);

    if SameText(TPath.GetExtension(FileName), '.' + DefaultExtension) then
      OpenPath(FileName);
  end;

  DragFinish(Drop);
end;

procedure TMarkdown4DStudioVCLForm.HandleFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if FPalette.Visible then
  begin
    if TryHandlePaletteKey(Key, Shift) then
      Key := 0;

    Exit;
  end;

  var Handled := TryHandleFindBarReturn(Key) or TryHandleGlobalKey(Key);

  const WantsShortcut = (ssCtrl in Shift) and not Handled;
  if WantsShortcut then
  begin
    if ssShift in Shift then
      Handled := TryHandleFormatShortcut(Key)
    else
      Handled := TryHandleCommandShortcut(Key);
  end;

  if Handled then
    Key := 0;
end;

// While the palette is open it owns the keyboard: the arrows, Return and
// Escape drive it, and control chords are swallowed so they cannot reach the
// editor underneath.
function TMarkdown4DStudioVCLForm.TryHandlePaletteKey(const Key: Word; const Shift: TShiftState): Boolean;
begin
  case Key of
    VK_UP:
      PaletteMoveSelection(-1);
    VK_DOWN:
      PaletteMoveSelection(1);
    VK_RETURN:
      ExecuteSelectedCommand;
    VK_ESCAPE:
      ClosePalette;
  else
    Exit(ssCtrl in Shift);
  end;

  Result := True;
end;

function TMarkdown4DStudioVCLForm.TryHandleFindBarReturn(const Key: Word): Boolean;
begin
  const IsFindReturn = pnlFind.Visible and (Key = VK_RETURN) and edtEditorFind.Focused;
  if not IsFindReturn then
    Exit(False);

  FindInEditor;
  Result := True;
end;

function TMarkdown4DStudioVCLForm.TryHandleGlobalKey(const Key: Word): Boolean;
begin
  case Key of
    VK_F11:
      ToggleZen;
    VK_F3:
      begin
        if not pnlFind.Visible then
          Exit(False);

        FindInEditor;
      end;
    VK_ESCAPE:
      begin
        if pnlFind.Visible then
          CloseFindBar
        else if FZenActive then
          ExitZen
        else
          Exit(False);
      end;
  else
    Exit(False);
  end;

  Result := True;
end;

function TMarkdown4DStudioVCLForm.TryHandleFormatShortcut(const Key: Word): Boolean;
begin
  case Key of
    Ord('1'):
      ExecuteFormatCommand(TEditorCommand.Heading1);
    Ord('2'):
      ExecuteFormatCommand(TEditorCommand.Heading2);
    Ord('3'):
      ExecuteFormatCommand(TEditorCommand.Heading3);
    Ord('U'):
      ExecuteFormatCommand(TEditorCommand.BulletList);
    Ord('O'):
      ExecuteFormatCommand(TEditorCommand.NumberedList);
    Ord('Q'):
      ExecuteFormatCommand(TEditorCommand.Quote);
    Ord('X'):
      ExecuteFormatCommand(TEditorCommand.Strikethrough);
    Ord('T'):
      ExecuteFormatCommand(TEditorCommand.Table);
    Ord('E'):
      DoExportHtml;
    Ord('C'):
      DoCopyHtml;
    Ord('S'):
      FController.SaveAs;
    VK_TAB:
      begin
        FWorkspace.ActivatePrevious;
        SwitchToDocument(FWorkspace.ActiveIndex);
      end;
  else
    Exit(False);
  end;

  Result := True;
end;

function TMarkdown4DStudioVCLForm.TryHandleCommandShortcut(const Key: Word): Boolean;
begin
  case Key of
    Ord('1'):
      SetViewMode(TPadViewMode.EditorOnly);
    Ord('2'):
      SetViewMode(TPadViewMode.Split);
    Ord('3'):
      SetViewMode(TPadViewMode.PreviewOnly);
    Ord('F'):
      ShowFindBar;
    Ord('H'):
      ShowReplaceBar;
    Ord('K'):
      ShowPalette;
    Ord('N'):
      FController.NewDocument;
    Ord('O'):
      FController.OpenViaDialog;
    Ord('S'):
      FController.Save;
    Ord('W'):
      CloseActiveDocument;
    VK_TAB:
      begin
        FWorkspace.ActivateNext;
        SwitchToDocument(FWorkspace.ActiveIndex);
      end;
  else
    Exit(False);
  end;

  Result := True;
end;

procedure TMarkdown4DStudioVCLForm.HandleCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FZenActive then
    ExitZen;

  CanClose := FController.QueryClose;
end;

procedure TMarkdown4DStudioVCLForm.HandleNewClick(Sender: TObject);
begin
  FController.NewDocument;
end;

procedure TMarkdown4DStudioVCLForm.HandleOpenClick(Sender: TObject);
begin
  FController.OpenViaDialog;
end;

procedure TMarkdown4DStudioVCLForm.HandleSaveClick(Sender: TObject);
begin
  FController.Save;
end;

procedure TMarkdown4DStudioVCLForm.HandleSaveAsClick(Sender: TObject);
begin
  FController.SaveAs;
end;

procedure TMarkdown4DStudioVCLForm.HandleRecentClick(Sender: TObject);
begin
  popRecent.Items.Clear;

  if System.Length(FSession.RecentFiles) = 0 then
  begin
    var Empty := TMenuItem.Create(popRecent);
    Empty.Caption := RecentNoneCaption;
    Empty.Enabled := False;
    popRecent.Items.Add(Empty);
  end
  else
  begin
    for var Path in FSession.RecentFiles do
    begin
      var Item := TMenuItem.Create(popRecent);
      Item.Caption := Path;
      Item.OnClick := HandleRecentItemClick;
      popRecent.Items.Add(Item);
    end;
  end;

  const Origin = FRecentButton.ClientToScreen(Point(0, FRecentButton.Height));
  popRecent.Popup(Origin.X, Origin.Y);
end;

procedure TMarkdown4DStudioVCLForm.HandleRecentItemClick(Sender: TObject);
begin
  const Item = Sender as TMenuItem;
  OpenPath(Item.Caption);
end;

procedure TMarkdown4DStudioVCLForm.HandleBoldClick(Sender: TObject);
begin
  mdEditor.ExecuteCommand(TEditorCommand.Bold);
  mdEditor.SetFocus;
end;

procedure TMarkdown4DStudioVCLForm.HandleItalicClick(Sender: TObject);
begin
  mdEditor.ExecuteCommand(TEditorCommand.Italic);
  mdEditor.SetFocus;
end;

procedure TMarkdown4DStudioVCLForm.HandleLinkClick(Sender: TObject);
begin
  mdEditor.ExecuteCommand(TEditorCommand.Link);
  mdEditor.SetFocus;
end;

procedure TMarkdown4DStudioVCLForm.HandleCodeClick(Sender: TObject);
begin
  mdEditor.ExecuteCommand(TEditorCommand.CodeBlock);
  mdEditor.SetFocus;
end;

procedure TMarkdown4DStudioVCLForm.HandleExportClick(Sender: TObject);
begin
  DoExportHtml;
end;

procedure TMarkdown4DStudioVCLForm.HandleCopyHtmlClick(Sender: TObject);
begin
  DoCopyHtml;
end;

procedure TMarkdown4DStudioVCLForm.ExecuteFormatCommand(const Command: TEditorCommand);
begin
  mdEditor.ExecuteCommand(Command);
  mdEditor.SetFocus;
end;

procedure TMarkdown4DStudioVCLForm.DoExportHtml;
begin
  FController.ExportHtml;
end;

function TMarkdown4DStudioVCLForm.PromptExportHtml(const SuggestedName: string; out FileName: string): Boolean;
begin
  if SuggestedName <> '' then
    dlgSaveHtml.FileName := SuggestedName;

  Result := dlgSaveHtml.Execute;
  if Result then
    FileName := dlgSaveHtml.FileName;
end;

procedure TMarkdown4DStudioVCLForm.DoCopyHtml;
begin
  FController.CopyHtml;
end;

procedure TMarkdown4DStudioVCLForm.CopyHtmlToClipboard(const Fragment: string);
const
  CfHtmlName = 'HTML Format';
begin
  const Payload = TMarkdownHtmlExport.BuildClipboardHtml(Fragment);
  const Bytes = TEncoding.UTF8.GetBytes(Payload);
  const CfHtml = RegisterClipboardFormat(CfHtmlName);

  if not OpenClipboard(Handle) then
    Exit;

  try
    EmptyClipboard;

    const HtmlMem = GlobalAlloc(GMEM_MOVEABLE, System.Length(Bytes) + 1);
    if HtmlMem = 0 then
      Exit;

    const HtmlPtr = GlobalLock(HtmlMem);
    if HtmlPtr = nil then
    begin
      GlobalFree(HtmlMem);
      Exit;
    end;

    Move(Bytes[0], HtmlPtr^, System.Length(Bytes));
    PByte(NativeUInt(HtmlPtr) + NativeUInt(System.Length(Bytes)))^ := 0;
    GlobalUnlock(HtmlMem);
    SetClipboardData(CfHtml, HtmlMem);

    const TextByteCount = (System.Length(Fragment) + 1) * SizeOf(Char);
    const TextMem = GlobalAlloc(GMEM_MOVEABLE, TextByteCount);
    if TextMem = 0 then
      Exit;

    const TextPtr = GlobalLock(TextMem);
    if TextPtr = nil then
    begin
      GlobalFree(TextMem);
      Exit;
    end;

    Move(PChar(Fragment)^, TextPtr^, TextByteCount);
    GlobalUnlock(TextMem);
    SetClipboardData(CF_UNICODETEXT, TextMem);
  finally
    CloseClipboard;
  end;
end;

procedure TMarkdown4DStudioVCLForm.HandleThemeClick(Sender: TObject);
begin
  ToggleDarkTheme;
end;

procedure TMarkdown4DStudioVCLForm.ToggleDarkTheme;
begin
  FDarkThemeActive := not FDarkThemeActive;
  ApplyTheme;
end;

procedure TMarkdown4DStudioVCLForm.HandleZenClick(Sender: TObject);
begin
  ToggleZen;
end;

procedure TMarkdown4DStudioVCLForm.HandleCommandsClick(Sender: TObject);
begin
  ShowPalette;
end;

procedure TMarkdown4DStudioVCLForm.HandleTocClick(Sender: TObject);
begin
  ToggleTocPane;
end;

procedure TMarkdown4DStudioVCLForm.ToggleTocPane;
begin
  const ShowToc = not pnlToc.Visible;
  pnlToc.Visible := ShowToc;
  splToc.Visible := ShowToc;

  EnforceLeftPaneOrder;
end;

procedure TMarkdown4DStudioVCLForm.HandleFindClick(Sender: TObject);
begin
  ExecuteFind;
end;

procedure TMarkdown4DStudioVCLForm.HandleFindEditKeyPress(Sender: TObject; var Key: Char);
begin
  if Key <> #13 then
    Exit;

  Key := #0;
  ExecuteFind;
end;

procedure TMarkdown4DStudioVCLForm.BuildTitleBar;
begin
  FUseCustomTitleBar := TTitleBar.Supported;

  FTabStrip := TPadTabStrip.Create(Self);
  FTabStrip.GlyphFontName := FIconFontName;
  FTabStrip.OnSelectTab := HandleTabSelect;
  FTabStrip.OnCloseTab := HandleTabClose;
  FTabStrip.OnAddTab := HandleTabAdd;
  FTabStrip.OnReorderTab := HandleTabReorder;

  if FUseCustomTitleBar then
  begin
    FTitleBar := TTitleBarPanel.Create(Self);
    FTitleBar.Parent := Self;
    FTitleBar.OnPaint := HandleTitleBarPaint;
    FTitleBarWndProc := FTitleBar.WindowProc;
    FTitleBar.WindowProc := HandleTitleBarWndProc;

    CustomTitleBar.Enabled := True;
    CustomTitleBar.SystemHeight := False;
    CustomTitleBar.Height := TitleBarHeight;
    CustomTitleBar.ShowCaption := False;
    CustomTitleBar.ShowIcon := False;
    CustomTitleBar.SystemColors := False;
    CustomTitleBar.SystemButtons := False;
    CustomTitleBar.Control := FTitleBar;

    FTabStrip.Parent := FTitleBar;
    FTabStrip.Align := alNone;
    FTabStrip.SetBounds(TitleBarLeftInset, 0, TitleBarHeight * 4, TitleBarHeight);

    LayoutTitleBar;
  end
  else
  begin
    FTabStrip.Parent := Self;
    FTabStrip.Align := alTop;
    FTabStrip.Height := TabsHeight;
    FTabStrip.Top := 0;
  end;
end;

procedure TMarkdown4DStudioVCLForm.LayoutTitleBar;
begin
  if not FUseCustomTitleBar or (FTitleBar = nil) or (FTabStrip = nil) then
    Exit;

  var Available := ClientWidth - TitleBarLeftInset - CaptionButtonsReserve;
  if Available < TPadTabStrip.MinTabWidth then
    Available := TPadTabStrip.MinTabWidth;

  var BarHeight := FTitleBar.ClientHeight;
  if BarHeight <= 0 then
    BarHeight := TitleBarHeight;

  FTabStrip.SetBounds(TitleBarLeftInset, 0, Available, BarHeight);
  FTabStrip.AvailableWidth := Available;

  ApplyCaptionColor;
end;

procedure TMarkdown4DStudioVCLForm.HandleTitleBarPaint(Sender: TObject; Canvas: TCanvas; var ARect: TRect);
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := FTitleBarColor;
  Canvas.FillRect(ARect);
end;

type
  // Exposes the protected TrapHitTest property that drives the caption button
  // hover repaint inside Vcl.TitleBarCtrls.
  TTitlebarButtonAccess = class(TSystemTitlebarButton);

procedure TMarkdown4DStudioVCLForm.HandleTitleBarWndProc(var Message: TMessage);
begin
  FTitleBarWndProc(Message);

  // The VCL repaints only the maximize/restore caption button on non-client
  // hover (its Windows 11 Snap Layouts support); minimize and close never see
  // a client mouse-enter because the title bar hit-tests as HTCAPTION, so we
  // mirror the VCL TrapHitTest mechanism for those two buttons here.
  if Message.Msg <> WM_NCHITTEST then
    Exit;

  const HitPoint = FTitleBar.ScreenToClient(
    Point(TWMNCHitTest(Message).XPos, TWMNCHitTest(Message).YPos));

  for var Index := 0 to FTitleBar.ControlCount - 1 do
  begin
    if not (FTitleBar.Controls[Index] is TSystemTitlebarButton) then
      Continue;

    const Button = TTitlebarButtonAccess(FTitleBar.Controls[Index]);
    if not (Button.ButtonType in [TSystemButton.sbMinimize, TSystemButton.sbClose]) then
      Continue;

    const InsideButton = Button.Visible and Button.BoundsRect.Contains(HitPoint);
    if Button.TrapHitTest <> InsideButton then
    begin
      Button.TrapHitTest := InsideButton;
      Button.Invalidate;
    end;
  end;
end;

procedure TMarkdown4DStudioVCLForm.ApplyCaptionColor;
begin
  if not FUseCustomTitleBar or not HandleAllocated then
    Exit;

  var CaptionColor: DWORD := ColorToRGB(FTitleBarColor);
  DwmSetWindowAttribute(Handle, DwmCaptionColorAttribute, @CaptionColor, SizeOf(CaptionColor));
end;

procedure TMarkdown4DStudioVCLForm.ApplyTitleBarColors(const ToolbarColor, IconColor, SeparatorColor: TColor);
begin
  if not FUseCustomTitleBar then
    Exit;

  FTitleBarColor := ToolbarColor;
  CustomTitleBar.BackgroundColor := ToolbarColor;
  CustomTitleBar.InactiveBackgroundColor := ToolbarColor;
  CustomTitleBar.ForegroundColor := IconColor;
  CustomTitleBar.ButtonForegroundColor := IconColor;
  CustomTitleBar.ButtonBackgroundColor := ToolbarColor;
  CustomTitleBar.ButtonHoverForegroundColor := IconColor;
  CustomTitleBar.ButtonHoverBackgroundColor := SeparatorColor;
  CustomTitleBar.ButtonPressedForegroundColor := IconColor;
  CustomTitleBar.ButtonPressedBackgroundColor := SeparatorColor;
  CustomTitleBar.ButtonInactiveForegroundColor := IconColor;
  CustomTitleBar.ButtonInactiveBackgroundColor := ToolbarColor;

  if FTitleBar <> nil then
    FTitleBar.Invalidate;

  ApplyCaptionColor;
end;

procedure TMarkdown4DStudioVCLForm.HandleTabSelect(Sender: TObject; const Index: Integer);
begin
  SwitchToDocument(Index);
end;

procedure TMarkdown4DStudioVCLForm.HandleTabClose(Sender: TObject; const Index: Integer);
begin
  CloseDocumentAt(Index);
end;

procedure TMarkdown4DStudioVCLForm.HandleTabAdd(Sender: TObject);
begin
  FController.NewDocument;
end;

procedure TMarkdown4DStudioVCLForm.HandleTabReorder(Sender: TObject; const FromIndex, ToIndex: Integer);
begin
  FWorkspace.Move(FromIndex, ToIndex);
  RebuildTabs;
end;

procedure TMarkdown4DStudioVCLForm.HandleEditorChange(Sender: TObject);
begin
  FController.NotifyEditorChanged;
end;

procedure TMarkdown4DStudioVCLForm.HandleSyncScroll(Sender: TObject; const SourceLine: Integer);
begin
  // The DFM links the panes, so the first sync fires while the form is still
  // streaming in and the controller does not exist yet.
  if FController = nil then
    Exit;

  // The editor keeps the two panes in step itself; we only reflect the position
  // in the contents outline.
  UpdateActiveTocEntry(SourceLine);
end;

procedure TMarkdown4DStudioVCLForm.HandlePreviewLinkClick(const Sender: TObject; const Url: string);
begin
  var FileName: string;
  if TPadLinkPolicy.TryResolveDocument(Url, ActiveDocumentFolder, FileName) then
  begin
    OpenPath(FileName);
    Exit;
  end;

  if not TPadLinkPolicy.MayOpen(Url) then
  begin
    MessageDlg(TPadLinkPolicy.RefusalMessage(Url), mtWarning, [mbOK], 0);
    Exit;
  end;

  ShellExecute(0, nil, PChar(Url), nil, nil, SW_SHOWNORMAL);
end;

// Empty while the active document has never been saved, which is exactly when a
// relative link has nothing to resolve against.
function TMarkdown4DStudioVCLForm.ActiveDocumentFolder: string;
begin
  const Document = FController.ActiveDocument;
  if (Document = nil) or Document.IsUntitled then
    Exit('');

  Result := TPath.GetDirectoryName(Document.FileName);
end;

procedure TMarkdown4DStudioVCLForm.HandleTocListClick(Sender: TObject);
begin
  const Index = lstToc.ItemIndex;
  if (Index < 0) or (Index >= FController.TocEntryCount) then
    Exit;

  if FMapDirty then
    RebuildSyncAndToc;

  if (Index < 0) or (Index >= FController.TocEntryCount) then
    Exit;

  const SourceLine = FController.TocSourceLine(Index);

  // Scrolling the editor drives the preview through the linked SyncScroll.
  mdEditor.CaretPosition := mdEditor.SourceLineStartOffset(SourceLine);
  mdEditor.ScrollToSourceLine(SourceLine);

  lstToc.ItemIndex := Index;
  mdEditor.SetFocus;
end;

procedure TMarkdown4DStudioVCLForm.HandleTick(Sender: TObject);
begin
  FController.Tick;
end;

procedure TMarkdown4DStudioVCLForm.OpenPath(const FileName: string);
begin
  FController.OpenPath(FileName);
end;

// A second studio instance handed its document over and exited; open it here and
// step into the foreground so the user sees where the file went.
procedure TMarkdown4DStudioVCLForm.HandleDocumentHandedOver(const FileName: string);
begin
  if FileName <> '' then
    OpenPath(FileName);

  if IsIconic(Handle) then
    ShowWindow(Handle, SW_RESTORE);
  SetForegroundWindow(Handle);
end;

function TMarkdown4DStudioVCLForm.GetEditorText: string;
begin
  Result := mdEditor.Text;
end;

procedure TMarkdown4DStudioVCLForm.SetEditorText(const Value: string);
begin
  mdEditor.Text := Value;
end;

function TMarkdown4DStudioVCLForm.MergeEditorText(const Value: string): Boolean;
begin
  Result := mdEditor.MergeText(Value);
end;

function TMarkdown4DStudioVCLForm.GetEditorCaret: Integer;
begin
  Result := mdEditor.CaretPosition;
end;

procedure TMarkdown4DStudioVCLForm.SetEditorCaret(const Value: Integer);
begin
  mdEditor.CaretPosition := Value;
end;

function TMarkdown4DStudioVCLForm.GetPreviewScrollOffset: Single;
begin
  Result := mdPreview.ScrollOffset;
end;

procedure TMarkdown4DStudioVCLForm.SetPreviewScrollOffset(const Value: Single);
begin
  mdPreview.ScrollOffset := Value;
end;

function TMarkdown4DStudioVCLForm.FirstVisibleSourceLine: Integer;
begin
  Result := mdEditor.FirstVisibleSourceLine;
end;

procedure TMarkdown4DStudioVCLForm.ScrollToSourceLine(const LineIndex: Integer);
begin
  mdEditor.ScrollToSourceLine(LineIndex);
end;

function TMarkdown4DStudioVCLForm.SaveEditState: IMarkdownEditorState;
begin
  Result := mdEditor.SaveEditState;
end;

procedure TMarkdown4DStudioVCLForm.LoadEditState(const State: IMarkdownEditorState);
begin
  mdEditor.LoadEditState(State);
end;

procedure TMarkdown4DStudioVCLForm.FlushPreview;
begin
  mdEditor.FlushPreview;
end;

procedure TMarkdown4DStudioVCLForm.BeginSwap;
begin
  FSwapping := True;
end;

procedure TMarkdown4DStudioVCLForm.EndSwap;
begin
  FSwapping := False;
end;

procedure TMarkdown4DStudioVCLForm.SwitchToDocument(const Index: Integer);
begin
  FController.SwitchToDocument(Index);
end;

procedure TMarkdown4DStudioVCLForm.CloseActiveDocument;
begin
  FController.CloseActiveDocument;
end;

procedure TMarkdown4DStudioVCLForm.CloseDocumentAt(const Index: Integer);
begin
  FController.CloseDocumentAt(Index);
end;

procedure TMarkdown4DStudioVCLForm.RestoreSession;
begin
  FController.RestoreSession;
end;

procedure TMarkdown4DStudioVCLForm.SaveSession;
begin
  FController.SaveSession;
end;

function TMarkdown4DStudioVCLForm.GetWorkspace: IPadWorkspace;
begin
  Result := FController.Workspace;
end;

function TMarkdown4DStudioVCLForm.GetSession: TPadSession;
begin
  Result := FController.Session;
end;

function TMarkdown4DStudioVCLForm.GetMapDirty: Boolean;
begin
  Result := FController.MapDirty;
end;

procedure TMarkdown4DStudioVCLForm.SetMapDirty(const Value: Boolean);
begin
  FController.MapDirty := Value;
end;

function TMarkdown4DStudioVCLForm.GetSwapping: Boolean;
begin
  Result := FController.Swapping;
end;

procedure TMarkdown4DStudioVCLForm.SetSwapping(const Value: Boolean);
begin
  FController.Swapping := Value;
end;

function TMarkdown4DStudioVCLForm.GetPaletteMatches: TArray<TPadCommandMatch>;
begin
  Result := FController.PaletteMatches;
end;

function TMarkdown4DStudioVCLForm.SampleMarkdown: string;
begin
  Result := BuildSampleMarkdown;
end;

function TMarkdown4DStudioVCLForm.DarkThemeActive: Boolean;
begin
  Result := FDarkThemeActive;
end;

function TMarkdown4DStudioVCLForm.EffectiveViewMode: TPadViewMode;
begin
  if FZenActive then
    Result := FPreZenViewMode
  else
    Result := FViewMode;
end;

procedure TMarkdown4DStudioVCLForm.ApplyRestoredViewMode(const Mode: TPadViewMode);
begin
  FViewMode := Mode;
  ApplyViewMode;
end;

function TMarkdown4DStudioVCLForm.PromptOpenFile(out FileName: string): Boolean;
begin
  Result := dlgOpen.Execute;
  if Result then
    FileName := dlgOpen.FileName;
end;

function TMarkdown4DStudioVCLForm.PromptSaveFile(const SuggestedName: string; out FileName: string): Boolean;
begin
  if SuggestedName <> '' then
    dlgSave.FileName := SuggestedName;

  Result := dlgSave.Execute;
  if Result then
    FileName := dlgSave.FileName;
end;

function TMarkdown4DStudioVCLForm.ConfirmClose: TPadCloseChoice;
begin
  const Answer = MessageDlg(CloseUnsavedPrompt, mtConfirmation, [mbYes, mbNo, mbCancel], 0);

  if Answer = mrCancel then
    Result := TPadCloseChoice.Cancel
  else if Answer = mrYes then
    Result := TPadCloseChoice.Save
  else
    Result := TPadCloseChoice.Discard;
end;

procedure TMarkdown4DStudioVCLForm.ShowOpenError(const FileName, ErrorMessage: string);
begin
  MessageDlg(ErrorMessage, mtError, [mbOK], 0);
end;

procedure TMarkdown4DStudioVCLForm.ShowSaveError(const FileName, ErrorMessage: string);
begin
  MessageDlg(Format(SaveErrorFormat, [FileName, ErrorMessage]), mtError, [mbOK], 0);
end;

procedure TMarkdown4DStudioVCLForm.CloseApplication;
begin
  Close;
end;

procedure TMarkdown4DStudioVCLForm.RebuildTabs;
begin
  var Captions: TArray<string>;
  var Modified: TArray<Boolean>;
  TPadSessionSync.CollectTabs(FWorkspace, Captions, Modified);

  FTabStrip.SetTabs(Captions, Modified, FWorkspace.ActiveIndex);
end;

procedure TMarkdown4DStudioVCLForm.ApplyTheme;
begin
  const Chrome = CurrentChrome;

  ApplyViewerTheme;
  ApplyWindowColor(Chrome);
  ApplyToolbarChrome(Chrome);
  ApplyTabStripChrome(Chrome);
  ApplyTitleBarColors(Chrome.ToolbarColor, Chrome.IconColor, Chrome.SeparatorColor);
  ApplySidePanelChrome(Chrome);
end;

function TMarkdown4DStudioVCLForm.CurrentChrome: TPadChrome;
begin
  if FDarkThemeActive then
  begin
    Result.ToolbarColor := ToolbarDarkColor;
    Result.IconColor := IconDarkColor;
    Result.SeparatorColor := SeparatorDarkColor;
    Result.ActiveTabColor := TabActiveDarkColor;
    Result.HoverTabColor := TabHoverDarkColor;
  end
  else
  begin
    Result.ToolbarColor := ToolbarLightColor;
    Result.IconColor := IconLightColor;
    Result.SeparatorColor := SeparatorLightColor;
    Result.ActiveTabColor := clWhite;
    Result.HoverTabColor := TabHoverLightColor;
  end;
end;

procedure TMarkdown4DStudioVCLForm.ApplyViewerTheme;
begin
  if FDarkThemeActive then
  begin
    mdEditor.Theme := FDarkTheme;
    mdPreview.Theme := FDarkTheme;
  end
  else
  begin
    mdEditor.Theme := FLightTheme;
    mdPreview.Theme := FLightTheme;
  end;
end;

// The custom title bar area behind the system caption buttons shows the form
// background, so tint it with the chrome colour; content panes cover the rest.
procedure TMarkdown4DStudioVCLForm.ApplyWindowColor(const Chrome: TPadChrome);
begin
  if FUseCustomTitleBar then
    Color := Chrome.ToolbarColor
  else if FDarkThemeActive then
    Color := clBlack
  else
    Color := clWhite;
end;

procedure TMarkdown4DStudioVCLForm.ApplyToolbarChrome(const Chrome: TPadChrome);
begin
  pnlToolbar.Color := Chrome.ToolbarColor;

  for var Button in FIconButtons do
  begin
    Button.Font.Color := Chrome.IconColor;
  end;

  for var Separator in FSeparators do
  begin
    Separator.Color := Chrome.SeparatorColor;
  end;
end;

procedure TMarkdown4DStudioVCLForm.ApplyTabStripChrome(const Chrome: TPadChrome);
begin
  FTabStrip.ActiveColor := Chrome.ActiveTabColor;
  FTabStrip.InactiveColor := Chrome.ToolbarColor;
  FTabStrip.HoverColor := Chrome.HoverTabColor;
  FTabStrip.TextColor := Chrome.IconColor;
  FTabStrip.AccentColor := TabAccentColor;
  FTabStrip.GlyphColor := Chrome.IconColor;
  FTabStrip.Invalidate;
end;

procedure TMarkdown4DStudioVCLForm.ApplySidePanelChrome(const Chrome: TPadChrome);
begin
  pnlToc.Color := Chrome.ToolbarColor;
  pnlToc.Font.Color := Chrome.IconColor;
  lstToc.Color := Chrome.ToolbarColor;
  lstToc.Font.Color := Chrome.IconColor;
  splToc.Color := Chrome.SeparatorColor;
  splMain.Color := Chrome.SeparatorColor;

  pnlStatus.Color := Chrome.ToolbarColor;
  lblPos.Font.Color := Chrome.IconColor;
  lblWords.Font.Color := Chrome.IconColor;

  pnlFind.Color := Chrome.ToolbarColor;
  lblFindCount.Font.Color := Chrome.IconColor;

  pnlToc.Invalidate;
  lstToc.Invalidate;
  pnlStatus.Invalidate;
end;

procedure TMarkdown4DStudioVCLForm.RebuildSyncAndToc;
begin
  FController.RebuildSyncAndToc;
end;

procedure TMarkdown4DStudioVCLForm.UpdateActiveTocEntry(const SourceLine: Integer);
begin
  FController.UpdateActiveTocEntry(SourceLine);
end;

procedure TMarkdown4DStudioVCLForm.ExecuteFind;
begin
  FController.ExecuteFind;
end;

procedure TMarkdown4DStudioVCLForm.SetDocumentTitle(const Name: string);
begin
  Caption := Format(TitleFormat, [WindowCaption, Name]);
end;

procedure TMarkdown4DStudioVCLForm.SetStatus(const PositionText, WordsText: string);
begin
  lblPos.Caption := PositionText;
  lblWords.Caption := WordsText;
end;

procedure TMarkdown4DStudioVCLForm.SetTocCaptions(const Captions: TArray<string>);
begin
  lstToc.Items.BeginUpdate;
  try
    lstToc.Items.Clear;

    for var Caption in Captions do
      lstToc.Items.Add(Caption);
  finally
    lstToc.Items.EndUpdate;
  end;
end;

procedure TMarkdown4DStudioVCLForm.SetActiveTocIndex(const Index: Integer);
begin
  if Index <> lstToc.ItemIndex then
    lstToc.ItemIndex := Index;
end;

procedure TMarkdown4DStudioVCLForm.BuildReplaceControls;
begin
  FReplaceEdit := TEdit.Create(Self);
  FReplaceEdit.Parent := pnlFind;
  FReplaceEdit.Left := FindBarEditWidth;
  FReplaceEdit.Align := alLeft;
  FReplaceEdit.Width := FindBarEditWidth;
  FReplaceEdit.TextHint := ReplaceHintCaption;

  FReplaceButton := TButton.Create(Self);
  FReplaceButton.Parent := pnlFind;
  FReplaceButton.Left := FindBarEditWidth * 2;
  FReplaceButton.Align := alLeft;
  FReplaceButton.Width := ReplaceButtonWidth;
  FReplaceButton.Caption := ReplaceButtonCaption;
  FReplaceButton.OnClick := HandleReplaceClick;

  FReplaceAllButton := TButton.Create(Self);
  FReplaceAllButton.Parent := pnlFind;
  FReplaceAllButton.Left := FindBarEditWidth * 2 + ReplaceButtonWidth;
  FReplaceAllButton.Align := alLeft;
  FReplaceAllButton.Width := ReplaceAllButtonWidth;
  FReplaceAllButton.Caption := ReplaceAllButtonCaption;
  FReplaceAllButton.OnClick := HandleReplaceAllClick;
end;

procedure TMarkdown4DStudioVCLForm.HandleReplaceClick(Sender: TObject);
begin
  FController.ReplaceInEditor;
end;

procedure TMarkdown4DStudioVCLForm.HandleReplaceAllClick(Sender: TObject);
begin
  FController.ReplaceAllInEditor;
end;

function TMarkdown4DStudioVCLForm.EditorReplaceValue: string;
begin
  Result := FReplaceEdit.Text;
end;

procedure TMarkdown4DStudioVCLForm.EditorHighlightMatches(const Needle: string);
begin
  mdEditor.HighlightMatches(Needle);
end;

function TMarkdown4DStudioVCLForm.EditorReplaceCurrent(const Needle, Replacement: string): Boolean;
begin
  Result := mdEditor.ReplaceCurrent(Needle, Replacement, Default(TMarkdownFindOptions));
end;

function TMarkdown4DStudioVCLForm.EditorReplaceAll(const Needle, Replacement: string): Integer;
begin
  Result := mdEditor.ReplaceAll(Needle, Replacement, Default(TMarkdownFindOptions));
end;

function TMarkdown4DStudioVCLForm.EditorFindNeedle: string;
begin
  Result := edtEditorFind.Text;
end;

function TMarkdown4DStudioVCLForm.PreviewFindNeedle: string;
begin
  Result := FFindEdit.Text;
end;

procedure TMarkdown4DStudioVCLForm.SetFindCount(const Value: string);
begin
  lblFindCount.Caption := Value;
end;

procedure TMarkdown4DStudioVCLForm.EditorFindNext(const Needle: string);
begin
  mdEditor.FindNext(Needle);
end;

function TMarkdown4DStudioVCLForm.EditorFindMatchCount(const Needle: string): Integer;
begin
  Result := mdEditor.FindMatchCount(Needle);
end;

procedure TMarkdown4DStudioVCLForm.PreviewFindText(const Needle: string);
begin
  mdPreview.FindText(Needle);
end;

function TMarkdown4DStudioVCLForm.ConfirmCloseDocument(const DocName: string): TPadCloseChoice;
begin
  const Answer = MessageDlg(Format(CloseDocumentPromptFormat, [DocName]), mtConfirmation,
    [mbYes, mbNo, mbCancel], 0);

  if Answer = mrCancel then
    Result := TPadCloseChoice.Cancel
  else if Answer = mrYes then
    Result := TPadCloseChoice.Save
  else
    Result := TPadCloseChoice.Discard;
end;

function TMarkdown4DStudioVCLForm.ConfirmSaveOverChangedFile(const DocName: string): TPadConflictChoice;
begin
  const Answer = MessageDlg(Format(ConflictPromptFormat, [DocName]), mtWarning,
    [mbYes, mbNo, mbCancel], 0);

  if Answer = mrYes then
    Result := TPadConflictChoice.Overwrite
  else if Answer = mrNo then
    Result := TPadConflictChoice.Reload
  else
    Result := TPadConflictChoice.Cancel;
end;

procedure TMarkdown4DStudioVCLForm.BuildPalette;
begin
  FPalette := TPanel.Create(Self);
  FPalette.Parent := Self;
  FPalette.BevelOuter := bvNone;
  FPalette.BevelKind := bkFlat;
  FPalette.ShowCaption := False;
  FPalette.Width := PaletteWidth;
  FPalette.Visible := False;

  FPaletteEdit := TEdit.Create(Self);
  FPaletteEdit.Parent := FPalette;
  FPaletteEdit.Align := alTop;
  FPaletteEdit.TextHint := PaletteHintCaption;
  FPaletteEdit.OnChange := HandlePaletteChange;

  FPaletteList := TListBox.Create(Self);
  FPaletteList.Parent := FPalette;
  FPaletteList.Align := alClient;
  FPaletteList.BorderStyle := bsNone;
  FPaletteList.Style := lbOwnerDrawFixed;
  FPaletteList.ItemHeight := PaletteRowHeight;
  FPaletteList.OnDrawItem := HandlePaletteDrawItem;
  FPaletteList.OnDblClick := HandlePaletteDblClick;

  FPalette.Height := FPaletteEdit.Height + PaletteRowHeight * PaletteVisibleRows;
  FPalette.Left := (ClientWidth - PaletteWidth) div 2;
  FPalette.Top := PaletteTop;
end;

procedure TMarkdown4DStudioVCLForm.BuildCommandRegistry;
begin
  FController.InitCommandRegistry(BuildCommandActions);
end;

function TMarkdown4DStudioVCLForm.BuildCommandActions: TPadCommandActions;
begin
  Result.NewDocument := procedure begin FController.NewDocument; end;
  Result.OpenDocument := procedure begin FController.OpenViaDialog; end;
  Result.Save := procedure begin FController.Save; end;
  Result.SaveAs := procedure begin FController.SaveAs; end;
  Result.CloseDocument := procedure begin CloseActiveDocument; end;
  Result.NextTab :=
    procedure
    begin
      FWorkspace.ActivateNext;
      SwitchToDocument(FWorkspace.ActiveIndex);
    end;
  Result.ExportHtml := procedure begin DoExportHtml; end;
  Result.CopyHtml := procedure begin DoCopyHtml; end;
  Result.ViewEditorOnly := procedure begin SetViewMode(TPadViewMode.EditorOnly); end;
  Result.ViewSplit := procedure begin SetViewMode(TPadViewMode.Split); end;
  Result.ViewPreviewOnly := procedure begin SetViewMode(TPadViewMode.PreviewOnly); end;
  Result.ToggleZen := procedure begin ToggleZen; end;
  Result.ToggleTheme := procedure begin ToggleDarkTheme; end;
  Result.ToggleToc := procedure begin ToggleTocPane; end;
  Result.ShowFind := procedure begin ShowFindBar; end;
  Result.ShowReplace := procedure begin ShowReplaceBar; end;
  Result.FindInPreview := procedure begin ExecuteFind; end;
  Result.Undo := procedure begin mdEditor.Undo; mdEditor.SetFocus; end;
  Result.Redo := procedure begin mdEditor.Redo; mdEditor.SetFocus; end;
  Result.SelectAll := procedure begin mdEditor.SelectAll; mdEditor.SetFocus; end;
  Result.Indent := procedure begin mdEditor.Indent; mdEditor.SetFocus; end;
  Result.Outdent := procedure begin mdEditor.Outdent; mdEditor.SetFocus; end;
  Result.DeleteWordLeft := procedure begin mdEditor.DeleteWordLeft; mdEditor.SetFocus; end;
  Result.ExecuteFormat :=
    procedure(const Command: TEditorCommand)
    begin
      ExecuteFormatCommand(Command);
    end;
end;

procedure TMarkdown4DStudioVCLForm.SetViewMode(const Mode: TPadViewMode);
begin
  if FZenActive then
    ExitZen;

  if FViewMode = TPadViewMode.Split then
    FSplitEditorWidth := mdEditor.Width;

  FViewMode := Mode;
  ApplyViewMode;
end;

procedure TMarkdown4DStudioVCLForm.ApplyViewMode;
begin
  case FViewMode of
    TPadViewMode.EditorOnly:
      begin
        splMain.Visible := False;
        mdPreview.Visible := False;
        mdEditor.Visible := True;
        mdEditor.Align := alClient;
      end;
    TPadViewMode.PreviewOnly:
      begin
        mdEditor.Visible := False;
        splMain.Visible := False;
        mdPreview.Visible := True;
      end;
  else
    begin
      mdEditor.Align := alLeft;
      mdEditor.Visible := True;
      mdEditor.Width := FSplitEditorWidth;
      splMain.Visible := True;
      mdPreview.Visible := True;
    end;
  end;

  EnforceTopBarOrder;
  EnforceLeftPaneOrder;
end;

procedure TMarkdown4DStudioVCLForm.EnforceTopBarOrder;
begin
  DisableAlign;
  try
    var Y := 0;

    if (not FUseCustomTitleBar) and (FTabStrip <> nil) and FTabStrip.Visible then
    begin
      FTabStrip.Top := Y;
      Inc(Y, FTabStrip.Height);
    end;

    pnlToolbar.Top := Y;
    Inc(Y, pnlToolbar.Height);

    pnlFind.Top := Y;
  finally
    EnableAlign;
  end;
end;

procedure TMarkdown4DStudioVCLForm.EnforceLeftPaneOrder;
begin
  DisableAlign;
  try
    var LeftOrder := 0;

    if pnlToc.Visible then
    begin
      pnlToc.Left := LeftOrder;
      Inc(LeftOrder);
    end;

    if splToc.Visible then
    begin
      splToc.Left := LeftOrder;
      Inc(LeftOrder);
    end;

    if mdEditor.Visible and (mdEditor.Align = alLeft) then
    begin
      mdEditor.Left := LeftOrder;
      Inc(LeftOrder);
    end;

    if splMain.Visible then
      splMain.Left := LeftOrder;
  finally
    EnableAlign;
  end;
end;

procedure TMarkdown4DStudioVCLForm.ShowFindBar;
begin
  pnlFind.Visible := True;

  EnforceTopBarOrder;

  const Sel = mdEditor.SelectedText;
  if Sel <> '' then
    edtEditorFind.Text := Sel;

  edtEditorFind.SetFocus;
  edtEditorFind.SelectAll;

  UpdateFindCount;
end;

procedure TMarkdown4DStudioVCLForm.ShowReplaceBar;
begin
  ShowFindBar;

  FReplaceEdit.SetFocus;
  FReplaceEdit.SelectAll;
end;

procedure TMarkdown4DStudioVCLForm.CloseFindBar;
begin
  pnlFind.Visible := False;
  mdEditor.ClearHighlights;

  EnforceTopBarOrder;

  if mdEditor.CanFocus then
    mdEditor.SetFocus;
end;

procedure TMarkdown4DStudioVCLForm.FindInEditor;
begin
  FController.FindInEditor;
end;

procedure TMarkdown4DStudioVCLForm.UpdateFindCount;
begin
  FController.UpdateFindCount;
end;

procedure TMarkdown4DStudioVCLForm.HandleEditorFindChange(Sender: TObject);
begin
  UpdateFindCount;
end;

procedure TMarkdown4DStudioVCLForm.ShowPalette;
begin
  FController.RebuildPaletteCommands;

  FPaletteEdit.Text := '';
  RefreshPaletteList;

  FPalette.Left := (ClientWidth - FPalette.Width) div 2;
  FPalette.Top := PaletteTop;
  FPalette.BringToFront;
  FPalette.Visible := True;
  FPaletteEdit.SetFocus;
end;

procedure TMarkdown4DStudioVCLForm.ClosePalette;
begin
  FPalette.Visible := False;

  if mdEditor.CanFocus then
    mdEditor.SetFocus;
end;

procedure TMarkdown4DStudioVCLForm.RefreshPaletteList;
begin
  FController.RefreshMatches(FPaletteEdit.Text);

  FPaletteList.Items.BeginUpdate;
  try
    FPaletteList.Items.Clear;

    for var Entry in FPaletteMatches do
    begin
      FPaletteList.Items.Add(Entry.Command.Name);
    end;
  finally
    FPaletteList.Items.EndUpdate;
  end;

  if FPaletteList.Count > 0 then
    FPaletteList.ItemIndex := 0
  else
    FPaletteList.ItemIndex := -1;
end;

procedure TMarkdown4DStudioVCLForm.HandlePaletteChange(Sender: TObject);
begin
  RefreshPaletteList;

  if FPaletteList.Count > 0 then
    FPaletteList.ItemIndex := 0;
end;

procedure TMarkdown4DStudioVCLForm.HandlePaletteDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
begin
  const List = Control as TListBox;
  const Canvas = List.Canvas;

  Canvas.FillRect(Rect);

  if (Index < 0) or (Index > High(FPaletteMatches)) then
    Exit;

  const Command = FPaletteMatches[Index].Command;
  const TextTop = Rect.Top + (Rect.Height - Canvas.TextHeight('Wg')) div 2;

  Canvas.TextOut(Rect.Left + PaletteTextMargin, TextTop, Command.Name);

  if Command.ShortcutText = '' then
    Exit;

  const PreviousColor = Canvas.Font.Color;
  try
    if not (odSelected in State) then
      Canvas.Font.Color := clGrayText;

    const ShortcutWidth = Canvas.TextWidth(Command.ShortcutText);
    Canvas.TextOut(Rect.Right - PaletteTextMargin - ShortcutWidth, TextTop, Command.ShortcutText);
  finally
    Canvas.Font.Color := PreviousColor;
  end;
end;

procedure TMarkdown4DStudioVCLForm.HandlePaletteDblClick(Sender: TObject);
begin
  ExecuteSelectedCommand;
end;

procedure TMarkdown4DStudioVCLForm.PaletteMoveSelection(const Delta: Integer);
begin
  if FPaletteList.Count = 0 then
    Exit;

  const NewIndex = EnsureRange(FPaletteList.ItemIndex + Delta, 0, FPaletteList.Count - 1);
  FPaletteList.ItemIndex := NewIndex;
end;

procedure TMarkdown4DStudioVCLForm.ExecuteSelectedCommand;
begin
  const Index = FPaletteList.ItemIndex;
  if (Index < 0) or (Index >= FController.PaletteMatchCount) then
    Exit;

  ClosePalette;

  FController.InvokePaletteCommand(Index);
end;

procedure TMarkdown4DStudioVCLForm.ToggleZen;
begin
  if FZenActive then
    ExitZen
  else
    EnterZen;
end;

procedure TMarkdown4DStudioVCLForm.EnterZen;
begin
  if FPalette.Visible then
    ClosePalette;

  FZenFindWasVisible := pnlFind.Visible;
  FZenTocWasVisible := pnlToc.Visible;
  FPreZenViewMode := FViewMode;

  pnlToolbar.Visible := False;
  FTabStrip.Visible := False;
  pnlToc.Visible := False;
  splToc.Visible := False;
  pnlStatus.Visible := False;
  pnlFind.Visible := False;

  // Keep the current view mode so zen mirrors what the user is doing: preview-only
  // becomes a distraction-free rendering, editor-only a distraction-free editor.
  // Split has no single column to center, so it collapses to editor-only.
  if FViewMode = TPadViewMode.Split then
  begin
    FSplitEditorWidth := mdEditor.Width;
    FViewMode := TPadViewMode.EditorOnly;
  end;
  ApplyViewMode;

  // Blend the padding margins into the centered pane's background.
  var ZenPadColor := clWhite;
  if FDarkThemeActive then
    ZenPadColor := ZenPadDarkColor;

  FZenLeftPad := TPanel.Create(Self);
  FZenLeftPad.Parent := Self;
  FZenLeftPad.BevelOuter := bvNone;
  FZenLeftPad.ShowCaption := False;
  FZenLeftPad.ParentBackground := False;
  FZenLeftPad.Color := ZenPadColor;
  FZenLeftPad.Align := alLeft;

  FZenRightPad := TPanel.Create(Self);
  FZenRightPad.Parent := Self;
  FZenRightPad.BevelOuter := bvNone;
  FZenRightPad.ShowCaption := False;
  FZenRightPad.ParentBackground := False;
  FZenRightPad.Color := ZenPadColor;
  FZenRightPad.Align := alRight;

  // The visible pane (editor for editor-only, preview for preview-only) is already
  // client-aligned by ApplyViewMode, so it centers between the zen padding panels.

  UpdateZenPadding;

  FZenActive := True;

  if mdEditor.CanFocus then
    mdEditor.SetFocus;
end;

procedure TMarkdown4DStudioVCLForm.ExitZen;
begin
  FreeAndNil(FZenLeftPad);
  FreeAndNil(FZenRightPad);

  pnlToolbar.Visible := True;
  FTabStrip.Visible := True;
  pnlStatus.Visible := True;
  pnlToc.Visible := FZenTocWasVisible;
  splToc.Visible := FZenTocWasVisible;
  pnlFind.Visible := FZenFindWasVisible;

  FViewMode := FPreZenViewMode;
  ApplyViewMode;

  FZenActive := False;

  if mdEditor.CanFocus then
    mdEditor.SetFocus;
end;

procedure TMarkdown4DStudioVCLForm.UpdateZenPadding;
begin
  if (FZenLeftPad = nil) or (FZenRightPad = nil) then
    Exit;

  const Pad = Max(0, (ClientWidth - ZenMaxTextWidth) div 2);
  FZenLeftPad.Width := Pad;
  FZenRightPad.Width := Pad;
end;

procedure TMarkdown4DStudioVCLForm.HandleResize(Sender: TObject);
begin
  LayoutTitleBar;

  if FZenActive then
    UpdateZenPadding;

  if FPalette <> nil then
    FPalette.Left := (ClientWidth - FPalette.Width) div 2;
end;

class function TMarkdown4DStudioVCLForm.BuildSampleMarkdown: string;
begin
  Result :=
    '# Markdown4D Studio'#10#10 +
    'A native Markdown editor with a **live preview**, a clickable table of contents, ' +
    'and synchronized scrolling. Everything renders directly on the VCL canvas, ' +
    'without an embedded browser.'#10#10 +
    '## Editing'#10#10 +
    'Use the toolbar or shortcuts: **Ctrl+B** bold, *Ctrl+I* italic, Ctrl+K link, ' +
    'and the Code button wraps the selection in a fenced block.'#10#10 +
    '- Undo and redo with Ctrl+Z / Ctrl+Y'#10 +
    '- Source syntax highlighting on the left'#10 +
    '- Debounced incremental preview on the right'#10#10 +
    '## Navigation'#10#10 +
    'The contents panel is built from the heading structure. Click an entry to jump ' +
    'there in both panes; it also follows the preview as you scroll.'#10#10 +
    '### Sub-section A'#10#10 +
    'Some filler text so the sub-sections occupy vertical space and the scroll-sync ' +
    'has something to align against.'#10#10 +
    '### Sub-section B'#10#10 +
    'More filler text. Paragraphs wrap to the width of the preview pane.'#10#10 +
    '## Charts'#10#10 +
    'Chart code blocks in the Codolex JSON format render natively on the canvas:'#10#10 +
    '```json'#10 +
    '{"type":"chart","data":{"type":"bar","data":{"labels":["Edit","Preview","Sync"],' +
    '"datasets":[{"label":"Coverage","data":[100,100,90],"backgroundColor":"#4E79A7"}]},' +
    '"options":{"plugins":{"title":{"display":true,"text":"Feature Coverage"}},' +
    '"scales":{"y":{"min":0,"max":100}}}}}'#10 +
    '```'#10#10 +
    '## Diagrams'#10#10 +
    'Mermaid fenced code blocks upgrade to native graphics on the canvas once the fence '  +
    'closes. Flowcharts lay out nodes, edges and labels:'#10#10 +
    '```mermaid'#10 +
    'flowchart LR'#10 +
    '  Edit[Edit source] --> Parse{Parse ok?}'#10 +
    '  Parse -->|yes| Preview([Render preview])'#10 +
    '  Parse -->|no| Edit'#10 +
    '  Preview --> Sync'#10 +
    '```'#10#10 +
    'Sequence diagrams draw participants, lifelines and messages:'#10#10 +
    '```mermaid'#10 +
    'sequenceDiagram'#10 +
    '  participant User'#10 +
    '  participant Editor'#10 +
    '  participant Viewer'#10 +
    '  User->>Editor: Type markdown'#10 +
    '  Editor->>Viewer: Incremental parse'#10 +
    '  Viewer-->>User: Rendered preview'#10 +
    '```'#10#10 +
    '## Code'#10#10 +
    '```pascal'#10 +
    'procedure Greet(const Name: string);'#10 +
    'begin'#10 +
    '  Writeln(Format(''Hello, %s!'', [Name]));'#10 +
    'end;'#10 +
    '```'#10#10 +
    '> Open a README.md to edit it live, then Save to write it back.'#10;
end;

end.
