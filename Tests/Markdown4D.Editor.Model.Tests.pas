unit Markdown4D.Editor.Model.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.Model;

type
  [TestFixture]
  TMarkdownEditorModelTests = class
  private
    const
      SampleText = 'Hello world';
      MultiLineText = 'first line'#10'second line'#10'third line';
      SurrogateText = 'ab'#$D83D#$DE00'cd';
    var
      FModel: TMarkdownEditorModel;
      FMirror: string;
      FChangeCount: Integer;
    procedure HandleChange(const Sender: TObject; const Range: TEditorReplaceRange);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure LoadText_NormalizesCrlfToLf;

    [Test]
    procedure LineCount_CountsNewlineSeparatedLines;

    [Test]
    procedure OffsetOfLineStart_ReturnsCharOffset;

    [Test]
    procedure LineIndexOfOffset_RoundTripsWithLineStart;

    [Test]
    procedure Insert_AtCaret_InsertsText;

    [Test]
    procedure DeleteBackward_RemovesPrecedingCharacter;

    [Test]
    procedure MoveCaret_OverSurrogatePair_NeverLandsMidPair;

    [Test]
    procedure ShiftMovement_ExtendsSelection;

    [Test]
    procedure MoveWordRight_JumpsWholeWord;

    [Test]
    procedure SelectAll_SelectsEntireBuffer;

    [Test]
    procedure ReplaceSelectionOnType_ReplacesSelectedText;

    [Test]
    procedure Undo_CoalescesConsecutiveTyping;

    [Test]
    procedure BreakUndoCoalescing_SplitsTypingIntoTwoSteps;

    [Test]
    procedure Redo_ClearedByNewEdit;

    [Test]
    procedure UndoAll_RestoresByteIdenticalOriginal;

    [Test]
    procedure Change_EmitsReplayableReplaceRange;

    [Test]
    procedure ExecuteBold_WrapsSelection;

    [Test]
    procedure ExecuteBold_OnBoldSelection_Unwraps;

    [Test]
    procedure ExecuteLink_InsertsPlaceholderWithCaretInUrl;

    [Test]
    procedure ExecuteCodeBlock_WrapsLinesInFences;

    [Test]
    procedure SelectWordAt_InsideWord_SelectsWholeWord;

    [Test]
    procedure SelectWordAt_UnderscoresAndDigits_FormSingleWord;

    [Test]
    procedure SelectWordAt_PunctuationIsland_SelectsPunctuationRun;

    [Test]
    procedure SelectWordAt_AtTrailingBoundary_SelectsPrecedingWord;

    [Test]
    procedure SelectWordAt_OverSurrogatePair_SelectsWholeEmoji;

    [Test]
    procedure SelectLineAt_MiddleLine_SelectsLineWithoutNewline;
  end;

implementation

uses
  System.SysUtils;

procedure TMarkdownEditorModelTests.Setup;
begin
  FModel := TMarkdownEditorModel.Create;
  FMirror := '';
  FChangeCount := 0;
end;

procedure TMarkdownEditorModelTests.TearDown;
begin
  FModel.Free;
end;

procedure TMarkdownEditorModelTests.HandleChange(const Sender: TObject; const Range: TEditorReplaceRange);
begin
  Inc(FChangeCount);
  FMirror := Range.Apply(FMirror);
end;

