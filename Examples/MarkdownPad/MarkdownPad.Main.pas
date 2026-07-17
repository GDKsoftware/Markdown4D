unit MarkdownPad.Main;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Dialogs,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Toc,
  Markdown4D.Editor.Model,
  Markdown4D.Editor.Sync,
  Markdown4D.Theme,
  Markdown4D.Vcl.Editor,
  Markdown4D.Vcl.Viewer;

type
  TMarkdownPadForm = class(TForm)
  private
    const
      WindowCaption = 'Markdown4D Pad';
      InitialClientWidth = 1200;
      InitialClientHeight = 760;
      ToolbarHeight = 40;
      TocPanelWidth = 240;
      ButtonSpacing = 4;
      ButtonWidth = 64;
      NarrowButtonWidth = 44;
      FindEditWidth = 160;
      TickIntervalMilliseconds = 100;
      TocHeaderCaption = 'Contents';
      OpenButtonCaption = 'Open';
      SaveButtonCaption = 'Save';
      SaveAsButtonCaption = 'Save As';
      BoldButtonCaption = 'B';
      ItalicButtonCaption = 'I';
      LinkButtonCaption = 'Link';
      CodeButtonCaption = 'Code';
      ThemeButtonCaption = 'Theme';
      TocButtonCaption = 'TOC';
      FindButtonCaption = 'Find';
      MarkdownFilter = 'Markdown files (*.md)|*.md|All files (*.*)|*.*';
      DefaultExtension = 'md';
      ModifiedMarker = ' *';
      StatusPositionFormat = 'Ln %d, Col %d';
      StatusWordsFormat = '%d words';
      TitleFormat = '%s - %s';
    var
      FToolbar: TPanel;
      FTocPanel: TPanel;
      FTocSplitter: TSplitter;
      FTocList: TListBox;
      FEditor: TMarkdownEditor;
      FMainSplitter: TSplitter;
      FPreview: TMarkdownViewer;
      FStatusBar: TStatusBar;
      FFindEdit: TEdit;
      FOpenButton: TButton;
      FSaveButton: TButton;
      FSaveAsButton: TButton;
      FBoldButton: TButton;
      FItalicButton: TButton;
      FLinkButton: TButton;
      FCodeButton: TButton;
      FThemeButton: TButton;
      FTocButton: TButton;
      FFindButton: TButton;
      FOpenDialog: TOpenDialog;
      FSaveDialog: TSaveDialog;
      FTickTimer: TTimer;
      FSync: TMarkdownEditorSync;
      FTocEntries: TArray<IMarkdownTocEntry>;
      FLightTheme: TMarkdownTheme;
      FDarkTheme: TMarkdownTheme;
      FDarkThemeActive: Boolean;
      FCurrentFile: string;
      FModified: Boolean;
      FMapDirty: Boolean;
      FSyncing: Boolean;
      FLastCaret: Integer;
    procedure BuildToolbar;
    procedure BuildTocPanel;
    procedure BuildEditorAndPreview;
    procedure BuildStatusBar;
    procedure BuildTimer;
    function AddButton(const Caption: string; const Width: Integer; const Handler: TNotifyEvent): TButton;
    procedure HandleOpenClick(Sender: TObject);
    procedure HandleSaveClick(Sender: TObject);
    procedure HandleSaveAsClick(Sender: TObject);
    procedure HandleBoldClick(Sender: TObject);
    procedure HandleItalicClick(Sender: TObject);
    procedure HandleLinkClick(Sender: TObject);
    procedure HandleCodeClick(Sender: TObject);
    procedure HandleThemeClick(Sender: TObject);
    procedure HandleTocClick(Sender: TObject);
    procedure HandleFindClick(Sender: TObject);
    procedure HandleFindEditKeyPress(Sender: TObject; var Key: Char);
    procedure HandleEditorChange(Sender: TObject);
    procedure HandleEditorScroll(Sender: TObject);
    procedure HandlePreviewScroll(Sender: TObject);
    procedure HandlePreviewLinkClick(const Sender: TObject; const Url: string);
    procedure HandleTocListClick(Sender: TObject);
    procedure HandleTick(Sender: TObject);
    procedure LoadDocument(const FileName: string);
    procedure SaveToFile(const FileName: string);
    procedure ApplyTheme;
    procedure RebuildSyncAndToc;
    procedure UpdateActiveTocEntry(const SourceLine: Integer);
    procedure UpdateStatusBar;
    procedure UpdateTitle;
    procedure ExecuteFind;
    class function BuildSampleMarkdown: string;
    class procedure ComputeLineColumn(const Text: string; const Offset: Integer; out Line, Column: Integer);
    class function CountWords(const Text: string): Integer;

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
  Winapi.Windows,
  Winapi.ShellAPI,
  Vcl.Graphics,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Extensions.Chart.BlockOverride,
  Markdown4D.Extensions.Mermaid.BlockOverride;

