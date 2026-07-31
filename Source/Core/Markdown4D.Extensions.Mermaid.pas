unit Markdown4D.Extensions.Mermaid;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces;

type
  TMermaidDiagramKind = (Flowchart, Sequence, Pie);

  TMermaidDirection = (TB, TD, LR, BT, RL);

  TMermaidNodeShape = (Rectangle, Rounded, Stadium, Circle, Diamond);

  TMermaidEdgeStroke = (Solid, Dashed, Thick);

  TMermaidMessageLine = (Solid, Dashed);

  TMermaidMessageHead = (Arrow, Open, Cross);

  TMermaidNotePlacement = (LeftOf, RightOf, Over);

  IMermaidNode = interface
    ['{6B1F2C08-9A34-4D57-8E20-71C4B5D0A9E3}']
    function GetId: string;
    function GetCaption: string;
    function GetShape: TMermaidNodeShape;
    property Id: string read GetId;
    property Caption: string read GetCaption;
    property Shape: TMermaidNodeShape read GetShape;
  end;

  IMermaidEdge = interface
    ['{2E7A9D41-5C08-4B36-9F12-83D0A6C4E5B7}']
    function GetSourceIndex: Integer;
    function GetTargetIndex: Integer;
    function GetCaption: string;
    function GetStroke: TMermaidEdgeStroke;
    function GetHasArrowHead: Boolean;
    property SourceIndex: Integer read GetSourceIndex;
    property TargetIndex: Integer read GetTargetIndex;
    property Caption: string read GetCaption;
    property Stroke: TMermaidEdgeStroke read GetStroke;
    property HasArrowHead: Boolean read GetHasArrowHead;
  end;

  IMermaidParticipant = interface
    ['{9D4C6B02-1E58-4A73-8C09-52F1B7E3D6A4}']
    function GetId: string;
    function GetCaption: string;
    function GetIsActor: Boolean;
    property Id: string read GetId;
    property Caption: string read GetCaption;
    property IsActor: Boolean read GetIsActor;
  end;

  IMermaidMessage = interface
    ['{4A0E7C61-8B29-4D50-9F73-16C5D2A8E0B4}']
    function GetSourceIndex: Integer;
    function GetTargetIndex: Integer;
    function GetCaption: string;
    function GetLine: TMermaidMessageLine;
    function GetHead: TMermaidMessageHead;
    function GetActivate: Boolean;
    function GetDeactivate: Boolean;
    property SourceIndex: Integer read GetSourceIndex;
    property TargetIndex: Integer read GetTargetIndex;
    property Caption: string read GetCaption;
    property Line: TMermaidMessageLine read GetLine;
    property Head: TMermaidMessageHead read GetHead;
    property Activate: Boolean read GetActivate;
    property Deactivate: Boolean read GetDeactivate;
  end;

  IMermaidNote = interface
    ['{7C3A5D18-6E42-4B09-8F51-90D2C6A4E7B3}']
    function GetPlacement: TMermaidNotePlacement;
    function GetText: string;
    function GetFromIndex: Integer;
    function GetToIndex: Integer;
    property Placement: TMermaidNotePlacement read GetPlacement;
    property Text: string read GetText;
    property FromIndex: Integer read GetFromIndex;
    property ToIndex: Integer read GetToIndex;
  end;

  IMermaidSlice = interface
    ['{1D8B4E70-3C19-4A62-9E05-74F2A6C8D5B0}']
    function GetCaption: string;
    function GetValue: Double;
    property Caption: string read GetCaption;
    property Value: Double read GetValue;
  end;

  // What a diagram of any kind carries. The three views below add what one
  // kind of diagram needs, so a layout builder sees the part of the model it
  // draws and nothing else.
  IMermaidDiagram = interface
    ['{0A5E7C93-2D46-4F81-9B7A-5C1E8D3F60A4}']
    function GetDiagramKind: TMermaidDiagramKind;
    function GetTitle: string;
    property DiagramKind: TMermaidDiagramKind read GetDiagramKind;
    property Title: string read GetTitle;
  end;

  IMermaidGraph = interface(IMermaidDiagram)
    ['{1B6F8DA4-3E57-4092-8C0B-6D2F9E4A71B5}']
    function GetDirection: TMermaidDirection;
    function GetNodeCount: Integer;
    function GetNode(const Index: Integer): IMermaidNode;
    function GetEdgeCount: Integer;
    function GetEdge(const Index: Integer): IMermaidEdge;
    property Direction: TMermaidDirection read GetDirection;
    property NodeCount: Integer read GetNodeCount;
    property Nodes[const Index: Integer]: IMermaidNode read GetNode;
    property EdgeCount: Integer read GetEdgeCount;
    property Edges[const Index: Integer]: IMermaidEdge read GetEdge;
  end;

  IMermaidSequence = interface(IMermaidDiagram)
    ['{2C709EB5-4F68-41A3-9D1C-7E30AF5B82C6}']
    function GetParticipantCount: Integer;
    function GetParticipant(const Index: Integer): IMermaidParticipant;
    function GetMessageCount: Integer;
    function GetMessage(const Index: Integer): IMermaidMessage;
    function GetNoteCount: Integer;
    function GetNote(const Index: Integer): IMermaidNote;
    property ParticipantCount: Integer read GetParticipantCount;
    property Participants[const Index: Integer]: IMermaidParticipant read GetParticipant;
    property MessageCount: Integer read GetMessageCount;
    property Messages[const Index: Integer]: IMermaidMessage read GetMessage;
    property NoteCount: Integer read GetNoteCount;
    property Notes[const Index: Integer]: IMermaidNote read GetNote;
  end;

  IMermaidPie = interface(IMermaidDiagram)
    ['{3D81AFC6-5079-42B4-8E2D-8F41B06C93D7}']
    function GetSliceCount: Integer;
    function GetSlice(const Index: Integer): IMermaidSlice;
    property SliceCount: Integer read GetSliceCount;
    property Slices[const Index: Integer]: IMermaidSlice read GetSlice;
  end;

  IMermaidModel = interface
    ['{8F2C6A14-5B70-4D39-8E01-63A5D0C7B4E2}']
    function GetDiagramKind: TMermaidDiagramKind;
    function GetDirection: TMermaidDirection;
    function GetTitle: string;
    function GetNodeCount: Integer;
    function GetNode(const Index: Integer): IMermaidNode;
    function GetEdgeCount: Integer;
    function GetEdge(const Index: Integer): IMermaidEdge;
    function GetParticipantCount: Integer;
    function GetParticipant(const Index: Integer): IMermaidParticipant;
    function GetMessageCount: Integer;
    function GetMessage(const Index: Integer): IMermaidMessage;
    function GetNoteCount: Integer;
    function GetNote(const Index: Integer): IMermaidNote;
    function GetSliceCount: Integer;
    function GetSlice(const Index: Integer): IMermaidSlice;
    property DiagramKind: TMermaidDiagramKind read GetDiagramKind;
    property Direction: TMermaidDirection read GetDirection;
    property Title: string read GetTitle;
    property NodeCount: Integer read GetNodeCount;
    property Nodes[const Index: Integer]: IMermaidNode read GetNode;
    property EdgeCount: Integer read GetEdgeCount;
    property Edges[const Index: Integer]: IMermaidEdge read GetEdge;
    property ParticipantCount: Integer read GetParticipantCount;
    property Participants[const Index: Integer]: IMermaidParticipant read GetParticipant;
    property MessageCount: Integer read GetMessageCount;
    property Messages[const Index: Integer]: IMermaidMessage read GetMessage;
    property NoteCount: Integer read GetNoteCount;
    property Notes[const Index: Integer]: IMermaidNote read GetNote;
    property SliceCount: Integer read GetSliceCount;
    property Slices[const Index: Integer]: IMermaidSlice read GetSlice;
  end;

  TMermaidExtension = class(TInterfacedObject, IMarkdownExtension)
  private
    class function IsMermaidInfoString(const InfoString: string): Boolean;
  public
    const
      MermaidInfoString = 'mermaid';
      MermaidModelExtensionKey = 'markdown4d.mermaid.model';
      MermaidProcessorPriority = TMarkdownPriorities.ExtensionProcessor;
      MaxNodeCount = 500;
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
    class function IsMermaidCodeBlock(const Node: IMarkdownNode): Boolean;
    class function TryParse(const Code: IMarkdownCodeBlock; out Model: IMermaidModel): Boolean;
    class function TryGetModel(const Node: IMarkdownNode; out Model: IMermaidModel): Boolean;
    class function CreateDocumentProcessor: IMarkdownDocumentProcessor;
    class procedure Process(const Document: IMarkdownDocument);
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Generics.Collections;

