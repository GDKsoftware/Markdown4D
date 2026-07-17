unit Markdown4D.Parser.Inlines;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.RegularExpressions,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Pipeline.Configuration,
  Markdown4D.Parser.References,
  Markdown4D.Parser.LinkSyntax,
  Markdown4D.Parser.HtmlBlocks,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Ast;

type
  TInlineChainNode = class
  private
    FValue: IMarkdownNode;
    FPrev: TInlineChainNode;
    FNext: TInlineChainNode;

  public
    constructor Create(const Value: IMarkdownNode);
    property Value: IMarkdownNode read FValue;
    property Prev: TInlineChainNode read FPrev write FPrev;
    property Next: TInlineChainNode read FNext write FNext;
  end;

  TInlineDelimiter = class
  private
    FNode: TMarkdownTextNode;
    FChainNode: TInlineChainNode;
    FDelimiterChar: Char;
    FCount: Integer;
    FOriginalCount: Integer;
    FCanOpen: Boolean;
    FCanClose: Boolean;
    FProcessor: IMarkdownDelimiterProcessor;
    FPrev: TInlineDelimiter;
    FNext: TInlineDelimiter;

  public
    constructor Create(const Node: TMarkdownTextNode; const ChainNode: TInlineChainNode;
                       const DelimiterChar: Char; const Count: Integer; const CanOpen, CanClose: Boolean;
                       const Processor: IMarkdownDelimiterProcessor);
    property Node: TMarkdownTextNode read FNode;
    property ChainNode: TInlineChainNode read FChainNode;
    property DelimiterChar: Char read FDelimiterChar;
    property Count: Integer read FCount write FCount;
    property OriginalCount: Integer read FOriginalCount;
    property CanOpen: Boolean read FCanOpen;
    property CanClose: Boolean read FCanClose;
    property Processor: IMarkdownDelimiterProcessor read FProcessor;
    property Prev: TInlineDelimiter read FPrev write FPrev;
    property Next: TInlineDelimiter read FNext write FNext;
  end;

  TInlineBracket = class
  private
    FChainNode: TInlineChainNode;
    FContentStart: Integer;
    FDelimiterBottom: TInlineDelimiter;
    FIsImage: Boolean;
    FActive: Boolean;
    FBracketAfter: Boolean;

  public
    constructor Create(const ChainNode: TInlineChainNode; const ContentStart: Integer;
                       const DelimiterBottom: TInlineDelimiter; const IsImage: Boolean);
    property ChainNode: TInlineChainNode read FChainNode;
    property ContentStart: Integer read FContentStart;
    property DelimiterBottom: TInlineDelimiter read FDelimiterBottom;
    property IsImage: Boolean read FIsImage;
    property Active: Boolean read FActive write FActive;
    property BracketAfter: Boolean read FBracketAfter write FBracketAfter;
  end;

  TInlineParser = class
  private
    type
      TDelimiterRun = record
        Length: Integer;
        CanOpen: Boolean;
        CanClose: Boolean;
      end;
    const
      Backslash = '\';
      LineFeed = #10;
      Space = ' ';
      Tab = #9;
      Asterisk = '*';
      Underscore = '_';
      Backtick = '`';
      LessThan = '<';
      Ampersand = '&';
      Bang = '!';
      Tilde = '~';
      OpenBracket = '[';
      CloseBracket = ']';
      OpenParen = '(';
      CloseParen = ')';
      ImageOpenerText = '![';
      MailtoPrefix = 'mailto:';
      WwwPrefix = 'www.';
      HttpSchemePrefix = 'http://';
      UrlAutolinkSchemes: array[0..2] of string = (HttpSchemePrefix, 'https://', 'ftp://');
      HardBreakSpaceCount = 2;
      StrongDelimiterCount = 2;
      CollapsedLabelLength = 2;
      TaskMarkerLength = 3;
      RuleOfThreeDivisor = 3;
      OpenersBottomBucketsPerChar = 6;
      UriAutolinkPattern = '^<[A-Za-z][A-Za-z0-9.+-]{1,31}:[^<>\x00-\x20]*>';
      EmailAutolinkPattern = '^<([a-zA-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
        + '(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>';
      HtmlTagPattern = '^(?:' + THtmlBlockScanner.OpenTag + '|' + THtmlBlockScanner.CloseTag
        + '|<!-->|<!--->|<!--[\s\S]*?-->|<\?[\s\S]*?\?>|<![A-Za-z][^>]*>|<!\[CDATA\[[\s\S]*?\]\]>)';
    var
      FConfiguration: TMarkdownPipelineConfiguration;
      FContext: IMarkdownInlineParserContext;
      FTriggerMap: TObjectDictionary<Char, TList<IMarkdownInlineParser>>;
      FParent: TMarkdownAstNode;
      FContent: string;
      FIndex: Integer;
      FTextBuffer: TStringBuilder;
      FFirstInline: TInlineChainNode;
      FLastInline: TInlineChainNode;
      FFirstDelimiter: TInlineDelimiter;
      FLastDelimiter: TInlineDelimiter;
      FOpenersBottom: TDictionary<Integer, TInlineDelimiter>;
      FBrackets: TObjectList<TInlineBracket>;
      FReferenceMap: TLinkReferenceMap;
      FLinkScanner: TLinkSyntaxScanner;
      FUriAutolinkRegex: TRegEx;
      FEmailAutolinkRegex: TRegEx;
      FHtmlTagRegex: TRegEx;
      FTaskListCandidate: Boolean;
    procedure BuildTriggerMap;
    function TryDispatch(const Current: Char): Boolean;
    function TryHandleCustomDelimiterRun(const Processor: IMarkdownDelimiterProcessor): Boolean;
    procedure HandleBackslash;
    procedure HandleLineEnding;
    procedure HandleBackticks;
    procedure EmitCodeSpan(const RawContent: string);
    procedure HandleLessThan;
    procedure EmitAutolink(const LabelText, Destination: string);
    procedure HandleAmpersand;
    function TrimTrailingSpacesFromBuffer: Integer;
    procedure HandleDelimiterRun;
    function ScanDelimiterRun: TDelimiterRun;
    procedure EmitDelimiterRun(const Processor: IMarkdownDelimiterProcessor; const Run: TDelimiterRun);
    function CharBefore(const Index: Integer): Char;
    function CharAfter(const Index: Integer): Char;
    procedure HandleOpenBracket;
    procedure HandleBang;
    procedure PushBracket(const ChainNode: TInlineChainNode; const ContentStart: Integer; const IsImage: Boolean);
    procedure HandleCloseBracket;
    procedure AbandonBracket;
    function TryParseInlineLinkSuffix(out Destination, Title: string): Boolean;
    function TryResolveReference(const Opener: TInlineBracket; const CloserPos: Integer;
                                 out Destination, Title: string): Boolean;
    procedure EmitLink(const Opener: TInlineBracket; const Destination, Title: string);
    procedure CloseBracketsAfterLink(const IsImage: Boolean);
    function TryParseTaskListMarker: Boolean;
    function TryParseWwwAutolink: Boolean;
    function TryParseUrlAutolink: Boolean;
    function TryParseEmailAutolink: Boolean;
    function TryScanEmailDomain(out DomainEnd: Integer): Boolean;
    function TryConsumePrecedingChars(const Count: Integer): Boolean;
    procedure RemoveTrailingInlineNode;
    function IsExtendedAutolinkBoundary: Boolean;
    function TryScanAutolinkDomain(const StartIndex: Integer; out DomainEnd: Integer): Boolean;
    function ScanExtendedAutolinkEnd(const StartIndex: Integer): Integer;
    function ApplyExtendedAutolinkTrailing(const StartIndex, CandidateEnd: Integer): Integer;
    class function IsAsciiAlphaNumeric(const Value: Char): Boolean;
    class function IsAsciiLetter(const Value: Char): Boolean;
    class function IsEmailUserChar(const Value: Char): Boolean;
    procedure ProcessEmphasis(const StackBottom: TInlineDelimiter);
    function FirstDelimiterAbove(const StackBottom: TInlineDelimiter): TInlineDelimiter;
    function FindOpener(const Closer, StackBottom: TInlineDelimiter): TInlineDelimiter;
    function OpenersBottomKey(const Closer: TInlineDelimiter): Integer;
    class function IsRuleOfThreeViolated(const Opener, Closer: TInlineDelimiter): Boolean;
    function ApplyMatch(const Opener, Closer: TInlineDelimiter): TInlineDelimiter;
    procedure WrapNodesInContainer(const Opener, Closer: TInlineDelimiter; const Container: TMarkdownAstNode);
    procedure ShrinkDelimiter(const Delimiter: TInlineDelimiter; const UseCount: Integer);
    function RemoveDepletedDelimiters(const Opener, Closer: TInlineDelimiter): TInlineDelimiter;
    procedure AttachInlinesToParent;
    procedure FlushText;
    procedure AddBreak(const Kind: TMarkdownNodeKind);
    function AppendInline(const Node: IMarkdownNode): TInlineChainNode;
    procedure InsertInlineAfter(const ChainNode: TInlineChainNode; const Node: IMarkdownNode);
    procedure RemoveInlineChainNode(const ChainNode: TInlineChainNode);
    procedure ClearInlineChain;
    procedure AppendDelimiter(const Delimiter: TInlineDelimiter);
    procedure RemoveDelimiter(const Delimiter: TInlineDelimiter);
    procedure RemoveDelimitersAbove(const StackBottom: TInlineDelimiter);
    procedure ClearDelimiterStack;
    class function IsUnicodeWhitespace(const Value: Char): Boolean;
    class function IsUnicodePunctuation(const Value: Char): Boolean;

  public
    constructor Create(const Configuration: TMarkdownPipelineConfiguration);
    destructor Destroy; override;
    procedure ParseInto(const Parent: TMarkdownAstNode; const Content: string;
                        const ReferenceMap: TLinkReferenceMap);
    property TaskListCandidate: Boolean read FTaskListCandidate write FTaskListCandidate;
  end;

  TInlineParserContext = class(TInterfacedObject, IMarkdownInlineParserContext)
  private
    FEngine: TInlineParser;

  public
    constructor Create(const Engine: TInlineParser);
    function GetContent: string;
    function GetPosition: Integer;
    property Engine: TInlineParser read FEngine;
  end;

  TCommonMarkInlineKind = (Backslash, LineEnding, EmphasisRun, CodeSpan, AngleBracket, Entity, LinkOpener,
    ImageOpener, LinkCloser);

  TCommonMarkInlineParser = class(TInterfacedObject, IMarkdownInlineParser)
  private
    const
      Names: array[TCommonMarkInlineKind] of string = ('backslash', 'linebreak', 'emphasis', 'codespan',
        'anglebracket', 'entity', 'linkopener', 'imageopener', 'linkcloser');
    var
      FKind: TCommonMarkInlineKind;

  public
    constructor Create(const Kind: TCommonMarkInlineKind);
    function GetName: string;
    function TryParse(const Context: IMarkdownInlineParserContext): Boolean;
  end;

  TGfmInlineKind = (TaskListMarker, WwwAutolink, UrlAutolink, EmailAutolink);

  TGfmInlineParser = class(TInterfacedObject, IMarkdownInlineParser)
  private
    const
      Names: array[TGfmInlineKind] of string = ('tasklistmarker', 'wwwautolink', 'urlautolink', 'emailautolink');
    var
      FKind: TGfmInlineKind;

  public
    const
      TaskCheckedNodeName = 'gfm-task-checked';
      TaskUncheckedNodeName = 'gfm-task-unchecked';
      StrikethroughNodeName = 'del';
    constructor Create(const Kind: TGfmInlineKind);
    function GetName: string;
    function TryParse(const Context: IMarkdownInlineParserContext): Boolean;
  end;

