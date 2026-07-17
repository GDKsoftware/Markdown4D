unit VclViewerDemo.Main;

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
  Markdown4D.Theme,
  Markdown4D.Vcl.Viewer;

type
  TVclViewerDemoForm = class(TForm)
  private
    const
      WindowCaption = 'Markdown4D VCL Viewer Demo';
      InitialClientWidth = 960;
      InitialClientHeight = 720;
      ToolbarHeight = 36;
      ControlMargin = 6;
      ControlHeight = 24;
      OpenButtonWidth = 90;
      ThemeButtonWidth = 110;
      FindEditWidth = 200;
      FindButtonWidth = 70;
      OpenButtonCaption = 'Open...';
      DarkThemeCaption = 'Dark theme';
      LightThemeCaption = 'Light theme';
      FindButtonCaption = 'Find';
      NotFoundStatusFormat = 'No matches for "%s"';
      MarkdownFileFilter = 'Markdown files (*.md)|*.md|All files (*.*)|*.*';
      MarkdownDefaultExtension = 'md';
    var
      FToolbarPanel: TPanel;
      FOpenButton: TButton;
      FThemeButton: TButton;
      FFindEdit: TEdit;
      FFindButton: TButton;
      FStatusBar: TStatusBar;
      FMarkdownViewer: TMarkdownViewer;
      FOpenDialog: TOpenDialog;
      FLightTheme: TMarkdownTheme;
      FDarkTheme: TMarkdownTheme;
      FDarkThemeActive: Boolean;
    procedure BuildToolbar;
    procedure BuildStatusBar;
    procedure BuildViewer;
    procedure HandleOpenClick(Sender: TObject);
    procedure OpenMarkdownFile(const FileName: string);
    procedure HandleThemeClick(Sender: TObject);
    procedure HandleFindClick(Sender: TObject);
    procedure HandleFindEditKeyPress(Sender: TObject; var Key: Char);
    procedure ExecuteFind;
    procedure HandleLinkClick(const Sender: TObject; const Url: string);
    procedure HandleLinkHover(const Sender: TObject; const Url: string);
    class function BuildWelcomeMarkdown: string;

  public
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
  end;

var
  VclViewerDemoForm: TVclViewerDemoForm;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows,
  Winapi.ShellAPI,
  Markdown4D.Extensions.Chart.BlockOverride,
  Markdown4D.Extensions.Mermaid.BlockOverride;

constructor TVclViewerDemoForm.Create(Owner: TComponent);
begin
  inherited CreateNew(Owner);

  TChartBlockOverride.RegisterOverride;
  TMermaidBlockOverride.RegisterOverride;

  Caption := WindowCaption;
  ClientWidth := InitialClientWidth;
  ClientHeight := InitialClientHeight;
  Position := TPosition.poScreenCenter;

  FLightTheme := TMarkdownTheme.CreateLight;
  FDarkTheme := TMarkdownTheme.CreateDark;

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := MarkdownFileFilter;
  FOpenDialog.DefaultExt := MarkdownDefaultExtension;

  BuildToolbar;
  BuildStatusBar;
  BuildViewer;
end;

procedure TVclViewerDemoForm.BuildToolbar;
begin
  FToolbarPanel := TPanel.Create(Self);
  FToolbarPanel.Parent := Self;
  FToolbarPanel.Align := alTop;
  FToolbarPanel.Height := ToolbarHeight;
  FToolbarPanel.BevelOuter := bvNone;
  FToolbarPanel.ShowCaption := False;

  const ControlTop = (ToolbarHeight - ControlHeight) div 2;

  FOpenButton := TButton.Create(Self);
  FOpenButton.Parent := FToolbarPanel;
  FOpenButton.SetBounds(ControlMargin, ControlTop, OpenButtonWidth, ControlHeight);
  FOpenButton.Caption := OpenButtonCaption;
  FOpenButton.OnClick := HandleOpenClick;

  FThemeButton := TButton.Create(Self);
  FThemeButton.Parent := FToolbarPanel;
  FThemeButton.SetBounds(FOpenButton.Left + FOpenButton.Width + ControlMargin, ControlTop, ThemeButtonWidth,
    ControlHeight);
  FThemeButton.Caption := DarkThemeCaption;
  FThemeButton.OnClick := HandleThemeClick;

  FFindEdit := TEdit.Create(Self);
  FFindEdit.Parent := FToolbarPanel;
  FFindEdit.SetBounds(FThemeButton.Left + FThemeButton.Width + ControlMargin, ControlTop, FindEditWidth,
    ControlHeight);
  FFindEdit.TextHint := FindButtonCaption;
  FFindEdit.OnKeyPress := HandleFindEditKeyPress;

  FFindButton := TButton.Create(Self);
  FFindButton.Parent := FToolbarPanel;
  FFindButton.SetBounds(FFindEdit.Left + FFindEdit.Width + ControlMargin, ControlTop, FindButtonWidth,
    ControlHeight);
  FFindButton.Caption := FindButtonCaption;
  FFindButton.OnClick := HandleFindClick;
