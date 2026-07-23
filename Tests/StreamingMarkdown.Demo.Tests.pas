unit StreamingMarkdown.Demo.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  StreamingMarkdown.Demo;

type
  [TestFixture]
  TMarkdownStreamerTests = class
  private
    var
      FStreamer: TMarkdownStreamer;
    function DrainAll(const ChunkSize: Integer): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure HasMore_EmptyText_IsFalse;

    [Test]
    procedure NextChunk_DrainedInPieces_ReproducesFullText;

    [Test]
    procedure NextChunk_ClampsToRemaining;

    [Test]
    procedure NextChunk_NonPositiveRequest_ReturnsEmptyAndKeepsPosition;

    [Test]
    procedure HasMore_AfterFullDrain_IsFalse;

    [Test]
    procedure Reset_Rewinds;

    [Test]
    procedure SampleAnswer_ContainsKeySections;
  end;

implementation

uses
  System.SysUtils;

procedure TMarkdownStreamerTests.Setup;
begin
  FStreamer := TMarkdownStreamer.Create;
end;

procedure TMarkdownStreamerTests.TearDown;
begin
  FStreamer.Free;
end;

function TMarkdownStreamerTests.DrainAll(const ChunkSize: Integer): string;
begin
  Result := '';
  while FStreamer.HasMore do
    Result := Result + FStreamer.NextChunk(ChunkSize);
end;

procedure TMarkdownStreamerTests.HasMore_EmptyText_IsFalse;
begin
  FStreamer.Reset('');
  Assert.IsFalse(FStreamer.HasMore);
end;

procedure TMarkdownStreamerTests.NextChunk_DrainedInPieces_ReproducesFullText;
begin
  const Text = 'The quick brown fox jumps over the lazy dog.';
  FStreamer.Reset(Text);
  Assert.AreEqual(Text, DrainAll(7));
end;

procedure TMarkdownStreamerTests.NextChunk_ClampsToRemaining;
begin
  FStreamer.Reset('abcde');
  Assert.AreEqual('abcde', FStreamer.NextChunk(100));
  Assert.IsFalse(FStreamer.HasMore);
end;

procedure TMarkdownStreamerTests.NextChunk_NonPositiveRequest_ReturnsEmptyAndKeepsPosition;
begin
  FStreamer.Reset('abc');
  Assert.AreEqual('', FStreamer.NextChunk(0));
  Assert.AreEqual('', FStreamer.NextChunk(-5));
  Assert.IsTrue(FStreamer.HasMore);
  Assert.AreEqual('abc', FStreamer.NextChunk(3));
end;

procedure TMarkdownStreamerTests.HasMore_AfterFullDrain_IsFalse;
begin
  FStreamer.Reset('hello');
  DrainAll(2);
  Assert.IsFalse(FStreamer.HasMore);
end;

procedure TMarkdownStreamerTests.Reset_Rewinds;
begin
  FStreamer.Reset('abc');
  FStreamer.NextChunk(2);
  FStreamer.Reset('abc');
  Assert.IsTrue(FStreamer.HasMore);
  Assert.AreEqual('abc', DrainAll(10));
end;

procedure TMarkdownStreamerTests.SampleAnswer_ContainsKeySections;
begin
  const Answer = BuildStreamingSampleAnswer;
  Assert.IsTrue(Answer.Contains('# Streaming Markdown'), 'heading missing');
  Assert.IsTrue(Answer.Contains('```mermaid'), 'mermaid fence missing');
  Assert.IsTrue(Answer.Contains('"type":"chart"'), 'chart block missing');
  Assert.IsTrue(Answer.Contains('[x] FMX viewer'), 'roadmap item missing');
end;

end.
