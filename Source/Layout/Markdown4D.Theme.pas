unit Markdown4D.Theme;

{$SCOPEDENUMS ON}

interface

uses
  System.JSON,
  Markdown4D.Defines,
  Markdown4D.Highlighter.Interfaces,
  Markdown4D.Layout.Interfaces;

type
  TMarkdownThemePreset = (Light, Dark);

  TMarkdownTheme = class
  private
    const
      MinHeadingLevel = 1;
      HeadingLevelCount = MaxHeadingLevel - MinHeadingLevel + 1;
    type
      THeadingFontArray = array[MinHeadingLevel..MaxHeadingLevel] of TMarkdownFontStyle;
      THeadingSpacingArray = array[MinHeadingLevel..MaxHeadingLevel] of Single;
      TTokenColorArray = array[TSyntaxTokenKind] of TLayoutColor;
      TThemeData = record
        BaseFont: TMarkdownFontStyle;
        CodeFont: TMarkdownFontStyle;
        HeadingFonts: THeadingFontArray;
        HeadingSpacingsAbove: THeadingSpacingArray;
        HeadingSpacingsBelow: THeadingSpacingArray;
        TextColor: TLayoutColor;
        BackgroundColor: TLayoutColor;
        LinkColor: TLayoutColor;
        CodeTextColor: TLayoutColor;
        CodeBackgroundColor: TLayoutColor;
        CodeSpanBackgroundColor: TLayoutColor;
        BlockQuoteBarColor: TLayoutColor;
        BlockQuoteTextColor: TLayoutColor;
        TableHeaderBackgroundColor: TLayoutColor;
        TableBorderColor: TLayoutColor;
        ThematicBreakColor: TLayoutColor;
        ParagraphSpacing: Single;
        ListIndent: Single;
        ListMarkerWidth: Single;
        BlockQuoteBarWidth: Single;
        BlockQuoteInset: Single;
        CodePadding: Single;
        TableCellPadding: Single;
        TableMinColumnWidth: Single;
        TableMaxColumnWidth: Single;
        ImagePlaceholderWidth: Single;
        ImagePlaceholderHeight: Single;
        CheckboxSize: Single;
        ThematicBreakThickness: Single;
        ContentPadding: Single;
        ChartBackgroundColor: TLayoutColor;
        ChartGridLineColor: TLayoutColor;
        ChartTextColor: TLayoutColor;
        ChartPalette: TArray<TLayoutColor>;
        TokenColors: TTokenColorArray;
      end;
    const
      DefaultTextFamilyName = 'Segoe UI';
      DefaultCodeFamilyName = 'Consolas';
      DefaultBaseFontSize = 16.0;
      DefaultHeadingSizes: THeadingSpacingArray = (32, 28, 24, 20, 18, 16);
      DefaultHeadingSpacingsAbove: THeadingSpacingArray = (24, 20, 16, 12, 10, 8);
      DefaultHeadingSpacingsBelow: THeadingSpacingArray = (12, 10, 8, 6, 4, 4);
      DefaultParagraphSpacing = 8.0;
      DefaultListIndent = 24.0;
      DefaultListMarkerWidth = 24.0;
      DefaultBlockQuoteBarWidth = 4.0;
      DefaultBlockQuoteInset = 16.0;
      DefaultCodePadding = 8.0;
      DefaultTableCellPadding = 6.0;
      DefaultTableMinColumnWidth = 40.0;
      DefaultTableMaxColumnWidth = 400.0;
      DefaultImagePlaceholderWidth = 120.0;
      DefaultImagePlaceholderHeight = 90.0;
      DefaultCheckboxSize = 16.0;
      DefaultThematicBreakThickness = 2.0;
      DefaultContentPadding = 16.0;
      LightInkColor = $FF1F2328;
      LightBackgroundColor = $FFFFFFFF;
      LightSurfaceColor = $FFF6F8FA;
      LightBorderColor = $FFD0D7DE;
      DarkInkColor = $FFE6EDF3;
      DarkBackgroundColor = $FF0D1117;
      DarkSurfaceColor = $FF161B22;
      DarkBorderColor = $FF3D444D;
      LightChartPaletteColors: array[0..7] of TLayoutColor = ($FF4E79A7, $FFF28E2B, $FFE15759, $FF76B7B2, $FF59A14F,
        $FFEDC948, $FFB07AA1, $FFFF9DA7);
      DarkChartPaletteColors: array[0..7] of TLayoutColor = ($FF6FA8DC, $FFF6B26B, $FFE06666, $FF76D7C4, $FF93C47D,
        $FFFFD966, $FFC27BA0, $FFF4A7B9);
      LightTokenColors: TTokenColorArray = ($FF1F2328, $FFCF222E, $FF0A3069, $FF0550AE, $FF59636E, $FF8250DF,
        $FF953800, $FF0550AE, $FF116329, $FF0550AE, $FF0A3069, $FF6639BA, $FF57606A);
      DarkTokenColors: TTokenColorArray = ($FFE6EDF3, $FFFF7B72, $FFA5D6FF, $FF79C0FF, $FF8B949E, $FFD2A8FF,
        $FFFFA657, $FF79C0FF, $FF7EE787, $FF79C0FF, $FFA5D6FF, $FFD2A8FF, $FF8B949E);
      TokenColorCount = Ord(High(TSyntaxTokenKind)) + 1;
      BaseFontKey = 'baseFont';
      CodeFontKey = 'codeFont';
      HeadingFontsKey = 'headingFonts';
      HeadingSpacingsAboveKey = 'headingSpacingsAbove';
      HeadingSpacingsBelowKey = 'headingSpacingsBelow';
      TextColorKey = 'textColor';
      BackgroundColorKey = 'backgroundColor';
      LinkColorKey = 'linkColor';
      CodeTextColorKey = 'codeTextColor';
      CodeBackgroundColorKey = 'codeBackgroundColor';
      CodeSpanBackgroundColorKey = 'codeSpanBackground';
      BlockQuoteBarColorKey = 'blockQuoteBarColor';
      BlockQuoteTextColorKey = 'blockQuoteTextColor';
      TableHeaderBackgroundColorKey = 'tableHeaderBackgroundColor';
      TableBorderColorKey = 'tableBorderColor';
      ThematicBreakColorKey = 'thematicBreakColor';
      ParagraphSpacingKey = 'paragraphSpacing';
      ListIndentKey = 'listIndent';
      ListMarkerWidthKey = 'listMarkerWidth';
      BlockQuoteBarWidthKey = 'blockQuoteBarWidth';
      BlockQuoteInsetKey = 'blockQuoteInset';
      CodePaddingKey = 'codePadding';
      TableCellPaddingKey = 'tableCellPadding';
      TableMinColumnWidthKey = 'tableMinColumnWidth';
      TableMaxColumnWidthKey = 'tableMaxColumnWidth';
      ImagePlaceholderWidthKey = 'imagePlaceholderWidth';
      ImagePlaceholderHeightKey = 'imagePlaceholderHeight';
      CheckboxSizeKey = 'checkboxSize';
      ThematicBreakThicknessKey = 'thematicBreakThickness';
      ContentPaddingKey = 'contentPadding';
      ChartBackgroundColorKey = 'chartBackgroundColor';
      ChartGridLineColorKey = 'chartGridLineColor';
      ChartTextColorKey = 'chartTextColor';
      ChartPaletteKey = 'chartPalette';
      CodeTokenColorsKey = 'codeTokenColors';
      FamilyNameKey = 'familyName';
      FontSizeKey = 'size';
      BoldKey = 'bold';
      ItalicKey = 'italic';
      UnderlineKey = 'underline';
      StrikeoutKey = 'strikeout';
    var
      FBaseFont: TMarkdownFontStyle;
      FCodeFont: TMarkdownFontStyle;
      FHeadingFonts: THeadingFontArray;
      FHeadingSpacingsAbove: THeadingSpacingArray;
      FHeadingSpacingsBelow: THeadingSpacingArray;
      FTextColor: TLayoutColor;
      FBackgroundColor: TLayoutColor;
      FLinkColor: TLayoutColor;
      FCodeTextColor: TLayoutColor;
      FCodeBackgroundColor: TLayoutColor;
      FCodeSpanBackgroundColor: TLayoutColor;
      FBlockQuoteBarColor: TLayoutColor;
      FBlockQuoteTextColor: TLayoutColor;
      FTableHeaderBackgroundColor: TLayoutColor;
      FTableBorderColor: TLayoutColor;
      FThematicBreakColor: TLayoutColor;
      FParagraphSpacing: Single;
      FListIndent: Single;
      FListMarkerWidth: Single;
      FBlockQuoteBarWidth: Single;
      FBlockQuoteInset: Single;
      FCodePadding: Single;
      FTableCellPadding: Single;
      FTableMinColumnWidth: Single;
      FTableMaxColumnWidth: Single;
      FImagePlaceholderWidth: Single;
      FImagePlaceholderHeight: Single;
      FCheckboxSize: Single;
      FThematicBreakThickness: Single;
      FContentPadding: Single;
      FChartBackgroundColor: TLayoutColor;
      FChartGridLineColor: TLayoutColor;
      FChartTextColor: TLayoutColor;
      FChartPalette: TArray<TLayoutColor>;
      FTokenColors: TTokenColorArray;
    class function PaletteFrom(const Colors: array of TLayoutColor): TArray<TLayoutColor>;
    function HeadingFontsToJson: TJSONArray;
    class function SpacingsToJson(const Spacings: THeadingSpacingArray): TJSONArray;
    function PaletteToJson: TJSONArray;
    function TokenColorsToJson: TJSONArray;
    class function FontToJson(const Font: TMarkdownFontStyle): TJSONObject;
    class procedure AddColorPair(const Root: TJSONObject; const Name: string; const Value: TLayoutColor);
    class procedure AddSinglePair(const Root: TJSONObject; const Name: string; const Value: Single);
    class function ReadThemeData(const Root: TJSONObject): TThemeData;
    procedure ApplyThemeData(const Data: TThemeData);
    class function ReadHeadingFonts(const Root: TJSONObject): THeadingFontArray;
    class function ReadSpacings(const Root: TJSONObject; const Name: string): THeadingSpacingArray;
    class function ReadPalette(const Root: TJSONObject): TArray<TLayoutColor>;
    class function ReadTokenColors(const Root: TJSONObject): TTokenColorArray;
    class function JsonToFont(const Value: TJSONValue; const Name: string): TMarkdownFontStyle;
    class function ReadColor(const Root: TJSONObject; const Name: string): TLayoutColor;
    class function ReadSingle(const Root: TJSONObject; const Name: string): Single;
    class function RequireArray(const Root: TJSONObject; const Name: string; const ExpectedCount: Integer): TJSONArray;
    class function RequireValue(const Root: TJSONObject; const Name: string): TJSONValue;
    class function RequireNumber(const Value: TJSONValue; const Name: string): TJSONNumber;
    class function RequireString(const Value: TJSONValue; const Name: string): TJSONString;
    class function RequireBool(const Value: TJSONValue; const Name: string): TJSONBool;
    class function RequireObject(const Value: TJSONValue; const Name: string): TJSONObject;
    class function RequireArrayValue(const Value: TJSONValue; const Name: string): TJSONArray;
    function GetHeadingFont(const Level: Integer): TMarkdownFontStyle;
    procedure SetHeadingFont(const Level: Integer; const Value: TMarkdownFontStyle);
    function GetHeadingSpacingAbove(const Level: Integer): Single;
    procedure SetHeadingSpacingAbove(const Level: Integer; const Value: Single);
    function GetHeadingSpacingBelow(const Level: Integer): Single;
    procedure SetHeadingSpacingBelow(const Level: Integer; const Value: Single);
    procedure ValidateHeadingLevel(const Level: Integer);
    function GetTokenColor(const Kind: TSyntaxTokenKind): TLayoutColor;
    procedure SetTokenColor(const Kind: TSyntaxTokenKind; const Value: TLayoutColor);

  public
    class function CreateLight: TMarkdownTheme;
    class function CreateDark: TMarkdownTheme;
    class function CreatePreset(const Preset: TMarkdownThemePreset): TMarkdownTheme;
    constructor Create;
    function SaveToJson: string;
    procedure LoadFromJson(const Json: string);
    property BaseFont: TMarkdownFontStyle read FBaseFont write FBaseFont;
    property CodeFont: TMarkdownFontStyle read FCodeFont write FCodeFont;
    property HeadingFonts[const Level: Integer]: TMarkdownFontStyle read GetHeadingFont write SetHeadingFont;
    property HeadingSpacingAbove[const Level: Integer]: Single read GetHeadingSpacingAbove write SetHeadingSpacingAbove;
    property HeadingSpacingBelow[const Level: Integer]: Single read GetHeadingSpacingBelow write SetHeadingSpacingBelow;
    property TextColor: TLayoutColor read FTextColor write FTextColor;
    property BackgroundColor: TLayoutColor read FBackgroundColor write FBackgroundColor;
    property LinkColor: TLayoutColor read FLinkColor write FLinkColor;
    property CodeTextColor: TLayoutColor read FCodeTextColor write FCodeTextColor;
    property CodeBackgroundColor: TLayoutColor read FCodeBackgroundColor write FCodeBackgroundColor;
    property CodeSpanBackgroundColor: TLayoutColor read FCodeSpanBackgroundColor write FCodeSpanBackgroundColor;
    property BlockQuoteBarColor: TLayoutColor read FBlockQuoteBarColor write FBlockQuoteBarColor;
    property BlockQuoteTextColor: TLayoutColor read FBlockQuoteTextColor write FBlockQuoteTextColor;
    property TableHeaderBackgroundColor: TLayoutColor read FTableHeaderBackgroundColor write FTableHeaderBackgroundColor;
    property TableBorderColor: TLayoutColor read FTableBorderColor write FTableBorderColor;
    property ThematicBreakColor: TLayoutColor read FThematicBreakColor write FThematicBreakColor;
    property ParagraphSpacing: Single read FParagraphSpacing write FParagraphSpacing;
    property ListIndent: Single read FListIndent write FListIndent;
    property ListMarkerWidth: Single read FListMarkerWidth write FListMarkerWidth;
    property BlockQuoteBarWidth: Single read FBlockQuoteBarWidth write FBlockQuoteBarWidth;
    property BlockQuoteInset: Single read FBlockQuoteInset write FBlockQuoteInset;
    property CodePadding: Single read FCodePadding write FCodePadding;
    property TableCellPadding: Single read FTableCellPadding write FTableCellPadding;
    property TableMinColumnWidth: Single read FTableMinColumnWidth write FTableMinColumnWidth;
    property TableMaxColumnWidth: Single read FTableMaxColumnWidth write FTableMaxColumnWidth;
    property ImagePlaceholderWidth: Single read FImagePlaceholderWidth write FImagePlaceholderWidth;
    property ImagePlaceholderHeight: Single read FImagePlaceholderHeight write FImagePlaceholderHeight;
    property CheckboxSize: Single read FCheckboxSize write FCheckboxSize;
    property ThematicBreakThickness: Single read FThematicBreakThickness write FThematicBreakThickness;
    property ContentPadding: Single read FContentPadding write FContentPadding;
    property ChartBackgroundColor: TLayoutColor read FChartBackgroundColor write FChartBackgroundColor;
    property ChartGridLineColor: TLayoutColor read FChartGridLineColor write FChartGridLineColor;
    property ChartTextColor: TLayoutColor read FChartTextColor write FChartTextColor;
    property ChartPalette: TArray<TLayoutColor> read FChartPalette write FChartPalette;
    property TokenColors[const Kind: TSyntaxTokenKind]: TLayoutColor read GetTokenColor write SetTokenColor;
  end;

