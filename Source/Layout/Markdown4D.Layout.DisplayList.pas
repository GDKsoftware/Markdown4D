unit Markdown4D.Layout.DisplayList;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces;

type
  TDisplayItemKind = (TextRun, Rectangle, Line, Image, Checkbox, Wedge, Polygon);

  IDisplayItem = interface
    ['{4F8C2D16-A93B-4E75-8C02-D51B9E3A7F64}']
    function GetKind: TDisplayItemKind;
    function GetBounds: TLayoutRectF;
    function GetNode: IMarkdownNode;
    property Kind: TDisplayItemKind read GetKind;
    property Bounds: TLayoutRectF read GetBounds;
    property Node: IMarkdownNode read GetNode;
  end;

  IDisplayTextRun = interface(IDisplayItem)
    ['{3B7F0D92-51C6-4E28-A80D-64F1B9E3C572}']
    function GetText: string;
    function GetFont: TMarkdownFontStyle;
    function GetColor: TLayoutColor;
    function GetBaseline: Single;
    function GetStartOffset: Integer;
    property Text: string read GetText;
    property Font: TMarkdownFontStyle read GetFont;
    property Color: TLayoutColor read GetColor;
    property Baseline: Single read GetBaseline;
    property StartOffset: Integer read GetStartOffset;
  end;

  IDisplayRectangle = interface(IDisplayItem)
    ['{C7E92B48-3F51-4A06-B8D3-2E9647C1F0A5}']
    function GetFillColor: TLayoutColor;
    function GetStrokeColor: TLayoutColor;
    function GetStrokeWidth: Single;
    property FillColor: TLayoutColor read GetFillColor;
    property StrokeColor: TLayoutColor read GetStrokeColor;
    property StrokeWidth: Single read GetStrokeWidth;
  end;

  IDisplayLine = interface(IDisplayItem)
    ['{5D30A8F2-7B64-4C19-A5E8-91F2C6D40B37}']
    function GetStartPoint: TLayoutPointF;
    function GetEndPoint: TLayoutPointF;
    function GetColor: TLayoutColor;
    function GetStrokeWidth: Single;
    property StartPoint: TLayoutPointF read GetStartPoint;
    property EndPoint: TLayoutPointF read GetEndPoint;
    property Color: TLayoutColor read GetColor;
    property StrokeWidth: Single read GetStrokeWidth;
  end;

  IDisplayImage = interface(IDisplayItem)
    ['{E82C4B95-D107-4F63-BA29-6C58F3E1D7A4}']
    function GetSource: string;
    function GetAltText: string;
    property Source: string read GetSource;
    property AltText: string read GetAltText;
  end;

  IDisplayCheckbox = interface(IDisplayItem)
    ['{1F6D93A7-42E8-4C50-8B16-A9D25C7E4F83}']
    function GetChecked: Boolean;
    property Checked: Boolean read GetChecked;
  end;

  IDisplayWedge = interface(IDisplayItem)
    ['{2A8B4C61-7D39-4E52-9F04-B31C6E5A8D70}']
    function GetCenter: TLayoutPointF;
    function GetOuterRadius: Single;
    function GetInnerRadius: Single;
    function GetStartAngle: Single;
    function GetSweepAngle: Single;
    function GetFillColor: TLayoutColor;
    function GetStrokeColor: TLayoutColor;
    function GetStrokeWidth: Single;
    property Center: TLayoutPointF read GetCenter;
    property OuterRadius: Single read GetOuterRadius;
    property InnerRadius: Single read GetInnerRadius;
    property StartAngle: Single read GetStartAngle;
    property SweepAngle: Single read GetSweepAngle;
    property FillColor: TLayoutColor read GetFillColor;
    property StrokeColor: TLayoutColor read GetStrokeColor;
    property StrokeWidth: Single read GetStrokeWidth;
  end;

  IDisplayPolygon = interface(IDisplayItem)
    ['{9C3E7A15-4B08-4D62-8F31-6A0D5B2E9C74}']
    function GetPointCount: Integer;
    function GetPoint(const Index: Integer): TLayoutPointF;
    function GetFillColor: TLayoutColor;
    function GetStrokeColor: TLayoutColor;
    function GetStrokeWidth: Single;
    property PointCount: Integer read GetPointCount;
    property Points[const Index: Integer]: TLayoutPointF read GetPoint;
    property FillColor: TLayoutColor read GetFillColor;
    property StrokeColor: TLayoutColor read GetStrokeColor;
    property StrokeWidth: Single read GetStrokeWidth;
  end;

  TLayoutBlockInfo = record
    FirstItemIndex: Integer;
    ItemCount: Integer;
    Top: Single;
    Height: Single;
    SpacingAbove: Single;
    SpacingBelow: Single;
    class function Create(const FirstItemIndex, ItemCount: Integer;
      const Top, Height, SpacingAbove, SpacingBelow: Single): TLayoutBlockInfo; static;
  end;

  IMarkdownDisplayList = interface
    ['{D16A4C83-2E97-4B50-9CF2-08B5E7A3D164}']
    function GetItemCount: Integer;
    function GetItem(const Index: Integer): IDisplayItem;
    function GetWidth: Single;
    function GetContentWidth: Single;
    function GetHeight: Single;
    function GetBlockCount: Integer;
    function GetBlockInfo(const Index: Integer): TLayoutBlockInfo;
    function GetRecomputedBlockIndexes: TArray<Integer>;
    property ItemCount: Integer read GetItemCount;
    property Items[const Index: Integer]: IDisplayItem read GetItem;
    property Width: Single read GetWidth;
    property ContentWidth: Single read GetContentWidth;
    property Height: Single read GetHeight;
    property BlockCount: Integer read GetBlockCount;
    property BlockInfos[const Index: Integer]: TLayoutBlockInfo read GetBlockInfo;
    property RecomputedBlockIndexes: TArray<Integer> read GetRecomputedBlockIndexes;
  end;

implementation

class function TLayoutBlockInfo.Create(const FirstItemIndex, ItemCount: Integer;
  const Top, Height, SpacingAbove, SpacingBelow: Single): TLayoutBlockInfo;
begin
  Result.FirstItemIndex := FirstItemIndex;
  Result.ItemCount := ItemCount;
  Result.Top := Top;
  Result.Height := Height;
  Result.SpacingAbove := SpacingAbove;
  Result.SpacingBelow := SpacingBelow;
end;

end.
