program Markdown4DStudioVCL;

uses
  Vcl.Forms,
  Markdown4DStudio.Workspace.Interfaces in '..\Shared\Markdown4DStudio.Workspace.Interfaces.pas',
  Markdown4DStudio.Workspace in '..\Shared\Markdown4DStudio.Workspace.pas',
  Markdown4DStudio.Session in '..\Shared\Markdown4DStudio.Session.pas',
  Markdown4DStudio.Commands in '..\Shared\Markdown4DStudio.Commands.pas',
  Markdown4DStudio.TabStrip.Layout in '..\Shared\Markdown4DStudio.TabStrip.Layout.pas',
  Markdown4DStudio.TabStrip.Interaction in '..\Shared\Markdown4DStudio.TabStrip.Interaction.pas',
  Markdown4DStudio.TabStrip in '..\Shared\Markdown4DStudio.TabStrip.pas',
  Markdown4DStudio.FileWatcher in '..\Shared\Markdown4DStudio.FileWatcher.pas',
  Markdown4DStudio.HtmlExport in '..\Shared\Markdown4DStudio.HtmlExport.pas',
  Markdown4DStudio.LinkPolicy in '..\Shared\Markdown4DStudio.LinkPolicy.pas',
  Markdown4DStudio.CommandSet in '..\Shared\Markdown4DStudio.CommandSet.pas',
  Markdown4DStudio.SessionSync in '..\Shared\Markdown4DStudio.SessionSync.pas',
  Markdown4DStudioVCL.Main in 'Markdown4DStudioVCL.Main.pas' {Markdown4DStudioVCLForm},
  Markdown4DStudio.Defines in '..\Shared\Markdown4DStudio.Defines.pas',
  Markdown4DStudio.Text in '..\Shared\Markdown4DStudio.Text.pas',
  Markdown4DStudio.Outline in '..\Shared\Markdown4DStudio.Outline.pas',
  Markdown4DStudioVCL.Defines in 'Markdown4DStudioVCL.Defines.pas',
  Markdown4DStudio.Shell in '..\Shared\Markdown4DStudio.Shell.pas',
  Markdown4DStudio.CommandLine in '..\Shared\Markdown4DStudio.CommandLine.pas',
  Markdown4DStudio.SingleInstance in '..\Shared\Markdown4DStudio.SingleInstance.pas',
  Markdown4DStudio.Controller in '..\Shared\Markdown4DStudio.Controller.pas';

{$R *.res}

begin
  if TPadSingleInstance.TryHandOff(StudioInstanceChannelVcl, TPadCommandLine.DocumentPath) then
    Exit;

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMarkdown4DStudioVCLForm, Markdown4DStudioVCLForm);
  Application.Run;
end.