implementation

uses
  System.Character,
  System.Math,
  Markdown4D.Text.Unescape;

constructor TInlineChainNode.Create(const Value: IMarkdownNode);
begin
  inherited Create;

  FValue := Value;
end;

constructor TInlineDelimiter.Create(const Node: TMarkdownTextNode; const ChainNode: TInlineChainNode;
                                    const DelimiterChar: Char; const Count: Integer;
                                    const CanOpen, CanClose: Boolean;
                                    const Processor: IMarkdownDelimiterProcessor);
begin
  inherited Create;

  FNode := Node;
  FChainNode := ChainNode;
  FDelimiterChar := DelimiterChar;
  FCount := Count;
  FOriginalCount := Count;
  FCanOpen := CanOpen;
  FCanClose := CanClose;
  FProcessor := Processor;
end;

constructor TInlineBracket.Create(const ChainNode: TInlineChainNode; const ContentStart: Integer;
                                  const DelimiterBottom: TInlineDelimiter; const IsImage: Boolean);
begin
  inherited Create;

  FChainNode := ChainNode;
  FContentStart := ContentStart;
  FDelimiterBottom := DelimiterBottom;
  FIsImage := IsImage;
  FActive := True;
  FBracketAfter := False;
end;

constructor TInlineParser.Create(const Configuration: TMarkdownPipelineConfiguration);
begin
  inherited Create;

  FConfiguration := Configuration;
  FContext := TInlineParserContext.Create(Self);
  FTriggerMap := TObjectDictionary<Char, TList<IMarkdownInlineParser>>.Create([doOwnsValues]);
  FTextBuffer := TStringBuilder.Create;
  FOpenersBottom := TDictionary<Integer, TInlineDelimiter>.Create;
  FBrackets := TObjectList<TInlineBracket>.Create(True);
  FLinkScanner := TLinkSyntaxScanner.Create;
  FUriAutolinkRegex := TRegEx.Create(UriAutolinkPattern);
  FEmailAutolinkRegex := TRegEx.Create(EmailAutolinkPattern);
  FHtmlTagRegex := TRegEx.Create(HtmlTagPattern);

  BuildTriggerMap;
