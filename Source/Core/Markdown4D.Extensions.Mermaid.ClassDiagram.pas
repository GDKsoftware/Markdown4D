unit Markdown4D.Extensions.Mermaid.ClassDiagram;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Extensions.Mermaid;

type
  // Reads the body of a mermaid classDiagram, the lines after its header.
  // Anything outside the supported subset (notes, namespaces, lollipop
  // interfaces, an arrow it does not know) makes TryParse fail, so the fence
  // falls back to a plain code block the way an unknown diagram type does.
  // Styling and interaction statements are read and left out of the model:
  // they change how a class looks or responds to a click, not what it is.
  TMermaidClassDiagramParser = class
  public
    class function TryParse(const Lines: TArray<string>; const StartLine: Integer;
      out Diagram: IMermaidClassDiagram): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  System.Character,
  System.Generics.Collections;

type
  TMermaidClassMember = class(TInterfacedObject, IMermaidClassMember)
  private
    const
      VisibilityMarkers: array[TMermaidClassVisibility] of string = ('', '+', '-', '#', '~');
      ReturnTypeSeparator = ' : ';
    var
      FVisibility: TMermaidClassVisibility;
      FSignature: string;
      FReturnType: string;
      FClassifier: TMermaidClassClassifier;
    function GetVisibility: TMermaidClassVisibility;
    function GetSignature: string;
    function GetReturnType: string;
    function GetClassifier: TMermaidClassClassifier;
    function GetDisplayText: string;

  public
    class function TryVisibilityOf(const Marker: Char; out Visibility: TMermaidClassVisibility): Boolean; static;
    constructor Create(const Visibility: TMermaidClassVisibility; const Signature, ReturnType: string;
      const Classifier: TMermaidClassClassifier);
  end;

  TMermaidClass = class(TInterfacedObject, IMermaidClass)
  private
    FId: string;
    FCaption: string;
    FAnnotation: string;
    FAttributes: TList<IMermaidClassMember>;
    FMethods: TList<IMermaidClassMember>;
    function GetId: string;
    function GetCaption: string;
    function GetAnnotation: string;
    function GetAttributeCount: Integer;
    function GetAttribute(const Index: Integer): IMermaidClassMember;
    function GetMethodCount: Integer;
    function GetMethod(const Index: Integer): IMermaidClassMember;

  public
    constructor Create(const Id: string);
    destructor Destroy; override;
    procedure AddAttribute(const Member: IMermaidClassMember);
    procedure AddMethod(const Member: IMermaidClassMember);
    property Caption: string read FCaption write FCaption;
    property Annotation: string read FAnnotation write FAnnotation;
  end;

  // Where a relation starts or ends: the class, the marker drawn at it and
  // the cardinality written next to it.
  TMermaidRelationEndpoint = record
    ClassIndex: Integer;
    Marker: TMermaidRelationEnd;
    Cardinality: string;
    class function Create(const ClassIndex: Integer; const Marker: TMermaidRelationEnd;
      const Cardinality: string): TMermaidRelationEndpoint; static;
  end;

  TMermaidClassRelation = class(TInterfacedObject, IMermaidClassRelation)
  private
    FSource: TMermaidRelationEndpoint;
    FTarget: TMermaidRelationEndpoint;
    FLine: TMermaidRelationLine;
    FCaption: string;
    function GetSourceIndex: Integer;
    function GetTargetIndex: Integer;
    function GetSourceEnd: TMermaidRelationEnd;
    function GetTargetEnd: TMermaidRelationEnd;
    function GetLine: TMermaidRelationLine;
    function GetSourceCardinality: string;
    function GetTargetCardinality: string;
    function GetCaption: string;

  public
    constructor Create(const Source, Target: TMermaidRelationEndpoint; const Line: TMermaidRelationLine;
      const Caption: string);
  end;

  TMermaidClassDiagram = class(TInterfacedObject, IMermaidDiagram, IMermaidClassDiagram)
  private
    FDirection: TMermaidDirection;
    FClasses: TList<IMermaidClass>;
    FClassIndex: TDictionary<string, Integer>;
    FRelations: TList<IMermaidClassRelation>;
    function GetDiagramKind: TMermaidDiagramKind;
    function GetTitle: string;
    function GetDirection: TMermaidDirection;
    function GetClassCount: Integer;
    function GetClass(const Index: Integer): IMermaidClass;
    function GetRelationCount: Integer;
    function GetRelation(const Index: Integer): IMermaidClassRelation;

  public
    constructor Create;
    destructor Destroy; override;
    function TryEnsureClass(const Id: string; out Index: Integer): Boolean;
    function ClassAt(const Index: Integer): TMermaidClass;
    procedure AddRelation(const Source, Target: TMermaidRelationEndpoint; const Line: TMermaidRelationLine;
      const Caption: string);
    property Direction: TMermaidDirection read FDirection write FDirection;
  end;

  TMermaidClassDiagramReader = class
  private
    const
      NoOpenClass = -1;
      CommentMarker = '%%';
      AnnotationOpen = '<<';
      AnnotationClose = '>>';
      BlockOpen = '{';
      BlockClose = '}';
      ClassKeyword = 'class';
      DirectionKeyword = 'direction';
      StyleSuffix = ':::';
      LabelSeparator = ':';
      StaticMarker = '$';
      AbstractMarker = '*';
      IgnoredKeywords: array[0..5] of string = ('style', 'classDef', 'cssClass', 'click', 'callback', 'link');
      AccessibilityKeywords: array[0..1] of string = ('accTitle', 'accDescr');
    var
      FDiagram: TMermaidClassDiagram;
      FDiagramReference: IMermaidClassDiagram;
      FOpenClass: Integer;
    function TryParseLine(const Line: string): Boolean;
    function TryParseBodyLine(const Line: string): Boolean;
    function TryAddBodyEntry(const ClassIndex: Integer; const Entry: string): Boolean;
    function TryParseStatement(const Line: string): Boolean;
    function TryParseDirection(const Value: string): Boolean;
    function TryParseClassDeclaration(const Declaration: string): Boolean;
    function TryOpenClassBlock(const ClassIndex: Integer; const Remainder: string): Boolean;
    function TryParseAnnotationStatement(const Line: string): Boolean;
    function TryParseClassReferenceStatement(const Line: string): Boolean;
    function TryParseRelation(const Line: string; var Index: Integer; const SourceIndex: Integer): Boolean;
    function TryAddMember(const ClassIndex: Integer; const Text: string): Boolean;
    function TryReferenceClass(const Line: string; var Index: Integer; out ClassIndex: Integer): Boolean;
    class function ClassifierOf(const Marker: string): TMermaidClassClassifier; static;
    class function IsSkippedLine(const Line: string): Boolean; static;
    class function IsIgnoredStatement(const Line: string): Boolean; static;
    class function StartsWithKeyword(const Line, Keyword: string; out Rest: string): Boolean; static;
    class function TryReadAnnotation(const Text: string; out Annotation: string; out Rest: string): Boolean; static;
    class function TryReadClassName(const Line: string; var Index: Integer; out Id, Generic: string): Boolean; static;
    class function TryReadGeneric(const Line: string; var Index: Integer; out Generic: string): Boolean; static;
    class function TryReadLabel(const Line: string; var Index: Integer; out Caption: string): Boolean; static;
    class function TryReadQuoted(const Line: string; var Index: Integer; out Text: string): Boolean; static;
    class function TryReadArrow(const Line: string; var Index: Integer; out SourceEnd: TMermaidRelationEnd;
      out RelationLine: TMermaidRelationLine; out TargetEnd: TMermaidRelationEnd): Boolean; static;
    class function ReadSourceEnd(const Line: string; var Index: Integer): TMermaidRelationEnd; static;
    class function ReadTargetEnd(const Line: string; var Index: Integer): TMermaidRelationEnd; static;
    class procedure SkipStyleSuffix(const Line: string; var Index: Integer); static;
    class procedure SkipSpaces(const Line: string; var Index: Integer); static;
    class function MatchToken(const Line: string; var Index: Integer; const Token: string): Boolean; static;
    class function IsNameChar(const Line: string; const Index: Integer): Boolean; static;
    class function ConvertGenerics(const Text: string): string; static;

  public
    constructor Create;
    function TryRead(const Lines: TArray<string>; const StartLine: Integer): Boolean;
    property Diagram: IMermaidClassDiagram read FDiagramReference;
  end;

