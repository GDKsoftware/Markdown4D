unit Markdown4D.Viewer.Model.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Theme,
  Markdown4D.Viewer.Model;

type
  [TestFixture]
  TMarkdownViewerModelTests = class
  private
    const
      DefaultWidth = 300.0;
      DefaultHeight = 200.0;
      SmallHeight = 100.0;
      WrapWidthCharacters = 12;
      BaseCharWidth = 10.0;
      BaseLineHeight = 22.4;
      ParagraphSpacingValue = 8.0;
      FlushIntervalValue = 100;
      StartTime = 1000;
      SingleTolerance = 0.05;
      TallParagraphCount = 10;
      ImageMarkdown = '![alt](img.png)';
      ImageSource = 'img.png';
      LoadedImageWidth = 200.0;
      LoadedImageHeight = 100.0;
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FModel: TMarkdownViewerModel;
    class function BuildTallMarkdown: string;
    class procedure AssertSingle(const Expected, Actual: Single);
    procedure SelectFromTo(const AnchorX, AnchorY, ExtentX, ExtentY: Single);
    procedure LoadImageDocument;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure SetText_LayoutsDocumentOnce;

    [Test]
    procedure Selection_WithinSingleRun_ProducesSingleRectAndText;

    [Test]
    procedure Selection_AcrossWrappedLines_ProducesRectPerLine;

    [Test]
    procedure Selection_AcrossBlocks_JoinsTextWithLineBreak;

    [Test]
    procedure Selection_Backwards_NormalizesToSameText;

    [Test]
    procedure ClearSelection_RemovesSelectionState;

    [Test]
    procedure AppendMarkdown_MarksDirtyWithoutRelayout;

    [Test]
    procedure TryFlush_BeforeInterval_ReturnsFalse;

    [Test]
    procedure TryFlush_AfterInterval_AppliesPendingMarkdown;

    [Test]
    procedure TryFlush_IntervalMeasuredFromFirstAppend;

    [Test]
    procedure TryFlush_WhenClean_ReturnsFalse;

    [Test]
    procedure TryFlush_WhenScrolledToBottom_SetsShouldAutoFollow;

    [Test]
    procedure TryFlush_WhenScrolledUp_DoesNotAutoFollow;

    [Test]
    procedure ImageSlot_AfterLayout_IsRequestedWithPendingRequest;

    [Test]
    procedure ImageArrived_TriggersRelayoutExactlyOnce;

    [Test]
    procedure ImageFailed_MarksSlotFailed;

    [Test]
    procedure ImageSlot_SurvivesDocumentUpdate_WhenUrlUnchanged;

    [Test]
    procedure ImageSlotState_UnknownSource_ReturnsUnknown;

    [Test]
    procedure FindText_IsCaseInsensitive_ReturnsRangesWithinRun;

    [Test]
    procedure FindText_AcrossBlocks_ReturnsRangePerBlock;

    [Test]
    procedure FindText_NoMatch_ReturnsEmpty;

    [Test]
    procedure FindText_EmptyNeedle_ReturnsEmpty;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.FakeMeasurer;

procedure TMarkdownViewerModelTests.Setup;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FTheme.ContentPadding := 0;
  FMeasurer := TFakeTextMeasurer.Create;
  FModel := TMarkdownViewerModel.Create(FTheme, FMeasurer);
end;

procedure TMarkdownViewerModelTests.TearDown;
begin
  FModel.Free;
  FModel := nil;

  FMeasurer := nil;

  FTheme.Free;
  FTheme := nil;
end;

procedure TMarkdownViewerModelTests.SetText_LayoutsDocumentOnce;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha';

  Assert.AreEqual(1, FModel.LayoutCount);
  Assert.AreEqual('alpha', FModel.Text);
  Assert.IsNotNull(FModel.DisplayList);
  AssertSingle(BaseLineHeight, FModel.DisplayList.Height);
end;

