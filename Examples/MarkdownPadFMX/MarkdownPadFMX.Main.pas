unit MarkdownPadFMX.Main;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.Types,
  System.UITypes,
  FMX.Forms,
  FMX.Types,
  FMX.Graphics,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Layouts,
  FMX.ListBox,
  FMX.Menus,
  FMX.Edit,
  FMX.Objects,
  FMX.Dialogs,
  Markdown4D.Toc,
  Markdown4D.Editor.Model,
  Markdown4D.Editor.Sync,
  Markdown4D.Theme,
  Markdown4D.Fmx.Editor,
  Markdown4D.Fmx.Viewer,
  MarkdownPad.Defines,
  MarkdownPad.Workspace.Interfaces,
  MarkdownPad.EditorView,
  MarkdownPad.Session,
  MarkdownPad.Commands,
  MarkdownPad.TabStrip.Layout,
  MarkdownPad.Fmx.TabStrip,
  MarkdownPad.FileWatcher;

type
  TMarkdownPadFMXForm = class(TForm, IPadEditorView)
  private
    const
      // Shared constants live in MarkdownPad.Defines; only FMX-specific values
      // (window chrome, custom title bar/tooltip, TAlphaColor palette) stay here.
      WindowCaption = 'Markdown4D Pad (FMX)';
      InitialClientWidth = 1180;
      ToolbarHeight = 38;
      TabControlHeight = 32;
      CaptionButtonWidth = 46;
      StatusBarHeight = 26;
      ControlMargin = 6;
      IconGlyphSize = 16;
      TocHeaderHeight = 22;
      SplitterWidth = 6;
      StatusLabelWidth = 150;
      GlyphMinimize = Char($E921);
      GlyphMaximize = Char($E922);
      GlyphRestore = Char($E923);
      GlyphClose = Char($E8BB);
      HintMinimize = 'Minimize';
      HintMaximize = 'Maximize';
      HintCloseWindow = 'Close';
      ToolbarLightColor = TAlphaColor($FFF3F3F3);
      ToolbarDarkColor = TAlphaColor($FF2D2D2D);
      IconLightColor = TAlphaColor($FF404040);
      IconDarkColor = TAlphaColor($FFD6D6D6);
      SeparatorLightColor = TAlphaColor($FFD0D0D0);
      SeparatorDarkColor = TAlphaColor($FF505050);
      HoverLightColor = TAlphaColor($FFE0E0E0);
      HoverDarkColor = TAlphaColor($FF3E3E3E);
      TabActiveLightColor = TAlphaColor($FFFFFFFF);
      TabActiveDarkColor = TAlphaColor($FF3F3F3F);
      TabHoverLightColor = TAlphaColor($FFEAEAEA);
      TabHoverDarkColor = TAlphaColor($FF383838);
      CaptionCloseHoverColor = TAlphaColor($FFE81123);
      HintBackColor = TAlphaColor($FF1E1E1E);
      HintTextColor = TAlphaColor($FFF0F0F0);
      HintHeight = 24;
      HintHorizontalPadding = 8;
      HintGap = 4;
      HintCornerRadius = 4;
      MarkdownExtension = '.md';
      SessionFileName = 'MarkdownPad.Fmx.json';
      OpenErrorFormat = 'Could not open the file:'#10'%s';
      CloseUnsavedPrompt = 'This document has unsaved changes. Save before closing?';
      ReloadPrompt = 'This file changed on disk. Reload and lose your local changes?';
      PaletteListHeight = PaletteRowHeight * PaletteVisibleRows;
      PaletteEditHeight = 30;
      PaletteShortcutWidth = 120;
      PaletteShortcutOpacity = 0.6;
    var
      FToolbar: TRectangle;
      FTitleBar: TRectangle;
      FTabStrip: TPadFmxTabStrip;
      FMinButton: TRectangle;
      FMaxButton: TRectangle;
      FCloseButton: TRectangle;
      FMaxGlyph: TText;
      FCaptionGlyphs: TArray<TText>;
      FFrameInstalled: Boolean;
      FStatusBar: TRectangle;
      FStatusPositionLabel: TLabel;
      FStatusWordsLabel: TLabel;
      FTocPanel: TLayout;
      FTocHeader: TText;
      FTocList: TListBox;
      FTocSplitter: TSplitter;
      FEditor: TMarkdownEditor;
      FMainSplitter: TSplitter;
      FPreview: TMarkdownViewer;
      FNewButton: TRectangle;
      FOpenButton: TRectangle;
      FSaveButton: TRectangle;
      FSaveAsButton: TRectangle;
      FRecentButton: TRectangle;
      FExportButton: TRectangle;
      FCopyHtmlButton: TRectangle;
      FBoldButton: TRectangle;
      FItalicButton: TRectangle;
      FLinkButton: TRectangle;
      FCodeButton: TRectangle;
      FThemeButton: TRectangle;
      FTocButton: TRectangle;
      FFindButton: TRectangle;
      FIconFontName: string;
      FIconButtons: TArray<TRectangle>;
      FIconGlyphs: TArray<TText>;
      FSeparators: TArray<TRectangle>;
      FToolbarFill: TAlphaColor;
      FHoverColor: TAlphaColor;
      FTocFill: TAlphaColor;
      FTocTextColor: TAlphaColor;
      FChromeTextColor: TAlphaColor;
      FFindEdit: TEdit;
      FRecentMenu: TPopupMenu;
      FOpenDialog: TOpenDialog;
      FSaveDialog: TSaveDialog;
      FHtmlSaveDialog: TSaveDialog;
      FTickTimer: TTimer;
      FTocEntries: TArray<IMarkdownTocEntry>;
      FLightTheme: TMarkdownTheme;
      FDarkTheme: TMarkdownTheme;
      FDarkThemeActive: Boolean;
      FWorkspace: IPadWorkspace;
      FSession: TPadSession;
      FWatcher: TPadFileWatcher;
      FActiveDoc: IPadDocument;
      FMapDirty: Boolean;
      FSwapping: Boolean;
      FTocFollowing: Boolean;
      FLastCaret: Integer;
      FFindBar: TRectangle;
      FEditorFindEdit: TEdit;
      FEditorFindCount: TLabel;
      FHintRect: TRectangle;
      FHintText: TText;
      FPalette: TRectangle;
      FPaletteEdit: TEdit;
      FPaletteList: TListBox;
      FCommands: TPadCommandRegistry;
      FPaletteMatches: TArray<TPadCommandMatch>;
      FViewMode: TPadViewMode;
      FSplitEditorWidth: Single;
      FZenActive: Boolean;
      FPreZenViewMode: TPadViewMode;
      FZenLeftPad: TLayout;
      FZenRightPad: TLayout;
      FZenTocWasVisible: Boolean;
      FZenFindWasVisible: Boolean;
    procedure BuildToolbar;
    function ResolveIconFontName: string;
    function AddIconButton(const Glyph: string; const Hint: string; const Handler: TNotifyEvent): TRectangle;
    procedure AddSeparator;
    procedure HandleIconMouseEnter(Sender: TObject);
    procedure HandleIconMouseLeave(Sender: TObject);
    procedure BuildTitleBar;
    function AddCaptionButton(const Glyph: string; const Hint: string;
      const Handler: TNotifyEvent): TRectangle;
    procedure LayoutTitleBar;
    procedure UpdateMaxRestoreGlyph;
    procedure HandleTitleBarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Single);
    procedure HandleTitleBarDblClick(Sender: TObject);
    procedure HandleMinimizeClick(Sender: TObject);
    procedure HandleMaximizeClick(Sender: TObject);
    procedure HandleCloseButtonClick(Sender: TObject);
    procedure HandleCaptionMouseEnter(Sender: TObject);
    procedure HandleCloseMouseEnter(Sender: TObject);
    procedure HandleTabSelect(Sender: TObject; const Index: Integer);
    procedure HandleTabCloseRequest(Sender: TObject; const Index: Integer);
    procedure HandleTabAdd(Sender: TObject);
    procedure HandleTabReorder(Sender: TObject; const FromIndex, ToIndex: Integer);
    procedure BuildStatusBar;
    procedure BuildTocPanel;
    procedure BuildEditorAndPreview;
    procedure BuildTimer;
    procedure BuildFindBar;
    procedure BuildHint;
    procedure ShowHintFor(const Control: TControl);
    procedure HideHint;
    procedure BuildPalette;
    procedure BuildCommandRegistry;
    procedure RegisterStaticCommands;
    procedure RestoreSession;
    function HandleFormKey(const Key: Word; const Shift: TShiftState): Boolean;
    procedure SetViewMode(const Mode: TPadViewMode);
    procedure ApplyViewMode;
    procedure ShowFindBar;
    procedure CloseFindBar;
    procedure FindInEditor;
    procedure UpdateFindCount;
    procedure HandleEditorFindKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure HandleEditorFindChange(Sender: TObject);
    procedure ShowPalette;
    procedure ClosePalette;
    procedure RefreshPaletteList;
    procedure PaletteMoveSelection(const Delta: Integer);
    procedure ExecuteSelectedCommand;
    procedure HandlePaletteChange(Sender: TObject);
    procedure HandlePaletteDblClick(Sender: TObject);
    procedure ToggleZen;
    procedure EnterZen;
    procedure ExitZen;
    procedure UpdateZenPadding;
    procedure HandleNewClick(Sender: TObject);
    procedure HandleOpenClick(Sender: TObject);
    procedure HandleRecentClick(Sender: TObject);
    procedure HandleRecentItemClick(Sender: TObject);
    procedure OpenPath(const FileName: string);
    procedure HandleSaveClick(Sender: TObject);
    procedure HandleSaveAsClick(Sender: TObject);
    function TrySaveActive: Boolean;
    procedure SaveToFile(const FileName: string);
    procedure CloseActiveDocument;
    procedure CloseDocumentAt(const Index: Integer);
    procedure HandleExportClick(Sender: TObject);
    procedure DoExportHtml;
    procedure HandleCopyHtmlClick(Sender: TObject);
    procedure DoCopyHtml;
    procedure HandleBoldClick(Sender: TObject);
    procedure HandleItalicClick(Sender: TObject);
    procedure HandleLinkClick(Sender: TObject);
    procedure HandleCodeClick(Sender: TObject);
    procedure HandleThemeClick(Sender: TObject);
    procedure HandleTocClick(Sender: TObject);
    procedure HandleFindClick(Sender: TObject);
    procedure HandleFindEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure HandleEditorChange(Sender: TObject);
    procedure HandleSyncScroll(Sender: TObject; const SourceLine: Integer);
    procedure HandlePreviewLinkClick(const Sender: TObject; const Url: string);
    procedure HandleTocChange(Sender: TObject);
    procedure HandleTick(Sender: TObject);
    procedure HandleFileChanged(const Document: IPadDocument);
    procedure ReloadDocument(const Document: IPadDocument);
    function GetEditorText: string;
    procedure SetEditorText(const Value: string);
    function GetEditorCaret: Integer;
    procedure SetEditorCaret(const Value: Integer);
    function GetPreviewScrollOffset: Single;
    procedure SetPreviewScrollOffset(const Value: Single);
    function FirstVisibleSourceLine: Integer;
    procedure ScrollToSourceLine(const LineIndex: Integer);
    function SaveEditState: IMarkdownEditorState;
    procedure LoadEditState(const State: IMarkdownEditorState);
    procedure FlushPreview;
    procedure BeginSwap;
    procedure EndSwap;
    procedure SwitchToDocument(const Index: Integer);
    procedure RebuildTabs;
    procedure RebuildSyncAndToc;
    procedure UpdateActiveTocEntry(const SourceLine: Integer);
    procedure UpdateStatusBar;
    procedure UpdateTitle;
    procedure ExecuteFind;
    procedure ApplyTheme;
    procedure ApplyChromeColors;
    procedure ApplyTocItemColors;
    procedure StyleTocBackground;
    procedure HandleTocListApplyStyle(Sender: TObject);
    procedure SaveSession;
    class function BuildSampleMarkdown: string;

  public
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure DoShow; override;
    function CloseQuery: Boolean; override;
    procedure Resize; override;
    procedure DragOver(const Data: TDragObject; const Point: TPointF; var Operation: TDragOperation); override;
    procedure DragDrop(const Data: TDragObject; const Point: TPointF); override;
  end;

