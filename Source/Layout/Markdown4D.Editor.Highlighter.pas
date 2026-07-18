unit Markdown4D.Editor.Highlighter;

{$SCOPEDENUMS ON}

interface

type
  TMarkdownSourceTokenKind = (Plain, HeadingMarker, HeadingText, EmphasisDelimiter, CodeSpanDelimiter, CodeSpanText,
    FenceLine, FenceContent, LinkBracket, LinkText, LinkUrl, BlockQuoteMarker, ListMarker);

  TMarkdownSourceToken = record
    Kind: TMarkdownSourceTokenKind;
    Start: Integer;
    Length: Integer;
    class function Create(const Kind: TMarkdownSourceTokenKind; const Start, Length: Integer): TMarkdownSourceToken; static;
  end;

  TMarkdownSourceLine = record
    Tokens: TArray<TMarkdownSourceToken>;
    NextState: Integer;
    class function Create(const Tokens: TArray<TMarkdownSourceToken>; const NextState: Integer): TMarkdownSourceLine; static;
  end;

  TMarkdownSourceHighlighter = class
  strict private
    const
      FenceStateFlag = Integer($40000000);
      SubStateMask = $000000FF;
      LanguageShift = 8;
      LanguageMask = $0000FFFF;
    var
      FFenceLanguages: TArray<string>;
    function LanguageIndex(const Language: string): Integer;
    function EncodeFence(const LangIndex, SubState: Integer): Integer;
    function DecodeLanguageIndex(const State: Integer): Integer;
    function DecodeLanguage(const State: Integer): string;
    function DecodeSubState(const State: Integer): Integer;
    function LeadingBacktickCount(const Line: string): Integer;
    function IsClosingFence(const Line: string): Boolean;
    function TokenizeFenceContent(const Line: string; const State: Integer): TMarkdownSourceLine;
    function TokenizeMarkdown(const Line: string): TMarkdownSourceLine;

  public
    const
      DefaultState = 0;
    function InitialState: Integer;
    function TokenizeLine(const Line: string; const State: Integer): TMarkdownSourceLine;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Defines,
  Markdown4D.Highlighter.Interfaces;

type
  TMarkdownLineScanner = class
  strict private
    var
      FLine: string;
      FPosition: Integer;
      FTokens: TArray<TMarkdownSourceToken>;
      FPlainStart: Integer;
      FPlainLength: Integer;
    procedure FlushPlain;
    procedure AddToken(const Kind: TMarkdownSourceTokenKind; const Start, TokenLength: Integer);
    procedure AddPlainCurrent;
    function TryScanHeading: Boolean;
    function TryScanBlockPrefix: Boolean;
    function TryScanList: Boolean;
    procedure ScanInlineFrom(const Start: Integer);
    procedure ScanInlineChar;
    procedure ScanEmphasis;
    procedure ScanCodeSpan;
    procedure ScanLink;
    function IndexOfChar(const Ch: Char; const From: Integer): Integer;

  public
    constructor Create(const Line: string);
    function Scan: TArray<TMarkdownSourceToken>;
  end;

class function TMarkdownSourceToken.Create(const Kind: TMarkdownSourceTokenKind;
  const Start, Length: Integer): TMarkdownSourceToken;
begin
  Result.Kind := Kind;
  Result.Start := Start;
  Result.Length := Length;
end;

class function TMarkdownSourceLine.Create(const Tokens: TArray<TMarkdownSourceToken>;
  const NextState: Integer): TMarkdownSourceLine;
begin
  Result.Tokens := Tokens;
  Result.NextState := NextState;
end;

function TMarkdownSourceHighlighter.InitialState: Integer;
begin
  Result := DefaultState;
end;

function TMarkdownSourceHighlighter.TokenizeLine(const Line: string; const State: Integer): TMarkdownSourceLine;
begin
  const InsideFence = (State and FenceStateFlag) <> 0;
  if InsideFence then
    Exit(TokenizeFenceContent(Line, State));

  Result := TokenizeMarkdown(Line);
end;

