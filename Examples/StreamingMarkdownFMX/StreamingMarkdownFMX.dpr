program StreamingMarkdownFMX;

uses
  FMX.Forms,
  Markdown4D.Fmx.MathFont,
  StreamingMarkdown.Demo in '..\Shared\StreamingMarkdown.Demo.pas',
  StreamingMarkdownFMX.Main in 'StreamingMarkdownFMX.Main.pas' {StreamingMarkdownFMXForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TStreamingMarkdownFMXForm, StreamingMarkdownFMXForm);
  Application.Run;
end.
