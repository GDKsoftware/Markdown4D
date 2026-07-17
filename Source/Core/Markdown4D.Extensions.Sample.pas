unit Markdown4D.Extensions.Sample;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Extensions.Interfaces;

type
  TMarkExtension = class(TInterfacedObject, IMarkdownExtension)
  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

implementation

uses
  Markdown4D.Ast.Interfaces;

type
  TMarkDelimiterProcessor = class(TInterfacedObject, IMarkdownDelimiterProcessor)
  public
    function GetDelimiterCharacter: Char;
    function GetMinimumLength: Integer;
    function GetNodeName: string;
  end;

  TMarkRendererHook = class(TInterfacedObject, IMarkdownRendererHook)
  public
    function GetNodeName: string;
    procedure RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
    procedure RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
  end;

const
  MarkNodeName = 'mark';
  MarkDelimiterCharacter = '=';
  MarkDelimiterMinimumLength = 2;
  MarkOpenTag = '<mark>';
  MarkCloseTag = '</mark>';
  MarkPriority = 50;

procedure TMarkExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterDelimiterProcessor(TMarkDelimiterProcessor.Create, MarkPriority);
  Pipeline.RegisterRendererHook(TMarkRendererHook.Create, MarkPriority);
end;

function TMarkDelimiterProcessor.GetDelimiterCharacter: Char;
begin
  Result := MarkDelimiterCharacter;
end;

function TMarkDelimiterProcessor.GetMinimumLength: Integer;
begin
  Result := MarkDelimiterMinimumLength;
end;

function TMarkDelimiterProcessor.GetNodeName: string;
begin
  Result := MarkNodeName;
end;

function TMarkRendererHook.GetNodeName: string;
begin
  Result := MarkNodeName;
end;

procedure TMarkRendererHook.RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
begin
  Writer.WriteRaw(MarkOpenTag);
end;

procedure TMarkRendererHook.RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
begin
  Writer.WriteRaw(MarkCloseTag);
end;

end.
