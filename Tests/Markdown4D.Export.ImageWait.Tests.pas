unit Markdown4D.Export.ImageWait.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownExportImageWaitTests = class
  private
    const
      GenerousTimeoutMilliseconds = 5000;
      ShortTimeoutMilliseconds = 50;
      PumpsUntilDone = 3;
      PumpSleepMilliseconds = 5;

  public
    [Test]
    procedure WaitUntil_AlreadyDone_ReturnsTrueWithoutPumping;

    [Test]
    procedure WaitUntil_DoneAfterPumping_ReturnsTrue;

    [Test]
    procedure WaitUntil_NeverDone_ReturnsFalseAfterTimeout;

    [Test]
    procedure WaitUntil_MissingPump_RaisesEMarkdownPdfExportError;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  Markdown4D.Export.ImageWait,
  Markdown4D.Export.Pdf.Errors;

procedure TMarkdownExportImageWaitTests.WaitUntil_AlreadyDone_ReturnsTrueWithoutPumping;
begin
  var PumpCount := 0;

  const IsDone = TMarkdownExportImageWait.WaitUntil(
    function: Boolean
    begin
      Result := True;
    end,
    GenerousTimeoutMilliseconds,
    procedure
    begin
      Inc(PumpCount);
    end);

  Assert.IsTrue(IsDone);
  Assert.AreEqual(0, PumpCount);
end;

procedure TMarkdownExportImageWaitTests.WaitUntil_DoneAfterPumping_ReturnsTrue;
begin
  var PumpCount := 0;

  const IsDone = TMarkdownExportImageWait.WaitUntil(
    function: Boolean
    begin
      Result := (PumpCount >= PumpsUntilDone);
    end,
    GenerousTimeoutMilliseconds,
    procedure
    begin
      Inc(PumpCount);
    end);

  Assert.IsTrue(IsDone);
  Assert.AreEqual(PumpsUntilDone, PumpCount);
end;

procedure TMarkdownExportImageWaitTests.WaitUntil_NeverDone_ReturnsFalseAfterTimeout;
begin
  const Watch = TStopwatch.StartNew;

  const IsDone = TMarkdownExportImageWait.WaitUntil(
    function: Boolean
    begin
      Result := False;
    end,
    ShortTimeoutMilliseconds,
    procedure
    begin
      TThread.Sleep(PumpSleepMilliseconds);
    end);

  Assert.IsFalse(IsDone);
  Assert.IsTrue(Watch.ElapsedMilliseconds >= ShortTimeoutMilliseconds, 'it waited the whole time');
end;

procedure TMarkdownExportImageWaitTests.WaitUntil_MissingPump_RaisesEMarkdownPdfExportError;
begin
  Assert.WillRaise(
    procedure
    begin
      TMarkdownExportImageWait.WaitUntil(
        function: Boolean
        begin
          Result := True;
        end,
        GenerousTimeoutMilliseconds, nil);
    end,
    EMarkdownPdfExportError);
end;

end.
