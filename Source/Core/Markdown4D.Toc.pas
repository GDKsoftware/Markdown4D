unit Markdown4D.Toc;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces;

type
  IMarkdownTocEntry = interface
    ['{9A208737-00DA-409D-8D0F-4471A92ED548}']
    function GetCaption: string;
    function GetLevel: Integer;
    function GetAnchor: string;
    function GetSourceLine: Integer;
    function GetChildCount: Integer;
    function GetChild(const Index: Integer): IMarkdownTocEntry;
    property Caption: string read GetCaption;
    property Level: Integer read GetLevel;
    property Anchor: string read GetAnchor;
    property SourceLine: Integer read GetSourceLine;
    property ChildCount: Integer read GetChildCount;
    property Children[const Index: Integer]: IMarkdownTocEntry read GetChild;
  end;

  IMarkdownToc = interface
    ['{FD266CFD-7347-4ABF-8A2F-3F1900D22AF0}']
    function GetEntryCount: Integer;
    function GetEntry(const Index: Integer): IMarkdownTocEntry;
    function GetEnumerator: TEnumerator<IMarkdownTocEntry>;
    property EntryCount: Integer read GetEntryCount;
    property Entries[const Index: Integer]: IMarkdownTocEntry read GetEntry;
  end;

  TMarkdownToc = class
  public
    class function FromDocument(const Document: IMarkdownDocument): IMarkdownToc;
  end;

implementation

uses
  System.SysUtils,
  System.Character;

type
  TMarkdownTocEntry = class(TInterfacedObject, IMarkdownTocEntry)
  private
    FCaption: string;
    FLevel: Integer;
    FAnchor: string;
    FSourceLine: Integer;
    FChildren: TList<IMarkdownTocEntry>;

  public
    constructor Create(const Caption, Anchor: string; const Level, SourceLine: Integer);
    destructor Destroy; override;
    function GetCaption: string;
    function GetLevel: Integer;
    function GetAnchor: string;
    function GetSourceLine: Integer;
    function GetChildCount: Integer;
    function GetChild(const Index: Integer): IMarkdownTocEntry;
    procedure AddChild(const Child: IMarkdownTocEntry);
    property Level: Integer read FLevel;
  end;

  TMarkdownTocInstance = class(TInterfacedObject, IMarkdownToc)
  private
    FEntries: TList<IMarkdownTocEntry>;

  public
    constructor Create;
    destructor Destroy; override;
    function GetEntryCount: Integer;
    function GetEntry(const Index: Integer): IMarkdownTocEntry;
    function GetEnumerator: TEnumerator<IMarkdownTocEntry>;
    procedure AddEntry(const Entry: IMarkdownTocEntry);
  end;

  TMarkdownTocBuilder = class
  private
    const
      CaptionSeparator = ' ';
      AnchorDash = '-';
      AnchorSuffixFormat = '%s-%d';
    var
      FToc: TMarkdownTocInstance;
      FOpenEntries: TList<TMarkdownTocEntry>;
      FAnchorUsage: TDictionary<string, Integer>;
    procedure CollectHeadings(const Document: IMarkdownDocument);
    procedure AddHeading(const Heading: IMarkdownHeading);
    class function ExtractCaption(const Heading: IMarkdownNode): string;
    function ReserveAnchor(const Caption: string): string;
    class function Slugify(const Caption: string): string;
    class procedure PushChildrenReversed(const Pending: TStack<IMarkdownNode>; const Node: IMarkdownNode);

  public
    constructor Create;
    destructor Destroy; override;
    function Build(const Document: IMarkdownDocument): IMarkdownToc;
  end;

class function TMarkdownToc.FromDocument(const Document: IMarkdownDocument): IMarkdownToc;
begin
  if Document = nil then
    raise EArgumentNilException.Create('Document must not be nil');

  const Builder = TMarkdownTocBuilder.Create;
  try
    Result := Builder.Build(Document);
  finally
    Builder.Free;
  end;
end;

constructor TMarkdownTocBuilder.Create;
begin
  inherited Create;

  FOpenEntries := TList<TMarkdownTocEntry>.Create;
  FAnchorUsage := TDictionary<string, Integer>.Create;
end;

destructor TMarkdownTocBuilder.Destroy;
begin
  FAnchorUsage.Free;
  FOpenEntries.Free;

  inherited Destroy;
end;

function TMarkdownTocBuilder.Build(const Document: IMarkdownDocument): IMarkdownToc;
begin
  const Toc = TMarkdownTocInstance.Create;
  Result := Toc;
  FToc := Toc;

  CollectHeadings(Document);
end;

procedure TMarkdownTocBuilder.CollectHeadings(const Document: IMarkdownDocument);
begin
  const Pending = TStack<IMarkdownNode>.Create;
  try
    PushChildrenReversed(Pending, Document);

    while Pending.Count > 0 do
    begin
      const Current = Pending.Pop;

      if Current.Kind = TMarkdownNodeKind.Heading then
        AddHeading(Current as IMarkdownHeading)
      else
        PushChildrenReversed(Pending, Current);
    end;
  finally
    Pending.Free;
  end;
end;