implementation

uses
  System.Generics.Collections;

class function TMarkdownTheme.CreateLight: TMarkdownTheme;
begin
  Result := TMarkdownTheme.Create;
end;

class function TMarkdownTheme.CreatePreset(const Preset: TMarkdownThemePreset): TMarkdownTheme;
begin
  case Preset of
    TMarkdownThemePreset.Dark:
      Result := CreateDark;
  else
    Result := CreateLight;
  end;
end;

class function TMarkdownTheme.CreateDark: TMarkdownTheme;
begin
  Result := TMarkdownTheme.Create;

  Result.FTextColor := DarkInkColor;
  Result.FBackgroundColor := DarkBackgroundColor;
  Result.FLinkColor := $FF4493F8;
  Result.FCodeTextColor := DarkInkColor;
  Result.FCodeBackgroundColor := DarkSurfaceColor;
  Result.FCodeSpanBackgroundColor := DarkSurfaceColor;
  Result.FBlockQuoteBarColor := DarkBorderColor;
  Result.FBlockQuoteTextColor := $FF9198A1;
  Result.FTableHeaderBackgroundColor := DarkSurfaceColor;
  Result.FTableBorderColor := DarkBorderColor;
  Result.FThematicBreakColor := DarkBorderColor;
  Result.FChartBackgroundColor := DarkBackgroundColor;
  Result.FChartGridLineColor := $FF30363D;
  Result.FChartTextColor := $FFC9D1D9;
  Result.FChartPalette := PaletteFrom(DarkChartPaletteColors);
  Result.FTokenColors := DarkTokenColors;