class function TMermaidClassMember.TryVisibilityOf(const Marker: Char; out Visibility: TMermaidClassVisibility): Boolean;
begin
  for var Candidate := Succ(Low(TMermaidClassVisibility)) to High(TMermaidClassVisibility) do
  begin
    if VisibilityMarkers[Candidate] = Marker then
    begin
      Visibility := Candidate;
      Result := True;
      Exit;
    end;
  end;

  Visibility := TMermaidClassVisibility.None;
  Result := False;
end;

constructor TMermaidClassMember.Create(const Visibility: TMermaidClassVisibility; const Signature, ReturnType: string;
  const Classifier: TMermaidClassClassifier);
begin
  inherited Create;

  FVisibility := Visibility;
  FSignature := Signature;
  FReturnType := ReturnType;
  FClassifier := Classifier;
end;

function TMermaidClassMember.GetVisibility: TMermaidClassVisibility;
begin
  Result := FVisibility;
end;

function TMermaidClassMember.GetSignature: string;
begin
  Result := FSignature;
end;

function TMermaidClassMember.GetReturnType: string;
begin
  Result := FReturnType;
end;

function TMermaidClassMember.GetClassifier: TMermaidClassClassifier;
begin
  Result := FClassifier;
end;

function TMermaidClassMember.GetDisplayText: string;
begin
  Result := VisibilityMarkers[FVisibility] + FSignature;

  if FReturnType <> '' then
    Result := Result + ReturnTypeSeparator + FReturnType;
