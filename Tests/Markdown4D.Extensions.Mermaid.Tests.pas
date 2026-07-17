unit Markdown4D.Extensions.Mermaid.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Mermaid.Corpus;

type
  [TestFixture]
  TMermaidExtensionTests = class
  private
    const
      ExpectedCaseCount = 28;
    var
      FCorpus: TMermaidCorpus;

  public
    [SetupFixture]
    procedure SetupFixture;

    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure Corpus_LoadsAllCases;

    [Test]
    procedure Detection_DetectedCases_ExposeModelViaChannel;

    [Test]
    procedure Detection_FallbackCases_ProduceNoModel;

    [Test]
    procedure Model_ResolvesFlowchartNodesAndEdges;

    [Test]
    procedure Model_ResolvesSequenceParticipants;

    [Test]
    procedure Model_ResolvesPieSlices;

    [Test]
    procedure Html_FencedCases_RenderPlainCodeBlock;

    [Test]
    procedure Writer_RoundTrip_PreservesMermaidSource;

    [Test]
    procedure OptIn_WithoutExtension_HtmlIsUnchanged;

    [Test]
    procedure Streaming_MidFence_NoModel_AfterClose_Model;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Pipeline,
  Markdown4D.Extensions.Mermaid;

function MermaidPipeline: IMarkdownPipeline;
begin
  Result := TMarkdownPipeline.Create.UseGfm.Use(TMermaidExtension.Create).UnsafeHtml.Build;
end;

function PlainPipeline: IMarkdownPipeline;
begin
  Result := TMarkdownPipeline.Create.UseGfm.UnsafeHtml.Build;
end;

function FindFirstCodeBlock(const Document: IMarkdownDocument; out Code: IMarkdownCodeBlock): Boolean;
begin
  Code := nil;

  for var Index := 0 to Document.ChildCount - 1 do
  begin
    const Child = Document.Children[Index];
    if Child.Kind = TMarkdownNodeKind.CodeBlock then
    begin
      Code := Child as IMarkdownCodeBlock;
      Exit(True);
    end;
  end;

  Result := False;
end;

procedure TMermaidExtensionTests.SetupFixture;
begin
  FCorpus := TMermaidCorpus.Create;
end;

procedure TMermaidExtensionTests.TearDownFixture;
begin
  FreeAndNil(FCorpus);
end;

procedure TMermaidExtensionTests.Corpus_LoadsAllCases;
begin
  Assert.AreEqual(ExpectedCaseCount, FCorpus.Count,
    Format('%s must contain %d cases', [TMermaidCorpus.CorpusFileName, ExpectedCaseCount]));
end;

procedure TMermaidExtensionTests.Detection_DetectedCases_ExposeModelViaChannel;
begin
  for var Index := 0 to FCorpus.Count - 1 do
  begin
    const Item = FCorpus[Index];
    if not Item.Detected then
      Continue;

    const Document = MermaidPipeline.Parse(Item.Markdown);

    var Code: IMarkdownCodeBlock;
    Assert.IsTrue(FindFirstCodeBlock(Document, Code), Format('Case "%s" must expose a code block', [Item.Name]));

    var Model: IMermaidModel;
    Assert.IsTrue(TMermaidExtension.TryGetModel(Code, Model),
      Format('Case "%s" must expose a mermaid model via the extension-data channel', [Item.Name]));
    Assert.IsNotNull(Model, Format('Case "%s" model must not be nil', [Item.Name]));
  end;
end;

procedure TMermaidExtensionTests.Detection_FallbackCases_ProduceNoModel;
begin
  for var Index := 0 to FCorpus.Count - 1 do
  begin
    const Item = FCorpus[Index];
    if Item.Detected then
      Continue;

    const Document = MermaidPipeline.Parse(Item.Markdown);

    var Code: IMarkdownCodeBlock;
    if not FindFirstCodeBlock(Document, Code) then
      Continue;

    var Model: IMermaidModel;
    Assert.IsFalse(TMermaidExtension.TryGetModel(Code, Model),
      Format('Fallback case "%s" must not produce a mermaid model', [Item.Name]));
  end;
end;

procedure TMermaidExtensionTests.Model_ResolvesFlowchartNodesAndEdges;
begin
  const Item = FCorpus.FindCase('flowchart-simple-chain');
  const Document = MermaidPipeline.Parse(Item.Markdown);

  var Code: IMarkdownCodeBlock;
  Assert.IsTrue(FindFirstCodeBlock(Document, Code));

  var Model: IMermaidModel;
  Assert.IsTrue(TMermaidExtension.TryParse(Code, Model));
  Assert.AreEqual(Ord(TMermaidDiagramKind.Flowchart), Ord(Model.DiagramKind));
  Assert.AreEqual(3, Model.NodeCount);
  Assert.AreEqual(2, Model.EdgeCount);
