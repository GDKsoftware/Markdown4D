unit Markdown4D.Extensions.FrontMatter.Tests;

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces;

type
  [TestFixture]
  TFrontMatterTests = class
  private
    const
      SampleLiteral = 'type: project'#10'status: idea'#10'tags: [markdown, delphi]';
      SampleSource = '---'#10 + SampleLiteral + #10'---'#10#10'# Title';
      HeadingLine = '# Title';
      HeadingSourceLine = 7;
      LineSeparator = '~';
    class function ParseWithFrontMatter(const Source: string): IMarkdownDocument;
    class function HasFrontMatterChild(const Document: IMarkdownDocument): Boolean;
    class function FrontMatterChildCount(const Document: IMarkdownDocument): Integer;
    class function ToLines(const Source: string): string;

  public
    [Test]
    procedure Parse_ValidBlock_FirstChildIsFrontMatterWithRawLiteral;

    [Test]
    procedure Parse_ValidBlock_HeadingAfterBlockKeepsSegmentAndSourceLine;

    [Test]
    [TestCase('ClosingDots', '---~a: b~...~# Title')]
    [TestCase('BlankLineInside', '---~a: b~~c: d~---')]
    [TestCase('EmptyBlock', '---~---')]
    procedure Parse_ValidFences_IsFrontMatter(const Source: string);

    [Test]
    procedure Parse_TrailingSpacesOnFences_IsFrontMatter;

    [Test]
    [TestCase('FourDashOpening', '----~a: b~----')]
    [TestCase('FourDashClosing', '---~a: b~----')]
    [TestCase('TextAfterOpening', '--- a~a: b~---')]
    [TestCase('InsideBlockQuote', '> ---~> a: b~> ---')]
    [TestCase('InsideListItem', '- ---~  a: b~  ---')]
    procedure Parse_InvalidFences_IsNotFrontMatter(const Source: string);

    [Test]
    procedure Parse_IndentedOpening_IsNotFrontMatter;

    [Test]
    procedure Parse_BlankLineBeforeOpening_IsCommonMark;

    [Test]
    procedure Parse_NoClosingFence_IsCommonMark;

    [Test]
    procedure Parse_SecondBlockLater_OnlyFirstIsFrontMatter;

    [Test]
    procedure Parse_InsideBlockQuote_IsBlockQuote;

    [Test]
    procedure Parse_ExtensionOff_GfmAndCommonMarkUnchanged;

    [Test]
    procedure UseCommonMark_DoesNotRegisterFrontMatter;

    [Test]
    procedure CrLfSource_LiteralUsesLineFeedAndOffsetsMatch;

    [Test]
    procedure TryParse_KeyValuePairs_ReadsEveryPair;

    [Test]
    procedure TryParse_FlowList_ReadsSeparateItems;

    [Test]
    procedure TryParse_BlockList_ReadsSeparateItems;

    [Test]
    procedure TryParse_QuotedValue_DropsQuotes;

    [Test]
    procedure TryParse_EmptyValue_YieldsNoValues;

    [Test]
    procedure TryParse_BlankLineAndComment_AreSkipped;

    [Test]
    [TestCase('NestedMap', 'author:~  name: Jan')]
    [TestCase('MultilineScalar', 'description: |~  text')]
    [TestCase('FoldedScalar', 'description: >~  text')]
    [TestCase('FlowMap', 'author: {name: Jan}')]
    [TestCase('LineWithoutColon', 'just text')]
    [TestCase('ListItemWithoutKey', '- a')]
    [TestCase('ListItemAfterValue', 'tags: a~- b')]
    [TestCase('ListOfMaps', 'people:~  - name: Jan')]
    [TestCase('NoSpaceAfterColon', 'a:b')]
    [TestCase('Alias', 'ref: *b')]
    [TestCase('Anchor', 'base: &b x')]
    [TestCase('Tag', 'n: !!int 3')]
    [TestCase('InlineComment', 'status: idea # todo')]
    [TestCase('QuotedKey', '"my key": v')]
    [TestCase('SameQuoteInside', 'title: "a" and "b"')]
    [TestCase('NestedFlowListItem', 'tags:~- [a]')]
    [TestCase('CommaInsideQuotedItem', 'tags: [a, ''b, c'']', ';')]
    procedure TryParse_UnsupportedYaml_ReturnsFalse(const Raw: string);

    [Test]
    procedure ToHtml_SimpleProperties_RendersTableWithListItems;

    [Test]
    procedure ToHtml_NestedMap_RendersEscapedPre;

    [Test]
    procedure ToHtml_EscapesKeysAndValues;

    [Test]
    procedure ToMarkdown_WritesFencesVerbatim_RoundTripsToSameLiteral;

    [Test]
    procedure IncrementalParser_FrontMatterPipeline_LaterDashBlockIsNotFrontMatter;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Pipeline,
  Markdown4D.Parser.Incremental,
  Markdown4D.Extensions.FrontMatter;

