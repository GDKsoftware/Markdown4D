unit Markdown4D.Vcl.Editor.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.UITypes,
  Vcl.Forms,
  DUnitX.TestFramework,
  Markdown4D.Editor.Model,
  Markdown4D.Theme,
  Markdown4D.Vcl.Viewer,
  Markdown4D.Vcl.Editor,
  Markdown4D.Tests.VclClipboard;

type
  TTestableVclEditor = class(TMarkdownEditor)
  private
    const
      AutoScrollTimerIntervalMs = 50;
  public
    procedure SimulateMouseDown(const X, Y: Integer; const Shift: TShiftState);
    procedure SimulateMouseMove(const X, Y: Integer; const Shift: TShiftState);
    procedure SimulateMouseUp(const X, Y: Integer; const Shift: TShiftState);
    procedure SimulateKeyDown(const Key: Word; const Shift: TShiftState);
    procedure SimulateKeyChar(const Ch: Char);
    function SimulateWheel(const WheelDelta: Integer; const Shift: TShiftState = []): Boolean;
    procedure SimulateVScroll(const ScrollCode: Word);
    procedure SimulateSetFocus;
    procedure SimulateKillFocus;
    procedure PumpAutoScrollTimer;
    procedure ForcePixelsPerInch(const Value: Integer);
    function CurrentPixelsPerInch: Integer;
    procedure SimulateMiddlePress;
    procedure SimulateKeyFromMessageLoop(const Key: Word);
    procedure SendMouse(const Message: Cardinal; const X, Y: Integer);
  end;

  [TestFixture]
  TMarkdownVclEditorTests = class
  private
    const
      HeadingMarkdown = '# Heading';
      SelectableText = 'alpha beta';
      AdoptedPrefix = 'new ';
      FormatKeySelectionLength = 5;
      EditText = ' appended body';
      MouseText = 'Hello world'#10'second';
      WordPairText = 'foo bar';
      DeleteKeyChar = #127;
      FarRight = 100000;
      FarDown = 100000;
      HostWidth = 400;
      ShortHostHeight = 100;
      ManyLineCount = 40;
      HighDpi = 192;
      ScaleTolerance = 0.05;
      GrowthNumerator = 3;
      GrowthDenominator = 2;
      ClickText = 'alpha';
      ClickX = 20;
      ClickY = 8;
      DragDistance = 40;
      PreviewScrollTarget = 40;
    var
      FEditor: TMarkdownEditor;
      FHostForm: TForm;
      FFormKeyCount: Integer;
      FAutoScrollChangeCount: Integer;
      FZoomChangeCount: Integer;
      FClickCount: Integer;
      FDoubleClickCount: Integer;
    function NewHostedEditor(const ControlHeight: Integer): TTestableVclEditor;
    function NewEditorOnPreviewingForm: TTestableVclEditor;
    procedure RecordFormKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure RecordAutoScrollChange(Sender: TObject);
    procedure RecordZoomChange(Sender: TObject);
    function NewClickRecordingEditor: TTestableVclEditor;
    procedure RecordClick(Sender: TObject);
    procedure RecordDoubleClick(Sender: TObject);
    function NewHostedPreview(const Editor: TMarkdownEditor): TMarkdownViewer;
    class function ManyLines(const Count: Integer): string; static;
    class function OneWrappedLine: string; static;
    class function ContentHeightOf(const Editor: TMarkdownEditor): Integer; static;

  public
    [Test]
    procedure CtrlWheel_Up_ZoomsInOneLevel;

    [Test]
    [TestCase('MainKeyboard', '187')]
    [TestCase('NumericKeypad', '107')]
    procedure Keyboard_CtrlPlus_ZoomsInOneLevel(const Key: Word);

    [Test]
    procedure Keyboard_CtrlZero_ResetsZoom;

    [Test]
    procedure Zoom_Double_LaysOutAsDoubleCodeFont;

    [Test]
    procedure Zoom_Changed_RaisesOnZoomChange;

    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure NewEditor_ConstructsWithoutForm;

    [Test]
    procedure SetText_RoundTripsThroughTextProperty;

    [Test]
    procedure CaretPosition_IsModelBacked;

    [Test]
    procedure SelectedText_ReflectsModelSelection;

    [Test]
    procedure ExecuteBold_ModifiesText;

    [Test]
    procedure UndoRedo_RestoreAndReapplyEdit;

    [Test]
    procedure AttachPreview_AfterEditAndFlush_PreviewContainsEdit;

    [Test]
    procedure TryAdoptPreviewSelection_PreviewShowsTheSameText_MovesTheSelectionOver;

    [Test]
    procedure TryAdoptPreviewSelection_PreviewShowsOlderText_LeavesTheSelectionAlone;

    [Test]
    procedure TryAdoptPreviewSelection_WithoutAPreview_ReturnsFalse;

    // Bold is a toggle, so a keystroke that reached the command twice would put
    // the markers on and straight back off and the text would come out
    // unchanged. One press changing the text is what proves it ran once.
    [Test]
    [TestCase('Bold', 'B,**alpha** beta')]
    [TestCase('Italic', 'I,*alpha* beta')]
    procedure FormatKey_OnASelection_RunsTheCommandExactlyOnce(const KeyChar: Char; const Expected: string);

    [Test]
    procedure OffscreenPaint_HeadingDiffersFromPlainPixels;

    [Test]
    procedure Click_PlacesCaretAtClickedTextPosition;

    [Test]
    procedure ClickFarBelow_PlacesCaretOnLastLine;

    [Test]
    procedure ClickDrag_SelectsDraggedRange;

    [Test]
    procedure ShiftClick_ExtendsSelectionToClick;

    [Test]
    procedure DoubleClick_SelectsWordUnderCursor;

    [Test]
    procedure TripleClick_SelectsWholeLine;

    [Test]
    procedure DragBelowLastLine_ClampsToDocumentEnd;

    [Test]
    procedure DragOutsideControlBounds_KeepsSelecting;

    [Test]
    procedure KeyChar_InsertsPrintableCharacter;

    [Test]
    procedure KeyChar_IgnoresDeleteControlChar;

    [Test]
    procedure KeyBackspace_DeletesCharBeforeCaret;

    [Test]
    procedure KeyDelete_DeletesCharAfterCaret;

    [Test]
    procedure KeyReturn_InsertsNewLine;

    [Test]
    procedure KeyRightThenLeft_MovesCaretByOne;

    [Test]
    procedure KeyDownThenUp_MovesCaretBetweenLines;

    [Test]
    procedure KeyHomeAndEnd_MoveToLineBounds;

    [Test]
    procedure ShiftArrow_ExtendsSelection;

    [Test]
    procedure CtrlWordArrows_MoveByWord;

    [Test]
    procedure EditWithUnlinkedPreview_KeepsPreviewScrollOffset;

    [Test]
    procedure EditWithLinkedPreview_LeavesPreviewOnEditorOffset;

    [Test]
    procedure EditorScroll_PreviewSizedAfterAttach_MovesPreview;

    [Test]
    procedure PreviewScroll_PreviewSizedAfterAttach_MovesEditor;

    [Test]
    procedure MergeText_KeepsCaretAndUndoHistory;

    [Test]
    procedure CtrlBackspace_DeletesWordBeforeCaret;

    [Test]
    procedure CtrlDelete_DeletesWordAfterCaret;

    [Test]
    procedure CtrlHomeAndEnd_MoveToDocumentBounds;

    [Test]
    procedure CtrlA_SelectsAllText;

    [Test]
    procedure CtrlZ_UndoesAndCtrlY_Redoes;

    [Test]
    procedure CtrlB_TogglesBoldFormatting;

    [Test]
    procedure CtrlI_TogglesItalicFormatting;

    [Test]
    procedure CtrlK_InsertsLinkSyntax;

    [Test]
    procedure CtrlC_CopiesSelectionToClipboard;

    [Test]
    procedure CtrlX_CutsSelectionToClipboard;

    [Test]
    procedure CtrlV_PastesClipboardText;

    [Test]
    procedure MouseWheelDown_ScrollsContentDown;

    [Test]
    procedure ClickAfterScroll_MapsToVisibleLine;

    [Test]
    procedure GutterClick_PlacesCaretAtLineStart;

    [Test]
    procedure VScrollLineAndPage_AdvanceViewport;

    [Test]
    procedure VScrollTopBottomAndThumb_ClampWithoutError;

    [Test]
    procedure PageDownAndPageUp_MoveCaretByPage;

    [Test]
    procedure AutoScrollTimer_DuringDragOutside_AdvancesAndExtends;

    [Test]
    procedure HighDpiClick_MapsCaretToClickedLine;

    [Test]
    procedure ScaleForPPI_OnHostForm_ScalesText;

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
    procedure Drag_PastThreshold_RaisesNoClick;

    [Test]
    procedure DoubleClick_InText_RaisesOnDblClickOnReleaseAndKeepsWord;

    [Test]
    procedure Click_EndingAutoScroll_RaisesNoClick;

    [Test]
    procedure FocusMessages_ShowAndHideCaretWithoutError;

    [Test]
    procedure WordWrap_VerticalArrowsTraverseVisualRows;

    [Test]
    procedure WordWrap_Home_GoesToVisualRowStart;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Clipbrd,
  Vcl.Graphics,
  Markdown4D.Tests.Pipeline.Helpers;

