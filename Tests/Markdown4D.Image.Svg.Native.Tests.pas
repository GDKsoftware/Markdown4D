unit Markdown4D.Image.Svg.Native.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Image.Svg;

type
  [TestFixture]
  TNativeSvgRasterizerTests = class
  private
    const
      Red = $FFFF0000;
      Green = $FF00FF00;
    function Rasterize(const Svg: string): TMarkdownSvgRaster;
    function ColorAt(const Raster: TMarkdownSvgRaster; const X, Y: Integer): Cardinal;
    function AlphaAt(const Raster: TMarkdownSvgRaster; const X, Y: Integer): Integer;

  public
    [SetupFixture]
    procedure SetupFixture;

    [Test]
    procedure Rasterize_Rectangle_FillsItsOwnAreaOnly;

    [Test]
    procedure Rasterize_ViewBox_ScalesOntoTheDeclaredSize;

    [Test]
    procedure Rasterize_EvenOddPath_LeavesTheInnerShapeEmpty;

    [Test]
    procedure Rasterize_NonZeroPath_FillsTheInnerShape;

    [Test]
    procedure Rasterize_GroupTransform_MovesItsChildren;

    [Test]
    procedure Rasterize_InheritedFill_ReachesTheChild;

    [Test]
    procedure Rasterize_Stroke_DrawsABandWithoutFillingTheInside;

    [Test]
    procedure Rasterize_MaxWidth_BoundsTheResult;

    [Test]
    procedure Rasterize_Circle_IsRoundAtItsEdges;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Image.Svg.Native;

procedure TNativeSvgRasterizerTests.SetupFixture;
begin
  RegisterNativeSvgRasterizer;
end;

function TNativeSvgRasterizerTests.Rasterize(const Svg: string): TMarkdownSvgRaster;
begin
  const Data = TEncoding.UTF8.GetBytes(Svg);

  Assert.IsTrue(TMarkdownSvgSupport.TryRasterize(Data, 0, 0, Result), 'The document must rasterize');
end;

function TNativeSvgRasterizerTests.ColorAt(const Raster: TMarkdownSvgRaster; const X, Y: Integer): Cardinal;
begin
  const Offset = (Y * Raster.Width + X) * 4;

  Result := (Cardinal(Raster.Pixels[Offset + 3]) shl 24) or (Cardinal(Raster.Pixels[Offset + 2]) shl 16) or
    (Cardinal(Raster.Pixels[Offset + 1]) shl 8) or Raster.Pixels[Offset];
end;

function TNativeSvgRasterizerTests.AlphaAt(const Raster: TMarkdownSvgRaster; const X, Y: Integer): Integer;
begin
  Result := Raster.Pixels[(Y * Raster.Width + X) * 4 + 3];
end;

procedure TNativeSvgRasterizerTests.Rasterize_Rectangle_FillsItsOwnAreaOnly;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">' +
    '<rect x="10" y="10" width="20" height="20" fill="#ff0000"/></svg>');

  Assert.AreEqual(40, Raster.Width);
  Assert.AreEqual(40, Raster.Height);
  Assert.AreEqual(Cardinal(Red), ColorAt(Raster, 20, 20), 'The rectangle is drawn in its own colour');
  Assert.AreEqual(0, AlphaAt(Raster, 5, 5), 'Outside the rectangle nothing is drawn');
  Assert.AreEqual(0, AlphaAt(Raster, 35, 35), 'Outside the rectangle nothing is drawn');
end;

procedure TNativeSvgRasterizerTests.Rasterize_ViewBox_ScalesOntoTheDeclaredSize;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 40 40">' +
    '<rect x="10" y="10" width="20" height="20" fill="#ff0000"/></svg>');

  Assert.AreEqual(80, Raster.Width);
  Assert.AreEqual(255, AlphaAt(Raster, 40, 40), 'The centre of the scaled rectangle is covered');
  Assert.AreEqual(0, AlphaAt(Raster, 10, 10), 'The scaled rectangle starts further in');
end;