end;

constructor TMarkdownTheme.Create;
begin
  inherited Create;

  FBaseFont := TMarkdownFontStyle.Create(DefaultTextFamilyName, DefaultBaseFontSize);
  FCodeFont := TMarkdownFontStyle.Create(DefaultCodeFamilyName, DefaultBaseFontSize);

  for var Level := MinHeadingLevel to MaxHeadingLevel do
  begin
    FHeadingFonts[Level] := TMarkdownFontStyle.Create(DefaultTextFamilyName, DefaultHeadingSizes[Level], True);
    FHeadingSpacingsAbove[Level] := DefaultHeadingSpacingsAbove[Level];
    FHeadingSpacingsBelow[Level] := DefaultHeadingSpacingsBelow[Level];
  end;

  FParagraphSpacing := DefaultParagraphSpacing;
  FListIndent := DefaultListIndent;
  FListMarkerWidth := DefaultListMarkerWidth;
  FBlockQuoteBarWidth := DefaultBlockQuoteBarWidth;
  FBlockQuoteInset := DefaultBlockQuoteInset;
  FCodePadding := DefaultCodePadding;
  FTableCellPadding := DefaultTableCellPadding;
  FTableMinColumnWidth := DefaultTableMinColumnWidth;
  FTableMaxColumnWidth := DefaultTableMaxColumnWidth;
  FImagePlaceholderWidth := DefaultImagePlaceholderWidth;
  FImagePlaceholderHeight := DefaultImagePlaceholderHeight;
  FCheckboxSize := DefaultCheckboxSize;
  FThematicBreakThickness := DefaultThematicBreakThickness;
  FContentPadding := DefaultContentPadding;

  FTextColor := LightInkColor;
  FBackgroundColor := LightBackgroundColor;
  FLinkColor := $FF0969DA;
  FCodeTextColor := LightInkColor;
  FCodeBackgroundColor := LightSurfaceColor;
  FCodeSpanBackgroundColor := LightSurfaceColor;
  FBlockQuoteBarColor := LightBorderColor;
  FBlockQuoteTextColor := $FF59636E;
  FTableHeaderBackgroundColor := LightSurfaceColor;
  FTableBorderColor := LightBorderColor;
  FThematicBreakColor := LightBorderColor;
  FChartBackgroundColor := LightBackgroundColor;
  FChartGridLineColor := $FFE5E7EB;
  FChartTextColor := $FF374151;
  FChartPalette := PaletteFrom(LightChartPaletteColors);
  FTokenColors := LightTokenColors;
