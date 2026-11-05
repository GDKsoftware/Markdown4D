unit Markdown4D.Viewer.Clipboard.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownMathClipboardTests = class
  private
    const
      MathML = '<math xmlns="http://www.w3.org/1998/Math/MathML"><mi>x</mi></math>';
    class function HeaderValue(const Document, Name: string): Integer; static;

  public
    [Test]
    procedure MathMLData_IsUtf16WithoutNullAtTheEnd;

    [Test]
    procedure TextData_EndsInNullCharacter;

    [Test]
    procedure HtmlData_HeaderPointsAtDocumentAndFragment;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Viewer.Clipboard;

// Word pastes the MathML formats as plain text when they end in a null.
procedure TMarkdownMathClipboardTests.MathMLData_IsUtf16WithoutNullAtTheEnd;
begin
  const Data = TMarkdownMathClipboard.MathMLData(MathML);

  Assert.AreEqual(MathML, TEncoding.Unicode.GetString(Data));
  Assert.AreEqual(Length(MathML) * SizeOf(Char), Integer(Length(Data)));
end;

procedure TMarkdownMathClipboardTests.TextData_EndsInNullCharacter;
begin
  const Data = TMarkdownMathClipboard.TextData('x2');

  Assert.AreEqual('x2'#0, TEncoding.Unicode.GetString(Data));
end;

// The offsets count bytes of UTF-8, so a letter outside ASCII counts twice.
procedure TMarkdownMathClipboardTests.HtmlData_HeaderPointsAtDocumentAndFragment;
begin
  const Fragment = '<p>'#$03C0'</p>';
  const Data = TMarkdownMathClipboard.HtmlData(Fragment);
  const Document = TEncoding.UTF8.GetString(Data);

  const StartHtml = HeaderValue(Document, 'StartHTML');
  const EndHtml = HeaderValue(Document, 'EndHTML');
  const StartFragment = HeaderValue(Document, 'StartFragment');
  const EndFragment = HeaderValue(Document, 'EndFragment');

  const Html = TEncoding.UTF8.GetString(Data, StartHtml, EndHtml - StartHtml);
  const Copied = TEncoding.UTF8.GetString(Data, StartFragment, EndFragment - StartFragment);
  Assert.StartsWith('<html>', Html);
  Assert.EndsWith('</html>', Html);
  Assert.AreEqual(Fragment, Copied);
  Assert.AreEqual(0, Integer(Data[High(Data)]), 'the document ends in a null character');
end;

class function TMarkdownMathClipboardTests.HeaderValue(const Document, Name: string): Integer;
begin
  const Key = Name + ':';
  const KeyStart = Document.IndexOf(Key);
  const Digits = Document.Substring(KeyStart + Key.Length, 10);
  Result := Digits.ToInteger;
end;

end.
