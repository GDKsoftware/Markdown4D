unit Markdown4D.Vcl.Emoji.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Vcl.Graphics,
  Markdown4D.Layout.Interfaces;

type
  [TestFixture]
  TMarkdownVclEmojiTests = class
  private
    const
      Smile = #$D83D#$DE04;
      BufferWidth = 160;
      BufferHeight = 80;
      FontFamilyName = 'Segoe UI';
      FontSize = 32.0;
      TextColor: TLayoutColor = $FF000000;
      // The yellow face of the smile emoji; a monochrome outline or ClearType
      // fringes around black text never fill this many pixels with it.
      FaceRedFloor = 200;
      FaceGreenFloor = 140;
      FaceBlueCeiling = 110;
      MinimumColouredPixels = 250;
      WidthTolerance = 0.01;
      ScrollOffset = 200;
      DrawLeft = 10.0;
      DrawTop = 10.0;
      WhiteColor = $FFFFFF;
      RasterBytesPerPixel = 4;
      RasterBlueOffset = 0;
      RasterGreenOffset = 1;
      RasterRedOffset = 2;
      // The em size in pixels of the 32 pt test font at 96 dpi.
      ProbeEmSize = 42.0;
      NoColourEmojiMessage = 'This machine draws no colour emoji (no Direct2D or no Segoe UI Emoji colour ' +
                             'layers); the GDI fallback drew the emoji, the colour check is skipped';
    class function TestFont: TMarkdownFontStyle;
    class function ColouredPixelCount(const Bitmap: TBitmap): Integer;
    class function InkedPixelCount(const Bitmap: TBitmap): Integer;
    class function IsColoured(const Color: TColor): Boolean;
    class function IsColouredRgb(const Red, Green, Blue: Integer): Boolean;
    class function CanDrawColourEmoji: Boolean;
    class function CreateWhiteBuffer: TBitmap;

  public
    [Test]
    procedure DrawTextRun_Emoji_PaintsColouredPixels;

    [Test]
    procedure DrawTextRun_EmojiOnScrolledBuffer_LandsInVisibleArea;

    [Test]
    procedure MeasureText_Emoji_HasPositiveWidth;

    [Test]
    procedure MeasureText_MixedRun_EqualsSumOfItsParts;
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  Markdown4D.Tests.Vcl.BitmapHelpers,
  Markdown4D.Vcl.ColorText,
  Markdown4D.Vcl.Painter;

procedure TMarkdownVclEmojiTests.DrawTextRun_Emoji_PaintsColouredPixels;
begin
  const Bitmap = CreateWhiteBuffer;
  try
    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    Painter.DrawTextRun(TLayoutPointF.Create(DrawLeft, DrawTop), Smile, TestFont, TextColor);

    Assert.IsTrue(InkedPixelCount(Bitmap) > 0, 'Expected the emoji drawn inside the buffer');
    if not CanDrawColourEmoji then
      Assert.Pass(NoColourEmojiMessage);

    const Coloured = ColouredPixelCount(Bitmap);
    Assert.IsTrue(Coloured >= MinimumColouredPixels,
      Format('Expected the emoji in colour (at least %d coloured pixels) but found %d',
      [MinimumColouredPixels, Coloured]));
  finally
    Bitmap.Free;
  end;
end;

// The viewer scrolls by moving the buffer's window origin; an emoji drawn at
// its logical position must still end up in the visible rows of the buffer.
procedure TMarkdownVclEmojiTests.DrawTextRun_EmojiOnScrolledBuffer_LandsInVisibleArea;
begin
  const Bitmap = CreateWhiteBuffer;
  try
    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    SetWindowOrgEx(Bitmap.Canvas.Handle, 0, ScrollOffset, nil);
    try
      Painter.DrawTextRun(TLayoutPointF.Create(DrawLeft, ScrollOffset + DrawTop), Smile, TestFont, TextColor);
    finally
      SetWindowOrgEx(Bitmap.Canvas.Handle, 0, 0, nil);
    end;

    Assert.IsTrue(InkedPixelCount(Bitmap) > 0, 'Expected the emoji drawn inside the scrolled buffer');
    if not CanDrawColourEmoji then
      Assert.Pass(NoColourEmojiMessage);

    const Coloured = ColouredPixelCount(Bitmap);
    Assert.IsTrue(Coloured >= MinimumColouredPixels,
      Format('Expected the emoji inside the scrolled buffer (at least %d coloured pixels) but found %d',
      [MinimumColouredPixels, Coloured]));
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclEmojiTests.MeasureText_Emoji_HasPositiveWidth;
begin
  const Bitmap = CreateWhiteBuffer;
  try
    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);

    const Width = Painter.MeasureText(Smile, TestFont).Width;
    Assert.IsTrue(Width > 0, Format('Expected a positive emoji width but found %.2f', [Width]));
  finally
    Bitmap.Free;
  end;
