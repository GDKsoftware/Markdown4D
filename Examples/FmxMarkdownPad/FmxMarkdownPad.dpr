program FmxMarkdownPad;

uses
  FMX.Forms,
  FMX.Types,
  MarkdownPad.Workspace.Interfaces in '..\Shared\MarkdownPad.Workspace.Interfaces.pas',
  MarkdownPad.Workspace in '..\Shared\MarkdownPad.Workspace.pas',
  MarkdownPad.Session in '..\Shared\MarkdownPad.Session.pas',
  MarkdownPad.Commands in '..\Shared\MarkdownPad.Commands.pas',
  MarkdownPad.TabStrip.Layout in '..\Shared\MarkdownPad.TabStrip.Layout.pas',
  MarkdownPad.Fmx.TabStrip in '..\Shared\MarkdownPad.Fmx.TabStrip.pas',
  MarkdownPad.Fmx.WinFrame in '..\Shared\MarkdownPad.Fmx.WinFrame.pas',
  MarkdownPad.FileWatcher in '..\Shared\MarkdownPad.FileWatcher.pas',
  MarkdownPad.HtmlExport in '..\Shared\MarkdownPad.HtmlExport.pas',
  FmxMarkdownPad.Main in 'FmxMarkdownPad.Main.pas';

{$R *.res}

begin
  // Use the GDI+ canvas (with ClearType) instead of Direct2D so the editor's source
  // text renders as crisply as the VCL version; Direct2D falls back to softer greyscale.
  GlobalUseDirect2D := False;
  GlobalUseGDIPlusClearType := True;

  Application.Initialize;
  Application.CreateForm(TFmxMarkdownPadForm, FmxMarkdownPadForm);
  Application.Run;
end.
