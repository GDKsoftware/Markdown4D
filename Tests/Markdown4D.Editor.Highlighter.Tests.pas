unit Markdown4D.Editor.Highlighter.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.Highlighter;

type
  [TestFixture]
  TMarkdownEditorHighlighterTests = class
  private
    var
      FHighlighter: TMarkdownSourceHighlighter;
    function TokenKinds(const Line: TMarkdownSourceLine): TArray<TMarkdownSourceTokenKind>;
    function CoversLineFully(const Line: TMarkdownSourceLine; const Text: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Heading_ProducesMarkerAndText;

    [Test]
    procedure Emphasis_ProducesDelimiterTokens;

    [Test]
    procedure CodeSpan_ProducesBacktickDelimiters;

    [Test]
    procedure BlockQuote_ProducesMarker;

    [Test]
    procedure ListItem_ProducesMarker;

    [Test]
    procedure Link_ProducesBracketsAndUrl;

    [Test]
    procedure PlainLine_IsSinglePlainToken;

    [Test]
    procedure FenceOpen_CarriesStateToNextLine;

    [Test]
    procedure FenceContent_DelegatesToRegisteredLanguage;

    [Test]
    procedure Tokens_CoverEachLineFully;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Highlighter.Interfaces,
  Markdown4D.Highlighter.Pascal;

procedure TMarkdownEditorHighlighterTests.Setup;
begin
  FHighlighter := TMarkdownSourceHighlighter.Create;
end;

procedure TMarkdownEditorHighlighterTests.TearDown;
begin
  FHighlighter.Free;
  THighlighterRegistry.Clear;
end;

function TMarkdownEditorHighlighterTests.TokenKinds(const Line: TMarkdownSourceLine): TArray<TMarkdownSourceTokenKind>;
begin
  Result := [];
  for var Token in Line.Tokens do
    Result := Result + [Token.Kind];
end;

function TMarkdownEditorHighlighterTests.CoversLineFully(const Line: TMarkdownSourceLine; const Text: string): Boolean;
begin
  var Cursor := 1;
  for var Token in Line.Tokens do
  begin
    if Token.Start <> Cursor then
      Exit(False);
    Cursor := Cursor + Token.Length;
  end;

  Result := Cursor = Length(Text) + 1;
end;

procedure TMarkdownEditorHighlighterTests.Heading_ProducesMarkerAndText;
begin
  const Line = FHighlighter.TokenizeLine('## Title', TMarkdownSourceHighlighter.DefaultState);
  Assert.AreEqual<TArray<TMarkdownSourceTokenKind>>(
    [TMarkdownSourceTokenKind.HeadingMarker, TMarkdownSourceTokenKind.HeadingText], TokenKinds(Line));
end;

procedure TMarkdownEditorHighlighterTests.Emphasis_ProducesDelimiterTokens;
begin
  const Line = FHighlighter.TokenizeLine('a *b* c', TMarkdownSourceHighlighter.DefaultState);
  Assert.Contains<TMarkdownSourceTokenKind>(TokenKinds(Line), TMarkdownSourceTokenKind.EmphasisDelimiter);
end;

procedure TMarkdownEditorHighlighterTests.CodeSpan_ProducesBacktickDelimiters;
begin
  const Line = FHighlighter.TokenizeLine('use `code` here', TMarkdownSourceHighlighter.DefaultState);
  Assert.Contains<TMarkdownSourceTokenKind>(TokenKinds(Line), TMarkdownSourceTokenKind.CodeSpanDelimiter);
end;

procedure TMarkdownEditorHighlighterTests.BlockQuote_ProducesMarker;
begin
  const Line = FHighlighter.TokenizeLine('> quoted', TMarkdownSourceHighlighter.DefaultState);
  Assert.Contains<TMarkdownSourceTokenKind>(TokenKinds(Line), TMarkdownSourceTokenKind.BlockQuoteMarker);
end;

procedure TMarkdownEditorHighlighterTests.ListItem_ProducesMarker;
begin
  const Line = FHighlighter.TokenizeLine('- item', TMarkdownSourceHighlighter.DefaultState);
  Assert.Contains<TMarkdownSourceTokenKind>(TokenKinds(Line), TMarkdownSourceTokenKind.ListMarker);
end;

procedure TMarkdownEditorHighlighterTests.Link_ProducesBracketsAndUrl;
begin
  const Line = FHighlighter.TokenizeLine('[text](http://x)', TMarkdownSourceHighlighter.DefaultState);
  Assert.Contains<TMarkdownSourceTokenKind>(TokenKinds(Line), TMarkdownSourceTokenKind.LinkUrl);
end;

procedure TMarkdownEditorHighlighterTests.PlainLine_IsSinglePlainToken;
begin
  const Line = FHighlighter.TokenizeLine('just some prose', TMarkdownSourceHighlighter.DefaultState);
  Assert.AreEqual<TArray<TMarkdownSourceTokenKind>>([TMarkdownSourceTokenKind.Plain], TokenKinds(Line));
end;

procedure TMarkdownEditorHighlighterTests.FenceOpen_CarriesStateToNextLine;
begin
  const Opened = FHighlighter.TokenizeLine('```pascal', TMarkdownSourceHighlighter.DefaultState);
  Assert.AreNotEqual(TMarkdownSourceHighlighter.DefaultState, Opened.NextState);
end;

procedure TMarkdownEditorHighlighterTests.FenceContent_DelegatesToRegisteredLanguage;
begin
  THighlighterRegistry.Register('pascal', TPascalSyntaxHighlighter.Create);
  const Opened = FHighlighter.TokenizeLine('```pascal', TMarkdownSourceHighlighter.DefaultState);
  const Content = FHighlighter.TokenizeLine('begin', Opened.NextState);
  Assert.Contains<TMarkdownSourceTokenKind>(TokenKinds(Content), TMarkdownSourceTokenKind.FenceContent);
end;

procedure TMarkdownEditorHighlighterTests.Tokens_CoverEachLineFully;
begin
  const Text = '## Title';
  const Line = FHighlighter.TokenizeLine(Text, TMarkdownSourceHighlighter.DefaultState);
  Assert.IsTrue(CoversLineFully(Line, Text));
end;

end.
