unit Markdown4D.Pipeline.Configuration;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Defaults,
  System.Generics.Collections,
  Markdown4D.Extensions.Interfaces;

type
  TMarkdownRendererOptions = record
    AllowRawHtml: Boolean;
    ApplyTagFilter: Boolean;
    XhtmlOutput: Boolean;
    class function SafeDefaults: TMarkdownRendererOptions; static;
    class function SpecDefaults: TMarkdownRendererOptions; static;
  end;

  TMarkdownBlockParserRegistration = record
    Parser: IMarkdownBlockParser;
    TriggerCharacters: string;
    Priority: Integer;
    Ordinal: Integer;
  end;

  TMarkdownInlineParserRegistration = record
    Parser: IMarkdownInlineParser;
    TriggerCharacters: string;
    Priority: Integer;
    Ordinal: Integer;
  end;

  TMarkdownDelimiterProcessorRegistration = record
    Processor: IMarkdownDelimiterProcessor;
    Priority: Integer;
    Ordinal: Integer;
  end;

  TMarkdownRendererHookRegistration = record
    Hook: IMarkdownRendererHook;
    Priority: Integer;
    Ordinal: Integer;
  end;

  TMarkdownDocumentProcessorRegistration = record
    Processor: IMarkdownDocumentProcessor;
    Priority: Integer;
    Ordinal: Integer;
  end;

  TMarkdownPipelineConfiguration = class
  private
    FBlockParsers: TList<TMarkdownBlockParserRegistration>;
    FInlineParsers: TList<TMarkdownInlineParserRegistration>;
    FDelimiterProcessors: TDictionary<Char, IMarkdownDelimiterProcessor>;
    FRendererHooks: TDictionary<string, IMarkdownRendererHook>;
    FDocumentProcessors: TList<IMarkdownDocumentProcessor>;
    FRendererOptions: TMarkdownRendererOptions;
    procedure CopyBlockParsers(const Registrations: TList<TMarkdownBlockParserRegistration>);
    procedure CopyInlineParsers(const Registrations: TList<TMarkdownInlineParserRegistration>);
    procedure ResolveDelimiterProcessors(const Registrations: TList<TMarkdownDelimiterProcessorRegistration>);
    procedure ResolveRendererHooks(const Registrations: TList<TMarkdownRendererHookRegistration>);
    procedure ResolveDocumentProcessors(const Registrations: TList<TMarkdownDocumentProcessorRegistration>);
    class function ComparePriorities(const LeftPriority, LeftOrdinal, RightPriority, RightOrdinal: Integer): Integer;

  public
    constructor Create(const BlockParsers: TList<TMarkdownBlockParserRegistration>;
                       const InlineParsers: TList<TMarkdownInlineParserRegistration>;
                       const DelimiterProcessors: TList<TMarkdownDelimiterProcessorRegistration>;
                       const RendererHooks: TList<TMarkdownRendererHookRegistration>;
                       const DocumentProcessors: TList<TMarkdownDocumentProcessorRegistration>;
                       const RendererOptions: TMarkdownRendererOptions);
    destructor Destroy; override;
    property BlockParsers: TList<TMarkdownBlockParserRegistration> read FBlockParsers;
    property InlineParsers: TList<TMarkdownInlineParserRegistration> read FInlineParsers;
    property DelimiterProcessors: TDictionary<Char, IMarkdownDelimiterProcessor> read FDelimiterProcessors;
    property RendererHooks: TDictionary<string, IMarkdownRendererHook> read FRendererHooks;
    property DocumentProcessors: TList<IMarkdownDocumentProcessor> read FDocumentProcessors;
    property RendererOptions: TMarkdownRendererOptions read FRendererOptions;
  end;

  IMarkdownPipelineConfigurationProvider = interface
    ['{B7E3A2C1-4D5F-4E86-9A17-3C2B8D64F0A9}']
    function GetConfiguration: TMarkdownPipelineConfiguration;
    property Configuration: TMarkdownPipelineConfiguration read GetConfiguration;
  end;

implementation

type
  TRegistrationOrder = record
    Priority: Integer;
    Ordinal: Integer;
  end;

  TRegistrationOrderSelector<T> = reference to function(const Registration: T): TRegistrationOrder;

  TRegistrationComparer = class
    class function ByPriority<T>(const OrderOf: TRegistrationOrderSelector<T>): IComparer<T>; static;
  end;

class function TRegistrationComparer.ByPriority<T>(const OrderOf: TRegistrationOrderSelector<T>): IComparer<T>;
begin
  Result := TComparer<T>.Construct(
    function(const Left, Right: T): Integer
    begin
      const LeftOrder = OrderOf(Left);
      const RightOrder = OrderOf(Right);
      Result := TMarkdownPipelineConfiguration.ComparePriorities(
        LeftOrder.Priority, LeftOrder.Ordinal, RightOrder.Priority, RightOrder.Ordinal);
    end);
end;

class function TMarkdownRendererOptions.SafeDefaults: TMarkdownRendererOptions;
begin
  Result := Default(TMarkdownRendererOptions);
end;

class function TMarkdownRendererOptions.SpecDefaults: TMarkdownRendererOptions;
begin
  Result := Default(TMarkdownRendererOptions);
  Result.AllowRawHtml := True;
end;

