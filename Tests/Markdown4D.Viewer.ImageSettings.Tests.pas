unit Markdown4D.Viewer.ImageSettings.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TViewerImageSettingsTests = class
  private
    const
      DefaultMaxBytes = 8 * 1024 * 1024;
      DocumentFolder = 'C:\docs\project';

  public
    [Test]
    procedure Create_NewSettings_AllowsRemoteWithinDefaultBound;

    [Test]
    procedure Assign_PopulatedSettings_CopiesEveryField;

    [Test]
    procedure ResolveImageUrl_RelativePath_ResolvesAgainstDocumentFolder;

    [Test]
    procedure ResolveImageUrl_ParentSegments_CollapseToCanonicalPath;

    [Test]
    procedure ResolveImageUrl_RestrictedAndEscaping_Fails;

    [Test]
    procedure ResolveImageUrl_RestrictedAndInsideFolder_Succeeds;

    [Test]
    procedure ResolveImageUrl_RestrictedAndSiblingFolderPrefix_Fails;

    [Test]
    procedure ResolveImageUrl_UnrestrictedAndEscaping_Succeeds;

    [Test]
    procedure ResolveImageUrl_RemoteSource_IsLeftAlone;

    [Test]
    procedure ResolveImageUrl_LocalBaseUrlEscapingWhileRestricted_Fails;

    [Test]
    procedure ResolveImageUrl_LocalBaseUrlInsideFolderWhileRestricted_Succeeds;

    [Test]
    procedure ResolveImageUrl_RemoteBaseUrlWhileRestricted_IsLeftAlone;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Markdown4D.Viewer.ImageSettings,
  Markdown4D.Viewer.Shared;

procedure TViewerImageSettingsTests.Create_NewSettings_AllowsRemoteWithinDefaultBound;
begin
  const Settings = TMarkdownViewerImageSettings.Create;
  try
    Assert.IsTrue(Settings.AllowRemote, 'Remote images stay enabled by default');
    Assert.AreEqual(DefaultMaxBytes, Settings.MaxBytes);
    Assert.IsFalse(Settings.RestrictToDocumentFolder, 'Local paths are unrestricted by default');
  finally
    Settings.Free;
  end;
end;

procedure TViewerImageSettingsTests.Assign_PopulatedSettings_CopiesEveryField;
begin
  const Source = TMarkdownViewerImageSettings.Create;
  try
    Source.BaseUrl := 'https://example.com/img/';
    Source.AllowRemote := False;
    Source.MaxBytes := 1024;
    Source.RestrictToDocumentFolder := True;

    const Target = TMarkdownViewerImageSettings.Create;
    try
      Target.Assign(Source);

      Assert.AreEqual(Source.BaseUrl, Target.BaseUrl);
      Assert.AreEqual(Source.AllowRemote, Target.AllowRemote);
      Assert.AreEqual(Source.MaxBytes, Target.MaxBytes);
      Assert.AreEqual(Source.RestrictToDocumentFolder, Target.RestrictToDocumentFolder);
    finally
      Target.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TViewerImageSettingsTests.ResolveImageUrl_RelativePath_ResolvesAgainstDocumentFolder;
begin
  var Url: string;
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl('logo.png', '', DocumentFolder, Url);

  Assert.IsTrue(Resolved);
  Assert.AreEqual(TPath.Combine(DocumentFolder, 'logo.png'), Url);
end;

procedure TViewerImageSettingsTests.ResolveImageUrl_ParentSegments_CollapseToCanonicalPath;
begin
  var Url: string;
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl('sub\..\logo.png', '', DocumentFolder, Url);

  Assert.IsTrue(Resolved);
  Assert.AreEqual(TPath.Combine(DocumentFolder, 'logo.png'), Url);
end;

procedure TViewerImageSettingsTests.ResolveImageUrl_RestrictedAndEscaping_Fails;
begin
  var Url: string;
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl('..\..\Windows\win.ini', '', DocumentFolder, True, Url);

  Assert.IsFalse(Resolved, 'A path leaving the document folder must not resolve');
  Assert.AreEqual('', Url);
end;

procedure TViewerImageSettingsTests.ResolveImageUrl_RestrictedAndInsideFolder_Succeeds;
begin
  var Url: string;
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl('images\logo.png', '', DocumentFolder, True, Url);

  Assert.IsTrue(Resolved);
  Assert.AreEqual(TPath.Combine(DocumentFolder, 'images\logo.png'), Url);
end;

// "C:\docs\project-private" starts with "C:\docs\project" as text but is a
// different folder, so the check has to compare on the separator.
procedure TViewerImageSettingsTests.ResolveImageUrl_RestrictedAndSiblingFolderPrefix_Fails;
begin
  var Url: string;
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl('..\project-private\logo.png', '', DocumentFolder,
    True, Url);

  Assert.IsFalse(Resolved, Format('A sibling folder must not pass as a child, got <%s>', [Url]));
end;

procedure TViewerImageSettingsTests.ResolveImageUrl_UnrestrictedAndEscaping_Succeeds;
begin
  var Url: string;
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl('..\other\logo.png', '', DocumentFolder, False, Url);

  Assert.IsTrue(Resolved);
  Assert.AreEqual('C:\docs\other\logo.png', Url);
end;

procedure TViewerImageSettingsTests.ResolveImageUrl_RemoteSource_IsLeftAlone;
begin
  const Remote = 'https://example.com/logo.png';

  var Url: string;
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl(Remote, '', DocumentFolder, True, Url);

  Assert.IsTrue(Resolved);
  Assert.AreEqual(Remote, Url);
end;

// A base that names a folder resolves to a path like any other, so the document
// folder restriction applies to the result.
procedure TViewerImageSettingsTests.ResolveImageUrl_LocalBaseUrlEscapingWhileRestricted_Fails;
begin
  var Url: string;
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl('logo.png', 'C:\elsewhere', DocumentFolder, True, Url);

  Assert.IsFalse(Resolved, Format('A base outside the document folder must not resolve, got <%s>', [Url]));
  Assert.AreEqual('', Url);
end;

procedure TViewerImageSettingsTests.ResolveImageUrl_LocalBaseUrlInsideFolderWhileRestricted_Succeeds;
begin
  var Url: string;
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl('logo.png', DocumentFolder + '\images',
    DocumentFolder, True, Url);

  Assert.IsTrue(Resolved);
  Assert.AreEqual(TPath.Combine(DocumentFolder, 'images\logo.png'), Url);
end;

procedure TViewerImageSettingsTests.ResolveImageUrl_RemoteBaseUrlWhileRestricted_IsLeftAlone;
begin
  var Url: string;
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl('logo.png', 'https://example.com/img/',
    DocumentFolder, True, Url);

  Assert.IsTrue(Resolved);
  Assert.AreEqual('https://example.com/img/logo.png', Url);
end;

end.
