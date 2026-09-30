unit Markdown4D.Text.UrlSafety.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TUrlSafetyTests = class
  private
    class function WebSchemes: TArray<string>;

  public
    [Test]
    [TestCase('plain', 'javascript:alert(1)')]
    [TestCase('mixed case', 'JaVaScRiPt:alert(1)')]
    [TestCase('leading space', ' javascript:alert(1)')]
    [TestCase('leading tab', #9'javascript:alert(1)')]
    [TestCase('inner tab', 'java'#9'script:alert(1)')]
    [TestCase('vbscript', 'vbscript:msgbox(1)')]
    [TestCase('file', 'file:///C:/Windows/System32/calc.exe')]
    [TestCase('data html', 'data:text/html;base64,PHNjcmlwdD4=', '|')]
    [TestCase('data svg', 'data:image/svg+xml;base64,PHN2Zz4=', '|')]
    procedure IsDangerous_ScriptingDestination_ReturnsTrue(const Url: string);

    [Test]
    [TestCase('https', 'https://example.com/page')]
    [TestCase('http', 'http://example.com/page')]
    [TestCase('mailto', 'mailto:someone@example.com')]
    [TestCase('relative', './other.md')]
    [TestCase('anchor', '#section')]
    [TestCase('empty', '')]
    [TestCase('data png', 'data:image/png;base64,iVBORw0KGgo=', '|')]
    [TestCase('data gif', 'data:image/gif;base64,R0lGODlh', '|')]
    [TestCase('data jpeg', 'data:image/jpeg;base64,/9j/4AAQ', '|')]
    [TestCase('data webp', 'data:image/webp;base64,UklGRg==', '|')]
    procedure IsDangerous_ReadableDestination_ReturnsFalse(const Url: string);

    [Test]
    procedure Sanitized_ScriptingDestination_ReturnsEmptyString;

    [Test]
    procedure Sanitized_ReadableDestination_ReturnsInput;

    [Test]
    procedure ToHtml_JavaScriptLink_EmptiesHref;

    [Test]
    procedure ToHtml_EntityEncodedJavaScriptLink_EmptiesHref;

    [Test]
    procedure ToHtml_ScriptingImage_EmptiesSource;

    [Test]
    procedure ToHtml_PngDataImage_KeepsSource;

    [Test]
    procedure ToHtml_OrdinaryLink_KeepsHref;

    [Test]
    procedure ToUnsafeHtml_JavaScriptLink_KeepsHref;

    [Test]
    [TestCase('https', 'https://example.com/page')]
    [TestCase('upper case scheme', 'HTTP://example.com/page')]
    [TestCase('relative path', 'docs/readme.md')]
    [TestCase('colon after path', 'docs/notes:1')]
    [TestCase('absolute path', '/path')]
    [TestCase('fragment', '#section')]
    [TestCase('query', '?page=2')]
    [TestCase('empty', '')]
    [TestCase('protocol relative', '//example.com/page')]
    [TestCase('non-ASCII letter before colon', 'r'#$00E9'sum'#$00E9':notes.md')]
    [TestCase('http without slashes', 'http:example.com')]
    procedure IsAllowed_RelativeOrListedScheme_ReturnsTrue(const Url: string);

    [Test]
    [TestCase('ftp', 'ftp://example.com')]
    [TestCase('mailto', 'mailto:someone@example.com')]
    [TestCase('mixed case javascript', 'JaVaScRiPt:alert(1)')]
    [TestCase('leading space', ' javascript:alert(1)')]
    [TestCase('inner tab', 'java'#9'script:alert(1)')]
    [TestCase('control character', 'java'#1'script:alert(1)')]
    [TestCase('png data', 'data:image/png;base64,iVBORw0KGgo=', '|')]
    [TestCase('long made-up scheme', 'averylongmadeupschemenamebeyondthewindow:x')]
    [TestCase('drive letter', 'C:\Windows\System32')]
    procedure IsAllowed_OtherScheme_ReturnsFalse(const Url: string);

    [Test]
    [TestCase('double slash', '//example.com/page')]
    [TestCase('double backslash', '\\example.com\page')]
    [TestCase('mixed slashes', '/\example.com/page')]
    [TestCase('tab between slashes', '/'#9'/example.com/page')]
    procedure IsAllowed_ProtocolRelativeWithoutHttps_ReturnsFalse(const Url: string);

    [Test]
    [TestCase('javascript', 'javascript:alert(1)|javascript', '|')]
    [TestCase('vbscript', 'vbscript:msgbox(1)|vbscript', '|')]
    [TestCase('file', 'file:///etc/passwd|file', '|')]
    [TestCase('html data', 'data:text/html;base64,PHNjcmlwdD4=|data', '|')]
    procedure IsAllowed_DangerousSchemeOnTheList_ReturnsFalse(const Url, ListedScheme: string);

    [Test]
    procedure IsAllowed_SchemeWithSymbols_MatchesListedName;

    [Test]
    procedure IsAllowed_ListEntryWithCaseAndColon_StillMatches;

    [Test]
    [TestCase('upper case', 'HTTPS|https', '|')]
    [TestCase('trailing colon', 'https:|https', '|')]
    [TestCase('surrounding spaces', ' ftp |ftp', '|')]
    procedure NormalizedScheme_SchemeName_ReturnsBareLowerCaseName(const Scheme, Expected: string);

    [Test]
    [TestCase('with slashes', 'https://')]
    [TestCase('empty', '')]
    [TestCase('starts with digit', '1http')]
    [TestCase('inner space', 'ht tp')]
    procedure NormalizedScheme_NotAScheme_RaisesMarkdownError(const Scheme: string);
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Text.UrlSafety;

class function TUrlSafetyTests.WebSchemes: TArray<string>;
begin
  Result := ['http', 'https'];
end;

procedure TUrlSafetyTests.IsDangerous_ScriptingDestination_ReturnsTrue(const Url: string);
begin
  Assert.IsTrue(TMarkdownUrlSafety.IsDangerous(Url), Format('<%s> must be rejected', [Url]));
end;

procedure TUrlSafetyTests.IsDangerous_ReadableDestination_ReturnsFalse(const Url: string);
begin
  Assert.IsFalse(TMarkdownUrlSafety.IsDangerous(Url), Format('<%s> must be accepted', [Url]));
end;

procedure TUrlSafetyTests.Sanitized_ScriptingDestination_ReturnsEmptyString;
begin
  Assert.AreEqual('', TMarkdownUrlSafety.Sanitized('javascript:alert(1)'));
end;

procedure TUrlSafetyTests.Sanitized_ReadableDestination_ReturnsInput;
begin
  const Url = 'https://example.com/page?a=1';

  Assert.AreEqual(Url, TMarkdownUrlSafety.Sanitized(Url));
end;

procedure TUrlSafetyTests.ToHtml_JavaScriptLink_EmptiesHref;
begin
  Assert.AreEqual('<p><a href="">x</a></p>'#10, TMarkdown.ToHtml('[x](javascript:alert(1))'));
end;

// The destination is entity-decoded before it is judged, so an encoded scheme
// cannot slip past the check.
procedure TUrlSafetyTests.ToHtml_EntityEncodedJavaScriptLink_EmptiesHref;
begin
  Assert.AreEqual('<p><a href="">x</a></p>'#10, TMarkdown.ToHtml('[x](&#106;avascript:alert(1))'));
end;

procedure TUrlSafetyTests.ToHtml_ScriptingImage_EmptiesSource;
begin
  Assert.AreEqual('<p><img src="" alt="x" /></p>'#10,
    TMarkdown.ToHtml('![x](data:text/html;base64,PHNjcmlwdD4=)'));
end;

procedure TUrlSafetyTests.ToHtml_PngDataImage_KeepsSource;
begin
  Assert.AreEqual('<p><img src="data:image/png;base64,iVBORw0KGgo=" alt="x" /></p>'#10,
    TMarkdown.ToHtml('![x](data:image/png;base64,iVBORw0KGgo=)'));
end;

procedure TUrlSafetyTests.ToHtml_OrdinaryLink_KeepsHref;
begin
  Assert.AreEqual('<p><a href="https://example.com/page">x</a></p>'#10,
    TMarkdown.ToHtml('[x](https://example.com/page)'));
end;

procedure TUrlSafetyTests.ToUnsafeHtml_JavaScriptLink_KeepsHref;
begin
  Assert.AreEqual('<p><a href="javascript:alert(1)">x</a></p>'#10,
    TMarkdown.ToUnsafeHtml('[x](javascript:alert(1))'));
end;

procedure TUrlSafetyTests.IsAllowed_RelativeOrListedScheme_ReturnsTrue(const Url: string);
begin
  const IsAllowed = (TMarkdownUrlSafety.IsAllowed(Url, WebSchemes));

  const Message = Format('<%s> must be allowed', [Url]);
  Assert.IsTrue(IsAllowed, Message);
end;

procedure TUrlSafetyTests.IsAllowed_OtherScheme_ReturnsFalse(const Url: string);
begin
  const IsAllowed = (TMarkdownUrlSafety.IsAllowed(Url, WebSchemes));

  const Message = Format('<%s> must be rejected', [Url]);
  Assert.IsFalse(IsAllowed, Message);
end;

procedure TUrlSafetyTests.IsAllowed_ProtocolRelativeWithoutHttps_ReturnsFalse(const Url: string);
begin
  const HttpOnly: TArray<string> = ['http'];

  const IsAllowed = (TMarkdownUrlSafety.IsAllowed(Url, HttpOnly));

  const Message = Format('<%s> must be rejected without https on the list', [Url]);
  Assert.IsFalse(IsAllowed, Message);
end;

procedure TUrlSafetyTests.IsAllowed_DangerousSchemeOnTheList_ReturnsFalse(const Url, ListedScheme: string);
begin
  const Listed: TArray<string> = [ListedScheme];

  const IsAllowed = (TMarkdownUrlSafety.IsAllowed(Url, Listed));

  Assert.IsFalse(IsAllowed);
end;

procedure TUrlSafetyTests.IsAllowed_SchemeWithSymbols_MatchesListedName;
begin
  const Listed: TArray<string> = ['irc+ssh.v2-x'];

  const IsAllowed = (TMarkdownUrlSafety.IsAllowed('irc+ssh.v2-x:host', Listed));

  Assert.IsTrue(IsAllowed);
end;

procedure TUrlSafetyTests.IsAllowed_ListEntryWithCaseAndColon_StillMatches;
begin
  const Listed: TArray<string> = ['HTTPS:'];

  const IsAllowed = (TMarkdownUrlSafety.IsAllowed('https://example.com', Listed));

  Assert.IsTrue(IsAllowed);
end;

procedure TUrlSafetyTests.NormalizedScheme_SchemeName_ReturnsBareLowerCaseName(const Scheme, Expected: string);
begin
  const Normalized = TMarkdownUrlSafety.NormalizedScheme(Scheme);

  Assert.AreEqual(Expected, Normalized);
end;

procedure TUrlSafetyTests.NormalizedScheme_NotAScheme_RaisesMarkdownError(const Scheme: string);
begin
  Assert.WillRaise(
    procedure
    begin
      TMarkdownUrlSafety.NormalizedScheme(Scheme);
    end, EMarkdownError);
end;

end.