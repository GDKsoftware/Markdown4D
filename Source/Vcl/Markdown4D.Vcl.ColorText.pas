unit Markdown4D.Vcl.ColorText;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.D2D1,
  Markdown4D.Image.Rasterizer,
  Markdown4D.Layout.Interfaces;

type
  // A rendered emoji stretch: premultiplied pixels plus the point inside them
  // where the pen starts on the baseline, so the painter can line it up with
  // the GDI text around it.
  TMarkdownVclColorTextImage = record
    Raster: TMarkdownPixelRaster;
    OriginX: Integer;
    BaselineY: Integer;
  end;

  // Measures and draws emoji through DirectWrite and Direct2D. GDI only draws
  // the monochrome outlines of Segoe UI Emoji; Direct2D with colour fonts
  // enabled draws its colour layers. Each stretch is rendered into its own
  // transparent buffer that the painter blends onto the canvas like any other
  // raster, so the canvas' window origin and clip region keep applying.
  TMarkdownVclColorText = class
  private
    const
      EmojiFamilyName = 'Segoe UI Emoji';
      FormatLocaleName = 'en-us';
      LayoutExtent = 100000.0;
      DevicePixelsPerInch = 96.0;
      GlyphMargin = 2;
      ColorChannelScale = 255.0;
      WidthKeyFormat = '%.2f|%s';
    var
      FWriteFactory: IDWriteFactory;
      FDrawFactory: ID2D1Factory;
      FFormats: TDictionary<Single, IDWriteTextFormat>;
      FWidths: TDictionary<string, Single>;
    function IsAvailable: Boolean;
    function TryGetFormat(const EmSize: Single; out TextFormat: IDWriteTextFormat): Boolean;
    function TryCreateLayout(const Text: string; const EmSize: Single; out Layout: IDWriteTextLayout): Boolean;
    function TryGetBaseline(const Layout: IDWriteTextLayout; out Baseline: Single): Boolean;
    function TryDrawInto(const Bits: Pointer; const Width, Height: Integer; const Layout: IDWriteTextLayout;
      const Color: TLayoutColor): Boolean;
    function TryDrawOnDC(const DC: HDC; const Width, Height: Integer; const Layout: IDWriteTextLayout;
      const Color: TLayoutColor): Boolean;
    class function BitmapInfoOf(const Width, Height: Integer): TBitmapInfo;
    class function BrushColorOf(const Color: TLayoutColor): TD2D1ColorF;

  public
    constructor Create;
    destructor Destroy; override;
    function TryMeasureWidth(const Text: string; const EmSize: Single; out Width: Single): Boolean;
    function TryRender(const Text: string; const EmSize: Single; const Color: TLayoutColor;
      out Image: TMarkdownVclColorTextImage): Boolean;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Winapi.DxgiFormat;

constructor TMarkdownVclColorText.Create;
begin
  inherited Create;

  FFormats := TDictionary<Single, IDWriteTextFormat>.Create;
  FWidths := TDictionary<string, Single>.Create;

  var WriteFactory: IUnknown;
  if Succeeded(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, IDWriteFactory, WriteFactory)) then
    FWriteFactory := WriteFactory as IDWriteFactory;

  if not Succeeded(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, ID2D1Factory, nil, FDrawFactory)) then
    FDrawFactory := nil;
end;

destructor TMarkdownVclColorText.Destroy;
begin
  FWidths.Free;
  FFormats.Free;

  inherited Destroy;
end;

function TMarkdownVclColorText.IsAvailable: Boolean;
begin
  Result := Assigned(FWriteFactory) and Assigned(FDrawFactory);
end;

function TMarkdownVclColorText.TryMeasureWidth(const Text: string; const EmSize: Single; out Width: Single): Boolean;
begin
  const Key = Format(WidthKeyFormat, [EmSize, Text]);
  if FWidths.TryGetValue(Key, Width) then
    Exit(True);

  var Layout: IDWriteTextLayout;
  if not TryCreateLayout(Text, EmSize, Layout) then
    Exit(False);

  var Metrics: TDWriteTextMetrics;
  if not Succeeded(Layout.GetMetrics(Metrics)) then
    Exit(False);

  Width := Metrics.widthIncludingTrailingWhitespace;
  FWidths.Add(Key, Width);
  Result := True;
end;

function TMarkdownVclColorText.TryRender(const Text: string; const EmSize: Single; const Color: TLayoutColor;
  out Image: TMarkdownVclColorTextImage): Boolean;
begin
  Image := Default(TMarkdownVclColorTextImage);

  var Layout: IDWriteTextLayout;
  if not TryCreateLayout(Text, EmSize, Layout) then
    Exit(False);

  var Metrics: TDWriteTextMetrics;
  var Baseline: Single;
  const HasMetrics = (Succeeded(Layout.GetMetrics(Metrics)) and TryGetBaseline(Layout, Baseline));
  if not HasMetrics then
    Exit(False);

  const Width = Ceil(Metrics.widthIncludingTrailingWhitespace) + (2 * GlyphMargin);
  const Height = Ceil(Metrics.height) + (2 * GlyphMargin);
  var Raster := TMarkdownPixelRaster.Create(Width, Height);
  if not TryDrawInto(@Raster.Pixels[0], Width, Height, Layout, Color) then
    Exit(False);

  Image.Raster := Raster;
  Image.OriginX := GlyphMargin;
  Image.BaselineY := GlyphMargin + Round(Baseline);
  Result := True;
