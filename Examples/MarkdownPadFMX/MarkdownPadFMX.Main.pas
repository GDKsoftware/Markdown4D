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
  MarkdownPad.CommandSet,
  MarkdownPad.TabStrip.Layout,
  MarkdownPad.Fmx.TabStrip,
  MarkdownPad.FileWatcher,
  MarkdownPad.Shell,
  MarkdownPad.Controller,
  MarkdownPadFMX.Defines;

type
  TMarkdownPadFMXForm = class(TForm, IPadEditorView, IPadShell)
  private
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
      FZenButton: TRectangle;
      FCommandsButton: TRectangle;
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
      FLightTheme: TMarkdownTheme;
      FDarkTheme: TMarkdownTheme;
      FDarkThemeActive: Boolean;
      FController: TPadController;
      FTocFollowing: Boolean;
      FFindBar: TRectangle;
      FEditorFindEdit: TEdit;
      FEditorFindCount: TLabel;
      FEditorReplaceEdit: TEdit;
      FReplaceButton: TButton;
      FReplaceAllButton: TButton;
      FHintRect: TRectangle;
      FHintText: TText;
      FPalette: TRectangle;
      FPaletteEdit: TEdit;
      FPaletteList: TListBox;
      FViewMode: TPadViewMode;
      FSplitEditorWidth: Single;
      FZenActive: Boolean;
      FPreZenViewMode: TPadViewMode;
      FZenLeftPad: TLayout;
      FZenRightPad: TLayout;
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
    procedure CopyHtmlToClipboard(const Fragment: string);
    procedure CloseApplication;
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
    function BuildCommandActions: TPadCommandActions;
    procedure RestoreSession;
    function HandleFormKey(const Key: Word; const Shift: TShiftState): Boolean;
    function TryHandlePaletteKey(const Key: Word; const Shift: TShiftState): Boolean;
    function TryHandleFormatShortcut(const Key: Word): Boolean;
    function TryHandleCommandShortcut(const Key: Word): Boolean;
    function TryHandleGlobalKey(const Key: Word): Boolean;
    procedure ExecuteFormatCommand(const Command: TEditorCommand);
    procedure SetViewMode(const Mode: TPadViewMode);
    procedure ApplyViewMode;
    procedure ShowFindBar;
    procedure ShowReplaceBar;
    procedure CloseFindBar;
    procedure FindInEditor;
    procedure UpdateFindCount;
    procedure HandleEditorFindKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure HandleEditorFindChange(Sender: TObject);
    procedure HandleReplaceClick(Sender: TObject);
    procedure HandleReplaceAllClick(Sender: TObject);
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
    procedure HandleZenClick(Sender: TObject);
    procedure HandleCommandsClick(Sender: TObject);
    procedure HandleFindClick(Sender: TObject);
    procedure HandleFindEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure HandleEditorChange(Sender: TObject);
    procedure HandleSyncScroll(Sender: TObject; const SourceLine: Integer);
    procedure HandlePreviewLinkClick(const Sender: TObject; const Url: string);
    function ActiveDocumentFolder: string;
    procedure HandleTocChange(Sender: TObject);
    procedure HandleTick(Sender: TObject);
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
    procedure RebuildTabs;
    procedure RebuildSyncAndToc;
    procedure UpdateActiveTocEntry(const SourceLine: Integer);
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
  MarkdownPad.SessionSync,
  MarkdownPad.Workspace,
  MarkdownPad.LinkPolicy,
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

  FController := TPadController.Create(Self, Self, SessionFileName);

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

  FDarkThemeActive := FController.Session.DarkTheme;
  ApplyTheme;

  RestoreSession;

  FMapDirty := True;
end;

