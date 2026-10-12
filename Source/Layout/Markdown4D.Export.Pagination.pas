unit Markdown4D.Export.Pagination;

{$SCOPEDENUMS ON}

// Cuts a laid-out document into pages. A page never ends inside a line of text,
// an image, a formula or a diagram: those are atomic. A block that fits on a
// page moves to the next page whole; a longer paragraph, list, table or code
// block breaks between its lines or rows. An atomic piece taller than a page
// gets a page of its own and is shrunk to fit, never cut.

interface

uses
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.DisplayList;

type
  TMarkdownPageSlice = record
  public
    Top: Single;
    Bottom: Single;
    // Below 1 when the slice is taller than a page and has to shrink to fit.
    Scale: Single;
    class function Create(const Top, Bottom, Scale: Single): TMarkdownPageSlice; static;
    function Height: Single;
  end;

  TMarkdownPagination = class
  private
    type
      TVerticalRange = record
        Top: Single;
        Bottom: Single;
        class function Create(const Top, Bottom: Single): TVerticalRange; static;
        function StrictlyContains(const Y: Single): Boolean;
      end;
    const
      OverlapEpsilon = 0.01;
      FullScale = 1.0;
      NonPositivePageHeightMessage = 'The page height for pagination must be above zero, not %g';
      UnhandledItemKindMessage = 'Unhandled display item kind: %d';
      NoProgressMessage = 'Pagination made no progress: a page from %g to %g';
    class procedure GuardPageHeight(const PageHeight: Single); static;
    class procedure GuardProgress(const Slice: TMarkdownPageSlice); static;
    class function AtomicRanges(const DisplayList: IMarkdownDisplayList): TArray<TVerticalRange>; static;
    class procedure CollectItemRange(const Item: IDisplayItem; const OverrideCache: TDictionary<IMarkdownNode, Boolean>;
      const OverrideRanges: TDictionary<IMarkdownNode, TVerticalRange>; const Ranges: TList<TVerticalRange>); static;
    class function IsAtomicKind(const Kind: TDisplayItemKind): Boolean; static;
    class function IsOverridden(const Node: IMarkdownNode;
      const OverrideCache: TDictionary<IMarkdownNode, Boolean>): Boolean; static;
    class function MergedRanges(const Ranges: TList<TVerticalRange>): TArray<TVerticalRange>; static;
    class function NextSlice(const DisplayList: IMarkdownDisplayList; const Ranges: TArray<TVerticalRange>;
      const Top, PageHeight: Single): TMarkdownPageSlice; static;
    class function TryFindBlockBreak(const DisplayList: IMarkdownDisplayList; const Top, Limit, PageHeight: Single;
      out BreakY: Single): Boolean; static;
    class function TryFindLineBreak(const Ranges: TArray<TVerticalRange>; const Top, Limit: Single;
      out BreakY: Single): Boolean; static;
    class function TryFindRangeContaining(const Ranges: TArray<TVerticalRange>; const Y: Single;
      out Range: TVerticalRange): Boolean; static;

  public
    class function Paginate(const DisplayList: IMarkdownDisplayList;
      const PageHeight: Single): TArray<TMarkdownPageSlice>; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Generics.Defaults,
  Markdown4D.Defines,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Export.Pdf.Errors;

class function TMarkdownPageSlice.Create(const Top, Bottom, Scale: Single): TMarkdownPageSlice;
begin
  Result.Top := Top;
  Result.Bottom := Bottom;
  Result.Scale := Scale;
end;

function TMarkdownPageSlice.Height: Single;
begin
  Result := Bottom - Top;
end;

class function TMarkdownPagination.TVerticalRange.Create(const Top, Bottom: Single): TVerticalRange;
begin
  Result.Top := Top;
  Result.Bottom := Bottom;
end;

function TMarkdownPagination.TVerticalRange.StrictlyContains(const Y: Single): Boolean;
begin
  Result := (Y > Top + OverlapEpsilon) and (Y < Bottom - OverlapEpsilon);
end;

class function TMarkdownPagination.Paginate(const DisplayList: IMarkdownDisplayList;
  const PageHeight: Single): TArray<TMarkdownPageSlice>;
