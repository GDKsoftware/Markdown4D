unit Markdown4D.Ast.Interfaces;

{$SCOPEDENUMS ON}

interface

type
  TMarkdownNodeKind = (Document, Paragraph, Heading, ThematicBreak, CodeBlock, BlockQuote, List, ListItem,
    HtmlBlock, Text, Emphasis, Strong, CodeSpan, Link, Image, Autolink, SoftLineBreak, HardLineBreak, InlineHtml,
    CustomInline, Table, TableRow, TableCell);

  TMarkdownTableColumnAlignment = (None, Left, Center, Right);

  TMarkdownSegment = record
    StartOffset: Integer;
    EndOffset: Integer;
    class function Create(const StartOffset, EndOffset: Integer): TMarkdownSegment; static;
    function Length: Integer;
  end;

  IMarkdownVisitor = interface;

  IMarkdownNode = interface
    ['{78979BFD-4EA8-4380-94C2-007A23AEEE02}']
    function GetKind: TMarkdownNodeKind;
    function GetSegment: TMarkdownSegment;
    function GetChildCount: Integer;
    function GetChild(const Index: Integer): IMarkdownNode;
    procedure Accept(const Visitor: IMarkdownVisitor);
    procedure SetExtensionData(const Key: string; const Data: IInterface);
    function TryGetExtensionData(const Key: string; out Data: IInterface): Boolean;
    property Kind: TMarkdownNodeKind read GetKind;
    property Segment: TMarkdownSegment read GetSegment;
    property ChildCount: Integer read GetChildCount;
    property Children[const Index: Integer]: IMarkdownNode read GetChild;
  end;

  IMarkdownDocument = interface(IMarkdownNode)
    ['{062DDB3F-2AEE-451A-8C1C-54B883B25E18}']
  end;

  IMarkdownHeading = interface(IMarkdownNode)
    ['{8518DF63-F3C2-4D35-B2EA-544D893B4F2B}']
    function GetLevel: Integer;
    function GetSourceLine: Integer;
    property Level: Integer read GetLevel;
    property SourceLine: Integer read GetSourceLine;
  end;

  IMarkdownCodeBlock = interface(IMarkdownNode)
    ['{E38104F1-2DFC-44B5-99FB-744FC2C5C536}']
    function GetLiteral: string;
    function GetInfoString: string;
    function GetIsFenced: Boolean;
    property Literal: string read GetLiteral;
    property InfoString: string read GetInfoString;
    property IsFenced: Boolean read GetIsFenced;
  end;

  IMarkdownList = interface(IMarkdownNode)
    ['{0419B2A2-482B-44BC-BB4B-56FAA93207A4}']
    function GetIsOrdered: Boolean;
    function GetStartNumber: Integer;
    function GetIsTight: Boolean;
    property IsOrdered: Boolean read GetIsOrdered;
    property StartNumber: Integer read GetStartNumber;
    property IsTight: Boolean read GetIsTight;
  end;

  IMarkdownText = interface(IMarkdownNode)
    ['{626F4D3C-7658-480B-AD4D-26A14393FE07}']
    function GetLiteral: string;
    property Literal: string read GetLiteral;
  end;

  IMarkdownCustomInline = interface(IMarkdownNode)
    ['{5B7C9D5E-2A6F-4E0B-9C41-8F3D2B6A7C10}']
    function GetNodeName: string;
    property NodeName: string read GetNodeName;
  end;

  IMarkdownTableRow = interface(IMarkdownNode)
    ['{3C1F8E52-9B74-4A06-8D2E-51A0C7F4B9D3}']
    function GetIsHeader: Boolean;
    property IsHeader: Boolean read GetIsHeader;
  end;

  IMarkdownTableCell = interface(IMarkdownNode)
    ['{A47D2B90-6E15-4F38-B8C2-0D9E63A1F7C4}']
    function GetAlignment: TMarkdownTableColumnAlignment;
    property Alignment: TMarkdownTableColumnAlignment read GetAlignment;
  end;

  IMarkdownLink = interface(IMarkdownNode)
    ['{DC2CCCFD-FF90-4D31-945A-69E547FCA38E}']
    function GetDestination: string;
    function GetTitle: string;
    property Destination: string read GetDestination;
    property Title: string read GetTitle;
  end;

  IMarkdownVisitor = interface
    ['{B5CA32F0-4236-4AAA-845B-6C4F94D3E52E}']
    procedure VisitDocument(const Node: IMarkdownDocument);
    procedure VisitParagraph(const Node: IMarkdownNode);
    procedure VisitHeading(const Node: IMarkdownHeading);
    procedure VisitThematicBreak(const Node: IMarkdownNode);
    procedure VisitCodeBlock(const Node: IMarkdownCodeBlock);
    procedure VisitBlockQuote(const Node: IMarkdownNode);
    procedure VisitList(const Node: IMarkdownList);
    procedure VisitListItem(const Node: IMarkdownNode);
    procedure VisitHtmlBlock(const Node: IMarkdownText);
    procedure VisitText(const Node: IMarkdownText);
    procedure VisitEmphasis(const Node: IMarkdownNode);
    procedure VisitStrong(const Node: IMarkdownNode);
    procedure VisitCodeSpan(const Node: IMarkdownText);
    procedure VisitLink(const Node: IMarkdownLink);
    procedure VisitImage(const Node: IMarkdownLink);
    procedure VisitAutolink(const Node: IMarkdownLink);
    procedure VisitSoftLineBreak(const Node: IMarkdownNode);
    procedure VisitHardLineBreak(const Node: IMarkdownNode);
    procedure VisitInlineHtml(const Node: IMarkdownText);
    procedure VisitCustomInline(const Node: IMarkdownCustomInline);
    procedure VisitTable(const Node: IMarkdownNode);
    procedure VisitTableRow(const Node: IMarkdownTableRow);
    procedure VisitTableCell(const Node: IMarkdownTableCell);
  end;

implementation

class function TMarkdownSegment.Create(const StartOffset, EndOffset: Integer): TMarkdownSegment;
begin
  Result.StartOffset := StartOffset;
  Result.EndOffset := EndOffset;
end;

function TMarkdownSegment.Length: Integer;
begin
  Result := EndOffset - StartOffset;
end;

end.
