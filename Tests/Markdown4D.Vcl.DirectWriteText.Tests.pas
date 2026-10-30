unit Markdown4D.Vcl.DirectWriteText.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.Types,
  Winapi.Windows,
  Vcl.Graphics,
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Vcl.Painter;

type
  [TestFixture]
  TMarkdownVclDirectWriteTextTests = class
  private
    const
      BitmapWidth = 240;
      BitmapHeight = 80;
      FontFamilyName = 'Segoe UI';
      FontSize = 32;
      RunLeft = 10;
      RunTop = 10;
      ScrollY = 100;
      ClipRight = 60;
      Emoji = #$D83D#$DE00#$D83C#$DF89#$D83D#$DC4D;
      Letter = 'H';
      WideText = 'HHHHHHHHHH';
      PlainText = 'The quick brown fox jumps over the lazy dog';
      KernedText = 'AVATAR WAVY Tokyo';
      MinimumColourPixels = 20;
      SaturationFloor = 120;
      ChannelTolerance = 24;
      InkLuminanceCeiling = 128;
      BaselineTolerance = 1;
      PlainWidthTolerance = 0.05;
      TextColor: TLayoutColor = $FF000000;
    class function NewWhiteBitmap: TBitmap; static;
    class function SampleFont: TMarkdownFontStyle; static;
    class function DrawRun(const Rendering: TMarkdownTextRendering; const Text: string): TBitmap; static;
    class procedure DrawRunOnScrolledBuffer(const Bitmap: TBitmap); static;
    class function ColouredPixelCount(const Bitmap: TBitmap): Integer; static;
    class function IsSaturated(const Color: TColor): Boolean; static;
    class function IsSameColour(const Color, Other: TColor): Boolean; static;
    class function IsInk(const Color: TColor): Boolean; static;
    class function LowestInkRow(const Bitmap: TBitmap): Integer; static;
    class function HasInkFrom(const Bitmap: TBitmap; const Left: Integer): Boolean; static;

  public
    [Test]
    procedure DrawTextRun_EmojiThroughDirectWrite_DrawsInColour;

    [Test]
    procedure DrawTextRun_EmojiThroughGdi_DrawsInOneColour;

    [Test]
    procedure DrawTextRun_DirectWrite_SitsOnTheGdiBaseline;

    [Test]
    procedure DrawTextRun_DirectWriteOnScrolledBuffer_DrawsAtTheLogicalPosition;

    [Test]
    procedure DrawTextRun_DirectWriteOutsideClip_LeavesPixelsUntouched;

    [Test]
    procedure MeasureText_SwitchedToDirectWrite_MeasuresAgain;

    [Test]
    procedure MeasureText_PlainTextThroughDirectWrite_StaysCloseToGdi;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D.Layout.Defaults,
  Markdown4D.Tests.Vcl.BitmapHelpers;

class function TMarkdownVclDirectWriteTextTests.NewWhiteBitmap: TBitmap;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf32bit;
  Result.SetSize(BitmapWidth, BitmapHeight);
  TMarkdownVclTestBitmapHelpers.FillWhite(Result);
end;

class function TMarkdownVclDirectWriteTextTests.SampleFont: TMarkdownFontStyle;
begin
  Result := TMarkdownFontStyle.Create(FontFamilyName, FontSize);
end;

class function TMarkdownVclDirectWriteTextTests.DrawRun(const Rendering: TMarkdownTextRendering;
                                                        const Text: string): TBitmap;
begin
  Result := NewWhiteBitmap;
  const Painter: IPainter = TMarkdownVclPainter.Create(Result.Canvas, ReferencePixelsPerInch, Rendering);
  Painter.DrawTextRun(TLayoutPointF.Create(RunLeft, RunTop), Text, SampleFont, TextColor);
end;

// Black text drawn with ClearType has strongly coloured fringes, but only along
// its edges: a fringe pixel never has neighbours of its own colour on all four
// sides, the way a pixel inside the yellow face of an emoji has.
class function TMarkdownVclDirectWriteTextTests.ColouredPixelCount(const Bitmap: TBitmap): Integer;
begin
  Result := 0;
  for var YIndex := 1 to Bitmap.Height - 2 do
  begin
    for var XIndex := 1 to Bitmap.Width - 2 do
    begin
      const Color = Bitmap.Canvas.Pixels[XIndex, YIndex];
      const IsInsideColouredArea = (IsSaturated(Color) and
                                    IsSameColour(Color, Bitmap.Canvas.Pixels[XIndex - 1, YIndex]) and
                                    IsSameColour(Color, Bitmap.Canvas.Pixels[XIndex + 1, YIndex]) and
                                    IsSameColour(Color, Bitmap.Canvas.Pixels[XIndex, YIndex - 1]) and
                                    IsSameColour(Color, Bitmap.Canvas.Pixels[XIndex, YIndex + 1]));
      if IsInsideColouredArea then
        Inc(Result);
    end;
  end;