procedure TMarkdownViewerModelTests.Selection_WithinSingleRun_ProducesSingleRectAndText;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta';

  SelectFromTo(1, 10, 48, 10);

  Assert.IsTrue(FModel.HasSelection);
  Assert.AreEqual('alpha', FModel.SelectedText);

  const Rects = FModel.SelectionRects;
  Assert.AreEqual(1, Length(Rects));
  AssertSingle(0, Rects[0].Left);
  AssertSingle(0, Rects[0].Top);
  AssertSingle(5 * BaseCharWidth, Rects[0].Right);
  AssertSingle(BaseLineHeight, Rects[0].Bottom);
end;

procedure TMarkdownViewerModelTests.Selection_AcrossWrappedLines_ProducesRectPerLine;
begin
  FModel.SetViewport(WrapWidthCharacters * BaseCharWidth, DefaultHeight);
  FModel.Text := 'alpha beta gamma';

  SelectFromTo(1, 10, 30, 33);

  Assert.AreEqual('alpha beta gam', FModel.SelectedText);

  const Rects = FModel.SelectionRects;
  Assert.AreEqual(2, Length(Rects));
  AssertSingle(0, Rects[0].Left);
  AssertSingle(0, Rects[0].Top);
  AssertSingle(10 * BaseCharWidth, Rects[0].Right);
  AssertSingle(BaseLineHeight, Rects[0].Bottom);
  AssertSingle(0, Rects[1].Left);
  AssertSingle(BaseLineHeight, Rects[1].Top);
  AssertSingle(3 * BaseCharWidth, Rects[1].Right);
  AssertSingle(2 * BaseLineHeight, Rects[1].Bottom);
end;

procedure TMarkdownViewerModelTests.Selection_AcrossBlocks_JoinsTextWithLineBreak;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'one'#10#10'two';

  SelectFromTo(1, 10, 30, 40);

  Assert.AreEqual('one' + sLineBreak + 'two', FModel.SelectedText);

  const Rects = FModel.SelectionRects;
  Assert.AreEqual(2, Length(Rects));
  AssertSingle(0, Rects[0].Left);
  AssertSingle(3 * BaseCharWidth, Rects[0].Right);
  AssertSingle(BaseLineHeight + ParagraphSpacingValue, Rects[1].Top);
  AssertSingle(3 * BaseCharWidth, Rects[1].Right);
end;

procedure TMarkdownViewerModelTests.Selection_Backwards_NormalizesToSameText;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta';

  SelectFromTo(48, 10, 1, 10);

  Assert.AreEqual('alpha', FModel.SelectedText);
end;

procedure TMarkdownViewerModelTests.ClearSelection_RemovesSelectionState;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta';
  SelectFromTo(1, 10, 48, 10);

  FModel.ClearSelection;

  Assert.IsFalse(FModel.HasSelection);
  Assert.AreEqual('', FModel.SelectedText);
  Assert.AreEqual(0, Length(FModel.SelectionRects));
end;

procedure TMarkdownViewerModelTests.AppendMarkdown_MarksDirtyWithoutRelayout;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'one';

  FModel.AppendMarkdown(' two', StartTime);

  Assert.IsTrue(FModel.IsDirty);
  Assert.AreEqual(1, FModel.LayoutCount);
  Assert.AreEqual('one', FModel.Text);
end;

procedure TMarkdownViewerModelTests.TryFlush_BeforeInterval_ReturnsFalse;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.FlushIntervalMilliseconds := FlushIntervalValue;
  FModel.Text := 'one';
  FModel.AppendMarkdown(' two', StartTime);

  Assert.IsFalse(FModel.TryFlush(StartTime + FlushIntervalValue - 1));
  Assert.IsTrue(FModel.IsDirty);
  Assert.AreEqual(1, FModel.LayoutCount);
end;

procedure TMarkdownViewerModelTests.TryFlush_AfterInterval_AppliesPendingMarkdown;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.FlushIntervalMilliseconds := FlushIntervalValue;
  FModel.Text := 'one';
  FModel.AppendMarkdown(' two', StartTime);

  Assert.IsTrue(FModel.TryFlush(StartTime + FlushIntervalValue));
  Assert.IsFalse(FModel.IsDirty);
  Assert.AreEqual('one two', FModel.Text);
  Assert.AreEqual(2, FModel.LayoutCount);
end;

