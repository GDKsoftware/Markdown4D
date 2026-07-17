unit Markdown4D.Fmx.Register;

interface

procedure Register;

implementation

uses
  System.Classes,
  Markdown4D.Fmx.Viewer,
  Markdown4D.Fmx.Editor;

procedure Register;
begin
  RegisterComponents('Markdown4D', [TMarkdownViewer, TMarkdownEditor]);
end;

end.
