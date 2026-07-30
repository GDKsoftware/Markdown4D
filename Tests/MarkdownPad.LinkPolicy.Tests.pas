unit MarkdownPad.LinkPolicy.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TPadLinkPolicyTests = class
  private
    const
      NeighbourFileName = 'other.md';
      SubfolderName = 'guide';
      SubfolderFileName = 'intro.md';
    var
      FDocumentFolder: string;
    procedure WriteFile(const RelativePath: string);

  public
    [Test]
    [TestCase('http', 'http://example.com')]
    [TestCase('https', 'https://example.com/page?a=1')]
    [TestCase('mailto', 'mailto:someone@example.com')]
    [TestCase('uppercase scheme', 'HTTPS://example.com')]
    [TestCase('surrounding space', ' https://example.com ')]
    procedure MayOpen_WebOrMailDestination_ReturnsTrue(const Url: string);

    [Test]
    [TestCase('file url', 'file:///C:/Windows/System32/calc.exe')]
    [TestCase('unc path', '\\attacker\share\payload.exe')]
    [TestCase('drive path', 'C:\Users\Public\payload.exe')]
    [TestCase('relative document', './other.md')]
    [TestCase('javascript', 'javascript:alert(1)')]
    [TestCase('vbscript', 'vbscript:msgbox(1)')]
    [TestCase('data html', 'data:text/html;base64,PHNjcmlwdD4=')]
    [TestCase('anchor', '#section')]
    [TestCase('empty', '')]
    [TestCase('whitespace only', '   ')]
    procedure MayOpen_EverythingElse_ReturnsFalse(const Url: string);

    [Test]
    procedure RefusalMessage_AnyUrl_NamesTheDestination;

    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure TryResolveDocument_NeighbouringMarkdownFile_ResolvesToFullPath;

    [Test]
    procedure TryResolveDocument_MarkdownFileInSubfolder_ResolvesToFullPath;

    [Test]
    procedure TryResolveDocument_TrailingAnchor_ResolvesToFileItself;

    [Test]
    procedure TryResolveDocument_MissingFile_Fails;

    [Test]
    [TestCase('other extension', 'notes.txt')]
    [TestCase('executable', 'setup.exe')]
    procedure TryResolveDocument_NonMarkdownFile_Fails(const Link: string);

    [Test]
    [TestCase('unc path', '\\attacker\share\doc.md')]
    [TestCase('drive path', 'C:\docs\doc.md')]
    [TestCase('drive relative', '\doc.md')]
    [TestCase('root relative', '/doc.md')]
    [TestCase('web address', 'https://example.com/doc.md')]
    [TestCase('file url', 'file:///C:/docs/doc.md')]
    procedure TryResolveDocument_NonRelativeDestination_Fails(const Link: string);

    [Test]
    procedure TryResolveDocument_WithoutDocumentFolder_Fails;

    [Test]
    procedure TryResolveDocument_ParentSegmentsLeavingTheFolder_Fails;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  MarkdownPad.LinkPolicy;

procedure TPadLinkPolicyTests.MayOpen_WebOrMailDestination_ReturnsTrue(const Url: string);
begin
  Assert.IsTrue(TPadLinkPolicy.MayOpen(Url), Format('<%s> must be opened', [Url]));
end;

procedure TPadLinkPolicyTests.MayOpen_EverythingElse_ReturnsFalse(const Url: string);
begin
  Assert.IsFalse(TPadLinkPolicy.MayOpen(Url), Format('<%s> must not reach the shell', [Url]));
end;

procedure TPadLinkPolicyTests.RefusalMessage_AnyUrl_NamesTheDestination;
begin
  const Url = 'file:///C:/Windows/System32/calc.exe';

  Assert.Contains(TPadLinkPolicy.RefusalMessage(Url), Url);
end;

procedure TPadLinkPolicyTests.Setup;
begin
  FDocumentFolder := TPath.Combine(TPath.GetTempPath, TPath.GetGUIDFileName);
  TDirectory.CreateDirectory(FDocumentFolder);

  WriteFile(NeighbourFileName);
  WriteFile(TPath.Combine(SubfolderName, SubfolderFileName));
