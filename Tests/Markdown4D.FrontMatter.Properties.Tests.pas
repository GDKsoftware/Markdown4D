unit Markdown4D.FrontMatter.Properties.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TFrontMatterPropertiesTests = class
  private
    class function DecodeLineEndings(const Source: string): string;

  public
    [Test]
    [TestCase('Key and value', 'type: project,True')]
    [TestCase('Double quoted value', 'title: "Hello: world",True')]
    [TestCase('Single quoted value', 'title: ''x'',True')]
    [TestCase('Flow list', 'tags: [a; b],True')]
    [TestCase('Block list', 'tags:\n- a\n- b,True')]
    [TestCase('Indented block list', 'tags:\n  - a\n  - b,True')]
    [TestCase('Empty value', 'draft:,True')]
    [TestCase('Comment and blank lines', '# note\n\ntype: project\n\nstatus: idea,True')]
    [TestCase('Colon inside a word', 'url: http://example.com,True')]
    [TestCase('Nested map', 'author:\n  name: Jan,False')]
    [TestCase('Literal block scalar', 'text: |,False')]
    [TestCase('Folded block scalar', 'text: >,False')]
    [TestCase('Line without colon', 'just text,False')]
    [TestCase('Flow map', 'author: {name: Jan},False')]
    [TestCase('Unclosed flow list', 'tags: [a; b,False')]
    [TestCase('List item without key', '- a,False')]
    [TestCase('List item after scalar value', 'type: project\n- a,False')]
    [TestCase('Only comments', '# note,False')]
    [TestCase('Quoted flow items with commas', 'tags: ["a; b"; c],True')]
    [TestCase('Apostrophe inside plain flow item', 'tags: [it''s; b],True')]
    [TestCase('Comment after flow list', 'tags: [a; b] # note,True')]
    [TestCase('Comment after a tab', 'status: idea\t# later,True')]
    [TestCase('Comment instead of value', 'draft: # later,True')]
    [TestCase('Escaped single quote', 'title: ''it''''s'',True')]
    [TestCase('Unclosed quote in flow list', 'tags: ["a; b],False')]
    [TestCase('Text after flow list', 'tags: [a; b] c,False')]
    [TestCase('Two quoted pieces', 'title: "a" "b",False')]
    [TestCase('Quoted piece with text after it', 'title: "a" b,False')]
    [TestCase('Unclosed quoted value', 'title: "abc,False')]
    [TestCase('Escaped closing quote only', 'title: "abc\",False')]
    [TestCase('Unclosed quoted list item', 'tags:\n- ''a,False')]
    [TestCase('Colon and space in plain value', 'title: Foo: bar,False')]
    [TestCase('Trailing colon in plain value', 'title: Foo:,False')]
    [TestCase('Nested flow list', 'tags: [a; [b]],False')]
    [TestCase('Quoted key with colon and space', '"a: b": c,False')]
    [TestCase('Nested list in a value', 'key: - a,False')]
    [TestCase('Nested list as list item', 'tags:\n- - a,False')]
    [TestCase('Anchor value', 'key: &anchor a,False')]
    [TestCase('Alias value', 'key: *alias,False')]
    [TestCase('Tag value', 'key: !tag a,False')]
    procedure TryParse_VariousInput_ReturnsExpected(const RawText: string; const Expected: Boolean);

    [Test]
    [TestCase('Trailing comment', 'title: a #note,a')]
    [TestCase('Hash inside word', 'title: c#d,c#d')]
    [TestCase('Dash without space', 'n: -5,-5')]
    procedure TryParse_PlainValue_ReturnsValue(const RawText: string; const Expected: string);

    [Test]
    procedure TryParse_KeyAndValue_ReturnsOneRowWithValue;

    [Test]
    procedure TryParse_QuotedValue_StripsQuotes;

    [Test]
    procedure TryParse_FlowList_SplitsIntoTrimmedItems;

    [Test]
    procedure TryParse_QuotedFlowItems_SplitsOnlyOutsideQuotes;

    [Test]
    procedure TryParse_CommentAfterTab_StripsComment;

    [Test]
    procedure TryParse_EscapedQuotes_AreResolved;

    [Test]
    procedure TryParse_BlockList_CollectsItemsUnderKey;

    [Test]
    procedure TryParse_EmptyValue_ReturnsEmptyRow;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Defines,
  Markdown4D.FrontMatter.Properties;

// A [TestCase] argument cannot carry a line break, a tab or a comma, so the
// cases write "\n" for a line feed, "\t" for a tab and ";" for a comma.
class function TFrontMatterPropertiesTests.DecodeLineEndings(const Source: string): string;
begin
  const WithLineFeeds = Source.Replace('\n', LineFeed);
  const WithTabs = WithLineFeeds.Replace('\t', Tab);

  Result := WithTabs.Replace(';', ',');
end;

procedure TFrontMatterPropertiesTests.TryParse_VariousInput_ReturnsExpected(const RawText: string;
                                                                              const Expected: Boolean);
begin
  var Properties: TArray<TFrontMatterProperty>;

  const Decoded = DecodeLineEndings(RawText);

  const Actual = TFrontMatterProperties.TryParse(Decoded, Properties);

  Assert.AreEqual(Expected, Actual);
end;

procedure TFrontMatterPropertiesTests.TryParse_PlainValue_ReturnsValue(const RawText: string;
                                                                       const Expected: string);
begin
  var Properties: TArray<TFrontMatterProperty>;

  const Parsed = TFrontMatterProperties.TryParse(RawText, Properties);

  Assert.IsTrue(Parsed);
  Assert.AreEqual(Expected, Properties[0].Values[0]);
end;

procedure TFrontMatterPropertiesTests.TryParse_KeyAndValue_ReturnsOneRowWithValue;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const Parsed = TFrontMatterProperties.TryParse('type: project'#10'status: idea # later', Properties);

  Assert.IsTrue(Parsed);
  Assert.AreEqual(2, Integer(Length(Properties)));
  Assert.AreEqual('type', Properties[0].Key);
  Assert.AreEqual('project', Properties[0].Values[0]);
  Assert.IsFalse(Properties[0].IsList);
  Assert.AreEqual('idea', Properties[1].Values[0]);
end;

procedure TFrontMatterPropertiesTests.TryParse_QuotedValue_StripsQuotes;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const Parsed = TFrontMatterProperties.TryParse('title: "Hello: world"', Properties);

  Assert.IsTrue(Parsed);
  Assert.AreEqual('Hello: world', Properties[0].Values[0]);
end;

procedure TFrontMatterPropertiesTests.TryParse_FlowList_SplitsIntoTrimmedItems;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const Parsed = TFrontMatterProperties.TryParse('tags: [ markdown ,delphi, ''yaml'' ]', Properties);

  Assert.IsTrue(Parsed);
  Assert.IsTrue(Properties[0].IsList);
  Assert.AreEqual(3, Integer(Length(Properties[0].Values)));
  Assert.AreEqual('markdown', Properties[0].Values[0]);
  Assert.AreEqual('delphi', Properties[0].Values[1]);
  Assert.AreEqual('yaml', Properties[0].Values[2]);
end;

procedure TFrontMatterPropertiesTests.TryParse_QuotedFlowItems_SplitsOnlyOutsideQuotes;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const Parsed = TFrontMatterProperties.TryParse('tags: ["a, b", c, ''x, y'']', Properties);

  Assert.IsTrue(Parsed);
  Assert.AreEqual(3, Integer(Length(Properties[0].Values)));
  Assert.AreEqual('a, b', Properties[0].Values[0]);
  Assert.AreEqual('c', Properties[0].Values[1]);
  Assert.AreEqual('x, y', Properties[0].Values[2]);
end;

procedure TFrontMatterPropertiesTests.TryParse_CommentAfterTab_StripsComment;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const Parsed = TFrontMatterProperties.TryParse('status: idea'#9'# later', Properties);

  Assert.IsTrue(Parsed);
  Assert.AreEqual('idea', Properties[0].Values[0]);
end;

procedure TFrontMatterPropertiesTests.TryParse_EscapedQuotes_AreResolved;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const Parsed = TFrontMatterProperties.TryParse('single: ''it''''s'''#10'double: "say \"hi\""', Properties);

  Assert.IsTrue(Parsed);
  Assert.AreEqual('it''s', Properties[0].Values[0]);
  Assert.AreEqual('say "hi"', Properties[1].Values[0]);
end;

procedure TFrontMatterPropertiesTests.TryParse_BlockList_CollectsItemsUnderKey;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const Parsed = TFrontMatterProperties.TryParse('tags:'#10'- markdown'#10'  - delphi'#10'type: project', Properties);

  Assert.IsTrue(Parsed);
  Assert.AreEqual(2, Integer(Length(Properties)));
  Assert.AreEqual('tags', Properties[0].Key);
  Assert.IsTrue(Properties[0].IsList);
  Assert.AreEqual(2, Integer(Length(Properties[0].Values)));
  Assert.AreEqual('markdown', Properties[0].Values[0]);
  Assert.AreEqual('delphi', Properties[0].Values[1]);
  Assert.AreEqual('type', Properties[1].Key);
end;

procedure TFrontMatterPropertiesTests.TryParse_EmptyValue_ReturnsEmptyRow;
begin
  var Properties: TArray<TFrontMatterProperty>;

  const Parsed = TFrontMatterProperties.TryParse('draft:', Properties);

  Assert.IsTrue(Parsed);
  Assert.AreEqual('draft', Properties[0].Key);
  Assert.AreEqual(0, Integer(Length(Properties[0].Values)));
  Assert.IsFalse(Properties[0].IsList);
end;

end.
