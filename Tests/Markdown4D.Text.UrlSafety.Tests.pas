unit Markdown4D.Text.UrlSafety.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TUrlSafetyTests = class
  public
    [Test]
    [TestCase('plain', 'javascript:alert(1)')]
    [TestCase('mixed case', 'JaVaScRiPt:alert(1)')]
    [TestCase('leading space', ' javascript:alert(1)')]
    [TestCase('leading tab', #9'javascript:alert(1)')]
    [TestCase('inner tab', 'java'#9'script:alert(1)')]
    [TestCase('vbscript', 'vbscript:msgbox(1)')]
    [TestCase('file', 'file:///C:/Windows/System32/calc.exe')]
    [TestCase('data html', 'data:text/html;base64,PHNjcmlwdD4=')]
    [TestCase('data svg', 'data:image/svg+xml;base64,PHN2Zz4=')]
    procedure IsDangerous_ScriptingDestination_ReturnsTrue(const Url: string);

    [Test]
    [TestCase('https', 'https://example.com/page')]
    [TestCase('http', 'http://example.com/page')]
    [TestCase('mailto', 'mailto:someone@example.com')]
    [TestCase('relative', './other.md')]
    [TestCase('anchor', '#section')]
    [TestCase('empty', '')]
    [TestCase('data png', 'data:image/png;base64,iVBORw0KGgo=')]
    [TestCase('data gif', 'data:image/gif;base64,R0lGODlh')]
    [TestCase('data jpeg', 'data:image/jpeg;base64,/9j/4AAQ')]
    [TestCase('data webp', 'data:image/webp;base64,UklGRg==')]
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
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Text.UrlSafety;

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

end.
