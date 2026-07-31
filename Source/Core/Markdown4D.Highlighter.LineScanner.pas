unit Markdown4D.Highlighter.LineScanner;

{$SCOPEDENUMS ON}

// The shape every syntax highlighter shares: it walks one line at a time,
// carries an integer state from the line before, and appends tokens to a
// builder. A language says what a character starts and what it does with an
// unfinished construct; the walk itself lives here.

interface

uses
  Markdown4D.Highlighter.Interfaces,
  Markdown4D.Highlighter.TokenBuilder;

type
  TSyntaxLineScanner = class
  protected
    const
      CleanState = THighlighterRegistry.DefaultState;
      Digits = ['0'..'9'];
      IdentifierStartCharacters = ['A'..'Z', 'a'..'z', '_'];
      IdentifierCharacters = ['A'..'Z', 'a'..'z', '_', '0'..'9'];
      DecimalPoint = '.';
    var
      FLine: string;
      FState: Integer;
      FPosition: Integer;
      FBuilder: TSyntaxTokenBuilder;

    // Finishes what the line before left open. A language whose constructs
    // never span a line has nothing to do here.
    procedure Resume; virtual;
    procedure ScanNext; virtual; abstract;
    function IsKeyword(const Identifier: string): Boolean; virtual;

    function CharAt(const Position: Integer): Char;
    procedure AddPlainCharacter;
    procedure TakeRestOfLine(const Kind: TSyntaxTokenKind);
    procedure ScanNumber;
    procedure ScanIdentifier;
    // Reads a literal that ends at the next unpaired quote, where the quote
    // itself is written twice to appear in the text.
    procedure ScanQuotedLiteral(const Quote: Char);

  public
    constructor Create(const Line: string; const State: Integer); virtual;
    destructor Destroy; override;
    function Scan: TSyntaxLine;
  end;

  TSyntaxLineScannerClass = class of TSyntaxLineScanner;

  // A highlighter differs from its neighbours only in the scanner it drives.
  TSyntaxHighlighter = class abstract(TInterfacedObject, IMarkdownSyntaxHighlighter)
  protected
    function ScannerClass: TSyntaxLineScannerClass; virtual; abstract;

  public
    function InitialState: Integer;
    function TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
  end;

implementation

uses
  System.SysUtils;

constructor TSyntaxLineScanner.Create(const Line: string; const State: Integer);
begin
  inherited Create;

  FLine := Line;
  FState := State;
  FPosition := 1;
  FBuilder := TSyntaxTokenBuilder.Create;
end;

destructor TSyntaxLineScanner.Destroy;
begin
  FBuilder.Free;

  inherited Destroy;
end;

function TSyntaxLineScanner.Scan: TSyntaxLine;
begin
  Resume;

  while FPosition <= Length(FLine) do
  begin
    ScanNext;
  end;

  Result := FBuilder.ToLine(FState);
end;

procedure TSyntaxLineScanner.Resume;
begin
end;

function TSyntaxLineScanner.IsKeyword(const Identifier: string): Boolean;
begin
  Result := False;
end;

function TSyntaxLineScanner.CharAt(const Position: Integer): Char;
begin
  const IsInsideLine = (Position >= 1) and (Position <= Length(FLine));
  if not IsInsideLine then
    Exit(#0);

  Result := FLine[Position];
end;

procedure TSyntaxLineScanner.AddPlainCharacter;
begin
  FBuilder.Add(TSyntaxTokenKind.PlainText, FPosition, 1);
  Inc(FPosition);
end;

procedure TSyntaxLineScanner.TakeRestOfLine(const Kind: TSyntaxTokenKind);
begin
  FBuilder.Add(Kind, FPosition, Length(FLine) - FPosition + 1);
  FPosition := Length(FLine) + 1;
end;

procedure TSyntaxLineScanner.ScanNumber;
begin
  const Start = FPosition;

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

  FBuilder.Add(TSyntaxTokenKind.NumberLiteral, Start, FPosition - Start);
end;

procedure TSyntaxLineScanner.ScanIdentifier;
begin
  const Start = FPosition;

  while (FPosition <= Length(FLine)) and CharInSet(FLine[FPosition], IdentifierCharacters) do
  begin
    Inc(FPosition);
  end;

  const Identifier = Copy(FLine, Start, FPosition - Start);
  var Kind := TSyntaxTokenKind.PlainText;
  if IsKeyword(Identifier) then
    Kind := TSyntaxTokenKind.Keyword;

  FBuilder.Add(Kind, Start, FPosition - Start);
end;

procedure TSyntaxLineScanner.ScanQuotedLiteral(const Quote: Char);
begin
  const Start = FPosition;
  Inc(FPosition);

  while FPosition <= Length(FLine) do
  begin
    if FLine[FPosition] <> Quote then
    begin
      Inc(FPosition);
      Continue;
    end;

    const IsDoubledQuote = (CharAt(FPosition + 1) = Quote);
    if IsDoubledQuote then
    begin
      Inc(FPosition, 2);
      Continue;
    end;

    Inc(FPosition);
    Break;
  end;

  FBuilder.Add(TSyntaxTokenKind.StringLiteral, Start, FPosition - Start);
end;

function TSyntaxHighlighter.InitialState: Integer;
begin
  Result := THighlighterRegistry.DefaultState;
end;

function TSyntaxHighlighter.TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
begin
  const Scanner = ScannerClass.Create(Line, State);
  try
    Result := Scanner.Scan;
  finally
    Scanner.Free;
  end;
end;

end.
