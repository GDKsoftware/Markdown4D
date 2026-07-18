unit Markdown4D.Viewer.Extensions.Cluster1.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Theme,
  Markdown4D.Viewer.Model;

type
  [TestFixture]
  TViewerExtensionCachingTests = class
  private
    const
      ViewportWidth = 480.0;
      ViewportHeight = 360.0;
      FlushInterval = 100;
      StartTime = 1000;
      ChartPie =
        '```chart'#10 +
        '{"type":"chart","data":{"type":"pie","data":{"labels":["A","B","C"],"datasets":[{"data":[1,2,3]}]}}}'#10 +
        '```'#10#10 +
        'after';
      MermaidPieClosed =
        '```mermaid'#10 +
        'pie title Pets'#10 +
        '    "Dogs" : 3'#10 +
        '    "Cats" : 2'#10 +
        '```'#10#10 +
        'after';
      MermaidPieOpen =
        '```mermaid'#10 +
        'pie title Pets'#10 +
        '    "Dogs" : 3'#10 +
        '    "Cats" : 2';
      MermaidFenceClose = #10'```'#10#10'after';
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FModel: TMarkdownViewerModel;
    function WedgeCount: Integer;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure ChartFence_InViewerPath_RendersWedgesFromCachedModel;

    [Test]
    procedure MermaidClosedFence_InViewerPath_RendersWedgesFromCachedModel;

    [Test]
    procedure MermaidOpenFence_InViewerPath_RendersNoDiagram;

    [Test]
    procedure StreamingFenceClose_PromotesCodeBlockToDiagram;

    [Test]
    procedure ReopeningFence_ByMutation_DropsDiagram;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.BlockOverride,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Extensions.Chart,
  Markdown4D.Extensions.Chart.BlockOverride,
  Markdown4D.Extensions.Mermaid,
  Markdown4D.Extensions.Mermaid.BlockOverride;

procedure TViewerExtensionCachingTests.Setup;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FTheme.ContentPadding := 0;
  FMeasurer := TFakeTextMeasurer.Create;
  FModel := TMarkdownViewerModel.Create(FTheme, FMeasurer);

  TMarkdownLayoutEngine.RegisterBlockOverride(TChartBlockOverride.Create, TChartBlockOverride.OverridePriority);
  TLayoutDocumentProcessorRegistry.Register(TChartExtension.CreateDocumentProcessor);

  TMarkdownLayoutEngine.RegisterBlockOverride(TMermaidBlockOverride.Create, TMermaidBlockOverride.OverridePriority);
  TLayoutDocumentProcessorRegistry.Register(TMermaidExtension.CreateDocumentProcessor);

  FModel.SetViewport(ViewportWidth, ViewportHeight);
end;

procedure TViewerExtensionCachingTests.TearDown;
begin
  TMarkdownLayoutEngine.ClearBlockOverrides;

  FModel.Free;
  FModel := nil;

  FMeasurer := nil;

  FTheme.Free;
  FTheme := nil;
end;

function TViewerExtensionCachingTests.WedgeCount: Integer;
begin
  Result := 0;

  const DisplayList = FModel.DisplayList;
  if DisplayList = nil then
    Exit;

  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Wedge: IDisplayWedge;
    if Supports(DisplayList.Items[Index], IDisplayWedge, Wedge) then
      Inc(Result);
  end;
end;

procedure TViewerExtensionCachingTests.ChartFence_InViewerPath_RendersWedgesFromCachedModel;
begin
  FModel.Text := ChartPie;

  Assert.AreEqual(3, WedgeCount,
    'The viewer must render a chart pie from the model cached by the document processor, not a fallback reparse');
end;

procedure TViewerExtensionCachingTests.MermaidClosedFence_InViewerPath_RendersWedgesFromCachedModel;
begin
  FModel.Text := MermaidPieClosed;

  Assert.IsTrue(WedgeCount > 0,
    'The viewer must render a mermaid pie from the model cached by the document processor');
end;

procedure TViewerExtensionCachingTests.MermaidOpenFence_InViewerPath_RendersNoDiagram;
begin
  FModel.Text := MermaidPieOpen;

  Assert.AreEqual(0, WedgeCount,
    'An open mermaid fence must not be cached and must fall back to a plain code block');
end;

procedure TViewerExtensionCachingTests.StreamingFenceClose_PromotesCodeBlockToDiagram;
begin
  FModel.FlushIntervalMilliseconds := FlushInterval;
  FModel.Text := MermaidPieOpen;
  Assert.AreEqual(0, WedgeCount, 'An open fence must render no diagram before the closing fence arrives');

  FModel.AppendMarkdown(MermaidFenceClose, StartTime);
  Assert.IsTrue(FModel.TryFlush(StartTime + FlushInterval));

  Assert.IsTrue(WedgeCount > 0, 'Closing the fence must promote the code block into a rendered diagram');
end;

procedure TViewerExtensionCachingTests.ReopeningFence_ByMutation_DropsDiagram;
begin
  FModel.Text := MermaidPieClosed;
  Assert.IsTrue(WedgeCount > 0, 'A closed fence must render a diagram');

  FModel.Text := MermaidPieOpen;

  Assert.AreEqual(0, WedgeCount,
    'Mutating the document back to an open fence must rebuild the cache and drop the diagram');
end;

end.
