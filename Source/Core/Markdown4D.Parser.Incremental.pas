unit Markdown4D.Parser.Incremental;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Parser.Interfaces;

type
  TMarkdownIncrementalParser = class
  public
    class function CreateParser(const Pipeline: IMarkdownPipeline): IMarkdownIncrementalParser;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Pipeline.Configuration,
  Markdown4D.Parser.Blocks,
  Markdown4D.Parser.References,
  Markdown4D.Renderer.Html;

type
  TFrozenSegment = class
  private
    FSource: string;
    FBaseHtml: string;
    FMissedLabels: TArray<string>;
    FDefinitions: TLinkReferenceMap;
    FPromotedHtml: string;
    FPromotedMissedLabels: TArray<string>;
    FPromotedVersion: Integer;

  public
    constructor Create(const Source, BaseHtml: string; const MissedLabels: TArray<string>; const Definitions: TLinkReferenceMap);
    destructor Destroy; override;
    procedure Promote(const Html: string; const Labels: TArray<string>; const Version: Integer);
    function HasPromotionFor(const Version: Integer): Boolean;
    property Source: string read FSource;
    property BaseHtml: string read FBaseHtml;
    property MissedLabels: TArray<string> read FMissedLabels;
    property Definitions: TLinkReferenceMap read FDefinitions;
    property PromotedHtml: string read FPromotedHtml;
    property PromotedMissedLabels: TArray<string> read FPromotedMissedLabels;
  end;

  TStreamingIncrementalParser = class(TInterfacedObject, IMarkdownIncrementalParser)
  private
    const
      MinimumFreezableBlockCount = 2;
      NoRenderedGeneration = -1;
      InitialFrozenVersion = 1;
      SegmentTargetLength = 4096;
      BoundarySearchAttemptLimit = 3;
      ReplaceRangeOutOfBoundsMessageFormat = 'ReplaceRange with start index %d and count %d is out of bounds for a source of length %d';
    var
      FPipeline: IMarkdownPipeline;
      FConfiguration: TMarkdownPipelineConfiguration;
      FFrozenReferences: TLinkReferenceMap;
      FSegments: TObjectList<TFrozenSegment>;
      FTail: string;
      FAnalyzedCompleteLength: Integer;
      FGeneration: Integer;
      FRenderedGeneration: Integer;
      FCachedHtml: string;
      FFrozenVersion: Integer;
    procedure FreezeCompletedBlocks;
    function CompletedLength: Integer;
    function TryFindFreezeBoundary(const CompleteText: string; out Boundary: Integer; out ChildOffsets: TArray<Integer>): Boolean;
    procedure FreezeUpTo(const Boundary: Integer; const ChildOffsets: TArray<Integer>);
    function InsertFrozenSegments(const InsertIndex: Integer; const Source: string; const ChildOffsets: TArray<Integer>): Integer;
    function CreateFrozenSegment(const Source: string): TFrozenSegment;
    function TotalSourceLength: Integer;
    procedure ValidateRange(const StartIndex, Count, TotalLength: Integer);
    procedure ApplyEdit(const StartIndex, Count: Integer; const Replacement: string);
    function SegmentStarts: TArray<Integer>;
    function SourcesBetween(const FirstIndex, LimitIndex: Integer): string;
    procedure SpliceBeforeRetained(const WindowFirst, RetainedIndex: Integer; const EditedWindow: string);
    function TryVerifyCleanBreak(const WindowText, RetainedSource: string; out ChildOffsets: TArray<Integer>): Boolean;
    procedure MergeIntoTail(const WindowFirst: Integer; const MergedText: string);
    procedure RebuildFrozenReferences(const SegmentLimit: Integer);
    procedure ReconcileDefinitions(const PreviousDefinitions: TLinkReferenceMap);
    procedure RebuildFromScratch;
    function ComposeFullSource: string;
    function SegmentHtml(const Segment: TFrozenSegment; const AvailableReferences: TLinkReferenceMap): string;
    procedure PromoteSegment(const Segment: TFrozenSegment);
    class function AnyLabelAvailable(const Labels: TArray<string>; const References: TLinkReferenceMap): Boolean;
    function ParseWithReferences(const Source: string; const References: TLinkReferenceMap): IMarkdownDocument;
    function RenderHtml(const Document: IMarkdownDocument): string;

  public
    constructor Create(const Pipeline: IMarkdownPipeline; const Configuration: TMarkdownPipelineConfiguration);
    destructor Destroy; override;
    procedure Append(const Chunk: string);
    procedure ReplaceRange(const StartIndex, Count: Integer; const Replacement: string);
    function ToHtml: string;
  end;

