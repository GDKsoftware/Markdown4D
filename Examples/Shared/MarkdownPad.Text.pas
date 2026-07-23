unit MarkdownPad.Text;

// Framework-agnostic text metrics shared by both pad builds.

interface

type
  TPadText = record
    class procedure ComputeLineColumn(const Text: string; const Offset: Integer;
      out Line, Column: Integer); static;
    class function CountWords(const Text: string): Integer; static;
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
      Inc(Column);
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

end.
