unit Markdown4D.Fmx.Viewer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  FMX.Graphics,
  Markdown4D.Theme,
  Markdown4D.Fmx.Viewer;

type
  [TestFixture]
  TMarkdownFmxViewerTests = class
  private
    const
      ControlWidth = 300.0;
      ControlHeight = 200.0;
      SampleMarkdown = '# Title'#10#10'Body paragraph with enough words to wrap onto a second line.';
      ImageMarkdown = '![alt](img.png)';
      RepeatedWordMarkdown = 'Alpha beta alpha';
      RepeatedWord = 'alpha';
      SecondParagraph = 'Paragraph 01';
      TallParagraphCount = 40;
      LastParagraph = 'Paragraph 39';
      ClipTestViewerWidth = 300.0;
      ClipTestViewerHeight = 80.0;
      ClipTestSelectionStartX = 5.0;
      ClipTestSelectionEndX = 250.0;
      ClipTestSelectionBottomY = 40.0;
      ClipTestBandHeight = 60;
      WheelNotchDown = -120;
      WheelNotchUp = 120;
      KeyboardMarkdown = 'alpha beta';
      ClickMarkdown = 'alpha';
      LinkMarkdown = '[alpha](https://example.com)';
      DragDistance = 40.0;
      ClipTestMarkdown =
        '# Top'#10#10 +
        'Filler paragraph number one with enough words to wrap across several lines of text at this width.'#10#10 +
        'Filler paragraph number two with enough words to wrap across several lines of text at this width.'#10#10 +
        'Filler paragraph number three with enough words to wrap across several lines of text at this width.'#10#10 +
        'Filler paragraph number four with enough words to wrap across several lines of text at this width.'#10#10 +
        'Filler paragraph number five with enough words to wrap across several lines of text at this width.'#10#10 +
        'Filler paragraph number six with enough words to wrap across several lines of text at this width.'#10#10 +
        'Filler paragraph number seven with enough words to wrap across several lines of text at this width.'#10#10 +
        'Filler paragraph number eight with enough words to wrap across several lines of text at this width.'#10#10 +
        'Filler paragraph number nine with enough words to wrap across several lines of text at this width.'#10#10 +
        'Filler paragraph number ten with enough words to wrap across several lines of text at this width.';
    var
      FViewer: TMarkdownViewer;
      FExternalTheme: TMarkdownTheme;
      FReportedSender: TObject;
      FAutoScrollChangeCount: Integer;
      FZoomChangeCount: Integer;
      FClickCount: Integer;
      FDoubleClickCount: Integer;
      FLinkClickCount: Integer;
    class function IsBandUntouched(const Bitmap: TBitmap; const BandHeight: Integer): Boolean;
    procedure PressKey(const Key: Word; const Shift: TShiftState);
    procedure StartAutoScroll;
    function PressDialogKey(const Key: Word): Word;
    procedure RecordAutoScrollChange(Sender: TObject);
    procedure RecordZoomChange(Sender: TObject);
    procedure ShowClickMarkdown(const Markdown: string);
    function FirstTextRunCenter: TPointF;
    procedure PressAt(const Point: TPointF; const Shift: TShiftState);
    procedure ReleaseAt(const Point: TPointF);
    procedure RecordClick(Sender: TObject);
    procedure RecordDoubleClick(Sender: TObject);
    procedure RecordLinkClick(const Sender: TObject; const Url: string);
    procedure RecordExtensionError(const Sender: TObject; const Extension: string; const Error: Exception);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure NewViewer_HasEmptySelectedText;

    [Test]
    procedure FindText_RepeatedSearch_SelectsNextMatch;

    [Test]
    procedure FindPrevious_NoSelection_SelectsLastMatch;

    [Test]
    procedure FindText_MatchInView_KeepsScrollPosition;

    [Test]
    procedure FindText_MatchBelowView_ScrollsToMatch;

    [Test]
    procedure HighlightMatches_SeveralMatches_CountsEveryMatch;

    [Test]
    procedure SetText_BuildsDocumentAtControlWidth;

    [Test]
    procedure SetText_RoundTripsThroughTextProperty;

    [Test]
    procedure AppendMarkdown_FromMainThread_AppendsToDocument;

    [Test]
    procedure ThemeSwitch_TriggersRelayout;

    [Test]
    procedure DestroyWithPendingImages_DoesNotCrash;

    [Test]
    procedure Paint_ScrolledPastActiveSelection_ConfinesPaintingToViewerBounds;

    [Test]
    procedure Wheel_ContentFitsViewport_LeavesWheelUnhandled;

    [Test]
    procedure Wheel_ContentOverflowsViewport_ScrollsAndHandles;

    [Test]
    procedure ScrollBarDrag_OverflowingContent_ScrollsWithoutSelecting;

    [Test]
    procedure Keyboard_CtrlA_SelectsWholeDocument;

    [Test]
    procedure CtrlWheel_Up_ZoomsInOneLevel;

    [Test]
    [TestCase('MainKeyboard', '187')]
    [TestCase('NumericKeypad', '107')]
    procedure Keyboard_CtrlPlus_ZoomsInOneLevel(const Key: Word);

    [Test]
    procedure Keyboard_CtrlZero_ResetsZoom;

    [Test]
    procedure Zoom_Changed_RaisesOnZoomChange;

    [Test]
    procedure Keyboard_ArrowDown_ScrollsOverflowingContent;

    [Test]
    procedure Keyboard_PlainCharacter_IsLeftToTheHost;

    [Test]
    procedure Text_FailingExtension_ReportsErrorWithViewerAsSender;

    [Test]
    procedure MiddlePress_OverflowingContent_IsAutoScrolling;

    [Test]
    procedure AutoScrollChange_StartAndStop_RaisedForBoth;

    [Test]
    procedure DialogKey_DuringAutoScroll_EndsItAndTakesTheKey;

    [Test]
    procedure DialogKey_WithoutAutoScroll_LeavesTheKey;

    [Test]
    procedure Click_InText_RaisesOnClickOnce;

    [Test]
    procedure Click_OnLink_RaisesOnlyOnLinkClick;

    [Test]
    procedure Drag_PastThreshold_RaisesNoClick;

    [Test]
    procedure DoubleClick_InText_RaisesOnDblClickOnReleaseAndKeepsWord;

    [Test]
    procedure Click_EndingAutoScroll_RaisesNoClick;
  end;

