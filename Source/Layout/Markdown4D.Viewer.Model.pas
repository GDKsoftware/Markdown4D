unit Markdown4D.Viewer.Model;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme;

type
  TMarkdownImageSlotState = (Unknown, Requested, Loaded, Failed);

  TMarkdownFoundRange = record
    ItemIndex: Integer;
    StartCharacter: Integer;
    CharacterCount: Integer;
    class function Create(const ItemIndex, StartCharacter, CharacterCount: Integer): TMarkdownFoundRange; static;
  end;

  TMarkdownViewerModel = class(TNoRefCountObject, IMarkdownImageSizeProvider)
  private
    type
      TTextPosition = record
        ItemIndex: Integer;
        CharacterIndex: Integer;
      end;
      TImageSlot = record
        State: TMarkdownImageSlotState;
        Size: TLayoutSizeF;
      end;
      TTextRange = record
        StartPosition: TTextPosition;
        EndPosition: TTextPosition;
      end;
    const
      DefaultFlushIntervalMilliseconds = 100;
      BottomEpsilon = 0.5;
      LineTopEpsilon = 0.5;
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FText: string;
      FPendingMarkdown: string;
      FDirty: Boolean;
      FDirtySince: Int64;
      FFlushIntervalMilliseconds: Cardinal;
      FViewportWidth: Single;
      FViewportHeight: Single;
      FScrollOffset: Single;
      FDisplayList: IMarkdownDisplayList;
      FLayoutCount: Integer;
      FShouldAutoFollow: Boolean;
      FSelectionActive: Boolean;
      FAnchor: TTextPosition;
      FExtent: TTextPosition;
      FImageSlots: TDictionary<string, TImageSlot>;
      FImageSlotOrder: TList<string>;
    procedure Relayout;
    procedure RegisterImageSlots;
    function TryResolvePosition(const Point: TLayoutPointF; out Position: TTextPosition): Boolean;
    function NearestCharacterBoundary(const Run: IDisplayTextRun; const X: Single): Integer;
    function NormalizeSelection: TTextRange;
    class function ComparePositions(const Left, Right: TTextPosition): Integer;
    function SelectedCharacterRange(const Run: IDisplayTextRun; const ItemIndex: Integer;
      const StartPosition, EndPosition: TTextPosition; out CharFrom, CharTo: Integer): Boolean;
    function BlockIndexOfItem(const ItemIndex: Integer): Integer;
    function PrefixWidth(const Run: IDisplayTextRun; const CharacterCount: Integer): Single;
    function GetText: string;
    procedure SetText(const Value: string);
    function GetPendingText: string;
    function GetFullText: string;
    function GetDisplayList: IMarkdownDisplayList;
    function GetLayoutCount: Integer;
    function GetIsDirty: Boolean;
    function GetShouldAutoFollow: Boolean;
    function GetFlushIntervalMilliseconds: Cardinal;
    procedure SetFlushIntervalMilliseconds(const Value: Cardinal);
    function GetScrollOffset: Single;
    procedure SetScrollOffset(const Value: Single);

  public
    constructor Create(const Theme: TMarkdownTheme; const Measurer: ITextMeasurer);
    destructor Destroy; override;
    procedure SetViewport(const Width, Height: Single);
    procedure ApplyTheme(const Theme: TMarkdownTheme);
    procedure RefreshLayout;
    function IsScrolledToBottom: Boolean;
    procedure AppendMarkdown(const Markdown: string; const NowMilliseconds: Int64);
    function TryFlush(const NowMilliseconds: Int64): Boolean;
    procedure SetSelectionAnchor(const Point: TLayoutPointF);
    procedure SetSelectionExtent(const Point: TLayoutPointF);
    procedure ClearSelection;
    function HasSelection: Boolean;
    function SelectionRects: TArray<TLayoutRectF>;
    function SelectedText: string;
    function PendingImageSources: TArray<string>;
    procedure NotifyImageArrived(const Source: string; const Size: TLayoutSizeF);
    procedure NotifyImageFailed(const Source: string);
    function ImageSlotState(const Source: string): TMarkdownImageSlotState;
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
    function FindText(const Needle: string): TArray<TMarkdownFoundRange>;
    property Text: string read GetText write SetText;
    property PendingText: string read GetPendingText;
    property FullText: string read GetFullText;
    property DisplayList: IMarkdownDisplayList read GetDisplayList;
    property LayoutCount: Integer read GetLayoutCount;
    property IsDirty: Boolean read GetIsDirty;
    property ShouldAutoFollow: Boolean read GetShouldAutoFollow;
    property FlushIntervalMilliseconds: Cardinal read GetFlushIntervalMilliseconds write SetFlushIntervalMilliseconds;
    property ScrollOffset: Single read GetScrollOffset write SetScrollOffset;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Layout.Engine;

