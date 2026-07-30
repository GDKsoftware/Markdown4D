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

    [Test]
    procedure Rasterize_LinearGradient_RunsFromOneStopToTheOther;

    [Test]
    procedure Rasterize_RadialGradient_IsBrightestAtItsCentre;

    [Test]
    procedure Rasterize_ClipPath_HoldsTheShapeInside;

    [Test]
    procedure Rasterize_BlurFilter_SoftensTheEdge;

    [Test]
    procedure Rasterize_DropShadowFilter_PutsInkBesideTheShape;

    [Test]
    procedure Rasterize_Use_DrawsWhatItPointsAtWhereItStands;

    [Test]
    procedure Rasterize_Mask_LetsThroughWhatIsBrightInIt;

    [Test]
    procedure Rasterize_Text_PutsInkOnTheBaseline;

    [Test]
    procedure Rasterize_TextInheritingFromItsGroup_IsDrawnAtThatSize;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Image.Glyphs,
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

// The ends of the ramp carry the stop colours, and the middle sits between
// them, which is all a gradient has to promise.
procedure TNativeSvgRasterizerTests.Rasterize_LinearGradient_RunsFromOneStopToTheOther;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">' +
    '<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">' +
    '<stop offset="0" stop-color="#ff0000"/><stop offset="1" stop-color="#0000ff"/>' +
    '</linearGradient></defs>' +
    '<rect x="0" y="0" width="40" height="40" fill="url(#g)"/></svg>');

  const Top = ColorAt(Raster, 20, 1);
  const Bottom = ColorAt(Raster, 20, 38);
  const Middle = ColorAt(Raster, 20, 20);

  Assert.IsTrue((Top shr 16) and $FF > 200, 'The top is the first stop');
  Assert.IsTrue(Bottom and $FF > 200, 'The bottom is the second stop');
  Assert.IsTrue(((Middle shr 16) and $FF > 60) and (Middle and $FF > 60), 'The middle mixes the two');
end;

procedure TNativeSvgRasterizerTests.Rasterize_RadialGradient_IsBrightestAtItsCentre;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">' +
    '<defs><radialGradient id="g" cx="0.5" cy="0.5" r="0.5">' +
    '<stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#000000"/>' +
    '</radialGradient></defs>' +
    '<rect x="0" y="0" width="40" height="40" fill="url(#g)"/></svg>');

  const Centre = ColorAt(Raster, 20, 20) and $FF;
  const Edge = ColorAt(Raster, 20, 38) and $FF;

  Assert.IsTrue(Centre > Edge + 100, Format('The centre (%d) must be far brighter than the edge (%d)',
    [Centre, Edge]));
end;

procedure TNativeSvgRasterizerTests.Rasterize_ClipPath_HoldsTheShapeInside;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" viewBox="0 0 60 60">' +
    '<defs><clipPath id="c"><rect x="10" y="10" width="20" height="20"/></clipPath></defs>' +
    '<g clip-path="url(#c)"><rect x="0" y="0" width="60" height="60" fill="#ff0000"/></g></svg>');

  Assert.AreEqual(255, AlphaAt(Raster, 20, 20), 'Inside the clip the fill stands');
  Assert.AreEqual(0, AlphaAt(Raster, 45, 45), 'Outside the clip nothing is drawn');
end;

// A blur spreads coverage past the edge of the shape and softens what is left
// behind, which is exactly what a sharp fill never does.
procedure TNativeSvgRasterizerTests.Rasterize_BlurFilter_SoftensTheEdge;
begin
  const Sharp = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" viewBox="0 0 60 60">' +
    '<rect x="20" y="20" width="20" height="20" fill="#ff0000"/></svg>');
  const Soft = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" viewBox="0 0 60 60">' +
    '<defs><filter id="b"><feGaussianBlur stdDeviation="3"/></filter></defs>' +
    '<rect x="20" y="20" width="20" height="20" fill="#ff0000" filter="url(#b)"/></svg>');

  Assert.AreEqual(0, AlphaAt(Sharp, 16, 30), 'A sharp fill stops at its edge');
  Assert.IsTrue(AlphaAt(Soft, 16, 30) > 0, 'A blur reaches past the edge');
  Assert.IsTrue(AlphaAt(Soft, 21, 30) < 255,
    'And thins out the edge it used to cover solidly');
  Assert.AreEqual(255, AlphaAt(Sharp, 21, 30), 'Where the sharp fill is still solid');
end;

