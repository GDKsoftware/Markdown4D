unit Markdown4D.Writer.Markdown;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces;

type
  TMarkdownWriter = class
  private
    type
      TWritePhase = (Enter, Leave);

      TWriteTask = record
        Node: IMarkdownNode;
        Parent: IMarkdownNode;
        Index: Integer;
        Phase: TWritePhase;
        WasTight: Boolean;
        Delimiter: string;
      end;

    const
      DeleteCharacter = #127;
      QuoteMarker = '>';
      QuoteContentPrefix = '> ';
      BulletMarker = '-';
      AlternateBulletMarker = '*';
      OrderedDelimiter = '.';
      AlternateOrderedDelimiter = ')';
      ThematicBreakText = '___';
      HeadingMarker = '#';
      SetextUnderlines: array[1..2] of string = ('===', '---');
      HardBreakMarker = '\';
      ImageMarker = '![';
      LinkMiddle = '](';
      TitleQuote = '"';
      TabEntity = '&#9;';
      NewlineEntity = '&#10;';
      CarriageReturnEntity = '&#13;';
      SpaceEntity = '&#32;';
      StrikethroughMarker = '~~';
      TaskCheckedText = '[x]';
      TaskUncheckedText = '[ ]';
      TablePipe = '|';
      EscapedPipe = '\|';
      PercentEncodedFormat = '%%%2.2X';
      OrderedMarkerFormat = '%d%s';
      TableDelimiterCells: array[TMarkdownTableColumnAlignment] of string = ('---', ':---', ':---:', '---:');
    var
      FOutput: TStringBuilder;
      FTasks: TStack<TWriteTask>;
      FPrefixes: TList<string>;
      FPrefix: string;
      FAtLineStart: Boolean;
      FPendingSpace: Boolean;
      FTight: Boolean;
      FInTable: Boolean;
      FLastDelimiter: Char;
      FOpenEmphasis: TStack<Char>;
      FListMarkers: TStack<Char>;
      FTableAlignments: TArray<TMarkdownTableColumnAlignment>;
    procedure Render(const Document: IMarkdownDocument);
    procedure EnterNode(const Task: TWriteTask);
    procedure LeaveNode(const Task: TWriteTask);
    procedure EnterParagraph(const Task: TWriteTask);
    procedure EnterHeading(const Task: TWriteTask);
    procedure WriteThematicBreak(const Task: TWriteTask);
    procedure WriteCodeBlock(const Task: TWriteTask);
    procedure EnterBlockQuote(const Task: TWriteTask);
    procedure EnterList(const Task: TWriteTask);
    function ComputeListMarkerChar(const Task: TWriteTask; const List: IMarkdownList): Char;
    procedure EnterListItem(const Task: TWriteTask);
    procedure WriteHtmlBlock(const Task: TWriteTask);
    procedure WriteTextNode(const Task: TWriteTask);
    function FollowsRawAutolink(const Task: TWriteTask): Boolean;
    class function RawAutolinkHeadLength(const Literal: string): Integer;
    procedure EnterEmphasis(const Task: TWriteTask);
    function PreviousContextChar: Char;
    procedure WriteCodeSpan(const Node: IMarkdownText);
    procedure EnterLink(const Task: TWriteTask);
    procedure EnterImage(const Task: TWriteTask);
    procedure LeaveLink(const Node: IMarkdownLink);
    class function FormatDestination(const Value: string): string;
    class function PercentEncodeControlCharacters(const Value: string): string;
    class function FormatTitle(const Value: string): string;
    procedure WriteAutolink(const Node: IMarkdownNode);
    class function AutolinkLabel(const Node: IMarkdownNode): string;
    procedure WriteInlineHtml(const Node: IMarkdownText);
    procedure EnterCustomInline(const Task: TWriteTask);
    procedure EnterTable(const Task: TWriteTask);
    procedure EnterTableRow(const Task: TWriteTask);
    procedure EnterTableCell(const Task: TWriteTask);
    procedure LeaveHeading(const Task: TWriteTask);
    procedure LeaveEmphasis(const Task: TWriteTask);
    procedure LeaveBlockQuote(const Task: TWriteTask);
    procedure LeaveList(const Task: TWriteTask);
    procedure LeaveListItem;
    procedure LeaveCustomInline(const Task: TWriteTask);
    procedure LeaveTable;
    procedure LeaveTableRow(const Task: TWriteTask);
    procedure WriteTableDelimiterRow;
    procedure BeginBlock(const Task: TWriteTask);
    procedure ScheduleLeaveAndChildren(const Task: TWriteTask; const Delimiter: string);
    procedure PushChildren(const Node: IMarkdownNode);
    procedure PushPrefix(const Value: string);
    procedure PopPrefix;
    procedure WriteText(const Value: string);
    procedure WriteRaw(const Value: string);
    procedure WriteLineBreak;
    procedure EnsureLineBreak;
    function ContainsLineBreak(const Node: IMarkdownNode): Boolean;
    class function EscapeText(const Value: string): string;
    class function EscapeCharacters(const Value: string; const Characters: TSysCharSet): string;
    class function SplitCodeLines(const Literal: string): TArray<string>;
    class function LongestRun(const Value: string; const Target: Char): Integer;

  public
    class function WriteDocument(const Document: IMarkdownDocument): string;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

