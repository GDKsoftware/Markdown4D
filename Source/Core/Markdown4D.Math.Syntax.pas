unit Markdown4D.Math.Syntax;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Defines;

type
  // The formula tree the layouter works from. It follows TeX's math list:
  // a Row is a sequence of atoms, every atom carries the class that decides
  // the spacing around it, and the structural nodes (fraction, script,
  // radical, delimited group, accent, matrix) hold their parts as children.
  TMathNodeKind = (Row, Symbol, Text, Fraction, Script, Radical, Delimited, Accent, Space, Matrix, Styled);

  TMathAtomClass = (Ordinary, Operator, Binary, Relation, Opening, Closing, Punctuation, Inner);

  TMathFontVariant = (Italic, Upright, Bold, BoldItalic, DoubleStruck, Script, Fraktur, SansSerif, Monospace);

  // How matrix cells sit in their column: centred in a matrix, at the left in
  // a cases environment, and alternating right and left in an align
  // environment so the equals signs line up.
  TMathColumnAlignment = (Centre, Left, Alternate);

  EMathSyntaxError = class(EMarkdownError);

  IMathNode = interface
    ['{2F7A9E15-6B3C-4D80-A1F4-8E5C7B2D9A36}']
    function GetKind: TMathNodeKind;
    function GetText: string;
    function GetAtomClass: TMathAtomClass;
    function GetVariant: TMathFontVariant;
    function GetChildCount: Integer;
    function GetChild(const Index: Integer): IMathNode;
    function GetLeftDelimiter: string;
    function GetRightDelimiter: string;
    function GetSpaceWidth: Single;
    function GetTakesLimits: Boolean;
    function GetIsLarge: Boolean;
    function GetIsError: Boolean;
    function GetHasRule: Boolean;
    function GetAlignment: TMathColumnAlignment;
    function IsEmpty: Boolean;
    property Kind: TMathNodeKind read GetKind;
    // Symbol: the glyphs to draw; Text: the words; Accent: the accent glyph,
    // empty for an overline; otherwise unused.
    property Text: string read GetText;
    property AtomClass: TMathAtomClass read GetAtomClass;
    // Symbol: how its letters are set; Styled: the variant applied to the
    // children.
    property Variant: TMathFontVariant read GetVariant;
    property ChildCount: Integer read GetChildCount;
    // Fraction: numerator, denominator. Script: base, superscript, subscript
    // (an empty row where absent). Radical: radicand, index. Delimited,
    // Accent, Styled: the body. Matrix: the rows, each holding its cells.
    property Children[const Index: Integer]: IMathNode read GetChild;
    property LeftDelimiter: string read GetLeftDelimiter;
    property RightDelimiter: string read GetRightDelimiter;
    // Space: the width in em.
    property SpaceWidth: Single read GetSpaceWidth;
    // Symbol: an operator that puts its limits above and below in display
    // style, like a sum or a limit.
    property TakesLimits: Boolean read GetTakesLimits;
    // Symbol: an operator drawn larger in display style, like a sum or an integral.
    property IsLarge: Boolean read GetIsLarge;
    // Symbol: an unknown command, drawn as its name so the author sees it.
    property IsError: Boolean read GetIsError;
    // Fraction: False for a binomial, which stacks without a bar.
    property HasRule: Boolean read GetHasRule;
    // Matrix: how the cells sit in their columns.
    property Alignment: TMathColumnAlignment read GetAlignment;
  end;

  TMathParser = class
  public
    // Never raises for ordinary input: an unclosed group is closed at the
    // end, a stray closing brace is dropped, an unknown command becomes an
    // error symbol. That keeps a formula stable while it streams in.
    class function Parse(const Source: string): IMathNode;
  end;

implementation

uses
  System.Character;