begin
  GuardPageHeight(PageHeight);

  const IsEmpty = (DisplayList = nil) or (DisplayList.Height <= 0);
  if IsEmpty then
  begin
    Result := [TMarkdownPageSlice.Create(0, PageHeight, FullScale)];
    Exit;
  end;

  const Ranges = AtomicRanges(DisplayList);
  const DocumentHeight = DisplayList.Height;

  Result := [];
  var Top: Single := 0;
  while Top < DocumentHeight do
  begin
    const Slice = NextSlice(DisplayList, Ranges, Top, PageHeight);
    GuardProgress(Slice);

    Result := Result + [Slice];
    Top := Slice.Bottom;
  end;
end;

class procedure TMarkdownPagination.GuardPageHeight(const PageHeight: Single);
begin
  const IsNonPositive = (PageHeight <= 0);
  if IsNonPositive then
    raise EMarkdownPdfExportError.CreateFmt(NonPositivePageHeightMessage, [PageHeight]);
end;

class procedure TMarkdownPagination.GuardProgress(const Slice: TMarkdownPageSlice);
begin
  const IsStuck = (Slice.Bottom <= Slice.Top);
  if IsStuck then
    raise EMarkdownPdfExportError.CreateFmt(NoProgressMessage, [Slice.Top, Slice.Bottom]);
end;

// A diagram or chart is one piece, wherever its items lie: the extension canvas
// attributes every item it draws to the node it replaced. Of all other items,
// a run of text, an image and a checkbox are pieces of their own, while the
// backgrounds, borders and rules around them may be cut, so the background of
// a code block or the grid of a table carries on over the page break.
class function TMarkdownPagination.AtomicRanges(const DisplayList: IMarkdownDisplayList): TArray<TVerticalRange>;
begin
  const OverrideCache = TDictionary<IMarkdownNode, Boolean>.Create;
  const OverrideRanges = TDictionary<IMarkdownNode, TVerticalRange>.Create;
  const Ranges = TList<TVerticalRange>.Create;
  try
    for var Index := 0 to DisplayList.ItemCount - 1 do
    begin
      CollectItemRange(DisplayList.Items[Index], OverrideCache, OverrideRanges, Ranges);
    end;

    Ranges.AddRange(OverrideRanges.Values);
    Result := MergedRanges(Ranges);
  finally
    Ranges.Free;
    OverrideRanges.Free;
    OverrideCache.Free;
  end;
end;

class procedure TMarkdownPagination.CollectItemRange(const Item: IDisplayItem;
  const OverrideCache: TDictionary<IMarkdownNode, Boolean>;
  const OverrideRanges: TDictionary<IMarkdownNode, TVerticalRange>; const Ranges: TList<TVerticalRange>);
begin
  const Bounds = Item.Bounds;
  const Node = Item.Node;

  if IsOverridden(Node, OverrideCache) then
  begin
    var Range: TVerticalRange;
    if OverrideRanges.TryGetValue(Node, Range) then
      Range := TVerticalRange.Create(Min(Range.Top, Bounds.Top), Max(Range.Bottom, Bounds.Bottom))
    else
      Range := TVerticalRange.Create(Bounds.Top, Bounds.Bottom);

    OverrideRanges.AddOrSetValue(Node, Range);
    Exit;
  end;

  if IsAtomicKind(Item.Kind) then
    Ranges.Add(TVerticalRange.Create(Bounds.Top, Bounds.Bottom));
end;

class function TMarkdownPagination.IsAtomicKind(const Kind: TDisplayItemKind): Boolean;
begin
  case Kind of
    TDisplayItemKind.TextRun,
    TDisplayItemKind.Image,
    TDisplayItemKind.Checkbox  : Result := True;
    TDisplayItemKind.Rectangle,
    TDisplayItemKind.Line,
    TDisplayItemKind.Wedge,
    TDisplayItemKind.Polygon   : Result := False;
  else
    raise EMarkdownError.CreateFmt(UnhandledItemKindMessage, [Ord(Kind)]);
  end;
end;

class function TMarkdownPagination.IsOverridden(const Node: IMarkdownNode;
  const OverrideCache: TDictionary<IMarkdownNode, Boolean>): Boolean;
begin
  if Node = nil then
  begin
    Result := False;
    Exit;
  end;

  if OverrideCache.TryGetValue(Node, Result) then
    Exit;

  var Handler: ILayoutBlockOverride;
  Result := TLayoutBlockOverrideRegistry.TryFind(Node, Handler);
  OverrideCache.Add(Node, Result);
