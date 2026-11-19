unit Markdown4D.Extensions.Mermaid.LayeredLayout;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Extensions.Mermaid;

type
  TMermaidNodeBox = record
    X: Single;
    Y: Single;
    Width: Single;
    Height: Single;
    Rank: Integer;
    function Center: TLayoutPointF;
    function Bounds: TLayoutRectF;
    function BorderPoint(const Toward: TLayoutPointF): TLayoutPointF;
  end;

  // An edge as the ranking sees it: from the node that goes on the earlier
  // rank to the one on the later rank. MinimumGap is the room it needs
  // between those two ranks, for a label or the markers at its ends.
  TMermaidLayeredEdge = record
    Source: Integer;
    Target: Integer;
    MinimumGap: Single;
    class function Create(const Source, Target: Integer; const MinimumGap: Single): TMermaidLayeredEdge; static;
  end;

  TMermaidBaryKey = record
    Bary: Double;
    Node: Integer;
    Ordinal: Integer;
  end;

  TMermaidLayeredMetrics = record
    RankMainStart: TArray<Single>;
    RankMainSize: TArray<Single>;
    RankCrossWidth: TArray<Single>;
    TotalMain: Single;
    TotalCross: Single;
  end;

  // A node's place in a single depth-first walk of the original edges: still
  // on the call stack (InProgress) is what tells a back edge apart from an
  // edge into an already-finished subtree.
  TMermaidDfsState = (Unvisited, InProgress, Done);

  // One frame of the depth-first walk's own call stack, kept explicit instead
  // of on the real one: which node, and which of its successor edges to
  // resume from. A frame comes off only once every edge from that node has
  // been visited, the same point the recursive version would set Done.
  TMermaidDfsFrame = record
    NodeIndex: Integer;
    NextEdgePosition: Integer;
  end;

  // Places boxes of known size on ranks, the way a flowchart and a class
  // diagram both read: every edge runs from an earlier rank to a later one,
  // boxes on one rank sit side by side in an order that keeps edges short,
  // and the direction decides whether ranks stack downward, upward or run
  // sideways. Boxes never overlap: ranks are as deep as their deepest box
  // plus a gap, and boxes on one rank keep a gap between them. The same input
  // always gives the same positions.
  TMermaidLayeredLayout = class
  private
    const
      OrderingSweeps = 2;
    var
      FBoxes: TArray<TMermaidNodeBox>;
      FEdges: TArray<TMermaidLayeredEdge>;
      FDirection: TMermaidDirection;
      FRankGap: Single;
      FSiblingGap: Single;
      FSuccessors: TArray<TArray<Integer>>;
      FPredecessors: TArray<TArray<Integer>>;
      FContentWidth: Single;
      FContentHeight: Single;
    function NodeCount: Integer;
    function IsHorizontal: Boolean;
    function IsReversed: Boolean;
    function IsEdgeValid(const EdgeIndex: Integer): Boolean;
    procedure BuildAdjacency;
    function FindBackEdges: TArray<Boolean>;
    procedure MarkBackEdges(const NodeIndex: Integer; const SuccessorEdges: TArray<TList<Integer>>;
      const State: TArray<TMermaidDfsState>; const IsBackEdge: TArray<Boolean>);
    procedure RankNodes(out MaxRank: Integer);
    procedure LayoutLayered(const Bounds: TLayoutRectF; const Margin: Single; const MaxRank: Integer);
    function BuildRankMembers(const Members: TObjectList<TList<Integer>>;
      const MaxRank: Integer): TArray<TList<Integer>>;
    function ComputeRankMainSizes(const Members: TArray<TList<Integer>>; const MaxRank: Integer): TArray<Single>;
    function RankGapAfter(const Rank: Integer): Single;
    function ComputeRankMainStarts(const RankMainSize: TArray<Single>; const MaxRank: Integer;
      out TotalMain: Single): TArray<Single>;
    function ComputeRankCrossWidths(const Members: TArray<TList<Integer>>; const MaxRank: Integer;
      out TotalCross: Single): TArray<Single>;
    procedure PlaceLayeredNodes(const Bounds: TLayoutRectF; const Margin: Single; const Members: TArray<TList<Integer>>;
      const MaxRank: Integer; const Metrics: TMermaidLayeredMetrics);
    procedure OrderRanks(const Members: TArray<TList<Integer>>; const MaxRank: Integer);
    procedure SortRankByAdjacent(const Members: TArray<TList<Integer>>; const Rank, ReferenceRank: Integer;
      const UsePredecessors: Boolean);
    function BuildReferencePositions(const Reference: TList<Integer>): TArray<Integer>;
    function ComputeBarycenterKeys(const Current: TList<Integer>; const ReferencePosition: TArray<Integer>;
      const UsePredecessors: Boolean): TArray<TMermaidBaryKey>;
    function MainSize(const Box: TMermaidNodeBox): Single;
    function CrossSize(const Box: TMermaidNodeBox): Single;

  public
    constructor Create(const Sizes: TArray<TLayoutSizeF>; const Edges: TArray<TMermaidLayeredEdge>;
      const Direction: TMermaidDirection; const RankGap, SiblingGap: Single);
    procedure Arrange(const Bounds: TLayoutRectF; const Margin: Single);
    function ParallelEdgeShift(const EdgeIndex: Integer; const Spacing: Single): TLayoutPointF;
    property Boxes: TArray<TMermaidNodeBox> read FBoxes;
    property ContentWidth: Single read FContentWidth;
    property ContentHeight: Single read FContentHeight;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  System.Generics.Defaults,
  Markdown4D.Defines;

