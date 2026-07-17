unit Markdown4D.Ast;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces;

type
  TMarkdownAstNode = class(TInterfacedObject, IMarkdownNode)
  private
    FKind: TMarkdownNodeKind;
    FSegment: TMarkdownSegment;
    FChildren: TList<IMarkdownNode>;
    FExtensionData: TDictionary<string, IInterface>;
    procedure ReleaseChildrenIteratively;

  public
    constructor Create(const Kind: TMarkdownNodeKind);
    destructor Destroy; override;
    function GetKind: TMarkdownNodeKind;
    function GetSegment: TMarkdownSegment;
    function GetChildCount: Integer;
    function GetChild(const Index: Integer): IMarkdownNode;
    procedure Accept(const Visitor: IMarkdownVisitor);
    procedure SetExtensionData(const Key: string; const Data: IInterface);
    function TryGetExtensionData(const Key: string; out Data: IInterface): Boolean;
    procedure AddChild(const Child: IMarkdownNode);
    procedure SetSegment(const Segment: TMarkdownSegment);
    property Kind: TMarkdownNodeKind read FKind;
    property ChildCount: Integer read GetChildCount;
  end;

  TMarkdownDocumentNode = class(TMarkdownAstNode, IMarkdownDocument)
  public
    constructor Create;
  end;

  TMarkdownHeadingNode = class(TMarkdownAstNode, IMarkdownHeading)
  private
    FLevel: Integer;
    FSourceLine: Integer;

  public
    constructor Create(const Level: Integer);
    function GetLevel: Integer;
    function GetSourceLine: Integer;
    procedure SetSourceLine(const SourceLine: Integer);
  end;

  TMarkdownCodeBlockNode = class(TMarkdownAstNode, IMarkdownCodeBlock)
  private
    FLiteral: string;
    FInfoString: string;
    FIsFenced: Boolean;

  public
    constructor Create(const Literal, InfoString: string; const IsFenced: Boolean);
    function GetLiteral: string;
    function GetInfoString: string;
    function GetIsFenced: Boolean;
  end;

  TMarkdownListNode = class(TMarkdownAstNode, IMarkdownList)
  private
    FIsOrdered: Boolean;
    FStartNumber: Integer;
    FIsTight: Boolean;

  public
    constructor Create(const IsOrdered: Boolean; const StartNumber: Integer; const IsTight: Boolean);
    function GetIsOrdered: Boolean;
    function GetStartNumber: Integer;
    function GetIsTight: Boolean;
  end;

  TMarkdownTextNode = class(TMarkdownAstNode, IMarkdownText)
  private
    FLiteral: string;

  public
    constructor Create(const Kind: TMarkdownNodeKind; const Literal: string);
    function GetLiteral: string;
    procedure SetLiteral(const Literal: string);
  end;

  TMarkdownCustomInlineNode = class(TMarkdownAstNode, IMarkdownCustomInline)
  private
    FNodeName: string;

  public
    constructor Create(const NodeName: string);
    function GetNodeName: string;
  end;

  TMarkdownTableRowNode = class(TMarkdownAstNode, IMarkdownTableRow)
  private
    FIsHeader: Boolean;

  public
    constructor Create(const IsHeader: Boolean);
    function GetIsHeader: Boolean;
  end;

  TMarkdownTableCellNode = class(TMarkdownAstNode, IMarkdownTableCell)
  private
    FAlignment: TMarkdownTableColumnAlignment;

  public
    constructor Create(const Alignment: TMarkdownTableColumnAlignment);
    function GetAlignment: TMarkdownTableColumnAlignment;
  end;

  TMarkdownLinkNode = class(TMarkdownAstNode, IMarkdownLink)
  private
    FDestination: string;
    FTitle: string;

  public
    constructor Create(const Kind: TMarkdownNodeKind; const Destination, Title: string);
    function GetDestination: string;
    function GetTitle: string;
  end;

implementation

constructor TMarkdownAstNode.Create(const Kind: TMarkdownNodeKind);
begin
  inherited Create;

  FKind := Kind;
  FChildren := TList<IMarkdownNode>.Create;
end;

destructor TMarkdownAstNode.Destroy;
begin
  ReleaseChildrenIteratively;

  FExtensionData.Free;
  FChildren.Free;

  inherited Destroy;
