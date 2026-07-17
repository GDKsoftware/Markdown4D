unit Markdown4D.Highlighter.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Highlighter.Interfaces;

type
  [TestFixture]
  TSyntaxHighlighterTests = class
  private
    const
      FakeLanguageName = 'FakeLang';
      UnknownLanguageName = 'nosuchlanguage';
    class function CreatePascal: IMarkdownSyntaxHighlighter;
    class function CreateSql: IMarkdownSyntaxHighlighter;
    class function CreateJson: IMarkdownSyntaxHighlighter;
    class function CreateXml: IMarkdownSyntaxHighlighter;
    class function DescribeTokens(const Tokens: TArray<TSyntaxToken>): string;
    class procedure AssertCoverage(const Tokens: TArray<TSyntaxToken>; const LineLength: Integer);
    class procedure AssertLineTokens(const Line: TSyntaxLine; const LineText, Expected: string);
    class procedure AssertTokenizes(const Highlighter: IMarkdownSyntaxHighlighter; const LineText, Expected: string);

  public
    [Test]
    procedure Pascal_KeywordsNumbersAndPlainText_AreTokenized;

    [Test]
    procedure Pascal_Keywords_MatchCaseInsensitively;

    [Test]
    procedure Pascal_StringWithDoubledQuotes_IsSingleToken;

    [Test]
    procedure Pascal_AllThreeCommentForms_AreTokenized;

    [Test]
    procedure Pascal_DecimalAndHexNumbers_AreTokenized;

    [Test]
    procedure Pascal_Directive_IsDistinctFromComment;

    [Test]
    procedure Pascal_BraceComment_CarriesStateAcrossLines;

    [Test]
    procedure Pascal_StarComment_CarriesStateAcrossLines;

    [Test]
    procedure Sql_KeywordsAndNumbers_AreTokenized;

    [Test]
    procedure Sql_Keywords_MatchCaseInsensitively;

    [Test]
    procedure Sql_StringWithDoubledQuote_IsSingleToken;

    [Test]
    procedure Sql_LineComment_RunsToEndOfLine;

    [Test]
    procedure Sql_BlockComment_WithinSingleLine;

    [Test]
    procedure Sql_BlockComment_CarriesStateAcrossLines;

    [Test]
    procedure Json_Keys_DifferFromStringValues;

    [Test]
    procedure Json_TrueFalseNull_AreKeywords;

    [Test]
    procedure Json_NumberWithSignFractionAndExponent_IsSingleToken;

    [Test]
    procedure Json_EscapesInsideStrings_AreSeparateTokens;

    [Test]
    procedure Xml_TagsAttributesAndValues_AreTokenized;

    [Test]
    procedure Xml_Entity_IsTokenized;

    [Test]
    procedure Xml_Comment_WithinSingleLine;

    [Test]
    procedure Xml_Comment_CarriesStateAcrossLines;

    [Test]
    procedure Xml_CDataSection_IsSingleToken;

    [Test]
    procedure Registry_RegisterAndTryGet_MatchesCaseInsensitively;

    [Test]
    procedure Registry_TryGet_UnknownLanguage_ReturnsFalseAndNil;

    [Test]
    procedure Registry_TokenizeLine_UnknownLanguage_ReturnsSinglePlainToken;

    [Test]
    procedure Registry_TokenizeLine_KnownLanguage_DelegatesToHighlighter;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Highlighter.Pascal,
  Markdown4D.Highlighter.Sql,
  Markdown4D.Highlighter.Json,
  Markdown4D.Highlighter.Xml;

type
  TFakeSyntaxHighlighter = class(TInterfacedObject, IMarkdownSyntaxHighlighter)
  public
    function InitialState: Integer;
    function TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
  end;

function TFakeSyntaxHighlighter.InitialState: Integer;
begin
  Result := THighlighterRegistry.DefaultState;
end;

function TFakeSyntaxHighlighter.TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
begin
  Result := TSyntaxLine.Create([TSyntaxToken.Create(TSyntaxTokenKind.PlainText, 1, Length(Line))], State);
end;

procedure TSyntaxHighlighterTests.Pascal_KeywordsNumbersAndPlainText_AreTokenized;
begin
  AssertTokenizes(CreatePascal, 'begin Writeln(42); end.',
    'Keyword@1+5 Plain@6+9 Number@15+2 Plain@17+3 Keyword@20+3 Plain@23+1');
end;