function TMermaidNodeBox.Center: TLayoutPointF;
begin
  Result := TLayoutPointF.Create(X + Width / 2, Y + Height / 2);
end;

function TMermaidNodeBox.Bounds: TLayoutRectF;
begin
  Result := TLayoutRectF.Create(X, Y, X + Width, Y + Height);
end;

function TMermaidNodeBox.BorderPoint(const Toward: TLayoutPointF): TLayoutPointF;
begin
  const CenterX = X + Width / 2;
  const CenterY = Y + Height / 2;
  const DeltaX = Toward.X - CenterX;
  const DeltaY = Toward.Y - CenterY;

  if (DeltaX = 0) and (DeltaY = 0) then
  begin
    Result := TLayoutPointF.Create(CenterX, CenterY);
    Exit;
  end;

  const HalfWidth = Width / 2;
  const HalfHeight = Height / 2;

  var Scale := MaxSingle;
  if DeltaX <> 0 then
    Scale := Min(Scale, HalfWidth / Abs(DeltaX));
  if DeltaY <> 0 then
    Scale := Min(Scale, HalfHeight / Abs(DeltaY));

  Result := TLayoutPointF.Create(CenterX + DeltaX * Scale, CenterY + DeltaY * Scale);
end;

class function TMermaidLayeredEdge.Create(const Source, Target: Integer; const MinimumGap: Single): TMermaidLayeredEdge;
begin
  Result.Source := Source;
  Result.Target := Target;
  Result.MinimumGap := MinimumGap;
end;

constructor TMermaidLayeredLayout.Create(const Sizes: TArray<TLayoutSizeF>; const Edges: TArray<TMermaidLayeredEdge>;
  const Direction: TMermaidDirection; const RankGap, SiblingGap: Single);
begin
  inherited Create;

  FEdges := Edges;
  FDirection := Direction;
  FRankGap := RankGap;
  FSiblingGap := SiblingGap;

  SetLength(FBoxes, Length(Sizes));
  for var Index := 0 to High(Sizes) do
  begin
    FBoxes[Index].Width := Sizes[Index].Width;
    FBoxes[Index].Height := Sizes[Index].Height;
    FBoxes[Index].Rank := 0;
  end;
end;