procedure TTestableVclEditor.SimulateMouseDown(const X, Y: Integer; const Shift: TShiftState);
begin
  MouseDown(TMouseButton.mbLeft, Shift, X, Y);
end;

procedure TTestableVclEditor.SimulateMouseMove(const X, Y: Integer; const Shift: TShiftState);
begin
  MouseMove(Shift, X, Y);
end;

procedure TTestableVclEditor.SimulateMouseUp(const X, Y: Integer; const Shift: TShiftState);
begin
  MouseUp(TMouseButton.mbLeft, Shift, X, Y);
end;

procedure TTestableVclEditor.SimulateKeyDown(const Key: Word; const Shift: TShiftState);
begin
  var Value := Key;
  KeyDown(Value, Shift);
end;

procedure TTestableVclEditor.SimulateKeyChar(const Ch: Char);
begin
  var Value := Ch;
  KeyPress(Value);
end;

function TTestableVclEditor.SimulateWheel(const WheelDelta: Integer; const Shift: TShiftState): Boolean;
begin
  Result := DoMouseWheel(Shift, WheelDelta, TPoint.Create(0, 0));
end;

procedure TTestableVclEditor.SimulateVScroll(const ScrollCode: Word);
begin
  Perform(WM_VSCROLL, ScrollCode, 0);
end;

procedure TTestableVclEditor.SimulateSetFocus;
begin
  Perform(WM_SETFOCUS, 0, 0);
end;

procedure TTestableVclEditor.SimulateKillFocus;
begin
  Perform(WM_KILLFOCUS, 0, 0);
end;

procedure TTestableVclEditor.PumpAutoScrollTimer;
begin
  for var Index := 0 to ComponentCount - 1 do
  begin
    const Timer = Components[Index] as TComponent;
    if (Timer is TTimer) and TTimer(Timer).Enabled and (TTimer(Timer).Interval = AutoScrollTimerIntervalMs) then
    begin
      TTimer(Timer).OnTimer(Timer);
      Exit;
    end;
  end;
end;

procedure TTestableVclEditor.SimulateMiddlePress;
begin
  MouseDown(TMouseButton.mbMiddle, [], 10, 10);
end;

// As the VCL message loop delivers a key: CN_KEYDOWN first, where menu and
// action shortcuts are handled, and WM_KEYDOWN only when nothing took it.
procedure TTestableVclEditor.SimulateKeyFromMessageLoop(const Key: Word);
begin
  const Handled = (Perform(CN_KEYDOWN, Key, 0) <> 0);
  if not Handled then
    Perform(WM_KEYDOWN, Key, 0);