end;

class function TMarkdownTheme.PaletteFrom(const Colors: array of TLayoutColor): TArray<TLayoutColor>;
begin
  SetLength(Result, Length(Colors));

  for var Index := 0 to High(Colors) do
  begin
    Result[Index] := Colors[Index];
  end;
end;

function TMarkdownTheme.SaveToJson: string;
begin
  const Root = TJSONObject.Create;
  try
    Root.AddPair(BaseFontKey, FontToJson(FBaseFont));
    Root.AddPair(CodeFontKey, FontToJson(FCodeFont));
    Root.AddPair(HeadingFontsKey, HeadingFontsToJson);
    Root.AddPair(HeadingSpacingsAboveKey, SpacingsToJson(FHeadingSpacingsAbove));
    Root.AddPair(HeadingSpacingsBelowKey, SpacingsToJson(FHeadingSpacingsBelow));

    AddColorPair(Root, TextColorKey, FTextColor);
    AddColorPair(Root, BackgroundColorKey, FBackgroundColor);
    AddColorPair(Root, LinkColorKey, FLinkColor);
    AddColorPair(Root, CodeTextColorKey, FCodeTextColor);
    AddColorPair(Root, CodeBackgroundColorKey, FCodeBackgroundColor);
    AddColorPair(Root, CodeSpanBackgroundColorKey, FCodeSpanBackgroundColor);
    AddColorPair(Root, BlockQuoteBarColorKey, FBlockQuoteBarColor);
    AddColorPair(Root, BlockQuoteTextColorKey, FBlockQuoteTextColor);
    AddColorPair(Root, TableHeaderBackgroundColorKey, FTableHeaderBackgroundColor);
    AddColorPair(Root, TableBorderColorKey, FTableBorderColor);
    AddColorPair(Root, ThematicBreakColorKey, FThematicBreakColor);

    AddSinglePair(Root, ParagraphSpacingKey, FParagraphSpacing);
    AddSinglePair(Root, ListIndentKey, FListIndent);
    AddSinglePair(Root, ListMarkerWidthKey, FListMarkerWidth);
    AddSinglePair(Root, BlockQuoteBarWidthKey, FBlockQuoteBarWidth);
    AddSinglePair(Root, BlockQuoteInsetKey, FBlockQuoteInset);
    AddSinglePair(Root, CodePaddingKey, FCodePadding);
    AddSinglePair(Root, TableCellPaddingKey, FTableCellPadding);
    AddSinglePair(Root, TableMinColumnWidthKey, FTableMinColumnWidth);
    AddSinglePair(Root, TableMaxColumnWidthKey, FTableMaxColumnWidth);
    AddSinglePair(Root, ImagePlaceholderWidthKey, FImagePlaceholderWidth);
    AddSinglePair(Root, ImagePlaceholderHeightKey, FImagePlaceholderHeight);
    AddSinglePair(Root, CheckboxSizeKey, FCheckboxSize);
    AddSinglePair(Root, ThematicBreakThicknessKey, FThematicBreakThickness);
    AddSinglePair(Root, ContentPaddingKey, FContentPadding);

    AddColorPair(Root, ChartBackgroundColorKey, FChartBackgroundColor);
    AddColorPair(Root, ChartGridLineColorKey, FChartGridLineColor);
    AddColorPair(Root, ChartTextColorKey, FChartTextColor);
    Root.AddPair(ChartPaletteKey, PaletteToJson);
    Root.AddPair(CodeTokenColorsKey, TokenColorsToJson);

    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TMarkdownTheme.HeadingFontsToJson: TJSONArray;
