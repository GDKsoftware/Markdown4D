unit Markdown4D.Vcl.Render.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Vcl.Graphics,
  Markdown4D.Theme,
  Markdown4D.Layout.DisplayList;

type
  [TestFixture]
  TMarkdownVclRenderTests = class
  private
    const
      BitmapWidth = 400;
      BitmapHeight = 300;
      SampleStep = 5;
      MinimumDistinctColors = 3;
      MinimumDistinctCodeColors = 3;
      DarkLuminanceCeiling = 80.0;
      PascalLanguageName = 'pascal';
    class function RenderToBitmap(const Markdown: string; const Theme: TMarkdownTheme;
      const Bitmap: TBitmap): IMarkdownDisplayList;
    class function DistinctSampledColorCount(const Bitmap: TBitmap): Integer;
    class function AverageSampledLuminance(const Bitmap: TBitmap): Double;
    class function DistinctCodeRunColorCount(const DisplayList: IMarkdownDisplayList;
      const CodeFamilyName: string): Integer;

  public
    [Test]
    procedure Render_RepresentativeMarkdown_ProducesNonBlankBitmap;

    [Test]
    procedure Render_CodeWithRegisteredHighlighter_ProducesMultipleTokenColors;

    [Test]
    procedure Render_DarkTheme_YieldsDarkBackgroundPixels;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.Renderer,
  Markdown4D.Highlighter.Interfaces,
  Markdown4D.Highlighter.Pascal,
  Markdown4D.Vcl.Painter;

procedure TMarkdownVclRenderTests.Render_RepresentativeMarkdown_ProducesNonBlankBitmap;
const
  RepresentativeMarkdown =
    '# Heading'#10#10 +
    'Intro with a [link](https://example.com) inside.'#10#10 +
    '| Name | Value |'#10'| --- | --- |'#10'| alpha | 1 |'#10#10 +
    '```pascal'#10'begin'#10'  Writeln(1);'#10'end.'#10'```'#10#10 +
    '![diagram](missing.png)';
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

procedure TMarkdownVclRenderTests.Render_CodeWithRegisteredHighlighter_ProducesMultipleTokenColors;
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

procedure TMarkdownVclRenderTests.Render_DarkTheme_YieldsDarkBackgroundPixels;
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

class function TMarkdownVclRenderTests.RenderToBitmap(const Markdown: string; const Theme: TMarkdownTheme;
  const Bitmap: TBitmap): IMarkdownDisplayList;
begin
  Bitmap.SetSize(BitmapWidth, BitmapHeight);

  var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
  const Document = TMarkdown.Parse(Markdown, TMarkdownDialect.Gfm);
  Result := TMarkdownLayoutEngine.LayoutDocument(Document, BitmapWidth, Theme, Painter);

  const Viewport = TLayoutRectF.Create(0, 0, BitmapWidth, BitmapHeight);
  TMarkdownDisplayListRenderer.Render(Result, Painter, Viewport, Theme.BackgroundColor);
end;

class function TMarkdownVclRenderTests.DistinctSampledColorCount(const Bitmap: TBitmap): Integer;
begin
  const Seen = TDictionary<TColor, Boolean>.Create;
  try
    for var YIndex := 0 to (Bitmap.Height - 1) div SampleStep do
    begin
      for var XIndex := 0 to (Bitmap.Width - 1) div SampleStep do
      begin
        Seen.AddOrSetValue(Bitmap.Canvas.Pixels[XIndex * SampleStep, YIndex * SampleStep], True);
      end;
    end;

    Result := Seen.Count;
  finally
    Seen.Free;
  end;
end;

class function TMarkdownVclRenderTests.AverageSampledLuminance(const Bitmap: TBitmap): Double;
begin
  var Total := 0.0;
  var SampleCount := 0;

  for var YIndex := 0 to (Bitmap.Height - 1) div SampleStep do
  begin
    for var XIndex := 0 to (Bitmap.Width - 1) div SampleStep do
    begin
      const Pixel = ColorToRGB(Bitmap.Canvas.Pixels[XIndex * SampleStep, YIndex * SampleStep]);
      const Red = Pixel and $FF;
      const Green = (Pixel shr 8) and $FF;
      const Blue = (Pixel shr 16) and $FF;
      Total := Total + (0.299 * Red) + (0.587 * Green) + (0.114 * Blue);
      SampleCount := SampleCount + 1;
    end;
  end;

  Result := Total / SampleCount;
end;

class function TMarkdownVclRenderTests.DistinctCodeRunColorCount(const DisplayList: IMarkdownDisplayList;
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

end.
