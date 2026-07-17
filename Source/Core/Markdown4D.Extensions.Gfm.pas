unit Markdown4D.Extensions.Gfm;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Extensions.Interfaces;

type
  TGfmTableExtension = class(TInterfacedObject, IMarkdownExtension)
  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

  TGfmTaskListExtension = class(TInterfacedObject, IMarkdownExtension)
  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

  TGfmStrikethroughExtension = class(TInterfacedObject, IMarkdownExtension)
  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

  TGfmAutolinkExtension = class(TInterfacedObject, IMarkdownExtension)
  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

  TGfmTagFilterExtension = class(TInterfacedObject, IMarkdownExtension)
  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

implementation

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Parser.Blocks,
  Markdown4D.Parser.Inlines;

type
  TStrikethroughDelimiterProcessor = class(TInterfacedObject, IMarkdownDelimiterProcessor)
  public
    function GetDelimiterCharacter: Char;
    function GetMinimumLength: Integer;
    function GetNodeName: string;
  end;

  TStrikethroughRendererHook = class(TInterfacedObject, IMarkdownRendererHook)
  public
    function GetNodeName: string;
    procedure RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
    procedure RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
  end;

  TTaskCheckboxRendererHook = class(TInterfacedObject, IMarkdownRendererHook)
  private
    FNodeName: string;
    FInputHtml: string;

  public
    constructor Create(const NodeName, InputHtml: string);
    function GetNodeName: string;
    procedure RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
    procedure RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
  end;

const
  TableTriggers = '|:-';
  TableStartPriority = 675;
  TaskListTriggers = '[';
  TaskListPriority = 950;
  TaskListHookPriority = 50;
  TaskCheckedInputHtml = '<input checked="" disabled="" type="checkbox">';
  TaskUncheckedInputHtml = '<input disabled="" type="checkbox">';
  WwwAutolinkTriggers = 'w';
  UrlAutolinkTriggers = 'hf';
  EmailAutolinkTriggers = '@';
  WwwAutolinkPriority = 480;
  UrlAutolinkPriority = 470;
  EmailAutolinkPriority = 460;
  StrikethroughDelimiterCharacter = '~';
  StrikethroughMinimumLength = 2;
  StrikethroughOpenTag = '<del>';
  StrikethroughCloseTag = '</del>';
  StrikethroughPriority = 50;

procedure TGfmTableExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterBlockParser(TGfmTableBlockStarter.Create, TableTriggers, TableStartPriority);
end;

procedure TGfmTaskListExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterInlineParser(TGfmInlineParser.Create(TGfmInlineKind.TaskListMarker), TaskListTriggers,
    TaskListPriority);
  Pipeline.RegisterRendererHook(TTaskCheckboxRendererHook.Create(TGfmInlineParser.TaskCheckedNodeName,
    TaskCheckedInputHtml), TaskListHookPriority);
  Pipeline.RegisterRendererHook(TTaskCheckboxRendererHook.Create(TGfmInlineParser.TaskUncheckedNodeName,
    TaskUncheckedInputHtml), TaskListHookPriority);
end;

procedure TGfmStrikethroughExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterDelimiterProcessor(TStrikethroughDelimiterProcessor.Create, StrikethroughPriority);
  Pipeline.RegisterRendererHook(TStrikethroughRendererHook.Create, StrikethroughPriority);
end;

procedure TGfmAutolinkExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterInlineParser(TGfmInlineParser.Create(TGfmInlineKind.WwwAutolink), WwwAutolinkTriggers,
    WwwAutolinkPriority);
  Pipeline.RegisterInlineParser(TGfmInlineParser.Create(TGfmInlineKind.UrlAutolink), UrlAutolinkTriggers,
    UrlAutolinkPriority);
  Pipeline.RegisterInlineParser(TGfmInlineParser.Create(TGfmInlineKind.EmailAutolink), EmailAutolinkTriggers,
    EmailAutolinkPriority);
end;

procedure TGfmTagFilterExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.TagFilter;
end;

function TStrikethroughDelimiterProcessor.GetDelimiterCharacter: Char;
begin
  Result := StrikethroughDelimiterCharacter;
end;

function TStrikethroughDelimiterProcessor.GetMinimumLength: Integer;
begin
  Result := StrikethroughMinimumLength;
end;

function TStrikethroughDelimiterProcessor.GetNodeName: string;
begin
  Result := TGfmInlineParser.StrikethroughNodeName;
end;

function TStrikethroughRendererHook.GetNodeName: string;
begin
  Result := TGfmInlineParser.StrikethroughNodeName;
end;

procedure TStrikethroughRendererHook.RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
begin
  Writer.WriteRaw(StrikethroughOpenTag);
end;

procedure TStrikethroughRendererHook.RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
begin
  Writer.WriteRaw(StrikethroughCloseTag);
end;

constructor TTaskCheckboxRendererHook.Create(const NodeName, InputHtml: string);
begin
  inherited Create;

  FNodeName := NodeName;
  FInputHtml := InputHtml;
end;

function TTaskCheckboxRendererHook.GetNodeName: string;
begin
  Result := FNodeName;
end;

procedure TTaskCheckboxRendererHook.RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
begin
  Writer.WriteRaw(FInputHtml);
end;

procedure TTaskCheckboxRendererHook.RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
begin
end;

end.