end;

// Pieces that overlap, such as the runs of one line in different font sizes,
// make one piece, so no page can end between them.
class function TMarkdownPagination.MergedRanges(const Ranges: TList<TVerticalRange>): TArray<TVerticalRange>;
begin
  Ranges.Sort(TComparer<TVerticalRange>.Construct(
    function(const Left, Right: TVerticalRange): Integer
    begin
      Result := CompareValue(Left.Top, Right.Top);
    end));

  const Merged = TList<TVerticalRange>.Create;
  try
    for var Range in Ranges do
    begin
      const LastIndex = Merged.Count - 1;
      const Overlaps = (LastIndex >= 0) and (Range.Top < Merged[LastIndex].Bottom - OverlapEpsilon);
      if Overlaps then
        Merged[LastIndex] := TVerticalRange.Create(Merged[LastIndex].Top, Max(Merged[LastIndex].Bottom, Range.Bottom))
      else
        Merged.Add(Range);
    end;

    Result := Merged.ToArray;
  finally
    Merged.Free;
  end;
end;

class function TMarkdownPagination.NextSlice(const DisplayList: IMarkdownDisplayList;
  const Ranges: TArray<TVerticalRange>; const Top, PageHeight: Single): TMarkdownPageSlice;
begin
  const Limit = Top + PageHeight;
  const DocumentHeight = DisplayList.Height;

  const IsLastPage = (Limit >= DocumentHeight);
  if IsLastPage then
  begin
    Result := TMarkdownPageSlice.Create(Top, DocumentHeight, FullScale);
    Exit;
  end;

  var BreakY: Single;
  const HasBreak = (TryFindBlockBreak(DisplayList, Top, Limit, PageHeight, BreakY) or
                    TryFindLineBreak(Ranges, Top, Limit, BreakY));
  if HasBreak then
  begin
    Result := TMarkdownPageSlice.Create(Top, BreakY, FullScale);
    Exit;
  end;

  var TallRange: TVerticalRange;
  if TryFindRangeContaining(Ranges, Limit, TallRange) then
  begin
    const Bottom = Min(TallRange.Bottom, DocumentHeight);
    Result := TMarkdownPageSlice.Create(Top, Bottom, PageHeight / (Bottom - Top));
    Exit;
  end;

  // Unreachable with valid ranges: without a break there is always a piece
  // across the limit. Cutting there keeps the export from looping forever.
  Result := TMarkdownPageSlice.Create(Top, Limit, FullScale);
end;

// A block that runs over the end of the page but fits on an empty one starts
// the next page, rather than being split.
class function TMarkdownPagination.TryFindBlockBreak(const DisplayList: IMarkdownDisplayList;
  const Top, Limit, PageHeight: Single; out BreakY: Single): Boolean;
begin
  BreakY := 0;

  for var Index := 0 to DisplayList.BlockCount - 1 do
  begin
    const Block = DisplayList.BlockInfos[Index];
    const BlockBottom = Block.Top + Block.Height;
    const CrossesLimit = (Block.Top < Limit) and (BlockBottom > Limit);
    if not CrossesLimit then
      Continue;

    const CanMoveWhole = (Block.Top > Top + OverlapEpsilon) and (Block.Height <= PageHeight);
    if CanMoveWhole then
      BreakY := Block.Top;

    Result := CanMoveWhole;
    Exit;
  end;

  Result := False;
end;

// The lowest point on the page that is not inside a piece: the limit itself,
// or else the top of the piece that runs over it.
class function TMarkdownPagination.TryFindLineBreak(const Ranges: TArray<TVerticalRange>; const Top, Limit: Single;
  out BreakY: Single): Boolean;
begin
  BreakY := Limit;

  var Crossing: TVerticalRange;
  if TryFindRangeContaining(Ranges, Limit, Crossing) then
    BreakY := Crossing.Top;

  Result := (BreakY > Top + OverlapEpsilon);
end;

class function TMarkdownPagination.TryFindRangeContaining(const Ranges: TArray<TVerticalRange>; const Y: Single;
  out Range: TVerticalRange): Boolean;
begin
  for var Candidate in Ranges do
  begin
    if Candidate.StrictlyContains(Y) then
    begin
      Range := Candidate;
      Result := True;
      Exit;
    end;
  end;

  Range := Default(TVerticalRange);
  Result := False;
end;

end.
