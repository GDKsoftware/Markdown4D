program Markdown4DStudioFMX;

uses
  FMX.Forms,
  FMX.Skia,
  Markdown4DStudio.Workspace.Interfaces in '..\Shared\Markdown4DStudio.Workspace.Interfaces.pas',
  Markdown4DStudio.Workspace in '..\Shared\Markdown4DStudio.Workspace.pas',
  Markdown4DStudio.Session in '..\Shared\Markdown4DStudio.Session.pas',
  Markdown4DStudio.Commands in '..\Shared\Markdown4DStudio.Commands.pas',
  Markdown4DStudio.TabStrip.Layout in '..\Shared\Markdown4DStudio.TabStrip.Layout.pas',
  Markdown4DStudio.TabStrip.Interaction in '..\Shared\Markdown4DStudio.TabStrip.Interaction.pas',
  Markdown4DStudio.Fmx.TabStrip in '..\Shared\Markdown4DStudio.Fmx.TabStrip.pas',
  Markdown4DStudio.Fmx.WinFrame in '..\Shared\Markdown4DStudio.Fmx.WinFrame.pas',
  Markdown4DStudio.FileWatcher in '..\Shared\Markdown4DStudio.FileWatcher.pas',
  Markdown4DStudio.HtmlExport in '..\Shared\Markdown4DStudio.HtmlExport.pas',
  Markdown4DStudio.LinkPolicy in '..\Shared\Markdown4DStudio.LinkPolicy.pas',
  Markdown4DStudio.CommandSet in '..\Shared\Markdown4DStudio.CommandSet.pas',
  Markdown4DStudio.SessionSync in '..\Shared\Markdown4DStudio.SessionSync.pas',
  Markdown4DStudioFMX.Main in 'Markdown4DStudioFMX.Main.pas',
  Markdown4DStudio.Defines in '..\Shared\Markdown4DStudio.Defines.pas',
  Markdown4DStudio.Text in '..\Shared\Markdown4DStudio.Text.pas',
  Markdown4DStudio.Outline in '..\Shared\Markdown4DStudio.Outline.pas',
  Markdown4DStudioFMX.Defines in 'Markdown4DStudioFMX.Defines.pas',
  Markdown4DStudio.Shell in '..\Shared\Markdown4DStudio.Shell.pas',
  Markdown4DStudio.CommandLine in '..\Shared\Markdown4DStudio.CommandLine.pas',
  Markdown4DStudio.SingleInstance in '..\Shared\Markdown4DStudio.SingleInstance.pas',
  Markdown4DStudio.Controller in '..\Shared\Markdown4DStudio.Controller.pas';

{$R *.res}

begin
  if TPadSingleInstance.TryHandOff(StudioInstanceChannelFmx, TPadCommandLine.DocumentPath) then
    Exit;

  // Render through Skia so the editor's source text is crisp on Windows; unlike the
  // GDI+ canvas, Skia keeps accurate text metrics (gutter, caret, selection).
  GlobalUseSkia := True;

  Application.Initialize;
  Application.CreateForm(TMarkdown4DStudioFMXForm, Markdown4DStudioFMXForm);
  Application.Run;
end.
