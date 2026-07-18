unit Markdown4D.Extensions.V11.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkdownPrioritiesTests = class
  public
    [Test]
    procedure BlockStartConstants_MatchCommonMarkOrdering;

    [Test]
    procedure GenericBands_AreStrictlyDescending;

    [Test]
    procedure ExtensionProcessor_OutranksRenderer;
  end;

  [TestFixture]
  THtmlWriterAttributeTests = class
  public
    [Test]
    procedure WriteAttribute_EscapesSpecialCharacters;

    [Test]
    procedure EscapeAttribute_EscapesAmpersand;
  end;

  [TestFixture]
  TTocEnumeratorTests = class
  public
    [Test]
    procedure GetEnumerator_YieldsTopLevelEntriesInOrder;

    [Test]
    procedure GetEnumerator_CountMatchesEntryCount;
  end;

  [TestFixture]
  TExtensionCanvasTests = class
  public
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Canvas_DrawsPrimitivesIntoDisplayList;

    [Test]
    procedure Canvas_ReturnsStableInstance;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Pipeline,
  Markdown4D.Toc,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Layout.Engine,
  Markdown4D.Theme,
  Markdown4D.Layout.FakeMeasurer;

type
  TAttributeDelimiterProcessor = class(TInterfacedObject, IMarkdownDelimiterProcessor)
  public
    const
      NodeName = 'attrspan';
    function GetDelimiterCharacter: Char;
    function GetMinimumLength: Integer;
    function GetNodeName: string;
  end;

  TAttributeRendererHook = class(TInterfacedObject, IMarkdownRendererHook)
  private
    FMode: Integer;
  public
    constructor Create(const Mode: Integer);
    function GetNodeName: string;
    procedure RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
    procedure RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
  end;

  TCanvasBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  public
    const
      OverrideName = 'markdown4d.test.canvas';
      BlockHeight = 40.0;
      FillColor = TLayoutColor($FF203040);
      PolygonColor = TLayoutColor($FF607080);
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
  end;

  TCanvasIdentityOverride = class(TInterfacedObject, ILayoutBlockOverride)
  public
    FirstCanvas: IExtensionCanvas;
    SecondCanvas: IExtensionCanvas;
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
  end;

function TAttributeDelimiterProcessor.GetDelimiterCharacter: Char;
begin
  Result := '^';
end;

function TAttributeDelimiterProcessor.GetMinimumLength: Integer;
begin
  Result := 2;
end;

function TAttributeDelimiterProcessor.GetNodeName: string;
begin
  Result := NodeName;
end;

constructor TAttributeRendererHook.Create(const Mode: Integer);
begin
  inherited Create;

  FMode := Mode;
end;

function TAttributeRendererHook.GetNodeName: string;
begin
  Result := TAttributeDelimiterProcessor.NodeName;
end;

