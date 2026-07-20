unit Markdown4D.Layout.Renderer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList;

type
  [TestFixture]
  TMarkdownLayoutRendererTests = class
  private
    class function Triangle: TArray<TLayoutPointF>;
    class function DisplayListWith(const Item: IDisplayItem): IMarkdownDisplayList;

  public
    [Test]
    procedure Render_DisplayListWithPolygon_InvokesFillPolygonWithPoints;

    [Test]
    procedure Render_PolygonOutsideViewport_IsCulled;

    [Test]
    procedure Render_TransparentPolygon_IsSkipped;
  end;

implementation

uses
  Markdown4D.Layout.Primitives,
  Markdown4D.Layout.Renderer;

const
  DisplaySize = 100.0;
  OpaquePolygonColor = TLayoutColor($FF3366CC);
  TransparentColor = TLayoutColor($00000000);

type
  TRecordingPainter = class(TInterfacedObject, IPainter)
  private
    FFillPolygonCount: Integer;
    FLastPolygonPointCount: Integer;
    FLastPolygonColor: TLayoutColor;

  public
    function MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
    function LineHeight(const Font: TMarkdownFontStyle): Single;
    function Baseline(const Font: TMarkdownFontStyle): Single;
    procedure DrawTextRun(const TopLeft: TLayoutPointF; const Text: string; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor);
    procedure FillRect(const Bounds: TLayoutRectF; const Color: TLayoutColor);
    procedure DrawRect(const Bounds: TLayoutRectF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure DrawImage(const Bounds: TLayoutRectF; const Source: string; const SourceRect: TLayoutRectF);
    procedure FillWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const Color: TLayoutColor);
    procedure FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
    procedure SaveState;
    procedure SetClip(const Bounds: TLayoutRectF);
    procedure RestoreState;
    property FillPolygonCount: Integer read FFillPolygonCount;
    property LastPolygonPointCount: Integer read FLastPolygonPointCount;
    property LastPolygonColor: TLayoutColor read FLastPolygonColor;
  end;

function TRecordingPainter.MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
begin
  Result := TLayoutSizeF.Create(0, 0);
end;

function TRecordingPainter.LineHeight(const Font: TMarkdownFontStyle): Single;
begin
  Result := 0;
end;

function TRecordingPainter.Baseline(const Font: TMarkdownFontStyle): Single;
begin
  Result := 0;
end;

procedure TRecordingPainter.DrawTextRun(const TopLeft: TLayoutPointF; const Text: string;
  const Font: TMarkdownFontStyle; const Color: TLayoutColor);
begin
end;

procedure TRecordingPainter.FillRect(const Bounds: TLayoutRectF; const Color: TLayoutColor);
begin
end;

procedure TRecordingPainter.DrawRect(const Bounds: TLayoutRectF; const Color: TLayoutColor; const StrokeWidth: Single);
begin
end;

procedure TRecordingPainter.DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
end;

procedure TRecordingPainter.DrawImage(const Bounds: TLayoutRectF; const Source: string; const SourceRect: TLayoutRectF);
begin
end;

procedure TRecordingPainter.FillWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle,
  SweepAngle: Single; const Color: TLayoutColor);
begin
end;

procedure TRecordingPainter.FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
begin
  Inc(FFillPolygonCount);
  FLastPolygonPointCount := Length(Points);
  FLastPolygonColor := Color;
end;

procedure TRecordingPainter.SaveState;
begin
end;

procedure TRecordingPainter.SetClip(const Bounds: TLayoutRectF);
begin
end;

procedure TRecordingPainter.RestoreState;
begin
end;

class function TMarkdownLayoutRendererTests.Triangle: TArray<TLayoutPointF>;
begin
  Result := [TLayoutPointF.Create(50, 10), TLayoutPointF.Create(90, 90), TLayoutPointF.Create(10, 90)];
end;

class function TMarkdownLayoutRendererTests.DisplayListWith(const Item: IDisplayItem): IMarkdownDisplayList;
begin
  var Items: TArray<IDisplayItem> := [Item];
  var NoBlocks: TArray<TLayoutBlockInfo>;
  var NoRecomputed: TArray<Integer>;
  Result := TMarkdownDisplayList.Create(Items, NoBlocks, DisplaySize, DisplaySize, DisplaySize, NoRecomputed);
end;

procedure TMarkdownLayoutRendererTests.Render_DisplayListWithPolygon_InvokesFillPolygonWithPoints;
begin
  var Painter := TRecordingPainter.Create;
  var PainterRef: IPainter := Painter;

  const Bounds = TLayoutRectF.Create(10, 10, 90, 90);
  const Polygon: IDisplayItem = TDisplayPolygon.Create(Bounds, nil, Triangle, OpaquePolygonColor);
  const DisplayList = DisplayListWith(Polygon);
  const Viewport = TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize);

  TMarkdownDisplayListRenderer.Render(DisplayList, PainterRef, Viewport, TransparentColor);

  Assert.AreEqual(1, Painter.FillPolygonCount, 'Polygon display item must be forwarded to Painter.FillPolygon');
  Assert.AreEqual(3, Painter.LastPolygonPointCount, 'All polygon points must be passed to the painter');
  Assert.IsTrue(Painter.LastPolygonColor = OpaquePolygonColor, 'Polygon fill color must be preserved');
end;

procedure TMarkdownLayoutRendererTests.Render_PolygonOutsideViewport_IsCulled;
begin
  var Painter := TRecordingPainter.Create;
  var PainterRef: IPainter := Painter;

  const Bounds = TLayoutRectF.Create(10, 200, 90, 280);
  const Polygon: IDisplayItem = TDisplayPolygon.Create(Bounds, nil, Triangle, OpaquePolygonColor);
  const DisplayList = DisplayListWith(Polygon);
  const Viewport = TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize);

  TMarkdownDisplayListRenderer.Render(DisplayList, PainterRef, Viewport, TransparentColor);

  Assert.AreEqual(0, Painter.FillPolygonCount, 'A polygon below the viewport must be culled, not painted');
end;

procedure TMarkdownLayoutRendererTests.Render_TransparentPolygon_IsSkipped;
begin
  var Painter := TRecordingPainter.Create;
  var PainterRef: IPainter := Painter;

  const Bounds = TLayoutRectF.Create(10, 10, 90, 90);
  const Polygon: IDisplayItem = TDisplayPolygon.Create(Bounds, nil, Triangle, TransparentColor);
  const DisplayList = DisplayListWith(Polygon);
  const Viewport = TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize);

  TMarkdownDisplayListRenderer.Render(DisplayList, PainterRef, Viewport, TransparentColor);

  Assert.AreEqual(0, Painter.FillPolygonCount, 'A fully transparent polygon must not reach the painter');
end;

end.
