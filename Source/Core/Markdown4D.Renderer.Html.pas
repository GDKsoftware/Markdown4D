unit Markdown4D.Renderer.Html;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.RegularExpressions,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Pipeline.Configuration,
  Markdown4D.Ast.Interfaces;

type
  TMarkdownHtmlRenderer = class
  private
    type
      TRenderPhase = (Enter, Leave);
      TRenderTask = record
        Node: IMarkdownNode;
        Phase: TRenderPhase;
        WasTightList: Boolean;
      end;
    const
      LanguageClassFormat = ' class="language-%s"';
      HeadingOpenFormat = '<h%d>';
      HeadingCloseFormat = '</h%d>';
      OrderedListStartFormat = '<ol start="%d">';
      AnchorOpenFormat = '<a href="%s"';
      ImageOpenFormat = '<img src="%s" alt="';
      TitleAttributeFormat = ' title="%s"';
      AnchorCloseTag = '</a>';
      TagCloseBracket = '>';
      OmittedHtmlComment = '<!-- raw HTML omitted -->';
      EscapedAmpersand = '&amp;';
      EscapedLessThan = '&lt;';
      EscapedGreaterThan = '&gt;';
      EscapedQuote = '&quot;';
      EscapedApostrophe = '&#39;';
      TableHeadOpenTag = '<thead>';
      TableHeadCloseTag = '</thead>';
      TableBodyOpenTag = '<tbody>';
      TableBodyCloseTag = '</tbody>';
      TableCellOpenFormat = '<%s';
      TableCellCloseFormat = '</%s>';
      TableAlignAttributeFormat = ' align="%s"';
      TableHeaderCellTag = 'th';
      TableDataCellTag = 'td';
      TableAlignmentNames: array[TMarkdownTableColumnAlignment] of string = ('', 'left', 'center', 'right');
      DisallowedTagPattern =
        '<(?=/?(?:title|textarea|style|xmp|iframe|noembed|noframes|script|plaintext)[\s/>])';
      InfoSplitChars: array[0..1] of Char = (' ', #9);
    var
      FOutput: TStringBuilder;
      FTasks: TStack<TRenderTask>;
      FTightList: Boolean;
      FTableInHeader: Boolean;
      FTableInBody: Boolean;
      FOptions: TMarkdownRendererOptions;
      FHooks: TDictionary<string, IMarkdownRendererHook>;
      FWriter: IMarkdownHtmlWriter;
      FTagFilterRegex: TRegEx;
    procedure Render(const Document: IMarkdownDocument);
    procedure EnterNode(const Node: IMarkdownNode);
    procedure LeaveNode(const Task: TRenderTask);
    procedure EnterParagraph(const Node: IMarkdownNode);
    procedure EnterHeading(const Node: IMarkdownHeading);
    procedure WriteThematicBreak;
    procedure WriteCodeBlock(const Node: IMarkdownCodeBlock);
    procedure EnterBlockQuote(const Node: IMarkdownNode);
    procedure EnterList(const Node: IMarkdownList);
    procedure EnterListItem(const Node: IMarkdownNode);
    procedure EnterHtmlBlock(const Node: IMarkdownText);
    procedure EnterTable(const Node: IMarkdownNode);
    procedure EnterTableRow(const Node: IMarkdownTableRow);
    procedure EnterTableCell(const Node: IMarkdownTableCell);
    function CurrentTableCellTag: string;
    function RawHtmlOutput(const Literal: string): string;
    procedure EnterCustomInline(const Node: IMarkdownNode);
    procedure LeaveCustomInline(const Node: IMarkdownNode);
    function TryFindHook(const Node: IMarkdownNode; out Hook: IMarkdownRendererHook): Boolean;
    procedure EnterSpan(const Node: IMarkdownNode; const OpenTag: string);
    procedure WriteCodeSpan(const Node: IMarkdownText);
    procedure EnterAnchor(const Node: IMarkdownLink);
    procedure WriteImage(const Node: IMarkdownLink);
    function DestinationOutput(const Destination: string): string;
    procedure AppendAltText(const Node: IMarkdownNode);
    class procedure PushChildrenReversed(const Pending: TStack<IMarkdownNode>; const Node: IMarkdownNode);
    procedure WriteHardBreak;
    procedure LeaveParagraph;
    procedure LeaveHeading(const Node: IMarkdownHeading);
    procedure LeaveBlockQuote(const WasTightList: Boolean);
    procedure LeaveList(const Node: IMarkdownList; const WasTightList: Boolean);
    procedure LeaveListItem;
    procedure LeaveTable;
    procedure LeaveTableRow(const Node: IMarkdownTableRow);
    procedure LeaveTableCell;
    procedure ScheduleLeaveAndChildren(const Node: IMarkdownNode; const WasTightList: Boolean);
    procedure AppendLineBreak;
    class function FirstInfoWord(const InfoString: string): string;
    class function EscapeCore(const Value: string; const EscapeApostrophe: Boolean): string;
    class function EscapeHtml(const Value: string): string;

  public
    class function RenderDocument(const Document: IMarkdownDocument): string; overload;
    class function RenderDocument(const Document: IMarkdownDocument; const Options: TMarkdownRendererOptions;
                                  const Hooks: TDictionary<string, IMarkdownRendererHook>): string; overload;
    constructor Create(const Options: TMarkdownRendererOptions;
                       const Hooks: TDictionary<string, IMarkdownRendererHook>);
    destructor Destroy; override;
  end;

implementation

uses
  Markdown4D.Defines,
  Markdown4D.Text.UrlSafety;

type
  TRendererHtmlWriter = class(TInterfacedObject, IMarkdownHtmlWriter)
  private
    FOutput: TStringBuilder;

  public
    constructor Create(const Output: TStringBuilder);
    procedure WriteRaw(const Html: string);
    procedure WriteEscaped(const Text: string);
    function EscapeAttribute(const Value: string): string;
    procedure WriteAttribute(const Name, Value: string);
  end;

class function TMarkdownHtmlRenderer.RenderDocument(const Document: IMarkdownDocument): string;
begin
  Result := RenderDocument(Document, TMarkdownRendererOptions.SpecDefaults, nil);
end;

class function TMarkdownHtmlRenderer.RenderDocument(const Document: IMarkdownDocument;
                                                    const Options: TMarkdownRendererOptions;
                                                    const Hooks: TDictionary<string, IMarkdownRendererHook>): string;
begin
  const Renderer = TMarkdownHtmlRenderer.Create(Options, Hooks);
  try
    Renderer.Render(Document);

    Result := Renderer.FOutput.ToString;
  finally
    Renderer.Free;
  end;
end;

constructor TMarkdownHtmlRenderer.Create(const Options: TMarkdownRendererOptions;
                                         const Hooks: TDictionary<string, IMarkdownRendererHook>);
begin
  inherited Create;

  FOptions := Options;
  FHooks := Hooks;
  FOutput := TStringBuilder.Create;
  FTasks := TStack<TRenderTask>.Create;
  FWriter := TRendererHtmlWriter.Create(FOutput);

  if FOptions.ApplyTagFilter then
    FTagFilterRegex := TRegEx.Create(DisallowedTagPattern, [roIgnoreCase]);
end;

destructor TMarkdownHtmlRenderer.Destroy;
begin
  FTasks.Free;
  FOutput.Free;

  inherited Destroy;
end;

procedure TMarkdownHtmlRenderer.Render(const Document: IMarkdownDocument);
begin
  ScheduleLeaveAndChildren(Document, FTightList);

  while FTasks.Count > 0 do
  begin
    const Task = FTasks.Pop;

    if Task.Phase = TRenderPhase.Enter then
      EnterNode(Task.Node)
    else
      LeaveNode(Task);
  end;
end;

procedure TMarkdownHtmlRenderer.EnterNode(const Node: IMarkdownNode);
begin
  case Node.Kind of
    TMarkdownNodeKind.Paragraph:
      EnterParagraph(Node);
    TMarkdownNodeKind.Heading:
      EnterHeading(Node as IMarkdownHeading);
    TMarkdownNodeKind.ThematicBreak:
      WriteThematicBreak;
    TMarkdownNodeKind.CodeBlock:
      WriteCodeBlock(Node as IMarkdownCodeBlock);
    TMarkdownNodeKind.BlockQuote:
      EnterBlockQuote(Node);
    TMarkdownNodeKind.List:
      EnterList(Node as IMarkdownList);
    TMarkdownNodeKind.ListItem:
      EnterListItem(Node);
    TMarkdownNodeKind.HtmlBlock:
      EnterHtmlBlock(Node as IMarkdownText);
    TMarkdownNodeKind.Text:
      FOutput.Append(EscapeHtml((Node as IMarkdownText).Literal));
    TMarkdownNodeKind.Emphasis:
      EnterSpan(Node, '<em>');
    TMarkdownNodeKind.Strong:
      EnterSpan(Node, '<strong>');
    TMarkdownNodeKind.CodeSpan:
      WriteCodeSpan(Node as IMarkdownText);
    TMarkdownNodeKind.Link, TMarkdownNodeKind.Autolink:
      EnterAnchor(Node as IMarkdownLink);
    TMarkdownNodeKind.Image:
      WriteImage(Node as IMarkdownLink);
    TMarkdownNodeKind.SoftLineBreak:
      FOutput.Append(LineFeed);
    TMarkdownNodeKind.HardLineBreak:
      WriteHardBreak;
    TMarkdownNodeKind.InlineHtml:
      FOutput.Append(RawHtmlOutput((Node as IMarkdownText).Literal));
    TMarkdownNodeKind.CustomInline:
      EnterCustomInline(Node);
    TMarkdownNodeKind.Table:
      EnterTable(Node);
    TMarkdownNodeKind.TableRow:
      EnterTableRow(Node as IMarkdownTableRow);
    TMarkdownNodeKind.TableCell:
      EnterTableCell(Node as IMarkdownTableCell);
  else
  end;
end;

procedure TMarkdownHtmlRenderer.LeaveNode(const Task: TRenderTask);
begin
  case Task.Node.Kind of
    TMarkdownNodeKind.Paragraph:
      LeaveParagraph;
    TMarkdownNodeKind.Heading:
      LeaveHeading(Task.Node as IMarkdownHeading);
    TMarkdownNodeKind.BlockQuote:
      LeaveBlockQuote(Task.WasTightList);
    TMarkdownNodeKind.List:
      LeaveList(Task.Node as IMarkdownList, Task.WasTightList);
    TMarkdownNodeKind.ListItem:
      LeaveListItem;
    TMarkdownNodeKind.Emphasis:
      FOutput.Append('</em>');
    TMarkdownNodeKind.Strong:
      FOutput.Append('</strong>');
    TMarkdownNodeKind.Link, TMarkdownNodeKind.Autolink:
      FOutput.Append(AnchorCloseTag);
    TMarkdownNodeKind.CustomInline:
      LeaveCustomInline(Task.Node);
    TMarkdownNodeKind.Table:
      LeaveTable;
    TMarkdownNodeKind.TableRow:
      LeaveTableRow(Task.Node as IMarkdownTableRow);
    TMarkdownNodeKind.TableCell:
      LeaveTableCell;
  else
  end;
end;

procedure TMarkdownHtmlRenderer.EnterParagraph(const Node: IMarkdownNode);
begin
  if not FTightList then
  begin
    AppendLineBreak;
    FOutput.Append('<p>');
  end;

  ScheduleLeaveAndChildren(Node, FTightList);
end;

procedure TMarkdownHtmlRenderer.EnterHeading(const Node: IMarkdownHeading);
begin
  AppendLineBreak;
  FOutput.Append(Format(HeadingOpenFormat, [Node.Level]));

  ScheduleLeaveAndChildren(Node, FTightList);
end;

procedure TMarkdownHtmlRenderer.WriteThematicBreak;
begin
  AppendLineBreak;
  FOutput.Append('<hr />');
  AppendLineBreak;
end;

procedure TMarkdownHtmlRenderer.WriteCodeBlock(const Node: IMarkdownCodeBlock);
begin
  AppendLineBreak;
  FOutput.Append('<pre><code');

  const Language = FirstInfoWord(Node.InfoString);
  const HasLanguage = Node.IsFenced and (Language <> '');
  if HasLanguage then
    FOutput.Append(Format(LanguageClassFormat, [EscapeHtml(Language)]));

  FOutput.Append(TagCloseBracket);
  FOutput.Append(EscapeHtml(Node.Literal));
  FOutput.Append('</code></pre>');
  AppendLineBreak;
end;

procedure TMarkdownHtmlRenderer.EnterBlockQuote(const Node: IMarkdownNode);
begin
  ScheduleLeaveAndChildren(Node, FTightList);
  FTightList := False;

  AppendLineBreak;
  FOutput.Append('<blockquote>');
  AppendLineBreak;
end;

procedure TMarkdownHtmlRenderer.EnterList(const Node: IMarkdownList);
begin
  ScheduleLeaveAndChildren(Node, FTightList);
  FTightList := Node.IsTight;

  var OpenTag := '<ul>';

  if Node.IsOrdered then
  begin
    OpenTag := '<ol>';

    const HasExplicitStart = (Node.StartNumber <> 1);
    if HasExplicitStart then
      OpenTag := Format(OrderedListStartFormat, [Node.StartNumber]);
  end;

  AppendLineBreak;
  FOutput.Append(OpenTag);
  AppendLineBreak;
end;

procedure TMarkdownHtmlRenderer.EnterListItem(const Node: IMarkdownNode);
begin
  FOutput.Append('<li>');

  ScheduleLeaveAndChildren(Node, FTightList);
end;

procedure TMarkdownHtmlRenderer.EnterHtmlBlock(const Node: IMarkdownText);
begin
  AppendLineBreak;
  FOutput.Append(RawHtmlOutput(Node.Literal));
  AppendLineBreak;
end;

procedure TMarkdownHtmlRenderer.EnterTable(const Node: IMarkdownNode);
begin
  FTableInBody := False;

  AppendLineBreak;
  FOutput.Append('<table>');
  AppendLineBreak;

  ScheduleLeaveAndChildren(Node, FTightList);
end;

procedure TMarkdownHtmlRenderer.EnterTableRow(const Node: IMarkdownTableRow);
begin
  FTableInHeader := Node.IsHeader;

  if FTableInHeader then
  begin
    FOutput.Append(TableHeadOpenTag);
    AppendLineBreak;
  end
  else if not FTableInBody then
  begin
    FOutput.Append(TableBodyOpenTag);
    AppendLineBreak;
    FTableInBody := True;
  end;

  FOutput.Append('<tr>');
  AppendLineBreak;

  ScheduleLeaveAndChildren(Node, FTightList);
end;

procedure TMarkdownHtmlRenderer.EnterTableCell(const Node: IMarkdownTableCell);
begin
  FOutput.Append(Format(TableCellOpenFormat, [CurrentTableCellTag]));

  const HasAlignment = (Node.Alignment <> TMarkdownTableColumnAlignment.None);
  if HasAlignment then
    FOutput.Append(Format(TableAlignAttributeFormat, [TableAlignmentNames[Node.Alignment]]));

  FOutput.Append(TagCloseBracket);

  ScheduleLeaveAndChildren(Node, FTightList);
end;

function TMarkdownHtmlRenderer.CurrentTableCellTag: string;
begin
  if FTableInHeader then
    Exit(TableHeaderCellTag);

  Result := TableDataCellTag;
end;

function TMarkdownHtmlRenderer.RawHtmlOutput(const Literal: string): string;
begin
  if not FOptions.AllowRawHtml then
    Exit(OmittedHtmlComment);

  if FOptions.ApplyTagFilter then
    Exit(FTagFilterRegex.Replace(Literal, EscapedLessThan));

  Result := Literal;
end;

procedure TMarkdownHtmlRenderer.EnterCustomInline(const Node: IMarkdownNode);
begin
  var Hook: IMarkdownRendererHook;

  if TryFindHook(Node, Hook) then
    Hook.RenderEnter(FWriter, Node);

  ScheduleLeaveAndChildren(Node, FTightList);
end;

procedure TMarkdownHtmlRenderer.LeaveCustomInline(const Node: IMarkdownNode);
begin
  var Hook: IMarkdownRendererHook;

  if TryFindHook(Node, Hook) then
    Hook.RenderLeave(FWriter, Node);
end;

function TMarkdownHtmlRenderer.TryFindHook(const Node: IMarkdownNode; out Hook: IMarkdownRendererHook): Boolean;
begin
  Hook := nil;

  if FHooks = nil then
    Exit(False);

  Result := FHooks.TryGetValue((Node as IMarkdownCustomInline).NodeName, Hook);
end;

procedure TMarkdownHtmlRenderer.EnterSpan(const Node: IMarkdownNode; const OpenTag: string);
begin
  FOutput.Append(OpenTag);

  ScheduleLeaveAndChildren(Node, FTightList);
end;

procedure TMarkdownHtmlRenderer.WriteCodeSpan(const Node: IMarkdownText);
begin
  FOutput.Append('<code>');
  FOutput.Append(EscapeHtml(Node.Literal));
  FOutput.Append('</code>');
end;

procedure TMarkdownHtmlRenderer.EnterAnchor(const Node: IMarkdownLink);
begin
  FOutput.Append(Format(AnchorOpenFormat, [EscapeHtml(DestinationOutput(Node.Destination))]));

  const HasTitle = (Node.Title <> '');
  if HasTitle then
    FOutput.Append(Format(TitleAttributeFormat, [EscapeHtml(Node.Title)]));

  FOutput.Append(TagCloseBracket);

  ScheduleLeaveAndChildren(Node, FTightList);
end;

procedure TMarkdownHtmlRenderer.WriteImage(const Node: IMarkdownLink);
begin
  FOutput.Append(Format(ImageOpenFormat, [EscapeHtml(DestinationOutput(Node.Destination))]));

  AppendAltText(Node);
  FOutput.Append('"');

  const HasTitle = (Node.Title <> '');
  if HasTitle then
    FOutput.Append(Format(TitleAttributeFormat, [EscapeHtml(Node.Title)]));

  FOutput.Append(' />');
end;

function TMarkdownHtmlRenderer.DestinationOutput(const Destination: string): string;
begin
  if FOptions.AllowUnsafeLinks then
    Exit(Destination);

  Result := TMarkdownUrlSafety.Sanitized(Destination);
end;

procedure TMarkdownHtmlRenderer.AppendAltText(const Node: IMarkdownNode);
begin
  const Pending = TStack<IMarkdownNode>.Create;
  try
    PushChildrenReversed(Pending, Node);

    while Pending.Count > 0 do
    begin
      const Current = Pending.Pop;

      case Current.Kind of
        TMarkdownNodeKind.Text, TMarkdownNodeKind.CodeSpan:
          FOutput.Append(EscapeHtml((Current as IMarkdownText).Literal));
        TMarkdownNodeKind.InlineHtml:
          FOutput.Append(RawHtmlOutput((Current as IMarkdownText).Literal));
        TMarkdownNodeKind.SoftLineBreak, TMarkdownNodeKind.HardLineBreak:
          FOutput.Append(LineFeed);
      else
        PushChildrenReversed(Pending, Current);
      end;
    end;
  finally
    Pending.Free;
  end;
end;

class procedure TMarkdownHtmlRenderer.PushChildrenReversed(const Pending: TStack<IMarkdownNode>;
                                                           const Node: IMarkdownNode);
begin
  for var Index := Node.ChildCount - 1 downto 0 do
  begin
    Pending.Push(Node.Children[Index]);
  end;
end;

procedure TMarkdownHtmlRenderer.WriteHardBreak;
begin
  FOutput.Append('<br />');
  FOutput.Append(LineFeed);
end;

procedure TMarkdownHtmlRenderer.LeaveParagraph;
begin
  if FTightList then
    Exit;

  FOutput.Append('</p>');
  AppendLineBreak;
end;

procedure TMarkdownHtmlRenderer.LeaveHeading(const Node: IMarkdownHeading);
begin
  FOutput.Append(Format(HeadingCloseFormat, [Node.Level]));
  AppendLineBreak;
end;

procedure TMarkdownHtmlRenderer.LeaveBlockQuote(const WasTightList: Boolean);
begin
  AppendLineBreak;
  FOutput.Append('</blockquote>');
  AppendLineBreak;

  FTightList := WasTightList;
end;

procedure TMarkdownHtmlRenderer.LeaveList(const Node: IMarkdownList; const WasTightList: Boolean);
begin
  var CloseTag := '</ul>';
  if Node.IsOrdered then
    CloseTag := '</ol>';

  AppendLineBreak;
  FOutput.Append(CloseTag);
  AppendLineBreak;

  FTightList := WasTightList;
end;

procedure TMarkdownHtmlRenderer.LeaveListItem;
begin
  FOutput.Append('</li>');
  AppendLineBreak;
end;

procedure TMarkdownHtmlRenderer.LeaveTable;
begin
  if FTableInBody then
  begin
    FOutput.Append(TableBodyCloseTag);
    AppendLineBreak;
    FTableInBody := False;
  end;

  FOutput.Append('</table>');
  AppendLineBreak;
end;

procedure TMarkdownHtmlRenderer.LeaveTableRow(const Node: IMarkdownTableRow);
begin
  FOutput.Append('</tr>');
  AppendLineBreak;

  if Node.IsHeader then
  begin
    FOutput.Append(TableHeadCloseTag);
    AppendLineBreak;
  end;
end;

procedure TMarkdownHtmlRenderer.LeaveTableCell;
begin
  FOutput.Append(Format(TableCellCloseFormat, [CurrentTableCellTag]));
  AppendLineBreak;
end;

procedure TMarkdownHtmlRenderer.ScheduleLeaveAndChildren(const Node: IMarkdownNode; const WasTightList: Boolean);
begin
  var LeaveTask: TRenderTask;
  LeaveTask.Node := Node;
  LeaveTask.Phase := TRenderPhase.Leave;
  LeaveTask.WasTightList := WasTightList;
  FTasks.Push(LeaveTask);

  for var Index := Node.ChildCount - 1 downto 0 do
  begin
    var EnterTask: TRenderTask;
    EnterTask.Node := Node.Children[Index];
    EnterTask.Phase := TRenderPhase.Enter;
    EnterTask.WasTightList := False;

    FTasks.Push(EnterTask);
  end;
end;

procedure TMarkdownHtmlRenderer.AppendLineBreak;
begin
  const IsAtLineStart = (FOutput.Length = 0) or (FOutput.Chars[FOutput.Length - 1] = LineFeed);
  if not IsAtLineStart then
    FOutput.Append(LineFeed);
end;

class function TMarkdownHtmlRenderer.FirstInfoWord(const InfoString: string): string;
begin
  const Parts = InfoString.Split(InfoSplitChars, TStringSplitOptions.ExcludeEmpty);

  if Length(Parts) = 0 then
    Exit('');

  Result := Parts[0];
end;

class function TMarkdownHtmlRenderer.EscapeCore(const Value: string; const EscapeApostrophe: Boolean): string;
begin
  const WithAmpersands = StringReplace(Value, '&', EscapedAmpersand, [rfReplaceAll]);
  const WithLessThan = StringReplace(WithAmpersands, '<', EscapedLessThan, [rfReplaceAll]);
  const WithGreaterThan = StringReplace(WithLessThan, '>', EscapedGreaterThan, [rfReplaceAll]);

  Result := StringReplace(WithGreaterThan, '"', EscapedQuote, [rfReplaceAll]);

  if EscapeApostrophe then
    Result := StringReplace(Result, '''', EscapedApostrophe, [rfReplaceAll]);
end;

class function TMarkdownHtmlRenderer.EscapeHtml(const Value: string): string;
begin
  Result := EscapeCore(Value, False);
end;

constructor TRendererHtmlWriter.Create(const Output: TStringBuilder);
begin
  inherited Create;

  FOutput := Output;
end;

procedure TRendererHtmlWriter.WriteRaw(const Html: string);
begin
  FOutput.Append(Html);
end;

procedure TRendererHtmlWriter.WriteEscaped(const Text: string);
begin
  FOutput.Append(TMarkdownHtmlRenderer.EscapeHtml(Text));
end;

function TRendererHtmlWriter.EscapeAttribute(const Value: string): string;
begin
  Result := TMarkdownHtmlRenderer.EscapeCore(Value, True);
end;

procedure TRendererHtmlWriter.WriteAttribute(const Name, Value: string);
begin
  FOutput.Append(' ');
  FOutput.Append(Name);
  FOutput.Append('="');
  FOutput.Append(EscapeAttribute(Value));
  FOutput.Append('"');
end;

end.