uses
  System.Character,
  System.Math,
  Markdown4D.Defines,
  Markdown4D.Text.Unescape,
  Markdown4D.Parser.Inlines,
  Markdown4D.Writer.Emphasis;

class function TMarkdownWriter.WriteDocument(const Document: IMarkdownDocument): string;
begin
  const Writer = TMarkdownWriter.Create;
  try
    Writer.Render(Document);

    Result := Writer.FOutput.ToString;
  finally
    Writer.Free;
  end;
end;

constructor TMarkdownWriter.Create;
begin
  inherited Create;

  FOutput := TStringBuilder.Create;
  FTasks := TStack<TWriteTask>.Create;
  FPrefixes := TList<string>.Create;
  FOpenEmphasis := TStack<Char>.Create;
  FListMarkers := TStack<Char>.Create;
  FAtLineStart := True;
end;

destructor TMarkdownWriter.Destroy;
begin
  FListMarkers.Free;
  FOpenEmphasis.Free;
  FPrefixes.Free;
  FTasks.Free;
  FOutput.Free;

  inherited Destroy;
end;

procedure TMarkdownWriter.Render(const Document: IMarkdownDocument);
begin
  PushChildren(Document);

  while FTasks.Count > 0 do
  begin
    const Task = FTasks.Pop;

    if Task.Phase = TWritePhase.Enter then
      EnterNode(Task)
    else
      LeaveNode(Task);
  end;
end;

procedure TMarkdownWriter.EnterNode(const Task: TWriteTask);
begin
  case Task.Node.Kind of
    TMarkdownNodeKind.Paragraph:
      EnterParagraph(Task);
    TMarkdownNodeKind.Heading:
      EnterHeading(Task);
    TMarkdownNodeKind.ThematicBreak:
      WriteThematicBreak(Task);
    TMarkdownNodeKind.CodeBlock:
      WriteCodeBlock(Task);
    TMarkdownNodeKind.BlockQuote:
      EnterBlockQuote(Task);
    TMarkdownNodeKind.List:
      EnterList(Task);
    TMarkdownNodeKind.ListItem:
      EnterListItem(Task);
    TMarkdownNodeKind.HtmlBlock:
      WriteHtmlBlock(Task);
    TMarkdownNodeKind.Text:
      WriteTextNode(Task);
    TMarkdownNodeKind.Emphasis, TMarkdownNodeKind.Strong:
      EnterEmphasis(Task);
    TMarkdownNodeKind.CodeSpan:
      WriteCodeSpan(Task.Node as IMarkdownText);
    TMarkdownNodeKind.Link:
      EnterLink(Task);
    TMarkdownNodeKind.Image:
      EnterImage(Task);
    TMarkdownNodeKind.Autolink:
      WriteAutolink(Task.Node);
    TMarkdownNodeKind.SoftLineBreak:
      WriteLineBreak;
    TMarkdownNodeKind.HardLineBreak:
      begin
        WriteRaw(HardBreakMarker);
        WriteLineBreak;
      end;
    TMarkdownNodeKind.InlineHtml:
      WriteInlineHtml(Task.Node as IMarkdownText);
    TMarkdownNodeKind.CustomInline:
      EnterCustomInline(Task);
    TMarkdownNodeKind.Table:
      EnterTable(Task);
    TMarkdownNodeKind.TableRow:
      EnterTableRow(Task);
    TMarkdownNodeKind.TableCell:
      EnterTableCell(Task);
  else
  end;
