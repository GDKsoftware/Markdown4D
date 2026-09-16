unit Markdown4D.Parser.LinkSyntax;

{$SCOPEDENUMS ON}

interface

type
  TLinkSyntaxScanner = class
  private
    const
      DoubleQuote = '"';
      SingleQuote = '''';
      MaxLabelUnits = 1000;
    var
      FContent: string;
      FPosition: Integer;
    function TryParsePointyDestination(out Destination: string): Boolean;

  public
    procedure Reset(const Content: string; const StartPosition: Integer);
    procedure Advance(const Count: Integer);
    procedure MoveTo(const Position: Integer);
    function TryParseLabel(out LabelContent: string; out ConsumedLength: Integer): Boolean;
    procedure SkipSpacesWithOneNewline;
    function TryParseDestination(out Destination: string): Boolean;
    function TryParseTitle(out Title: string): Boolean;
    function ConsumeSpacesToLineEnd: Boolean;
    function PeekChar: Char;
    property Position: Integer read FPosition;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Defines,
  Markdown4D.Text.Unescape;

procedure TLinkSyntaxScanner.Reset(const Content: string; const StartPosition: Integer);
begin
  FContent := Content;
  FPosition := StartPosition;
end;

procedure TLinkSyntaxScanner.Advance(const Count: Integer);
begin
  Inc(FPosition, Count);
end;

procedure TLinkSyntaxScanner.MoveTo(const Position: Integer);
begin
  FPosition := Position;
end;

function TLinkSyntaxScanner.TryParseLabel(out LabelContent: string; out ConsumedLength: Integer): Boolean;
begin
  LabelContent := '';
  ConsumedLength := 0;

  const StartsWithBracket = (PeekChar = OpenBracket);
  if not StartsWithBracket then
  begin
    Result := False;
    Exit;
  end;

  var Index := FPosition + 1;
  var Units := 0;

  while Index <= Length(FContent) do
  begin
    const Current = FContent[Index];

    if Current = CloseBracket then
    begin
      LabelContent := Copy(FContent, FPosition + 1, Index - FPosition - 1);
      ConsumedLength := Index - FPosition + 1;
      FPosition := Index + 1;
      Result := True;
      Exit;
    end;

    if Current = OpenBracket then
    begin
      Result := False;
      Exit;
    end;

    const HasEscapedChar = (Current = Backslash) and (Index < Length(FContent));
    if HasEscapedChar then
      Inc(Index, 2)
    else
      Inc(Index);

    Inc(Units);

    if Units > MaxLabelUnits then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := False;
end;

procedure TLinkSyntaxScanner.SkipSpacesWithOneNewline;
begin
  while CharInSet(PeekChar, [Space, Tab]) do
  begin
    Inc(FPosition);
  end;

  const HasNewline = (PeekChar = LineFeed);
  if not HasNewline then
    Exit;

  Inc(FPosition);

  while CharInSet(PeekChar, [Space, Tab]) do
  begin
    Inc(FPosition);
  end;
end;

function TLinkSyntaxScanner.TryParseDestination(out Destination: string): Boolean;
begin
  Destination := '';

  if PeekChar = LessThan then
  begin
    Result := TryParsePointyDestination(Destination);
    Exit;
  end;

  const StartPosition = FPosition;
  var OpenParens := 0;

  while FPosition <= Length(FContent) do
  begin
    const Current = FContent[FPosition];

    const IsEscapedPunctuation = (Current = Backslash) and (FPosition < Length(FContent)) and
      TMarkdownUnescape.IsAsciiPunctuation(FContent[FPosition + 1]);
    if IsEscapedPunctuation then
    begin
      Inc(FPosition, 2);
      Continue;
    end;

    if Current = OpenParen then
    begin
      Inc(OpenParens);
      Inc(FPosition);
      Continue;
    end;

    if Current = CloseParen then
    begin
      if OpenParens < 1 then
        Break;

      Dec(OpenParens);
      Inc(FPosition);
      Continue;
    end;

    if TMarkdownUnescape.IsMarkdownWhitespace(Current) then
      Break;

    Inc(FPosition);
  end;

  const ConsumedNothing = (FPosition = StartPosition) and (PeekChar <> CloseParen);
  if ConsumedNothing then
  begin
    Result := False;
    Exit;
  end;

  const Unbalanced = (OpenParens <> 0);
  if Unbalanced then
  begin
    Result := False;
    Exit;
  end;

  Destination := Copy(FContent, StartPosition, FPosition - StartPosition);
  Result := True;
end;

function TLinkSyntaxScanner.TryParsePointyDestination(out Destination: string): Boolean;
begin
  Destination := '';
  var Index := FPosition + 1;

  while Index <= Length(FContent) do
  begin
    const Current = FContent[Index];

    if Current = GreaterThan then
    begin
      Destination := Copy(FContent, FPosition + 1, Index - FPosition - 1);
      FPosition := Index + 1;
      Result := True;
      Exit;
    end;

    const IsForbidden = (Current = LessThan) or (Current = LineFeed);
    if IsForbidden then
    begin
      Result := False;
      Exit;
    end;

    const SkipsEscapedChar = (Current = Backslash) and (Index < Length(FContent)) and
      (FContent[Index + 1] <> LineFeed);
    if SkipsEscapedChar then
      Inc(Index, 2)
    else
      Inc(Index);
  end;

  Result := False;
end;

function TLinkSyntaxScanner.TryParseTitle(out Title: string): Boolean;
begin
  Title := '';
  const Opener = PeekChar;

  var Closer := #0;
  const IsQuoteOpener = (Opener = DoubleQuote) or (Opener = SingleQuote);
  if IsQuoteOpener then
    Closer := Opener
  else if Opener = OpenParen then
    Closer := CloseParen;

  const HasOpener = (Closer <> #0);
  if not HasOpener then
  begin
    Result := False;
    Exit;
  end;

  var Index := FPosition + 1;

  while Index <= Length(FContent) do
  begin
    const Current = FContent[Index];

    if Current = Closer then
    begin
      Title := Copy(FContent, FPosition + 1, Index - FPosition - 1);
      FPosition := Index + 1;
      Result := True;
      Exit;
    end;

    const IsNestedParen = (Closer = CloseParen) and (Current = OpenParen);
    if IsNestedParen then
    begin
      Result := False;
      Exit;
    end;

    const IsEscapedPunctuation = (Current = Backslash) and (Index < Length(FContent)) and
      TMarkdownUnescape.IsAsciiPunctuation(FContent[Index + 1]);
    if IsEscapedPunctuation then
      Inc(Index, 2)
    else
      Inc(Index);
  end;

  Result := False;
end;

function TLinkSyntaxScanner.ConsumeSpacesToLineEnd: Boolean;
begin
  var Index := FPosition;

  while (Index <= Length(FContent)) and CharInSet(FContent[Index], [Space, Tab]) do
  begin
    Inc(Index);
  end;

  const AtContentEnd = (Index > Length(FContent));
  if AtContentEnd then
  begin
    FPosition := Index;
    Result := True;
    Exit;
  end;

  const AtLineEnd = (FContent[Index] = LineFeed);
  if AtLineEnd then
  begin
    FPosition := Index + 1;
    Result := True;
    Exit;
  end;

  Result := False;
end;

function TLinkSyntaxScanner.PeekChar: Char;
begin
  const OutOfRange = (FPosition > Length(FContent));
  if OutOfRange then
  begin
    Result := #0;
    Exit;
  end;

  Result := FContent[FPosition];
end;

end.
