unit Markdown4D.Vcl.Viewer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  DUnitX.TestFramework,
  Markdown4D.Vcl.Viewer;

type
  TTestableVclViewer = class(TMarkdownViewer)
  public
    function SimulateWheel(const WheelDelta: Integer): Boolean;
    procedure SimulateKeyDown(const Key: Word; const Shift: TShiftState);
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
    var
      FHostForm: TForm;
      FReportedSender: TObject;
    function NewHostedViewer: TTestableVclViewer;
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
  end;

implementation

uses
  System.Types,
  Winapi.Windows,
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

procedure TMarkdownVclViewerTests.TearDown;
begin
  FHostForm.Free;
  FHostForm := nil;
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

end.