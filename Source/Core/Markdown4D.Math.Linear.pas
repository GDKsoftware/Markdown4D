unit Markdown4D.Math.Linear;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Math.Syntax;

type
  // A formula written out as plain text that reads in any editor or mail,
  // in the linear format of UnicodeMath (Unicode Technical Note 28): a/b for
  // a fraction, x^2 (with a superscript two) or x^(n+1) for a power, a root sign
  // before (x) for a root, and the matrix sign before (a&b@c&d) for a
  // matrix. Letters stay plain letters, so the text can be searched and
  // typed again.
  TMathLinearFormat = record
  private
    const
      Superscripts = #$2070#$00B9#$00B2#$00B3#$2074#$2075#$2076#$2077#$2078#$2079;
      Subscripts = #$2080#$2081#$2082#$2083#$2084#$2085#$2086#$2087#$2088#$2089;
    class function Write(const Node: IMathNode): string; static;
    class function WriteRow(const Node: IMathNode): string; static;
    class function WriteSymbol(const Node: IMathNode): string; static;
    class function WriteFraction(const Node: IMathNode): string; static;
    class function WriteScript(const Node: IMathNode): string; static;
    class function WriteRadical(const Node: IMathNode): string; static;
    class function WriteDelimited(const Node: IMathNode): string; static;
    class function WriteAccent(const Node: IMathNode): string; static;
    class function WriteMatrix(const Node: IMathNode): string; static;
    class function WriteLinked(const Node: IMathNode): string; static;
    class function IsColumnOfLines(const Node: IMathNode): Boolean; static;
    class function IsClosingRow(const Node: IMathNode; const RowIndex: Integer): Boolean; static;
    class function Operand(const Text: string): string; static;
    class function IsSingleOperand(const Text: string): Boolean; static;
    class function TryRaise(const Text, Digits: string; const Sign: Char; out Raised: string): Boolean; static;
    class function CombiningAccentOf(const Glyph: string): string; static;
    class function IsLetterLike(const Text: string): Boolean; static;

  public
    // The formula's TeX source as UnicodeMath linear text.
    class function FromSource(const Source: string): string; static;
    class function FromNode(const Node: IMathNode): string; static;
    // A glyph as a reader would type it: a letter of the mathematical
    // alphabets, such as a double-struck A or a bold x, as the plain letter or
    // digit it stands for.
    class function PlainText(const Text: string): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character;

const
  Space = ' ';
  Tab = #9;

class function TMathLinearFormat.FromSource(const Source: string): string;
begin
  Result := FromNode(TMathParser.Parse(Source));
end;

class function TMathLinearFormat.FromNode(const Node: IMathNode): string;
begin
  Result := Write(Node).Trim;
end;

class function TMathLinearFormat.Write(const Node: IMathNode): string;
begin
  case Node.Kind of
    TMathNodeKind.Row:
      Result := WriteRow(Node);
    TMathNodeKind.Symbol:
      Result := WriteSymbol(Node);
    TMathNodeKind.Text:
      Result := Node.Text;
    TMathNodeKind.Space:
      begin
        Result := '';
        if Node.SpaceWidth >= 0.5 then
          Result := Space;
      end;
    TMathNodeKind.Fraction:
      Result := WriteFraction(Node);
    TMathNodeKind.Script:
      Result := WriteScript(Node);
    TMathNodeKind.Radical:
      Result := WriteRadical(Node);
    TMathNodeKind.Delimited:
      Result := WriteDelimited(Node);
    TMathNodeKind.Accent:
      Result := WriteAccent(Node);
    TMathNodeKind.Matrix:
      Result := WriteMatrix(Node);
    TMathNodeKind.Styled,
    TMathNodeKind.Colored:
      Result := Write(Node.Children[0]);
    TMathNodeKind.Linked:
      Result := WriteLinked(Node);
  else
    raise EMathSyntaxError.CreateFmt('Unhandled math node kind: %d', [Ord(Node.Kind)]);
  end;
end;

