program Markdown4D.Tests;

{$APPTYPE CONSOLE}

{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  Markdown4D.Parser.Spec.Tests in 'Markdown4D.Parser.Spec.Tests.pas',
  Markdown4D.Parser.Gfm.Tests in 'Markdown4D.Parser.Gfm.Tests.pas',
  Markdown4D.Writer.RoundTrip.Tests in 'Markdown4D.Writer.RoundTrip.Tests.pas',
  Markdown4D.Writer.Canonical.Tests in 'Markdown4D.Writer.Canonical.Tests.pas',
  Markdown4D.Ast.Builder.Tests in 'Markdown4D.Ast.Builder.Tests.pas',
  Markdown4D.Parser.Incremental.Tests in 'Markdown4D.Parser.Incremental.Tests.pas',
  Markdown4D.Pipeline.Tests in 'Markdown4D.Pipeline.Tests.pas',
  Markdown4D.Extensions.Sample.Tests in 'Markdown4D.Extensions.Sample.Tests.pas',
  Markdown4D.Toc.Tests in 'Markdown4D.Toc.Tests.pas',
  Markdown4D.Renderer.Options.Tests in 'Markdown4D.Renderer.Options.Tests.pas',
  Markdown4D.Benchmarks.Scenarios in 'Markdown4D.Benchmarks.Scenarios.pas',
  Markdown4D.Performance.Tests in 'Markdown4D.Performance.Tests.pas',
  Markdown4D.Layout.FakeMeasurer in 'Markdown4D.Layout.FakeMeasurer.pas',
  Markdown4D.Layout.Engine.Tests in 'Markdown4D.Layout.Engine.Tests.pas',
  Markdown4D.Html.Subset.Tests in 'Markdown4D.Html.Subset.Tests.pas',
  Markdown4D.Layout.HitTest.Tests in 'Markdown4D.Layout.HitTest.Tests.pas',
  Markdown4D.Layout.Renderer.Tests in 'Markdown4D.Layout.Renderer.Tests.pas',
  Markdown4D.Theme.Tests in 'Markdown4D.Theme.Tests.pas',
  Markdown4D.Image.Rasterizer.Tests in 'Markdown4D.Image.Rasterizer.Tests.pas',
  Markdown4D.Image.Filters.Tests in 'Markdown4D.Image.Filters.Tests.pas',
  Markdown4D.Image.Svg.Xml.Tests in 'Markdown4D.Image.Svg.Xml.Tests.pas',
  Markdown4D.Image.Svg.Path.Tests in 'Markdown4D.Image.Svg.Path.Tests.pas',
  Markdown4D.Image.Svg.Native.Tests in 'Markdown4D.Image.Svg.Native.Tests.pas',
  Markdown4D.Layout.Incremental.Tests in 'Markdown4D.Layout.Incremental.Tests.pas',
  Markdown4D.Highlighter.Tests in 'Markdown4D.Highlighter.Tests.pas',
  Markdown4D.Viewer.Model.Tests in 'Markdown4D.Viewer.Model.Tests.pas',
  Markdown4D.Viewer.ContextMenu in '..\Source\Layout\Markdown4D.Viewer.ContextMenu.pas',
  Markdown4D.Viewer.ContextMenu.Tests in 'Markdown4D.Viewer.ContextMenu.Tests.pas',
  Markdown4D.Viewer.ScrollBar.Tests in 'Markdown4D.Viewer.ScrollBar.Tests.pas',
  Markdown4DStudio.SingleInstance in '..\Examples\Shared\Markdown4DStudio.SingleInstance.pas',
  Markdown4DStudio.SingleInstance.Tests in 'Markdown4DStudio.SingleInstance.Tests.pas',
  Markdown4D.Vcl.Render.Tests in 'Markdown4D.Vcl.Render.Tests.pas',
  Markdown4D.Vcl.Viewer.Tests in 'Markdown4D.Vcl.Viewer.Tests.pas',
  Markdown4D.Vcl.Image.Tests in 'Markdown4D.Vcl.Image.Tests.pas',
  Markdown4D.Charts.Corpus in 'Markdown4D.Charts.Corpus.pas',
  Markdown4D.Extensions.Chart.Tests in 'Markdown4D.Extensions.Chart.Tests.pas',
  Markdown4D.Extensions.Chart.Layout.Tests in 'Markdown4D.Extensions.Chart.Layout.Tests.pas',
  Markdown4D.Mermaid.Corpus in 'Markdown4D.Mermaid.Corpus.pas',
  Markdown4D.Extensions.Mermaid.Tests in 'Markdown4D.Extensions.Mermaid.Tests.pas',
  Markdown4D.Extensions.Mermaid.Layout.Tests in 'Markdown4D.Extensions.Mermaid.Layout.Tests.pas',
  Markdown4D.Extensions.Api.Tests in 'Markdown4D.Extensions.Api.Tests.pas',
  Markdown4D.Extensions.V11.Tests in 'Markdown4D.Extensions.V11.Tests.pas',
  Markdown4D.Extensions.Admonition.Tests in 'Markdown4D.Extensions.Admonition.Tests.pas',
  Markdown4D.Viewer.Extensions.Cluster1.Tests in 'Markdown4D.Viewer.Extensions.Cluster1.Tests.pas',
  Markdown4D.Vcl.Wedge.Tests in 'Markdown4D.Vcl.Wedge.Tests.pas',
  Markdown4D.Vcl.Polygon.Tests in 'Markdown4D.Vcl.Polygon.Tests.pas',
  Markdown4D.Editor.Keys in '..\Source\Layout\Markdown4D.Editor.Keys.pas',
  Markdown4D.Editor.Actions in '..\Source\Layout\Markdown4D.Editor.Actions.pas',
  Markdown4D.Editor.ContextMenu in '..\Source\Layout\Markdown4D.Editor.ContextMenu.pas',
  Markdown4D.Editor.Highlights in '..\Source\Layout\Markdown4D.Editor.Highlights.pas',
  Markdown4D.Editor.Model.Tests in 'Markdown4D.Editor.Model.Tests.pas',
  Markdown4D.Editor.Keys.Tests in 'Markdown4D.Editor.Keys.Tests.pas',
  Markdown4D.Editor.Actions.Tests in 'Markdown4D.Editor.Actions.Tests.pas',
  Markdown4D.Editor.ContextMenu.Tests in 'Markdown4D.Editor.ContextMenu.Tests.pas',
  Markdown4D.Editor.Highlights.Tests in 'Markdown4D.Editor.Highlights.Tests.pas',
  Markdown4D.Editor.Folding.Tests in 'Markdown4D.Editor.Folding.Tests.pas',
  Markdown4D.Editor.Highlighter.Tests in 'Markdown4D.Editor.Highlighter.Tests.pas',
  Markdown4D.Editor.Sync.Tests in 'Markdown4D.Editor.Sync.Tests.pas',
  Markdown4D.Vcl.Editor.Tests in 'Markdown4D.Vcl.Editor.Tests.pas',
  Markdown4D.Editor.Performance.Tests in 'Markdown4D.Editor.Performance.Tests.pas',
  Markdown4D.Vcl.Design.Tests in 'Markdown4D.Vcl.Design.Tests.pas',
  Markdown4D.Text.FileFormat in '..\Source\Core\Markdown4D.Text.FileFormat.pas',
  Markdown4D.Text.FileFormat.Tests in 'Markdown4D.Text.FileFormat.Tests.pas',
  Markdown4DStudio.Workspace.Interfaces in '..\Examples\Shared\Markdown4DStudio.Workspace.Interfaces.pas',
  Markdown4DStudio.Workspace in '..\Examples\Shared\Markdown4DStudio.Workspace.pas',
  Markdown4DStudio.Session in '..\Examples\Shared\Markdown4DStudio.Session.pas',
  Markdown4DStudio.Commands in '..\Examples\Shared\Markdown4DStudio.Commands.pas',
  Markdown4DStudio.CommandSet in '..\Examples\Shared\Markdown4DStudio.CommandSet.pas',
  Markdown4DStudio.SessionSync in '..\Examples\Shared\Markdown4DStudio.SessionSync.pas',
  Markdown4DStudio.TabStrip.Layout in '..\Examples\Shared\Markdown4DStudio.TabStrip.Layout.pas',
  Markdown4DStudio.TabStrip.Interaction in '..\Examples\Shared\Markdown4DStudio.TabStrip.Interaction.pas',
  Markdown4DStudio.TabStrip in '..\Examples\Shared\Markdown4DStudio.TabStrip.pas',
  Markdown4DStudio.FileWatcher in '..\Examples\Shared\Markdown4DStudio.FileWatcher.pas',
  Markdown4DStudio.HtmlExport in '..\Examples\Shared\Markdown4DStudio.HtmlExport.pas',
  Markdown4DStudio.LinkPolicy in '..\Examples\Shared\Markdown4DStudio.LinkPolicy.pas',
  Markdown4DStudio.Defines in '..\Examples\Shared\Markdown4DStudio.Defines.pas',
  Markdown4DStudio.Text in '..\Examples\Shared\Markdown4DStudio.Text.pas',
  Markdown4DStudio.Outline in '..\Examples\Shared\Markdown4DStudio.Outline.pas',
  Markdown4DStudio.CommandLine in '..\Examples\Shared\Markdown4DStudio.CommandLine.pas',
  Markdown4DStudio.Shell in '..\Examples\Shared\Markdown4DStudio.Shell.pas',
  Markdown4DStudio.EditorView in '..\Examples\Shared\Markdown4DStudio.EditorView.pas',
  Markdown4DStudio.Controller in '..\Examples\Shared\Markdown4DStudio.Controller.pas',
  StreamingMarkdown.Demo in '..\Examples\Shared\StreamingMarkdown.Demo.pas',
  Markdown4DStudio.Workspace.Tests in 'Markdown4DStudio.Workspace.Tests.pas',
  Markdown4DStudio.TabStrip.Tests in 'Markdown4DStudio.TabStrip.Tests.pas',
  Markdown4DStudio.Session.Tests in 'Markdown4DStudio.Session.Tests.pas',
  Markdown4DStudio.Commands.Tests in 'Markdown4DStudio.Commands.Tests.pas',
  Markdown4DStudio.CommandSet.Tests in 'Markdown4DStudio.CommandSet.Tests.pas',
  Markdown4DStudio.SessionSync.Tests in 'Markdown4DStudio.SessionSync.Tests.pas',
  Markdown4DStudio.FileWatcher.Tests in 'Markdown4DStudio.FileWatcher.Tests.pas',
  Markdown4DStudio.Controller.Tests in 'Markdown4DStudio.Controller.Tests.pas',
  Markdown4DStudio.HtmlExport.Tests in 'Markdown4DStudio.HtmlExport.Tests.pas',
  Markdown4DStudio.LinkPolicy.Tests in 'Markdown4DStudio.LinkPolicy.Tests.pas',
  Markdown4D.Text.UrlSafety.Tests in 'Markdown4D.Text.UrlSafety.Tests.pas',
  Markdown4D.Viewer.ImageSettings.Tests in 'Markdown4D.Viewer.ImageSettings.Tests.pas',
  StreamingMarkdown.Demo.Tests in 'StreamingMarkdown.Demo.Tests.pas';

const
  TestsFolderName = 'Tests';
  ResultsFolderName = 'results';
  ResultsFileName = 'dunitx-results.xml';

begin
  try
    TDUnitX.CheckCommandLine;

    var ResultsFile := TDUnitX.Options.XMLOutputFile;
    if ResultsFile.IsEmpty then
    begin
      const ExecutableFolder = TPath.GetDirectoryName(TPath.GetFullPath(ParamStr(0)));
      var ResultsRoot := ExecutableFolder;
      var Directory := ExecutableFolder;

      while Directory <> '' do
      begin
        const CandidateTestsFolder = TPath.Combine(Directory, TestsFolderName);
        if TDirectory.Exists(CandidateTestsFolder) then
        begin
          ResultsRoot := TPath.Combine(CandidateTestsFolder, ResultsFolderName);
          Break;
        end;

        const Parent = TPath.GetDirectoryName(Directory);
        const ReachedRoot = (Parent = Directory);
        if ReachedRoot then
          Break;

        Directory := Parent;
      end;

      ResultsFile := TPath.Combine(ResultsRoot, ResultsFileName);
    end;

    const ResultsFolder = TPath.GetDirectoryName(TPath.GetFullPath(ResultsFile));
    TDirectory.CreateDirectory(ResultsFolder);

    const Runner = TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.AddLogger(TDUnitXConsoleLogger.Create(False));
    Runner.AddLogger(TDUnitXXMLNUnitFileLogger.Create(ResultsFile));

    const RunResults = Runner.Execute;
    const HasFailures = ((RunResults.FailureCount + RunResults.ErrorCount) > 0);
    if HasFailures then
      ExitCode := 1
    else
      ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln(Format('%s: %s', [E.ClassName, E.Message]));
      ExitCode := 1;
    end;
  end;
end.