procedure TMarkdownViewerModelTests.TryFlush_IntervalMeasuredFromFirstAppend;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.FlushIntervalMilliseconds := FlushIntervalValue;
  FModel.Text := 'x';
  FModel.AppendMarkdown('a', StartTime);
  FModel.AppendMarkdown('b', StartTime + 80);

  Assert.IsTrue(FModel.TryFlush(StartTime + FlushIntervalValue));
  Assert.AreEqual('xab', FModel.Text);
end;

procedure TMarkdownViewerModelTests.TryFlush_WhenClean_ReturnsFalse;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'one';

  Assert.IsFalse(FModel.TryFlush(StartTime));
  Assert.AreEqual(1, FModel.LayoutCount);
end;

procedure TMarkdownViewerModelTests.TryFlush_WhenScrolledToBottom_SetsShouldAutoFollow;
begin
  FModel.SetViewport(DefaultWidth, SmallHeight);
  FModel.FlushIntervalMilliseconds := FlushIntervalValue;
  FModel.Text := BuildTallMarkdown;
  FModel.ScrollOffset := FModel.DisplayList.Height - SmallHeight;

  Assert.IsTrue(FModel.IsScrolledToBottom);

  FModel.AppendMarkdown(#10#10'tail', StartTime);
  Assert.IsTrue(FModel.TryFlush(StartTime + FlushIntervalValue));
  Assert.IsTrue(FModel.ShouldAutoFollow);
end;

procedure TMarkdownViewerModelTests.TryFlush_WhenScrolledUp_DoesNotAutoFollow;
begin
  FModel.SetViewport(DefaultWidth, SmallHeight);
  FModel.FlushIntervalMilliseconds := FlushIntervalValue;
  FModel.Text := BuildTallMarkdown;
  FModel.ScrollOffset := 0;

  Assert.IsFalse(FModel.IsScrolledToBottom);

  FModel.AppendMarkdown(#10#10'tail', StartTime);
  Assert.IsTrue(FModel.TryFlush(StartTime + FlushIntervalValue));
  Assert.IsFalse(FModel.ShouldAutoFollow);
end;

procedure TMarkdownViewerModelTests.ImageSlot_AfterLayout_IsRequestedWithPendingRequest;
begin
  LoadImageDocument;

  const IsRequested = (FModel.ImageSlotState(ImageSource) = TMarkdownImageSlotState.Requested);
  Assert.IsTrue(IsRequested);

  const Pending = FModel.PendingImageSources;
  Assert.AreEqual(1, Length(Pending));
  Assert.AreEqual(ImageSource, Pending[0]);
end;

procedure TMarkdownViewerModelTests.ImageArrived_TriggersRelayoutExactlyOnce;
begin
  LoadImageDocument;
  Assert.AreEqual(1, FModel.LayoutCount);

  FModel.NotifyImageArrived(ImageSource, TLayoutSizeF.Create(LoadedImageWidth, LoadedImageHeight));

  Assert.AreEqual(2, FModel.LayoutCount);
  const IsLoaded = (FModel.ImageSlotState(ImageSource) = TMarkdownImageSlotState.Loaded);
  Assert.IsTrue(IsLoaded);

  var Size: TLayoutSizeF;
  Assert.IsTrue(FModel.TryGetImageSize(ImageSource, Size));
  AssertSingle(LoadedImageWidth, Size.Width);
  AssertSingle(LoadedImageHeight, Size.Height);

  FModel.NotifyImageArrived(ImageSource, TLayoutSizeF.Create(LoadedImageWidth, LoadedImageHeight));
  Assert.AreEqual(2, FModel.LayoutCount);
  Assert.AreEqual(0, Length(FModel.PendingImageSources));
end;

procedure TMarkdownViewerModelTests.ImageFailed_MarksSlotFailed;
begin
  LoadImageDocument;

  FModel.NotifyImageFailed(ImageSource);

  const IsFailed = (FModel.ImageSlotState(ImageSource) = TMarkdownImageSlotState.Failed);
  Assert.IsTrue(IsFailed);

  var Size: TLayoutSizeF;
  Assert.IsFalse(FModel.TryGetImageSize(ImageSource, Size));
  Assert.AreEqual(0, Length(FModel.PendingImageSources));
end;

procedure TMarkdownViewerModelTests.ImageSlot_SurvivesDocumentUpdate_WhenUrlUnchanged;
begin
  LoadImageDocument;
  FModel.NotifyImageArrived(ImageSource, TLayoutSizeF.Create(LoadedImageWidth, LoadedImageHeight));

  FModel.Text := '# Title'#10#10 + ImageMarkdown;

  const StaysLoaded = (FModel.ImageSlotState(ImageSource) = TMarkdownImageSlotState.Loaded);
  Assert.IsTrue(StaysLoaded);

  var Size: TLayoutSizeF;
  Assert.IsTrue(FModel.TryGetImageSize(ImageSource, Size));
  Assert.AreEqual(0, Length(FModel.PendingImageSources));
end;

procedure TMarkdownViewerModelTests.ImageSlotState_UnknownSource_ReturnsUnknown;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'plain';

  const IsUnknown = (FModel.ImageSlotState('missing.png') = TMarkdownImageSlotState.Unknown);
  Assert.IsTrue(IsUnknown);
end;

procedure TMarkdownViewerModelTests.FindText_IsCaseInsensitive_ReturnsRangesWithinRun;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'Alpha beta ALPHA';

  const Ranges = FModel.FindText('alpha');

  Assert.AreEqual(2, Length(Ranges));
  Assert.AreEqual(Ranges[0].ItemIndex, Ranges[1].ItemIndex);
  Assert.AreEqual(1, Ranges[0].StartCharacter);
  Assert.AreEqual(5, Ranges[0].CharacterCount);
  Assert.AreEqual(12, Ranges[1].StartCharacter);
  Assert.AreEqual(5, Ranges[1].CharacterCount);

  var Run: IDisplayTextRun;
  Assert.IsTrue(Supports(FModel.DisplayList.Items[Ranges[0].ItemIndex], IDisplayTextRun, Run));
  Assert.IsTrue(SameText('alpha', Copy(Run.Text, Ranges[0].StartCharacter, Ranges[0].CharacterCount)));
end;

procedure TMarkdownViewerModelTests.FindText_AcrossBlocks_ReturnsRangePerBlock;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'one'#10#10'gone';

  const Ranges = FModel.FindText('one');

  Assert.AreEqual(2, Length(Ranges));
  const ItemsDiffer = (Ranges[0].ItemIndex <> Ranges[1].ItemIndex);
  Assert.IsTrue(ItemsDiffer);
  Assert.AreEqual(1, Ranges[0].StartCharacter);
  Assert.AreEqual(2, Ranges[1].StartCharacter);
end;

procedure TMarkdownViewerModelTests.FindText_NoMatch_ReturnsEmpty;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta';

  Assert.AreEqual(0, Length(FModel.FindText('zulu')));
end;

procedure TMarkdownViewerModelTests.FindText_EmptyNeedle_ReturnsEmpty;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := 'alpha beta';

  Assert.AreEqual(0, Length(FModel.FindText('')));
end;

class function TMarkdownViewerModelTests.BuildTallMarkdown: string;
begin
  Result := '';

  for var Index := 1 to TallParagraphCount do
  begin
    if Result <> '' then
      Result := Result + #10#10;
    Result := Result + Format('paragraph%d', [Index]);
  end;
end;

class procedure TMarkdownViewerModelTests.AssertSingle(const Expected, Actual: Single);
begin
  Assert.AreEqual(Double(Expected), Double(Actual), SingleTolerance);
end;

procedure TMarkdownViewerModelTests.SelectFromTo(const AnchorX, AnchorY, ExtentX, ExtentY: Single);
begin
  FModel.SetSelectionAnchor(TLayoutPointF.Create(AnchorX, AnchorY));
  FModel.SetSelectionExtent(TLayoutPointF.Create(ExtentX, ExtentY));
end;

procedure TMarkdownViewerModelTests.LoadImageDocument;
begin
  FModel.SetViewport(DefaultWidth, DefaultHeight);
  FModel.Text := ImageMarkdown;
end;

end.
