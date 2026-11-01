unit Markdown4D.Math.Integration.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Viewer.Model;

type
  [TestFixture]
  TMathThemeTests = class
  private
    const
      OverrideFamilyName = 'Test Math';
      OverrideFontSize = 20.0;
      OverrideErrorColor = $FF123456;
      MathFontKey = 'mathFont';
      MathErrorColorKey = 'mathErrorColor';
      SingleTolerance = 0.001;

  public
    [Test]
    procedure MathFont_Default_IsGenericMathFamilyAtBaseSize;

    [Test]
    procedure MathFontAndErrorColor_SurviveJsonRoundTrip;

    [Test]
    procedure LoadFromJson_WithoutMathKeys_UsesDefaults;
  end;

  [TestFixture]
  TMathLayoutIntegrationTests = class
  private
    const
      DefaultWidth = 400.0;
      SingleTolerance = 0.05;
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
    function Layout(const Source: string): IMarkdownDisplayList;
    class function RunWithText(const DisplayList: IMarkdownDisplayList; const Text: string): IDisplayTextRun;
    class function RunStartingWith(const DisplayList: IMarkdownDisplayList; const Prefix: string): IDisplayTextRun;
    class function BaselineOf(const Run: IDisplayTextRun): Single;
    class function CentreOf(const Run: IDisplayTextRun): TLayoutPointF;

  public
    [SetupFixture]
    procedure SetupFixture;

    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure InlineMath_SharesBaselineWithText;

    [Test]
    procedure InlineFraction_MakesLineTaller;

    [Test]
    procedure InlineMath_KeepsTheSpaceAfterIt;

    [Test]
    procedure FormulaGlyphs_AreFormulaRunsPlacedInTheSource;

    [Test]
    procedure FormulaGlyphs_HaveNoSourceRun;

    [Test]
    procedure TextWithDescender_KeepsFractionBarClear;

    [Test]
    procedure FractionInAligned_KeepsDisplaySize;

    [Test]
    procedure ScaledMeasurer_ScalesHeightsWithWidths;

    [Test]
    procedure DisplayBlock_IsCentred;

    [Test]
    procedure DisplayBlock_UsesDisplayStyle;

    [Test]
    procedure UnclosedDisplayBlock_StillLaysOut;

    [Test]
    [TestCase('InlinePart', '$a+\href{#target}{x}$,x,#target')]
    [TestCase('DisplayPart', '$$\frac{\href{#target}{x}}{2}$$,x,#target')]
    [TestCase('InsideMarkdownLink', '[$a+\href{#inner}{x}$](#outer),x,#inner')]
    [TestCase('AroundHref', '[$a+\href{#inner}{x}$](#outer),a,#outer')]
    procedure Href_PointOnGlyph_FindsItsLink(const Source, Glyph, ExpectedUrl: string);

    [Test]
    procedure Href_PointOnPlainPart_FindsNoLink;
  end;

  [TestFixture]
  TMathViewerTests = class
  private
    const
      DefaultWidth = 400.0;
      DefaultHeight = 300.0;
      ScrollTolerance = 0.01;
      WideFormula = '$$'#10'a + b + c + d + e + f + g + h + i + j + k + l + m + n + o + p + q + r + s + t + u' +
        ' + v + w + z'#10'$$';
      WideLinkedFormula = '$$'#10'\href{#target}{a} + b + c + d + e + f + g + h + i + j + k + l + m + n + o' +
        ' + p + q + r + s + t + u + v + w + z'#10'$$';
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FModel: TMarkdownViewerModel;
    class function FindScroller(const DisplayList: IMarkdownDisplayList): IDisplayScroller;
    class function GlyphBounds(const DisplayList: IMarkdownDisplayList; const Glyph: string): TLayoutRectF;
    class function CentreOf(const Bounds: TLayoutRectF): TLayoutPointF;
    function GlyphRun(const Glyph: string): IDisplayTextRun;
    procedure Drag(const FromGlyph, ToGlyph: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure FindText_SearchesFormulaGlyphsNotSource;

    [Test]
    procedure TrySelectNextMatch_InsideFormula_SelectsTheGlyph;

    [Test]
    procedure HighlightMatches_InsideFormula_MarksEveryHit;

    [Test]
    procedure SelectAll_CopiesFormulaAsLinearText;

    [Test]
    procedure SelectAll_DisplayBlock_CopiesLinearText;

    [Test]
    procedure SelectedMarkdown_SelectAll_KeepsFormulaSource;

    [Test]
    procedure Drag_PartOfFormula_CopiesShownGlyphsAndTheirSource;

    [Test]
    procedure Drag_InsideFraction_CopiesBalancedSource;

    [Test]
    procedure Drag_OverWholeFormula_CopiesLinearTextAndMarkdown;

    [Test]
    procedure Drag_FromTextIntoFormula_CopiesBoth;

    [Test]
    procedure Drag_InsideTextCommand_SelectsCharacters;

    [Test]
    procedure Drag_OverHrefText_CopiesWholeLink;

    [Test]
    procedure Drag_OverUrl_CopiesWholeCommand;

    [Test]
    procedure SelectWordAt_FormulaGlyph_SelectsTheGlyphsWithoutSpace;

    [Test]
    procedure SelectWordAt_LettersOnOneBaseline_SelectsTheName;

    [Test]
    procedure FormulaGlyphs_OfAFraction_DoNotOverlap;

    [Test]
    procedure Drag_InsideDenominator_SelectsItAlone;

    [Test]
    procedure Drag_PastTheEndOfFormula_SelectsAllOfIt;

    [Test]
    procedure CodeBlockRegions_DisplayFormulaByDefault_OffersNoButton;

    [Test]
    procedure CodeBlockRegions_DisplayFormula_OffersLinearText;

    [Test]
    procedure WideDisplayFormula_ScrollsInsteadOfOverflowing;

    [Test]
    procedure ScrollSideways_MovesContentAndKeepsItOverRelayout;

    [Test]
    procedure ScrollerThumbDrag_ScrollsToTheEnd;

    [Test]
    procedure WideDisplayFormula_TrackSitsRightBelowFormula;

    [Test]
    procedure DisplayFormula_TakesTextLineAsMinimumHeight;

    [Test]
    procedure Href_ScrolledOutOfView_FindsNoLink;
  end;

implementation

uses
  System.SysUtils,
  System.JSON,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.Defaults,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Engine,
  Markdown4D.Math.Layout,
  Markdown4D.Layout.HitTest,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Math.Linear;

procedure TMathThemeTests.MathFont_Default_IsGenericMathFamilyAtBaseSize;
begin
  const Theme = TMarkdownTheme.CreateLight;
  try
    Assert.AreEqual(MathFamilyName, Theme.MathFont.FamilyName);
    Assert.AreEqual(Theme.BaseFont.Size, Theme.MathFont.Size, SingleTolerance);
  finally
    Theme.Free;
  end;
end;

procedure TMathThemeTests.MathFontAndErrorColor_SurviveJsonRoundTrip;
begin
  const Source = TMarkdownTheme.CreateLight;
  try
    Source.MathFont := TMarkdownFontStyle.Create(OverrideFamilyName, OverrideFontSize);
    Source.MathErrorColor := OverrideErrorColor;
    const SavedJson = Source.SaveToJson;

    const Loaded = TMarkdownTheme.CreateDark;
    try
      Loaded.LoadFromJson(SavedJson);

      Assert.AreEqual(OverrideFamilyName, Loaded.MathFont.FamilyName);
      Assert.AreEqual(OverrideFontSize, Loaded.MathFont.Size, SingleTolerance);
      Assert.AreEqual<TLayoutColor>(OverrideErrorColor, Loaded.MathErrorColor);
    finally
      Loaded.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TMathThemeTests.LoadFromJson_WithoutMathKeys_UsesDefaults;
begin
  const Light = TMarkdownTheme.CreateLight;
  try
    const Root = TJSONObject.ParseJSONValue(Light.SaveToJson) as TJSONObject;
    try
      Root.RemovePair(MathFontKey).Free;
      Root.RemovePair(MathErrorColorKey).Free;
      const LegacyJson = Root.ToJSON;

      const Loaded = TMarkdownTheme.CreateDark;
      try
        Loaded.LoadFromJson(LegacyJson);

        Assert.AreEqual(MathFamilyName, Loaded.MathFont.FamilyName);
        Assert.AreEqual<TLayoutColor>(Light.MathErrorColor, Loaded.MathErrorColor);
      finally
        Loaded.Free;
      end;
    finally
      Root.Free;
    end;
  finally
    Light.Free;
  end;
end;

procedure TMathLayoutIntegrationTests.SetupFixture;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FMeasurer := TFakeTextMeasurer.Create;
end;

procedure TMathLayoutIntegrationTests.TearDownFixture;
begin
  FMeasurer := nil;
  FreeAndNil(FTheme);
end;

function TMathLayoutIntegrationTests.Layout(const Source: string): IMarkdownDisplayList;
begin
  const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);

  Result := TMarkdownLayoutEngine.LayoutDocument(Document, DefaultWidth, FTheme, FMeasurer);
