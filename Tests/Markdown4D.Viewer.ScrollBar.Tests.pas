unit Markdown4D.Viewer.ScrollBar.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownScrollBarGeometryTests = class
  private
    const
      ViewWidth = 400.0;
      ViewHeight = 100.0;
      FittingContent = 80.0;
      TallContent = 1000.0;
      MidOffset = 300.0;

  public
    [Test]
    procedure IsVisible_ContentFits_False;

    [Test]
    procedure IsVisible_ContentOverflows_True;

    [Test]
    procedure ThumbRect_AtTopOffset_StartsAtMargin;

    [Test]
    procedure ThumbRect_AtBottomOffset_EndsAtMargin;

    [Test]
    procedure ThumbRect_TallContent_ClampsToMinimumHeight;

    [Test]
    procedure OffsetForThumbTop_RoundTripsThroughThumbRect;
  end;

implementation

uses
  Markdown4D.Viewer.ScrollBar;

procedure TMarkdownScrollBarGeometryTests.IsVisible_ContentFits_False;
begin
  Assert.IsFalse(TMarkdownScrollBarGeometry.IsVisible(ViewHeight, FittingContent),
    'Content that fits needs no scrollbar');
end;

procedure TMarkdownScrollBarGeometryTests.IsVisible_ContentOverflows_True;
begin
  Assert.IsTrue(TMarkdownScrollBarGeometry.IsVisible(ViewHeight, TallContent),
    'Overflowing content needs a scrollbar');
end;

procedure TMarkdownScrollBarGeometryTests.ThumbRect_AtTopOffset_StartsAtMargin;
begin
  const Thumb = TMarkdownScrollBarGeometry.ThumbRect(ViewWidth, ViewHeight, TallContent, 0);

  Assert.AreEqual(Double(TMarkdownScrollBarGeometry.Margin), Double(Thumb.Top), 0.01);
  Assert.AreEqual(Double(ViewWidth - TMarkdownScrollBarGeometry.Margin), Double(Thumb.Right), 0.01);
end;

procedure TMarkdownScrollBarGeometryTests.ThumbRect_AtBottomOffset_EndsAtMargin;
begin
  const Thumb = TMarkdownScrollBarGeometry.ThumbRect(ViewWidth, ViewHeight, TallContent,
    TallContent - ViewHeight);

  Assert.AreEqual(Double(ViewHeight - TMarkdownScrollBarGeometry.Margin), Double(Thumb.Bottom), 0.01);
end;

procedure TMarkdownScrollBarGeometryTests.ThumbRect_TallContent_ClampsToMinimumHeight;
begin
  const Thumb = TMarkdownScrollBarGeometry.ThumbRect(ViewWidth, ViewHeight, TallContent, 0);

  Assert.AreEqual(Double(TMarkdownScrollBarGeometry.MinThumbHeight), Double(Thumb.Height), 0.01);
end;

procedure TMarkdownScrollBarGeometryTests.OffsetForThumbTop_RoundTripsThroughThumbRect;
begin
  const Thumb = TMarkdownScrollBarGeometry.ThumbRect(ViewWidth, ViewHeight, TallContent, MidOffset);
  const Restored = TMarkdownScrollBarGeometry.OffsetForThumbTop(ViewHeight, TallContent, Thumb.Top);

  Assert.AreEqual(Double(MidOffset), Double(Restored), 0.5);
end;

end.
