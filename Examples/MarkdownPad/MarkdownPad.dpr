program MarkdownPad;

uses
  Vcl.Forms,
  MarkdownPad.Workspace.Interfaces in '..\Shared\MarkdownPad.Workspace.Interfaces.pas',
  MarkdownPad.Workspace in '..\Shared\MarkdownPad.Workspace.pas',
  MarkdownPad.Session in '..\Shared\MarkdownPad.Session.pas',
  MarkdownPad.Commands in '..\Shared\MarkdownPad.Commands.pas',
  MarkdownPad.TabStrip.Layout in '..\Shared\MarkdownPad.TabStrip.Layout.pas',
  MarkdownPad.TabStrip.Interaction in '..\Shared\MarkdownPad.TabStrip.Interaction.pas',
  MarkdownPad.TabStrip in '..\Shared\MarkdownPad.TabStrip.pas',
  MarkdownPad.FileWatcher in '..\Shared\MarkdownPad.FileWatcher.pas',
  MarkdownPad.HtmlExport in '..\Shared\MarkdownPad.HtmlExport.pas',
  MarkdownPad.Main in 'MarkdownPad.Main.pas' {MarkdownPadForm},
  MarkdownPad.Defines in '..\Shared\MarkdownPad.Defines.pas',
  MarkdownPad.Text in '..\Shared\MarkdownPad.Text.pas',
  MarkdownPad.Outline in '..\Shared\MarkdownPad.Outline.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMarkdownPadForm, MarkdownPadForm);
  Application.Run;
end.
