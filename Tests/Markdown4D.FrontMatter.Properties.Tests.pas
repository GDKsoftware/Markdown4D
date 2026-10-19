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
    procedure TryParse_VariousInput_ReturnsExpected(const RawText: string; const Expected: Boolean);

    [Test]
    procedure TryParse_KeyAndValue_ReturnsOneRowWithValue;

    [Test]
    procedure TryParse_QuotedValue_StripsQuotes;

    [Test]
    procedure TryParse_FlowList_SplitsIntoTrimmedItems;

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

// A [TestCase] argument cannot carry a line break or a comma, so the cases
// write "\n" for a line feed and ";" for a comma.
class function TFrontMatterPropertiesTests.DecodeLineEndings(const Source: string): string;
begin
  const WithLineFeeds = Source.Replace('\n', LineFeed);

  Result := WithLineFeeds.Replace(';', ',');
end;

procedure TFrontMatterPropertiesTests.TryParse_VariousInput_ReturnsExpected(const RawText: string;
                                                                              const Expected: Boolean);
begin
  var Properties: TArray<TFrontMatterProperty>;

  const Actual = TFrontMatterProperties.TryParse(DecodeLineEndings(RawText), Properties);

  Assert.AreEqual(Expected, Actual);
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
