unit Markdown4D.AutoScroll.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.AutoScroll;

type
  [TestFixture]
  TMarkdownAutoScrollTests = class
  private
    const
      StartTime = 1000;
      OriginX = 200.0;
      OriginY = 100.0;
      NormalScale = 1.0;
      // Four dead zones below the origin: Firefox scrolls 4^1.5 - 1 = 7 pixels per frame.
      FourZonesBelow = OriginY + 48;
      FourZonesAbove = OriginY - 48;
      SpeedAtFourZones = 7.0;
      SingleTolerance = 0.001;
    var
      FAutoScroll: TMarkdownAutoScroll;
    procedure StartAtOrigin(const Scale: Single);
    class procedure AssertSingle(const Expected, Actual: Single);

  public
    [Setup]
    procedure Setup;

    [Test]
    procedure Start_FromIdle_IsActive;

    [Test]
    procedure Step_WithinDeadZone_ScrollsNothing;

    [Test]
    [TestCase('Below', '148,7')]
    [TestCase('Above', '52,-7')]
    procedure Step_OneFrameAway_ScrollsByFirefoxCurve(const PointerY, Expected: Single);

    [Test]
    procedure Step_TwoFramesLater_ScrollsTwiceAsFar;

    [Test]
    procedure Step_AfterLongPause_ScrollsAtMostOneMaximumStep;

    [Test]
    procedure Step_AtDoubleScale_ScalesDeadZoneAndSpeed;

    [Test]
    procedure Step_WhenIdle_ScrollsNothing;

    [Test]
    [TestCase('InsideDeadZone', '105,Both')]
    [TestCase('Above', '52,Up')]
    [TestCase('Below', '148,Down')]
    procedure Direction_PointerPosition_ShowsWayToScroll(const PointerY: Single;
      const Expected: TMarkdownAutoScrollDirection);

    [Test]
    procedure Release_WithoutLeavingDeadZone_KeepsScrolling;

    [Test]
    procedure Release_AfterDraggingOut_Stops;

    [Test]
    procedure Release_WhileToggled_KeepsScrolling;

    [Test]
    procedure Stop_WhileScrolling_MakesIdle;
  end;

implementation

procedure TMarkdownAutoScrollTests.Setup;
begin
  FAutoScroll := Default(TMarkdownAutoScroll);
end;

procedure TMarkdownAutoScrollTests.StartAtOrigin(const Scale: Single);
begin
  FAutoScroll.Start(OriginX, OriginY, Scale, StartTime);
end;

class procedure TMarkdownAutoScrollTests.AssertSingle(const Expected, Actual: Single);
begin
  Assert.AreEqual(Double(Expected), Double(Actual), SingleTolerance);
end;

procedure TMarkdownAutoScrollTests.Start_FromIdle_IsActive;
begin
  StartAtOrigin(NormalScale);

  Assert.IsTrue(FAutoScroll.IsActive);
  Assert.AreEqual<TMarkdownAutoScrollState>(TMarkdownAutoScrollState.Pressed, FAutoScroll.State);
end;

procedure TMarkdownAutoScrollTests.Step_WithinDeadZone_ScrollsNothing;
begin
  StartAtOrigin(NormalScale);

  const Delta = FAutoScroll.Step(StartTime + TMarkdownAutoScroll.FrameMilliseconds, OriginY + 10);

  AssertSingle(0, Delta);
end;

procedure TMarkdownAutoScrollTests.Step_OneFrameAway_ScrollsByFirefoxCurve(const PointerY, Expected: Single);
begin
  StartAtOrigin(NormalScale);

  const Delta = FAutoScroll.Step(StartTime + TMarkdownAutoScroll.FrameMilliseconds, PointerY);

  AssertSingle(Expected, Delta);
end;

procedure TMarkdownAutoScrollTests.Step_TwoFramesLater_ScrollsTwiceAsFar;
begin
  StartAtOrigin(NormalScale);

  const Delta = FAutoScroll.Step(StartTime + 2 * TMarkdownAutoScroll.FrameMilliseconds, FourZonesBelow);

  AssertSingle(2 * SpeedAtFourZones, Delta);
end;

procedure TMarkdownAutoScrollTests.Step_AfterLongPause_ScrollsAtMostOneMaximumStep;
begin
  StartAtOrigin(NormalScale);

  const Delta = FAutoScroll.Step(StartTime + 10 * TMarkdownAutoScroll.MaxStepMilliseconds, FourZonesBelow);

  const MaxFrames = TMarkdownAutoScroll.MaxStepMilliseconds / TMarkdownAutoScroll.FrameMilliseconds;
  AssertSingle(MaxFrames * SpeedAtFourZones, Delta);
end;

procedure TMarkdownAutoScrollTests.Step_AtDoubleScale_ScalesDeadZoneAndSpeed;
begin
  const DoubleScale = 2.0;
  StartAtOrigin(DoubleScale);

  const Delta = FAutoScroll.Step(StartTime + TMarkdownAutoScroll.FrameMilliseconds, OriginY + 96);

  AssertSingle(DoubleScale * SpeedAtFourZones, Delta);
end;

procedure TMarkdownAutoScrollTests.Step_WhenIdle_ScrollsNothing;
begin
  const Delta = FAutoScroll.Step(StartTime, FourZonesBelow);

  AssertSingle(0, Delta);
end;

procedure TMarkdownAutoScrollTests.Direction_PointerPosition_ShowsWayToScroll(const PointerY: Single;
  const Expected: TMarkdownAutoScrollDirection);
begin
  StartAtOrigin(NormalScale);

  const Actual = FAutoScroll.Direction(PointerY);

  Assert.AreEqual<TMarkdownAutoScrollDirection>(Expected, Actual);
end;

procedure TMarkdownAutoScrollTests.Release_WithoutLeavingDeadZone_KeepsScrolling;
begin
  StartAtOrigin(NormalScale);
  FAutoScroll.PointerMoved(OriginX + 5, OriginY + 5);

  const Stopped = FAutoScroll.Release;

  Assert.IsFalse(Stopped);
  Assert.AreEqual<TMarkdownAutoScrollState>(TMarkdownAutoScrollState.Toggled, FAutoScroll.State);
end;

procedure TMarkdownAutoScrollTests.Release_AfterDraggingOut_Stops;
begin
  StartAtOrigin(NormalScale);
  FAutoScroll.PointerMoved(OriginX, FourZonesBelow);

  const Stopped = FAutoScroll.Release;

  Assert.IsTrue(Stopped);
  Assert.IsFalse(FAutoScroll.IsActive);
end;

procedure TMarkdownAutoScrollTests.Release_WhileToggled_KeepsScrolling;
begin
  StartAtOrigin(NormalScale);
  FAutoScroll.Release;
  FAutoScroll.PointerMoved(OriginX, FourZonesAbove);

  const Stopped = FAutoScroll.Release;

  Assert.IsFalse(Stopped);
  Assert.IsTrue(FAutoScroll.IsActive);
end;

procedure TMarkdownAutoScrollTests.Stop_WhileScrolling_MakesIdle;
begin
  StartAtOrigin(NormalScale);

  FAutoScroll.Stop;

  Assert.IsFalse(FAutoScroll.IsActive);
  Assert.AreEqual<TMarkdownAutoScrollState>(TMarkdownAutoScrollState.Idle, FAutoScroll.State);
end;

end.
