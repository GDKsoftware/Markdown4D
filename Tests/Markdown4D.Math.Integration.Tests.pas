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
    procedure FormulaGlyphs_AreDrawingsWithOneSourceRun;

    [Test]
    procedure DisplayBlock_IsCentred;

    [Test]
    procedure DisplayBlock_UsesDisplayStyle;

    [Test]
    procedure UnclosedDisplayBlock_StillLaysOut;
  end;

  [TestFixture]
  TMathViewerTests = class
  private
    const
      DefaultWidth = 400.0;
      DefaultHeight = 300.0;
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FModel: TMarkdownViewerModel;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure FindText_SearchesFormulaSourceNotGlyphs;

    [Test]
    procedure SelectAll_CopiesFormulaAsMarkdown;

    [Test]
    procedure SelectAll_DisplayBlock_CopiesDollarFences;
  end;

implementation

uses
  System.SysUtils,
  System.JSON,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.Defaults,
  Markdown4D.Layout.Engine,
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

procedure TMathLayoutIntegrationTests.InlineMath_KeepsTheSpaceAfterIt;
begin
  const DisplayList = Layout('alpha $x$ beta');

  const Formula = RunWithText(DisplayList, 'x');
  const After = RunStartingWith(DisplayList, ' beta');
  Assert.IsTrue(After.Bounds.Left >= Formula.Bounds.Right, 'the space and the word follow the formula');
end;

procedure TMathLayoutIntegrationTests.FormulaGlyphs_AreDrawingsWithOneSourceRun;
begin
  const DisplayList = Layout('alpha $x^2$');

  Assert.AreEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Text, RunStartingWith(DisplayList, 'alpha').Role);
  Assert.AreEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Drawing, RunWithText(DisplayList, 'x').Role);
  Assert.AreEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Drawing, RunWithText(DisplayList, '2').Role);

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
  Assert.AreEqual<TDisplayTextRunRole>(TDisplayTextRunRole.Drawing, Formula.Role);
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

  Assert.AreEqual('before' + sLineBreak + '$$'#10'\frac{a}{b}'#10'$$' + sLineBreak + 'after', FModel.SelectedText);
end;

end.
