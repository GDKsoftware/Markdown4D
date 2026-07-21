program FmxMarkdownPad;

uses
  FMX.Forms,
  MarkdownPad.Workspace.Interfaces in '..\Shared\MarkdownPad.Workspace.Interfaces.pas',
  MarkdownPad.Workspace in '..\Shared\MarkdownPad.Workspace.pas',
  MarkdownPad.Session in '..\Shared\MarkdownPad.Session.pas',
  MarkdownPad.Commands in '..\Shared\MarkdownPad.Commands.pas',
  MarkdownPad.FileWatcher in '..\Shared\MarkdownPad.FileWatcher.pas',
  MarkdownPad.HtmlExport in '..\Shared\MarkdownPad.HtmlExport.pas',
  FmxMarkdownPad.Main in 'FmxMarkdownPad.Main.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFmxMarkdownPadForm, FmxMarkdownPadForm);
  Application.Run;
end.