end;

class function TMathLayoutIntegrationTests.RunWithText(const DisplayList: IMarkdownDisplayList;
  const Text: string): IDisplayTextRun;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const Matches = Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and (Run.Text = Text);
    if Matches then
    begin
      Result := Run;
      Exit;
    end;
  end;

  raise Exception.CreateFmt('No text run "%s" in the display list', [Text]);
end;

// Paragraph text runs carry their trailing space, so a word is found by its
// prefix; formula glyphs are runs of their own.
class function TMathLayoutIntegrationTests.RunStartingWith(const DisplayList: IMarkdownDisplayList;
  const Prefix: string): IDisplayTextRun;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const Matches = Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and Run.Text.StartsWith(Prefix);
    if Matches then
    begin
      Result := Run;
      Exit;
    end;
  end;

  raise Exception.CreateFmt('No text run starting with "%s" in the display list', [Prefix]);
end;

class function TMathLayoutIntegrationTests.BaselineOf(const Run: IDisplayTextRun): Single;
begin
  Result := Run.Bounds.Top + Run.Baseline;
end;

procedure TMathLayoutIntegrationTests.InlineMath_SharesBaselineWithText;
begin
  const DisplayList = Layout('alpha $x$ beta');

  const Text = RunStartingWith(DisplayList, 'alpha');
  const Formula = RunWithText(DisplayList, 'x');
  Assert.AreEqual(BaselineOf(Text), BaselineOf(Formula), SingleTolerance);
  Assert.IsTrue(Formula.Font.Italic, 'a formula letter is set in italic');
  Assert.AreEqual(Text.Font.Size, Formula.Font.Size, SingleTolerance);
