unit Markdown4D.Export.Pagination;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Layout.DisplayList;

type
  // One page of a laid-out document: the band from Top to Bottom, both whole
  // pixels, so consecutive pages meet without a gap or an overlap.
  TMarkdownPageSlice = record
    Top: Single;
    Bottom: Single;
    class function Create(const Top, Bottom: Single): TMarkdownPageSlice; static;
    function Height: Single;
  end;

  TMarkdownPagination = class
  private
    const
      // Neighbouring lines share an edge, which a Single carries with some
      // noise; within this distance an item touches a break, it does not cross it.
      EdgeTolerance = 0.01;
      InvalidPageHeightMessage = 'Page height must be at least one pixel, not %.2f';
      UnhandledItemKindMessage = 'Unhandled display item kind: %d';
    class procedure GuardPageHeight(const PageHeight: Single); static;
    class function NextBreak(const DisplayList: IMarkdownDisplayList; const Top, PageHeight: Single): Single; static;
    class function TryFindCrossingBlock(const DisplayList: IMarkdownDisplayList; const Y: Single;
      out Block: TLayoutBlockInfo): Boolean; static;
    class function BreakInsideBlock(const DisplayList: IMarkdownDisplayList; const Top, Limit: Single): Single; static;
    class function TryFindCrossingItemTop(const DisplayList: IMarkdownDisplayList; const Y: Single;
      out ItemTop: Single): Boolean; static;
    class function DecidesBreaks(const Item: IDisplayItem): Boolean; static;

  public
    // Splits the document into pages of PageHeight. A page ends between two
    // blocks where it can; a block that does not fit moves to the next page
    // whole, unless it is taller than a page, in which case it is broken
    // between its text runs, images and checkboxes. Backgrounds, borders and
    // shapes may be cut. An empty document still gives one page.
    class function Paginate(const DisplayList: IMarkdownDisplayList;
      const PageHeight: Single): TArray<TMarkdownPageSlice>; static;
  end;

implementation

uses
  System.Math,
  Markdown4D.Export.Pdf.Errors;

class function TMarkdownPageSlice.Create(const Top, Bottom: Single): TMarkdownPageSlice;
begin
  Result.Top := Top;
  Result.Bottom := Bottom;
end;

function TMarkdownPageSlice.Height: Single;
begin
  Result := Bottom - Top;
end;

class function TMarkdownPagination.Paginate(const DisplayList: IMarkdownDisplayList;
  const PageHeight: Single): TArray<TMarkdownPageSlice>;
begin
  GuardPageHeight(PageHeight);

  const IsEmpty = (DisplayList = nil) or (DisplayList.Height <= 0);
  if IsEmpty then
  begin
    Result := [TMarkdownPageSlice.Create(0, 0)];
    Exit;
  end;

  const DocumentBottom: Single = Ceil(DisplayList.Height);
  Result := nil;

  var Top: Single := 0;
  while Top < DocumentBottom do
  begin
    const IsLastPage = (Top + PageHeight >= DocumentBottom);
    if IsLastPage then
    begin
      Result := Result + [TMarkdownPageSlice.Create(Top, DocumentBottom)];
      Break;
    end;

    const Bottom = NextBreak(DisplayList, Top, PageHeight);
    Result := Result + [TMarkdownPageSlice.Create(Top, Bottom)];
    Top := Bottom;
  end;
end;

class procedure TMarkdownPagination.GuardPageHeight(const PageHeight: Single);
begin
  const IsTooLow = (PageHeight < 1);
  if IsTooLow then
    raise EMarkdownPdfExportError.CreateFmt(InvalidPageHeightMessage, [PageHeight]);
end;

class function TMarkdownPagination.NextBreak(const DisplayList: IMarkdownDisplayList;
  const Top, PageHeight: Single): Single;
begin
  const Limit = Top + PageHeight;
  const HardCut: Single = Floor(Limit);

  var Block: TLayoutBlockInfo;
  if not TryFindCrossingBlock(DisplayList, Limit, Block) then
  begin
    Result := HardCut;
    Exit;
  end;

  const CanMoveWholeBlock = ((Block.Top > Top) and (Block.Height <= PageHeight));
  if CanMoveWholeBlock then
    Result := Floor(Block.Top)
  else
    Result := BreakInsideBlock(DisplayList, Top, Limit);

  // Without a break below the top of the page the page is cut where it ends,
  // so pagination always moves on.
  const MakesProgress = (Result > Top);
  if not MakesProgress then
    Result := HardCut;
end;

class function TMarkdownPagination.TryFindCrossingBlock(const DisplayList: IMarkdownDisplayList; const Y: Single;
  out Block: TLayoutBlockInfo): Boolean;
begin
  for var Index := 0 to DisplayList.BlockCount - 1 do
  begin
    const Candidate = DisplayList.BlockInfos[Index];
    const Crosses = ((Candidate.Top < Y) and (Candidate.Top + Candidate.Height > Y));
    if Crosses then
    begin
      Block := Candidate;
      Result := True;
      Exit;
    end;
  end;

  Block := Default(TLayoutBlockInfo);
  Result := False;
end;

// Walks up from the bottom of the page: every item that may not be split and
// reaches across the candidate line pushes the line up to its own top.
class function TMarkdownPagination.BreakInsideBlock(const DisplayList: IMarkdownDisplayList;
  const Top, Limit: Single): Single;
begin
  var Candidate := Limit;
  var ItemTop: Single;
  while (Candidate > Top) and TryFindCrossingItemTop(DisplayList, Candidate, ItemTop) do
  begin
    Candidate := ItemTop;
  end;

  Result := Floor(Candidate);
end;

class function TMarkdownPagination.TryFindCrossingItemTop(const DisplayList: IMarkdownDisplayList; const Y: Single;
  out ItemTop: Single): Boolean;
begin
  Result := False;
  ItemTop := Y;

  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    const Item = DisplayList.Items[Index];
    if not DecidesBreaks(Item) then
      Continue;

    const Bounds = Item.Bounds;
    const Crosses = ((Bounds.Top < Y - EdgeTolerance) and (Bounds.Bottom > Y + EdgeTolerance));
    if Crosses then
    begin
      ItemTop := Min(ItemTop, Bounds.Top);
      Result := True;
    end;
  end;
end;

class function TMarkdownPagination.DecidesBreaks(const Item: IDisplayItem): Boolean;
begin
  case Item.Kind of
    TDisplayItemKind.TextRun,
    TDisplayItemKind.Image,
    TDisplayItemKind.Checkbox:
      Result := True;
    TDisplayItemKind.Rectangle,
    TDisplayItemKind.Line,
    TDisplayItemKind.Wedge,
    TDisplayItemKind.Polygon:
      Result := False;
  else
    raise EMarkdownPdfExportError.CreateFmt(UnhandledItemKindMessage, [Ord(Item.Kind)]);
  end;
end;

end.
