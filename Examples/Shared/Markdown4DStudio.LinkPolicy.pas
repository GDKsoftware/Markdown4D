unit Markdown4DStudio.LinkPolicy;

{$SCOPEDENUMS ON}

// A link in the preview is a string that came out of the document, and the studio
// opens documents from anywhere: a downloaded file, a drag and drop, the .md
// association. Handing such a string straight to the shell turns
// "[Release notes](file:///C:/Users/Public/payload.exe)" into a one-click
// launcher, so the studio opens the schemes a reader expects from a document,
// opens a neighbouring markdown file itself, and refuses everything else.

interface

uses
  Markdown4DStudio.Defines;

type
  TPadLinkPolicy = class
  private
    const
      OpenableSchemes: array[0..2] of string = ('http://', 'https://', 'mailto:');
      FragmentSeparator = '#';
      QuerySeparator = '?';
      DocumentExtension = '.' + DefaultExtension;
      ForwardSlash = '/';
      BackSlash = '\';
    class function WithoutFragment(const Url: string): string;
    class function LooksLikeDocumentPath(const Value: string): Boolean;
    class function IsInsideFolder(const Path, Folder: string): Boolean;

  public
    class function MayOpen(const Url: string): Boolean;
    // A link to a markdown file next to the current document is opened by the
    // studio itself instead of by the shell. Only a relative path that stays
    // inside the document's own folder qualifies: an absolute or UNC path would
    // let a document point at a server of someone else's choosing, and reaching
    // for that share hands over the credentials Windows offers it, while ".."
    // segments would turn a link into a reader for any file on this machine.
    class function TryResolveDocument(const Url, DocumentFolder: string; out FileName: string): Boolean;
    class function RefusalMessage(const Url: string): string;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Markdown4D.Defines;

class function TPadLinkPolicy.MayOpen(const Url: string): Boolean;
begin
  const Candidate = Url.Trim;

  if Candidate = '' then
    Exit(False);

  // An in-document anchor is the viewer's business, never the shell's.
  if Candidate.StartsWith(FragmentSeparator) then
    Exit(False);

  for var Scheme in OpenableSchemes do
  begin
    if Candidate.StartsWith(Scheme, True) then
      Exit(True);
  end;

  Result := False;
end;

class function TPadLinkPolicy.TryResolveDocument(const Url, DocumentFolder: string;
  out FileName: string): Boolean;
begin
  FileName := '';

  if DocumentFolder = '' then
    Exit(False);

  const Candidate = WithoutFragment(Url.Trim);
  if not LooksLikeDocumentPath(Candidate) then
    Exit(False);

  try
    const FullPath = TPath.GetFullPath(TPath.Combine(DocumentFolder, Candidate));

    if not IsInsideFolder(FullPath, DocumentFolder) then
      Exit(False);

    if not SameText(TPath.GetExtension(FullPath), DocumentExtension) then
      Exit(False);

    if not TFile.Exists(FullPath) then
      Exit(False);

    FileName := FullPath;
    Result := True;
  except
    on EArgumentException do
      Result := False;
    on EInOutError do
      Result := False;
  end;
end;

// Keeps the part before the "#section" or "?query" a document may append. The
// studio opens the file itself; jumping to the section is not supported yet.
class function TPadLinkPolicy.WithoutFragment(const Url: string): string;
begin
  Result := Url;

  const FragmentStart = Result.IndexOf(FragmentSeparator);
  if FragmentStart >= 0 then
    Result := Result.Substring(0, FragmentStart);

  const QueryStart = Result.IndexOf(QuerySeparator);
  if QueryStart >= 0 then
    Result := Result.Substring(0, QueryStart);
end;

class function TPadLinkPolicy.LooksLikeDocumentPath(const Value: string): Boolean;
begin
  if Value = '' then
    Exit(False);

  // Anything carrying a scheme belongs to MayOpen, and anything rooted, drive
  // relative or UNC reaches outside the folder the document came from.
  if Value.Contains(UrlSchemeSeparator) then
    Exit(False);

  if Value.StartsWith(ForwardSlash) or Value.StartsWith(BackSlash) then
    Exit(False);

  Result := not TPath.IsPathRooted(Value);
end;

// Compares canonical paths, so neither "..", a doubled separator nor a
// differing case decides the outcome. The separator guard keeps a sibling
// folder whose name merely starts with the same text from counting as a child.
class function TPadLinkPolicy.IsInsideFolder(const Path, Folder: string): Boolean;
begin
  const Root = IncludeTrailingPathDelimiter(TPath.GetFullPath(Folder));

  Result := TPath.GetFullPath(Path).StartsWith(Root, True);
end;

class function TPadLinkPolicy.RefusalMessage(const Url: string): string;
const
  MessageFormat = 'This link was not opened because it does not point at a web address or an e-mail address:' +
    sLineBreak + sLineBreak + '%s';
begin
  Result := Format(MessageFormat, [Url]);
end;

end.