type
  TMermaidNode = class(TInterfacedObject, IMermaidNode)
  private
    FId: string;
    FCaption: string;
    FShape: TMermaidNodeShape;
    function GetId: string;
    function GetCaption: string;
    function GetShape: TMermaidNodeShape;

  public
    constructor Create(const Id, Caption: string; const Shape: TMermaidNodeShape);
  end;

  TMermaidEdge = class(TInterfacedObject, IMermaidEdge)
  private
    FSourceIndex: Integer;
    FTargetIndex: Integer;
    FCaption: string;
    FStroke: TMermaidEdgeStroke;
    FHasArrowHead: Boolean;
    function GetSourceIndex: Integer;
    function GetTargetIndex: Integer;
    function GetCaption: string;
    function GetStroke: TMermaidEdgeStroke;
    function GetHasArrowHead: Boolean;

  public
    constructor Create(const SourceIndex, TargetIndex: Integer; const Caption: string;
      const Stroke: TMermaidEdgeStroke; const HasArrowHead: Boolean);
  end;

  TMermaidParticipant = class(TInterfacedObject, IMermaidParticipant)
  private
    FId: string;
    FCaption: string;
    FIsActor: Boolean;
    function GetId: string;
    function GetCaption: string;
    function GetIsActor: Boolean;

  public
    constructor Create(const Id, Caption: string; const IsActor: Boolean);
  end;

  TMermaidMessage = class(TInterfacedObject, IMermaidMessage)
  private
    FSourceIndex: Integer;
    FTargetIndex: Integer;
    FCaption: string;
    FLine: TMermaidMessageLine;
    FHead: TMermaidMessageHead;
    FActivate: Boolean;
    FDeactivate: Boolean;
    function GetSourceIndex: Integer;
    function GetTargetIndex: Integer;
    function GetCaption: string;
    function GetLine: TMermaidMessageLine;
    function GetHead: TMermaidMessageHead;
    function GetActivate: Boolean;
    function GetDeactivate: Boolean;

  public
    constructor Create(const SourceIndex, TargetIndex: Integer; const Caption: string;
      const Line: TMermaidMessageLine; const Head: TMermaidMessageHead; const Activate, Deactivate: Boolean);
  end;

  TMermaidNote = class(TInterfacedObject, IMermaidNote)
  private
    FPlacement: TMermaidNotePlacement;
    FText: string;
    FFromIndex: Integer;
    FToIndex: Integer;
    function GetPlacement: TMermaidNotePlacement;
    function GetText: string;
    function GetFromIndex: Integer;
    function GetToIndex: Integer;

  public
    constructor Create(const Placement: TMermaidNotePlacement; const Text: string; const FromIndex, ToIndex: Integer);
  end;

  TMermaidSlice = class(TInterfacedObject, IMermaidSlice)
  private
    FCaption: string;
    FValue: Double;
    function GetCaption: string;
    function GetValue: Double;

  public
    constructor Create(const Caption: string; const Value: Double);
  end;

  TMermaidModel = class(TInterfacedObject, IMermaidModel, IMermaidGraph, IMermaidSequence,
    IMermaidPie)
  private
    FDiagramKind: TMermaidDiagramKind;
    FDirection: TMermaidDirection;
    FTitle: string;
    FNodes: TList<IMermaidNode>;
    FNodeIndex: TDictionary<string, Integer>;
    FEdges: TList<IMermaidEdge>;
    FParticipants: TList<IMermaidParticipant>;
    FParticipantIndex: TDictionary<string, Integer>;
    FMessages: TList<IMermaidMessage>;
    FNotes: TList<IMermaidNote>;
    FSlices: TList<IMermaidSlice>;
    function GetDiagramKind: TMermaidDiagramKind;
    function GetDirection: TMermaidDirection;
    function GetTitle: string;
    function GetNodeCount: Integer;
    function GetNode(const Index: Integer): IMermaidNode;
    function GetEdgeCount: Integer;
    function GetEdge(const Index: Integer): IMermaidEdge;
    function GetParticipantCount: Integer;
    function GetParticipant(const Index: Integer): IMermaidParticipant;
    function GetMessageCount: Integer;
    function GetMessage(const Index: Integer): IMermaidMessage;
    function GetNoteCount: Integer;
    function GetNote(const Index: Integer): IMermaidNote;
    function GetSliceCount: Integer;
    function GetSlice(const Index: Integer): IMermaidSlice;

  public
    constructor Create;
    destructor Destroy; override;
    function TryEnsureNode(const Id: string; const Shape: TMermaidNodeShape; const Caption: string;
      const Explicit: Boolean; out Index: Integer): Boolean;
    procedure AddEdge(const SourceIndex, TargetIndex: Integer; const Caption: string;
      const Stroke: TMermaidEdgeStroke; const HasArrowHead: Boolean);
    function EnsureParticipant(const Id, Caption: string; const IsActor: Boolean): Integer;
    procedure AddMessage(const SourceIndex, TargetIndex: Integer; const Caption: string;
      const Line: TMermaidMessageLine; const Head: TMermaidMessageHead; const Activate, Deactivate: Boolean);
    procedure AddNote(const Placement: TMermaidNotePlacement; const Text: string; const FromIndex, ToIndex: Integer);
    procedure AddSlice(const Caption: string; const Value: Double);
  end;

  TMermaidParser = class
  public
    class function TryBuild(const Literal: string; out Model: IMermaidModel): Boolean;
  private
    const
      ParticipantKeyword = 'participant ';
      ActorKeyword = 'actor ';
      NoteKeyword = 'Note ';
      NoteLeftPlacement = 'left of ';
      NoteRightPlacement = 'right of ';
      NoteOverPlacement = 'over ';
      TitleKeyword = 'title ';
    class function SplitLines(const Value: string): TArray<string>;
    class function FirstToken(const Value: string; out Rest: string): string;
    class function TryDirection(const Value: string; out Direction: TMermaidDirection): Boolean;
    class procedure SkipSpaces(const Line: string; var Index: Integer);
    class function MatchToken(const Line: string; var Index: Integer; const Token: string): Boolean;
    class function TryReadIdentifier(const Line: string; var Index: Integer; out Id: string): Boolean;
    class function TryReadEnclosed(const Line: string; var Index: Integer; const OpenToken, CloseToken: string;
      const ShapeKind: TMermaidNodeShape; out Shape: TMermaidNodeShape; out Caption: string; out HasShape: Boolean): Boolean;
    class function TryReadShape(const Line: string; var Index: Integer; out Shape: TMermaidNodeShape;
      out Caption: string; out HasShape: Boolean): Boolean;
    class function TryReadEdge(const Line: string; var Index: Integer; out Stroke: TMermaidEdgeStroke;
      out HasArrowHead: Boolean): Boolean;
    class function ReadEdgeLabel(const Line: string; var Index: Integer): string;
    class function TryReadMessageArrow(const Line: string; var Index: Integer; out MessageLine: TMermaidMessageLine;
      out Head: TMermaidMessageHead): Boolean;
    class function TryParseFlowchart(const Lines: TArray<string>; const StartLine: Integer; const HeaderRest: string;
      const Model: TMermaidModel): Boolean;
    class function TryParseFlowchartLine(const Line: string; const Model: TMermaidModel): Boolean;
    class function TryParseSequence(const Lines: TArray<string>; const StartLine: Integer;
      const Model: TMermaidModel): Boolean;
    class function TryDeclareParticipant(const Declaration: string; const IsActor: Boolean;
      const Model: TMermaidModel): Boolean;
    class function TryParseMessage(const Line: string; const Model: TMermaidModel): Boolean;
    class function TryParseNote(const Line: string; const Model: TMermaidModel): Boolean;
    class function TryParsePie(const Lines: TArray<string>; const StartLine: Integer; const HeaderRest: string;
      const Model: TMermaidModel): Boolean;
    class function TryParsePieSlice(const Line: string; const Model: TMermaidModel): Boolean;
  end;

  TMermaidDocumentProcessor = class(TInterfacedObject, IMarkdownDocumentProcessor)
  public
    procedure Process(const Document: IMarkdownDocument);
  end;

