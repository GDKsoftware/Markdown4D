unit MarkdownPad.SessionSync;

{$SCOPEDENUMS ON}

// Framework-neutral glue between the workspace and the persisted session,
// shared by the MarkdownPad forms. These helpers touch only the workspace and
// the session; the live editor and preview state (SwitchToDocument) stays in
// each form because it is bound to the concrete VCL/FMX controls.

interface

uses
  MarkdownPad.Workspace.Interfaces,
  MarkdownPad.Session;

type
  TPadSessionSync = record
    // Opens every still-existing file from the session into the workspace and
    // activates the session's active document (or the first). Returns True when
    // the workspace holds at least one document; False means it stayed empty
    // and the caller should create a starter document.
    class function RestoreOpenFiles(const Workspace: IPadWorkspace;
      const Session: TPadSession): Boolean; static;

    // The titled (saved-to-disk) file names in workspace order, plus the active
    // document's index within that filtered list (-1 when the active document
    // is untitled).
    class function CollectOpenFiles(const Workspace: IPadWorkspace;
      out ActiveIndex: Integer): TArray<string>; static;

    // Tab captions and modified flags for every document, in order.
    class procedure CollectTabs(const Workspace: IPadWorkspace;
      out Captions: TArray<string>; out Modified: TArray<Boolean>); static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  MarkdownPad.Defines;

class function TPadSessionSync.RestoreOpenFiles(const Workspace: IPadWorkspace;
  const Session: TPadSession): Boolean;
begin
  var ActivePath := '';
  if (Session.ActiveIndex >= 0) and (Session.ActiveIndex <= High(Session.OpenFiles)) then
    ActivePath := Session.OpenFiles[Session.ActiveIndex];

  for var FileName in Session.OpenFiles do
  begin
    if not TFile.Exists(FileName) then
      Continue;

    try
      Workspace.OpenFile(FileName);
    except
      // A file that fails to open is skipped; the rest of the session restores.
    end;
  end;

  Result := Workspace.Count > 0;
  if not Result then
    Exit;

  var Target := 0;
  if ActivePath <> '' then
  begin
    const Found = Workspace.IndexOfFile(ActivePath);
    if Found >= 0 then
      Target := Found;
  end;

  Workspace.Activate(Target);
end;

class function TPadSessionSync.CollectOpenFiles(const Workspace: IPadWorkspace;
  out ActiveIndex: Integer): TArray<string>;
begin
  Result := [];
  ActiveIndex := -1;

  for var Index := 0 to Workspace.Count - 1 do
  begin
    const Document = Workspace.Documents[Index];
    if Document.IsUntitled then
      Continue;

    if Index = Workspace.ActiveIndex then
      ActiveIndex := Length(Result);

    Result := Result + [Document.FileName];
  end;
end;

class procedure TPadSessionSync.CollectTabs(const Workspace: IPadWorkspace;
  out Captions: TArray<string>; out Modified: TArray<Boolean>);
begin
  Captions := [];
  Modified := [];

  for var Index := 0 to Workspace.Count - 1 do
  begin
    const Document = Workspace.Documents[Index];

    var Caption := Document.DisplayName;

    if Document.DiskConflict then
      Caption := Caption + ConflictMarker;

    if Document.DiskMissing then
      Caption := Caption + MissingMarker;

    Captions := Captions + [Caption];
    Modified := Modified + [Document.Modified];
  end;
end;

end.