type
  TMathNode = class(TInterfacedObject, IMathNode)
  private
    FKind: TMathNodeKind;
    FText: string;
    FAtomClass: TMathAtomClass;
    FVariant: TMathFontVariant;
    FChildren: TList<IMathNode>;
    FLeftDelimiter: string;
    FRightDelimiter: string;
    FSpaceWidth: Single;
    FTakesLimits: Boolean;
    FIsLarge: Boolean;
    FIsError: Boolean;
    FHasRule: Boolean;
    FAlignment: TMathColumnAlignment;

  public
    constructor Create(const Kind: TMathNodeKind);
    destructor Destroy; override;
    function GetKind: TMathNodeKind;
    function GetText: string;
    function GetAtomClass: TMathAtomClass;
    function GetVariant: TMathFontVariant;
    function GetChildCount: Integer;
    function GetChild(const Index: Integer): IMathNode;
    function GetLeftDelimiter: string;
    function GetRightDelimiter: string;
    function GetSpaceWidth: Single;
    function GetTakesLimits: Boolean;
    function GetIsLarge: Boolean;
    function GetIsError: Boolean;
    function GetHasRule: Boolean;
    function GetAlignment: TMathColumnAlignment;
    function IsEmpty: Boolean;
    procedure AddChild(const Child: IMathNode);
    procedure SetChild(const Index: Integer; const Child: IMathNode);
    property Text: string read FText write FText;
    property AtomClass: TMathAtomClass read FAtomClass write FAtomClass;
    property Variant: TMathFontVariant read FVariant write FVariant;
    property LeftDelimiter: string read FLeftDelimiter write FLeftDelimiter;
    property RightDelimiter: string read FRightDelimiter write FRightDelimiter;
    property SpaceWidth: Single read FSpaceWidth write FSpaceWidth;
    property TakesLimits: Boolean read FTakesLimits write FTakesLimits;
    property IsLarge: Boolean read FIsLarge write FIsLarge;
    property IsError: Boolean read FIsError write FIsError;
    property HasRule: Boolean read FHasRule write FHasRule;
    property Alignment: TMathColumnAlignment read FAlignment write FAlignment;
  end;

  TMathSymbolInfo = record
    Text: string;
    AtomClass: TMathAtomClass;
    Variant: TMathFontVariant;
    TakesLimits: Boolean;
    IsLarge: Boolean;
  end;

  TMathSymbolEntry = record
    Name: string;
    Text: string;
    AtomClass: TMathAtomClass;
    Variant: TMathFontVariant;
    TakesLimits: Boolean;
    IsLarge: Boolean;
  end;

  TMathSymbolTable = class
  private
    class var
      FEntries: TDictionary<string, TMathSymbolInfo>;
    class procedure AddEntries(const Entries: array of TMathSymbolEntry);
    class procedure AddGreek;
    class procedure AddOperators;
    class procedure AddRelations;
    class procedure AddArrows;
    class procedure AddMiscellaneous;
    class procedure AddFunctions;
    class procedure AddDelimiters;
    class function Entry(const Name, Text: string; const AtomClass: TMathAtomClass;
                         const Variant: TMathFontVariant = TMathFontVariant.Upright;
                         const TakesLimits: Boolean = False; const IsLarge: Boolean = False): TMathSymbolEntry;

  public
    class constructor Create;
    class destructor Destroy;
    class function TryFind(const Name: string; out Info: TMathSymbolInfo): Boolean;
  end;

  TMathTokenKind = (EndOfInput, Command, Character, OpenBrace, CloseBrace, Superscript, Subscript, Ampersand, Prime);

  TMathToken = record
    Kind: TMathTokenKind;
    Text: string;
  end;

  TMathScanner = class
  private
    FSource: string;
    FPosition: Integer;
    FPeeked: Boolean;
    FPeekedToken: TMathToken;
    FPeekedPosition: Integer;
    procedure SkipWhitespace;
    function ReadToken: TMathToken;
    function ReadCommandName: string;
    class function IsCommandLetter(const Value: Char): Boolean; static;

  public
    constructor Create(const Source: string);
    function Peek: TMathToken;
    function Next: TMathToken;
    // The raw text of a braced group, braces balanced, spaces kept. Used for
    // \text and friends, where the content is words rather than math.
    function ReadRawGroup: string;
    function AtEnd: Boolean;
  end;

  TMathTreeParser = class
  private
    const
      BeginCommand = 'begin';
      EndCommand = 'end';
      LeftCommand = 'left';
      RightCommand = 'right';
      LineBreakCommand = '\';
      LimitsCommand = 'limits';
      NoLimitsCommand = 'nolimits';
      PrimeGlyph = #$2032;
      MinusGlyph = #$2212;
      AsteriskGlyph = #$2217;
      ThinSpaceEm = 3 / 18;
      MediumSpaceEm = 4 / 18;
      ThickSpaceEm = 5 / 18;
      WordSpaceEm = 0.333;
      QuadEm = 1.0;
    var
      FScanner: TMathScanner;
    function ParseLines: IMathNode;
    procedure ParseSequenceInto(const Row: TMathNode);
    function ParseSequence: TMathNode;
    function ParseSequenceUntilBracket: TMathNode;
    class function IsTerminator(const Token: TMathToken): Boolean; static;
    class function IsLineBreak(const Token: TMathToken): Boolean; static;
    procedure ConsumeStrayTerminator(const Token: TMathToken; const Line: TMathNode);
    function ParseAtomWithScripts: TMathNode;
    function ParseAtom: TMathNode;
    function ParseArgument: TMathNode;
    function ParseCharacter(const Value: Char): TMathNode;
    function ParseDigits(const First: Char): TMathNode;
    function ParseCommand(const Name: string): TMathNode;
    function TryParseFractionCommand(const Name: string; out Node: TMathNode): Boolean;
    function TryParseRadicalCommand(const Name: string; out Node: TMathNode): Boolean;
    function TryParseStyleCommand(const Name: string; out Node: TMathNode): Boolean;
    function TryParseAccentCommand(const Name: string; out Node: TMathNode): Boolean;
    function TryParseSpacingCommand(const Name: string; out Node: TMathNode): Boolean;
    function TryParseEnvironmentCommand(const Name: string; out Node: TMathNode): Boolean;
    function ParseFraction(const HasRule: Boolean): TMathNode;
    function ParseBinomial: TMathNode;
    function ParseRadical: TMathNode;
    function ParseDelimited: TMathNode;
    function ParseDelimiter: string;
    function ParseTextCommand(const Variant: TMathFontVariant): TMathNode;
    function ParseStyled(const Variant: TMathFontVariant): TMathNode;
    function ParseOperatorName(const TakesLimits: Boolean): TMathNode;
    function ParseAccent(const Glyph: string): TMathNode;
    function ParseEnvironment: TMathNode;
    function ParseMatrix: TMathNode;
    function ReadEnvironmentName: string;
    procedure ApplyLimitsCommands(const Atom: TMathNode);
    class function SpaceNode(const WidthEm: Single): TMathNode; static;
    class function SymbolNode(const Text: string; const AtomClass: TMathAtomClass;
                              const Variant: TMathFontVariant): TMathNode; static;
    class function ErrorNode(const Name: string): TMathNode; static;
    class function EmptyRow: TMathNode; static;
    class function TryMatrixDelimiters(const Name: string; out Left, Right: string;
                                       out Alignment: TMathColumnAlignment): Boolean; static;

  public
    constructor Create(const Source: string);
    destructor Destroy; override;
    function Parse: IMathNode;
  end;