function TMarkdownSourceHighlighter.TokenizeMarkdown(const Line: string): TMarkdownSourceLine;
begin
  const BacktickCount = LeadingBacktickCount(Line);
  if BacktickCount >= MinFenceLength then
  begin
    const Language = Trim(Copy(Line, BacktickCount + 1, System.Length(Line) - BacktickCount));
    const Index = LanguageIndex(Language);
    Result := TMarkdownSourceLine.Create(
      [TMarkdownSourceToken.Create(TMarkdownSourceTokenKind.FenceLine, 1, System.Length(Line))],
      EncodeFence(Index, THighlighterRegistry.DefaultState));
    Exit;
  end;

  const Scanner = TMarkdownLineScanner.Create(Line);
  try
    Result := TMarkdownSourceLine.Create(Scanner.Scan, DefaultState);
  finally
    Scanner.Free;
  end;
end;

function TMarkdownSourceHighlighter.TokenizeFenceContent(const Line: string;
  const State: Integer): TMarkdownSourceLine;
begin
  if IsClosingFence(Line) then
    Exit(TMarkdownSourceLine.Create(
      [TMarkdownSourceToken.Create(TMarkdownSourceTokenKind.FenceLine, 1, System.Length(Line))], DefaultState));

  const Language = DecodeLanguage(State);
  const SubState = DecodeSubState(State);
  const SyntaxLine = THighlighterRegistry.TokenizeLine(Language, Line, SubState);

  var Tokens: TArray<TMarkdownSourceToken> := [];
  for var Token in SyntaxLine.Tokens do
  begin
    Tokens := Tokens + [TMarkdownSourceToken.Create(TMarkdownSourceTokenKind.FenceContent, Token.Start, Token.Length)];
  end;

  const HasContent = (System.Length(Tokens) = 0) and (Line <> '');
  if HasContent then
    Tokens := [TMarkdownSourceToken.Create(TMarkdownSourceTokenKind.FenceContent, 1, System.Length(Line))];

  Result := TMarkdownSourceLine.Create(Tokens, EncodeFence(DecodeLanguageIndex(State), SyntaxLine.NextState));
end;

function TMarkdownSourceHighlighter.LeadingBacktickCount(const Line: string): Integer;
begin
  Result := 0;
  while (Result < System.Length(Line)) and (Line[Result + 1] = '`') do
    Inc(Result);
end;

function TMarkdownSourceHighlighter.IsClosingFence(const Line: string): Boolean;
begin
  const Trimmed = TrimRight(Line);
  const Count = LeadingBacktickCount(Trimmed);
  Result := (Count >= MinFenceLength) and (Count = System.Length(Trimmed));
end;

function TMarkdownSourceHighlighter.LanguageIndex(const Language: string): Integer;
begin
  for var Index := 0 to High(FFenceLanguages) do
  begin
    if SameText(FFenceLanguages[Index], Language) then
      Exit(Index);
  end;

  FFenceLanguages := FFenceLanguages + [Language];
  Result := High(FFenceLanguages);
end;

function TMarkdownSourceHighlighter.EncodeFence(const LangIndex, SubState: Integer): Integer;
begin
  Result := FenceStateFlag or ((LangIndex and LanguageMask) shl LanguageShift) or (SubState and SubStateMask);
end;

function TMarkdownSourceHighlighter.DecodeLanguageIndex(const State: Integer): Integer;
begin
  Result := (State shr LanguageShift) and LanguageMask;
end;

function TMarkdownSourceHighlighter.DecodeLanguage(const State: Integer): string;
begin
  const Index = DecodeLanguageIndex(State);
  const IsKnown = (Index >= 0) and (Index <= High(FFenceLanguages));
  if IsKnown then
    Result := FFenceLanguages[Index]
  else
    Result := '';
end;

function TMarkdownSourceHighlighter.DecodeSubState(const State: Integer): Integer;
begin
  Result := State and SubStateMask;
end;

constructor TMarkdownLineScanner.Create(const Line: string);
begin
  inherited Create;

  FLine := Line;
  FPosition := 1;
  FPlainStart := 0;
  FPlainLength := 0;