class function TMarkdownIncrementalParser.CreateParser(const Pipeline: IMarkdownPipeline): IMarkdownIncrementalParser;
begin
  var Provider: IMarkdownPipelineConfigurationProvider;
  const HasConfiguration = Supports(Pipeline, IMarkdownPipelineConfigurationProvider, Provider);
  if not HasConfiguration then
    raise EMarkdownError.Create('Incremental parsing requires a pipeline that provides its configuration');

  Result := TStreamingIncrementalParser.Create(Pipeline, Provider.Configuration);
end;

constructor TFrozenSegment.Create(const Source, BaseHtml: string; const MissedLabels: TArray<string>; const Definitions: TLinkReferenceMap);
begin
  inherited Create;

  FSource := Source;
  FBaseHtml := BaseHtml;
  FMissedLabels := MissedLabels;
  FDefinitions := Definitions;
end;

destructor TFrozenSegment.Destroy;
begin
  FDefinitions.Free;

  inherited Destroy;
end;

procedure TFrozenSegment.Promote(const Html: string; const Labels: TArray<string>; const Version: Integer);
begin
  FPromotedHtml := Html;
  FPromotedMissedLabels := Labels;
  FPromotedVersion := Version;
end;

function TFrozenSegment.HasPromotionFor(const Version: Integer): Boolean;
begin
  Result := (FPromotedVersion = Version);
end;

constructor TStreamingIncrementalParser.Create(const Pipeline: IMarkdownPipeline;
                                               const Configuration: TMarkdownPipelineConfiguration);
begin
  inherited Create;

  FPipeline := Pipeline;
  FConfiguration := Configuration;
  FFrozenReferences := TLinkReferenceMap.Create;
  FSegments := TObjectList<TFrozenSegment>.Create(True);
  FRenderedGeneration := NoRenderedGeneration;
  FFrozenVersion := InitialFrozenVersion;
end;

destructor TStreamingIncrementalParser.Destroy;
begin
  FSegments.Free;
  FFrozenReferences.Free;

  inherited Destroy;
end;

procedure TStreamingIncrementalParser.Append(const Chunk: string);
begin
  if Chunk = '' then
    Exit;

  FTail := FTail + Chunk;
  Inc(FGeneration);

  FreezeCompletedBlocks;
end;

procedure TStreamingIncrementalParser.FreezeCompletedBlocks;
begin
  const CompleteLength = CompletedLength;
  const HasNewCompleteLines = (CompleteLength > FAnalyzedCompleteLength);
  if not HasNewCompleteLines then
    Exit;

  var Boundary: Integer;
  var ChildOffsets: TArray<Integer>;
  if TryFindFreezeBoundary(Copy(FTail, 1, CompleteLength), Boundary, ChildOffsets) then
    FreezeUpTo(Boundary, ChildOffsets);

  FAnalyzedCompleteLength := CompletedLength;
end;

function TStreamingIncrementalParser.CompletedLength: Integer;
begin
  const TailLength = Length(FTail);

  for var Index := TailLength downto 1 do
  begin
    const Current = FTail[Index];

    if Current = LineFeed then
      Exit(Index);

    const IsSettledCarriageReturn = (Current = CarriageReturn) and (Index < TailLength);
    if IsSettledCarriageReturn then
      Exit(Index);
  end;

  Result := 0;
end;

function TStreamingIncrementalParser.TryFindFreezeBoundary(const CompleteText: string; out Boundary: Integer; out ChildOffsets: TArray<Integer>): Boolean;
begin
  Boundary := 0;
  ChildOffsets := nil;

  const Working = TLinkReferenceMap.Create;
  try
    FFrozenReferences.CopyTo(Working);

    const Document = ParseWithReferences(CompleteText, Working);
    const HasFreezableBlocks = (Document.ChildCount >= MinimumFreezableBlockCount);
    if not HasFreezableBlocks then
      Exit(False);

    SetLength(ChildOffsets, Document.ChildCount - 1);
    for var Index := 0 to Document.ChildCount - 2 do
    begin
      ChildOffsets[Index] := Document.Children[Index].Segment.StartOffset;
    end;

    Boundary := Document.Children[Document.ChildCount - 1].Segment.StartOffset;
    Result := (Boundary > 1);
  finally
    Working.Free;
  end;
