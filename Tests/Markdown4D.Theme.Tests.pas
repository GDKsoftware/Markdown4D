unit Markdown4D.Theme.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Theme;

type
  [TestFixture]
  TMarkdownThemeTests = class
  private
    const
      OverrideLinkColor = $FF123456;
      OverrideFamilyName = 'Override Sans';
      OverrideFontSize = 28.0;
      OverrideSpacing = 42.0;
      OverrideHeadingLevel = 2;
      OverrideSpacingLevel = 3;
      MinimumChartColors = 8;
      SingleTolerance = 0.001;
      DefaultContentPaddingValue = 16.0;
      OverrideContentPadding = 42.0;
      OverrideCodeSpanBackground = $FF7788AA;
      WrongTypeKey = 'linkColor';
      WrongTypeValue = 'not-a-color';

  public
    [Test]
    procedure CreateLightAndCreateDark_CoreColorsDiffer;

    [Test]
    procedure PerElementOverrides_StickAfterAssignment;

    [Test]
    procedure SaveToJson_LoadFromJson_IsByteStable;

    [Test]
    procedure ChartPalette_BothPresets_HaveAtLeastEightColors;

    [Test]
    procedure ContentPadding_BothPresets_DefaultToSixteen;

    [Test]
    procedure ContentPadding_SurvivesJsonRoundTrip;

    [Test]
    procedure CodeSpanBackground_BothPresets_MatchCodeBackgroundTone;

    [Test]
    procedure CodeSpanBackground_SurvivesJsonRoundTrip;

    [Test]
    procedure LoadFromJson_WronglyTypedValue_RaisesMarkdownError;
  end;

implementation

uses
  System.JSON,
  Markdown4D.Defines,
  Markdown4D.Layout.Interfaces;

procedure TMarkdownThemeTests.CreateLightAndCreateDark_CoreColorsDiffer;
begin
  const Light = TMarkdownTheme.CreateLight;
  try
    const Dark = TMarkdownTheme.CreateDark;
    try
      const BackgroundsDiffer = (Light.BackgroundColor <> Dark.BackgroundColor);
      Assert.IsTrue(BackgroundsDiffer);

      const TextColorsDiffer = (Light.TextColor <> Dark.TextColor);
      Assert.IsTrue(TextColorsDiffer);

      const CodeBackgroundsDiffer = (Light.CodeBackgroundColor <> Dark.CodeBackgroundColor);
      Assert.IsTrue(CodeBackgroundsDiffer);
    finally
      Dark.Free;
    end;
  finally
    Light.Free;
  end;
end;

procedure TMarkdownThemeTests.PerElementOverrides_StickAfterAssignment;
begin
  const Theme = TMarkdownTheme.CreateLight;
  try
    Theme.LinkColor := OverrideLinkColor;
    Theme.HeadingFonts[OverrideHeadingLevel] := TMarkdownFontStyle.Create(OverrideFamilyName, OverrideFontSize, True);
    Theme.HeadingSpacingAbove[OverrideSpacingLevel] := OverrideSpacing;

    const LinkColorSticks = (Theme.LinkColor = OverrideLinkColor);
    Assert.IsTrue(LinkColorSticks);

    const HeadingFont = Theme.HeadingFonts[OverrideHeadingLevel];
    Assert.AreEqual(OverrideFamilyName, HeadingFont.FamilyName);
    Assert.AreEqual(Double(OverrideFontSize), Double(HeadingFont.Size), SingleTolerance);
    Assert.IsTrue(HeadingFont.Bold);

    Assert.AreEqual(Double(OverrideSpacing), Double(Theme.HeadingSpacingAbove[OverrideSpacingLevel]), SingleTolerance);
  finally
    Theme.Free;
  end;
end;

procedure TMarkdownThemeTests.SaveToJson_LoadFromJson_IsByteStable;
begin
  const Light = TMarkdownTheme.CreateLight;
  try
    const SavedJson = Light.SaveToJson;

    const Loaded = TMarkdownTheme.CreateDark;
    try
      Loaded.LoadFromJson(SavedJson);

      const ReloadedJson = Loaded.SaveToJson;
      Assert.AreEqual(SavedJson, ReloadedJson);
    finally
      Loaded.Free;
    end;
  finally
    Light.Free;
  end;