procedure TMermaidLayeredLayout.Arrange(const Bounds: TLayoutRectF; const Margin: Single);
begin
  if NodeCount = 0 then
    Exit;

  BuildAdjacency;

  var MaxRank: Integer;
  RankNodes(MaxRank);
  LayoutLayered(Bounds, Margin, MaxRank);
end;

function TMermaidLayeredLayout.NodeCount: Integer;
begin
  Result := Length(FBoxes);
end;

function TMermaidLayeredLayout.IsHorizontal: Boolean;
begin
  Result := (FDirection = TMermaidDirection.LR) or (FDirection = TMermaidDirection.RL);
end;

function TMermaidLayeredLayout.IsReversed: Boolean;
begin
  Result := (FDirection = TMermaidDirection.BT) or (FDirection = TMermaidDirection.RL);
end;

function TMermaidLayeredLayout.IsEdgeValid(const EdgeIndex: Integer): Boolean;
begin
  const Edge = FEdges[EdgeIndex];
  Result := (Edge.Source >= 0) and (Edge.Source < NodeCount) and (Edge.Target >= 0) and (Edge.Target < NodeCount) and
    (Edge.Source <> Edge.Target);
end;

// The ranking pass needs an acyclic graph to run a topological sort over, but a
// diagram is free to loop back to an earlier node (a "no, try again" edge is
// what most flowchart decisions are for). A back edge found by depth-first
// search is treated as reversed for ranking only, so the cycle it closes cannot
// stop the sort; the builders still draw every edge the way its author pointed
// it.
procedure TMermaidLayeredLayout.BuildAdjacency;
begin
  const IsBackEdge = FindBackEdges;

  const SuccessorLists = TObjectList<TList<Integer>>.Create(True);
  try
    const PredecessorLists = TObjectList<TList<Integer>>.Create(True);
    try
      for var Index := 0 to NodeCount - 1 do
      begin
        SuccessorLists.Add(TList<Integer>.Create);
        PredecessorLists.Add(TList<Integer>.Create);
      end;

      for var Index := 0 to High(FEdges) do
      begin
        if not IsEdgeValid(Index) then
          Continue;

        var RankSource := FEdges[Index].Source;
        var RankTarget := FEdges[Index].Target;
        if IsBackEdge[Index] then
        begin
          RankSource := FEdges[Index].Target;
          RankTarget := FEdges[Index].Source;
        end;

        SuccessorLists[RankSource].Add(RankTarget);
        PredecessorLists[RankTarget].Add(RankSource);
      end;

      SetLength(FSuccessors, NodeCount);
      SetLength(FPredecessors, NodeCount);

      for var Index := 0 to NodeCount - 1 do
      begin
        FSuccessors[Index] := SuccessorLists[Index].ToArray;
        FPredecessors[Index] := PredecessorLists[Index].ToArray;
      end;
    finally
      PredecessorLists.Free;
    end;
  finally
    SuccessorLists.Free;
  end;
end;

// A depth-first search classifies every edge relative to its own traversal:
// an edge into a node still on the call stack is what closes a cycle. Nodes
// and each node's own edges are both visited in the diagram's declaration
// order, so the edge that reads as "loop back to an earlier step" in the
// source is the one found here, rather than an arbitrary other edge of the
// same cycle - the reading order the diagram was authored in is also the one
// that keeps the picture readable.
function TMermaidLayeredLayout.FindBackEdges: TArray<Boolean>;
begin
  const SuccessorEdgeLists = TObjectList<TList<Integer>>.Create(True);
  try
    for var Index := 0 to NodeCount - 1 do
    begin
      SuccessorEdgeLists.Add(TList<Integer>.Create);
    end;

    for var Index := 0 to High(FEdges) do
    begin
      if IsEdgeValid(Index) then
        SuccessorEdgeLists[FEdges[Index].Source].Add(Index);
    end;

    var SuccessorEdges: TArray<TList<Integer>>;
    SetLength(SuccessorEdges, NodeCount);
    for var Index := 0 to NodeCount - 1 do
    begin
      SuccessorEdges[Index] := SuccessorEdgeLists[Index];
    end;

    SetLength(Result, Length(FEdges));

    var State: TArray<TMermaidDfsState>;
    SetLength(State, NodeCount);

    for var NodeIndex := 0 to NodeCount - 1 do
    begin
      if State[NodeIndex] = TMermaidDfsState.Unvisited then
        MarkBackEdges(NodeIndex, SuccessorEdges, State, Result);
    end;
  finally
    SuccessorEdgeLists.Free;
  end;