implementation

uses
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Tests.Pipeline.Helpers,
  Markdown4D.Tests.FailingExtensions;

type
  // Widens MouseDown/MouseMove/MouseUp from protected to accessible-in-unit, so a
  // test can drive a text selection the same way a real mouse drag would.
  TMarkdownViewerAccess = class(TMarkdownViewer);

procedure TMarkdownFmxViewerTests.Setup;
begin
  FViewer := TMarkdownViewer.Create(nil);
  FViewer.Width := ControlWidth;
  FViewer.Height := ControlHeight;
end;

procedure TMarkdownFmxViewerTests.TearDown;
begin
  FViewer.Free;
  FViewer := nil;

  FExternalTheme.Free;
  FExternalTheme := nil;

  FAutoScrollChangeCount := 0;
  FZoomChangeCount := 0;
  FClickCount := 0;
  FDoubleClickCount := 0;
  FLinkClickCount := 0;
end;

procedure TMarkdownFmxViewerTests.NewViewer_HasEmptySelectedText;
begin
  Assert.AreEqual('', FViewer.SelectedText);
end;

procedure TMarkdownFmxViewerTests.FindText_RepeatedSearch_SelectsNextMatch;
begin
  FViewer.Text := RepeatedWordMarkdown;

  FViewer.FindText(RepeatedWord);
  Assert.AreEqual('Alpha', FViewer.SelectedText);

  FViewer.FindText(RepeatedWord);
  Assert.AreEqual('alpha', FViewer.SelectedText);
end;

procedure TMarkdownFmxViewerTests.FindPrevious_NoSelection_SelectsLastMatch;
begin
  FViewer.Text := RepeatedWordMarkdown;

  const Found = FViewer.FindPrevious(RepeatedWord);

  Assert.IsTrue(Found);
  Assert.AreEqual('alpha', FViewer.SelectedText);
end;

procedure TMarkdownFmxViewerTests.FindText_MatchInView_KeepsScrollPosition;
begin
  FViewer.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(TallParagraphCount);

  FViewer.FindText(SecondParagraph);

  Assert.AreEqual(0.0, Double(FViewer.ScrollOffset), 0.01);
end;

