unit Markdown4D.Math.Chemistry;

// A subset of mhchem, lowered to TeX that the math parser already lays out.
//
// Chemistry notes and generated text write formulas as \ce inside math:
// element counts are subscripts, a trailing plus or minus is a charge, and an
// arrow such as -> is a reaction. mhchem in KaTeX and MathJax translates to
// ordinary TeX the same way, which keeps the layouter unaware of chemistry.
//
// The subset covers formulas and counts, charges, isotopes, states of matter,
// reaction arrows, simple bonds, and the addition dot of a hydrate. Anything
// else is copied through, so an unknown TeX command still paints as the
// error symbol of the math parser.

interface

// Source is the interior of a \ce argument, without its braces.
function ChemistryToTeX(const Source: string): string;

implementation

uses
  System.SysUtils,
  System.Character;

type
  TChemistryTranslator = class
  private
    const
      Backslash = '\';
      CaretChar = '^';
      UnderscoreChar = '_';
      OpenBraceChar = '{';
      CloseBraceChar = '}';
      OpenParenthesisChar = '(';
      CloseParenthesisChar = ')';
      OpenBracketChar = '[';
      CloseBracketChar = ']';
      PlusChar = '+';
      MinusChar = '-';
      EqualsChar = '=';
      HashChar = '#';
      DotChar = '.';
      AsteriskChar = '*';
      // \equiv is a relation, which the layouter spaces; a bond sits tight
      // between its atoms like = and -.
      TripleBondGlyph = #$2261;
      // Real formulas nest a few groups deep. The cap bounds the recursion,
      // and the copy of the rest of the formula that each level takes.
      MaxGroupDepth = 32;
    var
      FSource: string;
      FIndex: Integer;
      FDepth: Integer;
      FOutput: TStringBuilder;
      // True while the output ends in an atom or a group, so that a count or
      // a charge right after it becomes its script.
      FCanAttachScript: Boolean;
    function AtEnd: Boolean;
    function Peek: Char;
    function StartsWith(const Value: string): Boolean;
    function StartsSpecies: Boolean;
    function StartsState: Boolean;
    procedure Advance(const Count: Integer);
    procedure SkipWhitespace;
    procedure EmitAtom(const Value: string);
    procedure EmitSeparator(const Value: string);
    procedure EmitCharge(const Sign: string);
    procedure EmitGroup(const Left, Inner, Right: string);
    function ReadBalanced(const OpenChar, CloseChar: Char): string;
    function ReadScriptBody: string;
    function ReadDigits: string;
    function ReadNumber: string;
    function TryReplaceToken(const Token, Replacement: string): Boolean;
    function TryTranslateArrow: Boolean;
    procedure TranslateNext;
    procedure TranslateScript;
    procedure TranslateNumber;
    procedure TranslateElement;
    procedure TranslateParenthesis;
    procedure TranslatePlus;
    procedure TranslateMinus;
    procedure TranslateEquals;
    procedure TranslateDot;
    procedure TranslateCommand;
    class function ScriptText(const Body: string): string; static;
    class function IsState(const Body: string): Boolean; static;
    class function StartsFormula(const Value: Char): Boolean; static;

  public
    constructor Create(const Source: string; const Depth: Integer);
    destructor Destroy; override;
    class function Lower(const Source: string; const Depth: Integer): string; static;
    function Translate: string;
  end;

function ChemistryToTeX(const Source: string): string;
begin
  Result := TChemistryTranslator.Lower(Source, 0);
end;

constructor TChemistryTranslator.Create(const Source: string; const Depth: Integer);
begin
  inherited Create;

  FSource := Source;
  FIndex := 1;
  FDepth := Depth;
  FOutput := TStringBuilder.Create;
end;

destructor TChemistryTranslator.Destroy;
begin
  FOutput.Free;

  inherited Destroy;
end;

class function TChemistryTranslator.Lower(const Source: string; const Depth: Integer): string;
begin
  const Translator = TChemistryTranslator.Create(Source, Depth);
  try
    Result := Translator.Translate;
  finally
    Translator.Free;
  end;
end;