var
  MarkdownPadFMXForm: TMarkdownPadFMXForm;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Character,
  System.IOUtils,
  Winapi.Windows,
  Winapi.ShellAPI,
  FMX.DialogService.Sync,
  FMX.Platform,
  MarkdownPad.Fmx.WinFrame,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  MarkdownPad.Text,
  MarkdownPad.Outline,
  MarkdownPad.CommandSet,
  MarkdownPad.SessionSync,
  MarkdownPad.Workspace,
  MarkdownPad.HtmlExport,
  Markdown4D.Extensions.Chart.BlockOverride,
  Markdown4D.Extensions.Mermaid.BlockOverride;

constructor TMarkdownPadFMXForm.Create(Owner: TComponent);
begin
  inherited CreateNew(Owner);

  TChartBlockOverride.RegisterOverride;
  TMermaidBlockOverride.RegisterOverride;

  Caption := WindowCaption;
  ClientWidth := InitialClientWidth;
  ClientHeight := InitialClientHeight;
  Position := TFormPosition.ScreenCenter;
  BorderStyle := TFmxFormBorderStyle.None;

  FLightTheme := TMarkdownTheme.CreateLight;
  FDarkTheme := TMarkdownTheme.CreateDark;

  FWorkspace := TPadWorkspace.Create;
  FWatcher := TPadFileWatcher.Create(FWorkspace, HandleFileChanged);

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := MarkdownFilter;
  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.Filter := MarkdownFilter;
  FSaveDialog.DefaultExt := DefaultExtension;
  FHtmlSaveDialog := TSaveDialog.Create(Self);
  FHtmlSaveDialog.Filter := HtmlFilter;
  FHtmlSaveDialog.DefaultExt := HtmlExtension;

  FIconFontName := ResolveIconFontName;

  BuildTitleBar;
  BuildToolbar;
  BuildFindBar;
  BuildStatusBar;
  BuildTocPanel;
  BuildEditorAndPreview;
  BuildTimer;
  BuildPalette;
  BuildHint;
  BuildCommandRegistry;

  FEditor.AttachPreview(FPreview);
  FEditor.OnSyncScroll := HandleSyncScroll;

  FViewMode := TPadViewMode.Split;
  FSplitEditorWidth := (InitialClientWidth - TocPanelWidth) / 2;

  RestoreSession;

  FMapDirty := True;
end;

destructor TMarkdownPadFMXForm.Destroy;
begin
  if FEditor <> nil then
    FEditor.DetachPreview;

  SaveSession;

  inherited Destroy;

  FWatcher.Free;
  FCommands.Free;
  FSession.Free;
  FDarkTheme.Free;
  FLightTheme.Free;
end;

procedure TMarkdownPadFMXForm.BuildToolbar;
begin
  FToolbar := TRectangle.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.Align := TAlignLayout.Top;
  FToolbar.Height := ToolbarHeight;
  FToolbar.Stroke.Kind := TBrushKind.None;
  FToolbar.Fill.Kind := TBrushKind.Solid;

  FTocButton := AddIconButton(GlyphToc, HintToc, HandleTocClick);
  FThemeButton := AddIconButton(GlyphTheme, HintTheme, HandleThemeClick);

  AddSeparator;

  FCodeButton := AddIconButton(GlyphCode, HintCode, HandleCodeClick);
  FLinkButton := AddIconButton(GlyphLink, HintLink, HandleLinkClick);
  FItalicButton := AddIconButton(GlyphItalic, HintItalic, HandleItalicClick);
  FBoldButton := AddIconButton(GlyphBold, HintBold, HandleBoldClick);

  AddSeparator;

  FCopyHtmlButton := AddIconButton(GlyphCopyHtml, HintCopyHtml, HandleCopyHtmlClick);
  FExportButton := AddIconButton(GlyphExport, HintExport, HandleExportClick);

  AddSeparator;

  FRecentButton := AddIconButton(GlyphRecent, HintRecent, HandleRecentClick);
  FSaveAsButton := AddIconButton(GlyphSaveAs, HintSaveAs, HandleSaveAsClick);
  FSaveButton := AddIconButton(GlyphSave, HintSave, HandleSaveClick);
  FOpenButton := AddIconButton(GlyphOpen, HintOpen, HandleOpenClick);
  FNewButton := AddIconButton(GlyphNew, HintNew, HandleNewClick);

  FFindEdit := TEdit.Create(Self);
  FFindEdit.Parent := FToolbar;
  FFindEdit.Align := TAlignLayout.Right;
  FFindEdit.Margins.Top := ControlMargin;
  FFindEdit.Margins.Right := ControlMargin;
  FFindEdit.Margins.Bottom := ControlMargin;
  FFindEdit.Width := FindEditWidth;
  FFindEdit.TextPrompt := FindButtonCaption;
  FFindEdit.OnKeyDown := HandleFindEditKeyDown;

  FFindButton := AddIconButton(GlyphFind, HintFind, HandleFindClick);
  FFindButton.Align := TAlignLayout.Right;
  FFindButton.Margins.Right := ControlMargin;
end;

function TMarkdownPadFMXForm.ResolveIconFontName: string;
begin
  const DeviceContext = GetDC(0);
  try
    const FontHandle = CreateFont(0, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET,
      OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE,
      PChar(FluentIconFontName));
    const Previous = SelectObject(DeviceContext, FontHandle);
    try
      var FaceName: string;
      SetLength(FaceName, LF_FACESIZE);
      GetTextFace(DeviceContext, LF_FACESIZE, PChar(FaceName));

      const ActualFace = string(PChar(FaceName));

      if SameText(ActualFace, FluentIconFontName) then
        Result := FluentIconFontName
      else
        Result := Mdl2IconFontName;
    finally
      SelectObject(DeviceContext, Previous);
      DeleteObject(FontHandle);
    end;
  finally
    ReleaseDC(0, DeviceContext);
  end;