class function TFrontMatterTests.ParseWithFrontMatter(const Source: string): IMarkdownDocument;
begin
  Result := TMarkdown.Parse(Source, TMarkdownDialect.Gfm, [TMarkdownParseOption.FrontMatter]);
end;

class function TFrontMatterTests.HasFrontMatterChild(const Document: IMarkdownDocument): Boolean;
begin
  Result := (FrontMatterChildCount(Document) > 0);
end;

class function TFrontMatterTests.FrontMatterChildCount(const Document: IMarkdownDocument): Integer;
begin
  Result := 0;

  for var Index := 0 to Document.ChildCount - 1 do
  begin
    const IsFrontMatter = (Document.Children[Index].Kind = TMarkdownNodeKind.FrontMatter);
    if IsFrontMatter then
      Inc(Result);
  end;
end;

class function TFrontMatterTests.ToLines(const Source: string): string;
begin
  Result := Source.Replace(LineSeparator, LineFeed);
end;

procedure TFrontMatterTests.Parse_ValidBlock_FirstChildIsFrontMatterWithRawLiteral;
begin
  const Document = ParseWithFrontMatter(SampleSource);

  Assert.AreEqual(2, Document.ChildCount);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.FrontMatter, Document.Children[0].Kind);

  const FrontMatter = Document.Children[0] as IMarkdownFrontMatter;
  Assert.AreEqual(SampleLiteral, FrontMatter.Literal);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.Heading, Document.Children[1].Kind);
end;

procedure TFrontMatterTests.Parse_ValidBlock_HeadingAfterBlockKeepsSegmentAndSourceLine;
begin
  const Document = ParseWithFrontMatter(SampleSource);

  const Heading = Document.Children[1] as IMarkdownHeading;
  const ExpectedStart = Pos(HeadingLine, SampleSource);

  Assert.AreEqual(ExpectedStart, Heading.Segment.StartOffset);
  Assert.AreEqual(ExpectedStart + Length(HeadingLine), Heading.Segment.EndOffset);
  Assert.AreEqual(HeadingSourceLine, Heading.SourceLine);
end;

procedure TFrontMatterTests.Parse_ValidFences_IsFrontMatter(const Source: string);
begin
  const Document = ParseWithFrontMatter(ToLines(Source));

  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.FrontMatter, Document.Children[0].Kind);
end;

procedure TFrontMatterTests.Parse_TrailingSpacesOnFences_IsFrontMatter;
begin
  const Source = '---  '#9#10'a: b'#10'--- '#10;

  const Document = ParseWithFrontMatter(Source);

  Assert.AreEqual(1, Document.ChildCount);
  Assert.AreEqual('a: b', (Document.Children[0] as IMarkdownFrontMatter).Literal);
end;

procedure TFrontMatterTests.Parse_InvalidFences_IsNotFrontMatter(const Source: string);
begin
  const Lines = ToLines(Source);

  const Document = ParseWithFrontMatter(Lines);

  Assert.IsFalse(HasFrontMatterChild(Document));
  Assert.AreEqual(TMarkdown.ToHtml(Lines, TMarkdownDialect.Gfm),
    TMarkdown.ToHtml(Lines, TMarkdownDialect.Gfm, [TMarkdownParseOption.FrontMatter]));
end;

procedure TFrontMatterTests.Parse_IndentedOpening_IsNotFrontMatter;
begin
  const Document = ParseWithFrontMatter(' ---'#10'a: b'#10'---');

  Assert.IsFalse(HasFrontMatterChild(Document));
end;

procedure TFrontMatterTests.Parse_BlankLineBeforeOpening_IsCommonMark;
begin
  const Document = ParseWithFrontMatter(LineFeed + SampleSource);

  Assert.IsFalse(HasFrontMatterChild(Document));
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.ThematicBreak, Document.Children[0].Kind);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.Heading, Document.Children[1].Kind);
  Assert.AreEqual(2, (Document.Children[1] as IMarkdownHeading).Level);
end;

procedure TFrontMatterTests.Parse_NoClosingFence_IsCommonMark;
begin
  const Source = '---'#10 + SampleLiteral + #10#10'# Title';

  const Document = ParseWithFrontMatter(Source);

  Assert.IsFalse(HasFrontMatterChild(Document));
  Assert.AreEqual(TMarkdown.ToHtml(Source, TMarkdownDialect.Gfm),
    TMarkdown.ToHtml(Source, TMarkdownDialect.Gfm, [TMarkdownParseOption.FrontMatter]));
