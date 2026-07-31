unit Markdown4D.Image.Filters.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownRasterFiltersTests = class
  private
    const
      Size = 21;
      Centre = 10;
      OpaqueRed = $FFFF0000;
      HalfBlack = $80000000;

  public
    [Test]
    procedure Blurred_SolidSquare_ReachesPastItsEdge;

    [Test]
    procedure Blurred_WithoutDeviation_LeavesThePixelsAlone;

    [Test]
    procedure Offset_MovesCoverageAndLeavesNothingBehind;

    [Test]
    procedure Flooded_FillsEveryPixelWithOneColour;

    [Test]
    procedure Flooded_TranslucentColour_StaysPremultiplied;

    [Test]
    procedure Over_OpaqueTop_HidesWhatIsUnderIt;

    [Test]
    procedure Over_EmptyTop_LeavesWhatIsUnderItStanding;

    [Test]
    procedure InsideOf_KeepsColourOnlyWhereTheShapeIs;

    [Test]
    procedure LuminanceMask_IsBrightForWhiteAndDarkForBlack;

    [Test]
    procedure AlphaMask_FollowsTheCoverage;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Image.Rasterizer,
  Markdown4D.Image.Filters;

function Square(const Left, Top, Right, Bottom: Single): TArray<TLayoutPointF>;
begin
  Result := [TLayoutPointF.Create(Left, Top), TLayoutPointF.Create(Right, Top),
    TLayoutPointF.Create(Right, Bottom), TLayoutPointF.Create(Left, Bottom)];
end;

function AlphaAt(const Raster: TMarkdownPixelRaster; const X, Y: Integer): Integer;
begin
  Result := Raster.Pixels[(Y * Raster.Width + X) * 4 + 3];
end;

function RedAt(const Raster: TMarkdownPixelRaster; const X, Y: Integer): Integer;
begin
  Result := Raster.Pixels[(Y * Raster.Width + X) * 4 + 2];
end;

procedure TMarkdownRasterFiltersTests.Blurred_SolidSquare_ReachesPastItsEdge;
begin
  const Source = TMarkdownPolygonRasterizer.Fill(Square(7, 7, 14, 14), OpaqueRed, Size, Size);

  Assert.AreEqual(0, AlphaAt(Source, 4, Centre), 'The square stops short of this pixel');

  const Blurred = TMarkdownRasterFilters.Blurred(Source, 2, 2);

  Assert.IsTrue(AlphaAt(Blurred, 4, Centre) > 0, 'A blur reaches past the edge');
  Assert.IsTrue(AlphaAt(Blurred, 7, Centre) < 255, 'And thins out the edge it used to cover solidly');
  Assert.IsTrue(AlphaAt(Blurred, Centre, Centre) > AlphaAt(Blurred, 4, Centre),
    'The middle stays heavier than the fringe');
end;

procedure TMarkdownRasterFiltersTests.Blurred_WithoutDeviation_LeavesThePixelsAlone;
begin
  const Source = TMarkdownPolygonRasterizer.Fill(Square(7, 7, 14, 14), OpaqueRed, Size, Size);
  const Blurred = TMarkdownRasterFilters.Blurred(Source, 0, 0);

  Assert.AreEqual(AlphaAt(Source, Centre, Centre), AlphaAt(Blurred, Centre, Centre));
  Assert.AreEqual(AlphaAt(Source, 4, Centre), AlphaAt(Blurred, 4, Centre));
end;

procedure TMarkdownRasterFiltersTests.Offset_MovesCoverageAndLeavesNothingBehind;
begin
  const Source = TMarkdownPolygonRasterizer.Fill(Square(2, 2, 6, 6), OpaqueRed, Size, Size);
  const Moved = TMarkdownRasterFilters.Offset(Source, 8, 4);

  Assert.AreEqual(255, AlphaAt(Source, 4, 4), 'The square starts here');
  Assert.AreEqual(255, AlphaAt(Moved, 12, 8), 'And arrives here');
  Assert.AreEqual(0, AlphaAt(Moved, 4, 4), 'Leaving nothing where it was');
end;