end;

function TMarkdownPadFMXForm.AddIconButton(const Glyph: string; const Hint: string;
  const Handler: TNotifyEvent): TRectangle;
begin
  const VerticalMargin = (ToolbarHeight - IconButtonSize) / 2;

  Result := TRectangle.Create(Self);
  Result.Parent := FToolbar;
  Result.Align := TAlignLayout.Left;
  Result.Width := IconButtonSize;
  Result.Margins.Left := 2;
  Result.Margins.Top := VerticalMargin;
  Result.Margins.Bottom := VerticalMargin;
  Result.Stroke.Kind := TBrushKind.None;
  Result.Fill.Kind := TBrushKind.Solid;
  Result.HitTest := True;
  Result.Cursor := crHandPoint;
  Result.Hint := Hint;
  // An FMX control ignores its own ShowHint while ParentShowHint is still True.
  Result.ParentShowHint := False;
  Result.ShowHint := True;
  Result.OnClick := Handler;
  Result.OnMouseEnter := HandleIconMouseEnter;
  Result.OnMouseLeave := HandleIconMouseLeave;

  const GlyphText = TText.Create(Result);
  GlyphText.Parent := Result;
  GlyphText.Align := TAlignLayout.Client;
  GlyphText.HitTest := False;
  GlyphText.Font.Family := FIconFontName;
  GlyphText.Font.Size := IconGlyphSize;
  GlyphText.HorzTextAlign := TTextAlign.Center;
  GlyphText.VertTextAlign := TTextAlign.Center;
  GlyphText.Text := Glyph;

  FIconButtons := FIconButtons + [Result];
  FIconGlyphs := FIconGlyphs + [GlyphText];
end;

procedure TMarkdownPadFMXForm.AddSeparator;
begin
  const VerticalMargin = ControlMargin + 2;

  const Separator = TRectangle.Create(Self);
  Separator.Parent := FToolbar;
  Separator.Align := TAlignLayout.Left;
  Separator.Width := SeparatorWidth;
  Separator.Margins.Left := ControlMargin;
  Separator.Margins.Right := ControlMargin;
  Separator.Margins.Top := VerticalMargin;
  Separator.Margins.Bottom := VerticalMargin;
  Separator.Stroke.Kind := TBrushKind.None;
  Separator.Fill.Kind := TBrushKind.Solid;
  Separator.HitTest := False;

  FSeparators := FSeparators + [Separator];
end;

procedure TMarkdownPadFMXForm.HandleIconMouseEnter(Sender: TObject);
begin
  const Button = Sender as TRectangle;
  Button.Fill.Color := FHoverColor;
  ShowHintFor(Button);
end;

procedure TMarkdownPadFMXForm.HandleIconMouseLeave(Sender: TObject);
begin
  const Button = Sender as TRectangle;
  Button.Fill.Color := FToolbarFill;
  HideHint;
end;

procedure TMarkdownPadFMXForm.BuildTitleBar;
begin
  FTitleBar := TRectangle.Create(Self);
  FTitleBar.Parent := Self;
  FTitleBar.Align := TAlignLayout.Top;
  FTitleBar.Height := TitleBarHeight;
  FTitleBar.Stroke.Kind := TBrushKind.None;
  FTitleBar.Fill.Kind := TBrushKind.Solid;
  FTitleBar.HitTest := True;
  FTitleBar.OnMouseDown := HandleTitleBarMouseDown;
  FTitleBar.OnDblClick := HandleTitleBarDblClick;

  // Caption buttons are right-aligned; create close first so it sits furthest right.
  FCloseButton := AddCaptionButton(GlyphClose, HintCloseWindow, HandleCloseButtonClick);
  FCloseButton.OnMouseEnter := HandleCloseMouseEnter;

  FMaxButton := AddCaptionButton(GlyphMaximize, HintMaximize, HandleMaximizeClick);
  FMaxGlyph := FCaptionGlyphs[High(FCaptionGlyphs)];

  FMinButton := AddCaptionButton(GlyphMinimize, HintMinimize, HandleMinimizeClick);

  FTabStrip := TPadFmxTabStrip.Create(Self);
  FTabStrip.Parent := FTitleBar;
  FTabStrip.Align := TAlignLayout.Left;
  FTabStrip.Margins.Left := TitleBarLeftInset;
  FTabStrip.GlyphFontName := FIconFontName;
  FTabStrip.OnSelectTab := HandleTabSelect;
  FTabStrip.OnCloseTab := HandleTabCloseRequest;
  FTabStrip.OnAddTab := HandleTabAdd;
  FTabStrip.OnReorderTab := HandleTabReorder;
end;

function TMarkdownPadFMXForm.AddCaptionButton(const Glyph: string; const Hint: string;
  const Handler: TNotifyEvent): TRectangle;
begin
  Result := TRectangle.Create(Self);
  Result.Parent := FTitleBar;
  Result.Align := TAlignLayout.Right;
  Result.Width := CaptionButtonWidth;
  Result.Stroke.Kind := TBrushKind.None;
  Result.Fill.Kind := TBrushKind.Solid;
  Result.HitTest := True;
  Result.Hint := Hint;
  Result.ParentShowHint := False;
  Result.ShowHint := True;
  Result.OnClick := Handler;
  Result.OnMouseEnter := HandleCaptionMouseEnter;
  Result.OnMouseLeave := HandleIconMouseLeave;

  const GlyphText = TText.Create(Result);
  GlyphText.Parent := Result;
  GlyphText.Align := TAlignLayout.Client;
  GlyphText.HitTest := False;
  GlyphText.Font.Family := FIconFontName;
  GlyphText.Font.Size := 10;
  GlyphText.HorzTextAlign := TTextAlign.Center;
  GlyphText.VertTextAlign := TTextAlign.Center;
  GlyphText.Text := Glyph;

  FCaptionGlyphs := FCaptionGlyphs + [GlyphText];
end;

procedure TMarkdownPadFMXForm.LayoutTitleBar;
begin
  if (FTitleBar = nil) or (FTabStrip = nil) then
    Exit;

  const CaptionButtonsWidth = 3 * CaptionButtonWidth;
  var Available := Round(FTitleBar.Width) - TitleBarLeftInset - CaptionButtonsWidth;
  if Available < TPadTabLayout.MinTabWidth then
    Available := TPadTabLayout.MinTabWidth;

  FTabStrip.AvailableWidth := Available;

  UpdateMaxRestoreGlyph;
end;

procedure TMarkdownPadFMXForm.UpdateMaxRestoreGlyph;
begin
  if FMaxGlyph = nil then
    Exit;

  if WindowState = TWindowState.wsMaximized then
    FMaxGlyph.Text := GlyphRestore
  else
    FMaxGlyph.Text := GlyphMaximize;
end;

procedure TMarkdownPadFMXForm.HandleTitleBarMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  if Button = TMouseButton.mbLeft then
    TFmxWinFrame.BeginDrag;
end;

procedure TMarkdownPadFMXForm.HandleTitleBarDblClick(Sender: TObject);
begin
  HandleMaximizeClick(Sender);
end;

procedure TMarkdownPadFMXForm.HandleMinimizeClick(Sender: TObject);
begin
  WindowState := TWindowState.wsMinimized;
end;

procedure TMarkdownPadFMXForm.HandleMaximizeClick(Sender: TObject);
begin
  if WindowState = TWindowState.wsMaximized then
    WindowState := TWindowState.wsNormal
  else
    WindowState := TWindowState.wsMaximized;

  UpdateMaxRestoreGlyph;
end;

procedure TMarkdownPadFMXForm.HandleCloseButtonClick(Sender: TObject);
begin
  Close;
end;

procedure TMarkdownPadFMXForm.HandleCaptionMouseEnter(Sender: TObject);
begin
  const Button = Sender as TRectangle;
  Button.Fill.Color := FHoverColor;
  ShowHintFor(Button);
end;

procedure TMarkdownPadFMXForm.HandleCloseMouseEnter(Sender: TObject);
begin
  const Button = Sender as TRectangle;
  Button.Fill.Color := CaptionCloseHoverColor;
  ShowHintFor(Button);
end;

procedure TMarkdownPadFMXForm.HandleTabSelect(Sender: TObject; const Index: Integer);
begin
  SwitchToDocument(Index);
end;

procedure TMarkdownPadFMXForm.HandleTabCloseRequest(Sender: TObject; const Index: Integer);
begin
  CloseDocumentAt(Index);
end;

procedure TMarkdownPadFMXForm.HandleTabAdd(Sender: TObject);
begin
  HandleNewClick(nil);
end;

procedure TMarkdownPadFMXForm.HandleTabReorder(Sender: TObject; const FromIndex, ToIndex: Integer);
begin
  FWorkspace.Move(FromIndex, ToIndex);
  RebuildTabs;
end;