end;

constructor TMermaidClass.Create(const Id: string);
begin
  inherited Create;

  FId := Id;
  FCaption := Id;
  FAttributes := TList<IMermaidClassMember>.Create;
  FMethods := TList<IMermaidClassMember>.Create;
end;

destructor TMermaidClass.Destroy;
begin
  FMethods.Free;
  FAttributes.Free;

  inherited Destroy;
end;

function TMermaidClass.GetId: string;
begin
  Result := FId;
end;

function TMermaidClass.GetCaption: string;
begin
  Result := FCaption;
end;

function TMermaidClass.GetAnnotation: string;
begin
  Result := FAnnotation;
end;

function TMermaidClass.GetAttributeCount: Integer;
begin
  Result := FAttributes.Count;
end;

function TMermaidClass.GetAttribute(const Index: Integer): IMermaidClassMember;
begin
  Result := FAttributes[Index];
end;

function TMermaidClass.GetMethodCount: Integer;
begin
  Result := FMethods.Count;
end;

function TMermaidClass.GetMethod(const Index: Integer): IMermaidClassMember;
begin
  Result := FMethods[Index];
end;

procedure TMermaidClass.AddAttribute(const Member: IMermaidClassMember);
begin
  FAttributes.Add(Member);
end;

procedure TMermaidClass.AddMethod(const Member: IMermaidClassMember);
begin
  FMethods.Add(Member);
end;

class function TMermaidRelationEndpoint.Create(const ClassIndex: Integer; const Marker: TMermaidRelationEnd;
  const Cardinality: string): TMermaidRelationEndpoint;
begin
  Result.ClassIndex := ClassIndex;
  Result.Marker := Marker;
  Result.Cardinality := Cardinality;
end;

constructor TMermaidClassRelation.Create(const Source, Target: TMermaidRelationEndpoint;
  const Line: TMermaidRelationLine; const Caption: string);
begin
  inherited Create;

  FSource := Source;
  FTarget := Target;
  FLine := Line;
  FCaption := Caption;
end;

function TMermaidClassRelation.GetSourceIndex: Integer;
begin
  Result := FSource.ClassIndex;
end;

function TMermaidClassRelation.GetTargetIndex: Integer;
begin
  Result := FTarget.ClassIndex;
end;

function TMermaidClassRelation.GetSourceEnd: TMermaidRelationEnd;
begin
  Result := FSource.Marker;
end;

function TMermaidClassRelation.GetTargetEnd: TMermaidRelationEnd;
begin
  Result := FTarget.Marker;
end;

function TMermaidClassRelation.GetLine: TMermaidRelationLine;
begin
  Result := FLine;
end;

function TMermaidClassRelation.GetSourceCardinality: string;
begin
  Result := FSource.Cardinality;
end;

function TMermaidClassRelation.GetTargetCardinality: string;
begin
  Result := FTarget.Cardinality;
end;

function TMermaidClassRelation.GetCaption: string;
begin
  Result := FCaption;
end;

constructor TMermaidClassDiagram.Create;
begin
  inherited Create;

  FDirection := TMermaidDirection.TB;
  FClasses := TList<IMermaidClass>.Create;
  FClassIndex := TDictionary<string, Integer>.Create;
  FRelations := TList<IMermaidClassRelation>.Create;
end;

destructor TMermaidClassDiagram.Destroy;
begin
  FRelations.Free;
  FClassIndex.Free;
  FClasses.Free;

  inherited Destroy;
end;

function TMermaidClassDiagram.GetDiagramKind: TMermaidDiagramKind;
begin
  Result := TMermaidDiagramKind.ClassDiagram;
end;

function TMermaidClassDiagram.GetTitle: string;
begin
  Result := '';
end;

function TMermaidClassDiagram.GetDirection: TMermaidDirection;
begin
  Result := FDirection;
end;

