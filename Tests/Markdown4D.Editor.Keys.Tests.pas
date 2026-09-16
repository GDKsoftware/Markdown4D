unit Markdown4D.Editor.Keys.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.Model,
  Markdown4D.Editor.Keys;

type
  [TestFixture]
  TMarkdownEditorKeymapTests = class
  public
    [Test]
    procedure Resolve_PlainLeftArrow_ReturnsMoveLeft;

    [Test]
    procedure Resolve_ShiftRightArrow_ReturnsMoveRightWithExtend;

    [Test]
    procedure Resolve_CtrlArrows_ReturnsMoveWordActions;

    [Test]
    procedure Resolve_CtrlBackspace_ReturnsDeleteWordLeft;

    [Test]
    procedure Resolve_CtrlDelete_ReturnsDeleteWordRight;

    [Test]
    procedure Resolve_PlainTab_ReturnsIndent;

    [Test]
    procedure Resolve_ShiftTab_ReturnsOutdent;

    [Test]
    procedure Resolve_CtrlZVariants_ReturnsUndoOrRedo;

    [Test]
    procedure Resolve_CtrlY_ReturnsRedo;

    [Test]
    procedure Resolve_ShiftInsert_ReturnsPaste;

    [Test]
    procedure Resolve_CtrlInsert_ReturnsCopy;

    [Test]
    procedure Resolve_ShiftDelete_ReturnsCut;

    [Test]
    procedure Resolve_CtrlAltLetter_IsNotHandled;

    [Test]
    procedure Resolve_PlainAltArrow_IsNotHandled;

    [Test]
    procedure Resolve_UnmappedKey_IsNotHandled;
  end;

  [TestFixture]
  TMarkdownEditorKeyDispatchTests = class
  private
    const
      IndentWidth = 2;
    var
      FModel: TMarkdownEditorModel;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Apply_MoveRightAction_MovesCaretRightAndReturnsHandled;

    [Test]
    procedure Apply_IndentAction_InsertsIndentWidthSpaces;

    [Test]
    procedure Apply_BoldAction_WrapsSelectionInBoldMarkers;

    [Test]
    procedure Apply_NoneAction_ReturnsNotHandled;
  end;

implementation

uses
  System.Classes,
  System.UITypes;

procedure TMarkdownEditorKeymapTests.Resolve_PlainLeftArrow_ReturnsMoveLeft;
begin
  const Stroke = TMarkdownEditorKeymap.Resolve(vkLeft, []);

  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.MoveLeft, Stroke.Action);
  Assert.IsFalse(Stroke.Extend);
end;

procedure TMarkdownEditorKeymapTests.Resolve_ShiftRightArrow_ReturnsMoveRightWithExtend;
begin
  const Stroke = TMarkdownEditorKeymap.Resolve(vkRight, [ssShift]);

  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.MoveRight, Stroke.Action);
  Assert.IsTrue(Stroke.Extend);
end;

procedure TMarkdownEditorKeymapTests.Resolve_CtrlArrows_ReturnsMoveWordActions;
begin
  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.MoveWordLeft, TMarkdownEditorKeymap.Resolve(vkLeft, [ssCtrl]).Action);
  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.MoveWordRight, TMarkdownEditorKeymap.Resolve(vkRight, [ssCtrl]).Action);
end;

procedure TMarkdownEditorKeymapTests.Resolve_CtrlBackspace_ReturnsDeleteWordLeft;
begin
  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.DeleteWordLeft, TMarkdownEditorKeymap.Resolve(vkBack, [ssCtrl]).Action);
end;

procedure TMarkdownEditorKeymapTests.Resolve_CtrlDelete_ReturnsDeleteWordRight;
begin
  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.DeleteWordRight, TMarkdownEditorKeymap.Resolve(vkDelete, [ssCtrl]).Action);
end;

procedure TMarkdownEditorKeymapTests.Resolve_PlainTab_ReturnsIndent;
begin
  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.Indent, TMarkdownEditorKeymap.Resolve(vkTab, []).Action);
end;

procedure TMarkdownEditorKeymapTests.Resolve_ShiftTab_ReturnsOutdent;
begin
  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.Outdent, TMarkdownEditorKeymap.Resolve(vkTab, [ssShift]).Action);
end;

