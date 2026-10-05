unit Markdown4D.Extensions.Api.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.BlockOverride;

type
  [TestFixture]
  TExtensionDataChannelTests = class
  public
    [Test]
    procedure SetThenGet_ReturnsStoredInterface;

    [Test]
    procedure Get_UnknownKey_ReturnsFalse;

    [Test]
    procedure StoredData_LivesForDocumentLifetime;
  end;

  [TestFixture]
  TBlockOverrideRegistrationTests = class
  private
    const
      CodeBlockMarkdown = '```'#10'code'#10'```';
    class function LayoutWithOverride(const Markdown: string; const Handler: ILayoutBlockOverride;
                                      const Errors: IMarkdownExtensionErrorSink): IMarkdownDisplayList;
    class function ContainsTextRun(const DisplayList: IMarkdownDisplayList; const Text: string): Boolean;
    class function ContainsRectangleFilledWith(const DisplayList: IMarkdownDisplayList;
      const FillColor: TLayoutColor): Boolean;

  public
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Registry_HighestPriorityWins;

    [Test]
    procedure Registry_NoHandler_TryFindIsFalse;

    [Test]
    procedure Engine_AppliesRegisteredOverride;

    [Test]
    procedure Engine_FailingOverride_LaysOutBlockWithoutOverride;

    [Test]
    procedure Engine_FailingOverride_DropsWhatItAlreadyDrew;

    [Test]
    procedure Engine_FailingOverride_ReportsOverrideName;

    [Test]
    procedure Engine_FailingOverrideWithoutErrorSink_Raises;
  end;

  [TestFixture]
  TDocumentProcessorRegistryTests = class
  private
    const
      ProcessedMarkdown = 'text';

  public
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Process_FailingProcessor_ReportsRegisteredName;

    [Test]
    procedure Process_FailingProcessor_RunsTheOtherProcessors;

    [Test]
    procedure Process_FailingProcessorWithoutErrorSink_Raises;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Layout.Engine,
  Markdown4D.Theme,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Tests.FailingExtensions;

const
  UnreportedFailureMustRaise = 'Without an error sink nobody hears about the failure, so it must reach the caller';

type
  ITag = interface
    ['{B9A1F5C2-3D48-4E71-9A05-6C2E8B4D71F0}']
    function Value: Integer;
  end;

  TTag = class(TInterfacedObject, ITag)
  private
    FValue: Integer;
  public
    constructor Create(const AValue: Integer);
    function Value: Integer;
  end;

  TDummyBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  private
    FName: string;
  public
    const
      MarkerFillColor = TLayoutColor($FF123456);
      BlockHeight = 64.0;
    constructor Create(const AName: string);
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
  end;

  TCountingDocumentProcessor = class(TInterfacedObject, IMarkdownDocumentProcessor)
  private
    FCallCount: Integer;
  public
    procedure Process(const Document: IMarkdownDocument);
    property CallCount: Integer read FCallCount;
  end;

  TRecordingErrorSink = class(TInterfacedObject, IMarkdownExtensionErrorSink)
  private
    FExtension: string;
    FMessage: string;
  public
    procedure ExtensionFailed(const Extension: string; const Error: Exception);
    property Extension: string read FExtension;
    property Message: string read FMessage;
  end;

procedure TCountingDocumentProcessor.Process(const Document: IMarkdownDocument);
begin
  Inc(FCallCount);
end;

procedure TRecordingErrorSink.ExtensionFailed(const Extension: string; const Error: Exception);
begin
  FExtension := Extension;
  FMessage := Error.Message;
end;

constructor TTag.Create(const AValue: Integer);
begin
  inherited Create;

  FValue := AValue;
end;

function TTag.Value: Integer;
begin
  Result := FValue;
end;

constructor TDummyBlockOverride.Create(const AName: string);
begin
  inherited Create;

  FName := AName;
end;

function TDummyBlockOverride.GetName: string;
begin
  Result := FName;
end;

function TDummyBlockOverride.Handles(const Node: IMarkdownNode): Boolean;
begin
  Result := (Node.Kind = TMarkdownNodeKind.Paragraph);
end;

function TDummyBlockOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
begin
  Context.Canvas.FillRectangle(TLayoutRectF.Create(0, Top, Context.Width, Top + BlockHeight), MarkerFillColor);
  Result := BlockHeight;
end;

procedure TExtensionDataChannelTests.SetThenGet_ReturnsStoredInterface;
begin
  const Document = TMarkdown.Parse('paragraph');
  const Node = Document.Children[0];

  Node.SetExtensionData('sample', TTag.Create(42));

  var Retrieved: IInterface;
  Assert.IsTrue(Node.TryGetExtensionData('sample', Retrieved), 'Stored extension data must be retrievable');

  var Tag: ITag;
  Assert.IsTrue(Supports(Retrieved, ITag, Tag), 'Retrieved data must implement the stored interface');
  Assert.AreEqual(42, Tag.Value);