// An operator name is a word and keeps a space from what it applies to, so
// sin x does not read as the letters s, i, n, x; so does an operator with
// limits, as the sum sign followed by _(i=1)^n i.
class function TMathLinearFormat.WriteRow(const Node: IMathNode): string;
begin
  Result := '';

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    const Child = Node.Children[Index];
    const Part = Write(Child);

    const IsWordOperator = ((Child.Kind = TMathNodeKind.Symbol) and (Child.AtomClass = TMathAtomClass.Operator) and
                            IsLetterLike(Part) and (Length(Part) > 1));
    const IsOperatorWithLimits = ((Child.Kind = TMathNodeKind.Script) and
                                  (Child.Children[0].AtomClass = TMathAtomClass.Operator));
    const IsLast = (Index = Node.ChildCount - 1);

    Result := Result + Part;
    if (IsWordOperator or IsOperatorWithLimits) and not IsLast then
      Result := Result + Space;
  end;
end;

class function TMathLinearFormat.WriteSymbol(const Node: IMathNode): string;
begin
  Result := Node.Text;
end;

// A binomial, a fraction without a bar, stacks with the broken bar.
class function TMathLinearFormat.WriteFraction(const Node: IMathNode): string;
begin
  const Numerator = Operand(Write(Node.Children[0]));
  const Denominator = Operand(Write(Node.Children[1]));

  if Node.HasRule then
    Result := Numerator + '/' + Denominator
  else
    Result := Numerator + #$00A6 + Denominator;
end;

