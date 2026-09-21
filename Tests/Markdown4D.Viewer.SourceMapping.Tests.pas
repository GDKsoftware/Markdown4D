unit Markdown4D.Viewer.SourceMapping.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Theme,
  Markdown4D.Viewer.Model;

type
  [TestFixture]
  TMarkdownInlineSegmentTests = class
  private
    class function ParseFirstBlock(const Source: string): IMarkdownNode;
    class function FindFirst(const Root: IMarkdownNode; const Kind: TMarkdownNodeKind): IMarkdownNode;
    class procedure AssertSegment(const Expected: TMarkdownSegment; const Node: IMarkdownNode;
                                  const Description: string);
    class procedure AssertSourceText(const Source, Expected: string; const Node: IMarkdownNode);

  public
    [Test]
    procedure Parse_PlainParagraph_TextNodeSpansWholeParagraph;

    [Test]
    procedure Parse_StrongEmphasis_ContainerCoversMarkersAndTextCoversContent;

    [Test]
    procedure Parse_Emphasis_TextSegmentExcludesMarkers;

    [Test]
    procedure Parse_InlineLink_LinkCoversWholeSyntaxAndLabelCoversLabelOnly;

    [Test]
    procedure Parse_CodeSpan_SegmentCoversBackticks;

    [Test]
    procedure Parse_BackslashEscape_TextSegmentCoversEscapedSource;

    [Test]
    procedure Parse_HtmlEntity_TextSegmentCoversEntitySource;

    [Test]
    procedure Parse_ParagraphInsideBlockQuote_TextSegmentSkipsQuoteMarker;

    [Test]
    procedure Parse_SecondSourceLine_TextSegmentFollowsSourceLine;

    [Test]
    procedure Parse_AtxHeading_TextSegmentSkipsHashes;
  end;

  [TestFixture]
  TMarkdownPreviewSelectionTests = class
  private
    const
      ViewportWidth = 600.0;
      ViewportHeight = 400.0;
      // Keeps a point off the seam between two runs, where either of them is
      // equally close and the first one wins.
      InwardNudge = 1.0;
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FModel: TMarkdownViewerModel;
    function RunIndexOf(const RunText: string): Integer;
    function PointInRun(const RunIndex, CharacterIndex: Integer; const Nudge: Single): TLayoutPointF;
    procedure SelectCharacters(const FromRunText: string; const FromCharacter: Integer;
                               const ToRunText: string; const ToCharacter: Integer);
    function SelectedSource(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure SelectionSource_PlainWords_CoversExactlyThoseCharacters;

    [Test]
    procedure SelectionSource_TextInsideStrong_CoversContentWithoutMarkers;

    [Test]
    procedure SelectionSource_LinkLabel_CoversLabelWithoutDestination;

    [Test]
    procedure SelectionSource_AroundBackslashEscape_CoversEscapeSource;

    [Test]
    procedure SelectionSource_AroundHtmlEntity_CoversEntitySource;

    [Test]
    procedure SelectionSource_AcrossTwoInlineNodes_SpansFromFirstToLast;

    [Test]
    procedure SelectionSource_InsideCodeSpan_CoversWholeCodeSpan;

    [Test]
    procedure SelectionSource_WithoutSelection_ReturnsFalse;

    [Test]
    procedure SelectionSource_InsideTable_ReturnsFalse;
  end;

  // Replays what a reader does in preview only mode: select words in the
  // rendered text, press Bold, and read the markdown back.
  [TestFixture]
  TMarkdownPreviewFormattingTests = class
  private
    const
      WideViewport = 4000.0;
      NarrowViewport = 320.0;
      ViewportHeight = 400.0;
      InwardNudge = 1.0;
      BoldMarker = '**';
      FirstLine = 'Formulas are written in LaTeX between dollars. Inline, $E = mc^2$ sits in the';
      SecondLine = 'sentence at the size of the text around it; a block on its own line is set in';
      ThirdLine = 'display style, centred, with limits above and below the operators.';
    type
      // The text the reader sees, with the run and the position inside it that
      // every character came from, so a phrase can be pointed at the way a
      // drag does.
      TVisibleText = record
        Text: string;
        ItemIndexes: TArray<Integer>;
        CharacterIndexes: TArray<Integer>;
      end;
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FModel: TMarkdownViewerModel;
      FSource: string;
    procedure LoadParagraph(const ViewportWidth: Single);
    function VisibleText: TVisibleText;
    function PointAt(const ItemIndex, CharacterIndex: Integer; const Nudge: Single): TLayoutPointF;
    procedure SelectPhrase(const Phrase: string);
    procedure BoldPhrase(const Phrase: string);
    procedure AssertEveryWordMatches;
    procedure AssertBoldThroughEditor(const Phrase, Expected: string);
    procedure BoldThroughEditor(const Phrase: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Bold_WordOnFirstSourceLine_WrapsThatWordOnly;

    [Test]
    procedure Bold_WordOnSecondSourceLine_WrapsThatWordOnly;

    [Test]
    procedure Bold_PhraseOnSecondSourceLine_WrapsThatPhraseOnly;

    [Test]
    procedure Bold_ThreeWordsInTurn_WrapsEachOfThem;

    [Test]
    procedure Bold_WordOnSecondSourceLine_WrapsThatWordOnlyWhenTextRewraps;

    [Test]
    procedure Bold_WordAfterASoftLineBreak_WrapsThatWordOnly;

    [Test]
    procedure SelectionSource_AfterTheTextChanged_ReturnsFalse;

    [Test]
    procedure SelectionSource_AfterTheTextChanged_DoesNotAnswerTheOldRange;

    [Test]
    procedure SelectionSource_EveryWordInTheParagraph_MatchesTheSelectedText;

    [Test]
    procedure SelectionSource_EveryWordAfterEarlierEdits_MatchesTheSelectedText;

    [Test]
    procedure Bold_SelectionCatchingTheSpaceBeforeAWord_WrapsTheWordOnly;

    [Test]
    procedure Bold_SelectionCatchingTheSpaceAfterAWord_WrapsTheWordOnly;

    [Test]
    procedure Bold_HalfOfABoldWordPlusThePlainTextAfterIt_BoldsTheWholeStretch;

    [Test]
    procedure Bold_PressedAgainOnTheSameWord_TakesTheBoldOffAgain;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Character,
  System.Classes,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Editor.Model,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.FakeMeasurer;

class function TMarkdownInlineSegmentTests.ParseFirstBlock(const Source: string): IMarkdownNode;
begin
  const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);

  Assert.IsTrue(Document.ChildCount > 0, 'The document should carry at least one block');

  Result := Document.Children[0];
end;

class function TMarkdownInlineSegmentTests.FindFirst(const Root: IMarkdownNode;
  const Kind: TMarkdownNodeKind): IMarkdownNode;
begin
  if Root.Kind = Kind then
  begin
    Result := Root;
    Exit;
  end;

  for var Index := 0 to Root.ChildCount - 1 do
  begin
    const Found = FindFirst(Root.Children[Index], Kind);
    if Found <> nil then
    begin
      Result := Found;
      Exit;
    end;
  end;

  Result := nil;
end;

class procedure TMarkdownInlineSegmentTests.AssertSegment(const Expected: TMarkdownSegment;
  const Node: IMarkdownNode; const Description: string);
begin
  Assert.IsNotNull(Node, Description);
  Assert.AreEqual(Expected.StartOffset, Node.Segment.StartOffset, Format('%s: start offset', [Description]));
  Assert.AreEqual(Expected.EndOffset, Node.Segment.EndOffset, Format('%s: end offset', [Description]));
end;

class procedure TMarkdownInlineSegmentTests.AssertSourceText(const Source, Expected: string;
  const Node: IMarkdownNode);
begin
  Assert.IsNotNull(Node, 'Node was not found');

  const Actual = Copy(Source, Node.Segment.StartOffset, Node.Segment.Length);

  Assert.AreEqual(Expected, Actual);
end;

procedure TMarkdownInlineSegmentTests.Parse_PlainParagraph_TextNodeSpansWholeParagraph;
begin
  const Source = 'alpha beta';

  const Paragraph = ParseFirstBlock(Source);
  const Text = FindFirst(Paragraph, TMarkdownNodeKind.Text);

  AssertSegment(TMarkdownSegment.Create(1, 11), Text, 'Text node of a plain paragraph');
end;

procedure TMarkdownInlineSegmentTests.Parse_StrongEmphasis_ContainerCoversMarkersAndTextCoversContent;
begin
  const Source = 'alpha **bold** gamma';

  const Paragraph = ParseFirstBlock(Source);
  const Strong = FindFirst(Paragraph, TMarkdownNodeKind.Strong);

  AssertSourceText(Source, '**bold**', Strong);
  AssertSourceText(Source, 'bold', FindFirst(Strong, TMarkdownNodeKind.Text));
end;

procedure TMarkdownInlineSegmentTests.Parse_Emphasis_TextSegmentExcludesMarkers;
begin
  const Source = 'an *italic* word';

  const Paragraph = ParseFirstBlock(Source);
  const Emphasis = FindFirst(Paragraph, TMarkdownNodeKind.Emphasis);

  AssertSourceText(Source, '*italic*', Emphasis);
  AssertSourceText(Source, 'italic', FindFirst(Emphasis, TMarkdownNodeKind.Text));
end;

procedure TMarkdownInlineSegmentTests.Parse_InlineLink_LinkCoversWholeSyntaxAndLabelCoversLabelOnly;
begin
  const Source = 'see [the docs](https://x.example) now';

  const Paragraph = ParseFirstBlock(Source);
  const Link = FindFirst(Paragraph, TMarkdownNodeKind.Link);

  AssertSourceText(Source, '[the docs](https://x.example)', Link);
  AssertSourceText(Source, 'the docs', FindFirst(Link, TMarkdownNodeKind.Text));
end;

procedure TMarkdownInlineSegmentTests.Parse_CodeSpan_SegmentCoversBackticks;
begin
  const Source = 'use `code` here';

  const Paragraph = ParseFirstBlock(Source);

  AssertSourceText(Source, '`code`', FindFirst(Paragraph, TMarkdownNodeKind.CodeSpan));
end;

procedure TMarkdownInlineSegmentTests.Parse_BackslashEscape_TextSegmentCoversEscapedSource;
begin
  const Source = 'a \* b';

  const Paragraph = ParseFirstBlock(Source);

  AssertSourceText(Source, 'a \* b', FindFirst(Paragraph, TMarkdownNodeKind.Text));
end;

procedure TMarkdownInlineSegmentTests.Parse_HtmlEntity_TextSegmentCoversEntitySource;
begin
  const Source = 'x &amp; y';

  const Paragraph = ParseFirstBlock(Source);

  AssertSourceText(Source, 'x &amp; y', FindFirst(Paragraph, TMarkdownNodeKind.Text));
end;

procedure TMarkdownInlineSegmentTests.Parse_ParagraphInsideBlockQuote_TextSegmentSkipsQuoteMarker;
begin
  const Source = '> quoted line';

  const Quote = ParseFirstBlock(Source);

  AssertSourceText(Source, 'quoted line', FindFirst(Quote, TMarkdownNodeKind.Text));
end;

procedure TMarkdownInlineSegmentTests.Parse_SecondSourceLine_TextSegmentFollowsSourceLine;
begin
  const Source = 'first' + LineFeed + LineFeed + 'second';

  const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);

  Assert.AreEqual(2, Document.ChildCount);
  AssertSourceText(Source, 'second', FindFirst(Document.Children[1], TMarkdownNodeKind.Text));