procedure TMarkdownRasterFiltersTests.Flooded_FillsEveryPixelWithOneColour;
begin
  const Flooded = TMarkdownRasterFilters.Flooded(Size, Size, OpaqueRed);

  Assert.AreEqual(255, AlphaAt(Flooded, 0, 0), 'The corner is filled');
  Assert.AreEqual(255, AlphaAt(Flooded, Centre, Centre), 'And so is the middle');
  Assert.AreEqual(255, RedAt(Flooded, Centre, Centre), 'In the colour it was given');
end;

// A premultiplied pixel never carries more colour than it carries coverage.
procedure TMarkdownRasterFiltersTests.Flooded_TranslucentColour_StaysPremultiplied;
begin
  const Flooded = TMarkdownRasterFilters.Flooded(Size, Size, HalfBlack);
  const Alpha = AlphaAt(Flooded, Centre, Centre);

  Assert.IsTrue(Abs(Alpha - 128) <= 1, Format('Expected about half coverage but found %d', [Alpha]));
  Assert.IsTrue(RedAt(Flooded, Centre, Centre) <= Alpha, 'Black stays black at any coverage');
end;

procedure TMarkdownRasterFiltersTests.Over_OpaqueTop_HidesWhatIsUnderIt;
begin
  const Bottom = TMarkdownRasterFilters.Flooded(Size, Size, HalfBlack);
  const Top = TMarkdownRasterFilters.Flooded(Size, Size, OpaqueRed);

  const Result = TMarkdownRasterFilters.Over(Top, Bottom);

  Assert.AreEqual(255, AlphaAt(Result, Centre, Centre));
  Assert.AreEqual(255, RedAt(Result, Centre, Centre), 'Nothing of the layer beneath shows through');
end;

procedure TMarkdownRasterFiltersTests.Over_EmptyTop_LeavesWhatIsUnderItStanding;
begin
  const Bottom = TMarkdownRasterFilters.Flooded(Size, Size, OpaqueRed);
  const Top = TMarkdownPixelRaster.Create(Size, Size);

  const Result = TMarkdownRasterFilters.Over(Top, Bottom);

  Assert.AreEqual(255, AlphaAt(Result, Centre, Centre), 'What was there survives');
  Assert.AreEqual(255, RedAt(Result, Centre, Centre));
end;

// This is how a flood is cut down to the shape it is meant to colour.
procedure TMarkdownRasterFiltersTests.InsideOf_KeepsColourOnlyWhereTheShapeIs;
begin
  const Colour = TMarkdownRasterFilters.Flooded(Size, Size, OpaqueRed);
  const Shape = TMarkdownPolygonRasterizer.Fill(Square(7, 7, 14, 14), $FF000000, Size, Size);

  const Result = TMarkdownRasterFilters.InsideOf(Colour, Shape);

  Assert.AreEqual(255, AlphaAt(Result, Centre, Centre), 'Inside the shape the colour stands');
  Assert.AreEqual(0, AlphaAt(Result, 2, 2), 'Outside it there is nothing left');
end;

procedure TMarkdownRasterFiltersTests.LuminanceMask_IsBrightForWhiteAndDarkForBlack;
begin
  const White = TMarkdownRasterFilters.Flooded(Size, Size, $FFFFFFFF);
  const Black = TMarkdownRasterFilters.Flooded(Size, Size, $FF000000);

  const Bright = TMarkdownRasterFilters.LuminanceMask(White);
  const Dark = TMarkdownRasterFilters.LuminanceMask(Black);

  Assert.IsTrue(Bright[Centre * Size + Centre] >= 250, 'White lets everything through');
  Assert.AreEqual(0, Integer(Dark[Centre * Size + Centre]), 'Black lets nothing through');
end;

procedure TMarkdownRasterFiltersTests.AlphaMask_FollowsTheCoverage;
begin
  const Source = TMarkdownPolygonRasterizer.Fill(Square(7, 7, 14, 14), OpaqueRed, Size, Size);
  const Mask = TMarkdownRasterFilters.AlphaMask(Source);

  Assert.AreEqual(255, Integer(Mask[Centre * Size + Centre]), 'Covered where the square is');
  Assert.AreEqual(0, Integer(Mask[2 * Size + 2]), 'And empty where it is not');
end;

end.