end;

class function TMarkdownVclDirectWriteTextTests.IsSaturated(const Color: TColor): Boolean;
begin
  const RGB = ColorToRGB(Color);
  const Channels: TArray<Integer> = [GetRValue(RGB), GetGValue(RGB), GetBValue(RGB)];
  Result := (MaxIntValue(Channels) - MinIntValue(Channels) >= SaturationFloor);
end;

class function TMarkdownVclDirectWriteTextTests.IsSameColour(const Color, Other: TColor): Boolean;
begin
  const RGB = ColorToRGB(Color);
  const OtherRGB = ColorToRGB(Other);
  Result := ((Abs(GetRValue(RGB) - GetRValue(OtherRGB)) < ChannelTolerance) and
             (Abs(GetGValue(RGB) - GetGValue(OtherRGB)) < ChannelTolerance) and
             (Abs(GetBValue(RGB) - GetBValue(OtherRGB)) < ChannelTolerance));
end;

class function TMarkdownVclDirectWriteTextTests.IsInk(const Color: TColor): Boolean;
begin
  const RGB = ColorToRGB(Color);
  Result := ((GetRValue(RGB) + GetGValue(RGB) + GetBValue(RGB)) div 3 < InkLuminanceCeiling);
end;

class function TMarkdownVclDirectWriteTextTests.LowestInkRow(const Bitmap: TBitmap): Integer;
begin
  for var YIndex := Bitmap.Height - 1 downto 0 do
  begin
    for var XIndex := 0 to Bitmap.Width - 1 do
    begin
      if IsInk(Bitmap.Canvas.Pixels[XIndex, YIndex]) then
        Exit(YIndex);
    end;
  end;

  Result := -1;
end;

class function TMarkdownVclDirectWriteTextTests.HasInkFrom(const Bitmap: TBitmap; const Left: Integer): Boolean;
begin
  for var YIndex := 0 to Bitmap.Height - 1 do
  begin
    for var XIndex := Left to Bitmap.Width - 1 do
    begin
      if IsInk(Bitmap.Canvas.Pixels[XIndex, YIndex]) then
        Exit(True);
    end;
  end;

  Result := False;
end;

procedure TMarkdownVclDirectWriteTextTests.DrawTextRun_EmojiThroughDirectWrite_DrawsInColour;
begin
  const Bitmap = DrawRun(TMarkdownTextRendering.DirectWrite, Emoji);
  try
    const ColouredPixels = ColouredPixelCount(Bitmap);

    Assert.IsTrue(ColouredPixels >= MinimumColourPixels,
      Format('Expected at least %d coloured pixels but found %d', [MinimumColourPixels, ColouredPixels]));
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclDirectWriteTextTests.DrawTextRun_EmojiThroughGdi_DrawsInOneColour;
begin
  const Bitmap = DrawRun(TMarkdownTextRendering.Gdi, Emoji);
  try
    const ColouredPixels = ColouredPixelCount(Bitmap);

    Assert.IsTrue(ColouredPixels < MinimumColourPixels,
      Format('GDI draws colour fonts in one colour, yet %d coloured pixels were found', [ColouredPixels]));
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclDirectWriteTextTests.DrawTextRun_DirectWrite_SitsOnTheGdiBaseline;
begin
  const GdiBitmap = DrawRun(TMarkdownTextRendering.Gdi, Letter);
  try
    const DirectWriteBitmap = DrawRun(TMarkdownTextRendering.DirectWrite, Letter);
    try
      const GdiBaseline = LowestInkRow(GdiBitmap);
      const DirectWriteBaseline = LowestInkRow(DirectWriteBitmap);

      Assert.AreEqual(Double(GdiBaseline), Double(DirectWriteBaseline), Double(BaselineTolerance),
        'Text drawn through DirectWrite must rest on the baseline GDI lays it out on');
    finally
      DirectWriteBitmap.Free;
    end;
  finally
    GdiBitmap.Free;
  end;
