unit Markdown4D.Layout.TextSearch;

{$SCOPEDENUMS ON}

interface

type
  TMarkdownFindOptions = record
    MatchCase: Boolean;
    WholeWord: Boolean;
    class function Create(const MatchCase, WholeWord: Boolean): TMarkdownFindOptions; static;
  end;

  // The rules a find follows, shared by the editor and the viewer so both
  // agree on what a match and a word are.
  TMarkdownTextSearch = class
  public
    class function IsWordCharacter(const Character: Char): Boolean; static;
    // Start counts from 1, as Text does.
    class function MatchesAt(const Needle, Text: string; const Start: Integer;
                             const Options: TMarkdownFindOptions): Boolean; static;
    // The first match at or after Start, counted from 1; 0 when there is none.
    class function IndexOf(const Needle, Text: string; const Start: Integer;
                           const Options: TMarkdownFindOptions): Integer; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character;

class function TMarkdownFindOptions.Create(const MatchCase, WholeWord: Boolean): TMarkdownFindOptions;
begin
  Result.MatchCase := MatchCase;
  Result.WholeWord := WholeWord;
end;

class function TMarkdownTextSearch.IsWordCharacter(const Character: Char): Boolean;
begin
  Result := Character.IsLetterOrDigit or (Character = '_');
end;

class function TMarkdownTextSearch.MatchesAt(const Needle, Text: string; const Start: Integer;
  const Options: TMarkdownFindOptions): Boolean;
begin
  const NeedleLength = Length(Needle);
  const LastCharacter = Start + NeedleLength - 1;

  const IsInside = (NeedleLength > 0) and (Start >= 1) and (LastCharacter <= Length(Text));
  if not IsInside then
  begin
    Result := False;
    Exit;
  end;

  for var Offset := 0 to NeedleLength - 1 do
  begin
    const TextCharacter = Text[Start + Offset];
    const NeedleCharacter = Needle[Offset + 1];

    const IsSame = ((TextCharacter = NeedleCharacter) or
                    ((not Options.MatchCase) and (TextCharacter.ToLower = NeedleCharacter.ToLower)));
    if not IsSame then
    begin
      Result := False;
      Exit;
    end;
  end;

  if not Options.WholeWord then
  begin
    Result := True;
    Exit;
  end;

  const HasLeftBoundary = (Start = 1) or not IsWordCharacter(Text[Start - 1]);
  const HasRightBoundary = (LastCharacter = Length(Text)) or not IsWordCharacter(Text[LastCharacter + 1]);
  Result := HasLeftBoundary and HasRightBoundary;
end;

class function TMarkdownTextSearch.IndexOf(const Needle, Text: string; const Start: Integer;
  const Options: TMarkdownFindOptions): Integer;
begin
  const LastStart = Length(Text) - Length(Needle) + 1;

  for var Candidate := Start to LastStart do
  begin
    if MatchesAt(Needle, Text, Candidate, Options) then
    begin
      Result := Candidate;
      Exit;
    end;
  end;

  Result := 0;
end;

end.
