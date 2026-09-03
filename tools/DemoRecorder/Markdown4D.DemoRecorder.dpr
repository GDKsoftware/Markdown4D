program Markdown4D.DemoRecorder;

// Renders the announcement demo frame by frame straight to PNG files, so the
// GIF and the video are rebuilt from source instead of captured off somebody's
// screen. It draws an editor window around the real components: the source pane
// runs on the editor's own highlighter, the preview pane on the same layout
// engine and painter the VCL viewer uses. The clock belongs to this program,
// which makes every run identical.
//
// tools\Make-Demo.ps1 compiles this, runs it, and feeds the frames to ffmpeg.

{$APPTYPE CONSOLE}
{$SCOPEDENUMS ON}

uses
  System.SysUtils,
  System.Math,
  System.IOUtils,
  Winapi.Windows,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.Renderer,
  Markdown4D.Theme,
  Markdown4D.Viewer.Model,
  Markdown4D.Editor.Highlighter,
  Markdown4D.Vcl.Painter,
  Markdown4D.Extensions.Chart.BlockOverride,
  Markdown4D.Extensions.Mermaid.BlockOverride;

type
  // Window furniture. The document colours come from the markdown theme; only
  // the shell around it lives here, and it has to follow the theme so a dark
  // screenshot is dark all the way to the title bar.
  TChromePalette = record
    Background: TLayoutColor;
    Border: TLayoutColor;
    Text: TLayoutColor;
    Muted: TLayoutColor;
    ActiveTab: TLayoutColor;
    SourceBackground: TLayoutColor;
    GutterText: TLayoutColor;
    Caret: TLayoutColor;
    Accent: TLayoutColor;
    Glyph: TLayoutColor;
    class function ForPreset(const Preset: TMarkdownThemePreset): TChromePalette; static;
  end;

  TDemoRecorder = class
  private
    const
      AppTitle = 'Markdown4D Studio';
      SecondTabName = 'README.md';

      FrameWidth = 1180;
      FrameHeight = 720;

      TitleBarHeight = 38;
      TabBarHeight = 34;
      StatusBarHeight = 26;
      SplitterX = 520;
      SplitterWidth = 1;

      GutterWidth = 46;
      SourcePadding = 10;
      PreviewPadding = 22;

      // One frame per chunk, so the chunk size decides how fast the text
      // appears on screen.
      ChunkCharacters = 9;
      // Frames held before the first token, once the text is complete, and
      // again after the rewind, so the loop has a beat of stillness at both
      // ends instead of snapping back to an empty page.
      LeadingHoldFrames = 8;
      SettleFrames = 16;
      RewindFrames = 26;
      TopHoldFrames = 14;
      // The viewer debounces relayout; here every frame is a flush, because the
      // frame rate already is the debounce.
      ImmediateFlush = 0;
      MillisecondsPerFrame = 66;
      CaretBlinkFrames = 6;

    var
      FOutputFolder: string;
      FChrome: TChromePalette;
      FDocumentName: string;
      FTheme: TMarkdownTheme;
      FMeasureBitmap: TBitmap;
      FMeasurePainter: IPainter;
      FModel: TMarkdownViewerModel;
      FHighlighter: TMarkdownSourceHighlighter;
      FFrame: TBitmap;
      FFrameIndex: Integer;
      FClock: Int64;
      FSource: string;
      // The first source line on screen. Fractional while the rewind eases, so
      // both panes travel on the same curve.
      FSourceScrollLine: Single;
      FSourceFont: TMarkdownFontStyle;
      FChromeFont: TMarkdownFontStyle;
      FStatusFont: TMarkdownFontStyle;
    class function DemoDocument: string; static;
    function PreviewLeft: Integer;
    function PreviewWidth: Integer;
    function ContentTop: Integer;
    function ContentHeight: Integer;
    function VisibleSourceLines: Integer;
    function SourceLineCount: Integer;
    function TokenColor(const Kind: TMarkdownSourceTokenKind): TLayoutColor;
    procedure PaintChrome(const Painter: IPainter);
    procedure PaintTitleBar(const Painter: IPainter);
    procedure PaintTabBar(const Painter: IPainter);
    procedure PaintStatusBar(const Painter: IPainter);
    procedure PaintSource(const Painter: IPainter);
    procedure PaintPreview;
    procedure PaintFrame;
    procedure SaveFrame;
    procedure Emit;
    // Keeps the newest text in view the way the viewer's auto-follow does.
    procedure FollowTail;
    procedure StreamDocument;
    procedure RewindToTop;
  public
    constructor Create(const OutputFolder: string; const Preset: TMarkdownThemePreset;
      const DocumentName: string);
    destructor Destroy; override;
    function Run: Integer;
    // Lays a whole document out at once and writes a single frame, for the
    // screenshots in the README.
    procedure WriteStill(const FileName, Document: string);
    // The two documents behind those screenshots. Between them they show what
    // the components can do without either one turning into a wall.
    class function ReportDocument: string; static;
    class function PipelineDocument: string; static;
  end;