function TMermaidClassDiagram.GetClassCount: Integer;
begin
  Result := FClasses.Count;
end;

function TMermaidClassDiagram.GetClass(const Index: Integer): IMermaidClass;
begin
  Result := FClasses[Index];
end;

function TMermaidClassDiagram.GetRelationCount: Integer;
begin
  Result := FRelations.Count;
end;

function TMermaidClassDiagram.GetRelation(const Index: Integer): IMermaidClassRelation;
begin
  Result := FRelations[Index];
end;

function TMermaidClassDiagram.TryEnsureClass(const Id: string; out Index: Integer): Boolean;
begin
  if FClassIndex.TryGetValue(Id, Index) then
  begin
    Result := True;
    Exit;
  end;

  if FClasses.Count >= TMermaidExtension.MaxNodeCount then
  begin
    Result := False;
    Exit;
  end;

  Index := FClasses.Count;
  FClasses.Add(TMermaidClass.Create(Id));
  FClassIndex.Add(Id, Index);

  Result := True;
end;

function TMermaidClassDiagram.ClassAt(const Index: Integer): TMermaidClass;
begin
  Result := FClasses[Index] as TMermaidClass;
end;

procedure TMermaidClassDiagram.AddRelation(const Source, Target: TMermaidRelationEndpoint;
  const Line: TMermaidRelationLine; const Caption: string);
begin
  FRelations.Add(TMermaidClassRelation.Create(Source, Target, Line, Caption));
end;

class function TMermaidClassDiagramParser.TryParse(const Lines: TArray<string>; const StartLine: Integer;
  out Diagram: IMermaidClassDiagram): Boolean;
begin
  Diagram := nil;

  const Reader = TMermaidClassDiagramReader.Create;
  try
    if not Reader.TryRead(Lines, StartLine) then
    begin
      Result := False;
      Exit;
    end;

    Diagram := Reader.Diagram;
  finally
    Reader.Free;
  end;

  Result := True;
end;

constructor TMermaidClassDiagramReader.Create;
begin
  inherited Create;

  FDiagram := TMermaidClassDiagram.Create;
  FDiagramReference := FDiagram;
  FOpenClass := NoOpenClass;
end;

function TMermaidClassDiagramReader.TryRead(const Lines: TArray<string>; const StartLine: Integer): Boolean;
begin
  for var Index := StartLine to High(Lines) do
  begin
    const Line = Trim(Lines[Index]);
    if IsSkippedLine(Line) then
      Continue;

    if not TryParseLine(Line) then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := (FOpenClass = NoOpenClass);
end;

function TMermaidClassDiagramReader.TryParseLine(const Line: string): Boolean;
begin
  if FOpenClass <> NoOpenClass then
    Result := TryParseBodyLine(Line)
  else
    Result := TryParseStatement(Line);
end;

function TMermaidClassDiagramReader.TryParseBodyLine(const Line: string): Boolean;
begin
  if not Line.EndsWith(BlockClose) then
  begin
    Result := TryAddBodyEntry(FOpenClass, Line);
    Exit;
  end;

  const LastEntry = Trim(Copy(Line, 1, Length(Line) - Length(BlockClose)));
  const ClassIndex = FOpenClass;
  FOpenClass := NoOpenClass;

  Result := (LastEntry = '') or TryAddBodyEntry(ClassIndex, LastEntry);
end;

function TMermaidClassDiagramReader.TryAddBodyEntry(const ClassIndex: Integer; const Entry: string): Boolean;
begin
  var Annotation: string;
  var Rest: string;
  if TryReadAnnotation(Entry, Annotation, Rest) then
  begin
    if Rest <> '' then
    begin
      Result := False;
      Exit;
    end;

    FDiagram.ClassAt(ClassIndex).Annotation := Annotation;

    Result := True;
    Exit;
  end;

  Result := TryAddMember(ClassIndex, Entry);
end;

function TMermaidClassDiagramReader.TryParseStatement(const Line: string): Boolean;
begin
  var Rest: string;
  if StartsWithKeyword(Line, DirectionKeyword, Rest) then
    Result := TryParseDirection(Rest)
  else if StartsWithKeyword(Line, ClassKeyword, Rest) then
    Result := TryParseClassDeclaration(Rest)
  else if Line.StartsWith(AnnotationOpen) then
    Result := TryParseAnnotationStatement(Line)
  else if IsIgnoredStatement(Line) then
    Result := True
  else
    Result := TryParseClassReferenceStatement(Line);
end;

