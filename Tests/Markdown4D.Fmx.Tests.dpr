program Markdown4D.Fmx.Tests;

{$APPTYPE CONSOLE}

{$STRONGLINKTYPES ON}

uses
  Markdown4D.Fmx.Painter in '..\Source\Fmx\Markdown4D.Fmx.Painter.pas',
  Markdown4D.Fmx.Viewer in '..\Source\Fmx\Markdown4D.Fmx.Viewer.pas',
  Markdown4D.Fmx.Render.Tests in 'Markdown4D.Fmx.Render.Tests.pas',
  Markdown4D.Fmx.Viewer.Tests in 'Markdown4D.Fmx.Viewer.Tests.pas',
  Markdown4D.Fmx.Wedge.Tests in 'Markdown4D.Fmx.Wedge.Tests.pas',
  Markdown4D.Fmx.Polygon.Tests in 'Markdown4D.Fmx.Polygon.Tests.pas',
  Markdown4D.Fmx.Editor in '..\Source\Fmx\Markdown4D.Fmx.Editor.pas',
  Markdown4D.Fmx.Editor.Tests in 'Markdown4D.Fmx.Editor.Tests.pas',
  Markdown4D.Tests.FmxClipboard in 'Markdown4D.Tests.FmxClipboard.pas',
  Markdown4D.Fmx.Design.Tests in 'Markdown4D.Fmx.Design.Tests.pas',
  Markdown4D.Tests.Pipeline.Helpers in 'Markdown4D.Tests.Pipeline.Helpers.pas',
  Markdown4D.Tests.FailingExtensions in 'Markdown4D.Tests.FailingExtensions.pas',
  Markdown4D.Tests.Fmx.BitmapHelpers in 'Markdown4D.Tests.Fmx.BitmapHelpers.pas',
  Markdown4D.Tests.PdfReader in 'Markdown4D.Tests.PdfReader.pas',
  Markdown4D.Fmx.PdfRasterizer in '..\Source\Fmx\Markdown4D.Fmx.PdfRasterizer.pas',
  Markdown4D.Fmx.PdfRasterizer.Tests in 'Markdown4D.Fmx.PdfRasterizer.Tests.pas',
  Markdown4D.Tests.Arrays in 'Markdown4D.Tests.Arrays.pas',
  Markdown4D.Tests.Runner in 'Markdown4D.Tests.Runner.pas';

begin
  TMarkdownTestRunner.Run('dunitx-fmx-results.xml');
end.