{ TChromePalette }

class function TChromePalette.ForPreset(const Preset: TMarkdownThemePreset): TChromePalette;
begin
  if Preset = TMarkdownThemePreset.Dark then
  begin
    Result.Background := TLayoutColor($FF23262B);
    Result.Border := TLayoutColor($FF32363D);
    Result.Text := TLayoutColor($FFE6EDF3);
    Result.Muted := TLayoutColor($FF8B949E);
    Result.ActiveTab := TLayoutColor($FF0D1117);
    Result.SourceBackground := TLayoutColor($FF14171C);
    Result.GutterText := TLayoutColor($FF5A626C);
    Result.Caret := TLayoutColor($FF58A6FF);
    Result.Accent := TLayoutColor($FF58A6FF);
    Result.Glyph := TLayoutColor($FFAEB6C0);
    Exit;
  end;

  Result.Background := TLayoutColor($FFF3F3F3);
  Result.Border := TLayoutColor($FFDDDDDD);
  Result.Text := TLayoutColor($FF3C4043);
  Result.Muted := TLayoutColor($FF80868B);
  Result.ActiveTab := TLayoutColor($FFFFFFFF);
  Result.SourceBackground := TLayoutColor($FFFBFBFB);
  Result.GutterText := TLayoutColor($FFB0B4B8);
  Result.Caret := TLayoutColor($FF1A73E8);
  Result.Accent := TLayoutColor($FF1A73E8);
  Result.Glyph := TLayoutColor($FF5F6368);
end;

{ TDemoRecorder }

constructor TDemoRecorder.Create(const OutputFolder: string; const Preset: TMarkdownThemePreset;
  const DocumentName: string);
begin
  inherited Create;

  FOutputFolder := OutputFolder;
  FDocumentName := DocumentName;
  FChrome := TChromePalette.ForPreset(Preset);

  // Without these the chart and mermaid fences stay ordinary code blocks.
  TChartBlockOverride.RegisterOverride;
  TMermaidBlockOverride.RegisterOverride;

  FTheme := TMarkdownTheme.CreatePreset(Preset);

  FMeasureBitmap := TBitmap.Create;
  FMeasureBitmap.SetSize(1, 1);
  FMeasurePainter := TMarkdownVclPainter.Create(FMeasureBitmap.Canvas);

  FModel := TMarkdownViewerModel.Create(FTheme, FMeasurePainter);
  FModel.FlushIntervalMilliseconds := ImmediateFlush;
  FModel.SetViewport(PreviewWidth - 2 * PreviewPadding, ContentHeight);

  FHighlighter := TMarkdownSourceHighlighter.Create;

  FSourceFont := FTheme.CodeFont;
  FSourceFont.Size := 13;

  FChromeFont := FTheme.BaseFont;
  FChromeFont.Size := 13;

  FStatusFont := FTheme.BaseFont;
  FStatusFont.Size := 12;

  FFrame := TBitmap.Create;
  FFrame.PixelFormat := pf24bit;
  FFrame.SetSize(FrameWidth, FrameHeight);
end;

