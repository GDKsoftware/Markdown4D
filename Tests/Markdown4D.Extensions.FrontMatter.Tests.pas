unit Markdown4D.Extensions.FrontMatter.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces;

type
  [TestFixture]
  TFrontMatterParserTests = class
  private
    const
      SampleDocument =
        '---'#10 +
        'type: project'#10 +
        'status: idea'#10 +
        'tags: [markdown, delphi]'#10 +
        '---'#10 +
        #10 +
        '# Title'#10;
      SampleRawText =
        'type: project'#10 +
        'status: idea'#10 +
        'tags: [markdown, delphi]';
      DashBlock = '---'#10'a: b'#10'---'#10;
    var
      FPipeline: IMarkdownPipeline;
    class function FirstKindOf(const Document: IMarkdownDocument): TMarkdownNodeKind;
    class function DecodeLineEndings(const Source: string): string;
    class function ContainsKind(const Node: IMarkdownNode; const Kind: TMarkdownNodeKind): Boolean;
    class procedure AssertSameTree(const Expected, Actual: IMarkdownNode);
    class function LiteralOf(const Node: IMarkdownNode): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Parse_ValidBlock_FirstChildIsFrontMatterWithRawText;

    [Test]
    [TestCase('Plain block', '---|a: b|---|,True')]
    [TestCase('Blank line before', '|---|a: b|---|,False')]
    [TestCase('Four dash opening fence', '----|a: b|---|,False')]
    [TestCase('Four dash closing fence', '---|a: b|----|,False')]
    [TestCase('Two dash opening fence', '--|a: b|---|,False')]
    [TestCase('No closing fence', '---|a: b|,False')]
    [TestCase('Indented opening fence', ' ---|a: b|---|,False')]
    [TestCase('Spaces after opening fence', '---  |a: b|---|,True')]
    [TestCase('Tab after opening fence', '---\t|a: b|---|,True')]
    [TestCase('Closing dots', '---|a: b|...|,True')]
    [TestCase('Trailing spaces after closing fence', '---|a: b|---   |,True')]
    [TestCase('Blank line inside', '---|a: b||c: d|---|,True')]
    [TestCase('Carriage return line feeds', '---\r|a: b\r|---\r|,True')]
    procedure Parse_VariousFences_ReturnsExpected(const Source: string; const Expected: Boolean);

    [Test]
    [TestCase('Block quote', '> ---|> a: b|> ---|')]
    [TestCase('List item', '* ---|  a: b|  ---|')]
    procedure Parse_BlockInsideContainer_IsNoFrontMatter(const Source: string);

    [Test]
    procedure Parse_NoClosingFence_SameTreeAsWithoutExtension;

    [Test]
    procedure Accept_FrontMatterNode_CallsVisitFrontMatter;

    [Test]
    procedure Parse_SecondDashBlockLater_IsNormalCommonMark;

    [Test]
    [TestCase('CommonMark', 'False')]
    [TestCase('GFM', 'True')]
    procedure Parse_WithoutExtension_SameAsBefore(const UseGfm: Boolean);

    [Test]
    procedure FrontMatterEnabled_On_GfmDialectRecognisesAndCommonMarkDialectDoesNot;

    [Test]
    procedure FrontMatterEnabled_Off_GfmDialectDoesNotRecognise;

    [Test]
    procedure ParseFragment_FrontMatterEnabled_NeverRecognises;

    [Test]
    procedure Parse_HeadingAfterFrontMatter_KeepsSourceLine;

    [Test]
    procedure Parse_ValidBlock_SegmentCoversBothFences;

    [Test]
    procedure ToHtml_SimpleProperties_WritesFrontMatterTable;

    [Test]
    procedure ToHtml_ListValue_WritesListItems;

    [Test]
    procedure ToHtml_NestedMap_WritesPreBlock;

    [Test]
    procedure ToMarkdown_FrontMatter_WritesFencesAndRawTextBack;

    [Test]
    procedure ToMarkdown_RoundTrip_KeepsRawText;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Pipeline,
  Markdown4D.Extensions.FrontMatter,
  Markdown4D.FrontMatter.RecordingVisitor;

procedure TFrontMatterParserTests.Setup;
begin
  FPipeline := TMarkdownPipeline.Create.UseGfm.Use(TFrontMatterExtension.Create).Build;
end;

procedure TFrontMatterParserTests.TearDown;
begin
  FPipeline := nil;
  TMarkdown.FrontMatterEnabled := False;
end;

class function TFrontMatterParserTests.FirstKindOf(const Document: IMarkdownDocument): TMarkdownNodeKind;
begin
  Assert.IsTrue(Document.ChildCount > 0, 'The document has no blocks');

  Result := Document.Children[0].Kind;
end;

