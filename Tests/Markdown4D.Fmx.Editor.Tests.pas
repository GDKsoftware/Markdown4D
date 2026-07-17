unit Markdown4D.Fmx.Editor.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.UITypes,
  DUnitX.TestFramework,
  Markdown4D.Editor.Model,
  Markdown4D.Fmx.Viewer,
  Markdown4D.Fmx.Editor;

type
  TTestableFmxEditor = class(TMarkdownEditor)
  private
    const
      AutoScrollTimerIntervalMs = 50;
  public
    procedure SimulateMouseDown(const X, Y: Single; const Shift: TShiftState);
    procedure SimulateMouseMove(const X, Y: Single; const Shift: TShiftState);
    procedure SimulateMouseUp(const X, Y: Single; const Shift: TShiftState);
    procedure SimulateKeyDown(const Key: Word; const KeyChar: WideChar; const Shift: TShiftState);
    function SimulateWheel(const WheelDelta: Integer): Boolean;
    procedure SimulateEnter;
    procedure SimulateExit;
    procedure PumpAutoScrollTimer;
  end;

  [TestFixture]
  TMarkdownFmxEditorTests = class
  private
    const
      HeadingMarkdown = '# Heading';
      MouseText = 'Hello world'#10'second';
      FarRight = 100000;
      FarDown = 100000;
      ShortHeight = 100;
      ManyLineCount = 40;
    var
      FEditor: TMarkdownEditor;
    class function ManyLines(const Count: Integer): string; static;
    class function ClipboardIsAvailable: Boolean; static;

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
    procedure OffscreenPaint_RendersHighlightedSource;

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
    procedure PageDownAndPageUp_MoveCaretByPage;

    [Test]
    procedure AutoScrollTimer_DuringDragOutside_ExtendsSelection;

    [Test]
    procedure FocusEnterExit_TogglesCaretWithoutError;
  end;

implementation

uses
  System.SysUtils,
  System.Rtti,
  FMX.Types,
  FMX.Platform,
  FMX.Graphics;

procedure TTestableFmxEditor.SimulateMouseDown(const X, Y: Single; const Shift: TShiftState);
begin
  MouseDown(TMouseButton.mbLeft, Shift, X, Y);
end;

procedure TTestableFmxEditor.SimulateMouseMove(const X, Y: Single; const Shift: TShiftState);
begin
  MouseMove(Shift, X, Y);
end;

procedure TTestableFmxEditor.SimulateMouseUp(const X, Y: Single; const Shift: TShiftState);
begin
  MouseUp(TMouseButton.mbLeft, Shift, X, Y);
end;

procedure TTestableFmxEditor.SimulateKeyDown(const Key: Word; const KeyChar: WideChar; const Shift: TShiftState);
begin
  var KeyValue := Key;
  var CharValue := KeyChar;
  KeyDown(KeyValue, CharValue, Shift);
end;

function TTestableFmxEditor.SimulateWheel(const WheelDelta: Integer): Boolean;
begin
  var Handled := False;
  MouseWheel([], WheelDelta, Handled);
  Result := Handled;
end;

procedure TTestableFmxEditor.SimulateEnter;
begin
  DoEnter;
end;

procedure TTestableFmxEditor.SimulateExit;
begin
  DoExit;
end;

procedure TTestableFmxEditor.PumpAutoScrollTimer;
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

procedure TMarkdownFmxEditorTests.Setup;
begin
  FEditor := TMarkdownEditor.Create(nil);
end;

procedure TMarkdownFmxEditorTests.TearDown;
begin
  FEditor.Free;
end;

class function TMarkdownFmxEditorTests.ManyLines(const Count: Integer): string;
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

class function TMarkdownFmxEditorTests.ClipboardIsAvailable: Boolean;
begin
  Result := False;

  var Service: IFMXClipboardService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Service) then
    Exit;

  try
    const Prior = Service.GetClipboard;
    Service.SetClipboard(Prior);
    Result := True;
  except
    Result := False;
  end;
end;

procedure TMarkdownFmxEditorTests.NewEditor_ConstructsWithoutForm;
begin
  Assert.AreEqual('', FEditor.Text);
end;