end;

function TMarkdownLineScanner.Scan: TArray<TMarkdownSourceToken>;
begin
  if not TryScanHeading then
  begin
    TryScanBlockPrefix;
    ScanInlineFrom(FPosition);
  end;

  FlushPlain;
  Result := FTokens;
end;

procedure TMarkdownLineScanner.FlushPlain;
begin
  if FPlainStart = 0 then
    Exit;

  FTokens := FTokens + [TMarkdownSourceToken.Create(TMarkdownSourceTokenKind.Plain, FPlainStart, FPlainLength)];
  FPlainStart := 0;
  FPlainLength := 0;
end;

procedure TMarkdownLineScanner.AddToken(const Kind: TMarkdownSourceTokenKind; const Start, TokenLength: Integer);
begin
  FlushPlain;
  FTokens := FTokens + [TMarkdownSourceToken.Create(Kind, Start, TokenLength)];
end;

procedure TMarkdownLineScanner.AddPlainCurrent;
begin
  if FPlainStart = 0 then
  begin
    FPlainStart := FPosition;
    FPlainLength := 0;
  end;

  Inc(FPlainLength);
  Inc(FPosition);
end;

function TMarkdownLineScanner.TryScanHeading: Boolean;
begin
  var Count := 0;
  while (Count < System.Length(FLine)) and (FLine[Count + 1] = '#') do
    Inc(Count);

  const IsAtx = (Count >= 1) and (Count <= 6) and
    ((Count = System.Length(FLine)) or (FLine[Count + 1] = ' '));
  if not IsAtx then
    Exit(False);

  AddToken(TMarkdownSourceTokenKind.HeadingMarker, 1, Count);
  if Count < System.Length(FLine) then
    AddToken(TMarkdownSourceTokenKind.HeadingText, Count + 1, System.Length(FLine) - Count);

  Result := True;
end;

function TMarkdownLineScanner.TryScanBlockPrefix: Boolean;
begin
  if (FPosition <= System.Length(FLine)) and (FLine[FPosition] = '>') then
  begin
    var MarkerLength := 1;
    if (FPosition + 1 <= System.Length(FLine)) and (FLine[FPosition + 1] = ' ') then
      Inc(MarkerLength);

    AddToken(TMarkdownSourceTokenKind.BlockQuoteMarker, FPosition, MarkerLength);
    FPosition := FPosition + MarkerLength;
    Exit(True);
  end;

  Result := TryScanList;
end;

function TMarkdownLineScanner.TryScanList: Boolean;
begin
  if FPosition > System.Length(FLine) then
    Exit(False);

  const Current = FLine[FPosition];
  const IsBullet = (Current = '-') or (Current = '+') or (Current = '*');
  const BulletHasSpace = (FPosition + 1 <= System.Length(FLine)) and (FLine[FPosition + 1] = ' ');
  if IsBullet and BulletHasSpace then
  begin
    AddToken(TMarkdownSourceTokenKind.ListMarker, FPosition, 2);
    FPosition := FPosition + 2;
    Exit(True);
  end;

  var Scan := FPosition;
  while (Scan <= System.Length(FLine)) and CharInSet(FLine[Scan], ['0'..'9']) do
    Inc(Scan);

  const HasDigits = Scan > FPosition;
  const HasDelimiter = (Scan <= System.Length(FLine)) and ((FLine[Scan] = '.') or (FLine[Scan] = ')'));
  const HasTrailingSpace = (Scan + 1 <= System.Length(FLine)) and (FLine[Scan + 1] = ' ');
  if HasDigits and HasDelimiter and HasTrailingSpace then
  begin
    AddToken(TMarkdownSourceTokenKind.ListMarker, FPosition, Scan - FPosition + 2);
    FPosition := Scan + 2;
    Exit(True);
  end;

  Result := False;
end;

procedure TMarkdownLineScanner.ScanInlineFrom(const Start: Integer);
begin
  FPosition := Start;
  while FPosition <= System.Length(FLine) do
    ScanInlineChar;
