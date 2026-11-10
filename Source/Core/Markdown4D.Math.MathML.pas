unit Markdown4D.Math.MathML;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Math.Syntax;

type
  // A formula as presentation MathML, which Word, LibreOffice and browsers
  // take as an editable equation when it is pasted. The TeX it was written
  // in rides along as an annotation, as KaTeX and MathJax do it.
  TMathMLFormat = record
  private
    const
      Namespace = 'http://www.w3.org/1998/Math/MathML';
      TeXEncoding = 'application/x-tex';
      Space = ' ';
      NoBreakSpace = #$00A0;
      Macron = #$00AF;
      FunctionApplication = #$2061;
      PairSpacing = '0em';
      BetweenPairsSpacing = '2em';
      ColumnRule = '|';
      SolidLine = 'solid';
      NoLine = 'none';
      // The element for a base with both scripts, with only the upper one and
      // with only the lower one; limits go above and below instead.
      BothScripts: array[Boolean] of string = ('msubsup', 'munderover');
      UpperScript: array[Boolean] of string = ('msup', 'mover');
      LowerScript: array[Boolean] of string = ('msub', 'munder');
    class function Write(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteRow(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteChild(const Node: IMathNode; const Index: Integer;
                              const Variant: TMathFontVariant): string; static;
    class function IsOperatorName(const Node: IMathNode): Boolean; static;
    class function WriteSpace(const Node: IMathNode): string; static;
    class function WriteFraction(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteText(const Node: IMathNode): string; static;
    class function WriteAccent(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteSymbol(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function IdentifierAttributes(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteScript(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteRadical(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteDelimited(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteColored(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteLinked(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteMatrix(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteMatrixRow(const Row: IMathNode; const Variant: TMathFontVariant): string; static;
    class function Fenced(const Node: IMathNode; const Content: string): string; static;
    class function Fence(const Delimiter: string): string; static;
    class function WriteTable(const Node: IMathNode; const Rows: string): string; static;
    class function PreambleAttributes(const ColumnSpec: string; out HasRuleLeft, HasRuleRight: Boolean): string;
                                      static;
    class function RowLineAttributes(const Node: IMathNode): string; static;
    class function RuledSides(const Node: IMathNode; const HasRuleLeft, HasRuleRight: Boolean): TArray<string>;
                              static;
    class function AlignmentAttributes(const Node: IMathNode): string; static;
    class function AlternateAttributes(const ColumnCount: Integer): string; static;
    class function ColumnCount(const Node: IMathNode): Integer; static;
    class function ListAttribute(const Name: string; const Values: TArray<string>): string; static;
    class function Element(const Name, Content: string; const Attributes: string = ''): string; static;
    class function Attribute(const Name, Value: string): string; static;
    class function VariantName(const Variant: TMathFontVariant): string; static;
    class function ColorOf(const Color: Cardinal): string; static;
    class function IsNumber(const Text: string): Boolean; static;
    class function Escaped(const Text: string): string; static;

  public
    // A whole <math> element; IsDisplay sets it as a display formula.
    class function FromSource(const Source: string; const IsDisplay: Boolean): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character;

class function TMathMLFormat.FromSource(const Source: string; const IsDisplay: Boolean): string;
begin
  const Formula = TMathParser.Parse(Source);
  const Body = Write(Formula, TMathFontVariant.Italic);
  const Row = Element('mrow', Body);
  const Annotation = Element('annotation', Escaped(Source), Attribute('encoding', TeXEncoding));
  const Semantics = Element('semantics', Row + Annotation);

  var Attributes := Attribute('xmlns', Namespace);
  if IsDisplay then
    Attributes := Attributes + Attribute('display', 'block');

  Result := Element('math', Semantics, Attributes);
end;

class function TMathMLFormat.Write(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  case Node.Kind of
    TMathNodeKind.Row:
      Result := WriteRow(Node, Variant);
    TMathNodeKind.Symbol:
      Result := WriteSymbol(Node, Variant);
    TMathNodeKind.Text:
      Result := WriteText(Node);
    TMathNodeKind.Space:
      Result := WriteSpace(Node);
    TMathNodeKind.Fraction:
      Result := WriteFraction(Node, Variant);
    TMathNodeKind.Script:
      Result := WriteScript(Node, Variant);
    TMathNodeKind.Radical:
      Result := WriteRadical(Node, Variant);
    TMathNodeKind.Delimited:
      Result := WriteDelimited(Node, Variant);
    TMathNodeKind.Accent:
      Result := WriteAccent(Node, Variant);
    TMathNodeKind.Matrix:
      Result := WriteMatrix(Node, Variant);
    TMathNodeKind.Styled:
      Result := Write(Node.Children[0], Node.Variant);
    TMathNodeKind.Colored:
      Result := WriteColored(Node, Variant);
    TMathNodeKind.Linked:
      Result := WriteLinked(Node, Variant);
  else
    raise EMathSyntaxError.CreateFmt('Unhandled math node kind: %d', [Ord(Node.Kind)]);
  end;
end;

// An operator name such as sin is followed by the invisible function
// application, which marks it as a function: Word then sets the space after
// it that TeX sets.
class function TMathMLFormat.WriteRow(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  Result := '';
  for var Index := 0 to Node.ChildCount - 1 do
  begin
    const Child = Node.Children[Index];
    Result := Result + Write(Child, Variant);

    const IsFollowed = (Index < Node.ChildCount - 1);
    const IsFunction = (IsFollowed and IsOperatorName(Child));
    if IsFunction then
      Result := Result + Element('mo', FunctionApplication);
  end;
end;

// A child of a fraction, a script or a radical as one row, so that it stays
// one argument of the element around it however many nodes it holds.
class function TMathMLFormat.WriteChild(const Node: IMathNode; const Index: Integer;
                                        const Variant: TMathFontVariant): string;
begin
  const Content = Write(Node.Children[Index], Variant);
  Result := Element('mrow', Content);
end;

// An operator name such as sin, sgn or lim, alone or with its limits; not a
// large operator such as a sum, which is a symbol.
class function TMathMLFormat.IsOperatorName(const Node: IMathNode): Boolean;
begin
  const IsScript = (Node.Kind = TMathNodeKind.Script);
  if IsScript then
  begin
    Result := IsOperatorName(Node.Children[0]);
    Exit;
  end;

  const IsSymbol = (Node.Kind = TMathNodeKind.Symbol);
  const IsOperator = (Node.AtomClass = TMathAtomClass.Operator);
  const IsWord = ((Node.Text <> '') and Node.Text[1].IsLetter);
  Result := (IsSymbol and IsOperator and IsWord and not Node.IsLarge);
end;

class function TMathMLFormat.WriteSpace(const Node: IMathNode): string;
begin
  const Width = FormatFloat('0.###', Node.SpaceWidth, TFormatSettings.Invariant);
  Result := Format('<mspace%s/>', [Attribute('width', Format('%sem', [Width]))]);
end;

// \atop and \choose set a fraction without its rule.
class function TMathMLFormat.WriteFraction(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  const Numerator = WriteChild(Node, 0, Variant);
  const Denominator = WriteChild(Node, 1, Variant);

  var Attributes := '';
  if not Node.HasRule then
    Attributes := Attribute('linethickness', '0');

  Result := Element('mfrac', Numerator + Denominator, Attributes);
end;

// Word drops the spaces at the ends of an mtext, as in \text{ if }, so the
// spaces go in as no-break spaces.
class function TMathMLFormat.WriteText(const Node: IMathNode): string;
begin
  const Words = Escaped(Node.Text);
  Result := Element('mtext', Words.Replace(Space, NoBreakSpace));
end;

// An overline has no accent glyph of its own; Word draws it as a bar from a
// macron over the body.
class function TMathMLFormat.WriteAccent(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  var Glyph := Node.Text;
  const IsOverline = (Glyph = '');
  if IsOverline then
    Glyph := Macron;

  const Body = WriteChild(Node, 0, Variant);
  const Accent = Element('mo', Escaped(Glyph));
  Result := Element('mover', Body + Accent, Attribute('accent', 'true'));
end;

// A number is <mn>, a letter or a word such as sin is <mi>, anything else an
// operator <mo>.
class function TMathMLFormat.WriteSymbol(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  const Text = Escaped(Node.Text);

  const IsNumeral = IsNumber(Node.Text);
  if IsNumeral then
  begin
    Result := Element('mn', Text);
    Exit;
  end;

  const IsWord = ((Node.Text <> '') and Node.Text[1].IsLetter);
  const IsBinaryOrRelation = (Node.AtomClass in [TMathAtomClass.Binary, TMathAtomClass.Relation]);
  const IsIdentifier = (IsWord and not IsBinaryOrRelation and not Node.IsLarge);
  if IsIdentifier then
    Result := Element('mi', Text, IdentifierAttributes(Node, Variant))
  else
    Result := Element('mo', Text);
end;

// A single letter is italic in MathML unless it says otherwise, a word such as
// sin upright; either gets a mathvariant where its variant differs.
class function TMathMLFormat.IdentifierAttributes(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  Result := '';

  var Effective := Variant;
  const HasOwnVariant = (Node.Variant <> TMathFontVariant.Italic);
  if HasOwnVariant then
    Effective := Node.Variant;

  const IsLetter = (Length(Node.Text) = 1);
  const IsSurrogateLetter = ((Length(Node.Text) = 2) and Node.Text[1].IsHighSurrogate);
  const IsSingleLetter = (IsLetter or IsSurrogateLetter);
  const IsItalic = (Effective = TMathFontVariant.Italic);
  const IsUpright = (Effective = TMathFontVariant.Upright);
  const NeedsVariant = (not IsItalic and (IsSingleLetter or not IsUpright));
  if NeedsVariant then
    Result := Attribute('mathvariant', VariantName(Effective));
end;

// An operator that takes limits sets them above and below.
class function TMathMLFormat.WriteScript(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  const Base = Write(Node.Children[0], Variant);
  const Superscript = WriteChild(Node, 1, Variant);
  const Subscript = WriteChild(Node, 2, Variant);
  const HasSuperscript = not Node.Children[1].IsEmpty;
  const HasSubscript = not Node.Children[2].IsEmpty;
  const HasBoth = (HasSuperscript and HasSubscript);
  const TakesLimits = Node.Children[0].TakesLimits;

  if HasBoth then
    Result := Element(BothScripts[TakesLimits], Base + Subscript + Superscript)
  else if HasSuperscript then
    Result := Element(UpperScript[TakesLimits], Base + Superscript)
  else if HasSubscript then
    Result := Element(LowerScript[TakesLimits], Base + Subscript)
  else
    Result := Base;
end;

class function TMathMLFormat.WriteRadical(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  const Radicand = WriteChild(Node, 0, Variant);

  const HasIndex = ((Node.ChildCount > 1) and not Node.Children[1].IsEmpty);
  if HasIndex then
  begin
    const RootIndex = WriteChild(Node, 1, Variant);
    Result := Element('mroot', Radicand + RootIndex);
  end
  else
  begin
    Result := Element('msqrt', Radicand);
  end;
end;

class function TMathMLFormat.WriteDelimited(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  const Body = Write(Node.Children[0], Variant);
  Result := Element('mrow', Fenced(Node, Body));
end;

class function TMathMLFormat.WriteColored(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  const Body = Write(Node.Children[0], Variant);
  Result := Element('mstyle', Body, Attribute('mathcolor', ColorOf(Node.Color)));
end;

class function TMathMLFormat.WriteLinked(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  const Body = Write(Node.Children[0], Variant);
  Result := Element('mrow', Body, Attribute('href', Escaped(Node.Text)));
end;

class function TMathMLFormat.WriteMatrix(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  var Rows := '';
  for var RowIndex := 0 to Node.ChildCount - 1 do
  begin
    Rows := Rows + WriteMatrixRow(Node.Children[RowIndex], Variant);
  end;

  Result := WriteTable(Node, Rows);
  const IsFenced = ((Node.LeftDelimiter <> '') or (Node.RightDelimiter <> ''));
  if IsFenced then
    Result := Element('mrow', Fenced(Node, Result));
end;

class function TMathMLFormat.WriteMatrixRow(const Row: IMathNode; const Variant: TMathFontVariant): string;
begin
  var Cells := '';
  for var CellIndex := 0 to Row.ChildCount - 1 do
  begin
    const Cell = Write(Row.Children[CellIndex], Variant);
    Cells := Cells + Element('mtd', Cell);
  end;

  Result := Element('mtr', Cells);
end;

class function TMathMLFormat.Fenced(const Node: IMathNode; const Content: string): string;
begin
  Result := Fence(Node.LeftDelimiter) + Content + Fence(Node.RightDelimiter);
end;

// The preamble of an array as MathML: how the columns align and the rules
// between columns and rows. Rules all around make a frame; rules on some
// sides only, a \hline above and below for instance, enclose the table on
// those sides.
class function TMathMLFormat.WriteTable(const Node: IMathNode; const Rows: string): string;
begin
  const HasPreamble = (Node.ColumnSpec <> '');
  if not HasPreamble then
  begin
    Result := Element('mtable', Rows, AlignmentAttributes(Node));
    Exit;
  end;

  var HasRuleLeft, HasRuleRight: Boolean;
  var Attributes := PreambleAttributes(Node.ColumnSpec, HasRuleLeft, HasRuleRight);
  Attributes := Attributes + RowLineAttributes(Node);

  const Sides = RuledSides(Node, HasRuleLeft, HasRuleRight);
  const IsFramed = (Length(Sides) = 4);
  if IsFramed then
    Attributes := Attributes + Attribute('frame', SolidLine);

  Result := Element('mtable', Rows, Attributes);

  const IsEnclosed = ((Length(Sides) > 0) and not IsFramed);
  if IsEnclosed then
    Result := Element('menclose', Result, Attribute('notation', string.Join(Space, Sides)));
end;

// A preamble such as |l|c r| as the alignment of each column and the rules
// between them; the rules at its ends come back on their own.
class function TMathMLFormat.PreambleAttributes(const ColumnSpec: string;
                                                out HasRuleLeft, HasRuleRight: Boolean): string;
begin
  HasRuleLeft := False;

  var Aligns: TArray<string> := [];
  var ColumnLines: TArray<string> := [];
  var PendingRule := False;
  for var Character in ColumnSpec do
  begin
    const HasColumnBefore = (Length(Aligns) > 0);
    const IsRule = (Character = ColumnRule);
    if IsRule then
    begin
      if HasColumnBefore then
        PendingRule := True
      else
        HasRuleLeft := True;
      Continue;
    end;

    if HasColumnBefore then
    begin
      if PendingRule then
        ColumnLines := ColumnLines + [SolidLine]
      else
        ColumnLines := ColumnLines + [NoLine];
    end;
    PendingRule := False;

    case Character of
      'l': Aligns := Aligns + ['left'];
      'r': Aligns := Aligns + ['right'];
    else
      Aligns := Aligns + ['center'];
    end;
  end;
  HasRuleRight := PendingRule;

  Result := ListAttribute('columnalign', Aligns) + ListAttribute('columnlines', ColumnLines);
end;

// A \hline between two rows rules the line between them.
class function TMathMLFormat.RowLineAttributes(const Node: IMathNode): string;
begin
  var RowLines: TArray<string> := [];
  for var RowIndex := 1 to Node.ChildCount - 1 do
  begin
    const IsRuledAbove = (Node.Children[RowIndex].RulesAbove > 0);
    if IsRuledAbove then
      RowLines := RowLines + [SolidLine]
    else
      RowLines := RowLines + [NoLine];
  end;

  Result := ListAttribute('rowlines', RowLines);
end;

class function TMathMLFormat.RuledSides(const Node: IMathNode; const HasRuleLeft, HasRuleRight: Boolean):
  TArray<string>;
begin
  Result := [];

  const IsRuledAtTop = (Node.Children[0].RulesAbove > 0);
  const IsRuledAtBottom = (Node.RulesBelow > 0);
  if IsRuledAtTop then
    Result := Result + ['top'];
  if IsRuledAtBottom then
    Result := Result + ['bottom'];
  if HasRuleLeft then
    Result := Result + ['left'];
  if HasRuleRight then
    Result := Result + ['right'];
end;

// How the cells of an environment without a preamble sit in their columns:
// centred in a matrix, at the left in a cases environment.
class function TMathMLFormat.AlignmentAttributes(const Node: IMathNode): string;
begin
  case Node.Alignment of
    TMathColumnAlignment.Centre    : Result := '';
    TMathColumnAlignment.Left      : Result := Attribute('columnalign', 'left');
    TMathColumnAlignment.Alternate : Result := AlternateAttributes(ColumnCount(Node));
  else
    raise EMathSyntaxError.CreateFmt('Unhandled column alignment: %d', [Ord(Node.Alignment)]);
  end;
end;

// An align environment sets its columns in pairs, right and left with no
// room in between, so the equals signs line up, and the pairs apart.
class function TMathMLFormat.AlternateAttributes(const ColumnCount: Integer): string;
begin
  var Aligns: TArray<string> := [];
  var Spacings: TArray<string> := [];
  for var Column := 0 to ColumnCount - 1 do
  begin
    const IsRightOfPair = Odd(Column);
    const IsFirstPair = (Column = 0);
    if IsRightOfPair then
    begin
      Aligns := Aligns + ['left'];
      Spacings := Spacings + [PairSpacing];
    end
    else
    begin
      Aligns := Aligns + ['right'];
      if not IsFirstPair then
        Spacings := Spacings + [BetweenPairsSpacing];
    end;
  end;

  Result := ListAttribute('columnalign', Aligns) + ListAttribute('columnspacing', Spacings);
end;

class function TMathMLFormat.ColumnCount(const Node: IMathNode): Integer;
begin
  Result := 0;
  for var RowIndex := 0 to Node.ChildCount - 1 do
  begin
    const Row = Node.Children[RowIndex];
    const IsWider = (Row.ChildCount > Result);
    if IsWider then
      Result := Row.ChildCount;
  end;
end;

// An attribute with a value per column or row, with the space before it; none
// when there are no values.
class function TMathMLFormat.ListAttribute(const Name: string; const Values: TArray<string>): string;
begin
  Result := '';

  const HasValues = (Length(Values) > 0);
  if HasValues then
    Result := Attribute(Name, string.Join(Space, Values));
end;

// \left. draws no delimiter and writes none.
class function TMathMLFormat.Fence(const Delimiter: string): string;
begin
  const DrawsNone = ((Delimiter = '') or (Delimiter = '.'));
  if DrawsNone then
    Result := ''
  else
    Result := Element('mo', Escaped(Delimiter), Attribute('fence', 'true'));
end;

// Attributes comes from Attribute and ListAttribute, each with its leading space.
class function TMathMLFormat.Element(const Name, Content, Attributes: string): string;
begin
  Result := Format('<%s%s>%s</%s>', [Name, Attributes, Content, Name]);
end;

class function TMathMLFormat.Attribute(const Name, Value: string): string;
begin
  Result := Format(' %s="%s"', [Name, Value]);
end;

class function TMathMLFormat.VariantName(const Variant: TMathFontVariant): string;
begin
  case Variant of
    TMathFontVariant.Italic       : Result := 'italic';
    TMathFontVariant.Upright      : Result := 'normal';
    TMathFontVariant.Bold         : Result := 'bold';
    TMathFontVariant.BoldItalic   : Result := 'bold-italic';
    TMathFontVariant.DoubleStruck : Result := 'double-struck';
    TMathFontVariant.Script       : Result := 'script';
    TMathFontVariant.Fraktur      : Result := 'fraktur';
    TMathFontVariant.SansSerif    : Result := 'sans-serif';
    TMathFontVariant.Monospace    : Result := 'monospace';
  else
    raise EMathSyntaxError.CreateFmt('Unhandled math font variant: %d', [Ord(Variant)]);
  end;
end;

class function TMathMLFormat.ColorOf(const Color: Cardinal): string;
begin
  Result := Format('#%.6X', [Color and $FFFFFF]);
end;

class function TMathMLFormat.IsNumber(const Text: string): Boolean;
begin
  Result := (Text <> '');
  for var Character in Text do
  begin
    const IsDigit = (CharInSet(Character, ['0'..'9']) or (Character = '.'));
    if not IsDigit then
      Result := False;
  end;
end;

class function TMathMLFormat.Escaped(const Text: string): string;
begin
  Result := Text.Replace('&', '&amp;');
  Result := Result.Replace('<', '&lt;');
  Result := Result.Replace('>', '&gt;');
  Result := Result.Replace('"', '&quot;');
end;

end.