constructor TMarkdownPipelineConfiguration.Create(const BlockParsers: TList<TMarkdownBlockParserRegistration>;
                                                  const InlineParsers: TList<TMarkdownInlineParserRegistration>;
                                                  const DelimiterProcessors: TList<TMarkdownDelimiterProcessorRegistration>;
                                                  const RendererHooks: TList<TMarkdownRendererHookRegistration>;
                                                  const DocumentProcessors: TList<TMarkdownDocumentProcessorRegistration>;
                                                  const RendererOptions: TMarkdownRendererOptions);
begin
  inherited Create;

  FBlockParsers := TList<TMarkdownBlockParserRegistration>.Create;
  FInlineParsers := TList<TMarkdownInlineParserRegistration>.Create;
  FDelimiterProcessors := TDictionary<Char, IMarkdownDelimiterProcessor>.Create;
  FRendererHooks := TDictionary<string, IMarkdownRendererHook>.Create;
  FDocumentProcessors := TList<IMarkdownDocumentProcessor>.Create;
  FRendererOptions := RendererOptions;

  CopyBlockParsers(BlockParsers);
  CopyInlineParsers(InlineParsers);
  ResolveDelimiterProcessors(DelimiterProcessors);
  ResolveRendererHooks(RendererHooks);
  ResolveDocumentProcessors(DocumentProcessors);
end;

destructor TMarkdownPipelineConfiguration.Destroy;
begin
  FDocumentProcessors.Free;
  FRendererHooks.Free;
  FDelimiterProcessors.Free;
  FInlineParsers.Free;
  FBlockParsers.Free;

  inherited Destroy;
end;

procedure TMarkdownPipelineConfiguration.CopyBlockParsers(const Registrations: TList<TMarkdownBlockParserRegistration>);
begin
  FBlockParsers.AddRange(Registrations);

  FBlockParsers.Sort(TRegistrationComparer.ByPriority<TMarkdownBlockParserRegistration>(
    function(const Registration: TMarkdownBlockParserRegistration): TRegistrationOrder
    begin
      Result.Priority := Registration.Priority;
      Result.Ordinal := Registration.Ordinal;
    end));
end;

procedure TMarkdownPipelineConfiguration.CopyInlineParsers(const Registrations: TList<TMarkdownInlineParserRegistration>);
begin
  FInlineParsers.AddRange(Registrations);

  FInlineParsers.Sort(TRegistrationComparer.ByPriority<TMarkdownInlineParserRegistration>(
    function(const Registration: TMarkdownInlineParserRegistration): TRegistrationOrder
    begin
      Result.Priority := Registration.Priority;
      Result.Ordinal := Registration.Ordinal;
    end));
end;

procedure TMarkdownPipelineConfiguration.ResolveDelimiterProcessors(const Registrations: TList<TMarkdownDelimiterProcessorRegistration>);
begin
  const Sorted = TList<TMarkdownDelimiterProcessorRegistration>.Create;
  try
    Sorted.AddRange(Registrations);
    Sorted.Sort(TRegistrationComparer.ByPriority<TMarkdownDelimiterProcessorRegistration>(
      function(const Registration: TMarkdownDelimiterProcessorRegistration): TRegistrationOrder
      begin
        Result.Priority := Registration.Priority;
        Result.Ordinal := Registration.Ordinal;
      end));

    for var Registration in Sorted do
    begin
      const DelimiterCharacter = Registration.Processor.DelimiterCharacter;

      if not FDelimiterProcessors.ContainsKey(DelimiterCharacter) then
        FDelimiterProcessors.Add(DelimiterCharacter, Registration.Processor);
    end;
  finally
    Sorted.Free;
  end;
end;

procedure TMarkdownPipelineConfiguration.ResolveRendererHooks(const Registrations: TList<TMarkdownRendererHookRegistration>);
begin
  const Sorted = TList<TMarkdownRendererHookRegistration>.Create;
  try
    Sorted.AddRange(Registrations);
    Sorted.Sort(TRegistrationComparer.ByPriority<TMarkdownRendererHookRegistration>(
      function(const Registration: TMarkdownRendererHookRegistration): TRegistrationOrder
      begin
        Result.Priority := Registration.Priority;
        Result.Ordinal := Registration.Ordinal;
      end));

    for var Registration in Sorted do
    begin
      const NodeName = Registration.Hook.NodeName;

      if not FRendererHooks.ContainsKey(NodeName) then
        FRendererHooks.Add(NodeName, Registration.Hook);
    end;
  finally
    Sorted.Free;
  end;
end;

procedure TMarkdownPipelineConfiguration.ResolveDocumentProcessors(const Registrations: TList<TMarkdownDocumentProcessorRegistration>);
begin
  const Sorted = TList<TMarkdownDocumentProcessorRegistration>.Create;
  try
    Sorted.AddRange(Registrations);
    Sorted.Sort(TRegistrationComparer.ByPriority<TMarkdownDocumentProcessorRegistration>(
      function(const Registration: TMarkdownDocumentProcessorRegistration): TRegistrationOrder
      begin
        Result.Priority := Registration.Priority;
        Result.Ordinal := Registration.Ordinal;
      end));

    for var Registration in Sorted do
    begin
      FDocumentProcessors.Add(Registration.Processor);
    end;
  finally
    Sorted.Free;
  end;
end;

class function TMarkdownPipelineConfiguration.ComparePriorities(const LeftPriority, LeftOrdinal, RightPriority,
                                                                RightOrdinal: Integer): Integer;
begin
  Result := RightPriority - LeftPriority;

  const SamePriority = (Result = 0);
  if SamePriority then
    Result := LeftOrdinal - RightOrdinal;
end;

end.
