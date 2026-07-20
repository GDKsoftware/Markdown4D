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

  TRegisteredHighlighter = record
    Language: string;
    Highlighter: IMarkdownSyntaxHighlighter;
    class function Create(const Language: string;
      const Highlighter: IMarkdownSyntaxHighlighter): TRegisteredHighlighter; static;
  end;

  THighlighterRegistry = class
  private
    class var
      FEntries: TArray<TRegisteredHighlighter>;
      FLock: TObject;
    class constructor Create;
    class destructor Destroy;
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

class function TRegisteredHighlighter.Create(const Language: string;
  const Highlighter: IMarkdownSyntaxHighlighter): TRegisteredHighlighter;
begin
  Result.Language := Language;
  Result.Highlighter := Highlighter;
end;

class constructor THighlighterRegistry.Create;
begin
  FLock := TObject.Create;
end;

class destructor THighlighterRegistry.Destroy;
begin
  FLock.Free;
end;

class procedure THighlighterRegistry.Register(const Language: string; const Highlighter: IMarkdownSyntaxHighlighter);
begin
  TMonitor.Enter(FLock);
  try
    const ExistingIndex = IndexOf(Language);
    if ExistingIndex >= 0 then
    begin
      FEntries[ExistingIndex].Highlighter := Highlighter;
      Exit;
    end;

    FEntries := FEntries + [TRegisteredHighlighter.Create(Language, Highlighter)];
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function THighlighterRegistry.TryGet(const Language: string;
  out Highlighter: IMarkdownSyntaxHighlighter): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    const FoundIndex = IndexOf(Language);
    if FoundIndex < 0 then
    begin
      Highlighter := nil;
      Exit(False);
    end;

    Highlighter := FEntries[FoundIndex].Highlighter;
    Result := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure THighlighterRegistry.Clear;
begin
  TMonitor.Enter(FLock);
  try
    FEntries := nil;
  finally
    TMonitor.Exit(FLock);
  end;
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
  for var Index := 0 to High(FEntries) do
  begin
    if SameText(FEntries[Index].Language, Language) then
      Exit(Index);
  end;

  Result := -1;
end;

end.
