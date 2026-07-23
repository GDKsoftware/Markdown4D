program StreamingMarkdownVCL;

uses
  Vcl.Forms,
  StreamingMarkdownVCL.Main in 'StreamingMarkdownVCL.Main.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TStreamingMarkdownVCLForm, StreamingMarkdownVCLForm);
  Application.Run;
end.