constructor TMarkdownPadForm.Create(Owner: TComponent);
begin
  inherited CreateNew(Owner);

  TChartBlockOverride.RegisterOverride;
  TMermaidBlockOverride.RegisterOverride;

  ClientWidth := InitialClientWidth;
  ClientHeight := InitialClientHeight;
  Position := TPosition.poScreenCenter;

  FLightTheme := TMarkdownTheme.CreateLight;
  FDarkTheme := TMarkdownTheme.CreateDark;
  FSync := TMarkdownEditorSync.Create;

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := MarkdownFilter;
  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.Filter := MarkdownFilter;
  FSaveDialog.DefaultExt := DefaultExtension;

  BuildStatusBar;
  BuildToolbar;
  BuildTocPanel;
  BuildEditorAndPreview;
  BuildTimer;

  FEditor.Text := BuildSampleMarkdown;
  FEditor.AttachPreview(FPreview);
  ApplyTheme;
  FMapDirty := True;
  UpdateTitle;
end;

destructor TMarkdownPadForm.Destroy;
begin
  if FEditor <> nil then
    FEditor.DetachPreview;

  inherited Destroy;

  FSync.Free;
  FDarkTheme.Free;
  FLightTheme.Free;
end;

procedure TMarkdownPadForm.BuildToolbar;
begin
  FToolbar := TPanel.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.Align := alTop;
  FToolbar.Height := ToolbarHeight;
  FToolbar.BevelOuter := bvNone;
  FToolbar.ShowCaption := False;

  FOpenButton := AddButton(OpenButtonCaption, ButtonWidth, HandleOpenClick);
  FSaveButton := AddButton(SaveButtonCaption, ButtonWidth, HandleSaveClick);
  FSaveAsButton := AddButton(SaveAsButtonCaption, ButtonWidth, HandleSaveAsClick);
  FBoldButton := AddButton(BoldButtonCaption, NarrowButtonWidth, HandleBoldClick);
  FItalicButton := AddButton(ItalicButtonCaption, NarrowButtonWidth, HandleItalicClick);
  FLinkButton := AddButton(LinkButtonCaption, ButtonWidth, HandleLinkClick);
  FCodeButton := AddButton(CodeButtonCaption, ButtonWidth, HandleCodeClick);
  FThemeButton := AddButton(ThemeButtonCaption, ButtonWidth, HandleThemeClick);
  FTocButton := AddButton(TocButtonCaption, NarrowButtonWidth, HandleTocClick);

  FFindEdit := TEdit.Create(Self);
  FFindEdit.Parent := FToolbar;
  FFindEdit.Align := alRight;
  FFindEdit.AlignWithMargins := True;
  FFindEdit.Margins.SetBounds(ButtonSpacing, ButtonSpacing + 2, ButtonSpacing, ButtonSpacing + 2);
  FFindEdit.Width := FindEditWidth;
  FFindEdit.TextHint := FindButtonCaption;
  FFindEdit.OnKeyPress := HandleFindEditKeyPress;

  FFindButton := TButton.Create(Self);
  FFindButton.Parent := FToolbar;
  FFindButton.Align := alRight;
  FFindButton.AlignWithMargins := True;
  FFindButton.Margins.SetBounds(ButtonSpacing, ButtonSpacing, ButtonSpacing, ButtonSpacing);
  FFindButton.Width := ButtonWidth;
  FFindButton.Caption := FindButtonCaption;
  FFindButton.OnClick := HandleFindClick;
end;

