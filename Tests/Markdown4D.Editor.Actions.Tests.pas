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
    [TestCase('Plain line keeps indent', '    indented text,18,    indented text'#10'    ')]
    [TestCase('Bullet item continues the list', '- first,7,- first'#10'- ')]
    [TestCase('Nested bullet keeps nesting', '  * nested,10,  * nested'#10'  * ')]
    [TestCase('Numbered item increments the number', '3. third,8,3. third'#10'4. ')]
    [TestCase('Task item starts an unchecked task', '- [x] done,10,- [x] done'#10'- [ ] ')]
    [TestCase('Quote continues the quote', '> quoted,8,> quoted'#10'> ')]
    [TestCase('Empty bullet item clears the marker', '- first'#10'- ,10,- first'#10#10)]
    [TestCase('Empty numbered item clears the marker', '1. first'#10'2. ,12,1. first'#10#10)]
    [TestCase('Mid word does not duplicate the marker', '- alphabeta,7,- alpha'#10'- beta')]
    procedure LineBreak_Various_ProducesExpectedText(const Text: string; const CaretPosition: Integer; const Expected: string);
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

procedure TMarkdownEditorActionsTests.LineBreak_Various_ProducesExpectedText(const Text: string; const CaretPosition: Integer; const Expected: string);
begin
  FModel.LoadText(Text);
  FModel.CaretPosition := CaretPosition;

  TMarkdownEditorActions.InsertLineBreak(FModel);

  Assert.AreEqual(Expected, FModel.Text);
end;

end.