class function TMarkdownFoundRange.Create(const ItemIndex, StartCharacter,
  CharacterCount: Integer): TMarkdownFoundRange;
begin
  Result.ItemIndex := ItemIndex;
  Result.StartCharacter := StartCharacter;
  Result.CharacterCount := CharacterCount;
end;

constructor TMarkdownViewerModel.Create(const Theme: TMarkdownTheme; const Measurer: ITextMeasurer);
begin
  inherited Create;

  FTheme := Theme;
  FMeasurer := Measurer;
  FFlushIntervalMilliseconds := DefaultFlushIntervalMilliseconds;
  FImageSlots := TDictionary<string, TImageSlot>.Create;
  FImageSlotOrder := TList<string>.Create;
end;

destructor TMarkdownViewerModel.Destroy;
begin
  FImageSlotOrder.Free;
  FImageSlots.Free;

  inherited Destroy;
end;

procedure TMarkdownViewerModel.SetViewport(const Width, Height: Single);
begin
  const WidthChanged = not SameValue(FViewportWidth, Width);
  FViewportWidth := Width;
  FViewportHeight := Height;

  const NeedsRelayout = WidthChanged and (FDisplayList <> nil);
  if NeedsRelayout then
    Relayout;
end;

procedure TMarkdownViewerModel.ApplyTheme(const Theme: TMarkdownTheme);
begin
  FTheme := Theme;
  RefreshLayout;
end;

procedure TMarkdownViewerModel.RefreshLayout;
begin
  if FDisplayList <> nil then
    Relayout;
end;

function TMarkdownViewerModel.IsScrolledToBottom: Boolean;
begin
  if FDisplayList = nil then
    Exit(True);

  Result := (FScrollOffset + FViewportHeight) >= (FDisplayList.Height - BottomEpsilon);
end;

procedure TMarkdownViewerModel.AppendMarkdown(const Markdown: string; const NowMilliseconds: Int64);
begin
  if Markdown = '' then
    Exit;

  if not FDirty then
    FDirtySince := NowMilliseconds;

  FPendingMarkdown := FPendingMarkdown + Markdown;
  FDirty := True;
end;

function TMarkdownViewerModel.TryFlush(const NowMilliseconds: Int64): Boolean;
begin
  if not FDirty then
    Exit(False);

  const IsTooEarly = (NowMilliseconds - FDirtySince) < FFlushIntervalMilliseconds;
  if IsTooEarly then
    Exit(False);

  FShouldAutoFollow := IsScrolledToBottom;
  FText := FText + FPendingMarkdown;
  FPendingMarkdown := '';
  FDirty := False;
  Relayout;

  Result := True;
end;

procedure TMarkdownViewerModel.SetSelectionAnchor(const Point: TLayoutPointF);
begin
  FSelectionActive := TryResolvePosition(Point, FAnchor);
  FExtent := FAnchor;
end;

procedure TMarkdownViewerModel.SetSelectionExtent(const Point: TLayoutPointF);
begin
  if not FSelectionActive then
    Exit;

  var Position: TTextPosition;
  if TryResolvePosition(Point, Position) then
    FExtent := Position;
end;

procedure TMarkdownViewerModel.ClearSelection;
begin
  FSelectionActive := False;
end;

function TMarkdownViewerModel.HasSelection: Boolean;
begin
  if not FSelectionActive or (FDisplayList = nil) then
    Exit(False);

  const AreIndexesValid = (FAnchor.ItemIndex < FDisplayList.ItemCount) and
    (FExtent.ItemIndex < FDisplayList.ItemCount);
  Result := AreIndexesValid and (ComparePositions(FAnchor, FExtent) <> 0);
