unit Markdown4D.Vcl.Image.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Vcl.Forms,
  Vcl.Graphics,
  Markdown4D.Vcl.Viewer;

type
  TPixelPredicate = reference to function(const Pixel: TColor): Boolean;

  TPixelMeasurement = record
    MatchCount: Integer;
    ExtentWidth: Integer;
  end;

  [TestFixture]
  TMarkdownVclImageTests = class
  private
    const
      ViewerWidth = 400;
      ViewerHeight = 300;
      ImagePixelSize = 32;
      SubstituteImageSize = 20;
      MinimumImagePixels = 500;
      MinimumSubstitutePixels = 200;
      MaximumTrueSizeExtent = 48;
      StrongChannelFloor = 200;
      WeakChannelCeiling = 60;
      ImageFileName = 'red.png';
      MarkdownFileName = 'doc.md';
      ImageMarkdown = '![red](red.png)';
      SvgFileName = 'badge.svg';
      SvgMarkdown = '![badge](badge.svg)';
      SvgPixelSize = 24;
    var
      FTempFolder: string;
      FForm: TForm;
      FViewer: TMarkdownViewer;
    procedure WriteRedPng;
    procedure WriteRedSvgFile;
    procedure RegisterRedSvgRasterizer;
    function PaintViewer: TBitmap;
    function MeasureMatchingPixels(const Predicate: TPixelPredicate): TPixelMeasurement;
    class function IsRed(const Pixel: TColor): Boolean; static;
    class function IsBlue(const Pixel: TColor): Boolean; static;
    procedure HandleResolveImage(const Sender: TObject; const Url: string; const Picture: TPicture;
      var Handled: Boolean);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure LocalFileImage_ViaBaseUrl_DrawsAtTrueSize;

    [Test]
    procedure LocalFileImage_RelativeToLoadedFile_Draws;

    [Test]
    procedure ResolveImageEvent_SubstitutesPicture;

    [Test]
    procedure SvgImage_ViaRegisteredRasterizer_DrawsRasterizedPixels;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  System.Math,
  System.IOUtils,
  Vcl.Imaging.pngimage,
  Markdown4D.Image.Svg,
  Markdown4D.Highlighter.Interfaces;

procedure TMarkdownVclImageTests.Setup;
begin
  FTempFolder := TPath.Combine(TPath.GetTempPath, 'Markdown4D.ImageTests.' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempFolder);

  FForm := TForm.CreateNew(nil);
  FForm.ClientWidth := ViewerWidth;
  FForm.ClientHeight := ViewerHeight;

  FViewer := TMarkdownViewer.Create(FForm);
  FViewer.Parent := FForm;
  FViewer.SetBounds(0, 0, ViewerWidth, ViewerHeight);
  FViewer.HandleNeeded;
end;

procedure TMarkdownVclImageTests.TearDown;
begin
  FViewer := nil;
  FForm.Free;
  FForm := nil;

  TMarkdownSvgSupport.RegisterRasterizer(nil);
  THighlighterRegistry.Clear;
  TDirectory.Delete(FTempFolder, True);
end;

procedure TMarkdownVclImageTests.LocalFileImage_ViaBaseUrl_DrawsAtTrueSize;
begin
  WriteRedPng;
  FViewer.Images.BaseUrl := FTempFolder;
  FViewer.Text := ImageMarkdown;

  const Measurement = MeasureMatchingPixels(IsRed);

  Assert.IsTrue(Measurement.MatchCount >= MinimumImagePixels,
    Format('Expected at least %d red pixels but found %d', [MinimumImagePixels, Measurement.MatchCount]));
  Assert.IsTrue(Measurement.ExtentWidth <= MaximumTrueSizeExtent,
    Format('Expected red extent of at most %d pixels but found %d', [MaximumTrueSizeExtent, Measurement.ExtentWidth]));
end;

procedure TMarkdownVclImageTests.LocalFileImage_RelativeToLoadedFile_Draws;
begin
  WriteRedPng;
  const MarkdownPath = TPath.Combine(FTempFolder, MarkdownFileName);
  TFile.WriteAllText(MarkdownPath, ImageMarkdown, TEncoding.UTF8);

  FViewer.LoadFromFile(MarkdownPath);

  const Measurement = MeasureMatchingPixels(IsRed);

  Assert.IsTrue(Measurement.MatchCount >= MinimumImagePixels,
    Format('Expected at least %d red pixels but found %d', [MinimumImagePixels, Measurement.MatchCount]));
end;

procedure TMarkdownVclImageTests.ResolveImageEvent_SubstitutesPicture;
begin
  FViewer.OnResolveImage := HandleResolveImage;
  FViewer.Text := '![substituted](nowhere.png)';

  const Measurement = MeasureMatchingPixels(IsBlue);

  Assert.IsTrue(Measurement.MatchCount >= MinimumSubstitutePixels,
    Format('Expected at least %d blue pixels but found %d', [MinimumSubstitutePixels, Measurement.MatchCount]));
end;

