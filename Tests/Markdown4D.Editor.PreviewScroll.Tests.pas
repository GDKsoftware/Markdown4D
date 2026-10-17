unit Markdown4D.Editor.PreviewScroll.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownPreviewScrollTests = class
  private
    const
      SingleTolerance = 0.001;

  public
    [Test]
    [TestCase('LineInView', '0,50,70,100,0')]
    [TestCase('LineBelowView', '0,150,180,100,80')]
    [TestCase('LineTallerThanView', '0,150,300,100,150')]
    [TestCase('ScrolledDocument', '400,520,540,100,440')]
    procedure OffsetShowingLine_ScrollsOnlyAsFarAsTheLineNeeds(const TopLineOffset, LineTop, LineBottom,
      ViewHeight, Expected: Single);
  end;

implementation

uses
  Markdown4D.Editor.PreviewScroll;

procedure TMarkdownPreviewScrollTests.OffsetShowingLine_ScrollsOnlyAsFarAsTheLineNeeds(const TopLineOffset, LineTop,
  LineBottom, ViewHeight, Expected: Single);
begin
  const Offset = TMarkdownPreviewScroll.OffsetShowingLine(TopLineOffset, LineTop, LineBottom, ViewHeight);

  Assert.AreEqual(Expected, Offset, SingleTolerance);
end;

end.
