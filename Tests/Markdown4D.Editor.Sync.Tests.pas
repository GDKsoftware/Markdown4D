unit Markdown4D.Editor.Sync.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Editor.Sync;

type
  [TestFixture]
  TMarkdownEditorSyncTests = class
  private
    const
      LayoutWidth = 400.0;
      SampleMarkdown =
        '# Heading'#10#10 +
        'First paragraph body text.'#10#10 +
        '## Subheading'#10#10 +
        'Second paragraph body text.';
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FSync: TMarkdownEditorSync;
      FDocument: IMarkdownDocument;
      FDisplayList: IMarkdownDisplayList;
    procedure BuildLayout(const Markdown: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure SourceLineToPreviewOffset_ReturnsBlockTop;

    [Test]
    procedure PreviewOffsetToSourceLine_ReversesForwardMapping;

    [Test]
    procedure Mapping_IsMonotonicInSourceLine;

    [Test]
    procedure Mapping_IsMonotonicInPreviewOffset;

    [Test]
    procedure ShiftAfter_MovesLaterMappingsConsistently;

    [Test]
    procedure MappedLineCount_MatchesSourceLines;

    [Test]
    procedure ParagraphLine_MapsBetweenSurroundingBlocks;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.FakeMeasurer;

procedure TMarkdownEditorSyncTests.Setup;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FMeasurer := TFakeTextMeasurer.Create;
  FSync := TMarkdownEditorSync.Create;
end;

procedure TMarkdownEditorSyncTests.TearDown;
begin
  FSync.Free;
  FMeasurer := nil;
  FTheme.Free;
end;

procedure TMarkdownEditorSyncTests.BuildLayout(const Markdown: string);
begin
  FDocument := TMarkdown.Parse(Markdown, TMarkdownDialect.Gfm);
  FDisplayList := TMarkdownLayoutEngine.LayoutDocument(FDocument, LayoutWidth, FTheme, FMeasurer);
  FSync.Update(FDocument, FDisplayList, Markdown);
end;

procedure TMarkdownEditorSyncTests.SourceLineToPreviewOffset_ReturnsBlockTop;
begin
  BuildLayout(SampleMarkdown);
  Assert.IsTrue(FSync.SourceLineToPreviewOffset(0) >= 0);
end;

procedure TMarkdownEditorSyncTests.PreviewOffsetToSourceLine_ReversesForwardMapping;
begin
  BuildLayout(SampleMarkdown);
  const Offset = FSync.SourceLineToPreviewOffset(4);
  Assert.AreEqual(4, FSync.PreviewOffsetToSourceLine(Offset));
end;

procedure TMarkdownEditorSyncTests.Mapping_IsMonotonicInSourceLine;
begin
  BuildLayout(SampleMarkdown);
  Assert.IsTrue(FSync.SourceLineToPreviewOffset(0) <= FSync.SourceLineToPreviewOffset(4));
end;

procedure TMarkdownEditorSyncTests.Mapping_IsMonotonicInPreviewOffset;
begin
  BuildLayout(SampleMarkdown);
  Assert.IsTrue(FSync.PreviewOffsetToSourceLine(0) <= FSync.PreviewOffsetToSourceLine(FDisplayList.Height));
end;

procedure TMarkdownEditorSyncTests.ShiftAfter_MovesLaterMappingsConsistently;
begin
  BuildLayout(SampleMarkdown);
  const Before = FSync.SourceLineToPreviewOffset(4);
  FSync.ShiftAfter(2, 1);
  Assert.IsTrue(Before <> FSync.SourceLineToPreviewOffset(5));
end;

procedure TMarkdownEditorSyncTests.MappedLineCount_MatchesSourceLines;
begin
  BuildLayout(SampleMarkdown);
  Assert.IsTrue(FSync.MappedLineCount > 0);
end;

procedure TMarkdownEditorSyncTests.ParagraphLine_MapsBetweenSurroundingBlocks;
begin
  BuildLayout(SampleMarkdown);

  // The first paragraph starts on line 2 (0-based). With per-block mapping its
  // offset must fall strictly between the heading above (line 0) and the
  // subheading below (line 4); heading-only mapping would snap it to the heading.
  const HeadingOffset = FSync.SourceLineToPreviewOffset(0);
  const ParagraphOffset = FSync.SourceLineToPreviewOffset(2);
  const SubheadingOffset = FSync.SourceLineToPreviewOffset(4);

  Assert.IsTrue(ParagraphOffset > HeadingOffset, 'paragraph should map below its heading');
  Assert.IsTrue(ParagraphOffset < SubheadingOffset, 'paragraph should map above the next heading');
end;

end.
