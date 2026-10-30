unit Markdown4D.Vcl.DirectWriteText;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.D2D1,
  Vcl.Graphics,
  Markdown4D.Defines;

type
  EMarkdownDirectWriteError = class(EMarkdownError);

  /// <summary>
  /// The font a run is measured and drawn in: an installed family, the em height in
  /// device pixels and the styles.
  /// </summary>
  TMarkdownDirectWriteFont = record
    FamilyName: string;
    EmHeight: Single;
    Styles: TFontStyles;
    constructor Create(const FamilyName: string; const EmHeight: Single; const Styles: TFontStyles);
    function Key: string;
  end;

  /// <summary>
  /// A run laid out and placed, waiting to be drawn with the runs around it. Its
  /// positions are in device pixels, so a window origin that changes before it is
  /// drawn does not move it.
  /// </summary>
  TMarkdownDirectWriteRun = record
    Layout: IDWriteTextLayout;
    Origin: TPointF;
    Bounds: TRect;
    Color: TColor;
  end;

  /// <summary>
  /// Measures and draws text through DirectWrite. Unlike GDI, DirectWrite draws colour
  /// fonts such as Segoe UI Emoji in colour, and falls back to another font per
  /// character on its own. Building a text layout costs far more than drawing it, so
  /// the layouts of drawn runs are kept: a control holds one instance for as long as
  /// it lives and hands it to every painter it creates.
  /// </summary>
  TMarkdownDirectWriteText = class
  private
    const
      UnboundedExtent = 100000.0;
      DevicePixelsPerDip = 1.0;
      MaxCachedLayouts = 1024;
      FallbackLocaleName = 'en-us';
      FailedCallMessage = 'DirectWrite call %s failed with %x';
    class var
      FD2DFactory: ID2D1Factory;
      FDWriteFactory: IDWriteFactory;
    var
      FTextFormats: TDictionary<string, IDWriteTextFormat>;
      FLayouts: TDictionary<string, IDWriteTextLayout>;
      FRenderTarget: ID2D1DCRenderTarget;
      FLocaleName: string;
    class function UserLocaleName: string; static;
    class function D2DFactory: ID2D1Factory; static;
    class function DWriteFactory: IDWriteFactory; static;
    class procedure Check(const Status: HResult; const CallName: string); static;
    class function BaselineOf(const Layout: IDWriteTextLayout): Single; static;
    class function MetricsOf(const Layout: IDWriteTextLayout): TDwriteTextMetrics; static;
    class function DeviceOffset(const DC: HDC): TPoint; static;
    class function UnionOf(const Runs: TArray<TMarkdownDirectWriteRun>): TRect; static;
    class function ColorOf(const Color: TColor): TD2D1ColorF; static;
    function TextFormat(const Font: TMarkdownDirectWriteFont): IDWriteTextFormat;
    function CreateTextFormat(const Font: TMarkdownDirectWriteFont): IDWriteTextFormat;
    function Layout(const Text: string; const Font: TMarkdownDirectWriteFont): IDWriteTextLayout;
    function CreateLayout(const Text: string; const Font: TMarkdownDirectWriteFont): IDWriteTextLayout;
    function RenderTarget: ID2D1DCRenderTarget;
    function CreateRenderTarget: ID2D1DCRenderTarget;

  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    /// The advance width of <c>Text</c>, trailing spaces included. The layout is not
    /// kept: a layout holds about 20 KB, and the painter keeps the widths it measured.
    /// </summary>
    function MeasureWidth(const Text: string; const Font: TMarkdownDirectWriteFont): Single;
    /// <summary>
    /// Lays out <c>Text</c> with its baseline at <c>Baseline</c>, both in the logical
    /// coordinates <c>DC</c> has now, ready for <c>DrawRuns</c>.
    /// </summary>
    function PrepareRun(const DC: HDC; const Left, Baseline: Single; const Text: string;
                        const Font: TMarkdownDirectWriteFont; const Color: TColor): TMarkdownDirectWriteRun;
    /// <summary>
    /// Draws <c>Runs</c> on <c>DC</c> in one pass. What <c>DC</c> holds around the text
    /// and its clip region stay as they are.
    /// </summary>
    procedure DrawRuns(const DC: HDC; const Runs: TArray<TMarkdownDirectWriteRun>);
  end;

implementation

uses
  System.Math,
  Winapi.DxgiFormat,
  Markdown4D.Layout.Defaults;

constructor TMarkdownDirectWriteFont.Create(const FamilyName: string; const EmHeight: Single;
                                            const Styles: TFontStyles);
begin
  Self.FamilyName := FamilyName;
  Self.EmHeight := EmHeight;
  Self.Styles := Styles;
end;

function TMarkdownDirectWriteFont.Key: string;
begin
  Result := Format('%s|%g|%d', [FamilyName, EmHeight, Byte(Styles)]);
end;