end;

// Walked with an explicit TMermaidDfsFrame stack rather than self-recursion,
// so a long chain of nodes (a diagram can have as many as its source declares)
// cannot grow the call stack one frame per node.
procedure TMermaidLayeredLayout.MarkBackEdges(const NodeIndex: Integer;
  const SuccessorEdges: TArray<TList<Integer>>; const State: TArray<TMermaidDfsState>;
  const IsBackEdge: TArray<Boolean>);
begin
  const Stack = TList<TMermaidDfsFrame>.Create;
  try
    State[NodeIndex] := TMermaidDfsState.InProgress;

    var StartFrame: TMermaidDfsFrame;
    StartFrame.NodeIndex := NodeIndex;
    StartFrame.NextEdgePosition := 0;
    Stack.Add(StartFrame);

    while Stack.Count > 0 do
    begin
      const TopIndex = Stack.Count - 1;
      const CurrentNode = Stack.List[TopIndex].NodeIndex;
      const Edges = SuccessorEdges[CurrentNode];

      const HasMoreEdges = Stack.List[TopIndex].NextEdgePosition < Edges.Count;
      if not HasMoreEdges then
      begin
        State[CurrentNode] := TMermaidDfsState.Done;
        Stack.Delete(TopIndex);
        Continue;
      end;

      const EdgeIndex = Edges[Stack.List[TopIndex].NextEdgePosition];
      Inc(Stack.List[TopIndex].NextEdgePosition);

      const Target = FEdges[EdgeIndex].Target;

      case State[Target] of
        TMermaidDfsState.InProgress:
          IsBackEdge[EdgeIndex] := True;
        TMermaidDfsState.Unvisited:
          begin
            State[Target] := TMermaidDfsState.InProgress;

            var NextFrame: TMermaidDfsFrame;
            NextFrame.NodeIndex := Target;
            NextFrame.NextEdgePosition := 0;
            Stack.Add(NextFrame);
          end;
        TMermaidDfsState.Done:
          ; // A forward or cross edge: it does not close a cycle, ranking keeps it as authored.
      else
        raise EMarkdownError.CreateFmt('Unhandled depth-first search state: %d', [Ord(State[Target])]);
      end;
    end;
  finally
    Stack.Free;
  end;
end;

// Reversing every back edge for ranking (see BuildAdjacency) always leaves an
// acyclic graph - a standard property of depth-first search: every edge that
// is not a back edge already runs from a later finish time to an earlier one,
// and a reversed back edge now does too, so the topological sort below cannot
// fail. If it ever does, that means a back edge was missed, which is a defect
// in this method, not a diagram shape to fall back away from silently.
procedure TMermaidLayeredLayout.RankNodes(out MaxRank: Integer);
begin
  MaxRank := 0;

  var Indegree: TArray<Integer>;
  SetLength(Indegree, NodeCount);
  for var Index := 0 to NodeCount - 1 do
  begin
    Indegree[Index] := Length(FPredecessors[Index]);
  end;

  const Order = TList<Integer>.Create;
  try
    const Ready = TQueue<Integer>.Create;
    try
      for var Index := 0 to NodeCount - 1 do
      begin
        if Indegree[Index] = 0 then
          Ready.Enqueue(Index);
      end;

      while Ready.Count > 0 do
      begin
        const Current = Ready.Dequeue;
        Order.Add(Current);

        for var Next in FSuccessors[Current] do
        begin
          Dec(Indegree[Next]);
          if Indegree[Next] = 0 then
            Ready.Enqueue(Next);
        end;
      end;
    finally
      Ready.Free;
    end;

    if Order.Count < NodeCount then
      raise EMarkdownError.Create('Mermaid layered ranking produced a graph that is still cyclic after back ' +
        'edges were reversed');

    for var Current in Order do
    begin
      for var Next in FSuccessors[Current] do
      begin
        if FBoxes[Current].Rank + 1 > FBoxes[Next].Rank then
          FBoxes[Next].Rank := FBoxes[Current].Rank + 1;
      end;
    end;

    for var Index := 0 to NodeCount - 1 do
    begin
      MaxRank := Max(MaxRank, FBoxes[Index].Rank);
    end;
  finally
    Order.Free;
  end;
