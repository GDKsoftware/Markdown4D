program LlmChat;

uses
  Vcl.Forms,
  LlmChat.Main in 'LlmChat.Main.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TLlmChatForm, LlmChatForm);
  Application.Run;
end.