end;

procedure TMarkdownInlineSegmentTests.Parse_AtxHeading_TextSegmentSkipsHashes;
begin
  const Source = '## Title here';

  const Heading = ParseFirstBlock(Source);

  AssertSourceText(Source, 'Title here', FindFirst(Heading, TMarkdownNodeKind.Text));
end;

procedure TMarkdownPreviewSelectionTests.Setup;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FTheme.ContentPadding := 0;
  FMeasurer := TFakeTextMeasurer.Create;
  FModel := TMarkdownViewerModel.Create(FTheme, FMeasurer);
  FModel.SetViewport(ViewportWidth, ViewportHeight);
end;

procedure TMarkdownPreviewSelectionTests.TearDown;
begin
  FModel.Free;
  FModel := nil;

  FMeasurer := nil;

  FTheme.Free;
  FTheme := nil;
end;

function TMarkdownPreviewSelectionTests.RunIndexOf(const RunText: string): Integer;
begin
  const List = FModel.DisplayList;

  for var Index := 0 to List.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    if not Supports(List.Items[Index], IDisplayTextRun, Run) then
      Continue;

    if Run.Text = RunText then
    begin
      Result := Index;
      Exit;
    end;
  end;

  Result := -1;
  Assert.Fail(Format('No text run reads "%s"', [RunText]));
