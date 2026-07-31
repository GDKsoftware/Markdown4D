unit Markdown4D.Vcl.Render.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Vcl.Graphics,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Theme,
  Markdown4D.Layout.Interfaces,
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
      ClipBufferWidth = 200;
      ClipBufferHeight = 60;
      ClipStraddleAboveHeight = 20;
      ClipStraddleBelowHeight = 20;
      ClipSelectionColor: TLayoutColor = $FF0000FF;
      MermaidBufferWidth = 200;
      MermaidBufferHeight = 200;
      MinimumDiamondEdgeColors = 6;
      DiamondDiagram = 'flowchart TD' + #10 + '  A{Diamond}';
    class function RenderToBitmap(const Markdown: string; const Theme: TMarkdownTheme;
      const Bitmap: TBitmap): IMarkdownDisplayList;
    class function DistinctSampledColorCount(const Bitmap: TBitmap): Integer;
    class function AverageSampledLuminance(const Bitmap: TBitmap): Double;
    class function DistinctCodeRunColorCount(const DisplayList: IMarkdownDisplayList;
      const CodeFamilyName: string): Integer;
    class function FindFirstCodeBlock(const Document: IMarkdownDocument; out Code: IMarkdownCodeBlock): Boolean;
    class function DistinctColorCountWithin(const Bitmap: TBitmap; const Bounds: TLayoutRectF): Integer;

  public
    [Test]
    procedure Render_RepresentativeMarkdown_ProducesNonBlankBitmap;

    [Test]
    procedure Render_CodeWithRegisteredHighlighter_ProducesMultipleTokenColors;

    [Test]
    procedure Render_DarkTheme_YieldsDarkBackgroundPixels;

    [Test]
    procedure Render_SelectionStraddlingScrolledOrigin_ClipsToBufferBounds;

    [Test]
    procedure Render_MermaidDiamondNode_BorderIsAntiAliased;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  System.Math,
  System.Generics.Collections,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Extensions.Mermaid,
  Markdown4D.Extensions.Mermaid.Layout,
  Markdown4D.Pipeline,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.Primitives,
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

procedure TMarkdownVclRenderTests.Render_SelectionStraddlingScrolledOrigin_ClipsToBufferBounds;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.SetSize(ClipBufferWidth, ClipBufferHeight);
    Bitmap.Canvas.Brush.Color := clWhite;
    Bitmap.Canvas.FillRect(TRect.Create(0, 0, ClipBufferWidth, ClipBufferHeight));

    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);

    // TMarkdownViewer.RenderToBuffer paints into a bitmap sized to the control and
    // shifts the window origin to make scrolled content line up; a rect that starts
    // above the current viewport therefore reaches the painter at a negative Top,
    // straddling the boundary between what is now off-screen and what is still visible.
    const StraddlingSelection = TLayoutRectF.Create(0, -ClipStraddleAboveHeight, ClipBufferWidth,
      ClipStraddleBelowHeight);
    Painter.FillRect(StraddlingSelection, ClipSelectionColor);

    for var YIndex := 0 to ClipStraddleBelowHeight - 1 do
    begin
      Assert.AreEqual(clBlue, Bitmap.Canvas.Pixels[0, YIndex],
        Format('Expected row %d, within the visible half of the selection, to be filled', [YIndex]));
    end;

    for var YIndex := ClipStraddleBelowHeight to ClipBufferHeight - 1 do
    begin
      Assert.AreEqual(clWhite, Bitmap.Canvas.Pixels[0, YIndex],
        Format('Expected row %d, below the selection, to remain untouched by the part painted above the buffer',
        [YIndex]));
    end;
  finally
    Bitmap.Free;
  end;
end;

// A diamond's border is a filled polygon stroked through the anti-aliased
// rasterizer, not GDI's Polygon call: the diagonal edges must blend across
// several intermediate shades between the fill and the background, not just
// jump between the two like an aliased staircase would.
procedure TMarkdownVclRenderTests.Render_MermaidDiamondNode_BorderIsAntiAliased;
begin
  const Theme = TMarkdownTheme.CreateLight;
  try
    const Markdown = '```mermaid' + #10 + DiamondDiagram + #10 + '```' + #10;
    const Pipeline = TMarkdownPipeline.Create.UseGfm.Use(TMermaidExtension.Create).UnsafeHtml.Build;
    const Document = Pipeline.Parse(Markdown);

    var Code: IMarkdownCodeBlock;
    Assert.IsTrue(FindFirstCodeBlock(Document, Code), 'The diagram must expose a code block');

    var Model: IMermaidModel;
    Assert.IsTrue(TMermaidExtension.TryParse(Code, Model), 'The diagram must parse into a mermaid model');

    const Bitmap = TBitmap.Create;
    try
      Bitmap.SetSize(MermaidBufferWidth, MermaidBufferHeight);

      var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
      const Bounds = TLayoutRectF.Create(0, 0, MermaidBufferWidth, MermaidBufferHeight);
      const Items = TMermaidLayouter.BuildDisplayItems(Model, Bounds, Theme, Painter, Code);

      var NoBlocks: TArray<TLayoutBlockInfo>;
      var NoRecomputed: TArray<Integer>;
      const DisplayList = TMarkdownDisplayList.Create(Items, NoBlocks, MermaidBufferWidth, MermaidBufferWidth,
        MermaidBufferHeight, NoRecomputed);

      var NodeBounds := Bounds;
      for var Item in Items do
      begin
        if Item.Kind = TDisplayItemKind.Polygon then
          NodeBounds := Item.Bounds;
      end;

      TMarkdownDisplayListRenderer.Render(DisplayList, Painter, Bounds, Theme.BackgroundColor);

      const EdgeColors = DistinctColorCountWithin(Bitmap, NodeBounds);
      Assert.IsTrue(EdgeColors >= MinimumDiamondEdgeColors,
        Format('Expected at least %d distinct colors across the diamond''s anti-aliased edges but found %d',
        [MinimumDiamondEdgeColors, EdgeColors]));
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

class function TMarkdownVclRenderTests.FindFirstCodeBlock(const Document: IMarkdownDocument;
  out Code: IMarkdownCodeBlock): Boolean;
begin
  Code := nil;

  for var Index := 0 to Document.ChildCount - 1 do
  begin
    const Child = Document.Children[Index];
    if Child.Kind = TMarkdownNodeKind.CodeBlock then
    begin
      Code := Child as IMarkdownCodeBlock;
      Exit(True);
    end;
  end;

  Result := False;
end;

// Every pixel in the node's bounding box, sampled one by one rather than on a
// stride: an anti-aliased diagonal edge is only a few pixels wide, and a
// SampleStep grid the size used elsewhere would step clean over it.
class function TMarkdownVclRenderTests.DistinctColorCountWithin(const Bitmap: TBitmap;
  const Bounds: TLayoutRectF): Integer;
begin
  const Seen = TDictionary<TColor, Boolean>.Create;
  try
    const Left = Max(0, Trunc(Bounds.Left));
    const Top = Max(0, Trunc(Bounds.Top));
    const Right = Min(Bitmap.Width - 1, Ceil(Bounds.Right));
    const Bottom = Min(Bitmap.Height - 1, Ceil(Bounds.Bottom));

    for var YIndex := Top to Bottom do
    begin
      for var XIndex := Left to Right do
      begin
        Seen.AddOrSetValue(Bitmap.Canvas.Pixels[XIndex, YIndex], True);
      end;
    end;

    Result := Seen.Count;
  finally
    Seen.Free;
  end;
end;

end.
