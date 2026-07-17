unit Markdown4D.Fmx.Render.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.UITypes,
  FMX.Graphics,
  Markdown4D.Theme,
  Markdown4D.Layout.DisplayList;

type
  [TestFixture]
  TMarkdownFmxRenderTests = class
  private
    const
      BitmapWidth = 400;
      BitmapHeight = 300;
      SampleStep = 5;
      MinimumDistinctColors = 3;
      MinimumDistinctCodeColors = 3;
      DarkLuminanceCeiling = 80.0;
      PascalLanguageName = 'pascal';
      TestImageSource = 'crop-source';
      CropBitmapSize = 2;
      ImageBoundsSize = 32.0;
      ClipInsideSize = 40.0;
      ClipProbeX = 380;
      ClipProbeY = 280;
      StrongChannelFloor = 200;
      WeakChannelCeiling = 60;
      MetricSampleCount = 1000;
      MetricTimeBudgetMilliseconds = 50.0;
      MetricFontSize = 16.0;
      MetricFamilyName = 'Segoe UI';
      RepresentativeMarkdown =
        '# Heading One'#10#10 +
        '## Heading Two'#10#10 +
        'Intro with a [link](https://example.com) and **bold** text.'#10#10 +
        '| Name | Value |'#10'| --- | --- |'#10'| alpha | 1 |'#10'| beta | 2 |'#10#10 +
        '```pascal'#10'begin'#10'  Writeln(''hi''); // note'#10'  Value := $FF;'#10'end.'#10'```'#10#10 +
        '- [x] done task'#10'- [ ] open task'#10#10 +
        '![diagram](missing.png)';
    class function RenderToBitmap(const Markdown: string; const Theme: TMarkdownTheme;
      const Bitmap: TBitmap): IMarkdownDisplayList;
    class function DistinctSampledColorCount(const Bitmap: TBitmap): Integer;
    class function AverageSampledLuminance(const Bitmap: TBitmap): Double;
    class function DistinctCodeRunColorCount(const DisplayList: IMarkdownDisplayList;
      const CodeFamilyName: string): Integer;
    class function ReadPixel(const Bitmap: TBitmap; const X, Y: Integer): TAlphaColor;
    class procedure FillWhite(const Bitmap: TBitmap);
    class function CreateCropSourceBitmap: TBitmap;
    class function IsRed(const Color: TAlphaColor): Boolean;
    class function IsWhite(const Color: TAlphaColor): Boolean;

  public
    [Test]
    procedure Render_RepresentativeMarkdown_ProducesNonBlankBitmap;

    [Test]
    procedure Render_CodeWithRegisteredHighlighter_ProducesMultipleTokenColors;

    [Test]
    procedure Render_DarkTheme_YieldsDarkBackgroundPixels;

    [Test]
    procedure DrawImage_WithSourceRect_CropsToSourceRegion;

    [Test]
    procedure Clipping_DrawOutsideClip_LeavesPixelsUntouched;

    [Test]
    procedure TextMetricCache_RepeatedMeasurement_IsStableAndFast;
  end;

implementation

uses
  System.SysUtils,
  System.Diagnostics,
  System.Generics.Collections,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.Renderer,
  Markdown4D.Highlighter.Interfaces,
  Markdown4D.Highlighter.Pascal,
  Markdown4D.Fmx.Painter;

procedure TMarkdownFmxRenderTests.Render_RepresentativeMarkdown_ProducesNonBlankBitmap;
begin
  const Theme = TMarkdownTheme.CreateLight;
  try
    const Bitmap = TBitmap.Create;
    try
      RenderToBitmap(RepresentativeMarkdown, Theme, Bitmap);

      const DistinctColors = DistinctSampledColorCount(Bitmap);
      Assert.IsTrue(DistinctColors >= MinimumDistinctColors,
        Format('Expected at least %d distinct colors but found %d', [MinimumDistinctColors, DistinctColors]));
    finally
      Bitmap.Free;
    end;
  finally
    Theme.Free;
  end;
end;

procedure TMarkdownFmxRenderTests.Render_CodeWithRegisteredHighlighter_ProducesMultipleTokenColors;
const
  CodeMarkdown = '```pascal'#10'begin'#10'  Writeln(''hi''); // note'#10'  X := $FF;'#10'end.'#10'```';
begin
  THighlighterRegistry.Register(PascalLanguageName, TPascalSyntaxHighlighter.Create);
  try
    const Theme = TMarkdownTheme.CreateLight;
    try
      const Bitmap = TBitmap.Create;
      try
        const DisplayList = RenderToBitmap(CodeMarkdown, Theme, Bitmap);

        const DistinctCodeColors = DistinctCodeRunColorCount(DisplayList, Theme.CodeFont.FamilyName);
        Assert.IsTrue(DistinctCodeColors >= MinimumDistinctCodeColors,
          Format('Expected at least %d distinct code token colors but found %d',
          [MinimumDistinctCodeColors, DistinctCodeColors]));
      finally
        Bitmap.Free;
      end;
    finally
      Theme.Free;
    end;
  finally
    THighlighterRegistry.Clear;
  end;
