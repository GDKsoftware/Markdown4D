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
    class function Write(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteRow(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteSymbol(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteScript(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteRadical(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteDelimited(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function WriteMatrix(const Node: IMathNode; const Variant: TMathFontVariant): string; static;
    class function Fence(const Delimiter: string): string; static;
    class function WriteTable(const Node: IMathNode; const Rows: string): string; static;
    class function Element(const Name, Content: string; const Attributes: string = ''): string; static;
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
  const Body = Write(TMathParser.Parse(Source), TMathFontVariant.Italic);
  const Annotation = Element('annotation', Escaped(Source), 'encoding="' + TeXEncoding + '"');
  const Semantics = Element('semantics', Element('mrow', Body) + Annotation);

  var Attributes := 'xmlns="' + Namespace + '"';
  if IsDisplay then
    Attributes := Attributes + ' display="block"';

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
      Result := Element('mtext', Escaped(Node.Text));
    TMathNodeKind.Space:
      Result := '<mspace width="' + FormatFloat('0.###', Node.SpaceWidth, TFormatSettings.Invariant) + 'em"/>';
    TMathNodeKind.Fraction:
      begin
        var Attributes := '';
        if not Node.HasRule then
          Attributes := 'linethickness="0"';
        Result := Element('mfrac', Element('mrow', Write(Node.Children[0], Variant)) +
          Element('mrow', Write(Node.Children[1], Variant)), Attributes);
      end;
    TMathNodeKind.Script:
      Result := WriteScript(Node, Variant);
    TMathNodeKind.Radical:
      Result := WriteRadical(Node, Variant);
    TMathNodeKind.Delimited:
      Result := WriteDelimited(Node, Variant);
    TMathNodeKind.Accent:
      Result := Element('mover', Element('mrow', Write(Node.Children[0], Variant)) + Element('mo', Escaped(Node.Text)),
        'accent="true"');
    TMathNodeKind.Matrix:
      Result := WriteMatrix(Node, Variant);
    TMathNodeKind.Styled:
      Result := Write(Node.Children[0], Node.Variant);
    TMathNodeKind.Colored:
      Result := Element('mstyle', Write(Node.Children[0], Variant), 'mathcolor="' + ColorOf(Node.Color) + '"');
    TMathNodeKind.Linked:
      Result := Element('mrow', Write(Node.Children[0], Variant), 'href="' + Escaped(Node.Text) + '"');
  else
    raise EMathSyntaxError.CreateFmt('Unhandled math node kind: %d', [Ord(Node.Kind)]);
  end;
end;

class function TMathMLFormat.WriteRow(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  Result := '';
  for var Index := 0 to Node.ChildCount - 1 do
    Result := Result + Write(Node.Children[Index], Variant);
end;

// A number is <mn>, a letter or a word such as sin is <mi>, anything else an
// operator <mo>.
class function TMathMLFormat.WriteSymbol(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  const Text = Escaped(Node.Text);

  if IsNumber(Node.Text) then
  begin
    Result := Element('mn', Text);
    Exit;
  end;

  const IsIdentifier = (Node.Text <> '') and Node.Text[1].IsLetter and
    not (Node.AtomClass in [TMathAtomClass.Binary, TMathAtomClass.Relation]) and not Node.IsLarge;
  if not IsIdentifier then
  begin
    Result := Element('mo', Text);
    Exit;
  end;

  var Effective := Variant;
  if Node.Variant <> TMathFontVariant.Italic then
    Effective := Node.Variant;

  // A single letter is italic in MathML unless it says otherwise; a word
  // such as sin is upright.
  const IsSingleLetter = (Length(Node.Text) = 1) or ((Length(Node.Text) = 2) and Node.Text[1].IsHighSurrogate);
  var Attributes := '';
  if (Effective <> TMathFontVariant.Italic) and IsSingleLetter then
    Attributes := 'mathvariant="' + VariantName(Effective) + '"'
  else if (Effective <> TMathFontVariant.Italic) and (Effective <> TMathFontVariant.Upright) then
    Attributes := 'mathvariant="' + VariantName(Effective) + '"';

  Result := Element('mi', Text, Attributes);
end;

// An operator that takes limits sets them above and below.
class function TMathMLFormat.WriteScript(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  const Base = Write(Node.Children[0], Variant);
  const HasSuperscript = not Node.Children[1].IsEmpty;
  const HasSubscript = not Node.Children[2].IsEmpty;
  const Superscript = Element('mrow', Write(Node.Children[1], Variant));
  const Subscript = Element('mrow', Write(Node.Children[2], Variant));
  const TakesLimits = Node.Children[0].TakesLimits;

  if HasSuperscript and HasSubscript then
  begin
    if TakesLimits then
      Result := Element('munderover', Base + Subscript + Superscript)
    else
      Result := Element('msubsup', Base + Subscript + Superscript);
  end
  else if HasSuperscript then
  begin
    if TakesLimits then
      Result := Element('mover', Base + Superscript)
    else
      Result := Element('msup', Base + Superscript);
  end
  else if HasSubscript then
  begin
    if TakesLimits then
      Result := Element('munder', Base + Subscript)
    else
      Result := Element('msub', Base + Subscript);
  end
  else
    Result := Base;
end;

class function TMathMLFormat.WriteRadical(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  const Radicand = Element('mrow', Write(Node.Children[0], Variant));

  const HasIndex = (Node.ChildCount > 1) and not Node.Children[1].IsEmpty;
  if HasIndex then
    Result := Element('mroot', Radicand + Element('mrow', Write(Node.Children[1], Variant)))
  else
    Result := Element('msqrt', Radicand);
end;

class function TMathMLFormat.WriteDelimited(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  Result := Element('mrow', Fence(Node.LeftDelimiter) + Write(Node.Children[0], Variant) +
    Fence(Node.RightDelimiter));
end;

class function TMathMLFormat.WriteMatrix(const Node: IMathNode; const Variant: TMathFontVariant): string;
begin
  var Rows := '';
  for var RowIndex := 0 to Node.ChildCount - 1 do
  begin
    const Row = Node.Children[RowIndex];

    var Cells := '';
    for var CellIndex := 0 to Row.ChildCount - 1 do
      Cells := Cells + Element('mtd', Write(Row.Children[CellIndex], Variant));

    Rows := Rows + Element('mtr', Cells);
  end;

  Result := WriteTable(Node, Rows);
  if (Node.LeftDelimiter <> '') or (Node.RightDelimiter <> '') then
    Result := Element('mrow', Fence(Node.LeftDelimiter) + Result + Fence(Node.RightDelimiter));
end;

// The preamble of an array as MathML: how the columns align and the rules
// between columns and rows. Rules all around make a frame; rules on some
// sides only, a \hline above and below for instance, enclose the table on
// those sides.
class function TMathMLFormat.WriteTable(const Node: IMathNode; const Rows: string): string;
begin
  if Node.ColumnSpec = '' then
  begin
    Result := Element('mtable', Rows);
    Exit;
  end;

  var Aligns: TArray<string> := [];
  var ColumnLines: TArray<string> := [];
  var HasRuleLeft := False;
  var PendingRule := False;
  for var Character in Node.ColumnSpec do
  begin
    if Character = '|' then
    begin
      if Length(Aligns) = 0 then
        HasRuleLeft := True
      else
        PendingRule := True;
      Continue;
    end;

    if Length(Aligns) > 0 then
    begin
      if PendingRule then
        ColumnLines := ColumnLines + ['solid']
      else
        ColumnLines := ColumnLines + ['none'];
    end;
    PendingRule := False;

    case Character of
      'l': Aligns := Aligns + ['left'];
      'r': Aligns := Aligns + ['right'];
    else
      Aligns := Aligns + ['center'];
    end;
  end;
  const HasRuleRight = PendingRule;

  var RowLines: TArray<string> := [];
  for var RowIndex := 1 to Node.ChildCount - 1 do
  begin
    if Node.Children[RowIndex].RulesAbove > 0 then
      RowLines := RowLines + ['solid']
    else
      RowLines := RowLines + ['none'];
  end;

  var Attributes := 'columnalign="' + string.Join(' ', Aligns) + '"';
  if Length(ColumnLines) > 0 then
    Attributes := Attributes + ' columnlines="' + string.Join(' ', ColumnLines) + '"';
  if Length(RowLines) > 0 then
    Attributes := Attributes + ' rowlines="' + string.Join(' ', RowLines) + '"';

  var Sides: TArray<string> := [];
  if Node.Children[0].RulesAbove > 0 then
    Sides := Sides + ['top'];
  if Node.RulesBelow > 0 then
    Sides := Sides + ['bottom'];
  if HasRuleLeft then
    Sides := Sides + ['left'];
  if HasRuleRight then
    Sides := Sides + ['right'];

  const IsFramed = (Length(Sides) = 4);
  if IsFramed then
    Attributes := Attributes + ' frame="solid"';

  Result := Element('mtable', Rows, Attributes);
  if (Length(Sides) > 0) and not IsFramed then
    Result := Element('menclose', Result, 'notation="' + string.Join(' ', Sides) + '"');
end;

// \left. draws no delimiter and writes none.
class function TMathMLFormat.Fence(const Delimiter: string): string;
begin
  if (Delimiter = '') or (Delimiter = '.') then
    Result := ''
  else
    Result := Element('mo', Escaped(Delimiter), 'fence="true"');
end;

class function TMathMLFormat.Element(const Name, Content, Attributes: string): string;
begin
  var Opening := Name;
  if Attributes <> '' then
    Opening := Opening + ' ' + Attributes;

  Result := '<' + Opening + '>' + Content + '</' + Name + '>';
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
  Result := '#' + IntToHex(Color and $FFFFFF, 6);
end;

class function TMathMLFormat.IsNumber(const Text: string): Boolean;
begin
  Result := (Text <> '');
  for var Character in Text do
  begin
    if not (CharInSet(Character, ['0'..'9']) or (Character = '.')) then
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
