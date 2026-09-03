unit Markdown4D.Fmx.Viewer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
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
      ClipTestViewerWidth = 300.0;
      ClipTestViewerHeight = 80.0;
      ClipTestSelectionStartX = 5.0;
      ClipTestSelectionEndX = 250.0;
      ClipTestSelectionBottomY = 40.0;
      ClipTestBandHeight = 60;
      WheelNotchDown = -120;
      KeyboardMarkdown = 'alpha beta';
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
    class function IsBandUntouched(const Bitmap: TBitmap; const BandHeight: Integer): Boolean;
    procedure PressKey(const Key: Word; const Shift: TShiftState);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure NewViewer_HasEmptySelectedText;

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
    procedure Keyboard_ArrowDown_ScrollsOverflowingContent;

    [Test]
    procedure Keyboard_PlainCharacter_IsLeftToTheHost;
  end;

implementation

uses
  System.SysUtils;

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
end;

procedure TMarkdownFmxViewerTests.NewViewer_HasEmptySelectedText;
begin
  Assert.AreEqual('', FViewer.SelectedText);
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
    Exit(False);

  try
    for var YIndex := 0 to BandHeight - 1 do
    begin
      for var XIndex := 0 to Bitmap.Width - 1 do
      begin
        const IsWhite = (Data.GetPixel(XIndex, YIndex) = TAlphaColorRec.White);
        if not IsWhite then
          Exit(False);
      end;
    end;
  finally
    Bitmap.Unmap(Data);
  end;
end;

end.