constructor TMermaidNode.Create(const Id, Caption: string; const Shape: TMermaidNodeShape);
begin
  inherited Create;

  FId := Id;
  FCaption := Caption;
  FShape := Shape;
end;

function TMermaidNode.GetId: string;
begin
  Result := FId;
end;

function TMermaidNode.GetCaption: string;
begin
  Result := FCaption;
end;

function TMermaidNode.GetShape: TMermaidNodeShape;
begin
  Result := FShape;
end;

constructor TMermaidEdge.Create(const SourceIndex, TargetIndex: Integer; const Caption: string;
  const Stroke: TMermaidEdgeStroke; const HasArrowHead: Boolean);
begin
  inherited Create;

  FSourceIndex := SourceIndex;
  FTargetIndex := TargetIndex;
  FCaption := Caption;
  FStroke := Stroke;
  FHasArrowHead := HasArrowHead;
end;

function TMermaidEdge.GetSourceIndex: Integer;
begin
  Result := FSourceIndex;
end;

function TMermaidEdge.GetTargetIndex: Integer;
begin
  Result := FTargetIndex;
end;

function TMermaidEdge.GetCaption: string;
begin
  Result := FCaption;
end;

function TMermaidEdge.GetStroke: TMermaidEdgeStroke;
begin
  Result := FStroke;