procedure TMarkdownPadFMXForm.BuildStatusBar;
begin
  FStatusBar := TRectangle.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.Align := TAlignLayout.Bottom;
  FStatusBar.Height := StatusBarHeight;
  FStatusBar.Stroke.Kind := TBrushKind.None;
  FStatusBar.Fill.Kind := TBrushKind.Solid;

  FStatusPositionLabel := TLabel.Create(Self);
  FStatusPositionLabel.Parent := FStatusBar;
  FStatusPositionLabel.Align := TAlignLayout.Left;
  FStatusPositionLabel.Margins.Left := ControlMargin;
  FStatusPositionLabel.Width := StatusLabelWidth;

  FStatusWordsLabel := TLabel.Create(Self);
  FStatusWordsLabel.Parent := FStatusBar;
  FStatusWordsLabel.Align := TAlignLayout.Left;
  FStatusWordsLabel.Margins.Left := ControlMargin;
  FStatusWordsLabel.Width := StatusLabelWidth;
end;

procedure TMarkdownPadFMXForm.BuildTocPanel;
begin
  FTocPanel := TLayout.Create(Self);
  FTocPanel.Parent := Self;
  FTocPanel.Align := TAlignLayout.Left;
  FTocPanel.Width := TocPanelWidth;

  FTocHeader := TText.Create(Self);
  FTocHeader.Parent := FTocPanel;
  FTocHeader.Align := TAlignLayout.Top;
  FTocHeader.Height := TocHeaderHeight;
  FTocHeader.Margins.Left := ControlMargin;
  FTocHeader.HorzTextAlign := TTextAlign.Leading;
  FTocHeader.Text := TocHeaderCaption;

  FTocList := TListBox.Create(Self);
  FTocList.Parent := FTocPanel;
  FTocList.Align := TAlignLayout.Client;
  FTocList.OnChange := HandleTocChange;
  FTocList.OnApplyStyleLookup := HandleTocListApplyStyle;

  FTocSplitter := TSplitter.Create(Self);
  FTocSplitter.Parent := Self;
  FTocSplitter.Align := TAlignLayout.Left;
  FTocSplitter.Width := SplitterWidth;
end;

procedure TMarkdownPadFMXForm.BuildEditorAndPreview;
begin
  FEditor := TMarkdownEditor.Create(Self);
  FEditor.Parent := Self;
  FEditor.Align := TAlignLayout.Left;
  FEditor.Width := (InitialClientWidth - TocPanelWidth) / 2;
  FEditor.ShowLineNumbers := True;
  FEditor.OnChange := HandleEditorChange;

  FMainSplitter := TSplitter.Create(Self);
  FMainSplitter.Parent := Self;
  FMainSplitter.Align := TAlignLayout.Left;
  FMainSplitter.Width := SplitterWidth;

  FPreview := TMarkdownViewer.Create(Self);
  FPreview.Parent := Self;
  FPreview.Align := TAlignLayout.Client;
  FPreview.OnLinkClick := HandlePreviewLinkClick;
end;

procedure TMarkdownPadFMXForm.BuildTimer;
begin
  FTickTimer := TTimer.Create(Self);
  FTickTimer.Interval := TickIntervalMilliseconds;
  FTickTimer.OnTimer := HandleTick;
  FTickTimer.Enabled := True;
end;

procedure TMarkdownPadFMXForm.BuildFindBar;
begin
  FFindBar := TRectangle.Create(Self);
  FFindBar.Parent := Self;
  FFindBar.Align := TAlignLayout.Top;
  FFindBar.Height := FindBarHeight;
  FFindBar.Visible := False;
  FFindBar.Stroke.Kind := TBrushKind.None;
  FFindBar.Fill.Kind := TBrushKind.Solid;

  FEditorFindEdit := TEdit.Create(Self);
  FEditorFindEdit.Parent := FFindBar;
  FEditorFindEdit.Align := TAlignLayout.Left;
  FEditorFindEdit.Margins.Left := ControlMargin;
  FEditorFindEdit.Margins.Top := ControlMargin;
  FEditorFindEdit.Margins.Bottom := ControlMargin;
  FEditorFindEdit.Width := FindBarEditWidth;
  FEditorFindEdit.TextPrompt := FindHintCaption;
  FEditorFindEdit.OnKeyDown := HandleEditorFindKeyDown;
  FEditorFindEdit.OnChangeTracking := HandleEditorFindChange;

  FEditorFindCount := TLabel.Create(Self);
  FEditorFindCount.Parent := FFindBar;
  FEditorFindCount.Align := TAlignLayout.Right;
  FEditorFindCount.Margins.Right := ControlMargin;
  FEditorFindCount.Width := StatusLabelWidth;
  FEditorFindCount.TextSettings.HorzAlign := TTextAlign.Trailing;
end;

procedure TMarkdownPadFMXForm.BuildHint;
begin
  // FMX does not reliably show native control hints on this window, so draw a
  // small tooltip ourselves on hover.
  FHintRect := TRectangle.Create(Self);
  FHintRect.Parent := Self;
  FHintRect.Visible := False;
  FHintRect.HitTest := False;
  FHintRect.XRadius := HintCornerRadius;
  FHintRect.YRadius := HintCornerRadius;
  FHintRect.Stroke.Kind := TBrushKind.None;
  FHintRect.Fill.Kind := TBrushKind.Solid;
  FHintRect.Fill.Color := HintBackColor;
  FHintRect.Height := HintHeight;

  FHintText := TText.Create(Self);
  FHintText.Parent := FHintRect;
  FHintText.Align := TAlignLayout.Client;
  FHintText.HitTest := False;
  FHintText.Margins.Left := HintHorizontalPadding;
  FHintText.Margins.Right := HintHorizontalPadding;
  FHintText.HorzTextAlign := TTextAlign.Center;
  FHintText.VertTextAlign := TTextAlign.Center;
  FHintText.Color := HintTextColor;
end;

procedure TMarkdownPadFMXForm.ShowHintFor(const Control: TControl);
begin
  if (FHintRect = nil) or (Control = nil) or (Control.Hint = '') then
    Exit;

  FHintText.Text := Control.Hint;

  const MeasureCanvas = TCanvasManager.MeasureCanvas;
  MeasureCanvas.Font.Assign(FHintText.Font);
  const TextWidth = MeasureCanvas.TextWidth(Control.Hint);
  FHintRect.Width := TextWidth + 2 * HintHorizontalPadding;

  // Position just below the hovered control, in form coordinates, clamped to the
  // right edge so long hints never run off-screen.
  const Anchor = Control.LocalToAbsolute(TPointF.Create(0, Control.Height + HintGap));
  var Left := Anchor.X;
  if Left + FHintRect.Width > ClientWidth - HintGap then
    Left := ClientWidth - HintGap - FHintRect.Width;
  if Left < HintGap then
    Left := HintGap;

  FHintRect.Position.X := Left;
  FHintRect.Position.Y := Anchor.Y;
  FHintRect.BringToFront;
  FHintRect.Visible := True;
end;

procedure TMarkdownPadFMXForm.HideHint;
begin
  if FHintRect <> nil then
    FHintRect.Visible := False;
end;

procedure TMarkdownPadFMXForm.BuildPalette;
begin
  FPalette := TRectangle.Create(Self);
  FPalette.Parent := Self;
  FPalette.Visible := False;
  FPalette.Width := PaletteWidth;
  FPalette.Height := PaletteEditHeight + PaletteListHeight;
  FPalette.Position.Y := PaletteTop;

  FPaletteEdit := TEdit.Create(Self);
  FPaletteEdit.Parent := FPalette;
  FPaletteEdit.Align := TAlignLayout.Top;
  FPaletteEdit.Height := PaletteEditHeight;
  FPaletteEdit.TextPrompt := PaletteHintCaption;
  FPaletteEdit.OnChangeTracking := HandlePaletteChange;

  FPaletteList := TListBox.Create(Self);
  FPaletteList.Parent := FPalette;
  FPaletteList.Align := TAlignLayout.Client;
  FPaletteList.OnDblClick := HandlePaletteDblClick;
end;

procedure TMarkdownPadFMXForm.BuildCommandRegistry;
begin
  FCommands := TPadCommandRegistry.Create;

  RegisterStaticCommands;
end;

procedure TMarkdownPadFMXForm.RegisterStaticCommands;
var
  Actions: TPadCommandActions;
begin
  Actions.NewDocument := procedure begin HandleNewClick(nil); end;
  Actions.OpenDocument := procedure begin HandleOpenClick(nil); end;
  Actions.Save := procedure begin HandleSaveClick(nil); end;
  Actions.SaveAs := procedure begin HandleSaveAsClick(nil); end;
  Actions.CloseDocument := procedure begin CloseActiveDocument; end;
  Actions.NextTab :=
    procedure
    begin
      FWorkspace.ActivateNext;
      SwitchToDocument(FWorkspace.ActiveIndex);
    end;
  Actions.ExportHtml := procedure begin DoExportHtml; end;
  Actions.CopyHtml := procedure begin DoCopyHtml; end;
  Actions.ViewEditorOnly := procedure begin SetViewMode(TPadViewMode.EditorOnly); end;
  Actions.ViewSplit := procedure begin SetViewMode(TPadViewMode.Split); end;
  Actions.ViewPreviewOnly := procedure begin SetViewMode(TPadViewMode.PreviewOnly); end;
  Actions.ToggleZen := procedure begin ToggleZen; end;
  Actions.ToggleTheme := procedure begin HandleThemeClick(nil); end;
  Actions.ToggleToc := procedure begin HandleTocClick(nil); end;
  Actions.ShowFind := procedure begin ShowFindBar; end;
  Actions.FindInPreview := procedure begin ExecuteFind; end;
  Actions.ExecuteFormat :=
    procedure(const Command: TEditorCommand)
    begin
      FEditor.ExecuteCommand(Command);
      FEditor.SetFocus;
    end;

  RegisterStaticPadCommands(FCommands, Actions);