end;

destructor TInlineParser.Destroy;
begin
  ClearDelimiterStack;
  ClearInlineChain;

  FLinkScanner.Free;
  FBrackets.Free;
  FOpenersBottom.Free;
  FTextBuffer.Free;
  FTriggerMap.Free;

  inherited Destroy;
end;

procedure TInlineParser.BuildTriggerMap;
begin
  for var Registration in FConfiguration.InlineParsers do
  begin
    for var Trigger in Registration.TriggerCharacters do
    begin
      var Parsers: TList<IMarkdownInlineParser>;

      if not FTriggerMap.TryGetValue(Trigger, Parsers) then
      begin
        Parsers := TList<IMarkdownInlineParser>.Create;
        FTriggerMap.Add(Trigger, Parsers);
      end;

      Parsers.Add(Registration.Parser);
    end;
  end;
end;

procedure TInlineParser.ParseInto(const Parent: TMarkdownAstNode; const Content: string;
                                  const ReferenceMap: TLinkReferenceMap);
begin
  FParent := Parent;
  FContent := Content;
  FReferenceMap := ReferenceMap;
  FIndex := 1;
  FTextBuffer.Clear;
  ClearDelimiterStack;
  ClearInlineChain;
  FBrackets.Clear;

  while FIndex <= Length(FContent) do
  begin
    const Current = FContent[FIndex];

    if not TryDispatch(Current) then
    begin
      FTextBuffer.Append(Current);
      Inc(FIndex);
    end;
  end;

  FlushText;

  ProcessEmphasis(nil);
  AttachInlinesToParent;
end;

function TInlineParser.TryDispatch(const Current: Char): Boolean;
begin
  var Parsers: TList<IMarkdownInlineParser>;

  if FTriggerMap.TryGetValue(Current, Parsers) then
  begin
    for var Parser in Parsers do
    begin
      if Parser.TryParse(FContext) then
        Exit(True);
    end;
  end;

  var Processor: IMarkdownDelimiterProcessor;

  if FConfiguration.DelimiterProcessors.TryGetValue(Current, Processor) then
    Exit(TryHandleCustomDelimiterRun(Processor));

  Result := False;
end;

function TInlineParser.TryHandleCustomDelimiterRun(const Processor: IMarkdownDelimiterProcessor): Boolean;
begin
  const Run = ScanDelimiterRun;
  if Run.Length < Processor.MinimumLength then
    Exit(False);

  EmitDelimiterRun(Processor, Run);
  Result := True;
end;

procedure TInlineParser.HandleBackslash;
begin
  const HasNext = (FIndex < Length(FContent));
  if not HasNext then
  begin
    FTextBuffer.Append(Backslash);
    Inc(FIndex);
    Exit;
  end;

  const Next = FContent[FIndex + 1];

  if Next = LineFeed then
  begin
    FlushText;
    AddBreak(TMarkdownNodeKind.HardLineBreak);
    Inc(FIndex, 2);
  end
  else if TMarkdownUnescape.IsAsciiPunctuation(Next) then
  begin
    FTextBuffer.Append(Next);
    Inc(FIndex, 2);
  end
  else
  begin
    FTextBuffer.Append(Backslash);
    Inc(FIndex);
  end;
end;

procedure TInlineParser.HandleLineEnding;
begin
  const RemovedSpaces = TrimTrailingSpacesFromBuffer;

  FlushText;

  const IsHardBreak = (RemovedSpaces >= HardBreakSpaceCount);
  if IsHardBreak then
    AddBreak(TMarkdownNodeKind.HardLineBreak)
  else
    AddBreak(TMarkdownNodeKind.SoftLineBreak);

  Inc(FIndex);
end;

function TInlineParser.TrimTrailingSpacesFromBuffer: Integer;
begin
  Result := 0;

  while (FTextBuffer.Length > 0) and (FTextBuffer.Chars[FTextBuffer.Length - 1] = Space) do
  begin
    FTextBuffer.Length := FTextBuffer.Length - 1;
    Inc(Result);
  end;
end;

procedure TInlineParser.HandleBackticks;
begin
  const RunStart = FIndex;
  var RunEnd := FIndex;

  while (RunEnd < Length(FContent)) and (FContent[RunEnd + 1] = Backtick) do
  begin
    Inc(RunEnd);
  end;

  const RunLength = (RunEnd - RunStart + 1);
  var SearchIndex := RunEnd + 1;

  while SearchIndex <= Length(FContent) do
  begin
    if FContent[SearchIndex] <> Backtick then
    begin
      Inc(SearchIndex);
      Continue;
    end;

    var CloserEnd := SearchIndex;

    while (CloserEnd < Length(FContent)) and (FContent[CloserEnd + 1] = Backtick) do
    begin
      Inc(CloserEnd);
    end;

    const CloserLength = (CloserEnd - SearchIndex + 1);
    if CloserLength = RunLength then
    begin
      EmitCodeSpan(Copy(FContent, RunEnd + 1, SearchIndex - RunEnd - 1));
      FIndex := CloserEnd + 1;
      Exit;
    end;

    SearchIndex := CloserEnd + 1;
  end;

  FTextBuffer.Append(StringOfChar(Backtick, RunLength));
  FIndex := RunEnd + 1;
end;

procedure TInlineParser.EmitCodeSpan(const RawContent: string);
begin
  var Content := StringReplace(RawContent, LineFeed, Space, [rfReplaceAll]);

  const HasNonSpace = (Content.Trim([Space]) <> '');
  const CanStripPadding = HasNonSpace and (Length(Content) >= 2) and (Content[1] = Space) and
    (Content[Length(Content)] = Space);
  if CanStripPadding then
    Content := Copy(Content, 2, Length(Content) - 2);

  FlushText;
  AppendInline(TMarkdownTextNode.Create(TMarkdownNodeKind.CodeSpan, Content));
end;