end;

function TMarkdownPreviewSelectionTests.PointInRun(const RunIndex, CharacterIndex: Integer;
  const Nudge: Single): TLayoutPointF;
begin
  const Run = FModel.DisplayList.Items[RunIndex] as IDisplayTextRun;
  const Prefix = Copy(Run.Text, 1, CharacterIndex);
  const PrefixWidth = FMeasurer.MeasureText(Prefix, Run.Font).Width;

  Result := TLayoutPointF.Create(Run.Bounds.Left + PrefixWidth + Nudge,
                                 (Run.Bounds.Top + Run.Bounds.Bottom) / 2);
end;

procedure TMarkdownPreviewSelectionTests.SelectCharacters(const FromRunText: string; const FromCharacter: Integer;
                                                         const ToRunText: string; const ToCharacter: Integer);
begin
  const FromIndex = RunIndexOf(FromRunText);
  const ToIndex = RunIndexOf(ToRunText);

  FModel.SetSelectionAnchor(PointInRun(FromIndex, FromCharacter, InwardNudge));
  FModel.SetSelectionExtent(PointInRun(ToIndex, ToCharacter, -InwardNudge));
end;

function TMarkdownPreviewSelectionTests.SelectedSource(const Source: string): string;
begin
  var Segment: TMarkdownSegment;

  Assert.IsTrue(FModel.TryGetSelectionSourceSegment(Segment), 'The selection should map back to the source');

  Result := Copy(Source, Segment.StartOffset, Segment.Length);