end;

function TMermaidEdge.GetHasArrowHead: Boolean;
begin
  Result := FHasArrowHead;
end;

constructor TMermaidParticipant.Create(const Id, Caption: string; const IsActor: Boolean);
begin
  inherited Create;

  FId := Id;
  FCaption := Caption;
  FIsActor := IsActor;
end;

function TMermaidParticipant.GetId: string;
begin
  Result := FId;
end;

function TMermaidParticipant.GetCaption: string;
begin
  Result := FCaption;
end;

function TMermaidParticipant.GetIsActor: Boolean;
begin
  Result := FIsActor;
end;

constructor TMermaidMessage.Create(const SourceIndex, TargetIndex: Integer; const Caption: string;
  const Line: TMermaidMessageLine; const Head: TMermaidMessageHead; const Activate, Deactivate: Boolean);
begin
  inherited Create;

  FSourceIndex := SourceIndex;
  FTargetIndex := TargetIndex;
  FCaption := Caption;
  FLine := Line;
  FHead := Head;
  FActivate := Activate;
  FDeactivate := Deactivate;
end;

function TMermaidMessage.GetSourceIndex: Integer;
begin
  Result := FSourceIndex;
end;

function TMermaidMessage.GetTargetIndex: Integer;
begin
  Result := FTargetIndex;
end;

function TMermaidMessage.GetCaption: string;
begin
  Result := FCaption;
end;

function TMermaidMessage.GetLine: TMermaidMessageLine;
begin
  Result := FLine;
end;

function TMermaidMessage.GetHead: TMermaidMessageHead;
begin
  Result := FHead;
end;

function TMermaidMessage.GetActivate: Boolean;
begin
  Result := FActivate;
end;

function TMermaidMessage.GetDeactivate: Boolean;
begin
  Result := FDeactivate;
end;

constructor TMermaidNote.Create(const Placement: TMermaidNotePlacement; const Text: string;
  const FromIndex, ToIndex: Integer);
begin
  inherited Create;

  FPlacement := Placement;
  FText := Text;
  FFromIndex := FromIndex;
  FToIndex := ToIndex;
end;

function TMermaidNote.GetPlacement: TMermaidNotePlacement;
begin
  Result := FPlacement;
end;

function TMermaidNote.GetText: string;
begin
  Result := FText;
end;

function TMermaidNote.GetFromIndex: Integer;
begin
  Result := FFromIndex;
end;

function TMermaidNote.GetToIndex: Integer;
begin
  Result := FToIndex;
end;

constructor TMermaidSlice.Create(const Caption: string; const Value: Double);
begin
  inherited Create;

  FCaption := Caption;
  FValue := Value;
end;

function TMermaidSlice.GetCaption: string;
begin
  Result := FCaption;
end;

function TMermaidSlice.GetValue: Double;
begin
  Result := FValue;
end;

constructor TMermaidModel.Create;
begin
  inherited Create;

  FDiagramKind := TMermaidDiagramKind.Flowchart;
  FDirection := TMermaidDirection.TB;
  FNodes := TList<IMermaidNode>.Create;
  FNodeIndex := TDictionary<string, Integer>.Create;
  FEdges := TList<IMermaidEdge>.Create;
  FParticipants := TList<IMermaidParticipant>.Create;
  FParticipantIndex := TDictionary<string, Integer>.Create;
  FMessages := TList<IMermaidMessage>.Create;
  FNotes := TList<IMermaidNote>.Create;
  FSlices := TList<IMermaidSlice>.Create;
end;

destructor TMermaidModel.Destroy;
begin
  FSlices.Free;
  FNotes.Free;
  FMessages.Free;
  FParticipantIndex.Free;
  FParticipants.Free;
  FEdges.Free;
  FNodeIndex.Free;
  FNodes.Free;

  inherited Destroy;
end;

function TMermaidModel.GetDiagramKind: TMermaidDiagramKind;
begin
  Result := FDiagramKind;
end;

function TMermaidModel.GetDirection: TMermaidDirection;
begin
  Result := FDirection;
end;

function TMermaidModel.GetTitle: string;
begin
  Result := FTitle;
end;

function TMermaidModel.GetNodeCount: Integer;
begin
  Result := FNodes.Count;
end;

function TMermaidModel.GetNode(const Index: Integer): IMermaidNode;
begin
  Result := FNodes[Index];
end;

function TMermaidModel.GetEdgeCount: Integer;
begin
  Result := FEdges.Count;
end;

function TMermaidModel.GetEdge(const Index: Integer): IMermaidEdge;
begin
  Result := FEdges[Index];
end;

function TMermaidModel.GetParticipantCount: Integer;
begin
  Result := FParticipants.Count;
end;

function TMermaidModel.GetParticipant(const Index: Integer): IMermaidParticipant;
begin
  Result := FParticipants[Index];
end;

function TMermaidModel.GetMessageCount: Integer;
begin
  Result := FMessages.Count;
end;

function TMermaidModel.GetMessage(const Index: Integer): IMermaidMessage;
begin
  Result := FMessages[Index];
end;

function TMermaidModel.GetNoteCount: Integer;
begin
  Result := FNotes.Count;
end;

function TMermaidModel.GetNote(const Index: Integer): IMermaidNote;
begin
  Result := FNotes[Index];
end;

function TMermaidModel.GetSliceCount: Integer;
begin
  Result := FSlices.Count;
end;

function TMermaidModel.GetSlice(const Index: Integer): IMermaidSlice;
begin
  Result := FSlices[Index];
end;

function TMermaidModel.TryEnsureNode(const Id: string; const Shape: TMermaidNodeShape; const Caption: string;
  const Explicit: Boolean; out Index: Integer): Boolean;
