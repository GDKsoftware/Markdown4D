unit Markdown4D.Extensions.Alerts;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces;

type
  TMarkdownAlertKind = (Note, Tip, Important, Warning, Caution);

  // The tag a block quote carries once it turned out to be an alert.
  IMarkdownAlert = interface
    ['{C6E1F4A2-3B57-4D98-8E0C-9A2F6B1D7E45}']
    function GetKind: TMarkdownAlertKind;
    property Kind: TMarkdownAlertKind read GetKind;
  end;

  TMarkdownAlertKindHelper = record helper for TMarkdownAlertKind
    // The name between the brackets of the marker, such as NOTE.
    function MarkerName: string;
    // The heading shown above the alert, such as Note.
    function Title: string;
    // The lower-case name GitHub uses in its class names, such as note.
    function CssName: string;
  end;

  TMarkdownAlerts = class
  public
    const
      ExtensionDataKey = 'markdown4d.alert';
    class function TryGetKind(const Node: IMarkdownNode; out Kind: TMarkdownAlertKind): Boolean; static;
  end;

  // GitHub alerts: a block quote at the top level of the document whose first
  // line is [!NOTE], [!TIP], [!IMPORTANT], [!WARNING] or [!CAUTION]. The
  // marker line is taken out of the quote and the quote is tagged with the
  // kind, so the renderers draw it as an alert and the text stays as written.
  TAlertExtension = class(TInterfacedObject, IMarkdownExtension)
  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Ast;

type
  TMarkdownAlert = class(TInterfacedObject, IMarkdownAlert)
  private
    FKind: TMarkdownAlertKind;

  public
    constructor Create(const Kind: TMarkdownAlertKind);
    function GetKind: TMarkdownAlertKind;
  end;

  TAlertDocumentProcessor = class(TInterfacedObject, IMarkdownDocumentProcessor)
  private
    const
      MarkerOpen = '[!';
      MarkerClose = ']';
    class procedure TagIfAlert(const BlockQuote: IMarkdownNode); static;
    class function TryReadMarker(const Paragraph: IMarkdownNode; out Kind: TMarkdownAlertKind;
      out MarkerNodeCount: Integer): Boolean; static;
    class function TryParseMarker(const Text: string; out Kind: TMarkdownAlertKind): Boolean; static;
    class function IsLineBreak(const Node: IMarkdownNode): Boolean; static;
    class procedure RemoveMarker(const BlockQuote, Paragraph: IMarkdownNode; const MarkerNodeCount: Integer); static;

  public
    procedure Process(const Document: IMarkdownDocument);
  end;

function TMarkdownAlertKindHelper.MarkerName: string;
begin
  case Self of
    TMarkdownAlertKind.Note      : Result := 'NOTE';
    TMarkdownAlertKind.Tip       : Result := 'TIP';
    TMarkdownAlertKind.Important : Result := 'IMPORTANT';
    TMarkdownAlertKind.Warning   : Result := 'WARNING';
    TMarkdownAlertKind.Caution   : Result := 'CAUTION';
  else
    raise ENotSupportedException.CreateFmt('Unsupported alert kind: %d', [Ord(Self)]);
  end;
end;

function TMarkdownAlertKindHelper.Title: string;
begin
  case Self of
    TMarkdownAlertKind.Note      : Result := 'Note';
    TMarkdownAlertKind.Tip       : Result := 'Tip';
    TMarkdownAlertKind.Important : Result := 'Important';
    TMarkdownAlertKind.Warning   : Result := 'Warning';
    TMarkdownAlertKind.Caution   : Result := 'Caution';
  else
    raise ENotSupportedException.CreateFmt('Unsupported alert kind: %d', [Ord(Self)]);
  end;
end;

function TMarkdownAlertKindHelper.CssName: string;
begin
  Result := MarkerName.ToLower;
end;

class function TMarkdownAlerts.TryGetKind(const Node: IMarkdownNode; out Kind: TMarkdownAlertKind): Boolean;
begin
  Kind := TMarkdownAlertKind.Note;

  var Data: IInterface;
  var Alert: IMarkdownAlert;
  Result := (Node.TryGetExtensionData(ExtensionDataKey, Data) and Supports(Data, IMarkdownAlert, Alert));
  if Result then
    Kind := Alert.Kind;
end;

procedure TAlertExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterDocumentProcessor(TAlertDocumentProcessor.Create, TMarkdownPriorities.ExtensionProcessor);
end;

constructor TMarkdownAlert.Create(const Kind: TMarkdownAlertKind);
begin
  inherited Create;

  FKind := Kind;
end;