procedure TInlineParser.HandleLessThan;
begin
  const Rest = Copy(FContent, FIndex, MaxInt);

  const UriMatch = FUriAutolinkRegex.Match(Rest);
  if UriMatch.Success then
  begin
    const Uri = Copy(UriMatch.Value, 2, UriMatch.Length - 2);
    EmitAutolink(Uri, TMarkdownUnescape.NormalizeUri(Uri));
    Inc(FIndex, UriMatch.Length);
    Exit;
  end;

  const EmailMatch = FEmailAutolinkRegex.Match(Rest);
  if EmailMatch.Success then
  begin
    const Email = Copy(EmailMatch.Value, 2, EmailMatch.Length - 2);
    EmitAutolink(Email, TMarkdownUnescape.NormalizeUri(MailtoPrefix + Email));
    Inc(FIndex, EmailMatch.Length);
    Exit;
  end;

  const TagMatch = FHtmlTagRegex.Match(Rest);
  if TagMatch.Success then
  begin
    FlushText;
    AppendInline(TMarkdownTextNode.Create(TMarkdownNodeKind.InlineHtml, TagMatch.Value));
    Inc(FIndex, TagMatch.Length);
    Exit;
  end;

  FTextBuffer.Append(LessThan);
  Inc(FIndex);
end;

procedure TInlineParser.EmitAutolink(const LabelText, Destination: string);
begin
  FlushText;

  const Node = TMarkdownLinkNode.Create(TMarkdownNodeKind.Autolink, Destination, '');
  Node.AddChild(TMarkdownTextNode.Create(TMarkdownNodeKind.Text, LabelText));

  AppendInline(Node);
end;

procedure TInlineParser.HandleAmpersand;
begin
  var Decoded: string;
  var Consumed: Integer;

  if TMarkdownUnescape.TryDecodeEntityAt(FContent, FIndex, Decoded, Consumed) then
  begin
    FTextBuffer.Append(Decoded);
    Inc(FIndex, Consumed);
    Exit;
  end;

  FTextBuffer.Append(Ampersand);
  Inc(FIndex);
end;

procedure TInlineParser.HandleDelimiterRun;
begin
  EmitDelimiterRun(nil, ScanDelimiterRun);
end;

function TInlineParser.ScanDelimiterRun: TDelimiterRun;
begin
  const DelimiterChar = FContent[FIndex];
  const RunStart = FIndex;
  var RunEnd := FIndex;

  while (RunEnd < Length(FContent)) and (FContent[RunEnd + 1] = DelimiterChar) do
  begin
    Inc(RunEnd);
  end;

  Result.Length := (RunEnd - RunStart + 1);

  const BeforeChar = CharBefore(RunStart);
  const AfterChar = CharAfter(RunEnd);
  const FollowedByWhitespace = IsUnicodeWhitespace(AfterChar);
  const FollowedByPunctuation = IsUnicodePunctuation(AfterChar);
  const PrecededByWhitespace = IsUnicodeWhitespace(BeforeChar);
  const PrecededByPunctuation = IsUnicodePunctuation(BeforeChar);
  const LeftFlanking = (not FollowedByWhitespace) and
    ((not FollowedByPunctuation) or PrecededByWhitespace or PrecededByPunctuation);
  const RightFlanking = (not PrecededByWhitespace) and
    ((not PrecededByPunctuation) or FollowedByWhitespace or FollowedByPunctuation);

  Result.CanOpen := LeftFlanking;
  Result.CanClose := RightFlanking;

  const IsUnderscoreRun = (DelimiterChar = Underscore);
  if IsUnderscoreRun then
  begin
    Result.CanOpen := LeftFlanking and ((not RightFlanking) or PrecededByPunctuation);
    Result.CanClose := RightFlanking and ((not LeftFlanking) or FollowedByPunctuation);
  end;
end;

procedure TInlineParser.EmitDelimiterRun(const Processor: IMarkdownDelimiterProcessor; const Run: TDelimiterRun);
begin
  FlushText;

  const DelimiterChar = FContent[FIndex];
  const Node = TMarkdownTextNode.Create(TMarkdownNodeKind.Text, StringOfChar(DelimiterChar, Run.Length));
  const ChainNode = AppendInline(Node);
  AppendDelimiter(TInlineDelimiter.Create(Node, ChainNode, DelimiterChar, Run.Length, Run.CanOpen, Run.CanClose,
    Processor));

  Inc(FIndex, Run.Length);
end;

function TInlineParser.CharBefore(const Index: Integer): Char;
begin
  const AtContentStart = (Index <= 1);
  if AtContentStart then
    Exit(LineFeed);

  Result := FContent[Index - 1];
end;

function TInlineParser.CharAfter(const Index: Integer): Char;
begin
  const AtContentEnd = (Index >= Length(FContent));
  if AtContentEnd then
    Exit(LineFeed);

  Result := FContent[Index + 1];
end;

procedure TInlineParser.HandleOpenBracket;
begin
  FlushText;

  const ChainNode = AppendInline(TMarkdownTextNode.Create(TMarkdownNodeKind.Text, OpenBracket));
  PushBracket(ChainNode, FIndex + 1, False);

  Inc(FIndex);
end;

procedure TInlineParser.HandleBang;
begin
  const StartsImage = (FIndex < Length(FContent)) and (FContent[FIndex + 1] = OpenBracket);
  if not StartsImage then
  begin
    FTextBuffer.Append(Bang);
    Inc(FIndex);
    Exit;
  end;

  FlushText;

  const ChainNode = AppendInline(TMarkdownTextNode.Create(TMarkdownNodeKind.Text, ImageOpenerText));
  PushBracket(ChainNode, FIndex + 2, True);

  Inc(FIndex, 2);
end;

procedure TInlineParser.PushBracket(const ChainNode: TInlineChainNode; const ContentStart: Integer;
                                    const IsImage: Boolean);
begin
  const HasOpenBrackets = (FBrackets.Count > 0);
  if HasOpenBrackets then
    FBrackets.Last.BracketAfter := True;

  FBrackets.Add(TInlineBracket.Create(ChainNode, ContentStart, FLastDelimiter, IsImage));
end;

procedure TInlineParser.HandleCloseBracket;
begin
  const CloserPos = FIndex;
  Inc(FIndex);

  FlushText;

  const HasOpener = (FBrackets.Count > 0);
  if not HasOpener then
  begin
    FTextBuffer.Append(CloseBracket);
    Exit;
  end;

  const Opener = FBrackets.Last;
  if not Opener.Active then
  begin
    AbandonBracket;
    Exit;
  end;

  var Destination := '';
  var Title := '';
  var Matched := TryParseInlineLinkSuffix(Destination, Title);

  if not Matched then
    Matched := TryResolveReference(Opener, CloserPos, Destination, Title);

  if not Matched then
  begin
    FIndex := CloserPos + 1;
    AbandonBracket;
    Exit;
  end;

  EmitLink(Opener, Destination, Title);
