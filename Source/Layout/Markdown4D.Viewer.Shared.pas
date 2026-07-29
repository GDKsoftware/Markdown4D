unit Markdown4D.Viewer.Shared;

{$SCOPEDENUMS ON}

interface

uses
  System.UITypes,
  Markdown4D.Layout.Interfaces;

type
  TMarkdownViewerShared = class
  public
    class function AlphaOf(const Color: TLayoutColor): Byte;
    class function FontStylesOf(const Font: TMarkdownFontStyle): TFontStyles;
    class function TryResolveGenericFamily(const FamilyName: string; out Resolved: string): Boolean;
    class function IsHttpUrl(const Url: string): Boolean;
    class function TryResolveImageUrl(const Source, BaseUrl, DocumentFolder: string;
      out Url: string): Boolean; overload;
    class function TryResolveImageUrl(const Source, BaseUrl, DocumentFolder: string;
      const RestrictToDocumentFolder: Boolean; out Url: string): Boolean; overload;
    class function NormalizedLocalPath(const Value: string): string;
    class function IsInsideFolder(const Path, Folder: string): Boolean;
    class procedure RegisterDefaultHighlighters;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Markdown4D.Defines,
  Markdown4D.Layout.Defaults,
  Markdown4D.Highlighter.Interfaces,
  Markdown4D.Highlighter.Pascal,
  Markdown4D.Highlighter.Sql,
  Markdown4D.Highlighter.Json,
  Markdown4D.Highlighter.Xml;

class function TMarkdownViewerShared.AlphaOf(const Color: TLayoutColor): Byte;
begin
  Result := Color shr 24;
end;

class function TMarkdownViewerShared.FontStylesOf(const Font: TMarkdownFontStyle): TFontStyles;
begin
  Result := [];
  if Font.Bold then
    Include(Result, TFontStyle.fsBold);
  if Font.Italic then
    Include(Result, TFontStyle.fsItalic);
  if Font.Underline then
    Include(Result, TFontStyle.fsUnderline);
  if Font.Strikeout then
    Include(Result, TFontStyle.fsStrikeOut);
end;

class function TMarkdownViewerShared.TryResolveGenericFamily(const FamilyName: string; out Resolved: string): Boolean;
begin
  Result := True;

  if SameText(FamilyName, MonospaceFamilyName) then
    Resolved := MonospaceFallbackFamilyName
  else if SameText(FamilyName, SansSerifFamilyName) then
    Resolved := DefaultFallbackFamilyName
  else if SameText(FamilyName, SerifFamilyName) then
    Resolved := SerifFallbackFamilyName
  else
  begin
    Resolved := '';
    Result := False;
  end;
end;

class function TMarkdownViewerShared.IsHttpUrl(const Url: string): Boolean;
begin
  Result := Url.StartsWith(HttpSchemePrefix, True) or Url.StartsWith(HttpsSchemePrefix, True);
end;

class function TMarkdownViewerShared.TryResolveImageUrl(const Source, BaseUrl, DocumentFolder: string;
  out Url: string): Boolean;
begin
  Result := TryResolveImageUrl(Source, BaseUrl, DocumentFolder, False, Url);
end;

class function TMarkdownViewerShared.TryResolveImageUrl(const Source, BaseUrl, DocumentFolder: string;
  const RestrictToDocumentFolder: Boolean; out Url: string): Boolean;
begin
  Url := Source;
  try
    if Source.Contains(UrlSchemeSeparator) then
      Exit(True);

    if BaseUrl <> '' then
    begin
      if BaseUrl.Contains(UrlSchemeSeparator) then
        Url := BaseUrl + Source
      else
        Url := NormalizedLocalPath(TPath.Combine(BaseUrl, Source));
      Exit(True);
    end;

    const UsesDocumentFolder = (DocumentFolder <> '') and not TPath.IsPathRooted(Source);
    if UsesDocumentFolder then
      Url := NormalizedLocalPath(TPath.Combine(DocumentFolder, Source));

    const EscapesDocumentFolder = RestrictToDocumentFolder and (DocumentFolder <> '') and
      (not IsInsideFolder(Url, DocumentFolder));
    if EscapesDocumentFolder then
    begin
      Url := '';
      Exit(False);
    end;

    Result := True;
  except
    on EArgumentException do
      Result := False;
    on EInOutError do
      Result := False;
  end;
end;

// Compares canonical paths, so neither "..", a doubled separator nor a differing
// case decides the outcome. The separator guard keeps "C:\docs-private" from
// counting as a child of "C:\docs".
class function TMarkdownViewerShared.IsInsideFolder(const Path, Folder: string): Boolean;
begin
  const FullPath = NormalizedLocalPath(Path);
  const Root = IncludeTrailingPathDelimiter(NormalizedLocalPath(Folder));

  Result := FullPath.StartsWith(Root, True);
end;

// Resolves the ".." segments a document can put in an image path, so callers
// compare, cache and open one canonical path instead of several spellings of
// the same file. Relative results are left alone: they carry no root to resolve
// against and would otherwise be bound to the process working directory.
class function TMarkdownViewerShared.NormalizedLocalPath(const Value: string): string;
begin
  if not TPath.IsPathRooted(Value) then
    Exit(Value);

  Result := TPath.GetFullPath(Value);
end;

class procedure TMarkdownViewerShared.RegisterDefaultHighlighters;
begin
  var Existing: IMarkdownSyntaxHighlighter;

  if not THighlighterRegistry.TryGet(PascalLanguageName, Existing) then
    THighlighterRegistry.Register(PascalLanguageName, TPascalSyntaxHighlighter.Create);

  if not THighlighterRegistry.TryGet(SqlLanguageName, Existing) then
    THighlighterRegistry.Register(SqlLanguageName, TSqlSyntaxHighlighter.Create);

  if not THighlighterRegistry.TryGet(JsonLanguageName, Existing) then
    THighlighterRegistry.Register(JsonLanguageName, TJsonSyntaxHighlighter.Create);

  if not THighlighterRegistry.TryGet(XmlLanguageName, Existing) then
    THighlighterRegistry.Register(XmlLanguageName, TXmlSyntaxHighlighter.Create);
end;

end.