end;

procedure TStreamingIncrementalParser.FreezeUpTo(const Boundary: Integer; const ChildOffsets: TArray<Integer>);
begin
  const CountBefore = FFrozenReferences.Count;
  const FrozenSource = Copy(FTail, 1, Boundary - 1);

  InsertFrozenSegments(FSegments.Count, FrozenSource, ChildOffsets);
  FTail := Copy(FTail, Boundary, MaxInt);

  const HasNewDefinitions = (FFrozenReferences.Count <> CountBefore);
  if HasNewDefinitions then
    Inc(FFrozenVersion);
end;

function TStreamingIncrementalParser.InsertFrozenSegments(const InsertIndex: Integer; const Source: string; const ChildOffsets: TArray<Integer>): Integer;
begin
  Result := 0;
  if Source = '' then
    Exit;

  var GroupStart := 1;
  for var Offset in ChildOffsets do
  begin
    const CompletesGroup = (Offset > GroupStart) and ((Offset - GroupStart) >= SegmentTargetLength);
    if not CompletesGroup then
      Continue;

    FSegments.Insert(InsertIndex + Result, CreateFrozenSegment(Copy(Source, GroupStart, Offset - GroupStart)));
    Inc(Result);
    GroupStart := Offset;
  end;

  FSegments.Insert(InsertIndex + Result, CreateFrozenSegment(Copy(Source, GroupStart, Length(Source) - GroupStart + 1)));
  Inc(Result);
end;

function TStreamingIncrementalParser.CreateFrozenSegment(const Source: string): TFrozenSegment;
begin
  const Definitions = TLinkReferenceMap.Create;
  try
    FFrozenReferences.ClearMissedLabels;
    FFrozenReferences.SetCaptureTarget(Definitions);

    var BaseHtml: string;
    try
      const Document = ParseWithReferences(Source, FFrozenReferences);
      BaseHtml := RenderHtml(Document);
    finally
      FFrozenReferences.SetCaptureTarget(nil);
    end;

    Result := TFrozenSegment.Create(Source, BaseHtml, FFrozenReferences.MissedLabels, Definitions);
  except
    Definitions.Free;
    raise;
  end;
end;

procedure TStreamingIncrementalParser.ReplaceRange(const StartIndex, Count: Integer; const Replacement: string);
begin
  const TotalLength = TotalSourceLength;
  ValidateRange(StartIndex, Count, TotalLength);

  const IsPureAppend = (StartIndex = TotalLength + 1);
  if IsPureAppend then
  begin
    Append(Replacement);
    Exit;
  end;

  const IsNoOp = (Count = 0) and (Replacement = '');
  if IsNoOp then
    Exit;

  Inc(FGeneration);

  const PreviousDefinitions = TLinkReferenceMap.Create;
  try
    FFrozenReferences.CopyTo(PreviousDefinitions);

    ApplyEdit(StartIndex, Count, Replacement);
    ReconcileDefinitions(PreviousDefinitions);
  finally
    PreviousDefinitions.Free;
  end;
end;

function TStreamingIncrementalParser.TotalSourceLength: Integer;
begin
  Result := Length(FTail);

  for var Segment in FSegments do
  begin
    Inc(Result, Length(Segment.Source));
  end;
end;

procedure TStreamingIncrementalParser.ValidateRange(const StartIndex, Count, TotalLength: Integer);
begin
  const StartIsValid = (StartIndex >= 1) and (StartIndex <= TotalLength + 1);
  const CountIsValid = (Count >= 0) and (Int64(StartIndex) + Int64(Count) <= Int64(TotalLength) + 1);
  if not (StartIsValid and CountIsValid) then
    raise EMarkdownError.CreateFmt(ReplaceRangeOutOfBoundsMessageFormat, [StartIndex, Count, TotalLength]);
end;