destructor TMarkdownPadFMXForm.Destroy;
begin
  if FEditor <> nil then
    FEditor.DetachPreview;

  SaveSession;

  inherited Destroy;

  FController.Free;
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

  FCommandsButton := AddIconButton(GlyphCommands, HintCommands, HandleCommandsClick);
  FZenButton := AddIconButton(GlyphZen, HintZen, HandleZenClick);
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

  FEditorReplaceEdit := TEdit.Create(Self);
  FEditorReplaceEdit.Parent := FFindBar;
  FEditorReplaceEdit.Align := TAlignLayout.Left;
  FEditorReplaceEdit.Margins.Left := ControlMargin;
  FEditorReplaceEdit.Margins.Top := ControlMargin;
  FEditorReplaceEdit.Margins.Bottom := ControlMargin;
  FEditorReplaceEdit.Width := FindBarEditWidth;
  FEditorReplaceEdit.TextPrompt := ReplaceHintCaption;

  FReplaceButton := TButton.Create(Self);
  FReplaceButton.Parent := FFindBar;
  FReplaceButton.Align := TAlignLayout.Left;
  FReplaceButton.Margins.Left := ControlMargin;
  FReplaceButton.Margins.Top := ControlMargin;
  FReplaceButton.Margins.Bottom := ControlMargin;
  FReplaceButton.Width := ReplaceButtonWidth;
  FReplaceButton.Text := ReplaceButtonCaption;
  FReplaceButton.OnClick := HandleReplaceClick;

  FReplaceAllButton := TButton.Create(Self);
  FReplaceAllButton.Parent := FFindBar;
  FReplaceAllButton.Align := TAlignLayout.Left;
  FReplaceAllButton.Margins.Left := ControlMargin;
  FReplaceAllButton.Margins.Top := ControlMargin;
  FReplaceAllButton.Margins.Bottom := ControlMargin;
  FReplaceAllButton.Width := ReplaceAllButtonWidth;
  FReplaceAllButton.Text := ReplaceAllButtonCaption;
  FReplaceAllButton.OnClick := HandleReplaceAllClick;

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
  FController.InitCommandRegistry(BuildCommandActions);
end;

function TMarkdownPadFMXForm.BuildCommandActions: TPadCommandActions;
begin
  Result.NewDocument := procedure begin HandleNewClick(nil); end;
  Result.OpenDocument := procedure begin HandleOpenClick(nil); end;
  Result.Save := procedure begin HandleSaveClick(nil); end;
  Result.SaveAs := procedure begin HandleSaveAsClick(nil); end;
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
  Result.ToggleTheme := procedure begin HandleThemeClick(nil); end;
  Result.ToggleToc := procedure begin HandleTocClick(nil); end;
  Result.ShowFind := procedure begin ShowFindBar; end;
  Result.ShowReplace := procedure begin ShowReplaceBar; end;
  Result.FindInPreview := procedure begin ExecuteFind; end;
  Result.Undo := procedure begin FEditor.Undo; FEditor.SetFocus; end;
  Result.Redo := procedure begin FEditor.Redo; FEditor.SetFocus; end;
  Result.SelectAll := procedure begin FEditor.SelectAll; FEditor.SetFocus; end;
  Result.Indent := procedure begin FEditor.Indent; FEditor.SetFocus; end;
  Result.Outdent := procedure begin FEditor.Outdent; FEditor.SetFocus; end;
  Result.DeleteWordLeft := procedure begin FEditor.DeleteWordLeft; FEditor.SetFocus; end;
  Result.ExecuteFormat :=
    procedure(const Command: TEditorCommand)
    begin
      FEditor.ExecuteCommand(Command);
      FEditor.SetFocus;
    end;
end;

procedure TMarkdownPadFMXForm.RestoreSession;
begin
  FController.RestoreSession;
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
  if FPalette.Visible then
    Exit(TryHandlePaletteKey(Key, Shift));

  const WantsShortcut = (ssCtrl in Shift);
  if WantsShortcut then
  begin
    if ssShift in Shift then
      Exit(TryHandleFormatShortcut(Key));

    Exit(TryHandleCommandShortcut(Key));
  end;

  Result := TryHandleGlobalKey(Key);
