unit Markdown4D.Layout.AlertIcons;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Alerts,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList;

type
  // The icon in front of an alert title, built from the display list's own
  // shapes so both viewers draw it anti-aliased: an information circle for a
  // note, a light bulb for a tip, a speech bubble for important, a triangle
  // for a warning and an octagon for a caution. The shapes are designed on a
  // grid of 16 and scaled to the size asked for.
  TAlertIconBuilder = class
  private
    const
      GridSize = 16.0;
      GridCentre = GridSize / 2;
      StrokeWidth = 1.5;
      FullTurn = 360.0;
      OctagonCorners = 8;
      OctagonRadius = 6.75;
      OctagonStartAngle = 22.5;
      // The upright of an exclamation mark or of the i in the note icon.
      UprightLeft = 7.25;
      UprightRight = 8.75;
      DotRadius = 0.9;
      // The two bands under the light bulb of the tip icon.
      BulbNeckHalfWidth = 2.0;
      BulbBaseHalfWidth = 1.25;
    var
      FLeft: Single;
      FTop: Single;
      FScale: Single;
      FColor: TLayoutColor;
      FNode: IMarkdownNode;
      FItems: TArray<IDisplayItem>;
    procedure AddNote;
    procedure AddTip;
    procedure AddImportant;
    procedure AddWarning;
    procedure AddCaution;
    procedure AddExclamation(const BarTop, BarBottom, DotY: Single);
    procedure AddDisc(const CenterX, CenterY, Radius: Single);
    procedure AddRing(const CenterX, CenterY, OuterRadius, InnerRadius: Single);
    procedure AddBar(const Left, Top, Right, Bottom: Single);
    procedure AddOutline(const GridPoints: array of Single);
    procedure AddItem(const Item: IDisplayItem);
    function GridPoint(const GridX, GridY: Single): TLayoutPointF;
    function IconBounds: TLayoutRectF;

  public
    constructor Create(const Left, Top, Size: Single; const Color: TLayoutColor; const Node: IMarkdownNode);
    function Build(const Kind: TMarkdownAlertKind): TArray<IDisplayItem>;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D.Layout.Primitives;

constructor TAlertIconBuilder.Create(const Left, Top, Size: Single; const Color: TLayoutColor;
  const Node: IMarkdownNode);
begin
  inherited Create;

  FLeft := Left;
  FTop := Top;
  FScale := Size / GridSize;
  FColor := Color;
  FNode := Node;
end;

function TAlertIconBuilder.Build(const Kind: TMarkdownAlertKind): TArray<IDisplayItem>;
begin
  FItems := nil;

  case Kind of
    TMarkdownAlertKind.Note      : AddNote;
    TMarkdownAlertKind.Tip       : AddTip;
    TMarkdownAlertKind.Important : AddImportant;
    TMarkdownAlertKind.Warning   : AddWarning;
    TMarkdownAlertKind.Caution   : AddCaution;
  else
    raise ENotSupportedException.CreateFmt(TMarkdownAlerts.UnsupportedKindMessage, [Ord(Kind)]);
  end;

  Result := FItems;
end;

procedure TAlertIconBuilder.AddNote;
begin
  AddRing(GridCentre, GridCentre, 7, 5.5);
  AddDisc(GridCentre, 4.75, 1);
  AddBar(UprightLeft, 6.75, UprightRight, 11.5);
end;

procedure TAlertIconBuilder.AddTip;
begin
  AddRing(GridCentre, 6.25, 5.25, 3.75);
  AddBar(GridCentre - BulbNeckHalfWidth, 11.25, GridCentre + BulbNeckHalfWidth, 12.5);
  AddBar(GridCentre - BulbBaseHalfWidth, 13.5, GridCentre + BulbBaseHalfWidth, 14.75);
end;

procedure TAlertIconBuilder.AddImportant;
begin
  AddOutline([1.75, 2.25, 14.25, 2.25, 14.25, 11, 8.5, 11, 5.25, 14, 5.25, 11, 1.75, 11]);
  AddExclamation(4.25, 7.75, 9.25);
end;

procedure TAlertIconBuilder.AddWarning;
begin
  AddOutline([GridCentre, 1.75, 14.75, 13.75, 1.25, 13.75]);
  AddExclamation(5.75, 9.5, 11.5);
end;

procedure TAlertIconBuilder.AddCaution;
begin
  var GridPoints: TArray<Single>;
  for var Corner := 0 to OctagonCorners - 1 do
  begin
    const Angle = DegToRad(OctagonStartAngle + Corner * FullTurn / OctagonCorners);
    const CornerX = GridCentre + OctagonRadius * Cos(Angle);
    const CornerY = GridCentre + OctagonRadius * Sin(Angle);
    GridPoints := GridPoints + [CornerX, CornerY];
  end;

  AddOutline(GridPoints);
  AddExclamation(4.5, 8.75, 10.75);
end;

procedure TAlertIconBuilder.AddExclamation(const BarTop, BarBottom, DotY: Single);
begin
  AddBar(UprightLeft, BarTop, UprightRight, BarBottom);
  AddDisc(GridCentre, DotY, DotRadius);
end;

procedure TAlertIconBuilder.AddDisc(const CenterX, CenterY, Radius: Single);
begin
  AddRing(CenterX, CenterY, Radius, 0);
end;

procedure TAlertIconBuilder.AddRing(const CenterX, CenterY, OuterRadius, InnerRadius: Single);
begin
  const Center = GridPoint(CenterX, CenterY);
  const Bounds = IconBounds;
  const Ring: IDisplayItem = TDisplayWedge.Create(Bounds, FNode, Center, OuterRadius * FScale,
    InnerRadius * FScale, 0, FullTurn, FColor, 0, 0);
  AddItem(Ring);
end;

procedure TAlertIconBuilder.AddBar(const Left, Top, Right, Bottom: Single);
begin
  const TopLeft = GridPoint(Left, Top);
  const TopRight = GridPoint(Right, Top);
  const BottomRight = GridPoint(Right, Bottom);
  const BottomLeft = GridPoint(Left, Bottom);
  const Bounds = IconBounds;

  const Bar: IDisplayItem = TDisplayPolygon.Create(Bounds, FNode, [TopLeft, TopRight, BottomRight, BottomLeft],
    FColor, 0, 0);
  AddItem(Bar);
end;

procedure TAlertIconBuilder.AddOutline(const GridPoints: array of Single);
begin
  var Corners: TArray<TLayoutPointF>;
  for var Index := 0 to Length(GridPoints) div 2 - 1 do
  begin
    const Corner = GridPoint(GridPoints[2 * Index], GridPoints[2 * Index + 1]);
    Corners := Corners + [Corner];
  end;

  const Bounds = IconBounds;
  const Outline: IDisplayItem = TDisplayPolygon.Create(Bounds, FNode, Corners, 0, FColor, StrokeWidth * FScale);
  AddItem(Outline);
end;

procedure TAlertIconBuilder.AddItem(const Item: IDisplayItem);
begin
  FItems := FItems + [Item];
end;

function TAlertIconBuilder.GridPoint(const GridX, GridY: Single): TLayoutPointF;
begin
  Result := TLayoutPointF.Create(FLeft + GridX * FScale, FTop + GridY * FScale);
end;

function TAlertIconBuilder.IconBounds: TLayoutRectF;
begin
  const Size = GridSize * FScale;
  Result := TLayoutRectF.Create(FLeft, FTop, FLeft + Size, FTop + Size);
end;

end.