procedure TMarkdownFmxViewerTests.FindText_MatchBelowView_ScrollsToMatch;
begin
  FViewer.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(TallParagraphCount);

  FViewer.FindText(LastParagraph);

  Assert.IsTrue(FViewer.ScrollOffset > 0, 'A match below the viewport should be scrolled into view');
end;

procedure TMarkdownFmxViewerTests.HighlightMatches_SeveralMatches_CountsEveryMatch;
begin
  FViewer.Text := RepeatedWordMarkdown;

  FViewer.HighlightMatches(RepeatedWord);

  Assert.AreEqual(2, FViewer.HighlightCount);
  Assert.AreEqual(2, FViewer.FindMatchCount(RepeatedWord));
end;

procedure TMarkdownFmxViewerTests.SetText_BuildsDocumentAtControlWidth;
begin
  FViewer.Text := SampleMarkdown;

  Assert.IsTrue(FViewer.ContentHeight > 0, 'Expected the display list to build a non-empty document height');
end;

procedure TMarkdownFmxViewerTests.SetText_RoundTripsThroughTextProperty;
begin
  FViewer.Text := SampleMarkdown;

  Assert.AreEqual(SampleMarkdown, FViewer.Text);
end;

procedure TMarkdownFmxViewerTests.AppendMarkdown_FromMainThread_AppendsToDocument;
begin
  FViewer.Text := 'one';

  FViewer.AppendMarkdown(' two');

  Assert.IsTrue(FViewer.Text.Contains('two'), 'Expected appended markdown to be present after flushing');
end;

procedure TMarkdownFmxViewerTests.ThemeSwitch_TriggersRelayout;
begin
  FViewer.Text := SampleMarkdown;

  FExternalTheme := TMarkdownTheme.CreateDark;
  FViewer.Theme := FExternalTheme;

  Assert.IsTrue(FViewer.ContentHeight > 0, 'Expected the viewer to relayout after a theme switch');
end;

procedure TMarkdownFmxViewerTests.DestroyWithPendingImages_DoesNotCrash;
begin
  const Viewer = TMarkdownViewer.Create(nil);
  try
    Viewer.Width := ControlWidth;
    Viewer.Height := ControlHeight;
    Viewer.Text := ImageMarkdown;
  finally
    Viewer.Free;
  end;

  Assert.Pass('Destroying a viewer with pending image slots must not crash');
end;

procedure TMarkdownFmxViewerTests.Paint_ScrolledPastActiveSelection_ConfinesPaintingToViewerBounds;
begin
  FViewer.Width := ClipTestViewerWidth;
  FViewer.Height := ClipTestViewerHeight;
  FViewer.Text := ClipTestMarkdown;

  const Access = TMarkdownViewerAccess(FViewer);
  Access.MouseDown(TMouseButton.mbLeft, [], ClipTestSelectionStartX, 2);
  Access.MouseMove([], ClipTestSelectionEndX, ClipTestSelectionBottomY);
  Access.MouseUp(TMouseButton.mbLeft, [], ClipTestSelectionEndX, ClipTestSelectionBottomY);
  Assert.AreNotEqual('', FViewer.SelectedText,
    'Expected the drag to select text near the top of the document before scrolling it out of view');

  FViewer.ScrollOffset := FViewer.ContentHeight;
  const ScrollY = FViewer.ScrollOffset;
  Assert.IsTrue(ScrollY > ClipTestSelectionBottomY,
    'Expected scrolling to the bottom to move the selected text above the current viewport');

  // Placing the destination rect at ScrollY within a canvas as tall as the scroll
  // position lines up doc-space coordinates with canvas coordinates one-to-one, so
  // anything painted above row 0 of this canvas is painting above the whole document.
  const CanvasHeight = Round(ScrollY) + Round(ClipTestViewerHeight);
  const Bitmap = TBitmap.Create(Round(ClipTestViewerWidth), CanvasHeight);
  try
    Bitmap.Clear(TAlphaColorRec.White);

    if Bitmap.Canvas.BeginScene then
    try
      FViewer.PaintTo(Bitmap.Canvas, TRectF.Create(0, ScrollY, ClipTestViewerWidth, ScrollY + ClipTestViewerHeight));
    finally
      Bitmap.Canvas.EndScene;
    end;

    const BandHeight = Round(ClipTestSelectionBottomY) + ClipTestBandHeight;
    Assert.IsTrue(IsBandUntouched(Bitmap, BandHeight),
      'Expected nothing to paint above the viewer''s own rectangle once scrolled past the selection');
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownFmxViewerTests.Wheel_ContentFitsViewport_LeavesWheelUnhandled;
begin
  FViewer.Text := SampleMarkdown;

  var Handled := False;
  TMarkdownViewerAccess(FViewer).MouseWheel([], WheelNotchDown, Handled);

  Assert.IsFalse(Handled, 'A viewer whose content fits should pass the wheel to its parent');