end;

procedure TExtensionDataChannelTests.Get_UnknownKey_ReturnsFalse;
begin
  const Document = TMarkdown.Parse('paragraph');
  const Node = Document.Children[0];

  var Retrieved: IInterface;
  Assert.IsFalse(Node.TryGetExtensionData('missing', Retrieved), 'Unknown keys must report absence');
end;

procedure TExtensionDataChannelTests.StoredData_LivesForDocumentLifetime;
begin
  const Document = TMarkdown.Parse('one'#10#10'two');
  const First = Document.Children[0];

  First.SetExtensionData('k', TTag.Create(7));

  var Retrieved: IInterface;
  Assert.IsTrue(First.TryGetExtensionData('k', Retrieved),
    'Extension data must remain attached for the lifetime of the node');
end;

procedure TBlockOverrideRegistrationTests.TearDown;
begin
  TMarkdownLayoutEngine.ClearBlockOverrides;
end;

procedure TBlockOverrideRegistrationTests.Registry_HighestPriorityWins;
begin
  const Document = TMarkdown.Parse('paragraph');
  const Node = Document.Children[0];

  const Low = TDummyBlockOverride.Create('low');
  const High = TDummyBlockOverride.Create('high');
  TLayoutBlockOverrideRegistry.Register(Low, 10);
  TLayoutBlockOverrideRegistry.Register(High, 900);

  var Winner: ILayoutBlockOverride;
  Assert.IsTrue(TLayoutBlockOverrideRegistry.TryFind(Node, Winner));
  Assert.AreEqual('high', Winner.Name, 'The highest-priority override must win');
end;

procedure TBlockOverrideRegistrationTests.Registry_NoHandler_TryFindIsFalse;
begin
  const Document = TMarkdown.Parse('# heading');
  const Node = Document.Children[0];

  TLayoutBlockOverrideRegistry.Register(TDummyBlockOverride.Create('paragraphs-only'), 100);

  var Handler: ILayoutBlockOverride;
  Assert.IsFalse(TLayoutBlockOverrideRegistry.TryFind(Node, Handler),
    'A heading must not be claimed by a paragraph-only override');
end;

procedure TBlockOverrideRegistrationTests.Engine_AppliesRegisteredOverride;
begin
  const Document = TMarkdown.Parse('paragraph');
  const Theme = TMarkdownTheme.CreateLight;
  try
    var Measurer: ITextMeasurer := TFakeTextMeasurer.Create;

    TMarkdownLayoutEngine.RegisterBlockOverride(TDummyBlockOverride.Create('paint'), 500);

    const DisplayList = TMarkdownLayoutEngine.LayoutDocument(Document, 400, Theme, Measurer);

    var FoundMarker := False;
    for var Index := 0 to DisplayList.ItemCount - 1 do
    begin
      var Rectangle: IDisplayRectangle;
      if Supports(DisplayList.Items[Index], IDisplayRectangle, Rectangle) and
        (Rectangle.FillColor = TDummyBlockOverride.MarkerFillColor) then
        FoundMarker := True;
    end;

    Assert.IsTrue(FoundMarker, 'The layout engine must delegate the block to its registered override');
  finally
    Theme.Free;
  end;
end;

procedure TBlockOverrideRegistrationTests.Engine_FailingOverride_LaysOutBlockWithoutOverride;
begin
  const Markdown = '# Title'#10#10'```'#10'code'#10'```'#10#10'After';

  const Errors: IMarkdownExtensionErrorSink = TRecordingErrorSink.Create;

  const DisplayList = LayoutWithOverride(Markdown, TFailingCodeBlockOverride.Create, Errors);

  Assert.IsTrue(ContainsTextRun(DisplayList, 'Title'), 'The heading before the failing block must be laid out');
  Assert.IsTrue(ContainsTextRun(DisplayList, 'code'), 'The failing block must fall back to its own layout');
  Assert.IsTrue(ContainsTextRun(DisplayList, 'After'), 'The paragraph after the failing block must be laid out');
end;

procedure TBlockOverrideRegistrationTests.Engine_FailingOverride_DropsWhatItAlreadyDrew;
begin
  const Errors: IMarkdownExtensionErrorSink = TRecordingErrorSink.Create;

  const DisplayList = LayoutWithOverride(CodeBlockMarkdown, TFailingCodeBlockOverride.Create, Errors);

  Assert.IsFalse(ContainsRectangleFilledWith(DisplayList, TFailingCodeBlockOverride.PartialFillColor),
    'What a failing override drew before it raised must not stay in the display list');
end;

procedure TBlockOverrideRegistrationTests.Engine_FailingOverride_ReportsOverrideName;
begin
  const Recorder = TRecordingErrorSink.Create;
  const Errors: IMarkdownExtensionErrorSink = Recorder;

  LayoutWithOverride(CodeBlockMarkdown, TFailingCodeBlockOverride.Create, Errors);

  Assert.AreEqual(TFailingCodeBlockOverride.OverrideName, Recorder.Extension);
  Assert.AreEqual(TFailingCodeBlockOverride.FailureMessage, Recorder.Message);
end;

procedure TBlockOverrideRegistrationTests.Engine_FailingOverrideWithoutErrorSink_Raises;
begin

  Assert.WillRaise(
    procedure
    begin
      LayoutWithOverride(CodeBlockMarkdown, TFailingCodeBlockOverride.Create, nil);
    end,
    EFailingExtension,
    UnreportedFailureMustRaise);
end;

class function TBlockOverrideRegistrationTests.LayoutWithOverride(const Markdown: string;
  const Handler: ILayoutBlockOverride; const Errors: IMarkdownExtensionErrorSink): IMarkdownDisplayList;
begin
  const Document = TMarkdown.Parse(Markdown);
  const Theme = TMarkdownTheme.CreateLight;
  try
    const Measurer: ITextMeasurer = TFakeTextMeasurer.Create;
    TMarkdownLayoutEngine.RegisterBlockOverride(Handler, 500);

    Result := TMarkdownLayoutEngine.LayoutDocument(Document, 400, Theme, Measurer, nil, Errors);
  finally
    Theme.Free;
  end;
end;

class function TBlockOverrideRegistrationTests.ContainsTextRun(const DisplayList: IMarkdownDisplayList;
  const Text: string): Boolean;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const IsMatch = (Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and (Run.Text = Text));
    if IsMatch then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

class function TBlockOverrideRegistrationTests.ContainsRectangleFilledWith(const DisplayList: IMarkdownDisplayList;
  const FillColor: TLayoutColor): Boolean;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Rectangle: IDisplayRectangle;
    const IsMatch = (Supports(DisplayList.Items[Index], IDisplayRectangle, Rectangle) and
                     (Rectangle.FillColor = FillColor));
    if IsMatch then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

procedure TDocumentProcessorRegistryTests.TearDown;
begin
  TLayoutDocumentProcessorRegistry.Clear;
end;

procedure TDocumentProcessorRegistryTests.Process_FailingProcessor_ReportsRegisteredName;
begin
  TLayoutDocumentProcessorRegistry.Register(TFailingDocumentProcessor.ProcessorName, TFailingDocumentProcessor.Create);
  const Recorder = TRecordingErrorSink.Create;
  const Errors: IMarkdownExtensionErrorSink = Recorder;

  const Document = TMarkdown.Parse(ProcessedMarkdown);
  TLayoutDocumentProcessorRegistry.Process(Document, Errors);

  Assert.AreEqual(TFailingDocumentProcessor.ProcessorName, Recorder.Extension);
  Assert.AreEqual(TFailingDocumentProcessor.FailureMessage, Recorder.Message);
end;

procedure TDocumentProcessorRegistryTests.Process_FailingProcessor_RunsTheOtherProcessors;
begin
  const Counter = TCountingDocumentProcessor.Create;
  const Processor: IMarkdownDocumentProcessor = Counter;
  TLayoutDocumentProcessorRegistry.Register(TFailingDocumentProcessor.ProcessorName, TFailingDocumentProcessor.Create);
  TLayoutDocumentProcessorRegistry.Register('counting-processor', Processor);
  const Errors: IMarkdownExtensionErrorSink = TRecordingErrorSink.Create;

  const Document = TMarkdown.Parse(ProcessedMarkdown);
  TLayoutDocumentProcessorRegistry.Process(Document, Errors);

  Assert.AreEqual(1, Counter.CallCount, 'A failing processor must not keep the next one from running');
end;

procedure TDocumentProcessorRegistryTests.Process_FailingProcessorWithoutErrorSink_Raises;
begin
  TLayoutDocumentProcessorRegistry.Register(TFailingDocumentProcessor.ProcessorName, TFailingDocumentProcessor.Create);

  const Document = TMarkdown.Parse(ProcessedMarkdown);

  Assert.WillRaise(
    procedure
    begin
      TLayoutDocumentProcessorRegistry.Process(Document, nil);
    end,
    EFailingExtension,
    UnreportedFailureMustRaise);
end;

end.
