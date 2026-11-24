unit Markdown4D.Layout.NestedScope;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces;

type
  // A block override can lay out documents of its own, and the <details>
  // sections in those need keys of their own. The keys of such a document get
  // a scope made of the scope of the document around it, the place of the
  // block that lays it out, and which of that block's documents it is.
  //
  // A block's place is its kind (its node kind, and its info string for a
  // code block) and which block of that kind it is. The content of an HTML
  // block, or of a <details> section written as one, is a document parsed
  // apart; its blocks are counted on their own, under the place of that HTML
  // block. Text typed inside or around a block keeps its place; a block of the
  // same kind added or removed before it, or before its HTML block, changes it.
  TMarkdownNestedScopes = class
  private
    type
      TPlace = record
        Text: string;
        // The HTML block whose content holds the block; nil for a block of
        // the document itself.
        Owner: IMarkdownNode;
        // The child of the document that holds the block.
        TopLevelBlock: IMarkdownNode;
      end;

      THtmlDocument = record
        Owner: IMarkdownNode;
        Name: string;
        Document: IMarkdownNode;
      end;

      TWalkedBlock = record
        Node: IMarkdownNode;
        TopLevelIndex: Integer;
      end;

      // Numbers the blocks of each kind in the order they come.
      TKindCounter = class
      private
        FKinds: TDictionary<TMarkdownNodeKind, Integer>;
        FInfoStrings: TDictionary<string, Integer>;

      public
        constructor Create;
        destructor Destroy; override;
        function Next(const Block: IMarkdownNode): Integer;
      end;
    const
      PlaceDataName = 'markdown4d.nested-scope.place';
      HostsDataName = 'markdown4d.nested-scope.hosts';
    var
      FDocument: IMarkdownNode;
      FScope: string;
      FPlaces: TDictionary<TObject, TPlace>;
      FHtmlDocuments: TList<THtmlDocument>;
    function PlaceOf(const Block: IMarkdownNode): TPlace;
    procedure RecordPlace(const Block: IMarkdownNode; const Place: TPlace);
    procedure IndexPlaces;
    procedure IndexHtmlDocument(const HtmlDocument: THtmlDocument);
    procedure IndexBlocks(const Document: IMarkdownNode; const Prefix: string; const Owner,
      TopLevelBlock: IMarkdownNode);
    class function WalkedBlocks(const Document: IMarkdownNode): TArray<TWalkedBlock>; static;
    class procedure CollectBlock(const Block: IMarkdownNode; const TopLevelIndex: Integer;
      const Blocks: TList<TWalkedBlock>); static;
    class function PlaceText(const Prefix: string; const Block: IMarkdownNode;
      const Occurrence: Integer): string; static;
    class function KindOf(const Block: IMarkdownNode): string; static;
    class function Escaped(const Text: string): string; static;
    class function TryGetRecordedPlace(const Block: IMarkdownNode; out Place: string): Boolean; static;

  public
    // Whether a child of Document from FirstIndex on holds a block that laid
    // out a document of its own; only then can LastMovedHostBlock find one.
    class function HoldsHostsFrom(const Document: IMarkdownNode; const FirstIndex: Integer): Boolean; static;
    // The index of the last block of Document that holds a block whose
    // documents were laid out at another place than the one it has now; -1
    // when there is none.
    class function LastMovedHostBlock(const Document: IMarkdownNode): Integer; static;
    // Scope is the scope of the keys of Document itself.
    constructor Create(const Document: IMarkdownNode; const Scope: string);
    destructor Destroy; override;
    // Gives the blocks of Document, the content Owner holds under Name, places
    // under the place of Owner.
    procedure AddHtmlDocument(const Owner: IMarkdownNode; const Name: string; const Document: IMarkdownNode);
    // The scope for the keys of the Sequence-th document that Host lays out.
    // Host, and the HTML blocks around it, keep their places for
    // LastMovedHostBlock. Host is a block of the document or of a document
    // added with AddHtmlDocument; any other block raises EMarkdownError.
    function RecordNestedScope(const Host: IMarkdownNode; const Sequence: Integer): string;
    property Scope: string read FScope;
  end;

implementation

uses
  System.SysUtils,
  System.TypInfo,
  Markdown4D.Defines,
  Markdown4D.Layout.Disclosure;

type
  IRecordedPlace = interface
    ['{3C8E5A71-6B2D-4E19-9F47-A1D0C5B83E26}']
    function Value: string;
  end;

  TRecordedPlace = class(TInterfacedObject, IRecordedPlace)
  private
    FValue: string;

  public
    constructor Create(const Value: string);
    function Value: string;
  end;

constructor TRecordedPlace.Create(const Value: string);
begin
  inherited Create;
  FValue := Value;
