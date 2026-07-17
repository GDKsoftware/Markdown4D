program Markdown4D.Benchmarks;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Markdown4D.Benchmarks.Scenarios in 'Markdown4D.Benchmarks.Scenarios.pas';

begin
  try
    TBenchmarkScenarios.RunAll;

    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln(Format('%s: %s', [E.ClassName, E.Message]));
      ExitCode := 1;
    end;
  end;
end.