function TMermaidClassDiagramReader.TryParseDirection(const Value: string): Boolean;
begin
  var Direction: TMermaidDirection;
  if not TMermaidDirection.TryParse(Value, Direction) then
  begin
    Result := False;
    Exit;
  end;

  FDiagram.Direction := Direction;

  Result := True;
end;

function TMermaidClassDiagramReader.TryParseClassDeclaration(const Declaration: string): Boolean;
begin
  var Index := 1;

  var Id: string;
  var Generic: string;
  if not TryReadClassName(Declaration, Index, Id, Generic) then
  begin
    Result := False;
    Exit;
  end;

  var Caption: string;
  if not TryReadLabel(Declaration, Index, Caption) then
  begin
    Result := False;
    Exit;
  end;

  SkipStyleSuffix(Declaration, Index);
  SkipSpaces(Declaration, Index);

  var ClassIndex: Integer;
  if not FDiagram.TryEnsureClass(Id, ClassIndex) then
  begin
    Result := False;
    Exit;
  end;

  const Declared = FDiagram.ClassAt(ClassIndex);
  if Caption <> '' then
    Declared.Caption := Caption
  else
    Declared.Caption := Id + Generic;

  const Remainder = Copy(Declaration, Index, MaxInt);
  if Remainder = '' then
  begin
    Result := True;
    Exit;
  end;

  if not Remainder.StartsWith(BlockOpen) then
  begin
    Result := False;
    Exit;
  end;

  Result := TryOpenClassBlock(ClassIndex, Trim(Copy(Remainder, Length(BlockOpen) + 1, MaxInt)));
end;

function TMermaidClassDiagramReader.TryOpenClassBlock(const ClassIndex: Integer; const Remainder: string): Boolean;
begin
  FOpenClass := ClassIndex;

  if Remainder = '' then
  begin
    Result := True;
    Exit;
  end;

  Result := TryParseBodyLine(Remainder);
end;

function TMermaidClassDiagramReader.TryParseAnnotationStatement(const Line: string): Boolean;
begin
  var Annotation: string;
  var Rest: string;
  if not TryReadAnnotation(Line, Annotation, Rest) then
  begin
    Result := False;
    Exit;
  end;

  var Index := 1;
  var ClassIndex: Integer;
  if not TryReferenceClass(Rest, Index, ClassIndex) then
  begin
    Result := False;
    Exit;
  end;

  SkipSpaces(Rest, Index);
  if Index <= Length(Rest) then
  begin
    Result := False;
    Exit;
  end;

  FDiagram.ClassAt(ClassIndex).Annotation := Annotation;

  Result := True;
end;

function TMermaidClassDiagramReader.TryParseClassReferenceStatement(const Line: string): Boolean;
begin
  var Index := 1;
  var SourceIndex: Integer;
  if not TryReferenceClass(Line, Index, SourceIndex) then
  begin
    Result := False;
    Exit;
  end;

  SkipSpaces(Line, Index);

  const IsMemberStatement = (Index <= Length(Line)) and (Line[Index] = LabelSeparator);
  if IsMemberStatement then
  begin
    Result := TryAddMember(SourceIndex, Copy(Line, Index + 1, MaxInt));
    Exit;
  end;

  Result := TryParseRelation(Line, Index, SourceIndex);
end;

function TMermaidClassDiagramReader.TryParseRelation(const Line: string; var Index: Integer;
  const SourceIndex: Integer): Boolean;
begin
  var SourceCardinality: string;
  if not TryReadQuoted(Line, Index, SourceCardinality) then
  begin
    Result := False;
    Exit;
  end;

  SkipSpaces(Line, Index);

  var SourceEnd: TMermaidRelationEnd;
  var RelationLine: TMermaidRelationLine;
  var TargetEnd: TMermaidRelationEnd;
  if not TryReadArrow(Line, Index, SourceEnd, RelationLine, TargetEnd) then
  begin
    Result := False;
    Exit;
  end;

  SkipSpaces(Line, Index);

  var TargetCardinality: string;
  if not TryReadQuoted(Line, Index, TargetCardinality) then
  begin
    Result := False;
    Exit;
  end;

  SkipSpaces(Line, Index);

  var TargetIndex: Integer;
  if not TryReferenceClass(Line, Index, TargetIndex) then
  begin
    Result := False;
    Exit;
  end;

  SkipSpaces(Line, Index);

  var Caption := '';
  if Index <= Length(Line) then
  begin
    if Line[Index] <> LabelSeparator then
    begin
      Result := False;
      Exit;
    end;

    Caption := Trim(Copy(Line, Index + 1, MaxInt));
  end;

  const Source = TMermaidRelationEndpoint.Create(SourceIndex, SourceEnd, SourceCardinality);
  const Target = TMermaidRelationEndpoint.Create(TargetIndex, TargetEnd, TargetCardinality);
  FDiagram.AddRelation(Source, Target, RelationLine, Caption);

  Result := True;
