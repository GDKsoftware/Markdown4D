unit MarkdownPad.TabStrip.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.UITypes,
  MarkdownPad.TabStrip.Layout,
  MarkdownPad.TabStrip.Interaction;

type
  [TestFixture]
  TPadTabStripGeometryTests = class
  private
    const
      WideStrip = 1000;
      NarrowStrip = 300;
  public
    [Test]
    procedure ComputeTabWidth_FewTabs_ClampsToMaximum;

    [Test]
    procedure ComputeTabWidth_ManyTabs_ClampsToMinimum;

    [Test]
    procedure ComputeTabWidth_NoTabs_ReturnsZero;

    [Test]
    procedure ContentWidth_FewTabs_LeavesTrailingSpace;

    [Test]
    procedure ContentWidth_ManyTabs_CapsAtAvailable;

    [Test]
    procedure HitTest_LeftOfFirstTab_ReturnsFirstTab;

    [Test]
    procedure HitTest_CloseRegion_ReturnsClose;

    [Test]
    procedure HitTest_SecondTabBody_ReturnsSecondTab;

    [Test]
    procedure HitTest_PlusRegion_ReturnsPlus;

    [Test]
    procedure HitTest_PastContent_ReturnsNone;

    [Test]
    procedure HitTest_NoTabs_ReturnsNone;
  end;

  [TestFixture]
  TPadTabInteractionTests = class
  private
    const
      Strip = 1000;
      TabCount = 2;
    var
      FInteraction: TPadTabInteraction;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure BeginPress_LeftOnTabBody_RequestsSelect;

    [Test]
    procedure BeginPress_MiddleOnTab_RequestsClose;

    [Test]
    procedure BeginPress_LeftOnCloseGlyph_DoesNotSelect;

    [Test]
    procedure EndPress_ReleasedOnCloseGlyph_RequestsClose;

    [Test]
    procedure EndPress_ReleasedOnPlus_RequestsAdd;

    [Test]
    procedure EndPress_ReleasedOnTabBody_DoesNothing;

    [Test]
    procedure PointerMove_HoverChanges_RequestsRepaintOnce;

    [Test]
    procedure PointerMove_DragBeyondThreshold_RequestsReorder;

    [Test]
    procedure PointerMove_WithinThreshold_DoesNotReorder;

    [Test]
    procedure DoubleClickClose_OnTabBody_RequestsClose;

    [Test]
    procedure DoubleClickClose_OnCloseGlyph_DoesNothing;

    [Test]
    procedure ClearHover_AfterHover_RequestsRepaintThenSettles;
  end;

implementation

procedure TPadTabStripGeometryTests.ComputeTabWidth_FewTabs_ClampsToMaximum;
begin
  const Width = TPadTabLayout.ComputeTabWidth(WideStrip, 2);

  Assert.AreEqual(TPadTabLayout.MaxTabWidth, Width);
end;

procedure TPadTabStripGeometryTests.ComputeTabWidth_ManyTabs_ClampsToMinimum;
begin
  const Width = TPadTabLayout.ComputeTabWidth(NarrowStrip, 20);

  Assert.AreEqual(TPadTabLayout.MinTabWidth, Width);
end;

procedure TPadTabStripGeometryTests.ComputeTabWidth_NoTabs_ReturnsZero;
begin
  Assert.AreEqual(0, TPadTabLayout.ComputeTabWidth(WideStrip, 0));
end;

procedure TPadTabStripGeometryTests.ContentWidth_FewTabs_LeavesTrailingSpace;
begin
  const TabWidth = TPadTabLayout.ComputeTabWidth(WideStrip, 2);
  const Content = TPadTabLayout.ContentWidthFor(WideStrip, 2, TabWidth);

  Assert.AreEqual(2 * TPadTabLayout.MaxTabWidth + TPadTabLayout.PlusButtonWidth, Content);
  Assert.IsTrue(Content < WideStrip);
end;

procedure TPadTabStripGeometryTests.ContentWidth_ManyTabs_CapsAtAvailable;
begin
  const TabWidth = TPadTabLayout.ComputeTabWidth(NarrowStrip, 20);
  const Content = TPadTabLayout.ContentWidthFor(NarrowStrip, 20, TabWidth);

  Assert.AreEqual(NarrowStrip, Content);
end;

procedure TPadTabStripGeometryTests.HitTest_LeftOfFirstTab_ReturnsFirstTab;
begin
  const Hit = TPadTabLayout.HitTest(10, WideStrip, 2);

  Assert.AreEqual(Ord(TPadTabHitKind.Tab), Ord(Hit.Kind));
  Assert.AreEqual(0, Hit.Index);
end;

procedure TPadTabStripGeometryTests.HitTest_CloseRegion_ReturnsClose;
begin
  // Tab 0 spans 0..240; close box sits at 240-8-16 .. 240-8 = 216..232.
  const Hit = TPadTabLayout.HitTest(220, WideStrip, 2);

  Assert.AreEqual(Ord(TPadTabHitKind.Close), Ord(Hit.Kind));
  Assert.AreEqual(0, Hit.Index);
end;

procedure TPadTabStripGeometryTests.HitTest_SecondTabBody_ReturnsSecondTab;
begin
  const Hit = TPadTabLayout.HitTest(300, WideStrip, 2);

  Assert.AreEqual(Ord(TPadTabHitKind.Tab), Ord(Hit.Kind));
  Assert.AreEqual(1, Hit.Index);
end;

