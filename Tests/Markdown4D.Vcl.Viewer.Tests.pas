unit Markdown4D.Vcl.Viewer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  Vcl.Forms,
  DUnitX.TestFramework,
  Markdown4D.Vcl.Viewer;

type
  TTestableVclViewer = class(TMarkdownViewer)
  public
    function SimulateWheel(const WheelDelta: Integer): Boolean;
    procedure SimulateKeyDown(const Key: Word; const Shift: TShiftState);
    procedure SimulateMiddlePress;
    procedure SimulateKeyFromMessageLoop(const Key: Word);
    procedure SendMouse(const Message: Cardinal; const X, Y: Integer);
  end;

  [TestFixture]
  TMarkdownVclViewerTests = class
  private
    const
      HostWidth = 400;
      HostHeight = 120;
      ShortMarkdown = 'one line';
      ParagraphCount = 40;
      RepeatedWordMarkdown = 'Alpha beta alpha';
      RepeatedWord = 'alpha';
      LastParagraph = 'Paragraph 39';
      SecondParagraph = 'Paragraph 01';
      ScaleTolerance = 0.1;
      GrowthNumerator = 3;
      GrowthDenominator = 2;
      ClickMarkdown = 'alpha';
      LinkMarkdown = '[alpha](https://example.com)';
      DragDistance = 40;
    var
      FHostForm: TForm;
      FReportedSender: TObject;
      FFormKeyCount: Integer;
      FAutoScrollChangeCount: Integer;
      FClickCount: Integer;
      FDoubleClickCount: Integer;
      FLinkClickCount: Integer;
    function NewHostedViewer: TTestableVclViewer;
    function NewViewerOnPreviewingForm: TTestableVclViewer;
    procedure RecordFormKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure RecordAutoScrollChange(Sender: TObject);
    function NewClickRecordingViewer(const Markdown: string): TTestableVclViewer;
    class function FirstTextRunCenter(const Viewer: TMarkdownViewer): TPoint; static;
    procedure RecordClick(Sender: TObject);
    procedure RecordDoubleClick(Sender: TObject);
    procedure RecordLinkClick(const Sender: TObject; const Url: string);
    class function FirstTextRunHeight(const Viewer: TMarkdownViewer): Single; static;
    procedure RecordExtensionError(const Sender: TObject; const Extension: string; const Error: Exception);

  public
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Wheel_ContentFitsViewport_LeavesWheelUnhandled;

    [Test]
    procedure Wheel_ContentOverflowsViewport_ScrollsAndHandles;

    [Test]
    procedure Keyboard_CtrlA_SelectsWholeDocument;

    [Test]
    procedure Keyboard_ArrowDown_ScrollsOverflowingContent;

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
    procedure ScaleForPPI_OnHostForm_ScalesText;

    [Test]
    procedure Text_FailingExtension_ReportsErrorWithViewerAsSender;

    [Test]
    procedure MiddlePress_OverflowingContent_IsAutoScrolling;

    [Test]
    procedure AutoScrollChange_StartAndStop_RaisedForBoth;

    [Test]
    procedure ShortcutKey_DuringAutoScroll_EndsItBeforeTheForm;

    [Test]
    procedure ShortcutKey_WithoutAutoScroll_ReachesTheForm;

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
  System.UITypes,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Controls,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Tests.Pipeline.Helpers,
  Markdown4D.Tests.FailingExtensions;

function TTestableVclViewer.SimulateWheel(const WheelDelta: Integer): Boolean;
begin
  Result := DoMouseWheel([], WheelDelta, TPoint.Create(0, 0));
end;

procedure TTestableVclViewer.SimulateKeyDown(const Key: Word; const Shift: TShiftState);
begin
  var PressedKey := Key;
  KeyDown(PressedKey, Shift);
end;

procedure TTestableVclViewer.SimulateMiddlePress;
begin
  MouseDown(TMouseButton.mbMiddle, [], 10, 10);
end;

// As the VCL message loop delivers a key: CN_KEYDOWN first, where menu and
// action shortcuts are handled, and WM_KEYDOWN only when nothing took it.
procedure TTestableVclViewer.SimulateKeyFromMessageLoop(const Key: Word);
begin
  const Handled = (Perform(CN_KEYDOWN, Key, 0) <> 0);
  if not Handled then
    Perform(WM_KEYDOWN, Key, 0);
end;