end;

procedure TMermaidExtensionTests.Model_ResolvesSequenceParticipants;
begin
  const Item = FCorpus.FindCase('sequence-two-participants');
  const Document = MermaidPipeline.Parse(Item.Markdown);

  var Code: IMarkdownCodeBlock;
  Assert.IsTrue(FindFirstCodeBlock(Document, Code));

  var Model: IMermaidModel;
  Assert.IsTrue(TMermaidExtension.TryParse(Code, Model));
  Assert.AreEqual(Ord(TMermaidDiagramKind.Sequence), Ord(Model.DiagramKind));
  Assert.AreEqual(2, Model.ParticipantCount);
  Assert.AreEqual(2, Model.MessageCount);
end;

procedure TMermaidExtensionTests.Model_ResolvesPieSlices;
begin
  const Item = FCorpus.FindCase('pie-title-three-slices');
  const Document = MermaidPipeline.Parse(Item.Markdown);

  var Code: IMarkdownCodeBlock;
  Assert.IsTrue(FindFirstCodeBlock(Document, Code));

  var Model: IMermaidModel;
  Assert.IsTrue(TMermaidExtension.TryParse(Code, Model));
  Assert.AreEqual(Ord(TMermaidDiagramKind.Pie), Ord(Model.DiagramKind));
  Assert.AreEqual(3, Model.SliceCount);
  Assert.AreEqual('Pets', Model.Title);
end;

procedure TMermaidExtensionTests.Html_FencedCases_RenderPlainCodeBlock;
begin
  const Pipeline = MermaidPipeline;

  for var Index := 0 to FCorpus.Count - 1 do
  begin
    const Item = FCorpus[Index];
    const Html = Pipeline.ToHtml(Item.Markdown);
    Assert.IsTrue(Html.Contains('<pre><code'),
      Format('Case "%s" must still render as a fenced code block in HTML', [Item.Name]));
  end;
end;

procedure TMermaidExtensionTests.Writer_RoundTrip_PreservesMermaidSource;
begin
  const MermaidPipe = MermaidPipeline;

  for var Index := 0 to FCorpus.Count - 1 do
  begin
    const Item = FCorpus[Index];
    const Document = MermaidPipe.Parse(Item.Markdown);

    var Code: IMarkdownCodeBlock;
    if not FindFirstCodeBlock(Document, Code) then
      Continue;

    const OriginalLiteral = Code.Literal;
    const Rewritten = TMarkdown.ToMarkdown(Document);
    const Reparsed = MermaidPipe.Parse(Rewritten);

    var ReparsedCode: IMarkdownCodeBlock;
    Assert.IsTrue(FindFirstCodeBlock(Reparsed, ReparsedCode),
      Format('Case "%s" must round-trip to a code block', [Item.Name]));
    Assert.AreEqual(OriginalLiteral, ReparsedCode.Literal,
      Format('Case "%s" mermaid source must survive the writer byte-for-byte', [Item.Name]));
  end;
end;

procedure TMermaidExtensionTests.OptIn_WithoutExtension_HtmlIsUnchanged;
begin
  const MermaidPipe = MermaidPipeline;
  const PlainPipe = PlainPipeline;

  for var Index := 0 to FCorpus.Count - 1 do
  begin
    const Item = FCorpus[Index];
    Assert.AreEqual(PlainPipe.ToHtml(Item.Markdown), MermaidPipe.ToHtml(Item.Markdown),
      Format('Case "%s" HTML must be identical with and without the mermaid extension', [Item.Name]));
  end;
end;

procedure TMermaidExtensionTests.Streaming_MidFence_NoModel_AfterClose_Model;
begin
  const Complete = FCorpus.FindCase('flowchart-simple-chain');
  const MidFence = '```mermaid'#10'flowchart TD'#10'    A --> B';

  const Pipeline = MermaidPipeline;

  const OpenDocument = Pipeline.Parse(MidFence);
  var OpenCode: IMarkdownCodeBlock;
  Assert.IsTrue(FindFirstCodeBlock(OpenDocument, OpenCode), 'An open fence must still parse as a code block');

  var OpenModel: IMermaidModel;
  Assert.IsFalse(TMermaidExtension.TryGetModel(OpenCode, OpenModel),
    'An incomplete mermaid fence must not expose a mermaid model');

  const ClosedDocument = Pipeline.Parse(Complete.Markdown);
  var ClosedCode: IMarkdownCodeBlock;
  Assert.IsTrue(FindFirstCodeBlock(ClosedDocument, ClosedCode));

  var ClosedModel: IMermaidModel;
  Assert.IsTrue(TMermaidExtension.TryGetModel(ClosedCode, ClosedModel),
    'A closed mermaid fence must expose a mermaid model');
end;

end.