begin
  Result := TJSONArray.Create;

  for var Level := MinHeadingLevel to MaxHeadingLevel do
  begin
    Result.AddElement(FontToJson(FHeadingFonts[Level]));
  end;
end;

class function TMarkdownTheme.SpacingsToJson(const Spacings: THeadingSpacingArray): TJSONArray;
begin
  Result := TJSONArray.Create;

  for var Level := MinHeadingLevel to MaxHeadingLevel do
  begin
    Result.AddElement(TJSONNumber.Create(Double(Spacings[Level])));
  end;
end;

function TMarkdownTheme.PaletteToJson: TJSONArray;
begin
  Result := TJSONArray.Create;

  for var Color in FChartPalette do
  begin
    Result.AddElement(TJSONNumber.Create(Int64(Color)));
  end;
end;

function TMarkdownTheme.TokenColorsToJson: TJSONArray;
begin
  Result := TJSONArray.Create;

  for var Kind := Low(TSyntaxTokenKind) to High(TSyntaxTokenKind) do
  begin
    Result.AddElement(TJSONNumber.Create(Int64(FTokenColors[Kind])));
  end;
end;

class function TMarkdownTheme.FontToJson(const Font: TMarkdownFontStyle): TJSONObject;
begin
  Result := TJSONObject.Create;

  Result.AddPair(FamilyNameKey, Font.FamilyName);
  Result.AddPair(FontSizeKey, TJSONNumber.Create(Double(Font.Size)));
  Result.AddPair(BoldKey, TJSONBool.Create(Font.Bold));
  Result.AddPair(ItalicKey, TJSONBool.Create(Font.Italic));
  Result.AddPair(UnderlineKey, TJSONBool.Create(Font.Underline));
  Result.AddPair(StrikeoutKey, TJSONBool.Create(Font.Strikeout));
