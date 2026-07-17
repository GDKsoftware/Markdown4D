unit FmxMarkdownPad.Main;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  FMX.Forms,
  FMX.Types,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Layouts,
  Markdown4D.Theme,
  Markdown4D.Fmx.Editor,
  Markdown4D.Fmx.Viewer;

type
  TFmxMarkdownPadForm = class(TForm)
  private
    const
      WindowCaption = 'Markdown4D Pad (FMX)';
      InitialClientWidth = 1080;
      InitialClientHeight = 720;
      ToolbarHeight = 44;
      ControlMargin = 6;
      ThemeButtonWidth = 130;
      SplitterWidth = 6;
      DarkThemeCaption = 'Dark theme';
      LightThemeCaption = 'Light theme';
    var
      FToolbar: TToolBar;
      FThemeButton: TButton;
      FEditor: TMarkdownEditor;
      FSplitter: TSplitter;
      FPreview: TMarkdownViewer;
      FLightTheme: TMarkdownTheme;
      FDarkTheme: TMarkdownTheme;
      FDarkThemeActive: Boolean;
    procedure BuildToolbar;
    procedure BuildEditorAndPreview;
    procedure HandleThemeClick(Sender: TObject);
    procedure ApplyTheme;
    class function BuildSampleMarkdown: string;

  public
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
  end;

var
  FmxMarkdownPadForm: TFmxMarkdownPadForm;

implementation

uses
  Markdown4D.Extensions.Chart.BlockOverride,
  Markdown4D.Extensions.Mermaid.BlockOverride;

constructor TFmxMarkdownPadForm.Create(Owner: TComponent);
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

  BuildToolbar;
  BuildEditorAndPreview;

  FEditor.Text := BuildSampleMarkdown;
  FEditor.AttachPreview(FPreview);
  ApplyTheme;
end;

destructor TFmxMarkdownPadForm.Destroy;
begin
  if FEditor <> nil then
    FEditor.DetachPreview;

  inherited Destroy;

  FDarkTheme.Free;
  FLightTheme.Free;
end;

procedure TFmxMarkdownPadForm.BuildToolbar;
begin
  FToolbar := TToolBar.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.Align := TAlignLayout.Top;
  FToolbar.Height := ToolbarHeight;

  FThemeButton := TButton.Create(Self);
  FThemeButton.Parent := FToolbar;
  FThemeButton.Align := TAlignLayout.Left;
  FThemeButton.Margins.Left := ControlMargin;
  FThemeButton.Margins.Top := ControlMargin;
  FThemeButton.Margins.Bottom := ControlMargin;
  FThemeButton.Width := ThemeButtonWidth;
  FThemeButton.Text := DarkThemeCaption;
  FThemeButton.OnClick := HandleThemeClick;
end;

procedure TFmxMarkdownPadForm.BuildEditorAndPreview;
begin
  FEditor := TMarkdownEditor.Create(Self);
  FEditor.Parent := Self;
  FEditor.Align := TAlignLayout.Left;
  FEditor.Width := InitialClientWidth / 2;
  FEditor.ShowLineNumbers := True;

  FSplitter := TSplitter.Create(Self);
  FSplitter.Parent := Self;
  FSplitter.Align := TAlignLayout.Left;
  FSplitter.Width := SplitterWidth;

  FPreview := TMarkdownViewer.Create(Self);
  FPreview.Parent := Self;
  FPreview.Align := TAlignLayout.Client;
end;

procedure TFmxMarkdownPadForm.HandleThemeClick(Sender: TObject);
begin
  FDarkThemeActive := not FDarkThemeActive;
  ApplyTheme;
end;

procedure TFmxMarkdownPadForm.ApplyTheme;
begin
  if FDarkThemeActive then
  begin
    FEditor.Theme := FDarkTheme;
    FPreview.Theme := FDarkTheme;
    FThemeButton.Text := LightThemeCaption;
  end
  else
  begin
    FEditor.Theme := FLightTheme;
    FPreview.Theme := FLightTheme;
    FThemeButton.Text := DarkThemeCaption;
  end;
end;

class function TFmxMarkdownPadForm.BuildSampleMarkdown: string;
begin
  Result :=
    '# Markdown4D Pad (FMX)'#10#10 +
    'A native FireMonkey Markdown editor with a **live preview**. Type on the left; ' +
    'the right pane re-renders through the debounced incremental pipeline.'#10#10 +
    '## Editing'#10#10 +
    '- **Ctrl+B** bold, *Ctrl+I* italic, Ctrl+K link'#10 +
    '- Undo / redo with Ctrl+Z / Ctrl+Y'#10 +
    '- Source syntax highlighting with line numbers'#10#10 +
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