end;

// While the palette is open it owns the keyboard: the arrows, Return and
// Escape drive it, and control chords are swallowed so they cannot reach the
// editor underneath.
function TMarkdownPadFMXForm.TryHandlePaletteKey(const Key: Word; const Shift: TShiftState): Boolean;
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
    Exit(ssCtrl in Shift);
  end;

  Result := True;
end;

function TMarkdownPadFMXForm.TryHandleFormatShortcut(const Key: Word): Boolean;
begin
  case Key of
    vk1:
      ExecuteFormatCommand(TEditorCommand.Heading1);
    vk2:
      ExecuteFormatCommand(TEditorCommand.Heading2);
    vk3:
      ExecuteFormatCommand(TEditorCommand.Heading3);
    vkU:
      ExecuteFormatCommand(TEditorCommand.BulletList);
    vkO:
      ExecuteFormatCommand(TEditorCommand.NumberedList);
    vkQ:
      ExecuteFormatCommand(TEditorCommand.Quote);
    vkX:
      ExecuteFormatCommand(TEditorCommand.Strikethrough);
    vkT:
      ExecuteFormatCommand(TEditorCommand.Table);
    vkE:
      DoExportHtml;
    vkC:
      DoCopyHtml;
    vkS:
      FController.SaveAs;
    vkTab:
      begin
        FWorkspace.ActivatePrevious;
        SwitchToDocument(FWorkspace.ActiveIndex);
      end;
  else
    Exit(False);
  end;

  Result := True;
end;

function TMarkdownPadFMXForm.TryHandleCommandShortcut(const Key: Word): Boolean;
begin
  case Key of
    vk1:
      SetViewMode(TPadViewMode.EditorOnly);
    vk2:
      SetViewMode(TPadViewMode.Split);
    vk3:
      SetViewMode(TPadViewMode.PreviewOnly);
    vkF:
      ShowFindBar;
    vkH:
      ShowReplaceBar;
    vkK:
      ShowPalette;
    vkN:
      FController.NewDocument;
    vkO:
      FController.OpenViaDialog;
    vkS:
      FController.Save;
    vkW:
      CloseActiveDocument;
    vkTab:
      begin
        FWorkspace.ActivateNext;
        SwitchToDocument(FWorkspace.ActiveIndex);
      end;
  else
    Exit(False);
  end;

  Result := True;
end;

function TMarkdownPadFMXForm.TryHandleGlobalKey(const Key: Word): Boolean;
begin
  case Key of
    vkF11:
      ToggleZen;
    vkF3:
      begin
        if not FFindBar.Visible then
          Exit(False);

        FindInEditor;
      end;
    vkEscape:
      begin
        if FFindBar.Visible then
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

procedure TMarkdownPadFMXForm.ExecuteFormatCommand(const Command: TEditorCommand);
begin
  FEditor.ExecuteCommand(Command);
  FEditor.SetFocus;
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

  Result := FController.QueryClose;
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

procedure TMarkdownPadFMXForm.ShowReplaceBar;
begin
  ShowFindBar;

  FEditorReplaceEdit.SetFocus;
  FEditorReplaceEdit.SelectAll;
end;

procedure TMarkdownPadFMXForm.CloseFindBar;
begin
  FFindBar.Visible := False;
  FEditor.ClearHighlights;

  FEditor.SetFocus;
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
  FController.RebuildPaletteCommands;

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
  FController.RefreshMatches(FPaletteEdit.Text);

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
  if (Index < 0) or (Index >= FController.PaletteMatchCount) then
    Exit;

  ClosePalette;

  FController.InvokePaletteCommand(Index);
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
  FController.NewDocument;
end;

procedure TMarkdownPadFMXForm.HandleOpenClick(Sender: TObject);
begin
  FController.OpenViaDialog;
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
  FController.OpenPath(FileName);