procedure TPadTabStripGeometryTests.HitTest_PlusRegion_ReturnsPlus;
begin
  // Content = 2*240 + 34 = 514; plus spans 480..514.
  const Hit = TPadTabLayout.HitTest(490, WideStrip, 2);

  Assert.AreEqual(Ord(TPadTabHitKind.Plus), Ord(Hit.Kind));
end;

procedure TPadTabStripGeometryTests.HitTest_PastContent_ReturnsNone;
begin
  const Hit = TPadTabLayout.HitTest(600, WideStrip, 2);

  Assert.AreEqual(Ord(TPadTabHitKind.None), Ord(Hit.Kind));
end;

procedure TPadTabStripGeometryTests.HitTest_NoTabs_ReturnsNone;
begin
  const Hit = TPadTabLayout.HitTest(10, WideStrip, 0);

  Assert.AreEqual(Ord(TPadTabHitKind.None), Ord(Hit.Kind));
end;

procedure TPadTabInteractionTests.Setup;
begin
  FInteraction.Reset;
end;

procedure TPadTabInteractionTests.BeginPress_LeftOnTabBody_RequestsSelect;
begin
  const PointerResult = FInteraction.BeginPress(10, Strip, TabCount, TMouseButton.mbLeft);

  Assert.IsTrue(PointerResult.Select);
  Assert.AreEqual(0, PointerResult.SelectIndex);
end;

procedure TPadTabInteractionTests.BeginPress_MiddleOnTab_RequestsClose;
begin
  const PointerResult = FInteraction.BeginPress(10, Strip, TabCount, TMouseButton.mbMiddle);

  Assert.IsTrue(PointerResult.Close);
  Assert.AreEqual(0, PointerResult.CloseIndex);
end;

procedure TPadTabInteractionTests.BeginPress_LeftOnCloseGlyph_DoesNotSelect;
begin
  // Tab 0 close box sits around x=216..232; pressing it must not select the tab.
  const PointerResult = FInteraction.BeginPress(220, Strip, TabCount, TMouseButton.mbLeft);

  Assert.IsFalse(PointerResult.Select);
end;

procedure TPadTabInteractionTests.EndPress_ReleasedOnCloseGlyph_RequestsClose;
begin
  FInteraction.BeginPress(220, Strip, TabCount, TMouseButton.mbLeft);

  const PointerResult = FInteraction.EndPress(220, Strip, TabCount, TMouseButton.mbLeft);

  Assert.IsTrue(PointerResult.Close);
  Assert.AreEqual(0, PointerResult.CloseIndex);
end;

procedure TPadTabInteractionTests.EndPress_ReleasedOnPlus_RequestsAdd;
begin
  FInteraction.BeginPress(490, Strip, TabCount, TMouseButton.mbLeft);

  const PointerResult = FInteraction.EndPress(490, Strip, TabCount, TMouseButton.mbLeft);

  Assert.IsTrue(PointerResult.Add);
end;

procedure TPadTabInteractionTests.EndPress_ReleasedOnTabBody_DoesNothing;
begin
  FInteraction.BeginPress(10, Strip, TabCount, TMouseButton.mbLeft);

  const PointerResult = FInteraction.EndPress(10, Strip, TabCount, TMouseButton.mbLeft);

  Assert.IsFalse(PointerResult.Close);
  Assert.IsFalse(PointerResult.Add);
end;

procedure TPadTabInteractionTests.PointerMove_HoverChanges_RequestsRepaintOnce;
begin
  const First = FInteraction.PointerMove(10, Strip, TabCount, False);
  const Second = FInteraction.PointerMove(15, Strip, TabCount, False);

  Assert.IsTrue(First.RepaintNeeded, 'Entering a tab should request a repaint');
  Assert.IsFalse(Second.RepaintNeeded, 'Staying on the same region should not repaint again');
end;

procedure TPadTabInteractionTests.PointerMove_DragBeyondThreshold_RequestsReorder;
begin
  FInteraction.BeginPress(10, Strip, TabCount, TMouseButton.mbLeft);

  const PointerResult = FInteraction.PointerMove(300, Strip, TabCount, True);

  Assert.IsTrue(PointerResult.Reorder);
  Assert.AreEqual(0, PointerResult.ReorderFrom);
  Assert.AreEqual(1, PointerResult.ReorderTo);
end;

procedure TPadTabInteractionTests.PointerMove_WithinThreshold_DoesNotReorder;
begin
  FInteraction.BeginPress(10, Strip, TabCount, TMouseButton.mbLeft);

  const PointerResult = FInteraction.PointerMove(13, Strip, TabCount, True);

  Assert.IsFalse(PointerResult.Reorder);
end;

procedure TPadTabInteractionTests.DoubleClickClose_OnTabBody_RequestsClose;
begin
  const PointerResult = FInteraction.DoubleClickClose(10, Strip, TabCount);

  Assert.IsTrue(PointerResult.Close);
  Assert.AreEqual(0, PointerResult.CloseIndex);
end;

procedure TPadTabInteractionTests.DoubleClickClose_OnCloseGlyph_DoesNothing;
begin
  const PointerResult = FInteraction.DoubleClickClose(220, Strip, TabCount);

  Assert.IsFalse(PointerResult.Close);
end;

procedure TPadTabInteractionTests.ClearHover_AfterHover_RequestsRepaintThenSettles;
begin
  FInteraction.PointerMove(10, Strip, TabCount, False);

  Assert.IsTrue(FInteraction.ClearHover, 'Clearing an active hover should request a repaint');
  Assert.IsFalse(FInteraction.ClearHover, 'A second clear with no hover should be a no-op');
end;

end.