procedure TSyntaxHighlighterTests.Pascal_Keywords_MatchCaseInsensitively;
begin
  AssertTokenizes(CreatePascal, 'BEGIN END.', 'Keyword@1+5 Plain@6+1 Keyword@7+3 Plain@10+1');
end;

procedure TSyntaxHighlighterTests.Pascal_StringWithDoubledQuotes_IsSingleToken;
begin
  AssertTokenizes(CreatePascal, 'S := ''it''''s'';', 'Plain@1+5 String@6+7 Plain@13+1');
end;

procedure TSyntaxHighlighterTests.Pascal_AllThreeCommentForms_AreTokenized;
begin
  AssertTokenizes(CreatePascal, '{ one } (* two *) // three',
    'Comment@1+7 Plain@8+1 Comment@9+9 Plain@18+1 Comment@19+8');
end;

procedure TSyntaxHighlighterTests.Pascal_DecimalAndHexNumbers_AreTokenized;
begin
  AssertTokenizes(CreatePascal, 'X := $1F + 42;', 'Plain@1+5 Number@6+3 Plain@9+3 Number@12+2 Plain@14+1');
end;

procedure TSyntaxHighlighterTests.Pascal_Directive_IsDistinctFromComment;
begin
  AssertTokenizes(CreatePascal, '{$IFDEF DEBUG} X {$ENDIF}', 'Directive@1+14 Plain@15+3 Directive@18+8');
end;

procedure TSyntaxHighlighterTests.Pascal_BraceComment_CarriesStateAcrossLines;
const
  FirstLineText = 'x := 1; { open';
  SecondLineText = 'still } done';
begin
  const Highlighter = CreatePascal;

  const FirstLine = Highlighter.TokenizeLine(FirstLineText, Highlighter.InitialState);
  AssertLineTokens(FirstLine, FirstLineText, 'Plain@1+5 Number@6+1 Plain@7+2 Comment@9+6');
  const StateCarriesOver = (FirstLine.NextState <> Highlighter.InitialState);
  Assert.IsTrue(StateCarriesOver);

  const SecondLine = Highlighter.TokenizeLine(SecondLineText, FirstLine.NextState);
  AssertLineTokens(SecondLine, SecondLineText, 'Comment@1+7 Plain@8+5');
  Assert.AreEqual(Highlighter.InitialState, SecondLine.NextState);
end;

procedure TSyntaxHighlighterTests.Pascal_StarComment_CarriesStateAcrossLines;
const
  FirstLineText = '(* open';
  SecondLineText = 'close *) x';
begin
  const Highlighter = CreatePascal;

  const FirstLine = Highlighter.TokenizeLine(FirstLineText, Highlighter.InitialState);
  AssertLineTokens(FirstLine, FirstLineText, 'Comment@1+7');
  const StateCarriesOver = (FirstLine.NextState <> Highlighter.InitialState);
  Assert.IsTrue(StateCarriesOver);

  const SecondLine = Highlighter.TokenizeLine(SecondLineText, FirstLine.NextState);
  AssertLineTokens(SecondLine, SecondLineText, 'Comment@1+8 Plain@9+2');
  Assert.AreEqual(Highlighter.InitialState, SecondLine.NextState);
end;

procedure TSyntaxHighlighterTests.Sql_KeywordsAndNumbers_AreTokenized;
begin
  AssertTokenizes(CreateSql, 'SELECT id FROM users WHERE id = 10;',
    'Keyword@1+6 Plain@7+4 Keyword@11+4 Plain@15+7 Keyword@22+5 Plain@27+6 Number@33+2 Plain@35+1');
end;

procedure TSyntaxHighlighterTests.Sql_Keywords_MatchCaseInsensitively;
begin
  AssertTokenizes(CreateSql, 'select * from t', 'Keyword@1+6 Plain@7+3 Keyword@10+4 Plain@14+2');
end;

procedure TSyntaxHighlighterTests.Sql_StringWithDoubledQuote_IsSingleToken;
begin
  AssertTokenizes(CreateSql, 'WHERE name = ''O''''Brien''', 'Keyword@1+5 Plain@6+8 String@14+10');
end;

procedure TSyntaxHighlighterTests.Sql_LineComment_RunsToEndOfLine;
begin
  AssertTokenizes(CreateSql, 'x -- note', 'Plain@1+2 Comment@3+7');
end;

procedure TSyntaxHighlighterTests.Sql_BlockComment_WithinSingleLine;
begin
  AssertTokenizes(CreateSql, 'a /* c */ b', 'Plain@1+2 Comment@3+7 Plain@10+2');
end;