end;

procedure TMathLayoutIntegrationTests.InlineFraction_MakesLineTaller;
begin
  const Plain = Layout('alpha beta');
  const WithFraction = Layout('alpha $\frac{1}{2}$ beta');

  const PlainHeight = Plain.BlockInfos[0].Height;
  const FractionHeight = WithFraction.BlockInfos[0].Height;
  Assert.IsTrue(FractionHeight > PlainHeight, 'a fraction must push the line apart');
end;

procedure TMathLayoutIntegrationTests.InlineMath_KeepsTheSpaceAfterIt;
begin
  const DisplayList = Layout('alpha $x$ beta');

  const Formula = RunWithText(DisplayList, 'x');
  const After = RunStartingWith(DisplayList, ' beta');
  Assert.IsTrue(After.Bounds.Left >= Formula.Bounds.Right, 'the space and the word follow the formula');
end;

// The p of the second word reaches below the baseline, so the numerator
// stands higher above the bar than the one without it.
procedure TMathLayoutIntegrationTests.TextWithDescender_KeepsFractionBarClear;
begin
  const Font = TMarkdownFontStyle.Create(FTheme.MathFont.FamilyName, FTheme.MathFont.Size);
  const Options = TMathLayoutOptions.Create(Font, TLayoutColor($FF000000), FTheme.MathErrorColor, False);

  const WithDescender = TMathLayouter.Layout('\frac{\text{Rohprotein}}{2}', Options, FMeasurer);
  const WithoutDescender = TMathLayouter.Layout('\frac{\text{Rohrotein}}{2}', Options, FMeasurer);

  Assert.IsTrue(WithDescender.Ascent > WithoutDescender.Ascent, 'every character of a word counts, not its first');
end;

type
  // Sets text 1.25 times larger than the size it is given, as the VCL viewer
  // does on a display scaled to 125 %.
  TScaledMeasurer = class(TInterfacedObject, ITextMeasurer)
  private
    const
      Scale = 1.25;
    var
      FInner: ITextMeasurer;
  public
    constructor Create(const Inner: ITextMeasurer);
    function MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
    function LineHeight(const Font: TMarkdownFontStyle): Single;
    function Baseline(const Font: TMarkdownFontStyle): Single;
  end;

constructor TScaledMeasurer.Create(const Inner: ITextMeasurer);
begin
  inherited Create;
  FInner := Inner;
end;

// An em space is one em wide, as in a real font.
function TScaledMeasurer.MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
begin
  Result := FInner.MeasureText(Text, Font);
  if Text = #$2003 then
    Result.Width := Font.Size;
  Result.Width := Result.Width * Scale;
  Result.Height := Result.Height * Scale;
end;

function TScaledMeasurer.LineHeight(const Font: TMarkdownFontStyle): Single;
begin
  Result := FInner.LineHeight(Font) * Scale;
end;

