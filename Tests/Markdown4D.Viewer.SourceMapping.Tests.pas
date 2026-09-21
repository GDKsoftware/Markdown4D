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

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D,
  Markdown4D.Defines,
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

end.