end;

procedure TMarkdownAstNode.ReleaseChildrenIteratively;
begin
  const HasChildren = (FChildren <> nil) and (FChildren.Count > 0);
  if not HasChildren then
    Exit;

  const Pending = TList<IMarkdownNode>.Create;
  try
    Pending.AddRange(FChildren);
    FChildren.Clear;

    while Pending.Count > 0 do
    begin
      const LastIndex = Pending.Count - 1;
      const Current = Pending.List[LastIndex] as TMarkdownAstNode;

      const DiesOnRelease = (Current.RefCount = 1);
      if DiesOnRelease then
      begin
        Pending.AddRange(Current.FChildren);
        Current.FChildren.Clear;
      end;

      Pending.Delete(LastIndex);
    end;
  finally
    Pending.Free;
  end;
end;

function TMarkdownAstNode.GetKind: TMarkdownNodeKind;
begin
  Result := FKind;
end;

function TMarkdownAstNode.GetSegment: TMarkdownSegment;
begin
  Result := FSegment;
end;

function TMarkdownAstNode.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TMarkdownAstNode.GetChild(const Index: Integer): IMarkdownNode;
begin
  Result := FChildren[Index];
end;

procedure TMarkdownAstNode.Accept(const Visitor: IMarkdownVisitor);
begin
  case FKind of
    TMarkdownNodeKind.Document:
      Visitor.VisitDocument(Self as IMarkdownDocument);
    TMarkdownNodeKind.Paragraph:
      Visitor.VisitParagraph(Self);
    TMarkdownNodeKind.Heading:
      Visitor.VisitHeading(Self as IMarkdownHeading);
    TMarkdownNodeKind.ThematicBreak:
      Visitor.VisitThematicBreak(Self);
    TMarkdownNodeKind.CodeBlock:
      Visitor.VisitCodeBlock(Self as IMarkdownCodeBlock);
    TMarkdownNodeKind.BlockQuote:
      Visitor.VisitBlockQuote(Self);
    TMarkdownNodeKind.List:
      Visitor.VisitList(Self as IMarkdownList);
    TMarkdownNodeKind.ListItem:
      Visitor.VisitListItem(Self);
    TMarkdownNodeKind.HtmlBlock:
      Visitor.VisitHtmlBlock(Self as IMarkdownText);
    TMarkdownNodeKind.Text:
      Visitor.VisitText(Self as IMarkdownText);
    TMarkdownNodeKind.Emphasis:
      Visitor.VisitEmphasis(Self);
    TMarkdownNodeKind.Strong:
      Visitor.VisitStrong(Self);
    TMarkdownNodeKind.CodeSpan:
      Visitor.VisitCodeSpan(Self as IMarkdownText);
    TMarkdownNodeKind.Link:
      Visitor.VisitLink(Self as IMarkdownLink);
    TMarkdownNodeKind.Image:
      Visitor.VisitImage(Self as IMarkdownLink);
    TMarkdownNodeKind.Autolink:
      Visitor.VisitAutolink(Self as IMarkdownLink);
    TMarkdownNodeKind.SoftLineBreak:
      Visitor.VisitSoftLineBreak(Self);
    TMarkdownNodeKind.HardLineBreak:
      Visitor.VisitHardLineBreak(Self);
    TMarkdownNodeKind.InlineHtml:
      Visitor.VisitInlineHtml(Self as IMarkdownText);
    TMarkdownNodeKind.CustomInline:
      Visitor.VisitCustomInline(Self as IMarkdownCustomInline);
    TMarkdownNodeKind.Table:
      Visitor.VisitTable(Self);
    TMarkdownNodeKind.TableRow:
      Visitor.VisitTableRow(Self as IMarkdownTableRow);
    TMarkdownNodeKind.TableCell:
      Visitor.VisitTableCell(Self as IMarkdownTableCell);
  end;
end;

procedure TMarkdownAstNode.SetExtensionData(const Key: string; const Data: IInterface);
begin
  if FExtensionData = nil then
    FExtensionData := TDictionary<string, IInterface>.Create;

  FExtensionData.AddOrSetValue(Key, Data);
end;

