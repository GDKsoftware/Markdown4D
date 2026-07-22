unit MarkdownPad.TabStrip.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  MarkdownPad.TabStrip.Layout;

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

end.