function TScaledMeasurer.Baseline(const Font: TMarkdownFontStyle): Single;
begin
  Result := FInner.Baseline(Font) * Scale;
end;

procedure TMathLayoutIntegrationTests.ScaledMeasurer_ScalesHeightsWithWidths;
begin
  const Font = TMarkdownFontStyle.Create(FTheme.MathFont.FamilyName, FTheme.MathFont.Size);
  const Options = TMathLayoutOptions.Create(Font, TLayoutColor($FF000000), FTheme.MathErrorColor, True);
  const Source = '\overline{\frac{a+b}{c}}';
  const ScaledMeasurer: ITextMeasurer = TScaledMeasurer.Create(FMeasurer);

  const Reference: IMathLayout = TMathLayouter.Layout(Source, Options, FMeasurer);
  const Scaled: IMathLayout = TMathLayouter.Layout(Source, Options, ScaledMeasurer);

  const ExpectedAscent: Single = Reference.Ascent * 1.25;
  const ExpectedDescent: Single = Reference.Descent * 1.25;
  const ActualAscent: Single = Scaled.Ascent;
  const ActualDescent: Single = Scaled.Descent;
  Assert.AreEqual(ExpectedAscent, ActualAscent, 0.5, 'heights and gaps follow the measurer as widths do');
  Assert.AreEqual(ExpectedDescent, ActualDescent, 0.5, 'and depths');
end;

procedure TMathLayoutIntegrationTests.FractionInAligned_KeepsDisplaySize;
begin
  const Aligned = Layout('$$'#10'\begin{aligned} x &= \frac{a}{b} \end{aligned}'#10'$$');
  const Matrix = Layout('$$'#10'\begin{matrix} \frac{a}{b} \end{matrix}'#10'$$');

  const AlignedSize = RunWithText(Aligned, 'a').Font.Size;
  const MatrixSize = RunWithText(Matrix, 'a').Font.Size;
  Assert.AreEqual(FTheme.MathFont.Size, AlignedSize, SingleTolerance, 'aligned lines are set in display style');
  Assert.IsTrue(MatrixSize < AlignedSize, 'matrix cells in text style');
end;

procedure TMathLayoutIntegrationTests.FormulaGlyphs_AreFormulaRunsPlacedInTheSource;
begin
  const DisplayList = Layout('alpha $x^2+\alpha$');

  Assert.AreEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Text, RunStartingWith(DisplayList, 'alpha').Role);

  const Letter = RunWithText(DisplayList, 'x');
  Assert.AreEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Formula, Letter.Role);
  Assert.IsTrue(Supports(Letter.SourceNode, IMarkdownMath), 'a glyph reads its source off the formula');
  Assert.AreEqual(0, Letter.StartOffset);
  Assert.AreEqual(1, Letter.SourceLength);

  const Exponent = RunWithText(DisplayList, '2');
  Assert.AreEqual(2, Exponent.StartOffset);
  Assert.AreEqual<TDisplayTextJoin>(TDisplayTextJoin.Adjacent, Exponent.Join, 'a formula copies as one stretch');

  const Alpha = RunWithText(DisplayList, #$03B1);
  Assert.AreEqual(4, Alpha.StartOffset);
  Assert.AreEqual(6, Alpha.SourceLength, 'a command glyph stands for its whole spelling');
end;

procedure TMathLayoutIntegrationTests.FormulaGlyphs_HaveNoSourceRun;
begin
  const DisplayList = Layout('alpha $x^2$');

  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    if Supports(DisplayList.Items[Index], IDisplayTextRun, Run) then
      Assert.AreNotEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Source, Run.Role);
  end;
end;

procedure TMathLayoutIntegrationTests.DisplayBlock_IsCentred;
begin
  const DisplayList = Layout('$$'#10'x'#10'$$');

  const Formula = RunWithText(DisplayList, 'x');
  const ContentLeft = FTheme.ContentPadding;
  const ContentWidth = DefaultWidth - 2 * FTheme.ContentPadding;
  const Expected = ContentLeft + (ContentWidth - Formula.Bounds.Width) / 2;
  Assert.AreEqual(Expected, Formula.Bounds.Left, SingleTolerance);
  Assert.AreEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Formula, Formula.Role);
end;

