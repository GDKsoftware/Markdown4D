unit Markdown4D.Export.ScaledPainter.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Tests.RecordingPainter;

type
  [TestFixture]
  TMarkdownScaledPainterTests = class
  private
    const
      Tolerance = 0.001;
      FontSize = 16.0;
      TextColor = TLayoutColor($FF000000);
    var
      FRecorder: TRecordingPainter;
      FInner: IPainter;
    function CreateScaled(const OriginY, Factor: Single): IPainter;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Double', '2')]
    [TestCase('PdfResolution', '2.0833')]
    [TestCase('Shrunk', '0.5')]
    procedure DrawTextRun_Factor_ScalesPointAndFontSize(const Factor: Single);

    [Test]
    procedure FillRect_OriginY_ShiftsThenScales;

    [Test]
    procedure StrokeWidthAndRadii_AreScaled;

    [Test]
    procedure Polygon_EveryPointIsMapped;

    [Test]
    procedure MeasureText_DividesInnerResultByFactor;

    [Test]
    [TestCase('Zero', '0')]
    [TestCase('Negative', '-1')]
    procedure Create_NonPositiveFactor_RaisesEMarkdownPdfExportError(const Factor: Single);
  end;

implementation

uses
  Markdown4D.Export.ScaledPainter,
  Markdown4D.Export.Pdf.Errors;

procedure TMarkdownScaledPainterTests.Setup;
begin
  FRecorder := TRecordingPainter.Create;
  FInner := FRecorder;
end;

procedure TMarkdownScaledPainterTests.TearDown;
begin
  FInner := nil;
  FRecorder := nil;
end;

function TMarkdownScaledPainterTests.CreateScaled(const OriginY, Factor: Single): IPainter;
begin
  Result := TMarkdownScaledPainter.Create(FInner, OriginY, Factor);
end;

procedure TMarkdownScaledPainterTests.DrawTextRun_Factor_ScalesPointAndFontSize(const Factor: Single);
begin
  const Painter = CreateScaled(0, Factor);
  const Font = TMarkdownFontStyle.Create('Segoe UI', FontSize);

  Painter.DrawTextRun(TLayoutPointF.Create(10, 20), 'text', Font, TextColor);

  const Runs = FRecorder.OfKind(TRecordedPrimitiveKind.TextRun);
  Assert.AreEqual(1, Integer(Length(Runs)));
  Assert.AreEqual(10 * Factor, Runs[0].StartPoint.X, Tolerance);
  Assert.AreEqual(20 * Factor, Runs[0].StartPoint.Y, Tolerance);
  Assert.AreEqual(FontSize * Factor, Runs[0].Font.Size, Tolerance);
  Assert.AreEqual('Segoe UI', Runs[0].Font.FamilyName);
end;

procedure TMarkdownScaledPainterTests.FillRect_OriginY_ShiftsThenScales;
begin
  const Painter = CreateScaled(100, 2);

  Painter.FillRect(TLayoutRectF.Create(5, 110, 15, 130), TextColor);

  const Fills = FRecorder.OfKind(TRecordedPrimitiveKind.FillRect);
  Assert.AreEqual(1, Integer(Length(Fills)));
  Assert.AreEqual(10.0, Fills[0].Bounds.Left, Tolerance);
  Assert.AreEqual(20.0, Fills[0].Bounds.Top, Tolerance);
  Assert.AreEqual(30.0, Fills[0].Bounds.Right, Tolerance);
  Assert.AreEqual(60.0, Fills[0].Bounds.Bottom, Tolerance);
end;

procedure TMarkdownScaledPainterTests.StrokeWidthAndRadii_AreScaled;
begin
  const Painter = CreateScaled(0, 3);

  Painter.DrawRect(TLayoutRectF.Create(0, 0, 10, 10), TextColor, 1);
  Painter.DrawLine(TLayoutPointF.Create(0, 0), TLayoutPointF.Create(10, 0), TextColor, 2);
  Painter.DrawWedge(TLayoutPointF.Create(4, 5), 10, 4, 0, 90, TextColor, 1.5);

  Assert.AreEqual(3.0, FRecorder.OfKind(TRecordedPrimitiveKind.DrawRect)[0].StrokeWidth, Tolerance);
  Assert.AreEqual(6.0, FRecorder.OfKind(TRecordedPrimitiveKind.Line)[0].StrokeWidth, Tolerance);

  const Wedge = FRecorder.OfKind(TRecordedPrimitiveKind.DrawWedge)[0];
  Assert.AreEqual(30.0, Wedge.OuterRadius, Tolerance);
  Assert.AreEqual(12.0, Wedge.InnerRadius, Tolerance);
  Assert.AreEqual(4.5, Wedge.StrokeWidth, Tolerance);
  Assert.AreEqual(12.0, Wedge.StartPoint.X, Tolerance);
  Assert.AreEqual(15.0, Wedge.StartPoint.Y, Tolerance);
end;

procedure TMarkdownScaledPainterTests.Polygon_EveryPointIsMapped;
begin
  const Painter = CreateScaled(10, 2);
  const Points: TArray<TLayoutPointF> = [TLayoutPointF.Create(0, 10), TLayoutPointF.Create(5, 20),
    TLayoutPointF.Create(10, 10)];

  Painter.FillPolygon(Points, TextColor);

  const Mapped = FRecorder.OfKind(TRecordedPrimitiveKind.FillPolygon)[0].Points;
  Assert.AreEqual(3, Integer(Length(Mapped)));
  Assert.AreEqual(10.0, Mapped[1].X, Tolerance);
  Assert.AreEqual(20.0, Mapped[1].Y, Tolerance);
  Assert.AreEqual(0.0, Mapped[2].Y, Tolerance);
end;

procedure TMarkdownScaledPainterTests.MeasureText_DividesInnerResultByFactor;
begin
  const Painter = CreateScaled(0, 2);
  const Font = TMarkdownFontStyle.Create('Segoe UI', FontSize);

  const Scaled = Painter.MeasureText('abcd', Font);
  const Direct = FInner.MeasureText('abcd', Font);

  Assert.AreEqual(Direct.Width, Scaled.Width, Tolerance);
  Assert.AreEqual(Direct.Height, Scaled.Height, Tolerance);
  Assert.AreEqual(FInner.LineHeight(Font), Painter.LineHeight(Font), Tolerance);
  Assert.AreEqual(FInner.Baseline(Font), Painter.Baseline(Font), Tolerance);
end;

procedure TMarkdownScaledPainterTests.Create_NonPositiveFactor_RaisesEMarkdownPdfExportError(const Factor: Single);
begin
  Assert.WillRaise(
    procedure
    begin
      CreateScaled(0, Factor);
    end,
    EMarkdownPdfExportError);
end;

end.
