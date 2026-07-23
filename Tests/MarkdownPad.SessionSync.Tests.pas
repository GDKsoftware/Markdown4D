unit MarkdownPad.SessionSync.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  DUnitX.TestFramework,
  MarkdownPad.Workspace.Interfaces,
  MarkdownPad.Workspace,
  MarkdownPad.Session,
  MarkdownPad.SessionSync;

type
  [TestFixture]
  TPadSessionSyncTests = class
  private
    var
      FWorkspace: IPadWorkspace;
      FTempFiles: TList<string>;
    function AddTitled(const FileName: string): IPadDocument;
    function WriteTempFile(const BaseName: string): string;
    function TempPath(const BaseName: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure CollectOpenFiles_SkipsUntitled_AndRemapsActiveIndex;

    [Test]
    procedure CollectOpenFiles_ActiveUntitled_ReturnsMinusOne;

    [Test]
    procedure CollectTabs_ReturnsDisplayNamesAndModified;

    [Test]
    procedure RestoreOpenFiles_OpensExisting_SkipsMissing;

    [Test]
    procedure RestoreOpenFiles_NoneExist_ReturnsFalse;

    [Test]
    procedure RestoreOpenFiles_ActivatesSessionActivePath;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

procedure TPadSessionSyncTests.Setup;
begin
  FWorkspace := TPadWorkspace.Create;
  FTempFiles := TList<string>.Create;
end;

procedure TPadSessionSyncTests.TearDown;
begin
  for var Path in FTempFiles do
    if TFile.Exists(Path) then
      TFile.Delete(Path);

  FTempFiles.Free;
end;

function TPadSessionSyncTests.AddTitled(const FileName: string): IPadDocument;
begin
  Result := FWorkspace.NewDocument;
  Result.FileName := FileName;
end;

function TPadSessionSyncTests.TempPath(const BaseName: string): string;
begin
  Result := TPath.Combine(TPath.GetTempPath, BaseName);
end;

function TPadSessionSyncTests.WriteTempFile(const BaseName: string): string;
begin
  Result := TempPath(BaseName);
  TFile.WriteAllText(Result, '# ' + BaseName);
  FTempFiles.Add(Result);
end;

procedure TPadSessionSyncTests.CollectOpenFiles_SkipsUntitled_AndRemapsActiveIndex;
begin
  FWorkspace.NewDocument;   // untitled at index 0
  AddTitled('a.md');        // index 1
  AddTitled('b.md');        // index 2
  FWorkspace.Activate(2);

  var ActiveIndex: Integer;
  const Files = TPadSessionSync.CollectOpenFiles(FWorkspace, ActiveIndex);

  Assert.AreEqual(2, Integer(Length(Files)));
  Assert.AreEqual('a.md', Files[0]);
  Assert.AreEqual('b.md', Files[1]);
  Assert.AreEqual(1, ActiveIndex);
end;

procedure TPadSessionSyncTests.CollectOpenFiles_ActiveUntitled_ReturnsMinusOne;
begin
  AddTitled('a.md');        // index 0
  FWorkspace.NewDocument;   // untitled at index 1, now active

  var ActiveIndex: Integer;
  const Files = TPadSessionSync.CollectOpenFiles(FWorkspace, ActiveIndex);

  Assert.AreEqual(1, Integer(Length(Files)));
  Assert.AreEqual(-1, ActiveIndex);
end;

procedure TPadSessionSyncTests.CollectTabs_ReturnsDisplayNamesAndModified;
begin
  FWorkspace.NewDocument;   // untitled number 1 -> 'Untitled', index 0
  const Doc = AddTitled(TPath.Combine('C:\docs', 'note.md'));   // index 1
  Doc.Modified := True;

  var Captions: TArray<string>;
  var Modified: TArray<Boolean>;
  TPadSessionSync.CollectTabs(FWorkspace, Captions, Modified);

  Assert.AreEqual(2, Integer(Length(Captions)));
  Assert.AreEqual('Untitled', Captions[0]);
  Assert.IsFalse(Modified[0]);
  Assert.AreEqual('note.md', Captions[1]);
  Assert.IsTrue(Modified[1]);
end;

procedure TPadSessionSyncTests.RestoreOpenFiles_OpensExisting_SkipsMissing;
begin
  const A = WriteTempFile('sessionsync_a.md');
  const B = WriteTempFile('sessionsync_b.md');
  const Session = TPadSession.Create(TempPath('sessionsync.json'));
  try
    Session.SetOpenFiles([A, TempPath('sessionsync_missing.md'), B], 0);

    const HasDocuments = TPadSessionSync.RestoreOpenFiles(FWorkspace, Session);

    Assert.IsTrue(HasDocuments);
    Assert.AreEqual(2, FWorkspace.Count);
  finally
    Session.Free;
  end;
end;

procedure TPadSessionSyncTests.RestoreOpenFiles_NoneExist_ReturnsFalse;
begin
  const Session = TPadSession.Create(TempPath('sessionsync.json'));
  try
    Session.SetOpenFiles([TempPath('sessionsync_none1.md'), TempPath('sessionsync_none2.md')], 0);

    const HasDocuments = TPadSessionSync.RestoreOpenFiles(FWorkspace, Session);

    Assert.IsFalse(HasDocuments);
    Assert.AreEqual(0, FWorkspace.Count);
  finally
    Session.Free;
  end;
end;

procedure TPadSessionSyncTests.RestoreOpenFiles_ActivatesSessionActivePath;
begin
  const A = WriteTempFile('sessionsync_a.md');
  const B = WriteTempFile('sessionsync_b.md');
  const Session = TPadSession.Create(TempPath('sessionsync.json'));
  try
    Session.SetOpenFiles([A, B], 1);   // active = B

    TPadSessionSync.RestoreOpenFiles(FWorkspace, Session);

    Assert.IsTrue(FWorkspace.ActiveDocument <> nil);
    Assert.AreEqual(B, FWorkspace.ActiveDocument.FileName);
  finally
    Session.Free;
  end;
end;

end.