end;

function TMarkdownViewerModel.SelectionRects: TArray<TLayoutRectF>;
begin
  Result := [];
  if not HasSelection then
    Exit;

  const Range = NormalizeSelection;

  for var Index := Range.StartPosition.ItemIndex to Range.EndPosition.ItemIndex do
  begin
    var Run: IDisplayTextRun;
    if not Supports(FDisplayList.Items[Index], IDisplayTextRun, Run) then
      Continue;

    var CharFrom, CharTo: Integer;
    if not SelectedCharacterRange(Run, Index, Range.StartPosition, Range.EndPosition, CharFrom, CharTo) then
      Continue;

    const RunRect = TLayoutRectF.Create(Run.Bounds.Left + PrefixWidth(Run, CharFrom), Run.Bounds.Top,
      Run.Bounds.Left + PrefixWidth(Run, CharTo), Run.Bounds.Bottom);

    const LastIndex = High(Result);
    const MergesWithLast = (LastIndex >= 0) and SameValue(Result[LastIndex].Top, RunRect.Top, LineTopEpsilon);
    if MergesWithLast then
    begin
      Result[LastIndex].Left := Min(Result[LastIndex].Left, RunRect.Left);
      Result[LastIndex].Right := Max(Result[LastIndex].Right, RunRect.Right);
      Result[LastIndex].Bottom := Max(Result[LastIndex].Bottom, RunRect.Bottom);
    end
    else
      Result := Result + [RunRect];
  end;
end;

function TMarkdownViewerModel.SelectedText: string;
begin
  Result := '';
  if not HasSelection then
    Exit;

  const Range = NormalizeSelection;

  var HasPrevious := False;
  var PreviousTop := 0.0;
  var PreviousBlock := 0;

  for var Index := Range.StartPosition.ItemIndex to Range.EndPosition.ItemIndex do
  begin
    var Run: IDisplayTextRun;
    if not Supports(FDisplayList.Items[Index], IDisplayTextRun, Run) then
      Continue;

    var CharFrom, CharTo: Integer;
    if not SelectedCharacterRange(Run, Index, Range.StartPosition, Range.EndPosition, CharFrom, CharTo) then
      Continue;

    const Segment = Copy(Run.Text, CharFrom + 1, CharTo - CharFrom);
    const BlockIndex = BlockIndexOfItem(Index);

    if not HasPrevious then
      Result := Segment
    else if BlockIndex <> PreviousBlock then
      Result := Result + sLineBreak + Segment
    else if not SameValue(Run.Bounds.Top, PreviousTop, LineTopEpsilon) then
      Result := Result + ' ' + Segment
    else
      Result := Result + Segment;

    HasPrevious := True;
    PreviousTop := Run.Bounds.Top;
    PreviousBlock := BlockIndex;
  end;
end;

function TMarkdownViewerModel.PendingImageSources: TArray<string>;
begin
  Result := [];

  for var Source in FImageSlotOrder do
  begin
    if FImageSlots[Source].State = TMarkdownImageSlotState.Requested then
      Result := Result + [Source];
  end;
end;

procedure TMarkdownViewerModel.NotifyImageArrived(const Source: string; const Size: TLayoutSizeF);
begin
  var Slot: TImageSlot;
  if not FImageSlots.TryGetValue(Source, Slot) then
    Exit;

  if Slot.State = TMarkdownImageSlotState.Loaded then
    Exit;

  Slot.State := TMarkdownImageSlotState.Loaded;
  Slot.Size := Size;
  FImageSlots[Source] := Slot;
  Relayout;
end;

procedure TMarkdownViewerModel.NotifyImageFailed(const Source: string);
begin
  var Slot: TImageSlot;
  if not FImageSlots.TryGetValue(Source, Slot) then
    Exit;

  if Slot.State = TMarkdownImageSlotState.Loaded then
    Exit;

  Slot.State := TMarkdownImageSlotState.Failed;
  FImageSlots[Source] := Slot;
end;

function TMarkdownViewerModel.ImageSlotState(const Source: string): TMarkdownImageSlotState;
begin
  var Slot: TImageSlot;
  if FImageSlots.TryGetValue(Source, Slot) then
    Exit(Slot.State);

  Result := TMarkdownImageSlotState.Unknown;
