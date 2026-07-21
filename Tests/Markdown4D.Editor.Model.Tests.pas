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
      TableSkeleton =
        '| Header 1 | Header 2 | Header 3 |'#10 +
        '| --- | --- | --- |'#10 +
        '| Cell | Cell | Cell |'#10 +
        '| Cell | Cell | Cell |'#10 +
        '| Cell | Cell | Cell |';
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

    [Test]
    procedure FindText_EmptyNeedle_ReturnsZero;

    [Test]
    procedure FindText_NeedleLongerThanText_ReturnsZero;

    [Test]
    procedure FindText_CountsCaseInsensitive;

    [Test]
    procedure FindText_NonOverlapping;

    [Test]
    procedure FindNext_EmptyNeedle_ReturnsMinusOne;

    [Test]
    procedure FindNext_FromBeforeStart_ReturnsFirstMatch;

    [Test]
    procedure FindNext_AdvancesPastStartAfter;

    [Test]
    procedure FindNext_WrapsAround;

    [Test]
    procedure FindNext_NoMatch_ReturnsMinusOne;

    [Test]
    procedure FindNext_SingleMatchAtStartAfter_WrapsToItself;

    [Test]
    procedure FindNext_CaseInsensitive;

    [Test]
    procedure ExecuteHeading1_AddsPrefix;

    [Test]
    procedure ExecuteHeading1_OnHeading1_Removes;

    [Test]
    procedure ExecuteHeading2_OnHeading1_ReplacesLevel;

    [Test]
    procedure ExecuteHeading1_MultiLine_AddsToEachNonBlank;

    [Test]
    procedure ExecuteHeading1_OnEmptyLine_AddsPrefix;

    [Test]
    procedure ExecuteBullet_AddsDash;

    [Test]
    procedure ExecuteBullet_OnBulleted_Removes;

    [Test]
    procedure ExecuteBullet_MultiLine_SkipsBlankLines;

    [Test]
    procedure ExecuteNumbered_NumbersSequentially;

    [Test]
    procedure ExecuteNumbered_OnNumbered_Removes;

    [Test]
    procedure ExecuteNumbered_MultiLine_BlankLineNotNumbered;

    [Test]
    procedure ExecuteQuote_AddsMarker;

    [Test]
    procedure ExecuteQuote_OnQuoted_Removes;

    [Test]
    procedure ExecuteStrikethrough_WrapsSelection;

    [Test]
    procedure ExecuteStrikethrough_OnStruck_Unwraps;

    [Test]
    procedure ExecuteTable_InsertsSkeletonOnNewLine;

    [Test]
    procedure ExecuteTable_AtDocumentStart_NoLeadingBlank;

    [Test]
    procedure ExecuteHeading1_Undo_RestoresOriginal;

    [Test]
    procedure ExecuteTable_Undo_RestoresOriginal;

    [Test]
    procedure ExecuteHeading1_SelectsModifiedRegion;
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

procedure TMarkdownEditorModelTests.FindText_EmptyNeedle_ReturnsZero;
begin
  FModel.LoadText(SampleText);
  Assert.AreEqual(0, FModel.FindText(''));
end;

procedure TMarkdownEditorModelTests.FindText_NeedleLongerThanText_ReturnsZero;
begin
  FModel.LoadText('ab');
  Assert.AreEqual(0, FModel.FindText('abcdef'));
end;

procedure TMarkdownEditorModelTests.FindText_CountsCaseInsensitive;
begin
  FModel.LoadText('One one ONE');
  Assert.AreEqual(3, FModel.FindText('one'));
end;

procedure TMarkdownEditorModelTests.FindText_NonOverlapping;
begin
  FModel.LoadText('aaaa');
  Assert.AreEqual(2, FModel.FindText('aa'));
end;

procedure TMarkdownEditorModelTests.FindNext_EmptyNeedle_ReturnsMinusOne;
begin
  FModel.LoadText(SampleText);
  Assert.AreEqual(-1, FModel.FindNext('', -1));
end;

procedure TMarkdownEditorModelTests.FindNext_FromBeforeStart_ReturnsFirstMatch;
begin
  FModel.LoadText('ab ab ab');
  Assert.AreEqual(0, FModel.FindNext('ab', -1));
end;

procedure TMarkdownEditorModelTests.FindNext_AdvancesPastStartAfter;
begin
  FModel.LoadText('ab ab ab');
  Assert.AreEqual(3, FModel.FindNext('ab', 0));
end;

procedure TMarkdownEditorModelTests.FindNext_WrapsAround;
begin
  FModel.LoadText('ab ab ab');
  Assert.AreEqual(0, FModel.FindNext('ab', 6));
end;

procedure TMarkdownEditorModelTests.FindNext_NoMatch_ReturnsMinusOne;
begin
  FModel.LoadText('ab ab ab');
  Assert.AreEqual(-1, FModel.FindNext('zz', -1));
end;

procedure TMarkdownEditorModelTests.FindNext_SingleMatchAtStartAfter_WrapsToItself;
begin
  FModel.LoadText('xxabxx');
  const M = FModel.FindNext('ab', -1);
  Assert.AreEqual(2, M);
  Assert.AreEqual(2, FModel.FindNext('ab', M));
end;

procedure TMarkdownEditorModelTests.FindNext_CaseInsensitive;
begin
  FModel.LoadText('Hello');
  Assert.AreEqual(0, FModel.FindNext('HELLO', -1));