end;

procedure TMarkdownPreviewSelectionTests.SelectionSource_PlainWords_CoversExactlyThoseCharacters;
begin
  const Source = 'alpha beta gamma';
  FModel.Text := Source;

  SelectCharacters(Source, 0, Source, 10);

  Assert.AreEqual('alpha beta', SelectedSource(Source));
end;

procedure TMarkdownPreviewSelectionTests.SelectionSource_TextInsideStrong_CoversContentWithoutMarkers;
begin
  const Source = 'alpha **bold** gamma';
  FModel.Text := Source;

  SelectCharacters('bold', 0, 'bold', 4);

  Assert.AreEqual('bold', SelectedSource(Source));
end;

procedure TMarkdownPreviewSelectionTests.SelectionSource_LinkLabel_CoversLabelWithoutDestination;
begin
  const Source = 'see [the docs](https://x.example) now';
  FModel.Text := Source;

  SelectCharacters('the docs', 0, 'the docs', 8);

  Assert.AreEqual('the docs', SelectedSource(Source));
end;

procedure TMarkdownPreviewSelectionTests.SelectionSource_AroundBackslashEscape_CoversEscapeSource;
begin
  const Source = 'a \* b';
  FModel.Text := Source;

  SelectCharacters('a * b', 2, 'a * b', 3);

  Assert.AreEqual('\*', SelectedSource(Source));
