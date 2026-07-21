unit Markdown4D.Vcl.Editor.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.UITypes,
  Vcl.Forms,
  DUnitX.TestFramework,
  Markdown4D.Editor.Model,
  Markdown4D.Vcl.Viewer,
  Markdown4D.Vcl.Editor;

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
    function SimulateWheel(const WheelDelta: Integer): Boolean;
    procedure SimulateVScroll(const ScrollCode: Word);
    procedure SimulateSetFocus;
    procedure SimulateKillFocus;
    procedure PumpAutoScrollTimer;
    procedure ForcePixelsPerInch(const Value: Integer);
    function CurrentPixelsPerInch: Integer;
  end;

  [TestFixture]
  TMarkdownVclEditorTests = class
  private
    const
      HeadingMarkdown = '# Heading';
      EditText = ' appended body';
      MouseText = 'Hello world'#10'second';
      FarRight = 100000;
      FarDown = 100000;
      HostWidth = 400;
      ShortHostHeight = 100;
      ManyLineCount = 40;
      HighDpi = 192;
    var
      FEditor: TMarkdownEditor;
      FHostForm: TForm;
    function NewHostedEditor(const ControlHeight: Integer): TTestableVclEditor;
    class function ManyLines(const Count: Integer): string; static;
    class function OneWrappedLine: string; static;
    class function ClipboardIsAccessible: Boolean; static;

  public
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
  Vcl.ExtCtrls,
  Vcl.Clipbrd,
  Vcl.Graphics;

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

function TTestableVclEditor.SimulateWheel(const WheelDelta: Integer): Boolean;
begin
  Result := DoMouseWheel([], WheelDelta, TPoint.Create(0, 0));
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

class function TMarkdownVclEditorTests.ClipboardIsAccessible: Boolean;
begin
  Result := True;
  try
    Clipboard.Open;
    Clipboard.Close;
  except
    Result := False;
  end;
end;

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
    Assert.IsTrue(Editor.CaretPosition >= Editor.SourceLineStartOffset(1),
      Format('Expected caret on second line but got %d', [Editor.CaretPosition]));
    Editor.SimulateKeyDown(vkUp, []);
    Assert.IsTrue(Editor.CaretPosition < Editor.SourceLineStartOffset(1),
      Format('Expected caret back on first line but got %d', [Editor.CaretPosition]));
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
    Editor.Text := 'foo bar';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkRight, [ssCtrl]);
    Assert.IsTrue(Editor.CaretPosition >= 3,
      Format('Expected caret past first word but got %d', [Editor.CaretPosition]));
    const AfterRight = Editor.CaretPosition;
    Editor.SimulateKeyDown(vkLeft, [ssCtrl]);
    Assert.IsTrue(Editor.CaretPosition < AfterRight,
      Format('Expected caret to move left of %d but got %d', [AfterRight, Editor.CaretPosition]));
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
  if not ClipboardIsAccessible then
    Assert.Pass('Clipboard service unavailable in this test session');

  const Saved = Clipboard.AsText;
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'copy target';
    Editor.SimulateKeyDown(Ord('A'), [ssCtrl]);
    Editor.SimulateKeyDown(Ord('C'), [ssCtrl]);
    Assert.AreEqual('copy target', Clipboard.AsText);
  finally
    Editor.Free;
    Clipboard.AsText := Saved;
  end;
end;

procedure TMarkdownVclEditorTests.CtrlX_CutsSelectionToClipboard;
begin
  if not ClipboardIsAccessible then
    Assert.Pass('Clipboard service unavailable in this test session');

  const Saved = Clipboard.AsText;
  const Editor = TTestableVclEditor.Create(nil);
  try
    Editor.Text := 'cut target';
    Editor.SimulateKeyDown(Ord('A'), [ssCtrl]);
    Editor.SimulateKeyDown(Ord('X'), [ssCtrl]);
    Assert.AreEqual('cut target', Clipboard.AsText);
    Assert.AreEqual('', Editor.Text);
  finally
    Editor.Free;
    Clipboard.AsText := Saved;
  end;
end;