// The locale picks the glyphs DirectWrite falls back to where languages share
// characters, such as the Chinese or the Japanese form of a Han character.
class function TMarkdownDirectWriteText.UserLocaleName: string;
begin
  var Buffer: array[0..LOCALE_NAME_MAX_LENGTH - 1] of Char;
  const CharCount = GetUserDefaultLocaleName(Buffer, LOCALE_NAME_MAX_LENGTH);
  const HasUserLocale = (CharCount > 0);
  if not HasUserLocale then
    Exit(FallbackLocaleName);

  Result := Buffer;
end;

class function TMarkdownDirectWriteText.D2DFactory: ID2D1Factory;
begin
  if FD2DFactory = nil then
    Check(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, IID_ID2D1Factory, nil, FD2DFactory),
          'D2D1CreateFactory');

  Result := FD2DFactory;
end;

class function TMarkdownDirectWriteText.DWriteFactory: IDWriteFactory;
begin
  if FDWriteFactory = nil then
  begin
    var Factory: IUnknown;
    Check(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, IID_IDWriteFactory, Factory), 'DWriteCreateFactory');
    FDWriteFactory := Factory as IDWriteFactory;
  end;

  Result := FDWriteFactory;
end;

class procedure TMarkdownDirectWriteText.Check(const Status: HResult; const CallName: string);
begin
  if Failed(Status) then
    raise EMarkdownDirectWriteError.CreateFmt(FailedCallMessage, [CallName, Status]);
end;

class function TMarkdownDirectWriteText.BaselineOf(const Layout: IDWriteTextLayout): Single;
begin
  var LineMetrics: TDwriteLineMetrics;
  var LineCount: Cardinal := 0;
  Check(Layout.GetLineMetrics(@LineMetrics, 1, LineCount), 'GetLineMetrics');
  Result := LineMetrics.baseline;
end;

class function TMarkdownDirectWriteText.MetricsOf(const Layout: IDWriteTextLayout): TDwriteTextMetrics;
begin
  Check(Layout.GetMetrics(Result), 'GetMetrics');
end;

constructor TMarkdownDirectWriteText.Create;
begin
  inherited Create;
  FTextFormats := TDictionary<string, IDWriteTextFormat>.Create;
  FLayouts := TDictionary<string, IDWriteTextLayout>.Create;
  FLocaleName := UserLocaleName;
end;

destructor TMarkdownDirectWriteText.Destroy;
begin
  FLayouts.Free;
  FTextFormats.Free;
  inherited Destroy;
end;

function TMarkdownDirectWriteText.MeasureWidth(const Text: string; const Font: TMarkdownDirectWriteFont): Single;
begin
  const TextLayout = CreateLayout(Text, Font);

  Result := MetricsOf(TextLayout).widthIncludingTrailingWhitespace;
end;

function TMarkdownDirectWriteText.PrepareRun(const DC: HDC; const Left, Baseline: Single; const Text: string;
                                             const Font: TMarkdownDirectWriteFont;
                                             const Color: TColor): TMarkdownDirectWriteRun;
begin
  const TextLayout = Layout(Text, Font);
  const Metrics = MetricsOf(TextLayout);

  // A glyph can reach past its advance, an italic one most of all, so the bound
  // area keeps an em of room on every side.
  const Offset = DeviceOffset(DC);
  const DeviceLeft = Left + Offset.X;
  const DeviceTop = Baseline - BaselineOf(TextLayout) + Offset.Y;
  const Margin = Font.EmHeight;

  Result.Layout := TextLayout;
  Result.Origin := TPointF.Create(DeviceLeft, DeviceTop);
  Result.Bounds := TRect.Create(Floor(DeviceLeft - Margin),
                                Floor(DeviceTop - Margin),
                                Ceil(DeviceLeft + Metrics.widthIncludingTrailingWhitespace + Margin),
                                Ceil(DeviceTop + Metrics.height + Margin));
  Result.Color := Color;
end;

// The render target copies the bound area out of DC before drawing and back after,
// so only the pixels the glyphs cover change, and the copy back honours the clip
// region. That copy costs far more than drawing a run, which is why the runs between
// two other drawing operations share one. The target binds in logical coordinates.
procedure TMarkdownDirectWriteText.DrawRuns(const DC: HDC; const Runs: TArray<TMarkdownDirectWriteRun>);
begin
  if Length(Runs) = 0 then
    Exit;

  const DeviceBounds = UnionOf(Runs);
  const Offset = DeviceOffset(DC);
  var LogicalBounds := DeviceBounds;
  LogicalBounds.Offset(-Offset.X, -Offset.Y);

  const Target = RenderTarget;
  Check(Target.BindDC(DC, LogicalBounds), 'BindDC');

  var Brush: ID2D1SolidColorBrush;
  Check(Target.CreateSolidColorBrush(ColorOf(Runs[0].Color), nil, Brush), 'CreateSolidColorBrush');

  Target.BeginDraw;
  for var Run in Runs do
  begin
    Brush.SetColor(ColorOf(Run.Color));
    const Origin = D2D1PointF(Run.Origin.X - DeviceBounds.Left, Run.Origin.Y - DeviceBounds.Top);
    Target.DrawTextLayout(Origin, Run.Layout, Brush, D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT);
  end;
  const Status = Target.EndDraw;

  if Status = D2DERR_RECREATE_TARGET then
    FRenderTarget := nil
  else
    Check(Status, 'EndDraw');