end;

procedure TMarkdownWriter.LeaveNode(const Task: TWriteTask);
begin
  case Task.Node.Kind of
    TMarkdownNodeKind.Paragraph:
      EnsureLineBreak;
    TMarkdownNodeKind.Heading:
      LeaveHeading(Task);
    TMarkdownNodeKind.BlockQuote:
      LeaveBlockQuote(Task);
    TMarkdownNodeKind.List:
      LeaveList(Task);
    TMarkdownNodeKind.ListItem:
      LeaveListItem;
    TMarkdownNodeKind.Emphasis, TMarkdownNodeKind.Strong:
      LeaveEmphasis(Task);
    TMarkdownNodeKind.Link, TMarkdownNodeKind.Image:
      LeaveLink(Task.Node as IMarkdownLink);
    TMarkdownNodeKind.CustomInline:
      LeaveCustomInline(Task);
    TMarkdownNodeKind.Table:
      LeaveTable;
    TMarkdownNodeKind.TableRow:
      LeaveTableRow(Task);
    TMarkdownNodeKind.TableCell:
      WriteRaw(Space + TablePipe);
  else
  end;
end;

procedure TMarkdownWriter.EnterParagraph(const Task: TWriteTask);
begin
  BeginBlock(Task);

  ScheduleLeaveAndChildren(Task, '');
end;

procedure TMarkdownWriter.EnterHeading(const Task: TWriteTask);
begin
  BeginBlock(Task);

  const Heading = Task.Node as IMarkdownHeading;
  const UseSetext = (Heading.Level >= Low(SetextUnderlines)) and (Heading.Level <= High(SetextUnderlines)) and
    ContainsLineBreak(Task.Node);
  if UseSetext then
  begin
    ScheduleLeaveAndChildren(Task, SetextUnderlines[Heading.Level]);
    Exit;
  end;

  WriteRaw(StringOfChar(HeadingMarker, Heading.Level));
  FPendingSpace := True;

  ScheduleLeaveAndChildren(Task, '');
end;

procedure TMarkdownWriter.WriteThematicBreak(const Task: TWriteTask);
begin
  BeginBlock(Task);

  WriteRaw(ThematicBreakText);
  EnsureLineBreak;
end;

procedure TMarkdownWriter.WriteCodeBlock(const Task: TWriteTask);
begin
  BeginBlock(Task);

  const Code = Task.Node as IMarkdownCodeBlock;
  var FenceChar := Backtick;
  if Code.InfoString.Contains(Backtick) then
    FenceChar := Tilde;

  const FenceLength = Max(MinFenceLength, LongestRun(Code.Literal, FenceChar) + 1);
  const Fence = StringOfChar(FenceChar, FenceLength);
  WriteRaw(Fence);
  WriteRaw(EscapeText(Code.InfoString));
  WriteLineBreak;

  for var Line in SplitCodeLines(Code.Literal) do
  begin
    WriteRaw(Line);
    WriteLineBreak;
  end;

  WriteRaw(Fence);
  EnsureLineBreak;
end;

procedure TMarkdownWriter.EnterBlockQuote(const Task: TWriteTask);
begin
  BeginBlock(Task);

  const IsEmpty = (Task.Node.ChildCount = 0);
  if IsEmpty then
    WriteRaw(QuoteMarker)
  else if not FAtLineStart then
    WriteRaw(QuoteContentPrefix);

  ScheduleLeaveAndChildren(Task, '');
  PushPrefix(QuoteContentPrefix);
  FTight := False;
end;

procedure TMarkdownWriter.EnterList(const Task: TWriteTask);
begin
  BeginBlock(Task);

  const List = Task.Node as IMarkdownList;
  FListMarkers.Push(ComputeListMarkerChar(Task, List));

  ScheduleLeaveAndChildren(Task, '');
  FTight := List.IsTight;
end;