end;

function TMarkdownVclColorText.TryGetFormat(const EmSize: Single; out TextFormat: IDWriteTextFormat): Boolean;
begin
  if FFormats.TryGetValue(EmSize, TextFormat) then
    Exit(True);

  const Created = FWriteFactory.CreateTextFormat(EmojiFamilyName, nil, DWRITE_FONT_WEIGHT_NORMAL,
    DWRITE_FONT_STYLE_NORMAL, DWRITE_FONT_STRETCH_NORMAL, EmSize, FormatLocaleName, TextFormat);
  if not Succeeded(Created) then
    Exit(False);

  TextFormat.SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP);
  FFormats.Add(EmSize, TextFormat);
  Result := True;
end;

function TMarkdownVclColorText.TryCreateLayout(const Text: string; const EmSize: Single;
  out Layout: IDWriteTextLayout): Boolean;
begin
  const CanLayout = (IsAvailable and (Text <> '') and (EmSize > 0));
  if not CanLayout then
    Exit(False);

  var TextFormat: IDWriteTextFormat;
  if not TryGetFormat(EmSize, TextFormat) then
    Exit(False);

  const Created = FWriteFactory.CreateTextLayout(PChar(Text), Length(Text), TextFormat, LayoutExtent, LayoutExtent,
    Layout);
  Result := Succeeded(Created);
end;

function TMarkdownVclColorText.TryGetBaseline(const Layout: IDWriteTextLayout; out Baseline: Single): Boolean;
begin
  var LineMetrics: TDWriteLineMetrics;
  var LineCount: Cardinal := 0;
  const Queried = Layout.GetLineMetrics(@LineMetrics, 1, LineCount);
  Result := Succeeded(Queried) and (LineCount >= 1);
  if Result then
    Baseline := LineMetrics.baseline;
end;

// Direct2D draws into a top-down 32-bit DIB section selected into a memory DC;
// the DIB starts fully transparent, so what comes back is the emoji alone,
// premultiplied, ready for AlphaBlend.
function TMarkdownVclColorText.TryDrawInto(const Bits: Pointer; const Width, Height: Integer;
  const Layout: IDWriteTextLayout; const Color: TLayoutColor): Boolean;
begin
  const Info = BitmapInfoOf(Width, Height);
  var SectionBits: Pointer := nil;
  const Section = CreateDIBSection(0, Info, DIB_RGB_COLORS, SectionBits, 0, 0);
  if Section = 0 then
    Exit(False);

  try
    const Memory = CreateCompatibleDC(0);
    if Memory = 0 then
      Exit(False);

    try
      const Previous = SelectObject(Memory, Section);
      try
        Result := (SectionBits <> nil) and TryDrawOnDC(Memory, Width, Height, Layout, Color);
        if Result then
        begin
          GdiFlush;
          Move(SectionBits^, Bits^, Width * Height * SizeOf(Cardinal));
        end;
      finally
        SelectObject(Memory, Previous);
      end;
    finally
      DeleteDC(Memory);
    end;
  finally
    DeleteObject(Section);
  end;
end;

function TMarkdownVclColorText.TryDrawOnDC(const DC: HDC; const Width, Height: Integer;
  const Layout: IDWriteTextLayout; const Color: TLayoutColor): Boolean;
begin
  const PixelFormat = D2D1PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_PREMULTIPLIED);
  const Properties = D2D1RenderTargetProperties(D2D1_RENDER_TARGET_TYPE_DEFAULT, PixelFormat, DevicePixelsPerInch,
    DevicePixelsPerInch);

  var Target: ID2D1DCRenderTarget;
  if not Succeeded(FDrawFactory.CreateDCRenderTarget(Properties, Target)) then
    Exit(False);

  const Bounds = TRect.Create(0, 0, Width, Height);
  if not Succeeded(Target.BindDC(DC, Bounds)) then
    Exit(False);

  var Brush: ID2D1SolidColorBrush;
  if not Succeeded(Target.CreateSolidColorBrush(BrushColorOf(Color), nil, Brush)) then
    Exit(False);

  Target.SetTextAntialiasMode(D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE);
  Target.BeginDraw;
  Target.Clear(D2D1ColorF(0, 0, 0, 0));
  Target.DrawTextLayout(D2D1PointF(GlyphMargin, GlyphMargin), Layout, Brush, D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT);
  Result := Succeeded(Target.EndDraw);
end;

class function TMarkdownVclColorText.BitmapInfoOf(const Width, Height: Integer): TBitmapInfo;
begin
  Result := Default(TBitmapInfo);
  Result.bmiHeader.biSize        := SizeOf(TBitmapInfoHeader);
  Result.bmiHeader.biWidth       := Width;
  Result.bmiHeader.biHeight      := -Height;
  Result.bmiHeader.biPlanes      := 1;
  Result.bmiHeader.biBitCount    := 32;
  Result.bmiHeader.biCompression := BI_RGB;
end;

class function TMarkdownVclColorText.BrushColorOf(const Color: TLayoutColor): TD2D1ColorF;
begin
  const Red = ((Color shr 16) and $FF) / ColorChannelScale;
  const Green = ((Color shr 8) and $FF) / ColorChannelScale;
  const Blue = (Color and $FF) / ColorChannelScale;
  Result := D2D1ColorF(Red, Green, Blue, 1);
end;

end.
