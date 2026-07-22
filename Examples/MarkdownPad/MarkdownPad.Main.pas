unit MarkdownPad.Main;

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
  MarkdownPad.Workspace.Interfaces,
  MarkdownPad.Session,
  MarkdownPad.Commands,
  MarkdownPad.TabStrip,
  MarkdownPad.FileWatcher;

type
  TMarkdownPadForm = class(TForm)
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
  private
    const
      WindowCaption = 'Markdown4D Pad';
      InitialClientWidth = 1200;
      InitialClientHeight = 760;
      ToolbarHeight = 36;
      TabsHeight = 30;
      TitleBarHeight = 40;
      TitleBarLeftInset = 8;
      CaptionButtonsReserve = 160;
      DwmCaptionColorAttribute = 35;
      StatusBarHeight = 22;
      StatusLabelWidth = 160;
      StatusLabelLeftMargin = 8;
      TocPanelWidth = 240;
      ButtonSpacing = 4;
      IconButtonSize = 32;
      IconGlyphSize = 14;
      SeparatorWidth = 1;
      FindEditWidth = 160;
      TickIntervalMilliseconds = 100;
      TocHeaderCaption = 'Contents';
      FindButtonCaption = 'Find';
      FluentIconFontName = 'Segoe Fluent Icons';
      Mdl2IconFontName = 'Segoe MDL2 Assets';
      GlyphNew = Char($E7C3);
      GlyphOpen = Char($E8E5);
      GlyphSave = Char($E74E);
      GlyphSaveAs = Char($E792);
      GlyphRecent = Char($E81C);
      GlyphExport = Char($E896);
      GlyphCopyHtml = Char($E8C8);
      GlyphBold = Char($E8DD);
      GlyphItalic = Char($E8DB);
      GlyphLink = Char($E71B);
      GlyphCode = Char($E943);
      GlyphTheme = Char($E793);
      GlyphToc = Char($E8FD);
      GlyphFind = Char($E721);
      HintNew = 'New (Ctrl+N)';
      HintOpen = 'Open (Ctrl+O)';
      HintSave = 'Save (Ctrl+S)';
      HintSaveAs = 'Save As (Ctrl+Shift+S)';
      HintRecent = 'Recent files';
      HintExport = 'Export HTML (Ctrl+Shift+E)';
      HintCopyHtml = 'Copy HTML (Ctrl+Shift+C)';
      HintBold = 'Bold (Ctrl+B)';
      HintItalic = 'Italic (Ctrl+I)';
      HintLink = 'Link (Ctrl+K)';
      HintCode = 'Code block';
      HintTheme = 'Toggle theme';
      HintToc = 'Toggle contents';
      HintFind = 'Find in preview';
      ToolbarLightColor = TColor($00F3F3F3);
      ToolbarDarkColor = TColor($002D2D2D);
      IconLightColor = TColor($00404040);
      IconDarkColor = TColor($00D6D6D6);
      SeparatorLightColor = TColor($00D0D0D0);
      SeparatorDarkColor = TColor($00505050);
      TabAccentColor = TColor($00C0742C);
      TabActiveDarkColor = TColor($003F3F3F);
      TabHoverLightColor = TColor($00EAEAEA);
      TabHoverDarkColor = TColor($00383838);
      ZenPadDarkColor = TColor($0017110D); // matches the dark theme editor/preview background ($0D1117)
      MarkdownFilter = 'Markdown files (*.md)|*.md|All files (*.*)|*.*';
      DefaultExtension = 'md';
      ModifiedMarker = ' *';
      StatusPositionFormat = 'Ln %d, Col %d';
      StatusWordsFormat = '%d words';
      TitleFormat = '%s - %s';
      SessionFileName = 'MarkdownPad.Vcl.json';
      UntitledName = 'Untitled';
      RecentNoneCaption = '(none)';
      CloseUnsavedPrompt = 'Save changes before closing this document?';
      CloseDocumentPromptFormat = 'Save changes to %s before closing?';
      ReloadPrompt = 'File changed on disk. Reload and lose your changes?';
      FindBarHeight = 32;
      FindBarEditWidth = 240;
      PaletteWidth = 560;
      PaletteTop = 80;
      PaletteRowHeight = 22;
      PaletteVisibleRows = 10;
      PaletteTextMargin = 8;
      ZenMaxTextWidth = 820;
      MatchCountFormat = '%d matches';
      SingleMatchCaption = '1 match';
      NoMatchCaption = 'No matches';
      EmptyFindCaption = '';
      FindHintCaption = 'Find in editor';
      PaletteHintCaption = 'Type a command';
      CmdNewName = 'New tab';
      CmdNewShortcut = 'Ctrl+N';
      CmdOpenName = 'Open...';
      CmdOpenShortcut = 'Ctrl+O';
      CmdSaveName = 'Save';
      CmdSaveShortcut = 'Ctrl+S';
      CmdSaveAsName = 'Save As...';
      CmdSaveAsShortcut = 'Ctrl+Shift+S';
      CmdCloseName = 'Close tab';
      CmdCloseShortcut = 'Ctrl+W';
      CmdNextTabName = 'Next tab';
      CmdNextTabShortcut = 'Ctrl+Tab';
      CmdThemeName = 'Toggle theme';
      CmdThemeShortcut = '';
      CmdTocName = 'Toggle contents';
      CmdTocShortcut = '';
      CmdViewEditorName = 'Editor only';
      CmdViewEditorShortcut = 'Ctrl+1';
      CmdViewSplitName = 'Split view';
      CmdViewSplitShortcut = 'Ctrl+2';
      CmdViewPreviewName = 'Preview only';
      CmdViewPreviewShortcut = 'Ctrl+3';
      CmdZenName = 'Zen mode';
      CmdZenShortcut = 'F11';
      CmdFindName = 'Find in editor';
      CmdFindShortcut = 'Ctrl+F';
      CmdFindPreviewName = 'Find in preview';
      CmdFindPreviewShortcut = '';
      CmdBoldName = 'Bold';
      CmdBoldShortcut = 'Ctrl+B';
      CmdItalicName = 'Italic';
      CmdItalicShortcut = 'Ctrl+I';
      CmdLinkName = 'Link';
      CmdLinkShortcut = '';
      CmdCodeName = 'Code block';
      CmdCodeShortcut = '';
      CmdH1Name = 'Heading 1';
      CmdH1Shortcut = 'Ctrl+Shift+1';
      CmdH2Name = 'Heading 2';
      CmdH2Shortcut = 'Ctrl+Shift+2';
      CmdH3Name = 'Heading 3';
      CmdH3Shortcut = 'Ctrl+Shift+3';
      CmdBulletName = 'Bullet list';
      CmdBulletShortcut = 'Ctrl+Shift+U';
      CmdNumberName = 'Numbered list';
      CmdNumberShortcut = 'Ctrl+Shift+O';
      CmdQuoteName = 'Quote';
      CmdQuoteShortcut = 'Ctrl+Shift+Q';
      CmdStrikeName = 'Strikethrough';
      CmdStrikeShortcut = 'Ctrl+Shift+X';
      CmdTableName = 'Insert table';
      CmdTableShortcut = 'Ctrl+Shift+T';
      CmdExportName = 'Export HTML...';
      CmdExportShortcut = 'Ctrl+Shift+E';
      CmdCopyHtmlName = 'Copy HTML';
      CmdCopyHtmlShortcut = 'Ctrl+Shift+C';
      ExportButtonCaption = 'Export';
      CopyHtmlButtonCaption = 'Copy HTML';
      HtmlFilter = 'HTML files (*.html)|*.html|All files (*.*)|*.*';
      HtmlExtension = 'html';
      CatFile = 'File';
      CatView = 'View';
      CatEdit = 'Edit';
      CatFormat = 'Format';
      CatRecent = 'Recent';
      RecentShortcut = '';
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
      FFindButton: TSpeedButton;
      FFindEdit: TEdit;
      FIconButtons: TArray<TSpeedButton>;
      FSeparators: TArray<TPanel>;
      FSync: TMarkdownEditorSync;
      FTocEntries: TArray<IMarkdownTocEntry>;
      FLightTheme: TMarkdownTheme;
      FDarkTheme: TMarkdownTheme;
      FDarkThemeActive: Boolean;
      FTitleBar: TTitleBarPanel;
      FTabStrip: TPadTabStrip;
      FUseCustomTitleBar: Boolean;
      FTitleBarColor: TColor;
      FWorkspace: IPadWorkspace;
      FActiveDoc: IPadDocument;
      FSession: TPadSession;
      FWatcher: TPadFileWatcher;
      FMapDirty: Boolean;
      FSyncing: Boolean;
      FSwapping: Boolean;
      FLastCaret: Integer;
      FViewMode: TPadViewMode;
      FSplitEditorWidth: Integer;
      FPalette: TPanel;
      FPaletteEdit: TEdit;
      FPaletteList: TListBox;
      FCommands: TPadCommandRegistry;
      FPaletteMatches: TArray<TPadCommandMatch>;
      FZenActive: Boolean;
      FPreZenViewMode: TPadViewMode;
      FZenLeftPad: TPanel;
      FZenRightPad: TPanel;
      FZenTocWasVisible: Boolean;
      FZenFindWasVisible: Boolean;
    procedure ConfigureControls;
    procedure BuildToolbar;
    function ResolveIconFontName: string;
    function AddIconButton(const Glyph: string; const Hint: string; const Handler: TNotifyEvent): TSpeedButton;
    procedure AddSeparator;
    procedure WMDropFiles(var Message: TMessage); message WM_DROPFILES;
    procedure HandleFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleCloseQuery(Sender: TObject; var CanClose: Boolean);
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
    procedure HandleFindClick(Sender: TObject);
    procedure HandleFindEditKeyPress(Sender: TObject; var Key: Char);
    procedure BuildTitleBar;
    procedure LayoutTitleBar;
    procedure ApplyCaptionColor;
    procedure ApplyTitleBarColors(const ToolbarColor, IconColor, SeparatorColor: TColor);
    procedure HandleTitleBarPaint(Sender: TObject; Canvas: TCanvas; var ARect: TRect);
    procedure HandleTabSelect(Sender: TObject; const Index: Integer);
    procedure HandleTabClose(Sender: TObject; const Index: Integer);
    procedure HandleTabAdd(Sender: TObject);
    procedure HandleTabReorder(Sender: TObject; const FromIndex, ToIndex: Integer);
    procedure HandleEditorChange(Sender: TObject);
    procedure HandleEditorScroll(Sender: TObject);
    procedure HandlePreviewScroll(Sender: TObject);
    procedure HandlePreviewLinkClick(const Sender: TObject; const Url: string);
    procedure HandleTocListClick(Sender: TObject);
    procedure HandleTick(Sender: TObject);
    procedure HandleFileChanged(const Document: IPadDocument);
    procedure OpenPath(const FileName: string);
    procedure SwitchToDocument(const Index: Integer);
    procedure CloseActiveDocument;
    procedure CloseDocumentAt(const Index: Integer);
    function SaveActiveDocument: Boolean;
    procedure SaveToFile(const FileName: string);
    procedure RestoreSession;
    procedure SaveSession;
    procedure RebuildTabs;
    procedure ApplyTheme;
    procedure RebuildSyncAndToc;
    procedure UpdateActiveTocEntry(const SourceLine: Integer);
    procedure UpdateStatusBar;
    procedure UpdateTitle;
    procedure ExecuteFind;
    procedure BuildPalette;
    procedure BuildCommandRegistry;
    procedure RegisterStaticCommands;
    procedure SetViewMode(const Mode: TPadViewMode);
    procedure ApplyViewMode;
    procedure EnforceTopBarOrder;
    procedure EnforceLeftPaneOrder;
    procedure ShowFindBar;
    procedure CloseFindBar;
    procedure FindInEditor;
    procedure UpdateFindCount;
    procedure HandleEditorFindChange(Sender: TObject);
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
    procedure HandleResize(Sender: TObject);
    class function BuildSampleMarkdown: string;
    class procedure ComputeLineColumn(const Text: string; const Offset: Integer; out Line, Column: Integer);
    class function CountWords(const Text: string): Integer;

  protected
    procedure CreateWnd; override;

  public
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MarkdownPadForm: TMarkdownPadForm;

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
  MarkdownPad.Workspace,
  MarkdownPad.HtmlExport;