function TChemistryTranslator.Translate: string;
begin
  while not AtEnd do
    TranslateNext;

  Result := FOutput.ToString;
end;

function TChemistryTranslator.AtEnd: Boolean;
begin
  Result := FIndex > Length(FSource);
end;

function TChemistryTranslator.Peek: Char;
begin
  if AtEnd then
  begin
    Result := #0;
    Exit;
  end;

  Result := FSource[FIndex];
end;

function TChemistryTranslator.StartsWith(const Value: string): Boolean;
begin
  Result := Copy(FSource, FIndex, Length(Value)) = Value;
end;

// A sign before another species is an operator or a bond. A state of matter
// is not a species, so the minus in Cl-(aq) is still a charge.
function TChemistryTranslator.StartsSpecies: Boolean;
begin
  Result := StartsFormula(Peek) and not StartsState;
end;

function TChemistryTranslator.StartsState: Boolean;
begin
  Result := False;
  if Peek <> OpenParenthesisChar then
    Exit;

  const Start = FIndex;
  Result := IsState(ReadBalanced(OpenParenthesisChar, CloseParenthesisChar));
  FIndex := Start;
end;

procedure TChemistryTranslator.Advance(const Count: Integer);
begin
  Inc(FIndex, Count);
end;

procedure TChemistryTranslator.SkipWhitespace;
begin
  while (not AtEnd) and Peek.IsWhiteSpace do
    Advance(1);
end;

procedure TChemistryTranslator.EmitAtom(const Value: string);
begin
  FOutput.Append(Value);
  FCanAttachScript := True;
end;

procedure TChemistryTranslator.EmitSeparator(const Value: string);
begin
  FOutput.Append(Value);
  FCanAttachScript := False;
end;

// A charge closes its species: a number after it is a coefficient, not a
// count.
procedure TChemistryTranslator.EmitCharge(const Sign: string);
begin
  EmitSeparator('^{' + Sign + '}');
end;

// Past MaxGroupDepth the group keeps its delimiters around an ellipsis.
procedure TChemistryTranslator.EmitGroup(const Left, Inner, Right: string);
begin
  const IsTooDeep = (FDepth >= MaxGroupDepth);
  if IsTooDeep then
  begin
    EmitAtom('{' + Left + '\ldots' + Right + '}');
    Exit;
  end;

  EmitAtom('{' + Left + Lower(Inner, FDepth + 1) + Right + '}');
end;

// The cursor is on OpenChar. An unclosed group runs to the end, because the
// formula may still be streaming in.
function TChemistryTranslator.ReadBalanced(const OpenChar, CloseChar: Char): string;
begin
  Advance(1);
  const Start = FIndex;
  var Depth := 1;

  while (not AtEnd) and (Depth > 0) do
  begin
    const Current = Peek;

    if Current = Backslash then
      Advance(1)
    else if Current = OpenChar then
      Inc(Depth)
    else if Current = CloseChar then
      Dec(Depth);

    Advance(1);
  end;

  var EndIndex := FIndex;
  if Depth = 0 then
    Dec(EndIndex);

  Result := Copy(FSource, Start, EndIndex - Start);
end;

// Without braces a script runs over digits, dots and charge signs, stopping
// before an arrow. Failing those it takes one letter, as in Fe_xO.
function TChemistryTranslator.ReadScriptBody: string;
begin
  if Peek = OpenBraceChar then
  begin
    Result := ReadBalanced(OpenBraceChar, CloseBraceChar);
    Exit;
  end;

  const Start = FIndex;

  while not AtEnd do
  begin
    const IsCharge = (Peek = PlusChar) or ((Peek = MinusChar) and not StartsWith('->'));
    if not (Peek.IsDigit or (Peek = DotChar) or IsCharge) then
      Break;

    Advance(1);
  end;

  const HasRun = (FIndex > Start);
  if (not HasRun) and Peek.IsLetter then
    Advance(1);

  Result := Copy(FSource, Start, FIndex - Start);
end;

function TChemistryTranslator.ReadDigits: string;
begin
  const Start = FIndex;

  while (not AtEnd) and Peek.IsDigit do
    Advance(1);

  Result := Copy(FSource, Start, FIndex - Start);
