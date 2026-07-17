program Markdown4D.Fmx.Tests;

{$APPTYPE CONSOLE}

{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  Markdown4D.Fmx.Painter in '..\Source\Fmx\Markdown4D.Fmx.Painter.pas',
  Markdown4D.Fmx.Viewer in '..\Source\Fmx\Markdown4D.Fmx.Viewer.pas',
  Markdown4D.Fmx.Render.Tests in 'Markdown4D.Fmx.Render.Tests.pas',
  Markdown4D.Fmx.Viewer.Tests in 'Markdown4D.Fmx.Viewer.Tests.pas',
  Markdown4D.Fmx.Wedge.Tests in 'Markdown4D.Fmx.Wedge.Tests.pas',
  Markdown4D.Fmx.Polygon.Tests in 'Markdown4D.Fmx.Polygon.Tests.pas',
  Markdown4D.Fmx.Editor in '..\Source\Fmx\Markdown4D.Fmx.Editor.pas',
  Markdown4D.Fmx.Editor.Tests in 'Markdown4D.Fmx.Editor.Tests.pas',
  Markdown4D.Fmx.Design.Tests in 'Markdown4D.Fmx.Design.Tests.pas';

const
  TestsFolderName = 'Tests';
  ResultsFolderName = 'results';
  ResultsFileName = 'dunitx-fmx-results.xml';

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
