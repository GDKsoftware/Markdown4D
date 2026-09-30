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
    class function AllInside(const Points: TArray<TLayoutPointF>; const Box: TLayoutRectF): Boolean;
    class function IsWholeNumber(const Value: Single): Boolean;

  public
    [Test]
    procedure Render_TextRun_InvokesDrawTextRun;

    [Test]
    procedure Render_SourceRun_IsNotPainted;

    [Test]
    procedure Render_DisplayListWithPolygon_InvokesFillPolygonWithPoints;

    [Test]
    procedure Render_PolygonOutsideViewport_IsCulled;

    [Test]
    procedure Render_TransparentPolygon_IsSkipped;

    [Test]
    procedure Render_StrokedPolygon_InvokesDrawPolygonWithStroke;

    [Test]
    procedure Render_PolygonWithoutStroke_DoesNotInvokeDrawPolygon;

    [Test]
    procedure Render_StrokedWedge_InvokesDrawWedgeWithStroke;

    [Test]
    procedure Render_WedgeWithoutStroke_DoesNotInvokeDrawWedge;

    [Test]
    procedure Render_CheckedCheckbox_FillsCheckMarkInsideBox;

    [Test]
    procedure Render_UncheckedCheckbox_DrawsBoxOnly;

    [Test]
    procedure Render_CheckboxAtFractionalPosition_DrawsPixelAlignedBox;

    [Test]
    [TestCase('Small', '8,1')]
    [TestCase('Default', '16,1')]
    [TestCase('Double', '32,2')]
    [TestCase('Large', '56,4')]
    procedure Render_CheckboxOfSize_ScalesBorderToWholePixels(const Size, ExpectedBorderWidth: Integer);
  end;

implementation

uses
  Markdown4D.Layout.Primitives,
  Markdown4D.Layout.Renderer;

const
  DisplaySize = 100.0;
  OpaquePolygonColor = TLayoutColor($FF3366CC);
  TransparentColor = TLayoutColor($00000000);
  OpaqueStrokeColor = TLayoutColor($FF112233);
  PolygonStrokeWidth = 1.5;
  CheckboxSize = 16.0;
  FractionalOffset = 0.4;

type
  TRecordingPainter = class(TInterfacedObject, IPainter)
  private
    FDrawTextRunCount: Integer;
    FDrawRectCount: Integer;
    FLastRectBounds: TLayoutRectF;
    FLastRectStrokeWidth: Single;
    FDrawLineCount: Integer;
    FFillPolygonCount: Integer;
    FLastPolygonPoints: TArray<TLayoutPointF>;
    FLastPolygonPointCount: Integer;
    FLastPolygonColor: TLayoutColor;
    FDrawPolygonCount: Integer;
    FLastPolygonStrokeColor: TLayoutColor;
    FLastPolygonStrokeWidth: Single;
    FFillWedgeCount: Integer;
    FDrawWedgeCount: Integer;
    FLastWedgeStrokeColor: TLayoutColor;
    FLastWedgeStrokeWidth: Single;

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
    procedure DrawWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const Color: TLayoutColor; const StrokeWidth: Single);
    procedure FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
    procedure DrawPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure SaveState;
    procedure SetClip(const Bounds: TLayoutRectF);
    procedure RestoreState;
    property FillPolygonCount: Integer read FFillPolygonCount;
    property DrawTextRunCount: Integer read FDrawTextRunCount;
    property DrawRectCount: Integer read FDrawRectCount;
    property LastRectBounds: TLayoutRectF read FLastRectBounds;
    property LastRectStrokeWidth: Single read FLastRectStrokeWidth;
    property DrawLineCount: Integer read FDrawLineCount;
    property LastPolygonPoints: TArray<TLayoutPointF> read FLastPolygonPoints;
    property LastPolygonPointCount: Integer read FLastPolygonPointCount;
    property LastPolygonColor: TLayoutColor read FLastPolygonColor;
    property DrawPolygonCount: Integer read FDrawPolygonCount;
    property LastPolygonStrokeColor: TLayoutColor read FLastPolygonStrokeColor;
    property LastPolygonStrokeWidth: Single read FLastPolygonStrokeWidth;
    property FillWedgeCount: Integer read FFillWedgeCount;
    property DrawWedgeCount: Integer read FDrawWedgeCount;
    property LastWedgeStrokeColor: TLayoutColor read FLastWedgeStrokeColor;
    property LastWedgeStrokeWidth: Single read FLastWedgeStrokeWidth;
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
  Inc(FDrawTextRunCount);