destructor TDemoRecorder.Destroy;
begin
  FFrame.Free;
  FHighlighter.Free;
  FModel.Free;
  FMeasurePainter := nil;
  FMeasureBitmap.Free;
  FTheme.Free;

  inherited;
end;

class function TDemoRecorder.DemoDocument: string;
begin
  Result :=
    '## Streaming markdown'#10#10 +
    'Text arrives a chunk at a time. The viewer reparses'#10 +
    'only the part that changed.'#10#10 +
    '| Renderer | Startup | Streaming |'#10 +
    '| --- | --- | --- |'#10 +
    '| Embedded browser | slow | awkward |'#10 +
    '| HTML export | fast | full reload |'#10 +
    '| **Markdown4D** | fast | incremental |'#10#10 +
    'A chart fence turns into graphics'#10 +
    'the moment it closes:'#10#10 +
    '```chart'#10 +
    '{'#10 +
    '  "type": "chart",'#10 +
    '  "data": {'#10 +
    '    "type": "bar",'#10 +
    '    "data": {'#10 +
    '      "labels": ["Q1", "Q2", "Q3", "Q4"],'#10 +
    '      "datasets": [{'#10 +
    '        "label": "Revenue",'#10 +
    '        "data": [12, 19, 14, 23]'#10 +
    '      }]'#10 +
    '    }'#10 +
    '  }'#10 +
    '}'#10 +
    '```'#10#10 +
    'So does a mermaid diagram:'#10#10 +
    '```mermaid'#10 +
    'flowchart LR'#10 +
    '  Source[Markdown] --> Parser{Parser}'#10 +
    '  Parser -->|AST| Layout([Layout])'#10 +
    '  Layout --> Canvas'#10 +
    '```'#10#10 +
    'And this is all it takes in your own form:'#10#10 +
    '```pascal'#10 +
    'procedure TReportForm.OnChunkReceived('#10 +
    '  const Chunk: string);'#10 +
    'begin'#10 +
    '  FViewer.AppendMarkdown(Chunk);'#10 +
    'end;'#10 +
    '```'#10#10 +
    'No browser. No DLL. VCL and FMX.'#10;
end;

class function TDemoRecorder.ReportDocument: string;
begin
  Result :=
    '# Quarterly report'#10#10 +
    'Revenue held up in **every region**, and the pipeline for next'#10 +
    'quarter is the widest it has been. Detail per region below.'#10#10 +
    '| Region | Revenue | Growth |'#10 +
    '| --- | ---: | ---: |'#10 +
    '| Europe | 1.24M | +12% |'#10 +
    '| North America | 0.98M | +7% |'#10 +
    '| Asia Pacific | 0.61M | +23% |'#10#10 +
    '```chart'#10 +
    '{'#10 +
    '  "type": "chart",'#10 +
    '  "data": {'#10 +
    '    "type": "bar",'#10 +
    '    "data": {'#10 +
    '      "labels": ["Q1", "Q2", "Q3", "Q4"],'#10 +
    '      "datasets": [{'#10 +
    '        "label": "Revenue",'#10 +
    '        "data": [12, 19, 14, 23]'#10 +
    '      }]'#10 +
    '    }'#10 +
    '  }'#10 +
    '}'#10 +
    '```'#10;
end;

class function TDemoRecorder.PipelineDocument: string;
begin
  Result :=
    '# How markdown reaches the screen'#10#10 +
    '```mermaid'#10 +
    'flowchart LR'#10 +
    '  Source[Markdown] --> Parser{Parser}'#10 +
    '  Parser -->|AST| Layout([Layout])'#10 +
    '  Layout --> Canvas'#10 +
    '```'#10#10 +
    'Text that arrives in pieces goes straight in:'#10#10 +
    '```pascal'#10 +
    'procedure TReportForm.OnChunkReceived('#10 +
    '  const Chunk: string);'#10 +
    'begin'#10 +
    '  FViewer.AppendMarkdown(Chunk);'#10 +
    'end;'#10 +
    '```'#10#10 +
    '| Call | Thread | Effect |'#10 +
    '| --- | --- | --- |'#10 +
    '| `AppendMarkdown` | any | reparses the tail |'#10 +
    '| `Text` | any | replaces the document |'#10#10 +
    '- [x] Incremental reparse'#10 +
    '- [x] Debounced relayout'#10 +
    '- [ ] Your next feature'#10#10 +
    '> Selections survive a relayout, so a reader can copy from'#10 +
    '> text that is still arriving.'#10;
