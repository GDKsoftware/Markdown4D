unit MarkdownPad.FileWatcher.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  MarkdownPad.Workspace.Interfaces,
  MarkdownPad.Workspace,
  MarkdownPad.FileWatcher;

type
  [TestFixture]
  TPadFileWatcherTests = class
  private
    var
      FWorkspace: IPadWorkspace;
      FWatcher: TPadFileWatcher;
      FFile1: string;
      FFile2: string;
      FFiredDocuments: TArray<IPadDocument>;
      FTimestampAtCallback: TDateTime;
    procedure HandleFileChanged(const Document: IPadDocument);
    procedure SimulateExternalEdit(const FileName: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Poll_NoChange_DoesNotFire;

    [Test]
    procedure Poll_FileModifiedExternally_FiresOnceWithDocument;

    [Test]
    procedure Poll_AfterFiring_SecondPollIsSilent;

    [Test]
    procedure Poll_UpdatesDocumentTimestampBeforeCallback;

    [Test]
    procedure Poll_UntitledDocument_Ignored;

    [Test]
    procedure Poll_MissingFile_Ignored;

    [Test]
    procedure Poll_ModifiedDocument_StillFires;

    [Test]
    procedure Poll_MultipleDocuments_FiresPerChangedFileOnly;

    [Test]
    procedure Reset_AfterExternalChange_SuppressesNextPoll;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.IOUtils;

procedure TPadFileWatcherTests.Setup;
begin
  FFiredDocuments := [];
  FTimestampAtCallback := 0;
  FWorkspace := TPadWorkspace.Create;

  FFile1 := TPath.GetTempFileName;
  TFile.WriteAllText(FFile1, 'file one');

  FFile2 := TPath.GetTempFileName;
  TFile.WriteAllText(FFile2, 'file two');

  FWatcher := TPadFileWatcher.Create(FWorkspace, HandleFileChanged);
end;

procedure TPadFileWatcherTests.TearDown;
begin
  FWatcher.Free;
  FWorkspace := nil;

  if TFile.Exists(FFile1) then
    TFile.Delete(FFile1);

  if TFile.Exists(FFile2) then
    TFile.Delete(FFile2);
end;

procedure TPadFileWatcherTests.Poll_NoChange_DoesNotFire;
begin
  FWorkspace.OpenFile(FFile1);

  FWatcher.Poll;

  Assert.AreEqual(0, Length(FFiredDocuments));
end;

procedure TPadFileWatcherTests.Poll_FileModifiedExternally_FiresOnceWithDocument;
begin
  const Doc = FWorkspace.OpenFile(FFile1);

  SimulateExternalEdit(FFile1);
  FWatcher.Poll;

  Assert.AreEqual(1, Length(FFiredDocuments));
  Assert.IsTrue(FFiredDocuments[0] = Doc);
end;

procedure TPadFileWatcherTests.Poll_AfterFiring_SecondPollIsSilent;
begin
  FWorkspace.OpenFile(FFile1);

  SimulateExternalEdit(FFile1);
  FWatcher.Poll;
  FWatcher.Poll;

  Assert.AreEqual(1, Length(FFiredDocuments));
end;

procedure TPadFileWatcherTests.Poll_UpdatesDocumentTimestampBeforeCallback;
begin
  FWorkspace.OpenFile(FFile1);

  SimulateExternalEdit(FFile1);
  const Expected = TFile.GetLastWriteTimeUtc(FFile1);
  FWatcher.Poll;

  Assert.AreEqual(Double(Expected), Double(FTimestampAtCallback), 0.0);
end;

procedure TPadFileWatcherTests.Poll_UntitledDocument_Ignored;
begin
  FWorkspace.NewDocument;

  FWatcher.Poll;

  Assert.AreEqual(0, Length(FFiredDocuments));
end;

procedure TPadFileWatcherTests.Poll_MissingFile_Ignored;
begin
  FWorkspace.OpenFile(FFile1);

  TFile.Delete(FFile1);
  FWatcher.Poll;

  Assert.AreEqual(0, Length(FFiredDocuments));
end;

procedure TPadFileWatcherTests.Poll_ModifiedDocument_StillFires;
begin
  const Doc = FWorkspace.OpenFile(FFile1);

  Doc.Modified := True;
  SimulateExternalEdit(FFile1);
  FWatcher.Poll;

  Assert.AreEqual(1, Length(FFiredDocuments));
end;

procedure TPadFileWatcherTests.Poll_MultipleDocuments_FiresPerChangedFileOnly;
begin
  FWorkspace.OpenFile(FFile1);
  const Doc2 = FWorkspace.OpenFile(FFile2);

  SimulateExternalEdit(FFile2);
  FWatcher.Poll;

  Assert.AreEqual(1, Length(FFiredDocuments));
  Assert.IsTrue(FFiredDocuments[0] = Doc2);
end;

procedure TPadFileWatcherTests.Reset_AfterExternalChange_SuppressesNextPoll;
begin
  const Doc = FWorkspace.OpenFile(FFile1);

  SimulateExternalEdit(FFile1);
  FWatcher.Reset(Doc);
  FWatcher.Poll;

  Assert.AreEqual(0, Length(FFiredDocuments));
end;

procedure TPadFileWatcherTests.HandleFileChanged(const Document: IPadDocument);
begin
  FFiredDocuments := FFiredDocuments + [Document];
  FTimestampAtCallback := Document.DiskTimestampUtc;
end;

procedure TPadFileWatcherTests.SimulateExternalEdit(const FileName: string);
begin
  const Current = TFile.GetLastWriteTimeUtc(FileName);
  TFile.SetLastWriteTimeUtc(FileName, IncMinute(Current, 1));
end;

end.
