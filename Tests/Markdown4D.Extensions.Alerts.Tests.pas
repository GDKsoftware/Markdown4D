unit Markdown4D.Extensions.Alerts.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Alerts,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList;

type
  [TestFixture]
  TMarkdownAlertTests = class
  private
    const
      NoteSource = '> [!NOTE]'#10'> Body text.';
    class function Parse(const Source: string): IMarkdownDocument;
    class function Html(const Source: string): string;
    class function FirstChild(const Source: string): IMarkdownNode;
    class function IsAlert(const Node: IMarkdownNode): Boolean;

  public
    [Test]
    [TestCase('Note', 'NOTE,0')]
    [TestCase('Tip', 'TIP,1')]
    [TestCase('Important', 'IMPORTANT,2')]
    [TestCase('Warning', 'WARNING,3')]
    [TestCase('Caution', 'CAUTION,4')]
    [TestCase('LowerCase', 'note,0')]
    procedure Parse_MarkerLine_TagsQuoteWithKind(const MarkerName: string; const ExpectedOrdinal: Integer);

    [Test]
    procedure Parse_MarkerLine_IsRemovedFromText;

    [Test]
    procedure Parse_MarkerInOwnParagraph_DropsEmptyParagraph;

    [Test]
    [TestCase('UnknownKind', '> [!FOO]'#10'> Body')]
    [TestCase('TextAfterMarker', '> [!NOTE] Body')]
    [TestCase('EmphasisedMarker', '> *[!NOTE]*'#10'> Body')]
    [TestCase('NestedInList', '- > [!NOTE]'#10'  > Body')]
    procedure Parse_NotAnAlert_StaysBlockQuote(const Source: string);

    [Test]
    procedure Parse_CommonMark_KeepsMarkerAsText;

    [Test]
    procedure ToHtml_Alert_WritesGitHubMarkup;

    [Test]
    [TestCase('WithBody', '> [!TIP]'#10'> Body text.')]
    [TestCase('WithoutBody', '> [!CAUTION]')]
    [TestCase('BodyInOwnParagraph', '> [!IMPORTANT]'#10'>'#10'> Body text.')]
    procedure ToMarkdown_Alert_RoundTrips(const Source: string);
  end;

  [TestFixture]
  TMarkdownAlertLayoutTests = class
  private
    const
      LayoutWidth = 400;
    class function Layout(const Source: string): IMarkdownDisplayList;
    class function FindRun(const DisplayList: IMarkdownDisplayList; const Prefix: string): IDisplayTextRun;
    class function CountRectanglesIn(const DisplayList: IMarkdownDisplayList; const Color: TLayoutColor): Integer;
    class function CountOfKind(const DisplayList: IMarkdownDisplayList; const Kind: TDisplayItemKind): Integer;

  public
    [Test]
    procedure Layout_Alert_DrawsTitleAndBarInKindColor;

    [Test]
    procedure Layout_Alert_DrawsIcon;

    [Test]
    procedure Layout_Alert_KeepsBodyInTextColor;

    [Test]
    procedure Layout_DiffBlock_ShadesAddedAndRemovedLines;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Theme,
  Markdown4D.Highlighter.Interfaces,
  Markdown4D.Highlighter.Diff,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.FakeMeasurer;

class function TMarkdownAlertTests.Parse(const Source: string): IMarkdownDocument;
begin
  Result := TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
end;

class function TMarkdownAlertTests.Html(const Source: string): string;
begin
  Result := TMarkdown.ToHtml(Source, TMarkdownDialect.Gfm);
end;

class function TMarkdownAlertTests.FirstChild(const Source: string): IMarkdownNode;
begin
  const Document = Parse(Source);
  Result := Document.Children[0];
end;

class function TMarkdownAlertTests.IsAlert(const Node: IMarkdownNode): Boolean;
begin
  var Kind: TMarkdownAlertKind;
  Result := TMarkdownAlerts.TryGetKind(Node, Kind);
end;

procedure TMarkdownAlertTests.Parse_MarkerLine_TagsQuoteWithKind(const MarkerName: string;
  const ExpectedOrdinal: Integer);
begin
  const Source = Format('> [!%s]'#10'> Body text.', [MarkerName]);

  const Quote = FirstChild(Source);

  var Kind: TMarkdownAlertKind;
  Assert.IsTrue(TMarkdownAlerts.TryGetKind(Quote, Kind));
  Assert.AreEqual<TMarkdownAlertKind>(TMarkdownAlertKind(ExpectedOrdinal), Kind);
end;

procedure TMarkdownAlertTests.Parse_MarkerLine_IsRemovedFromText;
begin
  const Output = Html(NoteSource);

  Assert.DoesNotContain(Output, '[!NOTE]');
  Assert.Contains(Output, '<p>Body text.</p>');
end;

procedure TMarkdownAlertTests.Parse_MarkerInOwnParagraph_DropsEmptyParagraph;
begin
  const Quote = FirstChild('> [!TIP]'#10'>'#10'> Body text.');

  Assert.IsTrue(IsAlert(Quote));
  Assert.AreEqual(1, Quote.ChildCount);
end;

procedure TMarkdownAlertTests.Parse_NotAnAlert_StaysBlockQuote(const Source: string);
begin
  const Output = Html(Source);

  Assert.Contains(Output, '<blockquote>');
  Assert.DoesNotContain(Output, 'markdown-alert');
end;

procedure TMarkdownAlertTests.Parse_CommonMark_KeepsMarkerAsText;
begin
  const Output = TMarkdown.ToHtml(NoteSource, TMarkdownDialect.CommonMark);

  Assert.Contains(Output, '[!NOTE]');
  Assert.Contains(Output, '<blockquote>');
end;

procedure TMarkdownAlertTests.ToHtml_Alert_WritesGitHubMarkup;
begin
  const Output = Html('> [!WARNING]'#10'> Body text.');

  Assert.Contains(Output, '<div class="markdown-alert markdown-alert-warning">');
  Assert.Contains(Output, '<p class="markdown-alert-title">Warning</p>');
  Assert.Contains(Output, '<p>Body text.</p>');
  Assert.Contains(Output, '</div>');
  Assert.DoesNotContain(Output, '<blockquote>');
end;

procedure TMarkdownAlertTests.ToMarkdown_Alert_RoundTrips(const Source: string);
begin
  const Written = TMarkdown.ToMarkdown(Parse(Source));

  Assert.AreEqual(Html(Source), Html(Written));
end;

class function TMarkdownAlertLayoutTests.Layout(const Source: string): IMarkdownDisplayList;
begin
  const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
  const Theme = TMarkdownTheme.CreateLight;
  try
    var Measurer: ITextMeasurer := TFakeTextMeasurer.Create;
    Result := TMarkdownLayoutEngine.LayoutDocument(Document, LayoutWidth, Theme, Measurer);
  finally
    Theme.Free;
  end;
end;

class function TMarkdownAlertLayoutTests.FindRun(const DisplayList: IMarkdownDisplayList;
  const Prefix: string): IDisplayTextRun;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const IsMatch = Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and Run.Text.StartsWith(Prefix);
    if IsMatch then
      Exit(Run);
  end;

  Result := nil;
end;

class function TMarkdownAlertLayoutTests.CountRectanglesIn(const DisplayList: IMarkdownDisplayList;
  const Color: TLayoutColor): Integer;
begin
  Result := 0;

  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Rectangle: IDisplayRectangle;
    const IsMatch = Supports(DisplayList.Items[Index], IDisplayRectangle, Rectangle) and
                    (Rectangle.FillColor = Color);
    if IsMatch then
      Inc(Result);
  end;
end;

class function TMarkdownAlertLayoutTests.CountOfKind(const DisplayList: IMarkdownDisplayList;
  const Kind: TDisplayItemKind): Integer;
begin
  Result := 0;

  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    if DisplayList.Items[Index].Kind = Kind then
      Inc(Result);
  end;
end;

procedure TMarkdownAlertLayoutTests.Layout_Alert_DrawsTitleAndBarInKindColor;
begin
  const Theme = TMarkdownTheme.CreateLight;
  try
    const WarningColor = Theme.AlertColors[TMarkdownAlertKind.Warning];

    const DisplayList = Layout('> [!WARNING]'#10'> Body text.');

    const Title = FindRun(DisplayList, 'Warning');
    Assert.IsNotNull(Title);
    Assert.AreEqual<TLayoutColor>(WarningColor, Title.Color);
    Assert.IsTrue(Title.Font.Bold);
    Assert.AreEqual(1, CountRectanglesIn(DisplayList, WarningColor));
  finally
    Theme.Free;
  end;
end;

procedure TMarkdownAlertLayoutTests.Layout_Alert_DrawsIcon;
begin
  const DisplayList = Layout('> [!CAUTION]'#10'> Body text.');

  const HasIconShapes = (CountOfKind(DisplayList, TDisplayItemKind.Polygon) > 0);
  Assert.IsTrue(HasIconShapes);
end;

procedure TMarkdownAlertLayoutTests.Layout_Alert_KeepsBodyInTextColor;
begin
  const Theme = TMarkdownTheme.CreateLight;
  try
    const DisplayList = Layout('> [!NOTE]'#10'> Body text.');

    const Body = FindRun(DisplayList, 'Body');
    Assert.IsNotNull(Body);
    Assert.AreEqual<TLayoutColor>(Theme.TextColor, Body.Color);
  finally
    Theme.Free;
  end;
end;

procedure TMarkdownAlertLayoutTests.Layout_DiffBlock_ShadesAddedAndRemovedLines;
begin
  THighlighterRegistry.Register(DiffLanguageName, TDiffSyntaxHighlighter.Create);

  const Theme = TMarkdownTheme.CreateLight;
  try
    const DisplayList = Layout('```diff'#10'+ added'#10'- removed'#10'  same'#10'+ again'#10'```');

    Assert.AreEqual(2, CountRectanglesIn(DisplayList, Theme.DiffInsertedBackgroundColor));
    Assert.AreEqual(1, CountRectanglesIn(DisplayList, Theme.DiffDeletedBackgroundColor));
  finally
    Theme.Free;
  end;
end;

end.