end;

procedure TMarkdownEditorModelTests.ExecuteHeading1_AddsPrefix;
begin
  FModel.LoadText('Hello');
  FModel.CaretPosition := 0;
  FModel.ExecuteCommand(TEditorCommand.Heading1);
  Assert.AreEqual('# Hello', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteHeading1_OnHeading1_Removes;
begin
  FModel.LoadText('# Hello');
  FModel.CaretPosition := 0;
  FModel.ExecuteCommand(TEditorCommand.Heading1);
  Assert.AreEqual('Hello', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteHeading2_OnHeading1_ReplacesLevel;
begin
  FModel.LoadText('# Hello');
  FModel.CaretPosition := 0;
  FModel.ExecuteCommand(TEditorCommand.Heading2);
  Assert.AreEqual('## Hello', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteHeading1_MultiLine_AddsToEachNonBlank;
begin
  FModel.LoadText('a'#10'b');
  FModel.SelectAll;
  FModel.ExecuteCommand(TEditorCommand.Heading1);
  Assert.AreEqual('# a'#10'# b', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteHeading1_OnEmptyLine_AddsPrefix;
begin
  FModel.LoadText('');
  FModel.ExecuteCommand(TEditorCommand.Heading1);
  Assert.AreEqual('# ', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteBullet_AddsDash;
begin
  FModel.LoadText('Hello');
  FModel.CaretPosition := 0;
  FModel.ExecuteCommand(TEditorCommand.BulletList);
  Assert.AreEqual('- Hello', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteBullet_OnBulleted_Removes;
begin
  FModel.LoadText('- Hello');
  FModel.CaretPosition := 0;
  FModel.ExecuteCommand(TEditorCommand.BulletList);
  Assert.AreEqual('Hello', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteBullet_MultiLine_SkipsBlankLines;
begin
  FModel.LoadText('a'#10#10'b');
  FModel.SelectAll;
  FModel.ExecuteCommand(TEditorCommand.BulletList);
  Assert.AreEqual('- a'#10#10'- b', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteNumbered_NumbersSequentially;
begin
  FModel.LoadText('a'#10'b'#10'c');
  FModel.SelectAll;
  FModel.ExecuteCommand(TEditorCommand.NumberedList);
  Assert.AreEqual('1. a'#10'2. b'#10'3. c', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteNumbered_OnNumbered_Removes;
begin
  FModel.LoadText('1. a'#10'2. b');
  FModel.SelectAll;
  FModel.ExecuteCommand(TEditorCommand.NumberedList);
  Assert.AreEqual('a'#10'b', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteNumbered_MultiLine_BlankLineNotNumbered;
begin
  FModel.LoadText('a'#10#10'b');
  FModel.SelectAll;
  FModel.ExecuteCommand(TEditorCommand.NumberedList);
  Assert.AreEqual('1. a'#10#10'2. b', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteQuote_AddsMarker;
begin
  FModel.LoadText('Hello');
  FModel.CaretPosition := 0;
  FModel.ExecuteCommand(TEditorCommand.Quote);
  Assert.AreEqual('> Hello', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteQuote_OnQuoted_Removes;
begin
  FModel.LoadText('> Hello');
  FModel.CaretPosition := 0;
  FModel.ExecuteCommand(TEditorCommand.Quote);
  Assert.AreEqual('Hello', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteStrikethrough_WrapsSelection;
begin
  FModel.LoadText('Hello');
  FModel.SetSelection(0, 5);
  FModel.ExecuteCommand(TEditorCommand.Strikethrough);
  Assert.AreEqual('~~Hello~~', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteStrikethrough_OnStruck_Unwraps;
begin
  FModel.LoadText('~~Hello~~');
  FModel.SetSelection(0, 9);
  FModel.ExecuteCommand(TEditorCommand.Strikethrough);
  Assert.AreEqual('Hello', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteTable_InsertsSkeletonOnNewLine;
begin
  FModel.LoadText('Para');
  FModel.CaretPosition := 4;
  FModel.ExecuteCommand(TEditorCommand.Table);
  Assert.AreEqual('Para'#10#10 + TableSkeleton + #10, FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteTable_AtDocumentStart_NoLeadingBlank;
begin
  FModel.LoadText('');
  FModel.ExecuteCommand(TEditorCommand.Table);
  Assert.AreEqual(TableSkeleton + #10, FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteHeading1_Undo_RestoresOriginal;
begin
  FModel.LoadText('Hello');
  FModel.CaretPosition := 0;
  FModel.ExecuteCommand(TEditorCommand.Heading1);
  FModel.Undo;
  Assert.AreEqual('Hello', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteTable_Undo_RestoresOriginal;
begin
  FModel.LoadText('Para');
  FModel.CaretPosition := 4;
  FModel.ExecuteCommand(TEditorCommand.Table);
  FModel.Undo;
  Assert.AreEqual('Para', FModel.Text);
end;

procedure TMarkdownEditorModelTests.ExecuteHeading1_SelectsModifiedRegion;
begin
  FModel.LoadText('Hello');
  FModel.CaretPosition := 0;
  FModel.ExecuteCommand(TEditorCommand.Heading1);
  Assert.AreEqual(0, FModel.SelectionStart);
  Assert.AreEqual('# Hello', FModel.SelectedText);
end;

end.