end;

procedure TTestableVclEditor.SendMouse(const Message: Cardinal; const X, Y: Integer);
begin
  const IsPressed = ((Message = WM_LBUTTONDOWN) or (Message = WM_LBUTTONDBLCLK) or (Message = WM_MOUSEMOVE));
  var Keys: WPARAM := 0;
  if IsPressed then
    Keys := MK_LBUTTON;

  Perform(Message, Keys, MakeLParam(X, Y));
end;

procedure TTestableVclEditor.ForcePixelsPerInch(const Value: Integer);
begin
  ScaleForPPI(Value);
end;

function TTestableVclEditor.CurrentPixelsPerInch: Integer;
begin
  Result := CurrentPPI;
end;

procedure TMarkdownVclEditorTests.Setup;
begin
  FEditor := TMarkdownEditor.Create(nil);
end;

procedure TMarkdownVclEditorTests.TearDown;
begin
  FEditor.Free;
  FHostForm.Free;
  FHostForm := nil;

  FFormKeyCount := 0;
  FAutoScrollChangeCount := 0;
  FZoomChangeCount := 0;
  FClickCount := 0;
  FDoubleClickCount := 0;
end;

function TMarkdownVclEditorTests.NewHostedEditor(const ControlHeight: Integer): TTestableVclEditor;
begin
  FHostForm := TForm.CreateNew(nil);
  FHostForm.ClientWidth := HostWidth;
  FHostForm.ClientHeight := ControlHeight;

  Result := TTestableVclEditor.Create(FHostForm);
  Result.Visible := False;
  Result.Parent := FHostForm;
  Result.SetBounds(0, 0, HostWidth, ControlHeight);
  Result.HandleNeeded;
end;

class function TMarkdownVclEditorTests.ManyLines(const Count: Integer): string;
begin
  var Builder := '';
  for var Index := 0 to Count - 1 do
  begin
    if Index > 0 then
      Builder := Builder + #10;
    Builder := Builder + Format('L%.2d', [Index]);
  end;
  Result := Builder;
end;

// Any process on the machine may hold the clipboard for a moment, and a test
// that loses that race says nothing about the editor, so it waits its turn.
procedure TMarkdownVclEditorTests.NewEditor_ConstructsWithoutForm;
begin
  Assert.AreEqual('', FEditor.Text);
end;

procedure TMarkdownVclEditorTests.SetText_RoundTripsThroughTextProperty;
begin
  FEditor.Text := HeadingMarkdown;
  Assert.AreEqual(HeadingMarkdown, FEditor.Text);
end;

procedure TMarkdownVclEditorTests.CaretPosition_IsModelBacked;
begin
  FEditor.Text := HeadingMarkdown;
  FEditor.CaretPosition := 3;
  Assert.AreEqual(3, FEditor.CaretPosition);
end;

procedure TMarkdownVclEditorTests.SelectedText_ReflectsModelSelection;
begin
  FEditor.Text := HeadingMarkdown;
  Assert.AreEqual('', FEditor.SelectedText);
end;

procedure TMarkdownVclEditorTests.ExecuteBold_ModifiesText;
begin
  FEditor.Text := 'word';
  FEditor.ExecuteCommand(TEditorCommand.Bold);
  Assert.AreNotEqual('word', FEditor.Text);
end;

procedure TMarkdownVclEditorTests.UndoRedo_RestoreAndReapplyEdit;
begin
  FEditor.Text := 'abc';
  FEditor.ExecuteCommand(TEditorCommand.Bold);
  const AfterCommand = FEditor.Text;
  FEditor.Undo;
  Assert.AreEqual('abc', FEditor.Text);
  FEditor.Redo;
  Assert.AreEqual(AfterCommand, FEditor.Text);
end;

procedure TMarkdownVclEditorTests.AttachPreview_AfterEditAndFlush_PreviewContainsEdit;
begin
  const Viewer = TMarkdownViewer.Create(nil);
  try
    FEditor.Text := HeadingMarkdown;
    FEditor.AttachPreview(Viewer);
    FEditor.CaretPosition := Length(HeadingMarkdown);
    FEditor.ExecuteCommand(TEditorCommand.Bold);
    FEditor.FlushPreview;
    Assert.Contains(Viewer.Text, 'Heading');
  finally
    Viewer.Free;
  end;
end;

procedure TMarkdownVclEditorTests.TryAdoptPreviewSelection_PreviewShowsTheSameText_MovesTheSelectionOver;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  const Viewer = NewHostedPreview(Editor);

  Viewer.SelectAll;
  Assert.AreEqual(SelectableText, Viewer.SelectedText, 'The preview selection');

  Assert.IsTrue(Editor.TryAdoptPreviewSelection);
  Assert.AreEqual(SelectableText, Editor.SelectedText);
end;

// The preview only refreshes every so often. While it is behind, the offsets
// it hands out belong to the text it is still showing, so the editor must not
// move its selection onto them.
procedure TMarkdownVclEditorTests.TryAdoptPreviewSelection_PreviewShowsOlderText_LeavesTheSelectionAlone;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  const Viewer = NewHostedPreview(Editor);

  Viewer.SelectAll;
  Assert.AreEqual(SelectableText, Viewer.SelectedText, 'The preview selection');

  Editor.CaretPosition := 0;
  Editor.InsertText(AdoptedPrefix);

  Assert.IsFalse(Editor.TryAdoptPreviewSelection);
  Assert.AreEqual('', Editor.SelectedText);
end;

// A preview showing the editor's text, ready to be selected in.
function TMarkdownVclEditorTests.NewHostedPreview(const Editor: TMarkdownEditor): TMarkdownViewer;
begin
  Result := TMarkdownViewer.Create(FHostForm);
  Result.Parent := FHostForm;
  Result.SetBounds(0, 0, HostWidth, ShortHostHeight);
  Result.HandleNeeded;

  Editor.Text := SelectableText;
  Editor.AttachPreview(Result);
  Editor.FlushPreview;