end;

procedure TInlineParser.AbandonBracket;
begin
  FBrackets.Delete(FBrackets.Count - 1);
  FTextBuffer.Append(CloseBracket);
end;

function TInlineParser.TryParseInlineLinkSuffix(out Destination, Title: string): Boolean;
begin
  Destination := '';
  Title := '';

  FLinkScanner.Reset(FContent, FIndex);

  const StartsInline = (FLinkScanner.PeekChar = OpenParen);
  if not StartsInline then
    Exit(False);

  FLinkScanner.Advance(1);
  FLinkScanner.SkipSpacesWithOneNewline;

  var RawDestination: string;
  if not FLinkScanner.TryParseDestination(RawDestination) then
    Exit(False);

  const BeforeSpaces = FLinkScanner.Position;
  FLinkScanner.SkipSpacesWithOneNewline;

  var RawTitle := '';
  const HasWhitespaceBeforeTitle = (FLinkScanner.Position > BeforeSpaces);
  if HasWhitespaceBeforeTitle then
    FLinkScanner.TryParseTitle(RawTitle);

  FLinkScanner.SkipSpacesWithOneNewline;

  const HasCloser = (FLinkScanner.PeekChar = CloseParen);
  if not HasCloser then
    Exit(False);

  FLinkScanner.Advance(1);
  FIndex := FLinkScanner.Position;

  Destination := TMarkdownUnescape.NormalizeUri(TMarkdownUnescape.Unescape(RawDestination));
  Title := TMarkdownUnescape.Unescape(RawTitle);
  Result := True;
end;

function TInlineParser.TryResolveReference(const Opener: TInlineBracket; const CloserPos: Integer;
                                           out Destination, Title: string): Boolean;
begin
  Destination := '';
  Title := '';

  FLinkScanner.Reset(FContent, FIndex);

  var LabelContent: string;
  var LabelLength: Integer;

  if FLinkScanner.TryParseLabel(LabelContent, LabelLength) then
    FIndex := FLinkScanner.Position;

  var RefLabel := '';
  var HasLabel := False;

  if LabelLength > CollapsedLabelLength then
  begin
    RefLabel := LabelContent;
    HasLabel := True;
  end
  else if not Opener.BracketAfter then
  begin
    RefLabel := Copy(FContent, Opener.ContentStart, CloserPos - Opener.ContentStart);
    HasLabel := (RefLabel <> '');
  end;

  var Reference: TLinkReference;
  const Resolved = HasLabel and Assigned(FReferenceMap) and FReferenceMap.TryGet(RefLabel, Reference);
  if not Resolved then
    Exit(False);

  Destination := Reference.Destination;
  Title := Reference.Title;
  Result := True;
end;

procedure TInlineParser.EmitLink(const Opener: TInlineBracket; const Destination, Title: string);
begin
  ProcessEmphasis(Opener.DelimiterBottom);

  var Kind := TMarkdownNodeKind.Link;
  if Opener.IsImage then
    Kind := TMarkdownNodeKind.Image;

  const LinkNode = TMarkdownLinkNode.Create(Kind, Destination, Title);

  var Walker := Opener.ChainNode.Next;
  while Walker <> nil do
  begin
    const Successor = Walker.Next;
    LinkNode.AddChild(Walker.Value);
    RemoveInlineChainNode(Walker);
    Walker := Successor;
  end;

  RemoveInlineChainNode(Opener.ChainNode);
  AppendInline(LinkNode);

  CloseBracketsAfterLink(Opener.IsImage);
end;

procedure TInlineParser.CloseBracketsAfterLink(const IsImage: Boolean);
begin
  FBrackets.Delete(FBrackets.Count - 1);

  if IsImage then
    Exit;

  for var Bracket in FBrackets do
  begin
    if not Bracket.IsImage then
      Bracket.Active := False;
  end;
end;

function TInlineParser.TryParseTaskListMarker: Boolean;
begin
  const AtTaskPosition = FTaskListCandidate and (FIndex = 1);
  if not AtTaskPosition then
    Exit(False);

  const HasMarkerShape = (Length(FContent) > TaskMarkerLength) and (FContent[1] = OpenBracket) and
    CharInSet(FContent[2], [Space, 'x', 'X']) and (FContent[3] = CloseBracket) and
    CharInSet(FContent[TaskMarkerLength + 1], [Space, Tab]);
  if not HasMarkerShape then
    Exit(False);

  var NodeName := TGfmInlineParser.TaskUncheckedNodeName;

  const IsChecked = (FContent[2] <> Space);
  if IsChecked then
    NodeName := TGfmInlineParser.TaskCheckedNodeName;

  AppendInline(TMarkdownCustomInlineNode.Create(NodeName));
  FIndex := TaskMarkerLength + 1;

  Result := True;
end;

function TInlineParser.TryParseWwwAutolink: Boolean;
begin
  if not IsExtendedAutolinkBoundary then
    Exit(False);

  const HasPrefix = (Copy(FContent, FIndex, Length(WwwPrefix)) = WwwPrefix);
  if not HasPrefix then
    Exit(False);

  var DomainEnd: Integer;
  if not TryScanAutolinkDomain(FIndex, DomainEnd) then
    Exit(False);

  const LinkEnd = ApplyExtendedAutolinkTrailing(FIndex, ScanExtendedAutolinkEnd(DomainEnd));

  const HasHost = (LinkEnd - FIndex > Length(WwwPrefix));
  if not HasHost then
    Exit(False);

  const LabelText = Copy(FContent, FIndex, LinkEnd - FIndex);
  EmitAutolink(LabelText, TMarkdownUnescape.NormalizeUri(HttpSchemePrefix + LabelText));
  FIndex := LinkEnd;

  Result := True;
end;

function TInlineParser.TryParseUrlAutolink: Boolean;
begin
  if not IsExtendedAutolinkBoundary then
    Exit(False);

  var SchemeLength := 0;

  for var Scheme in UrlAutolinkSchemes do
  begin
    const HasScheme = (Copy(FContent, FIndex, Length(Scheme)) = Scheme);
    if HasScheme then
    begin
      SchemeLength := Length(Scheme);
      Break;
    end;
  end;

  if SchemeLength = 0 then
    Exit(False);

  var DomainEnd: Integer;
  if not TryScanAutolinkDomain(FIndex + SchemeLength, DomainEnd) then
    Exit(False);

  const LinkEnd = ApplyExtendedAutolinkTrailing(FIndex, ScanExtendedAutolinkEnd(DomainEnd));

  const HasHost = (LinkEnd > FIndex + SchemeLength);
  if not HasHost then
    Exit(False);

  const LabelText = Copy(FContent, FIndex, LinkEnd - FIndex);
  EmitAutolink(LabelText, TMarkdownUnescape.NormalizeUri(LabelText));
  FIndex := LinkEnd;

  Result := True;