function TMarkdownWriter.ComputeListMarkerChar(const Task: TWriteTask; const List: IMarkdownList): Char;
begin
  var Alternate := False;
  var SiblingIndex := Task.Index - 1;

  while SiblingIndex >= 0 do
  begin
    const Sibling = Task.Parent.Children[SiblingIndex];
    const IsSameListType = (Sibling.Kind = TMarkdownNodeKind.List) and
      ((Sibling as IMarkdownList).IsOrdered = List.IsOrdered);
    if not IsSameListType then
      Break;

    Alternate := not Alternate;
    Dec(SiblingIndex);
  end;

  if List.IsOrdered then
  begin
    if Alternate then
      Exit(AlternateOrderedDelimiter);

    Exit(OrderedDelimiter);
  end;

  if Alternate then
    Exit(AlternateBulletMarker);

  Result := BulletMarker;
end;

procedure TMarkdownWriter.EnterListItem(const Task: TWriteTask);
begin
  BeginBlock(Task);

  const List = Task.Parent as IMarkdownList;
  var MarkerText: string := FListMarkers.Peek;
  if List.IsOrdered then
    MarkerText := Format(OrderedMarkerFormat, [List.StartNumber + Task.Index, MarkerText]);

  WriteRaw(MarkerText);
  FPendingSpace := True;

  ScheduleLeaveAndChildren(Task, '');
  PushPrefix(StringOfChar(Space, Length(MarkerText) + 1));
end;

procedure TMarkdownWriter.WriteHtmlBlock(const Task: TWriteTask);
begin
  BeginBlock(Task);

  WriteText((Task.Node as IMarkdownText).Literal);
  EnsureLineBreak;
end;

procedure TMarkdownWriter.WriteTextNode(const Task: TWriteTask);
begin
  var Literal := (Task.Node as IMarkdownText).Literal;

  if FollowsRawAutolink(Task) then
  begin
    const HeadLength = RawAutolinkHeadLength(Literal);
    WriteRaw(Copy(Literal, 1, HeadLength));
    Literal := Copy(Literal, HeadLength + 1, MaxInt);
  end;

  var Escaped := EscapeText(Literal);

  const StartsLineWithSpace = (FAtLineStart or FPendingSpace) and Escaped.StartsWith(Space);
  if StartsLineWithSpace then
    Escaped := SpaceEntity + Copy(Escaped, 2, MaxInt);

  WriteRaw(Escaped);
end;

function TMarkdownWriter.FollowsRawAutolink(const Task: TWriteTask): Boolean;
begin
  const HasPreviousSibling = (Task.Parent <> nil) and (Task.Index > 0);
  if not HasPreviousSibling then
    Exit(False);

  const Previous = Task.Parent.Children[Task.Index - 1];
  if Previous.Kind <> TMarkdownNodeKind.Autolink then
    Exit(False);

  Result := AutolinkLabel(Previous).StartsWith(WwwPrefix);
end;

class function TMarkdownWriter.RawAutolinkHeadLength(const Literal: string): Integer;
begin
  Result := 0;

  while (Result < Length(Literal)) and (not Literal[Result + 1].IsWhiteSpace) do
  begin
    Inc(Result);
  end;
end;

procedure TMarkdownWriter.EnterEmphasis(const Task: TWriteTask);
begin
  const ParentDelimiterIsAsterisk = (FOpenEmphasis.Count > 0) and (FOpenEmphasis.Peek = Asterisk);
  const DelimiterChar = TEmphasisDelimiterChooser.Choose(Task.Node, Task.Parent, Task.Index, PreviousContextChar,
    FLastDelimiter, ParentDelimiterIsAsterisk);

  var MarkerLength := 1;
  if Task.Node.Kind = TMarkdownNodeKind.Strong then
    MarkerLength := 2;

  const Marker = StringOfChar(DelimiterChar, MarkerLength);
  WriteRaw(Marker);
  FLastDelimiter := DelimiterChar;
  FOpenEmphasis.Push(DelimiterChar);

  ScheduleLeaveAndChildren(Task, Marker);
end;

function TMarkdownWriter.PreviousContextChar: Char;
begin
  if FPendingSpace then
    Exit(Space);

  if FAtLineStart or (FOutput.Length = 0) then
    Exit(LineFeed);

  Result := FOutput.Chars[FOutput.Length - 1];
end;

