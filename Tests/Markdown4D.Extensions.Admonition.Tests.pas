unit Markdown4D.Extensions.Admonition.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAdmonitionExtensionTests = class
  public
    [Test]
    procedure NoteAlert_TagsBlockQuoteWithKind;

    [Test]
    procedure WarningAlert_TagsBlockQuoteWithKind;

    [Test]
    procedure NestedAlert_IsTagged;

    [Test]
    procedure PlainBlockQuote_IsNotTagged;

    [Test]
    procedure UnknownMarker_IsNotTagged;

    [Test]
    procedure LowercaseMarker_IsNotTagged;

    [Test]
    procedure DocumentWithoutBlockQuotes_DoesNotCrash;

    [Test]
    procedure TaggedAlert_StillRendersAsBlockQuoteHtml;
  end;

  [TestFixture]
  TAdmonitionLayoutTests = class
  public
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Canvas_DrawsBannerRectangleAndKindText;

    [Test]
    procedure PlainBlockQuote_IsNotClaimed;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Pipeline,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Layout.Engine,
  Markdown4D.Theme,
  Markdown4D.Layout.FakeMeasurer;

type
  IAdmonitionTag = interface
    ['{4F1B8C2A-7D63-4E09-9A15-2C6E5B0D3A88}']
    function GetKind: string;
    property Kind: string read GetKind;
  end;

  TAdmonitionTag = class(TInterfacedObject, IAdmonitionTag)
  private
    FKind: string;

  public
    constructor Create(const Kind: string);
    function GetKind: string;
  end;

  TAdmonitionProcessor = class(TInterfacedObject, IMarkdownDocumentProcessor)
  private
    const
      MarkerOpen = '[!';
      MarkerClose = ']';
    class function TryMatchKind(const FirstLine: string; out Kind: string): Boolean; static;
    class function IsKnownKind(const Kind: string): Boolean; static;
    class function FirstParagraphLine(const BlockQuote: IMarkdownNode): string; static;
    class procedure TagBlockQuote(const BlockQuote: IMarkdownNode); static;

  public
    procedure Process(const Document: IMarkdownDocument);
  end;

  TAdmonitionExtension = class(TInterfacedObject, IMarkdownExtension)
  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

  TAdmonitionBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  public
    const
      OverrideName = 'admonition.banner';
      BannerHeight = 24.0;
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
  end;

const
  ExtensionDataKey = 'admonition';
  KnownKinds: array[0..4] of string = ('NOTE', 'TIP', 'IMPORTANT', 'WARNING', 'CAUTION');

constructor TAdmonitionTag.Create(const Kind: string);
begin
  inherited Create;

  FKind := Kind;
end;

function TAdmonitionTag.GetKind: string;
begin
  Result := FKind;
end;

procedure TAdmonitionExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterDocumentProcessor(TAdmonitionProcessor.Create, TMarkdownPriorities.ExtensionProcessor);
end;

procedure TAdmonitionProcessor.Process(const Document: IMarkdownDocument);
begin
  const Pending = TStack<IMarkdownNode>.Create;
  try
    for var Index := Document.ChildCount - 1 downto 0 do
    begin
      Pending.Push(Document.Children[Index]);
    end;

    while Pending.Count > 0 do
    begin
      const Current = Pending.Pop;

      if Current.Kind = TMarkdownNodeKind.BlockQuote then
        TagBlockQuote(Current);

      for var Index := Current.ChildCount - 1 downto 0 do
      begin
        Pending.Push(Current.Children[Index]);
      end;
    end;
  finally
    Pending.Free;
  end;
end;

class procedure TAdmonitionProcessor.TagBlockQuote(const BlockQuote: IMarkdownNode);
begin
  const FirstLine = FirstParagraphLine(BlockQuote);

  var Kind: string;
  if not TryMatchKind(FirstLine, Kind) then
    Exit;

  BlockQuote.SetExtensionData(ExtensionDataKey, TAdmonitionTag.Create(Kind));
end;

class function TAdmonitionProcessor.FirstParagraphLine(const BlockQuote: IMarkdownNode): string;
begin
  Result := '';

  if BlockQuote.ChildCount = 0 then
    Exit;

  const Paragraph = BlockQuote.Children[0];
  if Paragraph.Kind <> TMarkdownNodeKind.Paragraph then
    Exit;

  const Builder = TStringBuilder.Create;
  const Pending = TStack<IMarkdownNode>.Create;
  try
    for var Index := Paragraph.ChildCount - 1 downto 0 do
    begin
      Pending.Push(Paragraph.Children[Index]);
    end;

    while Pending.Count > 0 do
    begin
      const Current = Pending.Pop;

      const IsLineBreak = (Current.Kind = TMarkdownNodeKind.SoftLineBreak) or
        (Current.Kind = TMarkdownNodeKind.HardLineBreak);
      if IsLineBreak then
        Break;

      var Text: IMarkdownText;
      if Supports(Current, IMarkdownText, Text) then
        Builder.Append(Text.Literal)
      else
        for var Index := Current.ChildCount - 1 downto 0 do
        begin
          Pending.Push(Current.Children[Index]);
        end;
    end;

    Result := Builder.ToString;
  finally
    Pending.Free;
    Builder.Free;
  end;
