program FmxLlmChat;

uses
  FMX.Forms,
  FmxLlmChat.Main in 'FmxLlmChat.Main.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFmxLlmChatForm, FmxLlmChatForm);
  Application.Run;
end.