end;

procedure TMarkdownPadFMXForm.HandleSaveClick(Sender: TObject);
begin
  FController.Save;
end;

procedure TMarkdownPadFMXForm.HandleSaveAsClick(Sender: TObject);
begin
  FController.SaveAs;
end;

procedure TMarkdownPadFMXForm.CloseActiveDocument;
begin
  FController.CloseActiveDocument;
end;

procedure TMarkdownPadFMXForm.CloseDocumentAt(const Index: Integer);
begin
  FController.CloseDocumentAt(Index);
end;

procedure TMarkdownPadFMXForm.HandleExportClick(Sender: TObject);
begin
  DoExportHtml;
end;

procedure TMarkdownPadFMXForm.DoExportHtml;
begin
  FController.ExportHtml;
end;

function TMarkdownPadFMXForm.PromptExportHtml(const SuggestedName: string; out FileName: string): Boolean;
begin
  if SuggestedName <> '' then
    FHtmlSaveDialog.FileName := SuggestedName;

  Result := FHtmlSaveDialog.Execute;
  if Result then
    FileName := FHtmlSaveDialog.FileName;
end;

procedure TMarkdownPadFMXForm.HandleCopyHtmlClick(Sender: TObject);
begin
  DoCopyHtml;
end;

procedure TMarkdownPadFMXForm.DoCopyHtml;
begin
  FController.CopyHtml;
end;

procedure TMarkdownPadFMXForm.CopyHtmlToClipboard(const Fragment: string);
begin
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

procedure TMarkdownPadFMXForm.HandleZenClick(Sender: TObject);
begin
  ToggleZen;
end;

