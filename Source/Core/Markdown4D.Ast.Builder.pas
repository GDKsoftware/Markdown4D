unit Markdown4D.Ast.Builder;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces;

type
  IMarkdownDocumentBuilder = interface
    ['{91CBB126-35EB-42C8-A2AC-86A8D58ED75E}']
    function Heading(const Level: Integer; const Caption: string): IMarkdownDocumentBuilder;
    function BeginHeading(const Level: Integer): IMarkdownDocumentBuilder;
    function EndHeading: IMarkdownDocumentBuilder;
    function Paragraph(const Value: string): IMarkdownDocumentBuilder;
    function BeginParagraph: IMarkdownDocumentBuilder;
    function EndParagraph: IMarkdownDocumentBuilder;
    function CodeBlock(const Literal: string; const InfoString: string = ''): IMarkdownDocumentBuilder;
    function ThematicBreak: IMarkdownDocumentBuilder;
    function BeginBlockQuote: IMarkdownDocumentBuilder;
    function EndBlockQuote: IMarkdownDocumentBuilder;
    function BeginBulletList(const Tight: Boolean = True): IMarkdownDocumentBuilder;
    function BeginOrderedList(const StartNumber: Integer = 1; const Tight: Boolean = True): IMarkdownDocumentBuilder;
    function EndList: IMarkdownDocumentBuilder;
    function BeginListItem: IMarkdownDocumentBuilder;
    function BeginTaskListItem(const Checked: Boolean): IMarkdownDocumentBuilder;
    function EndListItem: IMarkdownDocumentBuilder;
    function BeginTable(const Alignments: array of TMarkdownTableColumnAlignment): IMarkdownDocumentBuilder;
    function EndTable: IMarkdownDocumentBuilder;
    function BeginTableRow: IMarkdownDocumentBuilder;
    function EndTableRow: IMarkdownDocumentBuilder;
    function Cell(const Value: string): IMarkdownDocumentBuilder;
    function BeginTableCell: IMarkdownDocumentBuilder;
    function EndTableCell: IMarkdownDocumentBuilder;
    function Text(const Value: string): IMarkdownDocumentBuilder;
    function Bold(const Value: string): IMarkdownDocumentBuilder;
    function BeginBold: IMarkdownDocumentBuilder;
    function EndBold: IMarkdownDocumentBuilder;
    function Italic(const Value: string): IMarkdownDocumentBuilder;
    function BeginItalic: IMarkdownDocumentBuilder;
    function EndItalic: IMarkdownDocumentBuilder;
    function Strikethrough(const Value: string): IMarkdownDocumentBuilder;
    function BeginStrikethrough: IMarkdownDocumentBuilder;
    function EndStrikethrough: IMarkdownDocumentBuilder;
    function Code(const Value: string): IMarkdownDocumentBuilder;
    function Link(const Caption, Destination: string; const Title: string = ''): IMarkdownDocumentBuilder;
    function BeginLink(const Destination: string; const Title: string = ''): IMarkdownDocumentBuilder;
    function EndLink: IMarkdownDocumentBuilder;
    function Image(const AltText, Destination: string; const Title: string = ''): IMarkdownDocumentBuilder;
    function HardLineBreak: IMarkdownDocumentBuilder;
    function SoftLineBreak: IMarkdownDocumentBuilder;
    function Build: IMarkdownDocument;
  end;

  TMarkdownDocumentBuilder = class
  public
    class function Create: IMarkdownDocumentBuilder;
  end;

implementation

uses
  System.SysUtils,
  System.TypInfo,
  System.Generics.Collections,
  Markdown4D.Defines,
  Markdown4D.Ast,
  Markdown4D.Parser.Inlines;

const
  TaskMarkerSeparator = ' ';
  DefaultBulletStartNumber = 1;

