program StreamingMarkdownFMX;

uses
  FMX.Forms,
  StreamingMarkdown.Demo in '..\Shared\StreamingMarkdown.Demo.pas',
  StreamingMarkdownFMX.Main in 'StreamingMarkdownFMX.Main.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TStreamingMarkdownFMXForm, StreamingMarkdownFMXForm);
  Application.Run;
end.