procedure TMarkdownPadFMXForm.HandleCommandsClick(Sender: TObject);
begin
  ShowPalette;
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
  FController.NotifyEditorChanged;
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
  var FileName: string;
  if TPadLinkPolicy.TryResolveDocument(Url, ActiveDocumentFolder, FileName) then
  begin
    OpenPath(FileName);
    Exit;
  end;

  if not TPadLinkPolicy.MayOpen(Url) then
  begin
    TDialogServiceSync.MessageDialog(TPadLinkPolicy.RefusalMessage(Url), TMsgDlgType.mtWarning,
      [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
    Exit;
  end;

  ShellExecute(0, nil, PChar(Url), nil, nil, SW_SHOWNORMAL);
end;

// Empty while the active document has never been saved, which is exactly when a
// relative link has nothing to resolve against.
function TMarkdownPadFMXForm.ActiveDocumentFolder: string;
begin
  const Document = FController.ActiveDocument;
  if (Document = nil) or Document.IsUntitled then
    Exit('');

  Result := TPath.GetDirectoryName(Document.FileName);
end;

procedure TMarkdownPadFMXForm.HandleTocChange(Sender: TObject);
begin
  if FTocFollowing then
    Exit;

  const Index = FTocList.ItemIndex;
  if (Index < 0) or (Index >= FController.TocEntryCount) then
    Exit;

  if FMapDirty then
    RebuildSyncAndToc;

  if (Index < 0) or (Index >= FController.TocEntryCount) then
    Exit;

  const SourceLine = FController.TocSourceLine(Index);

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
  FController.Tick;
end;

function TMarkdownPadFMXForm.GetEditorText: string;
begin
  Result := FEditor.Text;
end;

procedure TMarkdownPadFMXForm.SetEditorText(const Value: string);
begin
  FEditor.Text := Value;
end;

function TMarkdownPadFMXForm.MergeEditorText(const Value: string): Boolean;
begin
  Result := FEditor.MergeText(Value);
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
  FController.SwitchToDocument(Index);
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
  FController.RebuildSyncAndToc;
end;

procedure TMarkdownPadFMXForm.UpdateActiveTocEntry(const SourceLine: Integer);
begin
  FController.UpdateActiveTocEntry(SourceLine);
end;

procedure TMarkdownPadFMXForm.ExecuteFind;
begin
  FController.ExecuteFind;
end;

procedure TMarkdownPadFMXForm.FindInEditor;
begin
  FController.FindInEditor;
end;

procedure TMarkdownPadFMXForm.UpdateFindCount;
begin
  FController.UpdateFindCount;
end;

procedure TMarkdownPadFMXForm.SetDocumentTitle(const Name: string);
begin
  Caption := Format(TitleFormat, [WindowCaption, Name]);
end;

procedure TMarkdownPadFMXForm.SetStatus(const PositionText, WordsText: string);
begin
  FStatusPositionLabel.Text := PositionText;
  FStatusWordsLabel.Text := WordsText;
end;

procedure TMarkdownPadFMXForm.SetTocCaptions(const Captions: TArray<string>);
begin
  FTocFollowing := True;
  FTocList.Items.BeginUpdate;
  try
    FTocList.Items.Clear;

    for var Caption in Captions do
      FTocList.Items.Add(Caption);
  finally
    FTocList.Items.EndUpdate;
    FTocFollowing := False;
  end;

  ApplyTocItemColors;
end;

procedure TMarkdownPadFMXForm.SetActiveTocIndex(const Index: Integer);
begin
  if Index = FTocList.ItemIndex then
    Exit;

  FTocFollowing := True;
  try
    FTocList.ItemIndex := Index;
  finally
    FTocFollowing := False;
  end;
end;

function TMarkdownPadFMXForm.EditorFindNeedle: string;
begin
  Result := FEditorFindEdit.Text;
end;

function TMarkdownPadFMXForm.EditorReplaceValue: string;
begin
  Result := FEditorReplaceEdit.Text;
end;

procedure TMarkdownPadFMXForm.HandleReplaceClick(Sender: TObject);
begin
  FController.ReplaceInEditor;
end;

procedure TMarkdownPadFMXForm.HandleReplaceAllClick(Sender: TObject);
begin
  FController.ReplaceAllInEditor;
end;

procedure TMarkdownPadFMXForm.EditorHighlightMatches(const Needle: string);
begin
  FEditor.HighlightMatches(Needle);
end;

function TMarkdownPadFMXForm.EditorReplaceCurrent(const Needle, Replacement: string): Boolean;
begin
  Result := FEditor.ReplaceCurrent(Needle, Replacement, Default(TMarkdownFindOptions));
end;

function TMarkdownPadFMXForm.EditorReplaceAll(const Needle, Replacement: string): Integer;
begin
  Result := FEditor.ReplaceAll(Needle, Replacement, Default(TMarkdownFindOptions));
end;

function TMarkdownPadFMXForm.PreviewFindNeedle: string;
begin
  Result := FFindEdit.Text;
end;

procedure TMarkdownPadFMXForm.SetFindCount(const Value: string);
begin
  FEditorFindCount.Text := Value;
end;

procedure TMarkdownPadFMXForm.EditorFindNext(const Needle: string);
begin
  FEditor.FindNext(Needle);
end;

function TMarkdownPadFMXForm.EditorFindMatchCount(const Needle: string): Integer;
begin
  Result := FEditor.FindMatchCount(Needle);
end;

procedure TMarkdownPadFMXForm.PreviewFindText(const Needle: string);
begin
  FPreview.FindText(Needle);
end;

function TMarkdownPadFMXForm.ConfirmCloseDocument(const DocName: string): TPadCloseChoice;
begin
  const Answer = TDialogServiceSync.MessageDialog(Format(CloseDocumentPromptFormat, [DocName]),
    TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo, TMsgDlgBtn.mbCancel], TMsgDlgBtn.mbCancel, 0);

  if Answer = mrCancel then
    Result := TPadCloseChoice.Cancel
  else if Answer = mrYes then
    Result := TPadCloseChoice.Save
  else
    Result := TPadCloseChoice.Discard;
end;

function TMarkdownPadFMXForm.ConfirmSaveOverChangedFile(const DocName: string): TPadConflictChoice;
begin
  const Answer = TDialogServiceSync.MessageDialog(Format(ConflictPromptFormat, [DocName]),
    TMsgDlgType.mtWarning, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo, TMsgDlgBtn.mbCancel],
    TMsgDlgBtn.mbCancel, 0);

  if Answer = mrYes then
    Result := TPadConflictChoice.Overwrite
  else if Answer = mrNo then
    Result := TPadConflictChoice.Reload
  else
    Result := TPadConflictChoice.Cancel;
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
  FController.SaveSession;