end;

procedure TMarkdownVclEditorTests.TryAdoptPreviewSelection_WithoutAPreview_ReturnsFalse;
begin
  FEditor.Text := SelectableText;

  Assert.IsFalse(FEditor.TryAdoptPreviewSelection);
end;

procedure TMarkdownVclEditorTests.FormatKey_OnASelection_RunsTheCommandExactlyOnce(const KeyChar: Char;
  const Expected: string);
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := SelectableText;
  Editor.SelectRange(0, FormatKeySelectionLength);

  Editor.SimulateKeyDown(Ord(KeyChar), [ssCtrl]);

  Assert.AreEqual(Expected, Editor.Text);
end;

procedure TMarkdownVclEditorTests.OffscreenPaint_HeadingDiffersFromPlainPixels;
begin
  const Bitmap = TBitmap.Create;
  try
    Bitmap.SetSize(200, 60);
    FEditor.Text := HeadingMarkdown;
    FEditor.PaintTo(Bitmap);
    Assert.AreNotEqual<TColor>(clWhite, Bitmap.Canvas.Pixels[1, 1]);
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclEditorTests.Click_PlacesCaretAtClickedTextPosition;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(FarRight, 2, []);
    Assert.AreEqual(Editor.SourceLineStartOffset(1) - 1, Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.ClickFarBelow_PlacesCaretOnLastLine;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, FarDown, []);
    Assert.AreEqual(Editor.SourceLineStartOffset(1), Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.ClickDrag_SelectsDraggedRange;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseMove(FarRight, 2, []);
    Assert.AreEqual('Hello world', Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.ShiftClick_ExtendsSelectionToClick;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseDown(FarRight, 2, [ssShift]);
    Assert.AreEqual('Hello world', Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.DoubleClick_SelectsWordUnderCursor;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseDown(0, 2, []);
    Assert.AreEqual('Hello', Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.TripleClick_SelectsWholeLine;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseDown(0, 2, []);
    Assert.AreEqual('Hello world', Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.DragBelowLastLine_ClampsToDocumentEnd;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseMove(FarRight, FarDown, []);
    Assert.AreEqual(MouseText, Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.DragOutsideControlBounds_KeepsSelecting;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseMove(FarRight, Editor.Height + 500, []);
    Assert.AreEqual(MouseText, Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.KeyChar_InsertsPrintableCharacter;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := '';
    Editor.SimulateKeyChar('Z');
    Assert.AreEqual('Z', Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.KeyChar_IgnoresDeleteControlChar;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := WordPairText;
    Editor.CaretPosition := Length(WordPairText);
    Editor.SimulateKeyChar(DeleteKeyChar);
    Assert.AreEqual(WordPairText, Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.KeyBackspace_DeletesCharBeforeCaret;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'ab';
    Editor.CaretPosition := 2;
    Editor.SimulateKeyDown(vkBack, []);
    Assert.AreEqual('a', Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.KeyDelete_DeletesCharAfterCaret;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'ab';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkDelete, []);
    Assert.AreEqual('b', Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.KeyReturn_InsertsNewLine;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'ab';
    Editor.CaretPosition := 1;
    Editor.SimulateKeyDown(vkReturn, []);
    Assert.AreEqual('a'#10'b', Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.KeyRightThenLeft_MovesCaretByOne;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'abc';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkRight, []);
    Assert.AreEqual(1, Editor.CaretPosition);
    Editor.SimulateKeyDown(vkLeft, []);
    Assert.AreEqual(0, Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.KeyDownThenUp_MovesCaretBetweenLines;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'first'#10'second';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkDown, []);
    const CaretOnSecondLine = (Editor.CaretPosition >= Editor.SourceLineStartOffset(1));
    Assert.IsTrue(CaretOnSecondLine, Format('Expected caret on second line but got %d', [Editor.CaretPosition]));
    Editor.SimulateKeyDown(vkUp, []);
    const CaretOnFirstLine = (Editor.CaretPosition < Editor.SourceLineStartOffset(1));
    Assert.IsTrue(CaretOnFirstLine, Format('Expected caret back on first line but got %d', [Editor.CaretPosition]));
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.KeyHomeAndEnd_MoveToLineBounds;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'hello';
    Editor.CaretPosition := 2;
    Editor.SimulateKeyDown(vkEnd, []);
    Assert.AreEqual(5, Editor.CaretPosition);
    Editor.SimulateKeyDown(vkHome, []);
    Assert.AreEqual(0, Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.ShiftArrow_ExtendsSelection;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'hello';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkRight, [ssShift]);
    Editor.SimulateKeyDown(vkRight, [ssShift]);
    Assert.AreEqual('he', Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.CtrlWordArrows_MoveByWord;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := WordPairText;
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkRight, [ssCtrl]);
    const CaretPastFirstWord = (Editor.CaretPosition >= 3);
    Assert.IsTrue(CaretPastFirstWord, Format('Expected caret past first word but got %d', [Editor.CaretPosition]));
    const AfterRight = Editor.CaretPosition;
    Editor.SimulateKeyDown(vkLeft, [ssCtrl]);
    const CaretMovedLeft = (Editor.CaretPosition < AfterRight);
    Assert.IsTrue(CaretMovedLeft, Format('Expected caret to move left of %d but got %d', [AfterRight, Editor.CaretPosition]));
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.EditWithUnlinkedPreview_KeepsPreviewScrollOffset;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  const Viewer = TMarkdownViewer.Create(FHostForm);
  Viewer.Parent := FHostForm;
  Viewer.SetBounds(0, 0, HostWidth, ShortHostHeight);

  Editor.SyncScroll := False;
  Editor.Text := ManyLines(ManyLineCount);
  Editor.AttachPreview(Viewer);
  Editor.FlushPreview;

  Viewer.ScrollOffset := PreviewScrollTarget;
  const Before = Viewer.ScrollOffset;
  const PreviewIsScrollable = (Before > 0);
  Assert.IsTrue(PreviewIsScrollable, 'Preview should be scrollable for this test');

  Editor.CaretPosition := 0;
  Editor.SimulateKeyChar('X');
  Editor.FlushPreview;

  Assert.AreEqual(Double(Before), Double(Viewer.ScrollOffset), 0.5);
end;

procedure TMarkdownVclEditorTests.EditWithLinkedPreview_LeavesPreviewOnEditorOffset;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  const Viewer = TMarkdownViewer.Create(FHostForm);
  Viewer.Parent := FHostForm;
  Viewer.SetBounds(0, 0, HostWidth, ShortHostHeight);

  Editor.Text := ManyLines(ManyLineCount);
  Editor.AttachPreview(Viewer);
  Editor.ScrollToSourceLine(ManyLineCount div 2);
  Editor.FlushPreview;

  // Linked panes track each other, so an edit must leave the preview on the
  // offset the editor's position dictates instead of resetting it.
  const Expected = Viewer.ScrollOffset;

  Editor.CaretPosition := 0;
  Editor.SimulateKeyChar('X');
  Editor.FlushPreview;

  Assert.AreEqual(Double(Expected), Double(Viewer.ScrollOffset), 0.5);
end;

// A host typically links the panes while its form is still being built: the
// preview has no width yet, so the first scroll mapping is built against an
// empty layout. Both directions have to come alive once the preview gets its
// real size.
procedure TMarkdownVclEditorTests.EditorScroll_PreviewSizedAfterAttach_MovesPreview;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  const Viewer = TMarkdownViewer.Create(FHostForm);

  Editor.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(ManyLineCount);
  Editor.AttachPreview(Viewer);

  Viewer.Parent := FHostForm;
  Viewer.SetBounds(0, 0, HostWidth, ShortHostHeight);
  Viewer.HandleNeeded;

  Editor.SimulateVScroll(SB_BOTTOM);

  const PreviewFollowedToBottom = (Viewer.ScrollOffset > 0);
  Assert.IsTrue(PreviewFollowedToBottom, 'Expected the preview to follow the editor to the bottom');
end;

procedure TMarkdownVclEditorTests.PreviewScroll_PreviewSizedAfterAttach_MovesEditor;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  const Viewer = TMarkdownViewer.Create(FHostForm);

  Editor.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(ManyLineCount);
  Editor.AttachPreview(Viewer);

  Viewer.Parent := FHostForm;
  Viewer.SetBounds(0, 0, HostWidth, ShortHostHeight);
  Viewer.HandleNeeded;

  Viewer.ScrollOffset := Viewer.ContentHeight;

  const EditorFollowedDownward = (Editor.FirstVisibleSourceLine > 0);
  Assert.IsTrue(EditorFollowedDownward, 'Expected the editor to follow the preview downward');
end;

procedure TMarkdownVclEditorTests.MergeText_KeepsCaretAndUndoHistory;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'first line'#10'second line';
    Editor.CaretPosition := 3;

    Assert.IsTrue(Editor.MergeText('first line'#10'second line'#10'third line'));
    Assert.AreEqual(3, Editor.CaretPosition);
    Assert.IsTrue(Editor.CanUndo);
    Assert.IsFalse(Editor.MergeText('first line'#10'second line'#10'third line'));
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.CtrlBackspace_DeletesWordBeforeCaret;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := WordPairText;
    Editor.CaretPosition := Length(WordPairText);
    Editor.SimulateKeyDown(vkBack, [ssCtrl]);
    Assert.AreEqual('foo ', Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.CtrlDelete_DeletesWordAfterCaret;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := WordPairText;
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkDelete, [ssCtrl]);
    Assert.AreEqual('bar', Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.CtrlHomeAndEnd_MoveToDocumentBounds;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'line one'#10'line two';
    Editor.CaretPosition := 3;
    Editor.SimulateKeyDown(vkEnd, [ssCtrl]);
    Assert.AreEqual(Length(Editor.Text), Editor.CaretPosition);
    Editor.SimulateKeyDown(vkHome, [ssCtrl]);
    Assert.AreEqual(0, Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.CtrlA_SelectsAllText;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'select me';
    Editor.SimulateKeyDown(Ord('A'), [ssCtrl]);
    Assert.AreEqual('select me', Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.CtrlZ_UndoesAndCtrlY_Redoes;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'abc';
    Editor.SimulateKeyDown(Ord('B'), [ssCtrl]);
    const AfterBold = Editor.Text;
    Assert.AreNotEqual('abc', AfterBold);
    Editor.SimulateKeyDown(Ord('Z'), [ssCtrl]);
    Assert.AreEqual('abc', Editor.Text);
    Editor.SimulateKeyDown(Ord('Y'), [ssCtrl]);
    Assert.AreEqual(AfterBold, Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.CtrlB_TogglesBoldFormatting;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'word';
    Editor.SimulateKeyDown(Ord('A'), [ssCtrl]);
    Editor.SimulateKeyDown(Ord('B'), [ssCtrl]);
    Assert.Contains(Editor.Text, '**');
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.CtrlI_TogglesItalicFormatting;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'word';
    Editor.SimulateKeyDown(Ord('A'), [ssCtrl]);
    Editor.SimulateKeyDown(Ord('I'), [ssCtrl]);
    Assert.AreNotEqual('word', Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.CtrlK_InsertsLinkSyntax;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'word';
    Editor.SimulateKeyDown(Ord('A'), [ssCtrl]);
    Editor.SimulateKeyDown(Ord('K'), [ssCtrl]);
    Assert.Contains(Editor.Text, '](');
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.CtrlC_CopiesSelectionToClipboard;
begin
  if not TVclTestClipboard.IsAccessible then
    Assert.Pass('Clipboard service unavailable in this test session');

  var Saved: string;
  TVclTestClipboard.TryGetText(Saved);

  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'copy target';
    Editor.SimulateKeyDown(Ord('A'), [ssCtrl]);
    Editor.SimulateKeyDown(Ord('C'), [ssCtrl]);

    var Copied: string;
    if not TVclTestClipboard.TryGetText(Copied) then
      Assert.Pass('Clipboard held by another process throughout this test');

    Assert.AreEqual('copy target', Copied);
  finally
    Editor.Free;
    TVclTestClipboard.TrySetText(Saved);
  end;
end;

procedure TMarkdownVclEditorTests.CtrlX_CutsSelectionToClipboard;
begin
  if not TVclTestClipboard.IsAccessible then
    Assert.Pass('Clipboard service unavailable in this test session');

  var Saved: string;
  TVclTestClipboard.TryGetText(Saved);

  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'cut target';
    Editor.SimulateKeyDown(Ord('A'), [ssCtrl]);
    Editor.SimulateKeyDown(Ord('X'), [ssCtrl]);

    var Cut: string;
    if not TVclTestClipboard.TryGetText(Cut) then
      Assert.Pass('Clipboard held by another process throughout this test');

    Assert.AreEqual('cut target', Cut);
    Assert.AreEqual('', Editor.Text);
  finally
    Editor.Free;
    TVclTestClipboard.TrySetText(Saved);
  end;
end;

procedure TMarkdownVclEditorTests.CtrlV_PastesClipboardText;
begin
  if not TVclTestClipboard.IsAccessible then
    Assert.Pass('Clipboard service unavailable in this test session');

  var Saved: string;
  TVclTestClipboard.TryGetText(Saved);

  const Editor = TTestableVclEditor.Create(nil);
  try
    if not TVclTestClipboard.TrySetText('pasted') then
      Assert.Pass('Clipboard held by another process throughout this test');

    Editor.Text := '';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(Ord('V'), [ssCtrl]);
    Assert.AreEqual('pasted', Editor.Text);
  finally
    Editor.Free;
    TVclTestClipboard.TrySetText(Saved);
  end;
end;

procedure TMarkdownVclEditorTests.MouseWheelDown_ScrollsContentDown;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := ManyLines(ManyLineCount);
  const Before = Editor.FirstVisibleSourceLine;
  Editor.SimulateWheel(-WHEEL_DELTA);
  const ViewportAdvanced = (Editor.FirstVisibleSourceLine > Before);
  Assert.IsTrue(ViewportAdvanced, Format('Expected viewport to advance from line %d', [Before]));
end;

procedure TMarkdownVclEditorTests.ClickAfterScroll_MapsToVisibleLine;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := ManyLines(ManyLineCount);

  for var Notch := 1 to 5 do
  begin
    Editor.SimulateWheel(-WHEEL_DELTA);
  end;

  const VisibleLine = Editor.FirstVisibleSourceLine;
  const ContentScrolledDown = (VisibleLine > 0);
  Assert.IsTrue(ContentScrolledDown, 'Expected content to have scrolled down');

  Editor.SimulateMouseDown(0, 2, []);
  Assert.AreEqual(Editor.SourceLineStartOffset(VisibleLine), Editor.CaretPosition);
end;

procedure TMarkdownVclEditorTests.GutterClick_PlacesCaretAtLineStart;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.ShowLineNumbers := True;
  Editor.Text := MouseText;

  Editor.SimulateMouseDown(0, 2, []);
  Assert.AreEqual(Editor.SourceLineStartOffset(0), Editor.CaretPosition);
end;

procedure TMarkdownVclEditorTests.VScrollLineAndPage_AdvanceViewport;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := ManyLines(ManyLineCount);

  Editor.SimulateVScroll(SB_LINEDOWN);
  const AfterLine = Editor.FirstVisibleSourceLine;
  const LineScrollAdvanced = (AfterLine >= 1);
  Assert.IsTrue(LineScrollAdvanced, Format('Expected line scroll to advance but got %d', [AfterLine]));

  Editor.SimulateVScroll(SB_PAGEDOWN);
  const AfterPage = Editor.FirstVisibleSourceLine;
  const PageScrollAdvanced = (AfterPage > AfterLine);
  Assert.IsTrue(PageScrollAdvanced, Format('Expected page scroll to advance beyond %d', [AfterLine]));

  Editor.SimulateVScroll(SB_LINEUP);
  const LineUpRetreated = (Editor.FirstVisibleSourceLine < AfterPage);
  Assert.IsTrue(LineUpRetreated, Format('Expected line up to retreat below %d', [AfterPage]));
end;

procedure TMarkdownVclEditorTests.VScrollTopBottomAndThumb_ClampWithoutError;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := ManyLines(ManyLineCount);

  Editor.SimulateVScroll(SB_BOTTOM);
  const AtBottom = Editor.FirstVisibleSourceLine;
  const BottomScrollAdvanced = (AtBottom > 0);
  Assert.IsTrue(BottomScrollAdvanced, 'Expected bottom scroll to advance the viewport');

  Editor.SimulateVScroll(SB_THUMBTRACK);

  Editor.SimulateVScroll(SB_TOP);
  Assert.AreEqual(0, Editor.FirstVisibleSourceLine);
end;

procedure TMarkdownVclEditorTests.PageDownAndPageUp_MoveCaretByPage;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := ManyLines(ManyLineCount);
  Editor.CaretPosition := 0;

  Editor.SimulateKeyDown(vkNext, []);
  const AfterPageDown = Editor.CaretPosition;
  const CaretMovedDownAPage = (AfterPageDown >= Editor.SourceLineStartOffset(1));
  Assert.IsTrue(CaretMovedDownAPage,
    Format('Expected page down to move the caret down a page but caret is at %d', [AfterPageDown]));

  Editor.SimulateKeyDown(vkPrior, []);
  const CaretMovedBackUp = (Editor.CaretPosition < AfterPageDown);
  Assert.IsTrue(CaretMovedBackUp, Format('Expected page up to move the caret back above %d', [AfterPageDown]));
end;

procedure TMarkdownVclEditorTests.AutoScrollTimer_DuringDragOutside_AdvancesAndExtends;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := ManyLines(ManyLineCount);

  Editor.SimulateMouseDown(0, 2, []);
  Editor.SimulateMouseMove(5, Editor.ClientHeight + 50, []);
  Editor.PumpAutoScrollTimer;

  const AutoscrollAdvanced = (Editor.FirstVisibleSourceLine >= 1);
  Assert.IsTrue(AutoscrollAdvanced,
    Format('Expected autoscroll to advance the viewport but got %d', [Editor.FirstVisibleSourceLine]));
  const SelectionExtended = (Length(Editor.SelectedText) > 0);
  Assert.IsTrue(SelectionExtended, 'Expected drag-outside to extend the selection');
end;

procedure TMarkdownVclEditorTests.HighDpiClick_MapsCaretToClickedLine;
begin
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.ForcePixelsPerInch(HighDpi);
    Assert.AreEqual(HighDpi, Editor.CurrentPixelsPerInch);

    Editor.Text := MouseText;
    Editor.SimulateMouseDown(FarRight, 2, []);
    Assert.AreEqual(Editor.SourceLineStartOffset(1) - 1, Editor.CaretPosition);

    Editor.SimulateMouseDown(0, FarDown, []);
    Assert.AreEqual(Editor.SourceLineStartOffset(1), Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownVclEditorTests.FocusMessages_ShowAndHideCaretWithoutError;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := 'focus body';

  Editor.SimulateSetFocus;
  Editor.SimulateKeyChar('!');
  Assert.Contains(Editor.Text, '!');

  Editor.SimulateKillFocus;
  Assert.Contains(Editor.Text, 'focus body');
end;

class function TMarkdownVclEditorTests.OneWrappedLine: string;
begin
  var Builder := '';
  for var Index := 0 to 199 do
  begin
    Builder := Builder + 'word ';
  end;

  Result := Builder;
end;

procedure TMarkdownVclEditorTests.WordWrap_VerticalArrowsTraverseVisualRows;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := OneWrappedLine;
  Editor.CaretPosition := 0;

  Editor.SimulateKeyDown(vkDown, []);
  const AfterDown = Editor.CaretPosition;
  const CaretMovedToSecondRow = (AfterDown > 0);
  Assert.IsTrue(CaretMovedToSecondRow,
    Format('Expected wrapping to place a second visual row but the caret stayed at %d', [AfterDown]));
  const CaretWithinWrappedLine = (AfterDown < Length(Editor.Text));
  Assert.IsTrue(CaretWithinWrappedLine, 'Expected the caret to stay within the single wrapped line');

  Editor.SimulateKeyDown(vkUp, []);
  Assert.AreEqual(0, Editor.CaretPosition);
end;

procedure TMarkdownVclEditorTests.WordWrap_Home_GoesToVisualRowStart;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := OneWrappedLine;
  Editor.CaretPosition := 0;

  Editor.SimulateKeyDown(vkDown, []);
  const SecondRowStart = Editor.CaretPosition;
  const HasWrappedSecondRow = (SecondRowStart > 0);
  Assert.IsTrue(HasWrappedSecondRow, 'Expected a wrapped second visual row');

  Editor.CaretPosition := SecondRowStart + 2;
  Editor.SimulateKeyDown(vkHome, []);
  Assert.AreEqual(SecondRowStart, Editor.CaretPosition);
end;

procedure TMarkdownVclEditorTests.ScaleForPPI_OnHostForm_ScalesText;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := ManyLines(ManyLineCount);
  const HeightBefore = ContentHeightOf(Editor);
  const ScaledPixelsPerInch = MulDiv(FHostForm.PixelsPerInch, GrowthNumerator, GrowthDenominator);

  FHostForm.ScaleForPPI(ScaledPixelsPerInch);

  const HeightAfter = ContentHeightOf(Editor);
  const ExpectedHeight = HeightBefore * GrowthNumerator / GrowthDenominator;
  Assert.AreEqual(ExpectedHeight, Double(HeightAfter), HeightBefore * ScaleTolerance,
    'The text must grow with the form it is on, as the controls around it do');
end;

class function TMarkdownVclEditorTests.ContentHeightOf(const Editor: TMarkdownEditor): Integer;
begin
  var Info := Default(TScrollInfo);
  Info.cbSize := SizeOf(Info);
  Info.fMask := SIF_RANGE;
  GetScrollInfo(Editor.Handle, SB_VERT, Info);

  Result := Info.nMax + 1;
end;

procedure TMarkdownVclEditorTests.MiddlePress_OverflowingContent_IsAutoScrolling;
begin
  const Editor = NewEditorOnPreviewingForm;

  Editor.SimulateMiddlePress;

  Assert.IsTrue(Editor.IsAutoScrolling);
end;

procedure TMarkdownVclEditorTests.CtrlWheel_Up_ZoomsInOneLevel;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := 'alpha';

  const Handled = Editor.SimulateWheel(WHEEL_DELTA, [ssCtrl]);

  Assert.IsTrue(Handled);
  Assert.AreEqual(110, Editor.Zoom);
end;

procedure TMarkdownVclEditorTests.Keyboard_CtrlPlus_ZoomsInOneLevel(const Key: Word);
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := 'alpha';

  Editor.SimulateKeyDown(Key, [ssCtrl]);

  Assert.AreEqual(110, Editor.Zoom);
  Assert.AreEqual('alpha', Editor.Text);
end;

procedure TMarkdownVclEditorTests.Keyboard_CtrlZero_ResetsZoom;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := 'alpha';
  Editor.Zoom := 200;

  Editor.SimulateKeyDown(Ord('0'), [ssCtrl]);

  Assert.AreEqual(100, Editor.Zoom);
end;

// Font heights round to whole pixels, so twice the zoom is compared with twice
// the font rather than with twice the height.
procedure TMarkdownVclEditorTests.Zoom_Double_LaysOutAsDoubleCodeFont;
const
  LineCount = 40;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := ManyLines(LineCount);
  Editor.Zoom := 200;
  const ZoomedHeight = ContentHeightOf(Editor);

  const LargeTheme = TMarkdownTheme.CreateLight;
  try
    var LargeFont := LargeTheme.CodeFont;
    LargeFont.Size := 2 * LargeFont.Size;
    LargeTheme.CodeFont := LargeFont;
    Editor.Zoom := 100;
    Editor.Theme := LargeTheme;
    const LargeFontHeight = ContentHeightOf(Editor);
    Editor.ThemePreset := TMarkdownThemePreset.Light;

    Assert.AreEqual(LargeFontHeight, ZoomedHeight);
  finally
    LargeTheme.Free;
  end;
end;

procedure TMarkdownVclEditorTests.Zoom_Changed_RaisesOnZoomChange;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := 'alpha';
  Editor.OnZoomChange := RecordZoomChange;

  Editor.Zoom := 150;
  Editor.Zoom := 150;

  Assert.AreEqual(1, FZoomChangeCount);
end;

procedure TMarkdownVclEditorTests.RecordZoomChange(Sender: TObject);
begin
  Inc(FZoomChangeCount);
end;

procedure TMarkdownVclEditorTests.AutoScrollChange_StartAndStop_RaisedForBoth;
begin
  const Editor = NewEditorOnPreviewingForm;
  Editor.OnAutoScrollChange := RecordAutoScrollChange;

  Editor.SimulateMiddlePress;
  Editor.SimulateKeyFromMessageLoop(VK_DOWN);

  Assert.AreEqual(2, FAutoScrollChangeCount);
  Assert.IsFalse(Editor.IsAutoScrolling);
end;

procedure TMarkdownVclEditorTests.ShortcutKey_DuringAutoScroll_EndsItBeforeTheForm;
begin
  const Editor = NewEditorOnPreviewingForm;
  Editor.SimulateMiddlePress;

  Editor.SimulateKeyFromMessageLoop(VK_F3);

  Assert.IsFalse(Editor.IsAutoScrolling, 'The key must end autoscroll');
  Assert.AreEqual(0, FFormKeyCount, 'The key that ends autoscroll must not reach the form');
end;

procedure TMarkdownVclEditorTests.ShortcutKey_WithoutAutoScroll_ReachesTheForm;
begin
  const Editor = NewEditorOnPreviewingForm;

  Editor.SimulateKeyFromMessageLoop(VK_F3);

  Assert.AreEqual(1, FFormKeyCount);
end;

function TMarkdownVclEditorTests.NewEditorOnPreviewingForm: TTestableVclEditor;
begin
  Result := NewHostedEditor(ShortHostHeight);
  Result.Text := ManyLines(ManyLineCount);

  FHostForm.KeyPreview := True;
  FHostForm.OnKeyDown := RecordFormKey;
end;

procedure TMarkdownVclEditorTests.RecordFormKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  Inc(FFormKeyCount);
  Key := 0;
end;

procedure TMarkdownVclEditorTests.RecordAutoScrollChange(Sender: TObject);
begin
  Inc(FAutoScrollChangeCount);
end;

procedure TMarkdownVclEditorTests.Click_InText_RaisesOnClickOnce;
begin
  const Editor = NewClickRecordingEditor;

  Editor.SendMouse(WM_LBUTTONDOWN, ClickX, ClickY);
  Editor.SendMouse(WM_LBUTTONUP, ClickX, ClickY);

  Assert.AreEqual(1, FClickCount);
  Assert.AreEqual(0, FDoubleClickCount);
end;

procedure TMarkdownVclEditorTests.Drag_PastThreshold_RaisesNoClick;
begin
  const Editor = NewClickRecordingEditor;

  Editor.SendMouse(WM_LBUTTONDOWN, ClickX, ClickY);
  Editor.SendMouse(WM_MOUSEMOVE, ClickX + DragDistance, ClickY);
  Editor.SendMouse(WM_LBUTTONUP, ClickX + DragDistance, ClickY);

  Assert.AreEqual(0, FClickCount, 'A drag selects text and is no click');
end;

procedure TMarkdownVclEditorTests.DoubleClick_InText_RaisesOnDblClickOnReleaseAndKeepsWord;
begin
  const Editor = NewClickRecordingEditor;
  Editor.SendMouse(WM_LBUTTONDOWN, ClickX, ClickY);
  Editor.SendMouse(WM_LBUTTONUP, ClickX, ClickY);

  Editor.SendMouse(WM_LBUTTONDBLCLK, ClickX, ClickY);
  const DoubleClicksWhilePressed = FDoubleClickCount;
  Editor.SendMouse(WM_LBUTTONUP, ClickX, ClickY);

  Assert.AreEqual(0, DoubleClicksWhilePressed, 'The double click comes on release');
  Assert.AreEqual(1, FDoubleClickCount);
  Assert.AreEqual(1, FClickCount, 'The second press of a double click is no extra click');
  Assert.AreEqual(ClickText, Editor.SelectedText);
end;

procedure TMarkdownVclEditorTests.Click_EndingAutoScroll_RaisesNoClick;
begin
  const Editor = NewEditorOnPreviewingForm;
  Editor.OnClick := RecordClick;
  Editor.SimulateMiddlePress;

  Editor.SendMouse(WM_LBUTTONDOWN, ClickX, ClickY);
  Editor.SendMouse(WM_LBUTTONUP, ClickX, ClickY);

  Assert.IsFalse(Editor.IsAutoScrolling);
  Assert.AreEqual(0, FClickCount, 'The click that ends autoscroll is no click in the text');
end;

function TMarkdownVclEditorTests.NewClickRecordingEditor: TTestableVclEditor;
begin
  Result := NewHostedEditor(ShortHostHeight);
  Result.Text := ClickText;
  Result.OnClick := RecordClick;
  Result.OnDblClick := RecordDoubleClick;
end;

procedure TMarkdownVclEditorTests.RecordClick(Sender: TObject);
begin
  Inc(FClickCount);
end;

procedure TMarkdownVclEditorTests.RecordDoubleClick(Sender: TObject);
begin
  Inc(FDoubleClickCount);
end;

end.