// A script of digits only is written with the Unicode superscript and
// subscript digits, as x squared or a with index one, which every font has;
// anything else with ^
// and _.
class function TMathLinearFormat.WriteScript(const Node: IMathNode): string;
begin
  Result := Operand(Write(Node.Children[0]));

  const Subscript = Write(Node.Children[2]);
  if Subscript <> '' then
  begin
    var Lowered: string;
    if TryRaise(Subscript, Subscripts, #$208B, Lowered) then
      Result := Result + Lowered
    else
      Result := Result + '_' + Operand(Subscript);
  end;

  const Superscript = Write(Node.Children[1]);
  if Superscript <> '' then
  begin
    var Raised: string;
    const IsPrime = (Superscript.Replace(#$2032, '') = '');
    if IsPrime then
      Result := Result + Superscript
    else if TryRaise(Superscript, Superscripts, #$207B, Raised) then
      Result := Result + Raised
    else
      Result := Result + '^' + Operand(Superscript);
  end;
end;

class function TMathLinearFormat.WriteRadical(const Node: IMathNode): string;
begin
  const Radicand = Write(Node.Children[0]);

  var Index := '';
  if Node.ChildCount > 1 then
    Index := Write(Node.Children[1]);

  if Index = '' then
    Result := #$221A + Operand(Radicand)
  else if Index = '3' then
    Result := #$221B + Operand(Radicand)
  else if Index = '4' then
    Result := #$221C + Operand(Radicand)
  else
    Result := #$221A'(' + Index + '&' + Radicand + ')';
end;

// \left. and \right. draw no delimiter and write none.
class function TMathLinearFormat.WriteDelimited(const Node: IMathNode): string;
begin
  var Left := Node.LeftDelimiter;
  if Left = '.' then
    Left := '';

  var Right := Node.RightDelimiter;
  if Right = '.' then
    Right := '';

  Result := Left + Write(Node.Children[0]) + Right;
end;

// A single letter takes the accent as a combining mark, x with a hat; a longer body is
// bracketed first.
class function TMathLinearFormat.WriteAccent(const Node: IMathNode): string;
begin
  const Body = Write(Node.Children[0]);
  const Mark = CombiningAccentOf(Node.Text);

  if IsSingleOperand(Body) then
    Result := Body + Mark
  else
    Result := '(' + Body + ')' + Mark;
end;

// The lines of a display formula stay lines; a matrix is the matrix sign with its rows
// split by @ and its cells by &. A table, an array or a tabular, is written
// as a browser copies a table, its cells split by tabs and its rows by line
// breaks, so it pastes into a spreadsheet or a mail as a table.
class function TMathLinearFormat.WriteMatrix(const Node: IMathNode): string;
begin
  const IsLines = IsColumnOfLines(Node);
  const IsTable = (Node.ColumnSpec <> '');

  var Rows: TArray<string> := [];
  for var RowIndex := 0 to Node.ChildCount - 1 do
  begin
    const Row = Node.Children[RowIndex];
    if IsClosingRow(Node, RowIndex) then
      Continue;

    var Cells: TArray<string> := [];
    for var CellIndex := 0 to Row.ChildCount - 1 do
      Cells := Cells + [Write(Row.Children[CellIndex]).Trim];

    if IsTable then
      Rows := Rows + [string.Join(Tab, Cells)]
    else if IsLines then
      Rows := Rows + [string.Join('', Cells)]
    else
      Rows := Rows + [string.Join('&', Cells)];
  end;

  if IsLines or IsTable then
  begin
    Result := string.Join(sLineBreak, Rows);
    Exit;
  end;

  Result := Node.LeftDelimiter + #$25A0'(' + string.Join('@', Rows) + ')' + Node.RightDelimiter;
end;

// The empty row a \\ before \end leaves, which only carries the \hline below
// a table.
class function TMathLinearFormat.IsClosingRow(const Node: IMathNode; const RowIndex: Integer): Boolean;
begin
  const Row = Node.Children[RowIndex];
  Result := (RowIndex > 0) and (RowIndex = Node.ChildCount - 1) and (Row.ChildCount <= 1) and
    ((Row.ChildCount = 0) or Row.Children[0].IsEmpty);
end;

class function TMathLinearFormat.IsColumnOfLines(const Node: IMathNode): Boolean;
begin
  const HasDelimiters = ((Node.LeftDelimiter <> '') or (Node.RightDelimiter <> ''));
  if HasDelimiters then
  begin
    Result := False;
    Exit;
  end;

  if Node.Alignment = TMathColumnAlignment.Alternate then
  begin
    Result := True;
    Exit;
  end;

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    if Node.Children[Index].ChildCount > 1 then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

// A link copies as the text it shows, as a markdown link does; the address
// comes along only when the formula is copied as markdown.
class function TMathLinearFormat.WriteLinked(const Node: IMathNode): string;
begin
  Result := Write(Node.Children[0]);
end;

class function TMathLinearFormat.Operand(const Text: string): string;
begin
  if IsSingleOperand(Text) then
    Result := Text
  else
    Result := '(' + Text + ')';
end;

// One character, a number, or a word of letters reads as one operand without
// brackets, as does anything already bracketed as a whole.
class function TMathLinearFormat.IsSingleOperand(const Text: string): Boolean;
begin
  if Text = '' then
  begin
    Result := True;
    Exit;
  end;

  const IsOneCharacter = ((Length(Text) = 1) or ((Length(Text) = 2) and Text[1].IsHighSurrogate));
  if IsOneCharacter then
  begin
    Result := True;
    Exit;
  end;

  var IsNumber := True;
  for var Character in Text do
  begin
    if not (Character.IsDigit or (Character = '.')) then
      IsNumber := False;
  end;
  if IsNumber then
  begin
    Result := True;
    Exit;
  end;

  const IsBracketed = (Text[1] = '(') and (Text[Length(Text)] = ')') and (Text.LastIndexOf('(') = 0) and
                      (Text.IndexOf(')') = Length(Text) - 1);
  Result := IsBracketed;
end;

class function TMathLinearFormat.TryRaise(const Text, Digits: string; const Sign: Char; out Raised: string): Boolean;
begin
  Raised := '';

  for var Index := 1 to Length(Text) do
  begin
    const Character = Text[Index];
    if CharInSet(Character, ['0'..'9']) then
      Raised := Raised + Digits[Ord(Character) - Ord('0') + 1]
    else if ((Character = '-') or (Character = #$2212)) and (Index = 1) then
      Raised := Raised + Sign
    else
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := (Raised <> '') and (Raised <> Sign);
end;

class function TMathLinearFormat.CombiningAccentOf(const Glyph: string): string;
begin
  if Glyph = #$02C6 then
    Result := #$0302
  else if Glyph = #$02DC then
    Result := #$0303
  else if Glyph = #$00AF then
    Result := #$0304
  else if Glyph = #$02D9 then
    Result := #$0307
  else if Glyph = #$00A8 then
    Result := #$0308
  else if (Glyph = #$2192) or (Glyph = #$20D7) then
    Result := #$20D7
  else if Glyph = '' then
    Result := #$0305
  else
    Result := Glyph;
end;

class function TMathLinearFormat.IsLetterLike(const Text: string): Boolean;
begin
  for var Character in Text do
  begin
    if not Character.IsLetter then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := (Text <> '');
end;

// The mathematical alphanumeric symbols (U+1D400 to U+1D7FF) repeat the
// Latin alphabet in thirteen styles, the Greek one in five and the digits in
// five; the letterlike symbols fill the gaps in them.
class function TMathLinearFormat.PlainText(const Text: string): string;
const
  LatinFirst = $1D400;
  LatinLast = $1D6A3;
  GreekFirst = $1D6A8;
  GreekLast = $1D7C9;
  DigitFirst = $1D7CE;
  DigitLast = $1D7FF;
  GreekLetters =
    #$0391#$0392#$0393#$0394#$0395#$0396#$0397#$0398#$0399#$039A#$039B#$039C#$039D#$039E +
    #$039F#$03A0#$03A1#$03F4#$03A3#$03A4#$03A5#$03A6#$03A7#$03A8#$03A9#$2207#$03B1#$03B2 +
    #$03B3#$03B4#$03B5#$03B6#$03B7#$03B8#$03B9#$03BA#$03BB#$03BC#$03BD#$03BE#$03BF#$03C0 +
    #$03C1#$03C2#$03C3#$03C4#$03C5#$03C6#$03C7#$03C8#$03C9#$2202#$03F5#$03D1#$03F0#$03D5 +
    #$03F1#$03D6;
  LetterlikeFrom =
    #$210E#$212C#$2130#$2131#$210B#$2110#$2112#$2133#$211B#$212F#$210A#$2134#$212D#$210C +
    #$2111#$211C#$2128#$2102#$210D#$2115#$2119#$211A#$211D#$2124;
  LetterlikeTo = 'hBEFHILMReg' + 'oCHIRZCHNPQRZ';
begin
  Result := '';

  var Index := 1;
  while Index <= Length(Text) do
  begin
    const IsPair = ((Index < Length(Text)) and Text[Index].IsHighSurrogate);
    if not IsPair then
    begin
      const Letterlike = Pos(Text[Index], LetterlikeFrom);
      if Letterlike > 0 then
        Result := Result + LetterlikeTo[Letterlike]
      else
        Result := Result + Text[Index];
      Inc(Index);
      Continue;
    end;

    const CodePoint = Char.ConvertToUtf32(Text[Index], Text[Index + 1]);
    if (CodePoint >= LatinFirst) and (CodePoint <= LatinLast) then
    begin
      const Letter = (CodePoint - LatinFirst) mod 52;
      if Letter < 26 then
        Result := Result + Chr(Ord('A') + Letter)
      else
        Result := Result + Chr(Ord('a') + Letter - 26);
    end
    else if (CodePoint >= GreekFirst) and (CodePoint <= GreekLast) then
      Result := Result + GreekLetters[(CodePoint - GreekFirst) mod 58 + 1]
    else if (CodePoint >= DigitFirst) and (CodePoint <= DigitLast) then
      Result := Result + Chr(Ord('0') + (CodePoint - DigitFirst) mod 10)
    else
      Result := Result + Text[Index] + Text[Index + 1];

    Inc(Index, 2);
  end;
end;

end.
