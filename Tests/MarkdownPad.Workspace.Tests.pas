unit MarkdownPad.Workspace.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  MarkdownPad.Workspace.Interfaces,
  MarkdownPad.Workspace;

type
  [TestFixture]
  TPadWorkspaceTests = class
  private
    const
      File1Content = '# File One'#10'Body of file one.';
      File2Content = '# File Two'#10'Body of file two.';
      Tolerance = 0.001;
    var
      FWorkspace: IPadWorkspace;
      FFile1: string;
      FFile2: string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure NewDocument_AddsUntitledActiveDocument;

    [Test]
    procedure NewDocument_Twice_ProducesTwoDistinctUntitled;

    [Test]
    procedure OpenFile_NotOpen_AddsActivatesAndLoadsContent;

    [Test]
    procedure OpenFile_SetsModifiedFalseAndDiskTimestamp;

    [Test]
    procedure OpenFile_AlreadyOpen_ActivatesExistingWithoutReload;

    [Test]
    procedure OpenFile_AlreadyOpen_PreservesBufferAndModifiedState;

    [Test]
    procedure IndexOfFile_IsCaseInsensitive;

    [Test]
    procedure IndexOfFile_UntitledNeverMatches;

    [Test]
    procedure CloseDocument_ActiveMiddle_ActivatesRightNeighbour;

    [Test]
    procedure CloseDocument_BeforeActive_KeepsSameActiveDocument;

    [Test]
    procedure CloseDocument_LastRemaining_LeavesActiveIndexMinusOne;

    [Test]
    procedure CloseDocument_OutOfRange_Ignored;

    [Test]
    procedure Move_ForwardsDocument_ReordersList;

    [Test]
    procedure Move_KeepsActiveDocumentStable;

    [Test]
    procedure Move_SameIndex_LeavesOrderUnchanged;

    [Test]
    procedure Move_OutOfRange_Ignored;

    [Test]
    procedure Activate_OutOfRange_Ignored;

    [Test]
    procedure ActivateNext_WrapsAround;

    [Test]
    procedure ActivatePrevious_WrapsAround;

    [Test]
    procedure ActiveDocument_WhenEmpty_ReturnsNil;

    [Test]
    procedure DocumentBufferFields_RoundTripThroughInterface;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

procedure TPadWorkspaceTests.Setup;
begin
  FWorkspace := TPadWorkspace.Create;

  FFile1 := TPath.GetTempFileName;
  TFile.WriteAllText(FFile1, File1Content);

  FFile2 := TPath.GetTempFileName;
  TFile.WriteAllText(FFile2, File2Content);
end;

procedure TPadWorkspaceTests.TearDown;
begin
  FWorkspace := nil;

  if TFile.Exists(FFile1) then
    TFile.Delete(FFile1);

  if TFile.Exists(FFile2) then
    TFile.Delete(FFile2);
end;

procedure TPadWorkspaceTests.NewDocument_AddsUntitledActiveDocument;
begin
  const Doc = FWorkspace.NewDocument;

  Assert.AreEqual(1, FWorkspace.Count);
  Assert.AreEqual(0, FWorkspace.ActiveIndex);
  Assert.IsTrue(Doc.IsUntitled);
  Assert.IsTrue(FWorkspace.ActiveDocument = Doc);
end;

procedure TPadWorkspaceTests.NewDocument_Twice_ProducesTwoDistinctUntitled;
begin
  const Doc1 = FWorkspace.NewDocument;
  const Doc2 = FWorkspace.NewDocument;

  Assert.AreEqual(2, FWorkspace.Count);
  Assert.IsFalse(Doc1 = Doc2);
  Assert.IsTrue(Doc1.IsUntitled);
  Assert.IsTrue(Doc2.IsUntitled);
end;

procedure TPadWorkspaceTests.OpenFile_NotOpen_AddsActivatesAndLoadsContent;
begin
  const Doc = FWorkspace.OpenFile(FFile1);

  Assert.AreEqual(1, FWorkspace.Count);
  Assert.AreEqual(0, FWorkspace.ActiveIndex);
  Assert.AreEqual(File1Content, Doc.Text);
  Assert.AreEqual(FFile1, Doc.FileName);
end;

procedure TPadWorkspaceTests.OpenFile_SetsModifiedFalseAndDiskTimestamp;
begin
  const Doc = FWorkspace.OpenFile(FFile1);

  Assert.IsFalse(Doc.Modified);
  Assert.IsTrue(Doc.DiskTimestampUtc > 0);
end;

procedure TPadWorkspaceTests.OpenFile_AlreadyOpen_ActivatesExistingWithoutReload;
begin
  const Doc1 = FWorkspace.OpenFile(FFile1);

  FWorkspace.OpenFile(FFile2);
  Assert.AreEqual(1, FWorkspace.ActiveIndex);

  const Again = FWorkspace.OpenFile(FFile1);

  Assert.AreEqual(2, FWorkspace.Count);
  Assert.AreEqual(0, FWorkspace.ActiveIndex);
  Assert.IsTrue(Again = Doc1);
end;

procedure TPadWorkspaceTests.OpenFile_AlreadyOpen_PreservesBufferAndModifiedState;
begin
  const Doc = FWorkspace.OpenFile(FFile1);

  Doc.Text := 'edited buffer';
  Doc.Modified := True;

  const Again = FWorkspace.OpenFile(FFile1);

  Assert.IsTrue(Again = Doc);
  Assert.AreEqual('edited buffer', Again.Text);
  Assert.IsTrue(Again.Modified);
end;

procedure TPadWorkspaceTests.IndexOfFile_IsCaseInsensitive;
begin
  FWorkspace.OpenFile(FFile1);

  Assert.AreEqual(0, FWorkspace.IndexOfFile(UpperCase(FFile1)));
