program MarkdownPad;

uses
  Vcl.Forms,
  MarkdownPad.Main in 'MarkdownPad.Main.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMarkdownPadForm, MarkdownPadForm);
  Application.Run;
end.
