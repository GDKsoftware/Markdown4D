unit Markdown4D.Theme.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.JSON,
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
      OverrideDiffBackground = $FF224466;
      OverrideAlertColor = $FF6644AA;
      TokenColorsKey = 'codeTokenColors';
      LegacyTokenColorCount = 13;
      KeysAddedWithDiffAndAlerts: array[0..2] of string = ('diffInsertedBackgroundColor',
        'diffDeletedBackgroundColor', 'alertColors');
      OverrideThematicBreakSpacing = 30.0;
      GitHubBlockSpacing = 16.0;
      GitHubHeadingSpacingAbove = 24.0;
      GitHubThematicBreakSpacing = 24.0;
    class function LegacyThemeJson(const Preset: TMarkdownThemePreset): string;
    class function ThemeJsonWithArrayCount(const Key: string; const Count: Integer): string;
    class procedure TrimArray(const Root: TJSONObject; const Key: string; const Count: Integer);
    class function ParseObject(const Json: string): TJSONObject;
    class function PresetNamed(const Name: string): TMarkdownThemePreset;

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
    procedure BlockSpacings_LightPreset_MatchGitHub;

    [Test]
    procedure ThematicBreakSpacing_SurvivesJsonRoundTrip;

    [Test]
    procedure LoadFromJson_WronglyTypedValue_RaisesMarkdownError;

    [Test]
    procedure SaveToJson_DiffAndAlertColors_SurviveRoundTrip;

    [Test]
    [TestCase('Light', 'Light')]
    [TestCase('Dark', 'Dark')]
    procedure LoadFromJson_ThemeSavedBeforeDiffAndAlerts_GetsDefaultsOfItsPreset(const PresetName: string);

    [Test]
    [TestCase('TokenColors', 'codeTokenColors,14')]
    [TestCase('AlertColors', 'alertColors,4')]
    procedure LoadFromJson_ArrayWithWrongCount_RaisesMarkdownError(const Key: string; const Count: Integer);
  end;

implementation

uses
  System.SysUtils,
  System.TypInfo,
  Markdown4D.Defines,
  Markdown4D.Extensions.Alerts,
  Markdown4D.Highlighter.Interfaces,
  Markdown4D.Layout.Interfaces;

// A preset as it was saved before the diff and alert colours existed:
// without their keys, and with thirteen token colours.
class function TMarkdownThemeTests.LegacyThemeJson(const Preset: TMarkdownThemePreset): string;
begin
  const Source = TMarkdownTheme.CreatePreset(Preset);
  try
    const Json = Source.SaveToJson;
    const Root = ParseObject(Json);
    try
      for var Key in KeysAddedWithDiffAndAlerts do
      begin
        const Removed = Root.RemovePair(Key);
        Removed.Free;
      end;

      TrimArray(Root, TokenColorsKey, LegacyTokenColorCount);
      Result := Root.ToJSON;
    finally
      Root.Free;
    end;
  finally
    Source.Free;
  end;
end;

// A light theme whose array under Key holds Count entries instead of its own.
class function TMarkdownThemeTests.ThemeJsonWithArrayCount(const Key: string; const Count: Integer): string;
begin
  const Source = TMarkdownTheme.CreateLight;
  try
    const Json = Source.SaveToJson;
    const Root = ParseObject(Json);
    try
      TrimArray(Root, Key, Count);
      Result := Root.ToJSON;
    finally
      Root.Free;
    end;
  finally
    Source.Free;
  end;
end;

class procedure TMarkdownThemeTests.TrimArray(const Root: TJSONObject; const Key: string; const Count: Integer);
begin
  const Value = Root.GetValue(Key);
  const Entries = Value as TJSONArray;

  for var Index := Entries.Count - 1 downto Count do
  begin
    const Removed = Entries.Remove(Index);
    Removed.Free;
  end;
end;

class function TMarkdownThemeTests.ParseObject(const Json: string): TJSONObject;
begin
  const Parsed = TJSONObject.ParseJSONValue(Json);
  Result := Parsed as TJSONObject;
end;

class function TMarkdownThemeTests.PresetNamed(const Name: string): TMarkdownThemePreset;
begin
  const Ordinal = GetEnumValue(TypeInfo(TMarkdownThemePreset), Name);
  const IsKnownName = (Ordinal >= 0);
  Assert.IsTrue(IsKnownName, Format('Unknown theme preset in test case: %s', [Name]));
  Result := TMarkdownThemePreset(Ordinal);
end;

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