end;

// A member reads "[visibility]signature[ return type][classifier]". A method
// is told apart from an attribute by its parentheses; whatever follows the
// closing one is the return type, as mermaid writes it, with or without a
// colon in front. The classifier may also sit right after the parentheses,
// before the return type.
function TMermaidClassDiagramReader.TryAddMember(const ClassIndex: Integer; const Text: string): Boolean;
begin
  var Body := Trim(Text);

  var Visibility := TMermaidClassVisibility.None;
  if (Body <> '') and TMermaidClassMember.TryVisibilityOf(Body[1], Visibility) then
    Body := Trim(Copy(Body, 2, MaxInt));

  var Classifier := ClassifierOf(Copy(Body, Length(Body), 1));
  if Classifier <> TMermaidClassClassifier.None then
    Body := Trim(Copy(Body, 1, Length(Body) - 1));

  if Body = '' then
  begin
    Result := False;
    Exit;
  end;

  const OpenParenthesis = Pos('(', Body);
  const CloseParenthesis = Body.LastIndexOf(')') + 1;
  const IsMethod = (OpenParenthesis > 0) and (CloseParenthesis > OpenParenthesis);

  var Signature := Body;
  var ReturnType := '';
  if IsMethod then
  begin
    Signature := Copy(Body, 1, CloseParenthesis);
    ReturnType := Trim(Copy(Body, CloseParenthesis + 1, MaxInt));

    const LeadingClassifier = ClassifierOf(Copy(ReturnType, 1, 1));
    if (Classifier = TMermaidClassClassifier.None) and (LeadingClassifier <> TMermaidClassClassifier.None) then
    begin
      Classifier := LeadingClassifier;
      ReturnType := Trim(Copy(ReturnType, 2, MaxInt));
    end;

    if ReturnType.StartsWith(LabelSeparator) then
      ReturnType := Trim(Copy(ReturnType, 2, MaxInt));
  end;

  const Member: IMermaidClassMember = TMermaidClassMember.Create(Visibility, ConvertGenerics(Signature),
    ConvertGenerics(ReturnType), Classifier);

  const Owner = FDiagram.ClassAt(ClassIndex);
  if IsMethod then
    Owner.AddMethod(Member)
  else
    Owner.AddAttribute(Member);

  Result := True;
end;

function TMermaidClassDiagramReader.TryReferenceClass(const Line: string; var Index: Integer;
  out ClassIndex: Integer): Boolean;
begin
  ClassIndex := NoOpenClass;

  var Id: string;
  var Generic: string;
  if not TryReadClassName(Line, Index, Id, Generic) then
  begin
    Result := False;
    Exit;
  end;

  SkipStyleSuffix(Line, Index);

  if not FDiagram.TryEnsureClass(Id, ClassIndex) then
  begin
    Result := False;
    Exit;
  end;

  if Generic <> '' then
    FDiagram.ClassAt(ClassIndex).Caption := Id + Generic;

  Result := True;
end;

class function TMermaidClassDiagramReader.ClassifierOf(const Marker: string): TMermaidClassClassifier;
begin
  if Marker = StaticMarker then
    Result := TMermaidClassClassifier.Static
  else if Marker = AbstractMarker then
    Result := TMermaidClassClassifier.Abstract
  else
    Result := TMermaidClassClassifier.None;
end;

class function TMermaidClassDiagramReader.IsSkippedLine(const Line: string): Boolean;
begin
  Result := (Line = '') or Line.StartsWith(CommentMarker);
end;

class function TMermaidClassDiagramReader.IsIgnoredStatement(const Line: string): Boolean;
begin
  for var Keyword in IgnoredKeywords do
  begin
    var Rest: string;
    if StartsWithKeyword(Line, Keyword, Rest) and (Rest <> '') then
    begin
      Result := True;
      Exit;
    end;
  end;

  for var Keyword in AccessibilityKeywords do
  begin
    if Line.StartsWith(Keyword + ':') then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class function TMermaidClassDiagramReader.StartsWithKeyword(const Line, Keyword: string; out Rest: string): Boolean;
begin
  Rest := '';

  const HasKeyword = Line.StartsWith(Keyword) and (Length(Line) > Length(Keyword)) and
    CharInSet(Line[Length(Keyword) + 1], [' ', Tabulator]);
  if not HasKeyword then
  begin
    Result := False;
    Exit;
  end;

  Rest := Trim(Copy(Line, Length(Keyword) + 1, MaxInt));

  Result := True;
