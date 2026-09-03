unit Markdown4DStudio.CommandLine;

// Reads the document the shell asks the studio to open. When the studio is registered
// as the handler for .md, Explorer starts it with the file as a parameter; the
// same path is used by "Open with" and by dragging a file onto the executable.

interface

type
  TPadCommandLine = record
    // The first parameter naming an existing file, expanded to a full path so
    // it matches the workspace's file lookup. Empty when the studio was started
    // without a document (plain launch, or the path no longer exists).
    class function DocumentPath: string; static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

class function TPadCommandLine.DocumentPath: string;
begin
  for var Index := 1 to ParamCount do
  begin
    const Parameter = ParamStr(Index);

    if TFile.Exists(Parameter) then
      Exit(TPath.GetFullPath(Parameter));
  end;

  Result := '';
end;

end.