end;

class function TAdmonitionProcessor.TryMatchKind(const FirstLine: string; out Kind: string): Boolean;
begin
  Kind := '';

  const Trimmed = FirstLine.Trim;
  const HasMarker = Trimmed.StartsWith(MarkerOpen) and Trimmed.EndsWith(MarkerClose);
  if not HasMarker then
    Exit(False);

  const Inner = Trimmed.Substring(Length(MarkerOpen), Length(Trimmed) - Length(MarkerOpen) - Length(MarkerClose));
  if not IsKnownKind(Inner) then
    Exit(False);

  Kind := Inner;
  Result := True;
end;

class function TAdmonitionProcessor.IsKnownKind(const Kind: string): Boolean;
begin
  for var Known in KnownKinds do
  begin
    if Known = Kind then
      Exit(True);
  end;

  Result := False;
end;

function BuildPipeline: IMarkdownPipeline;
begin
  Result := TMarkdownPipeline.Create.UseCommonMark.Use(TAdmonitionExtension.Create).Build;
end;

function FindFirstBlockQuote(const Document: IMarkdownDocument): IMarkdownNode;
begin
  Result := nil;

  for var Index := 0 to Document.ChildCount - 1 do
  begin
    if Document.Children[Index].Kind = TMarkdownNodeKind.BlockQuote then
      Exit(Document.Children[Index]);
  end;
end;

function TryGetAdmonitionKind(const Node: IMarkdownNode; out Kind: string): Boolean;
begin
  Kind := '';

  var Data: IInterface;
  if not Node.TryGetExtensionData(ExtensionDataKey, Data) then
    Exit(False);

  var Tag: IAdmonitionTag;
  Result := Supports(Data, IAdmonitionTag, Tag);
  if Result then
    Kind := Tag.Kind;
end;

