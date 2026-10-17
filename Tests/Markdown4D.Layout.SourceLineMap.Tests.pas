unit Markdown4D.Layout.SourceLineMap.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Layout.SourceLineMap;

type
  [TestFixture]
  TMarkdownSourceLineMapTests = class
  private
    const
      LayoutWidth = 400.0;
      NarrowWidth = 200.0;
      SingleTolerance = 0.05;
      SampleMarkdown =
        '# Heading'#10#10 +
        'First paragraph body text.'#10#10 +
        '## Subheading'#10#10 +
        'Second paragraph body text.';
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FMap: TMarkdownSourceLineMap;
      FDisplayList: IMarkdownDisplayList;
    procedure BuildMap(const Markdown: string; const Width: Single = LayoutWidth);
    function TopOfRunContaining(const Text: string): Single;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure OffsetToSourceLine_OffsetOfALine_GivesThatLineBack;

    [Test]
    procedure SourceLineToOffset_LaterLine_IsNotHigher;

    [Test]
    procedure OffsetToSourceLine_LowerOffset_IsNotAnEarlierLine;

    [Test]
    procedure SourceLineToOffset_ParagraphLine_FallsBetweenSurroundingHeadings;

    [Test]
    procedure SourceLineToOffset_ItemAfterWrappedItem_IsTopOfThatItem;

    [Test]
    procedure SourceLineToOffset_LineInLongCodeBlock_IsTopOfThatLine;

    [Test]
    procedure SourceLineToOffset_ParagraphAfterHtmlBlock_IsTopOfThatParagraph;

    [Test]
    procedure OffsetToSourceLine_LowInsideAnImage_GivesTheLineOfThatImage;

    [Test]
    procedure Build_WithoutDisplayList_MapsEveryLineToTheTop;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.FakeMeasurer;

procedure TMarkdownSourceLineMapTests.Setup;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FMeasurer := TFakeTextMeasurer.Create;
  FMap := TMarkdownSourceLineMap.Create;
end;

procedure TMarkdownSourceLineMapTests.TearDown;
begin
  FMap.Free;
  FDisplayList := nil;
  FMeasurer := nil;
  FTheme.Free;
end;

procedure TMarkdownSourceLineMapTests.OffsetToSourceLine_OffsetOfALine_GivesThatLineBack;
begin
  BuildMap(SampleMarkdown);

  const Offset = FMap.SourceLineToOffset(4);

  Assert.AreEqual(4, FMap.OffsetToSourceLine(Offset));
end;

procedure TMarkdownSourceLineMapTests.SourceLineToOffset_LaterLine_IsNotHigher;
begin
  BuildMap(SampleMarkdown);

  for var Line := 1 to 7 do
  begin
    const IsInOrder = (FMap.SourceLineToOffset(Line - 1) <= FMap.SourceLineToOffset(Line));
    Assert.IsTrue(IsInOrder, Format('line %d maps above line %d', [Line, Line - 1]));
  end;
end;

procedure TMarkdownSourceLineMapTests.OffsetToSourceLine_LowerOffset_IsNotAnEarlierLine;
begin
  BuildMap(SampleMarkdown);

  const TopLine = FMap.OffsetToSourceLine(0);
  const BottomLine = FMap.OffsetToSourceLine(FDisplayList.Height);

  Assert.IsTrue(TopLine <= BottomLine);
end;

procedure TMarkdownSourceLineMapTests.SourceLineToOffset_ParagraphLine_FallsBetweenSurroundingHeadings;
begin
  BuildMap(SampleMarkdown);

  const HeadingOffset = FMap.SourceLineToOffset(0);
  const ParagraphOffset = FMap.SourceLineToOffset(2);
  const SubheadingOffset = FMap.SourceLineToOffset(4);

  Assert.IsTrue(ParagraphOffset > HeadingOffset, 'paragraph should map below its heading');
  Assert.IsTrue(ParagraphOffset < SubheadingOffset, 'paragraph should map above the next heading');
end;

procedure TMarkdownSourceLineMapTests.SourceLineToOffset_ItemAfterWrappedItem_IsTopOfThatItem;
begin
  BuildMap(
    '- zero has enough words to wrap over several lines at this narrow width'#10 +
    '- one'#10 +
    '- two'#10 +
    '- three'#10 +
    '- four'#10 +
    '- five'#10 +
    '- six', NarrowWidth);

  Assert.AreEqual(TopOfRunContaining('five'), FMap.SourceLineToOffset(5), SingleTolerance);
end;

procedure TMarkdownSourceLineMapTests.SourceLineToOffset_LineInLongCodeBlock_IsTopOfThatLine;
begin
  var Code := '';
  for var Index := 0 to 19 do
  begin
    Code := Code + Format('code%.2d', [Index]) + #10;
  end;

  BuildMap('# Code'#10#10'```'#10 + Code + '```'#10#10'After');

  Assert.AreEqual(TopOfRunContaining('code07'), FMap.SourceLineToOffset(10), SingleTolerance);
end;

procedure TMarkdownSourceLineMapTests.SourceLineToOffset_ParagraphAfterHtmlBlock_IsTopOfThatParagraph;
begin
  BuildMap(
    '# Top'#10#10 +
    '<div>'#10 +
    '<p>alpha beta gamma delta epsilon zeta eta theta iota kappa lambda</p>'#10 +
    '</div>'#10#10 +
    'After the block');

  Assert.AreEqual(TopOfRunContaining('After'), FMap.SourceLineToOffset(6), SingleTolerance);
end;

procedure TMarkdownSourceLineMapTests.OffsetToSourceLine_LowInsideAnImage_GivesTheLineOfThatImage;
begin
  BuildMap('- one'#10'- two ![picture](picture.png)'#10'- three');

  const ImageLineTop = TopOfRunContaining('two');
  const NextLineTop = TopOfRunContaining('three');
  const LowInImage = ImageLineTop + (NextLineTop - ImageLineTop) * 0.9;

  Assert.AreEqual(1, FMap.OffsetToSourceLine(LowInImage));
end;

procedure TMarkdownSourceLineMapTests.Build_WithoutDisplayList_MapsEveryLineToTheTop;
begin
  const Document = TMarkdown.Parse(SampleMarkdown, TMarkdownDialect.Gfm);

  FMap.Build(Document, nil, SampleMarkdown);

  Assert.AreEqual(0.0, FMap.SourceLineToOffset(4), SingleTolerance);
  Assert.AreEqual(0, FMap.OffsetToSourceLine(100));
end;

procedure TMarkdownSourceLineMapTests.BuildMap(const Markdown: string; const Width: Single);
begin
  const Document = TMarkdown.Parse(Markdown, TMarkdownDialect.Gfm);
  FDisplayList := TMarkdownLayoutEngine.LayoutDocument(Document, Width, FTheme, FMeasurer);
  FMap.Build(Document, FDisplayList, Markdown);
end;

function TMarkdownSourceLineMapTests.TopOfRunContaining(const Text: string): Single;
begin
  for var Index := 0 to FDisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const IsMatch = (Supports(FDisplayList.Items[Index], IDisplayTextRun, Run) and Run.Text.Contains(Text));
    if IsMatch then
    begin
      Result := Run.Bounds.Top;
      Exit;
    end;
  end;

  Assert.Fail(Format('No run shows "%s"', [Text]));
  Result := 0;
end;

end.