end;

procedure TMarkdownPreviewSelectionTests.SelectionSource_AroundHtmlEntity_CoversEntitySource;
begin
  const Source = 'x &amp; y';
  FModel.Text := Source;

  SelectCharacters('x & y', 2, 'x & y', 3);

  Assert.AreEqual('&amp;', SelectedSource(Source));
end;

procedure TMarkdownPreviewSelectionTests.SelectionSource_AcrossTwoInlineNodes_SpansFromFirstToLast;
begin
  const Source = 'alpha **bold** gamma';
  FModel.Text := Source;

  SelectCharacters('alpha ', 0, ' gamma', 6);

  Assert.AreEqual(Source, SelectedSource(Source));
end;

// Part of a code span is not a stretch of markdown that can be formatted on
// its own, so the whole span comes back.
procedure TMarkdownPreviewSelectionTests.SelectionSource_InsideCodeSpan_CoversWholeCodeSpan;
begin
  const Source = 'use `code` here';
  FModel.Text := Source;

  SelectCharacters('code', 1, 'code', 3);

  Assert.AreEqual('`code`', SelectedSource(Source));
end;

procedure TMarkdownPreviewSelectionTests.SelectionSource_WithoutSelection_ReturnsFalse;
begin
  FModel.Text := 'alpha beta';

  var Segment: TMarkdownSegment;

  Assert.IsFalse(FModel.TryGetSelectionSourceSegment(Segment));
end;

// A cell is cut out of its row before its inlines are parsed, so nothing in a
// table points back at the source yet and the caller is told so.
procedure TMarkdownPreviewSelectionTests.SelectionSource_InsideTable_ReturnsFalse;
begin
  const Lines: TArray<string> = ['| head |', '| ---- |', '| cell |'];
  FModel.Text := string.Join(LineFeed, Lines);

  Assert.IsTrue(FModel.SelectAll);

  var Segment: TMarkdownSegment;

  Assert.IsFalse(FModel.TryGetSelectionSourceSegment(Segment));
end;

procedure TMarkdownPreviewFormattingTests.Setup;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FTheme.ContentPadding := 0;
  FMeasurer := TFakeTextMeasurer.Create;
  FModel := TMarkdownViewerModel.Create(FTheme, FMeasurer);
end;

procedure TMarkdownPreviewFormattingTests.TearDown;
begin
  FModel.Free;
  FModel := nil;

  FMeasurer := nil;

  FTheme.Free;
  FTheme := nil;
end;

// One paragraph carrying the hard line endings the source file has, so the
// rendered text breaks in other places than the markdown does.
procedure TMarkdownPreviewFormattingTests.LoadParagraph(const ViewportWidth: Single);
begin
  const Lines: TArray<string> = [FirstLine, SecondLine, ThirdLine];

  FSource := string.Join(LineFeed, Lines);
  FModel.SetViewport(ViewportWidth, ViewportHeight);
  FModel.Text := FSource;
end;

function TMarkdownPreviewFormattingTests.VisibleText: TVisibleText;
begin
  Result := Default(TVisibleText);

  const Builder = TStringBuilder.Create;
  try
    for var Index := 0 to FModel.DisplayList.ItemCount - 1 do
    begin
      var Run: IDisplayTextRun;
      if not Supports(FModel.DisplayList.Items[Index], IDisplayTextRun, Run) then
        Continue;

      if Run.Role = TDisplayTextRunRole.Drawing then
        Continue;

      for var Position := 1 to Length(Run.Text) do
      begin
        Result.ItemIndexes := Result.ItemIndexes + [Index];
        Result.CharacterIndexes := Result.CharacterIndexes + [Position - 1];
      end;

      Builder.Append(Run.Text);
    end;

    Result.Text := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function TMarkdownPreviewFormattingTests.PointAt(const ItemIndex, CharacterIndex: Integer;
  const Nudge: Single): TLayoutPointF;