type
  TMarkdownDocumentBuilderInstance = class(TInterfacedObject, IMarkdownDocumentBuilder)
  private
    FDocument: IMarkdownDocument;
    FRoot: TMarkdownAstNode;
    FOpenNodes: TStack<TMarkdownAstNode>;
    FTableAlignments: TStack<TArray<TMarkdownTableColumnAlignment>>;
    FPendingTaskMarkerName: string;
    procedure InjectPendingTaskMarker(const Paragraph: TMarkdownAstNode);
    function OpenNode(const Node: TMarkdownAstNode): IMarkdownDocumentBuilder;
    function AppendNode(const Node: TMarkdownAstNode): IMarkdownDocumentBuilder;
    procedure ValidateChildPlacement(const ChildKind: TMarkdownNodeKind);
    function CloseNode(const Kind: TMarkdownNodeKind): IMarkdownDocumentBuilder;
    function CurrentContainer: TMarkdownAstNode;

  public
    constructor Create;
    destructor Destroy; override;
    function Heading(const Level: Integer; const Caption: string): IMarkdownDocumentBuilder;
    function BeginHeading(const Level: Integer): IMarkdownDocumentBuilder;
    function EndHeading: IMarkdownDocumentBuilder;
    function Paragraph(const Value: string): IMarkdownDocumentBuilder;
    function BeginParagraph: IMarkdownDocumentBuilder;
    function EndParagraph: IMarkdownDocumentBuilder;
    function CodeBlock(const Literal: string; const InfoString: string = ''): IMarkdownDocumentBuilder;
    function ThematicBreak: IMarkdownDocumentBuilder;
    function BeginBlockQuote: IMarkdownDocumentBuilder;
    function EndBlockQuote: IMarkdownDocumentBuilder;
    function BeginBulletList(const Tight: Boolean = True): IMarkdownDocumentBuilder;
    function BeginOrderedList(const StartNumber: Integer = 1; const Tight: Boolean = True): IMarkdownDocumentBuilder;
    function EndList: IMarkdownDocumentBuilder;
    function BeginListItem: IMarkdownDocumentBuilder;
    function BeginTaskListItem(const Checked: Boolean): IMarkdownDocumentBuilder;
    function EndListItem: IMarkdownDocumentBuilder;
    function BeginTable(const Alignments: array of TMarkdownTableColumnAlignment): IMarkdownDocumentBuilder;
    function EndTable: IMarkdownDocumentBuilder;
    function BeginTableRow: IMarkdownDocumentBuilder;
    function EndTableRow: IMarkdownDocumentBuilder;
    function Cell(const Value: string): IMarkdownDocumentBuilder;
    function BeginTableCell: IMarkdownDocumentBuilder;
    function EndTableCell: IMarkdownDocumentBuilder;
    function Text(const Value: string): IMarkdownDocumentBuilder;
    function Bold(const Value: string): IMarkdownDocumentBuilder;
    function BeginBold: IMarkdownDocumentBuilder;
    function EndBold: IMarkdownDocumentBuilder;
    function Italic(const Value: string): IMarkdownDocumentBuilder;
    function BeginItalic: IMarkdownDocumentBuilder;
    function EndItalic: IMarkdownDocumentBuilder;
    function Strikethrough(const Value: string): IMarkdownDocumentBuilder;
    function BeginStrikethrough: IMarkdownDocumentBuilder;
    function EndStrikethrough: IMarkdownDocumentBuilder;
    function Code(const Value: string): IMarkdownDocumentBuilder;
    function Link(const Caption, Destination: string; const Title: string = ''): IMarkdownDocumentBuilder;
    function BeginLink(const Destination: string; const Title: string = ''): IMarkdownDocumentBuilder;
    function EndLink: IMarkdownDocumentBuilder;
    function Image(const AltText, Destination: string; const Title: string = ''): IMarkdownDocumentBuilder;
    function HardLineBreak: IMarkdownDocumentBuilder;
    function SoftLineBreak: IMarkdownDocumentBuilder;
    function Build: IMarkdownDocument;
  end;

class function TMarkdownDocumentBuilder.Create: IMarkdownDocumentBuilder;
begin
  Result := TMarkdownDocumentBuilderInstance.Create;
end;

constructor TMarkdownDocumentBuilderInstance.Create;
begin
  inherited Create;

  const Root = TMarkdownDocumentNode.Create;
  FRoot := Root;
  FDocument := Root;

  FOpenNodes := TStack<TMarkdownAstNode>.Create;
  FTableAlignments := TStack<TArray<TMarkdownTableColumnAlignment>>.Create;
end;

destructor TMarkdownDocumentBuilderInstance.Destroy;
begin
  FTableAlignments.Free;
  FOpenNodes.Free;

  inherited Destroy;
end;

function TMarkdownDocumentBuilderInstance.Heading(const Level: Integer; const Caption: string): IMarkdownDocumentBuilder;
begin
  BeginHeading(Level);
  Text(Caption);

  Result := EndHeading;
end;

function TMarkdownDocumentBuilderInstance.BeginHeading(const Level: Integer): IMarkdownDocumentBuilder;
begin
  Result := OpenNode(TMarkdownHeadingNode.Create(Level));
