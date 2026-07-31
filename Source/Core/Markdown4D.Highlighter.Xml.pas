unit Markdown4D.Highlighter.Xml;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Highlighter.LineScanner;

type
  TXmlSyntaxHighlighter = class(TSyntaxHighlighter)
  protected
    function ScannerClass: TSyntaxLineScannerClass; override;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Highlighter.Interfaces;

type
  TXmlLineScanner = class(TSyntaxLineScanner)
  private
    const
      CommentState = 1;
      CDataState = 2;
      CommentOpen = '<!--';
      CommentClose = '-->';
      CDataOpen = '<![CDATA[';
      CDataClose = ']]>';
      EntityTerminator = ';';
      NameStartCharacters = ['A'..'Z', 'a'..'z', '_', ':'];
      NameCharacters = ['A'..'Z', 'a'..'z', '0'..'9', '_', ':', '-', '.'];
      EntityCharacters = ['A'..'Z', 'a'..'z', '0'..'9', '#'];
      TagOpenCharacter = '<';
      TagCloseCharacter = '>';
      EntityStartCharacter = '&';
      QuoteCharacters = ['"', ''''];
    var
      FInsideTag: Boolean;
      FExpectTagName: Boolean;
    procedure FinishComment;
    procedure FinishCData;
    procedure ScanText;
    procedure ScanComment;
    procedure ScanCData;
    procedure ScanTagOpen;
    procedure ScanEntity;
    procedure ScanInsideTag;
    procedure ScanName;
    procedure ScanAttributeValue;
    function StartsAt(const Prefix: string): Boolean;

  protected
    procedure Resume; override;
    procedure ScanNext; override;
  end;

function TXmlSyntaxHighlighter.ScannerClass: TSyntaxLineScannerClass;
begin
  Result := TXmlLineScanner;
end;

procedure TXmlLineScanner.Resume;
begin
  if FState = CommentState then
    FinishComment
  else if FState = CDataState then
    FinishCData;
end;

procedure TXmlLineScanner.ScanNext;
begin
  if FInsideTag then
    ScanInsideTag
  else
    ScanText;
end;

procedure TXmlLineScanner.FinishComment;
begin
  const CloseIndex = Pos(CommentClose, FLine, FPosition);
  if CloseIndex = 0 then
  begin
    FBuilder.Add(TSyntaxTokenKind.Comment, FPosition, Length(FLine) - FPosition + 1);
    FPosition := Length(FLine) + 1;
    Exit;
  end;

  FBuilder.Add(TSyntaxTokenKind.Comment, FPosition, CloseIndex + Length(CommentClose) - FPosition);
  FPosition := CloseIndex + Length(CommentClose);
  FState := CleanState;
end;

procedure TXmlLineScanner.FinishCData;
begin
  const CloseIndex = Pos(CDataClose, FLine, FPosition);
  if CloseIndex = 0 then
  begin
    FBuilder.Add(TSyntaxTokenKind.CDataSection, FPosition, Length(FLine) - FPosition + 1);
    FPosition := Length(FLine) + 1;
    Exit;
  end;

  FBuilder.Add(TSyntaxTokenKind.CDataSection, FPosition, CloseIndex + Length(CDataClose) - FPosition);
  FPosition := CloseIndex + Length(CDataClose);
  FState := CleanState;
end;

procedure TXmlLineScanner.ScanText;
begin
  const Current = FLine[FPosition];

  if Current = TagOpenCharacter then
  begin
    if StartsAt(CommentOpen) then
      ScanComment
    else if StartsAt(CDataOpen) then
      ScanCData
    else
      ScanTagOpen;
    Exit;
  end;

  if Current = EntityStartCharacter then
  begin
    ScanEntity;
    Exit;
  end;

  AddPlainCharacter;
end;

procedure TXmlLineScanner.ScanComment;
begin
  const Start = FPosition;

  const CloseIndex = Pos(CommentClose, FLine, FPosition + Length(CommentOpen));
  if CloseIndex = 0 then
  begin
    FBuilder.Add(TSyntaxTokenKind.Comment, Start, Length(FLine) - Start + 1);
    FPosition := Length(FLine) + 1;
    FState := CommentState;
    Exit;
  end;

  FBuilder.Add(TSyntaxTokenKind.Comment, Start, CloseIndex + Length(CommentClose) - Start);
  FPosition := CloseIndex + Length(CommentClose);
end;

procedure TXmlLineScanner.ScanCData;
begin
  const Start = FPosition;

  const CloseIndex = Pos(CDataClose, FLine, FPosition + Length(CDataOpen));
  if CloseIndex = 0 then
  begin
    FBuilder.Add(TSyntaxTokenKind.CDataSection, Start, Length(FLine) - Start + 1);
    FPosition := Length(FLine) + 1;
    FState := CDataState;
    Exit;
  end;

  FBuilder.Add(TSyntaxTokenKind.CDataSection, Start, CloseIndex + Length(CDataClose) - Start);
  FPosition := CloseIndex + Length(CDataClose);
end;

procedure TXmlLineScanner.ScanTagOpen;
begin
  AddPlainCharacter;
  FInsideTag := True;
  FExpectTagName := True;
end;

procedure TXmlLineScanner.ScanEntity;
begin
  var Probe := FPosition + 1;
  while (Probe <= Length(FLine)) and CharInSet(FLine[Probe], EntityCharacters) do
  begin
    Inc(Probe);
  end;

  const IsEntity = (Probe > FPosition + 1) and (CharAt(Probe) = EntityTerminator);
  if not IsEntity then
  begin
    AddPlainCharacter;
    Exit;
  end;

  FBuilder.Add(TSyntaxTokenKind.Entity, FPosition, Probe - FPosition + 1);
  FPosition := Probe + 1;
end;

procedure TXmlLineScanner.ScanInsideTag;
begin
  const Current = FLine[FPosition];

  if Current = TagCloseCharacter then
  begin
    AddPlainCharacter;
    FInsideTag := False;
    Exit;
  end;

  if CharInSet(Current, QuoteCharacters) then
  begin
    ScanAttributeValue;
    Exit;
  end;

  if CharInSet(Current, NameStartCharacters) then
  begin
    ScanName;
    Exit;
  end;

  AddPlainCharacter;
end;

procedure TXmlLineScanner.ScanName;
begin
  const Start = FPosition;

  while (FPosition <= Length(FLine)) and CharInSet(FLine[FPosition], NameCharacters) do
  begin
    Inc(FPosition);
  end;

  var Kind := TSyntaxTokenKind.AttributeName;
  if FExpectTagName then
    Kind := TSyntaxTokenKind.TagName;

  FBuilder.Add(Kind, Start, FPosition - Start);
  FExpectTagName := False;
end;

procedure TXmlLineScanner.ScanAttributeValue;
begin
  const Start = FPosition;
  const Quote = FLine[FPosition];
  Inc(FPosition);

  while (FPosition <= Length(FLine)) and (FLine[FPosition] <> Quote) do
  begin
    Inc(FPosition);
  end;

  const FoundClosingQuote = (FPosition <= Length(FLine));
  if FoundClosingQuote then
    Inc(FPosition);

  FBuilder.Add(TSyntaxTokenKind.AttributeValue, Start, FPosition - Start);
end;

function TXmlLineScanner.StartsAt(const Prefix: string): Boolean;
begin
  Result := (Copy(FLine, FPosition, Length(Prefix)) = Prefix);
end;

end.