end;

procedure TVclViewerDemoForm.BuildStatusBar;
begin
  FStatusBar := TStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.SimplePanel := True;
end;

procedure TVclViewerDemoForm.BuildViewer;
begin
  FMarkdownViewer := TMarkdownViewer.Create(Self);
  FMarkdownViewer.Parent := Self;
  FMarkdownViewer.Align := alClient;
  FMarkdownViewer.OnLinkClick := HandleLinkClick;
  FMarkdownViewer.OnLinkHover := HandleLinkHover;
  FMarkdownViewer.Text := BuildWelcomeMarkdown;
end;

procedure TVclViewerDemoForm.HandleOpenClick(Sender: TObject);
begin
  if FOpenDialog.Execute then
    OpenMarkdownFile(FOpenDialog.FileName);
end;

procedure TVclViewerDemoForm.OpenMarkdownFile(const FileName: string);
begin
  FMarkdownViewer.LoadFromFile(FileName);
  Caption := Format('%s - %s', [WindowCaption, TPath.GetFileName(FileName)]);
  FStatusBar.SimpleText := '';
end;

procedure TVclViewerDemoForm.HandleThemeClick(Sender: TObject);
begin
  FDarkThemeActive := not FDarkThemeActive;

  if FDarkThemeActive then
  begin
    FMarkdownViewer.Theme := FDarkTheme;
    FThemeButton.Caption := LightThemeCaption;
  end
  else
  begin
    FMarkdownViewer.Theme := FLightTheme;
    FThemeButton.Caption := DarkThemeCaption;
  end;
end;

procedure TVclViewerDemoForm.HandleFindClick(Sender: TObject);
begin
  ExecuteFind;
end;

procedure TVclViewerDemoForm.HandleFindEditKeyPress(Sender: TObject; var Key: Char);
begin
  if Key <> #13 then
    Exit;

  Key := #0;
  ExecuteFind;
end;

procedure TVclViewerDemoForm.ExecuteFind;
begin
  const Needle = FFindEdit.Text;
  if Needle = '' then
    Exit;

  const Found = FMarkdownViewer.FindText(Needle);
  if Found then
    FStatusBar.SimpleText := ''
  else
    FStatusBar.SimpleText := Format(NotFoundStatusFormat, [Needle]);
end;

procedure TVclViewerDemoForm.HandleLinkClick(const Sender: TObject; const Url: string);
begin
  ShellExecute(0, nil, PChar(Url), nil, nil, SW_SHOWNORMAL);
end;

procedure TVclViewerDemoForm.HandleLinkHover(const Sender: TObject; const Url: string);
begin
  FStatusBar.SimpleText := Url;
end;

class function TVclViewerDemoForm.BuildWelcomeMarkdown: string;
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
    '{"type":"chart","data":{"type":"bar","data":{"labels":["Parser","Layout","Viewer"],' +
    '"datasets":[{"label":"Progress","data":[100,100,80],"backgroundColor":"#59A14F"}]},' +
    '"options":{"plugins":{"title":{"display":true,"text":"Module Progress"}},' +
    '"scales":{"y":{"min":0,"max":100}}}}}'#10 +
    '```'#10#10 +
    '| Feature | Shortcut |'#10 +
    '| --- | --- |'#10 +
    '| Copy selection | Ctrl+C |'#10 +
    '| Scroll | Mouse wheel, arrows, PgUp/PgDn |'#10#10 +
    '> Load your own README.md to see it rendered natively.'#10;
end;

destructor TVclViewerDemoForm.Destroy;
begin
  inherited Destroy;

  FDarkTheme.Free;
  FLightTheme.Free;
end;

end.