procedure TMarkdownEditorKeymapTests.Resolve_CtrlZVariants_ReturnsUndoOrRedo;
begin
  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.Undo, TMarkdownEditorKeymap.Resolve(vkZ, [ssCtrl]).Action);
  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.Redo, TMarkdownEditorKeymap.Resolve(vkZ, [ssCtrl, ssShift]).Action);
end;

procedure TMarkdownEditorKeymapTests.Resolve_CtrlY_ReturnsRedo;
begin
  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.Redo, TMarkdownEditorKeymap.Resolve(vkY, [ssCtrl]).Action);
end;

procedure TMarkdownEditorKeymapTests.Resolve_ShiftInsert_ReturnsPaste;
begin
  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.Paste, TMarkdownEditorKeymap.Resolve(vkInsert, [ssShift]).Action);
end;

procedure TMarkdownEditorKeymapTests.Resolve_CtrlInsert_ReturnsCopy;
begin
  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.Copy, TMarkdownEditorKeymap.Resolve(vkInsert, [ssCtrl]).Action);
end;

procedure TMarkdownEditorKeymapTests.Resolve_ShiftDelete_ReturnsCut;
begin
  Assert.AreEqual<TEditorKeyAction>(TEditorKeyAction.Cut, TMarkdownEditorKeymap.Resolve(vkDelete, [ssShift]).Action);
end;

procedure TMarkdownEditorKeymapTests.Resolve_CtrlAltLetter_IsNotHandled;
begin
  // AltGr reaches the control as Ctrl+Alt; claiming it would eat the character
  // the layout puts behind that combination.
  const Stroke = TMarkdownEditorKeymap.Resolve(vkB, [ssCtrl, ssAlt]);

  Assert.IsFalse(Stroke.Handled);
end;

procedure TMarkdownEditorKeymapTests.Resolve_PlainAltArrow_IsNotHandled;
begin
  Assert.IsFalse(TMarkdownEditorKeymap.Resolve(vkLeft, [ssAlt]).Handled);
end;

procedure TMarkdownEditorKeymapTests.Resolve_UnmappedKey_IsNotHandled;
begin
  Assert.IsFalse(TMarkdownEditorKeymap.Resolve(vkF5, []).Handled);
end;

procedure TMarkdownEditorKeyDispatchTests.Setup;
begin
  FModel := TMarkdownEditorModel.Create;
end;

procedure TMarkdownEditorKeyDispatchTests.TearDown;
begin
  FModel.Free;
end;

procedure TMarkdownEditorKeyDispatchTests.Apply_MoveRightAction_MovesCaretRightAndReturnsHandled;
begin
  FModel.LoadText('hello');
  FModel.CaretPosition := 0;
  const Stroke = TEditorKeyStroke.Create(TEditorKeyAction.MoveRight, False);

  const Handled = TMarkdownEditorKeyDispatch.Apply(FModel, Stroke, IndentWidth);

  Assert.IsTrue(Handled);
  Assert.AreEqual(1, FModel.CaretPosition);
end;

procedure TMarkdownEditorKeyDispatchTests.Apply_IndentAction_InsertsIndentWidthSpaces;
begin
  FModel.LoadText('line');
  FModel.CaretPosition := 0;
  const Stroke = TEditorKeyStroke.Create(TEditorKeyAction.Indent, False);

  TMarkdownEditorKeyDispatch.Apply(FModel, Stroke, IndentWidth);

  Assert.AreEqual('  line', FModel.Text);
end;

procedure TMarkdownEditorKeyDispatchTests.Apply_BoldAction_WrapsSelectionInBoldMarkers;
begin
  FModel.LoadText('Hello');
  FModel.SetSelection(0, 5);
  const Stroke = TEditorKeyStroke.Create(TEditorKeyAction.Bold, False);

  TMarkdownEditorKeyDispatch.Apply(FModel, Stroke, IndentWidth);

  Assert.AreEqual('**Hello**', FModel.Text);
end;

procedure TMarkdownEditorKeyDispatchTests.Apply_NoneAction_ReturnsNotHandled;
begin
  const Stroke = TEditorKeyStroke.Create(TEditorKeyAction.None, False);

  const Handled = TMarkdownEditorKeyDispatch.Apply(FModel, Stroke, IndentWidth);

  Assert.IsFalse(Handled);
end;

end.