end;

function TMarkdownViewerModel.TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
begin
  Size := Default(TLayoutSizeF);

  var Slot: TImageSlot;
  Result := FImageSlots.TryGetValue(Source, Slot) and (Slot.State = TMarkdownImageSlotState.Loaded);
  if Result then
    Size := Slot.Size;
end;

function TMarkdownViewerModel.FindText(const Needle: string): TArray<TMarkdownFoundRange>;
begin
  Result := [];

  const IsSearchable = (Needle <> '') and (FDisplayList <> nil);
  if not IsSearchable then
    Exit;

  const UpperNeedle = AnsiUpperCase(Needle);

  for var Index := 0 to FDisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    if not Supports(FDisplayList.Items[Index], IDisplayTextRun, Run) then
      Continue;

    const UpperText = AnsiUpperCase(Run.Text);
    var Offset := 1;
    var Found := Pos(UpperNeedle, UpperText, Offset);

    while Found > 0 do
    begin
      Result := Result + [TMarkdownFoundRange.Create(Index, Found, Length(Needle))];
      Offset := Found + Length(UpperNeedle);
      Found := Pos(UpperNeedle, UpperText, Offset);
    end;
  end;
end;

procedure TMarkdownViewerModel.Relayout;
begin
  if FViewportWidth <= 0 then
    Exit;

  const Document = TMarkdown.Parse(FText, TMarkdownDialect.Gfm);
  TLayoutDocumentProcessorRegistry.Process(Document);

  FDisplayList := TMarkdownLayoutEngine.LayoutDocument(Document, FViewportWidth, FTheme, FMeasurer, Self);
  Inc(FLayoutCount);
  RegisterImageSlots;
end;

procedure TMarkdownViewerModel.RegisterImageSlots;
begin
  for var Index := 0 to FDisplayList.ItemCount - 1 do
  begin
    var Image: IDisplayImage;
    if not Supports(FDisplayList.Items[Index], IDisplayImage, Image) then
      Continue;

    if FImageSlots.ContainsKey(Image.Source) then
      Continue;

    var Slot := Default(TImageSlot);
    Slot.State := TMarkdownImageSlotState.Requested;
    FImageSlots.Add(Image.Source, Slot);
    FImageSlotOrder.Add(Image.Source);
  end;
end;

function TMarkdownViewerModel.TryResolvePosition(const Point: TLayoutPointF; out Position: TTextPosition): Boolean;
begin
  Position := Default(TTextPosition);
  if FDisplayList = nil then
    Exit(False);

  var BestIndex := -1;
  var BestRun: IDisplayTextRun := nil;
  var BestVertical := MaxSingle;
  var BestHorizontal := MaxSingle;

  for var Index := 0 to FDisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    if not Supports(FDisplayList.Items[Index], IDisplayTextRun, Run) then
      Continue;

    const Bounds = Run.Bounds;
    var Vertical := 0.0;
    if Point.Y < Bounds.Top then
      Vertical := Bounds.Top - Point.Y
    else if Point.Y >= Bounds.Bottom then
      Vertical := Point.Y - Bounds.Bottom;

    var Horizontal := 0.0;
    if Point.X < Bounds.Left then
      Horizontal := Bounds.Left - Point.X
    else if Point.X > Bounds.Right then
      Horizontal := Point.X - Bounds.Right;

    const VerticalComparison = CompareValue(Vertical, BestVertical, LineTopEpsilon);
    const IsCloser = (VerticalComparison < 0) or ((VerticalComparison = 0) and (Horizontal < BestHorizontal));
    if IsCloser then
    begin
      BestIndex := Index;
      BestRun := Run;
      BestVertical := Vertical;
      BestHorizontal := Horizontal;
    end;
  end;

  if BestIndex < 0 then
    Exit(False);

  Position.ItemIndex := BestIndex;
  Position.CharacterIndex := NearestCharacterBoundary(BestRun, Point.X);
  Result := True;
end;