end;

procedure TPadLinkPolicyTests.TearDown;
begin
  if TDirectory.Exists(FDocumentFolder) then
    TDirectory.Delete(FDocumentFolder, True);
end;

procedure TPadLinkPolicyTests.WriteFile(const RelativePath: string);
begin
  const FullPath = TPath.Combine(FDocumentFolder, RelativePath);
  TDirectory.CreateDirectory(TPath.GetDirectoryName(FullPath));

  TFile.WriteAllText(FullPath, '# heading');
end;

procedure TPadLinkPolicyTests.TryResolveDocument_NeighbouringMarkdownFile_ResolvesToFullPath;
begin
  var FileName: string;
  const Resolved = TPadLinkPolicy.TryResolveDocument('./' + NeighbourFileName, FDocumentFolder, FileName);

  Assert.IsTrue(Resolved);
  Assert.AreEqual(TPath.Combine(FDocumentFolder, NeighbourFileName), FileName);
end;

procedure TPadLinkPolicyTests.TryResolveDocument_MarkdownFileInSubfolder_ResolvesToFullPath;
begin
  var FileName: string;
  const Link = SubfolderName + '/' + SubfolderFileName;
  const Resolved = TPadLinkPolicy.TryResolveDocument(Link, FDocumentFolder, FileName);

  Assert.IsTrue(Resolved);
  Assert.AreEqual(TPath.Combine(FDocumentFolder, TPath.Combine(SubfolderName, SubfolderFileName)), FileName);
end;

procedure TPadLinkPolicyTests.TryResolveDocument_TrailingAnchor_ResolvesToFileItself;
begin
  var FileName: string;
  const Resolved = TPadLinkPolicy.TryResolveDocument(NeighbourFileName + '#heading', FDocumentFolder, FileName);

  Assert.IsTrue(Resolved);
  Assert.AreEqual(TPath.Combine(FDocumentFolder, NeighbourFileName), FileName);
end;

procedure TPadLinkPolicyTests.TryResolveDocument_MissingFile_Fails;
begin
  var FileName: string;

  Assert.IsFalse(TPadLinkPolicy.TryResolveDocument('absent.md', FDocumentFolder, FileName));
end;

procedure TPadLinkPolicyTests.TryResolveDocument_NonMarkdownFile_Fails(const Link: string);
begin
  WriteFile(Link);

  var FileName: string;

  Assert.IsFalse(TPadLinkPolicy.TryResolveDocument(Link, FDocumentFolder, FileName),
    Format('<%s> must not be opened by the pad', [Link]));
end;

// A UNC destination is the one that matters here: reaching for someone else's
// share is what hands over the credentials Windows offers it.
procedure TPadLinkPolicyTests.TryResolveDocument_NonRelativeDestination_Fails(const Link: string);
begin
  var FileName: string;

  Assert.IsFalse(TPadLinkPolicy.TryResolveDocument(Link, FDocumentFolder, FileName),
    Format('<%s> must not resolve to a document', [Link]));
end;

procedure TPadLinkPolicyTests.TryResolveDocument_WithoutDocumentFolder_Fails;
begin
  var FileName: string;

  Assert.IsFalse(TPadLinkPolicy.TryResolveDocument(NeighbourFileName, '', FileName));
end;

// The file exists and ends in .md, so only the folder boundary stands between
// the link and a reader for any document on this machine.
procedure TPadLinkPolicyTests.TryResolveDocument_ParentSegmentsLeavingTheFolder_Fails;
begin
  const OutsideName = TPath.GetGUIDFileName + '.md';
  const OutsidePath = TPath.Combine(TPath.GetDirectoryName(FDocumentFolder), OutsideName);
  TFile.WriteAllText(OutsidePath, '# heading');
  try
    var FileName: string;
    const Link = '../' + OutsideName;

    Assert.IsFalse(TPadLinkPolicy.TryResolveDocument(Link, FDocumentFolder, FileName),
      Format('<%s> must not resolve outside the document folder', [Link]));
  finally
    TFile.Delete(OutsidePath);
  end;
end;

end.