end;

function TRecordedPlace.Value: string;
begin
  Result := FValue;
end;

constructor TMarkdownNestedScopes.TKindCounter.Create;
begin
  inherited Create;

  FKinds       := TDictionary<TMarkdownNodeKind, Integer>.Create;
  FInfoStrings := TDictionary<string, Integer>.Create;
end;

destructor TMarkdownNestedScopes.TKindCounter.Destroy;
begin
  FInfoStrings.Free;
  FKinds.Free;

  inherited Destroy;
end;

// Code blocks are counted per info string, the other blocks per node kind.
function TMarkdownNestedScopes.TKindCounter.Next(const Block: IMarkdownNode): Integer;
begin
  Result := 0;

  var Code: IMarkdownCodeBlock;
  if Supports(Block, IMarkdownCodeBlock, Code) then
  begin
    FInfoStrings.TryGetValue(Code.InfoString, Result);
    Inc(Result);
    FInfoStrings.AddOrSetValue(Code.InfoString, Result);
  end
  else
  begin
    FKinds.TryGetValue(Block.Kind, Result);
    Inc(Result);
    FKinds.AddOrSetValue(Block.Kind, Result);
  end;
end;

class function TMarkdownNestedScopes.HoldsHostsFrom(const Document: IMarkdownNode; const FirstIndex: Integer): Boolean;
begin
  for var Index := FirstIndex to Document.ChildCount - 1 do
  begin
    var Marker: IInterface;
    if Document.Children[Index].TryGetExtensionData(HostsDataName, Marker) then
      Exit(True);
  end;

  Result := False;
end;

// Only the document's own blocks are walked: a block in the content of an
// HTML block records its place on that HTML block as well.
class function TMarkdownNestedScopes.LastMovedHostBlock(const Document: IMarkdownNode): Integer;
begin
  Result := -1;

  const Counter = TKindCounter.Create;
  try
    for var Block in WalkedBlocks(Document) do
    begin
      const Occurrence = Counter.Next(Block.Node);

      var Recorded: string;
      if not TryGetRecordedPlace(Block.Node, Recorded) then
        Continue;

      const HasMoved = (Recorded <> PlaceText('', Block.Node, Occurrence));
      if HasMoved then
        Result := Block.TopLevelIndex;
    end;
  finally
    Counter.Free;
  end;
end;

constructor TMarkdownNestedScopes.Create(const Document: IMarkdownNode; const Scope: string);
begin
  inherited Create;

  FDocument      := Document;
  FScope         := Scope;
  FHtmlDocuments := TList<THtmlDocument>.Create;
end;

destructor TMarkdownNestedScopes.Destroy;
begin
  FHtmlDocuments.Free;
  FPlaces.Free;

  inherited Destroy;
end;

// The places are counted when the first block asks for one, so a layout in
// which no block lays out a document of its own counts nothing.
procedure TMarkdownNestedScopes.AddHtmlDocument(const Owner: IMarkdownNode; const Name: string;
  const Document: IMarkdownNode);
begin
  var HtmlDocument := Default(THtmlDocument);
  HtmlDocument.Owner    := Owner;
  HtmlDocument.Name     := Name;
  HtmlDocument.Document := Document;
  FHtmlDocuments.Add(HtmlDocument);

  if FPlaces <> nil then
    IndexHtmlDocument(HtmlDocument);
end;

function TMarkdownNestedScopes.RecordNestedScope(const Host: IMarkdownNode; const Sequence: Integer): string;
begin
  const Place = PlaceOf(Host);
  RecordPlace(Host, Place);

  const Marker: IRecordedPlace = TRecordedPlace.Create(FScope);
  Place.TopLevelBlock.SetExtensionData(HostsDataName, Marker);

  Result := Format('%s%s.%d/', [FScope, Place.Text, Sequence]);
end;

// The layout pushes a block only from the document, from a block quote, list
// or list item in it, or from a document added with AddHtmlDocument, and all
// of those are indexed; another block is a mistake in the layout.
function TMarkdownNestedScopes.PlaceOf(const Block: IMarkdownNode): TPlace;
begin
  if FPlaces = nil then
    IndexPlaces;

  if not FPlaces.TryGetValue(Block as TObject, Result) then
    raise EMarkdownError.CreateFmt('No place for a %s block outside the documents of this layout',
      [KindOf(Block)]);
end;

procedure TMarkdownNestedScopes.RecordPlace(const Block: IMarkdownNode; const Place: TPlace);
begin
  const Recorded: IRecordedPlace = TRecordedPlace.Create(Place.Text);
  Block.SetExtensionData(PlaceDataName, Recorded);

  if Place.Owner <> nil then
    RecordPlace(Place.Owner, PlaceOf(Place.Owner));