end;

function TChemistryTranslator.ReadNumber: string;
begin
  Result := ReadDigits;

  const HasFraction = (Peek = DotChar) and (FIndex < Length(FSource)) and FSource[FIndex + 1].IsDigit;
  if not HasFraction then
    Exit;

  Advance(1);
  Result := Result + DotChar + ReadDigits;
end;

function TChemistryTranslator.TryReplaceToken(const Token, Replacement: string): Boolean;
begin
  Result := StartsWith(Token);
  if not Result then
    Exit;

  Advance(Length(Token));
  EmitSeparator(Replacement);
end;

// Longest first, so <=> is not read as <- followed by =>.
function TChemistryTranslator.TryTranslateArrow: Boolean;
begin
  Result := TryReplaceToken('<=>', '\rightleftharpoons') or TryReplaceToken('<->', '\leftrightarrow') or
    TryReplaceToken('->', '\rightarrow') or TryReplaceToken('<-', '\leftarrow');
end;

procedure TChemistryTranslator.TranslateNext;
begin
  if TryTranslateArrow then
    Exit;

  const Current = Peek;

  // Spaces in math are not drawn: the layouter spaces operators and arrows
  // itself. A space still ends the species, so the + in "Na +" joins two.
  if Current.IsWhiteSpace then
  begin
    SkipWhitespace;
    FCanAttachScript := False;
    Exit;
  end;

  if Current.IsDigit then
  begin
    TranslateNumber;
    Exit;
  end;

  if Current.IsLetter then
  begin
    TranslateElement;
    Exit;
  end;

  case Current of
    CaretChar, UnderscoreChar:
      TranslateScript;
    OpenParenthesisChar:
      TranslateParenthesis;
    OpenBracketChar:
      EmitGroup(OpenBracketChar, ReadBalanced(OpenBracketChar, CloseBracketChar), CloseBracketChar);
    OpenBraceChar:
      EmitGroup('', ReadBalanced(OpenBraceChar, CloseBraceChar), '');
    PlusChar:
      TranslatePlus;
    MinusChar:
      TranslateMinus;
    EqualsChar:
      TranslateEquals;
    HashChar:
      begin
        Advance(1);
        EmitSeparator(TripleBondGlyph);
      end;
    DotChar, AsteriskChar:
      TranslateDot;
    Backslash:
      TranslateCommand;
  else
    Advance(1);
    EmitSeparator(Current);
  end;
end;

// A script with nothing to attach to sits on an empty base, so the mass and
// atomic numbers in ^{227}_{90}Th stand to the left of the element.
procedure TChemistryTranslator.TranslateScript;
begin
  const Marker = Peek;
  Advance(1);

  const Body = ScriptText(ReadScriptBody);
  if Body = '' then
    Exit;

  if not FCanAttachScript then
    FOutput.Append('{}');

  EmitAtom(Marker + '{' + Body + '}');
end;

// A number after an atom is its count. Elsewhere it is a coefficient, which
// may carry a decimal point and keeps a thin space before its formula.
procedure TChemistryTranslator.TranslateNumber;
begin
  if FCanAttachScript then
  begin
    // A count is an integer: the dot in CuSO4.5H2O is an addition dot.
    FOutput.Append('_{').Append(ReadDigits).Append('}');
    Exit;
  end;

  EmitSeparator(ReadNumber);

  SkipWhitespace;
  if StartsFormula(Peek) then
    FOutput.Append('\,');
end;

// An element is a capital and its lowercase tail: Na is sodium, while CH is
// carbon then hydrogen.
procedure TChemistryTranslator.TranslateElement;
begin
  const Start = FIndex;
  const IsCapital = Peek.IsUpper;
  Advance(1);

  if IsCapital then
    while (not AtEnd) and Peek.IsLower do
      Advance(1);

  EmitAtom('\mathrm{' + Copy(FSource, Start, FIndex - Start) + '}');
end;