end;

procedure TMarkdownFmxViewerTests.Wheel_ContentOverflowsViewport_ScrollsAndHandles;
begin
  FViewer.Text := ClipTestMarkdown;

  var Handled := False;
  TMarkdownViewerAccess(FViewer).MouseWheel([], WheelNotchDown, Handled);

  Assert.IsTrue(Handled, 'A scrollable viewer should claim the wheel');
  Assert.IsTrue(FViewer.ScrollOffset > 0, 'The wheel should have scrolled the content down');
end;

procedure TMarkdownFmxViewerTests.ScrollBarDrag_OverflowingContent_ScrollsWithoutSelecting;
begin
  FViewer.Text := ClipTestMarkdown;

  const Access = TMarkdownViewerAccess(FViewer);
  const LaneX = FViewer.Width - 3;
  Access.MouseDown(TMouseButton.mbLeft, [], LaneX, 30);
  Access.MouseMove([], LaneX, 120);
  Access.MouseUp(TMouseButton.mbLeft, [], LaneX, 120);

  Assert.IsTrue(FViewer.ScrollOffset > 0, 'Dragging the scrollbar thumb must scroll the content');
  Assert.AreEqual('', FViewer.SelectedText, 'A scrollbar drag must not select text');
end;

procedure TMarkdownFmxViewerTests.PressKey(const Key: Word; const Shift: TShiftState);
begin
  var PressedKey: Word := Key;
  var PressedChar: WideChar := #0;
  TMarkdownViewerAccess(FViewer).KeyDown(PressedKey, PressedChar, Shift);
end;

procedure TMarkdownFmxViewerTests.CtrlWheel_Up_ZoomsInOneLevel;
begin
  FViewer.Text := KeyboardMarkdown;

  var Handled := False;
  TMarkdownViewerAccess(FViewer).MouseWheel([ssCtrl], WheelNotchUp, Handled);

  Assert.IsTrue(Handled);
  Assert.AreEqual(110, FViewer.Zoom);
end;

procedure TMarkdownFmxViewerTests.Keyboard_CtrlPlus_ZoomsInOneLevel(const Key: Word);
begin
  FViewer.Text := KeyboardMarkdown;

  PressKey(Key, [ssCtrl]);

  Assert.AreEqual(110, FViewer.Zoom);
end;

procedure TMarkdownFmxViewerTests.Keyboard_CtrlZero_ResetsZoom;
begin
  FViewer.Text := KeyboardMarkdown;
  FViewer.Zoom := 200;

  PressKey(vk0, [ssCtrl]);

  Assert.AreEqual(100, FViewer.Zoom);
end;

procedure TMarkdownFmxViewerTests.Zoom_Changed_RaisesOnZoomChange;
begin
  FViewer.Text := KeyboardMarkdown;
  FViewer.OnZoomChange := RecordZoomChange;

  FViewer.Zoom := 150;
  FViewer.Zoom := 150;

  Assert.AreEqual(1, FZoomChangeCount);
end;

procedure TMarkdownFmxViewerTests.Keyboard_CtrlA_SelectsWholeDocument;
begin
  FViewer.Text := KeyboardMarkdown;

  PressKey(vkA, [ssCtrl]);

  Assert.AreEqual(KeyboardMarkdown, FViewer.SelectedText);
end;

procedure TMarkdownFmxViewerTests.Keyboard_ArrowDown_ScrollsOverflowingContent;
begin
  FViewer.Text := ClipTestMarkdown;

  PressKey(vkDown, []);

  Assert.IsTrue(FViewer.ScrollOffset > 0, 'The down arrow should scroll a viewer whose content overflows');
end;