end;

procedure TMermaidLayeredLayout.LayoutLayered(const Bounds: TLayoutRectF; const Margin: Single;
  const MaxRank: Integer);
begin
  const Members = TObjectList<TList<Integer>>.Create(True);
  try
    const MemberArray = BuildRankMembers(Members, MaxRank);

    OrderRanks(MemberArray, MaxRank);

    var Metrics: TMermaidLayeredMetrics;
    Metrics.RankMainSize := ComputeRankMainSizes(MemberArray, MaxRank);
    Metrics.RankMainStart := ComputeRankMainStarts(Metrics.RankMainSize, MaxRank, Metrics.TotalMain);
    Metrics.RankCrossWidth := ComputeRankCrossWidths(MemberArray, MaxRank, Metrics.TotalCross);

    PlaceLayeredNodes(Bounds, Margin, MemberArray, MaxRank, Metrics);
  finally
    Members.Free;
  end;
end;

function TMermaidLayeredLayout.BuildRankMembers(const Members: TObjectList<TList<Integer>>;
  const MaxRank: Integer): TArray<TList<Integer>>;
begin
  for var Rank := 0 to MaxRank do
  begin
    Members.Add(TList<Integer>.Create);
  end;

  SetLength(Result, MaxRank + 1);
  for var Rank := 0 to MaxRank do
  begin
    Result[Rank] := Members[Rank];
  end;

  for var Index := 0 to NodeCount - 1 do
  begin
    Result[FBoxes[Index].Rank].Add(Index);
  end;
end;

function TMermaidLayeredLayout.ComputeRankMainSizes(const Members: TArray<TList<Integer>>;
  const MaxRank: Integer): TArray<Single>;
begin
  SetLength(Result, MaxRank + 1);
  for var Rank := 0 to MaxRank do
  begin
    var Value := 0.0;
    for var NodeIndex in Members[Rank] do
    begin
      Value := Max(Value, MainSize(FBoxes[NodeIndex]));
    end;
    Result[Rank] := Value;
  end;
end;

function TMermaidLayeredLayout.ComputeRankMainStarts(const RankMainSize: TArray<Single>;
  const MaxRank: Integer; out TotalMain: Single): TArray<Single>;
begin
  SetLength(Result, MaxRank + 1);
  var MainCursor := 0.0;
  for var Rank := 0 to MaxRank do
  begin
    Result[Rank] := MainCursor;
    MainCursor := MainCursor + RankMainSize[Rank];
    if Rank < MaxRank then
      MainCursor := MainCursor + RankGapAfter(Rank);
  end;
  TotalMain := MainCursor;

  if IsReversed then
  begin
    for var Rank := 0 to MaxRank do
    begin
      Result[Rank] := TotalMain - Result[Rank] - RankMainSize[Rank];
    end;
  end;
end;

// An edge that carries a label or markers at its ends needs more room than the
// bare gap between two ranks, or what it carries swallows the whole line and
// bites into the boxes on either side.
function TMermaidLayeredLayout.RankGapAfter(const Rank: Integer): Single;
begin
  Result := FRankGap;

  for var Index := 0 to High(FEdges) do
  begin
    if not IsEdgeValid(Index) then
      Continue;

    const SourceRank = FBoxes[FEdges[Index].Source].Rank;
    const TargetRank = FBoxes[FEdges[Index].Target].Rank;
    const CrossesThisBoundary = (Min(SourceRank, TargetRank) = Rank) and (Max(SourceRank, TargetRank) = Rank + 1);
    if CrossesThisBoundary then
      Result := Max(Result, FEdges[Index].MinimumGap);
  end;