// Blur the shape, move it, colour it, put the original back on top: the
// standard way a document asks for a drop shadow.
procedure TNativeSvgRasterizerTests.Rasterize_DropShadowFilter_PutsInkBesideTheShape;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 80 80">' +
    '<defs><filter id="s">' +
    '<feGaussianBlur in="SourceAlpha" stdDeviation="2" result="blurred"/>' +
    '<feOffset in="blurred" dx="6" dy="6" result="moved"/>' +
    '<feFlood flood-color="#000000" flood-opacity="0.6" result="colour"/>' +
    '<feComposite in="colour" in2="moved" operator="in" result="shadow"/>' +
    '<feMerge><feMergeNode in="shadow"/><feMergeNode in="SourceGraphic"/></feMerge>' +
    '</filter></defs>' +
    '<rect x="20" y="20" width="30" height="30" fill="#ff0000" filter="url(#s)"/></svg>');

  Assert.AreEqual(255, AlphaAt(Raster, 35, 35), 'The shape itself is still solid');
  Assert.IsTrue(AlphaAt(Raster, 54, 54) > 0, 'The shadow falls below and to the right');
  Assert.AreEqual(0, AlphaAt(Raster, 5, 5), 'Away from both, nothing is drawn');
end;

procedure TNativeSvgRasterizerTests.Rasterize_Use_DrawsWhatItPointsAtWhereItStands;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="40" viewBox="0 0 80 40">' +
    '<defs><rect id="box" x="0" y="0" width="10" height="10" fill="#ff0000"/></defs>' +
    '<use href="#box" x="5" y="5"/><use href="#box" x="50" y="20"/></svg>');

  Assert.AreEqual(255, AlphaAt(Raster, 10, 10), 'The first copy stands where it was placed');
  Assert.AreEqual(255, AlphaAt(Raster, 55, 25), 'And so does the second');
  Assert.AreEqual(0, AlphaAt(Raster, 30, 30), 'Between them nothing is drawn');
end;

// A mask is drawn like any other picture; how bright it is decides how much of
// what it masks survives.
procedure TNativeSvgRasterizerTests.Rasterize_Mask_LetsThroughWhatIsBrightInIt;
begin
  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="60" height="40" viewBox="0 0 60 40">' +
    '<defs><mask id="m">' +
    '<rect x="0" y="0" width="30" height="40" fill="#000000"/>' +
    '<rect x="30" y="0" width="30" height="40" fill="#ffffff"/>' +
    '</mask></defs>' +
    '<rect x="0" y="0" width="60" height="40" fill="#ff0000" mask="url(#m)"/></svg>');

  Assert.AreEqual(0, AlphaAt(Raster, 10, 20), 'Where the mask is black nothing comes through');
  Assert.AreEqual(255, AlphaAt(Raster, 50, 20), 'Where it is white everything does');
end;

procedure TNativeSvgRasterizerTests.Rasterize_Text_PutsInkOnTheBaseline;
begin
  if not TMarkdownGlyphSupport.IsAvailable then
    Assert.Pass('No glyph outliner on this platform');

  const Raster = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="40" viewBox="0 0 120 40">' +
    '<text x="10" y="30" font-family="Verdana" font-size="24" fill="#ff0000">Hi</text></svg>');

  var Ink := 0;
  for var Y := 0 to Raster.Height - 1 do
  begin
    for var X := 0 to Raster.Width - 1 do
    begin
      if AlphaAt(Raster, X, Y) > 0 then
        Inc(Ink);
    end;
  end;

  Assert.IsTrue(Ink > 40, Format('Expected letters to leave ink but found %d covered pixels', [Ink]));
  Assert.AreEqual(0, AlphaAt(Raster, 110, 5), 'Beyond the text nothing is drawn');
end;

// Font properties are inherited, and a badge sets them on the group around its
// text rather than on the text itself.
procedure TNativeSvgRasterizerTests.Rasterize_TextInheritingFromItsGroup_IsDrawnAtThatSize;
begin
  if not TMarkdownGlyphSupport.IsAvailable then
    Assert.Pass('No glyph outliner on this platform');

  const Small = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="60" viewBox="0 0 120 60">' +
    '<g font-family="Verdana" font-size="10" fill="#000000"><text x="10" y="40">Hi</text></g></svg>');
  const Large = Rasterize('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="60" viewBox="0 0 120 60">' +
    '<g font-family="Verdana" font-size="30" fill="#000000"><text x="10" y="40">Hi</text></g></svg>');

  var SmallInk := 0;
  var LargeInk := 0;
  for var Y := 0 to Small.Height - 1 do
  begin
    for var X := 0 to Small.Width - 1 do
    begin
      if AlphaAt(Small, X, Y) > 0 then
        Inc(SmallInk);
      if AlphaAt(Large, X, Y) > 0 then
        Inc(LargeInk);
    end;
  end;

  Assert.IsTrue(SmallInk > 0, 'The inherited size still draws');
  Assert.IsTrue(LargeInk > SmallInk * 2, Format('Three times the size must cover far more than %d pixels',
    [SmallInk]));
end;

end.
