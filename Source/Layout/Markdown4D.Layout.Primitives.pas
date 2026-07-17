unit Markdown4D.Layout.Primitives;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList;

type
  IDisplayItemShift = interface
    ['{D47F1B29-6C85-4E03-9A62-31B8E5D0C7A4}']
    function Shifted(const DeltaX, DeltaY: Single): IDisplayItem;
  end;

  TDisplayItem = class(TInterfacedObject, IDisplayItem, IDisplayItemShift)
  private
    FKind: TDisplayItemKind;
    FBounds: TLayoutRectF;
    FNode: IMarkdownNode;
    function GetKind: TDisplayItemKind;
    function GetBounds: TLayoutRectF;
    function GetNode: IMarkdownNode;

  protected
    function ShiftedBounds(const DeltaX, DeltaY: Single): TLayoutRectF;

  public
    constructor Create(const Kind: TDisplayItemKind; const Bounds: TLayoutRectF; const Node: IMarkdownNode);
    function Shifted(const DeltaX, DeltaY: Single): IDisplayItem; virtual; abstract;
  end;

  TDisplayTextRun = class(TDisplayItem, IDisplayTextRun)
  private
    FText: string;
    FFont: TMarkdownFontStyle;
    FColor: TLayoutColor;
    FBaseline: Single;
    FStartOffset: Integer;
    function GetText: string;
    function GetFont: TMarkdownFontStyle;
    function GetColor: TLayoutColor;
    function GetBaseline: Single;
    function GetStartOffset: Integer;

  public
    constructor Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode; const Text: string;
      const Font: TMarkdownFontStyle; const Color: TLayoutColor; const Baseline: Single; const StartOffset: Integer);
    function Shifted(const DeltaX, DeltaY: Single): IDisplayItem; override;
  end;

  TDisplayRectangle = class(TDisplayItem, IDisplayRectangle)
  private
    FFillColor: TLayoutColor;
    FStrokeColor: TLayoutColor;
    FStrokeWidth: Single;
    function GetFillColor: TLayoutColor;
    function GetStrokeColor: TLayoutColor;
    function GetStrokeWidth: Single;

  public
    constructor Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode; const FillColor: TLayoutColor;
      const StrokeColor: TLayoutColor; const StrokeWidth: Single);
    function Shifted(const DeltaX, DeltaY: Single): IDisplayItem; override;
  end;

  TDisplayLine = class(TDisplayItem, IDisplayLine)
  private
    FStartPoint: TLayoutPointF;
    FEndPoint: TLayoutPointF;
    FColor: TLayoutColor;
    FStrokeWidth: Single;
    function GetStartPoint: TLayoutPointF;
    function GetEndPoint: TLayoutPointF;
    function GetColor: TLayoutColor;
    function GetStrokeWidth: Single;

  public
    constructor Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode; const StartPoint, EndPoint: TLayoutPointF;
      const Color: TLayoutColor; const StrokeWidth: Single);
    function Shifted(const DeltaX, DeltaY: Single): IDisplayItem; override;
  end;

  TDisplayImage = class(TDisplayItem, IDisplayImage)
  private
    FSource: string;
    FAltText: string;
    function GetSource: string;
    function GetAltText: string;

  public
    constructor Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode; const Source, AltText: string);
    function Shifted(const DeltaX, DeltaY: Single): IDisplayItem; override;
  end;

  TDisplayCheckbox = class(TDisplayItem, IDisplayCheckbox)
  private
    FChecked: Boolean;
    function GetChecked: Boolean;

  public
    constructor Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode; const Checked: Boolean);
    function Shifted(const DeltaX, DeltaY: Single): IDisplayItem; override;
  end;

  TDisplayWedge = class(TDisplayItem, IDisplayWedge)
  private
    FCenter: TLayoutPointF;
    FOuterRadius: Single;
    FInnerRadius: Single;
    FStartAngle: Single;
    FSweepAngle: Single;
    FFillColor: TLayoutColor;
    function GetCenter: TLayoutPointF;
    function GetOuterRadius: Single;
    function GetInnerRadius: Single;
    function GetStartAngle: Single;
    function GetSweepAngle: Single;
    function GetFillColor: TLayoutColor;

  public
    constructor Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode; const Center: TLayoutPointF;
      const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single; const FillColor: TLayoutColor);
    function Shifted(const DeltaX, DeltaY: Single): IDisplayItem; override;
  end;

  TDisplayPolygon = class(TDisplayItem, IDisplayPolygon)
  private
    FPoints: TArray<TLayoutPointF>;
    FFillColor: TLayoutColor;
    function GetPointCount: Integer;
    function GetPoint(const Index: Integer): TLayoutPointF;
    function GetFillColor: TLayoutColor;

  public
    constructor Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode; const Points: TArray<TLayoutPointF>;
      const FillColor: TLayoutColor);
    function Shifted(const DeltaX, DeltaY: Single): IDisplayItem; override;
  end;

  TMarkdownDisplayList = class(TInterfacedObject, IMarkdownDisplayList)
  private
    FItems: TArray<IDisplayItem>;
    FBlocks: TArray<TLayoutBlockInfo>;
    FWidth: Single;
    FContentWidth: Single;
    FHeight: Single;
    FRecomputedBlockIndexes: TArray<Integer>;
    function GetItemCount: Integer;
    function GetItem(const Index: Integer): IDisplayItem;
    function GetWidth: Single;
    function GetContentWidth: Single;
    function GetHeight: Single;
    function GetBlockCount: Integer;
    function GetRecomputedBlockIndexes: TArray<Integer>;
    function GetBlockInfo(const Index: Integer): TLayoutBlockInfo;

  public
    constructor Create(const Items: TArray<IDisplayItem>; const Blocks: TArray<TLayoutBlockInfo>;
      const Width, ContentWidth, Height: Single; const RecomputedBlockIndexes: TArray<Integer>);
  end;

