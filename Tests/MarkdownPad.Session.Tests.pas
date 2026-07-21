unit MarkdownPad.Session.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  MarkdownPad.Session;

type
  [TestFixture]
  TPadSessionTests = class
  private
    var
      FRootDir: string;
      FPath: string;
      FSession: TPadSession;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure SaveThenLoad_RoundTripsAllFields;

    [Test]
    procedure Load_MissingFile_YieldsEmptyDefaults;

    [Test]
    procedure Load_CorruptJson_YieldsEmptyDefaults;

    [Test]
    procedure Load_RootNotObject_YieldsEmptyDefaults;

    [Test]
    procedure Save_CreatesMissingDirectory;

    [Test]
    procedure AddRecentFile_InsertsAtFront;

    [Test]
    procedure AddRecentFile_ExistingDuplicate_MovesToFrontNoGrowth;

    [Test]
    procedure AddRecentFile_CaseInsensitiveDuplicate;

    [Test]
    procedure AddRecentFile_CapsAtTen;

    [Test]
    procedure AddRecentFile_EmptyIgnored;

    [Test]
    procedure SetOpenFiles_DropsEmptyPaths;

    [Test]
    procedure SetOpenFiles_StoresActiveIndex;

    [Test]
    procedure DarkTheme_RoundTrips;

    [Test]
    procedure ViewMode_RoundTrips;

    [Test]
    procedure Load_MissingViewMode_DefaultsToSplit;

    [Test]
    procedure ResolvePath_UsesMarkdown4DAppDataSubfolder;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

procedure TPadSessionTests.Setup;
begin
  FRootDir := TPath.Combine(TPath.GetTempPath, Format('MarkdownPad_%s', [TPath.GetGUIDFileName]));
  TDirectory.CreateDirectory(FRootDir);

  FPath := TPath.Combine(FRootDir, 'session.json');
  FSession := TPadSession.Create(FPath);
end;

procedure TPadSessionTests.TearDown;
begin
  FSession.Free;

  if TDirectory.Exists(FRootDir) then
    TDirectory.Delete(FRootDir, True);
end;

procedure TPadSessionTests.SaveThenLoad_RoundTripsAllFields;
begin
  FSession.SetOpenFiles(['a.md', 'b.md'], 1);
  FSession.AddRecentFile('r1.md');
  FSession.DarkTheme := True;
  FSession.ViewMode := TPadViewMode.PreviewOnly;
  FSession.Save;

  const Loaded = TPadSession.Create(FPath);
  try
    Loaded.Load;

    Assert.AreEqual(2, Length(Loaded.OpenFiles));
    Assert.AreEqual('a.md', Loaded.OpenFiles[0]);
    Assert.AreEqual('b.md', Loaded.OpenFiles[1]);
    Assert.AreEqual(1, Loaded.ActiveIndex);
    Assert.AreEqual(1, Length(Loaded.RecentFiles));
    Assert.AreEqual('r1.md', Loaded.RecentFiles[0]);
    Assert.IsTrue(Loaded.DarkTheme);
    Assert.IsTrue(Loaded.ViewMode = TPadViewMode.PreviewOnly);
  finally
    Loaded.Free;
  end;
end;

procedure TPadSessionTests.Load_MissingFile_YieldsEmptyDefaults;
begin
  const Missing = TPadSession.Create(TPath.Combine(FRootDir, 'nope.json'));
  try
    Missing.Load;

    Assert.AreEqual(0, Length(Missing.OpenFiles));
    Assert.AreEqual(-1, Missing.ActiveIndex);
    Assert.AreEqual(0, Length(Missing.RecentFiles));
    Assert.IsFalse(Missing.DarkTheme);
    Assert.IsTrue(Missing.ViewMode = TPadViewMode.Split);
  finally
    Missing.Free;
  end;
end;

procedure TPadSessionTests.Load_CorruptJson_YieldsEmptyDefaults;
begin
  TFile.WriteAllText(FPath, 'this is not json {{{');

  FSession.Load;

  Assert.AreEqual(0, Length(FSession.OpenFiles));
  Assert.AreEqual(-1, FSession.ActiveIndex);
  Assert.IsFalse(FSession.DarkTheme);
end;

procedure TPadSessionTests.Load_RootNotObject_YieldsEmptyDefaults;
begin
  TFile.WriteAllText(FPath, '[1, 2, 3]');

  FSession.Load;

  Assert.AreEqual(0, Length(FSession.OpenFiles));
  Assert.AreEqual(-1, FSession.ActiveIndex);