end;

procedure TMarkdownThemeTests.ChartPalette_BothPresets_HaveAtLeastEightColors;
begin
  const Light = TMarkdownTheme.CreateLight;
  try
    const LightHasEnoughColors = (Length(Light.ChartPalette) >= MinimumChartColors);
    Assert.IsTrue(LightHasEnoughColors);
  finally
    Light.Free;
  end;

  const Dark = TMarkdownTheme.CreateDark;
  try
    const DarkHasEnoughColors = (Length(Dark.ChartPalette) >= MinimumChartColors);
    Assert.IsTrue(DarkHasEnoughColors);
  finally
    Dark.Free;
  end;
end;

procedure TMarkdownThemeTests.ContentPadding_BothPresets_DefaultToSixteen;
begin
  const Light = TMarkdownTheme.CreateLight;
  try
    Assert.AreEqual(Double(DefaultContentPaddingValue), Double(Light.ContentPadding), SingleTolerance);
  finally
    Light.Free;
  end;

  const Dark = TMarkdownTheme.CreateDark;
  try
    Assert.AreEqual(Double(DefaultContentPaddingValue), Double(Dark.ContentPadding), SingleTolerance);
  finally
    Dark.Free;
  end;
end;

procedure TMarkdownThemeTests.ContentPadding_SurvivesJsonRoundTrip;
begin
  const Source = TMarkdownTheme.CreateLight;
  try
    Source.ContentPadding := OverrideContentPadding;
    const SavedJson = Source.SaveToJson;

    const Loaded = TMarkdownTheme.CreateDark;
    try
      Loaded.LoadFromJson(SavedJson);
      Assert.AreEqual(Double(OverrideContentPadding), Double(Loaded.ContentPadding), SingleTolerance);
    finally
      Loaded.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TMarkdownThemeTests.CodeSpanBackground_BothPresets_MatchCodeBackgroundTone;
begin
  const Light = TMarkdownTheme.CreateLight;
  try
    const LightMatchesTone = (Light.CodeSpanBackgroundColor = Light.CodeBackgroundColor);
    Assert.IsTrue(LightMatchesTone);
  finally
    Light.Free;
  end;

  const Dark = TMarkdownTheme.CreateDark;
  try
    const DarkMatchesTone = (Dark.CodeSpanBackgroundColor = Dark.CodeBackgroundColor);
    Assert.IsTrue(DarkMatchesTone);
  finally
    Dark.Free;
  end;
end;

procedure TMarkdownThemeTests.CodeSpanBackground_SurvivesJsonRoundTrip;
begin
  const Source = TMarkdownTheme.CreateLight;
  try
    Source.CodeSpanBackgroundColor := OverrideCodeSpanBackground;
    const SavedJson = Source.SaveToJson;

    const Loaded = TMarkdownTheme.CreateDark;
    try
      Loaded.LoadFromJson(SavedJson);

      const RoundTrips = (Loaded.CodeSpanBackgroundColor = OverrideCodeSpanBackground);
      Assert.IsTrue(RoundTrips);
    finally
      Loaded.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TMarkdownThemeTests.LoadFromJson_WronglyTypedValue_RaisesMarkdownError;
begin
  const Source = TMarkdownTheme.CreateLight;
  try
    const ValidJson = Source.SaveToJson;

    const Root = TJSONObject.ParseJSONValue(ValidJson) as TJSONObject;
    try
      Root.RemovePair(WrongTypeKey).Free;
      Root.AddPair(WrongTypeKey, TJSONString.Create(WrongTypeValue));
      const InvalidJson = Root.ToJSON;

      const Target = TMarkdownTheme.CreateLight;
      try
        Assert.WillRaise(
          procedure
          begin
            Target.LoadFromJson(InvalidJson);
          end, EMarkdownError);
      finally
        Target.Free;
      end;
    finally
      Root.Free;
    end;
  finally
    Source.Free;
  end;
end;

end.