procedure TMarkdownTocBuilder.AddHeading(const Heading: IMarkdownHeading);
begin
  const Caption = ExtractCaption(Heading);
  const Anchor = ReserveAnchor(Caption);
  const Entry = TMarkdownTocEntry.Create(Caption, Anchor, Heading.Level, Heading.SourceLine);
  const Added: IMarkdownTocEntry = Entry;

  while (FOpenEntries.Count > 0) and (FOpenEntries.Last.Level >= Heading.Level) do
  begin
    FOpenEntries.Delete(FOpenEntries.Count - 1);
  end;

  if FOpenEntries.Count = 0 then
    FToc.AddEntry(Added)
  else
    FOpenEntries.Last.AddChild(Added);

  FOpenEntries.Add(Entry);
end;

class function TMarkdownTocBuilder.ExtractCaption(const Heading: IMarkdownNode): string;
begin
  const CaptionText = TStringBuilder.Create;
  const Pending = TStack<IMarkdownNode>.Create;
  try
    PushChildrenReversed(Pending, Heading);

    while Pending.Count > 0 do
    begin
      const Current = Pending.Pop;

      case Current.Kind of
        TMarkdownNodeKind.Text, TMarkdownNodeKind.CodeSpan:
          CaptionText.Append((Current as IMarkdownText).Literal);
        TMarkdownNodeKind.SoftLineBreak, TMarkdownNodeKind.HardLineBreak:
          CaptionText.Append(CaptionSeparator);
      else
        PushChildrenReversed(Pending, Current);
      end;
    end;

    Result := CaptionText.ToString;
  finally
    Pending.Free;
    CaptionText.Free;
  end;
end;

function TMarkdownTocBuilder.ReserveAnchor(const Caption: string): string;
begin
  const Anchor = Slugify(Caption);

  var UsedCount: Integer;
  if not FAnchorUsage.TryGetValue(Anchor, UsedCount) then
    UsedCount := 0;
  FAnchorUsage.AddOrSetValue(Anchor, UsedCount + 1);

  if UsedCount = 0 then
    Exit(Anchor);

  Result := Format(AnchorSuffixFormat, [Anchor, UsedCount]);
end;

class function TMarkdownTocBuilder.Slugify(const Caption: string): string;
begin
  const Slug = TStringBuilder.Create;
  try
    for var CaptionChar in Caption.ToLower do
    begin
      const KeepsCharacter = CaptionChar.IsLetterOrDigit or (CaptionChar = '_');
      const BecomesDash = (CaptionChar = CaptionSeparator) or (CaptionChar = AnchorDash);

      if KeepsCharacter then
        Slug.Append(CaptionChar)
      else if BecomesDash then
        Slug.Append(AnchorDash);
    end;

    Result := Slug.ToString;
  finally
    Slug.Free;
  end;
end;

class procedure TMarkdownTocBuilder.PushChildrenReversed(const Pending: TStack<IMarkdownNode>;
                                                         const Node: IMarkdownNode);
begin
  for var Index := Node.ChildCount - 1 downto 0 do
  begin
    Pending.Push(Node.Children[Index]);
  end;
end;

constructor TMarkdownTocEntry.Create(const Caption, Anchor: string; const Level, SourceLine: Integer);
begin
  inherited Create;

  FCaption := Caption;
  FAnchor := Anchor;
  FLevel := Level;
  FSourceLine := SourceLine;
  FChildren := TList<IMarkdownTocEntry>.Create;
end;

destructor TMarkdownTocEntry.Destroy;
begin
  FChildren.Free;

  inherited Destroy;
end;

function TMarkdownTocEntry.GetCaption: string;
begin
  Result := FCaption;
end;

function TMarkdownTocEntry.GetLevel: Integer;
begin
  Result := FLevel;
end;

function TMarkdownTocEntry.GetAnchor: string;
begin
  Result := FAnchor;
end;

function TMarkdownTocEntry.GetSourceLine: Integer;
begin
  Result := FSourceLine;
end;

function TMarkdownTocEntry.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TMarkdownTocEntry.GetChild(const Index: Integer): IMarkdownTocEntry;
begin
  Result := FChildren[Index];
end;

procedure TMarkdownTocEntry.AddChild(const Child: IMarkdownTocEntry);
begin
  FChildren.Add(Child);
end;

constructor TMarkdownTocInstance.Create;
begin
  inherited Create;

  FEntries := TList<IMarkdownTocEntry>.Create;
end;

destructor TMarkdownTocInstance.Destroy;
begin
  FEntries.Free;

  inherited Destroy;
end;

function TMarkdownTocInstance.GetEntryCount: Integer;
begin
  Result := FEntries.Count;
end;

function TMarkdownTocInstance.GetEntry(const Index: Integer): IMarkdownTocEntry;
begin
  Result := FEntries[Index];
end;

function TMarkdownTocInstance.GetEnumerator: TEnumerator<IMarkdownTocEntry>;
begin
  Result := FEntries.GetEnumerator;
end;

procedure TMarkdownTocInstance.AddEntry(const Entry: IMarkdownTocEntry);
begin
  FEntries.Add(Entry);
end;

end.