procedure TMarkdownThemeTests.BlockSpacings_LightPreset_MatchGitHub;
begin
  const Theme = TMarkdownTheme.CreateLight;
  try
    Assert.AreEqual(Double(GitHubBlockSpacing), Double(Theme.BlockSpacing), SingleTolerance);
    Assert.AreEqual(Double(GitHubThematicBreakSpacing), Double(Theme.ThematicBreakSpacing), SingleTolerance);

    for var Level := 1 to MaxHeadingLevel do
    begin
      Assert.AreEqual(Double(GitHubHeadingSpacingAbove), Double(Theme.HeadingSpacingAbove[Level]), SingleTolerance);
      Assert.AreEqual(Double(GitHubBlockSpacing), Double(Theme.HeadingSpacingBelow[Level]), SingleTolerance);
    end;
  finally
    Theme.Free;
  end;
end;

procedure TMarkdownThemeTests.ThematicBreakSpacing_SurvivesJsonRoundTrip;
begin
  const Source = TMarkdownTheme.CreateLight;
  try
    Source.ThematicBreakSpacing := OverrideThematicBreakSpacing;
    const SavedJson = Source.SaveToJson;

    const Loaded = TMarkdownTheme.CreateDark;
    try
      Loaded.LoadFromJson(SavedJson);
      Assert.AreEqual(Double(OverrideThematicBreakSpacing), Double(Loaded.ThematicBreakSpacing), SingleTolerance);
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

procedure TMarkdownThemeTests.SaveToJson_DiffAndAlertColors_SurviveRoundTrip;
begin
  const Source = TMarkdownTheme.CreateLight;
  try
    Source.DiffInsertedBackgroundColor := OverrideDiffBackground;
    Source.AlertColors[TMarkdownAlertKind.Tip] := OverrideAlertColor;
    const SavedJson = Source.SaveToJson;

    const Loaded = TMarkdownTheme.CreateDark;
    try
      Loaded.LoadFromJson(SavedJson);

      Assert.AreEqual<TLayoutColor>(OverrideDiffBackground, Loaded.DiffInsertedBackgroundColor);
      Assert.AreEqual<TLayoutColor>(OverrideAlertColor, Loaded.AlertColors[TMarkdownAlertKind.Tip]);
      Assert.AreEqual<TLayoutColor>(Source.AlertColors[TMarkdownAlertKind.Caution],
        Loaded.AlertColors[TMarkdownAlertKind.Caution]);
    finally
      Loaded.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TMarkdownThemeTests.LoadFromJson_ThemeSavedBeforeDiffAndAlerts_GetsDefaultsOfItsPreset(
  const PresetName: string);
begin
  const Preset = PresetNamed(PresetName);
  const Json = LegacyThemeJson(Preset);

  var OtherPreset := TMarkdownThemePreset.Light;
  const IsLight = (Preset = TMarkdownThemePreset.Light);
  if IsLight then
    OtherPreset := TMarkdownThemePreset.Dark;

  const Expected = TMarkdownTheme.CreatePreset(Preset);
  try
    const Loaded = TMarkdownTheme.CreatePreset(OtherPreset);
    try
      Loaded.LoadFromJson(Json);

      Assert.AreEqual<TLayoutColor>(Expected.TokenColors[TSyntaxTokenKind.CDataSection],
        Loaded.TokenColors[TSyntaxTokenKind.CDataSection]);
      Assert.AreEqual<TLayoutColor>(Expected.TokenColors[TSyntaxTokenKind.Inserted],
        Loaded.TokenColors[TSyntaxTokenKind.Inserted]);
      Assert.AreEqual<TLayoutColor>(Expected.DiffDeletedBackgroundColor, Loaded.DiffDeletedBackgroundColor);
      Assert.AreEqual<TLayoutColor>(Expected.AlertColors[TMarkdownAlertKind.Warning],
        Loaded.AlertColors[TMarkdownAlertKind.Warning]);
    finally
      Loaded.Free;
    end;
  finally
    Expected.Free;
  end;
end;

procedure TMarkdownThemeTests.LoadFromJson_ArrayWithWrongCount_RaisesMarkdownError(const Key: string;
  const Count: Integer);
begin
  const Json = ThemeJsonWithArrayCount(Key, Count);

  const Target = TMarkdownTheme.CreateLight;
  try
    Assert.WillRaise(
      procedure
      begin
        Target.LoadFromJson(Json);
      end, EMarkdownError);
  finally
    Target.Free;
  end;
end;

end.
