unit Markdown4D.Viewer.Clicks.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Viewer.Clicks;

type
  [TestFixture]
  TMarkdownClickCounterTests = class
  private
    const
      StartTime = 1000;
      Interval = 500;
      Tolerance = 2.0;
      PressX = 40.0;
      PressY = 20.0;
    var
      FCounter: TMarkdownClickCounter;
    function Press(const TimeMilliseconds: Int64; const X: Single; const IsDoubleClick: Boolean): Integer;

  public
    [Setup]
    procedure Setup;

    [Test]
    procedure RegisterPress_PlainPress_CountsSingleClick;

    [Test]
    procedure RegisterPress_PlatformDoubleClick_CountsDoubleClick;

    [Test]
    [TestCase('PlainThirdPress', 'False')]
    [TestCase('ThirdPressReportedAsDouble', 'True')]
    procedure RegisterPress_SoonAfterDoubleClick_CountsTripleClick(const IsDoubleClick: Boolean);

    [Test]
    procedure RegisterPress_AfterIntervalPassed_CountsSingleClick;

    [Test]
    procedure RegisterPress_AwayFromDoubleClick_CountsSingleClick;

    [Test]
    procedure RegisterPress_AfterTripleClick_StartsOver;
  end;

  [TestFixture]
  TMarkdownClickGestureTests = class
  private
    const
      PressX = 40.0;
      PressY = 20.0;
      DragThreshold = 5.0;
    var
      FGesture: TMarkdownClickGesture;
    function ReleaseAt(const X: Single): TMarkdownClickKind;

  public
    [Setup]
    procedure Setup;

    [Test]
    [TestCase('SingleClick', '1,Click')]
    [TestCase('DoubleClick', '2,DoubleClick')]
    [TestCase('TripleClick', '3,Click')]
    procedure Release_AfterPressInText_ReportsKindByClickCount(const ClickCount: Integer;
                                                                 const Expected: TMarkdownClickKind);

    [Test]
    [TestCase('WithinThreshold', '5,Click')]
    [TestCase('PastThreshold', '6,None')]
    procedure Release_AfterMove_IsClickOnlyWithinDragThreshold(const Distance: Single;
                                                                 const Expected: TMarkdownClickKind);

    [Test]
    procedure Release_AfterPressElsewhere_IsNone;

    [Test]
    procedure Release_Twice_ReportsOnlyOnce;
  end;

implementation

procedure TMarkdownClickCounterTests.Setup;
begin
  FCounter := Default(TMarkdownClickCounter);
end;

function TMarkdownClickCounterTests.Press(const TimeMilliseconds: Int64; const X: Single;
  const IsDoubleClick: Boolean): Integer;
begin
  Result := FCounter.RegisterPress(TimeMilliseconds, X, PressY, IsDoubleClick, Interval, Tolerance);
end;

procedure TMarkdownClickCounterTests.RegisterPress_PlainPress_CountsSingleClick;
begin
  const Count = Press(StartTime, PressX, False);

  Assert.AreEqual(TMarkdownClickCounter.SingleClick, Count);
end;

procedure TMarkdownClickCounterTests.RegisterPress_PlatformDoubleClick_CountsDoubleClick;
begin
  Press(StartTime, PressX, False);

  const Count = Press(StartTime + 100, PressX, True);

  Assert.AreEqual(TMarkdownClickCounter.DoubleClick, Count);
end;

procedure TMarkdownClickCounterTests.RegisterPress_SoonAfterDoubleClick_CountsTripleClick(
  const IsDoubleClick: Boolean);
begin
  Press(StartTime, PressX, False);
  Press(StartTime + 100, PressX, True);

  const Count = Press(StartTime + 200, PressX + 1, IsDoubleClick);

  Assert.AreEqual(TMarkdownClickCounter.TripleClick, Count);
end;

procedure TMarkdownClickCounterTests.RegisterPress_AfterIntervalPassed_CountsSingleClick;
begin
  Press(StartTime, PressX, False);
  Press(StartTime + 100, PressX, True);

  const Count = Press(StartTime + 100 + Interval + 1, PressX, False);

  Assert.AreEqual(TMarkdownClickCounter.SingleClick, Count);
end;

procedure TMarkdownClickCounterTests.RegisterPress_AwayFromDoubleClick_CountsSingleClick;
begin
  Press(StartTime, PressX, False);
  Press(StartTime + 100, PressX, True);

  const Count = Press(StartTime + 200, PressX + Tolerance + 1, False);

  Assert.AreEqual(TMarkdownClickCounter.SingleClick, Count);
end;

procedure TMarkdownClickCounterTests.RegisterPress_AfterTripleClick_StartsOver;
begin
  Press(StartTime, PressX, False);
  Press(StartTime + 100, PressX, True);
  Press(StartTime + 200, PressX, False);

  const Count = Press(StartTime + 300, PressX, False);

  Assert.AreEqual(TMarkdownClickCounter.SingleClick, Count);
end;

procedure TMarkdownClickGestureTests.Setup;
begin
  FGesture := Default(TMarkdownClickGesture);
end;

function TMarkdownClickGestureTests.ReleaseAt(const X: Single): TMarkdownClickKind;
begin
  Result := FGesture.Release(X, PressY, DragThreshold);
end;

procedure TMarkdownClickGestureTests.Release_AfterPressInText_ReportsKindByClickCount(const ClickCount: Integer;
  const Expected: TMarkdownClickKind);
begin
  FGesture.PressInText(PressX, PressY, ClickCount);

  const Actual = ReleaseAt(PressX);

  Assert.AreEqual<TMarkdownClickKind>(Expected, Actual);
end;

procedure TMarkdownClickGestureTests.Release_AfterMove_IsClickOnlyWithinDragThreshold(const Distance: Single;
  const Expected: TMarkdownClickKind);
begin
  FGesture.PressInText(PressX, PressY, TMarkdownClickCounter.SingleClick);

  const Actual = ReleaseAt(PressX + Distance);

  Assert.AreEqual<TMarkdownClickKind>(Expected, Actual);
end;

procedure TMarkdownClickGestureTests.Release_AfterPressElsewhere_IsNone;
begin
  FGesture.PressInText(PressX, PressY, TMarkdownClickCounter.SingleClick);
  FGesture.PressElsewhere;

  const Actual = ReleaseAt(PressX);

  Assert.AreEqual<TMarkdownClickKind>(TMarkdownClickKind.None, Actual);
end;

procedure TMarkdownClickGestureTests.Release_Twice_ReportsOnlyOnce;
begin
  FGesture.PressInText(PressX, PressY, TMarkdownClickCounter.SingleClick);
  ReleaseAt(PressX);

  const Actual = ReleaseAt(PressX);

  Assert.AreEqual<TMarkdownClickKind>(TMarkdownClickKind.None, Actual);
end;

end.