procedure TMarkdownFmxViewerTests.Keyboard_PlainCharacter_IsLeftToTheHost;
begin
  FViewer.Text := KeyboardMarkdown;

  var PressedKey: Word := vkA;
  var PressedChar: WideChar := 'a';
  TMarkdownViewerAccess(FViewer).KeyDown(PressedKey, PressedChar, []);

  Assert.AreEqual(Word(vkA), PressedKey, 'A viewer must not swallow keys it has no use for');
  Assert.AreEqual('a', string(PressedChar));
end;

class function TMarkdownFmxViewerTests.IsBandUntouched(const Bitmap: TBitmap; const BandHeight: Integer): Boolean;
begin
  Result := True;

  var Data: TBitmapData;
  if not Bitmap.Map(TMapAccess.Read, Data) then
  begin
    Result := False;
    Exit;
  end;

  try
    for var YIndex := 0 to BandHeight - 1 do
    begin
      for var XIndex := 0 to Bitmap.Width - 1 do
      begin
        const IsWhite = (Data.GetPixel(XIndex, YIndex) = TAlphaColorRec.White);
        if not IsWhite then
        begin
          Result := False;
          Exit;
        end;
      end;
    end;
  finally
    Bitmap.Unmap(Data);
  end;
end;

procedure TMarkdownFmxViewerTests.Text_FailingExtension_ReportsErrorWithViewerAsSender;
begin
  TLayoutDocumentProcessorRegistry.Register(TFailingDocumentProcessor.ProcessorName, TFailingDocumentProcessor.Create);
  try
    FViewer.OnExtensionError := RecordExtensionError;

    FViewer.Text := SampleMarkdown;

    Assert.AreSame(FViewer, FReportedSender, 'The viewer, not its internal model, must be the sender');
  finally
    TLayoutDocumentProcessorRegistry.Clear;
  end;
end;

procedure TMarkdownFmxViewerTests.RecordExtensionError(const Sender: TObject; const Extension: string;
  const Error: Exception);
begin
  FReportedSender := Sender;
end;

procedure TMarkdownFmxViewerTests.MiddlePress_OverflowingContent_IsAutoScrolling;
begin
  StartAutoScroll;

  Assert.IsTrue(FViewer.IsAutoScrolling);
end;

procedure TMarkdownFmxViewerTests.AutoScrollChange_StartAndStop_RaisedForBoth;
begin
  FViewer.OnAutoScrollChange := RecordAutoScrollChange;

  StartAutoScroll;
  PressKey(vkDown, []);

  Assert.AreEqual(2, FAutoScrollChangeCount);
  Assert.IsFalse(FViewer.IsAutoScrolling);
end;

// The form offers F-keys and Ctrl or Alt combinations to the focused
// control's DialogKey before its menus and action lists.
procedure TMarkdownFmxViewerTests.DialogKey_DuringAutoScroll_EndsItAndTakesTheKey;
begin
  StartAutoScroll;

  const RemainingKey = PressDialogKey(vkF3);

  Assert.IsFalse(FViewer.IsAutoScrolling, 'The key must end autoscroll');
  Assert.AreEqual(0, Integer(RemainingKey), 'The key that ends autoscroll must not reach a shortcut');
end;

procedure TMarkdownFmxViewerTests.DialogKey_WithoutAutoScroll_LeavesTheKey;
begin
  FViewer.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(TallParagraphCount);

  const RemainingKey = PressDialogKey(vkF3);

  Assert.AreEqual(Integer(vkF3), Integer(RemainingKey));
end;

procedure TMarkdownFmxViewerTests.StartAutoScroll;
begin
  FViewer.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(TallParagraphCount);
  TMarkdownViewerAccess(FViewer).MouseDown(TMouseButton.mbMiddle, [], 10, 10);
end;

function TMarkdownFmxViewerTests.PressDialogKey(const Key: Word): Word;
begin
  Result := Key;
  TMarkdownViewerAccess(FViewer).DialogKey(Result, []);
end;

procedure TMarkdownFmxViewerTests.RecordAutoScrollChange(Sender: TObject);
begin
  Inc(FAutoScrollChangeCount);
end;

procedure TMarkdownFmxViewerTests.RecordZoomChange(Sender: TObject);
begin
  Inc(FZoomChangeCount);
end;

procedure TMarkdownFmxViewerTests.Click_InText_RaisesOnClickOnce;
begin
  ShowClickMarkdown(ClickMarkdown);
  const Center = FirstTextRunCenter;

  PressAt(Center, []);
  ReleaseAt(Center);

  Assert.AreEqual(1, FClickCount);
  Assert.AreEqual(0, FDoubleClickCount);
