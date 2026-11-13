unit Markdown4D.Math.UnicodeMath;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Math.Syntax;

type
  // A formula as text a reader takes in without knowing TeX: UnicodeMath, the
  // linear format Word writes when an equation is copied as text. A fraction
  // is its parts around a slash, a script follows ^ or _, and a part of more
  // than one word stands in brackets. A formula that is a table and nothing
  // else, an array, a tabular or a matrix without delimiters, is its cells
  // apart by tabs and its rows by line breaks, as a table copies from a
  // browser. Equations under each other, aligned or gathered, are no table.
  // The marks UnicodeMath has for a program rather than a reader are left
  // out: the function application after sin, the operand mark after a sum,
  // the quotes around text and the mark of a delimiter that is not drawn.
  TUnicodeMathFormat = record
  private
    const
      Space = ' ';
      Tab = #9;
      Minus = #$2212;
      Hyphen = '-';
      Over = '/';
      Atop = #$00A6;
      Superscript = '^';
      Subscript = '_';
      Prime = #$2032;
      SquareRoot = #$221A;
      CubeRoot = #$221B;
      FourthRoot = #$221C;
      Overbar = #$00AF;
      MatrixMark = #$25A0;
      EquationArrayMark = #$2588;
      CellEnd = '&';
      RowEnd = '@';
      GroupStart = '(';
      GroupEnd = ')';
      NoDelimiter = '.';
      // The accents as the parser names them, and the combining mark that
      // sets each over the letter before it.
      AccentGlyphs = #$02C6#$02DC#$00AF#$02D9#$00A8#$2192#$02C7#$02D8#$00B4'`';
      CombiningMarks = #$0302#$0303#$0304#$0307#$0308#$20D7#$030C#$0306#$0301#$0300;
    class function Write(const Node: IMathNode): string; static;
    class function WriteRow(const Node: IMathNode): string; static;
    class function RunsOn(const Previous, Next: IMathNode; const Before, After: string): Boolean; static;
    class function IsOperator(const Node: IMathNode): Boolean; static;
    class function WriteSymbol(const Node: IMathNode): string; static;
    class function WriteSpace(const Node: IMathNode): string; static;
    class function WriteFraction(const Node: IMathNode): string; static;
    class function WriteScript(const Node: IMathNode): string; static;
    class function IsPrimes(const Node: IMathNode): Boolean; static;
    class function WriteRadical(const Node: IMathNode): string; static;
    class function RootSign(const RootIndex: string): string; static;
    class function WriteDelimited(const Node: IMathNode): string; static;
    class function WriteAccent(const Node: IMathNode): string; static;
    class function WriteMatrix(const Node: IMathNode): string; static;
    class function WriteCells(const Node: IMathNode; const CellSeparator, RowSeparator: string): string; static;
    class function WriteRowCells(const Row: IMathNode; const CellSeparator: string): string; static;
    class function Delimiter(const Text: string): string; static;
    class function Base(const Node: IMathNode): string; static;
    class function Argument(const Node: IMathNode): string; static;
    class function FractionPart(const Node: IMathNode): string; static;
    class function Grouped(const Content: string): string; static;
    class function Unwrapped(const Node: IMathNode): IMathNode; static;
    class function IsSingle(const Node: IMathNode): Boolean; static;
    class function IsWord(const Node: IMathNode): Boolean; static;
    class function IsLetterOrDigit(const Node: IMathNode): Boolean; static;
    class function IsBareMatrix(const Node: IMathNode): Boolean; static;
    class function HasSeveralColumns(const Matrix: IMathNode): Boolean; static;

  public
    class function FromSource(const Source: string): string; static;
    // True for a formula that is a table and nothing else, which FromSource
    // writes as its cells.
    class function IsTable(const Source: string): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character;

class function TUnicodeMathFormat.FromSource(const Source: string): string;
begin
  const Formula = TMathParser.Parse(Source);
  const Table = Unwrapped(Formula);
  const IsTableAlone = IsBareMatrix(Table);
  if IsTableAlone then
    Result := WriteCells(Table, Tab, sLineBreak)
  else
    Result := Write(Formula).Trim;
end;

class function TUnicodeMathFormat.IsTable(const Source: string): Boolean;
begin
  const Formula = TMathParser.Parse(Source);
  const Table = Unwrapped(Formula);
  Result := IsBareMatrix(Table);
