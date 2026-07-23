program StreamingMarkdownFMX;

uses
  FMX.Forms,
  StreamingMarkdownFMX.Main in 'StreamingMarkdownFMX.Main.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TStreamingMarkdownFMXForm, StreamingMarkdownFMXForm);
  Application.Run;
end.