implementation

uses
  Markdown4D.Defines;

constructor TDisplayItem.Create(const Kind: TDisplayItemKind; const Bounds: TLayoutRectF; const Node: IMarkdownNode);
begin
  inherited Create;

  FKind := Kind;
  FBounds := Bounds;
  FNode := Node;
end;

function TDisplayItem.GetKind: TDisplayItemKind;
begin
  Result := FKind;
end;

function TDisplayItem.GetBounds: TLayoutRectF;
begin
  Result := FBounds;
end;

function TDisplayItem.GetNode: IMarkdownNode;
begin
  Result := FNode;
end;

function TDisplayItem.ShiftedBounds(const DeltaX, DeltaY: Single): TLayoutRectF;
begin
  Result := TLayoutRectF.Create(FBounds.Left + DeltaX, FBounds.Top + DeltaY, FBounds.Right + DeltaX,
    FBounds.Bottom + DeltaY);
end;

constructor TDisplayTextRun.Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode; const Text: string;
  const Font: TMarkdownFontStyle; const Color: TLayoutColor; const Baseline: Single; const StartOffset: Integer);
begin
  inherited Create(TDisplayItemKind.TextRun, Bounds, Node);

  FText := Text;
  FFont := Font;
  FColor := Color;
  FBaseline := Baseline;
  FStartOffset := StartOffset;
end;

function TDisplayTextRun.GetText: string;
begin
  Result := FText;
end;

function TDisplayTextRun.GetFont: TMarkdownFontStyle;
begin
  Result := FFont;
end;

function TDisplayTextRun.GetColor: TLayoutColor;
begin
  Result := FColor;
end;

function TDisplayTextRun.GetBaseline: Single;
begin
  Result := FBaseline;
end;

function TDisplayTextRun.GetStartOffset: Integer;
begin
  Result := FStartOffset;
end;

function TDisplayTextRun.Shifted(const DeltaX, DeltaY: Single): IDisplayItem;
begin
  Result := TDisplayTextRun.Create(ShiftedBounds(DeltaX, DeltaY), FNode, FText, FFont, FColor, FBaseline, FStartOffset);