procedure TMarkdownVclImageTests.SvgImage_ViaRegisteredRasterizer_DrawsRasterizedPixels;
begin
  RegisterRedSvgRasterizer;
  WriteRedSvgFile;
  FViewer.Images.BaseUrl := FTempFolder;
  FViewer.Text := SvgMarkdown;

  const Measurement = MeasureMatchingPixels(IsRed);

  Assert.IsTrue(Measurement.MatchCount >= MinimumImagePixels,
    Format('Expected at least %d rasterized SVG pixels but found %d', [MinimumImagePixels, Measurement.MatchCount]));
end;

procedure TMarkdownVclImageTests.WriteRedSvgFile;
begin
  const Svg = Format('<svg xmlns="http://www.w3.org/2000/svg" width="%0:d" height="%0:d"></svg>', [SvgPixelSize]);
  TFile.WriteAllText(TPath.Combine(FTempFolder, SvgFileName), Svg, TEncoding.UTF8);
end;

procedure TMarkdownVclImageTests.RegisterRedSvgRasterizer;
begin
  TMarkdownSvgSupport.RegisterRasterizer(
    function(const Svg: TBytes; const MaxWidth, MaxHeight: Single; out Raster: TMarkdownSvgRaster): Boolean
    begin
      Raster.Width := SvgPixelSize;
      Raster.Height := SvgPixelSize;
      SetLength(Raster.Pixels, SvgPixelSize * SvgPixelSize * 4);

      var Index := 0;
      while Index < SvgPixelSize * SvgPixelSize do
      begin
        Raster.Pixels[Index * 4 + 0] := 0;
        Raster.Pixels[Index * 4 + 1] := 0;
        Raster.Pixels[Index * 4 + 2] := 255;
        Raster.Pixels[Index * 4 + 3] := 255;
        Inc(Index);
      end;

      Result := True;
    end);
end;

procedure TMarkdownVclImageTests.WriteRedPng;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.PixelFormat := pf24bit;
    Bitmap.SetSize(ImagePixelSize, ImagePixelSize);
    Bitmap.Canvas.Brush.Color := clRed;
    Bitmap.Canvas.FillRect(TRect.Create(0, 0, ImagePixelSize, ImagePixelSize));

    const Png = TPngImage.Create;
    try
      Png.Assign(Bitmap);
      Png.SaveToFile(TPath.Combine(FTempFolder, ImageFileName));
    finally
      Png.Free;
    end;
  finally
    Bitmap.Free;
  end;
end;

function TMarkdownVclImageTests.PaintViewer: TBitmap;
begin
  Result := TBitmap.Create;
  Result.SetSize(ViewerWidth, ViewerHeight);
  Result.Canvas.Brush.Color := clWhite;
  Result.Canvas.FillRect(TRect.Create(0, 0, ViewerWidth, ViewerHeight));
  FViewer.PaintTo(Result.Canvas.Handle, 0, 0);
end;

function TMarkdownVclImageTests.MeasureMatchingPixels(const Predicate: TPixelPredicate): TPixelMeasurement;
begin
  Result.MatchCount := 0;
  Result.ExtentWidth := 0;
  var MinX := MaxInt;
  var MaxX := -1;

  const Bitmap = PaintViewer;
  try
    for var Y := 0 to Bitmap.Height - 1 do
    begin
      for var X := 0 to Bitmap.Width - 1 do
      begin
        if Predicate(Bitmap.Canvas.Pixels[X, Y]) then
        begin
          Inc(Result.MatchCount);
          MinX := Min(MinX, X);
          MaxX := Max(MaxX, X);
        end;
      end;
    end;
  finally
    Bitmap.Free;
  end;

  if MaxX >= MinX then
    Result.ExtentWidth := MaxX - MinX + 1;
end;

class function TMarkdownVclImageTests.IsRed(const Pixel: TColor): Boolean;
begin
  const Rgb = ColorToRGB(Pixel);
  const Red = Rgb and $FF;
  const Green = (Rgb shr 8) and $FF;
  const Blue = (Rgb shr 16) and $FF;
  Result := (Red >= StrongChannelFloor) and (Green <= WeakChannelCeiling) and (Blue <= WeakChannelCeiling);
end;

class function TMarkdownVclImageTests.IsBlue(const Pixel: TColor): Boolean;
begin
  const Rgb = ColorToRGB(Pixel);
  const Red = Rgb and $FF;
  const Green = (Rgb shr 8) and $FF;
  const Blue = (Rgb shr 16) and $FF;
  Result := (Blue >= StrongChannelFloor) and (Red <= WeakChannelCeiling) and (Green <= WeakChannelCeiling);
end;

procedure TMarkdownVclImageTests.HandleResolveImage(const Sender: TObject; const Url: string;
  const Picture: TPicture; var Handled: Boolean);
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.PixelFormat := pf24bit;
    Bitmap.SetSize(SubstituteImageSize, SubstituteImageSize);
    Bitmap.Canvas.Brush.Color := clBlue;
    Bitmap.Canvas.FillRect(TRect.Create(0, 0, SubstituteImageSize, SubstituteImageSize));
    Picture.Bitmap.Assign(Bitmap);
  finally
    Bitmap.Free;
  end;

  Handled := True;
end;

end.
