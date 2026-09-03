unit Markdown4DStudio.FileWatcher;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4DStudio.Workspace.Interfaces;

type
  TPadFileChangedNotify = procedure(const Document: IPadDocument) of object;

  TPadFileWatcher = class
  strict private
    FWorkspace: IPadWorkspace;
    FOnFileChanged: TPadFileChangedNotify;
    FOnFileVanished: TPadFileChangedNotify;
    procedure PollDocument(const Document: IPadDocument);
    class function TryReadTimestamp(const FileName: string; out Value: TDateTime): Boolean; static;

  public
    constructor Create(const Workspace: IPadWorkspace; const OnFileChanged: TPadFileChangedNotify;
      const OnFileVanished: TPadFileChangedNotify);
    procedure Poll;
    procedure Reset(const Document: IPadDocument);
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

constructor TPadFileWatcher.Create(const Workspace: IPadWorkspace; const OnFileChanged: TPadFileChangedNotify;
  const OnFileVanished: TPadFileChangedNotify);
begin
  inherited Create;

  FWorkspace := Workspace;
  FOnFileChanged := OnFileChanged;
  FOnFileVanished := OnFileVanished;
end;

procedure TPadFileWatcher.Poll;
begin
  for var Index := 0 to FWorkspace.Count - 1 do
  begin
    const Document = FWorkspace.Documents[Index];

    if not Document.IsUntitled then
      PollDocument(Document);
  end;
end;

procedure TPadFileWatcher.PollDocument(const Document: IPadDocument);
begin
  var Timestamp: TDateTime;
  if not TryReadTimestamp(Document.FileName, Timestamp) then
  begin
    const JustVanished = not Document.DiskMissing;
    if JustVanished then
    begin
      Document.DiskMissing := True;

      if Assigned(FOnFileVanished) then
        FOnFileVanished(Document);
    end;

    Exit;
  end;

  const Reappeared = Document.DiskMissing;
  if Reappeared then
    Document.DiskMissing := False;

  if Timestamp <> Document.DiskTimestampUtc then
  begin
    Document.DiskTimestampUtc := Timestamp;

    if Assigned(FOnFileChanged) then
      FOnFileChanged(Document);
  end;
end;

procedure TPadFileWatcher.Reset(const Document: IPadDocument);
begin
  var Timestamp: TDateTime;
  if TryReadTimestamp(Document.FileName, Timestamp) then
  begin
    Document.DiskTimestampUtc := Timestamp;
    Document.DiskMissing := False;
    Exit;
  end;

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
