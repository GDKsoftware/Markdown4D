unit Markdown4D.Highlighter.Pascal;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Highlighter.LineScanner;

type
  TPascalSyntaxHighlighter = class(TSyntaxHighlighter)
  protected
    function ScannerClass: TSyntaxLineScannerClass; override;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Highlighter.Interfaces;

type
  TPascalLineScanner = class(TSyntaxLineScanner)
  private
    const
      BraceCommentState = 1;
      StarCommentState = 2;
      BraceCommentClose = '}';
      StarCommentClose = '*)';
      QuoteCharacter = '''';
      DirectiveCharacter = '$';
      HexPrefixCharacter = '$';
      HexDigits = ['0'..'9', 'A'..'F', 'a'..'f'];
      BraceOpenCharacter = '{';
      ParenCharacter = '(';
      StarCharacter = '*';
      SlashCharacter = '/';
    procedure FinishBraceComment;
    procedure FinishStarComment;
    procedure ScanBraceBlock;
    procedure ScanStarComment;
    procedure ScanLineComment;
    procedure ScanHexNumber;

  protected
    procedure Resume; override;
    procedure ScanNext; override;
    function IsKeyword(const Identifier: string): Boolean; override;
  end;

function TPascalSyntaxHighlighter.ScannerClass: TSyntaxLineScannerClass;
begin
  Result := TPascalLineScanner;
end;

procedure TPascalLineScanner.Resume;
begin
  if FState = BraceCommentState then
    FinishBraceComment
  else if FState = StarCommentState then
    FinishStarComment;
end;

procedure TPascalLineScanner.FinishBraceComment;
begin
  const CloseIndex = Pos(BraceCommentClose, FLine, FPosition);
  if CloseIndex = 0 then
  begin
    TakeRestOfLine(TSyntaxTokenKind.Comment);
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
    TakeRestOfLine(TSyntaxTokenKind.Comment);
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
    ScanQuotedLiteral(QuoteCharacter)
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
  TakeRestOfLine(TSyntaxTokenKind.Comment);
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

function TPascalLineScanner.IsKeyword(const Identifier: string): Boolean;
const
  KeywordList = ' and array as asm begin case class const constructor destructor div do downto else end except' +
    ' exports file finalization finally for function goto if implementation in inherited initialization interface' +
    ' is label library mod nil not object of or out packed procedure program property raise record repeat' +
    ' resourcestring set shl shr string then threadvar to try type unit until uses var while with xor ';
begin
  Result := KeywordList.Contains(' ' + Identifier.ToLower + ' ');
end;

end.