procedure TTestableVclViewer.SendMouse(const Message: Cardinal; const X, Y: Integer);
begin
  const IsPressed = ((Message = WM_LBUTTONDOWN) or (Message = WM_LBUTTONDBLCLK) or (Message = WM_MOUSEMOVE));
  var Keys: WPARAM := 0;
  if IsPressed then
    Keys := MK_LBUTTON;

  Perform(Message, Keys, MakeLParam(X, Y));
end;

procedure TMarkdownVclViewerTests.TearDown;
begin
  FHostForm.Free;
  FHostForm := nil;

  FFormKeyCount := 0;
  FAutoScrollChangeCount := 0;
  FClickCount := 0;
  FDoubleClickCount := 0;
  FLinkClickCount := 0;
end;

function TMarkdownVclViewerTests.NewHostedViewer: TTestableVclViewer;
begin
  FHostForm := TForm.CreateNew(nil);
  FHostForm.ClientWidth := HostWidth;
  FHostForm.ClientHeight := HostHeight;

  Result := TTestableVclViewer.Create(FHostForm);
  Result.Visible := False;
  Result.Parent := FHostForm;
  Result.SetBounds(0, 0, HostWidth, HostHeight);
  Result.HandleNeeded;
end;

procedure TMarkdownVclViewerTests.Wheel_ContentFitsViewport_LeavesWheelUnhandled;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := ShortMarkdown;

  Assert.IsFalse(Viewer.SimulateWheel(-WHEEL_DELTA),
    'A viewer whose content fits should pass the wheel to its parent');
end;

procedure TMarkdownVclViewerTests.Wheel_ContentOverflowsViewport_ScrollsAndHandles;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(ParagraphCount);

  Assert.IsTrue(Viewer.SimulateWheel(-WHEEL_DELTA), 'A scrollable viewer should claim the wheel');
  Assert.IsTrue(Viewer.ScrollOffset > 0, 'The wheel should have scrolled the content down');
end;

procedure TMarkdownVclViewerTests.Keyboard_CtrlA_SelectsWholeDocument;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := ShortMarkdown;

  Viewer.SimulateKeyDown(Ord('A'), [ssCtrl]);

  Assert.AreEqual(ShortMarkdown, Viewer.SelectedText);
end;

procedure TMarkdownVclViewerTests.Keyboard_ArrowDown_ScrollsOverflowingContent;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(ParagraphCount);

  Viewer.SimulateKeyDown(VK_DOWN, []);

  Assert.IsTrue(Viewer.ScrollOffset > 0, 'The down arrow should scroll a viewer whose content overflows');
end;

procedure TMarkdownVclViewerTests.FindText_RepeatedSearch_SelectsNextMatch;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := RepeatedWordMarkdown;

  Viewer.FindText(RepeatedWord);
  Assert.AreEqual('Alpha', Viewer.SelectedText);

  Viewer.FindText(RepeatedWord);
  Assert.AreEqual('alpha', Viewer.SelectedText);
end;

procedure TMarkdownVclViewerTests.FindPrevious_NoSelection_SelectsLastMatch;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := RepeatedWordMarkdown;

  const Found = Viewer.FindPrevious(RepeatedWord);

  Assert.IsTrue(Found);
  Assert.AreEqual('alpha', Viewer.SelectedText);
end;

procedure TMarkdownVclViewerTests.FindText_MatchInView_KeepsScrollPosition;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(ParagraphCount);

  Viewer.FindText(SecondParagraph);

  Assert.AreEqual(0.0, Double(Viewer.ScrollOffset), 0.01);
end;

procedure TMarkdownVclViewerTests.FindText_MatchBelowView_ScrollsToMatch;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(ParagraphCount);

  Viewer.FindText(LastParagraph);

  Assert.IsTrue(Viewer.ScrollOffset > 0, 'A match below the viewport should be scrolled into view');
end;

procedure TMarkdownVclViewerTests.HighlightMatches_SeveralMatches_CountsEveryMatch;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := RepeatedWordMarkdown;

  Viewer.HighlightMatches(RepeatedWord);

  Assert.AreEqual(2, Viewer.HighlightCount);
  Assert.AreEqual(2, Viewer.FindMatchCount(RepeatedWord));
end;