end;

class function TUnicodeMathFormat.Write(const Node: IMathNode): string;
begin
  case Node.Kind of
    TMathNodeKind.Row:
      Result := WriteRow(Node);
    TMathNodeKind.Symbol:
      Result := WriteSymbol(Node);
    TMathNodeKind.Text:
      Result := Node.Text;
    TMathNodeKind.Space:
      Result := WriteSpace(Node);
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
    TMathNodeKind.Styled, TMathNodeKind.Colored, TMathNodeKind.Linked:
      Result := Write(Node.Children[0]);
  else
    raise EMathSyntaxError.CreateFmt('Unhandled math node kind: %d', [Ord(Node.Kind)]);
  end;
end;

class function TUnicodeMathFormat.WriteRow(const Node: IMathNode): string;
begin
  Result := '';
  for var Index := 0 to Node.ChildCount - 1 do
  begin
    const Child = Node.Children[Index];
    const Written = Write(Child);

    const HasPrevious = (Index > 0);
    const IsSetApart = (HasPrevious and RunsOn(Node.Children[Index - 1], Child, Result, Written));
    if IsSetApart then
      Result := Result + Space;

    Result := Result + Written;
  end;
end;

// A script, a fraction and a root take the letters and digits after them as
// their own, so what follows one is set apart by a space, as Word writes
// x^2 y. An operator such as sin, lim or a sum is set apart the same way from
// what it applies to and from a letter before it.
class function TUnicodeMathFormat.RunsOn(const Previous, Next: IMathNode; const Before, After: string): Boolean;
begin
  const StartsWord = ((After <> '') and After[1].IsLetterOrDigit);
  const EndsWord = ((Before <> '') and Before[Length(Before)].IsLetterOrDigit);
  const TakesWhatFollows = (Previous.Kind in [TMathNodeKind.Script, TMathNodeKind.Fraction, TMathNodeKind.Radical]);
  const JoinsWords = (EndsWord and (TakesWhatFollows or IsOperator(Next)));

  Result := (StartsWord and (IsOperator(Previous) or JoinsWords));
end;

// An operator name such as sin or lim, or a large operator such as a sum,
// alone or with its limits.
class function TUnicodeMathFormat.IsOperator(const Node: IMathNode): Boolean;
begin
  const IsScript = (Node.Kind = TMathNodeKind.Script);
  if IsScript then
  begin
    Result := IsOperator(Node.Children[0]);
    Exit;
  end;

  const IsSymbol = (Node.Kind = TMathNodeKind.Symbol);
  Result := (IsSymbol and (Node.AtomClass = TMathAtomClass.Operator));
end;

// Word writes the minus sign as the hyphen a reader types.
class function TUnicodeMathFormat.WriteSymbol(const Node: IMathNode): string;
begin
  Result := Node.Text.Replace(Minus, Hyphen);
end;

// A space of any width is one space; a negative one draws two parts together
// and writes nothing.
class function TUnicodeMathFormat.WriteSpace(const Node: IMathNode): string;
begin
  const IsVisible = (Node.SpaceWidth > 0);
  if IsVisible then
    Result := Space
  else
    Result := '';
end;

// \atop and \choose stack their parts without a rule.
class function TUnicodeMathFormat.WriteFraction(const Node: IMathNode): string;
begin
  const Numerator = FractionPart(Node.Children[0]);
  const Denominator = FractionPart(Node.Children[1]);

  if Node.HasRule then
    Result := Numerator + Over + Denominator
  else
    Result := Numerator + Atop + Denominator;
end;

// A prime is a superscript in TeX and follows its base directly here.
class function TUnicodeMathFormat.WriteScript(const Node: IMathNode): string;
begin
  Result := Base(Node.Children[0]);

  const Upper = Node.Children[1];
  const Lower = Node.Children[2];

  const HasPrimes = IsPrimes(Upper);
  if HasPrimes then
    Result := Result + Write(Upper);

  const HasSubscript = not Lower.IsEmpty;
  if HasSubscript then
    Result := Result + Subscript + Argument(Lower);

  const HasSuperscript = (not Upper.IsEmpty and not HasPrimes);
  if HasSuperscript then
    Result := Result + Superscript + Argument(Upper);
end;