end;

procedure TRecordingPainter.FillRect(const Bounds: TLayoutRectF; const Color: TLayoutColor);
begin
end;

procedure TRecordingPainter.DrawRect(const Bounds: TLayoutRectF; const Color: TLayoutColor; const StrokeWidth: Single);
begin
  Inc(FDrawRectCount);
  FLastRectBounds := Bounds;
  FLastRectStrokeWidth := StrokeWidth;
end;

procedure TRecordingPainter.DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  Inc(FDrawLineCount);
end;

procedure TRecordingPainter.DrawImage(const Bounds: TLayoutRectF; const Source: string; const SourceRect: TLayoutRectF);
begin
end;

procedure TRecordingPainter.FillWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle,
  SweepAngle: Single; const Color: TLayoutColor);
begin
  Inc(FFillWedgeCount);
end;

procedure TRecordingPainter.DrawWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle,
  SweepAngle: Single; const Color: TLayoutColor; const StrokeWidth: Single);
begin
  Inc(FDrawWedgeCount);
  FLastWedgeStrokeColor := Color;
  FLastWedgeStrokeWidth := StrokeWidth;
end;

procedure TRecordingPainter.FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
begin
  Inc(FFillPolygonCount);
  FLastPolygonPoints := Points;
  FLastPolygonPointCount := Length(Points);
  FLastPolygonColor := Color;
end;

procedure TRecordingPainter.DrawPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  Inc(FDrawPolygonCount);
  FLastPolygonStrokeColor := Color;
  FLastPolygonStrokeWidth := StrokeWidth;
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

class function TMarkdownLayoutRendererTests.AllInside(const Points: TArray<TLayoutPointF>;
  const Box: TLayoutRectF): Boolean;
begin
  Result := (Length(Points) > 0);
  for var Point in Points do
  begin
    const IsInside = ((Point.X >= Box.Left) and
                      (Point.X <= Box.Right) and
                      (Point.Y >= Box.Top) and
                      (Point.Y <= Box.Bottom));
    if not IsInside then
      Exit(False);
  end;
end;

class function TMarkdownLayoutRendererTests.IsWholeNumber(const Value: Single): Boolean;
begin
  Result := (Frac(Value) = 0);
end;

procedure TMarkdownLayoutRendererTests.Render_TextRun_InvokesDrawTextRun;
begin
  const Painter = TRecordingPainter.Create;
  const PainterLifetime: IPainter = Painter;
  const Run = TDisplayTextRun.Create(TLayoutRectF.Create(0, 0, 40, 20), nil, 'text',
    TMarkdownFontStyle.Create('Test', 16), $FF000000, 12, 0);

  TMarkdownDisplayListRenderer.Render(DisplayListWith(Run), PainterLifetime,
    TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize), 0);

  Assert.AreEqual(1, Painter.DrawTextRunCount);
end;

procedure TMarkdownLayoutRendererTests.Render_SourceRun_IsNotPainted;
begin
  const Painter = TRecordingPainter.Create;
  const PainterLifetime: IPainter = Painter;
  const Run = TDisplayTextRun.Create(TLayoutRectF.Create(0, 0, 40, 20), nil, '$x$',
    TMarkdownFontStyle.Create('Test', 16), $FF000000, 12, 0, TDisplayTextRunRole.Source);

  TMarkdownDisplayListRenderer.Render(DisplayListWith(Run), PainterLifetime,
    TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize), 0);

  Assert.AreEqual(0, Painter.DrawTextRunCount);
end;

procedure TMarkdownLayoutRendererTests.Render_DisplayListWithPolygon_InvokesFillPolygonWithPoints;
begin
  var Painter := TRecordingPainter.Create;
  var PainterRef: IPainter := Painter;

  const Bounds = TLayoutRectF.Create(10, 10, 90, 90);
  const Polygon: IDisplayItem = TDisplayPolygon.Create(Bounds, nil, Triangle, OpaquePolygonColor, 0, 0);
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
  const Polygon: IDisplayItem = TDisplayPolygon.Create(Bounds, nil, Triangle, OpaquePolygonColor, 0, 0);
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
  const Polygon: IDisplayItem = TDisplayPolygon.Create(Bounds, nil, Triangle, TransparentColor, 0, 0);
  const DisplayList = DisplayListWith(Polygon);
  const Viewport = TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize);

  TMarkdownDisplayListRenderer.Render(DisplayList, PainterRef, Viewport, TransparentColor);

  Assert.AreEqual(0, Painter.FillPolygonCount, 'A fully transparent polygon must not reach the painter');