end;

procedure TPadSessionTests.Save_CreatesMissingDirectory;
begin
  const NestedPath = TPath.Combine(TPath.Combine(FRootDir, 'nested'), 'session.json');
  const Session = TPadSession.Create(NestedPath);
  try
    Session.Save;

    Assert.IsTrue(TFile.Exists(NestedPath));
  finally
    Session.Free;
  end;
end;

procedure TPadSessionTests.AddRecentFile_InsertsAtFront;
begin
  FSession.AddRecentFile('one.md');
  FSession.AddRecentFile('two.md');

  Assert.AreEqual('two.md', FSession.RecentFiles[0]);
  Assert.AreEqual('one.md', FSession.RecentFiles[1]);
end;

procedure TPadSessionTests.AddRecentFile_ExistingDuplicate_MovesToFrontNoGrowth;
begin
  FSession.AddRecentFile('one.md');
  FSession.AddRecentFile('two.md');
  FSession.AddRecentFile('one.md');

  Assert.AreEqual(2, Length(FSession.RecentFiles));
  Assert.AreEqual('one.md', FSession.RecentFiles[0]);
  Assert.AreEqual('two.md', FSession.RecentFiles[1]);
end;

procedure TPadSessionTests.AddRecentFile_CaseInsensitiveDuplicate;
begin
  FSession.AddRecentFile('File.md');
  FSession.AddRecentFile('FILE.MD');

  Assert.AreEqual(1, Length(FSession.RecentFiles));
  Assert.AreEqual('FILE.MD', FSession.RecentFiles[0]);
end;

procedure TPadSessionTests.AddRecentFile_CapsAtTen;
begin
  for var Index := 1 to 15 do
  begin
    FSession.AddRecentFile(Format('file%d.md', [Index]));
  end;

  Assert.AreEqual(10, Length(FSession.RecentFiles));
  Assert.AreEqual('file15.md', FSession.RecentFiles[0]);
  Assert.AreEqual('file6.md', FSession.RecentFiles[9]);
end;

procedure TPadSessionTests.AddRecentFile_EmptyIgnored;
begin
  FSession.AddRecentFile('');

  Assert.AreEqual(0, Length(FSession.RecentFiles));
end;

procedure TPadSessionTests.SetOpenFiles_DropsEmptyPaths;
begin
  FSession.SetOpenFiles(['a.md', '', 'b.md', ''], 0);

  Assert.AreEqual(2, Length(FSession.OpenFiles));
  Assert.AreEqual('a.md', FSession.OpenFiles[0]);
  Assert.AreEqual('b.md', FSession.OpenFiles[1]);
end;

procedure TPadSessionTests.SetOpenFiles_StoresActiveIndex;
begin
  FSession.SetOpenFiles(['a.md', 'b.md', 'c.md'], 2);

  Assert.AreEqual(2, FSession.ActiveIndex);
end;

procedure TPadSessionTests.DarkTheme_RoundTrips;
begin
  FSession.DarkTheme := True;
  FSession.Save;

  const Loaded = TPadSession.Create(FPath);
  try
    Loaded.Load;

    Assert.IsTrue(Loaded.DarkTheme);
  finally
    Loaded.Free;
  end;
end;

procedure TPadSessionTests.ViewMode_RoundTrips;
begin
  FSession.ViewMode := TPadViewMode.EditorOnly;
  FSession.Save;

  const Loaded = TPadSession.Create(FPath);
  try
    Loaded.Load;

    Assert.IsTrue(Loaded.ViewMode = TPadViewMode.EditorOnly);
  finally
    Loaded.Free;
  end;
end;

procedure TPadSessionTests.Load_MissingViewMode_DefaultsToSplit;
begin
  TFile.WriteAllText(FPath, '{"darkTheme":true}');

  FSession.Load;

  Assert.IsTrue(FSession.ViewMode = TPadViewMode.Split);
  Assert.IsTrue(FSession.DarkTheme);
end;

procedure TPadSessionTests.ResolvePath_UsesMarkdown4DAppDataSubfolder;
begin
  const Resolved = TPadSession.ResolvePath('MarkdownPad.Vcl.json');

  Assert.IsTrue(Resolved.EndsWith(TPath.Combine('Markdown4D', 'MarkdownPad.Vcl.json')));

  const AppData = GetEnvironmentVariable('APPDATA');
  Assert.IsTrue(Resolved.Contains(AppData));
end;

end.
