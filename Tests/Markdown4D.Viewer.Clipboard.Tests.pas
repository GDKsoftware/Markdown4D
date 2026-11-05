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

  public
    [Test]
    procedure MathMLData_IsUtf16WithoutNullAtTheEnd;

    [Test]
    procedure TextData_EndsInNullCharacter;
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

end.