procedure TNativeSvgRasterizerTests.Rasterize_EvenOddPath_LeavesTheInnerShapeEmpty;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" viewBox="0 0 60 60">' +
    '<path d="M10 10 h40 v40 h-40 Z M20 20 h20 v20 h-20 Z" fill="#ff0000" fill-rule="evenodd"/></svg>');

  Assert.AreEqual(255, AlphaAt(Raster, 15, 30), 'The ring itself is filled');
  Assert.AreEqual(0, AlphaAt(Raster, 30, 30), 'The inner square is a hole');
end;

procedure TNativeSvgRasterizerTests.Rasterize_NonZeroPath_FillsTheInnerShape;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" viewBox="0 0 60 60">' +
    '<path d="M10 10 h40 v40 h-40 Z M20 20 h20 v20 h-20 Z" fill="#ff0000"/></svg>');

  Assert.AreEqual(255, AlphaAt(Raster, 30, 30),
    'Two sub-paths wound the same way leave no hole under the non-zero rule');
end;

procedure TNativeSvgRasterizerTests.Rasterize_GroupTransform_MovesItsChildren;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" viewBox="0 0 60 60">' +
    '<g transform="translate(30 0)"><rect x="0" y="0" width="20" height="20" fill="#ff0000"/></g></svg>');

  Assert.AreEqual(255, AlphaAt(Raster, 35, 10), 'The child moved with its group');
  Assert.AreEqual(0, AlphaAt(Raster, 10, 10), 'Nothing is left where it was written');
end;

procedure TNativeSvgRasterizerTests.Rasterize_InheritedFill_ReachesTheChild;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">' +
    '<g fill="#00ff00"><rect x="10" y="10" width="20" height="20"/></g></svg>');

  Assert.AreEqual(Cardinal(Green), ColorAt(Raster, 20, 20), 'The child took the fill of its group');
end;

procedure TNativeSvgRasterizerTests.Rasterize_Stroke_DrawsABandWithoutFillingTheInside;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" viewBox="0 0 60 60">' +
    '<rect x="15" y="15" width="30" height="30" fill="none" stroke="#ff0000" stroke-width="6"/></svg>');

  Assert.AreEqual(255, AlphaAt(Raster, 30, 15), 'The band sits on the outline');
  Assert.AreEqual(0, AlphaAt(Raster, 30, 30), 'The inside stays empty without a fill');
  Assert.AreEqual(0, AlphaAt(Raster, 5, 5), 'Outside the band nothing is drawn');
end;

procedure TNativeSvgRasterizerTests.Rasterize_MaxWidth_BoundsTheResult;
begin
  const Svg = '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 200 100">' +
    '<rect x="0" y="0" width="200" height="100" fill="#ff0000"/></svg>';
  const Data = TEncoding.UTF8.GetBytes(Svg);

  var Raster: TMarkdownSvgRaster;
  Assert.IsTrue(TMarkdownSvgSupport.TryRasterize(Data, 100, 0, Raster));

  Assert.AreEqual(100, Raster.Width);
  Assert.AreEqual(50, Raster.Height, 'The aspect ratio is kept');
end;

// A circle drawn without anti-aliasing has only covered and uncovered pixels;
// the partly covered ones are what makes its edge look round.
procedure TNativeSvgRasterizerTests.Rasterize_Circle_IsRoundAtItsEdges;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">' +
    '<circle cx="20" cy="20" r="15" fill="#ff0000"/></svg>');

  var Partial := 0;
  for var Y := 0 to Raster.Height - 1 do
  begin
    for var X := 0 to Raster.Width - 1 do
    begin
      const Alpha = AlphaAt(Raster, X, Y);
      if (Alpha > 0) and (Alpha < 255) then
        Inc(Partial);
    end;
  end;

  Assert.IsTrue(Partial > 20, Format('Expected an anti-aliased edge but found %d partial pixels', [Partial]));
  Assert.AreEqual(255, AlphaAt(Raster, 20, 20), 'The middle is solid');
  Assert.AreEqual(0, AlphaAt(Raster, 2, 2), 'The corner is outside the circle');
end;

end.