begin
  const Run = FModel.DisplayList.Items[ItemIndex] as IDisplayTextRun;
  const Prefix = Copy(Run.Text, 1, CharacterIndex);
  const PrefixWidth = FMeasurer.MeasureText(Prefix, Run.Font).Width;

  Result := TLayoutPointF.Create(Run.Bounds.Left + PrefixWidth + Nudge,
                                 (Run.Bounds.Top + Run.Bounds.Bottom) / 2);
end;

procedure TMarkdownPreviewFormattingTests.SelectPhrase(const Phrase: string);
begin
  const Visible = VisibleText;

  const Found = Pos(Phrase, Visible.Text);
  Assert.IsTrue(Found > 0, Format('The preview does not read "%s"', [Phrase]));

  const LastFound = Found + Length(Phrase) - 1;

  FModel.SetSelectionAnchor(PointAt(Visible.ItemIndexes[Found - 1],
                                    Visible.CharacterIndexes[Found - 1], InwardNudge));
  FModel.SetSelectionExtent(PointAt(Visible.ItemIndexes[LastFound - 1],
                                    Visible.CharacterIndexes[LastFound - 1] + 1, -InwardNudge));
end;

// Selects the phrase in the preview and puts markers around the markdown it
// was rendered from, which is what the studio does when Bold is pressed.
procedure TMarkdownPreviewFormattingTests.BoldPhrase(const Phrase: string);
begin
  SelectPhrase(Phrase);

  Assert.AreEqual(Phrase, FModel.SelectedText, 'The preview selection');

  var Segment: TMarkdownSegment;
  Assert.IsTrue(FModel.TryGetSelectionSourceSegment(Segment),
    Format('No source range for "%s"', [Phrase]));

  const Before = Copy(FSource, 1, Segment.StartOffset - 1);
  const Selected = Copy(FSource, Segment.StartOffset, Segment.Length);
  const After = Copy(FSource, Segment.EndOffset, MaxInt);

  Assert.AreEqual(Phrase, Selected, 'The markdown behind the selection');

  FSource := Before + BoldMarker + Selected + BoldMarker + After;
  FModel.Text := FSource;
end;

// Walks every word the reader can see and checks that the markdown it maps to
// spells the same word. One word landing a character off fails here and names
// itself, whatever made it drift.
procedure TMarkdownPreviewFormattingTests.AssertEveryWordMatches;
begin
  const Visible = VisibleText;

  var Position := 1;

  while Position <= Length(Visible.Text) do
  begin
    const IsWordCharacter = Visible.Text[Position].IsLetter;
    if not IsWordCharacter then
    begin
      Inc(Position);
      Continue;
    end;

    const WordStart = Position;
    while (Position <= Length(Visible.Text)) and Visible.Text[Position].IsLetter do
    begin
      Inc(Position);
    end;

    const Word = Copy(Visible.Text, WordStart, Position - WordStart);
    const Run = FModel.DisplayList.Items[Visible.ItemIndexes[WordStart - 1]] as IDisplayTextRun;

    // The source of a formula is selected whole or not at all, so a word
    // inside it cannot be pointed at on its own.
    if Run.Role = TDisplayTextRunRole.Source then
      Continue;

    FModel.SetSelectionAnchor(PointAt(Visible.ItemIndexes[WordStart - 1],
                                      Visible.CharacterIndexes[WordStart - 1], InwardNudge));
    FModel.SetSelectionExtent(PointAt(Visible.ItemIndexes[Position - 2],
                                      Visible.CharacterIndexes[Position - 2] + 1, -InwardNudge));

    Assert.AreEqual(Word, FModel.SelectedText, Format('Selecting "%s"', [Word]));

    var Segment: TMarkdownSegment;
    Assert.IsTrue(FModel.TryGetSelectionSourceSegment(Segment), Format('No source range for "%s"', [Word]));
    Assert.AreEqual(Word, Copy(FSource, Segment.StartOffset, Segment.Length),
      Format('The markdown behind "%s"', [Word]));
  end;