class function TUnicodeMathFormat.IsPrimes(const Node: IMathNode): Boolean;
begin
  const Marks = Write(Node);

  Result := (Marks <> '');
  for var Mark in Marks do
  begin
    const IsPrime = (Mark = Prime);
    if not IsPrime then
      Result := False;
  end;
end;

// A root with an index holds the index and the radicand as two cells, unless
// Unicode has a sign of its own for it.
class function TUnicodeMathFormat.WriteRadical(const Node: IMathNode): string;
begin
  const Radicand = Argument(Node.Children[0]);

  const HasIndex = ((Node.ChildCount > 1) and not Node.Children[1].IsEmpty);
  if not HasIndex then
  begin
    Result := SquareRoot + Radicand;
    Exit;
  end;

  const RootIndex = Write(Node.Children[1]);
  const Sign = RootSign(RootIndex);
  const HasSign = (Sign <> '');
  if HasSign then
    Result := Sign + Radicand
  else
    Result := SquareRoot + Grouped(RootIndex + CellEnd + Write(Node.Children[0]));
end;

class function TUnicodeMathFormat.RootSign(const RootIndex: string): string;
begin
  if RootIndex = '3' then
    Result := CubeRoot
  else if RootIndex = '4' then
    Result := FourthRoot
  else
    Result := '';
end;

class function TUnicodeMathFormat.WriteDelimited(const Node: IMathNode): string;
begin
  const Content = Write(Node.Children[0]);
  Result := Delimiter(Node.LeftDelimiter) + Content + Delimiter(Node.RightDelimiter);
end;

// An accent is the combining mark after its body; an overline is the overbar
// before it.
class function TUnicodeMathFormat.WriteAccent(const Node: IMathNode): string;
begin
  const IsOverline = (Node.Text = '');
  if IsOverline then
  begin
    Result := Overbar + Argument(Node.Children[0]);
    Exit;
  end;

  const Body = Base(Node.Children[0]);
  const Known = Pos(Node.Text, AccentGlyphs);
  const IsKnown = (Known > 0);
  if IsKnown then
    Result := Body + CombiningMarks[Known]
  else
    Result := Body + Node.Text;
end;

// A matrix is its cells apart by & and its rows by @, after the matrix mark; a
// cases or an align environment is an equation array.
class function TUnicodeMathFormat.WriteMatrix(const Node: IMathNode): string;
begin
  var Mark := MatrixMark;
  const IsEquationArray = (Node.Alignment <> TMathColumnAlignment.Centre);
  if IsEquationArray then
    Mark := EquationArrayMark;

  const Cells = WriteCells(Node, CellEnd, RowEnd);
  Result := Delimiter(Node.LeftDelimiter) + Mark + Grouped(Cells) + Delimiter(Node.RightDelimiter);
end;

class function TUnicodeMathFormat.WriteCells(const Node: IMathNode; const CellSeparator, RowSeparator: string): string;
begin
  var Rows: TArray<string> := [];
  for var RowIndex := 0 to Node.ChildCount - 1 do
  begin
    const Row = WriteRowCells(Node.Children[RowIndex], CellSeparator);
    Rows := Rows + [Row];
  end;

  Result := string.Join(RowSeparator, Rows);
end;

class function TUnicodeMathFormat.WriteRowCells(const Row: IMathNode; const CellSeparator: string): string;
begin
  var Cells: TArray<string> := [];
  for var CellIndex := 0 to Row.ChildCount - 1 do
  begin
    const Cell = Write(Row.Children[CellIndex]);
    Cells := Cells + [Cell.Trim];
  end;

  Result := string.Join(CellSeparator, Cells);
end;

// \left. draws no delimiter and writes none.
class function TUnicodeMathFormat.Delimiter(const Text: string): string;
begin
  const DrawsNone = (Text = NoDelimiter);
  if DrawsNone then
    Result := ''
  else
    Result := Text;
end;

// What a script or an accent sits on: in brackets unless it is one sign.
class function TUnicodeMathFormat.Base(const Node: IMathNode): string;
begin
  Result := Write(Node);

  const IsOneSign = IsSingle(Node);
  if not IsOneSign then
    Result := Grouped(Result);
end;