end;

function TInlineParser.TryParseEmailAutolink: Boolean;
begin
  var Rewind := 0;

  while (FIndex - Rewind > 1) and IsEmailUserChar(FContent[FIndex - Rewind - 1]) do
  begin
    Inc(Rewind);
  end;

  if Rewind = 0 then
    Exit(False);

  var DomainEnd: Integer;
  if not TryScanEmailDomain(DomainEnd) then
    Exit(False);

  if not TryConsumePrecedingChars(Rewind) then
    Exit(False);

  const LinkStart = FIndex - Rewind;
  const LabelText = Copy(FContent, LinkStart, DomainEnd - LinkStart);
  EmitAutolink(LabelText, TMarkdownUnescape.NormalizeUri(MailtoPrefix + LabelText));
  FIndex := DomainEnd;

  Result := True;
end;

function TInlineParser.TryScanEmailDomain(out DomainEnd: Integer): Boolean;
begin
  var Index := FIndex + 1;
  var DotCount := 0;

  while Index <= Length(FContent) do
  begin
    const Current = FContent[Index];

    if IsAsciiAlphaNumeric(Current) or CharInSet(Current, ['-', '_']) then
      Inc(Index)
    else if (Current = '.') and (Index < Length(FContent)) and IsAsciiAlphaNumeric(FContent[Index + 1]) then
    begin
      Inc(DotCount);
      Inc(Index);
    end
    else
      Break;
  end;

  DomainEnd := Index;

  if DotCount = 0 then
    Exit(False);

  Result := not CharInSet(FContent[Index - 1], ['-', '_']);
end;

function TInlineParser.TryConsumePrecedingChars(const Count: Integer): Boolean;
begin
  const FromBuffer = Min(FTextBuffer.Length, Count);
  var Remaining := Count - FromBuffer;
  var NodesToRemove := 0;
  var PartialTrim := 0;
  var Walker := FLastInline;

  while Remaining > 0 do
  begin
    const CanExamineNode = (Walker <> nil) and (Walker.Value.Kind = TMarkdownNodeKind.Text);
    if not CanExamineNode then
      Exit(False);

    const LiteralLength = Length((Walker.Value as IMarkdownText).Literal);

    if LiteralLength <= Remaining then
    begin
      Inc(NodesToRemove);
      Dec(Remaining, LiteralLength);
      Walker := Walker.Prev;
    end
    else
    begin
      PartialTrim := Remaining;
      Remaining := 0;
    end;
  end;

  FTextBuffer.Length := FTextBuffer.Length - FromBuffer;

  for var RemoveIndex := 1 to NodesToRemove do
  begin
    RemoveTrailingInlineNode;
  end;

  if PartialTrim > 0 then
  begin
    const TrimmedNode = FLastInline.Value as TMarkdownTextNode;
    const Literal = TrimmedNode.GetLiteral;

    TrimmedNode.SetLiteral(Copy(Literal, 1, Length(Literal) - PartialTrim));
  end;

  Result := True;
end;

procedure TInlineParser.RemoveTrailingInlineNode;
begin
  const Node = FLastInline.Value as TMarkdownTextNode;

  const TrailingDelimiterMatches = (FLastDelimiter <> nil) and (FLastDelimiter.Node = Node);
  if TrailingDelimiterMatches then
    RemoveDelimiter(FLastDelimiter);

  RemoveInlineChainNode(FLastInline);
end;

