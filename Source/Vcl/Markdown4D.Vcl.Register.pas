unit Markdown4D.Vcl.Register;

interface

procedure Register;

implementation

uses
  System.Classes,
  Markdown4D.Vcl.Viewer,
  Markdown4D.Vcl.Editor;

procedure Register;
begin
  RegisterComponents('Markdown4D', [TMarkdownViewer, TMarkdownEditor]);
end;

end.