end;

// DrawTextRun places each stretch at the summed widths of the stretches before
// it, so a mixed run must measure as exactly that sum.
procedure TMarkdownVclEmojiTests.MeasureText_MixedRun_EqualsSumOfItsParts;
begin
  const Bitmap = CreateWhiteBuffer;
  try
    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    const Font = TestFont;

    const Whole = Painter.MeasureText('Start ' + Smile + ' en', Font).Width;
    const Parts = Painter.MeasureText('Start ', Font).Width +
                  Painter.MeasureText(Smile, Font).Width +
                  Painter.MeasureText(' en', Font).Width;
    Assert.AreEqual(Parts, Whole, WidthTolerance);
  finally
    Bitmap.Free;
  end;
end;

class function TMarkdownVclEmojiTests.TestFont: TMarkdownFontStyle;
begin
  Result := TMarkdownFontStyle.Create(FontFamilyName, FontSize);
end;

class function TMarkdownVclEmojiTests.CreateWhiteBuffer: Vcl.Graphics.TBitmap;
begin
  Result := Vcl.Graphics.TBitmap.Create;
  Result.SetSize(BufferWidth, BufferHeight);
  TMarkdownVclTestBitmapHelpers.FillWhite(Result);
end;

class function TMarkdownVclEmojiTests.ColouredPixelCount(const Bitmap: Vcl.Graphics.TBitmap): Integer;
begin
  Result := 0;

  for var YIndex := 0 to Bitmap.Height - 1 do
  begin
    for var XIndex := 0 to Bitmap.Width - 1 do
    begin
      if IsColoured(Bitmap.Canvas.Pixels[XIndex, YIndex]) then
        Inc(Result);
    end;
  end;
end;

class function TMarkdownVclEmojiTests.InkedPixelCount(const Bitmap: Vcl.Graphics.TBitmap): Integer;
begin
  Result := 0;

  for var YIndex := 0 to Bitmap.Height - 1 do
  begin
    for var XIndex := 0 to Bitmap.Width - 1 do
    begin
      const IsInked = (ColorToRGB(Bitmap.Canvas.Pixels[XIndex, YIndex]) <> WhiteColor);
      if IsInked then
        Inc(Result);
    end;
  end;
end;

class function TMarkdownVclEmojiTests.IsColoured(const Color: TColor): Boolean;
begin
  const Pixel = ColorToRGB(Color);
  const Red = Pixel and $FF;
  const Green = (Pixel shr 8) and $FF;
  const Blue = (Pixel shr 16) and $FF;
  Result := IsColouredRgb(Red, Green, Blue);
end;

class function TMarkdownVclEmojiTests.IsColouredRgb(const Red, Green, Blue: Integer): Boolean;
begin
  Result := (Red >= FaceRedFloor) and (Green >= FaceGreenFloor) and (Blue <= FaceBlueCeiling);
end;

// Whether this machine can draw the emoji in colour at all: Direct2D present
// and an emoji font with colour layers. Build servers without them fall back
// to GDI, which is intended behaviour, not a failure.
class function TMarkdownVclEmojiTests.CanDrawColourEmoji: Boolean;
begin
  const ColorText = TMarkdownVclColorText.Create;
  try
    var Image: TMarkdownVclColorTextImage;
    if not ColorText.TryRender(Smile, ProbeEmSize, TextColor, Image) then
      Exit(False);

    const Pixels = Image.Raster.Pixels;
    var Coloured := 0;
    var Offset := 0;
    while Offset < Length(Pixels) do
    begin
      const IsPixelColoured = IsColouredRgb(Pixels[Offset + RasterRedOffset],
                                            Pixels[Offset + RasterGreenOffset],
                                            Pixels[Offset + RasterBlueOffset]);
      if IsPixelColoured then
        Inc(Coloured);
      Offset := Offset + RasterBytesPerPixel;
    end;

    Result := (Coloured >= MinimumColouredPixels);
  finally
    ColorText.Free;
  end;
end;

end.