end;

class function TMermaidClassDiagramReader.TryReadAnnotation(const Text: string; out Annotation: string;
  out Rest: string): Boolean;
begin
  Annotation := '';
  Rest := '';

  if not Text.StartsWith(AnnotationOpen) then
  begin
    Result := False;
    Exit;
  end;

  const ClosePos = Pos(AnnotationClose, Text, Length(AnnotationOpen) + 1);
  if ClosePos = 0 then
  begin
    Result := False;
    Exit;
  end;

  Annotation := Trim(Copy(Text, Length(AnnotationOpen) + 1, ClosePos - Length(AnnotationOpen) - 1));
  Rest := Trim(Copy(Text, ClosePos + Length(AnnotationClose), MaxInt));

  Result := (Annotation <> '');
end;

// A class name is a run of letters, digits, underscores and single dashes,
// or any text between backticks. A generic parameter follows the name between
// tildes ("Square~Shape~") and comes back as "<Shape>".
class function TMermaidClassDiagramReader.TryReadClassName(const Line: string; var Index: Integer;
  out Id, Generic: string): Boolean;
begin
  Id := '';
  Generic := '';

  if Index > Length(Line) then
  begin
    Result := False;
    Exit;
  end;

  if Line[Index] = '`' then
  begin
    const ClosePos = Pos('`', Line, Index + 1);
    if ClosePos <= Index + 1 then
    begin
      Result := False;
      Exit;
    end;

    Id := Copy(Line, Index + 1, ClosePos - Index - 1);
    Index := ClosePos + 1;
  end
  else
  begin
    const Start = Index;
    while IsNameChar(Line, Index) do
    begin
      Inc(Index);
    end;

    Id := Copy(Line, Start, Index - Start);
    if Id = '' then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := TryReadGeneric(Line, Index, Generic);
end;

class function TMermaidClassDiagramReader.TryReadGeneric(const Line: string; var Index: Integer;
  out Generic: string): Boolean;
begin
  Generic := '';

  if (Index > Length(Line)) or (Line[Index] <> '~') then
  begin
    Result := True;
    Exit;
  end;

  const Start = Index;
  while (Index <= Length(Line)) and not CharInSet(Line[Index], [' ', Tabulator, '{', '[', ':', '"']) do
  begin
    Inc(Index);
  end;

  const Part = Copy(Line, Start, Index - Start);
  if (Length(Part) < 3) or not Part.EndsWith('~') then
  begin
    Result := False;
    Exit;
  end;

  const Parameters = ConvertGenerics(Copy(Part, 2, Length(Part) - 2));
  Generic := Format('<%s>', [Parameters]);

  Result := True;
end;

class function TMermaidClassDiagramReader.TryReadLabel(const Line: string; var Index: Integer;
  out Caption: string): Boolean;
begin
  Caption := '';

  if (Index > Length(Line)) or (Line[Index] <> '[') then
  begin
    Result := True;
    Exit;
  end;

  const ClosePos = Pos(']', Line, Index + 1);
  if ClosePos = 0 then
  begin
    Result := False;
    Exit;
  end;

  var Inner := Trim(Copy(Line, Index + 1, ClosePos - Index - 1));
  if (Length(Inner) >= 2) and Inner.StartsWith('"') and Inner.EndsWith('"') then
    Inner := Copy(Inner, 2, Length(Inner) - 2);

  Caption := Inner;
  Index := ClosePos + 1;

  Result := True;
end;

class function TMermaidClassDiagramReader.TryReadQuoted(const Line: string; var Index: Integer;
  out Text: string): Boolean;
begin
  Text := '';

  if (Index > Length(Line)) or (Line[Index] <> '"') then
  begin
    Result := True;
    Exit;
  end;

  const ClosePos = Pos('"', Line, Index + 1);
  if ClosePos = 0 then
  begin
    Result := False;
    Exit;
  end;

  Text := Copy(Line, Index + 1, ClosePos - Index - 1);
  Index := ClosePos + 1;

  Result := True;
end;

// An arrow is an optional marker, a solid "--" or dashed ".." line and an
// optional marker, so "<|--", "..|>", "*--" and "<-->" are all one shape.
class function TMermaidClassDiagramReader.TryReadArrow(const Line: string; var Index: Integer;
  out SourceEnd: TMermaidRelationEnd; out RelationLine: TMermaidRelationLine;
  out TargetEnd: TMermaidRelationEnd): Boolean;