procedure TMarkdownWriter.WriteCodeSpan(const Node: IMarkdownText);
begin
  var Content := Node.Literal;
  if Content = '' then
    Content := Space;

  const Fence = StringOfChar(Backtick, LongestRun(Content, Backtick) + 1);

  const FirstChar = Content[1];
  const LastChar = Content[Length(Content)];
  const HasNonSpace = (Content.Trim([Space]) <> '');
  const NeedsPadding = (FirstChar = Backtick) or (LastChar = Backtick) or
    ((FirstChar = Space) and (LastChar = Space) and HasNonSpace);
  if NeedsPadding then
    Content := Space + Content + Space;

  if FInTable then
    Content := StringReplace(Content, TablePipe, EscapedPipe, [rfReplaceAll]);

  WriteRaw(Fence + Content + Fence);
end;

procedure TMarkdownWriter.EnterLink(const Task: TWriteTask);
begin
  WriteRaw(OpenBracket);

  ScheduleLeaveAndChildren(Task, '');
end;

procedure TMarkdownWriter.EnterImage(const Task: TWriteTask);
begin
  WriteRaw(ImageMarker);

  ScheduleLeaveAndChildren(Task, '');
end;

procedure TMarkdownWriter.LeaveLink(const Node: IMarkdownLink);
begin
  var Suffix := LinkMiddle + FormatDestination(Node.Destination) + FormatTitle(Node.Title) + CloseParen;

  if FInTable then
    Suffix := StringReplace(Suffix, TablePipe, EscapedPipe, [rfReplaceAll]);

  WriteText(Suffix);
end;

class function TMarkdownWriter.FormatDestination(const Value: string): string;
begin
  const Encoded = PercentEncodeControlCharacters(Value);

  var NeedsAngleBrackets := False;
  for var Current in Encoded do
  begin
    if Current.IsWhiteSpace then
    begin
      NeedsAngleBrackets := True;
      Break;
    end;
  end;

  if NeedsAngleBrackets then
    Exit(LessThan + EscapeCharacters(Encoded, [LessThan, GreaterThan, Ampersand, Backslash]) + GreaterThan);

  Result := EscapeCharacters(Encoded,
    [OpenParen, CloseParen, LessThan, GreaterThan, Ampersand, Backslash]);
end;

class function TMarkdownWriter.PercentEncodeControlCharacters(const Value: string): string;
begin
  const Builder = TStringBuilder.Create;
  try
    for var Current in Value do
    begin
      const IsControlCharacter = (Current < Space) or (Current = DeleteCharacter);
      if IsControlCharacter then
        Builder.Append(Format(PercentEncodedFormat, [Ord(Current)]))
      else
        Builder.Append(Current);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TMarkdownWriter.FormatTitle(const Value: string): string;
begin
  if Value = '' then
    Exit('');

  Result := Space + TitleQuote + EscapeCharacters(Value, [TitleQuote, Ampersand, Backslash]) + TitleQuote;
end;

procedure TMarkdownWriter.WriteAutolink(const Node: IMarkdownNode);
begin
  const LabelText = AutolinkLabel(Node);

  if LabelText.StartsWith(WwwPrefix) then
  begin
    WriteRaw(LabelText);
    Exit;
  end;

  WriteRaw(LessThan + LabelText + GreaterThan);
end;

class function TMarkdownWriter.AutolinkLabel(const Node: IMarkdownNode): string;
begin
  const HasTextChild = (Node.ChildCount > 0) and (Node.Children[0].Kind = TMarkdownNodeKind.Text);
  if HasTextChild then
    Exit((Node.Children[0] as IMarkdownText).Literal);

  Result := (Node as IMarkdownLink).Destination;
end;

procedure TMarkdownWriter.WriteInlineHtml(const Node: IMarkdownText);
begin
  var Content := Node.Literal;

  if FInTable then
    Content := StringReplace(Content, TablePipe, EscapedPipe, [rfReplaceAll]);

  WriteText(Content);
end;

procedure TMarkdownWriter.EnterCustomInline(const Task: TWriteTask);
begin
  const NodeName = (Task.Node as IMarkdownCustomInline).NodeName;

  if NodeName = TGfmInlineParser.StrikethroughNodeName then
  begin
    WriteRaw(StrikethroughMarker);
    ScheduleLeaveAndChildren(Task, StrikethroughMarker);
    Exit;
  end;

  if NodeName = TGfmInlineParser.TaskCheckedNodeName then
    WriteRaw(TaskCheckedText);

  if NodeName = TGfmInlineParser.TaskUncheckedNodeName then
    WriteRaw(TaskUncheckedText);

  ScheduleLeaveAndChildren(Task, '');
