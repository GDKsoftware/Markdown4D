unit FmxViewerDemo.Main;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.UITypes,
  FMX.Forms,
  FMX.Types,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.Dialogs,
  Markdown4D.Theme,
  Markdown4D.Fmx.Viewer;

type
  TFmxViewerDemoForm = class(TForm)
  private
    const
      WindowCaption = 'Markdown4D FMX Viewer Demo';
      InitialClientWidth = 960;
      InitialClientHeight = 720;
      ToolbarHeight = 44;
      ControlMargin = 6;
      OpenButtonWidth = 90;
      ThemeButtonWidth = 110;
      FindButtonWidth = 70;
      OpenButtonCaption = 'Open...';
      DarkThemeCaption = 'Dark theme';
      LightThemeCaption = 'Light theme';
      FindHintCaption = 'Find';
      NotFoundStatusFormat = 'No matches for "%s"';
      MarkdownFileFilter = 'Markdown files (*.md)|*.md|All files (*.*)|*.*';
      OpenedCaptionFormat = '%s - %s';
    var
      FToolbar: TToolBar;
      FOpenButton: TButton;
      FThemeButton: TButton;
      FFindEdit: TEdit;
      FFindButton: TButton;
      FStatusBar: TStatusBar;
      FStatusLabel: TLabel;
      FMarkdownViewer: TMarkdownViewer;
      FOpenDialog: TOpenDialog;
      FLightTheme: TMarkdownTheme;
      FDarkTheme: TMarkdownTheme;
      FDarkThemeActive: Boolean;
    procedure BuildToolbar;
    procedure BuildStatusBar;
    procedure BuildViewer;
    procedure SetUniformMargins(const Control: TControl; const Amount: Single);
    procedure HandleOpenClick(Sender: TObject);
    procedure OpenMarkdownFile(const FileName: string);
    procedure HandleThemeClick(Sender: TObject);
    procedure HandleFindClick(Sender: TObject);
    procedure HandleFindEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure ExecuteFind;
    procedure HandleLinkClick(const Sender: TObject; const Url: string);
    procedure HandleLinkHover(const Sender: TObject; const Url: string);
    class function BuildWelcomeMarkdown: string;

  public
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
  end;

var
  FmxViewerDemoForm: TFmxViewerDemoForm;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Markdown4D.Extensions.Chart.BlockOverride,
  Markdown4D.Extensions.Mermaid.BlockOverride,
  FmxViewerDemo.Browser;

constructor TFmxViewerDemoForm.Create(Owner: TComponent);
begin
  inherited CreateNew(Owner);

  TChartBlockOverride.RegisterOverride;
  TMermaidBlockOverride.RegisterOverride;

  Caption := WindowCaption;
  ClientWidth := InitialClientWidth;
  ClientHeight := InitialClientHeight;
  Position := TFormPosition.ScreenCenter;

  FLightTheme := TMarkdownTheme.CreateLight;
  FDarkTheme := TMarkdownTheme.CreateDark;

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := MarkdownFileFilter;

  BuildStatusBar;
  BuildToolbar;
  BuildViewer;
end;

procedure TFmxViewerDemoForm.BuildToolbar;
begin
  FToolbar := TToolBar.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.Align := TAlignLayout.Top;
  FToolbar.Height := ToolbarHeight;

  FOpenButton := TButton.Create(Self);
  FOpenButton.Parent := FToolbar;
  FOpenButton.Align := TAlignLayout.Left;
  SetUniformMargins(FOpenButton, ControlMargin);
  FOpenButton.Width := OpenButtonWidth;
  FOpenButton.Text := OpenButtonCaption;
  FOpenButton.OnClick := HandleOpenClick;

  FThemeButton := TButton.Create(Self);
  FThemeButton.Parent := FToolbar;
  FThemeButton.Align := TAlignLayout.Left;
  SetUniformMargins(FThemeButton, ControlMargin);
  FThemeButton.Width := ThemeButtonWidth;
  FThemeButton.Text := DarkThemeCaption;
  FThemeButton.OnClick := HandleThemeClick;

  FFindButton := TButton.Create(Self);
  FFindButton.Parent := FToolbar;
  FFindButton.Align := TAlignLayout.Right;
  SetUniformMargins(FFindButton, ControlMargin);
  FFindButton.Width := FindButtonWidth;
  FFindButton.Text := FindHintCaption;
  FFindButton.OnClick := HandleFindClick;

  FFindEdit := TEdit.Create(Self);
  FFindEdit.Parent := FToolbar;
  FFindEdit.Align := TAlignLayout.Client;
  SetUniformMargins(FFindEdit, ControlMargin);
  FFindEdit.TextPrompt := FindHintCaption;
  FFindEdit.OnKeyDown := HandleFindEditKeyDown;
end;

