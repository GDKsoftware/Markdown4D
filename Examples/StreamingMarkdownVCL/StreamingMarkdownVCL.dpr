program StreamingMarkdownVCL;

uses
  Vcl.Forms,
  Markdown4D.Vcl.MathFont,
  StreamingMarkdown.Demo in '..\Shared\StreamingMarkdown.Demo.pas',
  StreamingMarkdownVCL.Main in 'StreamingMarkdownVCL.Main.pas' {StreamingMarkdownVCLForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TStreamingMarkdownVCLForm, StreamingMarkdownVCLForm);
  Application.Run;
end.