procedure TStreamingIncrementalParser.ApplyEdit(const StartIndex, Count: Integer; const Replacement: string);
begin
  const Starts = SegmentStarts;
  const SegmentCount = FSegments.Count;

  var FirstAffected := SegmentCount;
  for var Index := 0 to SegmentCount - 1 do
  begin
    if StartIndex < Starts[Index + 1] then
    begin
      FirstAffected := Index;
      Break;
    end;
  end;

  const WindowFirst = Max(FirstAffected - 1, 0);

  const EndPosition = StartIndex + Count;
  var RetainedIndex := SegmentCount;
  for var Index := WindowFirst + 1 to SegmentCount - 1 do
  begin
    if Starts[Index] >= EndPosition then
    begin
      RetainedIndex := Index;
      Break;
    end;
  end;

  const IncludesTail = (RetainedIndex >= SegmentCount);
  var WindowText := SourcesBetween(WindowFirst, RetainedIndex);
  if IncludesTail then
    WindowText := WindowText + FTail;

  const LocalStart = StartIndex - Starts[WindowFirst] + 1;
  const EditedWindow = Copy(WindowText, 1, LocalStart - 1) + Replacement + Copy(WindowText, LocalStart + Count, MaxInt);

  if IncludesTail then
    MergeIntoTail(WindowFirst, EditedWindow)
  else
    SpliceBeforeRetained(WindowFirst, RetainedIndex, EditedWindow);
end;

function TStreamingIncrementalParser.SegmentStarts: TArray<Integer>;
begin
  SetLength(Result, FSegments.Count + 1);

  var Position := 1;
  for var Index := 0 to FSegments.Count - 1 do
  begin
    Result[Index] := Position;
    Inc(Position, Length(FSegments[Index].Source));
  end;

  Result[FSegments.Count] := Position;
end;

function TStreamingIncrementalParser.SourcesBetween(const FirstIndex, LimitIndex: Integer): string;
begin
  const Builder = TStringBuilder.Create;
  try
    for var Index := FirstIndex to LimitIndex - 1 do
    begin
      Builder.Append(FSegments[Index].Source);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

procedure TStreamingIncrementalParser.SpliceBeforeRetained(const WindowFirst, RetainedIndex: Integer; const EditedWindow: string);
begin
  var CurrentWindow := EditedWindow;
  var CurrentRetained := RetainedIndex;
  var Attempts := 0;
  var ChildOffsets: TArray<Integer>;
  var Verified := False;

  while (not Verified) and (CurrentRetained < FSegments.Count) and (Attempts < BoundarySearchAttemptLimit) do
  begin
    Verified := TryVerifyCleanBreak(CurrentWindow, FSegments[CurrentRetained].Source, ChildOffsets);

    if not Verified then
    begin
      CurrentWindow := CurrentWindow + FSegments[CurrentRetained].Source;
      Inc(CurrentRetained);
      Inc(Attempts);
    end;
  end;

  if not Verified then
  begin
    MergeIntoTail(WindowFirst, CurrentWindow + SourcesBetween(CurrentRetained, FSegments.Count) + FTail);
    Exit;
  end;

  FSegments.DeleteRange(WindowFirst, CurrentRetained - WindowFirst);
  RebuildFrozenReferences(WindowFirst);

  const InsertedCount = InsertFrozenSegments(WindowFirst, CurrentWindow, ChildOffsets);
  for var Index := WindowFirst + InsertedCount to FSegments.Count - 1 do
  begin
    FSegments[Index].Definitions.CopyTo(FFrozenReferences);
  end;
end;

function TStreamingIncrementalParser.TryVerifyCleanBreak(const WindowText, RetainedSource: string; out ChildOffsets: TArray<Integer>): Boolean;
begin
  ChildOffsets := nil;

  const Scratch = TLinkReferenceMap.Create;
  try
    const Document = ParseWithReferences(WindowText + RetainedSource, Scratch);
    const BoundaryOffset = Length(WindowText) + 1;

    for var Index := 0 to Document.ChildCount - 1 do
    begin
      const ChildStart = Document.Children[Index].Segment.StartOffset;

      if ChildStart = BoundaryOffset then
      begin
        SetLength(ChildOffsets, Index);
        for var Preceding := 0 to Index - 1 do
        begin
          ChildOffsets[Preceding] := Document.Children[Preceding].Segment.StartOffset;
        end;

        Exit(True);
      end;

      const PassedBoundary = (ChildStart > BoundaryOffset);
      if PassedBoundary then
        Break;
    end;

    Result := False;
  finally
    Scratch.Free;
  end;
end;

procedure TStreamingIncrementalParser.MergeIntoTail(const WindowFirst: Integer; const MergedText: string);
begin
  FSegments.DeleteRange(WindowFirst, FSegments.Count - WindowFirst);
  RebuildFrozenReferences(FSegments.Count);

  FTail := MergedText;
  FAnalyzedCompleteLength := 0;

  FreezeCompletedBlocks;
end;