end;

procedure TMarkdownPadFMXForm.RestoreSession;
begin
  FSession := TPadSession.Create(TPadSession.ResolvePath(SessionFileName));
  FSession.Load;

  FDarkThemeActive := FSession.DarkTheme;
  ApplyTheme;

  FViewMode := FSession.ViewMode;
  ApplyViewMode;

  if not TPadSessionSync.RestoreOpenFiles(FWorkspace, FSession) then
  begin
    const Document = FWorkspace.NewDocument;
    Document.Text := BuildSampleMarkdown;
  end;

  RebuildTabs;
  SwitchToDocument(FWorkspace.ActiveIndex);
end;

procedure TMarkdownPadFMXForm.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if HandleFormKey(Key, Shift) then
  begin
    Key := 0;
    KeyChar := #0;
    Exit;
  end;

  inherited KeyDown(Key, KeyChar, Shift);
end;

function TMarkdownPadFMXForm.HandleFormKey(const Key: Word; const Shift: TShiftState): Boolean;
begin
  Result := True;

  if FPalette.Visible then
  begin
    case Key of
      vkUp:
        PaletteMoveSelection(-1);
      vkDown:
        PaletteMoveSelection(1);
      vkReturn:
        ExecuteSelectedCommand;
      vkEscape:
        ClosePalette;
    else
      Result := ssCtrl in Shift;
    end;

    Exit;
  end;

  if ssCtrl in Shift then
  begin
    if ssShift in Shift then
    begin
      case Key of
        vk1:
          begin
            FEditor.ExecuteCommand(TEditorCommand.Heading1);
            FEditor.SetFocus;
          end;
        vk2:
          begin
            FEditor.ExecuteCommand(TEditorCommand.Heading2);
            FEditor.SetFocus;
          end;
        vk3:
          begin
            FEditor.ExecuteCommand(TEditorCommand.Heading3);
            FEditor.SetFocus;
          end;
        vkU:
          begin
            FEditor.ExecuteCommand(TEditorCommand.BulletList);
            FEditor.SetFocus;
          end;
        vkO:
          begin
            FEditor.ExecuteCommand(TEditorCommand.NumberedList);
            FEditor.SetFocus;
          end;
        vkQ:
          begin
            FEditor.ExecuteCommand(TEditorCommand.Quote);
            FEditor.SetFocus;
          end;
        vkX:
          begin
            FEditor.ExecuteCommand(TEditorCommand.Strikethrough);
            FEditor.SetFocus;
          end;
        vkT:
          begin
            FEditor.ExecuteCommand(TEditorCommand.Table);
            FEditor.SetFocus;
          end;
        vkE:
          DoExportHtml;
        vkC:
          DoCopyHtml;
        vkS:
          HandleSaveAsClick(nil);
        vkTab:
          begin
            FWorkspace.ActivatePrevious;
            SwitchToDocument(FWorkspace.ActiveIndex);
          end;
      else
        Result := False;
      end;

      Exit;
    end;

    case Key of
      vk1:
        SetViewMode(TPadViewMode.EditorOnly);
      vk2:
        SetViewMode(TPadViewMode.Split);
      vk3:
        SetViewMode(TPadViewMode.PreviewOnly);
      vkF:
        ShowFindBar;
      vkK:
        ShowPalette;
      vkN:
        HandleNewClick(nil);
      vkO:
        HandleOpenClick(nil);
      vkS:
        HandleSaveClick(nil);
      vkW:
        CloseActiveDocument;
      vkTab:
        begin
          FWorkspace.ActivateNext;
          SwitchToDocument(FWorkspace.ActiveIndex);
        end;
    else
      Result := False;
    end;

    Exit;
  end;

  case Key of
    vkF11:
      ToggleZen;
    vkF3:
      if FFindBar.Visible then
        FindInEditor
      else
        Result := False;
    vkEscape:
      if FFindBar.Visible then
        CloseFindBar
      else if FZenActive then
        ExitZen
      else
        Result := False;
  else
    Result := False;
  end;
end;

procedure TMarkdownPadFMXForm.DoShow;
begin
  inherited DoShow;

  if not FFrameInstalled then
    FFrameInstalled := TFmxWinFrame.Install(Self);

  ApplyTheme;
  LayoutTitleBar;
end;

function TMarkdownPadFMXForm.CloseQuery: Boolean;
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
    const Answer = TDialogServiceSync.MessageDialog(Prompt, TMsgDlgType.mtConfirmation,
      [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo, TMsgDlgBtn.mbCancel], TMsgDlgBtn.mbCancel, 0);

    if Answer = mrCancel then
      Exit(False);

    if (Answer = mrYes) and not TrySaveActive then
      Exit(False);

    Document.Modified := False;
  end;

  Result := True;
end;

procedure TMarkdownPadFMXForm.Resize;
begin
  inherited Resize;

  LayoutTitleBar;

  if FZenActive then
    UpdateZenPadding;

  if (FPalette <> nil) and FPalette.Visible then
    FPalette.Position.X := (ClientWidth - FPalette.Width) / 2;
end;

procedure TMarkdownPadFMXForm.SetViewMode(const Mode: TPadViewMode);
begin
  if FZenActive then
    ExitZen;

  if FViewMode = TPadViewMode.Split then
    FSplitEditorWidth := FEditor.Width;

  FViewMode := Mode;

  ApplyViewMode;
end;

procedure TMarkdownPadFMXForm.ApplyViewMode;
begin
  case FViewMode of
    TPadViewMode.Split:
      begin
        FEditor.Visible := True;
        FEditor.Align := TAlignLayout.Left;
        FEditor.Width := FSplitEditorWidth;
        FMainSplitter.Visible := True;
        FPreview.Visible := True;
      end;
    TPadViewMode.EditorOnly:
      begin
        FMainSplitter.Visible := False;
        FPreview.Visible := False;
        FEditor.Visible := True;
        FEditor.Align := TAlignLayout.Client;
      end;
    TPadViewMode.PreviewOnly:
      begin
        FEditor.Visible := False;
        FMainSplitter.Visible := False;
        FPreview.Visible := True;
      end;
  end;
end;

procedure TMarkdownPadFMXForm.ShowFindBar;
begin
  FFindBar.Visible := True;

  const Sel = FEditor.SelectedText;
  if Sel <> '' then
    FEditorFindEdit.Text := Sel;

  FEditorFindEdit.SetFocus;
  FEditorFindEdit.SelectAll;

  UpdateFindCount;
end;

procedure TMarkdownPadFMXForm.CloseFindBar;
begin
  FFindBar.Visible := False;

  FEditor.SetFocus;
end;

procedure TMarkdownPadFMXForm.FindInEditor;
begin
  const Needle = FEditorFindEdit.Text;
  if Needle = '' then
  begin
    UpdateFindCount;
    Exit;
  end;

  FEditor.FindNext(Needle);

  UpdateFindCount;
end;

procedure TMarkdownPadFMXForm.UpdateFindCount;
begin
  const Needle = FEditorFindEdit.Text;
  if Needle = '' then
  begin
    FEditorFindCount.Text := EmptyFindCaption;
    Exit;
  end;

  const N = FEditor.FindMatchCount(Needle);

  if N = 0 then
    FEditorFindCount.Text := NoMatchCaption
  else if N = 1 then
    FEditorFindCount.Text := SingleMatchCaption
  else
    FEditorFindCount.Text := Format(MatchCountFormat, [N]);
end;

procedure TMarkdownPadFMXForm.HandleEditorFindKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  case Key of
    vkReturn:
      FindInEditor;
    vkF3:
      FindInEditor;
    vkEscape:
      CloseFindBar;
  else
    Exit;
  end;

  Key := 0;
  KeyChar := #0;
end;

procedure TMarkdownPadFMXForm.HandleEditorFindChange(Sender: TObject);
begin
  UpdateFindCount;
end;

procedure TMarkdownPadFMXForm.ShowPalette;
begin
  FCommands.Clear;
  RegisterStaticCommands;

  for var FileName in FSession.RecentFiles do
  begin
    const Path = FileName;
    FCommands.Register(Path, CatRecent, '',
      procedure
      begin
        OpenPath(Path);
      end);
  end;

  FPaletteEdit.Text := '';

  RefreshPaletteList;

  FPalette.Position.X := (ClientWidth - FPalette.Width) / 2;
  FPalette.Position.Y := PaletteTop;
  FPalette.BringToFront;
  FPalette.Visible := True;

  FPaletteEdit.SetFocus;
