unit Markdown4D.Editor.Keys.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.Keys;

type
  [TestFixture]
  TMarkdownEditorKeymapTests = class
  public
    [Test]
    procedure PlainArrow_MovesCaret;

    [Test]
    procedure ShiftArrow_ExtendsSelection;

    [Test]
    procedure CtrlArrow_MovesByWord;

    [Test]
    procedure CtrlBackspace_DeletesWordLeft;

    [Test]
    procedure CtrlDelete_DeletesWordRight;

    [Test]
    procedure Tab_Indents;

    [Test]
    procedure ShiftTab_Outdents;

    [Test]
    procedure CtrlShiftZ_Redoes;

    [Test]
    procedure CtrlY_Redoes;

    [Test]
    procedure ShiftInsert_Pastes;

    [Test]
    procedure CtrlInsert_Copies;

    [Test]
    procedure ShiftDelete_Cuts;

    [Test]
    procedure AltGrLetter_IsLeftToTheCharacterPath;

    [Test]
    procedure PlainAltKey_IsIgnored;

    [Test]
    procedure UnknownKey_IsNotHandled;
  end;

implementation

uses
  System.Classes,
  System.UITypes;

procedure TMarkdownEditorKeymapTests.PlainArrow_MovesCaret;
begin
  const Stroke = TMarkdownEditorKeymap.Resolve(vkLeft, []);

  Assert.IsTrue(Stroke.Action = TEditorKeyAction.MoveLeft);
  Assert.IsFalse(Stroke.Extend);
end;

procedure TMarkdownEditorKeymapTests.ShiftArrow_ExtendsSelection;
begin
  const Stroke = TMarkdownEditorKeymap.Resolve(vkRight, [ssShift]);

  Assert.IsTrue(Stroke.Action = TEditorKeyAction.MoveRight);
  Assert.IsTrue(Stroke.Extend);
end;

procedure TMarkdownEditorKeymapTests.CtrlArrow_MovesByWord;
begin
  Assert.IsTrue(TMarkdownEditorKeymap.Resolve(vkLeft, [ssCtrl]).Action = TEditorKeyAction.MoveWordLeft);
  Assert.IsTrue(TMarkdownEditorKeymap.Resolve(vkRight, [ssCtrl]).Action = TEditorKeyAction.MoveWordRight);
end;

procedure TMarkdownEditorKeymapTests.CtrlBackspace_DeletesWordLeft;
begin
  Assert.IsTrue(TMarkdownEditorKeymap.Resolve(vkBack, [ssCtrl]).Action = TEditorKeyAction.DeleteWordLeft);
end;

procedure TMarkdownEditorKeymapTests.CtrlDelete_DeletesWordRight;
begin
  Assert.IsTrue(TMarkdownEditorKeymap.Resolve(vkDelete, [ssCtrl]).Action = TEditorKeyAction.DeleteWordRight);
end;

procedure TMarkdownEditorKeymapTests.Tab_Indents;
begin
  Assert.IsTrue(TMarkdownEditorKeymap.Resolve(vkTab, []).Action = TEditorKeyAction.Indent);
end;

procedure TMarkdownEditorKeymapTests.ShiftTab_Outdents;
begin
  Assert.IsTrue(TMarkdownEditorKeymap.Resolve(vkTab, [ssShift]).Action = TEditorKeyAction.Outdent);
end;

procedure TMarkdownEditorKeymapTests.CtrlShiftZ_Redoes;
begin
  Assert.IsTrue(TMarkdownEditorKeymap.Resolve(vkZ, [ssCtrl]).Action = TEditorKeyAction.Undo);
  Assert.IsTrue(TMarkdownEditorKeymap.Resolve(vkZ, [ssCtrl, ssShift]).Action = TEditorKeyAction.Redo);
end;

procedure TMarkdownEditorKeymapTests.CtrlY_Redoes;
begin
  Assert.IsTrue(TMarkdownEditorKeymap.Resolve(vkY, [ssCtrl]).Action = TEditorKeyAction.Redo);
end;

procedure TMarkdownEditorKeymapTests.ShiftInsert_Pastes;
begin
  Assert.IsTrue(TMarkdownEditorKeymap.Resolve(vkInsert, [ssShift]).Action = TEditorKeyAction.Paste);
end;

procedure TMarkdownEditorKeymapTests.CtrlInsert_Copies;
begin
  Assert.IsTrue(TMarkdownEditorKeymap.Resolve(vkInsert, [ssCtrl]).Action = TEditorKeyAction.Copy);
end;

procedure TMarkdownEditorKeymapTests.ShiftDelete_Cuts;
begin
  Assert.IsTrue(TMarkdownEditorKeymap.Resolve(vkDelete, [ssShift]).Action = TEditorKeyAction.Cut);
end;

procedure TMarkdownEditorKeymapTests.AltGrLetter_IsLeftToTheCharacterPath;
begin
  // AltGr reaches the control as Ctrl+Alt; claiming it would eat the character
  // the layout puts behind that combination.
  const Stroke = TMarkdownEditorKeymap.Resolve(vkB, [ssCtrl, ssAlt]);

  Assert.IsFalse(Stroke.Handled);
end;

procedure TMarkdownEditorKeymapTests.PlainAltKey_IsIgnored;
begin
  Assert.IsFalse(TMarkdownEditorKeymap.Resolve(vkLeft, [ssAlt]).Handled);
end;

procedure TMarkdownEditorKeymapTests.UnknownKey_IsNotHandled;
begin
  Assert.IsFalse(TMarkdownEditorKeymap.Resolve(vkF5, []).Handled);
end;

end.
