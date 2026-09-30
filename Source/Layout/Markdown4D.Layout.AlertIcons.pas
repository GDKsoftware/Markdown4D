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
    procedure AddRing(const CenterX, CenterY, OuterRadius, InnerRadius: Single);
    procedure AddDisc(const CenterX, CenterY, Radius: Single);
    procedure AddBar(const Left, Top, Right, Bottom: Single);
    procedure AddOutline(const GridPoints: array of Single);
    function Point(const GridX, GridY: Single): TLayoutPointF;
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
    raise ENotSupportedException.CreateFmt('Unsupported alert kind: %d', [Ord(Kind)]);
  end;

  Result := FItems;
end;

procedure TAlertIconBuilder.AddNote;
begin
  AddRing(8, 8, 7, 5.5);
  AddDisc(8, 4.75, 1);
  AddBar(7.25, 6.75, 8.75, 11.5);
end;

procedure TAlertIconBuilder.AddTip;
begin
  AddRing(8, 6.25, 5.25, 3.75);
  AddBar(6, 11.25, 10, 12.5);
  AddBar(6.75, 13.5, 9.25, 14.75);
end;

procedure TAlertIconBuilder.AddImportant;
begin
  AddOutline([1.75, 2.25, 14.25, 2.25, 14.25, 11, 8.5, 11, 5.25, 14, 5.25, 11, 1.75, 11]);
  AddExclamation(4.25, 7.75, 9.25);
end;

procedure TAlertIconBuilder.AddWarning;
begin
  AddOutline([8, 1.75, 14.75, 13.75, 1.25, 13.75]);
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
  AddBar(7.25, BarTop, 8.75, BarBottom);
  AddDisc(8, DotY, 0.9);
end;

procedure TAlertIconBuilder.AddRing(const CenterX, CenterY, OuterRadius, InnerRadius: Single);
begin
  const Center = Point(CenterX, CenterY);
  FItems := FItems + [TDisplayWedge.Create(IconBounds, FNode, Center, OuterRadius * FScale, InnerRadius * FScale,
    0, FullTurn, FColor, 0, 0)];
end;

procedure TAlertIconBuilder.AddDisc(const CenterX, CenterY, Radius: Single);
begin
  AddRing(CenterX, CenterY, Radius, 0);
end;

procedure TAlertIconBuilder.AddBar(const Left, Top, Right, Bottom: Single);
begin
  const Corners: TArray<TLayoutPointF> = [Point(Left, Top), Point(Right, Top), Point(Right, Bottom),
    Point(Left, Bottom)];
  FItems := FItems + [TDisplayPolygon.Create(IconBounds, FNode, Corners, FColor, 0, 0)];
end;

procedure TAlertIconBuilder.AddOutline(const GridPoints: array of Single);
begin
  var Corners: TArray<TLayoutPointF>;
  for var Index := 0 to Length(GridPoints) div 2 - 1 do
  begin
    Corners := Corners + [Point(GridPoints[2 * Index], GridPoints[2 * Index + 1])];
  end;

  FItems := FItems + [TDisplayPolygon.Create(IconBounds, FNode, Corners, 0, FColor, StrokeWidth * FScale)];
end;

function TAlertIconBuilder.Point(const GridX, GridY: Single): TLayoutPointF;
begin
  Result := TLayoutPointF.Create(FLeft + GridX * FScale, FTop + GridY * FScale);
end;

function TAlertIconBuilder.IconBounds: TLayoutRectF;
begin
  const Size = GridSize * FScale;
  Result := TLayoutRectF.Create(FLeft, FTop, FLeft + Size, FTop + Size);
end;

end.
