unit Markdown4D.Layout.TextAnchor;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.DisplayList;

type
  // A place in the text a display list shows: a text run and the character
  // boundary inside it, counted from 0.
  TMarkdownTextPosition = record
    ItemIndex: Integer;
    CharacterIndex: Integer;
  end;

  // A text position that outlives the display list: the node it falls in,
  // counted in reading order, and the offset into that node's literal. The
  // kind and the start of the node tell whether a new layout still has the
  // same node at that count; its end moves while text streams in.
  TMarkdownTextAnchor = record
    NodeOrdinal: Integer;
    NodeKind: TMarkdownNodeKind;
    NodeStart: Integer;
    LiteralOffset: Integer;
  end;

  // Turns positions in one display list into anchors and back, so a position
  // taken before a new layout can be found in the layout that replaces it.
  TMarkdownTextAnchors = class
  private
    FDisplayList: IMarkdownDisplayList;
    FNodeStarts: TArray<Integer>;
    procedure CollectNodeStarts;
    function NodeOrdinalOf(const ItemIndex: Integer): Integer;
    function PositionInNode(const FirstIndex, LiteralOffset: Integer): TMarkdownTextPosition;
    class function IsSameNode(const Node: IMarkdownNode; const Anchor: TMarkdownTextAnchor): Boolean; static;

  public
    constructor Create(const DisplayList: IMarkdownDisplayList);
    // Glyphs that belong to a drawing, such as a formula, are text runs for
    // the painter but not for the reader: selecting, searching and copying
    // skip them. The drawing's source run takes their place.
    class function TrySelectableRun(const DisplayList: IMarkdownDisplayList; const Index: Integer;
                                    out Run: IDisplayTextRun): Boolean; static;
    function TryAnchorOf(const Position: TMarkdownTextPosition; out Anchor: TMarkdownTextAnchor): Boolean;
    // False when this layout no longer has the node the anchor was taken in.
    function TryPositionOf(const Anchor: TMarkdownTextAnchor; out Position: TMarkdownTextPosition): Boolean;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections;

constructor TMarkdownTextAnchors.Create(const DisplayList: IMarkdownDisplayList);
begin
  inherited Create;

  FDisplayList := DisplayList;
  CollectNodeStarts;
end;

class function TMarkdownTextAnchors.TrySelectableRun(const DisplayList: IMarkdownDisplayList; const Index: Integer;
  out Run: IDisplayTextRun): Boolean;
begin
  Result := Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and (Run.Role <> TDisplayTextRunRole.Drawing);
end;

function TMarkdownTextAnchors.TryAnchorOf(const Position: TMarkdownTextPosition;
  out Anchor: TMarkdownTextAnchor): Boolean;
begin
  Anchor := Default(TMarkdownTextAnchor);

  var Run: IDisplayTextRun;
  Result := TrySelectableRun(FDisplayList, Position.ItemIndex, Run) and Assigned(Run.SourceNode);
  if not Result then
    Exit;

  Anchor.NodeOrdinal := NodeOrdinalOf(Position.ItemIndex);
  Anchor.NodeKind := Run.SourceNode.Kind;
  Anchor.NodeStart := Run.SourceNode.Segment.StartOffset;
  Anchor.LiteralOffset := Run.StartOffset + Position.CharacterIndex;
end;

function TMarkdownTextAnchors.TryPositionOf(const Anchor: TMarkdownTextAnchor;
  out Position: TMarkdownTextPosition): Boolean;
begin
  Position := Default(TMarkdownTextPosition);

  Result := (Anchor.NodeOrdinal < Length(FNodeStarts));
  if not Result then
    Exit;

  const FirstIndex = FNodeStarts[Anchor.NodeOrdinal];
  var Run: IDisplayTextRun;
  TrySelectableRun(FDisplayList, FirstIndex, Run);
  Result := IsSameNode(Run.SourceNode, Anchor);
  if Result then
    Position := PositionInNode(FirstIndex, Anchor.LiteralOffset);
end;

// Keeps the index of the first run of every node. Runs that wrap one node
// over several lines follow each other, so a node counts once however many
// runs it takes.
procedure TMarkdownTextAnchors.CollectNodeStarts;
begin
  const Starts = TList<Integer>.Create;
  try
    var Previous: IMarkdownNode := nil;

    for var Index := 0 to FDisplayList.ItemCount - 1 do
    begin
      var Run: IDisplayTextRun;
      if not TrySelectableRun(FDisplayList, Index, Run) then
        Continue;

      const IsNextNode = (Run.SourceNode <> Previous);
      if IsNextNode then
      begin
        Starts.Add(Index);
        Previous := Run.SourceNode;
      end;
    end;

    FNodeStarts := Starts.ToArray;
  finally
    Starts.Free;
  end;
end;

function TMarkdownTextAnchors.NodeOrdinalOf(const ItemIndex: Integer): Integer;
begin
  Result := -1;

  for var Start in FNodeStarts do
  begin
    const IsPastItem = (Start > ItemIndex);
    if IsPastItem then
      Break;

    Inc(Result);
  end;
end;

// The space a line wraps at belongs to no run, so an offset on it lands at the
// start of the run on the next line.
function TMarkdownTextAnchors.PositionInNode(const FirstIndex, LiteralOffset: Integer): TMarkdownTextPosition;
begin
  var Run: IDisplayTextRun;
  TrySelectableRun(FDisplayList, FirstIndex, Run);
  Result.ItemIndex := FirstIndex;

  for var Index := FirstIndex to FDisplayList.ItemCount - 1 do
  begin
    var Candidate: IDisplayTextRun;
    if not TrySelectableRun(FDisplayList, Index, Candidate) then
      Continue;

    const IsOtherNode = (Candidate.SourceNode <> Run.SourceNode);
    if IsOtherNode then
      Break;

    Run := Candidate;
    Result.ItemIndex := Index;
    const RunEnd = Run.StartOffset + Length(Run.Text);
    const IsWithinRun = (LiteralOffset <= RunEnd);
    if IsWithinRun then
      Break;
  end;

  Result.CharacterIndex := EnsureRange(LiteralOffset - Run.StartOffset, 0, Length(Run.Text));
end;

class function TMarkdownTextAnchors.IsSameNode(const Node: IMarkdownNode; const Anchor: TMarkdownTextAnchor): Boolean;
begin
  Result := (Node.Kind = Anchor.NodeKind) and (Node.Segment.StartOffset = Anchor.NodeStart);
end;

end.
