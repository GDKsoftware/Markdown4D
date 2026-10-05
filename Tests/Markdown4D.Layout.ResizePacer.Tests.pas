unit Markdown4D.Layout.ResizePacer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.ResizePacer;

type
  [TestFixture]
  TMarkdownResizePacerTests = class
  private
    const
      StartTime = 1000;
      QuickLayoutMilliseconds = 10;
      SlowLayoutMilliseconds = 100;
    var
      FPacer: TMarkdownResizePacer;

  public
    [Setup]
    procedure Setup;

    [Test]
    procedure TryReflowNow_AfterQuickLayout_ReflowsLive;

    [Test]
    procedure TryReflowNow_AfterSlowLayout_Waits;

    [Test]
    procedure TryFlush_BeforeTheWidthSettles_Waits;

    [Test]
    procedure TryFlush_OnceTheWidthSettles_ReflowsOnce;

    [Test]
    procedure TryFlush_EveryWidthChange_RestartsTheWait;

    [Test]
    procedure TryFlush_WithoutAWaitingChange_DoesNothing;

    [Test]
    procedure TryFlush_WhileThePointerIsHeld_Waits;
  end;

implementation

procedure TMarkdownResizePacerTests.Setup;
begin
  FPacer := Default(TMarkdownResizePacer);
end;

procedure TMarkdownResizePacerTests.TryReflowNow_AfterQuickLayout_ReflowsLive;
begin
  const ReflowsNow = FPacer.TryReflowNow(StartTime, QuickLayoutMilliseconds);

  Assert.IsTrue(ReflowsNow);
  Assert.IsFalse(FPacer.IsWaiting);
end;

procedure TMarkdownResizePacerTests.TryReflowNow_AfterSlowLayout_Waits;
begin
  const ReflowsNow = FPacer.TryReflowNow(StartTime, SlowLayoutMilliseconds);

  Assert.IsFalse(ReflowsNow);
  Assert.IsTrue(FPacer.IsWaiting);
end;

procedure TMarkdownResizePacerTests.TryFlush_BeforeTheWidthSettles_Waits;
begin
  FPacer.TryReflowNow(StartTime, SlowLayoutMilliseconds);

  const Flushed = FPacer.TryFlush(StartTime + TMarkdownResizePacer.SettleMilliseconds - 1, False);

  Assert.IsFalse(Flushed);
end;

procedure TMarkdownResizePacerTests.TryFlush_OnceTheWidthSettles_ReflowsOnce;
begin
  FPacer.TryReflowNow(StartTime, SlowLayoutMilliseconds);

  const FirstFlush = FPacer.TryFlush(StartTime + TMarkdownResizePacer.SettleMilliseconds, False);
  const SecondFlush = FPacer.TryFlush(StartTime + 2 * TMarkdownResizePacer.SettleMilliseconds, False);

  Assert.IsTrue(FirstFlush);
  Assert.IsFalse(SecondFlush);
end;

procedure TMarkdownResizePacerTests.TryFlush_EveryWidthChange_RestartsTheWait;
begin
  FPacer.TryReflowNow(StartTime, SlowLayoutMilliseconds);
  const LaterChange = StartTime + TMarkdownResizePacer.SettleMilliseconds - 1;
  FPacer.TryReflowNow(LaterChange, SlowLayoutMilliseconds);

  const Flushed = FPacer.TryFlush(StartTime + TMarkdownResizePacer.SettleMilliseconds, False);

  Assert.IsFalse(Flushed, 'A width that is still changing is not settled');
end;

procedure TMarkdownResizePacerTests.TryFlush_WithoutAWaitingChange_DoesNothing;
begin
  const Flushed = FPacer.TryFlush(StartTime, False);

  Assert.IsFalse(Flushed);
end;

procedure TMarkdownResizePacerTests.TryFlush_WhileThePointerIsHeld_Waits;
begin
  FPacer.TryReflowNow(StartTime, SlowLayoutMilliseconds);
  const Settled = StartTime + TMarkdownResizePacer.SettleMilliseconds;

  const FlushedWhileHeld = FPacer.TryFlush(Settled, True);
  const FlushedOnRelease = FPacer.TryFlush(Settled + 1, False);

  Assert.IsFalse(FlushedWhileHeld, 'A splitter that is still held is not settled, however long it rests');
  Assert.IsTrue(FlushedOnRelease);
end;

end.