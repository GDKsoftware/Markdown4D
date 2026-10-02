unit Markdown4D.Vcl.ColorEmoji;

{$SCOPEDENUMS ON}

// Draws emoji in colour onto a GDI device context. GDI renders a colour font
// such as Segoe UI Emoji in the single text colour, so the emoji parts of a
// text run go through DirectWrite instead, which draws the colour glyph layers
// when asked to. The glyphs are drawn into a transparent premultiplied buffer
// and alpha-blended onto the canvas, which keeps the canvas clip region in
// charge exactly as it is for every other GDI drawing call.

interface

uses
  System.Types,
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.D2D1,
  Markdown4D.Layout.Interfaces;

type
  TMarkdownVclColorEmojiRenderer = class
  private
    const
      EmojiFamilyName = 'Segoe UI Emoji';
      // D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT (Windows 8.1 and later).
      EnableColorFontOption = 4;
      DeviceIndependentPixelsPerInch = 96;
      // Room around the glyphs for the anti-aliased edge and for glyph parts
      // that reach outside their advance box.
      BufferMargin = 2;
      ColorChannelScale = 255;
    class var
      FDrawFactory: ID2D1Factory;
      FWriteFactory: IDWriteFactory;
    var
      FTextFormats: TDictionary<Integer, IDWriteTextFormat>;
      FRenderTarget: ID2D1DCRenderTarget;
    class function TryGetDrawFactory(out Factory: ID2D1Factory): Boolean; static;
    class function TryGetWriteFactory(out Factory: IDWriteFactory): Boolean; static;
    class function TryGetBaseline(const Layout: IDWriteTextLayout; out Baseline: Single): Boolean; static;
    class function TopDownBitmapInfo(const Width, Height: Integer): TBitmapInfo; static;
    class function SourceAlphaBlendFunction: TBlendFunction; static;
    class function ToBrushColor(const Color: TLayoutColor): TD2D1ColorF; static;
    function TryCreateLayout(const Text: string; const PixelSize: Integer; out Layout: IDWriteTextLayout): Boolean;
    function TryGetTextFormat(const PixelSize: Integer; out TextFormat: IDWriteTextFormat): Boolean;
    function TryDrawThroughBuffer(const TargetDC: HDC; const Bounds: TRect; const Layout: IDWriteTextLayout;
      const Origin: TD2D1Point2F; const Color: TLayoutColor): Boolean;
    function TryRenderInto(const MemoryDC: HDC; const BufferRect: TRect; const Layout: IDWriteTextLayout;
      const Origin: TD2D1Point2F; const Color: TLayoutColor): Boolean;
    function TryGetRenderTarget(out RenderTarget: ID2D1DCRenderTarget): Boolean;

  public
    constructor Create;
    destructor Destroy; override;
    // Advance width of Text at PixelSize (the em height in device pixels).
    function TryMeasure(const Text: string; const PixelSize: Integer; out Width: Single): Boolean;
    // Draws Text with its baseline start at (Left, BaselineY) on TargetDC.
    function TryDraw(const TargetDC: HDC; const Left, BaselineY: Single; const Text: string;
      const PixelSize: Integer; const Color: TLayoutColor): Boolean;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Winapi.DxgiFormat;

// The factories are shared by every renderer: creating them is the costly
// part, and painters come and go with every paint.
class function TMarkdownVclColorEmojiRenderer.TryGetDrawFactory(out Factory: ID2D1Factory): Boolean;
begin
  if FDrawFactory = nil then
    D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, ID2D1Factory, nil, FDrawFactory);

  Factory := FDrawFactory;
  Result := (Factory <> nil);
end;

class function TMarkdownVclColorEmojiRenderer.TryGetWriteFactory(out Factory: IDWriteFactory): Boolean;
begin
  if FWriteFactory = nil then
  begin
    var SharedFactory: IUnknown;
    const IsCreated = Succeeded(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, IDWriteFactory, SharedFactory));
    if IsCreated then
      FWriteFactory := SharedFactory as IDWriteFactory;
  end;

  Factory := FWriteFactory;
  Result := (Factory <> nil);
end;

class function TMarkdownVclColorEmojiRenderer.TryGetBaseline(const Layout: IDWriteTextLayout;
  out Baseline: Single): Boolean;