function TMarkdownViewerModel.NearestCharacterBoundary(const Run: IDisplayTextRun; const X: Single): Integer;
begin
  const LocalX = X - Run.Bounds.Left;

  Result := 0;
  var BestDistance := Abs(LocalX);

  for var Count := 1 to Length(Run.Text) do
  begin
    const Distance = Abs(LocalX - PrefixWidth(Run, Count));
    if Distance < BestDistance then
    begin
      BestDistance := Distance;
      Result := Count;
    end;
  end;
end;

function TMarkdownViewerModel.NormalizeSelection: TTextRange;
begin
  if ComparePositions(FAnchor, FExtent) <= 0 then
  begin
    Result.StartPosition := FAnchor;
    Result.EndPosition := FExtent;
    Exit;
  end;

  Result.StartPosition := FExtent;
  Result.EndPosition := FAnchor;
end;

class function TMarkdownViewerModel.ComparePositions(const Left, Right: TTextPosition): Integer;
begin
  Result := CompareValue(Left.ItemIndex, Right.ItemIndex);
  if Result = 0 then
    Result := CompareValue(Left.CharacterIndex, Right.CharacterIndex);
end;

function TMarkdownViewerModel.SelectedCharacterRange(const Run: IDisplayTextRun; const ItemIndex: Integer;
  const StartPosition, EndPosition: TTextPosition; out CharFrom, CharTo: Integer): Boolean;
begin
  CharFrom := 0;
  CharTo := Length(Run.Text);

  if ItemIndex = StartPosition.ItemIndex then
    CharFrom := StartPosition.CharacterIndex;
  if ItemIndex = EndPosition.ItemIndex then
    CharTo := EndPosition.CharacterIndex;

  Result := CharTo > CharFrom;
end;

function TMarkdownViewerModel.BlockIndexOfItem(const ItemIndex: Integer): Integer;
begin
  for var BlockIndex := 0 to FDisplayList.BlockCount - 1 do
  begin
    const Info = FDisplayList.BlockInfos[BlockIndex];
    const IsInsideBlock = (ItemIndex >= Info.FirstItemIndex) and (ItemIndex < Info.FirstItemIndex + Info.ItemCount);
    if IsInsideBlock then
      Exit(BlockIndex);
  end;

  Result := -1;
end;

function TMarkdownViewerModel.PrefixWidth(const Run: IDisplayTextRun; const CharacterCount: Integer): Single;
begin
  if CharacterCount <= 0 then
    Exit(0);

  Result := FMeasurer.MeasureText(Copy(Run.Text, 1, CharacterCount), Run.Font).Width;
end;

function TMarkdownViewerModel.GetText: string;
begin
  Result := FText;
end;

procedure TMarkdownViewerModel.SetText(const Value: string);
begin
  FText := Value;
  FPendingMarkdown := '';
  FDirty := False;
  ClearSelection;
  Relayout;
end;

function TMarkdownViewerModel.GetPendingText: string;
begin
  Result := FPendingMarkdown;
end;

function TMarkdownViewerModel.GetFullText: string;
begin
  Result := FText + FPendingMarkdown;
end;

function TMarkdownViewerModel.GetDisplayList: IMarkdownDisplayList;
begin
  Result := FDisplayList;
end;

function TMarkdownViewerModel.GetLayoutCount: Integer;
begin
  Result := FLayoutCount;
end;

function TMarkdownViewerModel.GetIsDirty: Boolean;
begin
  Result := FDirty;
end;

function TMarkdownViewerModel.GetShouldAutoFollow: Boolean;
begin
  Result := FShouldAutoFollow;
end;

function TMarkdownViewerModel.GetFlushIntervalMilliseconds: Cardinal;
begin
  Result := FFlushIntervalMilliseconds;
end;

procedure TMarkdownViewerModel.SetFlushIntervalMilliseconds(const Value: Cardinal);
begin
  FFlushIntervalMilliseconds := Value;
end;

function TMarkdownViewerModel.GetScrollOffset: Single;
begin
  Result := FScrollOffset;
end;

procedure TMarkdownViewerModel.SetScrollOffset(const Value: Single);
begin
  var Clamped: Single := Max(Single(0), Value);
  if FDisplayList <> nil then
  begin
    const MaxOffset = Max(Single(0), FDisplayList.Height - FViewportHeight);
    Clamped := Min(Clamped, MaxOffset);
  end;

  FScrollOffset := Clamped;
end;

end.
