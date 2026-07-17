unit Markdown4D.Extensions.Api.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

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
  public
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Registry_HighestPriorityWins;

    [Test]
    procedure Registry_NoHandler_TryFindIsFalse;

    [Test]
    procedure Engine_AppliesRegisteredOverride;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Theme,
  Markdown4D.Layout.FakeMeasurer;

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
  Context.EmitRectangle(TLayoutRectF.Create(0, Top, Context.Width, Top + BlockHeight), MarkerFillColor, 0, 0);
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

end.