end;

function TMarkdownPadFMXForm.GetWorkspace: IPadWorkspace;
begin
  Result := FController.Workspace;
end;

function TMarkdownPadFMXForm.GetSession: TPadSession;
begin
  Result := FController.Session;
end;

function TMarkdownPadFMXForm.GetMapDirty: Boolean;
begin
  Result := FController.MapDirty;
end;

procedure TMarkdownPadFMXForm.SetMapDirty(const Value: Boolean);
begin
  FController.MapDirty := Value;
end;

function TMarkdownPadFMXForm.GetSwapping: Boolean;
begin
  Result := FController.Swapping;
end;

procedure TMarkdownPadFMXForm.SetSwapping(const Value: Boolean);
begin
  FController.Swapping := Value;
end;

function TMarkdownPadFMXForm.GetPaletteMatches: TArray<TPadCommandMatch>;
begin
  Result := FController.PaletteMatches;
end;

function TMarkdownPadFMXForm.SampleMarkdown: string;
begin
  Result := BuildSampleMarkdown;
end;

function TMarkdownPadFMXForm.DarkThemeActive: Boolean;
begin
  Result := FDarkThemeActive;
end;

function TMarkdownPadFMXForm.EffectiveViewMode: TPadViewMode;
begin
  if FZenActive then
    Result := FPreZenViewMode
  else
    Result := FViewMode;
end;

procedure TMarkdownPadFMXForm.ApplyRestoredViewMode(const Mode: TPadViewMode);
begin
  FViewMode := Mode;
  ApplyViewMode;
end;

function TMarkdownPadFMXForm.PromptOpenFile(out FileName: string): Boolean;
begin
  Result := FOpenDialog.Execute;
  if Result then
    FileName := FOpenDialog.FileName;
end;

function TMarkdownPadFMXForm.PromptSaveFile(const SuggestedName: string; out FileName: string): Boolean;
begin
  if SuggestedName <> '' then
    FSaveDialog.FileName := SuggestedName;

  Result := FSaveDialog.Execute;
  if Result then
    FileName := FSaveDialog.FileName;
end;

function TMarkdownPadFMXForm.ConfirmClose: TPadCloseChoice;
begin
  const Answer = TDialogServiceSync.MessageDialog(CloseUnsavedPrompt, TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo, TMsgDlgBtn.mbCancel], TMsgDlgBtn.mbCancel, 0);

  if Answer = mrCancel then
    Result := TPadCloseChoice.Cancel
  else if Answer = mrYes then
    Result := TPadCloseChoice.Save
  else
    Result := TPadCloseChoice.Discard;
end;

procedure TMarkdownPadFMXForm.ShowOpenError(const FileName, ErrorMessage: string);
begin
  TDialogServiceSync.MessageDialog(Format(OpenErrorFormat, [FileName]), TMsgDlgType.mtError,
    [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
end;

procedure TMarkdownPadFMXForm.ShowSaveError(const FileName, ErrorMessage: string);
begin
  TDialogServiceSync.MessageDialog(Format(SaveErrorFormat, [FileName, ErrorMessage]), TMsgDlgType.mtError,
    [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
end;

procedure TMarkdownPadFMXForm.CloseApplication;
begin
  Close;
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
