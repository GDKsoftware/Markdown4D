unit Markdown4D.Layout.InlineHtml.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.InlineHtml;

type
  [TestFixture]
  TInlineHtmlTagTests = class
  public
    [Test]
    [TestCase('Opening', '<b>,b,False')]
    [TestCase('Closing', '</b>,b,True')]
    [TestCase('UpperCase', '<STRONG>,strong,False')]
    [TestCase('SelfClosing', '<br/>,br,False')]
    [TestCase('WithAttribute', '<span class="x">,span,False')]
    procedure Parse_Tag_ReadsNameAndDirection(const Literal, Name: string; const IsClosing: Boolean);

    [Test]
    [TestCase('DoubleQuotes', '<a href="https://example.com">,https://example.com')]
    [TestCase('SingleQuotes', '<a href=''docs.md''>,docs.md')]
    [TestCase('NoQuotes', '<a href=docs.md>,docs.md')]
    procedure Parse_Anchor_ReadsHref(const Literal, Href: string);

    [Test]
    procedure Parse_Comment_IsComment;

    [Test]
    [TestCase('b', 'b,Bold')]
    [TestCase('strong', 'strong,Bold')]
    [TestCase('i', 'i,Italic')]
    [TestCase('em', 'em,Italic')]
    [TestCase('code', 'code,Code')]
    [TestCase('kbd', 'kbd,Code')]
    [TestCase('samp', 'samp,Code')]
    [TestCase('s', 's,Strikethrough')]
    [TestCase('del', 'del,Strikethrough')]
    [TestCase('strike', 'strike,Strikethrough')]
    [TestCase('ins', 'ins,Underline')]
    [TestCase('sub', 'sub,Subscript')]
    [TestCase('sup', 'sup,Superscript')]
    [TestCase('small', 'small,Small')]
    [TestCase('mark', 'mark,Mark')]
    [TestCase('br', 'br,LineBreak')]
    [TestCase('a', 'a,Link')]
    [TestCase('span', 'span,Hidden')]
    [TestCase('u', 'u,Hidden')]
    procedure Effect_TagName_ReturnsItsEffect(const Name: string; const Expected: TInlineHtmlEffect);
  end;

implementation

uses
  System.SysUtils;

procedure TInlineHtmlTagTests.Parse_Tag_ReadsNameAndDirection(const Literal, Name: string; const IsClosing: Boolean);
begin
  const Tag = TInlineHtmlTag.Parse(Literal);

  Assert.AreEqual(Name, Tag.Name);
  Assert.AreEqual(IsClosing, Tag.IsClosing);
end;

procedure TInlineHtmlTagTests.Parse_Anchor_ReadsHref(const Literal, Href: string);
begin
  const Tag = TInlineHtmlTag.Parse(Literal);

  Assert.AreEqual(Href, Tag.Href);
end;

procedure TInlineHtmlTagTests.Parse_Comment_IsComment;
begin
  const Tag = TInlineHtmlTag.Parse('<!-- not shown -->');

  Assert.IsTrue(Tag.IsComment);
end;

procedure TInlineHtmlTagTests.Effect_TagName_ReturnsItsEffect(const Name: string; const Expected: TInlineHtmlEffect);
begin
  const Tag = TInlineHtmlTag.Parse(Format('<%s>', [Name]));

  Assert.AreEqual<TInlineHtmlEffect>(Expected, Tag.Effect);
end;

end.