end;

procedure TMarkdownFmxRenderTests.Render_DarkTheme_YieldsDarkBackgroundPixels;
const
  DarkMarkdown = '# Hello'#10#10'Dark mode body text.';
begin
  const Theme = TMarkdownTheme.CreateDark;
  try
    const Bitmap = TBitmap.Create;
    try
      RenderToBitmap(DarkMarkdown, Theme, Bitmap);

      const Luminance = AverageSampledLuminance(Bitmap);
      Assert.IsTrue(Luminance < DarkLuminanceCeiling,
        Format('Expected average luminance below %.1f but found %.1f', [DarkLuminanceCeiling, Luminance]));
    finally
      Bitmap.Free;
    end;
  finally
    Theme.Free;
  end;
end;

procedure TMarkdownFmxRenderTests.DrawImage_WithSourceRect_CropsToSourceRegion;
begin
  const Target = TBitmap.Create;
  try
    Target.SetSize(BitmapWidth, BitmapHeight);
    FillWhite(Target);

    const Source = CreateCropSourceBitmap;
    try
      var Painter: IPainter := TMarkdownFmxPainter.Create(Target.Canvas);
      TMarkdownFmxPainter(Painter).ImageResolver :=
        function(const ImageSource: string): TBitmap
        begin
          Result := Source;
        end;

      Target.Canvas.BeginScene;
      try
        const Bounds = TLayoutRectF.Create(0, 0, ImageBoundsSize, ImageBoundsSize);
        const SourceRect = TLayoutRectF.Create(0, 0, 1, 1);
        Painter.DrawImage(Bounds, TestImageSource, SourceRect);
      finally
        Target.Canvas.EndScene;
      end;

      const Center = ReadPixel(Target, Round(ImageBoundsSize / 2), Round(ImageBoundsSize / 2));
      Assert.IsTrue(IsRed(Center), 'Expected the cropped source region to paint red pixels');
    finally
      Source.Free;
    end;
  finally
    Target.Free;
  end;
end;

procedure TMarkdownFmxRenderTests.Clipping_DrawOutsideClip_LeavesPixelsUntouched;
begin
  const Target = TBitmap.Create;
  try
    Target.SetSize(BitmapWidth, BitmapHeight);
    FillWhite(Target);

    var Painter: IPainter := TMarkdownFmxPainter.Create(Target.Canvas);

    Target.Canvas.BeginScene;
    try
      Painter.SaveState;
      try
        Painter.SetClip(TLayoutRectF.Create(0, 0, ClipInsideSize, ClipInsideSize));
        Painter.FillRect(TLayoutRectF.Create(0, 0, BitmapWidth, BitmapHeight), TAlphaColorRec.Black);
      finally
        Painter.RestoreState;
      end;
    finally
      Target.Canvas.EndScene;
    end;

    const Probe = ReadPixel(Target, ClipProbeX, ClipProbeY);
    Assert.IsTrue(IsWhite(Probe), 'Expected pixels outside the clip region to remain untouched');
  finally
    Target.Free;
  end;
end;

procedure TMarkdownFmxRenderTests.TextMetricCache_RepeatedMeasurement_IsStableAndFast;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.SetSize(BitmapWidth, BitmapHeight);

    var Painter: IPainter := TMarkdownFmxPainter.Create(Bitmap.Canvas);
    const Font = TMarkdownFontStyle.Create(MetricFamilyName, MetricFontSize);

    const Baseline = Painter.MeasureText('The quick brown fox', Font);

    const Stopwatch = TStopwatch.StartNew;
    for var Index := 1 to MetricSampleCount do
    begin
      const Measured = Painter.MeasureText('The quick brown fox', Font);
      Assert.AreEqual(Double(Baseline.Width), Double(Measured.Width), 0.01);
      Assert.AreEqual(Double(Baseline.Height), Double(Measured.Height), 0.01);
    end;
    const Elapsed = Stopwatch.Elapsed.TotalMilliseconds;

    Assert.IsTrue(Elapsed < MetricTimeBudgetMilliseconds,
      Format('Expected %d cached measurements under %.0f ms but took %.1f ms',
      [MetricSampleCount, MetricTimeBudgetMilliseconds, Elapsed]));
  finally
    Bitmap.Free;
  end;
end;

class function TMarkdownFmxRenderTests.RenderToBitmap(const Markdown: string; const Theme: TMarkdownTheme;
  const Bitmap: TBitmap): IMarkdownDisplayList;