{$R *.dfm}

constructor TMarkdownPadForm.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  TChartBlockOverride.RegisterOverride;
  TMermaidBlockOverride.RegisterOverride;

  OnKeyDown := HandleFormKeyDown;
  OnCloseQuery := HandleCloseQuery;
  OnResize := HandleResize;

  FLightTheme := TMarkdownTheme.CreateLight;
  FDarkTheme := TMarkdownTheme.CreateDark;
  FSync := TMarkdownEditorSync.Create;

  dlgOpen.Filter := MarkdownFilter;
  dlgSave.Filter := MarkdownFilter;
  dlgSave.DefaultExt := DefaultExtension;
  dlgSaveHtml.Filter := HtmlFilter;
  dlgSaveHtml.DefaultExt := HtmlExtension;

  FWorkspace := TPadWorkspace.Create;
  FSession := TPadSession.Create(TPadSession.ResolvePath(SessionFileName));
  FSession.Load;
  FWatcher := TPadFileWatcher.Create(FWorkspace, HandleFileChanged);

  ConfigureControls;
  BuildToolbar;
  BuildTitleBar;
  BuildPalette;
  BuildCommandRegistry;

  mdEditor.AttachPreview(mdPreview);

  FSplitEditorWidth := (InitialClientWidth - TocPanelWidth) div 2;
  FViewMode := TPadViewMode.Split;

  FDarkThemeActive := FSession.DarkTheme;
  ApplyTheme;

  RestoreSession;

  if FUseCustomTitleBar then
    TThread.ForceQueue(nil,
      procedure
      begin
        LayoutTitleBar;
      end);
