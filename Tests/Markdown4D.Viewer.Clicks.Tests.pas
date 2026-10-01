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

end.