function TMarkdownPadForm.AddButton(const Caption: string; const Width: Integer;
  const Handler: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := FToolbar;
  Result.Align := alLeft;
  Result.AlignWithMargins := True;
  Result.Margins.SetBounds(ButtonSpacing, ButtonSpacing, 0, ButtonSpacing);
  Result.Width := Width;
  Result.Caption := Caption;
  Result.OnClick := Handler;
end;

procedure TMarkdownPadForm.BuildTocPanel;
begin
  FTocPanel := TPanel.Create(Self);
  FTocPanel.Parent := Self;
  FTocPanel.Align := alLeft;
  FTocPanel.Width := TocPanelWidth;
  FTocPanel.BevelOuter := bvNone;
  FTocPanel.Caption := TocHeaderCaption;
  FTocPanel.ShowCaption := True;
  FTocPanel.Alignment := taLeftJustify;
  FTocPanel.VerticalAlignment := taAlignTop;

  FTocList := TListBox.Create(Self);
  FTocList.Parent := FTocPanel;
  FTocList.Align := alClient;
  FTocList.AlignWithMargins := True;
  FTocList.Margins.SetBounds(4, 20, 4, 4);
  FTocList.BorderStyle := bsNone;
  FTocList.OnClick := HandleTocListClick;

  FTocSplitter := TSplitter.Create(Self);
  FTocSplitter.Parent := Self;
  FTocSplitter.Align := alLeft;
  FTocSplitter.Width := ButtonSpacing;
end;

procedure TMarkdownPadForm.BuildEditorAndPreview;
begin
  FEditor := TMarkdownEditor.Create(Self);
  FEditor.Parent := Self;
  FEditor.Align := alLeft;
  FEditor.Width := (InitialClientWidth - TocPanelWidth) div 2;
  FEditor.ShowLineNumbers := True;
  FEditor.OnChange := HandleEditorChange;
  FEditor.OnScroll := HandleEditorScroll;

  FMainSplitter := TSplitter.Create(Self);
  FMainSplitter.Parent := Self;
  FMainSplitter.Align := alLeft;
  FMainSplitter.Width := ButtonSpacing;

  FPreview := TMarkdownViewer.Create(Self);
  FPreview.Parent := Self;
  FPreview.Align := alClient;
  FPreview.OnScroll := HandlePreviewScroll;
  FPreview.OnLinkClick := HandlePreviewLinkClick;
end;

procedure TMarkdownPadForm.BuildStatusBar;
begin
  FStatusBar := TStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.SimplePanel := False;
  FStatusBar.Panels.Add.Width := 160;
  FStatusBar.Panels.Add.Width := 160;
end;

procedure TMarkdownPadForm.BuildTimer;
begin
  FTickTimer := TTimer.Create(Self);
  FTickTimer.Interval := TickIntervalMilliseconds;
  FTickTimer.OnTimer := HandleTick;
  FTickTimer.Enabled := True;
end;

procedure TMarkdownPadForm.HandleOpenClick(Sender: TObject);
begin
  if FOpenDialog.Execute then
    LoadDocument(FOpenDialog.FileName);
end;

procedure TMarkdownPadForm.HandleSaveClick(Sender: TObject);
begin
  if FCurrentFile = '' then
    HandleSaveAsClick(Sender)
  else
    SaveToFile(FCurrentFile);
end;

procedure TMarkdownPadForm.HandleSaveAsClick(Sender: TObject);
begin
  if FCurrentFile <> '' then
    FSaveDialog.FileName := FCurrentFile;

  if FSaveDialog.Execute then
    SaveToFile(FSaveDialog.FileName);
end;

procedure TMarkdownPadForm.HandleBoldClick(Sender: TObject);
begin
  FEditor.ExecuteCommand(TEditorCommand.Bold);
  FEditor.SetFocus;
end;

procedure TMarkdownPadForm.HandleItalicClick(Sender: TObject);
begin
  FEditor.ExecuteCommand(TEditorCommand.Italic);
  FEditor.SetFocus;
end;

procedure TMarkdownPadForm.HandleLinkClick(Sender: TObject);
begin
  FEditor.ExecuteCommand(TEditorCommand.Link);
  FEditor.SetFocus;
end;

procedure TMarkdownPadForm.HandleCodeClick(Sender: TObject);
begin
  FEditor.ExecuteCommand(TEditorCommand.CodeBlock);
  FEditor.SetFocus;
end;

procedure TMarkdownPadForm.HandleThemeClick(Sender: TObject);
begin
  FDarkThemeActive := not FDarkThemeActive;
  ApplyTheme;
end;

procedure TMarkdownPadForm.HandleTocClick(Sender: TObject);
begin
  const ShowToc = not FTocPanel.Visible;
  FTocPanel.Visible := ShowToc;
  FTocSplitter.Visible := ShowToc;
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

procedure TMarkdownPadForm.HandleEditorChange(Sender: TObject);
begin
  FModified := True;
  FMapDirty := True;
  UpdateTitle;
end;

procedure TMarkdownPadForm.HandleEditorScroll(Sender: TObject);
begin
  if FSyncing then
    Exit;

  const SourceLine = FEditor.FirstVisibleSourceLine;

  FSyncing := True;
  try
    FPreview.ScrollOffset := FSync.SourceLineToPreviewOffset(SourceLine);
  finally
    FSyncing := False;
  end;

  UpdateActiveTocEntry(SourceLine);
end;

procedure TMarkdownPadForm.HandlePreviewScroll(Sender: TObject);
begin
  if FSyncing then
    Exit;

  UpdateActiveTocEntry(FSync.PreviewOffsetToSourceLine(FPreview.ScrollOffset));
end;

procedure TMarkdownPadForm.HandlePreviewLinkClick(const Sender: TObject; const Url: string);
begin
  ShellExecute(0, nil, PChar(Url), nil, nil, SW_SHOWNORMAL);
end;

procedure TMarkdownPadForm.HandleTocListClick(Sender: TObject);
begin
  const Index = FTocList.ItemIndex;
  if (Index < 0) or (Index > High(FTocEntries)) then
    Exit;

  const SourceLine = FTocEntries[Index].SourceLine - 1;

  FEditor.CaretPosition := FEditor.SourceLineStartOffset(SourceLine);
  FPreview.ScrollOffset := FSync.SourceLineToPreviewOffset(SourceLine);
  FEditor.SetFocus;
end;

procedure TMarkdownPadForm.HandleTick(Sender: TObject);
begin
  if FMapDirty then
    RebuildSyncAndToc;

  UpdateStatusBar;
end;

procedure TMarkdownPadForm.LoadDocument(const FileName: string);
begin
  FEditor.Text := TFile.ReadAllText(FileName);
  FCurrentFile := FileName;
  FModified := False;
  FMapDirty := True;
  FEditor.FlushPreview;
  UpdateTitle;
end;

procedure TMarkdownPadForm.SaveToFile(const FileName: string);
begin
  TFile.WriteAllText(FileName, FEditor.Text);
  FCurrentFile := FileName;
  FModified := False;
  UpdateTitle;
end;

procedure TMarkdownPadForm.ApplyTheme;
begin
  if FDarkThemeActive then
  begin
    FEditor.Theme := FDarkTheme;
    FPreview.Theme := FDarkTheme;
    Color := clBlack;
  end
  else
  begin
    FEditor.Theme := FLightTheme;
    FPreview.Theme := FLightTheme;
    Color := clWhite;
  end;
end;

procedure TMarkdownPadForm.RebuildSyncAndToc;
begin
  FMapDirty := False;

  const Document = TMarkdown.Parse(FEditor.Text, TMarkdownDialect.Gfm);
  FSync.Update(Document, FPreview.DisplayList);

  const Toc = TMarkdownToc.FromDocument(Document);

  FTocEntries := [];
  FTocList.Items.BeginUpdate;
  try
    FTocList.Items.Clear;

    var Stack: TArray<IMarkdownTocEntry> := [];
    for var Index := Toc.EntryCount - 1 downto 0 do
    begin
      Stack := Stack + [Toc.Entries[Index]];
    end;

    while Length(Stack) > 0 do
    begin
      const Entry = Stack[High(Stack)];
      SetLength(Stack, Length(Stack) - 1);

      FTocEntries := FTocEntries + [Entry];
      FTocList.Items.Add(StringOfChar(' ', 2 * (Entry.Level - 1)) + Entry.Caption);

      for var Index := Entry.ChildCount - 1 downto 0 do
      begin
        Stack := Stack + [Entry.Children[Index]];
      end;
    end;
  finally
    FTocList.Items.EndUpdate;
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

  if Best <> FTocList.ItemIndex then
    FTocList.ItemIndex := Best;
end;

procedure TMarkdownPadForm.UpdateStatusBar;
begin
  const Caret = FEditor.CaretPosition;
  if Caret = FLastCaret then
    Exit;

  FLastCaret := Caret;

  var Line, Column: Integer;
  ComputeLineColumn(FEditor.Text, Caret, Line, Column);
  FStatusBar.Panels[0].Text := Format(StatusPositionFormat, [Line, Column]);
  FStatusBar.Panels[1].Text := Format(StatusWordsFormat, [CountWords(FEditor.Text)]);
end;

procedure TMarkdownPadForm.UpdateTitle;
begin
  var Name := FCurrentFile;
  if Name = '' then
    Name := 'Untitled'
  else
    Name := TPath.GetFileName(Name);

  if FModified then
    Name := Name + ModifiedMarker;

  Caption := Format(TitleFormat, [WindowCaption, Name]);
end;

procedure TMarkdownPadForm.ExecuteFind;
begin
  const Needle = FFindEdit.Text;
  if Needle = '' then
    Exit;

  FPreview.FindText(Needle);
end;

class procedure TMarkdownPadForm.ComputeLineColumn(const Text: string; const Offset: Integer;
  out Line, Column: Integer);
begin
  Line := 1;
  Column := 1;

  const Limit = System.Math.Min(Offset, Length(Text));
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