begin
  Baseline := 0;

  var LineMetrics: TDwriteLineMetrics;
  var LineCount: Cardinal := 0;
  Result := Succeeded(Layout.GetLineMetrics(@LineMetrics, 1, LineCount)) and (LineCount > 0);
  if Result then
    Baseline := LineMetrics.baseline;
end;

class function TMarkdownVclColorEmojiRenderer.TopDownBitmapInfo(const Width, Height: Integer): TBitmapInfo;
begin
  Result := Default(TBitmapInfo);
  Result.bmiHeader.biSize        := SizeOf(TBitmapInfoHeader);
  Result.bmiHeader.biWidth       := Width;
  Result.bmiHeader.biHeight      := -Height;
  Result.bmiHeader.biPlanes      := 1;
  Result.bmiHeader.biBitCount    := 32;
  Result.bmiHeader.biCompression := BI_RGB;
end;

class function TMarkdownVclColorEmojiRenderer.SourceAlphaBlendFunction: TBlendFunction;
begin
  Result := Default(TBlendFunction);
  Result.BlendOp             := AC_SRC_OVER;
  Result.SourceConstantAlpha := ColorChannelScale;
  Result.AlphaFormat         := AC_SRC_ALPHA;
end;

class function TMarkdownVclColorEmojiRenderer.ToBrushColor(const Color: TLayoutColor): TD2D1ColorF;
begin
  const Red = (Color shr 16) and $FF;
  const Green = (Color shr 8) and $FF;
  const Blue = Color and $FF;
  Result := D2D1ColorF(Red / ColorChannelScale, Green / ColorChannelScale, Blue / ColorChannelScale, 1);
end;

constructor TMarkdownVclColorEmojiRenderer.Create;
begin
  inherited Create;

  FTextFormats := TDictionary<Integer, IDWriteTextFormat>.Create;
end;

destructor TMarkdownVclColorEmojiRenderer.Destroy;
begin
  FRenderTarget := nil;
  FTextFormats.Free;

  inherited Destroy;
end;

function TMarkdownVclColorEmojiRenderer.TryMeasure(const Text: string; const PixelSize: Integer;
  out Width: Single): Boolean;
begin
  Width := 0;

  var Layout: IDWriteTextLayout;
  if not TryCreateLayout(Text, PixelSize, Layout) then
    Exit(False);

  var Metrics: TDwriteTextMetrics;
  Result := Succeeded(Layout.GetMetrics(Metrics));
  if Result then
    Width := Metrics.widthIncludingTrailingWhitespace;
end;

function TMarkdownVclColorEmojiRenderer.TryDraw(const TargetDC: HDC; const Left, BaselineY: Single;
  const Text: string; const PixelSize: Integer; const Color: TLayoutColor): Boolean;
begin
  var Layout: IDWriteTextLayout;
  var Metrics: TDwriteTextMetrics;
  var Baseline: Single;
  const IsLaidOut = TryCreateLayout(Text, PixelSize, Layout) and Succeeded(Layout.GetMetrics(Metrics)) and
    TryGetBaseline(Layout, Baseline);
  if not IsLaidOut then
    Exit(False);

  const Top = BaselineY - Baseline;
  const BufferLeft = Floor(Left) - BufferMargin;
  const BufferTop = Floor(Top) - BufferMargin;
  const BufferWidth = Ceil(Metrics.widthIncludingTrailingWhitespace) + 2 * BufferMargin;
  const BufferHeight = Ceil(Metrics.height) + 2 * BufferMargin;
  const Bounds = TRect.Create(BufferLeft, BufferTop, BufferLeft + BufferWidth, BufferTop + BufferHeight);
  const Origin = D2D1PointF(Left - BufferLeft, Top - BufferTop);

  Result := TryDrawThroughBuffer(TargetDC, Bounds, Layout, Origin, Color);
end;

function TMarkdownVclColorEmojiRenderer.TryCreateLayout(const Text: string; const PixelSize: Integer;
  out Layout: IDWriteTextLayout): Boolean;
begin
  Layout := nil;

  var TextFormat: IDWriteTextFormat;
  var Factory: IDWriteFactory;
  const CanLayOut = (Text <> '') and (PixelSize > 0) and TryGetTextFormat(PixelSize, TextFormat) and
    TryGetWriteFactory(Factory);
  if not CanLayOut then
    Exit(False);

  Result := Succeeded(Factory.CreateTextLayout(PChar(Text), Length(Text), TextFormat, MaxSingle, MaxSingle,
    Layout));
end;