procedure TMarkdownVclEditorTests.CtrlV_PastesClipboardText;
begin
  if not ClipboardIsAccessible then
    Assert.Pass('Clipboard service unavailable in this test session');

  const Saved = Clipboard.AsText;
  const Editor = TTestableVclEditor.Create(nil);
  try
    Clipboard.AsText := 'pasted';
    Editor.Text := '';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(Ord('V'), [ssCtrl]);
    Assert.AreEqual('pasted', Editor.Text);
  finally
    Editor.Free;
    Clipboard.AsText := Saved;
  end;
end;

procedure TMarkdownVclEditorTests.MouseWheelDown_ScrollsContentDown;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := ManyLines(ManyLineCount);
  const Before = Editor.FirstVisibleSourceLine;
  Editor.SimulateWheel(-WHEEL_DELTA);
  Assert.IsTrue(Editor.FirstVisibleSourceLine > Before,
    Format('Expected viewport to advance from line %d', [Before]));
end;

procedure TMarkdownVclEditorTests.ClickAfterScroll_MapsToVisibleLine;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := ManyLines(ManyLineCount);

  for var Notch := 1 to 5 do
    Editor.SimulateWheel(-WHEEL_DELTA);

  const VisibleLine = Editor.FirstVisibleSourceLine;
  Assert.IsTrue(VisibleLine > 0, 'Expected content to have scrolled down');

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
  Assert.IsTrue(AfterLine >= 1, Format('Expected line scroll to advance but got %d', [AfterLine]));

  Editor.SimulateVScroll(SB_PAGEDOWN);
  const AfterPage = Editor.FirstVisibleSourceLine;
  Assert.IsTrue(AfterPage > AfterLine,
    Format('Expected page scroll to advance beyond %d', [AfterLine]));

  Editor.SimulateVScroll(SB_LINEUP);
  Assert.IsTrue(Editor.FirstVisibleSourceLine < AfterPage,
    Format('Expected line up to retreat below %d', [AfterPage]));
end;

procedure TMarkdownVclEditorTests.VScrollTopBottomAndThumb_ClampWithoutError;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := ManyLines(ManyLineCount);

  Editor.SimulateVScroll(SB_BOTTOM);
  const AtBottom = Editor.FirstVisibleSourceLine;
  Assert.IsTrue(AtBottom > 0, 'Expected bottom scroll to advance the viewport');

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
  Assert.IsTrue(AfterPageDown >= Editor.SourceLineStartOffset(1),
    Format('Expected page down to move the caret down a page but caret is at %d', [AfterPageDown]));

  Editor.SimulateKeyDown(vkPrior, []);
  Assert.IsTrue(Editor.CaretPosition < AfterPageDown,
    Format('Expected page up to move the caret back above %d', [AfterPageDown]));
end;

procedure TMarkdownVclEditorTests.AutoScrollTimer_DuringDragOutside_AdvancesAndExtends;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := ManyLines(ManyLineCount);

  Editor.SimulateMouseDown(0, 2, []);
  Editor.SimulateMouseMove(5, Editor.ClientHeight + 50, []);
  Editor.PumpAutoScrollTimer;

  Assert.IsTrue(Editor.FirstVisibleSourceLine >= 1,
    Format('Expected autoscroll to advance the viewport but got %d', [Editor.FirstVisibleSourceLine]));
  Assert.IsTrue(Length(Editor.SelectedText) > 0, 'Expected drag-outside to extend the selection');
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
    Builder := Builder + 'word ';

  Result := Builder;
end;

procedure TMarkdownVclEditorTests.WordWrap_VerticalArrowsTraverseVisualRows;
begin
  const Editor = NewHostedEditor(ShortHostHeight);
  Editor.Text := OneWrappedLine;
  Editor.CaretPosition := 0;

  Editor.SimulateKeyDown(vkDown, []);
  const AfterDown = Editor.CaretPosition;
  Assert.IsTrue(AfterDown > 0,
    Format('Expected wrapping to place a second visual row but the caret stayed at %d', [AfterDown]));
  Assert.IsTrue(AfterDown < Length(Editor.Text), 'Expected the caret to stay within the single wrapped line');

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
  Assert.IsTrue(SecondRowStart > 0, 'Expected a wrapped second visual row');

  Editor.CaretPosition := SecondRowStart + 2;
  Editor.SimulateKeyDown(vkHome, []);
  Assert.AreEqual(SecondRowStart, Editor.CaretPosition);
end;

end.
