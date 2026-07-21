unit MarkdownPad.HtmlExport.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownHtmlExportTests = class
  private
    class function ReadHeaderInt(const Payload, Name: string): Integer; static;

  public
    [Test]
    procedure BuildDocument_ContainsHtml5Skeleton;

    [Test]
    procedure BuildDocument_EscapesTitle;

    [Test]
    procedure BuildDocument_DarkVsLightBackground;

    [Test]
    procedure BuildClipboardHtml_HasHeaderAndMarkers;

    [Test]
    procedure BuildClipboardHtml_ByteOffsetsAreAccurate_Ascii;

    [Test]
    procedure BuildClipboardHtml_NonAsciiUsesByteOffsets;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  MarkdownPad.HtmlExport;

class function TMarkdownHtmlExportTests.ReadHeaderInt(const Payload, Name: string): Integer;
begin
  const Marker = Name + ':';
  const MarkerAt = Payload.IndexOf(Marker);
  Assert.IsTrue(MarkerAt >= 0);

  Result := StrToInt(Payload.Substring(MarkerAt + Length(Marker), 10));
end;

procedure TMarkdownHtmlExportTests.BuildDocument_ContainsHtml5Skeleton;
begin
  const Document = TMarkdownHtmlExport.BuildDocument('# Hi', 'Doc', False);

  Assert.IsTrue(Document.Contains('<!DOCTYPE html>'));
  Assert.IsTrue(Document.Contains('<title>'));
  Assert.IsTrue(Document.Contains('</html>'));
  Assert.IsTrue(Document.Contains('<h1>'));
end;

procedure TMarkdownHtmlExportTests.BuildDocument_EscapesTitle;
begin
  const Document = TMarkdownHtmlExport.BuildDocument('body', '<A & B>', False);

  Assert.IsTrue(Document.Contains('<title>&lt;A &amp; B&gt;</title>'));
end;

procedure TMarkdownHtmlExportTests.BuildDocument_DarkVsLightBackground;
begin
  const Dark = TMarkdownHtmlExport.BuildDocument('body', 'Doc', True);
  const Light = TMarkdownHtmlExport.BuildDocument('body', 'Doc', False);

  Assert.IsTrue(Dark.ToLower.Contains('#0d1117'));
  Assert.IsTrue(Light.ToLower.Contains('#ffffff'));
end;

procedure TMarkdownHtmlExportTests.BuildClipboardHtml_HasHeaderAndMarkers;
begin
  const Payload = TMarkdownHtmlExport.BuildClipboardHtml('<p>hi</p>');

  Assert.IsTrue(Payload.Contains('Version:0.9'));
  Assert.IsTrue(Payload.Contains('StartHTML:'));
  Assert.IsTrue(Payload.Contains('EndHTML:'));
  Assert.IsTrue(Payload.Contains('StartFragment:'));
  Assert.IsTrue(Payload.Contains('EndFragment:'));
  Assert.IsTrue(Payload.Contains('<!--StartFragment-->'));
  Assert.IsTrue(Payload.Contains('<!--EndFragment-->'));
end;

procedure TMarkdownHtmlExportTests.BuildClipboardHtml_ByteOffsetsAreAccurate_Ascii;
begin
  const Html = '<p>hi</p>';
  const Payload = TMarkdownHtmlExport.BuildClipboardHtml(Html);

  const StartHtml = ReadHeaderInt(Payload, 'StartHTML');
  const EndHtml = ReadHeaderInt(Payload, 'EndHTML');
  const StartFragment = ReadHeaderInt(Payload, 'StartFragment');
  const EndFragment = ReadHeaderInt(Payload, 'EndFragment');

  const Bytes = TEncoding.UTF8.GetBytes(Payload);
  Assert.AreEqual(EndHtml, Length(Bytes));

  const FromStartHtml = TEncoding.UTF8.GetString(Bytes, StartHtml, Length(Bytes) - StartHtml);
  Assert.IsTrue(FromStartHtml.StartsWith('<html>'));

  const Fragment = TEncoding.UTF8.GetString(Bytes, StartFragment, EndFragment - StartFragment);
  Assert.AreEqual(Html, Fragment);
end;

procedure TMarkdownHtmlExportTests.BuildClipboardHtml_NonAsciiUsesByteOffsets;
begin
  const Html = 'x' + #$20AC + 'y';
  const Payload = TMarkdownHtmlExport.BuildClipboardHtml(Html);

  const StartFragment = ReadHeaderInt(Payload, 'StartFragment');
  const EndFragment = ReadHeaderInt(Payload, 'EndFragment');

  Assert.AreEqual(TEncoding.UTF8.GetByteCount(Html), EndFragment - StartFragment);

  const Bytes = TEncoding.UTF8.GetBytes(Payload);
  const Fragment = TEncoding.UTF8.GetString(Bytes, StartFragment, EndFragment - StartFragment);
  Assert.AreEqual(Html, Fragment);
end;

end.