function TMarkdownAlert.GetKind: TMarkdownAlertKind;
begin
  Result := FKind;
end;

// Only quotes at the top level become alerts, as on GitHub: a quote inside a
// list or another quote keeps its marker as text.
procedure TAlertDocumentProcessor.Process(const Document: IMarkdownDocument);
begin
  for var Index := 0 to Document.ChildCount - 1 do
  begin
    const Child = Document.Children[Index];
    const IsBlockQuote = (Child.Kind = TMarkdownNodeKind.BlockQuote);
    if IsBlockQuote then
      TagIfAlert(Child);
  end;
end;

class procedure TAlertDocumentProcessor.TagIfAlert(const BlockQuote: IMarkdownNode);
begin
  if BlockQuote.ChildCount = 0 then
    Exit;

  const Paragraph = BlockQuote.Children[0];
  if Paragraph.Kind <> TMarkdownNodeKind.Paragraph then
    Exit;

  const CanRemoveMarker = ((BlockQuote is TMarkdownAstNode) and (Paragraph is TMarkdownAstNode));
  if not CanRemoveMarker then
    Exit;

  var Kind: TMarkdownAlertKind;
  var MarkerNodeCount: Integer;
  if not TryReadMarker(Paragraph, Kind, MarkerNodeCount) then
    Exit;

  RemoveMarker(BlockQuote, Paragraph, MarkerNodeCount);
  BlockQuote.SetExtensionData(TMarkdownAlerts.ExtensionDataKey, TMarkdownAlert.Create(Kind));
end;

// The marker is the whole first line of the paragraph. The inline parser may
// split it over several text nodes ("[", "!NOTE", "]"), so the text nodes up
// to the first line break are read together. Anything else on that line,
// such as emphasis, means the line is not a marker.
class function TAlertDocumentProcessor.TryReadMarker(const Paragraph: IMarkdownNode; out Kind: TMarkdownAlertKind;
  out MarkerNodeCount: Integer): Boolean;
begin
  Kind := TMarkdownAlertKind.Note;
  MarkerNodeCount := 0;

  var Line := '';
  for var Index := 0 to Paragraph.ChildCount - 1 do
  begin
    const Child = Paragraph.Children[Index];
    if IsLineBreak(Child) then
      Break;

    var Text: IMarkdownText;
    const IsText = (Child.Kind = TMarkdownNodeKind.Text) and Supports(Child, IMarkdownText, Text);
    if not IsText then
      Exit(False);

    Line := Line + Text.Literal;
    Inc(MarkerNodeCount);
  end;

  Result := TryParseMarker(Line, Kind);
end;

class function TAlertDocumentProcessor.TryParseMarker(const Text: string; out Kind: TMarkdownAlertKind): Boolean;
begin
  Kind := TMarkdownAlertKind.Note;

  const Trimmed = Text.Trim;
  const HasBrackets = (Trimmed.StartsWith(MarkerOpen) and Trimmed.EndsWith(MarkerClose));
  if not HasBrackets then
    Exit(False);

  const NameLength = Length(Trimmed) - Length(MarkerOpen) - Length(MarkerClose);
  const Name = Trimmed.Substring(Length(MarkerOpen), NameLength);

  for var Candidate := Low(TMarkdownAlertKind) to High(TMarkdownAlertKind) do
  begin
    if SameText(Candidate.MarkerName, Name) then
    begin
      Kind := Candidate;
      Exit(True);
    end;
  end;

  Result := False;
end;

class function TAlertDocumentProcessor.IsLineBreak(const Node: IMarkdownNode): Boolean;
begin
  Result := (Node.Kind = TMarkdownNodeKind.SoftLineBreak) or (Node.Kind = TMarkdownNodeKind.HardLineBreak);
end;

// Drops the marker nodes and the line break after them. A paragraph left
// empty, because the alert text starts in a paragraph of its own, goes too.
class procedure TAlertDocumentProcessor.RemoveMarker(const BlockQuote, Paragraph: IMarkdownNode;
  const MarkerNodeCount: Integer);
begin
  const ParagraphNode = Paragraph as TMarkdownAstNode;

  var RemoveCount := MarkerNodeCount;
  const HasLineBreak = (RemoveCount < Paragraph.ChildCount) and IsLineBreak(Paragraph.Children[RemoveCount]);
  if HasLineBreak then
    Inc(RemoveCount);

  for var Removed := 1 to RemoveCount do
  begin
    ParagraphNode.DeleteChild(0);
  end;

  const IsEmpty = (Paragraph.ChildCount = 0);
  if IsEmpty then
    (BlockQuote as TMarkdownAstNode).DeleteChild(0);
end;

end.