procedure TMarkdownVclViewerTests.ScaleForPPI_OnHostForm_ScalesText;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := ShortMarkdown;
  const HeightBefore = FirstTextRunHeight(Viewer);
  const ScaledPixelsPerInch = MulDiv(FHostForm.PixelsPerInch, GrowthNumerator, GrowthDenominator);

  FHostForm.ScaleForPPI(ScaledPixelsPerInch);

  const HeightAfter = FirstTextRunHeight(Viewer);
  const ExpectedHeight = HeightBefore * GrowthNumerator / GrowthDenominator;
  Assert.AreEqual(ExpectedHeight, Double(HeightAfter), Double(HeightBefore * ScaleTolerance),
    'The text must grow with the form it is on, as the controls around it do');
end;

class function TMarkdownVclViewerTests.FirstTextRunHeight(const Viewer: TMarkdownViewer): Single;
begin
  Result := 0;

  const DisplayList = Viewer.DisplayList;
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    if Supports(DisplayList.Items[Index], IDisplayTextRun, Run) then
    begin
      Result := Run.Bounds.Height;
      Exit;
    end;
  end;

  Assert.Fail('The viewer laid out no text run');
end;

procedure TMarkdownVclViewerTests.Text_FailingExtension_ReportsErrorWithViewerAsSender;
begin
  TLayoutDocumentProcessorRegistry.Register(TFailingDocumentProcessor.ProcessorName, TFailingDocumentProcessor.Create);
  try
    const Viewer = NewHostedViewer;
    Viewer.OnExtensionError := RecordExtensionError;

    Viewer.Text := ShortMarkdown;

    Assert.AreSame(Viewer, FReportedSender, 'The viewer, not its internal model, must be the sender');
  finally
    TLayoutDocumentProcessorRegistry.Clear;
  end;
end;

procedure TMarkdownVclViewerTests.RecordExtensionError(const Sender: TObject; const Extension: string;
  const Error: Exception);
begin
  FReportedSender := Sender;
end;

procedure TMarkdownVclViewerTests.MiddlePress_OverflowingContent_IsAutoScrolling;
begin
  const Viewer = NewViewerOnPreviewingForm;

  Viewer.SimulateMiddlePress;

  Assert.IsTrue(Viewer.IsAutoScrolling);
end;

procedure TMarkdownVclViewerTests.AutoScrollChange_StartAndStop_RaisedForBoth;
begin
  const Viewer = NewViewerOnPreviewingForm;
  Viewer.OnAutoScrollChange := RecordAutoScrollChange;

  Viewer.SimulateMiddlePress;
  Viewer.SimulateKeyFromMessageLoop(VK_DOWN);

  Assert.AreEqual(2, FAutoScrollChangeCount);
  Assert.IsFalse(Viewer.IsAutoScrolling);
end;

procedure TMarkdownVclViewerTests.ShortcutKey_DuringAutoScroll_EndsItBeforeTheForm;
begin
  const Viewer = NewViewerOnPreviewingForm;
  Viewer.SimulateMiddlePress;

  Viewer.SimulateKeyFromMessageLoop(VK_F3);

  Assert.IsFalse(Viewer.IsAutoScrolling, 'The key must end autoscroll');
  Assert.AreEqual(0, FFormKeyCount, 'The key that ends autoscroll must not reach the form');
end;

procedure TMarkdownVclViewerTests.ShortcutKey_WithoutAutoScroll_ReachesTheForm;
begin
  const Viewer = NewViewerOnPreviewingForm;

  Viewer.SimulateKeyFromMessageLoop(VK_F3);

  Assert.AreEqual(1, FFormKeyCount);
end;

function TMarkdownVclViewerTests.NewViewerOnPreviewingForm: TTestableVclViewer;
begin
  Result := NewHostedViewer;
  Result.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(ParagraphCount);

  FHostForm.KeyPreview := True;
  FHostForm.OnKeyDown := RecordFormKey;
end;

procedure TMarkdownVclViewerTests.RecordFormKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  Inc(FFormKeyCount);
  Key := 0;
end;

procedure TMarkdownVclViewerTests.RecordAutoScrollChange(Sender: TObject);
begin
  Inc(FAutoScrollChangeCount);
end;

procedure TMarkdownVclViewerTests.Click_InText_RaisesOnClickOnce;
begin
  const Viewer = NewClickRecordingViewer(ClickMarkdown);
  const Center = FirstTextRunCenter(Viewer);

  Viewer.SendMouse(WM_LBUTTONDOWN, Center.X, Center.Y);
  Viewer.SendMouse(WM_LBUTTONUP, Center.X, Center.Y);

  Assert.AreEqual(1, FClickCount);
  Assert.AreEqual(0, FDoubleClickCount);