function TMarkdownAstNode.TryGetExtensionData(const Key: string; out Data: IInterface): Boolean;
begin
  Data := nil;

  Result := (FExtensionData <> nil) and FExtensionData.TryGetValue(Key, Data);
end;

procedure TMarkdownAstNode.AddChild(const Child: IMarkdownNode);
begin
  FChildren.Add(Child);
end;

procedure TMarkdownAstNode.SetSegment(const Segment: TMarkdownSegment);
begin
  FSegment := Segment;
end;

constructor TMarkdownDocumentNode.Create;
begin
  inherited Create(TMarkdownNodeKind.Document);
end;

constructor TMarkdownHeadingNode.Create(const Level: Integer);
begin
  inherited Create(TMarkdownNodeKind.Heading);

  FLevel := Level;
end;

function TMarkdownHeadingNode.GetLevel: Integer;
begin
  Result := FLevel;
end;

function TMarkdownHeadingNode.GetSourceLine: Integer;
begin
  Result := FSourceLine;
end;

procedure TMarkdownHeadingNode.SetSourceLine(const SourceLine: Integer);
begin
  FSourceLine := SourceLine;
end;

constructor TMarkdownCodeBlockNode.Create(const Literal, InfoString: string; const IsFenced: Boolean);
begin
  inherited Create(TMarkdownNodeKind.CodeBlock);

  FLiteral := Literal;
  FInfoString := InfoString;
  FIsFenced := IsFenced;
end;

function TMarkdownCodeBlockNode.GetLiteral: string;
begin
  Result := FLiteral;
end;

function TMarkdownCodeBlockNode.GetInfoString: string;
begin
  Result := FInfoString;
end;

function TMarkdownCodeBlockNode.GetIsFenced: Boolean;
begin
  Result := FIsFenced;
end;

constructor TMarkdownListNode.Create(const IsOrdered: Boolean; const StartNumber: Integer; const IsTight: Boolean);
begin
  inherited Create(TMarkdownNodeKind.List);

  FIsOrdered := IsOrdered;
  FStartNumber := StartNumber;
  FIsTight := IsTight;
end;

function TMarkdownListNode.GetIsOrdered: Boolean;
begin
  Result := FIsOrdered;
end;

function TMarkdownListNode.GetStartNumber: Integer;
begin
  Result := FStartNumber;
end;

function TMarkdownListNode.GetIsTight: Boolean;
begin
  Result := FIsTight;
end;

constructor TMarkdownTextNode.Create(const Kind: TMarkdownNodeKind; const Literal: string);
begin
  inherited Create(Kind);

  FLiteral := Literal;
end;

function TMarkdownTextNode.GetLiteral: string;
begin
  Result := FLiteral;
end;

procedure TMarkdownTextNode.SetLiteral(const Literal: string);
begin
  FLiteral := Literal;
end;

constructor TMarkdownCustomInlineNode.Create(const NodeName: string);
begin
  inherited Create(TMarkdownNodeKind.CustomInline);

  FNodeName := NodeName;
end;

function TMarkdownCustomInlineNode.GetNodeName: string;
begin
  Result := FNodeName;
end;

constructor TMarkdownTableRowNode.Create(const IsHeader: Boolean);
begin
  inherited Create(TMarkdownNodeKind.TableRow);

  FIsHeader := IsHeader;
end;

function TMarkdownTableRowNode.GetIsHeader: Boolean;
begin
  Result := FIsHeader;
end;

constructor TMarkdownTableCellNode.Create(const Alignment: TMarkdownTableColumnAlignment);
begin
  inherited Create(TMarkdownNodeKind.TableCell);

  FAlignment := Alignment;
end;

function TMarkdownTableCellNode.GetAlignment: TMarkdownTableColumnAlignment;
begin
  Result := FAlignment;
end;

constructor TMarkdownLinkNode.Create(const Kind: TMarkdownNodeKind; const Destination, Title: string);
begin
  inherited Create(Kind);

  FDestination := Destination;
  FTitle := Title;
end;

function TMarkdownLinkNode.GetDestination: string;
begin
  Result := FDestination;
end;

function TMarkdownLinkNode.GetTitle: string;
begin
  Result := FTitle;
end;

end.