procedure TMathLayoutIntegrationTests.DisplayBlock_UsesDisplayStyle;
begin
  const DisplayList = Layout('$$'#10'\sum_{i=1}^{n} i'#10'$$');

  const Sum = RunWithText(DisplayList, #$2211);
  const Upper = RunWithText(DisplayList, 'n');
  Assert.IsTrue(BaselineOf(Upper) < BaselineOf(Sum), 'display style puts the upper limit above the sum');
  Assert.IsTrue(Sum.Font.Size > FTheme.MathFont.Size, 'display style enlarges the sum');
end;

procedure TMathLayoutIntegrationTests.UnclosedDisplayBlock_StillLaysOut;
begin
  const DisplayList = Layout('$$'#10'\frac{a}{');

  RunWithText(DisplayList, 'a');
  Assert.IsTrue(DisplayList.BlockInfos[0].Height > 0);
end;

procedure TMathLayoutIntegrationTests.Href_PointOnGlyph_FindsItsLink(const Source, Glyph, ExpectedUrl: string);
begin
  const DisplayList = Layout(Source);
  const Point = CentreOf(RunWithText(DisplayList, Glyph));

  var Link: IMarkdownLink;
  const Found = TMarkdownHitTester.TryFindLink(DisplayList, Point, Link);

  Assert.IsTrue(Found);
  Assert.AreEqual(ExpectedUrl, Link.Destination);
end;

procedure TMathLayoutIntegrationTests.Href_PointOnPlainPart_FindsNoLink;
begin
  const DisplayList = Layout('$a+\href{#target}{x}$');
  const Point = CentreOf(RunWithText(DisplayList, 'a'));

  var Link: IMarkdownLink;
  const Found = TMarkdownHitTester.TryFindLink(DisplayList, Point, Link);

  Assert.IsFalse(Found);
end;

class function TMathLayoutIntegrationTests.CentreOf(const Run: IDisplayTextRun): TLayoutPointF;
begin
  const Bounds = Run.Bounds;
  Result := TLayoutPointF.Create((Bounds.Left + Bounds.Right) / 2, (Bounds.Top + Bounds.Bottom) / 2);
end;

procedure TMathViewerTests.Setup;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FMeasurer := TFakeTextMeasurer.Create;
  FModel := TMarkdownViewerModel.Create(FTheme, FMeasurer);
end;

procedure TMathViewerTests.TearDown;
begin
  FreeAndNil(FModel);
  FMeasurer := nil;
  FreeAndNil(FTheme);
end;

function TMathViewerTests.GlyphRun(const Glyph: string): IDisplayTextRun;
begin
  const DisplayList = FModel.DisplayList;
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const Matches = Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and
      (TMathLinearFormat.PlainText(Run.Text) = Glyph);
    if Matches then
    begin
      Result := Run;
      Exit;
    end;
  end;

  raise Exception.CreateFmt('No run "%s" in the display list', [Glyph]);
end;

// From the left edge of one run to the right edge of another, as a drag with
// the mouse does.
procedure TMathViewerTests.Drag(const FromGlyph, ToGlyph: string);
begin
  const First = GlyphRun(FromGlyph).Bounds;
  const Last = GlyphRun(ToGlyph).Bounds;

  FModel.SetSelectionAnchor(TLayoutPointF.Create(First.Left + 0.01, (First.Top + First.Bottom) / 2));
  FModel.SetSelectionExtent(TLayoutPointF.Create(Last.Right - 0.01, (Last.Top + Last.Bottom) / 2));
end;

procedure TMathViewerTests.FindText_SearchesFormulaGlyphsNotSource;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'pi and $\pi r^2$';

  Assert.AreEqual(1, Integer(Length(FModel.FindText(#$03C0))), 'what the reader sees is searchable');
  Assert.AreEqual(0, Integer(Length(FModel.FindText('\pi'))), 'the LaTeX source is not, as in a browser');
end;

procedure TMathViewerTests.TrySelectNextMatch_InsideFormula_SelectsTheGlyph;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'area $\pi r^2$ done';

  var Match: TMarkdownFoundRange;
  const Found = FModel.TrySelectNextMatch(#$03C0, Match);

  Assert.IsTrue(Found);
  Assert.AreEqual(string(#$03C0), FModel.SelectedText);
  Assert.AreEqual('\pi', FModel.SelectedMarkdown);
end;

procedure TMathViewerTests.HighlightMatches_InsideFormula_MarksEveryHit;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'sum $x + x$ done';

  FModel.HighlightMatches('x');

  Assert.AreEqual(2, FModel.HighlightCount, 'each hit in a formula is marked');
  Assert.AreEqual(2, FModel.MatchCount('x'));

  const WholeDocument = TLayoutRectF.Create(0, 0, DefaultWidth, FModel.DisplayList.Height);
  const Marks = FModel.HighlightRectsWithin(WholeDocument);
  const Mark = Marks[0];
  const HasWidth = (Mark.Width > 0);
  Assert.IsTrue(HasWidth, 'the mark covers the formula');
end;

procedure TMathViewerTests.SelectAll_CopiesFormulaAsLinearText;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'area $\pi r^2$ done';

  Assert.IsTrue(FModel.SelectAll);

  Assert.AreEqual('area ' + #$03C0 + 'r' + #$00B2 + ' done', FModel.SelectedText);
end;

procedure TMathViewerTests.SelectAll_DisplayBlock_CopiesLinearText;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'before'#10#10'$$'#10'\frac{a+1}{b}'#10'$$'#10#10'after';

  Assert.IsTrue(FModel.SelectAll);

  Assert.AreEqual('before' + sLineBreak + sLineBreak + '(a+1)/b' + sLineBreak + sLineBreak + 'after',
    FModel.SelectedText);
end;

procedure TMathViewerTests.WideDisplayFormula_ScrollsInsteadOfOverflowing;
begin
  FModel.SetViewport(200, DefaultHeight);
  FModel.Text := WideFormula;

  const Scroller = FindScroller(FModel.DisplayList);
  Assert.IsNotNull(Scroller, 'a formula wider than the column scrolls');
  Assert.IsTrue(Scroller.ContentWidth > Scroller.Bounds.Width);
  Assert.AreEqual(Single(0), Scroller.Offset);

  FModel.Text := '$$'#10'a + b'#10'$$';
  Assert.IsNull(FindScroller(FModel.DisplayList), 'one that fits does not');
end;

procedure TMathViewerTests.ScrollSideways_MovesContentAndKeepsItOverRelayout;
begin
  FModel.SetViewport(200, DefaultHeight);
  FModel.Text := WideFormula;

  const Before = GlyphBounds(FModel.DisplayList, 'c').Left;
  const Band = FindScroller(FModel.DisplayList).Bounds;
  const Inside = TLayoutPointF.Create(Band.Left + 10, (Band.Top + Band.Bottom) / 2);

  Assert.IsTrue(FModel.ScrollSideways(Inside, 30));
  Assert.AreEqual(Before - 30, GlyphBounds(FModel.DisplayList, 'c').Left, ScrollTolerance,
    'the content moves with the offset');

  FModel.SetViewport(210, DefaultHeight);
  Assert.AreEqual(Single(30), FindScroller(FModel.DisplayList).Offset, ScrollTolerance, 'a new layout keeps it');

  Assert.IsFalse(FModel.ScrollSideways(TLayoutPointF.Create(Band.Left + 10, Band.Bottom + 50), 30),
    'outside a scroller there is nothing to scroll');
end;

procedure TMathViewerTests.ScrollerThumbDrag_ScrollsToTheEnd;
begin
  FModel.SetViewport(200, DefaultHeight);
  FModel.Text := WideFormula;

  const Scroller = FindScroller(FModel.DisplayList);
  const Thumb = Scroller.Thumb;
  const Middle = (Thumb.Top + Thumb.Bottom) / 2;

  Assert.IsTrue(FModel.TryBeginScrollerDrag(TLayoutPointF.Create(Thumb.Left + 1, Middle)));
  FModel.DragScrollerThumb(TLayoutPointF.Create(Scroller.Track.Right + 100, Middle));
  FModel.EndScrollerDrag;

  const Moved = FindScroller(FModel.DisplayList);
  Assert.AreEqual(Moved.MaxOffset, Moved.Offset, ScrollTolerance, 'dragging past the end stops at the end');
end;

procedure TMathViewerTests.WideDisplayFormula_TrackSitsRightBelowFormula;
begin
  FModel.SetViewport(200, DefaultHeight);
  FModel.Text := WideFormula;

  const Track = FindScroller(FModel.DisplayList).Track;
  const Block = FModel.DisplayList.BlockInfos[0];
  const SpaceBelowTrack = Block.Top + Block.Height - Track.Bottom;
  const IsAbovePadding = (SpaceBelowTrack >= FTheme.BlockSpacing / 2 - ScrollTolerance);
  Assert.IsTrue(IsAbovePadding, 'the padding of the block stays below the track');
end;

procedure TMathViewerTests.DisplayFormula_TakesTextLineAsMinimumHeight;
begin
  FTheme.BaseFont := TMarkdownFontStyle.Create(FTheme.BaseFont.FamilyName, FTheme.MathFont.Size / 2);
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '$$'#10'x'#10'$$';

  const Block = FModel.DisplayList.BlockInfos[0];
  const MathLineHeight = FMeasurer.LineHeight(FTheme.MathFont);
  const IsBelowMathLine = (Block.Height < MathLineHeight + FTheme.BlockSpacing);
  Assert.IsTrue(IsBelowMathLine, 'the line height of the math font, which can be far taller, does not count');
end;

procedure TMathViewerTests.Href_ScrolledOutOfView_FindsNoLink;
begin
  FModel.SetViewport(200, DefaultHeight);
  FModel.Text := WideLinkedFormula;

  const Band = FindScroller(FModel.DisplayList).Bounds;
  const InView = CentreOf(GlyphBounds(FModel.DisplayList, 'a'));
  var Link: IMarkdownLink;
  Assert.IsTrue(TMarkdownHitTester.TryFindLink(FModel.DisplayList, InView, Link), 'in view the link answers');

  FModel.ScrollSideways(InView, 30);

  const Glyph = GlyphBounds(FModel.DisplayList, 'a');
  const IsOutOfView = (Glyph.Right < Band.Left);
  Assert.IsTrue(IsOutOfView);
  Assert.IsFalse(TMarkdownHitTester.TryFindLink(FModel.DisplayList, CentreOf(Glyph), Link),
    'scrolled out of view it does not');
end;

class function TMathViewerTests.FindScroller(const DisplayList: IMarkdownDisplayList): IDisplayScroller;
begin
  Result := nil;
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    if Supports(DisplayList.Items[Index], IDisplayScroller, Result) then
      Exit;
  end;
end;

class function TMathViewerTests.GlyphBounds(const DisplayList: IMarkdownDisplayList; const Glyph: string): TLayoutRectF;
begin
  const Run = TMathLayoutIntegrationTests.RunWithText(DisplayList, Glyph);
  Result := Run.Bounds;
end;

class function TMathViewerTests.CentreOf(const Bounds: TLayoutRectF): TLayoutPointF;
begin
  Result := TLayoutPointF.Create((Bounds.Left + Bounds.Right) / 2, (Bounds.Top + Bounds.Bottom) / 2);
end;

procedure TMathViewerTests.SelectedMarkdown_SelectAll_KeepsFormulaSource;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'area $\pi r^2$ done';

  Assert.IsTrue(FModel.SelectAll);

  Assert.AreEqual('area $\pi r^2$ done', FModel.SelectedMarkdown);
end;

procedure TMathViewerTests.Drag_PartOfFormula_CopiesShownGlyphsAndTheirSource;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'area $\pi r^2$ done';

  Drag('r', '2');

  Assert.AreEqual('r2', FModel.SelectedText);
  Assert.AreEqual('r^2', FModel.SelectedMarkdown);
end;

procedure TMathViewerTests.Drag_InsideFraction_CopiesBalancedSource;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'so $\frac{a}{b}+c$ holds';

  Drag('a', 'b');

  Assert.AreEqual('\frac{a}{b}', FModel.SelectedMarkdown);
end;

procedure TMathViewerTests.Drag_OverWholeFormula_CopiesLinearTextAndMarkdown;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'so $\frac{a}{b}$ holds';

  Drag('a', 'b');

  Assert.AreEqual('a/b', FModel.SelectedText);
  Assert.AreEqual('$\frac{a}{b}$', FModel.SelectedMarkdown);
end;

procedure TMathViewerTests.Drag_FromTextIntoFormula_CopiesBoth;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'area $\pi r^2$ done';

  const Area = GlyphRun('area ').Bounds;
  const Letter = GlyphRun('r').Bounds;
  FModel.SetSelectionAnchor(TLayoutPointF.Create(Area.Left + 0.01, (Area.Top + Area.Bottom) / 2));
  FModel.SetSelectionExtent(TLayoutPointF.Create(Letter.Right - 0.01, (Letter.Top + Letter.Bottom) / 2));

  Assert.AreEqual('area ' + #$03C0 + 'r', FModel.SelectedText);
  Assert.AreEqual('area $\pi r', FModel.SelectedMarkdown);
end;

procedure TMathViewerTests.Drag_InsideTextCommand_SelectsCharacters;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'so $x \text{hello} y$ done';

  const Words = GlyphRun('hello').Bounds;
  const Middle = (Words.Top + Words.Bottom) / 2;
  FModel.SetSelectionAnchor(TLayoutPointF.Create(Words.Left + Words.Width * 0.3, Middle));
  FModel.SetSelectionExtent(TLayoutPointF.Create(Words.Right - 0.01, Middle));

  const Selected = FModel.SelectedText;
  Assert.IsTrue((Selected <> '') and (Selected <> 'hello') and 'hello'.EndsWith(Selected),
    'part of a word in \text is selected as in a paragraph: ' + Selected);
  Assert.AreEqual(Selected, FModel.SelectedMarkdown, 'and copies as typed');
end;

procedure TMathViewerTests.Drag_OverHrefText_CopiesWholeLink;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'see $a+\href{https://example.com}{x+y}$ here';

  Drag('x', 'y');

  Assert.AreEqual('x+y', FModel.SelectedText, 'plain text copies what the link shows');
  Assert.AreEqual('\href{https://example.com}{x+y}', FModel.SelectedMarkdown, 'markdown keeps the link');
end;

procedure TMathViewerTests.Drag_OverUrl_CopiesWholeCommand;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'see $a+\url{example.com}$ here';

  const Address = GlyphRun('example.com').Bounds;
  const Middle = (Address.Top + Address.Bottom) / 2;
  FModel.SetSelectionAnchor(TLayoutPointF.Create(Address.Left + Address.Width * 0.3, Middle));
  FModel.SetSelectionExtent(TLayoutPointF.Create(Address.Right - 0.01, Middle));

  Assert.AreEqual('\url{example.com}', FModel.SelectedMarkdown);
end;

procedure TMathViewerTests.SelectWordAt_FormulaGlyph_SelectsTheGlyphsWithoutSpace;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'area $\pi r^2$ done';

  const Letter = GlyphRun('r').Bounds;
  Assert.IsTrue(FModel.SelectWordAt(TLayoutPointF.Create((Letter.Left + Letter.Right) / 2,
    (Letter.Top + Letter.Bottom) / 2)));

  Assert.AreEqual(#$03C0 + 'r', FModel.SelectedText, 'as a browser takes letters without a space between them');
end;

procedure TMathViewerTests.SelectWordAt_LettersOnOneBaseline_SelectsTheName;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'so $x = ac^2 + b$ holds';

  const Letter = GlyphRun('a').Bounds;
  Assert.IsTrue(FModel.SelectWordAt(TLayoutPointF.Create((Letter.Left + Letter.Right) / 2,
    (Letter.Top + Letter.Bottom) / 2)));

  Assert.AreEqual('ac', FModel.SelectedText, 'the letters of a name, but not its power');
end;

procedure TMathViewerTests.FormulaGlyphs_OfAFraction_DoNotOverlap;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '$$'#10'\frac{a}{b}'#10'$$';

  const Numerator = GlyphRun('a').Bounds;
  const Denominator = GlyphRun('b').Bounds;
  Assert.IsTrue(Numerator.Bottom <= Denominator.Top, 'a glyph spans its ink, not the line of its font');
end;

procedure TMathViewerTests.Drag_InsideDenominator_SelectsItAlone;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '$$'#10'x = \frac{-b+c}{2a}'#10'$$';

  Drag('2', 'a');

  Assert.AreEqual('2a', FModel.SelectedText);
  Assert.AreEqual('2a', FModel.SelectedMarkdown);
end;

procedure TMathViewerTests.Drag_PastTheEndOfFormula_SelectsAllOfIt;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '$$'#10'x = \frac{-b+c}{2a}'#10'$$';

  const Start = GlyphRun('x').Bounds;
  const Numerator = GlyphRun('c').Bounds;
  FModel.SetSelectionAnchor(TLayoutPointF.Create(Start.Left + 0.01, (Start.Top + Start.Bottom) / 2));
  FModel.SetSelectionExtent(TLayoutPointF.Create(Numerator.Right + 20, (Numerator.Top + Numerator.Bottom) / 2));

  Assert.AreEqual('x=('#$2212'b+c)/(2a)', FModel.SelectedText,
    'beside the numerator still means the end of the formula');
  Assert.AreEqual('$$'#10'x = \frac{-b+c}{2a}'#10'$$', FModel.SelectedMarkdown.Replace(sLineBreak, #10));
end;

procedure TMathViewerTests.CodeBlockRegions_DisplayFormulaByDefault_OffersNoButton;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '$$'#10'\sqrt{x^2+1}'#10'$$';

  Assert.AreEqual(0, Integer(Length(FModel.CodeBlockRegions)));
end;

procedure TMathViewerTests.CodeBlockRegions_DisplayFormula_OffersLinearText;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.FormulaCopyButton := True;
  FModel.Text := '$$'#10'\sqrt{x^2+1}'#10'$$';

  const Regions = FModel.CodeBlockRegions;

  Assert.AreEqual(1, Integer(Length(Regions)));
  Assert.AreEqual(#$221A + '(x' + #$00B2 + '+1)', Regions[0].Text);
end;

end.