end;

procedure TMarkdownVclViewerTests.Click_OnLink_RaisesOnlyOnLinkClick;
begin
  const Viewer = NewClickRecordingViewer(LinkMarkdown);
  const Center = FirstTextRunCenter(Viewer);

  Viewer.SendMouse(WM_LBUTTONDOWN, Center.X, Center.Y);
  Viewer.SendMouse(WM_LBUTTONUP, Center.X, Center.Y);

  Assert.AreEqual(1, FLinkClickCount);
  Assert.AreEqual(0, FClickCount, 'A click on a link is not a click in the text');
end;

procedure TMarkdownVclViewerTests.Drag_PastThreshold_RaisesNoClick;
begin
  const Viewer = NewClickRecordingViewer(ClickMarkdown);
  const Center = FirstTextRunCenter(Viewer);

  Viewer.SendMouse(WM_LBUTTONDOWN, Center.X, Center.Y);
  Viewer.SendMouse(WM_MOUSEMOVE, Center.X + DragDistance, Center.Y);
  Viewer.SendMouse(WM_LBUTTONUP, Center.X + DragDistance, Center.Y);

  Assert.AreEqual(0, FClickCount, 'A drag selects text and is no click');
end;

procedure TMarkdownVclViewerTests.DoubleClick_InText_RaisesOnDblClickOnReleaseAndKeepsWord;
begin
  const Viewer = NewClickRecordingViewer(ClickMarkdown);
  const Center = FirstTextRunCenter(Viewer);
  Viewer.SendMouse(WM_LBUTTONDOWN, Center.X, Center.Y);
  Viewer.SendMouse(WM_LBUTTONUP, Center.X, Center.Y);

  Viewer.SendMouse(WM_LBUTTONDBLCLK, Center.X, Center.Y);
  const DoubleClicksWhilePressed = FDoubleClickCount;
  Viewer.SendMouse(WM_LBUTTONUP, Center.X, Center.Y);

  Assert.AreEqual(0, DoubleClicksWhilePressed, 'The double click comes on release');
  Assert.AreEqual(1, FDoubleClickCount);
  Assert.AreEqual(1, FClickCount, 'The second press of a double click is no extra click');
  Assert.AreEqual(ClickMarkdown, Viewer.SelectedText);
end;

procedure TMarkdownVclViewerTests.Click_EndingAutoScroll_RaisesNoClick;
begin
  const Viewer = NewViewerOnPreviewingForm;
  Viewer.OnClick := RecordClick;
  Viewer.SimulateMiddlePress;

  Viewer.SendMouse(WM_LBUTTONDOWN, 10, 10);
  Viewer.SendMouse(WM_LBUTTONUP, 10, 10);

  Assert.IsFalse(Viewer.IsAutoScrolling);
  Assert.AreEqual(0, FClickCount, 'The click that ends autoscroll is no click in the text');
end;

function TMarkdownVclViewerTests.NewClickRecordingViewer(const Markdown: string): TTestableVclViewer;
begin
  Result := NewHostedViewer;
  Result.Text := Markdown;
  Result.OnClick := RecordClick;
  Result.OnDblClick := RecordDoubleClick;
  Result.OnLinkClick := RecordLinkClick;
end;

class function TMarkdownVclViewerTests.FirstTextRunCenter(const Viewer: TMarkdownViewer): TPoint;
begin
  Result := TPoint.Zero;

  const DisplayList = Viewer.DisplayList;
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    if Supports(DisplayList.Items[Index], IDisplayTextRun, Run) then
    begin
      const Bounds = Run.Bounds;
      Result := TPoint.Create(Round((Bounds.Left + Bounds.Right) / 2), Round((Bounds.Top + Bounds.Bottom) / 2));
      Exit;
    end;
  end;

  Assert.Fail('The viewer laid out no text run');
end;

procedure TMarkdownVclViewerTests.RecordClick(Sender: TObject);
begin
  Inc(FClickCount);
end;

procedure TMarkdownVclViewerTests.RecordDoubleClick(Sender: TObject);
begin
  Inc(FDoubleClickCount);
end;

procedure TMarkdownVclViewerTests.RecordLinkClick(const Sender: TObject; const Url: string);
begin
  Inc(FLinkClickCount);
end;

end.