procedure TFmxViewerDemoForm.BuildStatusBar;
begin
  FStatusBar := TStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.Align := TAlignLayout.Bottom;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := FStatusBar;
  FStatusLabel.Align := TAlignLayout.Client;
  SetUniformMargins(FStatusLabel, ControlMargin);
end;

procedure TFmxViewerDemoForm.BuildViewer;
begin
  FMarkdownViewer := TMarkdownViewer.Create(Self);
  FMarkdownViewer.Parent := Self;
  FMarkdownViewer.Align := TAlignLayout.Client;
  FMarkdownViewer.OnLinkClick := HandleLinkClick;
  FMarkdownViewer.OnLinkHover := HandleLinkHover;
  FMarkdownViewer.Text := BuildWelcomeMarkdown;
end;

procedure TFmxViewerDemoForm.SetUniformMargins(const Control: TControl; const Amount: Single);
begin
  Control.Margins.Left := Amount;
  Control.Margins.Top := Amount;
  Control.Margins.Right := Amount;
  Control.Margins.Bottom := Amount;
end;

procedure TFmxViewerDemoForm.HandleOpenClick(Sender: TObject);
begin
  if FOpenDialog.Execute then
    OpenMarkdownFile(FOpenDialog.FileName);
end;

procedure TFmxViewerDemoForm.OpenMarkdownFile(const FileName: string);
begin
  FMarkdownViewer.LoadFromFile(FileName);
  Caption := Format(OpenedCaptionFormat, [WindowCaption, TPath.GetFileName(FileName)]);
  FStatusLabel.Text := '';
end;

procedure TFmxViewerDemoForm.HandleThemeClick(Sender: TObject);
begin
  FDarkThemeActive := not FDarkThemeActive;

  if FDarkThemeActive then
  begin
    FMarkdownViewer.Theme := FDarkTheme;
    FThemeButton.Text := LightThemeCaption;
  end
  else
  begin
    FMarkdownViewer.Theme := FLightTheme;
    FThemeButton.Text := DarkThemeCaption;
  end;
end;

procedure TFmxViewerDemoForm.HandleFindClick(Sender: TObject);
begin
  ExecuteFind;
end;

procedure TFmxViewerDemoForm.HandleFindEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  if Key <> vkReturn then
    Exit;

  Key := 0;
  KeyChar := #0;
  ExecuteFind;
end;

procedure TFmxViewerDemoForm.ExecuteFind;
begin
  const Needle = FFindEdit.Text;
  if Needle = '' then
    Exit;

  const Found = FMarkdownViewer.FindText(Needle);
  if Found then
    FStatusLabel.Text := ''
  else
    FStatusLabel.Text := Format(NotFoundStatusFormat, [Needle]);
end;

procedure TFmxViewerDemoForm.HandleLinkClick(const Sender: TObject; const Url: string);
begin
  TBrowserLauncher.Open(Url);
end;

procedure TFmxViewerDemoForm.HandleLinkHover(const Sender: TObject; const Url: string);
begin
  FStatusLabel.Text := Url;
end;

class function TFmxViewerDemoForm.BuildWelcomeMarkdown: string;
begin
  Result :=
    '# Markdown4D Viewer Demo'#10#10 +
    'Use **Open...** to load a Markdown file, toggle the theme, or search with the find box.'#10#10 +
    '## Try it'#10#10 +
    '- Hover a link to see its URL in the status bar: [Embarcadero](https://www.embarcadero.com)'#10 +
    '- Click a link to open it in your default browser: [CommonMark spec](https://spec.commonmark.org)'#10 +
    '- Task list:'#10 +
    '  - [x] Open files'#10 +
    '  - [x] Light and dark themes'#10 +
    '  - [x] Find text'#10#10 +
    '## Code'#10#10 +
    '```pascal'#10 +
    'procedure Greet(const Name: string);'#10 +
    'begin'#10 +
    '  Writeln(Format(''Hello, %s!'', [Name]));'#10 +
    'end;'#10 +
    '```'#10#10 +
    '## Chart'#10#10 +
    'Chart code blocks render natively - no browser required:'#10#10 +
    '```json'#10 +
    '{"type":"chart","data":{"type":"doughnut","data":{"labels":["Parser","Layout","Viewer"],' +
    '"datasets":[{"data":[40,35,25],"backgroundColor":["#4E79A7","#F28E2B","#59A14F"]}]},' +
    '"options":{"plugins":{"title":{"display":true,"text":"Effort Split"},' +
    '"legend":{"position":"right"}}}}}'#10 +
    '```'#10#10 +
    '| Feature | Shortcut |'#10 +
    '| --- | --- |'#10 +
    '| Copy selection | Ctrl+C |'#10 +
    '| Scroll | Mouse wheel, arrows, PgUp/PgDn |'#10#10 +
    '> Load your own README.md to see it rendered natively.'#10;
end;

destructor TFmxViewerDemoForm.Destroy;
begin
  inherited Destroy;

  FDarkTheme.Free;
  FLightTheme.Free;
end;

end.