end;

procedure TMarkdownLayoutRendererTests.Render_StrokedPolygon_InvokesDrawPolygonWithStroke;
begin
  var Painter := TRecordingPainter.Create;
  var PainterRef: IPainter := Painter;

  const Bounds = TLayoutRectF.Create(10, 10, 90, 90);
  const Polygon: IDisplayItem = TDisplayPolygon.Create(Bounds, nil, Triangle, OpaquePolygonColor, OpaqueStrokeColor,
    PolygonStrokeWidth);
  const DisplayList = DisplayListWith(Polygon);
  const Viewport = TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize);

  TMarkdownDisplayListRenderer.Render(DisplayList, PainterRef, Viewport, TransparentColor);

  Assert.AreEqual(1, Painter.FillPolygonCount, 'A stroked polygon must still be filled');
  Assert.AreEqual(1, Painter.DrawPolygonCount, 'A polygon with a stroke color and width must be outlined');
  Assert.IsTrue(Painter.LastPolygonStrokeColor = OpaqueStrokeColor, 'Polygon stroke color must be preserved');
  Assert.AreEqual(PolygonStrokeWidth, Painter.LastPolygonStrokeWidth, 0.001, 'Polygon stroke width must be preserved');
end;

procedure TMarkdownLayoutRendererTests.Render_PolygonWithoutStroke_DoesNotInvokeDrawPolygon;
begin
  var Painter := TRecordingPainter.Create;
  var PainterRef: IPainter := Painter;

  const Bounds = TLayoutRectF.Create(10, 10, 90, 90);
  const Polygon: IDisplayItem = TDisplayPolygon.Create(Bounds, nil, Triangle, OpaquePolygonColor, 0, 0);
  const DisplayList = DisplayListWith(Polygon);
  const Viewport = TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize);

  TMarkdownDisplayListRenderer.Render(DisplayList, PainterRef, Viewport, TransparentColor);

  Assert.AreEqual(0, Painter.DrawPolygonCount, 'A polygon with no stroke color or width must not be outlined');
end;

procedure TMarkdownLayoutRendererTests.Render_StrokedWedge_InvokesDrawWedgeWithStroke;
begin
  var Painter := TRecordingPainter.Create;
  var PainterRef: IPainter := Painter;

  const Bounds = TLayoutRectF.Create(10, 10, 90, 90);
  const Wedge: IDisplayItem = TDisplayWedge.Create(Bounds, nil, TLayoutPointF.Create(50, 50), 40, 0, 0, 360,
    OpaquePolygonColor, OpaqueStrokeColor, PolygonStrokeWidth);
  const DisplayList = DisplayListWith(Wedge);
  const Viewport = TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize);

  TMarkdownDisplayListRenderer.Render(DisplayList, PainterRef, Viewport, TransparentColor);

  Assert.AreEqual(1, Painter.FillWedgeCount, 'A stroked wedge must still be filled');
  Assert.AreEqual(1, Painter.DrawWedgeCount, 'A wedge with a stroke color and width must be outlined');
  Assert.IsTrue(Painter.LastWedgeStrokeColor = OpaqueStrokeColor, 'Wedge stroke color must be preserved');
  Assert.AreEqual(PolygonStrokeWidth, Painter.LastWedgeStrokeWidth, 0.001, 'Wedge stroke width must be preserved');
end;

procedure TMarkdownLayoutRendererTests.Render_WedgeWithoutStroke_DoesNotInvokeDrawWedge;
begin
  var Painter := TRecordingPainter.Create;
  var PainterRef: IPainter := Painter;

  const Bounds = TLayoutRectF.Create(10, 10, 90, 90);
  const Wedge: IDisplayItem = TDisplayWedge.Create(Bounds, nil, TLayoutPointF.Create(50, 50), 40, 0, 0, 360,
    OpaquePolygonColor, 0, 0);
  const DisplayList = DisplayListWith(Wedge);
  const Viewport = TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize);

  TMarkdownDisplayListRenderer.Render(DisplayList, PainterRef, Viewport, TransparentColor);

  Assert.AreEqual(0, Painter.DrawWedgeCount, 'A wedge with no stroke color or width must not be outlined');
end;

