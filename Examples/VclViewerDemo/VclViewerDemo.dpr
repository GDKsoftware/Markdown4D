program VclViewerDemo;

uses
  Vcl.Forms,
  VclViewerDemo.Main in 'VclViewerDemo.Main.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TVclViewerDemoForm, VclViewerDemoForm);
  Application.Run;
end.
