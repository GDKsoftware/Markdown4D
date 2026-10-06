unit Markdown4D.Layout.SelectedMarkdown.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.SelectedMarkdown;

type
  [TestFixture]
  TMarkdownSelectedSourceTests = class
  private
    class function ExtractSelecting(const Source, Selected: string): string; static;
    class function Lines(const Values: array of string): string; static;

  public
    [Test]
    procedure Extract_PlainWords_CopiesThemExactly;

    [Test]
    [TestCase('Strong', 'A **bold** word|bold|**bold**', '|')]
    [TestCase('Emphasis', 'An *italic* word|italic|*italic*', '|')]
    [TestCase('Strikethrough', 'A ~~gone~~ word|gone|~~gone~~', '|')]
    [TestCase('Link', 'See [the docs](docs.md) now|the docs|[the docs](docs.md)', '|')]
    [TestCase('StrongLink', 'See **[docs](d.md)** now|docs|**[docs](d.md)**', '|')]
    procedure Extract_WordInsideMarkup_TakesTheMarkupAlong(const Source, Selected, Expected: string);

    [Test]
    procedure Extract_PartOfAWordInsideMarkup_CopiesOnlyThatPart;

    [Test]
    procedure Extract_AcrossListItems_CopiesWholeLines;

    [Test]
    procedure Extract_InsideATable_CopiesTheWholeTable;

    [Test]
    procedure WithPlatformLineBreaks_LineFeeds_BecomePlatformLineBreaks;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces;

procedure TMarkdownSelectedSourceTests.Extract_PlainWords_CopiesThemExactly;
begin
  const Actual = ExtractSelecting('alpha beta gamma', 'beta');

  Assert.AreEqual('beta', Actual);
end;

procedure TMarkdownSelectedSourceTests.Extract_WordInsideMarkup_TakesTheMarkupAlong(const Source, Selected,
  Expected: string);
begin
  const Actual = ExtractSelecting(Source, Selected);

  Assert.AreEqual(Expected, Actual);
end;

procedure TMarkdownSelectedSourceTests.Extract_PartOfAWordInsideMarkup_CopiesOnlyThatPart;
begin
  const Actual = ExtractSelecting('A **bold** word', 'bol');

  Assert.AreEqual('bol', Actual);
end;

procedure TMarkdownSelectedSourceTests.Extract_AcrossListItems_CopiesWholeLines;
begin
  const Source = Lines(['- one', '- two', '- three']);

  const Actual = ExtractSelecting(Source, 'ne'#10'- tw');

  Assert.AreEqual(Lines(['- one', '- two']).Replace(#10, sLineBreak), Actual);
end;

procedure TMarkdownSelectedSourceTests.Extract_InsideATable_CopiesTheWholeTable;
begin
  const Table = Lines(['| a | b |', '| - | - |', '| c | d |']);
  const Source = 'Before'#10#10 + Table + #10#10'After';

  const Actual = ExtractSelecting(Source, 'c');

  Assert.AreEqual(Table.Replace(#10, sLineBreak), Actual);
end;

procedure TMarkdownSelectedSourceTests.WithPlatformLineBreaks_LineFeeds_BecomePlatformLineBreaks;
begin
  const Actual = TMarkdownSelectedSource.WithPlatformLineBreaks('one'#10'two'#13#10'three');

  Assert.AreEqual('one' + sLineBreak + 'two' + sLineBreak + 'three', Actual);
end;

// Selects the first occurrence of Selected in Source, as a selection in the
// viewer maps back to the source.
class function TMarkdownSelectedSourceTests.ExtractSelecting(const Source, Selected: string): string;
begin
  const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
  const Start = Pos(Selected, Source);
  Assert.IsTrue(Start > 0, Format('"%s" does not occur in the source', [Selected]));

  const Selection = TMarkdownSegment.Create(Start, Start + Length(Selected));
  Result := TMarkdownSelectedSource.Extract(Source, Document, Selection);
end;

class function TMarkdownSelectedSourceTests.Lines(const Values: array of string): string;
begin
  Result := string.Join(#10, Values);
end;

end.
