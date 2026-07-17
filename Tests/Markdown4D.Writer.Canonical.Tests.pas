unit Markdown4D.Writer.Canonical.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownWriterCanonicalTests = class
  private
    class function CanonicalMarkdown(const Source: string): string;

  public
    [Test]
    procedure ToMarkdown_SetextHeadings_WriteAtxHeadings;

    [Test]
    procedure ToMarkdown_AtxHeadingWithClosingSequence_WritesHeadingWithoutClosingSequence;

    [Test]
    procedure ToMarkdown_TwoSpaceHardBreak_WritesBackslashHardBreak;

    [Test]
    procedure ToMarkdown_IndentedCodeBlock_WritesBacktickFence;

    [Test]
    procedure ToMarkdown_CodeBlockContainingTripleBacktickRun_WritesFourBacktickFence;

    [Test]
    procedure ToMarkdown_FencedCodeWithInfoString_KeepsInfoStringOnOpeningFence;

    [Test]
    procedure ToMarkdown_BulletListWithStarMarkers_WritesHyphenMarkers;

    [Test]
    procedure ToMarkdown_BulletListWithPlusMarkers_WritesHyphenMarkers;

    [Test]
    procedure ToMarkdown_OrderedListWithParenthesisMarkers_WritesDotMarkersFromStartNumber;

    [Test]
    procedure ToMarkdown_ReferenceLink_WritesInlineLink;

    [Test]
    procedure ToMarkdown_ReferenceImage_WritesInlineImage;

    [Test]
    procedure ToMarkdown_ExcessBlankLines_WritesSingleBlankLineBetweenBlocksWithoutTrailingBlanks;

    [Test]
    procedure ToMarkdown_AdjacentBlocks_SeparatesWithSingleBlankLine;

    [Test]
    procedure ToMarkdown_EmptyDocument_WritesEmptyString;
  end;

implementation

uses
  Markdown4D;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_SetextHeadings_WriteAtxHeadings;
begin
  const Canonical = CanonicalMarkdown('Title'#10'====='#10#10'Sub'#10'---'#10);

  Assert.AreEqual('# Title'#10#10'## Sub'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_AtxHeadingWithClosingSequence_WritesHeadingWithoutClosingSequence;
begin
  const Canonical = CanonicalMarkdown('## Two ##'#10);

  Assert.AreEqual('## Two'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_TwoSpaceHardBreak_WritesBackslashHardBreak;
begin
  const Canonical = CanonicalMarkdown('one  '#10'two'#10);

  Assert.AreEqual('one\'#10'two'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_IndentedCodeBlock_WritesBacktickFence;
begin
  const Canonical = CanonicalMarkdown('    code'#10);

  Assert.AreEqual('```'#10'code'#10'```'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_CodeBlockContainingTripleBacktickRun_WritesFourBacktickFence;
begin
  const Canonical = CanonicalMarkdown('~~~'#10'```'#10'~~~'#10);

  Assert.AreEqual('````'#10'```'#10'````'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_FencedCodeWithInfoString_KeepsInfoStringOnOpeningFence;
begin
  const Canonical = CanonicalMarkdown('```pascal'#10'writeln;'#10'```'#10);

  Assert.AreEqual('```pascal'#10'writeln;'#10'```'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_BulletListWithStarMarkers_WritesHyphenMarkers;
begin
  const Canonical = CanonicalMarkdown('* one'#10'* two'#10);

  Assert.AreEqual('- one'#10'- two'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_BulletListWithPlusMarkers_WritesHyphenMarkers;
begin
  const Canonical = CanonicalMarkdown('+ one'#10'+ two'#10);

  Assert.AreEqual('- one'#10'- two'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_OrderedListWithParenthesisMarkers_WritesDotMarkersFromStartNumber;
begin
  const Canonical = CanonicalMarkdown('3) three'#10'4) four'#10);

  Assert.AreEqual('3. three'#10'4. four'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_ReferenceLink_WritesInlineLink;
begin
  const Canonical = CanonicalMarkdown('[foo]'#10#10'[foo]: /url "title"'#10);

  Assert.AreEqual('[foo](/url "title")'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_ReferenceImage_WritesInlineImage;
begin
  const Canonical = CanonicalMarkdown('![bar]'#10#10'[bar]: /img.png'#10);

  Assert.AreEqual('![bar](/img.png)'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_ExcessBlankLines_WritesSingleBlankLineBetweenBlocksWithoutTrailingBlanks;
begin
  const Canonical = CanonicalMarkdown('# A'#10#10#10#10'first'#10#10#10'second'#10#10#10);

  Assert.AreEqual('# A'#10#10'first'#10#10'second'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_AdjacentBlocks_SeparatesWithSingleBlankLine;
begin
  const Canonical = CanonicalMarkdown('# A'#10'first'#10);

  Assert.AreEqual('# A'#10#10'first'#10, Canonical);
end;

procedure TMarkdownWriterCanonicalTests.ToMarkdown_EmptyDocument_WritesEmptyString;
begin
  const Canonical = CanonicalMarkdown('');

  Assert.AreEqual('', Canonical);
end;

class function TMarkdownWriterCanonicalTests.CanonicalMarkdown(const Source: string): string;
begin
  const Document = TMarkdown.Parse(Source);

  Result := TMarkdown.ToMarkdown(Document);
end;

end.
