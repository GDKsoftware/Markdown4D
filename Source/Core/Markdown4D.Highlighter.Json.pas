unit Markdown4D.Highlighter.Json;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Highlighter.LineScanner;

type
  TJsonSyntaxHighlighter = class(TSyntaxHighlighter)
  protected
    function ScannerClass: TSyntaxLineScannerClass; override;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Highlighter.Interfaces;

type
  TJsonLineScanner = class(TSyntaxLineScanner)
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
      Letters = ['A'..'Z', 'a'..'z'];
      SignCharacters = ['+', '-'];
      WhitespaceCharacters = [' ', #9];
      MinusSign = '-';
      DecimalPoint = '.';
      ExponentIndicators = ['e', 'E'];
    procedure ScanString;
    function IsKeyString(const Start: Integer): Boolean;
    function FindStringClose(const Start: Integer): Integer;
    // A number here may carry a sign and an exponent, which the plain reader
    // this descends from does not allow.
    procedure ScanSignedNumber;
    procedure ScanWord;
    function EscapeLengthAt(const Position: Integer): Integer;

  protected
    procedure ScanNext; override;
  end;

function TJsonSyntaxHighlighter.ScannerClass: TSyntaxLineScannerClass;
begin
  Result := TJsonLineScanner;
end;

procedure TJsonLineScanner.ScanNext;
begin
  const Current = FLine[FPosition];

  const StartsNumber = CharInSet(Current, Digits) or
    ((Current = MinusSign) and CharInSet(CharAt(FPosition + 1), Digits));

  if Current = QuoteCharacter then
    ScanString
  else if StartsNumber then
    ScanSignedNumber
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

procedure TJsonLineScanner.ScanSignedNumber;
begin
  const Start = FPosition;

  if FLine[FPosition] = MinusSign then
    Inc(FPosition);

  while (FPosition <= Length(FLine)) and CharInSet(FLine[FPosition], Digits) do
  begin
    Inc(FPosition);
  end;

  const HasFraction = (CharAt(FPosition) = DecimalPoint) and CharInSet(CharAt(FPosition + 1), Digits);
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
  const HasExponent = CharInSet(CharAt(FPosition), ExponentIndicators) and
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

end.
