unit Markdown4D.Pipeline.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownPipelineTests = class
  private
    const
      ParitySources: array[0..4] of string = (
        '# Title',
        '*emphasis* and **strong**',
        '- one'#10'- two',
        '    indented code',
        '[link](/uri "title")');

  public
    [Test]
    procedure Build_CommonMarkPipeline_ReturnsPipeline;

    [Test]
    procedure ToHtml_CommonMarkInputs_MatchesFacadeOutput;

    [Test]
    procedure Parse_Heading_ReturnsDocumentAst;

    [Test]
    procedure ToHtml_GfmStrikethrough_RendersDelElement;

    [Test]
    procedure Build_Extensions_InvokesSetupInRegistrationOrder;

    [Test]
    procedure RegisterRendererHook_SameNodeName_HigherPriorityWins;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Pipeline,
  Markdown4D;

const
  SupNodeName = 'sup';
  SupDelimiterPriority = 50;
  LowHookPriority = 10;
  HighHookPriority = 90;

type
  TRecordingExtension = class(TInterfacedObject, IMarkdownExtension)
  private
    FName: string;
    FLog: TList<string>;

  public
    constructor Create(const Name: string; const Log: TList<string>);
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

  TSupDelimiterProcessor = class(TInterfacedObject, IMarkdownDelimiterProcessor)
  public
    function GetDelimiterCharacter: Char;
    function GetMinimumLength: Integer;
    function GetNodeName: string;
  end;

  TTaggedRendererHook = class(TInterfacedObject, IMarkdownRendererHook)
  private
    FOpenTag: string;
    FCloseTag: string;

  public
    constructor Create(const OpenTag, CloseTag: string);
    function GetNodeName: string;
    procedure RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
    procedure RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
  end;

procedure TMarkdownPipelineTests.Build_CommonMarkPipeline_ReturnsPipeline;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.Build;

  Assert.IsNotNull(Pipeline);
end;

procedure TMarkdownPipelineTests.ToHtml_CommonMarkInputs_MatchesFacadeOutput;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.Build;

  for var Source in ParitySources do
  begin
    Assert.AreEqual(TMarkdown.ToHtml(Source), Pipeline.ToHtml(Source), Format('Pipeline output differs from facade output for <%s>', [Source]));
  end;
end;

procedure TMarkdownPipelineTests.Parse_Heading_ReturnsDocumentAst;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.Build;

  const Document = Pipeline.Parse('# Title');
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.Document, Document.Kind);
  Assert.AreEqual(1, Document.ChildCount);
  Assert.AreEqual<TMarkdownNodeKind>(TMarkdownNodeKind.Heading, Document.Children[0].Kind);
end;

procedure TMarkdownPipelineTests.ToHtml_GfmStrikethrough_RendersDelElement;
begin
  const Pipeline = TMarkdownPipeline.Create.UseGfm.Build;

  Assert.AreEqual('<p><del>gone</del></p>'#10, Pipeline.ToHtml('~~gone~~'));
end;

procedure TMarkdownPipelineTests.Build_Extensions_InvokesSetupInRegistrationOrder;
begin
  const Log = TList<string>.Create;
  try
    const Builder = TMarkdownPipeline.Create.UseCommonMark
      .Use(TRecordingExtension.Create('first', Log))
      .Use(TRecordingExtension.Create('second', Log));
    Builder.Build;

    Assert.AreEqual('first,second', string.Join(',', Log.ToArray));
  finally
    Log.Free;
  end;
end;

procedure TMarkdownPipelineTests.RegisterRendererHook_SameNodeName_HigherPriorityWins;
begin
  const Builder = TMarkdownPipeline.Create.UseCommonMark;
  Builder.RegisterDelimiterProcessor(TSupDelimiterProcessor.Create, SupDelimiterPriority);
  Builder.RegisterRendererHook(TTaggedRendererHook.Create('<sub>', '</sub>'), LowHookPriority);
  Builder.RegisterRendererHook(TTaggedRendererHook.Create('<sup>', '</sup>'), HighHookPriority);

  const Pipeline = Builder.Build;
  Assert.AreEqual('<p>a <sup>x</sup> b</p>'#10, Pipeline.ToHtml('a ^^x^^ b'));
end;

constructor TRecordingExtension.Create(const Name: string; const Log: TList<string>);
begin
  inherited Create;

  FName := Name;
  FLog := Log;
end;

procedure TRecordingExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  FLog.Add(FName);
end;

function TSupDelimiterProcessor.GetDelimiterCharacter: Char;
begin
  Result := '^';
end;

function TSupDelimiterProcessor.GetMinimumLength: Integer;
begin
  Result := 2;
end;

function TSupDelimiterProcessor.GetNodeName: string;
begin
  Result := SupNodeName;
end;

constructor TTaggedRendererHook.Create(const OpenTag, CloseTag: string);
begin
  inherited Create;

  FOpenTag := OpenTag;
  FCloseTag := CloseTag;
end;

function TTaggedRendererHook.GetNodeName: string;
begin
  Result := SupNodeName;
end;

procedure TTaggedRendererHook.RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
begin
  Writer.WriteRaw(FOpenTag);
end;

procedure TTaggedRendererHook.RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
begin
  Writer.WriteRaw(FCloseTag);
end;

end.
