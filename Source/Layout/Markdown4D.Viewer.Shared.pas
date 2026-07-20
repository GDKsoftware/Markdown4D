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
    class function TryResolveImageUrl(const Source, BaseUrl, DocumentFolder: string; out Url: string): Boolean;
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
  Url := Source;
  try
    if Source.Contains(UrlSchemeSeparator) then
      Exit(True);

    if BaseUrl <> '' then
    begin
      if BaseUrl.Contains(UrlSchemeSeparator) then
        Url := BaseUrl + Source
      else
        Url := TPath.Combine(BaseUrl, Source);
      Exit(True);
    end;

    const UsesDocumentFolder = (DocumentFolder <> '') and not TPath.IsPathRooted(Source);
    if UsesDocumentFolder then
      Url := TPath.Combine(DocumentFolder, Source);

    Result := True;
  except
    on Exception do
      Result := False;
  end;
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
