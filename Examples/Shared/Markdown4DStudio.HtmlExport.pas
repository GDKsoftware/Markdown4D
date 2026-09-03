unit Markdown4DStudio.HtmlExport;

{$SCOPEDENUMS ON}

interface

type
  TMarkdownHtmlExport = class
  private
    class function EscapeTitle(const Title: string): string;
    class function StyleSheet(const Dark: Boolean): string;

  public
    class function BuildDocument(const Markdown: string; const Title: string; const Dark: Boolean): string;
    class function BuildClipboardHtml(const Html: string): string;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  Markdown4D,
  Markdown4D.Defines;

class function TMarkdownHtmlExport.BuildDocument(const Markdown: string; const Title: string;
  const Dark: Boolean): string;
const
  DocumentTemplate =
    '<!DOCTYPE html>' + LineFeed +
    '<html lang="en">' + LineFeed +
    '<head>' + LineFeed +
    '<meta charset="utf-8">' + LineFeed +
    '<meta name="viewport" content="width=device-width, initial-scale=1">' + LineFeed +
    '<title>%s</title>' + LineFeed +
    '<style>' + LineFeed +
    '%s' + LineFeed +
    '</style>' + LineFeed +
    '</head>' + LineFeed +
    '<body>' + LineFeed +
    '<main class="markdown-body">' + LineFeed +
    '%s</main>' + LineFeed +
    '</body>' + LineFeed +
    '</html>';
begin
  const Fragment = TMarkdown.ToHtml(Markdown, TMarkdownDialect.Gfm);
  const Css = StyleSheet(Dark);
  const SafeTitle = EscapeTitle(Title);

  Result := Format(DocumentTemplate, [SafeTitle, Css, Fragment]);
end;

class function TMarkdownHtmlExport.BuildClipboardHtml(const Html: string): string;
const
  EOL = #13#10;
  StartMarker = '<!--StartFragment-->';
  EndMarker = '<!--EndFragment-->';
  BodyOpen = '<html><body>' + EOL;
  BodyClose = EOL + '</body></html>';
  Placeholder = '0000000000';
  HeaderFormat =
    'Version:0.9' + EOL +
    'StartHTML:%s' + EOL +
    'EndHTML:%s' + EOL +
    'StartFragment:%s' + EOL +
    'EndFragment:%s' + EOL;
  NumberFormat = '%.10d';
begin
  var Header := Format(HeaderFormat, [Placeholder, Placeholder, Placeholder, Placeholder]);
  const StartHtml = TEncoding.UTF8.GetByteCount(Header);

  const PreFragment = Header + BodyOpen + StartMarker;
  const StartFragment = TEncoding.UTF8.GetByteCount(PreFragment);

  const EndFragment = StartFragment + TEncoding.UTF8.GetByteCount(Html);

  const Full = PreFragment + Html + EndMarker + BodyClose;
  const EndHtml = TEncoding.UTF8.GetByteCount(Full);

  Header := Format(HeaderFormat, [Format(NumberFormat, [StartHtml]), Format(NumberFormat, [EndHtml]),
    Format(NumberFormat, [StartFragment]), Format(NumberFormat, [EndFragment])]);

  Result := Header + BodyOpen + StartMarker + Html + EndMarker + BodyClose;
end;

class function TMarkdownHtmlExport.EscapeTitle(const Title: string): string;
begin
  Result := StringReplace(Title, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

class function TMarkdownHtmlExport.StyleSheet(const Dark: Boolean): string;
const
  Template =
    'body{margin:0;background:$BG;color:$TEXT}' + LineFeed +
    '.markdown-body{max-width:820px;margin:0 auto;padding:32px 24px;' +
    'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;' +
    'font-size:16px;line-height:1.5}' + LineFeed +
    '.markdown-body h1,.markdown-body h2,.markdown-body h3,' +
    '.markdown-body h4,.markdown-body h5,.markdown-body h6{margin:1.2em 0 0.6em;font-weight:600}' + LineFeed +
    'a{color:$LINK;text-decoration:none}' + LineFeed +
    'a:hover{text-decoration:underline}' + LineFeed +
    'code{font-family:Consolas,"Courier New",monospace;font-size:0.9em;' +
    'background:$SURFACE;padding:0.15em 0.3em;border-radius:4px}' + LineFeed +
    'pre{background:$SURFACE;padding:12px;border-radius:6px;overflow-x:auto}' + LineFeed +
    'pre code{background:none;padding:0}' + LineFeed +
    'blockquote{margin:0;padding:0 1em;border-left:4px solid $BORDER;color:$QUOTE}' + LineFeed +
    'table{border-collapse:collapse}' + LineFeed +
    'th,td{border:1px solid $BORDER;padding:6px 12px}' + LineFeed +
    'th{background:$SURFACE}' + LineFeed +
    'hr{border:0;border-top:1px solid $BORDER}' + LineFeed +
    'img{max-width:100%}';
begin
  var Css := Template;

  if Dark then
  begin
    Css := StringReplace(Css, '$BG', '#0d1117', [rfReplaceAll]);
    Css := StringReplace(Css, '$TEXT', '#e6edf3', [rfReplaceAll]);
    Css := StringReplace(Css, '$LINK', '#4493f8', [rfReplaceAll]);
    Css := StringReplace(Css, '$SURFACE', '#161b22', [rfReplaceAll]);
    Css := StringReplace(Css, '$BORDER', '#3d444d', [rfReplaceAll]);
    Css := StringReplace(Css, '$QUOTE', '#9198a1', [rfReplaceAll]);
  end
  else
  begin
    Css := StringReplace(Css, '$BG', '#ffffff', [rfReplaceAll]);
    Css := StringReplace(Css, '$TEXT', '#1f2328', [rfReplaceAll]);
    Css := StringReplace(Css, '$LINK', '#0969da', [rfReplaceAll]);
    Css := StringReplace(Css, '$SURFACE', '#f6f8fa', [rfReplaceAll]);
    Css := StringReplace(Css, '$BORDER', '#d0d7de', [rfReplaceAll]);
    Css := StringReplace(Css, '$QUOTE', '#59636e', [rfReplaceAll]);
  end;

  Result := Css;
end;

end.
