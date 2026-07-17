unit Markdown4D.Highlighter.Json;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Highlighter.Interfaces;

type
  TJsonSyntaxHighlighter = class(TInterfacedObject, IMarkdownSyntaxHighlighter)
  public
    function InitialState: Integer;
    function TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Highlighter.TokenBuilder;

type
  TJsonLineScanner = class
  private
    const
      QuoteCharacter = '"';
      EscapeCharacter = '\';
      KeySeparator = ':';
      UnicodeEscapeIndicator = 'u';
      ShortEscapeLength = 2;
      UnicodeEscapeLength = 6;
      TrueLiteral = 'true';
      FalseLiteral = 'false';
      NullLiteral = 'null';
      Digits = ['0'..'9'];
      Letters = ['A'..'Z', 'a'..'z'];
      SignCharacters = ['+', '-'];
      WhitespaceCharacters = [' ', #9];
    var
      FLine: string;
      FState: Integer;
      FPosition: Integer;
      FBuilder: TSyntaxTokenBuilder;
    procedure ScanNext;
    procedure ScanString;
    function IsKeyString(const Start: Integer): Boolean;
    function FindStringClose(const Start: Integer): Integer;
    procedure ScanNumber;
    procedure ScanWord;
    procedure AddPlainCharacter;
    function EscapeLengthAt(const Position: Integer): Integer;
    function CharAt(const Position: Integer): Char;

  public
    constructor Create(const Line: string; const State: Integer);
    destructor Destroy; override;
    function Scan: TSyntaxLine;
  end;

function TJsonSyntaxHighlighter.InitialState: Integer;
begin
  Result := THighlighterRegistry.DefaultState;
end;

function TJsonSyntaxHighlighter.TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
begin
  const Scanner = TJsonLineScanner.Create(Line, State);
  try
    Result := Scanner.Scan;
  finally
    Scanner.Free;
  end;
end;

constructor TJsonLineScanner.Create(const Line: string; const State: Integer);
begin
  inherited Create;

  FLine := Line;
  FState := State;
  FPosition := 1;
  FBuilder := TSyntaxTokenBuilder.Create;
end;

destructor TJsonLineScanner.Destroy;
begin
  FBuilder.Free;

  inherited Destroy;
end;

function TJsonLineScanner.Scan: TSyntaxLine;
begin
  while FPosition <= Length(FLine) do
  begin
    ScanNext;
  end;

  Result := FBuilder.ToLine(FState);
end;

procedure TJsonLineScanner.ScanNext;
begin
  const Current = FLine[FPosition];

  const StartsNumber = CharInSet(Current, Digits) or
    ((Current = '-') and CharInSet(CharAt(FPosition + 1), Digits));

  if Current = QuoteCharacter then
    ScanString
  else if StartsNumber then
    ScanNumber
  else if CharInSet(Current, Letters) then
    ScanWord
  else
    AddPlainCharacter;
end;

procedure TJsonLineScanner.ScanString;
begin
  const Start = FPosition;

  var TextKind := TSyntaxTokenKind.StringLiteral;
  if IsKeyString(Start) then
    TextKind := TSyntaxTokenKind.JsonKey;

  var SegmentStart := Start;
  Inc(FPosition);

  while FPosition <= Length(FLine) do
  begin
    const Current = FLine[FPosition];

    if Current = EscapeCharacter then
    begin
      FBuilder.Add(TextKind, SegmentStart, FPosition - SegmentStart);

      const EscapeLength = EscapeLengthAt(FPosition);
      FBuilder.Add(TSyntaxTokenKind.EscapeSequence, FPosition, EscapeLength);
      FPosition := FPosition + EscapeLength;
      SegmentStart := FPosition;
      Continue;
    end;

    Inc(FPosition);
    if Current = QuoteCharacter then
      Break;
  end;

  FBuilder.Add(TextKind, SegmentStart, FPosition - SegmentStart);
end;

function TJsonLineScanner.IsKeyString(const Start: Integer): Boolean;
begin
  const CloseIndex = FindStringClose(Start);
  if CloseIndex = 0 then
    Exit(False);

  var Probe := CloseIndex + 1;
  while (Probe <= Length(FLine)) and CharInSet(FLine[Probe], WhitespaceCharacters) do
  begin
    Inc(Probe);
  end;

  Result := (CharAt(Probe) = KeySeparator);
end;

function TJsonLineScanner.FindStringClose(const Start: Integer): Integer;
begin
  var Probe := Start + 1;

  while Probe <= Length(FLine) do
  begin
    const Current = FLine[Probe];

    if Current = EscapeCharacter then
    begin
      Probe := Probe + EscapeLengthAt(Probe);
      Continue;
    end;

    if Current = QuoteCharacter then
      Exit(Probe);

    Inc(Probe);
  end;

  Result := 0;
end;

procedure TJsonLineScanner.ScanNumber;
begin
  const Start = FPosition;

  if FLine[FPosition] = '-' then
    Inc(FPosition);

  while (FPosition <= Length(FLine)) and CharInSet(FLine[FPosition], Digits) do
  begin
    Inc(FPosition);
  end;

  const HasFraction = (CharAt(FPosition) = '.') and CharInSet(CharAt(FPosition + 1), Digits);
  if HasFraction then
  begin
    Inc(FPosition);

    while (FPosition <= Length(FLine)) and CharInSet(FLine[FPosition], Digits) do
    begin
      Inc(FPosition);
    end;
  end;

  const HasSignedExponent = CharInSet(CharAt(FPosition + 1), SignCharacters) and
    CharInSet(CharAt(FPosition + 2), Digits);
  const HasExponent = CharInSet(CharAt(FPosition), ['e', 'E']) and
    (CharInSet(CharAt(FPosition + 1), Digits) or HasSignedExponent);
  if HasExponent then
  begin
    Inc(FPosition);

    if CharInSet(FLine[FPosition], SignCharacters) then
      Inc(FPosition);

    while (FPosition <= Length(FLine)) and CharInSet(FLine[FPosition], Digits) do
    begin
      Inc(FPosition);
    end;
  end;

  FBuilder.Add(TSyntaxTokenKind.NumberLiteral, Start, FPosition - Start);
end;

procedure TJsonLineScanner.ScanWord;
begin
  const Start = FPosition;

  while (FPosition <= Length(FLine)) and CharInSet(FLine[FPosition], Letters) do
  begin
    Inc(FPosition);
  end;

  const WordText = Copy(FLine, Start, FPosition - Start);
  const IsLiteralKeyword = (WordText = TrueLiteral) or (WordText = FalseLiteral) or (WordText = NullLiteral);

  var Kind := TSyntaxTokenKind.PlainText;
  if IsLiteralKeyword then
    Kind := TSyntaxTokenKind.Keyword;

  FBuilder.Add(Kind, Start, FPosition - Start);
end;

procedure TJsonLineScanner.AddPlainCharacter;
begin
  FBuilder.Add(TSyntaxTokenKind.PlainText, FPosition, 1);
  Inc(FPosition);
end;

function TJsonLineScanner.EscapeLengthAt(const Position: Integer): Integer;
begin
  var EscapeLength := ShortEscapeLength;
  if CharAt(Position + 1) = UnicodeEscapeIndicator then
    EscapeLength := UnicodeEscapeLength;

  const RemainingLength = Length(FLine) - Position + 1;
  if EscapeLength > RemainingLength then
    EscapeLength := RemainingLength;

  Result := EscapeLength;
end;

function TJsonLineScanner.CharAt(const Position: Integer): Char;
begin
  const IsInsideLine = (Position >= 1) and (Position <= Length(FLine));
  if not IsInsideLine then
    Exit(#0);

  Result := FLine[Position];
end;

end.