// A [TestCase] argument cannot carry a line break, so the cases write "|" for
// a line feed, "\r" for a carriage return and "\t" for a tab.
class function TFrontMatterParserTests.DecodeLineEndings(const Source: string): string;
begin
  const WithLineFeeds = Source.Replace('|', LineFeed);
  const WithReturns = WithLineFeeds.Replace('\r', CarriageReturn);

  Result := WithReturns.Replace('\t', Tab);
end;

class function TFrontMatterParserTests.ContainsKind(const Node: IMarkdownNode; const Kind: TMarkdownNodeKind): Boolean;
begin
  if Node.Kind = Kind then
  begin
    Result := True;
    Exit;
  end;

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    if ContainsKind(Node.Children[Index], Kind) then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class procedure TFrontMatterParserTests.AssertSameTree(const Expected, Actual: IMarkdownNode);
begin
  Assert.AreEqual<TMarkdownNodeKind>(Expected.Kind, Actual.Kind);
  Assert.AreEqual(Expected.Segment.StartOffset, Actual.Segment.StartOffset);
  Assert.AreEqual(Expected.Segment.EndOffset, Actual.Segment.EndOffset);
  Assert.AreEqual(LiteralOf(Expected), LiteralOf(Actual));
  Assert.AreEqual(Expected.ChildCount, Actual.ChildCount);

  for var Index := 0 to Expected.ChildCount - 1 do
  begin
    AssertSameTree(Expected.Children[Index], Actual.Children[Index]);
  end;
end;

class function TFrontMatterParserTests.LiteralOf(const Node: IMarkdownNode): string;
begin
  Result := '';

  var Text: IMarkdownText;
  if Supports(Node, IMarkdownText, Text) then
    Result := Text.Literal;
end;

procedure TFrontMatterParserTests.Parse_ValidBlock_FirstChildIsFrontMatterWithRawText;
begin
  const Document = FPipeline.Parse(SampleDocument);

  Assert.AreEqual(2, Document.ChildCount);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.FrontMatter, Document.Children[0].Kind);
  const FrontMatter = Document.Children[0] as IMarkdownFrontMatter;
  Assert.AreEqual(SampleRawText, FrontMatter.RawText);

  const Heading = Document.Children[1];
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.Heading, Heading.Kind);
  Assert.AreEqual(1, (Heading as IMarkdownHeading).Level);
end;

procedure TFrontMatterParserTests.Parse_VariousFences_ReturnsExpected(const Source: string; const Expected: Boolean);
begin
  const Decoded = DecodeLineEndings(Source);
  const Document = FPipeline.Parse(Decoded);

  const Actual = (FirstKindOf(Document) = TMarkdownNodeKind.FrontMatter);

  Assert.AreEqual(Expected, Actual);
end;

procedure TFrontMatterParserTests.Parse_BlockInsideContainer_IsNoFrontMatter(const Source: string);
begin
  const Decoded = DecodeLineEndings(Source);
  const Document = FPipeline.Parse(Decoded);

  const HasFrontMatter = ContainsKind(Document, TMarkdownNodeKind.FrontMatter);

  Assert.IsFalse(HasFrontMatter);
end;

procedure TFrontMatterParserTests.Parse_NoClosingFence_SameTreeAsWithoutExtension;
begin
  const Source = '---'#10'a: b'#10#10'# Title'#10'Some *text* here'#10;
  const PlainPipeline = TMarkdownPipeline.Create.UseGfm.Build;

  const Expected = PlainPipeline.Parse(Source);
  const Actual = FPipeline.Parse(Source);

  AssertSameTree(Expected, Actual);
end;

procedure TFrontMatterParserTests.Accept_FrontMatterNode_CallsVisitFrontMatter;
begin
  const Document = FPipeline.Parse(SampleDocument);
  const Recorder = TFrontMatterRecordingVisitor.Create;
  const Visitor: IMarkdownVisitor = Recorder;

  Document.Children[0].Accept(Visitor);

  Assert.AreEqual(1, Recorder.VisitCount);
  Assert.AreEqual(SampleRawText, Recorder.VisitedRawText);
end;

procedure TFrontMatterParserTests.Parse_SecondDashBlockLater_IsNormalCommonMark;
begin
  const Document = FPipeline.Parse(DashBlock + #10'text'#10#10 + DashBlock);

  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.FrontMatter, Document.Children[0].Kind);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.Paragraph, Document.Children[1].Kind);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.ThematicBreak, Document.Children[2].Kind);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.Heading, Document.Children[3].Kind);
  Assert.AreEqual(4, Document.ChildCount);
end;

procedure TFrontMatterParserTests.Parse_WithoutExtension_SameAsBefore(const UseGfm: Boolean);
begin
  var Builder := TMarkdownPipeline.Create.UseCommonMark;
  if UseGfm then
    Builder := Builder.UseGfm;

  const Document = Builder.Build.Parse(DashBlock);

  Assert.AreEqual(2, Document.ChildCount);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.ThematicBreak, Document.Children[0].Kind);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.Heading, Document.Children[1].Kind);