end;

procedure TMarkdownPadFMXForm.ClosePalette;
begin
  FPalette.Visible := False;

  FEditor.SetFocus;
end;

procedure TMarkdownPadFMXForm.RefreshPaletteList;
begin
  FPaletteMatches := FCommands.Match(FPaletteEdit.Text);

  FPaletteList.BeginUpdate;
  try
    FPaletteList.Clear;

    for var Index := 0 to High(FPaletteMatches) do
    begin
      const Command = FPaletteMatches[Index].Command;

      var Item := TListBoxItem.Create(FPaletteList);
      Item.Parent := FPaletteList;
      Item.Text := Command.Name;
      Item.Height := PaletteRowHeight;

      if Command.ShortcutText <> '' then
      begin
        var ShortcutLabel := TLabel.Create(Item);
        ShortcutLabel.Parent := Item;
        ShortcutLabel.Align := TAlignLayout.Right;
        ShortcutLabel.Width := PaletteShortcutWidth;
        ShortcutLabel.Margins.Right := ControlMargin;
        ShortcutLabel.Text := Command.ShortcutText;
        ShortcutLabel.Opacity := PaletteShortcutOpacity;
        ShortcutLabel.HitTest := False;
        ShortcutLabel.TextSettings.HorzAlign := TTextAlign.Trailing;
      end;
    end;
  finally
    FPaletteList.EndUpdate;
  end;

  if FPaletteList.Count > 0 then
    FPaletteList.ItemIndex := 0
  else
    FPaletteList.ItemIndex := -1;
end;

procedure TMarkdownPadFMXForm.HandlePaletteDblClick(Sender: TObject);
begin
  ExecuteSelectedCommand;
end;

procedure TMarkdownPadFMXForm.PaletteMoveSelection(const Delta: Integer);
begin
  if FPaletteList.Count = 0 then
    Exit;

  const NewIndex = EnsureRange(FPaletteList.ItemIndex + Delta, 0, FPaletteList.Count - 1);
  FPaletteList.ItemIndex := NewIndex;
end;

procedure TMarkdownPadFMXForm.ExecuteSelectedCommand;
begin
  const Index = FPaletteList.ItemIndex;
  if (Index < 0) or (Index > High(FPaletteMatches)) then
    Exit;

  const Action = FPaletteMatches[Index].Command.Action;

  ClosePalette;

  if Assigned(Action) then
    Action();
end;

procedure TMarkdownPadFMXForm.HandlePaletteChange(Sender: TObject);
begin
  RefreshPaletteList;

  if FPaletteList.Count > 0 then
    FPaletteList.ItemIndex := 0;
end;

procedure TMarkdownPadFMXForm.ToggleZen;
begin
  if FZenActive then
    ExitZen
  else
    EnterZen;
end;

procedure TMarkdownPadFMXForm.EnterZen;
begin
  if FPalette.Visible then
    ClosePalette;

  FZenFindWasVisible := FFindBar.Visible;
  FZenTocWasVisible := FTocPanel.Visible;
  FPreZenViewMode := FViewMode;

  FToolbar.Visible := False;
  FTabStrip.Visible := False;
  FTocPanel.Visible := False;
  FTocSplitter.Visible := False;
  FStatusBar.Visible := False;
  FFindBar.Visible := False;

  // Keep the current view mode so zen mirrors what the user is doing: preview-only
  // becomes a distraction-free rendering, editor-only a distraction-free editor.
  // Split has no single column to center, so it collapses to editor-only.
  if FViewMode = TPadViewMode.Split then
  begin
    FSplitEditorWidth := FEditor.Width;
    FViewMode := TPadViewMode.EditorOnly;
  end;
  ApplyViewMode;

  FZenLeftPad := TLayout.Create(Self);
  FZenLeftPad.Parent := Self;
  FZenLeftPad.Align := TAlignLayout.Left;

  FZenRightPad := TLayout.Create(Self);
  FZenRightPad.Parent := Self;
  FZenRightPad.Align := TAlignLayout.Right;

  UpdateZenPadding;

  FZenActive := True;
  FEditor.SetFocus;
end;

procedure TMarkdownPadFMXForm.ExitZen;
begin
  FreeAndNil(FZenLeftPad);
  FreeAndNil(FZenRightPad);

  FToolbar.Visible := True;
  FTabStrip.Visible := True;
  FStatusBar.Visible := True;
  FTocPanel.Visible := FZenTocWasVisible;
  FTocSplitter.Visible := FZenTocWasVisible;
  FFindBar.Visible := FZenFindWasVisible;

  FViewMode := FPreZenViewMode;
  ApplyViewMode;

  FZenActive := False;
  FEditor.SetFocus;
end;

procedure TMarkdownPadFMXForm.UpdateZenPadding;
begin
  const Pad = Max(0, (ClientWidth - ZenMaxTextWidth) div 2);

  FZenLeftPad.Width := Pad;
  FZenRightPad.Width := Pad;
end;

procedure TMarkdownPadFMXForm.DragOver(const Data: TDragObject; const Point: TPointF;
  var Operation: TDragOperation);
begin
  inherited DragOver(Data, Point, Operation);

  if Length(Data.Files) > 0 then
    Operation := TDragOperation.Copy;
end;

procedure TMarkdownPadFMXForm.DragDrop(const Data: TDragObject; const Point: TPointF);
begin
  inherited DragDrop(Data, Point);

  for var FileName in Data.Files do
  begin
    if SameText(TPath.GetExtension(FileName), MarkdownExtension) then
      OpenPath(FileName);
  end;
end;

procedure TMarkdownPadFMXForm.HandleNewClick(Sender: TObject);
begin
  FWorkspace.NewDocument;

  RebuildTabs;
  SwitchToDocument(FWorkspace.ActiveIndex);
end;

procedure TMarkdownPadFMXForm.HandleOpenClick(Sender: TObject);
begin
  if FOpenDialog.Execute then
    OpenPath(FOpenDialog.FileName);
end;

procedure TMarkdownPadFMXForm.HandleRecentClick(Sender: TObject);
begin
  FRecentMenu.Free;
  FRecentMenu := TPopupMenu.Create(Self);

  const Files = FSession.RecentFiles;
  if Length(Files) = 0 then
  begin
    var EmptyItem := TMenuItem.Create(FRecentMenu);
    EmptyItem.Parent := FRecentMenu;
    EmptyItem.Text := RecentNoneCaption;
    EmptyItem.Enabled := False;
  end
  else
  begin
    for var FileName in Files do
    begin
      var Item := TMenuItem.Create(FRecentMenu);
      Item.Parent := FRecentMenu;
      Item.Text := FileName;
      Item.TagString := FileName;
      Item.OnClick := HandleRecentItemClick;
    end;
  end;

  const ScreenPos = FRecentButton.LocalToScreen(TPointF.Create(0, FRecentButton.Height));
  FRecentMenu.Popup(ScreenPos.X, ScreenPos.Y);
end;

procedure TMarkdownPadFMXForm.HandleRecentItemClick(Sender: TObject);
begin
  const Item = Sender as TMenuItem;
  OpenPath(Item.TagString);
end;

