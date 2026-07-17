unit Markdown4D.Pipeline;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Extensions.Interfaces;

type
  TMarkdownPipeline = class
  public
    class function Create: IMarkdownPipelineBuilder;
  end;

implementation

uses
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Pipeline.Configuration,
  Markdown4D.Parser.Blocks,
  Markdown4D.Parser.Inlines,
  Markdown4D.Renderer.Html,
  Markdown4D.Extensions.Gfm;

type
  TMarkdownPipelineInstance = class(TInterfacedObject, IMarkdownPipeline, IMarkdownPipelineConfigurationProvider)
  private
    FConfiguration: TMarkdownPipelineConfiguration;

  public
    constructor Create(const Configuration: TMarkdownPipelineConfiguration);
    destructor Destroy; override;
    function ToHtml(const Source: string): string;
    function Parse(const Source: string): IMarkdownDocument;
    function GetConfiguration: TMarkdownPipelineConfiguration;
  end;

  TMarkdownPipelineBuilder = class(TInterfacedObject, IMarkdownPipelineBuilder)
  private
    const
      BlockQuoteStartPriority = 900;
      AtxHeadingStartPriority = 850;
      FencedCodeStartPriority = 800;
      HtmlBlockStartPriority = 750;
      SetextHeadingStartPriority = 700;
      ThematicBreakStartPriority = 650;
      ListItemStartPriority = 600;
      IndentedCodeStartPriority = 550;
      BackslashInlinePriority = 900;
      LineEndingInlinePriority = 850;
      EmphasisInlinePriority = 800;
      CodeSpanInlinePriority = 750;
      AngleBracketInlinePriority = 700;
      EntityInlinePriority = 650;
      LinkOpenerInlinePriority = 600;
      ImageOpenerInlinePriority = 550;
      LinkCloserInlinePriority = 500;
      BlockQuoteTriggers = '>';
      AtxHeadingTriggers = '#';
      FencedCodeTriggers = '`~';
      HtmlBlockTriggers = '<';
      SetextHeadingTriggers = '=-';
      ThematicBreakTriggers = '*-_';
      ListItemTriggers = '*+-0123456789';
      IndentedCodeTriggers = '';
      BackslashTriggers = '\';
      LineEndingTriggers = #10;
      EmphasisTriggers = '*_';
      CodeSpanTriggers = '`';
      AngleBracketTriggers = '<';
      EntityTriggers = '&';
      LinkOpenerTriggers = '[';
      ImageOpenerTriggers = '!';
      LinkCloserTriggers = ']';
    var
      FBlockParsers: TList<TMarkdownBlockParserRegistration>;
      FInlineParsers: TList<TMarkdownInlineParserRegistration>;
      FDelimiterProcessors: TList<TMarkdownDelimiterProcessorRegistration>;
      FRendererHooks: TList<TMarkdownRendererHookRegistration>;
      FDocumentProcessors: TList<TMarkdownDocumentProcessorRegistration>;
      FPendingExtensions: TList<IMarkdownExtension>;
      FOptions: TMarkdownRendererOptions;
      FNextOrdinal: Integer;
      FCommonMarkRegistered: Boolean;
      FGfmRegistered: Boolean;
    procedure RegisterCommonMarkBlockParsers;
    procedure RegisterCommonMarkInlineParsers;
    procedure RunPendingExtensions;
    function TakeOrdinal: Integer;

  public
    constructor Create;
    destructor Destroy; override;
    function UseCommonMark: IMarkdownPipelineBuilder;
    function UseGfm: IMarkdownPipelineBuilder;
    function Use(const Extension: IMarkdownExtension): IMarkdownPipelineBuilder;
    function XhtmlOutput: IMarkdownPipelineBuilder;
    function UnsafeHtml: IMarkdownPipelineBuilder;
    function TagFilter: IMarkdownPipelineBuilder;
    function RegisterBlockParser(const Parser: IMarkdownBlockParser; const TriggerCharacters: string;
                                 const Priority: Integer): IMarkdownPipelineBuilder;
    function RegisterInlineParser(const Parser: IMarkdownInlineParser; const TriggerCharacters: string;
                                  const Priority: Integer): IMarkdownPipelineBuilder;
    function RegisterDelimiterProcessor(const Processor: IMarkdownDelimiterProcessor;
                                        const Priority: Integer): IMarkdownPipelineBuilder;
    function RegisterRendererHook(const Hook: IMarkdownRendererHook;
                                  const Priority: Integer): IMarkdownPipelineBuilder;
    function RegisterDocumentProcessor(const Processor: IMarkdownDocumentProcessor;
                                       const Priority: Integer): IMarkdownPipelineBuilder;
    function Build: IMarkdownPipeline;
  end;

class function TMarkdownPipeline.Create: IMarkdownPipelineBuilder;
begin
  Result := TMarkdownPipelineBuilder.Create;
end;

constructor TMarkdownPipelineInstance.Create(const Configuration: TMarkdownPipelineConfiguration);
begin
  inherited Create;

  FConfiguration := Configuration;