procedure TAttributeRendererHook.RenderEnter(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
begin
  if FMode = 0 then
  begin
    Writer.WriteRaw('<span');
    Writer.WriteAttribute('data-x', 'a"b<c>&');
    Writer.WriteRaw('>');
  end
  else
    Writer.WriteRaw(Writer.EscapeAttribute('a&b'));
end;

procedure TAttributeRendererHook.RenderLeave(const Writer: IMarkdownHtmlWriter; const Node: IMarkdownNode);
begin
  if FMode = 0 then
    Writer.WriteRaw('</span>');
end;

function TCanvasBlockOverride.GetName: string;
begin
  Result := OverrideName;
end;

function TCanvasBlockOverride.Handles(const Node: IMarkdownNode): Boolean;
begin
  Result := (Node.Kind = TMarkdownNodeKind.Paragraph);
end;

function TCanvasBlockOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
begin
  const Canvas = Context.Canvas;
  const Font = TMarkdownFontStyle.Create('Arial', 12);

  Canvas.SaveState;
  Canvas.SetClip(TLayoutRectF.Create(0, Top, Context.Width, Top + BlockHeight));
  Canvas.FillRectangle(TLayoutRectF.Create(0, Top, Context.Width, Top + BlockHeight), FillColor);
  Canvas.DrawText(TLayoutPointF.Create(0, Top), 'canvas', Font, FillColor);
  Canvas.DrawLine(TLayoutPointF.Create(0, Top), TLayoutPointF.Create(Context.Width, Top), FillColor, 1);
  Canvas.FillPolygon([TLayoutPointF.Create(0, Top), TLayoutPointF.Create(10, Top),
    TLayoutPointF.Create(5, Top + 10)], PolygonColor);
  Canvas.FillWedge(TLayoutPointF.Create(20, Top + 20), 10, 0, 0, 90, PolygonColor);
  Canvas.DrawImage(TLayoutRectF.Create(0, Top, 10, Top + 10), 'img.png', 'alt');
  Canvas.RestoreState;

  Result := BlockHeight;
end;

function TCanvasIdentityOverride.GetName: string;
begin
  Result := 'markdown4d.test.canvas.identity';
end;

function TCanvasIdentityOverride.Handles(const Node: IMarkdownNode): Boolean;
begin
  Result := (Node.Kind = TMarkdownNodeKind.Paragraph);
end;

function TCanvasIdentityOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
begin
  FirstCanvas := Context.Canvas;
  SecondCanvas := Context.Canvas;

  Result := 0;
end;

procedure TMarkdownPrioritiesTests.BlockStartConstants_MatchCommonMarkOrdering;
begin
  Assert.AreEqual(900, TMarkdownPriorities.BlockQuoteStart);
  Assert.AreEqual(550, TMarkdownPriorities.IndentedCodeStart);

  var BlockStarts: TArray<Integer> := [TMarkdownPriorities.BlockQuoteStart, TMarkdownPriorities.AtxHeadingStart,
    TMarkdownPriorities.FencedCodeStart, TMarkdownPriorities.HtmlBlockStart, TMarkdownPriorities.SetextHeadingStart,
    TMarkdownPriorities.ThematicBreakStart, TMarkdownPriorities.ListItemStart, TMarkdownPriorities.IndentedCodeStart];

  for var Index := 1 to High(BlockStarts) do
  begin
    Assert.IsTrue(BlockStarts[Index] < BlockStarts[Index - 1], 'CommonMark block starts must strictly descend');
  end;
end;

procedure TMarkdownPrioritiesTests.GenericBands_AreStrictlyDescending;
begin
  var Bands: TArray<Integer> := [TMarkdownPriorities.Highest, TMarkdownPriorities.High, TMarkdownPriorities.Normal,
    TMarkdownPriorities.Low, TMarkdownPriorities.Lowest];

  for var Index := 1 to High(Bands) do
  begin
    Assert.IsTrue(Bands[Index] < Bands[Index - 1], 'Generic priority bands must strictly descend');
  end;
end;

procedure TMarkdownPrioritiesTests.ExtensionProcessor_OutranksRenderer;
begin
  var Values: TArray<Integer> := [TMarkdownPriorities.ExtensionProcessor, TMarkdownPriorities.ExtensionRenderer];

  Assert.IsTrue(Values[0] > Values[1], 'Document processors must run before renderer hooks');
end;

procedure THtmlWriterAttributeTests.WriteAttribute_EscapesSpecialCharacters;
begin
  const Builder = TMarkdownPipeline.Create.UseCommonMark;
  Builder.RegisterDelimiterProcessor(TAttributeDelimiterProcessor.Create, 50);
  Builder.RegisterRendererHook(TAttributeRendererHook.Create(0), 90);

  const Pipeline = Builder.Build;
  Assert.AreEqual('<p><span data-x="a&quot;b&lt;c&gt;&amp;">x</span></p>'#10, Pipeline.ToHtml('^^x^^'));
end;

procedure THtmlWriterAttributeTests.EscapeAttribute_EscapesAmpersand;
begin
  const Builder = TMarkdownPipeline.Create.UseCommonMark;
  Builder.RegisterDelimiterProcessor(TAttributeDelimiterProcessor.Create, 50);
  Builder.RegisterRendererHook(TAttributeRendererHook.Create(1), 90);

  const Pipeline = Builder.Build;
  Assert.AreEqual('<p>a&amp;bx</p>'#10, Pipeline.ToHtml('^^x^^'));
end;

procedure TTocEnumeratorTests.GetEnumerator_YieldsTopLevelEntriesInOrder;
begin
  const Document = TMarkdown.Parse('# Alpha'#10#10'# Beta'#10#10'## Gamma');
  const Toc = TMarkdownToc.FromDocument(Document);

  const Captions = TList<string>.Create;
  try
    for var Entry in Toc do
    begin
      Captions.Add(Entry.Caption);
    end;

    Assert.AreEqual('Alpha,Beta', string.Join(',', Captions.ToArray),
      'Enumeration must yield only top-level entries in document order');
  finally
    Captions.Free;
  end;
end;

procedure TTocEnumeratorTests.GetEnumerator_CountMatchesEntryCount;
begin
  const Document = TMarkdown.Parse('# One'#10#10'# Two'#10#10'# Three');
  const Toc = TMarkdownToc.FromDocument(Document);

  var Counted := 0;
  for var Entry in Toc do
  begin
    Assert.IsNotEmpty(Entry.Caption);
    Inc(Counted);
  end;

  Assert.AreEqual(Toc.EntryCount, Counted);
end;

procedure TExtensionCanvasTests.TearDown;
begin
  TMarkdownLayoutEngine.ClearBlockOverrides;
end;

procedure TExtensionCanvasTests.Canvas_DrawsPrimitivesIntoDisplayList;
begin
  const Document = TMarkdown.Parse('paragraph');
  const Theme = TMarkdownTheme.CreateLight;
  try
    var Measurer: ITextMeasurer := TFakeTextMeasurer.Create;

    TMarkdownLayoutEngine.RegisterBlockOverride(TCanvasBlockOverride.Create, 500);

    const DisplayList = TMarkdownLayoutEngine.LayoutDocument(Document, 400, Theme, Measurer);

    var HasRectangle := False;
    var HasText := False;
    var HasLine := False;
    var HasPolygon := False;
    var HasWedge := False;
    var HasImage := False;

    for var Index := 0 to DisplayList.ItemCount - 1 do
    begin
      const Item = DisplayList.Items[Index];
      if Supports(Item, IDisplayRectangle) then
        HasRectangle := True;
      if Supports(Item, IDisplayTextRun) then
        HasText := True;
      if Supports(Item, IDisplayLine) then
        HasLine := True;
      if Supports(Item, IDisplayPolygon) then
        HasPolygon := True;
      if Supports(Item, IDisplayWedge) then
        HasWedge := True;
      if Supports(Item, IDisplayImage) then
        HasImage := True;
    end;

    Assert.IsTrue(HasRectangle, 'Canvas.FillRectangle must produce a rectangle item');
    Assert.IsTrue(HasText, 'Canvas.DrawText must produce a text run item');
    Assert.IsTrue(HasLine, 'Canvas.DrawLine must produce a line item');
    Assert.IsTrue(HasPolygon, 'Canvas.FillPolygon must produce a polygon item');
    Assert.IsTrue(HasWedge, 'Canvas.FillWedge must produce a wedge item');
    Assert.IsTrue(HasImage, 'Canvas.DrawImage must produce an image item');
  finally
    Theme.Free;
  end;
end;

procedure TExtensionCanvasTests.Canvas_ReturnsStableInstance;
var
  First: IExtensionCanvas;
  Second: IExtensionCanvas;
begin
  const Document = TMarkdown.Parse('paragraph');
  const Theme = TMarkdownTheme.CreateLight;
  try
    var Measurer: ITextMeasurer := TFakeTextMeasurer.Create;

    const Probe = TCanvasIdentityOverride.Create;
    TMarkdownLayoutEngine.RegisterBlockOverride(Probe, 500);

    TMarkdownLayoutEngine.LayoutDocument(Document, 400, Theme, Measurer);

    First := Probe.FirstCanvas;
    Second := Probe.SecondCanvas;
    Assert.IsNotNull(First);
    Assert.IsTrue(First = Second, 'Repeated Canvas access must return the same instance');
  finally
    Theme.Free;
  end;
end;

end.
