unit Markdown4D.Parser.StagingBlock;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Parser.HtmlBlocks;

type
  TListData = record
    IsOrdered: Boolean;
    BulletChar: Char;
    Delimiter: Char;
    StartNumber: Integer;
    IsTight: Boolean;
    MarkerOffset: Integer;
    Padding: Integer;
    function MatchesKind(const Other: TListData): Boolean;
  end;

  TStagingBlock = class
  private
    FKind: TMarkdownNodeKind;
    FParent: TStagingBlock;
    FChildren: TObjectList<TStagingBlock>;
    FIsOpen: Boolean;
    FContent: TStringBuilder;
    FLiteral: string;
    FInfoString: string;
    FHeadingLevel: Integer;
    FIsFenced: Boolean;
    FFenceChar: Char;
    FFenceLength: Integer;
    FFenceOffset: Integer;
    FHtmlKind: THtmlBlockKind;
    FListData: TListData;
    FTableAlignments: TArray<TMarkdownTableColumnAlignment>;
    FLastLineBlank: Boolean;
    FEndsWithBlankLine: Boolean;
    FHadStrippedReferences: Boolean;
    FStartLine: Integer;
    FStartOffset: Integer;
    FEndOffset: Integer;
    procedure FreeDescendantsIteratively;
    procedure MoveChildrenTo(const Pending: TStack<TStagingBlock>);
    procedure SetLastLineBlank(const Value: Boolean);

  public
    constructor Create(const Kind: TMarkdownNodeKind; const Parent: TStagingBlock);
    destructor Destroy; override;
    function LastChild: TStagingBlock;
    property Kind: TMarkdownNodeKind read FKind write FKind;
    property Parent: TStagingBlock read FParent;
    property Children: TObjectList<TStagingBlock> read FChildren;
    property IsOpen: Boolean read FIsOpen write FIsOpen;
    property Content: TStringBuilder read FContent;
    property Literal: string read FLiteral write FLiteral;
    property InfoString: string read FInfoString write FInfoString;
    property HeadingLevel: Integer read FHeadingLevel write FHeadingLevel;
    property IsFenced: Boolean read FIsFenced write FIsFenced;
    property FenceChar: Char read FFenceChar write FFenceChar;
    property FenceLength: Integer read FFenceLength write FFenceLength;
    property FenceOffset: Integer read FFenceOffset write FFenceOffset;
    property HtmlKind: THtmlBlockKind read FHtmlKind write FHtmlKind;
    property ListData: TListData read FListData write FListData;
    property TableAlignments: TArray<TMarkdownTableColumnAlignment> read FTableAlignments write FTableAlignments;
    property LastLineBlank: Boolean read FLastLineBlank write SetLastLineBlank;
    // Whether this block, or the innermost list level underneath it, ended on a
    // blank line. Held as a value rather than answered by walking down the
    // last-child chain: a document nesting thousands of lists would otherwise
    // make the loose-list check quadratic. TBlockParser refreshes it when a
    // block is finalized, by which time its children are already final.
    property EndsWithBlankLine: Boolean read FEndsWithBlankLine write FEndsWithBlankLine;
    property HadStrippedReferences: Boolean read FHadStrippedReferences write FHadStrippedReferences;
    property StartLine: Integer read FStartLine write FStartLine;
    property StartOffset: Integer read FStartOffset write FStartOffset;
    property EndOffset: Integer read FEndOffset write FEndOffset;
  end;

implementation

function TListData.MatchesKind(const Other: TListData): Boolean;
begin
  Result := (IsOrdered = Other.IsOrdered) and (BulletChar = Other.BulletChar) and (Delimiter = Other.Delimiter);
end;

constructor TStagingBlock.Create(const Kind: TMarkdownNodeKind; const Parent: TStagingBlock);
begin
  inherited Create;

  FKind := Kind;
  FParent := Parent;
  FChildren := TObjectList<TStagingBlock>.Create(True);
  FContent := TStringBuilder.Create;
  FIsOpen := True;
end;

destructor TStagingBlock.Destroy;
begin
  FreeDescendantsIteratively;

  FContent.Free;
  FChildren.Free;

  inherited Destroy;
end;

function TStagingBlock.LastChild: TStagingBlock;
begin
  if FChildren.Count = 0 then
    Exit(nil);

  Result := FChildren[FChildren.Count - 1];
end;

procedure TStagingBlock.SetLastLineBlank(const Value: Boolean);
begin
  FLastLineBlank := Value;

  // A block ending on a blank line ends on a blank line whatever its children
  // say, so this stays right even for a block that was already finalized.
  if Value then
    FEndsWithBlankLine := True;
end;

procedure TStagingBlock.FreeDescendantsIteratively;
begin
  const HasChildren = (FChildren <> nil) and (FChildren.Count > 0);
  if not HasChildren then
    Exit;

  const Pending = TStack<TStagingBlock>.Create;
  try
    MoveChildrenTo(Pending);

    while Pending.Count > 0 do
    begin
      const Current = Pending.Pop;
      Current.MoveChildrenTo(Pending);
      Current.Free;
    end;
  finally
    Pending.Free;
  end;
end;

procedure TStagingBlock.MoveChildrenTo(const Pending: TStack<TStagingBlock>);
begin
  for var Index := FChildren.Count - 1 downto 0 do
  begin
    Pending.Push(FChildren.ExtractAt(Index));
  end;
end;

end.