function TMarkdownVclColorEmojiRenderer.TryGetTextFormat(const PixelSize: Integer;
  out TextFormat: IDWriteTextFormat): Boolean;
begin
  if FTextFormats.TryGetValue(PixelSize, TextFormat) then
    Exit(True);

  var Factory: IDWriteFactory;
  if not TryGetWriteFactory(Factory) then
    Exit(False);

  Result := Succeeded(Factory.CreateTextFormat(EmojiFamilyName, nil, DWRITE_FONT_WEIGHT_NORMAL,
    DWRITE_FONT_STYLE_NORMAL, DWRITE_FONT_STRETCH_NORMAL, PixelSize, '', TextFormat));
  if not Result then
    Exit;

  TextFormat.SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP);
  FTextFormats.Add(PixelSize, TextFormat);
end;

// Renders into a 32-bit top-down DIB section, the one kind of bitmap a
// premultiplied DC render target can draw transparently into, and blends that
// onto the target device context at Bounds.
function TMarkdownVclColorEmojiRenderer.TryDrawThroughBuffer(const TargetDC: HDC; const Bounds: TRect;
  const Layout: IDWriteTextLayout; const Origin: TD2D1Point2F; const Color: TLayoutColor): Boolean;
begin
  const Info = TopDownBitmapInfo(Bounds.Width, Bounds.Height);
  var Bits: Pointer := nil;
  const Section = CreateDIBSection(TargetDC, Info, DIB_RGB_COLORS, Bits, 0, 0);
  if Section = 0 then
    Exit(False);

  try
    const MemoryDC = CreateCompatibleDC(TargetDC);
    if MemoryDC = 0 then
      Exit(False);

    try
      const Previous = SelectObject(MemoryDC, Section);
      try
        const BufferRect = TRect.Create(0, 0, Bounds.Width, Bounds.Height);
        Result := TryRenderInto(MemoryDC, BufferRect, Layout, Origin, Color);
        if not Result then
          Exit;

        Result := AlphaBlend(TargetDC, Bounds.Left, Bounds.Top, Bounds.Width, Bounds.Height,
          MemoryDC, 0, 0, Bounds.Width, Bounds.Height, SourceAlphaBlendFunction);
      finally
        SelectObject(MemoryDC, Previous);
      end;
    finally
      DeleteDC(MemoryDC);
    end;
  finally
    DeleteObject(Section);
  end;
end;

function TMarkdownVclColorEmojiRenderer.TryRenderInto(const MemoryDC: HDC; const BufferRect: TRect;
  const Layout: IDWriteTextLayout; const Origin: TD2D1Point2F; const Color: TLayoutColor): Boolean;
begin
  var RenderTarget: ID2D1DCRenderTarget;
  if not TryGetRenderTarget(RenderTarget) then
    Exit(False);

  if Failed(RenderTarget.BindDC(MemoryDC, BufferRect)) then
    Exit(False);

  var Brush: ID2D1SolidColorBrush;
  if Failed(RenderTarget.CreateSolidColorBrush(ToBrushColor(Color), nil, Brush)) then
    Exit(False);

  RenderTarget.BeginDraw;
  RenderTarget.Clear(D2D1ColorF(0, 0, 0, 0));
  RenderTarget.SetTextAntialiasMode(D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE);
  RenderTarget.DrawTextLayout(Origin, Layout, Brush, EnableColorFontOption);
  Result := Succeeded(RenderTarget.EndDraw);

  // A lost device makes EndDraw fail; the next call starts with a fresh target.
  if not Result then
    FRenderTarget := nil;
end;

function TMarkdownVclColorEmojiRenderer.TryGetRenderTarget(out RenderTarget: ID2D1DCRenderTarget): Boolean;
begin
  RenderTarget := FRenderTarget;
  if RenderTarget <> nil then
    Exit(True);

  var Factory: ID2D1Factory;
  if not TryGetDrawFactory(Factory) then
    Exit(False);

  const PixelFormat = D2D1PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_PREMULTIPLIED);
  const Properties = D2D1RenderTargetProperties(D2D1_RENDER_TARGET_TYPE_DEFAULT, PixelFormat,
    DeviceIndependentPixelsPerInch, DeviceIndependentPixelsPerInch);
  Result := Succeeded(Factory.CreateDCRenderTarget(Properties, RenderTarget));
  if Result then
    FRenderTarget := RenderTarget;
end;

end.
