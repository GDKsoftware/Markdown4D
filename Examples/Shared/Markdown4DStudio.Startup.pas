unit Markdown4DStudio.Startup;

interface

type
  TStudioStartup = class
  public
    class procedure ConfigureMarkdown;
  end;

implementation

uses
  Markdown4D;

class procedure TStudioStartup.ConfigureMarkdown;
begin
  TMarkdown.FrontMatterEnabled := True;
end;

end.