procedure TMarkdownFmxEditorTests.SetText_RoundTripsThroughTextProperty;
begin
  FEditor.Text := HeadingMarkdown;
  Assert.AreEqual(HeadingMarkdown, FEditor.Text);
end;

procedure TMarkdownFmxEditorTests.CaretPosition_IsModelBacked;
begin
  FEditor.Text := HeadingMarkdown;
  FEditor.CaretPosition := 3;
  Assert.AreEqual(3, FEditor.CaretPosition);
end;

procedure TMarkdownFmxEditorTests.SelectedText_ReflectsModelSelection;
begin
  FEditor.Text := HeadingMarkdown;
  Assert.AreEqual('', FEditor.SelectedText);
end;

procedure TMarkdownFmxEditorTests.ExecuteBold_ModifiesText;
begin
  FEditor.Text := 'word';
  FEditor.ExecuteCommand(TEditorCommand.Bold);
  Assert.AreNotEqual('word', FEditor.Text);
end;

procedure TMarkdownFmxEditorTests.UndoRedo_RestoreAndReapplyEdit;
begin
  FEditor.Text := 'abc';
  FEditor.ExecuteCommand(TEditorCommand.Bold);
  const AfterCommand = FEditor.Text;
  FEditor.Undo;
  Assert.AreEqual('abc', FEditor.Text);
  FEditor.Redo;
  Assert.AreEqual(AfterCommand, FEditor.Text);
end;

procedure TMarkdownFmxEditorTests.AttachPreview_AfterEditAndFlush_PreviewContainsEdit;
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