procedure TAdmonitionExtensionTests.NoteAlert_TagsBlockQuoteWithKind;
begin
  const Document = BuildPipeline.Parse('> [!NOTE]'#10'> Body text here.');
  const BlockQuote = FindFirstBlockQuote(Document);
  Assert.IsNotNull(BlockQuote, 'The alert must parse into a block quote');

  var Kind: string;
  Assert.IsTrue(TryGetAdmonitionKind(BlockQuote, Kind), 'A GitHub-style note alert must be tagged');
  Assert.AreEqual('NOTE', Kind);
end;

procedure TAdmonitionExtensionTests.WarningAlert_TagsBlockQuoteWithKind;
begin
  const Document = BuildPipeline.Parse('> [!WARNING]'#10'> Careful here.');
  const BlockQuote = FindFirstBlockQuote(Document);

  var Kind: string;
  Assert.IsTrue(TryGetAdmonitionKind(BlockQuote, Kind));
  Assert.AreEqual('WARNING', Kind);
end;

procedure TAdmonitionExtensionTests.NestedAlert_IsTagged;
begin
  const Document = BuildPipeline.Parse('- outer'#10#10'  > [!TIP]'#10'  > Nested advice.');

  var Found := False;
  const Pending = TStack<IMarkdownNode>.Create;
  try
    Pending.Push(Document);

    while Pending.Count > 0 do
    begin
      const Current = Pending.Pop;

      if Current.Kind = TMarkdownNodeKind.BlockQuote then
      begin
        var Kind: string;
        if TryGetAdmonitionKind(Current, Kind) and (Kind = 'TIP') then
          Found := True;
      end;

      for var Index := 0 to Current.ChildCount - 1 do
      begin
        Pending.Push(Current.Children[Index]);
      end;
    end;
  finally
    Pending.Free;
  end;

  Assert.IsTrue(Found, 'A nested alert block quote must also be tagged by the document processor');
end;

procedure TAdmonitionExtensionTests.PlainBlockQuote_IsNotTagged;
begin
  const Document = BuildPipeline.Parse('> Just a quote.');
  const BlockQuote = FindFirstBlockQuote(Document);

  var Kind: string;
  Assert.IsFalse(TryGetAdmonitionKind(BlockQuote, Kind), 'A plain block quote must not be tagged as an admonition');
end;

procedure TAdmonitionExtensionTests.UnknownMarker_IsNotTagged;
begin
  const Document = BuildPipeline.Parse('> [!BOGUS]'#10'> Body.');
  const BlockQuote = FindFirstBlockQuote(Document);

  var Kind: string;
  Assert.IsFalse(TryGetAdmonitionKind(BlockQuote, Kind), 'An unknown marker must be left untagged');
end;

procedure TAdmonitionExtensionTests.LowercaseMarker_IsNotTagged;
begin
  const Document = BuildPipeline.Parse('> [!note]'#10'> Body.');
  const BlockQuote = FindFirstBlockQuote(Document);

  var Kind: string;
  Assert.IsFalse(TryGetAdmonitionKind(BlockQuote, Kind), 'Alert markers are case sensitive and must be uppercase');
end;

procedure TAdmonitionExtensionTests.DocumentWithoutBlockQuotes_DoesNotCrash;
begin
  const Html = BuildPipeline.ToHtml('# Heading'#10#10'A paragraph with **bold** text.');

  Assert.AreEqual('<h1>Heading</h1>'#10'<p>A paragraph with <strong>bold</strong> text.</p>'#10, Html,
    'The admonition extension must not alter documents that contain no block quotes');
end;

procedure TAdmonitionExtensionTests.TaggedAlert_StillRendersAsBlockQuoteHtml;
begin
  const Html = BuildPipeline.ToHtml('> [!NOTE]'#10'> Remember this.');

  Assert.AreEqual('<blockquote>'#10'<p>[!NOTE]'#10'Remember this.</p>'#10'</blockquote>'#10, Html,
    'Tagging via extension data must leave the rendered HTML unchanged');
end;

function TAdmonitionBlockOverride.GetName: string;
begin
  Result := OverrideName;
end;

function TAdmonitionBlockOverride.Handles(const Node: IMarkdownNode): Boolean;
begin
  const IsBlockQuote = (Node.Kind = TMarkdownNodeKind.BlockQuote);

  var Kind: string;
  Result := IsBlockQuote and TryGetAdmonitionKind(Node, Kind);
end;

function TAdmonitionBlockOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
begin
  var Kind: string;
  if not TryGetAdmonitionKind(Node, Kind) then
    Exit(0);

  const Canvas = Context.Canvas;
  const Bounds = TLayoutRectF.Create(0, Top, Context.Width, Top + BannerHeight);

  Canvas.FillAndStrokeRectangle(Bounds, Context.Theme.CodeBackgroundColor, Context.Theme.LinkColor, 1);
  Canvas.DrawText(TLayoutPointF.Create(0, Top), Kind, Context.Theme.BaseFont, Context.Theme.TextColor);

  Result := BannerHeight;
end;

procedure TAdmonitionLayoutTests.TearDown;
begin
  TMarkdownLayoutEngine.ClearBlockOverrides;
end;

procedure TAdmonitionLayoutTests.Canvas_DrawsBannerRectangleAndKindText;
begin
  const Document = BuildPipeline.Parse('> [!NOTE]'#10'> Body text.');
  const Theme = TMarkdownTheme.CreateLight;
  try
    var Measurer: ITextMeasurer := TFakeTextMeasurer.Create;

    TMarkdownLayoutEngine.RegisterBlockOverride(TAdmonitionBlockOverride.Create, 500);

    const DisplayList = TMarkdownLayoutEngine.LayoutDocument(Document, 400, Theme, Measurer);

    var HasBanner := False;
    var HasKindText := False;
    for var Index := 0 to DisplayList.ItemCount - 1 do
    begin
      const Item = DisplayList.Items[Index];

      if Supports(Item, IDisplayRectangle) then
        HasBanner := True;

      var Run: IDisplayTextRun;
      if Supports(Item, IDisplayTextRun, Run) and (Run.Text = 'NOTE') then
        HasKindText := True;
    end;

    Assert.IsTrue(HasBanner, 'The admonition override must draw a banner rectangle onto the canvas');
    Assert.IsTrue(HasKindText, 'The admonition override must draw the alert kind as a text run');
  finally
    Theme.Free;
  end;
end;

procedure TAdmonitionLayoutTests.PlainBlockQuote_IsNotClaimed;
begin
  const Document = BuildPipeline.Parse('> Just a quote.');
  const BlockQuote = FindFirstBlockQuote(Document);

  const Override = TAdmonitionBlockOverride.Create;
  Assert.IsFalse(Override.Handles(BlockQuote),
    'An untagged block quote must not be claimed by the admonition override');
end;

end.
