unit Markdown4D.Highlighter.Sql;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Highlighter.Interfaces;

type
  TSqlSyntaxHighlighter = class(TInterfacedObject, IMarkdownSyntaxHighlighter)
  public
    function InitialState: Integer;
    function TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Highlighter.TokenBuilder;

type
  TSqlLineScanner = class
  private
    const
      CleanState = THighlighterRegistry.DefaultState;
      BlockCommentState = 1;
      BlockCommentClose = '*/';
      QuoteCharacter = '''';
      Digits = ['0'..'9'];
      IdentifierStartCharacters = ['A'..'Z', 'a'..'z', '_'];
      IdentifierCharacters = ['A'..'Z', 'a'..'z', '_', '0'..'9'];
      HyphenCharacter = '-';
      SlashCharacter = '/';
      StarCharacter = '*';
      DecimalPoint = '.';
    var
      FLine: string;
      FState: Integer;
      FPosition: Integer;
      FBuilder: TSyntaxTokenBuilder;
    procedure FinishBlockComment;
    procedure ScanNext;
    procedure ScanLineComment;
    procedure ScanBlockComment;
    procedure ScanStringLiteral;
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

function TSqlSyntaxHighlighter.InitialState: Integer;
begin
  Result := THighlighterRegistry.DefaultState;
end;

function TSqlSyntaxHighlighter.TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
begin
  const Scanner = TSqlLineScanner.Create(Line, State);
  try
    Result := Scanner.Scan;
  finally
    Scanner.Free;
  end;
end;

constructor TSqlLineScanner.Create(const Line: string; const State: Integer);
begin
  inherited Create;

  FLine := Line;
  FState := State;
  FPosition := 1;
  FBuilder := TSyntaxTokenBuilder.Create;
end;

destructor TSqlLineScanner.Destroy;
begin
  FBuilder.Free;

  inherited Destroy;
end;

function TSqlLineScanner.Scan: TSyntaxLine;
begin
  if FState = BlockCommentState then
    FinishBlockComment;

  while FPosition <= Length(FLine) do
  begin
    ScanNext;
  end;

  Result := FBuilder.ToLine(FState);
end;

procedure TSqlLineScanner.FinishBlockComment;
begin
  const CloseIndex = Pos(BlockCommentClose, FLine, FPosition);
  if CloseIndex = 0 then
  begin
    FBuilder.Add(TSyntaxTokenKind.Comment, FPosition, Length(FLine) - FPosition + 1);
    FPosition := Length(FLine) + 1;
    Exit;
  end;

  FBuilder.Add(TSyntaxTokenKind.Comment, FPosition, CloseIndex + Length(BlockCommentClose) - FPosition);
  FPosition := CloseIndex + Length(BlockCommentClose);
  FState := CleanState;
end;

procedure TSqlLineScanner.ScanNext;
begin
  const Current = FLine[FPosition];

  if (Current = HyphenCharacter) and (CharAt(FPosition + 1) = HyphenCharacter) then
    ScanLineComment
  else if (Current = SlashCharacter) and (CharAt(FPosition + 1) = StarCharacter) then
    ScanBlockComment
  else if Current = QuoteCharacter then
    ScanStringLiteral
  else if CharInSet(Current, Digits) then
    ScanNumber
  else if CharInSet(Current, IdentifierStartCharacters) then
    ScanIdentifier
  else
    AddPlainCharacter;
end;

procedure TSqlLineScanner.ScanLineComment;
begin
  FBuilder.Add(TSyntaxTokenKind.Comment, FPosition, Length(FLine) - FPosition + 1);
  FPosition := Length(FLine) + 1;
end;

procedure TSqlLineScanner.ScanBlockComment;
begin
  const Start = FPosition;

  const CloseIndex = Pos(BlockCommentClose, FLine, FPosition + 2);
  if CloseIndex = 0 then
  begin
    FBuilder.Add(TSyntaxTokenKind.Comment, Start, Length(FLine) - Start + 1);
    FPosition := Length(FLine) + 1;
    FState := BlockCommentState;
    Exit;
  end;

  FBuilder.Add(TSyntaxTokenKind.Comment, Start, CloseIndex + Length(BlockCommentClose) - Start);
  FPosition := CloseIndex + Length(BlockCommentClose);
end;

procedure TSqlLineScanner.ScanStringLiteral;
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

procedure TSqlLineScanner.ScanNumber;
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

procedure TSqlLineScanner.ScanIdentifier;
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

procedure TSqlLineScanner.AddPlainCharacter;
begin
  FBuilder.Add(TSyntaxTokenKind.PlainText, FPosition, 1);
  Inc(FPosition);
end;

function TSqlLineScanner.CharAt(const Position: Integer): Char;
begin
  const IsInsideLine = (Position >= 1) and (Position <= Length(FLine));
  if not IsInsideLine then
    Exit(#0);

  Result := FLine[Position];
end;

class function TSqlLineScanner.IsKeyword(const Identifier: string): Boolean;
const
  KeywordList = ' select insert update delete merge from where and or not null is in like between exists group by' +
    ' order having union all distinct as inner left right full outer cross join on create table alter drop index' +
    ' view trigger primary key foreign references check unique constraint default values into set limit offset' +
    ' case when then else end cast begin commit rollback transaction ';
begin
  Result := KeywordList.Contains(' ' + Identifier.ToLower + ' ');
end;

end.
