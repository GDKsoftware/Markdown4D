unit Markdown4D.Highlighter.Pascal;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Highlighter.Interfaces;

type
  TPascalSyntaxHighlighter = class(TInterfacedObject, IMarkdownSyntaxHighlighter)
  public
    function InitialState: Integer;
    function TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Highlighter.TokenBuilder;

type
  TPascalLineScanner = class
  private
    const
      CleanState = THighlighterRegistry.DefaultState;
      BraceCommentState = 1;
      StarCommentState = 2;
      BraceCommentClose = '}';
      StarCommentClose = '*)';
      QuoteCharacter = '''';
      DirectiveCharacter = '$';
      HexPrefixCharacter = '$';
      Digits = ['0'..'9'];
      HexDigits = ['0'..'9', 'A'..'F', 'a'..'f'];
      IdentifierStartCharacters = ['A'..'Z', 'a'..'z', '_'];
      IdentifierCharacters = ['A'..'Z', 'a'..'z', '_', '0'..'9'];
      BraceOpenCharacter = '{';
      ParenCharacter = '(';
      StarCharacter = '*';
      SlashCharacter = '/';
      DecimalPoint = '.';
    var
      FLine: string;
      FState: Integer;
      FPosition: Integer;
      FBuilder: TSyntaxTokenBuilder;
    procedure FinishBraceComment;
    procedure FinishStarComment;
    procedure ScanNext;
    procedure ScanBraceBlock;
    procedure ScanStarComment;
    procedure ScanLineComment;
    procedure ScanStringLiteral;
    procedure ScanHexNumber;
    procedure ScanNumber;
    procedure ScanIdentifier;
    procedure AddPlainCharacter;
    function CharAt(const Position: Integer): Char;
    class function IsKeyword(const Identifier: string): Boolean;

  public
    constructor Create(const Line: string; const State: Integer);
    destructor Destroy; override;
    function Scan: TSyntaxLine;
  end;

function TPascalSyntaxHighlighter.InitialState: Integer;
begin
  Result := THighlighterRegistry.DefaultState;
end;

function TPascalSyntaxHighlighter.TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
begin
  const Scanner = TPascalLineScanner.Create(Line, State);
  try
    Result := Scanner.Scan;
  finally
    Scanner.Free;
  end;
end;

constructor TPascalLineScanner.Create(const Line: string; const State: Integer);
begin
  inherited Create;

  FLine := Line;
  FState := State;
  FPosition := 1;
  FBuilder := TSyntaxTokenBuilder.Create;
end;

destructor TPascalLineScanner.Destroy;
begin
  FBuilder.Free;

  inherited Destroy;
end;

function TPascalLineScanner.Scan: TSyntaxLine;
begin
  if FState = BraceCommentState then
    FinishBraceComment
  else if FState = StarCommentState then
    FinishStarComment;

  while FPosition <= Length(FLine) do
  begin
    ScanNext;
  end;

  Result := FBuilder.ToLine(FState);
end;

procedure TPascalLineScanner.FinishBraceComment;
begin
  const CloseIndex = Pos(BraceCommentClose, FLine, FPosition);
  if CloseIndex = 0 then
  begin
    FBuilder.Add(TSyntaxTokenKind.Comment, FPosition, Length(FLine) - FPosition + 1);
    FPosition := Length(FLine) + 1;
    Exit;
  end;

  FBuilder.Add(TSyntaxTokenKind.Comment, FPosition, CloseIndex - FPosition + 1);
  FPosition := CloseIndex + 1;
  FState := CleanState;
end;

procedure TPascalLineScanner.FinishStarComment;
begin
  const CloseIndex = Pos(StarCommentClose, FLine, FPosition);
  if CloseIndex = 0 then
  begin
    FBuilder.Add(TSyntaxTokenKind.Comment, FPosition, Length(FLine) - FPosition + 1);
    FPosition := Length(FLine) + 1;
    Exit;
  end;

  FBuilder.Add(TSyntaxTokenKind.Comment, FPosition, CloseIndex + Length(StarCommentClose) - FPosition);
  FPosition := CloseIndex + Length(StarCommentClose);
  FState := CleanState;
end;

procedure TPascalLineScanner.ScanNext;
begin
  const Current = FLine[FPosition];

  if Current = BraceOpenCharacter then
    ScanBraceBlock
  else if (Current = ParenCharacter) and (CharAt(FPosition + 1) = StarCharacter) then
    ScanStarComment
  else if (Current = SlashCharacter) and (CharAt(FPosition + 1) = SlashCharacter) then
    ScanLineComment
  else if Current = QuoteCharacter then
    ScanStringLiteral
  else if (Current = HexPrefixCharacter) and CharInSet(CharAt(FPosition + 1), HexDigits) then
    ScanHexNumber
  else if CharInSet(Current, Digits) then
    ScanNumber
  else if CharInSet(Current, IdentifierStartCharacters) then
    ScanIdentifier
  else
    AddPlainCharacter;
end;

procedure TPascalLineScanner.ScanBraceBlock;
begin
  const Start = FPosition;
  const IsDirective = (CharAt(FPosition + 1) = DirectiveCharacter);

  var Kind := TSyntaxTokenKind.Comment;
  if IsDirective then
    Kind := TSyntaxTokenKind.Directive;

  const CloseIndex = Pos(BraceCommentClose, FLine, FPosition + 1);
  if CloseIndex = 0 then
  begin
    FBuilder.Add(Kind, Start, Length(FLine) - Start + 1);
    FPosition := Length(FLine) + 1;
    FState := BraceCommentState;
    Exit;
  end;

  FBuilder.Add(Kind, Start, CloseIndex - Start + 1);
  FPosition := CloseIndex + 1;
end;

procedure TPascalLineScanner.ScanStarComment;
begin
  const Start = FPosition;

  const CloseIndex = Pos(StarCommentClose, FLine, FPosition + 2);
  if CloseIndex = 0 then
  begin
    FBuilder.Add(TSyntaxTokenKind.Comment, Start, Length(FLine) - Start + 1);
    FPosition := Length(FLine) + 1;
    FState := StarCommentState;
    Exit;
  end;

  FBuilder.Add(TSyntaxTokenKind.Comment, Start, CloseIndex + Length(StarCommentClose) - Start);
  FPosition := CloseIndex + Length(StarCommentClose);
end;

procedure TPascalLineScanner.ScanLineComment;
begin
  FBuilder.Add(TSyntaxTokenKind.Comment, FPosition, Length(FLine) - FPosition + 1);
  FPosition := Length(FLine) + 1;
end;

procedure TPascalLineScanner.ScanStringLiteral;
begin
  const Start = FPosition;
  Inc(FPosition);

  while FPosition <= Length(FLine) do
  begin
    if FLine[FPosition] <> QuoteCharacter then
    begin
      Inc(FPosition);
      Continue;
    end;

    const IsDoubledQuote = (CharAt(FPosition + 1) = QuoteCharacter);
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

procedure TPascalLineScanner.ScanHexNumber;
begin
  const Start = FPosition;
  Inc(FPosition);

  while (FPosition <= Length(FLine)) and CharInSet(FLine[FPosition], HexDigits) do
  begin
    Inc(FPosition);
  end;

  FBuilder.Add(TSyntaxTokenKind.NumberLiteral, Start, FPosition - Start);
end;

procedure TPascalLineScanner.ScanNumber;
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

procedure TPascalLineScanner.ScanIdentifier;
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

procedure TPascalLineScanner.AddPlainCharacter;
begin
  FBuilder.Add(TSyntaxTokenKind.PlainText, FPosition, 1);
  Inc(FPosition);
end;

function TPascalLineScanner.CharAt(const Position: Integer): Char;
begin
  const IsInsideLine = (Position >= 1) and (Position <= Length(FLine));
  if not IsInsideLine then
    Exit(#0);

  Result := FLine[Position];
end;

class function TPascalLineScanner.IsKeyword(const Identifier: string): Boolean;
const
  KeywordList = ' and array as asm begin case class const constructor destructor div do downto else end except' +
    ' exports file finalization finally for function goto if implementation in inherited initialization interface' +
    ' is label library mod nil not object of or out packed procedure program property raise record repeat' +
    ' resourcestring set shl shr string then threadvar to try type unit until uses var while with xor ';
begin
  Result := KeywordList.Contains(' ' + Identifier.ToLower + ' ');
end;

end.