end;

procedure TMarkdownNestedScopes.IndexPlaces;
begin
  FPlaces := TDictionary<TObject, TPlace>.Create;
  IndexBlocks(FDocument, '', nil, nil);

  for var HtmlDocument in FHtmlDocuments do
  begin
    IndexHtmlDocument(HtmlDocument);
  end;
end;

procedure TMarkdownNestedScopes.IndexHtmlDocument(const HtmlDocument: THtmlDocument);
begin
  const OwnerPlace = PlaceOf(HtmlDocument.Owner);
  const Prefix = Format('%s>%s>', [OwnerPlace.Text, Escaped(HtmlDocument.Name)]);
  IndexBlocks(HtmlDocument.Document, Prefix, HtmlDocument.Owner, OwnerPlace.TopLevelBlock);
end;

// TopLevelBlock is the child of the layout's document that holds Document;
// nil when Document is that document itself.
procedure TMarkdownNestedScopes.IndexBlocks(const Document: IMarkdownNode; const Prefix: string; const Owner,
  TopLevelBlock: IMarkdownNode);
begin
  const Counter = TKindCounter.Create;
  try
    for var Block in WalkedBlocks(Document) do
    begin
      const Occurrence = Counter.Next(Block.Node);

      var Place := Default(TPlace);
      Place.Text          := PlaceText(Prefix, Block.Node, Occurrence);
      Place.Owner         := Owner;
      Place.TopLevelBlock := TopLevelBlock;
      if TopLevelBlock = nil then
        Place.TopLevelBlock := Document.Children[Block.TopLevelIndex];

      FPlaces.AddOrSetValue(Block.Node as TObject, Place);
    end;
  finally
    Counter.Free;
  end;
end;

// The blocks a block override can lay out, in document order: the children of
// Document, each followed by the blocks of the block quotes, lists and list
// items in it.
class function TMarkdownNestedScopes.WalkedBlocks(const Document: IMarkdownNode): TArray<TWalkedBlock>;
begin
  const Blocks = TList<TWalkedBlock>.Create;
  try
    for var Index := 0 to Document.ChildCount - 1 do
    begin
      CollectBlock(Document.Children[Index], Index, Blocks);
    end;

    Result := Blocks.ToArray;
  finally
    Blocks.Free;
  end;
end;

class procedure TMarkdownNestedScopes.CollectBlock(const Block: IMarkdownNode; const TopLevelIndex: Integer;
  const Blocks: TList<TWalkedBlock>);
begin
  var Walked := Default(TWalkedBlock);
  Walked.Node          := Block;
  Walked.TopLevelIndex := TopLevelIndex;
  Blocks.Add(Walked);

  if not TMarkdownDisclosures.IsContainer(Block) then
    Exit;

  for var Index := 0 to Block.ChildCount - 1 do
  begin
    CollectBlock(Block.Children[Index], TopLevelIndex, Blocks);
  end;
end;

class function TMarkdownNestedScopes.PlaceText(const Prefix: string; const Block: IMarkdownNode;
  const Occurrence: Integer): string;
begin
  Result := Format('%s%s#%d', [Prefix, KindOf(Block), Occurrence]);
end;

class function TMarkdownNestedScopes.KindOf(const Block: IMarkdownNode): string;
begin
  const KindName = GetEnumName(TypeInfo(TMarkdownNodeKind), Ord(Block.Kind));

  var Code: IMarkdownCodeBlock;
  if not Supports(Block, IMarkdownCodeBlock, Code) then
    Exit(KindName);

  Result := Format('%s:%s', [KindName, Escaped(Code.InfoString)]);
end;

// The characters that separate the parts of a scope, so an info string cannot
// make one scope read as another.
class function TMarkdownNestedScopes.Escaped(const Text: string): string;
begin
  Result := Text.Replace('%', '%25', [rfReplaceAll]);
  Result := Result.Replace('#', '%23', [rfReplaceAll]);
  Result := Result.Replace('.', '%2E', [rfReplaceAll]);
  Result := Result.Replace('/', '%2F', [rfReplaceAll]);
  Result := Result.Replace('>', '%3E', [rfReplaceAll]);
end;

class function TMarkdownNestedScopes.TryGetRecordedPlace(const Block: IMarkdownNode; out Place: string): Boolean;
begin
  Place := '';

  var Stored: IInterface;
  var Recorded: IRecordedPlace;
  Result := (Block.TryGetExtensionData(PlaceDataName, Stored) and Supports(Stored, IRecordedPlace, Recorded));
  if Result then
    Place := Recorded.Value;
end;

end.