end;

destructor TMarkdownPipelineInstance.Destroy;
begin
  FConfiguration.Free;

  inherited Destroy;
end;

function TMarkdownPipelineInstance.ToHtml(const Source: string): string;
begin
  const Document = Parse(Source);

  Result := TMarkdownHtmlRenderer.RenderDocument(Document, FConfiguration.RendererOptions,
    FConfiguration.RendererHooks);
end;

function TMarkdownPipelineInstance.Parse(const Source: string): IMarkdownDocument;
begin
  const Parser = TBlockParser.Create(FConfiguration);
  try
    Result := Parser.Parse(Source);
  finally
    Parser.Free;
  end;
end;

function TMarkdownPipelineInstance.GetConfiguration: TMarkdownPipelineConfiguration;
begin
  Result := FConfiguration;
end;

constructor TMarkdownPipelineBuilder.Create;
begin
  inherited Create;

  FBlockParsers := TList<TMarkdownBlockParserRegistration>.Create;
  FInlineParsers := TList<TMarkdownInlineParserRegistration>.Create;
  FDelimiterProcessors := TList<TMarkdownDelimiterProcessorRegistration>.Create;
  FRendererHooks := TList<TMarkdownRendererHookRegistration>.Create;
  FDocumentProcessors := TList<TMarkdownDocumentProcessorRegistration>.Create;
  FPendingExtensions := TList<IMarkdownExtension>.Create;
  FOptions := TMarkdownRendererOptions.SafeDefaults;
end;

destructor TMarkdownPipelineBuilder.Destroy;
begin
  FPendingExtensions.Free;
  FDocumentProcessors.Free;
  FRendererHooks.Free;
  FDelimiterProcessors.Free;
  FInlineParsers.Free;
  FBlockParsers.Free;

  inherited Destroy;
end;

function TMarkdownPipelineBuilder.UseCommonMark: IMarkdownPipelineBuilder;
begin
  if not FCommonMarkRegistered then
  begin
    RegisterCommonMarkBlockParsers;
    RegisterCommonMarkInlineParsers;
    FCommonMarkRegistered := True;
  end;

  Result := Self;
end;

procedure TMarkdownPipelineBuilder.RegisterCommonMarkBlockParsers;
begin
  RegisterBlockParser(TCommonMarkBlockStarter.Create(TCommonMarkBlockKind.BlockQuote), BlockQuoteTriggers,
    BlockQuoteStartPriority);
  RegisterBlockParser(TCommonMarkBlockStarter.Create(TCommonMarkBlockKind.AtxHeading), AtxHeadingTriggers,
    AtxHeadingStartPriority);
  RegisterBlockParser(TCommonMarkBlockStarter.Create(TCommonMarkBlockKind.FencedCode), FencedCodeTriggers,
    FencedCodeStartPriority);
  RegisterBlockParser(TCommonMarkBlockStarter.Create(TCommonMarkBlockKind.HtmlBlock), HtmlBlockTriggers,
    HtmlBlockStartPriority);
  RegisterBlockParser(TCommonMarkBlockStarter.Create(TCommonMarkBlockKind.SetextHeading), SetextHeadingTriggers,
    SetextHeadingStartPriority);
  RegisterBlockParser(TCommonMarkBlockStarter.Create(TCommonMarkBlockKind.ThematicBreak), ThematicBreakTriggers,
    ThematicBreakStartPriority);
  RegisterBlockParser(TCommonMarkBlockStarter.Create(TCommonMarkBlockKind.ListItem), ListItemTriggers,
    ListItemStartPriority);
  RegisterBlockParser(TCommonMarkBlockStarter.Create(TCommonMarkBlockKind.IndentedCode), IndentedCodeTriggers,
    IndentedCodeStartPriority);
end;

procedure TMarkdownPipelineBuilder.RegisterCommonMarkInlineParsers;
begin
  RegisterInlineParser(TCommonMarkInlineParser.Create(TCommonMarkInlineKind.Backslash), BackslashTriggers,
    BackslashInlinePriority);
  RegisterInlineParser(TCommonMarkInlineParser.Create(TCommonMarkInlineKind.LineEnding), LineEndingTriggers,
    LineEndingInlinePriority);
  RegisterInlineParser(TCommonMarkInlineParser.Create(TCommonMarkInlineKind.EmphasisRun), EmphasisTriggers,
    EmphasisInlinePriority);
  RegisterInlineParser(TCommonMarkInlineParser.Create(TCommonMarkInlineKind.CodeSpan), CodeSpanTriggers,
    CodeSpanInlinePriority);
  RegisterInlineParser(TCommonMarkInlineParser.Create(TCommonMarkInlineKind.AngleBracket), AngleBracketTriggers,
    AngleBracketInlinePriority);
  RegisterInlineParser(TCommonMarkInlineParser.Create(TCommonMarkInlineKind.Entity), EntityTriggers,
    EntityInlinePriority);
  RegisterInlineParser(TCommonMarkInlineParser.Create(TCommonMarkInlineKind.LinkOpener), LinkOpenerTriggers,
    LinkOpenerInlinePriority);
  RegisterInlineParser(TCommonMarkInlineParser.Create(TCommonMarkInlineKind.ImageOpener), ImageOpenerTriggers,
    ImageOpenerInlinePriority);
  RegisterInlineParser(TCommonMarkInlineParser.Create(TCommonMarkInlineKind.LinkCloser), LinkCloserTriggers,
    LinkCloserInlinePriority);