end;

function TDemoRecorder.PreviewLeft: Integer;
begin
  Result := SplitterX + SplitterWidth;
end;

function TDemoRecorder.PreviewWidth: Integer;
begin
  Result := FrameWidth - PreviewLeft;
end;

function TDemoRecorder.ContentTop: Integer;
begin
  Result := TitleBarHeight + TabBarHeight;
end;

function TDemoRecorder.ContentHeight: Integer;
begin
  Result := FrameHeight - ContentTop - StatusBarHeight;
end;

function TDemoRecorder.VisibleSourceLines: Integer;
begin
  Result := Trunc((ContentHeight - 2 * SourcePadding) / FMeasurePainter.LineHeight(FSourceFont));
end;

function TDemoRecorder.SourceLineCount: Integer;
begin
  Result := FSource.CountChar(#10) + 1;
end;

// The same mapping the VCL editor applies to its own source pane.
function TDemoRecorder.TokenColor(const Kind: TMarkdownSourceTokenKind): TLayoutColor;
begin
  case Kind of
    TMarkdownSourceTokenKind.HeadingMarker,
    TMarkdownSourceTokenKind.EmphasisDelimiter,
    TMarkdownSourceTokenKind.CodeSpanDelimiter,
    TMarkdownSourceTokenKind.BlockQuoteMarker,
    TMarkdownSourceTokenKind.ListMarker,
    TMarkdownSourceTokenKind.LinkBracket:
      Result := FTheme.BlockQuoteTextColor;
    TMarkdownSourceTokenKind.CodeSpanText,
    TMarkdownSourceTokenKind.FenceLine,
    TMarkdownSourceTokenKind.FenceContent:
      Result := FTheme.CodeTextColor;
    TMarkdownSourceTokenKind.LinkText,
    TMarkdownSourceTokenKind.LinkUrl:
      Result := FTheme.LinkColor;
  else
    Result := FTheme.TextColor;
  end;
end;

procedure TDemoRecorder.PaintTitleBar(const Painter: IPainter);
begin
  Painter.FillRect(TLayoutRectF.Create(0, 0, FrameWidth, TitleBarHeight), FChrome.Background);
  Painter.DrawLine(TLayoutPointF.Create(0, TitleBarHeight), TLayoutPointF.Create(FrameWidth, TitleBarHeight),
    FChrome.Border, 1);

  const Caption = AppTitle + '  -  ' + FDocumentName;
  const CaptionSize = Painter.MeasureText(Caption, FChromeFont);
  Painter.DrawTextRun(TLayoutPointF.Create((FrameWidth - CaptionSize.Width) / 2,
    (TitleBarHeight - CaptionSize.Height) / 2), Caption, FChromeFont, FChrome.Text);

  // Minimise, maximise and close, drawn rather than pulled from a resource so
  // the frame has no dependency beyond the painter.
  const ButtonCenterY = TitleBarHeight / 2;
  const MinimiseX = FrameWidth - 108;
  const MaximiseX = FrameWidth - 70;
  const CloseX = FrameWidth - 32;
  const GlyphRadius = 5;

  Painter.DrawLine(TLayoutPointF.Create(MinimiseX - GlyphRadius, ButtonCenterY),
    TLayoutPointF.Create(MinimiseX + GlyphRadius, ButtonCenterY), FChrome.Glyph, 1);

  Painter.DrawRect(TLayoutRectF.Create(MaximiseX - GlyphRadius, ButtonCenterY - GlyphRadius,
    MaximiseX + GlyphRadius, ButtonCenterY + GlyphRadius), FChrome.Glyph, 1);

  Painter.DrawLine(TLayoutPointF.Create(CloseX - GlyphRadius, ButtonCenterY - GlyphRadius),
    TLayoutPointF.Create(CloseX + GlyphRadius, ButtonCenterY + GlyphRadius), FChrome.Glyph, 1);
  Painter.DrawLine(TLayoutPointF.Create(CloseX + GlyphRadius, ButtonCenterY - GlyphRadius),
    TLayoutPointF.Create(CloseX - GlyphRadius, ButtonCenterY + GlyphRadius), FChrome.Glyph, 1);
end;

procedure TDemoRecorder.PaintTabBar(const Painter: IPainter);
begin
  const Top = TitleBarHeight;
  const Bottom = Top + TabBarHeight;

  Painter.FillRect(TLayoutRectF.Create(0, Top, FrameWidth, Bottom), FChrome.Background);

  const ActiveWidth = Painter.MeasureText(FDocumentName, FChromeFont).Width + 46;
  const ActiveRect = TLayoutRectF.Create(0, Top, ActiveWidth, Bottom);
  Painter.FillRect(ActiveRect, FChrome.ActiveTab);
  // The accent stripe reads as "this tab is current" without any icon work.
  Painter.FillRect(TLayoutRectF.Create(0, Top, ActiveWidth, Top + 2), FChrome.Accent);

  const LabelHeight = Painter.MeasureText(FDocumentName, FChromeFont).Height;
  const LabelTop = Top + (TabBarHeight - LabelHeight) / 2;
  Painter.DrawTextRun(TLayoutPointF.Create(14, LabelTop), FDocumentName, FChromeFont, FChrome.Text);

  const CloseX = ActiveWidth - 18;
  const CloseY = Top + TabBarHeight / 2;
  Painter.DrawLine(TLayoutPointF.Create(CloseX - 4, CloseY - 4), TLayoutPointF.Create(CloseX + 4, CloseY + 4),
    FChrome.Muted, 1);
  Painter.DrawLine(TLayoutPointF.Create(CloseX + 4, CloseY - 4), TLayoutPointF.Create(CloseX - 4, CloseY + 4),
    FChrome.Muted, 1);

  Painter.DrawTextRun(TLayoutPointF.Create(ActiveWidth + 16, LabelTop), SecondTabName, FChromeFont, FChrome.Muted);

  Painter.DrawLine(TLayoutPointF.Create(0, Bottom), TLayoutPointF.Create(FrameWidth, Bottom), FChrome.Border, 1);
end;

procedure TDemoRecorder.PaintStatusBar(const Painter: IPainter);
begin
  const Top = FrameHeight - StatusBarHeight;

  Painter.FillRect(TLayoutRectF.Create(0, Top, FrameWidth, FrameHeight), FChrome.Background);
  Painter.DrawLine(TLayoutPointF.Create(0, Top), TLayoutPointF.Create(FrameWidth, Top), FChrome.Border, 1);

  const Lines = FSource.CountChar(#10) + 1;
  const LastBreak = FSource.LastDelimiter(#10);
  const Column = Length(FSource) - LastBreak + 1;

  const Left = Format('Ln %d, Col %d', [Lines, Column]);
  const Right = 'GFM   CommonMark 0.31.2   UTF-8';

  const LabelHeight = Painter.MeasureText(Left, FStatusFont).Height;
  const LabelTop = Top + (StatusBarHeight - LabelHeight) / 2;

  Painter.DrawTextRun(TLayoutPointF.Create(14, LabelTop), Left, FStatusFont, FChrome.Muted);

  const RightWidth = Painter.MeasureText(Right, FStatusFont).Width;
  Painter.DrawTextRun(TLayoutPointF.Create(FrameWidth - RightWidth - 14, LabelTop), Right, FStatusFont,
    FChrome.Muted);
end;

procedure TDemoRecorder.PaintSource(const Painter: IPainter);
begin
  const Top = ContentTop;
  const Bottom = Top + ContentHeight;

  Painter.FillRect(TLayoutRectF.Create(0, Top, SplitterX, Bottom), FChrome.SourceBackground);
  Painter.FillRect(TLayoutRectF.Create(SplitterX, Top, SplitterX + SplitterWidth, Bottom), FChrome.Border);

  const LineHeight = Painter.LineHeight(FSourceFont);

  const Lines = FSource.Split([#10]);
  const FirstLine = Max(0, Min(High(Lines), Round(FSourceScrollLine)));

  Painter.SaveState;
  try
    Painter.SetClip(TLayoutRectF.Create(0, Top, SplitterX, Bottom));

    // The highlighter carries state across lines, so a fence opened above the
    // first visible line still colours the lines below it.
    var State := FHighlighter.InitialState;
    for var Index := 0 to FirstLine - 1 do
      State := FHighlighter.TokenizeLine(Lines[Index], State).NextState;

    var Y: Single := Top + SourcePadding;
    for var Index := FirstLine to High(Lines) do
    begin
      const Line = FHighlighter.TokenizeLine(Lines[Index], State);
      State := Line.NextState;

      const Number = (Index + 1).ToString;
      const NumberWidth = Painter.MeasureText(Number, FSourceFont).Width;
      Painter.DrawTextRun(TLayoutPointF.Create(GutterWidth - 10 - NumberWidth, Y), Number, FSourceFont,
        FChrome.GutterText);

      var X: Single := GutterWidth + SourcePadding;
      for var Token in Line.Tokens do
      begin
        const Segment = Copy(Lines[Index], Token.Start, Token.Length);
        Painter.DrawTextRun(TLayoutPointF.Create(X, Y), Segment, FSourceFont, TokenColor(Token.Kind));
        X := X + Painter.MeasureText(Segment, FSourceFont).Width;
      end;

      const IsLastLine = Index = High(Lines);
      const CaretVisible = (FFrameIndex div CaretBlinkFrames) mod 2 = 0;
      if IsLastLine and CaretVisible then
        Painter.FillRect(TLayoutRectF.Create(X, Y + 1, X + 2, Y + LineHeight - 1), FChrome.Caret);

      Y := Y + LineHeight;
    end;
  finally
    Painter.RestoreState;
  end;
end;

procedure TDemoRecorder.PaintPreview;
begin
  const Painter = TMarkdownVclPainter.Create(FFrame.Canvas);
  const PainterLifetime: IPainter = Painter;

  const ScrollY = Round(FModel.ScrollOffset);
  // Shifting the origin puts the document inside the right-hand pane while the
  // layout keeps working in its own coordinates from zero.
  SetWindowOrgEx(FFrame.Canvas.Handle, -(PreviewLeft + PreviewPadding), ScrollY - ContentTop, nil);
  try
    const Viewport = TLayoutRectF.Create(-PreviewPadding, ScrollY,
      PreviewWidth - PreviewPadding, ScrollY + ContentHeight);
    TMarkdownDisplayListRenderer.Render(FModel.DisplayList, PainterLifetime, Viewport, FTheme.BackgroundColor);
  finally
    SetWindowOrgEx(FFrame.Canvas.Handle, 0, 0, nil);
  end;
end;

procedure TDemoRecorder.PaintChrome(const Painter: IPainter);
begin
  PaintTitleBar(Painter);
  PaintTabBar(Painter);
  PaintSource(Painter);
  PaintStatusBar(Painter);
end;

procedure TDemoRecorder.PaintFrame;
begin
  PaintPreview;

  const Painter = TMarkdownVclPainter.Create(FFrame.Canvas);
  const PainterLifetime: IPainter = Painter;
  PaintChrome(PainterLifetime);
end;

procedure TDemoRecorder.SaveFrame;
begin
  const Png = TPngImage.Create;
  try
    Png.Assign(FFrame);
    Png.SaveToFile(TPath.Combine(FOutputFolder, Format('frame_%.4d.png', [FFrameIndex])));
  finally
    Png.Free;
  end;
end;

procedure TDemoRecorder.Emit;
begin
  PaintFrame;
  SaveFrame;
  Inc(FFrameIndex);
end;

// Keeps the newest line in view in both panes, the way the viewer's auto-follow
// and an editor being typed into both do.
procedure TDemoRecorder.FollowTail;
begin
  FModel.ScrollOffset := Max(0, FModel.DisplayList.Height - ContentHeight);
  FSourceScrollLine := Max(0, SourceLineCount - VisibleSourceLines);
end;

procedure TDemoRecorder.StreamDocument;
begin
  const Document = DemoDocument;

  var Position := 1;
  while Position <= Length(Document) do
  begin
    const Chunk = Copy(Document, Position, ChunkCharacters);
    Inc(Position, ChunkCharacters);

    FSource := FSource + Chunk;

    Inc(FClock, MillisecondsPerFrame);
    FModel.AppendMarkdown(Chunk, FClock);
    FModel.TryFlush(FClock);
    FollowTail;

    Emit;
  end;
end;

// Scrolls both panes back to the top once the text is complete, so the loop
// ends where it started and the whole document has been seen at least once.
procedure TDemoRecorder.RewindToTop;
begin
  const StartOffset = FModel.ScrollOffset;
  const StartLine = FSourceScrollLine;

  for var Step := 1 to RewindFrames do
  begin
    const Progress = Step / RewindFrames;
    // Smoothstep, so the rewind eases in and out instead of jerking.
    const Eased = Progress * Progress * (3 - 2 * Progress);

    FModel.ScrollOffset := StartOffset * (1 - Eased);
    FSourceScrollLine := StartLine * (1 - Eased);

    Emit;
  end;
end;

procedure TDemoRecorder.WriteStill(const FileName, Document: string);
begin
  FSource := Document;
  FModel.Text := Document;
  FModel.TryFlush(0);
  FSourceScrollLine := 0;
  FModel.ScrollOffset := 0;

  PaintFrame;

  const Png = TPngImage.Create;
  try
    Png.Assign(FFrame);
    Png.SaveToFile(FileName);
  finally
    Png.Free;
  end;
end;

function TDemoRecorder.Run: Integer;
begin
  for var Hold := 1 to LeadingHoldFrames do
    Emit;

  StreamDocument;

  for var Hold := 1 to SettleFrames do
    Emit;

  RewindToTop;

  for var Hold := 1 to TopHoldFrames do
    Emit;

  Result := FFrameIndex;
end;

const
  AnimationDocumentName = 'streaming.md';
  StillDocumentName = 'release-notes.md';
  StillsMode = 'stills';

function OutputFolderFromCommandLine: string;
begin
  if ParamCount >= 1 then
    Result := ParamStr(1)
  else
    Result := TPath.Combine(TDirectory.GetCurrentDirectory, 'frames');
end;

procedure WriteAnimation(const OutputFolder: string);
begin
  const Recorder = TDemoRecorder.Create(OutputFolder, TMarkdownThemePreset.Light, AnimationDocumentName);
  try
    const FrameCount = Recorder.Run;
    Writeln(Format('%d frames written to %s', [FrameCount, OutputFolder]));
  finally
    Recorder.Free;
  end;
end;

// Two screenshots that between them cover the ground: a report with a table and
// a chart in the light theme, and the streaming pipeline with a diagram, code
// and a task list in the dark one.
procedure WriteStills(const OutputFolder: string);
begin
  const Light = TDemoRecorder.Create(OutputFolder, TMarkdownThemePreset.Light, StillDocumentName);
  try
    const LightPath = TPath.Combine(OutputFolder, 'studio-light.png');
    Light.WriteStill(LightPath, TDemoRecorder.ReportDocument);
    Writeln('Wrote ' + LightPath);
  finally
    Light.Free;
  end;

  const Dark = TDemoRecorder.Create(OutputFolder, TMarkdownThemePreset.Dark, StillDocumentName);
  try
    const DarkPath = TPath.Combine(OutputFolder, 'studio-dark.png');
    Dark.WriteStill(DarkPath, TDemoRecorder.PipelineDocument);
    Writeln('Wrote ' + DarkPath);
  finally
    Dark.Free;
  end;
end;

begin
  try
    const OutputFolder = OutputFolderFromCommandLine;
    if not TDirectory.Exists(OutputFolder) then
      TDirectory.CreateDirectory(OutputFolder);

    if SameText(ParamStr(2), StillsMode) then
      WriteStills(OutputFolder)
    else
      WriteAnimation(OutputFolder);
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