end;

function TMermaidLayeredLayout.ComputeRankCrossWidths(const Members: TArray<TList<Integer>>;
  const MaxRank: Integer; out TotalCross: Single): TArray<Single>;
begin
  SetLength(Result, MaxRank + 1);
  TotalCross := 0.0;
  for var Rank := 0 to MaxRank do
  begin
    var Width := 0.0;
    for var NodeIndex in Members[Rank] do
    begin
      Width := Width + CrossSize(FBoxes[NodeIndex]) + FSiblingGap;
    end;
    if Width > 0 then
      Width := Width - FSiblingGap;
    Result[Rank] := Width;
    TotalCross := Max(TotalCross, Width);
  end;
end;

procedure TMermaidLayeredLayout.PlaceLayeredNodes(const Bounds: TLayoutRectF; const Margin: Single;
  const Members: TArray<TList<Integer>>; const MaxRank: Integer; const Metrics: TMermaidLayeredMetrics);
begin
  const Horizontal = IsHorizontal;
  if Horizontal then
  begin
    FContentWidth := Metrics.TotalMain;
    FContentHeight := Metrics.TotalCross;
  end
  else
  begin
    FContentWidth := Metrics.TotalCross;
    FContentHeight := Metrics.TotalMain;
  end;

  const OriginX = Bounds.Left + Max(0.0, (Bounds.Width - FContentWidth) / 2);
  const OriginY = Bounds.Top + Margin;

  var OriginMain := OriginY;
  var OriginCross := OriginX;
  if Horizontal then
  begin
    OriginMain := OriginX;
    OriginCross := OriginY;
  end;

  for var Rank := 0 to MaxRank do
  begin
    const Offset = (Metrics.TotalCross - Metrics.RankCrossWidth[Rank]) / 2;
    var CrossCursor := 0.0;

    for var NodeIndex in Members[Rank] do
    begin
      const CrossPos = OriginCross + Offset + CrossCursor;
      const MainPos = OriginMain + Metrics.RankMainStart[Rank] +
        (Metrics.RankMainSize[Rank] - MainSize(FBoxes[NodeIndex])) / 2;

      if Horizontal then
      begin
        FBoxes[NodeIndex].X := MainPos;
        FBoxes[NodeIndex].Y := CrossPos;
      end
      else
      begin
        FBoxes[NodeIndex].X := CrossPos;
        FBoxes[NodeIndex].Y := MainPos;
      end;

      CrossCursor := CrossCursor + CrossSize(FBoxes[NodeIndex]) + FSiblingGap;
    end;
  end;
end;

procedure TMermaidLayeredLayout.OrderRanks(const Members: TArray<TList<Integer>>; const MaxRank: Integer);
begin
  for var Sweep := 1 to OrderingSweeps do
  begin
    for var Rank := 1 to MaxRank do
    begin
      SortRankByAdjacent(Members, Rank, Rank - 1, True);
    end;

    for var Rank := MaxRank - 1 downto 0 do
    begin
      SortRankByAdjacent(Members, Rank, Rank + 1, False);
    end;
  end;
end;

procedure TMermaidLayeredLayout.SortRankByAdjacent(const Members: TArray<TList<Integer>>;
  const Rank, ReferenceRank: Integer; const UsePredecessors: Boolean);
begin
  const Current = Members[Rank];
  if Current.Count <= 1 then
    Exit;

  const ReferencePosition = BuildReferencePositions(Members[ReferenceRank]);
  var Keys := ComputeBarycenterKeys(Current, ReferencePosition, UsePredecessors);

  TArray.Sort<TMermaidBaryKey>(Keys, TComparer<TMermaidBaryKey>.Construct(
    function(const Left, Right: TMermaidBaryKey): Integer
    begin
      Result := CompareValue(Left.Bary, Right.Bary);
      if Result = 0 then
        Result := Left.Ordinal - Right.Ordinal;
    end));

  for var Index := 0 to Current.Count - 1 do
  begin
    Current[Index] := Keys[Index].Node;
  end;