end;

procedure TMarkdownPreviewFormattingTests.SelectionSource_EveryWordInTheParagraph_MatchesTheSelectedText;
begin
  LoadParagraph(WideViewport);

  AssertEveryWordMatches;
end;

procedure TMarkdownPreviewFormattingTests.SelectionSource_EveryWordAfterEarlierEdits_MatchesTheSelectedText;
begin
  LoadParagraph(WideViewport);

  BoldPhrase('LaTeX');
  BoldPhrase('line is');

  AssertEveryWordMatches;
end;

// Aiming at a word in a rendered paragraph is a matter of a few pixels, and a
// space is the narrowest target on the line. Catching it would produce markers
// standing against whitespace, which CommonMark does not read as emphasis at
// all, so the editor pulls the range in to the word.
procedure TMarkdownPreviewFormattingTests.Bold_SelectionCatchingTheSpaceBeforeAWord_WrapsTheWordOnly;
begin
  LoadParagraph(WideViewport);

  AssertBoldThroughEditor(' around', 'the text **around** it;');
end;

procedure TMarkdownPreviewFormattingTests.Bold_SelectionCatchingTheSpaceAfterAWord_WrapsTheWordOnly;
begin
  LoadParagraph(WideViewport);

  AssertBoldThroughEditor('around ', 'the text **around** it;');
end;

// Runs the whole chain the studio runs: point at the preview, translate, hand
// the range to the editor and let it run the command.
procedure TMarkdownPreviewFormattingTests.AssertBoldThroughEditor(const Phrase, Expected: string);
begin
  SelectPhrase(Phrase);

  Assert.AreEqual(Phrase, FModel.SelectedText, 'The preview selection');

  var Segment: TMarkdownSegment;
  Assert.IsTrue(FModel.TryGetSelectionSourceSegment(Segment), 'No source range');
  Assert.AreEqual(Phrase, Copy(FSource, Segment.StartOffset, Segment.Length), 'The markdown behind the selection');

  const Editor = TMarkdownEditorModel.Create;
  try
    Editor.Text := FSource;
    Editor.SelectTextRange(Segment.StartOffset - 1, Segment.Length);
    Editor.ExecuteCommand(TEditorCommand.Bold);

    Assert.IsTrue(Editor.Text.Contains(Expected), Editor.Text);
  finally
    Editor.Free;
  end;
end;

// The same chain, but the result becomes the new source, so a second press
// works on what the first one left behind.
procedure TMarkdownPreviewFormattingTests.BoldThroughEditor(const Phrase: string);
begin
  SelectPhrase(Phrase);

  Assert.AreEqual(Phrase, FModel.SelectedText, 'The preview selection');

  var Segment: TMarkdownSegment;
  Assert.IsTrue(FModel.TryGetSelectionSourceSegment(Segment), 'No source range');

  const Editor = TMarkdownEditorModel.Create;
  try
    Editor.Text := FSource;
    Editor.SelectTextRange(Segment.StartOffset - 1, Segment.Length);
    Editor.ExecuteCommand(TEditorCommand.Bold);

    FSource := Editor.Text;
  finally
    Editor.Free;
  end;

  FModel.Text := FSource;
end;

// The case that still went wrong on screen: point at the back half of a bold
// word and the plain text after it. The range runs over the closing markers,
// so the bold that was there is taken in rather than cut through.
procedure TMarkdownPreviewFormattingTests.Bold_HalfOfABoldWordPlusThePlainTextAfterIt_BoldsTheWholeStretch;
begin
  LoadParagraph(WideViewport);

  BoldThroughEditor('LaTeX');
  Assert.IsTrue(FSource.Contains('written in **LaTeX** between'), FSource);

  BoldThroughEditor('TeX between');

  Assert.IsTrue(FSource.Contains('written in **LaTeX between** dollars'), FSource);