end;

// As the viewer renders: the window origin is back at zero before the painter is
// released, which is when the painter draws the text it has gathered.
class procedure TMarkdownVclDirectWriteTextTests.DrawRunOnScrolledBuffer(const Bitmap: TBitmap);
begin
  const Painter: IPainter = TMarkdownVclPainter.Create(Bitmap.Canvas, ReferencePixelsPerInch,
                                                       TMarkdownTextRendering.DirectWrite);
  SetWindowOrgEx(Bitmap.Canvas.Handle, 0, ScrollY, nil);
  try
    Painter.DrawTextRun(TLayoutPointF.Create(RunLeft, RunTop + ScrollY), Letter, SampleFont, TextColor);
  finally
    SetWindowOrgEx(Bitmap.Canvas.Handle, 0, 0, nil);
  end;
end;

procedure TMarkdownVclDirectWriteTextTests.DrawTextRun_DirectWriteOnScrolledBuffer_DrawsAtTheLogicalPosition;
begin
  const Unscrolled = DrawRun(TMarkdownTextRendering.DirectWrite, Letter);
  try
    const Scrolled = NewWhiteBitmap;
    try
      DrawRunOnScrolledBuffer(Scrolled);

      Assert.AreEqual(LowestInkRow(Unscrolled), LowestInkRow(Scrolled),
        'A run on a scrolled buffer must land where the window origin puts its logical position');
    finally
      Scrolled.Free;
    end;
  finally
    Unscrolled.Free;
  end;
end;

procedure TMarkdownVclDirectWriteTextTests.DrawTextRun_DirectWriteOutsideClip_LeavesPixelsUntouched;
begin
  const Bitmap = NewWhiteBitmap;
  try
    const Painter: IPainter = TMarkdownVclPainter.Create(Bitmap.Canvas, ReferencePixelsPerInch,
                                                         TMarkdownTextRendering.DirectWrite);
    Painter.SaveState;
    try
      Painter.SetClip(TLayoutRectF.Create(0, 0, ClipRight, BitmapHeight));
      Painter.DrawTextRun(TLayoutPointF.Create(RunLeft, RunTop), WideText, SampleFont, TextColor);
    finally
      Painter.RestoreState;
    end;

    Assert.IsFalse(HasInkFrom(Bitmap, ClipRight), 'Text drawn through DirectWrite must stay inside the clip');
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclDirectWriteTextTests.MeasureText_SwitchedToDirectWrite_MeasuresAgain;
begin
  const Bitmap = NewWhiteBitmap;
  try
    const DirectWritePainter: IPainter = TMarkdownVclPainter.Create(Bitmap.Canvas, ReferencePixelsPerInch,
                                                                    TMarkdownTextRendering.DirectWrite);
    const Expected = DirectWritePainter.MeasureText(KernedText, SampleFont).Width;

    const Painter = TMarkdownVclPainter.Create(Bitmap.Canvas);
    const PainterLifetime: IPainter = Painter;
    const GdiWidth = Painter.MeasureText(KernedText, SampleFont).Width;
    Assert.AreNotEqual(Double(Expected), Double(GdiWidth), 'GDI does not kern, so the sample must measure wider there');

    Painter.TextRendering := TMarkdownTextRendering.DirectWrite;

    const Actual = Painter.MeasureText(KernedText, SampleFont).Width;
    Assert.AreEqual(Double(Expected), Double(Actual),
      'A painter switched to DirectWrite must not answer with the widths GDI measured');
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclDirectWriteTextTests.MeasureText_PlainTextThroughDirectWrite_StaysCloseToGdi;
begin
  const Bitmap = NewWhiteBitmap;
  try
    const GdiPainter: IPainter = TMarkdownVclPainter.Create(Bitmap.Canvas);
    const DirectWritePainter: IPainter = TMarkdownVclPainter.Create(Bitmap.Canvas, ReferencePixelsPerInch,
                                                                    TMarkdownTextRendering.DirectWrite);

    const GdiWidth = GdiPainter.MeasureText(PlainText, SampleFont).Width;
    const DirectWriteWidth = DirectWritePainter.MeasureText(PlainText, SampleFont).Width;

    Assert.AreEqual(Double(GdiWidth), Double(DirectWriteWidth), Double(GdiWidth * PlainWidthTolerance),
      'Plain text must measure about as wide through DirectWrite as through GDI');
  finally
    Bitmap.Free;
  end;
end;

end.
