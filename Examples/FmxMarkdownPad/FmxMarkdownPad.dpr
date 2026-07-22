program FmxMarkdownPad;

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
  FmxMarkdownPad.Main in 'FmxMarkdownPad.Main.pas';

{$R *.res}

begin
  // Render through Skia so the editor's source text is crisp on Windows; unlike the
  // GDI+ canvas, Skia keeps accurate text metrics (gutter, caret, selection).
  GlobalUseSkia := True;

  Application.Initialize;
  Application.CreateForm(TFmxMarkdownPadForm, FmxMarkdownPadForm);
  Application.Run;
end.