procedure TStreamingIncrementalParser.RebuildFrozenReferences(const SegmentLimit: Integer);
begin
  FFrozenReferences.Clear;

  for var Index := 0 to SegmentLimit - 1 do
  begin
    FSegments[Index].Definitions.CopyTo(FFrozenReferences);
  end;
end;

procedure TStreamingIncrementalParser.ReconcileDefinitions(const PreviousDefinitions: TLinkReferenceMap);
begin
  const PreservesPreviousDefinitions = FFrozenReferences.ContainsAllEntriesOf(PreviousDefinitions);
  if not PreservesPreviousDefinitions then
  begin
    RebuildFromScratch;
    Exit;
  end;

  const HasNewDefinitions = (FFrozenReferences.Count <> PreviousDefinitions.Count);
  if HasNewDefinitions then
    Inc(FFrozenVersion);
end;

procedure TStreamingIncrementalParser.RebuildFromScratch;
begin
  const FullSource = ComposeFullSource;

  FSegments.Clear;
  FFrozenReferences.Clear;
  FTail := FullSource;
  FAnalyzedCompleteLength := 0;

  FreezeCompletedBlocks;
end;

function TStreamingIncrementalParser.ComposeFullSource: string;
begin
  const Builder = TStringBuilder.Create;
  try
    for var Segment in FSegments do
    begin
      Builder.Append(Segment.Source);
    end;

    Builder.Append(FTail);
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function TStreamingIncrementalParser.ToHtml: string;
begin
  const IsCurrent = (FRenderedGeneration = FGeneration);
  if IsCurrent then
    Exit(FCachedHtml);

  const Working = TLinkReferenceMap.Create;
  try
    const Output = TStringBuilder.Create;
    try
      FFrozenReferences.CopyTo(Working);
      const TailDocument = ParseWithReferences(FTail, Working);
      const TailHtml = RenderHtml(TailDocument);

      for var Segment in FSegments do
      begin
        Output.Append(SegmentHtml(Segment, Working));
      end;

      Output.Append(TailHtml);
      FCachedHtml := Output.ToString;
    finally
      Output.Free;
    end;
  finally
    Working.Free;
  end;

  FRenderedGeneration := FGeneration;
  Result := FCachedHtml;
end;

function TStreamingIncrementalParser.SegmentHtml(const Segment: TFrozenSegment;
                                                 const AvailableReferences: TLinkReferenceMap): string;
begin
  var EffectiveHtml := Segment.BaseHtml;
  var EffectiveMissedLabels := Segment.MissedLabels;

  const NeedsFrozenPromotion = AnyLabelAvailable(Segment.MissedLabels, FFrozenReferences);
  if NeedsFrozenPromotion then
  begin
    if not Segment.HasPromotionFor(FFrozenVersion) then
      PromoteSegment(Segment);

    EffectiveHtml := Segment.PromotedHtml;
    EffectiveMissedLabels := Segment.PromotedMissedLabels;
  end;

  const HasTailResolvableMisses = AnyLabelAvailable(EffectiveMissedLabels, AvailableReferences);
  if not HasTailResolvableMisses then
    Exit(EffectiveHtml);

  const Document = ParseWithReferences(Segment.Source, AvailableReferences);
  Result := RenderHtml(Document);
end;

procedure TStreamingIncrementalParser.PromoteSegment(const Segment: TFrozenSegment);
begin
  FFrozenReferences.ClearMissedLabels;

  const Document = ParseWithReferences(Segment.Source, FFrozenReferences);
  Segment.Promote(RenderHtml(Document), FFrozenReferences.MissedLabels, FFrozenVersion);
end;

class function TStreamingIncrementalParser.AnyLabelAvailable(const Labels: TArray<string>;
                                                             const References: TLinkReferenceMap): Boolean;
begin
  for var CurrentLabel in Labels do
  begin
    if References.ContainsNormalizedLabel(CurrentLabel) then
      Exit(True);
  end;

  Result := False;
end;

function TStreamingIncrementalParser.ParseWithReferences(const Source: string;
                                                         const References: TLinkReferenceMap): IMarkdownDocument;
begin
  const Parser = TBlockParser.Create(FConfiguration);
  try
    Result := Parser.Parse(Source, References);
  finally
    Parser.Free;
  end;
end;

function TStreamingIncrementalParser.RenderHtml(const Document: IMarkdownDocument): string;
begin
  Result := TMarkdownHtmlRenderer.RenderDocument(Document, FConfiguration.RendererOptions,
    FConfiguration.RendererHooks);
end;

end.