// A script or what a root covers: in brackets unless it is one word, as in
// e^(-x) against e^2x.
class function TUnicodeMathFormat.Argument(const Node: IMathNode): string;
begin
  Result := Write(Node);

  const IsOneWord = IsWord(Node);
  if not IsOneWord then
    Result := Grouped(Result);
end;

// The numerator or the denominator: a word, or a word with its scripts as in
// x^2/y^2, or else in brackets.
class function TUnicodeMathFormat.FractionPart(const Node: IMathNode): string;
begin
  Result := Write(Node);

  const IsScript = (Unwrapped(Node).Kind = TMathNodeKind.Script);
  const IsOnePart = (IsWord(Node) or IsScript);
  if not IsOnePart then
    Result := Grouped(Result);
end;

class function TUnicodeMathFormat.Grouped(const Content: string): string;
begin
  Result := GroupStart + Content + GroupEnd;
end;

// The node under the rows, styles, colours and links that hold it alone.
class function TUnicodeMathFormat.Unwrapped(const Node: IMathNode): IMathNode;
begin
  const IsRowOfOne = ((Node.Kind = TMathNodeKind.Row) and (Node.ChildCount = 1));
  const IsStyle = (Node.Kind in [TMathNodeKind.Styled, TMathNodeKind.Colored, TMathNodeKind.Linked]);
  if IsRowOfOne or IsStyle then
    Result := Unwrapped(Node.Children[0])
  else
    Result := Node;
end;

// One sign, one word of text, or a part that brings its own brackets or marks.
class function TUnicodeMathFormat.IsSingle(const Node: IMathNode): Boolean;
begin
  const Inner = Unwrapped(Node);
  case Inner.Kind of
    TMathNodeKind.Symbol, TMathNodeKind.Delimited, TMathNodeKind.Matrix, TMathNodeKind.Accent:
      Result := True;
    TMathNodeKind.Text:
      Result := not Inner.Text.Contains(Space);
    TMathNodeKind.Row:
      Result := (Inner.ChildCount = 0);
  else
    Result := False;
  end;
end;

// Letters and digits in a row, such as 2a or dx, which UnicodeMath reads as
// one operand.
class function TUnicodeMathFormat.IsWord(const Node: IMathNode): Boolean;
begin
  Result := IsSingle(Node);
  if Result then
    Exit;

  const Inner = Unwrapped(Node);
  const IsRow = (Inner.Kind = TMathNodeKind.Row);
  if not IsRow then
    Exit;

  Result := True;
  for var Index := 0 to Inner.ChildCount - 1 do
  begin
    const IsPartOfWord = IsLetterOrDigit(Inner.Children[Index]);
    if not IsPartOfWord then
      Result := False;
  end;
end;

class function TUnicodeMathFormat.IsLetterOrDigit(const Node: IMathNode): Boolean;
begin
  const Inner = Unwrapped(Node);
  const IsOrdinarySymbol = ((Inner.Kind = TMathNodeKind.Symbol) and (Inner.AtomClass = TMathAtomClass.Ordinary));
  Result := (IsOrdinarySymbol and (Inner.Text <> '') and Inner.Text[1].IsLetterOrDigit);
end;

// Equations under each other are a matrix to the parser as well: an aligned
// environment, a gathered one and the lines a \\ makes. They are no table and
// stay an equation: an aligned environment by its alignment, the others by
// their one column.
class function TUnicodeMathFormat.IsBareMatrix(const Node: IMathNode): Boolean;
begin
  const IsMatrix = (Node.Kind = TMathNodeKind.Matrix);
  const HasDelimiters = ((Node.LeftDelimiter <> '') or (Node.RightDelimiter <> ''));
  const IsBare = (IsMatrix and not HasDelimiters);
  if not IsBare then
  begin
    Result := False;
    Exit;
  end;

  const AlignsEquations = (Node.Alignment = TMathColumnAlignment.Alternate);
  const HasPreamble = (Node.ColumnSpec <> '');
  Result := (not AlignsEquations and (HasPreamble or HasSeveralColumns(Node)));
end;

class function TUnicodeMathFormat.HasSeveralColumns(const Matrix: IMathNode): Boolean;
begin
  Result := False;
  for var RowIndex := 0 to Matrix.ChildCount - 1 do
  begin
    const HasSeveralCells = (Matrix.Children[RowIndex].ChildCount > 1);
    if HasSeveralCells then
      Result := True;
  end;
end;

end.