procedure TChemistryTranslator.TranslateParenthesis;
begin
  const Inner = ReadBalanced(OpenParenthesisChar, CloseParenthesisChar);

  if IsState(Inner) then
  begin
    EmitSeparator('\,\text{(' + Inner.Trim + ')}');
    Exit;
  end;

  EmitGroup(OpenParenthesisChar, Inner, CloseParenthesisChar);
end;

// A plus right after an atom is a charge, as in Na+. Before another species
// it is the plus of a reaction.
procedure TChemistryTranslator.TranslatePlus;
begin
  Advance(1);

  const IsCharge = FCanAttachScript and not StartsSpecies;
  if IsCharge then
  begin
    EmitCharge(PlusChar);
    Exit;
  end;

  EmitSeparator(PlusChar);
end;

// Before another species a minus is a single bond, drawn as a hyphen rather
// than a minus sign. Right after an atom it is a charge.
procedure TChemistryTranslator.TranslateMinus;
begin
  Advance(1);

  if StartsSpecies then
  begin
    EmitSeparator('\text{-}');
    Exit;
  end;

  if FCanAttachScript then
  begin
    EmitCharge(MinusChar);
    Exit;
  end;

  EmitSeparator(MinusChar);
end;

procedure TChemistryTranslator.TranslateEquals;
begin
  Advance(1);

  if StartsSpecies then
  begin
    EmitSeparator('\text{=}');
    Exit;
  end;

  EmitSeparator(EqualsChar);
end;

// An asterisk, or a dot before a number, is the addition dot of a hydrate:
// CuSO4*5H2O and CuSO4.5H2O both show a centred dot.
procedure TChemistryTranslator.TranslateDot;
begin
  const IsAsterisk = (Peek = AsteriskChar);
  Advance(1);

  if IsAsterisk or Peek.IsDigit then
  begin
    EmitSeparator('\cdot');
    Exit;
  end;

  EmitSeparator(DotChar);
end;

// A command is copied with its first braced argument, so the math parser
// still draws an unknown one as an error. A control symbol such as \{ is
// one character long.
procedure TChemistryTranslator.TranslateCommand;
begin
  const Start = FIndex;
  Advance(1);

  while (not AtEnd) and Peek.IsLetter do
    Advance(1);

  const IsControlSymbol = (FIndex = Start + 1);
  if IsControlSymbol or (Peek = AsteriskChar) then
    Advance(1);

  var Command := Copy(FSource, Start, FIndex - Start);

  const HasArgument = (not IsControlSymbol) and (Peek = OpenBraceChar);
  if HasArgument then
    Command := Command + '{' + ReadBalanced(OpenBraceChar, CloseBraceChar) + '}';

  EmitSeparator(Command);
end;

// Letters in a script are element symbols, so they stay upright. A command
// such as \bullet is copied unchanged.
class function TChemistryTranslator.ScriptText(const Body: string): string;
begin
  Result := '';
  var Index := 1;

  while Index <= Length(Body) do
  begin
    const Start = Index;

    if Body[Index] = Backslash then
    begin
      Inc(Index);
      while (Index <= Length(Body)) and Body[Index].IsLetter do
        Inc(Index);

      const IsControlSymbol = (Index = Start + 1) and (Index <= Length(Body));
      if IsControlSymbol then
        Inc(Index);

      Result := Result + Copy(Body, Start, Index - Start);
      Continue;
    end;

    if Body[Index].IsLetter then
    begin
      while (Index <= Length(Body)) and Body[Index].IsLetter do
        Inc(Index);

      Result := Result + '\mathrm{' + Copy(Body, Start, Index - Start) + '}';
      Continue;
    end;

    Result := Result + Body[Index];
    Inc(Index);
  end;
end;

// Case matters: (S) is a sulfur group, not a solid.
class function TChemistryTranslator.IsState(const Body: string): Boolean;
begin
  const Name = Body.Trim;
  Result := (Name = 's') or (Name = 'l') or (Name = 'g') or (Name = 'aq');
end;

class function TChemistryTranslator.StartsFormula(const Value: Char): Boolean;
begin
  Result := Value.IsLetter or Value.IsDigit or (Value = OpenParenthesisChar) or (Value = OpenBracketChar) or
    (Value = Backslash);
end;

end.
