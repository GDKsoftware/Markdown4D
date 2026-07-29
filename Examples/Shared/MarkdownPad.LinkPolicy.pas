unit MarkdownPad.LinkPolicy;

{$SCOPEDENUMS ON}

// A link in the preview is a string that came out of the document, and the pad
// opens documents from anywhere: a downloaded file, a drag and drop, the .md
// association. Handing such a string straight to the shell turns
// "[Release notes](file:///C:/Users/Public/payload.exe)" into a one-click
// launcher, so the pad opens the schemes a reader expects from a document,
// opens a neighbouring markdown file itself, and refuses everything else.

interface

uses
  MarkdownPad.Defines;

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

  public
    class function MayOpen(const Url: string): Boolean;
    // A link to a markdown file next to the current document is opened by the
    // pad itself instead of by the shell. Only a relative path qualifies: an
    // absolute or UNC path would let a document point at a server of someone
    // else's choosing, and reaching for that share hands over the credentials
    // Windows offers it.
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
// pad opens the file itself; jumping to the section is not supported yet.
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

class function TPadLinkPolicy.RefusalMessage(const Url: string): string;
const
  MessageFormat = 'This link was not opened because it does not point at a web address or an e-mail address:' +
    sLineBreak + sLineBreak + '%s';
begin
  Result := Format(MessageFormat, [Url]);
end;

end.