end;

function TMarkdownDocumentBuilderInstance.EndHeading: IMarkdownDocumentBuilder;
begin
  Result := CloseNode(TMarkdownNodeKind.Heading);
end;

function TMarkdownDocumentBuilderInstance.Paragraph(const Value: string): IMarkdownDocumentBuilder;
begin
  BeginParagraph;
  Text(Value);

  Result := EndParagraph;
end;

function TMarkdownDocumentBuilderInstance.BeginParagraph: IMarkdownDocumentBuilder;
begin
  const Node = TMarkdownAstNode.Create(TMarkdownNodeKind.Paragraph);
  Result := OpenNode(Node);

  InjectPendingTaskMarker(Node);
end;

function TMarkdownDocumentBuilderInstance.EndParagraph: IMarkdownDocumentBuilder;
begin
  Result := CloseNode(TMarkdownNodeKind.Paragraph);
end;

function TMarkdownDocumentBuilderInstance.CodeBlock(const Literal: string; const InfoString: string): IMarkdownDocumentBuilder;
begin
  var NormalizedLiteral := Literal;

  const NeedsTrailingLineFeed = (NormalizedLiteral <> '') and (not NormalizedLiteral.EndsWith(LineFeed));
  if NeedsTrailingLineFeed then
    NormalizedLiteral := NormalizedLiteral + LineFeed;

  Result := AppendNode(TMarkdownCodeBlockNode.Create(NormalizedLiteral, InfoString, True));
end;

function TMarkdownDocumentBuilderInstance.ThematicBreak: IMarkdownDocumentBuilder;
begin
  Result := AppendNode(TMarkdownAstNode.Create(TMarkdownNodeKind.ThematicBreak));
end;

function TMarkdownDocumentBuilderInstance.BeginBlockQuote: IMarkdownDocumentBuilder;
begin
  Result := OpenNode(TMarkdownAstNode.Create(TMarkdownNodeKind.BlockQuote));
end;

function TMarkdownDocumentBuilderInstance.EndBlockQuote: IMarkdownDocumentBuilder;
begin
  Result := CloseNode(TMarkdownNodeKind.BlockQuote);
end;

function TMarkdownDocumentBuilderInstance.BeginBulletList(const Tight: Boolean): IMarkdownDocumentBuilder;
begin
  Result := OpenNode(TMarkdownListNode.Create(False, DefaultBulletStartNumber, Tight));
end;

function TMarkdownDocumentBuilderInstance.BeginOrderedList(const StartNumber: Integer; const Tight: Boolean): IMarkdownDocumentBuilder;
begin
  Result := OpenNode(TMarkdownListNode.Create(True, StartNumber, Tight));
end;

function TMarkdownDocumentBuilderInstance.EndList: IMarkdownDocumentBuilder;
begin
  Result := CloseNode(TMarkdownNodeKind.List);
end;

function TMarkdownDocumentBuilderInstance.BeginListItem: IMarkdownDocumentBuilder;
begin
  Result := OpenNode(TMarkdownAstNode.Create(TMarkdownNodeKind.ListItem));
end;

function TMarkdownDocumentBuilderInstance.BeginTaskListItem(const Checked: Boolean): IMarkdownDocumentBuilder;
begin
  Result := BeginListItem;

  FPendingTaskMarkerName := TGfmInlineParser.TaskUncheckedNodeName;
  if Checked then
    FPendingTaskMarkerName := TGfmInlineParser.TaskCheckedNodeName;
end;

function TMarkdownDocumentBuilderInstance.EndListItem: IMarkdownDocumentBuilder;
begin
  FPendingTaskMarkerName := '';

  Result := CloseNode(TMarkdownNodeKind.ListItem);
end;

function TMarkdownDocumentBuilderInstance.BeginTable(const Alignments: array of TMarkdownTableColumnAlignment): IMarkdownDocumentBuilder;
begin
  var AlignmentValues: TArray<TMarkdownTableColumnAlignment>;
  SetLength(AlignmentValues, Length(Alignments));

  for var Index := 0 to High(Alignments) do
  begin
    AlignmentValues[Index] := Alignments[Index];
  end;
  FTableAlignments.Push(AlignmentValues);

  Result := OpenNode(TMarkdownAstNode.Create(TMarkdownNodeKind.Table));
end;

function TMarkdownDocumentBuilderInstance.EndTable: IMarkdownDocumentBuilder;
begin
  Result := CloseNode(TMarkdownNodeKind.Table);

  FTableAlignments.Pop;