begin
  SourceEnd := ReadSourceEnd(Line, Index);
  TargetEnd := TMermaidRelationEnd.None;
  RelationLine := TMermaidRelationLine.Solid;

  if MatchToken(Line, Index, '--') then
    RelationLine := TMermaidRelationLine.Solid
  else if MatchToken(Line, Index, '..') then
    RelationLine := TMermaidRelationLine.Dashed
  else
  begin
    Result := False;
    Exit;
  end;

  TargetEnd := ReadTargetEnd(Line, Index);

  Result := True;
end;

class function TMermaidClassDiagramReader.ReadSourceEnd(const Line: string; var Index: Integer): TMermaidRelationEnd;
begin
  const IsAggregation = (Copy(Line, Index, 2) = 'o-') or (Copy(Line, Index, 2) = 'o.');

  if MatchToken(Line, Index, '<|') then
    Result := TMermaidRelationEnd.Inheritance
  else if MatchToken(Line, Index, '*') then
    Result := TMermaidRelationEnd.Composition
  else if IsAggregation and MatchToken(Line, Index, 'o') then
    Result := TMermaidRelationEnd.Aggregation
  else if MatchToken(Line, Index, '<') then
    Result := TMermaidRelationEnd.Arrow
  else
    Result := TMermaidRelationEnd.None;
end;

class function TMermaidClassDiagramReader.ReadTargetEnd(const Line: string; var Index: Integer): TMermaidRelationEnd;
begin
  const IsAggregation = (Copy(Line, Index, 1) = 'o') and not IsNameChar(Line, Index + 1);

  if MatchToken(Line, Index, '|>') then
    Result := TMermaidRelationEnd.Inheritance
  else if MatchToken(Line, Index, '*') then
    Result := TMermaidRelationEnd.Composition
  else if IsAggregation and MatchToken(Line, Index, 'o') then
    Result := TMermaidRelationEnd.Aggregation
  else if MatchToken(Line, Index, '>') then
    Result := TMermaidRelationEnd.Arrow
  else
    Result := TMermaidRelationEnd.None;
end;

class procedure TMermaidClassDiagramReader.SkipStyleSuffix(const Line: string; var Index: Integer);
begin
  if not MatchToken(Line, Index, StyleSuffix) then
    Exit;

  while IsNameChar(Line, Index) do
  begin
    Inc(Index);
  end;
end;

class procedure TMermaidClassDiagramReader.SkipSpaces(const Line: string; var Index: Integer);
begin
  while (Index <= Length(Line)) and CharInSet(Line[Index], [' ', Tabulator]) do
  begin
    Inc(Index);
  end;
end;

class function TMermaidClassDiagramReader.MatchToken(const Line: string; var Index: Integer;
  const Token: string): Boolean;
begin
  if Copy(Line, Index, Length(Token)) = Token then
  begin
    Inc(Index, Length(Token));

    Result := True;
    Exit;
  end;

  Result := False;
end;

// A dash belongs to a name only between two name characters, so "Tree-Node"
// is one name while the dashes of "A-->B" start an arrow.
class function TMermaidClassDiagramReader.IsNameChar(const Line: string; const Index: Integer): Boolean;
begin
  if (Index < 1) or (Index > Length(Line)) then
  begin
    Result := False;
    Exit;
  end;

  const Current = Line[Index];
  if Current.IsLetterOrDigit or (Current = '_') then
  begin
    Result := True;
    Exit;
  end;

  const IsInnerDash = (Current = '-') and (Index > 1) and (Index < Length(Line)) and
    (Line[Index - 1].IsLetterOrDigit or (Line[Index - 1] = '_')) and Line[Index + 1].IsLetterOrDigit;
  Result := IsInnerDash;
end;

// Mermaid writes generics with tildes: "List~int~" and, nested,
// "List~List~int~~". A tilde between two name characters opens a parameter
// list and any other tilde closes the innermost one; text whose tildes do not
// pair up that way is left as written.
class function TMermaidClassDiagramReader.ConvertGenerics(const Text: string): string;
begin
  var Converted := Text;
  var Depth := 0;

  for var Index := 1 to Length(Converted) do
  begin
    if Converted[Index] <> '~' then
      Continue;

    const Opens = (Index > 1) and IsNameChar(Text, Index - 1) and IsNameChar(Text, Index + 1);
    if Opens then
    begin
      Converted[Index] := '<';
      Inc(Depth);
    end
    else if Depth > 0 then
    begin
      Converted[Index] := '>';
      Dec(Depth);
    end
    else
    begin
      Result := Text;
      Exit;
    end;
  end;

  if Depth <> 0 then
  begin
    Result := Text;
    Exit;
  end;

  Result := Converted;
end;

end.