end;

procedure TMarkdownLineScanner.ScanInlineChar;
begin
  const Current = FLine[FPosition];
  if Current = '`' then
    ScanCodeSpan
  else if (Current = '*') or (Current = '_') then
    ScanEmphasis
  else if Current = '[' then
    ScanLink
  else
    AddPlainCurrent;
end;

procedure TMarkdownLineScanner.ScanEmphasis;
begin
  const Start = FPosition;
  var MarkerLength := 1;
  if (FPosition + 1 <= System.Length(FLine)) and (FLine[FPosition + 1] = FLine[FPosition]) then
    Inc(MarkerLength);

  AddToken(TMarkdownSourceTokenKind.EmphasisDelimiter, Start, MarkerLength);
  FPosition := FPosition + MarkerLength;
end;

procedure TMarkdownLineScanner.ScanCodeSpan;
begin
  const Start = FPosition;
  var OpenLength := 0;
  while (Start + OpenLength <= System.Length(FLine)) and (FLine[Start + OpenLength] = '`') do
    Inc(OpenLength);

  AddToken(TMarkdownSourceTokenKind.CodeSpanDelimiter, Start, OpenLength);
  const ContentStart = Start + OpenLength;

  var CloseStart := 0;
  var Scan := ContentStart;
  while Scan <= System.Length(FLine) do
  begin
    if FLine[Scan] <> '`' then
    begin
      Inc(Scan);
      Continue;
    end;

    var Run := 0;
    while (Scan + Run <= System.Length(FLine)) and (FLine[Scan + Run] = '`') do
      Inc(Run);
    if Run = OpenLength then
    begin
      CloseStart := Scan;
      Break;
    end;

    Scan := Scan + Run;
  end;

  if CloseStart = 0 then
  begin
    if ContentStart <= System.Length(FLine) then
      AddToken(TMarkdownSourceTokenKind.CodeSpanText, ContentStart, System.Length(FLine) - ContentStart + 1);
    FPosition := System.Length(FLine) + 1;
    Exit;
  end;

  if CloseStart > ContentStart then
    AddToken(TMarkdownSourceTokenKind.CodeSpanText, ContentStart, CloseStart - ContentStart);

  AddToken(TMarkdownSourceTokenKind.CodeSpanDelimiter, CloseStart, OpenLength);
  FPosition := CloseStart + OpenLength;
end;

procedure TMarkdownLineScanner.ScanLink;
begin
  const Start = FPosition;
  const CloseBracket = IndexOfChar(']', Start + 1);
  const HasParen = (CloseBracket > 0) and (CloseBracket + 1 <= System.Length(FLine)) and
    (FLine[CloseBracket + 1] = '(');
  if not HasParen then
  begin
    AddPlainCurrent;
    Exit;
  end;

  const CloseParen = IndexOfChar(')', CloseBracket + 2);
  if CloseParen = 0 then
  begin
    AddPlainCurrent;
    Exit;
  end;

  AddToken(TMarkdownSourceTokenKind.LinkBracket, Start, 1);
  if CloseBracket > Start + 1 then
    AddToken(TMarkdownSourceTokenKind.LinkText, Start + 1, CloseBracket - Start - 1);
  AddToken(TMarkdownSourceTokenKind.LinkBracket, CloseBracket, 1);
  AddToken(TMarkdownSourceTokenKind.LinkBracket, CloseBracket + 1, 1);
  if CloseParen > CloseBracket + 2 then
    AddToken(TMarkdownSourceTokenKind.LinkUrl, CloseBracket + 2, CloseParen - CloseBracket - 2);
  AddToken(TMarkdownSourceTokenKind.LinkBracket, CloseParen, 1);
  FPosition := CloseParen + 1;
end;

function TMarkdownLineScanner.IndexOfChar(const Ch: Char; const From: Integer): Integer;
begin
  for var Index := From to System.Length(FLine) do
  begin
    if FLine[Index] = Ch then
      Exit(Index);
  end;

  Result := 0;
end;

end.