end;

procedure TFrontMatterTests.Parse_SecondBlockLater_OnlyFirstIsFrontMatter;
begin
  const Source = SampleSource + #10#10'---'#10'a: b'#10'---';

  const Document = ParseWithFrontMatter(Source);

  Assert.AreEqual(1, FrontMatterChildCount(Document));
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.FrontMatter, Document.Children[0].Kind);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.ThematicBreak, Document.Children[2].Kind);
end;

procedure TFrontMatterTests.Parse_InsideBlockQuote_IsBlockQuote;
begin
  const Document = ParseWithFrontMatter('> ---'#10'> a: b'#10'> ---');

  Assert.AreEqual(1, Document.ChildCount);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.BlockQuote, Document.Children[0].Kind);
end;

procedure TFrontMatterTests.Parse_ExtensionOff_GfmAndCommonMarkUnchanged;
begin
  const GfmDocument = TMarkdown.Parse(SampleSource, TMarkdownDialect.Gfm);
  const CommonMarkDocument = TMarkdown.Parse(SampleSource, TMarkdownDialect.CommonMark);

  Assert.IsFalse(HasFrontMatterChild(GfmDocument));
  Assert.IsFalse(HasFrontMatterChild(CommonMarkDocument));
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.ThematicBreak, GfmDocument.Children[0].Kind);
end;

procedure TFrontMatterTests.UseCommonMark_DoesNotRegisterFrontMatter;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.UseGfm.Build;

  const Document = Pipeline.Parse(SampleSource);

  Assert.IsFalse(HasFrontMatterChild(Document));
end;

