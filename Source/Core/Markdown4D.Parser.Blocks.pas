unit Markdown4D.Parser.Blocks;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Pipeline.Configuration,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Ast,
  Markdown4D.Parser.LineReader,
  Markdown4D.Parser.LineScanner,
  Markdown4D.Parser.HtmlBlocks,
  Markdown4D.Parser.References,
  Markdown4D.Parser.StagingBlock,
  Markdown4D.Parser.Inlines;

type
  TBlockParser = class
  private
    type
      TContinueResult = (Continued, Rejected, Consumed);
      TContinuationMatch = record
        Container: TStagingBlock;
        LineConsumed: Boolean;
      end;
      TBuildFrame = record
        Staging: TStagingBlock;
        AstParent: TMarkdownAstNode;
      end;
      // Where the current line stops being a run of one thematic break marker.
      // Cached per line so a line carrying many markers does not rescan its own
      // tail once per marker.
      TThematicBreakScan = record
        Marker: Char;
        LastForeignIndex: Integer;
      end;
    const
      CodeIndent = 4;
      MinThematicMarkers = 3;
      MaxOrderedDigits = 9;
      MaxMarkerPaddingColumns = 5;
      HashChar = '#';
      EqualsChar = '=';
      DashChar = '-';
      AsteriskChar = '*';
      PlusChar = '+';
      UnderscoreChar = '_';
      GreaterThanChar = '>';
      LessThanChar = '<';
      BacktickChar = '`';
      TildeChar = '~';
      OpenBracketChar = '[';
      PipeChar = '|';
      ColonChar = ':';
      BackslashChar = '\';
      DotChar = '.';
      RightParenChar = ')';
      ZeroChar = '0';
      NineChar = '9';
      TrimChars: array[0..1] of Char = (' ', #9);
      ContentTrimChars: array[0..3] of Char = (' ', #9, #10, #13);
    var
      FConfiguration: TMarkdownPipelineConfiguration;
      FContext: IMarkdownBlockParserContext;
      FScanner: TLineScanner;
      FInlineParser: TInlineParser;
      FHtmlScanner: THtmlBlockScanner;
      FReferenceParser: TLinkReferenceParser;
      FReferenceMap: TLinkReferenceMap;
      FActiveReferences: TLinkReferenceMap;
      FRoot: TStagingBlock;
      FTip: TStagingBlock;
      FOldTip: TStagingBlock;
      FLastMatchedContainer: TStagingBlock;
      FStartContainer: TStagingBlock;
      FAllClosed: Boolean;
      FBlank: Boolean;
      FLineNumber: Integer;
      FCurrentLine: TSourceLine;
      FThematicBreakScan: TThematicBreakScan;
    procedure ProcessLine(const Line: TSourceLine);
    function MatchContinuations: TContinuationMatch;
    function ContinueBlock(const Block: TStagingBlock): TContinueResult;
    function ContinueBlockQuote: TContinueResult;
    function ContinueListItem(const Block: TStagingBlock): TContinueResult;
    function ContinueCodeBlock(const Block: TStagingBlock): TContinueResult;
    function IsClosingFenceLine(const Block: TStagingBlock): Boolean;
    function ContinueHtmlBlock(const Block: TStagingBlock): TContinueResult;
    function ContinueTable: TContinueResult;
    function TableRowIsInterrupted: Boolean;
    function IsFenceOpeningLine: Boolean;
    function IsListMarkerLine: Boolean;
    function OpenNewBlocks(const StartContainer: TStagingBlock; const LeafAlreadyMatched: Boolean): TStagingBlock;
    function TryStartBlock(const Container: TStagingBlock): TMarkdownBlockStart;
    function TryStartBlockQuote: TMarkdownBlockStart;
    function TryConsumeBlockQuoteMarker: Boolean;
    function TryStartAtxHeading: TMarkdownBlockStart;
    function TryMatchAtxHeading(out Level: Integer; out Content: string): Boolean;
    class function StripAtxClosingSequence(const Value: string): string;
    function TryStartFencedCode: TMarkdownBlockStart;
    function TryStartHtmlBlock(const Container: TStagingBlock): TMarkdownBlockStart;
    function TryStartSetextHeading(const Container: TStagingBlock): TMarkdownBlockStart;
    function TryMatchSetextUnderline(out Level: Integer): Boolean;
    function TryStartTable(const Container: TStagingBlock): TMarkdownBlockStart;
    class function TryParseTableDelimiterRow(const Line: string;
                                             out Alignments: TArray<TMarkdownTableColumnAlignment>): Boolean;
    class function TryParseTableDelimiterCell(const Cell: string;
                                              out Alignment: TMarkdownTableColumnAlignment): Boolean;
    class function SplitTableRow(const Line: string): TArray<string>;
    function TryStartThematicBreak: TMarkdownBlockStart;
    function IsThematicBreakLine: Boolean;
    function ScanThematicBreak(const Marker: Char): TThematicBreakScan;
    function TryStartListItem(const Container: TStagingBlock): TMarkdownBlockStart;
    function TryParseListMarker(const Container: TStagingBlock; out MarkerData: TListData): Boolean;
    function TryMatchListMarker(const Container: TStagingBlock; out MarkerData: TListData;
                                out MarkerLength: Integer): Boolean;
    function TryScanOrderedMarker(out Number, DigitCount, DelimiterIndex: Integer): Boolean;
    class function IsBulletChar(const Value: Char): Boolean;
    function ComputeMarkerPadding(const MarkerLength: Integer): Integer;
    function TryStartIndentedCode: TMarkdownBlockStart;
    procedure AddTextToContainer(const Container: TStagingBlock);
    procedure UpdateLastLineBlank(const Container: TStagingBlock);
    procedure AddLineToTip;
    procedure CloseUnmatchedBlocks;
    function AddChild(const Kind: TMarkdownNodeKind): TStagingBlock;
    class function CanContain(const ParentKind, ChildKind: TMarkdownNodeKind): Boolean;
    class function AcceptsLines(const Kind: TMarkdownNodeKind): Boolean;
    procedure FinalizeBlock(const Block: TStagingBlock);
    function FinalizeParagraph(const Block: TStagingBlock): Boolean;
    procedure StripLeadingReferences(const Block: TStagingBlock);
    class function IsBlankText(const Value: string): Boolean;
    procedure FinalizeCodeBlock(const Block: TStagingBlock);
    procedure FinalizeHtmlBlock(const Block: TStagingBlock);
    class function StripTrailingBlankLines(const Value: string; const KeepFinalLineBreak: Boolean): string;
    procedure FinalizeList(const Block: TStagingBlock);
    class function ListIsLoose(const Block: TStagingBlock): Boolean;
    function BuildDocument(const SourceLength: Integer): IMarkdownDocument;
    procedure AppendChildren(const Staging: TStagingBlock; const AstParent: TMarkdownAstNode);
    class procedure PushChildFrames(const Pending: TStack<TBuildFrame>; const Staging: TStagingBlock;
                                    const AstParent: TMarkdownAstNode);
    function CreateNode(const Block: TStagingBlock): TMarkdownAstNode;
    function CreateTableNode(const Block: TStagingBlock): TMarkdownAstNode;
    class function IsTaskListParagraph(const Block: TStagingBlock): Boolean;
    class function HasNestedBlocks(const Kind: TMarkdownNodeKind): Boolean;
    procedure AttachInlines(const Node: TMarkdownAstNode; const Content: string;
                            const IsTaskListCandidate: Boolean);
    procedure RunDocumentProcessors(const Document: IMarkdownDocument);

  public
    constructor Create(const Configuration: TMarkdownPipelineConfiguration);
    destructor Destroy; override;
    function Parse(const Source: string): IMarkdownDocument; overload;
    function Parse(const Source: string; const References: TLinkReferenceMap): IMarkdownDocument; overload;
  end;

  TBlockParserContext = class(TInterfacedObject, IMarkdownBlockParserContext)
  private
    FEngine: TBlockParser;

  public
    constructor Create(const Engine: TBlockParser);
    function GetLineText: string;
    function GetIndent: Integer;
    function GetIsBlankLine: Boolean;
    property Engine: TBlockParser read FEngine;
  end;

  TCommonMarkBlockKind = (BlockQuote, AtxHeading, FencedCode, HtmlBlock, SetextHeading, ThematicBreak, ListItem,
    IndentedCode);

  TCommonMarkBlockStarter = class(TInterfacedObject, IMarkdownBlockParser)
  private
    const
      Names: array[TCommonMarkBlockKind] of string = ('blockquote', 'atxheading', 'fencedcode', 'htmlblock',
        'setextheading', 'thematicbreak', 'listitem', 'indentedcode');
    var
      FKind: TCommonMarkBlockKind;

  public
    constructor Create(const Kind: TCommonMarkBlockKind);
    function GetName: string;
    function TryStart(const Context: IMarkdownBlockParserContext): TMarkdownBlockStart;
  end;

  TGfmTableBlockStarter = class(TInterfacedObject, IMarkdownBlockParser)
  private
    const
      TableParserName = 'table';

  public
    function GetName: string;
    function TryStart(const Context: IMarkdownBlockParserContext): TMarkdownBlockStart;
  end;

implementation

uses
  Markdown4D.Defines,
  Markdown4D.Text.Unescape;

constructor TBlockParser.Create(const Configuration: TMarkdownPipelineConfiguration);
begin
  inherited Create;

  FConfiguration := Configuration;
  FContext := TBlockParserContext.Create(Self);
  FScanner := TLineScanner.Create;
  FInlineParser := TInlineParser.Create(Configuration);
  FHtmlScanner := THtmlBlockScanner.Create;
  FReferenceParser := TLinkReferenceParser.Create;
  FReferenceMap := TLinkReferenceMap.Create;
end;

destructor TBlockParser.Destroy;
begin
  FReferenceMap.Free;
  FReferenceParser.Free;
  FHtmlScanner.Free;
  FInlineParser.Free;
  FScanner.Free;

  inherited Destroy;
end;

function TBlockParser.Parse(const Source: string): IMarkdownDocument;
begin
  FReferenceMap.Clear;

  Result := Parse(Source, FReferenceMap);
end;

function TBlockParser.Parse(const Source: string; const References: TLinkReferenceMap): IMarkdownDocument;
begin
  FActiveReferences := References;
  FLineNumber := 0;

  FRoot := TStagingBlock.Create(TMarkdownNodeKind.Document, nil);
  try
    FTip := FRoot;

    const Reader = TLineReader.Create(Source);
    try
      var Line: TSourceLine;

      while Reader.TryReadLine(Line) do
      begin
        ProcessLine(Line);
      end;
    finally
      Reader.Free;
    end;

    while FTip <> nil do
    begin
      FinalizeBlock(FTip);
    end;

    Result := BuildDocument(Length(Source));
  finally
    FreeAndNil(FRoot);
  end;

  RunDocumentProcessors(Result);
end;

procedure TBlockParser.RunDocumentProcessors(const Document: IMarkdownDocument);
begin
  for var Processor in FConfiguration.DocumentProcessors do
  begin
    Processor.Process(Document);
  end;
end;

procedure TBlockParser.ProcessLine(const Line: TSourceLine);
begin
  Inc(FLineNumber);
  FCurrentLine := Line;
  FThematicBreakScan := Default(TThematicBreakScan);
  FScanner.Reset(Line.Text);
  FBlank := FScanner.IsBlank;
  FOldTip := FTip;

  const Match = MatchContinuations;
  if Match.LineConsumed then
    Exit;

  var Container := Match.Container;
  FAllClosed := (Container = FOldTip);
  FLastMatchedContainer := Container;

  const LeafAlreadyMatched = (Container.Kind <> TMarkdownNodeKind.Paragraph) and AcceptsLines(Container.Kind);
  Container := OpenNewBlocks(Container, LeafAlreadyMatched);

  AddTextToContainer(Container);
end;

function TBlockParser.MatchContinuations: TContinuationMatch;
begin
  Result.LineConsumed := False;
  Result.Container := FRoot;

  var Child := Result.Container.LastChild;

  while (Child <> nil) and Child.IsOpen do
  begin
    Result.Container := Child;
    FBlank := FScanner.IsBlank;

    const ContinuationResult = ContinueBlock(Result.Container);
    case ContinuationResult of
      TContinueResult.Continued:
        ;
      TContinueResult.Rejected:
        begin
          Result.Container := Result.Container.Parent;
          Exit;
        end;
      TContinueResult.Consumed:
        begin
          Result.LineConsumed := True;
          Exit;
        end;
    else
      raise EMarkdownError.CreateFmt('Unhandled continuation result: %d', [Ord(ContinuationResult)]);
    end;

    Child := Result.Container.LastChild;
  end;
end;

function TBlockParser.ContinueBlock(const Block: TStagingBlock): TContinueResult;
begin
  case Block.Kind of
    TMarkdownNodeKind.BlockQuote:
      Result := ContinueBlockQuote;
    TMarkdownNodeKind.ListItem:
      Result := ContinueListItem(Block);
    TMarkdownNodeKind.CodeBlock:
      Result := ContinueCodeBlock(Block);
    TMarkdownNodeKind.HtmlBlock:
      Result := ContinueHtmlBlock(Block);
    TMarkdownNodeKind.Table:
      Result := ContinueTable;
    TMarkdownNodeKind.Heading, TMarkdownNodeKind.ThematicBreak:
      Result := TContinueResult.Rejected;
    TMarkdownNodeKind.Paragraph:
      begin
        if FBlank then
          Result := TContinueResult.Rejected
        else
          Result := TContinueResult.Continued;
      end;
  else
    Result := TContinueResult.Continued;
  end;
end;

function TBlockParser.ContinueBlockQuote: TContinueResult;
begin
  if not TryConsumeBlockQuoteMarker then
    Exit(TContinueResult.Rejected);

  Result := TContinueResult.Continued;
end;

function TBlockParser.ContinueListItem(const Block: TStagingBlock): TContinueResult;
begin
  if FBlank then
  begin
    const IsEmptyItem = (Block.Children.Count = 0);
    if IsEmptyItem then
      Exit(TContinueResult.Rejected);

    FScanner.AdvanceNextNonSpace;

    Exit(TContinueResult.Continued);
  end;

  const RequiredIndent = Block.ListData.MarkerOffset + Block.ListData.Padding;
  if FScanner.Indent >= RequiredIndent then
  begin
    FScanner.AdvanceOffset(RequiredIndent, True);

    Exit(TContinueResult.Continued);
  end;

  Result := TContinueResult.Rejected;
end;

function TBlockParser.ContinueCodeBlock(const Block: TStagingBlock): TContinueResult;
begin
  if Block.IsFenced then
  begin
    const AtClosingFence = (FScanner.Indent < CodeIndent) and (FScanner.NextChar = Block.FenceChar) and
      IsClosingFenceLine(Block);
    if AtClosingFence then
    begin
      FinalizeBlock(Block);

      Exit(TContinueResult.Consumed);
    end;

    var Remaining := Block.FenceOffset;

    while (Remaining > 0) and TLineScanner.IsSpaceOrTab(FScanner.CharAt(FScanner.Offset)) do
    begin
      FScanner.AdvanceOffset(1, True);
      Dec(Remaining);
    end;

    Exit(TContinueResult.Continued);
  end;

  if FScanner.Indent >= CodeIndent then
  begin
    FScanner.AdvanceOffset(CodeIndent, True);

    Exit(TContinueResult.Continued);
  end;

  if FBlank then
  begin
    FScanner.AdvanceNextNonSpace;

    Exit(TContinueResult.Continued);
  end;

  Result := TContinueResult.Rejected;
end;

function TBlockParser.IsClosingFenceLine(const Block: TStagingBlock): Boolean;
begin
  const Line = FScanner.Line;
  var Index := FScanner.NextNonSpaceIndex;
  var RunLength := 0;

  while (Index <= Length(Line)) and (Line[Index] = Block.FenceChar) do
  begin
    Inc(RunLength);
    Inc(Index);
  end;

  if RunLength < Block.FenceLength then
    Exit(False);

  while (Index <= Length(Line)) and TLineScanner.IsSpaceOrTab(Line[Index]) do
  begin
    Inc(Index);
  end;

  Result := (Index > Length(Line));
end;

function TBlockParser.ContinueHtmlBlock(const Block: TStagingBlock): TContinueResult;
begin
  const EndsHere = FBlank and THtmlBlockScanner.EndsAtBlankLine(Block.HtmlKind);
  if EndsHere then
    Exit(TContinueResult.Rejected);

  Result := TContinueResult.Continued;
end;

function TBlockParser.ContinueTable: TContinueResult;
begin
  if FBlank then
    Exit(TContinueResult.Rejected);

  if TableRowIsInterrupted then
    Exit(TContinueResult.Rejected);

  Result := TContinueResult.Continued;
end;

function TBlockParser.TableRowIsInterrupted: Boolean;
begin
  if FScanner.Indent >= CodeIndent then
    Exit(False);

  if FScanner.NextChar = GreaterThanChar then
    Exit(True);

  var Level: Integer;
  var Content: string;
  if TryMatchAtxHeading(Level, Content) then
    Exit(True);

  if IsThematicBreakLine then
    Exit(True);

  if IsFenceOpeningLine then
    Exit(True);

  Result := IsListMarkerLine;
end;

function TBlockParser.IsFenceOpeningLine: Boolean;
begin
  const Marker = FScanner.NextChar;
  const IsFenceChar = (Marker = BacktickChar) or (Marker = TildeChar);
  if not IsFenceChar then
    Exit(False);

  const Line = FScanner.Line;
  var Index := FScanner.NextNonSpaceIndex;
  var RunLength := 0;

  while (Index <= Length(Line)) and (Line[Index] = Marker) do
  begin
    Inc(RunLength);
    Inc(Index);
  end;

  if RunLength < MinFenceLength then
    Exit(False);

  if Marker = BacktickChar then
    Exit(Pos(BacktickChar, Line, Index) = 0);

  Result := True;
end;

function TBlockParser.IsListMarkerLine: Boolean;
begin
  const Marker = FScanner.NextChar;

  if IsBulletChar(Marker) then
  begin
    const AfterBullet = FScanner.CharAt(FScanner.NextNonSpaceIndex + 1);

    Exit((AfterBullet = #0) or TLineScanner.IsSpaceOrTab(AfterBullet));
  end;

  var Number: Integer;
  var DigitCount: Integer;
  var DelimiterIndex: Integer;
  if not TryScanOrderedMarker(Number, DigitCount, DelimiterIndex) then
    Exit(False);

  const AfterDelimiter = FScanner.CharAt(DelimiterIndex + 1);
  Result := (AfterDelimiter = #0) or TLineScanner.IsSpaceOrTab(AfterDelimiter);
end;

function TBlockParser.OpenNewBlocks(const StartContainer: TStagingBlock;
                                    const LeafAlreadyMatched: Boolean): TStagingBlock;
begin
  Result := StartContainer;
  var MatchedLeaf := LeafAlreadyMatched;

  while not MatchedLeaf do
  begin
    FBlank := FScanner.IsBlank;

    const BlockStart = TryStartBlock(Result);
    case BlockStart of
      TMarkdownBlockStart.NoMatch:
        begin
          FScanner.AdvanceNextNonSpace;
          Exit;
        end;
      TMarkdownBlockStart.Container:
        Result := FTip;
      TMarkdownBlockStart.Leaf:
        begin
          Result := FTip;
          MatchedLeaf := True;
        end;
    else
      raise EMarkdownError.CreateFmt('Unhandled block start: %d', [Ord(BlockStart)]);
    end;
  end;
end;

function TBlockParser.TryStartBlock(const Container: TStagingBlock): TMarkdownBlockStart;
begin
  FStartContainer := Container;

  const Trigger = FScanner.NextChar;
  for var Registration in FConfiguration.BlockParsers do
  begin
    const Triggered = (Registration.TriggerCharacters = '') or (Pos(Trigger, Registration.TriggerCharacters) > 0);
    if not Triggered then
      Continue;

    Result := Registration.Parser.TryStart(FContext);
    if Result <> TMarkdownBlockStart.NoMatch then
      Exit;
  end;

  Result := TMarkdownBlockStart.NoMatch;
end;

function TBlockParser.TryStartBlockQuote: TMarkdownBlockStart;
begin
  if not TryConsumeBlockQuoteMarker then
    Exit(TMarkdownBlockStart.NoMatch);

  CloseUnmatchedBlocks;
  AddChild(TMarkdownNodeKind.BlockQuote);

  Result := TMarkdownBlockStart.Container;
end;

function TBlockParser.TryConsumeBlockQuoteMarker: Boolean;
begin
  const HasMarker = (FScanner.Indent < CodeIndent) and (FScanner.NextChar = GreaterThanChar);
  if not HasMarker then
    Exit(False);

  FScanner.AdvanceNextNonSpace;
  FScanner.AdvanceOffset(1, False);

  if TLineScanner.IsSpaceOrTab(FScanner.CharAt(FScanner.Offset)) then
    FScanner.AdvanceOffset(1, True);

  Result := True;
end;

function TBlockParser.TryStartAtxHeading: TMarkdownBlockStart;
begin
  if FScanner.Indent >= CodeIndent then
    Exit(TMarkdownBlockStart.NoMatch);

  var Level: Integer;
  var Content: string;

  if not TryMatchAtxHeading(Level, Content) then
    Exit(TMarkdownBlockStart.NoMatch);

  FScanner.AdvanceNextNonSpace;
  FScanner.AdvanceToLineEnd;
  CloseUnmatchedBlocks;

  const Heading = AddChild(TMarkdownNodeKind.Heading);
  Heading.HeadingLevel := Level;
  Heading.Content.Append(Content);

  Result := TMarkdownBlockStart.Leaf;
end;

function TBlockParser.TryMatchAtxHeading(out Level: Integer; out Content: string): Boolean;
begin
  Level := 0;
  Content := '';
  const Line = FScanner.Line;
  var Index := FScanner.NextNonSpaceIndex;

  while (Index <= Length(Line)) and (Line[Index] = HashChar) do
  begin
    Inc(Level);
    Inc(Index);
  end;

  const ValidLevel = (Level >= 1) and (Level <= MaxHeadingLevel);
  if not ValidLevel then
    Exit(False);

  const AtLineEnd = (Index > Length(Line));
  const HasSpaceAfter = (not AtLineEnd) and TLineScanner.IsSpaceOrTab(Line[Index]);
  if not (AtLineEnd or HasSpaceAfter) then
    Exit(False);

  const RawContent = FScanner.TextFrom(Index).Trim(TrimChars);
  Content := StripAtxClosingSequence(RawContent);
  Result := True;
end;

class function TBlockParser.StripAtxClosingSequence(const Value: string): string;
begin
  var Index := Length(Value);

  while (Index >= 1) and (Value[Index] = HashChar) do
  begin
    Dec(Index);
  end;

  const RunLength = Length(Value) - Index;
  if RunLength = 0 then
    Exit(Value);

  const IsEntireContent = (Index = 0);
  if IsEntireContent then
    Exit('');

  const PrecededBySpace = TLineScanner.IsSpaceOrTab(Value[Index]);
  if not PrecededBySpace then
    Exit(Value);

  Result := Copy(Value, 1, Index).TrimRight(TrimChars);
end;

function TBlockParser.TryStartFencedCode: TMarkdownBlockStart;
begin
  if FScanner.Indent >= CodeIndent then
    Exit(TMarkdownBlockStart.NoMatch);

  const Marker = FScanner.NextChar;
  const IsFenceChar = (Marker = BacktickChar) or (Marker = TildeChar);
  if not IsFenceChar then
    Exit(TMarkdownBlockStart.NoMatch);

  const Line = FScanner.Line;
  var Index := FScanner.NextNonSpaceIndex;
  var RunLength := 0;

  while (Index <= Length(Line)) and (Line[Index] = Marker) do
  begin
    Inc(RunLength);
    Inc(Index);
  end;

  if RunLength < MinFenceLength then
    Exit(TMarkdownBlockStart.NoMatch);

  if Marker = BacktickChar then
  begin
    const RestContainsBacktick = (Pos(BacktickChar, Line, Index) > 0);
    if RestContainsBacktick then
      Exit(TMarkdownBlockStart.NoMatch);
  end;

  const FenceIndent = FScanner.Indent;
  CloseUnmatchedBlocks;

  const CodeBlock = AddChild(TMarkdownNodeKind.CodeBlock);
  CodeBlock.IsFenced := True;
  CodeBlock.FenceChar := Marker;
  CodeBlock.FenceLength := RunLength;
  CodeBlock.FenceOffset := FenceIndent;

  FScanner.AdvanceNextNonSpace;
  FScanner.AdvanceOffset(RunLength, False);

  Result := TMarkdownBlockStart.Leaf;
end;

function TBlockParser.TryStartHtmlBlock(const Container: TStagingBlock): TMarkdownBlockStart;
begin
  const MayStart = (FScanner.Indent < CodeIndent) and (FScanner.NextChar = LessThanChar);
  if not MayStart then
    Exit(TMarkdownBlockStart.NoMatch);

  const MaybeLazyParagraph = (not FAllClosed) and (not FBlank) and
    (FTip.Kind = TMarkdownNodeKind.Paragraph);
  const AllowInterruptingKind = (Container.Kind <> TMarkdownNodeKind.Paragraph) and (not MaybeLazyParagraph);
  const LineRest = FScanner.TextFrom(FScanner.NextNonSpaceIndex);

  var HtmlKind: THtmlBlockKind;
  if not FHtmlScanner.TryMatchStart(LineRest, AllowInterruptingKind, HtmlKind) then
    Exit(TMarkdownBlockStart.NoMatch);

  CloseUnmatchedBlocks;

  const HtmlBlock = AddChild(TMarkdownNodeKind.HtmlBlock);
  HtmlBlock.HtmlKind := HtmlKind;

  Result := TMarkdownBlockStart.Leaf;
end;

function TBlockParser.TryStartSetextHeading(const Container: TStagingBlock): TMarkdownBlockStart;
begin
  const MayStart = (FScanner.Indent < CodeIndent) and (Container.Kind = TMarkdownNodeKind.Paragraph);
  if not MayStart then
    Exit(TMarkdownBlockStart.NoMatch);

  var Level: Integer;
  if not TryMatchSetextUnderline(Level) then
    Exit(TMarkdownBlockStart.NoMatch);

  CloseUnmatchedBlocks;
  StripLeadingReferences(Container);

  const HasContent = (Container.Content.Length > 0);
  if not HasContent then
    Exit(TMarkdownBlockStart.NoMatch);

  Container.Kind := TMarkdownNodeKind.Heading;
  Container.HeadingLevel := Level;
  FScanner.AdvanceToLineEnd;

  Result := TMarkdownBlockStart.Leaf;
end;

function TBlockParser.TryMatchSetextUnderline(out Level: Integer): Boolean;
begin
  Level := 0;
  const Marker = FScanner.NextChar;

  if Marker = EqualsChar then
    Level := 1
  else if Marker = DashChar then
    Level := 2
  else
    Exit(False);

  const Line = FScanner.Line;
  var Index := FScanner.NextNonSpaceIndex;

  while (Index <= Length(Line)) and (Line[Index] = Marker) do
  begin
    Inc(Index);
  end;

  while (Index <= Length(Line)) and TLineScanner.IsSpaceOrTab(Line[Index]) do
  begin
    Inc(Index);
  end;

  Result := (Index > Length(Line));
end;

function TBlockParser.TryStartTable(const Container: TStagingBlock): TMarkdownBlockStart;
begin
  const MayStart = (FScanner.Indent < CodeIndent) and (Container.Kind = TMarkdownNodeKind.Paragraph);
  if not MayStart then
    Exit(TMarkdownBlockStart.NoMatch);

  var Alignments: TArray<TMarkdownTableColumnAlignment>;
  if not TryParseTableDelimiterRow(FScanner.TextFrom(FScanner.NextNonSpaceIndex), Alignments) then
    Exit(TMarkdownBlockStart.NoMatch);

  const HeaderContent = Container.Content.ToString;
  const NewlinePosition = Pos(LineFeed, HeaderContent);
  const IsSingleLineHeader = (NewlinePosition = Length(HeaderContent)) and (NewlinePosition > 1);
  if not IsSingleLineHeader then
    Exit(TMarkdownBlockStart.NoMatch);

  const HeaderCells = SplitTableRow(Copy(HeaderContent, 1, NewlinePosition - 1));
  const ColumnsMatch = (Length(HeaderCells) = Length(Alignments));
  if not ColumnsMatch then
    Exit(TMarkdownBlockStart.NoMatch);

  CloseUnmatchedBlocks;
  Container.Kind := TMarkdownNodeKind.Table;
  Container.TableAlignments := Alignments;
  FScanner.AdvanceToLineEnd;

  Result := TMarkdownBlockStart.Leaf;
end;

class function TBlockParser.TryParseTableDelimiterRow(const Line: string;
                                                      out Alignments: TArray<TMarkdownTableColumnAlignment>): Boolean;
begin
  const Cells = SplitTableRow(Line);
  const HasCells = (Length(Cells) > 0);
  if not HasCells then
    Exit(False);

  SetLength(Alignments, Length(Cells));

  for var Index := 0 to High(Cells) do
  begin
    if not TryParseTableDelimiterCell(Cells[Index], Alignments[Index]) then
      Exit(False);
  end;

  Result := True;
end;

class function TBlockParser.TryParseTableDelimiterCell(const Cell: string;
                                                       out Alignment: TMarkdownTableColumnAlignment): Boolean;
begin
  Alignment := TMarkdownTableColumnAlignment.None;

  if Cell = '' then
    Exit(False);

  var StartIndex := 1;
  var EndIndex := Length(Cell);

  const HasLeadingColon = (Cell[StartIndex] = ColonChar);
  if HasLeadingColon then
    Inc(StartIndex);

  const HasTrailingColon = (EndIndex >= StartIndex) and (Cell[EndIndex] = ColonChar);
  if HasTrailingColon then
    Dec(EndIndex);

  const HasDashes = (EndIndex >= StartIndex);
  if not HasDashes then
    Exit(False);

  for var Index := StartIndex to EndIndex do
  begin
    if Cell[Index] <> DashChar then
      Exit(False);
  end;

  if HasLeadingColon and HasTrailingColon then
    Alignment := TMarkdownTableColumnAlignment.Center
  else if HasTrailingColon then
    Alignment := TMarkdownTableColumnAlignment.Right
  else if HasLeadingColon then
    Alignment := TMarkdownTableColumnAlignment.Left;

  Result := True;
end;

class function TBlockParser.SplitTableRow(const Line: string): TArray<string>;
begin
  const Trimmed = Line.Trim(TrimChars);
  const Cells = TList<string>.Create;
  const Cell = TStringBuilder.Create;
  try
    var Index := 1;
    var EndsAtBoundary := (Trimmed <> '') and (Trimmed[1] = PipeChar);
    if EndsAtBoundary then
      Index := 2;

    while Index <= Length(Trimmed) do
    begin
      const Current = Trimmed[Index];

      if (Current = BackslashChar) and (Index < Length(Trimmed)) then
      begin
        if Trimmed[Index + 1] = PipeChar then
        begin
          Cell.Append(PipeChar);
        end
        else
        begin
          Cell.Append(Current);
          Cell.Append(Trimmed[Index + 1]);
        end;

        EndsAtBoundary := False;
        Inc(Index, 2);
        Continue;
      end;

      if Current = PipeChar then
      begin
        Cells.Add(Cell.ToString.Trim(TrimChars));
        Cell.Clear;
        EndsAtBoundary := True;
      end
      else
      begin
        Cell.Append(Current);
        EndsAtBoundary := False;
      end;

      Inc(Index);
    end;

    const HasTrailingCell = (Cell.Length > 0) or (not EndsAtBoundary);
    if HasTrailingCell then
      Cells.Add(Cell.ToString.Trim(TrimChars));

    Result := Cells.ToArray;
  finally
    Cell.Free;
    Cells.Free;
  end;
end;

function TBlockParser.TryStartThematicBreak: TMarkdownBlockStart;
begin
  const IsBreak = (FScanner.Indent < CodeIndent) and IsThematicBreakLine;
  if not IsBreak then
    Exit(TMarkdownBlockStart.NoMatch);

  CloseUnmatchedBlocks;
  AddChild(TMarkdownNodeKind.ThematicBreak);
  FScanner.AdvanceToLineEnd;

  Result := TMarkdownBlockStart.Leaf;
end;

function TBlockParser.IsThematicBreakLine: Boolean;
begin
  const Marker = FScanner.NextChar;
  const IsMarker = (Marker = AsteriskChar) or (Marker = DashChar) or (Marker = UnderscoreChar);
  if not IsMarker then
    Exit(False);

  const IsScanCurrent = (FThematicBreakScan.Marker = Marker);
  if not IsScanCurrent then
    FThematicBreakScan := ScanThematicBreak(Marker);

  // Something other than the marker follows, so no starting point left of it can
  // be a thematic break either. This is the answer for every marker on a line
  // such as "- - - - x", and it costs nothing after the first scan.
  const RunIsBroken = (FThematicBreakScan.LastForeignIndex >= FScanner.NextNonSpaceIndex);
  if RunIsBroken then
    Exit(False);

  var MarkerCount := 0;
  const Line = FScanner.Line;

  for var Index := FScanner.NextNonSpaceIndex to Length(Line) do
  begin
    if Line[Index] = Marker then
      Inc(MarkerCount);
  end;

  Result := (MarkerCount >= MinThematicMarkers);
end;

// Reports the rightmost position holding something that is neither the marker
// nor a space or tab, or zero when the line has no such character.
function TBlockParser.ScanThematicBreak(const Marker: Char): TThematicBreakScan;
begin
  Result.Marker := Marker;
  Result.LastForeignIndex := 0;

  const Line = FScanner.Line;

  for var Index := Length(Line) downto 1 do
  begin
    const Current = Line[Index];
    const IsForeign = (Current <> Marker) and (not TLineScanner.IsSpaceOrTab(Current));
    if IsForeign then
    begin
      Result.LastForeignIndex := Index;
      Exit;
    end;
  end;
end;

function TBlockParser.TryStartListItem(const Container: TStagingBlock): TMarkdownBlockStart;
begin
  const MayStart = (FScanner.Indent < CodeIndent) or (Container.Kind = TMarkdownNodeKind.List);
  if not MayStart then
    Exit(TMarkdownBlockStart.NoMatch);

  var MarkerData: TListData;
  if not TryParseListMarker(Container, MarkerData) then
    Exit(TMarkdownBlockStart.NoMatch);

  CloseUnmatchedBlocks;

  const NeedsNewList = (FTip.Kind <> TMarkdownNodeKind.List) or (not Container.ListData.MatchesKind(MarkerData));
  if NeedsNewList then
  begin
    const List = AddChild(TMarkdownNodeKind.List);
    List.ListData := MarkerData;
  end;

  const Item = AddChild(TMarkdownNodeKind.ListItem);
  Item.ListData := MarkerData;

  Result := TMarkdownBlockStart.Container;
end;

function TBlockParser.TryParseListMarker(const Container: TStagingBlock; out MarkerData: TListData): Boolean;
begin
  MarkerData := Default(TListData);

  if FScanner.Indent >= CodeIndent then
    Exit(False);

  var MarkerLength: Integer;
  if not TryMatchListMarker(Container, MarkerData, MarkerLength) then
    Exit(False);

  const AfterMarker = FScanner.CharAt(FScanner.NextNonSpaceIndex + MarkerLength);
  const HasValidTerminator = (AfterMarker = #0) or TLineScanner.IsSpaceOrTab(AfterMarker);
  if not HasValidTerminator then
    Exit(False);

  const InterruptsParagraphWithBlank = (Container.Kind = TMarkdownNodeKind.Paragraph) and
    FScanner.IsBlankFrom(FScanner.NextNonSpaceIndex + MarkerLength);
  if InterruptsParagraphWithBlank then
    Exit(False);

  FScanner.AdvanceNextNonSpace;
  FScanner.AdvanceOffset(MarkerLength, True);

  MarkerData.Padding := ComputeMarkerPadding(MarkerLength);
  Result := True;
end;

function TBlockParser.TryMatchListMarker(const Container: TStagingBlock; out MarkerData: TListData;
                                         out MarkerLength: Integer): Boolean;
begin
  MarkerData := Default(TListData);
  MarkerData.IsTight := True;
  MarkerData.StartNumber := 1;
  MarkerData.MarkerOffset := FScanner.Indent;
  MarkerLength := 0;

  const Marker = FScanner.NextChar;
  if IsBulletChar(Marker) then
  begin
    MarkerData.BulletChar := Marker;
    MarkerLength := 1;

    Exit(True);
  end;

  var Number: Integer;
  var DigitCount: Integer;
  var DelimiterIndex: Integer;
  if not TryScanOrderedMarker(Number, DigitCount, DelimiterIndex) then
    Exit(False);

  const CanInterrupt = (Container.Kind <> TMarkdownNodeKind.Paragraph) or (Number = 1);
  if not CanInterrupt then
    Exit(False);

  MarkerData.IsOrdered := True;
  MarkerData.StartNumber := Number;
  MarkerData.Delimiter := FScanner.Line[DelimiterIndex];
  MarkerLength := DigitCount + 1;
  Result := True;
end;

function TBlockParser.TryScanOrderedMarker(out Number, DigitCount, DelimiterIndex: Integer): Boolean;
begin
  Number := 0;
  DigitCount := 0;
  DelimiterIndex := 0;
  const Line = FScanner.Line;
  var Index := FScanner.NextNonSpaceIndex;

  while (Index <= Length(Line)) and (Line[Index] >= ZeroChar) and (Line[Index] <= NineChar) do
  begin
    Number := (Number * 10) + (Ord(Line[Index]) - Ord(ZeroChar));
    Inc(DigitCount);
    Inc(Index);

    if DigitCount > MaxOrderedDigits then
      Exit(False);
  end;

  if DigitCount = 0 then
    Exit(False);

  const HasDelimiter = (Index <= Length(Line)) and ((Line[Index] = DotChar) or (Line[Index] = RightParenChar));
  if not HasDelimiter then
    Exit(False);

  DelimiterIndex := Index;
  Result := True;
end;

class function TBlockParser.IsBulletChar(const Value: Char): Boolean;
begin
  Result := (Value = AsteriskChar) or (Value = PlusChar) or (Value = DashChar);
end;

function TBlockParser.ComputeMarkerPadding(const MarkerLength: Integer): Integer;
begin
  const SpacesStartColumn = FScanner.Column;
  const SavedState = FScanner.SaveState;

  var KeepConsumingSpaces := True;
  while KeepConsumingSpaces do
  begin
    FScanner.AdvanceOffset(1, True);

    const WithinPaddingLimit = (FScanner.Column - SpacesStartColumn < MaxMarkerPaddingColumns);
    const AtSpaceOrTab = TLineScanner.IsSpaceOrTab(FScanner.CharAt(FScanner.Offset));
    KeepConsumingSpaces := WithinPaddingLimit and AtSpaceOrTab;
  end;

  const BlankItem = (FScanner.CharAt(FScanner.Offset) = #0);
  const SpacesAfterMarker = FScanner.Column - SpacesStartColumn;

  const UseSingleSpacePadding = (SpacesAfterMarker >= MaxMarkerPaddingColumns) or (SpacesAfterMarker < 1) or BlankItem;
  if not UseSingleSpacePadding then
    Exit(MarkerLength + SpacesAfterMarker);

  FScanner.RestoreState(SavedState);

  if TLineScanner.IsSpaceOrTab(FScanner.CharAt(FScanner.Offset)) then
    FScanner.AdvanceOffset(1, True);

  Result := MarkerLength + 1;
end;

function TBlockParser.TryStartIndentedCode: TMarkdownBlockStart;
begin
  const StartsCode = (FScanner.Indent >= CodeIndent) and (FTip.Kind <> TMarkdownNodeKind.Paragraph) and
    (not FBlank);
  if not StartsCode then
    Exit(TMarkdownBlockStart.NoMatch);

  FScanner.AdvanceOffset(CodeIndent, True);
  CloseUnmatchedBlocks;
  AddChild(TMarkdownNodeKind.CodeBlock);

  Result := TMarkdownBlockStart.Leaf;
end;

procedure TBlockParser.AddTextToContainer(const Container: TStagingBlock);
begin
  const IsLazyContinuation = (not FAllClosed) and (not FBlank) and
    (FTip.Kind = TMarkdownNodeKind.Paragraph);
  if IsLazyContinuation then
  begin
    AddLineToTip;
    Exit;
  end;

  CloseUnmatchedBlocks;

  if FBlank and (Container.LastChild <> nil) then
    Container.LastChild.LastLineBlank := True;

  UpdateLastLineBlank(Container);

  if AcceptsLines(Container.Kind) then
  begin
    AddLineToTip;

    const HtmlEndsHere = (Container.Kind = TMarkdownNodeKind.HtmlBlock) and
      FHtmlScanner.EndsOnSameLine(Container.HtmlKind, FScanner.RestOfLine);
    if HtmlEndsHere then
      FinalizeBlock(Container);

    Exit;
  end;

  const HasText = (not FBlank) and (FScanner.Offset <= Length(FScanner.Line));
  if HasText then
  begin
    AddChild(TMarkdownNodeKind.Paragraph);
    FScanner.AdvanceNextNonSpace;
    AddLineToTip;
  end;
end;

procedure TBlockParser.UpdateLastLineBlank(const Container: TStagingBlock);
begin
  const IsFreshEmptyListItem = (Container.Kind = TMarkdownNodeKind.ListItem) and
    (Container.Children.Count = 0) and (Container.StartLine = FLineNumber);
  const IgnoresBlank = (Container.Kind = TMarkdownNodeKind.BlockQuote) or
    ((Container.Kind = TMarkdownNodeKind.CodeBlock) and Container.IsFenced) or IsFreshEmptyListItem;
  const LastLineBlank = FBlank and (not IgnoresBlank);

  var Ancestor := Container;

  while Ancestor <> nil do
  begin
    Ancestor.LastLineBlank := LastLineBlank;
    Ancestor := Ancestor.Parent;
  end;
end;

procedure TBlockParser.AddLineToTip;
begin
  FTip.Content.Append(FScanner.RestOfLine);
  FTip.Content.Append(LineFeed);
  FTip.EndOffset := FCurrentLine.EndOffset;
end;

procedure TBlockParser.CloseUnmatchedBlocks;
begin
  if FAllClosed then
    Exit;

  while FOldTip <> FLastMatchedContainer do
  begin
    const Parent = FOldTip.Parent;
    FinalizeBlock(FOldTip);
    FOldTip := Parent;
  end;

  FAllClosed := True;
end;

function TBlockParser.AddChild(const Kind: TMarkdownNodeKind): TStagingBlock;
begin
  while not CanContain(FTip.Kind, Kind) do
  begin
    FinalizeBlock(FTip);
  end;

  Result := TStagingBlock.Create(Kind, FTip);
  Result.StartLine := FLineNumber;
  Result.StartOffset := FCurrentLine.StartOffset;
  Result.EndOffset := FCurrentLine.EndOffset;

  FTip.Children.Add(Result);
  FTip := Result;
end;

class function TBlockParser.CanContain(const ParentKind, ChildKind: TMarkdownNodeKind): Boolean;
begin
  case ParentKind of
    TMarkdownNodeKind.Document, TMarkdownNodeKind.BlockQuote, TMarkdownNodeKind.ListItem:
      Result := (ChildKind <> TMarkdownNodeKind.ListItem);
    TMarkdownNodeKind.List:
      Result := (ChildKind = TMarkdownNodeKind.ListItem);
  else
    Result := False;
  end;
end;

class function TBlockParser.AcceptsLines(const Kind: TMarkdownNodeKind): Boolean;
begin
  Result := (Kind = TMarkdownNodeKind.Paragraph) or (Kind = TMarkdownNodeKind.CodeBlock) or
    (Kind = TMarkdownNodeKind.HtmlBlock) or (Kind = TMarkdownNodeKind.Table);
end;

procedure TBlockParser.FinalizeBlock(const Block: TStagingBlock);
begin
  const Parent = Block.Parent;
  Block.IsOpen := False;

  if Block.LastChild <> nil then
  begin
    const ChildEnd = Block.LastChild.EndOffset;
    if ChildEnd > Block.EndOffset then
      Block.EndOffset := ChildEnd;
  end;

  var ShouldUnlink := False;

  case Block.Kind of
    TMarkdownNodeKind.Paragraph:
      ShouldUnlink := FinalizeParagraph(Block);
    TMarkdownNodeKind.CodeBlock:
      FinalizeCodeBlock(Block);
    TMarkdownNodeKind.HtmlBlock:
      FinalizeHtmlBlock(Block);
    TMarkdownNodeKind.List:
      FinalizeList(Block);
  else
    ;
  end;

  // Every descendant is final by now, so the block can settle whether it trails
  // a blank line once instead of being asked again for each enclosing list.
  const IsListLevel = (Block.Kind = TMarkdownNodeKind.List) or (Block.Kind = TMarkdownNodeKind.ListItem);
  const InnermostTrailsBlank = IsListLevel and (Block.LastChild <> nil) and Block.LastChild.EndsWithBlankLine;
  Block.EndsWithBlankLine := Block.LastLineBlank or InnermostTrailsBlank;

  FTip := Parent;

  if ShouldUnlink then
    Parent.Children.Remove(Block);
end;

function TBlockParser.FinalizeParagraph(const Block: TStagingBlock): Boolean;
begin
  StripLeadingReferences(Block);

  Result := Block.HadStrippedReferences and IsBlankText(Block.Content.ToString);
end;

procedure TBlockParser.StripLeadingReferences(const Block: TStagingBlock);
begin
  var Stripped := False;
  var Content := Block.Content.ToString;

  while (Content <> '') and (Content[1] = OpenBracketChar) do
  begin
    var Consumed: Integer;
    if not FReferenceParser.TryConsumeReference(Content, FActiveReferences, Consumed) then
      Break;

    Content := Copy(Content, Consumed + 1, MaxInt);
    Stripped := True;
  end;

  if Stripped then
  begin
    Block.HadStrippedReferences := True;
    Block.Content.Clear;
    Block.Content.Append(Content);
  end;
end;

class function TBlockParser.IsBlankText(const Value: string): Boolean;
begin
  for var Current in Value do
  begin
    if not TMarkdownUnescape.IsMarkdownWhitespace(Current) then
      Exit(False);
  end;

  Result := True;
end;

procedure TBlockParser.FinalizeCodeBlock(const Block: TStagingBlock);
begin
  const Content = Block.Content.ToString;

  if not Block.IsFenced then
  begin
    Block.Literal := StripTrailingBlankLines(Content, True);
    Exit;
  end;

  const NewlinePosition = Pos(LineFeed, Content);
  if NewlinePosition = 0 then
  begin
    Block.InfoString := TMarkdownUnescape.Unescape(Content.Trim(TrimChars));
    Block.Literal := '';
    Exit;
  end;

  const InfoLine = Copy(Content, 1, NewlinePosition - 1);
  Block.InfoString := TMarkdownUnescape.Unescape(InfoLine.Trim(TrimChars));
  Block.Literal := Copy(Content, NewlinePosition + 1, MaxInt);
end;

procedure TBlockParser.FinalizeHtmlBlock(const Block: TStagingBlock);
begin
  Block.Literal := StripTrailingBlankLines(Block.Content.ToString, False);
end;

class function TBlockParser.StripTrailingBlankLines(const Value: string; const KeepFinalLineBreak: Boolean): string;
begin
  var LastContentIndex := Length(Value);

  while (LastContentIndex >= 1) and CharInSet(Value[LastContentIndex], [' ', #10]) do
  begin
    Dec(LastContentIndex);
  end;

  var FirstTrailingNewline := 0;

  for var Index := LastContentIndex + 1 to Length(Value) do
  begin
    if Value[Index] = LineFeed then
    begin
      FirstTrailingNewline := Index;
      Break;
    end;
  end;

  if FirstTrailingNewline = 0 then
    Exit(Value);

  Result := Copy(Value, 1, FirstTrailingNewline - 1);

  if KeepFinalLineBreak then
    Result := Result + LineFeed;
end;

procedure TBlockParser.FinalizeList(const Block: TStagingBlock);
begin
  if not ListIsLoose(Block) then
    Exit;

  var Data := Block.ListData;
  Data.IsTight := False;
  Block.ListData := Data;
end;

class function TBlockParser.ListIsLoose(const Block: TStagingBlock): Boolean;
begin
  const ItemCount = Block.Children.Count;

  for var ItemIndex := 0 to ItemCount - 1 do
  begin
    const Item = Block.Children[ItemIndex];
    const HasNextItem = (ItemIndex < ItemCount - 1);

    if Item.EndsWithBlankLine and HasNextItem then
      Exit(True);

    const SubCount = Item.Children.Count;

    for var SubIndex := 0 to SubCount - 1 do
    begin
      const SubItem = Item.Children[SubIndex];
      const HasNextBlock = HasNextItem or (SubIndex < SubCount - 1);

      if SubItem.EndsWithBlankLine and HasNextBlock then
        Exit(True);
    end;
  end;

  Result := False;
end;

function TBlockParser.BuildDocument(const SourceLength: Integer): IMarkdownDocument;
begin
  const DocumentNode = TMarkdownDocumentNode.Create;
  Result := DocumentNode;
  DocumentNode.SetSegment(TMarkdownSegment.Create(1, SourceLength + 1));

  AppendChildren(FRoot, DocumentNode);
end;

procedure TBlockParser.AppendChildren(const Staging: TStagingBlock; const AstParent: TMarkdownAstNode);
begin
  const Pending = TStack<TBuildFrame>.Create;
  try
    PushChildFrames(Pending, Staging, AstParent);

    while Pending.Count > 0 do
    begin
      const Frame = Pending.Pop;
      const Node = CreateNode(Frame.Staging);
      Frame.AstParent.AddChild(Node);

      if HasNestedBlocks(Frame.Staging.Kind) then
        PushChildFrames(Pending, Frame.Staging, Node);
    end;
  finally
    Pending.Free;
  end;
end;

class procedure TBlockParser.PushChildFrames(const Pending: TStack<TBuildFrame>; const Staging: TStagingBlock;
                                             const AstParent: TMarkdownAstNode);
begin
  for var Index := Staging.Children.Count - 1 downto 0 do
  begin
    var Frame: TBuildFrame;
    Frame.Staging := Staging.Children[Index];
    Frame.AstParent := AstParent;

    Pending.Push(Frame);
  end;
end;

function TBlockParser.CreateNode(const Block: TStagingBlock): TMarkdownAstNode;
begin
  case Block.Kind of
    TMarkdownNodeKind.Paragraph:
      begin
        Result := TMarkdownAstNode.Create(TMarkdownNodeKind.Paragraph);
        AttachInlines(Result, Block.Content.ToString, IsTaskListParagraph(Block));
      end;
    TMarkdownNodeKind.Heading:
      begin
        const HeadingNode = TMarkdownHeadingNode.Create(Block.HeadingLevel);
        HeadingNode.SetSourceLine(Block.StartLine);
        Result := HeadingNode;

        AttachInlines(Result, Block.Content.ToString, False);
      end;
    TMarkdownNodeKind.CodeBlock:
      Result := TMarkdownCodeBlockNode.Create(Block.Literal, Block.InfoString, Block.IsFenced);
    TMarkdownNodeKind.HtmlBlock:
      Result := TMarkdownTextNode.Create(TMarkdownNodeKind.HtmlBlock, Block.Literal);
    TMarkdownNodeKind.Table:
      Result := CreateTableNode(Block);
    TMarkdownNodeKind.List:
      Result := TMarkdownListNode.Create(Block.ListData.IsOrdered, Block.ListData.StartNumber,
        Block.ListData.IsTight);
  else
    Result := TMarkdownAstNode.Create(Block.Kind);
  end;

  Result.SetSegment(TMarkdownSegment.Create(Block.StartOffset, Block.EndOffset));
end;

function TBlockParser.CreateTableNode(const Block: TStagingBlock): TMarkdownAstNode;
begin
  Result := TMarkdownAstNode.Create(TMarkdownNodeKind.Table);

  const Alignments = Block.TableAlignments;
  const Lines = Block.Content.ToString.Split([LineFeed], TStringSplitOptions.ExcludeEmpty);

  for var LineIndex := 0 to High(Lines) do
  begin
    const IsHeaderRow = (LineIndex = 0);
    const Row = TMarkdownTableRowNode.Create(IsHeaderRow);
    const Cells = SplitTableRow(Lines[LineIndex]);

    for var ColumnIndex := 0 to High(Alignments) do
    begin
      const Cell = TMarkdownTableCellNode.Create(Alignments[ColumnIndex]);

      var CellText := '';
      if ColumnIndex <= High(Cells) then
        CellText := Cells[ColumnIndex];

      AttachInlines(Cell, CellText, False);
      Row.AddChild(Cell);
    end;

    Result.AddChild(Row);
  end;
end;

class function TBlockParser.IsTaskListParagraph(const Block: TStagingBlock): Boolean;
begin
  const Parent = Block.Parent;
  const IsListItemChild = (Parent <> nil) and (Parent.Kind = TMarkdownNodeKind.ListItem);

  Result := IsListItemChild and (Parent.Children[0] = Block);
end;

class function TBlockParser.HasNestedBlocks(const Kind: TMarkdownNodeKind): Boolean;
begin
  Result := (Kind = TMarkdownNodeKind.List) or (Kind = TMarkdownNodeKind.BlockQuote) or
    (Kind = TMarkdownNodeKind.ListItem);
end;

procedure TBlockParser.AttachInlines(const Node: TMarkdownAstNode; const Content: string;
                                     const IsTaskListCandidate: Boolean);
begin
  FInlineParser.TaskListCandidate := IsTaskListCandidate;
  FInlineParser.ParseInto(Node, Content.Trim(ContentTrimChars), FActiveReferences);
end;

constructor TBlockParserContext.Create(const Engine: TBlockParser);
begin
  inherited Create;

  FEngine := Engine;
end;

function TBlockParserContext.GetLineText: string;
begin
  Result := FEngine.FScanner.Line;
end;

function TBlockParserContext.GetIndent: Integer;
begin
  Result := FEngine.FScanner.Indent;
end;

function TBlockParserContext.GetIsBlankLine: Boolean;
begin
  Result := FEngine.FBlank;
end;

constructor TCommonMarkBlockStarter.Create(const Kind: TCommonMarkBlockKind);
begin
  inherited Create;

  FKind := Kind;
end;

function TCommonMarkBlockStarter.GetName: string;
begin
  Result := Names[FKind];
end;

function TCommonMarkBlockStarter.TryStart(const Context: IMarkdownBlockParserContext): TMarkdownBlockStart;
begin
  const Engine = (Context as TBlockParserContext).Engine;

  case FKind of
    TCommonMarkBlockKind.BlockQuote:
      Result := Engine.TryStartBlockQuote;
    TCommonMarkBlockKind.AtxHeading:
      Result := Engine.TryStartAtxHeading;
    TCommonMarkBlockKind.FencedCode:
      Result := Engine.TryStartFencedCode;
    TCommonMarkBlockKind.HtmlBlock:
      Result := Engine.TryStartHtmlBlock(Engine.FStartContainer);
    TCommonMarkBlockKind.SetextHeading:
      Result := Engine.TryStartSetextHeading(Engine.FStartContainer);
    TCommonMarkBlockKind.ThematicBreak:
      Result := Engine.TryStartThematicBreak;
    TCommonMarkBlockKind.ListItem:
      Result := Engine.TryStartListItem(Engine.FStartContainer);
  else
    Result := Engine.TryStartIndentedCode;
  end;
end;

function TGfmTableBlockStarter.GetName: string;
begin
  Result := TableParserName;
end;

function TGfmTableBlockStarter.TryStart(const Context: IMarkdownBlockParserContext): TMarkdownBlockStart;
begin
  const Engine = (Context as TBlockParserContext).Engine;

  Result := Engine.TryStartTable(Engine.FStartContainer);
end;

end.