end;

procedure TMarkdownFmxViewerTests.Click_OnLink_RaisesOnlyOnLinkClick;
begin
  ShowClickMarkdown(LinkMarkdown);
  const Center = FirstTextRunCenter;

  PressAt(Center, []);
  ReleaseAt(Center);

  Assert.AreEqual(1, FLinkClickCount);
  Assert.AreEqual(0, FClickCount, 'A click on a link is not a click in the text');
end;

procedure TMarkdownFmxViewerTests.Drag_PastThreshold_RaisesNoClick;
begin
  ShowClickMarkdown(ClickMarkdown);
  const Center = FirstTextRunCenter;
  const Dragged = TPointF.Create(Center.X + DragDistance, Center.Y);

  PressAt(Center, []);
  TMarkdownViewerAccess(FViewer).MouseMove([ssLeft], Dragged.X, Dragged.Y);
  ReleaseAt(Dragged);

  Assert.AreEqual(0, FClickCount, 'A drag selects text and is no click');
end;

procedure TMarkdownFmxViewerTests.DoubleClick_InText_RaisesOnDblClickOnReleaseAndKeepsWord;
begin
  ShowClickMarkdown(ClickMarkdown);
  const Center = FirstTextRunCenter;
  PressAt(Center, []);
  ReleaseAt(Center);

  PressAt(Center, [ssDouble]);
  const DoubleClicksWhilePressed = FDoubleClickCount;
  ReleaseAt(Center);

  Assert.AreEqual(0, DoubleClicksWhilePressed, 'The double click comes on release');
  Assert.AreEqual(1, FDoubleClickCount);
  Assert.AreEqual(1, FClickCount, 'The second press of a double click is no extra click');
  Assert.AreEqual(ClickMarkdown, FViewer.SelectedText);
end;

procedure TMarkdownFmxViewerTests.Click_EndingAutoScroll_RaisesNoClick;
begin
  StartAutoScroll;
  FViewer.OnClick := RecordClick;
  const Point = TPointF.Create(10, 10);

  PressAt(Point, []);
  ReleaseAt(Point);

  Assert.IsFalse(FViewer.IsAutoScrolling);
  Assert.AreEqual(0, FClickCount, 'The click that ends autoscroll is no click in the text');
end;

procedure TMarkdownFmxViewerTests.ShowClickMarkdown(const Markdown: string);
begin
  FViewer.Text := Markdown;
  FViewer.OnClick := RecordClick;
  FViewer.OnDblClick := RecordDoubleClick;
  FViewer.OnLinkClick := RecordLinkClick;
end;

function TMarkdownFmxViewerTests.FirstTextRunCenter: TPointF;
begin
  Result := TPointF.Zero;

  const DisplayList = FViewer.DisplayList;
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    if Supports(DisplayList.Items[Index], IDisplayTextRun, Run) then
    begin
      const Bounds = Run.Bounds;
      Result := TPointF.Create((Bounds.Left + Bounds.Right) / 2, (Bounds.Top + Bounds.Bottom) / 2);
      Exit;
    end;
  end;

  Assert.Fail('The viewer laid out no text run');
end;

procedure TMarkdownFmxViewerTests.PressAt(const Point: TPointF; const Shift: TShiftState);
begin
  TMarkdownViewerAccess(FViewer).MouseDown(TMouseButton.mbLeft, Shift + [ssLeft], Point.X, Point.Y);
end;

// In the order the form delivers a release: MouseClick first, then MouseUp.
procedure TMarkdownFmxViewerTests.ReleaseAt(const Point: TPointF);
begin
  TMarkdownViewerAccess(FViewer).MouseClick(TMouseButton.mbLeft, [], Point.X, Point.Y);
  TMarkdownViewerAccess(FViewer).MouseUp(TMouseButton.mbLeft, [], Point.X, Point.Y);
end;

procedure TMarkdownFmxViewerTests.RecordClick(Sender: TObject);
begin
  Inc(FClickCount);
end;

procedure TMarkdownFmxViewerTests.RecordDoubleClick(Sender: TObject);
begin
  Inc(FDoubleClickCount);
end;

procedure TMarkdownFmxViewerTests.RecordLinkClick(const Sender: TObject; const Url: string);
begin
  Inc(FLinkClickCount);
end;

end.