procedure TFrontMatterTests.CrLfSource_LiteralUsesLineFeedAndOffsetsMatch;
begin
  const Source = '---'#13#10'a: b'#13#10'c: d'#13#10'---'#13#10#13#10 + HeadingLine;

  const Document = ParseWithFrontMatter(Source);

  const FrontMatter = Document.Children[0] as IMarkdownFrontMatter;
  Assert.AreEqual('a: b'#10'c: d', FrontMatter.Literal);
  Assert.AreEqual(1, FrontMatter.Segment.StartOffset);

  const ClosingFenceEnd = Pos(#13#10#13#10, Source);
  Assert.AreEqual(ClosingFenceEnd, FrontMatter.Segment.EndOffset);

  const Heading = Document.Children[1] as IMarkdownHeading;
  Assert.AreEqual(Pos(HeadingLine, Source), Heading.Segment.StartOffset);
  Assert.AreEqual(6, Heading.SourceLine);
end;

procedure TFrontMatterTests.TryParse_KeyValuePairs_ReadsEveryPair;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const IsParsed = TFrontMatterProperties.TryParse('type: project'#10'status: idea', Properties);

  Assert.IsTrue(IsParsed);
  Assert.AreEqual(2, Integer(Length(Properties)));
  Assert.AreEqual('type', Properties[0].Key);
  Assert.AreEqual('project', Properties[0].Values[0]);
  Assert.IsFalse(Properties[0].IsList);
  Assert.AreEqual('status', Properties[1].Key);
  Assert.AreEqual('idea', Properties[1].Values[0]);
end;

procedure TFrontMatterTests.TryParse_FlowList_ReadsSeparateItems;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const IsParsed = TFrontMatterProperties.TryParse('tags: [markdown, "delphi"]', Properties);

  Assert.IsTrue(IsParsed);
  Assert.AreEqual(1, Integer(Length(Properties)));
  Assert.IsTrue(Properties[0].IsList);
  Assert.AreEqual(2, Integer(Length(Properties[0].Values)));
  Assert.AreEqual('markdown', Properties[0].Values[0]);
  Assert.AreEqual('delphi', Properties[0].Values[1]);
end;

procedure TFrontMatterTests.TryParse_BlockList_ReadsSeparateItems;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const IsParsed = TFrontMatterProperties.TryParse('tags:'#10'- markdown'#10'  - delphi'#10'type: note', Properties);

  Assert.IsTrue(IsParsed);
  Assert.AreEqual(2, Integer(Length(Properties)));
  Assert.IsTrue(Properties[0].IsList);
  Assert.AreEqual(2, Integer(Length(Properties[0].Values)));
  Assert.AreEqual('markdown', Properties[0].Values[0]);
  Assert.AreEqual('delphi', Properties[0].Values[1]);
  Assert.AreEqual('note', Properties[1].Values[0]);
end;

procedure TFrontMatterTests.TryParse_QuotedValue_DropsQuotes;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const IsParsed = TFrontMatterProperties.TryParse('title: "A: B"'#10'alias: ''x''', Properties);

  Assert.IsTrue(IsParsed);
  Assert.AreEqual('A: B', Properties[0].Values[0]);
  Assert.AreEqual('x', Properties[1].Values[0]);
end;

procedure TFrontMatterTests.TryParse_EmptyValue_YieldsNoValues;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const IsParsed = TFrontMatterProperties.TryParse('draft:'#10'type: note', Properties);

  Assert.IsTrue(IsParsed);
  Assert.AreEqual(2, Integer(Length(Properties)));
  Assert.AreEqual('draft', Properties[0].Key);
  Assert.AreEqual(0, Integer(Length(Properties[0].Values)));
  Assert.IsFalse(Properties[0].IsList);
end;

procedure TFrontMatterTests.TryParse_BlankLineAndComment_AreSkipped;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const IsParsed = TFrontMatterProperties.TryParse('a: b'#10#10'# note'#10'c: d', Properties);

  Assert.IsTrue(IsParsed);
  Assert.AreEqual(2, Integer(Length(Properties)));
  Assert.AreEqual('c', Properties[1].Key);
end;

procedure TFrontMatterTests.TryParse_UnsupportedYaml_ReturnsFalse(const Raw: string);
begin
  var Properties: TArray<TFrontMatterProperty>;

  const IsParsed = TFrontMatterProperties.TryParse(ToLines(Raw), Properties);

  Assert.IsFalse(IsParsed);
  Assert.AreEqual(0, Integer(Length(Properties)));
end;

procedure TFrontMatterTests.ToHtml_SimpleProperties_RendersTableWithListItems;
begin
  const Expected =
    '<table class="front-matter">'#10 +
    '<tbody>'#10 +
    '<tr>'#10'<th>type</th>'#10'<td>project</td>'#10'</tr>'#10 +
    '<tr>'#10'<th>status</th>'#10'<td>idea</td>'#10'</tr>'#10 +
    '<tr>'#10'<th>tags</th>'#10'<td><ul><li>markdown</li><li>delphi</li></ul></td>'#10'</tr>'#10 +
    '</tbody>'#10 +
    '</table>'#10 +
    '<h1>Title</h1>'#10;

  const Html = TMarkdown.ToHtml(SampleSource, TMarkdownDialect.Gfm, [TMarkdownParseOption.FrontMatter]);

  Assert.AreEqual(Expected, Html);
end;

procedure TFrontMatterTests.ToHtml_NestedMap_RendersEscapedPre;
begin
  const Source = '---'#10'author:'#10'  name: <Jan>'#10'---';

  const Html = TMarkdown.ToHtml(Source, TMarkdownDialect.Gfm, [TMarkdownParseOption.FrontMatter]);

  Assert.AreEqual('<pre class="front-matter"><code class="language-yaml">author:'#10 +
    '  name: &lt;Jan&gt;</code></pre>'#10, Html);
end;

procedure TFrontMatterTests.ToHtml_EscapesKeysAndValues;
begin
  const Source = '---'#10'a<b: x & y'#10'tags: [<i>]'#10'---';

  const Html = TMarkdown.ToHtml(Source, TMarkdownDialect.Gfm, [TMarkdownParseOption.FrontMatter]);

  Assert.Contains(Html, '<th>a&lt;b</th>');
  Assert.Contains(Html, '<td>x &amp; y</td>');
  Assert.Contains(Html, '<li>&lt;i&gt;</li>');
  Assert.DoesNotContain(Html, '<i>');
end;

procedure TFrontMatterTests.ToMarkdown_WritesFencesVerbatim_RoundTripsToSameLiteral;
begin
  const Source = '---'#10'a: b'#10#10'tags:'#10'  - x'#10'---'#10#10'# Title';

  const Markdown = TMarkdown.ToMarkdown(ParseWithFrontMatter(Source));

  Assert.IsTrue(Markdown.StartsWith('---'#10'a: b'#10#10'tags:'#10'  - x'#10'---'#10#10'# Title'), Markdown);

  const Reparsed = ParseWithFrontMatter(Markdown);
  Assert.AreEqual('a: b'#10#10'tags:'#10'  - x', (Reparsed.Children[0] as IMarkdownFrontMatter).Literal);
end;

procedure TFrontMatterTests.IncrementalParser_FrontMatterPipeline_LaterDashBlockIsNotFrontMatter;
begin
  const Source = SampleSource + #10#10'---'#10'a: b'#10'---'#10;
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.Use(TFrontMatterExtension.Create).Build;
  const Parser = TMarkdownIncrementalParser.CreateParser(Pipeline);

  Parser.Append(Source);

  const Html = Parser.ToHtml;
  Assert.DoesNotContain(Html, 'front-matter');
  Assert.AreEqual(TMarkdown.ToHtml(Source, TMarkdownDialect.CommonMark), Html);
end;

end.
