unit Markdown4D.Highlighter.Sql;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Highlighter.LineScanner;

type
  TSqlSyntaxHighlighter = class(TSyntaxHighlighter)
  protected
    function ScannerClass: TSyntaxLineScannerClass; override;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Highlighter.Interfaces;

type
  TSqlLineScanner = class(TSyntaxLineScanner)
  private
    const
      BlockCommentState = 1;
      BlockCommentClose = '*/';
      QuoteCharacter = '''';
      HyphenCharacter = '-';
      SlashCharacter = '/';
      StarCharacter = '*';
    procedure FinishBlockComment;
    procedure ScanLineComment;
    procedure ScanBlockComment;

  protected
    procedure Resume; override;
    procedure ScanNext; override;
    function IsKeyword(const Identifier: string): Boolean; override;
  end;

function TSqlSyntaxHighlighter.ScannerClass: TSyntaxLineScannerClass;
begin
  Result := TSqlLineScanner;
end;

procedure TSqlLineScanner.Resume;
begin
  if FState = BlockCommentState then
    FinishBlockComment;
end;

procedure TSqlLineScanner.FinishBlockComment;
begin
  const CloseIndex = Pos(BlockCommentClose, FLine, FPosition);
  if CloseIndex = 0 then
  begin
    TakeRestOfLine(TSyntaxTokenKind.Comment);
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
    ScanQuotedLiteral(QuoteCharacter)
  else if CharInSet(Current, Digits) then
    ScanNumber
  else if CharInSet(Current, IdentifierStartCharacters) then
    ScanIdentifier
  else
    AddPlainCharacter;
end;

procedure TSqlLineScanner.ScanLineComment;
begin
  TakeRestOfLine(TSyntaxTokenKind.Comment);
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

function TSqlLineScanner.IsKeyword(const Identifier: string): Boolean;
const
  KeywordList = ' select insert update delete merge from where and or not null is in like between exists group by' +
    ' order having union all distinct as inner left right full outer cross join on create table alter drop index' +
    ' view trigger primary key foreign references check unique constraint default values into set limit offset' +
    ' case when then else end cast begin commit rollback transaction ';
begin
  Result := KeywordList.Contains(' ' + Identifier.ToLower + ' ');
end;

end.
