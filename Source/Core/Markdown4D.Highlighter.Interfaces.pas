unit Markdown4D.Highlighter.Interfaces;

{$SCOPEDENUMS ON}

interface

const
  // Canonical language identifiers for the bundled highlighters
  PascalLanguageName = 'pascal';
  JsonLanguageName = 'json';
  SqlLanguageName = 'sql';
  XmlLanguageName = 'xml';

type
  TSyntaxTokenKind = (PlainText, Keyword, StringLiteral, NumberLiteral, Comment, Directive, EscapeSequence, JsonKey,
    TagName, AttributeName, AttributeValue, Entity, CDataSection);

  TSyntaxToken = record
    Kind: TSyntaxTokenKind;
    Start: Integer;
    Length: Integer;
    class function Create(const Kind: TSyntaxTokenKind; const Start, Length: Integer): TSyntaxToken; static;
  end;

  TSyntaxLine = record
    Tokens: TArray<TSyntaxToken>;
    NextState: Integer;
    class function Create(const Tokens: TArray<TSyntaxToken>; const NextState: Integer): TSyntaxLine; static;
  end;

  IMarkdownSyntaxHighlighter = interface
    ['{9C4E1B72-A35D-4F80-B6E9-27D1C8F45A03}']
    function InitialState: Integer;
    function TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
  end;

  THighlighterRegistry = class
  private
    class var
      FLanguages: TArray<string>;
      FHighlighters: TArray<IMarkdownSyntaxHighlighter>;
    class function IndexOf(const Language: string): Integer;

  public
    const
      DefaultState = 0;
    class procedure Register(const Language: string; const Highlighter: IMarkdownSyntaxHighlighter);
    class function TryGet(const Language: string; out Highlighter: IMarkdownSyntaxHighlighter): Boolean;
    class procedure Clear;
    class function TokenizeLine(const Language, Line: string; const State: Integer): TSyntaxLine;
  end;

implementation

uses
  System.SysUtils;

class function TSyntaxToken.Create(const Kind: TSyntaxTokenKind; const Start, Length: Integer): TSyntaxToken;
begin
  Result.Kind := Kind;
  Result.Start := Start;
  Result.Length := Length;
end;

class function TSyntaxLine.Create(const Tokens: TArray<TSyntaxToken>; const NextState: Integer): TSyntaxLine;
begin
  Result.Tokens := Tokens;
  Result.NextState := NextState;
end;

class procedure THighlighterRegistry.Register(const Language: string; const Highlighter: IMarkdownSyntaxHighlighter);
begin
  const ExistingIndex = IndexOf(Language);
  if ExistingIndex >= 0 then
  begin
    FHighlighters[ExistingIndex] := Highlighter;
    Exit;
  end;

  FLanguages := FLanguages + [Language];
  FHighlighters := FHighlighters + [Highlighter];
end;

class function THighlighterRegistry.TryGet(const Language: string;
  out Highlighter: IMarkdownSyntaxHighlighter): Boolean;
begin
  const FoundIndex = IndexOf(Language);
  if FoundIndex < 0 then
  begin
    Highlighter := nil;
    Exit(False);
  end;

  Highlighter := FHighlighters[FoundIndex];
  Result := True;
end;

class procedure THighlighterRegistry.Clear;
begin
  FLanguages := nil;
  FHighlighters := nil;
end;

class function THighlighterRegistry.TokenizeLine(const Language, Line: string; const State: Integer): TSyntaxLine;
begin
  var Highlighter: IMarkdownSyntaxHighlighter;
  if TryGet(Language, Highlighter) then
    Exit(Highlighter.TokenizeLine(Line, State));

  if Line = '' then
    Exit(TSyntaxLine.Create(nil, State));

  Result := TSyntaxLine.Create([TSyntaxToken.Create(TSyntaxTokenKind.PlainText, 1, Length(Line))], State);
end;

class function THighlighterRegistry.IndexOf(const Language: string): Integer;
begin
  for var Index := 0 to High(FLanguages) do
  begin
    if SameText(FLanguages[Index], Language) then
      Exit(Index);
  end;

  Result := -1;
end;

end.