end;

function TMarkdownDocumentBuilderInstance.BeginTableRow: IMarkdownDocumentBuilder;
begin
  const IsHeaderRow = (CurrentContainer.ChildCount = 0);

  Result := OpenNode(TMarkdownTableRowNode.Create(IsHeaderRow));
end;

function TMarkdownDocumentBuilderInstance.EndTableRow: IMarkdownDocumentBuilder;
begin
  Result := CloseNode(TMarkdownNodeKind.TableRow);
end;

function TMarkdownDocumentBuilderInstance.Cell(const Value: string): IMarkdownDocumentBuilder;
begin
  BeginTableCell;
  Text(Value);

  Result := EndTableCell;
end;

function TMarkdownDocumentBuilderInstance.BeginTableCell: IMarkdownDocumentBuilder;
begin
  const ColumnIndex = CurrentContainer.ChildCount;

  var Alignment := TMarkdownTableColumnAlignment.None;
  if FTableAlignments.Count > 0 then
  begin
    const Alignments = FTableAlignments.Peek;
    if ColumnIndex < Length(Alignments) then
      Alignment := Alignments[ColumnIndex];
  end;

  Result := OpenNode(TMarkdownTableCellNode.Create(Alignment));
end;

function TMarkdownDocumentBuilderInstance.EndTableCell: IMarkdownDocumentBuilder;
begin
  Result := CloseNode(TMarkdownNodeKind.TableCell);
end;

function TMarkdownDocumentBuilderInstance.Text(const Value: string): IMarkdownDocumentBuilder;
begin
  Result := AppendNode(TMarkdownTextNode.Create(TMarkdownNodeKind.Text, Value));
end;

function TMarkdownDocumentBuilderInstance.Bold(const Value: string): IMarkdownDocumentBuilder;
begin
  BeginBold;
  Text(Value);

  Result := EndBold;
end;

function TMarkdownDocumentBuilderInstance.BeginBold: IMarkdownDocumentBuilder;
begin
  Result := OpenNode(TMarkdownAstNode.Create(TMarkdownNodeKind.Strong));
end;

function TMarkdownDocumentBuilderInstance.EndBold: IMarkdownDocumentBuilder;
begin
  Result := CloseNode(TMarkdownNodeKind.Strong);
end;

function TMarkdownDocumentBuilderInstance.Italic(const Value: string): IMarkdownDocumentBuilder;
begin
  BeginItalic;
  Text(Value);

  Result := EndItalic;
end;

function TMarkdownDocumentBuilderInstance.BeginItalic: IMarkdownDocumentBuilder;
begin
  Result := OpenNode(TMarkdownAstNode.Create(TMarkdownNodeKind.Emphasis));
end;

function TMarkdownDocumentBuilderInstance.EndItalic: IMarkdownDocumentBuilder;
begin
  Result := CloseNode(TMarkdownNodeKind.Emphasis);
end;

function TMarkdownDocumentBuilderInstance.Strikethrough(const Value: string): IMarkdownDocumentBuilder;
begin
  BeginStrikethrough;
  Text(Value);

  Result := EndStrikethrough;
end;

function TMarkdownDocumentBuilderInstance.BeginStrikethrough: IMarkdownDocumentBuilder;
begin
  Result := OpenNode(TMarkdownCustomInlineNode.Create(TGfmInlineParser.StrikethroughNodeName));
end;

function TMarkdownDocumentBuilderInstance.EndStrikethrough: IMarkdownDocumentBuilder;
begin
  Result := CloseNode(TMarkdownNodeKind.CustomInline);
end;

function TMarkdownDocumentBuilderInstance.Code(const Value: string): IMarkdownDocumentBuilder;
begin
  Result := AppendNode(TMarkdownTextNode.Create(TMarkdownNodeKind.CodeSpan, Value));
end;

function TMarkdownDocumentBuilderInstance.Link(const Caption, Destination: string; const Title: string): IMarkdownDocumentBuilder;
begin
  BeginLink(Destination, Title);
  Text(Caption);

  Result := EndLink;
end;

function TMarkdownDocumentBuilderInstance.BeginLink(const Destination: string; const Title: string): IMarkdownDocumentBuilder;
begin
  Result := OpenNode(TMarkdownLinkNode.Create(TMarkdownNodeKind.Link, Destination, Title));
end;

function TMarkdownDocumentBuilderInstance.EndLink: IMarkdownDocumentBuilder;
begin
  Result := CloseNode(TMarkdownNodeKind.Link);