begin
  if FNodeIndex.TryGetValue(Id, Index) then
  begin
    if Explicit then
      FNodes[Index] := TMermaidNode.Create(Id, Caption, Shape);

    Exit(True);
  end;

  if FNodes.Count >= TMermaidExtension.MaxNodeCount then
    Exit(False);

  Index := FNodes.Count;
  FNodes.Add(TMermaidNode.Create(Id, Caption, Shape));
  FNodeIndex.Add(Id, Index);

  Result := True;
end;

procedure TMermaidModel.AddEdge(const SourceIndex, TargetIndex: Integer; const Caption: string;
  const Stroke: TMermaidEdgeStroke; const HasArrowHead: Boolean);
begin
  FEdges.Add(TMermaidEdge.Create(SourceIndex, TargetIndex, Caption, Stroke, HasArrowHead));
end;

function TMermaidModel.EnsureParticipant(const Id, Caption: string; const IsActor: Boolean): Integer;
begin
  if FParticipantIndex.TryGetValue(Id, Result) then
    Exit;

  Result := FParticipants.Count;
  FParticipants.Add(TMermaidParticipant.Create(Id, Caption, IsActor));
  FParticipantIndex.Add(Id, Result);
end;

procedure TMermaidModel.AddMessage(const SourceIndex, TargetIndex: Integer; const Caption: string;
  const Line: TMermaidMessageLine; const Head: TMermaidMessageHead; const Activate, Deactivate: Boolean);
begin
  FMessages.Add(TMermaidMessage.Create(SourceIndex, TargetIndex, Caption, Line, Head, Activate, Deactivate));
end;

procedure TMermaidModel.AddNote(const Placement: TMermaidNotePlacement; const Text: string;
  const FromIndex, ToIndex: Integer);
begin
  FNotes.Add(TMermaidNote.Create(Placement, Text, FromIndex, ToIndex));
end;

procedure TMermaidModel.AddSlice(const Caption: string; const Value: Double);
begin
  FSlices.Add(TMermaidSlice.Create(Caption, Value));
end;

