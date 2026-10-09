unit Markdown4DStudio.Text;

// Framework-agnostic text metrics shared by both studio builds.

interface

type
  TPadText = record
    class procedure ComputeLineColumn(const Text: string; const Offset: Integer;
      out Line, Column: Integer); static;
    class function CountWords(const Text: string): Integer; static;
    class function CountCharacters(const Text: string): Integer; static;
  end;

implementation

uses
  System.Math,
  System.Character;

class procedure TPadText.ComputeLineColumn(const Text: string; const Offset: Integer;
  out Line, Column: Integer);
begin
  Line := 1;
  Column := 1;

  const Limit = Min(Offset, Length(Text));
  for var Index := 1 to Limit do
  begin
    if Text[Index] = #10 then
    begin
      Inc(Line);
      Column := 1;
    end
    else
    begin
      Inc(Column);
    end;
  end;
end;

class function TPadText.CountWords(const Text: string): Integer;
begin
  Result := 0;

  var InsideWord := False;
  for var Character in Text do
  begin
    if Character.IsWhiteSpace then
      InsideWord := False
    else if not InsideWord then
    begin
      InsideWord := True;
      Inc(Result);
    end;
  end;
end;

class function TPadText.CountCharacters(const Text: string): Integer;
begin
  Result := 0;

  var Index := 1;
  const TextLength = Length(Text);
  while Index <= TextLength do
  begin
    const Current = Text[Index];
    const IsLineBreak = ((Current = #13) or (Current = #10));
    const IsSurrogatePair = ((Index < TextLength) and
                             Current.IsHighSurrogate and
                             Text[Index + 1].IsLowSurrogate);

    if not IsLineBreak then
      Inc(Result);

    if IsSurrogatePair then
      Inc(Index, 2)
    else
      Inc(Index);
  end;
end;

end.
