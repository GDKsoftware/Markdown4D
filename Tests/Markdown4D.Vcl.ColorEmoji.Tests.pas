unit Markdown4D.Vcl.ColorEmoji.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Vcl.Graphics;

type
  [TestFixture]
  TMarkdownVclColorEmojiTests = class
  private
    const
      BitmapWidth = 200;
      BitmapHeight = 80;
      FontFamilyName = 'Segoe UI';
      FontSize = 32.0;
      TextLeft = 10.0;
      TextTop = 10.0;
      ClipWidth = 5.0;
      WidthTolerance = 0.01;
      BlackText = $FF000000;
      SmileEmoji = #$D83D#$DE04;
      // The smiling face is yellow; a monochrome glyph has no such pixels.
      MinimumYellowPixels = 20;
      YellowRedFloor = 200;
      YellowGreenFloor = 150;
      YellowBlueCeiling = 100;
    class function CreateWhiteBitmap: TBitmap; static;
    class function YellowPixelCount(const Bitmap: TBitmap): Integer; static;

  public
    [Test]
    procedure DrawTextRun_Emoji_DrawsInColor;

    [Test]
    procedure DrawTextRun_EmojiOutsideClip_LeavesPixelsUntouched;

    [Test]
    procedure MeasureText_TextAroundEmoji_EqualsSumOfParts;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Vcl.Painter,
  Markdown4D.Tests.Vcl.BitmapHelpers;

class function TMarkdownVclColorEmojiTests.CreateWhiteBitmap: TBitmap;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf32bit;
  Result.SetSize(BitmapWidth, BitmapHeight);
  TMarkdownVclTestBitmapHelpers.FillWhite(Result);
end;

class function TMarkdownVclColorEmojiTests.YellowPixelCount(const Bitmap: TBitmap): Integer;
begin
  Result := 0;
  for var YIndex := 0 to Bitmap.Height - 1 do
  begin
    for var XIndex := 0 to Bitmap.Width - 1 do
    begin
      const Pixel = ColorToRGB(Bitmap.Canvas.Pixels[XIndex, YIndex]);
      const Red = Pixel and $FF;
      const Green = (Pixel shr 8) and $FF;
      const Blue = (Pixel shr 16) and $FF;
      const IsYellow = (Red >= YellowRedFloor) and (Green >= YellowGreenFloor) and (Blue <= YellowBlueCeiling);
      if IsYellow then
        Inc(Result);
    end;
  end;
end;

procedure TMarkdownVclColorEmojiTests.DrawTextRun_Emoji_DrawsInColor;
begin
  const Bitmap = CreateWhiteBitmap;
  try
    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    const Font = TMarkdownFontStyle.Create(FontFamilyName, FontSize);

    Painter.DrawTextRun(TLayoutPointF.Create(TextLeft, TextTop), SmileEmoji, Font, BlackText);

    Assert.IsTrue(YellowPixelCount(Bitmap) >= MinimumYellowPixels,
      'An emoji drawn in black text must still show its own colours');
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclColorEmojiTests.DrawTextRun_EmojiOutsideClip_LeavesPixelsUntouched;
begin
  const Bitmap = CreateWhiteBitmap;
  try
    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    const Font = TMarkdownFontStyle.Create(FontFamilyName, FontSize);

    Painter.SaveState;
    try
      Painter.SetClip(TLayoutRectF.Create(0, 0, ClipWidth, BitmapHeight));
      Painter.DrawTextRun(TLayoutPointF.Create(TextLeft, TextTop), SmileEmoji, Font, BlackText);
    finally
      Painter.RestoreState;
    end;

    Assert.AreEqual(1, TMarkdownVclTestBitmapHelpers.DistinctColorCount(Bitmap),
      'A colour emoji outside the clip region must not paint any pixel');
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclColorEmojiTests.MeasureText_TextAroundEmoji_EqualsSumOfParts;
begin
  const Bitmap = CreateWhiteBitmap;
  try
    var Painter: IPainter := TMarkdownVclPainter.Create(Bitmap.Canvas);
    const Font = TMarkdownFontStyle.Create(FontFamilyName, FontSize);

    const EmojiWidth = Painter.MeasureText(SmileEmoji, Font).Width;
    const Whole = Painter.MeasureText(Format('a %s b', [SmileEmoji]), Font).Width;
    const Parts = Painter.MeasureText('a ', Font).Width + EmojiWidth + Painter.MeasureText(' b', Font).Width;

    const HasRoom = (EmojiWidth > 0);
    const IsSumOfParts = SameValue(Parts, Whole, WidthTolerance);
    Assert.IsTrue(HasRoom, 'An emoji must take up room');
    Assert.IsTrue(IsSumOfParts, Format('Expected %.2f, got %.2f', [Parts, Whole]));
  finally
    Bitmap.Free;
  end;
end;

end.