const
  OpenBraceChar = '{';
  CloseBraceChar = '}';
  CaretChar = '^';
  UnderscoreChar = '_';
  AmpersandChar = '&';
  PrimeChar = '''';
  TildeChar = '~';
  EmptyDelimiter = '.';

constructor TMathNode.Create(const Kind: TMathNodeKind);
begin
  inherited Create;

  FKind := Kind;
  FChildren := TList<IMathNode>.Create;
  FHasRule := True;
end;

destructor TMathNode.Destroy;
begin
  FChildren.Free;

  inherited Destroy;
end;

function TMathNode.GetKind: TMathNodeKind;
begin
  Result := FKind;
end;

function TMathNode.GetText: string;
begin
  Result := FText;
end;

function TMathNode.GetAtomClass: TMathAtomClass;
begin
  Result := FAtomClass;
end;

function TMathNode.GetVariant: TMathFontVariant;
begin
  Result := FVariant;
end;

function TMathNode.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TMathNode.GetChild(const Index: Integer): IMathNode;
begin
  Result := FChildren[Index];
end;

function TMathNode.GetLeftDelimiter: string;
begin
  Result := FLeftDelimiter;
end;

function TMathNode.GetRightDelimiter: string;
begin
  Result := FRightDelimiter;
end;

function TMathNode.GetSpaceWidth: Single;
begin
  Result := FSpaceWidth;
end;

function TMathNode.GetTakesLimits: Boolean;
begin
  Result := FTakesLimits;
end;

function TMathNode.GetIsLarge: Boolean;
begin
  Result := FIsLarge;
end;

function TMathNode.GetIsError: Boolean;
begin
  Result := FIsError;
end;

function TMathNode.GetHasRule: Boolean;
begin
  Result := FHasRule;
end;

function TMathNode.GetAlignment: TMathColumnAlignment;
begin
  Result := FAlignment;
end;

function TMathNode.IsEmpty: Boolean;
begin
  Result := (FKind = TMathNodeKind.Row) and (FChildren.Count = 0);
end;

procedure TMathNode.AddChild(const Child: IMathNode);
begin
  FChildren.Add(Child);
end;

procedure TMathNode.SetChild(const Index: Integer; const Child: IMathNode);
begin
  FChildren[Index] := Child;
end;

class constructor TMathSymbolTable.Create;
begin
  FEntries := TDictionary<string, TMathSymbolInfo>.Create;

  AddGreek;
  AddOperators;
  AddRelations;
  AddArrows;
  AddMiscellaneous;
  AddFunctions;
  AddDelimiters;
end;

class destructor TMathSymbolTable.Destroy;
begin
  FEntries.Free;
end;

class function TMathSymbolTable.Entry(const Name, Text: string; const AtomClass: TMathAtomClass;
                                      const Variant: TMathFontVariant; const TakesLimits: Boolean;
                                      const IsLarge: Boolean): TMathSymbolEntry;
begin
  Result.Name := Name;
  Result.Text := Text;
  Result.AtomClass := AtomClass;
  Result.Variant := Variant;
  Result.TakesLimits := TakesLimits;
  Result.IsLarge := IsLarge;
end;

class procedure TMathSymbolTable.AddEntries(const Entries: array of TMathSymbolEntry);
begin
  for var Item in Entries do
  begin
    var Info: TMathSymbolInfo;
    Info.Text := Item.Text;
    Info.AtomClass := Item.AtomClass;
    Info.Variant := Item.Variant;
    Info.TakesLimits := Item.TakesLimits;
    Info.IsLarge := Item.IsLarge;

    FEntries.AddOrSetValue(Item.Name, Info);
  end;
end;

class procedure TMathSymbolTable.AddGreek;
begin
  const Ordinary = TMathAtomClass.Ordinary;
  const Italic = TMathFontVariant.Italic;

  AddEntries([
    Entry('alpha', #$03B1, Ordinary, Italic), Entry('beta', #$03B2, Ordinary, Italic),
    Entry('gamma', #$03B3, Ordinary, Italic), Entry('delta', #$03B4, Ordinary, Italic),
    Entry('epsilon', #$03F5, Ordinary, Italic), Entry('varepsilon', #$03B5, Ordinary, Italic),
    Entry('zeta', #$03B6, Ordinary, Italic), Entry('eta', #$03B7, Ordinary, Italic),
    Entry('theta', #$03B8, Ordinary, Italic), Entry('vartheta', #$03D1, Ordinary, Italic),
    Entry('iota', #$03B9, Ordinary, Italic), Entry('kappa', #$03BA, Ordinary, Italic),
    Entry('lambda', #$03BB, Ordinary, Italic), Entry('mu', #$03BC, Ordinary, Italic),
    Entry('nu', #$03BD, Ordinary, Italic), Entry('xi', #$03BE, Ordinary, Italic),
    Entry('omicron', #$03BF, Ordinary, Italic), Entry('pi', #$03C0, Ordinary, Italic),
    Entry('varpi', #$03D6, Ordinary, Italic), Entry('rho', #$03C1, Ordinary, Italic),
    Entry('varrho', #$03F1, Ordinary, Italic), Entry('sigma', #$03C3, Ordinary, Italic),
    Entry('varsigma', #$03C2, Ordinary, Italic), Entry('tau', #$03C4, Ordinary, Italic),
    Entry('upsilon', #$03C5, Ordinary, Italic), Entry('phi', #$03D5, Ordinary, Italic),
    Entry('varphi', #$03C6, Ordinary, Italic), Entry('chi', #$03C7, Ordinary, Italic),
    Entry('psi', #$03C8, Ordinary, Italic), Entry('omega', #$03C9, Ordinary, Italic),
    Entry('Gamma', #$0393, Ordinary), Entry('Delta', #$0394, Ordinary), Entry('Theta', #$0398, Ordinary),
    Entry('Lambda', #$039B, Ordinary), Entry('Xi', #$039E, Ordinary), Entry('Pi', #$03A0, Ordinary),
    Entry('Sigma', #$03A3, Ordinary), Entry('Upsilon', #$03A5, Ordinary), Entry('Phi', #$03A6, Ordinary),
    Entry('Psi', #$03A8, Ordinary), Entry('Omega', #$03A9, Ordinary)]);
end;

class procedure TMathSymbolTable.AddOperators;
begin
  const Binary = TMathAtomClass.Binary;
  const Operator = TMathAtomClass.Operator;
  const Upright = TMathFontVariant.Upright;

  AddEntries([
    Entry('pm', #$00B1, Binary), Entry('mp', #$2213, Binary), Entry('times', #$00D7, Binary),
    Entry('div', #$00F7, Binary), Entry('cdot', #$22C5, Binary), Entry('ast', #$2217, Binary),
    Entry('star', #$22C6, Binary), Entry('circ', #$2218, Binary), Entry('bullet', #$2219, Binary),
    Entry('cup', #$222A, Binary), Entry('cap', #$2229, Binary), Entry('setminus', #$2216, Binary),
    Entry('wedge', #$2227, Binary), Entry('vee', #$2228, Binary), Entry('land', #$2227, Binary),
    Entry('lor', #$2228, Binary), Entry('oplus', #$2295, Binary), Entry('ominus', #$2296, Binary),
    Entry('otimes', #$2297, Binary), Entry('odot', #$2299, Binary), Entry('amalg', #$2A3F, Binary),
    Entry('sqcup', #$2294, Binary), Entry('sqcap', #$2293, Binary), Entry('dagger', #$2020, Binary),
    Entry('ddagger', #$2021, Binary), Entry('wr', #$2240, Binary), Entry('diamond', #$22C4, Binary),
    Entry('sum', #$2211, Operator, Upright, True, True), Entry('prod', #$220F, Operator, Upright, True, True),
    Entry('coprod', #$2210, Operator, Upright, True, True), Entry('int', #$222B, Operator, Upright, False, True),
    Entry('iint', #$222C, Operator, Upright, False, True), Entry('iiint', #$222D, Operator, Upright, False, True),
    Entry('oint', #$222E, Operator, Upright, False, True), Entry('bigcup', #$22C3, Operator, Upright, True, True),
    Entry('bigcap', #$22C2, Operator, Upright, True, True), Entry('bigvee', #$22C1, Operator, Upright, True, True),
    Entry('bigwedge', #$22C0, Operator, Upright, True, True),
    Entry('bigoplus', #$2A01, Operator, Upright, True, True),
    Entry('bigotimes', #$2A02, Operator, Upright, True, True)]);
end;

class procedure TMathSymbolTable.AddRelations;
begin
  const Relation = TMathAtomClass.Relation;

  AddEntries([
    Entry('leq', #$2264, Relation), Entry('le', #$2264, Relation), Entry('geq', #$2265, Relation),
    Entry('ge', #$2265, Relation), Entry('neq', #$2260, Relation), Entry('ne', #$2260, Relation),
    Entry('equiv', #$2261, Relation), Entry('approx', #$2248, Relation), Entry('sim', #$223C, Relation),
    Entry('simeq', #$2243, Relation), Entry('cong', #$2245, Relation), Entry('propto', #$221D, Relation),
    Entry('ll', #$226A, Relation), Entry('gg', #$226B, Relation), Entry('subset', #$2282, Relation),
    Entry('supset', #$2283, Relation), Entry('subseteq', #$2286, Relation), Entry('supseteq', #$2287, Relation),
    Entry('in', #$2208, Relation), Entry('notin', #$2209, Relation), Entry('ni', #$220B, Relation),
    Entry('perp', #$22A5, Relation), Entry('parallel', #$2225, Relation), Entry('mid', #$2223, Relation),
    Entry('models', #$22A8, Relation), Entry('vdash', #$22A2, Relation), Entry('dashv', #$22A3, Relation),
    Entry('prec', #$227A, Relation), Entry('succ', #$227B, Relation), Entry('preceq', #$2AAF, Relation),
    Entry('succeq', #$2AB0, Relation), Entry('doteq', #$2250, Relation), Entry('asymp', #$224D, Relation),
    Entry('bowtie', #$22C8, Relation), Entry('triangleq', #$225C, Relation), Entry('coloneqq', #$2254, Relation)]);
end;

class procedure TMathSymbolTable.AddArrows;
begin
  const Relation = TMathAtomClass.Relation;

  AddEntries([
    Entry('to', #$2192, Relation), Entry('rightarrow', #$2192, Relation), Entry('leftarrow', #$2190, Relation),
    Entry('gets', #$2190, Relation), Entry('leftrightarrow', #$2194, Relation), Entry('Rightarrow', #$21D2, Relation),
    Entry('Leftarrow', #$21D0, Relation), Entry('Leftrightarrow', #$21D4, Relation), Entry('implies', #$27F9, Relation),
    Entry('iff', #$27FA, Relation), Entry('mapsto', #$21A6, Relation), Entry('longrightarrow', #$27F6, Relation),
    Entry('longleftarrow', #$27F5, Relation), Entry('Longrightarrow', #$27F9, Relation),
    Entry('uparrow', #$2191, Relation), Entry('downarrow', #$2193, Relation), Entry('updownarrow', #$2195, Relation),
    Entry('Uparrow', #$21D1, Relation), Entry('Downarrow', #$21D3, Relation), Entry('nearrow', #$2197, Relation),
    Entry('searrow', #$2198, Relation), Entry('swarrow', #$2199, Relation), Entry('nwarrow', #$2196, Relation),
    Entry('hookrightarrow', #$21AA, Relation), Entry('hookleftarrow', #$21A9, Relation)]);
end;

class procedure TMathSymbolTable.AddMiscellaneous;
begin
  const Ordinary = TMathAtomClass.Ordinary;
  const Punctuation = TMathAtomClass.Punctuation;
  const Italic = TMathFontVariant.Italic;

  AddEntries([
    Entry('infty', #$221E, Ordinary), Entry('partial', #$2202, Ordinary, Italic), Entry('nabla', #$2207, Ordinary),
    Entry('forall', #$2200, Ordinary), Entry('exists', #$2203, Ordinary), Entry('nexists', #$2204, Ordinary),
    Entry('emptyset', #$2205, Ordinary), Entry('varnothing', #$2205, Ordinary), Entry('neg', #$00AC, Ordinary),
    Entry('lnot', #$00AC, Ordinary), Entry('angle', #$2220, Ordinary), Entry('triangle', #$25B3, Ordinary),
    Entry('prime', #$2032, Ordinary), Entry('hbar', #$210F, Ordinary), Entry('ell', #$2113, Ordinary, Italic),
    Entry('Re', #$211C, Ordinary), Entry('Im', #$2111, Ordinary), Entry('aleph', #$2135, Ordinary),
    Entry('wp', #$2118, Ordinary), Entry('imath', #$0131, Ordinary, Italic), Entry('jmath', #$0237, Ordinary, Italic),
    Entry('top', #$22A4, Ordinary), Entry('bot', #$22A5, Ordinary), Entry('flat', #$266D, Ordinary),
    Entry('natural', #$266E, Ordinary), Entry('sharp', #$266F, Ordinary), Entry('clubsuit', #$2663, Ordinary),
    Entry('diamondsuit', #$2662, Ordinary), Entry('heartsuit', #$2661, Ordinary), Entry('spadesuit', #$2660, Ordinary),
    Entry('checkmark', #$2713, Ordinary), Entry('degree', #$00B0, Ordinary), Entry('cdots', #$22EF, Ordinary),
    Entry('ldots', #$2026, Ordinary), Entry('dots', #$2026, Ordinary), Entry('vdots', #$22EE, Ordinary),
    Entry('ddots', #$22F1, Ordinary), Entry('colon', ':', Punctuation), Entry('%', '%', Ordinary),
    Entry('&', '&', Ordinary), Entry('#', '#', Ordinary), Entry('$', '$', Ordinary), Entry('_', '_', Ordinary),
    Entry('|', #$2016, Ordinary), Entry('backslash', '\', Ordinary)]);
end;

class procedure TMathSymbolTable.AddFunctions;
begin
  const Operator = TMathAtomClass.Operator;
  const Upright = TMathFontVariant.Upright;

  AddEntries([
    Entry('sin', 'sin', Operator), Entry('cos', 'cos', Operator), Entry('tan', 'tan', Operator),
    Entry('cot', 'cot', Operator), Entry('sec', 'sec', Operator), Entry('csc', 'csc', Operator),
    Entry('arcsin', 'arcsin', Operator), Entry('arccos', 'arccos', Operator), Entry('arctan', 'arctan', Operator),
    Entry('sinh', 'sinh', Operator), Entry('cosh', 'cosh', Operator), Entry('tanh', 'tanh', Operator),
    Entry('coth', 'coth', Operator), Entry('exp', 'exp', Operator), Entry('log', 'log', Operator),
    Entry('ln', 'ln', Operator), Entry('lg', 'lg', Operator), Entry('arg', 'arg', Operator),
    Entry('deg', 'deg', Operator), Entry('dim', 'dim', Operator), Entry('hom', 'hom', Operator),
    Entry('ker', 'ker', Operator), Entry('det', 'det', Operator, Upright, True), Entry('gcd', 'gcd', Operator, Upright, True),
    Entry('lim', 'lim', Operator, Upright, True), Entry('liminf', 'lim inf', Operator, Upright, True),
    Entry('limsup', 'lim sup', Operator, Upright, True), Entry('max', 'max', Operator, Upright, True),
    Entry('min', 'min', Operator, Upright, True), Entry('sup', 'sup', Operator, Upright, True),
    Entry('inf', 'inf', Operator, Upright, True), Entry('Pr', 'Pr', Operator, Upright, True)]);
end;

class procedure TMathSymbolTable.AddDelimiters;
begin
  const Opening = TMathAtomClass.Opening;
  const Closing = TMathAtomClass.Closing;

  AddEntries([
    Entry('{', '{', Opening), Entry('}', '}', Closing), Entry('lbrace', '{', Opening), Entry('rbrace', '}', Closing),
    Entry('langle', #$27E8, Opening), Entry('rangle', #$27E9, Closing), Entry('lfloor', #$230A, Opening),
    Entry('rfloor', #$230B, Closing), Entry('lceil', #$2308, Opening), Entry('rceil', #$2309, Closing),
    Entry('lvert', '|', Opening), Entry('rvert', '|', Closing), Entry('lVert', #$2016, Opening),
    Entry('rVert', #$2016, Closing), Entry('vert', '|', TMathAtomClass.Ordinary),
    Entry('Vert', #$2016, TMathAtomClass.Ordinary)]);
end;

class function TMathSymbolTable.TryFind(const Name: string; out Info: TMathSymbolInfo): Boolean;
begin
  Result := FEntries.TryGetValue(Name, Info);
end;

constructor TMathScanner.Create(const Source: string);
begin
  inherited Create;

  FSource := Source;
  FPosition := 1;
end;

function TMathScanner.AtEnd: Boolean;
begin
  Result := (Peek.Kind = TMathTokenKind.EndOfInput);
end;

procedure TMathScanner.SkipWhitespace;
begin
  while (FPosition <= Length(FSource)) and FSource[FPosition].IsWhiteSpace do
  begin
    Inc(FPosition);
  end;
end;

class function TMathScanner.IsCommandLetter(const Value: Char): Boolean;
begin
  Result := CharInSet(Value, ['a'..'z', 'A'..'Z']);
end;

function TMathScanner.Peek: TMathToken;
begin
  if not FPeeked then
  begin
    const Start = FPosition;
    FPeekedToken := ReadToken;
    FPeekedPosition := FPosition;
    FPosition := Start;
    FPeeked := True;
  end;

  Result := FPeekedToken;
end;

function TMathScanner.Next: TMathToken;
begin
  if FPeeked then
  begin
    FPosition := FPeekedPosition;
    FPeeked := False;
    Result := FPeekedToken;
    Exit;
  end;

  Result := ReadToken;
end;

function TMathScanner.ReadToken: TMathToken;
begin
  SkipWhitespace;

  Result.Text := '';

  const AtEndOfInput = (FPosition > Length(FSource));
  if AtEndOfInput then
  begin
    Result.Kind := TMathTokenKind.EndOfInput;
    Exit;
  end;

  const Current = FSource[FPosition];
  Inc(FPosition);

  case Current of
    Backslash:
      begin
        Result.Kind := TMathTokenKind.Command;
        Result.Text := ReadCommandName;
      end;
    OpenBraceChar:
      Result.Kind := TMathTokenKind.OpenBrace;
    CloseBraceChar:
      Result.Kind := TMathTokenKind.CloseBrace;
    CaretChar:
      Result.Kind := TMathTokenKind.Superscript;
    UnderscoreChar:
      Result.Kind := TMathTokenKind.Subscript;
    AmpersandChar:
      Result.Kind := TMathTokenKind.Ampersand;
    PrimeChar:
      Result.Kind := TMathTokenKind.Prime;
  else
    Result.Kind := TMathTokenKind.Character;
    Result.Text := Current;
  end;
end;

// A command is a backslash followed by letters, or a backslash followed by
// exactly one other character, which is how TeX spells \, \; \{ and \\.
function TMathScanner.ReadCommandName: string;
begin
  const AtEndOfInput = (FPosition > Length(FSource));
  if AtEndOfInput then
  begin
    Result := '';
    Exit;
  end;

  const Start = FPosition;

  if not IsCommandLetter(FSource[Start]) then
  begin
    Inc(FPosition);
    Result := FSource[Start];
    Exit;
  end;

  while (FPosition <= Length(FSource)) and IsCommandLetter(FSource[FPosition]) do
  begin
    Inc(FPosition);
  end;

  const HasStar = (FPosition <= Length(FSource)) and (FSource[FPosition] = '*');
  if HasStar then
    Inc(FPosition);

  Result := Copy(FSource, Start, FPosition - Start);
end;

function TMathScanner.ReadRawGroup: string;
begin
  FPeeked := False;
  SkipWhitespace;

  const HasBrace = (FPosition <= Length(FSource)) and (FSource[FPosition] = OpenBraceChar);
  if not HasBrace then
  begin
    const HasCharacter = (FPosition <= Length(FSource));
    if not HasCharacter then
    begin
      Result := '';
      Exit;
    end;

    Result := FSource[FPosition];
    Inc(FPosition);
    Exit;
  end;

  Inc(FPosition);
  const Start = FPosition;
  var Depth := 1;

  while (FPosition <= Length(FSource)) and (Depth > 0) do
  begin
    const Current = FSource[FPosition];

    if Current = Backslash then
      Inc(FPosition)
    else if Current = OpenBraceChar then
      Inc(Depth)
    else if Current = CloseBraceChar then
      Dec(Depth);

    Inc(FPosition);
  end;

  const ClosedProperly = (Depth = 0);
  var EndPosition := FPosition;
  if ClosedProperly then
    Dec(EndPosition);

  Result := Copy(FSource, Start, EndPosition - Start);
end;

class function TMathParser.Parse(const Source: string): IMathNode;
begin
  const Parser = TMathTreeParser.Create(Source);
  try
    Result := Parser.Parse;
  finally
    Parser.Free;
  end;
end;

constructor TMathTreeParser.Create(const Source: string);
begin
  inherited Create;

  FScanner := TMathScanner.Create(Source);
end;

destructor TMathTreeParser.Destroy;
begin
  FScanner.Free;

  inherited Destroy;
end;

function TMathTreeParser.Parse: IMathNode;
begin
  Result := ParseLines;
end;

// A formula with \\ at the top level is a column of lines, which is what a
// display formula spread over several lines expects. Without one it is a
// single row. Every sequence stops at any terminator, so a closer without an
// opener surfaces here, where it is consumed and the line goes on.
function TMathTreeParser.ParseLines: IMathNode;
begin
  const Lines = TList<IMathNode>.Create;
  try
    var Line := TMathNode.Create(TMathNodeKind.Row);
    Lines.Add(Line);

    while not FScanner.AtEnd do
    begin
      ParseSequenceInto(Line);

      const Token = FScanner.Peek;

      const AtEndOfInput = (Token.Kind = TMathTokenKind.EndOfInput);
      if AtEndOfInput then
        Break;

      if IsLineBreak(Token) then
      begin
        FScanner.Next;
        Line := TMathNode.Create(TMathNodeKind.Row);
        Lines.Add(Line);
        Continue;
      end;

      ConsumeStrayTerminator(Token, Line);
    end;

    const IsSingleLine = (Lines.Count = 1);
    if IsSingleLine then
    begin
      Result := Lines[0];
      Exit;
    end;

    const Column = TMathNode.Create(TMathNodeKind.Matrix);
    Result := Column;

    for var LineNode in Lines do
    begin
      const Row = TMathNode.Create(TMathNodeKind.Row);
      Row.AddChild(LineNode);
      Column.AddChild(Row);
    end;
  finally
    Lines.Free;
  end;
end;

class function TMathTreeParser.IsTerminator(const Token: TMathToken): Boolean;
begin
  case Token.Kind of
    TMathTokenKind.CloseBrace, TMathTokenKind.Ampersand:
      Result := True;
    TMathTokenKind.Command:
      Result := (Token.Text = RightCommand) or (Token.Text = EndCommand) or (Token.Text = LineBreakCommand);
  else
    Result := False;
  end;
end;

class function TMathTreeParser.IsLineBreak(const Token: TMathToken): Boolean;
begin
  Result := (Token.Kind = TMathTokenKind.Command) and (Token.Text = LineBreakCommand);
end;

// A terminator without an opener: a closing brace or an ampersand outside a
// matrix is dropped, \right without \left keeps its delimiter as an
// ordinary symbol, \end without \begin loses its argument.
procedure TMathTreeParser.ConsumeStrayTerminator(const Token: TMathToken; const Line: TMathNode);
begin
  FScanner.Next;

  const IsRight = (Token.Kind = TMathTokenKind.Command) and (Token.Text = RightCommand);
  if IsRight then
  begin
    const Delimiter = ParseDelimiter;
    if Delimiter <> '' then
      Line.AddChild(SymbolNode(Delimiter, TMathAtomClass.Ordinary, TMathFontVariant.Upright));
  end;

  const IsEnd = (Token.Kind = TMathTokenKind.Command) and (Token.Text = EndCommand);
  if IsEnd then
    ReadEnvironmentName;
end;

procedure TMathTreeParser.ParseSequenceInto(const Row: TMathNode);
begin
  while True do
  begin
    const Token = FScanner.Peek;

    const AtEndOfInput = (Token.Kind = TMathTokenKind.EndOfInput);
    if AtEndOfInput or IsTerminator(Token) then
      Exit;

    const Atom = ParseAtomWithScripts;
    if Atom <> nil then
      Row.AddChild(Atom);
  end;
end;

function TMathTreeParser.ParseSequence: TMathNode;
begin
  Result := TMathNode.Create(TMathNodeKind.Row);
  ParseSequenceInto(Result);
end;

function TMathTreeParser.ParseSequenceUntilBracket: TMathNode;
begin
  Result := TMathNode.Create(TMathNodeKind.Row);

  while True do
  begin
    const Token = FScanner.Peek;

    const AtEndOfInput = (Token.Kind = TMathTokenKind.EndOfInput);
    if AtEndOfInput or IsTerminator(Token) then
      Exit;

    const IsCloser = (Token.Kind = TMathTokenKind.Character) and (Token.Text = ']');
    if IsCloser then
    begin
      FScanner.Next;
      Exit;
    end;

    const Atom = ParseAtomWithScripts;
    if Atom <> nil then
      Result.AddChild(Atom);
  end;
end;

function TMathTreeParser.ParseAtomWithScripts: TMathNode;
begin
  // A script without a base scripts an empty box, as TeX does.
  var Base: TMathNode;
  const StartsWithScript = (FScanner.Peek.Kind = TMathTokenKind.Superscript) or
    (FScanner.Peek.Kind = TMathTokenKind.Subscript) or (FScanner.Peek.Kind = TMathTokenKind.Prime);
  if StartsWithScript then
    Base := EmptyRow
  else
    Base := ParseAtom;

  if Base = nil then
  begin
    Result := nil;
    Exit;
  end;

  ApplyLimitsCommands(Base);

  var Superscript: TMathNode := nil;
  var Subscript: TMathNode := nil;
  var Script: TMathNode := nil;

  while True do
  begin
    const Token = FScanner.Peek;

    const IsSuperscript = (Token.Kind = TMathTokenKind.Superscript) or (Token.Kind = TMathTokenKind.Prime);
    const IsSubscript = (Token.Kind = TMathTokenKind.Subscript);
    if not (IsSuperscript or IsSubscript) then
      Break;

    // TeX rejects a double superscript; here it nests, so f'^2 still shows
    // both rather than dropping one.
    const NeedsNesting = (IsSuperscript and (Superscript <> nil)) or (IsSubscript and (Subscript <> nil));
    if NeedsNesting then
    begin
      Base := Script;
      Script := nil;
      Superscript := nil;
      Subscript := nil;
    end;

    FScanner.Next;

    var Part: TMathNode;
    if Token.Kind = TMathTokenKind.Prime then
      Part := SymbolNode(PrimeGlyph, TMathAtomClass.Ordinary, TMathFontVariant.Upright)
    else
      Part := ParseArgument;

    if IsSuperscript then
      Superscript := Part
    else
      Subscript := Part;

    if Script = nil then
    begin
      Script := TMathNode.Create(TMathNodeKind.Script);
      Script.AtomClass := Base.AtomClass;
      Script.AddChild(Base);
      Script.AddChild(EmptyRow);
      Script.AddChild(EmptyRow);
    end;

    if IsSuperscript then
      Script.SetChild(1, Superscript)
    else
      Script.SetChild(2, Subscript);
  end;

  if Script <> nil then
  begin
    Result := Script;
    Exit;
  end;

  Result := Base;
end;

procedure TMathTreeParser.ApplyLimitsCommands(const Atom: TMathNode);
begin
  while True do
  begin
    const Token = FScanner.Peek;
    const IsLimits = (Token.Kind = TMathTokenKind.Command) and (Token.Text = LimitsCommand);
    const IsNoLimits = (Token.Kind = TMathTokenKind.Command) and (Token.Text = NoLimitsCommand);
    if not (IsLimits or IsNoLimits) then
      Exit;

    FScanner.Next;
    Atom.TakesLimits := IsLimits;
  end;
end;

function TMathTreeParser.ParseAtom: TMathNode;
begin
  const Token = FScanner.Next;

  case Token.Kind of
    TMathTokenKind.Character:
      Result := ParseCharacter(Token.Text[1]);
    TMathTokenKind.Command:
      Result := ParseCommand(Token.Text);
    TMathTokenKind.OpenBrace:
      begin
        Result := ParseSequence;

        const HasCloser = (FScanner.Peek.Kind = TMathTokenKind.CloseBrace);
        if HasCloser then
          FScanner.Next;
      end;
  else
    Result := nil;
  end;
end;

// The argument of a command or a script: a braced group, a command with its
// own arguments, or a single character. "x^10" therefore raises only the 1.
function TMathTreeParser.ParseArgument: TMathNode;
begin
  const Token = FScanner.Peek;

  case Token.Kind of
    TMathTokenKind.EndOfInput:
      Result := EmptyRow;
    TMathTokenKind.OpenBrace, TMathTokenKind.Character, TMathTokenKind.Command:
      begin
        if IsTerminator(Token) then
        begin
          Result := EmptyRow;
          Exit;
        end;

        Result := ParseAtom;
        if Result = nil then
          Result := EmptyRow;
      end;
  else
    Result := EmptyRow;
  end;
end;

function TMathTreeParser.ParseCharacter(const Value: Char): TMathNode;
begin
  if Value.IsDigit then
  begin
    Result := ParseDigits(Value);
    Exit;
  end;

  if Value.IsLetter then
  begin
    Result := SymbolNode(Value, TMathAtomClass.Ordinary, TMathFontVariant.Italic);
    Exit;
  end;

  case Value of
    '+':
      Result := SymbolNode(Value, TMathAtomClass.Binary, TMathFontVariant.Upright);
    '-':
      Result := SymbolNode(MinusGlyph, TMathAtomClass.Binary, TMathFontVariant.Upright);
    '*':
      Result := SymbolNode(AsteriskGlyph, TMathAtomClass.Binary, TMathFontVariant.Upright);
    '=', '<', '>', ':':
      Result := SymbolNode(Value, TMathAtomClass.Relation, TMathFontVariant.Upright);
    ',', ';':
      Result := SymbolNode(Value, TMathAtomClass.Punctuation, TMathFontVariant.Upright);
    '(', '[':
      Result := SymbolNode(Value, TMathAtomClass.Opening, TMathFontVariant.Upright);
    ')', ']', '!':
      Result := SymbolNode(Value, TMathAtomClass.Closing, TMathFontVariant.Upright);
    TildeChar:
      Result := SpaceNode(WordSpaceEm);
  else
    Result := SymbolNode(Value, TMathAtomClass.Ordinary, TMathFontVariant.Upright);
  end;
end;

// Digits run together into one symbol so the font kerns them as a number.
function TMathTreeParser.ParseDigits(const First: Char): TMathNode;
begin
  var Digits := string(First);

  while True do
  begin
    const Token = FScanner.Peek;
    const IsDigit = (Token.Kind = TMathTokenKind.Character) and Token.Text[1].IsDigit;
    if not IsDigit then
      Break;

    FScanner.Next;
    Digits := Digits + Token.Text;
  end;

  Result := SymbolNode(Digits, TMathAtomClass.Ordinary, TMathFontVariant.Upright);
end;

function TMathTreeParser.ParseCommand(const Name: string): TMathNode;
begin
  var Info: TMathSymbolInfo;
  if TMathSymbolTable.TryFind(Name, Info) then
  begin
    Result := SymbolNode(Info.Text, Info.AtomClass, Info.Variant);
    Result.TakesLimits := Info.TakesLimits;
    Result.IsLarge := Info.IsLarge;
    Exit;
  end;

  if TryParseFractionCommand(Name, Result) then
    Exit;

  if TryParseRadicalCommand(Name, Result) then
    Exit;

  if Name = LeftCommand then
  begin
    Result := ParseDelimited;
    Exit;
  end;

  if TryParseStyleCommand(Name, Result) then
    Exit;

  if TryParseAccentCommand(Name, Result) then
    Exit;

  if TryParseSpacingCommand(Name, Result) then
    Exit;

  if TryParseEnvironmentCommand(Name, Result) then
    Exit;

  Result := ErrorNode(Name);
end;

function TMathTreeParser.TryParseFractionCommand(const Name: string; out Node: TMathNode): Boolean;
begin
  Result := True;

  if (Name = 'frac') or (Name = 'dfrac') or (Name = 'tfrac') then
  begin
    Node := ParseFraction(True);
    Exit;
  end;

  if Name = 'binom' then
  begin
    Node := ParseBinomial;
    Exit;
  end;

  Result := False;
end;

function TMathTreeParser.TryParseRadicalCommand(const Name: string; out Node: TMathNode): Boolean;
begin
  Result := (Name = 'sqrt');
  if Result then
    Node := ParseRadical;
end;

function TMathTreeParser.TryParseStyleCommand(const Name: string; out Node: TMathNode): Boolean;
begin
  Result := True;

  if (Name = 'text') or (Name = 'textrm') or (Name = 'mbox') then
  begin
    Node := ParseTextCommand(TMathFontVariant.Upright);
    Exit;
  end;

  if Name = 'textit' then
  begin
    Node := ParseTextCommand(TMathFontVariant.Italic);
    Exit;
  end;

  if Name = 'textbf' then
  begin
    Node := ParseTextCommand(TMathFontVariant.Bold);
    Exit;
  end;

  if Name = 'mathrm' then
  begin
    Node := ParseStyled(TMathFontVariant.Upright);
    Exit;
  end;

  if (Name = 'mathbf') or (Name = 'boldsymbol') or (Name = 'bm') then
  begin
    Node := ParseStyled(TMathFontVariant.Bold);
    Exit;
  end;

  if Name = 'mathit' then
  begin
    Node := ParseStyled(TMathFontVariant.Italic);
    Exit;
  end;

  if Name = 'mathbb' then
  begin
    Node := ParseStyled(TMathFontVariant.DoubleStruck);
    Exit;
  end;

  if (Name = 'mathcal') or (Name = 'mathscr') then
  begin
    Node := ParseStyled(TMathFontVariant.Script);
    Exit;
  end;

  if Name = 'mathfrak' then
  begin
    Node := ParseStyled(TMathFontVariant.Fraktur);
    Exit;
  end;

  if Name = 'mathsf' then
  begin
    Node := ParseStyled(TMathFontVariant.SansSerif);
    Exit;
  end;

  if Name = 'mathtt' then
  begin
    Node := ParseStyled(TMathFontVariant.Monospace);
    Exit;
  end;

  if Name = 'operatorname' then
  begin
    Node := ParseOperatorName(False);
    Exit;
  end;

  if Name = 'operatorname*' then
  begin
    Node := ParseOperatorName(True);
    Exit;
  end;

  if (Name = 'displaystyle') or (Name = 'textstyle') or (Name = 'scriptstyle') or (Name = 'scriptscriptstyle') then
  begin
    Node := nil;
    Exit;
  end;

  Result := False;
end;

function TMathTreeParser.TryParseAccentCommand(const Name: string; out Node: TMathNode): Boolean;
begin
  Result := True;

  if Name = 'hat' then
  begin
    Node := ParseAccent(#$02C6);
    Exit;
  end;

  if Name = 'widehat' then
  begin
    Node := ParseAccent(#$02C6);
    Exit;
  end;

  if Name = 'tilde' then
  begin
    Node := ParseAccent(#$02DC);
    Exit;
  end;

  if Name = 'widetilde' then
  begin
    Node := ParseAccent(#$02DC);
    Exit;
  end;

  if Name = 'bar' then
  begin
    Node := ParseAccent(#$00AF);
    Exit;
  end;

  if Name = 'dot' then
  begin
    Node := ParseAccent(#$02D9);
    Exit;
  end;

  if Name = 'ddot' then
  begin
    Node := ParseAccent(#$00A8);
    Exit;
  end;

  if Name = 'vec' then
  begin
    Node := ParseAccent(#$2192);
    Exit;
  end;

  if Name = 'check' then
  begin
    Node := ParseAccent(#$02C7);
    Exit;
  end;

  if Name = 'breve' then
  begin
    Node := ParseAccent(#$02D8);
    Exit;
  end;

  if Name = 'acute' then
  begin
    Node := ParseAccent(#$00B4);
    Exit;
  end;

  if Name = 'grave' then
  begin
    Node := ParseAccent('`');
    Exit;
  end;

  if Name = 'overline' then
  begin
    Node := ParseAccent('');
    Exit;
  end;

  Result := False;
end;

function TMathTreeParser.TryParseSpacingCommand(const Name: string; out Node: TMathNode): Boolean;
begin
  Result := True;

  if Name = ',' then
  begin
    Node := SpaceNode(ThinSpaceEm);
    Exit;
  end;

  if Name = ':' then
  begin
    Node := SpaceNode(MediumSpaceEm);
    Exit;
  end;

  if Name = ';' then
  begin
    Node := SpaceNode(ThickSpaceEm);
    Exit;
  end;

  if Name = '!' then
  begin
    Node := SpaceNode(-ThinSpaceEm);
    Exit;
  end;

  if Name = ' ' then
  begin
    Node := SpaceNode(WordSpaceEm);
    Exit;
  end;

  if Name = 'quad' then
  begin
    Node := SpaceNode(QuadEm);
    Exit;
  end;

  if Name = 'qquad' then
  begin
    Node := SpaceNode(2 * QuadEm);
    Exit;
  end;

  Result := False;
end;

function TMathTreeParser.TryParseEnvironmentCommand(const Name: string; out Node: TMathNode): Boolean;
begin
  Result := (Name = BeginCommand);
  if Result then
    Node := ParseEnvironment;
end;

function TMathTreeParser.ParseFraction(const HasRule: Boolean): TMathNode;
begin
  Result := TMathNode.Create(TMathNodeKind.Fraction);
  Result.HasRule := HasRule;
  Result.AtomClass := TMathAtomClass.Inner;
  Result.AddChild(ParseArgument);
  Result.AddChild(ParseArgument);
end;

function TMathTreeParser.ParseBinomial: TMathNode;
begin
  const Body = TMathNode.Create(TMathNodeKind.Row);
  Body.AddChild(ParseFraction(False));

  Result := TMathNode.Create(TMathNodeKind.Delimited);
  Result.AtomClass := TMathAtomClass.Inner;
  Result.LeftDelimiter := '(';
  Result.RightDelimiter := ')';
  Result.AddChild(Body);
end;

function TMathTreeParser.ParseRadical: TMathNode;
begin
  var Index: TMathNode := EmptyRow;

  const HasIndex = (FScanner.Peek.Kind = TMathTokenKind.Character) and (FScanner.Peek.Text = '[');
  if HasIndex then
  begin
    FScanner.Next;
    Index := ParseSequenceUntilBracket;
  end;

  Result := TMathNode.Create(TMathNodeKind.Radical);
  Result.AtomClass := TMathAtomClass.Ordinary;
  Result.AddChild(ParseArgument);
  Result.AddChild(Index);
end;

function TMathTreeParser.ParseDelimited: TMathNode;
begin
  Result := TMathNode.Create(TMathNodeKind.Delimited);
  Result.AtomClass := TMathAtomClass.Inner;
  Result.LeftDelimiter := ParseDelimiter;
  Result.AddChild(ParseSequence);

  const Token = FScanner.Peek;
  const HasRight = (Token.Kind = TMathTokenKind.Command) and (Token.Text = RightCommand);
  if HasRight then
  begin
    FScanner.Next;
    Result.RightDelimiter := ParseDelimiter;
  end;
end;

// The delimiter after \left or \right: a bracket character, a delimiter
// command such as \langle, or a dot for none.
function TMathTreeParser.ParseDelimiter: string;
begin
  const Token = FScanner.Next;

  case Token.Kind of
    TMathTokenKind.Character:
      begin
        if Token.Text = EmptyDelimiter then
        begin
          Result := '';
          Exit;
        end;

        Result := Token.Text;
      end;
    TMathTokenKind.Command:
      begin
        var Info: TMathSymbolInfo;
        if TMathSymbolTable.TryFind(Token.Text, Info) then
        begin
          Result := Info.Text;
          Exit;
        end;

        Result := '';
      end;
    TMathTokenKind.OpenBrace:
      Result := '{';
    TMathTokenKind.CloseBrace:
      Result := '}';
  else
    Result := '';
  end;
end;

function TMathTreeParser.ParseTextCommand(const Variant: TMathFontVariant): TMathNode;
begin
  Result := TMathNode.Create(TMathNodeKind.Text);
  Result.AtomClass := TMathAtomClass.Ordinary;
  Result.Variant := Variant;
  Result.Text := FScanner.ReadRawGroup;
end;

function TMathTreeParser.ParseStyled(const Variant: TMathFontVariant): TMathNode;
begin
  Result := TMathNode.Create(TMathNodeKind.Styled);
  Result.AtomClass := TMathAtomClass.Ordinary;
  Result.Variant := Variant;
  Result.AddChild(ParseArgument);
end;

function TMathTreeParser.ParseOperatorName(const TakesLimits: Boolean): TMathNode;
begin
  Result := SymbolNode(FScanner.ReadRawGroup, TMathAtomClass.Operator, TMathFontVariant.Upright);
  Result.TakesLimits := TakesLimits;
end;

function TMathTreeParser.ParseAccent(const Glyph: string): TMathNode;
begin
  Result := TMathNode.Create(TMathNodeKind.Accent);
  Result.AtomClass := TMathAtomClass.Ordinary;
  Result.Text := Glyph;
  Result.AddChild(ParseArgument);
end;

function TMathTreeParser.ParseEnvironment: TMathNode;
begin
  const Name = ReadEnvironmentName;

  var Left: string;
  var Right: string;
  var Alignment: TMathColumnAlignment;
  if TryMatrixDelimiters(Name, Left, Right, Alignment) then
  begin
    Result := ParseMatrix;
    Result.LeftDelimiter := Left;
    Result.RightDelimiter := Right;
    Result.Alignment := Alignment;
    Exit;
  end;

  Result := ErrorNode(Format('%s{%s}', [BeginCommand, Name]));
end;

function TMathTreeParser.ReadEnvironmentName: string;
begin
  Result := FScanner.ReadRawGroup.Trim;
end;

class function TMathTreeParser.TryMatrixDelimiters(const Name: string; out Left, Right: string;
                                                   out Alignment: TMathColumnAlignment): Boolean;
begin
  Left := '';
  Right := '';
  Alignment := TMathColumnAlignment.Centre;
  Result := True;

  if (Name = 'matrix') or (Name = 'array') or (Name = 'gathered') or (Name = 'gather') or (Name = 'gather*') then
    Exit;

  if (Name = 'aligned') or (Name = 'align') or (Name = 'align*') then
  begin
    Alignment := TMathColumnAlignment.Alternate;
    Exit;
  end;

  if Name = 'pmatrix' then
  begin
    Left := '(';
    Right := ')';
    Exit;
  end;

  if Name = 'bmatrix' then
  begin
    Left := '[';
    Right := ']';
    Exit;
  end;

  if Name = 'Bmatrix' then
  begin
    Left := '{';
    Right := '}';
    Exit;
  end;

  if Name = 'vmatrix' then
  begin
    Left := '|';
    Right := '|';
    Exit;
  end;

  if Name = 'Vmatrix' then
  begin
    Left := #$2016;
    Right := #$2016;
    Exit;
  end;

  if Name = 'cases' then
  begin
    Left := '{';
    Alignment := TMathColumnAlignment.Left;
    Exit;
  end;

  Result := False;
end;

// Cells are separated by &, rows by \\, the whole thing ends at \end{name}.
// A missing \end closes the matrix at the end of the input.
function TMathTreeParser.ParseMatrix: TMathNode;
begin
  Result := TMathNode.Create(TMathNodeKind.Matrix);
  Result.AtomClass := TMathAtomClass.Inner;

  var Row := TMathNode.Create(TMathNodeKind.Row);
  Result.AddChild(Row);

  while True do
  begin
    Row.AddChild(ParseSequence);

    const Token = FScanner.Peek;

    const AtEndOfInput = (Token.Kind = TMathTokenKind.EndOfInput);
    if AtEndOfInput then
      Exit;

    if Token.Kind = TMathTokenKind.Ampersand then
    begin
      FScanner.Next;
      Continue;
    end;

    if IsLineBreak(Token) then
    begin
      FScanner.Next;
      Row := TMathNode.Create(TMathNodeKind.Row);
      Result.AddChild(Row);
      Continue;
    end;

    const IsEnd = (Token.Kind = TMathTokenKind.Command) and (Token.Text = EndCommand);
    if IsEnd then
    begin
      FScanner.Next;
      ReadEnvironmentName;
      Exit;
    end;

    Exit;
  end;
end;

class function TMathTreeParser.SpaceNode(const WidthEm: Single): TMathNode;
begin
  Result := TMathNode.Create(TMathNodeKind.Space);
  Result.SpaceWidth := WidthEm;
end;

class function TMathTreeParser.SymbolNode(const Text: string; const AtomClass: TMathAtomClass;
                                          const Variant: TMathFontVariant): TMathNode;
begin
  Result := TMathNode.Create(TMathNodeKind.Symbol);
  Result.Text := Text;
  Result.AtomClass := AtomClass;
  Result.Variant := Variant;
end;

class function TMathTreeParser.ErrorNode(const Name: string): TMathNode;
begin
  Result := SymbolNode(Backslash + Name, TMathAtomClass.Ordinary, TMathFontVariant.Upright);
  Result.IsError := True;
end;

class function TMathTreeParser.EmptyRow: TMathNode;
begin
  Result := TMathNode.Create(TMathNodeKind.Row);
end;

end.