end;

constructor TDisplayRectangle.Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode;
  const FillColor: TLayoutColor; const StrokeColor: TLayoutColor; const StrokeWidth: Single);
begin
  inherited Create(TDisplayItemKind.Rectangle, Bounds, Node);

  FFillColor := FillColor;
  FStrokeColor := StrokeColor;
  FStrokeWidth := StrokeWidth;
end;

function TDisplayRectangle.GetFillColor: TLayoutColor;
begin
  Result := FFillColor;
end;

function TDisplayRectangle.GetStrokeColor: TLayoutColor;
begin
  Result := FStrokeColor;
end;

function TDisplayRectangle.GetStrokeWidth: Single;
begin
  Result := FStrokeWidth;
end;

function TDisplayRectangle.Shifted(const DeltaX, DeltaY: Single): IDisplayItem;
begin
  Result := TDisplayRectangle.Create(ShiftedBounds(DeltaX, DeltaY), FNode, FFillColor, FStrokeColor, FStrokeWidth);
end;

constructor TDisplayLine.Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode;
  const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor; const StrokeWidth: Single);
begin
  inherited Create(TDisplayItemKind.Line, Bounds, Node);

  FStartPoint := StartPoint;
  FEndPoint := EndPoint;
  FColor := Color;
  FStrokeWidth := StrokeWidth;
end;

function TDisplayLine.GetStartPoint: TLayoutPointF;
begin
  Result := FStartPoint;
end;

function TDisplayLine.GetEndPoint: TLayoutPointF;
begin
  Result := FEndPoint;
end;

function TDisplayLine.GetColor: TLayoutColor;
begin
  Result := FColor;
end;

function TDisplayLine.GetStrokeWidth: Single;
begin
  Result := FStrokeWidth;
end;

function TDisplayLine.Shifted(const DeltaX, DeltaY: Single): IDisplayItem;
begin
  const NewStart = TLayoutPointF.Create(FStartPoint.X + DeltaX, FStartPoint.Y + DeltaY);
  const NewEnd = TLayoutPointF.Create(FEndPoint.X + DeltaX, FEndPoint.Y + DeltaY);

  Result := TDisplayLine.Create(ShiftedBounds(DeltaX, DeltaY), FNode, NewStart, NewEnd, FColor, FStrokeWidth);
end;

constructor TDisplayImage.Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode; const Source, AltText: string);
begin
  inherited Create(TDisplayItemKind.Image, Bounds, Node);

  FSource := Source;
  FAltText := AltText;
end;

function TDisplayImage.GetSource: string;
begin
  Result := FSource;
end;

function TDisplayImage.GetAltText: string;
begin
  Result := FAltText;
end;

function TDisplayImage.Shifted(const DeltaX, DeltaY: Single): IDisplayItem;
begin
  Result := TDisplayImage.Create(ShiftedBounds(DeltaX, DeltaY), FNode, FSource, FAltText);
end;

constructor TDisplayCheckbox.Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode; const Checked: Boolean);
begin
  inherited Create(TDisplayItemKind.Checkbox, Bounds, Node);

  FChecked := Checked;
end;

function TDisplayCheckbox.GetChecked: Boolean;
begin
  Result := FChecked;
end;

function TDisplayCheckbox.Shifted(const DeltaX, DeltaY: Single): IDisplayItem;
begin
  Result := TDisplayCheckbox.Create(ShiftedBounds(DeltaX, DeltaY), FNode, FChecked);
end;

constructor TDisplayWedge.Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode; const Center: TLayoutPointF;
  const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single; const FillColor: TLayoutColor);
begin
  inherited Create(TDisplayItemKind.Wedge, Bounds, Node);

  FCenter := Center;
  FOuterRadius := OuterRadius;
  FInnerRadius := InnerRadius;
  FStartAngle := StartAngle;
  FSweepAngle := SweepAngle;
  FFillColor := FillColor;
end;

function TDisplayWedge.GetCenter: TLayoutPointF;
begin
  Result := FCenter;