end;

procedure TMarkdownWriter.EnterTable(const Task: TWriteTask);
begin
  BeginBlock(Task);

  FInTable := True;

  var Alignments: TArray<TMarkdownTableColumnAlignment> := nil;
  const HasHeaderRow = (Task.Node.ChildCount > 0);
  if HasHeaderRow then
  begin
    const HeaderRow = Task.Node.Children[0];
    SetLength(Alignments, HeaderRow.ChildCount);

    for var Index := 0 to HeaderRow.ChildCount - 1 do
    begin
      Alignments[Index] := (HeaderRow.Children[Index] as IMarkdownTableCell).Alignment;
    end;
  end;
  FTableAlignments := Alignments;

  ScheduleLeaveAndChildren(Task, '');
end;

procedure TMarkdownWriter.EnterTableRow(const Task: TWriteTask);
begin
  WriteRaw(TablePipe);

  ScheduleLeaveAndChildren(Task, '');
end;

procedure TMarkdownWriter.EnterTableCell(const Task: TWriteTask);
begin
  WriteRaw(Space);

  ScheduleLeaveAndChildren(Task, '');
end;

procedure TMarkdownWriter.LeaveHeading(const Task: TWriteTask);
begin
  const HasUnderline = (Task.Delimiter <> '');
  if HasUnderline then
  begin
    EnsureLineBreak;
    WriteRaw(Task.Delimiter);
  end;

  EnsureLineBreak;
end;

procedure TMarkdownWriter.LeaveEmphasis(const Task: TWriteTask);
begin
  FOpenEmphasis.Pop;

  WriteRaw(Task.Delimiter);
  FLastDelimiter := Task.Delimiter[1];
end;

procedure TMarkdownWriter.LeaveBlockQuote(const Task: TWriteTask);
begin
  PopPrefix;
  FTight := Task.WasTight;

  EnsureLineBreak;
end;

procedure TMarkdownWriter.LeaveList(const Task: TWriteTask);
begin
  FListMarkers.Pop;
  FTight := Task.WasTight;

  EnsureLineBreak;
end;

procedure TMarkdownWriter.LeaveListItem;
begin
  PopPrefix;

  EnsureLineBreak;
end;

procedure TMarkdownWriter.LeaveCustomInline(const Task: TWriteTask);
begin
  if Task.Delimiter <> '' then
    WriteRaw(Task.Delimiter);
end;

procedure TMarkdownWriter.LeaveTable;
begin
  FInTable := False;

  EnsureLineBreak;
end;

procedure TMarkdownWriter.LeaveTableRow(const Task: TWriteTask);
begin
  EnsureLineBreak;

  if (Task.Node as IMarkdownTableRow).IsHeader then
    WriteTableDelimiterRow;
end;

procedure TMarkdownWriter.WriteTableDelimiterRow;
begin
  WriteRaw(TablePipe);

  for var Alignment in FTableAlignments do
  begin
    WriteRaw(Space + TableDelimiterCells[Alignment] + Space + TablePipe);
  end;

  WriteLineBreak;
end;

procedure TMarkdownWriter.BeginBlock(const Task: TWriteTask);
begin
  if Task.Index = 0 then
    Exit;

  EnsureLineBreak;

  if not FTight then
    WriteLineBreak;
end;

procedure TMarkdownWriter.ScheduleLeaveAndChildren(const Task: TWriteTask; const Delimiter: string);
begin
  var LeaveTask := Task;
  LeaveTask.Phase := TWritePhase.Leave;
  LeaveTask.WasTight := FTight;
  LeaveTask.Delimiter := Delimiter;
  FTasks.Push(LeaveTask);

  PushChildren(Task.Node);
end;

procedure TMarkdownWriter.PushChildren(const Node: IMarkdownNode);
begin
  for var Index := Node.ChildCount - 1 downto 0 do
  begin
    var EnterTask: TWriteTask;
    EnterTask.Node := Node.Children[Index];
    EnterTask.Parent := Node;
    EnterTask.Index := Index;
    EnterTask.Phase := TWritePhase.Enter;
    EnterTask.WasTight := False;
    EnterTask.Delimiter := '';

    FTasks.Push(EnterTask);
  end;