end;

class procedure TMarkdownTheme.AddColorPair(const Root: TJSONObject; const Name: string; const Value: TLayoutColor);
begin
  Root.AddPair(Name, TJSONNumber.Create(Int64(Value)));
end;

class procedure TMarkdownTheme.AddSinglePair(const Root: TJSONObject; const Name: string; const Value: Single);
begin
  Root.AddPair(Name, TJSONNumber.Create(Double(Value)));
end;

procedure TMarkdownTheme.LoadFromJson(const Json: string);
begin
  const Parsed = TJSONObject.ParseJSONValue(Json);
  if Parsed = nil then
    raise EMarkdownError.Create('Theme JSON could not be parsed');

  try
    const HasRootObject = (Parsed is TJSONObject);
    if not HasRootObject then
      raise EMarkdownError.Create('Theme JSON must contain a single object');

    const Root = TJSONObject(Parsed);
    const Data = ReadThemeData(Root);
    ApplyThemeData(Data);
  finally
    Parsed.Free;
  end;
end;

class function TMarkdownTheme.ReadThemeData(const Root: TJSONObject): TThemeData;
begin
  Result := Default(TThemeData);

  Result.BaseFont := JsonToFont(RequireValue(Root, BaseFontKey), BaseFontKey);
  Result.CodeFont := JsonToFont(RequireValue(Root, CodeFontKey), CodeFontKey);
  Result.HeadingFonts := ReadHeadingFonts(Root);
  Result.HeadingSpacingsAbove := ReadSpacings(Root, HeadingSpacingsAboveKey);
  Result.HeadingSpacingsBelow := ReadSpacings(Root, HeadingSpacingsBelowKey);

  Result.TextColor := ReadColor(Root, TextColorKey);
  Result.BackgroundColor := ReadColor(Root, BackgroundColorKey);
  Result.LinkColor := ReadColor(Root, LinkColorKey);
  Result.CodeTextColor := ReadColor(Root, CodeTextColorKey);
  Result.CodeBackgroundColor := ReadColor(Root, CodeBackgroundColorKey);
  Result.CodeSpanBackgroundColor := ReadColor(Root, CodeSpanBackgroundColorKey);
  Result.BlockQuoteBarColor := ReadColor(Root, BlockQuoteBarColorKey);
  Result.BlockQuoteTextColor := ReadColor(Root, BlockQuoteTextColorKey);
  Result.TableHeaderBackgroundColor := ReadColor(Root, TableHeaderBackgroundColorKey);
  Result.TableBorderColor := ReadColor(Root, TableBorderColorKey);
  Result.ThematicBreakColor := ReadColor(Root, ThematicBreakColorKey);

  Result.ParagraphSpacing := ReadSingle(Root, ParagraphSpacingKey);
  Result.ListIndent := ReadSingle(Root, ListIndentKey);
  Result.ListMarkerWidth := ReadSingle(Root, ListMarkerWidthKey);
  Result.BlockQuoteBarWidth := ReadSingle(Root, BlockQuoteBarWidthKey);
  Result.BlockQuoteInset := ReadSingle(Root, BlockQuoteInsetKey);
  Result.CodePadding := ReadSingle(Root, CodePaddingKey);
  Result.TableCellPadding := ReadSingle(Root, TableCellPaddingKey);
  Result.TableMinColumnWidth := ReadSingle(Root, TableMinColumnWidthKey);
  Result.TableMaxColumnWidth := ReadSingle(Root, TableMaxColumnWidthKey);
  Result.ImagePlaceholderWidth := ReadSingle(Root, ImagePlaceholderWidthKey);
  Result.ImagePlaceholderHeight := ReadSingle(Root, ImagePlaceholderHeightKey);
  Result.CheckboxSize := ReadSingle(Root, CheckboxSizeKey);
  Result.ThematicBreakThickness := ReadSingle(Root, ThematicBreakThicknessKey);
  Result.ContentPadding := ReadSingle(Root, ContentPaddingKey);

  Result.ChartBackgroundColor := ReadColor(Root, ChartBackgroundColorKey);
  Result.ChartGridLineColor := ReadColor(Root, ChartGridLineColorKey);
  Result.ChartTextColor := ReadColor(Root, ChartTextColorKey);
  Result.ChartPalette := ReadPalette(Root);
  Result.TokenColors := ReadTokenColors(Root);
