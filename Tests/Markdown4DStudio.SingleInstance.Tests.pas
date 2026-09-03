unit Markdown4DStudio.SingleInstance.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TPadSingleInstanceTests = class
  private
    const
      ChannelName = 'Markdown4DStudio.Test.Instance';
      SamplePath = 'C:\docs\sample document.md';

  public
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TryHandOff_NoChannelOpen_ReturnsFalse;

    [Test]
    procedure TryHandOff_OpenChannel_DeliversTheDocumentPath;

    [Test]
    procedure TryHandOff_EmptyPath_StillReachesTheChannel;

    [Test]
    procedure CloseChannel_HandOffAfterwards_ReturnsFalse;
  end;

implementation

uses
  Markdown4DStudio.SingleInstance;

procedure TPadSingleInstanceTests.TearDown;
begin
  TPadSingleInstance.CloseChannel;
end;

procedure TPadSingleInstanceTests.TryHandOff_NoChannelOpen_ReturnsFalse;
begin
  Assert.IsFalse(TPadSingleInstance.TryHandOff(ChannelName, SamplePath),
    'Without an open channel there is nothing to hand the document to');
end;

procedure TPadSingleInstanceTests.TryHandOff_OpenChannel_DeliversTheDocumentPath;
begin
  var Received := '';
  var CallCount := 0;
  TPadSingleInstance.OpenChannel(ChannelName,
    procedure(const FileName: string)
    begin
      Received := FileName;
      Inc(CallCount);
    end);

  Assert.IsTrue(TPadSingleInstance.TryHandOff(ChannelName, SamplePath),
    'An open channel must accept the hand-off');
  Assert.AreEqual(1, CallCount);
  Assert.AreEqual(SamplePath, Received);
end;

procedure TPadSingleInstanceTests.TryHandOff_EmptyPath_StillReachesTheChannel;
begin
  var CallCount := 0;
  TPadSingleInstance.OpenChannel(ChannelName,
    procedure(const FileName: string)
    begin
      Inc(CallCount);
    end);

  Assert.IsTrue(TPadSingleInstance.TryHandOff(ChannelName, ''),
    'A plain second launch still hands off, so the first instance can come forward');
  Assert.AreEqual(1, CallCount);
end;

procedure TPadSingleInstanceTests.CloseChannel_HandOffAfterwards_ReturnsFalse;
begin
  TPadSingleInstance.OpenChannel(ChannelName,
    procedure(const FileName: string)
    begin
    end);
  TPadSingleInstance.CloseChannel;

  Assert.IsFalse(TPadSingleInstance.TryHandOff(ChannelName, SamplePath),
    'A closed channel must no longer be discoverable');
end;

end.
