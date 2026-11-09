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
    procedure Tabular_DrawsRulesAndUprightText;

    [Test]
    procedure Tabular_KeepsRoomBetweenTextAndRules;

    [Test]
    procedure InlineMath_AloneOnLine_KeepsTheTextLineHeight;

    [Test]
    procedure InlineMath_AloneInTableCell_SharesBaselineWithNeighbour;

    [Test]
    procedure FormulaGlyphs_AreGlyphsWithOneSourceRun;

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
    class function GlyphPlaces(const DisplayList: IMarkdownDisplayList): string;
    function GlyphRun(const Text: string): IDisplayTextRun;
    procedure Drag(const FromText, ToText: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure FindText_SearchesFormulaSourceNotGlyphs;

    [Test]
    procedure TrySelectNextMatch_InsideFormula_SelectsWholeFormula;

    [Test]
    procedure SelectedMarkdown_DisplayFormula_TakesItsClosingFence;

    [Test]
    procedure SelectedMarkdown_DisplayFormulaInQuote_TakesItsClosingFence;

    [Test]
    procedure SelectedMarkdown_OpenDisplayFormula_EndsWithTheDocument;

    [Test]
    procedure HighlightMatches_InsideFormula_MarksWholeFormulaOnce;

    [Test]
    procedure SelectAll_CopiesFormulaAsMarkdown;

    [Test]
    procedure SelectAll_DisplayBlock_CopiesDollarFences;

    [Test]
    procedure Glyphs_ArePlacedInTheirFormula;

    [Test]
    procedure Drag_PartOfFormula_CopiesTheGlyphsShown;

    [Test]
    procedure Drag_OverWholeFormula_CopiesItsMarkdown;

    [Test]
    procedure Drag_FromTextIntoFormula_CopiesBoth;

    [Test]
    procedure Drag_InsideDenominator_SelectsItAlone;

    [Test]
    procedure Drag_InsideTextCommand_SelectsCharacters;

    [Test]
    procedure Drag_PastTheEndOfFormula_SelectsAllOfIt;

    [Test]
    procedure Drag_OverDisplayFormulaBetweenText_CopiesItsFences;

    [Test]
    procedure SelectionRects_PartOfFormula_MarkOnlyItsGlyphs;

    [Test]
    procedure SelectWordAt_LettersOnOneBaseline_SelectsTheName;

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
  Markdown4D.Layout.FakeMeasurer;

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

procedure TMathLayoutIntegrationTests.Tabular_DrawsRulesAndUprightText;
begin
  const DisplayList = Layout('$$'#10'\begin{tabular}{|c|c|}'#10'\hline'#10'Spalte 1 & Spalte 2 \\'#10'\hline'#10 +
    '\end{tabular}'#10'$$');

  const Words = RunWithText(DisplayList, 'Spalte 1');
  Assert.IsFalse(Words.Font.Italic, 'tabular cells are text');

  var Rules := 0;
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Rectangle: IDisplayRectangle;
    if Supports(DisplayList.Items[Index], IDisplayRectangle, Rectangle) and (Rectangle.FillColor <> 0) then
      Inc(Rules);
  end;
  Assert.AreEqual(5, Rules, 'two \hline and three vertical rules');
end;

// A row is as tall as LaTeX's strut, 1.2 em, with 0.2 em more above and below
// it, so the rules keep clear of the text.
procedure TMathLayoutIntegrationTests.Tabular_KeepsRoomBetweenTextAndRules;
begin
  const DisplayList = Layout('$$'#10'\begin{tabular}{c}'#10'\hline'#10'Word \\'#10'\hline'#10'\end{tabular}'#10'$$');
  const MinimumRowHeight = 1.6 * FTheme.MathFont.Size;

  var Rules: TArray<TLayoutRectF> := [];
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Rule: IDisplayRectangle;
    const IsRule = (Supports(DisplayList.Items[Index], IDisplayRectangle, Rule) and (Rule.FillColor <> 0));
    if IsRule then
      Rules := Rules + [Rule.Bounds];
  end;

  Assert.AreEqual(2, Integer(Length(Rules)));
  const RowHeight = Rules[1].Top - Rules[0].Bottom;
  Assert.IsTrue(RowHeight >= MinimumRowHeight - SingleTolerance, 'the row keeps room above and below its text');
end;

procedure TMathLayoutIntegrationTests.InlineMath_KeepsTheSpaceAfterIt;
begin
  const DisplayList = Layout('alpha $x$ beta');

  const Formula = RunWithText(DisplayList, 'x');
  const After = RunStartingWith(DisplayList, ' beta');
  Assert.IsTrue(After.Bounds.Left >= Formula.Bounds.Right, 'the space and the word follow the formula');
end;

// A small formula such as $m$ alone on a line must not make the line lower
// than a line of text: the line keeps the height of its font, as in a browser.
procedure TMathLayoutIntegrationTests.InlineMath_AloneOnLine_KeepsTheTextLineHeight;
begin
  const Text = Layout('alpha');
  const Formula = Layout('$m$');

  Assert.AreEqual(Text.BlockInfos[0].Height, Formula.BlockInfos[0].Height, SingleTolerance);
end;

// A table cell holding nothing but a formula sits on the same baseline as the
// text in the cell next to it instead of rising to the top of the row.
procedure TMathLayoutIntegrationTests.InlineMath_AloneInTableCell_SharesBaselineWithNeighbour;
begin
  const DisplayList = Layout('| a | b |' + sLineBreak + '|---|---|' + sLineBreak + '| $m$ | Masse |');

  const Formula = RunWithText(DisplayList, 'm');
  const Text = RunStartingWith(DisplayList, 'Masse');
  Assert.AreEqual(BaselineOf(Text), BaselineOf(Formula), SingleTolerance);
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

procedure TMathLayoutIntegrationTests.FormulaGlyphs_AreGlyphsWithOneSourceRun;
begin
  const DisplayList = Layout('alpha $x^2$');

  Assert.AreEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Text, RunStartingWith(DisplayList, 'alpha').Role);
  Assert.AreEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Formula, RunWithText(DisplayList, 'x').Role);
  Assert.AreEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Formula, RunWithText(DisplayList, '2').Role);

  const Source = RunWithText(DisplayList, '$x^2$');
  Assert.AreEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Source, Source.Role);
  Assert.AreEqual(RunWithText(DisplayList, 'x').Bounds.Left, Source.Bounds.Left, SingleTolerance);
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
  Assert.AreEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Source, RunWithText(DisplayList, '$$'#10'x'#10'$$').Role);
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

procedure TMathViewerTests.FindText_SearchesFormulaSourceNotGlyphs;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'pi and $\pi r^2$';

  Assert.AreEqual(1, Integer(Length(FModel.FindText('\pi'))), 'the LaTeX source is searchable');
  Assert.AreEqual(0, Integer(Length(FModel.FindText(#$03C0))), 'the drawn glyph is not');
end;

procedure TMathViewerTests.TrySelectNextMatch_InsideFormula_SelectsWholeFormula;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'area $\pi r^2$ done';

  var Match: TMarkdownFoundRange;
  const Found = FModel.TrySelectNextMatch('r^2', Match);

  Assert.IsTrue(Found);
  Assert.AreEqual('$\pi r^2$', FModel.SelectedText, 'a formula is selected whole or not at all');
end;

// Pasted without the $$ that closes it, a display formula would swallow
// everything after it.
procedure TMathViewerTests.SelectedMarkdown_DisplayFormula_TakesItsClosingFence;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'before'#10#10'$$'#10'x + y'#10'$$'#10#10'after';

  var Match: TMarkdownFoundRange;
  Assert.IsTrue(FModel.TrySelectNextMatch('x + y', Match));

  Assert.AreEqual('$$'#10'x + y'#10'$$', FModel.SelectedMarkdown.Replace(sLineBreak, #10));
end;

procedure TMathViewerTests.SelectedMarkdown_DisplayFormulaInQuote_TakesItsClosingFence;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '> $$'#10'> x + y'#10'> $$'#10#10'after';

  var Match: TMarkdownFoundRange;
  Assert.IsTrue(FModel.TrySelectNextMatch('x + y', Match));

  Assert.AreEqual('> $$'#10'> x + y'#10'> $$', FModel.SelectedMarkdown.Replace(sLineBreak, #10));
end;

procedure TMathViewerTests.SelectedMarkdown_OpenDisplayFormula_EndsWithTheDocument;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'before'#10#10'$$'#10'x + y';

  var Match: TMarkdownFoundRange;
  Assert.IsTrue(FModel.TrySelectNextMatch('x + y', Match));

  Assert.AreEqual('$$'#10'x + y', FModel.SelectedMarkdown.Replace(sLineBreak, #10));
end;

procedure TMathViewerTests.HighlightMatches_InsideFormula_MarksWholeFormulaOnce;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'sum $x + x$ done';

  FModel.HighlightMatches('x');

  Assert.AreEqual(1, FModel.HighlightCount, 'two hits in one formula mark it once');
  Assert.AreEqual(1, FModel.MatchCount('x'), 'and count as one stop');

  const WholeDocument = TLayoutRectF.Create(0, 0, DefaultWidth, FModel.DisplayList.Height);
  const Marks = FModel.HighlightRectsWithin(WholeDocument);
  const Mark = Marks[0];
  const HasWidth = (Mark.Width > 0);
  Assert.IsTrue(HasWidth, 'the mark covers the formula');
end;

procedure TMathViewerTests.SelectAll_CopiesFormulaAsMarkdown;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'area $\pi r^2$ done';

  Assert.IsTrue(FModel.SelectAll);

  Assert.AreEqual('area $\pi r^2$ done', FModel.SelectedText);
end;

procedure TMathViewerTests.SelectAll_DisplayBlock_CopiesDollarFences;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'before'#10#10'$$'#10'\frac{a}{b}'#10'$$'#10#10'after';

  Assert.IsTrue(FModel.SelectAll);

  Assert.AreEqual('before' + sLineBreak + sLineBreak + '$$'#10'\frac{a}{b}'#10'$$' + sLineBreak + sLineBreak + 'after',
    FModel.SelectedText);
end;

// Inside a link a glyph is attributed to the link, so a click follows it,
// while its place stays in the formula.
procedure TMathViewerTests.Glyphs_ArePlacedInTheirFormula;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '[so $a+\alpha$](#target)'#10#10'$$'#10'\frac{b}{c}'#10'$$';

  Assert.AreEqual('a|+|\alpha|b|c', GlyphPlaces(FModel.DisplayList));
end;

// Copy as Markdown takes a formula the selection cuts whole, as it takes any
// other inline element.
procedure TMathViewerTests.Drag_PartOfFormula_CopiesTheGlyphsShown;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'area $\pi r^2$ done';

  Drag('r', '2');

  Assert.AreEqual('r2', FModel.SelectedText);
  Assert.AreEqual('$\pi r^2$', FModel.SelectedMarkdown);
end;

procedure TMathViewerTests.Drag_OverWholeFormula_CopiesItsMarkdown;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'so $\frac{a}{b}$ holds';

  Drag('a', 'b');

  Assert.AreEqual('$\frac{a}{b}$', FModel.SelectedText, 'a whole formula copies as its markdown');
  Assert.AreEqual('$\frac{a}{b}$', FModel.SelectedMarkdown);
end;

procedure TMathViewerTests.Drag_FromTextIntoFormula_CopiesBoth;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'area $\pi r^2$ done';

  Drag('area ', 'r');

  Assert.AreEqual('area ' + #$03C0 + 'r', FModel.SelectedText);
  Assert.AreEqual('area $\pi r^2$', FModel.SelectedMarkdown);
end;

procedure TMathViewerTests.Drag_InsideDenominator_SelectsItAlone;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '$$'#10'x = \frac{-b+c}{2a}'#10'$$';

  Drag('2', 'a');

  Assert.AreEqual('2a', FModel.SelectedText);
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
  const IsPartOfWord = ((Selected <> '') and (Selected <> 'hello') and 'hello'.EndsWith(Selected));
  Assert.IsTrue(IsPartOfWord, 'part of a word in \text is selected as in a paragraph: ' + Selected);
end;

// Beside the numerator still means the end of the formula.
procedure TMathViewerTests.Drag_PastTheEndOfFormula_SelectsAllOfIt;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := '$$'#10'x = \frac{-b+c}{2a}'#10'$$';

  const Start = GlyphRun('x').Bounds;
  const Numerator = GlyphRun('c').Bounds;
  FModel.SetSelectionAnchor(TLayoutPointF.Create(Start.Left + 0.01, (Start.Top + Start.Bottom) / 2));
  FModel.SetSelectionExtent(TLayoutPointF.Create(Numerator.Right + 20, (Numerator.Top + Numerator.Bottom) / 2));

  Assert.AreEqual('$$'#10'x = \frac{-b+c}{2a}'#10'$$', FModel.SelectedText);
end;

procedure TMathViewerTests.Drag_OverDisplayFormulaBetweenText_CopiesItsFences;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'before'#10#10'$$'#10'x + y'#10'$$'#10#10'after';

  Drag('x', 'y');

  Assert.AreEqual('$$'#10'x + y'#10'$$', FModel.SelectedText);
  Assert.AreEqual('$$'#10'x + y'#10'$$', FModel.SelectedMarkdown.Replace(sLineBreak, #10));
end;

procedure TMathViewerTests.SelectionRects_PartOfFormula_MarkOnlyItsGlyphs;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'area $\pi r^2$ done';

  Drag('r', '2');

  const Left = GlyphRun('r').Bounds.Left;
  const Right = GlyphRun('2').Bounds.Right;
  const Rects = FModel.SelectionRects;
  Assert.IsTrue(Length(Rects) > 0);
  for var Rect in Rects do
  begin
    const IsInside = ((Rect.Left >= Left - ScrollTolerance) and (Rect.Right <= Right + ScrollTolerance));
    Assert.IsTrue(IsInside, 'the rest of the formula stays unmarked');
  end;
end;

procedure TMathViewerTests.SelectWordAt_LettersOnOneBaseline_SelectsTheName;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'so $x = ac^2 + b$ holds';

  const Letter = GlyphRun('a').Bounds;
  Assert.IsTrue(FModel.SelectWordAt(CentreOf(Letter)));

  Assert.AreEqual('ac', FModel.SelectedText, 'the letters of a name, but not its power');
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

// The first run that shows Text, a glyph of a formula or a run of text.
function TMathViewerTests.GlyphRun(const Text: string): IDisplayTextRun;
begin
  const DisplayList = FModel.DisplayList;
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const IsMatch = (Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and (Run.Text = Text));
    if IsMatch then
    begin
      Result := Run;
      Exit;
    end;
  end;

  raise Exception.CreateFmt('No run "%s" in the display list', [Text]);
end;

// From the left edge of one run to the right edge of another, as a drag with
// the mouse does.
procedure TMathViewerTests.Drag(const FromText, ToText: string);
begin
  const First = GlyphRun(FromText).Bounds;
  const Last = GlyphRun(ToText).Bounds;

  FModel.SetSelectionAnchor(TLayoutPointF.Create(First.Left + 0.01, (First.Top + First.Bottom) / 2));
  FModel.SetSelectionExtent(TLayoutPointF.Create(Last.Right - 0.01, (Last.Top + Last.Bottom) / 2));
end;

// The source each glyph of a formula was set from, in the order of the
// display list.
class function TMathViewerTests.GlyphPlaces(const DisplayList: IMarkdownDisplayList): string;
begin
  var Places: TArray<string> := [];
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    if not Supports(DisplayList.Items[Index], IDisplayTextRun, Run) then
      Continue;

    var Math: IMarkdownMath;
    const IsGlyph = ((Run.Role = TDisplayTextRunRole.Formula) and Supports(Run.SourceNode, IMarkdownMath, Math));
    if IsGlyph then
      Places := Places + [Copy(Math.Literal, Run.StartOffset + 1, Run.SourceLength)];
  end;

  Result := string.Join('|', Places);
end;

end.
