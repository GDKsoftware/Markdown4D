program FmxViewerDemo;

uses
  FMX.Forms,
  FmxViewerDemo.Main in 'FmxViewerDemo.Main.pas',
  FmxViewerDemo.Browser in 'FmxViewerDemo.Browser.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFmxViewerDemoForm, FmxViewerDemoForm);
  Application.Run;
end.
