unit Markdown4D.Editor.Folding.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.Folding;

type
  [TestFixture]
  TMarkdownFoldComputerTests = class
  private
    function RegionAt(const Regions: TArray<TFoldRegion>; const HeaderLine: Integer): TFoldRegion;
    function HasHeader(const Regions: TArray<TFoldRegion>; const HeaderLine: Integer): Boolean;

  public
    [Test]
    procedure FencedCodeBlock_FoldsFromFenceToClose;

    [Test]
    procedure UnterminatedFence_FoldsToEnd;

    [Test]
    procedure Heading_FoldsToLineBeforeNextSameLevelHeading;

    [Test]
    procedure SubHeading_NestsInsideParentSection;

    [Test]
    procedure HashInsideFence_IsNotAHeading;

    [Test]
    procedure PlainParagraphs_ProduceNoRegions;
  end;

implementation

uses
  System.SysUtils;

function TMarkdownFoldComputerTests.RegionAt(const Regions: TArray<TFoldRegion>;
  const HeaderLine: Integer): TFoldRegion;
begin
  for var Region in Regions do
  begin
    if Region.HeaderLine = HeaderLine then
      Exit(Region);
  end;

  Assert.Fail(Format('No fold region with header line %d', [HeaderLine]));
end;

function TMarkdownFoldComputerTests.HasHeader(const Regions: TArray<TFoldRegion>;
  const HeaderLine: Integer): Boolean;
begin
  for var Region in Regions do
  begin
    if Region.HeaderLine = HeaderLine then
      Exit(True);
  end;

  Result := False;
end;

procedure TMarkdownFoldComputerTests.FencedCodeBlock_FoldsFromFenceToClose;
begin
  const Regions = TMarkdownFoldComputer.ComputeRegions(['```', 'one', 'two', '```', 'after']);
  const Region = RegionAt(Regions, 0);
  Assert.AreEqual(1, Region.StartLine);
  Assert.AreEqual(3, Region.EndLine);
end;

procedure TMarkdownFoldComputerTests.UnterminatedFence_FoldsToEnd;
begin
  const Regions = TMarkdownFoldComputer.ComputeRegions(['```', 'one', 'two']);
  const Region = RegionAt(Regions, 0);
  Assert.AreEqual(1, Region.StartLine);
  Assert.AreEqual(2, Region.EndLine);
end;

procedure TMarkdownFoldComputerTests.Heading_FoldsToLineBeforeNextSameLevelHeading;
begin
  const Regions = TMarkdownFoldComputer.ComputeRegions(['# A', 'body', 'more', '# B', 'tail']);
  const First = RegionAt(Regions, 0);
  Assert.AreEqual(1, First.StartLine);
  Assert.AreEqual(2, First.EndLine);

  const Second = RegionAt(Regions, 3);
  Assert.AreEqual(4, Second.StartLine);
  Assert.AreEqual(4, Second.EndLine);
end;

procedure TMarkdownFoldComputerTests.SubHeading_NestsInsideParentSection;
begin
  const Regions = TMarkdownFoldComputer.ComputeRegions(['# A', '## B', 'body', '# C']);

  const Parent = RegionAt(Regions, 0);
  Assert.AreEqual(2, Parent.EndLine);

  const Child = RegionAt(Regions, 1);
  Assert.AreEqual(2, Child.StartLine);
  Assert.AreEqual(2, Child.EndLine);
end;

procedure TMarkdownFoldComputerTests.HashInsideFence_IsNotAHeading;
begin
  const Regions = TMarkdownFoldComputer.ComputeRegions(['# A', '```', '# not a heading', '```']);

  const Fence = RegionAt(Regions, 1);
  Assert.AreEqual(2, Fence.StartLine);
  Assert.AreEqual(3, Fence.EndLine);

  const Section = RegionAt(Regions, 0);
  Assert.AreEqual(3, Section.EndLine);

  Assert.IsFalse(HasHeader(Regions, 2), 'A hash inside a fence must not open a heading region');
end;

procedure TMarkdownFoldComputerTests.PlainParagraphs_ProduceNoRegions;
begin
  const Regions = TMarkdownFoldComputer.ComputeRegions(['just text', 'more text', '']);
  Assert.AreEqual(0, Length(Regions));
end;

end.