procedure TSyntaxHighlighterTests.Sql_BlockComment_CarriesStateAcrossLines;
const
  FirstLineText = 'a /* open';
  SecondLineText = 'end */ b';
begin
  const Highlighter = CreateSql;

  const FirstLine = Highlighter.TokenizeLine(FirstLineText, Highlighter.InitialState);
  AssertLineTokens(FirstLine, FirstLineText, 'Plain@1+2 Comment@3+7');
  const StateCarriesOver = (FirstLine.NextState <> Highlighter.InitialState);
  Assert.IsTrue(StateCarriesOver);

  const SecondLine = Highlighter.TokenizeLine(SecondLineText, FirstLine.NextState);
  AssertLineTokens(SecondLine, SecondLineText, 'Comment@1+6 Plain@7+2');
  Assert.AreEqual(Highlighter.InitialState, SecondLine.NextState);
end;

procedure TSyntaxHighlighterTests.Json_Keys_DifferFromStringValues;
begin
  AssertTokenizes(CreateJson, '{"name": "value", "count": 3}',
    'Plain@1+1 Key@2+6 Plain@8+2 String@10+7 Plain@17+2 Key@19+7 Plain@26+2 Number@28+1 Plain@29+1');
end;

procedure TSyntaxHighlighterTests.Json_TrueFalseNull_AreKeywords;
begin
  AssertTokenizes(CreateJson, '[true, false, null]',
    'Plain@1+1 Keyword@2+4 Plain@6+2 Keyword@8+5 Plain@13+2 Keyword@15+4 Plain@19+1');
end;

procedure TSyntaxHighlighterTests.Json_NumberWithSignFractionAndExponent_IsSingleToken;
begin
  AssertTokenizes(CreateJson, '{"a": -1.5e2}', 'Plain@1+1 Key@2+3 Plain@5+2 Number@7+6 Plain@13+1');
end;

procedure TSyntaxHighlighterTests.Json_EscapesInsideStrings_AreSeparateTokens;
begin
  AssertTokenizes(CreateJson, '{"a": "x\n\"y"}',
    'Plain@1+1 Key@2+3 Plain@5+2 String@7+2 Escape@9+2 Escape@11+2 String@13+2 Plain@15+1');
end;

procedure TSyntaxHighlighterTests.Xml_TagsAttributesAndValues_AreTokenized;
begin
  AssertTokenizes(CreateXml, '<a href="x">hi</a>',
    'Plain@1+1 Tag@2+1 Plain@3+1 Attr@4+4 Plain@8+1 Value@9+3 Plain@12+5 Tag@17+1 Plain@18+1');
end;

procedure TSyntaxHighlighterTests.Xml_Entity_IsTokenized;
begin
  AssertTokenizes(CreateXml, 'a &amp; b', 'Plain@1+2 Entity@3+5 Plain@8+2');
end;

procedure TSyntaxHighlighterTests.Xml_Comment_WithinSingleLine;
begin
  AssertTokenizes(CreateXml, '<!-- hi -->', 'Comment@1+11');
end;

procedure TSyntaxHighlighterTests.Xml_Comment_CarriesStateAcrossLines;
const
  FirstLineText = '<!-- open';
  SecondLineText = 'done -->';
begin
  const Highlighter = CreateXml;

  const FirstLine = Highlighter.TokenizeLine(FirstLineText, Highlighter.InitialState);
  AssertLineTokens(FirstLine, FirstLineText, 'Comment@1+9');
  const StateCarriesOver = (FirstLine.NextState <> Highlighter.InitialState);
  Assert.IsTrue(StateCarriesOver);

  const SecondLine = Highlighter.TokenizeLine(SecondLineText, FirstLine.NextState);
  AssertLineTokens(SecondLine, SecondLineText, 'Comment@1+8');
  Assert.AreEqual(Highlighter.InitialState, SecondLine.NextState);
end;

procedure TSyntaxHighlighterTests.Xml_CDataSection_IsSingleToken;
begin
  AssertTokenizes(CreateXml, '<![CDATA[x < y]]>', 'CData@1+17');
end;