end;

procedure TMarkdownTheme.ApplyThemeData(const Data: TThemeData);
begin
  FBaseFont := Data.BaseFont;
  FCodeFont := Data.CodeFont;
  FHeadingFonts := Data.HeadingFonts;
  FHeadingSpacingsAbove := Data.HeadingSpacingsAbove;
  FHeadingSpacingsBelow := Data.HeadingSpacingsBelow;

  FTextColor := Data.TextColor;
  FBackgroundColor := Data.BackgroundColor;
  FLinkColor := Data.LinkColor;
  FCodeTextColor := Data.CodeTextColor;
  FCodeBackgroundColor := Data.CodeBackgroundColor;
  FCodeSpanBackgroundColor := Data.CodeSpanBackgroundColor;
  FBlockQuoteBarColor := Data.BlockQuoteBarColor;
  FBlockQuoteTextColor := Data.BlockQuoteTextColor;
  FTableHeaderBackgroundColor := Data.TableHeaderBackgroundColor;
  FTableBorderColor := Data.TableBorderColor;
  FThematicBreakColor := Data.ThematicBreakColor;

  FParagraphSpacing := Data.ParagraphSpacing;
  FListIndent := Data.ListIndent;
  FListMarkerWidth := Data.ListMarkerWidth;
  FBlockQuoteBarWidth := Data.BlockQuoteBarWidth;
  FBlockQuoteInset := Data.BlockQuoteInset;
  FCodePadding := Data.CodePadding;
  FTableCellPadding := Data.TableCellPadding;
  FTableMinColumnWidth := Data.TableMinColumnWidth;
  FTableMaxColumnWidth := Data.TableMaxColumnWidth;
  FImagePlaceholderWidth := Data.ImagePlaceholderWidth;
  FImagePlaceholderHeight := Data.ImagePlaceholderHeight;
  FCheckboxSize := Data.CheckboxSize;
  FThematicBreakThickness := Data.ThematicBreakThickness;
  FContentPadding := Data.ContentPadding;

  FChartBackgroundColor := Data.ChartBackgroundColor;
  FChartGridLineColor := Data.ChartGridLineColor;
  FChartTextColor := Data.ChartTextColor;
  FChartPalette := Data.ChartPalette;
  FTokenColors := Data.TokenColors;
end;

class function TMarkdownTheme.ReadHeadingFonts(const Root: TJSONObject): THeadingFontArray;
begin
  const Fonts = RequireArray(Root, HeadingFontsKey, HeadingLevelCount);

  for var Level := MinHeadingLevel to MaxHeadingLevel do
  begin
    Result[Level] := JsonToFont(Fonts.Items[Level - MinHeadingLevel], HeadingFontsKey);
  end;
end;

class function TMarkdownTheme.ReadSpacings(const Root: TJSONObject; const Name: string): THeadingSpacingArray;
begin
  const Spacings = RequireArray(Root, Name, HeadingLevelCount);

  for var Level := MinHeadingLevel to MaxHeadingLevel do
  begin
    Result[Level] := Single(RequireNumber(Spacings.Items[Level - MinHeadingLevel], Name).AsDouble);
  end;
end;

class function TMarkdownTheme.ReadPalette(const Root: TJSONObject): TArray<TLayoutColor>;
begin
  const Colors = RequireArray(Root, ChartPaletteKey, -1);
  SetLength(Result, Colors.Count);

  for var Index := 0 to Colors.Count - 1 do
  begin
    Result[Index] := TLayoutColor(RequireNumber(Colors.Items[Index], ChartPaletteKey).AsInt64);
  end;
end;

class function TMarkdownTheme.ReadTokenColors(const Root: TJSONObject): TTokenColorArray;
begin
  const Colors = RequireArray(Root, CodeTokenColorsKey, TokenColorCount);

  for var Kind := Low(TSyntaxTokenKind) to High(TSyntaxTokenKind) do
  begin
    Result[Kind] := TLayoutColor(RequireNumber(Colors.Items[Ord(Kind)], CodeTokenColorsKey).AsInt64);
  end;
end;

class function TMarkdownTheme.JsonToFont(const Value: TJSONValue; const Name: string): TMarkdownFontStyle;
begin
  const FontObject = RequireObject(Value, Name);

  Result.FamilyName := RequireString(RequireValue(FontObject, FamilyNameKey), FamilyNameKey).Value;
  Result.Size := Single(RequireNumber(RequireValue(FontObject, FontSizeKey), FontSizeKey).AsDouble);
  Result.Bold := RequireBool(RequireValue(FontObject, BoldKey), BoldKey).AsBoolean;
  Result.Italic := RequireBool(RequireValue(FontObject, ItalicKey), ItalicKey).AsBoolean;
  Result.Underline := RequireBool(RequireValue(FontObject, UnderlineKey), UnderlineKey).AsBoolean;
  Result.Strikeout := RequireBool(RequireValue(FontObject, StrikeoutKey), StrikeoutKey).AsBoolean;
