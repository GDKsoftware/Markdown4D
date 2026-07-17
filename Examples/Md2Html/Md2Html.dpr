program Md2Html;

{$APPTYPE CONSOLE}

uses
  Md2Html.Runner in 'Md2Html.Runner.pas';

{$R *.res}

begin
  ExitCode := TMd2HtmlRunner.Run;
end.