end;

function TMarkdownPipelineBuilder.UseGfm: IMarkdownPipelineBuilder;
begin
  UseCommonMark;

  if not FGfmRegistered then
  begin
    Use(TGfmTableExtension.Create);
    Use(TGfmTaskListExtension.Create);
    Use(TGfmStrikethroughExtension.Create);
    Use(TGfmAutolinkExtension.Create);
    Use(TGfmTagFilterExtension.Create);
    FGfmRegistered := True;
  end;

  Result := Self;
end;

function TMarkdownPipelineBuilder.Use(const Extension: IMarkdownExtension): IMarkdownPipelineBuilder;
begin
  FPendingExtensions.Add(Extension);

  Result := Self;
end;

function TMarkdownPipelineBuilder.XhtmlOutput: IMarkdownPipelineBuilder;
begin
  FOptions.XhtmlOutput := True;

  Result := Self;
end;

function TMarkdownPipelineBuilder.UnsafeHtml: IMarkdownPipelineBuilder;
begin
  FOptions.AllowRawHtml := True;

  Result := Self;
end;

function TMarkdownPipelineBuilder.TagFilter: IMarkdownPipelineBuilder;
begin
  FOptions.ApplyTagFilter := True;

  Result := Self;
end;

function TMarkdownPipelineBuilder.RegisterBlockParser(const Parser: IMarkdownBlockParser;
                                                      const TriggerCharacters: string;
                                                      const Priority: Integer): IMarkdownPipelineBuilder;
begin
  var Registration: TMarkdownBlockParserRegistration;
  Registration.Parser := Parser;
  Registration.TriggerCharacters := TriggerCharacters;
  Registration.Priority := Priority;
  Registration.Ordinal := TakeOrdinal;

  FBlockParsers.Add(Registration);

  Result := Self;
end;

function TMarkdownPipelineBuilder.RegisterInlineParser(const Parser: IMarkdownInlineParser;
                                                       const TriggerCharacters: string;
                                                       const Priority: Integer): IMarkdownPipelineBuilder;
begin
  var Registration: TMarkdownInlineParserRegistration;
  Registration.Parser := Parser;
  Registration.TriggerCharacters := TriggerCharacters;
  Registration.Priority := Priority;
  Registration.Ordinal := TakeOrdinal;

  FInlineParsers.Add(Registration);

  Result := Self;
end;

function TMarkdownPipelineBuilder.RegisterDelimiterProcessor(const Processor: IMarkdownDelimiterProcessor;
                                                             const Priority: Integer): IMarkdownPipelineBuilder;
begin
  var Registration: TMarkdownDelimiterProcessorRegistration;
  Registration.Processor := Processor;
  Registration.Priority := Priority;
  Registration.Ordinal := TakeOrdinal;

  FDelimiterProcessors.Add(Registration);

  Result := Self;
end;

function TMarkdownPipelineBuilder.RegisterRendererHook(const Hook: IMarkdownRendererHook;
                                                       const Priority: Integer): IMarkdownPipelineBuilder;
begin
  var Registration: TMarkdownRendererHookRegistration;
  Registration.Hook := Hook;
  Registration.Priority := Priority;
  Registration.Ordinal := TakeOrdinal;

  FRendererHooks.Add(Registration);

  Result := Self;
end;

function TMarkdownPipelineBuilder.RegisterDocumentProcessor(const Processor: IMarkdownDocumentProcessor;
                                                            const Priority: Integer): IMarkdownPipelineBuilder;
begin
  var Registration: TMarkdownDocumentProcessorRegistration;
  Registration.Processor := Processor;
  Registration.Priority := Priority;
  Registration.Ordinal := TakeOrdinal;

  FDocumentProcessors.Add(Registration);

  Result := Self;
end;

function TMarkdownPipelineBuilder.Build: IMarkdownPipeline;
begin
  RunPendingExtensions;

  const Configuration = TMarkdownPipelineConfiguration.Create(FBlockParsers, FInlineParsers, FDelimiterProcessors,
    FRendererHooks, FDocumentProcessors, FOptions);
  Result := TMarkdownPipelineInstance.Create(Configuration);
end;

procedure TMarkdownPipelineBuilder.RunPendingExtensions;
begin
  while FPendingExtensions.Count > 0 do
  begin
    const Extension = FPendingExtensions[0];
    FPendingExtensions.Delete(0);

    Extension.Setup(Self);
  end;
end;

function TMarkdownPipelineBuilder.TakeOrdinal: Integer;
begin
  Result := FNextOrdinal;
  Inc(FNextOrdinal);
end;

end.