begin
  Bitmap.SetSize(BitmapWidth, BitmapHeight);

  var Painter: IPainter := TMarkdownFmxPainter.Create(Bitmap.Canvas);
  const Document = TMarkdown.Parse(Markdown, TMarkdownDialect.Gfm);
  Result := TMarkdownLayoutEngine.LayoutDocument(Document, BitmapWidth, Theme, Painter);

  Bitmap.Canvas.BeginScene;
  try
    const Viewport = TLayoutRectF.Create(0, 0, BitmapWidth, BitmapHeight);
    TMarkdownDisplayListRenderer.Render(Result, Painter, Viewport, Theme.BackgroundColor);
  finally
    Bitmap.Canvas.EndScene;
  end;
end;

class function TMarkdownFmxRenderTests.DistinctSampledColorCount(const Bitmap: TBitmap): Integer;
begin
  const Seen = TDictionary<TAlphaColor, Boolean>.Create;
  try
    var Data: TBitmapData;
    if not Bitmap.Map(TMapAccess.Read, Data) then
      Exit(0);

    try
      for var YIndex := 0 to (Bitmap.Height - 1) div SampleStep do
      begin
        for var XIndex := 0 to (Bitmap.Width - 1) div SampleStep do
        begin
          Seen.AddOrSetValue(Data.GetPixel(XIndex * SampleStep, YIndex * SampleStep), True);
        end;
      end;
    finally
      Bitmap.Unmap(Data);
    end;

    Result := Seen.Count;
  finally
    Seen.Free;
  end;
end;

class function TMarkdownFmxRenderTests.AverageSampledLuminance(const Bitmap: TBitmap): Double;
begin
  var Total := 0.0;
  var SampleCount := 0;

  var Data: TBitmapData;
  if not Bitmap.Map(TMapAccess.Read, Data) then
    Exit(0);

  try
    for var YIndex := 0 to (Bitmap.Height - 1) div SampleStep do
    begin
      for var XIndex := 0 to (Bitmap.Width - 1) div SampleStep do
      begin
        const Pixel = TAlphaColorRec(Data.GetPixel(XIndex * SampleStep, YIndex * SampleStep));
        Total := Total + (0.299 * Pixel.R) + (0.587 * Pixel.G) + (0.114 * Pixel.B);
        SampleCount := SampleCount + 1;
      end;
    end;
  finally
    Bitmap.Unmap(Data);
  end;

  Result := Total / SampleCount;
end;

class function TMarkdownFmxRenderTests.DistinctCodeRunColorCount(const DisplayList: IMarkdownDisplayList;
  const CodeFamilyName: string): Integer;
begin
  const Seen = TDictionary<TLayoutColor, Boolean>.Create;
  try
    for var Index := 0 to DisplayList.ItemCount - 1 do
    begin
      var Run: IDisplayTextRun;
      const IsCodeRun = Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and
        SameText(Run.Font.FamilyName, CodeFamilyName);
      if IsCodeRun then
        Seen.AddOrSetValue(Run.Color, True);
    end;

    Result := Seen.Count;
  finally
    Seen.Free;
  end;
end;

class function TMarkdownFmxRenderTests.ReadPixel(const Bitmap: TBitmap; const X, Y: Integer): TAlphaColor;
begin
  Result := TAlphaColorRec.Null;

  var Data: TBitmapData;
  if not Bitmap.Map(TMapAccess.Read, Data) then
    Exit;

  try
    Result := Data.GetPixel(X, Y);
  finally
    Bitmap.Unmap(Data);
  end;
end;

class procedure TMarkdownFmxRenderTests.FillWhite(const Bitmap: TBitmap);
begin
  Bitmap.Clear(TAlphaColorRec.White);
end;

class function TMarkdownFmxRenderTests.CreateCropSourceBitmap: TBitmap;
begin
  Result := TBitmap.Create;
  Result.SetSize(CropBitmapSize, CropBitmapSize);

  var Data: TBitmapData;
  if not Result.Map(TMapAccess.Write, Data) then
    Exit;

  try
    Data.SetPixel(0, 0, TAlphaColorRec.Red);
    Data.SetPixel(1, 0, TAlphaColorRec.Lime);
    Data.SetPixel(0, 1, TAlphaColorRec.Blue);
    Data.SetPixel(1, 1, TAlphaColorRec.White);
  finally
    Result.Unmap(Data);
  end;
end;

class function TMarkdownFmxRenderTests.IsRed(const Color: TAlphaColor): Boolean;
begin
  const Channels = TAlphaColorRec(Color);
  Result := (Channels.R >= StrongChannelFloor) and (Channels.G <= WeakChannelCeiling) and
    (Channels.B <= WeakChannelCeiling);
end;

class function TMarkdownFmxRenderTests.IsWhite(const Color: TAlphaColor): Boolean;
begin
  const Channels = TAlphaColorRec(Color);
  Result := (Channels.R >= StrongChannelFloor) and (Channels.G >= StrongChannelFloor) and
    (Channels.B >= StrongChannelFloor);
end;

end.