end;

function TMermaidLayeredLayout.BuildReferencePositions(const Reference: TList<Integer>): TArray<Integer>;
begin
  SetLength(Result, NodeCount);
  for var Index := 0 to High(Result) do
  begin
    Result[Index] := -1;
  end;

  for var Position := 0 to Reference.Count - 1 do
  begin
    Result[Reference[Position]] := Position;
  end;
end;

function TMermaidLayeredLayout.ComputeBarycenterKeys(const Current: TList<Integer>;
  const ReferencePosition: TArray<Integer>; const UsePredecessors: Boolean): TArray<TMermaidBaryKey>;
begin
  SetLength(Result, Current.Count);

  for var Index := 0 to Current.Count - 1 do
  begin
    const NodeIndex = Current[Index];

    var Neighbors: TArray<Integer>;
    if UsePredecessors then
      Neighbors := FPredecessors[NodeIndex]
    else
      Neighbors := FSuccessors[NodeIndex];

    var Sum := 0.0;
    var Count := 0;
    for var Neighbor in Neighbors do
    begin
      if ReferencePosition[Neighbor] >= 0 then
      begin
        Sum := Sum + ReferencePosition[Neighbor];
        Inc(Count);
      end;
    end;

    if Count > 0 then
      Result[Index].Bary := Sum / Count
    else
      Result[Index].Bary := Index;

    Result[Index].Node := NodeIndex;
    Result[Index].Ordinal := Index;
  end;
end;

function TMermaidLayeredLayout.ParallelEdgeShift(const EdgeIndex: Integer; const Spacing: Single): TLayoutPointF;
begin
  const Edge = FEdges[EdgeIndex];
  const PairLow = Min(Edge.Source, Edge.Target);
  const PairHigh = Max(Edge.Source, Edge.Target);

  // Fan out every edge that connects the same node pair (parallel and
  // anti-parallel edges) so they no longer draw on top of each other. The
  // offset uses the pair's canonical low->high direction, so a back-edge lands
  // on the opposite side of the forward edge instead of cancelling it out.
  var Count := 0;
  var Position := 0;
  for var Other := 0 to High(FEdges) do
  begin
    const OtherEdge = FEdges[Other];
    if (Min(OtherEdge.Source, OtherEdge.Target) = PairLow) and
      (Max(OtherEdge.Source, OtherEdge.Target) = PairHigh) then
    begin
      if Other < EdgeIndex then
        Inc(Position);
      Inc(Count);
    end;
  end;

  if Count <= 1 then
  begin
    Result := TLayoutPointF.Create(0, 0);
    Exit;
  end;

  const Offset = (Position - (Count - 1) / 2) * Spacing;

  const LowCenter = FBoxes[PairLow].Center;
  const HighCenter = FBoxes[PairHigh].Center;
  const DeltaX = HighCenter.X - LowCenter.X;
  const DeltaY = HighCenter.Y - LowCenter.Y;
  const Distance = Sqrt(DeltaX * DeltaX + DeltaY * DeltaY);
  if Distance = 0 then
  begin
    Result := TLayoutPointF.Create(0, 0);
    Exit;
  end;

  Result := TLayoutPointF.Create(-DeltaY / Distance * Offset, DeltaX / Distance * Offset);
end;

function TMermaidLayeredLayout.MainSize(const Box: TMermaidNodeBox): Single;
begin
  if IsHorizontal then
    Result := Box.Width
  else
    Result := Box.Height;
end;

function TMermaidLayeredLayout.CrossSize(const Box: TMermaidNodeBox): Single;
begin
  if IsHorizontal then
    Result := Box.Height
  else
    Result := Box.Width;
end;

end.