end;

function TDisplayWedge.GetOuterRadius: Single;
begin
  Result := FOuterRadius;
end;

function TDisplayWedge.GetInnerRadius: Single;
begin
  Result := FInnerRadius;
end;

function TDisplayWedge.GetStartAngle: Single;
begin
  Result := FStartAngle;
end;

function TDisplayWedge.GetSweepAngle: Single;
begin
  Result := FSweepAngle;
end;

function TDisplayWedge.GetFillColor: TLayoutColor;
begin
  Result := FFillColor;
end;

function TDisplayWedge.Shifted(const DeltaX, DeltaY: Single): IDisplayItem;
begin
  const NewCenter = TLayoutPointF.Create(FCenter.X + DeltaX, FCenter.Y + DeltaY);

  Result := TDisplayWedge.Create(ShiftedBounds(DeltaX, DeltaY), FNode, NewCenter, FOuterRadius, FInnerRadius,
    FStartAngle, FSweepAngle, FFillColor);
end;

constructor TDisplayPolygon.Create(const Bounds: TLayoutRectF; const Node: IMarkdownNode;
  const Points: TArray<TLayoutPointF>; const FillColor: TLayoutColor);
begin
  inherited Create(TDisplayItemKind.Polygon, Bounds, Node);

  FPoints := Points;
  FFillColor := FillColor;
end;

function TDisplayPolygon.GetPointCount: Integer;
begin
  Result := Length(FPoints);
end;

function TDisplayPolygon.GetPoint(const Index: Integer): TLayoutPointF;
begin
  Result := FPoints[Index];
end;

function TDisplayPolygon.GetFillColor: TLayoutColor;
begin
  Result := FFillColor;
end;

function TDisplayPolygon.Shifted(const DeltaX, DeltaY: Single): IDisplayItem;
begin
  var Moved: TArray<TLayoutPointF>;
  SetLength(Moved, Length(FPoints));

  for var Index := 0 to High(FPoints) do
  begin
    Moved[Index] := TLayoutPointF.Create(FPoints[Index].X + DeltaX, FPoints[Index].Y + DeltaY);
  end;

  Result := TDisplayPolygon.Create(ShiftedBounds(DeltaX, DeltaY), FNode, Moved, FFillColor);
end;

constructor TMarkdownDisplayList.Create(const Items: TArray<IDisplayItem>; const Blocks: TArray<TLayoutBlockInfo>;
  const Width, ContentWidth, Height: Single; const RecomputedBlockIndexes: TArray<Integer>);
begin
  inherited Create;

  FItems := Items;
  FBlocks := Blocks;
  FWidth := Width;
  FContentWidth := ContentWidth;
  FHeight := Height;
  FRecomputedBlockIndexes := RecomputedBlockIndexes;
end;

function TMarkdownDisplayList.GetItemCount: Integer;
begin
  Result := Length(FItems);
end;

function TMarkdownDisplayList.GetItem(const Index: Integer): IDisplayItem;
begin
  Result := FItems[Index];
end;

function TMarkdownDisplayList.GetWidth: Single;
begin
  Result := FWidth;
end;

function TMarkdownDisplayList.GetContentWidth: Single;
begin
  Result := FContentWidth;
end;

function TMarkdownDisplayList.GetHeight: Single;
begin
  Result := FHeight;
end;

function TMarkdownDisplayList.GetBlockCount: Integer;
begin
  Result := Length(FBlocks);
end;

function TMarkdownDisplayList.GetRecomputedBlockIndexes: TArray<Integer>;
begin
  Result := FRecomputedBlockIndexes;
end;

function TMarkdownDisplayList.GetBlockInfo(const Index: Integer): TLayoutBlockInfo;
begin
  const IsValidIndex = (Index >= 0) and (Index < Length(FBlocks));
  if not IsValidIndex then
    raise EMarkdownError.CreateFmt('Block index %d is out of range for %d blocks', [Index, Length(FBlocks)]);

  Result := FBlocks[Index];
end;

end.
