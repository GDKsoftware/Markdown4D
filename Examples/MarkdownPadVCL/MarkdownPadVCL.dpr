program MarkdownPadVCL;

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
  MarkdownPad.CommandSet in '..\Shared\MarkdownPad.CommandSet.pas',
  MarkdownPad.SessionSync in '..\Shared\MarkdownPad.SessionSync.pas',
  MarkdownPadVCL.Main in 'MarkdownPadVCL.Main.pas' {MarkdownPadVCLForm},
  MarkdownPad.Defines in '..\Shared\MarkdownPad.Defines.pas',
  MarkdownPad.Text in '..\Shared\MarkdownPad.Text.pas',
  MarkdownPad.Outline in '..\Shared\MarkdownPad.Outline.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMarkdownPadVCLForm, MarkdownPadVCLForm);
  Application.Run;
end.