class function TMermaidParser.SplitLines(const Value: string): TArray<string>;
begin
  Result := Value.Split([#10]);

  for var Index := 0 to High(Result) do
  begin
    if Result[Index].EndsWith(#13) then
      Result[Index] := Copy(Result[Index], 1, Length(Result[Index]) - 1);
  end;
end;

class function TMermaidParser.FirstToken(const Value: string; out Rest: string): string;
begin
  const Trimmed = Trim(Value);
  const SpacePos = Pos(' ', Trimmed);

  if SpacePos = 0 then
  begin
    Rest := '';
    Exit(Trimmed);
  end;

  Result := Copy(Trimmed, 1, SpacePos - 1);
  Rest := Trim(Copy(Trimmed, SpacePos + 1, MaxInt));
end;

class function TMermaidParser.TryDirection(const Value: string; out Direction: TMermaidDirection): Boolean;
begin
  const Normalized = UpperCase(Trim(Value));

  if Normalized = 'TB' then
    Direction := TMermaidDirection.TB
  else if Normalized = 'TD' then
    Direction := TMermaidDirection.TD
  else if Normalized = 'LR' then
    Direction := TMermaidDirection.LR
  else if Normalized = 'BT' then
    Direction := TMermaidDirection.BT
  else if Normalized = 'RL' then
    Direction := TMermaidDirection.RL
  else
    Exit(False);

  Result := True;
end;

class procedure TMermaidParser.SkipSpaces(const Line: string; var Index: Integer);
begin
  while (Index <= Length(Line)) and CharInSet(Line[Index], [' ', #9]) do
  begin
    Inc(Index);
  end;
end;

class function TMermaidParser.MatchToken(const Line: string; var Index: Integer; const Token: string): Boolean;
begin
  if Copy(Line, Index, Length(Token)) = Token then
  begin
    Inc(Index, Length(Token));

    Exit(True);
  end;

  Result := False;
end;

class function TMermaidParser.TryReadIdentifier(const Line: string; var Index: Integer; out Id: string): Boolean;
begin
  Id := '';
  if Index > Length(Line) then
    Exit(False);

  if not CharInSet(Line[Index], ['A'..'Z', 'a'..'z', '_']) then
    Exit(False);

  const Start = Index;
  while (Index <= Length(Line)) and CharInSet(Line[Index], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
  begin
    Inc(Index);
  end;

  Id := Copy(Line, Start, Index - Start);

  Result := True;
end;

class function TMermaidParser.TryReadEnclosed(const Line: string; var Index: Integer; const OpenToken, CloseToken: string;
  const ShapeKind: TMermaidNodeShape; out Shape: TMermaidNodeShape; out Caption: string; out HasShape: Boolean): Boolean;
begin
  Shape := ShapeKind;
  Caption := '';
  HasShape := False;

  if Copy(Line, Index, Length(OpenToken)) <> OpenToken then
    Exit(False);

  const ContentStart = Index + Length(OpenToken);
  const ClosePos = PosEx(CloseToken, Line, ContentStart);
  if ClosePos = 0 then
    Exit(False);

  var Inner := Copy(Line, ContentStart, ClosePos - ContentStart);
  if (Length(Inner) >= 2) and (Inner[1] = '"') and (Inner[Length(Inner)] = '"') then
    Inner := Copy(Inner, 2, Length(Inner) - 2);

  Caption := Inner;
  HasShape := True;
  Index := ClosePos + Length(CloseToken);

  Result := True;
end;

class function TMermaidParser.TryReadShape(const Line: string; var Index: Integer; out Shape: TMermaidNodeShape;
  out Caption: string; out HasShape: Boolean): Boolean;
begin
  Shape := TMermaidNodeShape.Rectangle;
  Caption := '';
  HasShape := False;

  if Index > Length(Line) then
    Exit(True);

  case Line[Index] of
    '[':
      Result := TryReadEnclosed(Line, Index, '[', ']', TMermaidNodeShape.Rectangle, Shape, Caption, HasShape);
    '{':
      Result := TryReadEnclosed(Line, Index, '{', '}', TMermaidNodeShape.Diamond, Shape, Caption, HasShape);
    '(':
      begin
        if (Index < Length(Line)) and (Line[Index + 1] = '(') then
          Result := TryReadEnclosed(Line, Index, '((', '))', TMermaidNodeShape.Circle, Shape, Caption, HasShape)
        else if (Index < Length(Line)) and (Line[Index + 1] = '[') then
          Result := TryReadEnclosed(Line, Index, '([', '])', TMermaidNodeShape.Stadium, Shape, Caption, HasShape)
        else
          Result := TryReadEnclosed(Line, Index, '(', ')', TMermaidNodeShape.Rounded, Shape, Caption, HasShape);
      end;
  else
    Result := True;
  end;
end;

class function TMermaidParser.TryReadEdge(const Line: string; var Index: Integer; out Stroke: TMermaidEdgeStroke;
  out HasArrowHead: Boolean): Boolean;
begin
  if MatchToken(Line, Index, '-.->') then
  begin
    Stroke := TMermaidEdgeStroke.Dashed;
    HasArrowHead := True;
    Exit(True);
  end;

  if MatchToken(Line, Index, '-.-') then
  begin
    Stroke := TMermaidEdgeStroke.Dashed;
    HasArrowHead := False;
    Exit(True);
  end;

  if MatchToken(Line, Index, '==>') then
  begin
    Stroke := TMermaidEdgeStroke.Thick;
    HasArrowHead := True;
    Exit(True);
  end;

  if MatchToken(Line, Index, '===') then
  begin
    Stroke := TMermaidEdgeStroke.Thick;
    HasArrowHead := False;
    Exit(True);
  end;

  if MatchToken(Line, Index, '-->') then
  begin
    Stroke := TMermaidEdgeStroke.Solid;
    HasArrowHead := True;
    Exit(True);
  end;

  if MatchToken(Line, Index, '---') then
  begin
    Stroke := TMermaidEdgeStroke.Solid;
    HasArrowHead := False;
    Exit(True);
  end;

  Result := False;
end;

class function TMermaidParser.ReadEdgeLabel(const Line: string; var Index: Integer): string;
begin
  Result := '';
  if (Index > Length(Line)) or (Line[Index] <> '|') then
    Exit;

  const Start = Index + 1;
  const ClosePos = PosEx('|', Line, Start);
  if ClosePos = 0 then
    Exit;

  Result := Copy(Line, Start, ClosePos - Start);
  Index := ClosePos + 1;
end;

class function TMermaidParser.TryReadMessageArrow(const Line: string; var Index: Integer;
  out MessageLine: TMermaidMessageLine; out Head: TMermaidMessageHead): Boolean;
begin
  if MatchToken(Line, Index, '-->>') then
  begin
    MessageLine := TMermaidMessageLine.Dashed;
    Head := TMermaidMessageHead.Arrow;
    Exit(True);
  end;

  if MatchToken(Line, Index, '-->') then
  begin
    MessageLine := TMermaidMessageLine.Dashed;
    Head := TMermaidMessageHead.Open;
    Exit(True);
  end;

  if MatchToken(Line, Index, '--x') then
  begin
    MessageLine := TMermaidMessageLine.Dashed;
    Head := TMermaidMessageHead.Cross;
    Exit(True);
  end;

  if MatchToken(Line, Index, '->>') then
  begin
    MessageLine := TMermaidMessageLine.Solid;
    Head := TMermaidMessageHead.Arrow;
    Exit(True);
  end;

  if MatchToken(Line, Index, '->') then
  begin
    MessageLine := TMermaidMessageLine.Solid;
    Head := TMermaidMessageHead.Open;
    Exit(True);
  end;

  if MatchToken(Line, Index, '-x') then
  begin
    MessageLine := TMermaidMessageLine.Solid;
    Head := TMermaidMessageHead.Cross;
    Exit(True);
  end;

  Result := False;
end;

class function TMermaidParser.TryParseFlowchartLine(const Line: string; const Model: TMermaidModel): Boolean;
begin
  var Index := 1;
  SkipSpaces(Line, Index);

  if Index > Length(Line) then
    Exit(True);

  var PrevId: string;
  if not TryReadIdentifier(Line, Index, PrevId) then
    Exit(False);

  var Shape: TMermaidNodeShape;
  var Caption: string;
  var HasShape: Boolean;
  if not TryReadShape(Line, Index, Shape, Caption, HasShape) then
    Exit(False);

  var EffectiveCaption := PrevId;
  if HasShape and (Caption <> '') then
    EffectiveCaption := Caption;

  var PrevIndex: Integer;
  if not Model.TryEnsureNode(PrevId, Shape, EffectiveCaption, HasShape, PrevIndex) then
    Exit(False);

  SkipSpaces(Line, Index);

  while Index <= Length(Line) do
  begin
    var Stroke: TMermaidEdgeStroke;
    var HasArrowHead: Boolean;
    if not TryReadEdge(Line, Index, Stroke, HasArrowHead) then
      Exit(False);

    const EdgeLabel = ReadEdgeLabel(Line, Index);

    SkipSpaces(Line, Index);

    var NextId: string;
    if not TryReadIdentifier(Line, Index, NextId) then
      Exit(False);

    var NextShape: TMermaidNodeShape;
    var NextCaption: string;
    var NextHasShape: Boolean;
    if not TryReadShape(Line, Index, NextShape, NextCaption, NextHasShape) then
      Exit(False);

    var NextEffectiveCaption := NextId;
    if NextHasShape and (NextCaption <> '') then
      NextEffectiveCaption := NextCaption;

    var NextIndex: Integer;
    if not Model.TryEnsureNode(NextId, NextShape, NextEffectiveCaption, NextHasShape, NextIndex) then
      Exit(False);

    Model.AddEdge(PrevIndex, NextIndex, EdgeLabel, Stroke, HasArrowHead);

    PrevIndex := NextIndex;
    SkipSpaces(Line, Index);
  end;

  Result := True;
end;

class function TMermaidParser.TryParseFlowchart(const Lines: TArray<string>; const StartLine: Integer;
  const HeaderRest: string; const Model: TMermaidModel): Boolean;
begin
  Model.FDiagramKind := TMermaidDiagramKind.Flowchart;

  if Trim(HeaderRest) = '' then
    Model.FDirection := TMermaidDirection.TB
  else if not TryDirection(HeaderRest, Model.FDirection) then
    Exit(False);

  for var Index := StartLine to High(Lines) do
  begin
    if Trim(Lines[Index]) = '' then
      Continue;

    if not TryParseFlowchartLine(Lines[Index], Model) then
      Exit(False);
  end;

  Result := True;
end;

class function TMermaidParser.TryDeclareParticipant(const Declaration: string; const IsActor: Boolean;
  const Model: TMermaidModel): Boolean;
begin
  const Trimmed = Trim(Declaration);
  const AsPos = Pos(' as ', Trimmed);

  var Id := Trimmed;
  var Caption := Trimmed;

  if AsPos > 0 then
  begin
    Id := Trim(Copy(Trimmed, 1, AsPos - 1));
    Caption := Trim(Copy(Trimmed, AsPos + 4, MaxInt));
  end;

  if (Id = '') or (Pos(' ', Id) > 0) then
    Exit(False);

  Model.EnsureParticipant(Id, Caption, IsActor);

  Result := True;
end;

class function TMermaidParser.TryParseMessage(const Line: string; const Model: TMermaidModel): Boolean;
begin
  var Index := 1;
  SkipSpaces(Line, Index);

  var SourceId: string;
  if not TryReadIdentifier(Line, Index, SourceId) then
    Exit(False);

  SkipSpaces(Line, Index);

  var MessageLine: TMermaidMessageLine;
  var Head: TMermaidMessageHead;
  if not TryReadMessageArrow(Line, Index, MessageLine, Head) then
    Exit(False);

  var Activate := False;
  var Deactivate := False;
  if (Index <= Length(Line)) and (Line[Index] = '+') then
  begin
    Activate := True;
    Inc(Index);
  end
  else if (Index <= Length(Line)) and (Line[Index] = '-') then
  begin
    Deactivate := True;
    Inc(Index);
  end;

  SkipSpaces(Line, Index);

  var TargetId: string;
  if not TryReadIdentifier(Line, Index, TargetId) then
    Exit(False);

  SkipSpaces(Line, Index);

  var Caption := '';
  if (Index <= Length(Line)) and (Line[Index] = ':') then
  begin
    Caption := Trim(Copy(Line, Index + 1, MaxInt));
    Index := Length(Line) + 1;
  end
  else if Index <= Length(Line) then
    Exit(False);

  const SourceIndex = Model.EnsureParticipant(SourceId, SourceId, False);
  const TargetIndex = Model.EnsureParticipant(TargetId, TargetId, False);

  Model.AddMessage(SourceIndex, TargetIndex, Caption, MessageLine, Head, Activate, Deactivate);

  Result := True;
end;

class function TMermaidParser.TryParseNote(const Line: string; const Model: TMermaidModel): Boolean;
begin
  const Trimmed = Trim(Line);
  var Rest := Trim(Trimmed.Substring(Length(NoteKeyword)));

  var Placement: TMermaidNotePlacement;
  if Rest.StartsWith(NoteLeftPlacement) then
  begin
    Placement := TMermaidNotePlacement.LeftOf;
    Rest := Rest.Substring(Length(NoteLeftPlacement));
  end
  else if Rest.StartsWith(NoteRightPlacement) then
  begin
    Placement := TMermaidNotePlacement.RightOf;
    Rest := Rest.Substring(Length(NoteRightPlacement));
  end
  else if Rest.StartsWith(NoteOverPlacement) then
  begin
    Placement := TMermaidNotePlacement.Over;
    Rest := Rest.Substring(Length(NoteOverPlacement));
  end
  else
    Exit(False);

  const ColonPos = Pos(':', Rest);
  if ColonPos = 0 then
    Exit(False);

  const TargetsPart = Trim(Copy(Rest, 1, ColonPos - 1));
  const Text = Trim(Copy(Rest, ColonPos + 1, MaxInt));

  const Parts = TargetsPart.Split([',']);
  if Length(Parts) = 0 then
    Exit(False);

  const FromId = Trim(Parts[0]);
  const ToId = Trim(Parts[High(Parts)]);
  if (FromId = '') or (ToId = '') then
    Exit(False);

  const FromIndex = Model.EnsureParticipant(FromId, FromId, False);
  const ToIndex = Model.EnsureParticipant(ToId, ToId, False);

  Model.AddNote(Placement, Text, FromIndex, ToIndex);

  Result := True;
end;

class function TMermaidParser.TryParseSequence(const Lines: TArray<string>; const StartLine: Integer;
  const Model: TMermaidModel): Boolean;
begin
  Model.FDiagramKind := TMermaidDiagramKind.Sequence;

  for var Index := StartLine to High(Lines) do
  begin
    const Trimmed = Trim(Lines[Index]);
    if Trimmed = '' then
      Continue;

    var Ok: Boolean;
    if Trimmed.StartsWith(ParticipantKeyword) then
      Ok := TryDeclareParticipant(Trimmed.Substring(Length(ParticipantKeyword)), False, Model)
    else if Trimmed.StartsWith(ActorKeyword) then
      Ok := TryDeclareParticipant(Trimmed.Substring(Length(ActorKeyword)), True, Model)
    else if Trimmed.StartsWith(NoteKeyword) then
      Ok := TryParseNote(Trimmed, Model)
    else
      Ok := TryParseMessage(Trimmed, Model);

    if not Ok then
      Exit(False);
  end;

  Result := True;
end;

class function TMermaidParser.TryParsePieSlice(const Line: string; const Model: TMermaidModel): Boolean;
begin
  const Trimmed = Trim(Line);
  if (Trimmed = '') or (Trimmed[1] <> '"') then
    Exit(False);

  const ClosePos = PosEx('"', Trimmed, 2);
  if ClosePos = 0 then
    Exit(False);

  const Caption = Copy(Trimmed, 2, ClosePos - 2);

  var Index := ClosePos + 1;
  SkipSpaces(Trimmed, Index);

  if (Index > Length(Trimmed)) or (Trimmed[Index] <> ':') then
    Exit(False);

  const ValueText = Trim(Copy(Trimmed, Index + 1, MaxInt));

  var Value: Double;
  const FormatSettings = TFormatSettings.Invariant;
  if not TryStrToFloat(ValueText, Value, FormatSettings) then
    Exit(False);

  Model.AddSlice(Caption, Value);

  Result := True;
end;

class function TMermaidParser.TryParsePie(const Lines: TArray<string>; const StartLine: Integer;
  const HeaderRest: string; const Model: TMermaidModel): Boolean;
begin
  Model.FDiagramKind := TMermaidDiagramKind.Pie;

  const Rest = Trim(HeaderRest);
  if Rest.StartsWith(TitleKeyword) then
    Model.FTitle := Trim(Rest.Substring(Length(TitleKeyword)))
  else if Rest = 'title' then
    Model.FTitle := ''
  else if Rest <> '' then
    Exit(False);

  for var Index := StartLine to High(Lines) do
  begin
    if Trim(Lines[Index]) = '' then
      Continue;

    if not TryParsePieSlice(Lines[Index], Model) then
      Exit(False);
  end;

  Result := True;
end;

class function TMermaidParser.TryBuild(const Literal: string; out Model: IMermaidModel): Boolean;
begin
  Model := nil;

  const Lines = SplitLines(Literal);

  var HeaderLine := -1;
  for var Index := 0 to High(Lines) do
  begin
    if Trim(Lines[Index]) <> '' then
    begin
      HeaderLine := Index;
      Break;
    end;
  end;

  if HeaderLine < 0 then
    Exit(False);

  var Rest: string;
  const FirstWord = FirstToken(Lines[HeaderLine], Rest);

  const Instance = TMermaidModel.Create;
  var Keep: IMermaidModel := Instance;

  var Ok: Boolean;
  if (FirstWord = 'flowchart') or (FirstWord = 'graph') then
    Ok := TryParseFlowchart(Lines, HeaderLine + 1, Rest, Instance)
  else if FirstWord = 'sequenceDiagram' then
    Ok := TryParseSequence(Lines, HeaderLine + 1, Instance)
  else if FirstWord = 'pie' then
    Ok := TryParsePie(Lines, HeaderLine + 1, Rest, Instance)
  else
    Ok := False;

  if not Ok then
    Exit(False);

  Model := Keep;

  Result := True;
end;

procedure TMermaidDocumentProcessor.Process(const Document: IMarkdownDocument);
begin
  TMermaidExtension.Process(Document);
end;

procedure TMermaidExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterDocumentProcessor(CreateDocumentProcessor, MermaidProcessorPriority);
end;

class function TMermaidExtension.CreateDocumentProcessor: IMarkdownDocumentProcessor;
begin
  Result := TMermaidDocumentProcessor.Create;
end;

class function TMermaidExtension.IsMermaidInfoString(const InfoString: string): Boolean;
begin
  const Trimmed = Trim(InfoString);
  const SpacePos = Pos(' ', Trimmed);

  var FirstWord := Trimmed;
  if SpacePos > 0 then
    FirstWord := Copy(Trimmed, 1, SpacePos - 1);

  Result := SameText(FirstWord, MermaidInfoString);
end;

class function TMermaidExtension.IsMermaidCodeBlock(const Node: IMarkdownNode): Boolean;
begin
  var CachedModel: IMermaidModel;
  if TryGetModel(Node, CachedModel) then
    Exit(True);

  var Code: IMarkdownCodeBlock;
  Result := Supports(Node, IMarkdownCodeBlock, Code) and Code.IsFenced and IsMermaidInfoString(Code.InfoString);
end;

class function TMermaidExtension.TryParse(const Code: IMarkdownCodeBlock; out Model: IMermaidModel): Boolean;
begin
  Model := nil;
  if Code = nil then
    Exit(False);

  Result := TMermaidParser.TryBuild(Code.Literal, Model);
end;

class function TMermaidExtension.TryGetModel(const Node: IMarkdownNode; out Model: IMermaidModel): Boolean;
begin
  Model := nil;
  if Node = nil then
    Exit(False);

  var Data: IInterface;
  Result := Node.TryGetExtensionData(MermaidModelExtensionKey, Data) and Supports(Data, IMermaidModel, Model);
end;

class procedure TMermaidExtension.Process(const Document: IMarkdownDocument);
begin
  if Document = nil then
    Exit;

  const DocumentEnd = Document.Segment.EndOffset;

  const Pending = TStack<IMarkdownNode>.Create;
  try
    for var Index := Document.ChildCount - 1 downto 0 do
    begin
      Pending.Push(Document.Children[Index]);
    end;

    while Pending.Count > 0 do
    begin
      const Node = Pending.Pop;

      var Code: IMarkdownCodeBlock;
      if Supports(Node, IMarkdownCodeBlock, Code) and Code.IsFenced and IsMermaidInfoString(Code.InfoString) then
      begin
        const IsClosedFence = Code.Segment.EndOffset < DocumentEnd;
        if IsClosedFence then
        begin
          var Model: IMermaidModel;
          if TryParse(Code, Model) then
            Node.SetExtensionData(MermaidModelExtensionKey, Model);
        end;
      end;

      for var Index := Node.ChildCount - 1 downto 0 do
      begin
        Pending.Push(Node.Children[Index]);
      end;
    end;
  finally
    Pending.Free;
  end;
end;

end.
