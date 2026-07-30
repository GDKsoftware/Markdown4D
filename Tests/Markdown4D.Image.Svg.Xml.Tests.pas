unit Markdown4D.Image.Svg.Xml.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSvgXmlScannerTests = class
  private
    function ElementNames(const Text: string): string;

  public
    [Test]
    procedure ReadElement_NestedElements_ReportsOpeningAndClosingInOrder;

    [Test]
    procedure ReadElement_Attributes_AreReadWithBothQuoteStyles;

    [Test]
    procedure ReadElement_SelfClosing_IsMarked;

    [Test]
    procedure ReadElement_CommentsAndDoctype_AreStepped0ver;

    [Test]
    procedure ReadElement_Entities_AreDecodedInAttributeValues;

    [Test]
    procedure Attribute_MissingName_ReturnsTheDefault;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Image.Svg.Xml;

function TSvgXmlScannerTests.ElementNames(const Text: string): string;
begin
  Result := '';

  const Scanner = TSvgXmlScanner.Create(Text);
  try
    var Element: TSvgXmlElement;
    while Scanner.ReadElement(Element) do
    begin
      if Result <> '' then
        Result := Result + ' ';

      if Element.IsClosing then
        Result := Result + '/';

      Result := Result + Element.Name;
    end;
  finally
    Scanner.Free;
  end;
end;

procedure TSvgXmlScannerTests.ReadElement_NestedElements_ReportsOpeningAndClosingInOrder;
begin
  Assert.AreEqual('svg g rect /g /svg', ElementNames('<svg><g><rect/></g></svg>'));
end;

procedure TSvgXmlScannerTests.ReadElement_Attributes_AreReadWithBothQuoteStyles;
begin
  const Scanner = TSvgXmlScanner.Create('<rect x="10" y=''20'' width = "30" />');
  try
    var Element: TSvgXmlElement;
    Assert.IsTrue(Scanner.ReadElement(Element));

    Assert.AreEqual('10', Element.Attribute('x'));
    Assert.AreEqual('20', Element.Attribute('y'));
    Assert.AreEqual('30', Element.Attribute('width'));
  finally
    Scanner.Free;
  end;
end;

procedure TSvgXmlScannerTests.ReadElement_SelfClosing_IsMarked;
begin
  const Scanner = TSvgXmlScanner.Create('<circle r="4"/><g>');
  try
    var Element: TSvgXmlElement;
    Assert.IsTrue(Scanner.ReadElement(Element));
    Assert.IsTrue(Element.IsSelfClosing, 'A closing slash marks the element');

    Assert.IsTrue(Scanner.ReadElement(Element));
    Assert.IsFalse(Element.IsSelfClosing, 'A plain element is not self closing');
  finally
    Scanner.Free;
  end;
end;

procedure TSvgXmlScannerTests.ReadElement_CommentsAndDoctype_AreStepped0ver;
begin
  const Text = '<?xml version="1.0"?><!DOCTYPE svg><!-- <rect/> --><svg><![CDATA[ <g/> ]]><path/></svg>';

  Assert.AreEqual('svg path /svg', ElementNames(Text));
end;

procedure TSvgXmlScannerTests.ReadElement_Entities_AreDecodedInAttributeValues;
begin
  const Scanner = TSvgXmlScanner.Create('<path d="M0 0" title="a &amp; b &lt;c&gt; &#65;"/>');
  try
    var Element: TSvgXmlElement;
    Assert.IsTrue(Scanner.ReadElement(Element));

    Assert.AreEqual('a & b <c> A', Element.Attribute('title'));
  finally
    Scanner.Free;
  end;
end;

procedure TSvgXmlScannerTests.Attribute_MissingName_ReturnsTheDefault;
begin
  const Scanner = TSvgXmlScanner.Create('<rect/>');
  try
    var Element: TSvgXmlElement;
    Assert.IsTrue(Scanner.ReadElement(Element));

    Assert.AreEqual('0', Element.Attribute('x', '0'));

    var Value: string;
    Assert.IsFalse(Element.TryAttribute('x', Value));
  finally
    Scanner.Free;
  end;
end;

end.
