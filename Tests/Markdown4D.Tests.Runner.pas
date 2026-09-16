unit Markdown4D.Tests.Runner;

interface

type
  TMarkdownTestRunner = class
  public
    class procedure Run(const ResultsFileName: string);
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit;

class procedure TMarkdownTestRunner.Run(const ResultsFileName: string);
const
  TestsFolderName = 'Tests';
  ResultsFolderName = 'results';
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
    on E: System.SysUtils.Exception do
    begin
      System.Writeln(System.SysUtils.Format('%s: %s', [E.ClassName, E.Message]));
      ExitCode := 1;
    end;
  end;
end;

end.