end;

destructor TMarkdownPadForm.Destroy;
begin
  SaveSession;

  if mdEditor <> nil then
    mdEditor.DetachPreview;

  inherited Destroy;

  FCommands.Free;
  FWatcher.Free;
  FSession.Free;
  FSync.Free;
  FDarkTheme.Free;
  FLightTheme.Free;
end;

procedure TMarkdownPadForm.ConfigureControls;
begin
  lstToc.AlignWithMargins := True;
  lstToc.Margins.SetBounds(4, 20, 4, 4);
  lstToc.BorderStyle := bsNone;
  lstToc.OnClick := HandleTocListClick;

  mdEditor.ShowLineNumbers := True;
  mdEditor.OnChange := HandleEditorChange;
  mdEditor.OnScroll := HandleEditorScroll;

  mdPreview.OnScroll := HandlePreviewScroll;
  mdPreview.OnLinkClick := HandlePreviewLinkClick;

  lblPos.AlignWithMargins := True;
  lblPos.Margins.SetBounds(StatusLabelLeftMargin, 0, 0, 0);
  lblPos.Layout := tlCenter;
  lblPos.AutoSize := False;
  lblPos.Width := StatusLabelWidth;
  lblPos.Transparent := True;

  lblWords.AlignWithMargins := True;
  lblWords.Margins.SetBounds(StatusLabelLeftMargin, 0, 0, 0);
  lblWords.Layout := tlCenter;
  lblWords.AutoSize := False;
  lblWords.Width := StatusLabelWidth;
  lblWords.Transparent := True;

  edtEditorFind.TextHint := FindHintCaption;
  edtEditorFind.OnChange := HandleEditorFindChange;

  lblFindCount.Layout := tlCenter;
  lblFindCount.Caption := EmptyFindCaption;

  popRecent.AutoHotkeys := maManual;

  tmrTick.Interval := TickIntervalMilliseconds;
  tmrTick.OnTimer := HandleTick;
  tmrTick.Enabled := True;
end;

procedure TMarkdownPadForm.BuildToolbar;
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

function TMarkdownPadForm.ResolveIconFontName: string;
begin
  if Screen.Fonts.IndexOf(FluentIconFontName) >= 0 then
    Result := FluentIconFontName
  else
    Result := Mdl2IconFontName;
end;

