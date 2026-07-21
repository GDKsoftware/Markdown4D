unit MarkdownPad.FileWatcher;

{$SCOPEDENUMS ON}

interface

uses
  MarkdownPad.Workspace.Interfaces;

type
  TPadFileChangedNotify = procedure(const Document: IPadDocument) of object;

  TPadFileWatcher = class
  strict private
    FWorkspace: IPadWorkspace;
    FOnFileChanged: TPadFileChangedNotify;
    class function TryReadTimestamp(const FileName: string; out Value: TDateTime): Boolean; static;

  public
    constructor Create(const Workspace: IPadWorkspace; const OnFileChanged: TPadFileChangedNotify);
    procedure Poll;
    procedure Reset(const Document: IPadDocument);
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

constructor TPadFileWatcher.Create(const Workspace: IPadWorkspace; const OnFileChanged: TPadFileChangedNotify);
begin
  inherited Create;

  FWorkspace := Workspace;
  FOnFileChanged := OnFileChanged;
end;

procedure TPadFileWatcher.Poll;
begin
  for var Index := 0 to FWorkspace.Count - 1 do
  begin
    const Document = FWorkspace.Documents[Index];

    if Document.IsUntitled then
      Continue;

    var Timestamp: TDateTime;
    if not TryReadTimestamp(Document.FileName, Timestamp) then
      Continue;

    if Timestamp <> Document.DiskTimestampUtc then
    begin
      Document.DiskTimestampUtc := Timestamp;

      if Assigned(FOnFileChanged) then
        FOnFileChanged(Document);
    end;
  end;
end;

procedure TPadFileWatcher.Reset(const Document: IPadDocument);
begin
  var Timestamp: TDateTime;
  if TryReadTimestamp(Document.FileName, Timestamp) then
    Document.DiskTimestampUtc := Timestamp
  else
    Document.DiskTimestampUtc := 0;
end;

class function TPadFileWatcher.TryReadTimestamp(const FileName: string; out Value: TDateTime): Boolean;
begin
  Value := 0;

  if (FileName = '') or not TFile.Exists(FileName) then
    Exit(False);

  try
    Value := TFile.GetLastWriteTimeUtc(FileName);
    Result := True;
  except
    Result := False;
  end;
end;

end.