procedure TMarkdownPadFMXForm.OpenPath(const FileName: string);
begin
  if not TFile.Exists(FileName) then
    Exit;

  var Document: IPadDocument;
  try
    Document := FWorkspace.OpenFile(FileName);
  except
    on E: Exception do
    begin
      TDialogServiceSync.MessageDialog(Format(OpenErrorFormat, [FileName]), TMsgDlgType.mtError,
        [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
      Exit;
    end;
  end;

  FSession.AddRecentFile(FileName);
  FWatcher.Reset(Document);

  RebuildTabs;
  SwitchToDocument(FWorkspace.ActiveIndex);
end;

procedure TMarkdownPadFMXForm.HandleSaveClick(Sender: TObject);
begin
  TrySaveActive;
end;

procedure TMarkdownPadFMXForm.HandleSaveAsClick(Sender: TObject);
begin
  if FActiveDoc = nil then
    Exit;

  if not FActiveDoc.IsUntitled then
    FSaveDialog.FileName := FActiveDoc.FileName;

  if FSaveDialog.Execute then
    SaveToFile(FSaveDialog.FileName);
end;

function TMarkdownPadFMXForm.TrySaveActive: Boolean;
begin
  if FActiveDoc = nil then
    Exit(True);

  if FActiveDoc.IsUntitled then
  begin
    if not FSaveDialog.Execute then
      Exit(False);

    SaveToFile(FSaveDialog.FileName);
  end
  else
    SaveToFile(FActiveDoc.FileName);

  Result := True;
end;

procedure TMarkdownPadFMXForm.SaveToFile(const FileName: string);
begin
  FActiveDoc.Text := FEditor.Text;

  TFile.WriteAllText(FileName, FEditor.Text);

  FActiveDoc.FileName := FileName;
  FActiveDoc.Modified := False;
  FWatcher.Reset(FActiveDoc);

  FSession.AddRecentFile(FileName);

  RebuildTabs;
  UpdateTitle;
end;

procedure TMarkdownPadFMXForm.CloseActiveDocument;
begin
  CloseDocumentAt(FWorkspace.ActiveIndex);
end;

procedure TMarkdownPadFMXForm.CloseDocumentAt(const Index: Integer);
begin
  if (Index < 0) or (Index >= FWorkspace.Count) then
    Exit;

  if Index <> FWorkspace.ActiveIndex then
    SwitchToDocument(Index);

  if FActiveDoc = nil then
    Exit;

  if FActiveDoc.Modified then
  begin
    const Answer = TDialogServiceSync.MessageDialog(CloseUnsavedPrompt, TMsgDlgType.mtConfirmation,
      [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo, TMsgDlgBtn.mbCancel], TMsgDlgBtn.mbCancel, 0);

    if Answer = mrCancel then
      Exit;

    if (Answer = mrYes) and not TrySaveActive then
      Exit;
  end;

  const ClosingIndex = FWorkspace.ActiveIndex;
  FActiveDoc := nil;
  FWorkspace.CloseDocument(ClosingIndex);

  if FWorkspace.Count = 0 then
  begin
    Close;
    Exit;
  end;

  RebuildTabs;
  SwitchToDocument(FWorkspace.ActiveIndex);
end;

procedure TMarkdownPadFMXForm.HandleExportClick(Sender: TObject);
begin
  DoExportHtml;
end;

procedure TMarkdownPadFMXForm.DoExportHtml;
begin
  if FActiveDoc <> nil then
    FActiveDoc.Text := FEditor.Text;

  var Title := UntitledName;
  if FActiveDoc <> nil then
    Title := FActiveDoc.DisplayName;

  FHtmlSaveDialog.FileName := TPath.ChangeExtension(Title, '.' + HtmlExtension);

  if not FHtmlSaveDialog.Execute then
    Exit;

  const Html = TMarkdownHtmlExport.BuildDocument(FEditor.Text, Title, FDarkThemeActive);

  TFile.WriteAllText(FHtmlSaveDialog.FileName, Html, TEncoding.UTF8);
end;

procedure TMarkdownPadFMXForm.HandleCopyHtmlClick(Sender: TObject);
begin
  DoCopyHtml;
end;

procedure TMarkdownPadFMXForm.DoCopyHtml;
begin
  const Fragment = TMarkdown.ToHtml(FEditor.Text, TMarkdownDialect.Gfm);

  var Clip: IFMXClipboardService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clip) then
    Clip.SetClipboard(Fragment);
end;

procedure TMarkdownPadFMXForm.HandleBoldClick(Sender: TObject);
begin
  FEditor.ExecuteCommand(TEditorCommand.Bold);
  FEditor.SetFocus;
end;

procedure TMarkdownPadFMXForm.HandleItalicClick(Sender: TObject);
begin
  FEditor.ExecuteCommand(TEditorCommand.Italic);
  FEditor.SetFocus;
end;

procedure TMarkdownPadFMXForm.HandleLinkClick(Sender: TObject);
begin
  FEditor.ExecuteCommand(TEditorCommand.Link);
  FEditor.SetFocus;
end;

procedure TMarkdownPadFMXForm.HandleCodeClick(Sender: TObject);
begin
  FEditor.ExecuteCommand(TEditorCommand.CodeBlock);
  FEditor.SetFocus;
end;

procedure TMarkdownPadFMXForm.HandleThemeClick(Sender: TObject);
begin
  FDarkThemeActive := not FDarkThemeActive;
  ApplyTheme;
end;

procedure TMarkdownPadFMXForm.HandleTocClick(Sender: TObject);
begin
  const ShowToc = not FTocPanel.Visible;
  FTocPanel.Visible := ShowToc;
  FTocSplitter.Visible := ShowToc;
end;

procedure TMarkdownPadFMXForm.HandleFindClick(Sender: TObject);
begin
  ExecuteFind;
end;

procedure TMarkdownPadFMXForm.HandleFindEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  if Key <> vkReturn then
    Exit;

  Key := 0;
  KeyChar := #0;
  ExecuteFind;
end;

procedure TMarkdownPadFMXForm.HandleEditorChange(Sender: TObject);
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

procedure TMarkdownPadFMXForm.HandleSyncScroll(Sender: TObject; const SourceLine: Integer);
begin
  // The editor keeps the two panes in step itself; we only reflect the position
  // in the contents outline. Suppressed while the outline drives the scroll.
  if FTocFollowing then
    Exit;

  UpdateActiveTocEntry(SourceLine);
end;

procedure TMarkdownPadFMXForm.HandlePreviewLinkClick(const Sender: TObject; const Url: string);
begin
  ShellExecute(0, nil, PChar(Url), nil, nil, SW_SHOWNORMAL);
end;

procedure TMarkdownPadFMXForm.HandleTocChange(Sender: TObject);
begin
  if FTocFollowing then
    Exit;

  const Index = FTocList.ItemIndex;
  if (Index < 0) or (Index > High(FTocEntries)) then
    Exit;

  if FMapDirty then
    RebuildSyncAndToc;

  if (Index < 0) or (Index > High(FTocEntries)) then
    Exit;

  const SourceLine = FTocEntries[Index].SourceLine - 1;

  // Scrolling the editor drives the preview through the linked SyncScroll; guard
  // the outline so the resulting sync callback does not fight the selection.
  FTocFollowing := True;
  try
    FEditor.CaretPosition := FEditor.SourceLineStartOffset(SourceLine);
    FEditor.ScrollToSourceLine(SourceLine);
    FTocList.ItemIndex := Index;
  finally
    FTocFollowing := False;
  end;

  FEditor.SetFocus;
end;

procedure TMarkdownPadFMXForm.HandleTick(Sender: TObject);
begin
  if FMapDirty then
    RebuildSyncAndToc;

  UpdateStatusBar;

  FWatcher.Poll;
end;

procedure TMarkdownPadFMXForm.HandleFileChanged(const Document: IPadDocument);
begin
  if Document.Modified then
  begin
    const Answer = TDialogServiceSync.MessageDialog(ReloadPrompt, TMsgDlgType.mtConfirmation,
      [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0);

    if Answer <> mrYes then
      Exit;
  end;

  ReloadDocument(Document);
end;

procedure TMarkdownPadFMXForm.ReloadDocument(const Document: IPadDocument);
begin
  var NewText: string;
  try
    NewText := TFile.ReadAllText(Document.FileName);
  except
    on E: Exception do
    begin
      Document.DiskTimestampUtc := 0;
      Exit;
    end;
  end;

  Document.Text := NewText;
  Document.Modified := False;

  if Document = FActiveDoc then
  begin
    FSwapping := True;
    try
      FEditor.Text := NewText;
      FEditor.FlushPreview;
    finally
      FSwapping := False;
    end;

    FMapDirty := True;
  end;

  RebuildTabs;
  UpdateTitle;
end;

function TMarkdownPadFMXForm.GetEditorText: string;
begin
  Result := FEditor.Text;
end;

procedure TMarkdownPadFMXForm.SetEditorText(const Value: string);
begin
  FEditor.Text := Value;
end;

function TMarkdownPadFMXForm.GetEditorCaret: Integer;
begin
  Result := FEditor.CaretPosition;
end;

procedure TMarkdownPadFMXForm.SetEditorCaret(const Value: Integer);
begin
  FEditor.CaretPosition := Value;
end;

function TMarkdownPadFMXForm.GetPreviewScrollOffset: Single;
begin
  Result := FPreview.ScrollOffset;
end;

procedure TMarkdownPadFMXForm.SetPreviewScrollOffset(const Value: Single);
begin
  FPreview.ScrollOffset := Value;
end;

function TMarkdownPadFMXForm.FirstVisibleSourceLine: Integer;
begin
  Result := FEditor.FirstVisibleSourceLine;
end;

procedure TMarkdownPadFMXForm.ScrollToSourceLine(const LineIndex: Integer);
begin
  FEditor.ScrollToSourceLine(LineIndex);
end;

function TMarkdownPadFMXForm.SaveEditState: IMarkdownEditorState;
begin
  Result := FEditor.SaveEditState;
end;

procedure TMarkdownPadFMXForm.LoadEditState(const State: IMarkdownEditorState);
begin
  FEditor.LoadEditState(State);
end;

procedure TMarkdownPadFMXForm.FlushPreview;
begin
  FEditor.FlushPreview;
end;

procedure TMarkdownPadFMXForm.BeginSwap;
begin
  FSwapping := True;
end;

procedure TMarkdownPadFMXForm.EndSwap;
begin
  FSwapping := False;
end;

procedure TMarkdownPadFMXForm.SwitchToDocument(const Index: Integer);
begin
  if FSwapping then
    Exit;

  FActiveDoc := TPadDocumentSwitch.Execute(FWorkspace, Self, FActiveDoc, Index);

  if FActiveDoc = nil then
    Exit;

  FLastCaret := -1;
  FMapDirty := True;

  RebuildTabs;
  UpdateTitle;
end;

procedure TMarkdownPadFMXForm.RebuildTabs;
begin
  var Captions: TArray<string>;
  var Modified: TArray<Boolean>;
  TPadSessionSync.CollectTabs(FWorkspace, Captions, Modified);

  FTabStrip.SetTabs(Captions, Modified, FWorkspace.ActiveIndex);
end;

procedure TMarkdownPadFMXForm.RebuildSyncAndToc;
begin
  FMapDirty := False;

  const Document = TMarkdown.Parse(FEditor.Text, TMarkdownDialect.Gfm);

  const Outline = TPadOutlineBuilder.Build(TMarkdownToc.FromDocument(Document));
  FTocEntries := Outline.Entries;

  FTocFollowing := True;
  FTocList.Items.BeginUpdate;
  try
    FTocList.Items.Clear;

    for var Caption in Outline.Captions do
      FTocList.Items.Add(Caption);
  finally
    FTocList.Items.EndUpdate;
    FTocFollowing := False;
  end;

  ApplyTocItemColors;
end;

procedure TMarkdownPadFMXForm.UpdateActiveTocEntry(const SourceLine: Integer);
begin
  const Best = TPadOutlineBuilder.ActiveIndex(FTocEntries, SourceLine);

  if Best = FTocList.ItemIndex then
    Exit;

  FTocFollowing := True;
  try
    FTocList.ItemIndex := Best;
  finally
    FTocFollowing := False;
  end;
end;

procedure TMarkdownPadFMXForm.UpdateStatusBar;
begin
  const Caret = FEditor.CaretPosition;
  if Caret = FLastCaret then
    Exit;

  FLastCaret := Caret;

  var Line, Column: Integer;
  TPadText.ComputeLineColumn(FEditor.Text, Caret, Line, Column);
  FStatusPositionLabel.Text := Format(StatusPositionFormat, [Line, Column]);
  FStatusWordsLabel.Text := Format(StatusWordsFormat, [TPadText.CountWords(FEditor.Text)]);
end;

procedure TMarkdownPadFMXForm.UpdateTitle;
begin
  var Name := UntitledName;
  if FActiveDoc <> nil then
    Name := FActiveDoc.DisplayName;

  if (FActiveDoc <> nil) and FActiveDoc.Modified then
    Name := Name + ModifiedMarker;

  Caption := Format(TitleFormat, [WindowCaption, Name]);
end;

procedure TMarkdownPadFMXForm.ExecuteFind;
begin
  const Needle = FFindEdit.Text;
  if Needle = '' then
    Exit;

  FPreview.FindText(Needle);
end;

procedure TMarkdownPadFMXForm.ApplyTheme;
begin
  var IconColor := IconLightColor;
  var SeparatorColor := SeparatorLightColor;

  if FDarkThemeActive then
  begin
    FEditor.Theme := FDarkTheme;
    FPreview.Theme := FDarkTheme;

    FToolbarFill := ToolbarDarkColor;
    FHoverColor := HoverDarkColor;
    IconColor := IconDarkColor;
    SeparatorColor := SeparatorDarkColor;
  end
  else
  begin
    FEditor.Theme := FLightTheme;
    FPreview.Theme := FLightTheme;

    FToolbarFill := ToolbarLightColor;
    FHoverColor := HoverLightColor;
  end;

  FTocFill := FToolbarFill;
  FTocTextColor := IconColor;
  FChromeTextColor := IconColor;

  Fill.Color := FToolbarFill;
  Fill.Kind := TBrushKind.Solid;

  FToolbar.Fill.Color := FToolbarFill;

  for var Button in FIconButtons do
  begin
    Button.Fill.Color := FToolbarFill;
  end;

  for var GlyphText in FIconGlyphs do
  begin
    GlyphText.Color := IconColor;
  end;

  for var Separator in FSeparators do
  begin
    Separator.Fill.Color := SeparatorColor;
  end;

  FTocHeader.Color := IconColor;
  FTocList.NeedStyleLookup;
  FTocList.ApplyStyleLookup;
  StyleTocBackground;
  ApplyTocItemColors;

  ApplyChromeColors;
end;

procedure TMarkdownPadFMXForm.ApplyChromeColors;
begin
  FStatusBar.Fill.Color := FToolbarFill;
  FFindBar.Fill.Color := FToolbarFill;

  FTitleBar.Fill.Color := FToolbarFill;
  FMinButton.Fill.Color := FToolbarFill;
  FMaxButton.Fill.Color := FToolbarFill;
  FCloseButton.Fill.Color := FToolbarFill;

  for var GlyphText in FCaptionGlyphs do
    GlyphText.Color := FChromeTextColor;

  if FDarkThemeActive then
  begin
    FTabStrip.ActiveColor := TabActiveDarkColor;
    FTabStrip.HoverColor := TabHoverDarkColor;
  end
  else
  begin
    FTabStrip.ActiveColor := TabActiveLightColor;
    FTabStrip.HoverColor := TabHoverLightColor;
  end;

  FTabStrip.InactiveColor := FToolbarFill;
  FTabStrip.TextColor := FChromeTextColor;
  FTabStrip.GlyphColor := FChromeTextColor;
  FTabStrip.Repaint;

  const Labels: TArray<TLabel> = [FStatusPositionLabel, FStatusWordsLabel, FEditorFindCount];

  for var LabelControl in Labels do
  begin
    LabelControl.StyledSettings := LabelControl.StyledSettings - [TStyledSetting.FontColor];
    LabelControl.TextSettings.FontColor := FChromeTextColor;
  end;
end;

procedure TMarkdownPadFMXForm.ApplyTocItemColors;
begin
  for var Index := 0 to FTocList.Count - 1 do
  begin
    const Item = FTocList.ListItems[Index];
    Item.StyledSettings := Item.StyledSettings - [TStyledSetting.FontColor];
    Item.TextSettings.FontColor := FTocTextColor;
  end;
end;

procedure TMarkdownPadFMXForm.HandleTocListApplyStyle(Sender: TObject);
begin
  StyleTocBackground;
end;

procedure TMarkdownPadFMXForm.StyleTocBackground;
begin
  // Recolor the list-box background directly. Relying only on OnApplyStyleLookup
  // is unreliable: the event does not always re-fire when the theme is toggled at
  // runtime, which left the Contents panel white in dark mode.
  const Background = FTocList.FindStyleResource('background');
  if Background is TRectangle then
  begin
    TRectangle(Background).Fill.Kind := TBrushKind.Solid;
    TRectangle(Background).Fill.Color := FTocFill;
    TRectangle(Background).Stroke.Kind := TBrushKind.None;
  end
  else if Background is TControl then
    TControl(Background).Opacity := 0;
end;

procedure TMarkdownPadFMXForm.SaveSession;
begin
  if FSession = nil then
    Exit;

  var FilteredActive: Integer;
  const Titled = TPadSessionSync.CollectOpenFiles(FWorkspace, FilteredActive);

  FSession.SetOpenFiles(Titled, FilteredActive);
  FSession.DarkTheme := FDarkThemeActive;

  if FZenActive then
    FSession.ViewMode := FPreZenViewMode
  else
    FSession.ViewMode := FViewMode;

  FSession.Save;
end;

class function TMarkdownPadFMXForm.BuildSampleMarkdown: string;
begin
  Result :=
    '# Markdown4D Pad (FMX)'#10#10 +
    'A native FireMonkey Markdown editor with a **live preview**. Type on the left; ' +
    'the right pane re-renders through the debounced incremental pipeline.'#10#10 +
    '## Editing'#10#10 +
    '- **Ctrl+B** bold, *Ctrl+I* italic, Ctrl+K link'#10 +
    '- Undo / redo with Ctrl+Z / Ctrl+Y'#10 +
    '- Source syntax highlighting with line numbers'#10#10 +
    '## Documents'#10#10 +
    'Open several files into tabs, switch with Ctrl+Tab, create a blank one with Ctrl+N, ' +
    'and close the current one with Ctrl+W. Open tabs and recent files are remembered ' +
    'between sessions.'#10#10 +
    '## Chart'#10#10 +
    'Chart code blocks render natively on the canvas:'#10#10 +
    '```json'#10 +
    '{"type":"chart","data":{"type":"doughnut","data":{"labels":["Edit","Preview"],' +
    '"datasets":[{"data":[60,40],"backgroundColor":["#4E79A7","#F28E2B"]}]},' +
    '"options":{"plugins":{"title":{"display":true,"text":"Split"}}}}}'#10 +
    '```'#10#10 +
    '## Diagrams'#10#10 +
    'Mermaid fences render natively too - a flowchart:'#10#10 +
    '```mermaid'#10 +
    'flowchart LR'#10 +
    '  Type[Type text] --> Parse{Parse ok?}'#10 +
    '  Parse -->|yes| Render([Render preview])'#10 +
    '  Parse -->|no| Type'#10 +
    '```'#10#10 +
    'and a sequence diagram:'#10#10 +
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
    '> Toggle the theme with the toolbar button.'#10;
end;

end.