end;

procedure TMarkdownWriter.PushPrefix(const Value: string);
begin
  FPrefixes.Add(Value);
  FPrefix := FPrefix + Value;
end;

procedure TMarkdownWriter.PopPrefix;
begin
  const LastIndex = FPrefixes.Count - 1;

  SetLength(FPrefix, Length(FPrefix) - Length(FPrefixes[LastIndex]));
  FPrefixes.Delete(LastIndex);
end;

procedure TMarkdownWriter.WriteText(const Value: string);
begin
  var Start := 1;

  for var Index := 1 to Length(Value) do
  begin
    if Value[Index] = LineFeed then
    begin
      WriteRaw(Copy(Value, Start, Index - Start));
      WriteLineBreak;
      Start := Index + 1;
    end;
  end;

  WriteRaw(Copy(Value, Start, MaxInt));
end;

procedure TMarkdownWriter.WriteRaw(const Value: string);
begin
  if Value = '' then
    Exit;

  if FAtLineStart then
  begin
    FOutput.Append(FPrefix);
    FAtLineStart := False;
  end;

  if FPendingSpace then
  begin
    FOutput.Append(Space);
    FPendingSpace := False;
  end;

  FOutput.Append(Value);
  FLastDelimiter := #0;
end;

procedure TMarkdownWriter.WriteLineBreak;
begin
  if FAtLineStart then
    FOutput.Append(FPrefix.TrimRight);

  FOutput.Append(LineFeed);
  FAtLineStart := True;
  FPendingSpace := False;
  FLastDelimiter := #0;
end;

procedure TMarkdownWriter.EnsureLineBreak;
begin
  if not FAtLineStart then
    WriteLineBreak;
end;

function TMarkdownWriter.ContainsLineBreak(const Node: IMarkdownNode): Boolean;
begin
  const Pending = TStack<IMarkdownNode>.Create;
  try
    Pending.Push(Node);

    while Pending.Count > 0 do
    begin
      const Current = Pending.Pop;

      const IsBreak = (Current.Kind = TMarkdownNodeKind.SoftLineBreak) or
        (Current.Kind = TMarkdownNodeKind.HardLineBreak);
      if IsBreak then
        Exit(True);

      for var Index := 0 to Current.ChildCount - 1 do
      begin
        Pending.Push(Current.Children[Index]);
      end;
    end;

    Result := False;
  finally
    Pending.Free;
  end;
end;

class function TMarkdownWriter.EscapeText(const Value: string): string;
begin
  const Builder = TStringBuilder.Create;
  try
    for var Current in Value do
    begin
      if Current = Tab then
      begin
        Builder.Append(TabEntity);
        Continue;
      end;

      if Current = LineFeed then
      begin
        Builder.Append(NewlineEntity);
        Continue;
      end;

      if Current = CarriageReturn then
      begin
        Builder.Append(CarriageReturnEntity);
        Continue;
      end;

      if TMarkdownUnescape.IsAsciiPunctuation(Current) then
        Builder.Append(Backslash);

      Builder.Append(Current);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TMarkdownWriter.EscapeCharacters(const Value: string; const Characters: TSysCharSet): string;
begin
  const Builder = TStringBuilder.Create;
  try
    for var Current in Value do
    begin
      if CharInSet(Current, Characters) then
        Builder.Append(Backslash);

      Builder.Append(Current);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TMarkdownWriter.SplitCodeLines(const Literal: string): TArray<string>;
begin
  if Literal = '' then
    Exit(nil);

  var Content := Literal;
  if Content.EndsWith(LineFeed) then
    SetLength(Content, Length(Content) - 1);

  if Content = '' then
    Exit(TArray<string>.Create(''));

  Result := Content.Split([LineFeed]);
end;

class function TMarkdownWriter.LongestRun(const Value: string; const Target: Char): Integer;
begin
  Result := 0;
  var CurrentRun := 0;

  for var Current in Value do
  begin
    if Current = Target then
    begin
      Inc(CurrentRun);

      if CurrentRun > Result then
        Result := CurrentRun;
    end
    else
      CurrentRun := 0;
  end;
end;

end.
