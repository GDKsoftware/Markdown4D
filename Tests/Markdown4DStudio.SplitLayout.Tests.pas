unit Markdown4DStudio.SplitLayout.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4DStudio.SplitLayout;

type
  [TestFixture]
  TPadSplitLayoutTests = class
  private
    const
      // A pane narrower than this is not worth showing, so the split always
      // leaves at least this much for each side.
      MinPane = 300;

  public
    [Test]
    procedure ClampEditorWidth_SavedWidthLeavesRoomForBothPanes_KeepsSavedWidth;

    [Test]
    procedure ClampEditorWidth_SavedWidthWouldCollapsePreview_ReservesPreviewMinimum;

    [Test]
    procedure ClampEditorWidth_SavedWidthBelowMinimum_RaisesToMinimum;

    [Test]
    procedure ClampEditorWidth_AvailableTooSmallForTwoPanes_SplitsEvenly;

    [Test]
    procedure ClampEditorWidth_WidthSavedAtWiderWindow_StillShowsPreview;

    [Test]
    procedure ClampEditorWidth_NoAvailableWidth_ReturnsZero;

    [Test]
    procedure EffectiveMinPaneWidth_RoomForBothPanes_ReturnsRequestedMinimum;

    [Test]
    procedure EffectiveMinPaneWidth_NotEnoughRoom_ReturnsHalfOfWhatThereIs;

    [Test]
    procedure EffectiveMinPaneWidth_NoAvailableWidth_ReturnsZero;
  end;

implementation

procedure TPadSplitLayoutTests.ClampEditorWidth_SavedWidthLeavesRoomForBothPanes_KeepsSavedWidth;
begin
  // 480 for the editor leaves 480 for the preview, so nothing needs adjusting.
  const Width = TPadSplitLayout.ClampEditorWidth(480, 960, MinPane);

  Assert.AreEqual(480, Width);
end;

procedure TPadSplitLayoutTests.ClampEditorWidth_SavedWidthWouldCollapsePreview_ReservesPreviewMinimum;
begin
  // The editor asks for everything; the preview must still get its minimum.
  const Width = TPadSplitLayout.ClampEditorWidth(960, 960, MinPane);

  Assert.AreEqual(660, Width);
end;

procedure TPadSplitLayoutTests.ClampEditorWidth_SavedWidthBelowMinimum_RaisesToMinimum;
begin
  const Width = TPadSplitLayout.ClampEditorWidth(20, 960, MinPane);

  Assert.AreEqual(MinPane, Width);
end;

procedure TPadSplitLayoutTests.ClampEditorWidth_AvailableTooSmallForTwoPanes_SplitsEvenly;
begin
  // Below two minimums there is no way to honour both, so share what there is.
  const Width = TPadSplitLayout.ClampEditorWidth(500, 500, MinPane);

  Assert.AreEqual(250, Width);
end;

procedure TPadSplitLayoutTests.ClampEditorWidth_WidthSavedAtWiderWindow_StillShowsPreview;
begin
  // Regression for the collapsing split view: an editor width remembered at a
  // 1200 wide window is applied after the window shrinks to 900. Unclamped it
  // swallowed the whole area and the preview disappeared, which made split view
  // look exactly like editor only.
  const Width = TPadSplitLayout.ClampEditorWidth(838, 650, MinPane);

  Assert.AreEqual(350, Width);
  Assert.IsTrue(650 - Width >= MinPane, 'preview pane must keep its minimum width');
end;

procedure TPadSplitLayoutTests.ClampEditorWidth_NoAvailableWidth_ReturnsZero;
begin
  // A window too small to lay out at all must not produce a negative width.
  const Width = TPadSplitLayout.ClampEditorWidth(480, 0, MinPane);

  Assert.AreEqual(0, Width);
end;

procedure TPadSplitLayoutTests.EffectiveMinPaneWidth_RoomForBothPanes_ReturnsRequestedMinimum;
begin
  Assert.AreEqual(MinPane, TPadSplitLayout.EffectiveMinPaneWidth(960, MinPane));
end;

procedure TPadSplitLayoutTests.EffectiveMinPaneWidth_NotEnoughRoom_ReturnsHalfOfWhatThereIs;
begin
  // A splitter cannot be asked to honour a minimum the window cannot give, or a
  // drag ends up handing the whole area to one pane.
  Assert.AreEqual(250, TPadSplitLayout.EffectiveMinPaneWidth(500, MinPane));
  Assert.AreEqual(224, TPadSplitLayout.EffectiveMinPaneWidth(448, MinPane));
end;

procedure TPadSplitLayoutTests.EffectiveMinPaneWidth_NoAvailableWidth_ReturnsZero;
begin
  Assert.AreEqual(0, TPadSplitLayout.EffectiveMinPaneWidth(0, MinPane));
end;

end.
