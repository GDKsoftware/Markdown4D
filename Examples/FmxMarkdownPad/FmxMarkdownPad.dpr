program FmxMarkdownPad;

uses
  FMX.Forms,
  FmxMarkdownPad.Main in 'FmxMarkdownPad.Main.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFmxMarkdownPadForm, FmxMarkdownPadForm);
  Application.Run;
end.