function TInlineParser.IsExtendedAutolinkBoundary: Boolean;
begin
  const AtContentStart = (FIndex = 1);
  if AtContentStart then
    Exit(True);

  Result := CharInSet(FContent[FIndex - 1], [Space, Tab, #10, #13, Asterisk, Underscore, Tilde, OpenParen]);
end;

function TInlineParser.TryScanAutolinkDomain(const StartIndex: Integer; out DomainEnd: Integer): Boolean;
begin
  var Index := StartIndex;
  var DotCount := 0;
  var PreviousUnderscores := 0;
  var CurrentUnderscores := 0;

  while Index <= Length(FContent) do
  begin
    const Current = FContent[Index];

    if Current = Underscore then
      Inc(CurrentUnderscores)
    else if Current = '.' then
    begin
      PreviousUnderscores := CurrentUnderscores;
      CurrentUnderscores := 0;
      Inc(DotCount);
    end
    else if (not IsAsciiAlphaNumeric(Current)) and (Current <> '-') then
      Break;

    Inc(Index);
  end;

  DomainEnd := Index;
  Result := (Index > StartIndex) and (DotCount > 0) and (PreviousUnderscores = 0) and (CurrentUnderscores = 0);
end;

function TInlineParser.ScanExtendedAutolinkEnd(const StartIndex: Integer): Integer;
begin
  var Index := StartIndex;

  while (Index <= Length(FContent)) and (not CharInSet(FContent[Index], [Space, Tab, #10, #11, #12, #13])) and
    (FContent[Index] <> LessThan) do
  begin
    Inc(Index);
  end;

  Result := Index;
end;

function TInlineParser.ApplyExtendedAutolinkTrailing(const StartIndex, CandidateEnd: Integer): Integer;
begin
  var EndIndex := CandidateEnd;

  while EndIndex > StartIndex do
  begin
    const Current = FContent[EndIndex - 1];

    if CharInSet(Current, ['?', '!', '.', ',', ':', '*', '_', '~', '''', '"']) then
      Dec(EndIndex)
    else if Current = CloseParen then
    begin
      var Opens := 0;
      var Closes := 0;

      for var Index := StartIndex to EndIndex - 1 do
      begin
        if FContent[Index] = OpenParen then
          Inc(Opens)
        else if FContent[Index] = CloseParen then
          Inc(Closes);
      end;

      if Closes <= Opens then
        Break;

      Dec(EndIndex);
    end
    else if Current = ';' then
    begin
      var ScanIndex := EndIndex - 2;

      while (ScanIndex >= StartIndex) and IsAsciiLetter(FContent[ScanIndex]) do
      begin
        Dec(ScanIndex);
      end;

      const IsEntityLike = (ScanIndex < EndIndex - 2) and (ScanIndex >= StartIndex) and
        (FContent[ScanIndex] = Ampersand);
      if IsEntityLike then
        EndIndex := ScanIndex
      else
        Dec(EndIndex);
    end
    else
      Break;
  end;

  Result := EndIndex;
end;

class function TInlineParser.IsAsciiAlphaNumeric(const Value: Char): Boolean;
begin
  Result := CharInSet(Value, ['0'..'9', 'a'..'z', 'A'..'Z']);
end;

class function TInlineParser.IsAsciiLetter(const Value: Char): Boolean;
begin
  Result := CharInSet(Value, ['a'..'z', 'A'..'Z']);
end;

class function TInlineParser.IsEmailUserChar(const Value: Char): Boolean;
begin
  Result := IsAsciiAlphaNumeric(Value) or CharInSet(Value, ['.', '-', '_', '+']);
end;

procedure TInlineParser.ProcessEmphasis(const StackBottom: TInlineDelimiter);
begin
  FOpenersBottom.Clear;

  var Closer := FirstDelimiterAbove(StackBottom);

  while Closer <> nil do
  begin
    if not Closer.CanClose then
    begin
      Closer := Closer.Next;
      Continue;
    end;

    const Opener = FindOpener(Closer, StackBottom);
    if Opener <> nil then
    begin
      Closer := ApplyMatch(Opener, Closer);
      Continue;
    end;

    FOpenersBottom.AddOrSetValue(OpenersBottomKey(Closer), Closer.Prev);

    const Unmatched = Closer;
    Closer := Closer.Next;
    if not Unmatched.CanOpen then
      RemoveDelimiter(Unmatched);
  end;

  RemoveDelimitersAbove(StackBottom);
end;

function TInlineParser.FirstDelimiterAbove(const StackBottom: TInlineDelimiter): TInlineDelimiter;
begin
  if StackBottom = nil then
    Exit(FFirstDelimiter);

  Result := StackBottom.Next;
end;

function TInlineParser.FindOpener(const Closer, StackBottom: TInlineDelimiter): TInlineDelimiter;
begin
  var SearchBottom := StackBottom;
  var BucketBottom: TInlineDelimiter;

  if FOpenersBottom.TryGetValue(OpenersBottomKey(Closer), BucketBottom) then
    SearchBottom := BucketBottom;

  var Candidate := Closer.Prev;

  while (Candidate <> nil) and (Candidate <> StackBottom) and (Candidate <> SearchBottom) do
  begin
    const Matches = Candidate.CanOpen and (Candidate.DelimiterChar = Closer.DelimiterChar) and (Candidate.Count > 0);

    if Matches then
    begin
      const IsEmphasisRun = (Closer.Processor = nil);
      const RuleOfThreeBlocks = IsEmphasisRun and IsRuleOfThreeViolated(Candidate, Closer);
      if not RuleOfThreeBlocks then
        Exit(Candidate);
    end;

    Candidate := Candidate.Prev;
  end;

  Result := nil;
end;

function TInlineParser.OpenersBottomKey(const Closer: TInlineDelimiter): Integer;
begin
  var CanOpenOffset := 0;
  if Closer.CanOpen then
    CanOpenOffset := RuleOfThreeDivisor;

  Result := (Ord(Closer.DelimiterChar) * OpenersBottomBucketsPerChar) + CanOpenOffset
    + (Closer.OriginalCount mod RuleOfThreeDivisor);
end;

class function TInlineParser.IsRuleOfThreeViolated(const Opener, Closer: TInlineDelimiter): Boolean;
begin
  const EitherServesBothRoles = (Closer.CanOpen or Opener.CanClose);
  if not EitherServesBothRoles then
    Exit(False);

  const SumIsMultipleOfThree = (((Opener.OriginalCount + Closer.OriginalCount) mod RuleOfThreeDivisor) = 0);
  const BothAreMultiplesOfThree = ((Opener.OriginalCount mod RuleOfThreeDivisor) = 0) and
    ((Closer.OriginalCount mod RuleOfThreeDivisor) = 0);

  Result := SumIsMultipleOfThree and (not BothAreMultiplesOfThree);
end;

function TInlineParser.ApplyMatch(const Opener, Closer: TInlineDelimiter): TInlineDelimiter;
begin
  const IsCustomRun = (Closer.Processor <> nil);
  if IsCustomRun then
  begin
    const CustomUseCount = Min(Opener.Count, Closer.Count);
    WrapNodesInContainer(Opener, Closer, TMarkdownCustomInlineNode.Create(Closer.Processor.NodeName));

    ShrinkDelimiter(Opener, CustomUseCount);
    ShrinkDelimiter(Closer, CustomUseCount);

    Exit(RemoveDepletedDelimiters(Opener, Closer));
  end;

  const UseStrong = (Opener.Count >= StrongDelimiterCount) and (Closer.Count >= StrongDelimiterCount);

  var UseCount := 1;
  if UseStrong then
    UseCount := StrongDelimiterCount;

  var Kind := TMarkdownNodeKind.Emphasis;
  if UseStrong then
    Kind := TMarkdownNodeKind.Strong;

  WrapNodesInContainer(Opener, Closer, TMarkdownAstNode.Create(Kind));

  ShrinkDelimiter(Opener, UseCount);
  ShrinkDelimiter(Closer, UseCount);

  Result := RemoveDepletedDelimiters(Opener, Closer);
end;

procedure TInlineParser.WrapNodesInContainer(const Opener, Closer: TInlineDelimiter;
                                             const Container: TMarkdownAstNode);
begin
  const ContainerNode: IMarkdownNode = Container;
  var Walker := Opener.ChainNode.Next;

  while Walker <> Closer.ChainNode do
  begin
    const Successor = Walker.Next;
    Container.AddChild(Walker.Value);
    RemoveInlineChainNode(Walker);
    Walker := Successor;
  end;

  InsertInlineAfter(Opener.ChainNode, ContainerNode);
end;

procedure TInlineParser.ShrinkDelimiter(const Delimiter: TInlineDelimiter; const UseCount: Integer);
begin
  Delimiter.Count := Delimiter.Count - UseCount;

  Delimiter.Node.SetLiteral(StringOfChar(Delimiter.DelimiterChar, Delimiter.Count));
end;

function TInlineParser.RemoveDepletedDelimiters(const Opener, Closer: TInlineDelimiter): TInlineDelimiter;
begin
  var Walker := Closer.Prev;

  while Walker <> Opener do
  begin
    const Predecessor = Walker.Prev;
    RemoveDelimiter(Walker);
    Walker := Predecessor;
  end;

  const OpenerDepleted = (Opener.Count = 0);
  if OpenerDepleted then
  begin
    RemoveInlineChainNode(Opener.ChainNode);
    RemoveDelimiter(Opener);
  end;

  const CloserDepleted = (Closer.Count = 0);
  if not CloserDepleted then
    Exit(Closer);

  const Successor = Closer.Next;
  RemoveInlineChainNode(Closer.ChainNode);
  RemoveDelimiter(Closer);
  Result := Successor;
end;

procedure TInlineParser.AttachInlinesToParent;
begin
  var Walker := FFirstInline;

  while Walker <> nil do
  begin
    const Successor = Walker.Next;
    FParent.AddChild(Walker.Value);
    Walker.Free;
    Walker := Successor;
  end;

  FFirstInline := nil;
  FLastInline := nil;
end;

procedure TInlineParser.FlushText;
begin
  const HasText = (FTextBuffer.Length > 0);
  if not HasText then
    Exit;

  AppendInline(TMarkdownTextNode.Create(TMarkdownNodeKind.Text, FTextBuffer.ToString));
  FTextBuffer.Clear;
end;

procedure TInlineParser.AddBreak(const Kind: TMarkdownNodeKind);
begin
  AppendInline(TMarkdownAstNode.Create(Kind));
end;

function TInlineParser.AppendInline(const Node: IMarkdownNode): TInlineChainNode;
begin
  Result := TInlineChainNode.Create(Node);
  Result.Prev := FLastInline;

  if FLastInline = nil then
    FFirstInline := Result
  else
    FLastInline.Next := Result;

  FLastInline := Result;
end;

procedure TInlineParser.InsertInlineAfter(const ChainNode: TInlineChainNode; const Node: IMarkdownNode);
begin
  const Inserted = TInlineChainNode.Create(Node);

  Inserted.Prev := ChainNode;
  Inserted.Next := ChainNode.Next;

  if ChainNode.Next = nil then
    FLastInline := Inserted
  else
    ChainNode.Next.Prev := Inserted;

  ChainNode.Next := Inserted;
end;

procedure TInlineParser.RemoveInlineChainNode(const ChainNode: TInlineChainNode);
begin
  if ChainNode.Prev = nil then
    FFirstInline := ChainNode.Next
  else
    ChainNode.Prev.Next := ChainNode.Next;

  if ChainNode.Next = nil then
    FLastInline := ChainNode.Prev
  else
    ChainNode.Next.Prev := ChainNode.Prev;

  ChainNode.Free;
end;

procedure TInlineParser.ClearInlineChain;
begin
  var Walker := FFirstInline;

  while Walker <> nil do
  begin
    const Successor = Walker.Next;
    Walker.Free;
    Walker := Successor;
  end;

  FFirstInline := nil;
  FLastInline := nil;
end;

procedure TInlineParser.AppendDelimiter(const Delimiter: TInlineDelimiter);
begin
  Delimiter.Prev := FLastDelimiter;

  if FLastDelimiter = nil then
    FFirstDelimiter := Delimiter
  else
    FLastDelimiter.Next := Delimiter;

  FLastDelimiter := Delimiter;
end;

procedure TInlineParser.RemoveDelimiter(const Delimiter: TInlineDelimiter);
begin
  if Delimiter.Prev = nil then
    FFirstDelimiter := Delimiter.Next
  else
    Delimiter.Prev.Next := Delimiter.Next;

  if Delimiter.Next = nil then
    FLastDelimiter := Delimiter.Prev
  else
    Delimiter.Next.Prev := Delimiter.Prev;

  Delimiter.Free;
end;

procedure TInlineParser.RemoveDelimitersAbove(const StackBottom: TInlineDelimiter);
begin
  while FLastDelimiter <> StackBottom do
  begin
    RemoveDelimiter(FLastDelimiter);
  end;
end;

procedure TInlineParser.ClearDelimiterStack;
begin
  RemoveDelimitersAbove(nil);
end;

class function TInlineParser.IsUnicodeWhitespace(const Value: Char): Boolean;
begin
  Result := Value.IsWhiteSpace;
end;

class function TInlineParser.IsUnicodePunctuation(const Value: Char): Boolean;
begin
  Result := Value.IsPunctuation or Value.IsSymbol;
end;

constructor TInlineParserContext.Create(const Engine: TInlineParser);
begin
  inherited Create;

  FEngine := Engine;
end;

function TInlineParserContext.GetContent: string;
begin
  Result := FEngine.FContent;
end;

function TInlineParserContext.GetPosition: Integer;
begin
  Result := FEngine.FIndex;
end;

constructor TCommonMarkInlineParser.Create(const Kind: TCommonMarkInlineKind);
begin
  inherited Create;

  FKind := Kind;
end;

function TCommonMarkInlineParser.GetName: string;
begin
  Result := Names[FKind];
end;

function TCommonMarkInlineParser.TryParse(const Context: IMarkdownInlineParserContext): Boolean;
begin
  const Engine = (Context as TInlineParserContext).Engine;

  case FKind of
    TCommonMarkInlineKind.Backslash:
      Engine.HandleBackslash;
    TCommonMarkInlineKind.LineEnding:
      Engine.HandleLineEnding;
    TCommonMarkInlineKind.EmphasisRun:
      Engine.HandleDelimiterRun;
    TCommonMarkInlineKind.CodeSpan:
      Engine.HandleBackticks;
    TCommonMarkInlineKind.AngleBracket:
      Engine.HandleLessThan;
    TCommonMarkInlineKind.Entity:
      Engine.HandleAmpersand;
    TCommonMarkInlineKind.LinkOpener:
      Engine.HandleOpenBracket;
    TCommonMarkInlineKind.ImageOpener:
      Engine.HandleBang;
    TCommonMarkInlineKind.LinkCloser:
      Engine.HandleCloseBracket;
  end;

  Result := True;
end;

constructor TGfmInlineParser.Create(const Kind: TGfmInlineKind);
begin
  inherited Create;

  FKind := Kind;
end;

function TGfmInlineParser.GetName: string;
begin
  Result := Names[FKind];
end;

function TGfmInlineParser.TryParse(const Context: IMarkdownInlineParserContext): Boolean;
begin
  const Engine = (Context as TInlineParserContext).Engine;

  case FKind of
    TGfmInlineKind.TaskListMarker:
      Result := Engine.TryParseTaskListMarker;
    TGfmInlineKind.WwwAutolink:
      Result := Engine.TryParseWwwAutolink;
    TGfmInlineKind.UrlAutolink:
      Result := Engine.TryParseUrlAutolink;
  else
    Result := Engine.TryParseEmailAutolink;
  end;
end;

end.