end;

// Where the logical origin of DC lands in device pixels, which a scrolled buffer
// moves through its window origin.
class function TMarkdownDirectWriteText.DeviceOffset(const DC: HDC): TPoint;
begin
  Result := TPoint.Zero;
  LPtoDP(DC, Result, 1);
end;

class function TMarkdownDirectWriteText.UnionOf(const Runs: TArray<TMarkdownDirectWriteRun>): TRect;
begin
  Result := Runs[0].Bounds;
  for var Run in Runs do
  begin
    Result.Union(Run.Bounds);
  end;
end;

class function TMarkdownDirectWriteText.ColorOf(const Color: TColor): TD2D1ColorF;
begin
  const RGB = ColorToRGB(Color);
  Result := D2D1ColorF(GetRValue(RGB) / ColorChannelMax, GetGValue(RGB) / ColorChannelMax,
                       GetBValue(RGB) / ColorChannelMax, 1);
end;

function TMarkdownDirectWriteText.TextFormat(const Font: TMarkdownDirectWriteFont): IDWriteTextFormat;
begin
  const Key = Font.Key;
  if FTextFormats.TryGetValue(Key, Result) then
    Exit;

  Result := CreateTextFormat(Font);
  FTextFormats.Add(Key, Result);
end;

function TMarkdownDirectWriteText.CreateTextFormat(const Font: TMarkdownDirectWriteFont): IDWriteTextFormat;
begin
  var Weight := DWRITE_FONT_WEIGHT_NORMAL;
  if TFontStyle.fsBold in Font.Styles then
    Weight := DWRITE_FONT_WEIGHT_BOLD;

  var Style := DWRITE_FONT_STYLE_NORMAL;
  if TFontStyle.fsItalic in Font.Styles then
    Style := DWRITE_FONT_STYLE_ITALIC;

  Check(DWriteFactory.CreateTextFormat(PChar(Font.FamilyName), nil, Weight, Style, DWRITE_FONT_STRETCH_NORMAL,
                                       Font.EmHeight, PChar(FLocaleName), Result),
        'CreateTextFormat');
  Check(Result.SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP), 'SetWordWrapping');
end;

// The runs on one screen fit in the cache several times over. When scrolling fills it, it
// starts over rather than tracking which layouts were used last.
function TMarkdownDirectWriteText.Layout(const Text: string; const Font: TMarkdownDirectWriteFont): IDWriteTextLayout;
begin
  const Key = Format('%s'#0'%s', [Font.Key, Text]);
  if FLayouts.TryGetValue(Key, Result) then
    Exit;

  if FLayouts.Count >= MaxCachedLayouts then
    FLayouts.Clear;

  Result := CreateLayout(Text, Font);
  FLayouts.Add(Key, Result);
end;

// GDI-natural metrics place glyphs on the pixel grid the way the GDI painter does,
// which keeps widths close to what GDI measures for the same text.
function TMarkdownDirectWriteText.CreateLayout(const Text: string;
                                               const Font: TMarkdownDirectWriteFont): IDWriteTextLayout;
begin
  Check(DWriteFactory.CreateGdiCompatibleTextLayout(PChar(Text), Length(Text), TextFormat(Font), UnboundedExtent,
                                                    UnboundedExtent, DevicePixelsPerDip, nil, True, Result),
        'CreateGdiCompatibleTextLayout');

  var WholeText: TDwriteTextRange;
  WholeText.startPosition := 0;
  WholeText.length := Length(Text);
  if TFontStyle.fsUnderline in Font.Styles then
    Check(Result.SetUnderline(True, WholeText), 'SetUnderline');
  if TFontStyle.fsStrikeOut in Font.Styles then
    Check(Result.SetStrikethrough(True, WholeText), 'SetStrikethrough');
end;

function TMarkdownDirectWriteText.RenderTarget: ID2D1DCRenderTarget;
begin
  if FRenderTarget = nil then
    FRenderTarget := CreateRenderTarget;

  Result := FRenderTarget;
end;

// A software target: it draws small runs, where copying the area to the GPU and
// back would cost more than drawing them.
function TMarkdownDirectWriteText.CreateRenderTarget: ID2D1DCRenderTarget;
begin
  const PixelFormat = D2D1PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_IGNORE);
  const Properties = D2D1RenderTargetProperties(D2D1_RENDER_TARGET_TYPE_SOFTWARE, PixelFormat);
  Check(D2DFactory.CreateDCRenderTarget(Properties, Result), 'CreateDCRenderTarget');
  Result.SetTextAntialiasMode(D2D1_TEXT_ANTIALIAS_MODE_CLEARTYPE);
end;

end.
