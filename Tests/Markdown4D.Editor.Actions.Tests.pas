unit Markdown4D.Editor.Actions.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.Model,
  Markdown4D.Editor.Actions;

type
  [TestFixture]
  TMarkdownEditorActionsTests = class
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
    procedure Indent_WithoutSelection_InsertsSpacesAtCaret;

    [Test]
    procedure Indent_MultiLineSelection_ShiftsEveryLine;

    [Test]
    procedure Outdent_MultiLineSelection_RemovesOneStep;

    [Test]
    procedure Outdent_LineWithTab_RemovesTheTab;

    [Test]
    procedure Outdent_UnindentedLines_LeavesTextAlone;

    [Test]
    procedure LineBreak_PlainLine_KeepsIndent;

    [Test]
    procedure LineBreak_BulletItem_ContinuesTheList;

    [Test]
    procedure LineBreak_NestedBullet_KeepsNesting;

    [Test]
    procedure LineBreak_NumberedItem_IncrementsTheNumber;

    [Test]
    procedure LineBreak_TaskItem_StartsAnUncheckedTask;

    [Test]
    procedure LineBreak_Quote_ContinuesTheQuote;

    [Test]
    procedure LineBreak_EmptyBulletItem_ClearsTheMarker;

    [Test]
    procedure LineBreak_EmptyNumberedItem_ClearsTheMarker;

    [Test]
    procedure LineBreak_MidWord_DoesNotDuplicateTheMarker;
  end;

implementation

procedure TMarkdownEditorActionsTests.Setup;
begin
  FModel := TMarkdownEditorModel.Create;
end;

procedure TMarkdownEditorActionsTests.TearDown;
begin
  FModel.Free;
end;

procedure TMarkdownEditorActionsTests.Indent_WithoutSelection_InsertsSpacesAtCaret;
begin
  FModel.LoadText('alpha');
  FModel.CaretPosition := 0;

  TMarkdownEditorActions.Indent(FModel, IndentWidth);

  Assert.AreEqual('  alpha', FModel.Text);
  Assert.AreEqual(2, FModel.CaretPosition);
end;

procedure TMarkdownEditorActionsTests.Indent_MultiLineSelection_ShiftsEveryLine;
begin
  FModel.LoadText('one'#10'two'#10'three');
  FModel.SetSelection(0, Length(FModel.Text));

  TMarkdownEditorActions.Indent(FModel, IndentWidth);

  Assert.AreEqual('  one'#10'  two'#10'  three', FModel.Text);
end;

procedure TMarkdownEditorActionsTests.Outdent_MultiLineSelection_RemovesOneStep;
begin
  FModel.LoadText('    one'#10'  two');
  FModel.SetSelection(0, Length(FModel.Text));

  TMarkdownEditorActions.Outdent(FModel, IndentWidth);

  Assert.AreEqual('  one'#10'two', FModel.Text);
end;

procedure TMarkdownEditorActionsTests.Outdent_LineWithTab_RemovesTheTab;
begin
  FModel.LoadText(#9'one');
  FModel.CaretPosition := 2;

  TMarkdownEditorActions.Outdent(FModel, IndentWidth);

  Assert.AreEqual('one', FModel.Text);
end;

procedure TMarkdownEditorActionsTests.Outdent_UnindentedLines_LeavesTextAlone;
begin
  FModel.LoadText('one'#10'two');
  FModel.SetSelection(0, Length(FModel.Text));

  TMarkdownEditorActions.Outdent(FModel, IndentWidth);

  Assert.AreEqual('one'#10'two', FModel.Text);
  Assert.IsFalse(FModel.CanUndo);
end;

procedure TMarkdownEditorActionsTests.LineBreak_PlainLine_KeepsIndent;
begin
  FModel.LoadText('    indented text');
  FModel.CaretPosition := Length(FModel.Text);

  TMarkdownEditorActions.InsertLineBreak(FModel);

  Assert.AreEqual('    indented text'#10'    ', FModel.Text);
end;

procedure TMarkdownEditorActionsTests.LineBreak_BulletItem_ContinuesTheList;
begin
  FModel.LoadText('- first');
  FModel.CaretPosition := Length(FModel.Text);

  TMarkdownEditorActions.InsertLineBreak(FModel);

  Assert.AreEqual('- first'#10'- ', FModel.Text);
end;

procedure TMarkdownEditorActionsTests.LineBreak_NestedBullet_KeepsNesting;
begin
  FModel.LoadText('  * nested');
  FModel.CaretPosition := Length(FModel.Text);

  TMarkdownEditorActions.InsertLineBreak(FModel);

  Assert.AreEqual('  * nested'#10'  * ', FModel.Text);
end;

procedure TMarkdownEditorActionsTests.LineBreak_NumberedItem_IncrementsTheNumber;
begin
  FModel.LoadText('3. third');
  FModel.CaretPosition := Length(FModel.Text);

  TMarkdownEditorActions.InsertLineBreak(FModel);

  Assert.AreEqual('3. third'#10'4. ', FModel.Text);
end;

procedure TMarkdownEditorActionsTests.LineBreak_TaskItem_StartsAnUncheckedTask;
begin
  FModel.LoadText('- [x] done');
  FModel.CaretPosition := Length(FModel.Text);

  TMarkdownEditorActions.InsertLineBreak(FModel);

  Assert.AreEqual('- [x] done'#10'- [ ] ', FModel.Text);
end;

procedure TMarkdownEditorActionsTests.LineBreak_Quote_ContinuesTheQuote;
begin
  FModel.LoadText('> quoted');
  FModel.CaretPosition := Length(FModel.Text);

  TMarkdownEditorActions.InsertLineBreak(FModel);

  Assert.AreEqual('> quoted'#10'> ', FModel.Text);
end;

procedure TMarkdownEditorActionsTests.LineBreak_EmptyBulletItem_ClearsTheMarker;
begin
  FModel.LoadText('- first'#10'- ');
  FModel.CaretPosition := Length(FModel.Text);

  TMarkdownEditorActions.InsertLineBreak(FModel);

  Assert.AreEqual('- first'#10#10, FModel.Text);
end;

procedure TMarkdownEditorActionsTests.LineBreak_EmptyNumberedItem_ClearsTheMarker;
begin
  FModel.LoadText('1. first'#10'2. ');
  FModel.CaretPosition := Length(FModel.Text);

  TMarkdownEditorActions.InsertLineBreak(FModel);

  Assert.AreEqual('1. first'#10#10, FModel.Text);
end;

procedure TMarkdownEditorActionsTests.LineBreak_MidWord_DoesNotDuplicateTheMarker;
begin
  FModel.LoadText('- alphabeta');
  FModel.CaretPosition := 7;

  TMarkdownEditorActions.InsertLineBreak(FModel);

  Assert.AreEqual('- alpha'#10'- beta', FModel.Text);
end;

end.