procedure TSyntaxHighlighterTests.Registry_RegisterAndTryGet_MatchesCaseInsensitively;
begin
  THighlighterRegistry.Clear;

  var Registered: IMarkdownSyntaxHighlighter := TFakeSyntaxHighlighter.Create;
  THighlighterRegistry.Register(FakeLanguageName, Registered);

  var Found: IMarkdownSyntaxHighlighter;
  Assert.IsTrue(THighlighterRegistry.TryGet(FakeLanguageName.ToLower, Found));
  const LowerCaseFindsSameInstance = (Found = Registered);
  Assert.IsTrue(LowerCaseFindsSameInstance);

  Assert.IsTrue(THighlighterRegistry.TryGet(FakeLanguageName.ToUpper, Found));
  const UpperCaseFindsSameInstance = (Found = Registered);
  Assert.IsTrue(UpperCaseFindsSameInstance);
end;

procedure TSyntaxHighlighterTests.Registry_TryGet_UnknownLanguage_ReturnsFalseAndNil;
begin
  THighlighterRegistry.Clear;

  var Found: IMarkdownSyntaxHighlighter := TFakeSyntaxHighlighter.Create;
  Assert.IsFalse(THighlighterRegistry.TryGet(UnknownLanguageName, Found));
  const FoundIsNil = (Found = nil);
  Assert.IsTrue(FoundIsNil);
end;

procedure TSyntaxHighlighterTests.Registry_TokenizeLine_UnknownLanguage_ReturnsSinglePlainToken;
const
  LineText = 'plain text';
begin
  THighlighterRegistry.Clear;

  const Line = THighlighterRegistry.TokenizeLine(UnknownLanguageName, LineText, THighlighterRegistry.DefaultState);
  AssertLineTokens(Line, LineText, 'Plain@1+10');
  Assert.AreEqual(THighlighterRegistry.DefaultState, Line.NextState);
end;

procedure TSyntaxHighlighterTests.Registry_TokenizeLine_KnownLanguage_DelegatesToHighlighter;
const
  LineText = 'abc';
begin
  THighlighterRegistry.Clear;
  THighlighterRegistry.Register(FakeLanguageName, TFakeSyntaxHighlighter.Create);

  const Line = THighlighterRegistry.TokenizeLine(FakeLanguageName.ToLower, LineText,
    THighlighterRegistry.DefaultState);
  AssertLineTokens(Line, LineText, 'Plain@1+3');
end;

class function TSyntaxHighlighterTests.CreatePascal: IMarkdownSyntaxHighlighter;
begin
  Result := TPascalSyntaxHighlighter.Create;
end;

class function TSyntaxHighlighterTests.CreateSql: IMarkdownSyntaxHighlighter;
begin
  Result := TSqlSyntaxHighlighter.Create;
end;

class function TSyntaxHighlighterTests.CreateJson: IMarkdownSyntaxHighlighter;
begin
  Result := TJsonSyntaxHighlighter.Create;
end;

class function TSyntaxHighlighterTests.CreateXml: IMarkdownSyntaxHighlighter;
begin
  Result := TXmlSyntaxHighlighter.Create;
end;

class function TSyntaxHighlighterTests.DescribeTokens(const Tokens: TArray<TSyntaxToken>): string;
const
  KindNames: array[TSyntaxTokenKind] of string = ('Plain', 'Keyword', 'String', 'Number', 'Comment', 'Directive',
    'Escape', 'Key', 'Tag', 'Attr', 'Value', 'Entity', 'CData');
begin
  Result := '';

  for var Token in Tokens do
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + Format('%s@%d+%d', [KindNames[Token.Kind], Token.Start, Token.Length]);
  end;
end;

class procedure TSyntaxHighlighterTests.AssertCoverage(const Tokens: TArray<TSyntaxToken>; const LineLength: Integer);
begin
  var ExpectedStart := 1;

  for var Token in Tokens do
  begin
    Assert.AreEqual(ExpectedStart, Token.Start);
    const HasPositiveLength = (Token.Length > 0);
    Assert.IsTrue(HasPositiveLength);
    ExpectedStart := ExpectedStart + Token.Length;
  end;

  Assert.AreEqual(LineLength + 1, ExpectedStart);
end;

class procedure TSyntaxHighlighterTests.AssertLineTokens(const Line: TSyntaxLine; const LineText, Expected: string);
begin
  AssertCoverage(Line.Tokens, Length(LineText));
  Assert.AreEqual(Expected, DescribeTokens(Line.Tokens));
end;

class procedure TSyntaxHighlighterTests.AssertTokenizes(const Highlighter: IMarkdownSyntaxHighlighter;
  const LineText, Expected: string);
begin
  const Line = Highlighter.TokenizeLine(LineText, Highlighter.InitialState);

  AssertLineTokens(Line, LineText, Expected);
  Assert.AreEqual(Highlighter.InitialState, Line.NextState);
end;

end.
