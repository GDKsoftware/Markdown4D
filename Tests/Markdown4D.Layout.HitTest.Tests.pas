unit Markdown4D.Layout.HitTest.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme;

type
  [TestFixture]
  TMarkdownLayoutHitTestTests = class
  private
    const
      BaseFamilyName = 'Test Sans';
      BaseFontSize = 16.0;
      BaseCharWidth = 10.0;
      LinkDestination = 'http://example.com/page';
      DefaultWidth = 300.0;
      FirstLineY = 10.0;
      SecondLineY = 30.0;
      MissY = 300.0;
      ContentPaddingValue = 16.0;
    class function CreateTestTheme: TMarkdownTheme;
    class function LayoutMarkdown(const Source: string; const AvailableWidth: Single): IMarkdownDisplayList;
    class function LayoutMarkdownWithPadding(const Source: string;
      const AvailableWidth, Padding: Single): IMarkdownDisplayList;
    class function CreateMeasurer: ITextMeasurer;

  public
    [Test]
    procedure TryFindLink_LinkAtPaddedOrigin_StillHits;

    [Test]
    procedure TryFindLink_PointInsideLinkRun_ReturnsLinkWithDestination;

    [Test]
    procedure TryFindLink_LinkWrappedAcrossLines_HitsOnBothLines;

    [Test]
    procedure TryFindLink_PointInPlainText_ReturnsFalse;

    [Test]
    procedure TryFindTextPosition_PointInRun_ReturnsNearestCharacterIndex;

    [Test]
    procedure TryFindTextPosition_PointOutsideContent_ReturnsFalse;
  end;

implementation

uses
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.HitTest,
  Markdown4D.Layout.FakeMeasurer;

procedure TMarkdownLayoutHitTestTests.TryFindLink_LinkAtPaddedOrigin_StillHits;
begin
  const DisplayList = LayoutMarkdownWithPadding('[click here](' + LinkDestination + ')', DefaultWidth,
    ContentPaddingValue);

  const InsideLink = TLayoutPointF.Create(ContentPaddingValue + 2 * BaseCharWidth, ContentPaddingValue + 5);

  var Link: IMarkdownLink;
  const Found = TMarkdownHitTester.TryFindLink(DisplayList, InsideLink, Link);

  Assert.IsTrue(Found);
  Assert.AreEqual(LinkDestination, Link.Destination);
end;

procedure TMarkdownLayoutHitTestTests.TryFindLink_PointInsideLinkRun_ReturnsLinkWithDestination;
begin
  const DisplayList = LayoutMarkdown('[click here](' + LinkDestination + ')', DefaultWidth);

  var Link: IMarkdownLink;
  const Found = TMarkdownHitTester.TryFindLink(DisplayList, TLayoutPointF.Create(5 * BaseCharWidth, FirstLineY), Link);

  Assert.IsTrue(Found);
  Assert.AreEqual(LinkDestination, Link.Destination);
end;

procedure TMarkdownLayoutHitTestTests.TryFindLink_LinkWrappedAcrossLines_HitsOnBothLines;
begin
  const DisplayList = LayoutMarkdown('[alpha beta gamma](' + LinkDestination + ')', 11 * BaseCharWidth);

  var FirstLineLink: IMarkdownLink;
  const FoundOnFirstLine = TMarkdownHitTester.TryFindLink(DisplayList,
    TLayoutPointF.Create(5 * BaseCharWidth, FirstLineY), FirstLineLink);
  Assert.IsTrue(FoundOnFirstLine);
  Assert.AreEqual(LinkDestination, FirstLineLink.Destination);

  var SecondLineLink: IMarkdownLink;
  const FoundOnSecondLine = TMarkdownHitTester.TryFindLink(DisplayList,
    TLayoutPointF.Create(2.5 * BaseCharWidth, SecondLineY), SecondLineLink);
  Assert.IsTrue(FoundOnSecondLine);
  Assert.AreEqual(LinkDestination, SecondLineLink.Destination);
end;

procedure TMarkdownLayoutHitTestTests.TryFindLink_PointInPlainText_ReturnsFalse;
begin
  const DisplayList = LayoutMarkdown('plain words only', DefaultWidth);

  var Link: IMarkdownLink;
  const Found = TMarkdownHitTester.TryFindLink(DisplayList, TLayoutPointF.Create(3 * BaseCharWidth, FirstLineY), Link);

  Assert.IsFalse(Found);
end;

procedure TMarkdownLayoutHitTestTests.TryFindTextPosition_PointInRun_ReturnsNearestCharacterIndex;
begin
  const DisplayList = LayoutMarkdown('alphabet', DefaultWidth);
  const Measurer = CreateMeasurer;

  var HitBefore: TMarkdownTextHit;
  const FoundBefore = TMarkdownHitTester.TryFindTextPosition(DisplayList, TLayoutPointF.Create(33, FirstLineY),
    Measurer, HitBefore);
  Assert.IsTrue(FoundBefore);
  Assert.AreEqual(3, HitBefore.CharacterIndex);
  Assert.AreEqual('alphabet', HitBefore.Run.Text);

  var HitAfter: TMarkdownTextHit;
  const FoundAfter = TMarkdownHitTester.TryFindTextPosition(DisplayList, TLayoutPointF.Create(37, FirstLineY),
    Measurer, HitAfter);
  Assert.IsTrue(FoundAfter);
  Assert.AreEqual(4, HitAfter.CharacterIndex);
end;

procedure TMarkdownLayoutHitTestTests.TryFindTextPosition_PointOutsideContent_ReturnsFalse;
begin
  const DisplayList = LayoutMarkdown('alphabet', DefaultWidth);
  const Measurer = CreateMeasurer;
  const MissPoint = TLayoutPointF.Create(6 * BaseCharWidth, MissY);

  var Hit: TMarkdownTextHit;
  const FoundText = TMarkdownHitTester.TryFindTextPosition(DisplayList, MissPoint, Measurer, Hit);
  Assert.IsFalse(FoundText);

  var Link: IMarkdownLink;
  const FoundLink = TMarkdownHitTester.TryFindLink(DisplayList, MissPoint, Link);
  Assert.IsFalse(FoundLink);
end;

class function TMarkdownLayoutHitTestTests.CreateTestTheme: TMarkdownTheme;
begin
  Result := TMarkdownTheme.CreateLight;

  Result.BaseFont := TMarkdownFontStyle.Create(BaseFamilyName, BaseFontSize);
  Result.ContentPadding := 0;
end;

class function TMarkdownLayoutHitTestTests.LayoutMarkdown(const Source: string;
  const AvailableWidth: Single): IMarkdownDisplayList;
begin
  const Theme = CreateTestTheme;
  try
    const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
    const Measurer = CreateMeasurer;

    Result := TMarkdownLayoutEngine.LayoutDocument(Document, AvailableWidth, Theme, Measurer);
  finally
    Theme.Free;
  end;
end;

class function TMarkdownLayoutHitTestTests.LayoutMarkdownWithPadding(const Source: string;
  const AvailableWidth, Padding: Single): IMarkdownDisplayList;
begin
  const Theme = CreateTestTheme;
  try
    Theme.ContentPadding := Padding;

    const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
    const Measurer = CreateMeasurer;

    Result := TMarkdownLayoutEngine.LayoutDocument(Document, AvailableWidth, Theme, Measurer);
  finally
    Theme.Free;
  end;
end;

class function TMarkdownLayoutHitTestTests.CreateMeasurer: ITextMeasurer;
begin
  Result := TFakeTextMeasurer.Create;
end;

end.