procedure TMarkdownLayoutRendererTests.Render_CheckedCheckbox_FillsCheckMarkInsideBox;
begin
  var Painter := TRecordingPainter.Create;
  var PainterRef: IPainter := Painter;

  const Bounds = TLayoutRectF.Create(10, 10, 10 + CheckboxSize, 10 + CheckboxSize);
  const Checkbox: IDisplayItem = TDisplayCheckbox.Create(Bounds, nil, True);
  const DisplayList = DisplayListWith(Checkbox);
  const Viewport = TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize);

  TMarkdownDisplayListRenderer.Render(DisplayList, PainterRef, Viewport, TransparentColor);

  Assert.AreEqual(1, Painter.DrawRectCount, 'A checked checkbox must still draw its box');
  Assert.AreEqual(1, Painter.FillPolygonCount, 'The check mark must be one filled outline');
  Assert.AreEqual(0, Painter.DrawLineCount, 'The check mark must not be drawn as separate lines');
  const IsMarkInsideBox = AllInside(Painter.LastPolygonPoints, Bounds);
  Assert.IsTrue(IsMarkInsideBox, 'The check mark must stay inside the box');
end;

procedure TMarkdownLayoutRendererTests.Render_UncheckedCheckbox_DrawsBoxOnly;
begin
  var Painter := TRecordingPainter.Create;
  var PainterRef: IPainter := Painter;

  const Bounds = TLayoutRectF.Create(10, 10, 10 + CheckboxSize, 10 + CheckboxSize);
  const Checkbox: IDisplayItem = TDisplayCheckbox.Create(Bounds, nil, False);
  const DisplayList = DisplayListWith(Checkbox);
  const Viewport = TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize);

  TMarkdownDisplayListRenderer.Render(DisplayList, PainterRef, Viewport, TransparentColor);

  Assert.AreEqual(1, Painter.DrawRectCount, 'An unchecked checkbox must draw its box');
  Assert.AreEqual(0, Painter.FillPolygonCount, 'An unchecked checkbox must not draw a check mark');
end;

procedure TMarkdownLayoutRendererTests.Render_CheckboxAtFractionalPosition_DrawsPixelAlignedBox;
begin
  var Painter := TRecordingPainter.Create;
  var PainterRef: IPainter := Painter;

  const Left = 10 + FractionalOffset;
  const Top = 20 + FractionalOffset;
  const Bounds = TLayoutRectF.Create(Left, Top, Left + CheckboxSize, Top + CheckboxSize);
  const Checkbox: IDisplayItem = TDisplayCheckbox.Create(Bounds, nil, True);
  const DisplayList = DisplayListWith(Checkbox);
  const Viewport = TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize);

  TMarkdownDisplayListRenderer.Render(DisplayList, PainterRef, Viewport, TransparentColor);

  const Box = Painter.LastRectBounds;
  const IsPixelAligned = (IsWholeNumber(Box.Left) and
                          IsWholeNumber(Box.Top) and
                          IsWholeNumber(Box.Right) and
                          IsWholeNumber(Box.Bottom));
  Assert.IsTrue(IsPixelAligned, 'The checkbox border must sit on whole pixels');
  Assert.AreEqual(CheckboxSize, Box.Width, 0.001, 'Aligning the box must keep its size');
  const IsMarkInsideAlignedBox = AllInside(Painter.LastPolygonPoints, Box);
  Assert.IsTrue(IsMarkInsideAlignedBox, 'The check mark must follow the aligned box');
end;

procedure TMarkdownLayoutRendererTests.Render_CheckboxOfSize_ScalesBorderToWholePixels(const Size,
  ExpectedBorderWidth: Integer);
begin
  var Painter := TRecordingPainter.Create;
  var PainterRef: IPainter := Painter;

  const Bounds = TLayoutRectF.Create(10, 10, 10 + Size, 10 + Size);
  const Checkbox: IDisplayItem = TDisplayCheckbox.Create(Bounds, nil, True);
  const DisplayList = DisplayListWith(Checkbox);
  const Viewport = TLayoutRectF.Create(0, 0, DisplaySize, DisplaySize);

  TMarkdownDisplayListRenderer.Render(DisplayList, PainterRef, Viewport, TransparentColor);

  Assert.AreEqual(Single(ExpectedBorderWidth), Painter.LastRectStrokeWidth, 0.001,
    'The border must scale with the checkbox and stay a whole number of pixels');
end;

end.
