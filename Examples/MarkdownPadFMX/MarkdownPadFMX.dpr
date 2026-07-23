program MarkdownPadFMX;

uses
  FMX.Forms,
  FMX.Skia,
  MarkdownPad.Workspace.Interfaces in '..\Shared\MarkdownPad.Workspace.Interfaces.pas',
  MarkdownPad.Workspace in '..\Shared\MarkdownPad.Workspace.pas',
  MarkdownPad.Session in '..\Shared\MarkdownPad.Session.pas',
  MarkdownPad.Commands in '..\Shared\MarkdownPad.Commands.pas',
  MarkdownPad.TabStrip.Layout in '..\Shared\MarkdownPad.TabStrip.Layout.pas',
  MarkdownPad.TabStrip.Interaction in '..\Shared\MarkdownPad.TabStrip.Interaction.pas',
  MarkdownPad.Fmx.TabStrip in '..\Shared\MarkdownPad.Fmx.TabStrip.pas',
  MarkdownPad.Fmx.WinFrame in '..\Shared\MarkdownPad.Fmx.WinFrame.pas',
  MarkdownPad.FileWatcher in '..\Shared\MarkdownPad.FileWatcher.pas',
  MarkdownPad.HtmlExport in '..\Shared\MarkdownPad.HtmlExport.pas',
  MarkdownPad.CommandSet in '..\Shared\MarkdownPad.CommandSet.pas',
  MarkdownPad.SessionSync in '..\Shared\MarkdownPad.SessionSync.pas',
  MarkdownPadFMX.Main in 'MarkdownPadFMX.Main.pas',
  MarkdownPad.Defines in '..\Shared\MarkdownPad.Defines.pas',
  MarkdownPad.Text in '..\Shared\MarkdownPad.Text.pas',
  MarkdownPad.Outline in '..\Shared\MarkdownPad.Outline.pas';

{$R *.res}

begin
  // Render through Skia so the editor's source text is crisp on Windows; unlike the
  // GDI+ canvas, Skia keeps accurate text metrics (gutter, caret, selection).
  GlobalUseSkia := True;

  Application.Initialize;
  Application.CreateForm(TMarkdownPadFMXForm, MarkdownPadFMXForm);
  Application.Run;
end.