end;

procedure TMarkdownPreviewFormattingTests.Bold_PressedAgainOnTheSameWord_TakesTheBoldOffAgain;
begin
  LoadParagraph(WideViewport);
  const Original = FSource;

  BoldThroughEditor('LaTeX');
  Assert.IsTrue(FSource.Contains('written in **LaTeX** between'), FSource);

  BoldThroughEditor('LaTeX');

  Assert.AreEqual(Original, FSource);
end;

procedure TMarkdownPreviewFormattingTests.Bold_WordOnFirstSourceLine_WrapsThatWordOnly;
begin
  LoadParagraph(WideViewport);

  BoldPhrase('LaTeX');

  Assert.IsTrue(FSource.Contains('written in **LaTeX** between'), FSource);
end;

procedure TMarkdownPreviewFormattingTests.Bold_WordOnSecondSourceLine_WrapsThatWordOnly;
begin
  LoadParagraph(WideViewport);

  BoldPhrase('around');

  Assert.IsTrue(FSource.Contains('the text **around** it;'), FSource);
end;

procedure TMarkdownPreviewFormattingTests.Bold_PhraseOnSecondSourceLine_WrapsThatPhraseOnly;
begin
  LoadParagraph(WideViewport);

  BoldPhrase('line is');

  Assert.IsTrue(FSource.Contains('its own **line is** set in'), FSource);
end;

procedure TMarkdownPreviewFormattingTests.Bold_ThreeWordsInTurn_WrapsEachOfThem;
begin
  LoadParagraph(WideViewport);

  BoldPhrase('LaTeX');
  BoldPhrase('line is');
  BoldPhrase('around');

  Assert.IsTrue(FSource.Contains('written in **LaTeX** between'), FSource);
  Assert.IsTrue(FSource.Contains('its own **line is** set in'), FSource);
  Assert.IsTrue(FSource.Contains('the text **around** it;'), FSource);
end;

procedure TMarkdownPreviewFormattingTests.Bold_WordOnSecondSourceLine_WrapsThatWordOnlyWhenTextRewraps;
begin
  LoadParagraph(NarrowViewport);

  BoldPhrase('around');

  Assert.IsTrue(FSource.Contains('the text **around** it;'), FSource);
end;

// Pressing Bold a second time without pointing at anything new must not reach
// for the characters the first press moved.
procedure TMarkdownPreviewFormattingTests.SelectionSource_AfterTheTextChanged_ReturnsFalse;
begin
  LoadParagraph(WideViewport);

  BoldPhrase('around');

  var Segment: TMarkdownSegment;

  Assert.IsFalse(FModel.TryGetSelectionSourceSegment(Segment));
end;

procedure TMarkdownPreviewFormattingTests.SelectionSource_AfterTheTextChanged_DoesNotAnswerTheOldRange;
begin
  LoadParagraph(WideViewport);

  SelectPhrase('around');

  var Before: TMarkdownSegment;
  Assert.IsTrue(FModel.TryGetSelectionSourceSegment(Before));

  FSource := FSource.Replace('sentence at', 'one more sentence at', [rfReplaceAll]);
  FModel.Text := FSource;

  var After: TMarkdownSegment;
  const IsMapped = FModel.TryGetSelectionSourceSegment(After);

  Assert.IsFalse(IsMapped, Format('Answered %d..%d for a selection made on other text',
    [After.StartOffset, After.EndOffset]));
end;

// The word right after a hard line ending in the source: the preview renders
// the ending as a space, so the reader cannot see it is there.
procedure TMarkdownPreviewFormattingTests.Bold_WordAfterASoftLineBreak_WrapsThatWordOnly;
begin
  LoadParagraph(WideViewport);

  BoldPhrase('sentence');

  Assert.IsTrue(FSource.Contains(LineFeed + '**sentence** at'), FSource);
end;

end.