procedure TMarkdownEditorModelTests.LoadText_NormalizesCrlfToLf;
begin
  FModel.LoadText('a'#13#10'b'#13'c');
  Assert.AreEqual('a'#10'b'#10'c', FModel.Text);
end;

procedure TMarkdownEditorModelTests.LineCount_CountsNewlineSeparatedLines;
begin
  FModel.LoadText(MultiLineText);
  Assert.AreEqual(3, FModel.LineCount);
end;

procedure TMarkdownEditorModelTests.OffsetOfLineStart_ReturnsCharOffset;
begin
  FModel.LoadText(MultiLineText);
  Assert.AreEqual(11, FModel.OffsetOfLineStart(1));
end;

procedure TMarkdownEditorModelTests.LineIndexOfOffset_RoundTripsWithLineStart;
begin
  FModel.LoadText(MultiLineText);
  const LineStart = FModel.OffsetOfLineStart(2);
  Assert.AreEqual(2, FModel.LineIndexOfOffset(LineStart));
end;

procedure TMarkdownEditorModelTests.Insert_AtCaret_InsertsText;
begin
  FModel.LoadText(SampleText);
  FModel.CaretPosition := 5;
  FModel.Insert('!');
  Assert.AreEqual('Hello! world', FModel.Text);
end;

procedure TMarkdownEditorModelTests.DeleteBackward_RemovesPrecedingCharacter;
begin
  FModel.LoadText(SampleText);
  FModel.CaretPosition := 5;
  FModel.DeleteBackward;
  Assert.AreEqual('Hell world', FModel.Text);
end;

procedure TMarkdownEditorModelTests.MoveCaret_OverSurrogatePair_NeverLandsMidPair;
begin
  FModel.LoadText(SurrogateText);
  FModel.CaretPosition := 2;
  FModel.MoveCaret(1, False);
  Assert.AreEqual(4, FModel.CaretPosition);
end;

procedure TMarkdownEditorModelTests.ShiftMovement_ExtendsSelection;
begin
  FModel.LoadText(SampleText);
  FModel.CaretPosition := 0;
  FModel.MoveCaret(5, True);
  Assert.AreEqual('Hello', FModel.SelectedText);
end;

procedure TMarkdownEditorModelTests.MoveWordRight_JumpsWholeWord;
begin
  FModel.LoadText(SampleText);
  FModel.CaretPosition := 0;
  FModel.MoveWordRight(False);
  Assert.AreEqual(6, FModel.CaretPosition);
end;

procedure TMarkdownEditorModelTests.SelectAll_SelectsEntireBuffer;
begin
  FModel.LoadText(SampleText);
  FModel.SelectAll;
  Assert.AreEqual(SampleText, FModel.SelectedText);
end;

procedure TMarkdownEditorModelTests.ReplaceSelectionOnType_ReplacesSelectedText;
begin
  FModel.LoadText(SampleText);
  FModel.SetSelection(0, 5);
  FModel.Insert('Howdy');
  Assert.AreEqual('Howdy world', FModel.Text);
end;

procedure TMarkdownEditorModelTests.Undo_CoalescesConsecutiveTyping;
begin
  FModel.LoadText('');
  FModel.Insert('a');
  FModel.Insert('b');
  FModel.Insert('c');
  FModel.Undo;
  Assert.AreEqual('', FModel.Text);
end;

procedure TMarkdownEditorModelTests.BreakUndoCoalescing_SplitsTypingIntoTwoSteps;
begin
  FModel.LoadText('');
  FModel.Insert('ab');
  FModel.BreakUndoCoalescing;
  FModel.Insert('cd');
  FModel.Undo;
  Assert.AreEqual('ab', FModel.Text);
end;

procedure TMarkdownEditorModelTests.Redo_ClearedByNewEdit;
begin
  FModel.LoadText('');
  FModel.Insert('a');
  FModel.Undo;
  FModel.Insert('b');
  Assert.IsFalse(FModel.CanRedo);
end;

procedure TMarkdownEditorModelTests.UndoAll_RestoresByteIdenticalOriginal;
begin
  FModel.LoadText(SampleText);
  FModel.CaretPosition := Length(SampleText);
  FModel.Insert(' extra');
  FModel.BreakUndoCoalescing;
  FModel.SetSelection(0, 5);
  FModel.Insert('Hi');
  while FModel.CanUndo do
    FModel.Undo;
  Assert.AreEqual(SampleText, FModel.Text);
end;

procedure TMarkdownEditorModelTests.Change_EmitsReplayableReplaceRange;
begin
  FModel.LoadText('start');
  FMirror := FModel.Text;
  FModel.OnChange := HandleChange;
  FModel.CaretPosition := 5;
  FModel.Insert('X');
  FModel.SetSelection(0, 1);
  FModel.Insert('Y');
  Assert.AreEqual(FModel.Text, FMirror);
end;

procedure TMarkdownEditorModelTests.ExecuteBold_WrapsSelection;
begin
  FModel.LoadText(SampleText);
  FModel.SetSelection(0, 5);
  FModel.ExecuteCommand(TEditorCommand.Bold);
  Assert.AreEqual('**Hello** world', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteBold_OnBoldSelection_Unwraps;
begin
  FModel.LoadText('**Hello** world');
  FModel.SetSelection(0, 9);
  FModel.ExecuteCommand(TEditorCommand.Bold);
  Assert.AreEqual('Hello world', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteLink_InsertsPlaceholderWithCaretInUrl;
begin
  FModel.LoadText('Hello');
  FModel.SetSelection(0, 5);
  FModel.ExecuteCommand(TEditorCommand.Link);
  Assert.AreEqual('[Hello](url)', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteCodeBlock_WrapsLinesInFences;
begin
  FModel.LoadText('code');
  FModel.SelectAll;
  FModel.ExecuteCommand(TEditorCommand.CodeBlock);
  Assert.AreEqual('```'#10'code'#10'```', FModel.Text);
end;

procedure TMarkdownEditorModelTests.SelectWordAt_InsideWord_SelectsWholeWord;
begin
  FModel.LoadText(SampleText);
  FModel.SelectWordAt(2);
  Assert.AreEqual('Hello', FModel.SelectedText);
end;

procedure TMarkdownEditorModelTests.SelectWordAt_UnderscoresAndDigits_FormSingleWord;
begin
  FModel.LoadText('foo_bar123 tail');
  FModel.SelectWordAt(4);
  Assert.AreEqual('foo_bar123', FModel.SelectedText);
end;

procedure TMarkdownEditorModelTests.SelectWordAt_PunctuationIsland_SelectsPunctuationRun;
begin
  FModel.LoadText('a???b');
  FModel.SelectWordAt(2);
  Assert.AreEqual('???', FModel.SelectedText);
end;

procedure TMarkdownEditorModelTests.SelectWordAt_AtTrailingBoundary_SelectsPrecedingWord;
begin
  FModel.LoadText(SampleText);
  FModel.SelectWordAt(5);
  Assert.AreEqual('Hello', FModel.SelectedText);
end;

procedure TMarkdownEditorModelTests.SelectWordAt_OverSurrogatePair_SelectsWholeEmoji;
begin
  FModel.LoadText(SurrogateText);
  FModel.SelectWordAt(2);
  Assert.AreEqual(#$D83D#$DE00, FModel.SelectedText);
end;

procedure TMarkdownEditorModelTests.SelectLineAt_MiddleLine_SelectsLineWithoutNewline;
begin
  FModel.LoadText(MultiLineText);
  FModel.SelectLineAt(FModel.OffsetOfLineStart(1) + 2);
  Assert.AreEqual('second line', FModel.SelectedText);
end;

end.
