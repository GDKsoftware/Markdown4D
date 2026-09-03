unit Markdown4DStudio.Commands;

{$SCOPEDENUMS ON}

interface

type
  TPadCommandAction = reference to procedure;

  TPadCommand = record
    Name: string;
    Category: string;
    ShortcutText: string;
    Action: TPadCommandAction;
    class function Create(const Name, Category, ShortcutText: string;
      const Action: TPadCommandAction): TPadCommand; static;
  end;

  TPadCommandMatch = record
    Command: TPadCommand;
    Score: Integer;
  end;

  TPadCommandRegistry = class
  strict private
    var
      FCommands: TArray<TPadCommand>;
  public
    procedure Register(const Name, Category, ShortcutText: string; const Action: TPadCommandAction);
    procedure Clear;
    function Count: Integer;
    function Commands: TArray<TPadCommand>;
    function Match(const Query: string): TArray<TPadCommandMatch>;
  end;

  TPadFuzzyMatcher = record
  strict private
    class function IsWordStart(const Candidate: string; const Index: Integer): Boolean; static;
  public
    class function Score(const Candidate, Query: string; out Score: Integer): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Character;

type
  TPadIndexedMatch = record
    Command: TPadCommand;
    Score: Integer;
    Order: Integer;
  end;

class function TPadCommand.Create(const Name, Category, ShortcutText: string;
  const Action: TPadCommandAction): TPadCommand;
begin
  Result.Name := Name;
  Result.Category := Category;
  Result.ShortcutText := ShortcutText;
  Result.Action := Action;
end;

procedure TPadCommandRegistry.Register(const Name, Category, ShortcutText: string; const Action: TPadCommandAction);
begin
  FCommands := FCommands + [TPadCommand.Create(Name, Category, ShortcutText, Action)];
end;

procedure TPadCommandRegistry.Clear;
begin
  FCommands := nil;
end;

function TPadCommandRegistry.Count: Integer;
begin
  Result := Length(FCommands);
end;

function TPadCommandRegistry.Commands: TArray<TPadCommand>;
begin
  Result := FCommands;
end;

function TPadCommandRegistry.Match(const Query: string): TArray<TPadCommandMatch>;
begin
  if Query = '' then
  begin
    SetLength(Result, Length(FCommands));

    for var Index := 0 to High(FCommands) do
    begin
      Result[Index].Command := FCommands[Index];
      Result[Index].Score := 0;
    end;

    Exit;
  end;

  var Ranked: TArray<TPadIndexedMatch> := [];

  for var Index := 0 to High(FCommands) do
  begin
    var CommandScore: Integer;
    if TPadFuzzyMatcher.Score(FCommands[Index].Name, Query, CommandScore) then
    begin
      var Entry := Default(TPadIndexedMatch);
      Entry.Command := FCommands[Index];
      Entry.Score := CommandScore;
      Entry.Order := Index;
      Ranked := Ranked + [Entry];
    end;
  end;

  TArray.Sort<TPadIndexedMatch>(Ranked, TComparer<TPadIndexedMatch>.Construct(
    function(const Left, Right: TPadIndexedMatch): Integer
    begin
      Result := Right.Score - Left.Score;
      if Result = 0 then
        Result := Left.Order - Right.Order;
    end));

  SetLength(Result, Length(Ranked));

  for var Index := 0 to High(Ranked) do
  begin
    Result[Index].Command := Ranked[Index].Command;
    Result[Index].Score := Ranked[Index].Score;
  end;
end;

class function TPadFuzzyMatcher.Score(const Candidate, Query: string; out Score: Integer): Boolean;
const
  WordStartBonus = 10;
  ConsecutiveBonus = 5;
  LeadingPenaltyPerChar = 1;
begin
  Score := 0;

  if Query = '' then
    Exit(True);

  var QueryCursor := 1;
  var PreviousMatchedIndex := -1;

  for var Index := 1 to Length(Candidate) do
  begin
    if QueryCursor > Length(Query) then
      Break;

    const IsMatch = Candidate[Index].ToLower = Query[QueryCursor].ToLower;
    if not IsMatch then
      Continue;

    if QueryCursor = 1 then
      Dec(Score, (Index - 1) * LeadingPenaltyPerChar);

    if IsWordStart(Candidate, Index) then
      Inc(Score, WordStartBonus);

    if Index = PreviousMatchedIndex + 1 then
      Inc(Score, ConsecutiveBonus);

    PreviousMatchedIndex := Index;
    Inc(QueryCursor);
  end;

  Result := QueryCursor > Length(Query);
  if not Result then
    Score := 0;
end;

class function TPadFuzzyMatcher.IsWordStart(const Candidate: string; const Index: Integer): Boolean;
begin
  if Index = 1 then
    Exit(True);

  const PreviousChar = Candidate[Index - 1];
  const CurrentChar = Candidate[Index];

  if not PreviousChar.IsLetterOrDigit then
    Exit(True);

  Result := PreviousChar.IsLower and CurrentChar.IsUpper;
end;

end.