end;

procedure TFrontMatterParserTests.FrontMatterEnabled_On_GfmDialectRecognisesAndCommonMarkDialectDoesNot;
begin
  TMarkdown.FrontMatterEnabled := True;

  const GfmDocument = TMarkdown.Parse(DashBlock, TMarkdownDialect.Gfm);
  const CommonMarkDocument = TMarkdown.Parse(DashBlock, TMarkdownDialect.CommonMark);

  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.FrontMatter, FirstKindOf(GfmDocument));
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.ThematicBreak, FirstKindOf(CommonMarkDocument));
end;

procedure TFrontMatterParserTests.FrontMatterEnabled_Off_GfmDialectDoesNotRecognise;
begin
  TMarkdown.FrontMatterEnabled := False;

  const Document = TMarkdown.Parse(DashBlock, TMarkdownDialect.Gfm);

  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.ThematicBreak, FirstKindOf(Document));
end;

procedure TFrontMatterParserTests.ParseFragment_FrontMatterEnabled_NeverRecognises;
begin
  TMarkdown.FrontMatterEnabled := True;

  const Document = TMarkdown.ParseFragment(DashBlock, TMarkdownDialect.Gfm);

  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.ThematicBreak, FirstKindOf(Document));
end;

procedure TFrontMatterParserTests.Parse_HeadingAfterFrontMatter_KeepsSourceLine;
begin
  const Document = FPipeline.Parse(SampleDocument);

  const Heading = Document.Children[1] as IMarkdownHeading;
  const HeadingStart = Pos('# Title', SampleDocument);

  Assert.AreEqual(7, Heading.SourceLine);
  Assert.AreEqual(HeadingStart, Heading.Segment.StartOffset);
end;

procedure TFrontMatterParserTests.Parse_ValidBlock_SegmentCoversBothFences;
begin
  const Document = FPipeline.Parse(SampleDocument);

  const Segment = Document.Children[0].Segment;
  const ClosingFenceEnd = Pos(#10'---'#10, SampleDocument) + Length(#10'---');

  Assert.AreEqual(1, Segment.StartOffset);
  Assert.AreEqual(ClosingFenceEnd, Segment.EndOffset);
end;

procedure TFrontMatterParserTests.ToHtml_SimpleProperties_WritesFrontMatterTable;
begin
  const Html = FPipeline.ToHtml('---'#10'type: project'#10'status: idea'#10'---'#10#10'# Title'#10);

  const Expected =
    '<table class="front-matter">'#10 +
    '<tbody>'#10 +
    '<tr>'#10'<th>type</th>'#10'<td>project</td>'#10'</tr>'#10 +
    '<tr>'#10'<th>status</th>'#10'<td>idea</td>'#10'</tr>'#10 +
    '</tbody>'#10 +
    '</table>'#10 +
    '<h1>Title</h1>'#10;

  Assert.AreEqual(Expected, Html);
end;

procedure TFrontMatterParserTests.ToHtml_ListValue_WritesListItems;
begin
  const Html = FPipeline.ToHtml('---'#10'tags: [markdown, "a<b"]'#10'---'#10);

  Assert.Contains(Html, '<th>tags</th>');
  Assert.Contains(Html, '<td><ul><li>markdown</li><li>a&lt;b</li></ul></td>');
end;

procedure TFrontMatterParserTests.ToHtml_NestedMap_WritesPreBlock;
begin
  const Html = FPipeline.ToHtml('---'#10'author:'#10'  name: <Jan>'#10'---'#10);

  const Expected =
    '<pre class="front-matter"><code class="language-yaml">author:'#10 +
    '  name: &lt;Jan&gt;</code></pre>'#10;

  Assert.AreEqual(Expected, Html);
end;

procedure TFrontMatterParserTests.ToMarkdown_FrontMatter_WritesFencesAndRawTextBack;
begin
  const Document = FPipeline.Parse('---'#10'a: b'#10#10'c: d'#10'...'#10'# Title'#10);

  const Markdown = TMarkdown.ToMarkdown(Document);

  Assert.AreEqual('---'#10'a: b'#10#10'c: d'#10'---'#10#10'# Title'#10, Markdown);
end;

procedure TFrontMatterParserTests.ToMarkdown_RoundTrip_KeepsRawText;
begin
  const Original = FPipeline.Parse(SampleDocument);

  const Markdown = TMarkdown.ToMarkdown(Original);
  const Restored = FPipeline.Parse(Markdown);

  const OriginalFrontMatter = Original.Children[0] as IMarkdownFrontMatter;
  const RestoredFrontMatter = Restored.Children[0] as IMarkdownFrontMatter;
  Assert.AreEqual(OriginalFrontMatter.RawText, RestoredFrontMatter.RawText);
  Assert.AreEqual(Original.ChildCount, Restored.ChildCount);
end;

end.