procedure TMarkdownFmxEditorTests.OffscreenPaint_RendersHighlightedSource;
begin
  const Bitmap = TBitmap.Create(200, 60);
  try
    FEditor.Text := HeadingMarkdown;
    FEditor.PaintTo(Bitmap);
    Assert.IsTrue(Bitmap.Width > 0);
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.Click_PlacesCaretAtClickedTextPosition;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(FarRight, 2, []);
    Assert.AreEqual(Editor.SourceLineStartOffset(1) - 1, Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.ClickFarBelow_PlacesCaretOnLastLine;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, FarDown, []);
    Assert.AreEqual(Editor.SourceLineStartOffset(1), Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.ClickDrag_SelectsDraggedRange;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseMove(FarRight, 2, []);
    Assert.AreEqual('Hello world', Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.ShiftClick_ExtendsSelectionToClick;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseDown(FarRight, 2, [ssShift]);
    Assert.AreEqual('Hello world', Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.DoubleClick_SelectsWordUnderCursor;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseDown(0, 2, []);
    Assert.AreEqual('Hello', Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.TripleClick_SelectsWholeLine;
begin
  const Editor = TTestableFmxEditor.Create(nil);
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

procedure TMarkdownFmxEditorTests.DragBelowLastLine_ClampsToDocumentEnd;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseMove(FarRight, FarDown, []);
    Assert.AreEqual(MouseText, Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.DragOutsideControlBounds_KeepsSelecting;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := MouseText;
    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseMove(FarRight, Editor.Height + 500, []);
    Assert.AreEqual(MouseText, Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.KeyChar_InsertsPrintableCharacter;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := '';
    Editor.SimulateKeyDown(0, 'Z', []);
    Assert.AreEqual('Z', Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.KeyBackspace_DeletesCharBeforeCaret;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'ab';
    Editor.CaretPosition := 2;
    Editor.SimulateKeyDown(vkBack, #0, []);
    Assert.AreEqual('a', Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.KeyDelete_DeletesCharAfterCaret;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'ab';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkDelete, #0, []);
    Assert.AreEqual('b', Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.KeyReturn_InsertsNewLine;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'ab';
    Editor.CaretPosition := 1;
    Editor.SimulateKeyDown(vkReturn, #0, []);
    Assert.AreEqual('a'#10'b', Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.KeyRightThenLeft_MovesCaretByOne;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'abc';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkRight, #0, []);
    Assert.AreEqual(1, Editor.CaretPosition);
    Editor.SimulateKeyDown(vkLeft, #0, []);
    Assert.AreEqual(0, Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.KeyDownThenUp_MovesCaretBetweenLines;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'first'#10'second';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkDown, #0, []);
    Assert.IsTrue(Editor.CaretPosition >= Editor.SourceLineStartOffset(1),
      Format('Expected caret on second line but got %d', [Editor.CaretPosition]));
    Editor.SimulateKeyDown(vkUp, #0, []);
    Assert.IsTrue(Editor.CaretPosition < Editor.SourceLineStartOffset(1),
      Format('Expected caret back on first line but got %d', [Editor.CaretPosition]));
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.KeyHomeAndEnd_MoveToLineBounds;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'hello';
    Editor.CaretPosition := 2;
    Editor.SimulateKeyDown(vkEnd, #0, []);
    Assert.AreEqual(5, Editor.CaretPosition);
    Editor.SimulateKeyDown(vkHome, #0, []);
    Assert.AreEqual(0, Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.ShiftArrow_ExtendsSelection;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'hello';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkRight, #0, [ssShift]);
    Editor.SimulateKeyDown(vkRight, #0, [ssShift]);
    Assert.AreEqual('he', Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.CtrlWordArrows_MoveByWord;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'foo bar';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkRight, #0, [ssCtrl]);
    Assert.IsTrue(Editor.CaretPosition >= 3,
      Format('Expected caret past first word but got %d', [Editor.CaretPosition]));
    const AfterRight = Editor.CaretPosition;
    Editor.SimulateKeyDown(vkLeft, #0, [ssCtrl]);
    Assert.IsTrue(Editor.CaretPosition < AfterRight,
      Format('Expected caret to move left of %d but got %d', [AfterRight, Editor.CaretPosition]));
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.CtrlHomeAndEnd_MoveToDocumentBounds;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'line one'#10'line two';
    Editor.CaretPosition := 3;
    Editor.SimulateKeyDown(vkEnd, #0, [ssCtrl]);
    Assert.AreEqual(Length(Editor.Text), Editor.CaretPosition);
    Editor.SimulateKeyDown(vkHome, #0, [ssCtrl]);
    Assert.AreEqual(0, Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.CtrlA_SelectsAllText;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'select me';
    Editor.SimulateKeyDown(vkA, #0, [ssCtrl]);
    Assert.AreEqual('select me', Editor.SelectedText);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.CtrlZ_UndoesAndCtrlY_Redoes;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'abc';
    Editor.SimulateKeyDown(vkB, #0, [ssCtrl]);
    const AfterBold = Editor.Text;
    Assert.AreNotEqual('abc', AfterBold);
    Editor.SimulateKeyDown(vkZ, #0, [ssCtrl]);
    Assert.AreEqual('abc', Editor.Text);
    Editor.SimulateKeyDown(vkY, #0, [ssCtrl]);
    Assert.AreEqual(AfterBold, Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.CtrlB_TogglesBoldFormatting;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'word';
    Editor.SimulateKeyDown(vkA, #0, [ssCtrl]);
    Editor.SimulateKeyDown(vkB, #0, [ssCtrl]);
    Assert.Contains(Editor.Text, '**');
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.CtrlI_TogglesItalicFormatting;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'word';
    Editor.SimulateKeyDown(vkA, #0, [ssCtrl]);
    Editor.SimulateKeyDown(vkI, #0, [ssCtrl]);
    Assert.AreNotEqual('word', Editor.Text);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.CtrlK_InsertsLinkSyntax;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'word';
    Editor.SimulateKeyDown(vkA, #0, [ssCtrl]);
    Editor.SimulateKeyDown(vkK, #0, [ssCtrl]);
    Assert.Contains(Editor.Text, '](');
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.CtrlC_CopiesSelectionToClipboard;
begin
  if not ClipboardIsAvailable then
    Assert.Pass('Clipboard service unavailable in this test session');

  var Service: IFMXClipboardService;
  TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Service);
  const Saved = Service.GetClipboard;
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'copy target';
    Editor.SimulateKeyDown(vkA, #0, [ssCtrl]);
    Editor.SimulateKeyDown(vkC, #0, [ssCtrl]);
    Assert.AreEqual('copy target', Service.GetClipboard.ToString);
  finally
    Editor.Free;
    Service.SetClipboard(Saved);
  end;
end;

procedure TMarkdownFmxEditorTests.CtrlX_CutsSelectionToClipboard;
begin
  if not ClipboardIsAvailable then
    Assert.Pass('Clipboard service unavailable in this test session');

  var Service: IFMXClipboardService;
  TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Service);
  const Saved = Service.GetClipboard;
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'cut target';
    Editor.SimulateKeyDown(vkA, #0, [ssCtrl]);
    Editor.SimulateKeyDown(vkX, #0, [ssCtrl]);
    Assert.AreEqual('cut target', Service.GetClipboard.ToString);
    Assert.AreEqual('', Editor.Text);
  finally
    Editor.Free;
    Service.SetClipboard(Saved);
  end;
end;

procedure TMarkdownFmxEditorTests.CtrlV_PastesClipboardText;
begin
  if not ClipboardIsAvailable then
    Assert.Pass('Clipboard service unavailable in this test session');

  var Service: IFMXClipboardService;
  TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Service);
  const Saved = Service.GetClipboard;
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Service.SetClipboard('pasted');
    Editor.Text := '';
    Editor.CaretPosition := 0;
    Editor.SimulateKeyDown(vkV, #0, [ssCtrl]);
    Assert.AreEqual('pasted', Editor.Text);
  finally
    Editor.Free;
    Service.SetClipboard(Saved);
  end;
end;

procedure TMarkdownFmxEditorTests.MouseWheelDown_ScrollsContentDown;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Height := ShortHeight;
    Editor.Text := ManyLines(ManyLineCount);
    const Before = Editor.FirstVisibleSourceLine;
    Editor.SimulateWheel(-120);
    Assert.IsTrue(Editor.FirstVisibleSourceLine > Before,
      Format('Expected viewport to advance from line %d', [Before]));
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.ClickAfterScroll_MapsToVisibleLine;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Height := ShortHeight;
    Editor.Text := ManyLines(ManyLineCount);

    for var Notch := 1 to 5 do
      Editor.SimulateWheel(-120);

    const VisibleLine = Editor.FirstVisibleSourceLine;
    Assert.IsTrue(VisibleLine > 0, 'Expected content to have scrolled down');

    Editor.SimulateMouseDown(0, 2, []);
    Assert.AreEqual(Editor.SourceLineStartOffset(VisibleLine), Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.GutterClick_PlacesCaretAtLineStart;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.ShowLineNumbers := True;
    Editor.Text := MouseText;

    Editor.SimulateMouseDown(0, 2, []);
    Assert.AreEqual(Editor.SourceLineStartOffset(0), Editor.CaretPosition);
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.PageDownAndPageUp_MoveCaretByPage;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Height := ShortHeight;
    Editor.Text := ManyLines(ManyLineCount);
    Editor.CaretPosition := 0;

    Editor.SimulateKeyDown(vkNext, #0, []);
    const AfterPageDown = Editor.CaretPosition;
    Assert.IsTrue(AfterPageDown >= Editor.SourceLineStartOffset(1),
      Format('Expected page down to move the caret down a page but caret is at %d', [AfterPageDown]));

    Editor.SimulateKeyDown(vkPrior, #0, []);
    Assert.IsTrue(Editor.CaretPosition < AfterPageDown,
      Format('Expected page up to move the caret back above %d', [AfterPageDown]));
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.AutoScrollTimer_DuringDragOutside_ExtendsSelection;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Height := ShortHeight;
    Editor.Text := ManyLines(ManyLineCount);

    Editor.SimulateMouseDown(0, 2, []);
    Editor.SimulateMouseMove(5, Editor.Height + 50, []);
    Editor.PumpAutoScrollTimer;

    Assert.IsTrue(Length(Editor.SelectedText) > 0, 'Expected drag-outside to extend the selection');
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxEditorTests.FocusEnterExit_TogglesCaretWithoutError;
begin
  const Editor = TTestableFmxEditor.Create(nil);
  try
    Editor.Text := 'focus body';

    Editor.SimulateEnter;
    Editor.SimulateExit;
    Assert.AreEqual('focus body', Editor.Text);
  finally
    Editor.Free;
  end;
end;

end.