end;

function TMarkdownDocumentBuilderInstance.Image(const AltText, Destination: string; const Title: string): IMarkdownDocumentBuilder;
begin
  const Node = TMarkdownLinkNode.Create(TMarkdownNodeKind.Image, Destination, Title);
  Node.AddChild(TMarkdownTextNode.Create(TMarkdownNodeKind.Text, AltText));

  Result := AppendNode(Node);
end;

function TMarkdownDocumentBuilderInstance.HardLineBreak: IMarkdownDocumentBuilder;
begin
  Result := AppendNode(TMarkdownAstNode.Create(TMarkdownNodeKind.HardLineBreak));
end;

function TMarkdownDocumentBuilderInstance.SoftLineBreak: IMarkdownDocumentBuilder;
begin
  Result := AppendNode(TMarkdownAstNode.Create(TMarkdownNodeKind.SoftLineBreak));
end;

function TMarkdownDocumentBuilderInstance.Build: IMarkdownDocument;
begin
  const HasOpenNodes = (FOpenNodes.Count > 0);
  if HasOpenNodes then
    raise EMarkdownError.CreateFmt('Cannot build the document because %d node(s) are still open', [FOpenNodes.Count]);

  Result := FDocument;
end;

procedure TMarkdownDocumentBuilderInstance.InjectPendingTaskMarker(const Paragraph: TMarkdownAstNode);
begin
  if FPendingTaskMarkerName = '' then
    Exit;

  Paragraph.AddChild(TMarkdownCustomInlineNode.Create(FPendingTaskMarkerName));
  Paragraph.AddChild(TMarkdownTextNode.Create(TMarkdownNodeKind.Text, TaskMarkerSeparator));
  FPendingTaskMarkerName := '';
end;

function TMarkdownDocumentBuilderInstance.OpenNode(const Node: TMarkdownAstNode): IMarkdownDocumentBuilder;
begin
  const Child: IMarkdownNode = Node;
  ValidateChildPlacement(Node.Kind);

  CurrentContainer.AddChild(Child);
  FOpenNodes.Push(Node);

  Result := Self;
end;

function TMarkdownDocumentBuilderInstance.AppendNode(const Node: TMarkdownAstNode): IMarkdownDocumentBuilder;
begin
  const Child: IMarkdownNode = Node;
  ValidateChildPlacement(Node.Kind);

  CurrentContainer.AddChild(Child);

  Result := Self;
end;

procedure TMarkdownDocumentBuilderInstance.ValidateChildPlacement(const ChildKind: TMarkdownNodeKind);
begin
  const ContainerKind = CurrentContainer.Kind;

  const RowOutsideTable = (ChildKind = TMarkdownNodeKind.TableRow) and (ContainerKind <> TMarkdownNodeKind.Table);
  if RowOutsideTable then
    raise EMarkdownError.Create('A table row can only be opened inside a table');

  const CellOutsideRow = (ChildKind = TMarkdownNodeKind.TableCell) and (ContainerKind <> TMarkdownNodeKind.TableRow);
  if CellOutsideRow then
    raise EMarkdownError.Create('A table cell can only be opened inside a table row');

  const NonRowInsideTable = (ContainerKind = TMarkdownNodeKind.Table) and (ChildKind <> TMarkdownNodeKind.TableRow);
  if NonRowInsideTable then
    raise EMarkdownError.Create('A table can only contain table rows');

  const NonCellInsideRow = (ContainerKind = TMarkdownNodeKind.TableRow) and (ChildKind <> TMarkdownNodeKind.TableCell);
  if NonCellInsideRow then
    raise EMarkdownError.Create('A table row can only contain table cells');
end;

function TMarkdownDocumentBuilderInstance.CloseNode(const Kind: TMarkdownNodeKind): IMarkdownDocumentBuilder;
begin
  const HasMatchingOpenNode = (FOpenNodes.Count > 0) and (FOpenNodes.Peek.Kind = Kind);
  if not HasMatchingOpenNode then
    raise EMarkdownError.CreateFmt('Cannot close %s because it is not the innermost open node',
      [GetEnumName(TypeInfo(TMarkdownNodeKind), Ord(Kind))]);

  FOpenNodes.Pop;

  Result := Self;
end;

function TMarkdownDocumentBuilderInstance.CurrentContainer: TMarkdownAstNode;
begin
  if FOpenNodes.Count > 0 then
    Exit(FOpenNodes.Peek);

  Result := FRoot;
end;

end.
