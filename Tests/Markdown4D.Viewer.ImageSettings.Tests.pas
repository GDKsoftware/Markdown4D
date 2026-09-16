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
    [TestCase('Relative path', 'logo.png')]
    [TestCase('Parent segments collapse', 'sub\..\logo.png')]
    procedure ResolveImageUrl_UnrestrictedOverload_ResolvesAgainstDocumentFolder(const Source: string);

    [Test]
    [TestCase('Restricted and escaping fails', '..\..\Windows\win.ini,,True,False,')]
    [TestCase('Restricted and inside folder succeeds', 'images\logo.png,,True,True,C:\docs\project\images\logo.png')]
    [TestCase('Restricted and sibling folder prefix fails', '..\project-private\logo.png,,True,False,')]
    [TestCase('Unrestricted and escaping succeeds', '..\other\logo.png,,False,True,C:\docs\other\logo.png')]
    [TestCase('Remote source is left alone', 'https://example.com/logo.png,,True,True,https://example.com/logo.png')]
    [TestCase('Local base url escaping while restricted fails', 'logo.png,C:\elsewhere,True,False,')]
    [TestCase('Local base url inside folder while restricted succeeds', 'logo.png,C:\docs\project\images,True,True,C:\docs\project\images\logo.png')]
    [TestCase('Remote base url while restricted is left alone', 'logo.png,https://example.com/img/,True,True,https://example.com/img/logo.png')]
    procedure ResolveImageUrl_RestrictedOverload_ResolvesOrFailsAsExpected(const Source, BaseUrl: string; const Restrict, ExpectedResolved: Boolean; const ExpectedUrl: string);
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

procedure TViewerImageSettingsTests.ResolveImageUrl_UnrestrictedOverload_ResolvesAgainstDocumentFolder(const Source: string);
begin
  var Url: string;
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl(Source, '', DocumentFolder, Url);

  Assert.IsTrue(Resolved);
  Assert.AreEqual(TPath.Combine(DocumentFolder, 'logo.png'), Url);
end;

// "C:\docs\project-private" starts with "C:\docs\project" as text but is a
// different folder, so the check has to compare on the separator. A base that
// names a folder resolves to a path like any other, so the document folder
// restriction applies to it as well. Every failure path leaves Url empty.
procedure TViewerImageSettingsTests.ResolveImageUrl_RestrictedOverload_ResolvesOrFailsAsExpected(const Source, BaseUrl: string; const Restrict, ExpectedResolved: Boolean; const ExpectedUrl: string);
begin
  var Url: string;
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl(Source, BaseUrl, DocumentFolder, Restrict, Url);

  Assert.AreEqual(ExpectedResolved, Resolved);
  Assert.AreEqual(ExpectedUrl, Url);
end;

end.
