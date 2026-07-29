unit Markdown4D.Extensions.Interfaces;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces;

type
  TMarkdownBlockStart = (NoMatch, Container, Leaf);

  TMarkdownPriorities = record
  public
    const
      Highest = 1000;
      High = 800;
      AboveNormal = 700;
      Normal = 500;
      BelowNormal = 300;
      Low = 200;
      Lowest = 0;
      BlockQuoteStart = 900;
      AtxHeadingStart = 850;
      FencedCodeStart = 800;
      HtmlBlockStart = 750;
      SetextHeadingStart = 700;
      ThematicBreakStart = 650;
      ListItemStart = 600;
      IndentedCodeStart = 550;
      BackslashInline = 900;
      LineEndingInline = 850;
      EmphasisInline = 800;
      CodeSpanInline = 750;
      AngleBracketInline = 700;
      EntityInline = 650;
      LinkOpenerInline = 600;
      ImageOpenerInline = 550;
      LinkCloserInline = 500;
      ExtensionParser = 100;
      ExtensionProcessor = 100;
      ExtensionRenderer = 50;
      ExtensionLayoutOverride = 100;
  end;

  IMarkdownPipelineBuilder = interface;

  IMarkdownExtension = interface
    ['{F2C04073-36AF-4725-BEC6-B6E27C880DE6}']
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

  IMarkdownHtmlWriter = interface
    ['{105D08B3-54BA-4CB6-A240-487BCB25509D}']
    procedure WriteRaw(const Html: string);
    procedure WriteEscaped(const Text: string);
    function EscapeAttribute(const Value: string): string;
    procedure WriteAttribute(const Name, Value: string);
  end;

  IMarkdownBlockParserContext = interface
    ['{3E6A1F42-9D0C-4B7E-8A25-6C1D4F9B0E73}']
    function GetLineText: string;
    function GetIndent: Integer;
    function GetIsBlankLine: Boolean;
    property LineText: string read GetLineText;
    property Indent: Integer read GetIndent;
    property IsBlankLine: Boolean read GetIsBlankLine;
  end;

  IMarkdownBlockParser = interface
    ['{CC0A3BE0-012C-4AE5-B7CA-B15DAFC5256E}']
    function GetName: string;
    function TryStart(const Context: IMarkdownBlockParserContext): TMarkdownBlockStart;
    property Name: string read GetName;
  end;

  IMarkdownInlineParserContext = interface
    ['{7D24C8B1-5F3A-4906-B2E8-0A9C6D5E1F84}']
    function GetContent: string;
    function GetPosition: Integer;
    property Content: string read GetContent;
    property Position: Integer read GetPosition;
  end;

  IMarkdownInlineParser = interface
    ['{6FD91196-DFC6-4F9E-B364-B4F5E1D28F52}']
    function GetName: string;
    function TryParse(const Context: IMarkdownInlineParserContext): Boolean;
    property Name: string read GetName;
  end;

  IMarkdownDelimiterProcessor = interface
    ['{041E56EF-C0D3-49F4-8E73-2C2F5CE8C589}']
    function GetDelimiterCharacter: Char;
    function GetMinimumLength: Integer;
    function GetNodeName: string;
    property DelimiterCharacter: Char read GetDelimiterCharacter;
    property MinimumLength: Integer read GetMinimumLength;
    property NodeName: string read GetNodeName;
  end;

  IMarkdownRendererHook = interface
    ['{F0DAEDBD-1517-497F-94B0-62C0E2A2CF08}']
    function GetNodeName: string;
    procedure RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
    procedure RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
    property NodeName: string read GetNodeName;
  end;

  IMarkdownDocumentProcessor = interface
    ['{9B3E7A21-4C58-4F06-8D19-2A7C5E0B3F84}']
    procedure Process(const Document: IMarkdownDocument);
  end;

  IMarkdownPipeline = interface
    ['{F6A1136E-13B3-4EBF-81AF-20A3492E10E2}']
    function ToHtml(const Source: string): string;
    function Parse(const Source: string): IMarkdownDocument;
  end;

  IMarkdownPipelineBuilder = interface
    ['{82E72E24-F334-4BEE-AD72-2E146B40CEFB}']
    function UseCommonMark: IMarkdownPipelineBuilder;
    function UseGfm: IMarkdownPipelineBuilder;
    function Use(const Extension: IMarkdownExtension): IMarkdownPipelineBuilder;
    function XhtmlOutput: IMarkdownPipelineBuilder;
    function UnsafeHtml: IMarkdownPipelineBuilder;
    function UnsafeLinks: IMarkdownPipelineBuilder;
    function TagFilter: IMarkdownPipelineBuilder;
    function RegisterBlockParser(const Parser: IMarkdownBlockParser; const TriggerCharacters: string; const Priority: Integer): IMarkdownPipelineBuilder;
    function RegisterInlineParser(const Parser: IMarkdownInlineParser; const TriggerCharacters: string; const Priority: Integer): IMarkdownPipelineBuilder;
    function RegisterDelimiterProcessor(const Processor: IMarkdownDelimiterProcessor; const Priority: Integer): IMarkdownPipelineBuilder;
    function RegisterRendererHook(const Hook: IMarkdownRendererHook; const Priority: Integer): IMarkdownPipelineBuilder;
    function RegisterDocumentProcessor(const Processor: IMarkdownDocumentProcessor; const Priority: Integer): IMarkdownPipelineBuilder;
    function Build: IMarkdownPipeline;
  end;

implementation

end.
