unit Markdown4D.Parser.InlineSegments.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces;

type
  [TestFixture]
  TInlineSegmentTests = class
  private
    class function FirstTextNode(const Source: string): IMarkdownNode;
    class function SourceOf(const Source: string; const Node: IMarkdownNode): string;

  public
    [Test]
    procedure Segment_PlainParagraph_PointsAtTheSourceCharacters;

    [Test]
    procedure Segment_TextAfterEmphasis_SkipsTheMarkers;

    [Test]
    procedure Segment_BlockQuote_SkipsTheStrippedMarker;

    [Test]
    procedure Segment_IndentedListItem_SkipsTheBullet;

    [Test]
    procedure Segment_AtxHeading_SkipsTheHashesAndTheSpace;
  end;

implementation

uses
  Markdown4D;

class function TInlineSegmentTests.FirstTextNode(const Source: string): IMarkdownNode;

  function Search(const Node: IMarkdownNode): IMarkdownNode;
  begin
    if Node.Kind = TMarkdownNodeKind.Text then
      Exit(Node);

    for var Index := 0 to Node.ChildCount - 1 do
    begin
      Result := Search(Node.Children[Index]);
      if Result <> nil then
        Exit;
    end;

    Result := nil;
  end;

begin
  Result := Search(TMarkdown.Parse(Source));
end;

class function TInlineSegmentTests.SourceOf(const Source: string; const Node: IMarkdownNode): string;
begin
  const Segment = Node.Segment;
  Result := Copy(Source, Segment.StartOffset, Segment.Length);
end;

procedure TInlineSegmentTests.Segment_PlainParagraph_PointsAtTheSourceCharacters;
begin
  const Source = 'Hello world';

  const Node = FirstTextNode(Source);

  Assert.IsNotNull(Node, 'expected a text node');
  Assert.AreEqual('Hello world', SourceOf(Source, Node));
end;

procedure TInlineSegmentTests.Segment_TextAfterEmphasis_SkipsTheMarkers;
begin
  // The asterisks never reach the rendered text, so the segment of the word
  // inside them has to point past them in the source.
  const Source = 'a **bold** word';

  const Node = FirstTextNode(Source);

  Assert.AreEqual('a ', SourceOf(Source, Node));
end;

procedure TInlineSegmentTests.Segment_BlockQuote_SkipsTheStrippedMarker;
begin
  // '> ' is removed before the inline parser sees the content, so the segment
  // must account for characters that are in the source but not in the content.
  const Source = '> quoted text';

  const Node = FirstTextNode(Source);

  Assert.AreEqual('quoted text', SourceOf(Source, Node));
end;

procedure TInlineSegmentTests.Segment_IndentedListItem_SkipsTheBullet;
begin
  const Source = '- item one';

  const Node = FirstTextNode(Source);

  Assert.AreEqual('item one', SourceOf(Source, Node));
end;

procedure TInlineSegmentTests.Segment_AtxHeading_SkipsTheHashesAndTheSpace;
begin
  const Source = '## Some heading';

  const Node = FirstTextNode(Source);

  Assert.AreEqual('Some heading', SourceOf(Source, Node));
end;

end.
