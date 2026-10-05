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
    class function TestFont: TMarkdownFontStyle;
    class function ColouredPixelCount(const Bitmap: TBitmap): Integer;
    class function IsColoured(const Color: TColor): Boolean;
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
  Markdown4D.Vcl.Painter;

procedure TMarkdownVclEmojiTests.DrawTextRun_Emoji_PaintsColouredPixels;
begin
  const Bitmap = CreateWhiteBuffer;
  try
    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    Painter.DrawTextRun(TLayoutPointF.Create(DrawLeft, DrawTop), Smile, TestFont, TextColor);

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

class function TMarkdownVclEmojiTests.IsColoured(const Color: TColor): Boolean;
begin
  const Pixel = ColorToRGB(Color);
  const Red = Pixel and $FF;
  const Green = (Pixel shr 8) and $FF;
  const Blue = (Pixel shr 16) and $FF;
  Result := (Red >= FaceRedFloor) and (Green >= FaceGreenFloor) and (Blue <= FaceBlueCeiling);
end;

end.