end;

procedure TPadWorkspaceTests.IndexOfFile_UntitledNeverMatches;
begin
  FWorkspace.NewDocument;

  Assert.AreEqual(-1, FWorkspace.IndexOfFile(''));
end;

procedure TPadWorkspaceTests.CloseDocument_ActiveMiddle_ActivatesRightNeighbour;
begin
  FWorkspace.NewDocument;
  FWorkspace.NewDocument;
  FWorkspace.NewDocument;
  FWorkspace.Activate(1);

  const RightNeighbour = FWorkspace.Documents[2];

  FWorkspace.CloseDocument(1);

  Assert.AreEqual(2, FWorkspace.Count);
  Assert.AreEqual(1, FWorkspace.ActiveIndex);
  Assert.IsTrue(FWorkspace.ActiveDocument = RightNeighbour);
end;

procedure TPadWorkspaceTests.CloseDocument_BeforeActive_KeepsSameActiveDocument;
begin
  FWorkspace.NewDocument;
  FWorkspace.NewDocument;
  FWorkspace.NewDocument;
  FWorkspace.Activate(2);

  const ActiveDoc = FWorkspace.Documents[2];

  FWorkspace.CloseDocument(0);

  Assert.AreEqual(1, FWorkspace.ActiveIndex);
  Assert.IsTrue(FWorkspace.ActiveDocument = ActiveDoc);
end;

procedure TPadWorkspaceTests.CloseDocument_LastRemaining_LeavesActiveIndexMinusOne;
begin
  FWorkspace.NewDocument;

  FWorkspace.CloseDocument(0);

  Assert.AreEqual(0, FWorkspace.Count);
  Assert.AreEqual(-1, FWorkspace.ActiveIndex);
end;

procedure TPadWorkspaceTests.CloseDocument_OutOfRange_Ignored;
begin
  FWorkspace.NewDocument;

  FWorkspace.CloseDocument(5);

  Assert.AreEqual(1, FWorkspace.Count);
  Assert.AreEqual(0, FWorkspace.ActiveIndex);
end;

procedure TPadWorkspaceTests.Move_ForwardsDocument_ReordersList;
begin
  const DocA = FWorkspace.NewDocument;
  const DocB = FWorkspace.NewDocument;
  const DocC = FWorkspace.NewDocument;

  FWorkspace.Move(0, 2);

  Assert.IsTrue(FWorkspace.Documents[0] = DocB);
  Assert.IsTrue(FWorkspace.Documents[1] = DocC);
  Assert.IsTrue(FWorkspace.Documents[2] = DocA);
end;

procedure TPadWorkspaceTests.Move_KeepsActiveDocumentStable;
begin
  const DocA = FWorkspace.NewDocument;
  FWorkspace.NewDocument;
  FWorkspace.NewDocument;
  FWorkspace.Activate(0);

  FWorkspace.Move(2, 0);

  Assert.IsTrue(FWorkspace.ActiveDocument = DocA);
  Assert.AreEqual(1, FWorkspace.ActiveIndex);
end;

procedure TPadWorkspaceTests.Move_SameIndex_LeavesOrderUnchanged;
begin
  const DocA = FWorkspace.NewDocument;
  const DocB = FWorkspace.NewDocument;

  FWorkspace.Move(1, 1);

  Assert.IsTrue(FWorkspace.Documents[0] = DocA);
  Assert.IsTrue(FWorkspace.Documents[1] = DocB);
end;

procedure TPadWorkspaceTests.Move_OutOfRange_Ignored;
begin
  const DocA = FWorkspace.NewDocument;
  const DocB = FWorkspace.NewDocument;

  FWorkspace.Move(5, 0);

  Assert.IsTrue(FWorkspace.Documents[0] = DocA);
  Assert.IsTrue(FWorkspace.Documents[1] = DocB);
end;

procedure TPadWorkspaceTests.Activate_OutOfRange_Ignored;
begin
  FWorkspace.NewDocument;
  FWorkspace.NewDocument;
  FWorkspace.Activate(1);

  FWorkspace.Activate(9);

  Assert.AreEqual(1, FWorkspace.ActiveIndex);
end;

procedure TPadWorkspaceTests.ActivateNext_WrapsAround;
begin
  FWorkspace.NewDocument;
  FWorkspace.NewDocument;
  FWorkspace.Activate(1);

  FWorkspace.ActivateNext;

  Assert.AreEqual(0, FWorkspace.ActiveIndex);
end;

procedure TPadWorkspaceTests.ActivatePrevious_WrapsAround;
begin
  FWorkspace.NewDocument;
  FWorkspace.NewDocument;
  FWorkspace.Activate(0);

  FWorkspace.ActivatePrevious;

  Assert.AreEqual(1, FWorkspace.ActiveIndex);
end;

procedure TPadWorkspaceTests.ActiveDocument_WhenEmpty_ReturnsNil;
begin
  Assert.IsTrue(FWorkspace.ActiveDocument = nil);
end;

procedure TPadWorkspaceTests.DocumentBufferFields_RoundTripThroughInterface;
begin
  const Doc = FWorkspace.NewDocument;

  Doc.Text := 'body';
  Doc.CaretPosition := 12;
  Doc.EditorScrollOffset := 3.5;
  Doc.PreviewScrollOffset := 7.25;
  Doc.Modified := True;

  Assert.AreEqual('body', Doc.Text);
  Assert.AreEqual(12, Doc.CaretPosition);
  Assert.IsTrue(Abs(Doc.EditorScrollOffset - 3.5) < Tolerance);
  Assert.IsTrue(Abs(Doc.PreviewScrollOffset - 7.25) < Tolerance);
  Assert.IsTrue(Doc.Modified);
end;

end.