function TMarkdownPadForm.AddIconButton(const Glyph: string; const Hint: string;
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

procedure TMarkdownPadForm.AddSeparator;
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

procedure TMarkdownPadForm.CreateWnd;
begin
  inherited CreateWnd;

  DragAcceptFiles(Handle, True);
end;

procedure TMarkdownPadForm.WMDropFiles(var Message: TMessage);
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

procedure TMarkdownPadForm.HandleFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if FPalette.Visible then
  begin
    case Key of
      VK_UP:
        begin
          PaletteMoveSelection(-1);
          Key := 0;
          Exit;
        end;
      VK_DOWN:
        begin
          PaletteMoveSelection(1);
          Key := 0;
          Exit;
        end;
      VK_RETURN:
        begin
          ExecuteSelectedCommand;
          Key := 0;
          Exit;
        end;
      VK_ESCAPE:
        begin
          ClosePalette;
          Key := 0;
          Exit;
        end;
    end;

    if ssCtrl in Shift then
      Key := 0;

    Exit;
  end;

  if pnlFind.Visible and (Key = VK_RETURN) and edtEditorFind.Focused then
  begin
    FindInEditor;
    Key := 0;
    Exit;
  end;

  case Key of
    VK_F11:
      begin
        ToggleZen;
        Key := 0;
        Exit;
      end;
    VK_F3:
      begin
        if pnlFind.Visible then
        begin
          FindInEditor;
          Key := 0;
        end;

        Exit;
      end;
    VK_ESCAPE:
      begin
        if pnlFind.Visible then
        begin
          CloseFindBar;
          Key := 0;
        end
        else if FZenActive then
        begin
          ExitZen;
          Key := 0;
        end;

        Exit;
      end;
  end;

  if not (ssCtrl in Shift) then
    Exit;

  if ssShift in Shift then
  begin
    case Key of
      Ord('1'):
        begin
          ExecuteFormatCommand(TEditorCommand.Heading1);
          Key := 0;
          Exit;
        end;
      Ord('2'):
        begin
          ExecuteFormatCommand(TEditorCommand.Heading2);
          Key := 0;
          Exit;
        end;
      Ord('3'):
        begin
          ExecuteFormatCommand(TEditorCommand.Heading3);
          Key := 0;
          Exit;
        end;
      Ord('U'):
        begin
          ExecuteFormatCommand(TEditorCommand.BulletList);
          Key := 0;
          Exit;
        end;
      Ord('O'):
        begin
          ExecuteFormatCommand(TEditorCommand.NumberedList);
          Key := 0;
          Exit;
        end;
      Ord('Q'):
        begin
          ExecuteFormatCommand(TEditorCommand.Quote);
          Key := 0;
          Exit;
        end;
      Ord('X'):
        begin
          ExecuteFormatCommand(TEditorCommand.Strikethrough);
          Key := 0;
          Exit;
        end;
      Ord('T'):
        begin
          ExecuteFormatCommand(TEditorCommand.Table);
          Key := 0;
          Exit;
        end;
      Ord('E'):
        begin
          DoExportHtml;
          Key := 0;
          Exit;
        end;
      Ord('C'):
        begin
          DoCopyHtml;
          Key := 0;
          Exit;
        end;
      Ord('S'):
        begin
          HandleSaveAsClick(nil);
          Key := 0;
          Exit;
        end;
      VK_TAB:
        begin
          FWorkspace.ActivatePrevious;
          SwitchToDocument(FWorkspace.ActiveIndex);
          Key := 0;
          Exit;
        end;
    end;

    Exit;
  end;

  case Key of
    Ord('1'):
      begin
        SetViewMode(TPadViewMode.EditorOnly);
        Key := 0;
      end;
    Ord('2'):
      begin
        SetViewMode(TPadViewMode.Split);
        Key := 0;
      end;
    Ord('3'):
      begin
        SetViewMode(TPadViewMode.PreviewOnly);
        Key := 0;
      end;
    Ord('F'):
      begin
        ShowFindBar;
        Key := 0;
      end;
    Ord('K'):
      begin
        ShowPalette;
        Key := 0;
      end;
    Ord('N'):
      begin
        HandleNewClick(nil);
        Key := 0;
      end;
    Ord('O'):
      begin
        HandleOpenClick(nil);
        Key := 0;
      end;
    Ord('S'):
      begin
        HandleSaveClick(nil);
        Key := 0;
      end;
    Ord('W'):
      begin
        CloseActiveDocument;
        Key := 0;
      end;
    VK_TAB:
      begin
        FWorkspace.ActivateNext;
        SwitchToDocument(FWorkspace.ActiveIndex);
        Key := 0;
      end;
  end;
end;

procedure TMarkdownPadForm.HandleCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FZenActive then
    ExitZen;

  for var Index := 0 to FWorkspace.Count - 1 do
  begin
    const Document = FWorkspace.Documents[Index];
    if not Document.Modified then
      Continue;

    SwitchToDocument(Index);

    const Prompt = Format(CloseDocumentPromptFormat, [Document.DisplayName]);
    const Answer = MessageDlg(Prompt, mtConfirmation, [mbYes, mbNo, mbCancel], 0);

    if Answer = mrCancel then
    begin
      CanClose := False;
      Exit;
    end;

    if (Answer = mrYes) and not SaveActiveDocument then
    begin
      CanClose := False;
      Exit;
    end;

    Document.Modified := False;
  end;

  CanClose := True;
end;

procedure TMarkdownPadForm.HandleNewClick(Sender: TObject);
begin
  FWorkspace.NewDocument;
  SwitchToDocument(FWorkspace.ActiveIndex);
end;

procedure TMarkdownPadForm.HandleOpenClick(Sender: TObject);
begin
  if dlgOpen.Execute then
    OpenPath(dlgOpen.FileName);
end;

procedure TMarkdownPadForm.HandleSaveClick(Sender: TObject);
begin
  if FActiveDoc = nil then
    Exit;

  if FActiveDoc.IsUntitled then
    HandleSaveAsClick(Sender)
  else
    SaveToFile(FActiveDoc.FileName);
end;

procedure TMarkdownPadForm.HandleSaveAsClick(Sender: TObject);
begin
  if FActiveDoc = nil then
    Exit;

  if not FActiveDoc.IsUntitled then
    dlgSave.FileName := FActiveDoc.FileName;

  if dlgSave.Execute then
    SaveToFile(dlgSave.FileName);
end;

procedure TMarkdownPadForm.HandleRecentClick(Sender: TObject);
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

procedure TMarkdownPadForm.HandleRecentItemClick(Sender: TObject);
begin
  const Item = Sender as TMenuItem;
  OpenPath(Item.Caption);
end;

procedure TMarkdownPadForm.HandleBoldClick(Sender: TObject);
begin
  mdEditor.ExecuteCommand(TEditorCommand.Bold);
  mdEditor.SetFocus;
end;

procedure TMarkdownPadForm.HandleItalicClick(Sender: TObject);
begin
  mdEditor.ExecuteCommand(TEditorCommand.Italic);
  mdEditor.SetFocus;
end;

procedure TMarkdownPadForm.HandleLinkClick(Sender: TObject);
begin
  mdEditor.ExecuteCommand(TEditorCommand.Link);
  mdEditor.SetFocus;
end;

procedure TMarkdownPadForm.HandleCodeClick(Sender: TObject);
begin
  mdEditor.ExecuteCommand(TEditorCommand.CodeBlock);
  mdEditor.SetFocus;
end;

procedure TMarkdownPadForm.HandleExportClick(Sender: TObject);
begin
  DoExportHtml;
end;

procedure TMarkdownPadForm.HandleCopyHtmlClick(Sender: TObject);
begin
  DoCopyHtml;
end;

procedure TMarkdownPadForm.ExecuteFormatCommand(const Command: TEditorCommand);
begin
  mdEditor.ExecuteCommand(Command);
  mdEditor.SetFocus;
end;

procedure TMarkdownPadForm.DoExportHtml;
begin
  if FActiveDoc <> nil then
    FActiveDoc.Text := mdEditor.Text;

  var Title := UntitledName;
  if FActiveDoc <> nil then
    Title := FActiveDoc.DisplayName;

  dlgSaveHtml.FileName := TPath.ChangeExtension(Title, '.' + HtmlExtension);

  if not dlgSaveHtml.Execute then
    Exit;

  const Html = TMarkdownHtmlExport.BuildDocument(mdEditor.Text, Title, FDarkThemeActive);
  TFile.WriteAllText(dlgSaveHtml.FileName, Html, TEncoding.UTF8);
end;

procedure TMarkdownPadForm.DoCopyHtml;
begin
  const Fragment = TMarkdown.ToHtml(mdEditor.Text, TMarkdownDialect.Gfm);
  CopyHtmlToClipboard(Fragment);
end;

procedure TMarkdownPadForm.CopyHtmlToClipboard(const Fragment: string);
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

procedure TMarkdownPadForm.HandleThemeClick(Sender: TObject);
begin
  FDarkThemeActive := not FDarkThemeActive;
  ApplyTheme;
end;

procedure TMarkdownPadForm.HandleTocClick(Sender: TObject);
begin
  const ShowToc = not pnlToc.Visible;
  pnlToc.Visible := ShowToc;
  splToc.Visible := ShowToc;

  EnforceLeftPaneOrder;
end;

procedure TMarkdownPadForm.HandleFindClick(Sender: TObject);
begin
  ExecuteFind;
end;

procedure TMarkdownPadForm.HandleFindEditKeyPress(Sender: TObject; var Key: Char);
begin
  if Key <> #13 then
    Exit;

  Key := #0;
  ExecuteFind;
end;

procedure TMarkdownPadForm.BuildTitleBar;
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

procedure TMarkdownPadForm.LayoutTitleBar;
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

procedure TMarkdownPadForm.HandleTitleBarPaint(Sender: TObject; Canvas: TCanvas; var ARect: TRect);
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := FTitleBarColor;
  Canvas.FillRect(ARect);
end;

procedure TMarkdownPadForm.ApplyCaptionColor;
begin
  if not FUseCustomTitleBar or not HandleAllocated then
    Exit;

  var CaptionColor: DWORD := ColorToRGB(FTitleBarColor);
  DwmSetWindowAttribute(Handle, DwmCaptionColorAttribute, @CaptionColor, SizeOf(CaptionColor));
end;

procedure TMarkdownPadForm.ApplyTitleBarColors(const ToolbarColor, IconColor, SeparatorColor: TColor);
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

procedure TMarkdownPadForm.HandleTabSelect(Sender: TObject; const Index: Integer);
begin
  SwitchToDocument(Index);
end;

procedure TMarkdownPadForm.HandleTabClose(Sender: TObject; const Index: Integer);
begin
  CloseDocumentAt(Index);
end;

procedure TMarkdownPadForm.HandleTabAdd(Sender: TObject);
begin
  HandleNewClick(nil);
end;

procedure TMarkdownPadForm.HandleTabReorder(Sender: TObject; const FromIndex, ToIndex: Integer);
begin
  FWorkspace.Move(FromIndex, ToIndex);
  RebuildTabs;
end;

procedure TMarkdownPadForm.HandleEditorChange(Sender: TObject);
begin
  if FSwapping then
    Exit;

  const WasModified = (FActiveDoc <> nil) and FActiveDoc.Modified;

  if FActiveDoc <> nil then
    FActiveDoc.Modified := True;

  FMapDirty := True;

  if not WasModified then
    RebuildTabs;

  UpdateTitle;
end;

procedure TMarkdownPadForm.HandleEditorScroll(Sender: TObject);
begin
  if FSyncing then
    Exit;

  const SourceLine = mdEditor.FirstVisibleSourceLine;

  FSyncing := True;
  try
    mdPreview.ScrollOffset := FSync.SourceLineToPreviewOffset(SourceLine);
  finally
    FSyncing := False;
  end;

  UpdateActiveTocEntry(SourceLine);
end;

procedure TMarkdownPadForm.HandlePreviewScroll(Sender: TObject);
begin
  if FSyncing then
    Exit;

  UpdateActiveTocEntry(FSync.PreviewOffsetToSourceLine(mdPreview.ScrollOffset));
end;

procedure TMarkdownPadForm.HandlePreviewLinkClick(const Sender: TObject; const Url: string);
begin
  ShellExecute(0, nil, PChar(Url), nil, nil, SW_SHOWNORMAL);
end;

procedure TMarkdownPadForm.HandleTocListClick(Sender: TObject);
begin
  const Index = lstToc.ItemIndex;
  if (Index < 0) or (Index > High(FTocEntries)) then
    Exit;

  if FMapDirty then
    RebuildSyncAndToc;

  if (Index < 0) or (Index > High(FTocEntries)) then
    Exit;

  const SourceLine = FTocEntries[Index].SourceLine - 1;

  FSyncing := True;
  try
    mdEditor.CaretPosition := mdEditor.SourceLineStartOffset(SourceLine);
    mdEditor.ScrollToSourceLine(SourceLine);
    mdPreview.ScrollOffset := FSync.SourceLineToPreviewOffset(SourceLine);
  finally
    FSyncing := False;
  end;

  lstToc.ItemIndex := Index;
  mdEditor.SetFocus;
end;

procedure TMarkdownPadForm.HandleTick(Sender: TObject);
begin
  if FMapDirty then
    RebuildSyncAndToc;

  UpdateStatusBar;

  FWatcher.Poll;
end;

procedure TMarkdownPadForm.HandleFileChanged(const Document: IPadDocument);
begin
  if Document.Modified then
  begin
    if MessageDlg(ReloadPrompt, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
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
      mdEditor.Text := NewText;
      mdEditor.FlushPreview;

      if mdEditor.CaretPosition > System.Length(NewText) then
        mdEditor.CaretPosition := System.Length(NewText);
    finally
      FSwapping := False;
    end;

    FMapDirty := True;
  end;

  RebuildTabs;
  UpdateTitle;
end;

procedure TMarkdownPadForm.OpenPath(const FileName: string);
begin
  if not TFile.Exists(FileName) then
    Exit;

  var Document: IPadDocument;
  try
    Document := FWorkspace.OpenFile(FileName);
  except
    on E: Exception do
    begin
      MessageDlg(E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  FWatcher.Reset(Document);
  FSession.AddRecentFile(FileName);

  RebuildTabs;
  SwitchToDocument(FWorkspace.ActiveIndex);
end;

procedure TMarkdownPadForm.SwitchToDocument(const Index: Integer);
begin
  if FSwapping then
    Exit;

  if FActiveDoc <> nil then
  begin
    FActiveDoc.Text := mdEditor.Text;
    FActiveDoc.CaretPosition := mdEditor.CaretPosition;
    FActiveDoc.EditorScrollOffset := mdEditor.FirstVisibleSourceLine;
    FActiveDoc.PreviewScrollOffset := mdPreview.ScrollOffset;
    FActiveDoc.EditState := mdEditor.SaveEditState;
  end;

  FWorkspace.Activate(Index);
  FActiveDoc := FWorkspace.ActiveDocument;

  if FActiveDoc = nil then
    Exit;

  FSwapping := True;
  try
    var State: IMarkdownEditorState;
    if Supports(FActiveDoc.EditState, IMarkdownEditorState, State) then
      mdEditor.LoadEditState(State)
    else
      mdEditor.Text := FActiveDoc.Text;

    mdEditor.FlushPreview;
    mdEditor.CaretPosition := FActiveDoc.CaretPosition;
    mdEditor.ScrollToSourceLine(Round(FActiveDoc.EditorScrollOffset));
    mdPreview.ScrollOffset := FActiveDoc.PreviewScrollOffset;
  finally
    FSwapping := False;
  end;

  FLastCaret := -1;
  FMapDirty := True;

  RebuildTabs;
  UpdateTitle;
end;

procedure TMarkdownPadForm.CloseActiveDocument;
begin
  CloseDocumentAt(FWorkspace.ActiveIndex);
end;

procedure TMarkdownPadForm.CloseDocumentAt(const Index: Integer);
begin
  if (Index < 0) or (Index >= FWorkspace.Count) then
    Exit;

  if Index <> FWorkspace.ActiveIndex then
    SwitchToDocument(Index);

  if FActiveDoc = nil then
    Exit;

  if FActiveDoc.Modified then
  begin
    const Answer = MessageDlg(CloseUnsavedPrompt, mtConfirmation, [mbYes, mbNo, mbCancel], 0);
    if Answer = mrCancel then
      Exit;

    if (Answer = mrYes) and not SaveActiveDocument then
      Exit;
  end;

  FWorkspace.CloseDocument(FWorkspace.ActiveIndex);
  FActiveDoc := nil;

  if FWorkspace.Count = 0 then
  begin
    Close;
    Exit;
  end;

  RebuildTabs;
  SwitchToDocument(FWorkspace.ActiveIndex);
end;

function TMarkdownPadForm.SaveActiveDocument: Boolean;
begin
  if FActiveDoc = nil then
    Exit(False);

  FActiveDoc.Text := mdEditor.Text;

  if FActiveDoc.IsUntitled then
  begin
    if not dlgSave.Execute then
      Exit(False);

    SaveToFile(dlgSave.FileName);
  end
  else
    SaveToFile(FActiveDoc.FileName);

  Result := True;
end;

procedure TMarkdownPadForm.SaveToFile(const FileName: string);
begin
  TFile.WriteAllText(FileName, mdEditor.Text);

  FActiveDoc.Text := mdEditor.Text;
  FActiveDoc.FileName := FileName;
  FActiveDoc.Modified := False;

  FWatcher.Reset(FActiveDoc);
  FSession.AddRecentFile(FileName);

  RebuildTabs;
  UpdateTitle;
end;

procedure TMarkdownPadForm.RestoreSession;
begin
  var ActivePath := '';
  if (FSession.ActiveIndex >= 0) and (FSession.ActiveIndex <= High(FSession.OpenFiles)) then
    ActivePath := FSession.OpenFiles[FSession.ActiveIndex];

  for var Path in FSession.OpenFiles do
  begin
    if not TFile.Exists(Path) then
      Continue;

    try
      FWorkspace.OpenFile(Path);
    except
    end;
  end;

  if FWorkspace.Count = 0 then
  begin
    const Document = FWorkspace.NewDocument;
    Document.Text := BuildSampleMarkdown;
  end;

  var RestoreIndex := 0;
  if ActivePath <> '' then
  begin
    const Found = FWorkspace.IndexOfFile(ActivePath);
    if Found >= 0 then
      RestoreIndex := Found;
  end;
  FWorkspace.Activate(RestoreIndex);

  for var Index := 0 to FWorkspace.Count - 1 do
  begin
    FWatcher.Reset(FWorkspace.Documents[Index]);
  end;

  RebuildTabs;
  SwitchToDocument(FWorkspace.ActiveIndex);

  FViewMode := FSession.ViewMode;
  ApplyViewMode;
end;

procedure TMarkdownPadForm.SaveSession;
begin
  if FActiveDoc <> nil then
    FActiveDoc.Text := mdEditor.Text;

  var Titled: TArray<string> := [];
  var FilteredActive := -1;

  for var Index := 0 to FWorkspace.Count - 1 do
  begin
    const Document = FWorkspace.Documents[Index];
    if Document.IsUntitled then
      Continue;

    if Index = FWorkspace.ActiveIndex then
      FilteredActive := System.Length(Titled);

    Titled := Titled + [Document.FileName];
  end;

  FSession.SetOpenFiles(Titled, FilteredActive);
  FSession.DarkTheme := FDarkThemeActive;

  if FZenActive then
    FSession.ViewMode := FPreZenViewMode
  else
    FSession.ViewMode := FViewMode;

  FSession.Save;
end;

procedure TMarkdownPadForm.RebuildTabs;
begin
  var Captions: TArray<string> := [];
  var Modified: TArray<Boolean> := [];

  for var Index := 0 to FWorkspace.Count - 1 do
  begin
    const Document = FWorkspace.Documents[Index];
    Captions := Captions + [Document.DisplayName];
    Modified := Modified + [Document.Modified];
  end;

  FTabStrip.SetTabs(Captions, Modified, FWorkspace.ActiveIndex);
end;

procedure TMarkdownPadForm.ApplyTheme;
begin
  var ToolbarColor := ToolbarLightColor;
  var IconColor := IconLightColor;
  var SeparatorColor := SeparatorLightColor;
  var ActiveTabColor := clWhite;
  var HoverTabColor := TabHoverLightColor;

  if FDarkThemeActive then
  begin
    mdEditor.Theme := FDarkTheme;
    mdPreview.Theme := FDarkTheme;

    ToolbarColor := ToolbarDarkColor;
    IconColor := IconDarkColor;
    SeparatorColor := SeparatorDarkColor;

    ActiveTabColor := TabActiveDarkColor;
    HoverTabColor := TabHoverDarkColor;
  end
  else
  begin
    mdEditor.Theme := FLightTheme;
    mdPreview.Theme := FLightTheme;
  end;

  // The custom title bar area behind the system caption buttons shows the form
  // background, so tint it with the chrome colour; content panes cover the rest.
  if FUseCustomTitleBar then
    Color := ToolbarColor
  else if FDarkThemeActive then
    Color := clBlack
  else
    Color := clWhite;

  pnlToolbar.Color := ToolbarColor;

  for var Button in FIconButtons do
  begin
    Button.Font.Color := IconColor;
  end;

  for var Separator in FSeparators do
  begin
    Separator.Color := SeparatorColor;
  end;

  FTabStrip.ActiveColor := ActiveTabColor;
  FTabStrip.InactiveColor := ToolbarColor;
  FTabStrip.HoverColor := HoverTabColor;
  FTabStrip.TextColor := IconColor;
  FTabStrip.AccentColor := TabAccentColor;
  FTabStrip.GlyphColor := IconColor;
  FTabStrip.Invalidate;

  ApplyTitleBarColors(ToolbarColor, IconColor, SeparatorColor);

  pnlToc.Color := ToolbarColor;
  pnlToc.Font.Color := IconColor;
  lstToc.Color := ToolbarColor;
  lstToc.Font.Color := IconColor;
  splToc.Color := SeparatorColor;
  splMain.Color := SeparatorColor;

  pnlStatus.Color := ToolbarColor;
  lblPos.Font.Color := IconColor;
  lblWords.Font.Color := IconColor;

  pnlFind.Color := ToolbarColor;
  lblFindCount.Font.Color := IconColor;

  pnlToc.Invalidate;
  lstToc.Invalidate;
  pnlStatus.Invalidate;
end;

procedure TMarkdownPadForm.RebuildSyncAndToc;
begin
  FMapDirty := False;

  const Document = TMarkdown.Parse(mdEditor.Text, TMarkdownDialect.Gfm);
  FSync.Update(Document, mdPreview.DisplayList);

  const Toc = TMarkdownToc.FromDocument(Document);

  FTocEntries := [];
  lstToc.Items.BeginUpdate;
  try
    lstToc.Items.Clear;

    var Stack: TArray<IMarkdownTocEntry> := [];
    for var Index := Toc.EntryCount - 1 downto 0 do
    begin
      Stack := Stack + [Toc.Entries[Index]];
    end;

    while System.Length(Stack) > 0 do
    begin
      const Entry = Stack[High(Stack)];
      SetLength(Stack, System.Length(Stack) - 1);

      FTocEntries := FTocEntries + [Entry];
      lstToc.Items.Add(Format('%s%s', [StringOfChar(' ', 2 * (Entry.Level - 1)), Entry.Caption]));

      for var Index := Entry.ChildCount - 1 downto 0 do
      begin
        Stack := Stack + [Entry.Children[Index]];
      end;
    end;
  finally
    lstToc.Items.EndUpdate;
  end;
end;

procedure TMarkdownPadForm.UpdateActiveTocEntry(const SourceLine: Integer);
begin
  var Best := -1;
  for var Index := 0 to High(FTocEntries) do
  begin
    if FTocEntries[Index].SourceLine - 1 <= SourceLine then
      Best := Index;
  end;

  if Best <> lstToc.ItemIndex then
    lstToc.ItemIndex := Best;
end;

procedure TMarkdownPadForm.UpdateStatusBar;
begin
  const Caret = mdEditor.CaretPosition;
  if Caret = FLastCaret then
    Exit;

  FLastCaret := Caret;

  var Line, Column: Integer;
  ComputeLineColumn(mdEditor.Text, Caret, Line, Column);
  lblPos.Caption := Format(StatusPositionFormat, [Line, Column]);
  lblWords.Caption := Format(StatusWordsFormat, [CountWords(mdEditor.Text)]);
end;

procedure TMarkdownPadForm.UpdateTitle;
begin
  var Name := UntitledName;

  if FActiveDoc <> nil then
  begin
    Name := FActiveDoc.DisplayName;
    if FActiveDoc.Modified then
      Name := Name + ModifiedMarker;
  end;

  Caption := Format(TitleFormat, [WindowCaption, Name]);
end;

procedure TMarkdownPadForm.ExecuteFind;
begin
  const Needle = FFindEdit.Text;
  if Needle = '' then
    Exit;

  mdPreview.FindText(Needle);
end;

procedure TMarkdownPadForm.BuildPalette;
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

procedure TMarkdownPadForm.BuildCommandRegistry;
begin
  FCommands := TPadCommandRegistry.Create;

  RegisterStaticCommands;
end;

procedure TMarkdownPadForm.RegisterStaticCommands;
begin
  FCommands.Register(CmdNewName, CatFile, CmdNewShortcut,
    procedure
    begin
      HandleNewClick(nil);
    end);

  FCommands.Register(CmdOpenName, CatFile, CmdOpenShortcut,
    procedure
    begin
      HandleOpenClick(nil);
    end);

  FCommands.Register(CmdSaveName, CatFile, CmdSaveShortcut,
    procedure
    begin
      HandleSaveClick(nil);
    end);

  FCommands.Register(CmdSaveAsName, CatFile, CmdSaveAsShortcut,
    procedure
    begin
      HandleSaveAsClick(nil);
    end);

  FCommands.Register(CmdCloseName, CatFile, CmdCloseShortcut,
    procedure
    begin
      CloseActiveDocument;
    end);

  FCommands.Register(CmdNextTabName, CatFile, CmdNextTabShortcut,
    procedure
    begin
      FWorkspace.ActivateNext;
      SwitchToDocument(FWorkspace.ActiveIndex);
    end);

  FCommands.Register(CmdExportName, CatFile, CmdExportShortcut,
    procedure
    begin
      DoExportHtml;
    end);

  FCommands.Register(CmdCopyHtmlName, CatFile, CmdCopyHtmlShortcut,
    procedure
    begin
      DoCopyHtml;
    end);

  FCommands.Register(CmdViewEditorName, CatView, CmdViewEditorShortcut,
    procedure
    begin
      SetViewMode(TPadViewMode.EditorOnly);
    end);

  FCommands.Register(CmdViewSplitName, CatView, CmdViewSplitShortcut,
    procedure
    begin
      SetViewMode(TPadViewMode.Split);
    end);

  FCommands.Register(CmdViewPreviewName, CatView, CmdViewPreviewShortcut,
    procedure
    begin
      SetViewMode(TPadViewMode.PreviewOnly);
    end);

  FCommands.Register(CmdZenName, CatView, CmdZenShortcut,
    procedure
    begin
      ToggleZen;
    end);

  FCommands.Register(CmdThemeName, CatView, CmdThemeShortcut,
    procedure
    begin
      HandleThemeClick(nil);
    end);

  FCommands.Register(CmdTocName, CatView, CmdTocShortcut,
    procedure
    begin
      HandleTocClick(nil);
    end);

  FCommands.Register(CmdFindName, CatEdit, CmdFindShortcut,
    procedure
    begin
      ShowFindBar;
    end);

  FCommands.Register(CmdFindPreviewName, CatEdit, CmdFindPreviewShortcut,
    procedure
    begin
      ExecuteFind;
    end);

  FCommands.Register(CmdBoldName, CatFormat, CmdBoldShortcut,
    procedure
    begin
      mdEditor.ExecuteCommand(TEditorCommand.Bold);
      mdEditor.SetFocus;
    end);

  FCommands.Register(CmdItalicName, CatFormat, CmdItalicShortcut,
    procedure
    begin
      mdEditor.ExecuteCommand(TEditorCommand.Italic);
      mdEditor.SetFocus;
    end);

  FCommands.Register(CmdLinkName, CatFormat, CmdLinkShortcut,
    procedure
    begin
      mdEditor.ExecuteCommand(TEditorCommand.Link);
      mdEditor.SetFocus;
    end);

  FCommands.Register(CmdCodeName, CatFormat, CmdCodeShortcut,
    procedure
    begin
      mdEditor.ExecuteCommand(TEditorCommand.CodeBlock);
      mdEditor.SetFocus;
    end);

  FCommands.Register(CmdH1Name, CatFormat, CmdH1Shortcut,
    procedure
    begin
      ExecuteFormatCommand(TEditorCommand.Heading1);
    end);

  FCommands.Register(CmdH2Name, CatFormat, CmdH2Shortcut,
    procedure
    begin
      ExecuteFormatCommand(TEditorCommand.Heading2);
    end);

  FCommands.Register(CmdH3Name, CatFormat, CmdH3Shortcut,
    procedure
    begin
      ExecuteFormatCommand(TEditorCommand.Heading3);
    end);

  FCommands.Register(CmdBulletName, CatFormat, CmdBulletShortcut,
    procedure
    begin
      ExecuteFormatCommand(TEditorCommand.BulletList);
    end);

  FCommands.Register(CmdNumberName, CatFormat, CmdNumberShortcut,
    procedure
    begin
      ExecuteFormatCommand(TEditorCommand.NumberedList);
    end);

  FCommands.Register(CmdQuoteName, CatFormat, CmdQuoteShortcut,
    procedure
    begin
      ExecuteFormatCommand(TEditorCommand.Quote);
    end);

  FCommands.Register(CmdStrikeName, CatFormat, CmdStrikeShortcut,
    procedure
    begin
      ExecuteFormatCommand(TEditorCommand.Strikethrough);
    end);

  FCommands.Register(CmdTableName, CatFormat, CmdTableShortcut,
    procedure
    begin
      ExecuteFormatCommand(TEditorCommand.Table);
    end);
end;

procedure TMarkdownPadForm.SetViewMode(const Mode: TPadViewMode);
begin
  if FZenActive then
    ExitZen;

  if FViewMode = TPadViewMode.Split then
    FSplitEditorWidth := mdEditor.Width;

  FViewMode := Mode;
  ApplyViewMode;
end;

procedure TMarkdownPadForm.ApplyViewMode;
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

procedure TMarkdownPadForm.EnforceTopBarOrder;
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

procedure TMarkdownPadForm.EnforceLeftPaneOrder;
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

procedure TMarkdownPadForm.ShowFindBar;
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

procedure TMarkdownPadForm.CloseFindBar;
begin
  pnlFind.Visible := False;

  EnforceTopBarOrder;

  if mdEditor.CanFocus then
    mdEditor.SetFocus;
end;

procedure TMarkdownPadForm.FindInEditor;
begin
  const Needle = edtEditorFind.Text;
  if Needle = '' then
  begin
    UpdateFindCount;
    Exit;
  end;

  mdEditor.FindNext(Needle);

  UpdateFindCount;
end;

procedure TMarkdownPadForm.UpdateFindCount;
begin
  const Needle = edtEditorFind.Text;
  if Needle = '' then
  begin
    lblFindCount.Caption := EmptyFindCaption;
    Exit;
  end;

  const Total = mdEditor.FindMatchCount(Needle);

  if Total = 0 then
    lblFindCount.Caption := NoMatchCaption
  else if Total = 1 then
    lblFindCount.Caption := SingleMatchCaption
  else
    lblFindCount.Caption := Format(MatchCountFormat, [Total]);
end;

procedure TMarkdownPadForm.HandleEditorFindChange(Sender: TObject);
begin
  UpdateFindCount;
end;

procedure TMarkdownPadForm.ShowPalette;
begin
  FCommands.Clear;
  RegisterStaticCommands;

  for var Path in FSession.RecentFiles do
  begin
    const RecentPath = Path;
    FCommands.Register(RecentPath, CatRecent, RecentShortcut,
      procedure
      begin
        OpenPath(RecentPath);
      end);
  end;

  FPaletteEdit.Text := '';
  RefreshPaletteList;

  FPalette.Left := (ClientWidth - FPalette.Width) div 2;
  FPalette.Top := PaletteTop;
  FPalette.BringToFront;
  FPalette.Visible := True;
  FPaletteEdit.SetFocus;
end;

procedure TMarkdownPadForm.ClosePalette;
begin
  FPalette.Visible := False;

  if mdEditor.CanFocus then
    mdEditor.SetFocus;
end;

procedure TMarkdownPadForm.RefreshPaletteList;
begin
  FPaletteMatches := FCommands.Match(FPaletteEdit.Text);

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

procedure TMarkdownPadForm.HandlePaletteChange(Sender: TObject);
begin
  RefreshPaletteList;

  if FPaletteList.Count > 0 then
    FPaletteList.ItemIndex := 0;
end;

procedure TMarkdownPadForm.HandlePaletteDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
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

procedure TMarkdownPadForm.HandlePaletteDblClick(Sender: TObject);
begin
  ExecuteSelectedCommand;
end;

procedure TMarkdownPadForm.PaletteMoveSelection(const Delta: Integer);
begin
  if FPaletteList.Count = 0 then
    Exit;

  const NewIndex = EnsureRange(FPaletteList.ItemIndex + Delta, 0, FPaletteList.Count - 1);
  FPaletteList.ItemIndex := NewIndex;
end;

procedure TMarkdownPadForm.ExecuteSelectedCommand;
begin
  const Index = FPaletteList.ItemIndex;
  if (Index < 0) or (Index > High(FPaletteMatches)) then
    Exit;

  const Action = FPaletteMatches[Index].Command.Action;

  ClosePalette;

  if Assigned(Action) then
    Action();
end;

procedure TMarkdownPadForm.ToggleZen;
begin
  if FZenActive then
    ExitZen
  else
    EnterZen;
end;

procedure TMarkdownPadForm.EnterZen;
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

procedure TMarkdownPadForm.ExitZen;
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

procedure TMarkdownPadForm.UpdateZenPadding;
begin
  if (FZenLeftPad = nil) or (FZenRightPad = nil) then
    Exit;

  const Pad = Max(0, (ClientWidth - ZenMaxTextWidth) div 2);
  FZenLeftPad.Width := Pad;
  FZenRightPad.Width := Pad;
end;

procedure TMarkdownPadForm.HandleResize(Sender: TObject);
begin
  LayoutTitleBar;

  if FZenActive then
    UpdateZenPadding;

  if FPalette <> nil then
    FPalette.Left := (ClientWidth - FPalette.Width) div 2;
end;

class procedure TMarkdownPadForm.ComputeLineColumn(const Text: string; const Offset: Integer;
  out Line, Column: Integer);
begin
  Line := 1;
  Column := 1;

  const Limit = System.Math.Min(Offset, System.Length(Text));
  for var Index := 1 to Limit do
  begin
    if Text[Index] = #10 then
    begin
      Inc(Line);
      Column := 1;
    end
    else
      Inc(Column);
  end;
end;

class function TMarkdownPadForm.CountWords(const Text: string): Integer;
begin
  Result := 0;
  var InsideWord := False;
  for var Character in Text do
  begin
    if Character.IsWhiteSpace then
      InsideWord := False
    else if not InsideWord then
    begin
      InsideWord := True;
      Inc(Result);
    end;
  end;
end;

class function TMarkdownPadForm.BuildSampleMarkdown: string;
begin
  Result :=
    '# Markdown4D Pad'#10#10 +
    'A native Markdown editor with a **live preview**, a clickable table of contents, ' +
    'and synchronized scrolling. Everything renders directly on the VCL canvas - ' +
    'no embedded browser.'#10#10 +
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