end;

class function TMarkdownTheme.ReadColor(const Root: TJSONObject; const Name: string): TLayoutColor;
begin
  Result := TLayoutColor(RequireNumber(RequireValue(Root, Name), Name).AsInt64);
end;

class function TMarkdownTheme.ReadSingle(const Root: TJSONObject; const Name: string): Single;
begin
  Result := Single(RequireNumber(RequireValue(Root, Name), Name).AsDouble);
end;

class function TMarkdownTheme.RequireArray(const Root: TJSONObject; const Name: string;
  const ExpectedCount: Integer): TJSONArray;
begin
  Result := RequireArrayValue(RequireValue(Root, Name), Name);

  const HasExpectedCount = (ExpectedCount < 0) or (Result.Count = ExpectedCount);
  if not HasExpectedCount then
    raise EMarkdownError.CreateFmt('Theme JSON array "%s" must contain %d entries', [Name, ExpectedCount]);
end;

class function TMarkdownTheme.RequireValue(const Root: TJSONObject; const Name: string): TJSONValue;
begin
  Result := Root.GetValue(Name);

  if Result = nil then
    raise EMarkdownError.CreateFmt('Theme JSON is missing "%s"', [Name]);
end;

class function TMarkdownTheme.RequireNumber(const Value: TJSONValue; const Name: string): TJSONNumber;
begin
  const IsNumber = (Value is TJSONNumber);
  if not IsNumber then
    raise EMarkdownError.CreateFmt('Theme JSON value "%s" must be a number', [Name]);

  Result := TJSONNumber(Value);
end;

class function TMarkdownTheme.RequireString(const Value: TJSONValue; const Name: string): TJSONString;
begin
  const IsString = (Value is TJSONString);
  if not IsString then
    raise EMarkdownError.CreateFmt('Theme JSON value "%s" must be a string', [Name]);

  Result := TJSONString(Value);
end;

class function TMarkdownTheme.RequireBool(const Value: TJSONValue; const Name: string): TJSONBool;
begin
  const IsBool = (Value is TJSONBool);
  if not IsBool then
    raise EMarkdownError.CreateFmt('Theme JSON value "%s" must be a boolean', [Name]);

  Result := TJSONBool(Value);
end;

class function TMarkdownTheme.RequireObject(const Value: TJSONValue; const Name: string): TJSONObject;
begin
  const IsObject = (Value is TJSONObject);
  if not IsObject then
    raise EMarkdownError.CreateFmt('Theme JSON value "%s" must be an object', [Name]);

  Result := TJSONObject(Value);
end;

class function TMarkdownTheme.RequireArrayValue(const Value: TJSONValue; const Name: string): TJSONArray;
begin
  const IsArray = (Value is TJSONArray);
  if not IsArray then
    raise EMarkdownError.CreateFmt('Theme JSON value "%s" must be an array', [Name]);

  Result := TJSONArray(Value);
end;

function TMarkdownTheme.GetHeadingFont(const Level: Integer): TMarkdownFontStyle;
begin
  ValidateHeadingLevel(Level);

  Result := FHeadingFonts[Level];
end;

procedure TMarkdownTheme.SetHeadingFont(const Level: Integer; const Value: TMarkdownFontStyle);
begin
  ValidateHeadingLevel(Level);

  FHeadingFonts[Level] := Value;
end;

function TMarkdownTheme.GetHeadingSpacingAbove(const Level: Integer): Single;
begin
  ValidateHeadingLevel(Level);

  Result := FHeadingSpacingsAbove[Level];
end;

procedure TMarkdownTheme.SetHeadingSpacingAbove(const Level: Integer; const Value: Single);
begin
  ValidateHeadingLevel(Level);

  FHeadingSpacingsAbove[Level] := Value;
end;

function TMarkdownTheme.GetHeadingSpacingBelow(const Level: Integer): Single;
begin
  ValidateHeadingLevel(Level);

  Result := FHeadingSpacingsBelow[Level];
end;

procedure TMarkdownTheme.SetHeadingSpacingBelow(const Level: Integer; const Value: Single);
begin
  ValidateHeadingLevel(Level);

  FHeadingSpacingsBelow[Level] := Value;
end;

procedure TMarkdownTheme.ValidateHeadingLevel(const Level: Integer);
begin
  const IsValidLevel = (Level >= MinHeadingLevel) and (Level <= MaxHeadingLevel);
  if not IsValidLevel then
    raise EMarkdownError.CreateFmt('Heading level %d is out of range %d..%d', [Level, MinHeadingLevel, MaxHeadingLevel]);
end;

function TMarkdownTheme.GetTokenColor(const Kind: TSyntaxTokenKind): TLayoutColor;
begin
  Result := FTokenColors[Kind];
end;

procedure TMarkdownTheme.SetTokenColor(const Kind: TSyntaxTokenKind; const Value: TLayoutColor);
begin
  FTokenColors[Kind] := Value;
end;

end.
