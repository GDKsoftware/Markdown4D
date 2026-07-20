unit Markdown4D.Parser.References;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Parser.LinkSyntax;

type
  TLinkReference = record
    Destination: string;
    Title: string;
  end;

  TLinkReferenceMap = class
  private
    FEntries: TDictionary<string, TLinkReference>;
    FMissedLabels: TDictionary<string, Boolean>;
    FCaptureTarget: TLinkReferenceMap;

  public
    class function NormalizeLabel(const RawLabel: string): string;
    constructor Create;
    destructor Destroy; override;
    procedure AddIfAbsent(const RawLabel: string; const Reference: TLinkReference);
    function TryGet(const RawLabel: string; out Reference: TLinkReference): Boolean;
    procedure Clear;
    procedure CopyTo(const Target: TLinkReferenceMap);
    function ContainsNormalizedLabel(const NormalizedLabel: string): Boolean;
    function ContainsAllEntriesOf(const Other: TLinkReferenceMap): Boolean;
    function Count: Integer;
    procedure SetCaptureTarget(const Target: TLinkReferenceMap);
    function MissedLabels: TArray<string>;
    procedure ClearMissedLabels;
  end;

  TLinkReferenceParser = class
  private
    const
      Colon = ':';
    var
      FScanner: TLinkSyntaxScanner;
    function TryParse(out Consumed: Integer; out RawLabel: string; out Reference: TLinkReference): Boolean;

  public
    constructor Create;
    destructor Destroy; override;
    function TryConsumeReference(const Content: string; const Map: TLinkReferenceMap;
                                 out Consumed: Integer): Boolean;
  end;

implementation

uses
  Markdown4D.Text.Unescape;

constructor TLinkReferenceMap.Create;
begin
  inherited Create;

  FEntries := TDictionary<string, TLinkReference>.Create;
  FMissedLabels := TDictionary<string, Boolean>.Create;
end;

destructor TLinkReferenceMap.Destroy;
begin
  FMissedLabels.Free;
  FEntries.Free;

  inherited Destroy;
end;

procedure TLinkReferenceMap.AddIfAbsent(const RawLabel: string; const Reference: TLinkReference);
begin
  const HasCaptureTarget = (FCaptureTarget <> nil);
  if HasCaptureTarget then
    FCaptureTarget.AddIfAbsent(RawLabel, Reference);

  const Key = NormalizeLabel(RawLabel);
  if not FEntries.ContainsKey(Key) then
    FEntries.Add(Key, Reference);
end;

function TLinkReferenceMap.TryGet(const RawLabel: string; out Reference: TLinkReference): Boolean;
begin
  const Key = NormalizeLabel(RawLabel);
  Result := FEntries.TryGetValue(Key, Reference);

  if not Result then
    FMissedLabels.AddOrSetValue(Key, True);
end;

procedure TLinkReferenceMap.Clear;
begin
  FEntries.Clear;
  FMissedLabels.Clear;
end;

procedure TLinkReferenceMap.CopyTo(const Target: TLinkReferenceMap);
begin
  for var Entry in FEntries do
  begin
    if not Target.FEntries.ContainsKey(Entry.Key) then
      Target.FEntries.Add(Entry.Key, Entry.Value);
  end;
end;

function TLinkReferenceMap.ContainsNormalizedLabel(const NormalizedLabel: string): Boolean;
begin
  Result := FEntries.ContainsKey(NormalizedLabel);
end;

function TLinkReferenceMap.ContainsAllEntriesOf(const Other: TLinkReferenceMap): Boolean;
begin
  for var Entry in Other.FEntries do
  begin
    var Existing: TLinkReference;
    if not FEntries.TryGetValue(Entry.Key, Existing) then
      Exit(False);

    const SameReference = (Existing.Destination = Entry.Value.Destination) and (Existing.Title = Entry.Value.Title);
    if not SameReference then
      Exit(False);
  end;

  Result := True;
end;

function TLinkReferenceMap.Count: Integer;
begin
  Result := FEntries.Count;
end;

procedure TLinkReferenceMap.SetCaptureTarget(const Target: TLinkReferenceMap);
begin
  FCaptureTarget := Target;
end;

function TLinkReferenceMap.MissedLabels: TArray<string>;
begin
  Result := FMissedLabels.Keys.ToArray;
end;

procedure TLinkReferenceMap.ClearMissedLabels;
begin
  FMissedLabels.Clear;
end;

class function TLinkReferenceMap.NormalizeLabel(const RawLabel: string): string;
begin
  const Builder = TStringBuilder.Create;
  try
    var PendingSpace := False;
    var HasContent := False;

    for var Current in RawLabel do
    begin
      const IsWhitespace = CharInSet(Current, [' ', #9, #10, #13]);

      if IsWhitespace then
      begin
        PendingSpace := HasContent;
        Continue;
      end;

      if PendingSpace then
      begin
        Builder.Append(' ');
        PendingSpace := False;
      end;

      Builder.Append(Current);
      HasContent := True;
    end;

    const SharpS = #$00DF;
    const Collapsed = Builder.ToString;
    const Lowered = Collapsed.ToLower;
    const SharpSFolded = Lowered.Replace(SharpS, 'ss', [rfReplaceAll]);

    Result := SharpSFolded.ToUpper;
  finally
    Builder.Free;
  end;
end;

constructor TLinkReferenceParser.Create;
begin
  inherited Create;

  FScanner := TLinkSyntaxScanner.Create;
end;

destructor TLinkReferenceParser.Destroy;
begin
  FScanner.Free;

  inherited Destroy;
end;

function TLinkReferenceParser.TryConsumeReference(const Content: string; const Map: TLinkReferenceMap;
                                                  out Consumed: Integer): Boolean;
begin
  FScanner.Reset(Content, 1);

  var RawLabel: string;
  var Reference: TLinkReference;

  Result := TryParse(Consumed, RawLabel, Reference);

  if Result then
    Map.AddIfAbsent(RawLabel, Reference);
end;

function TLinkReferenceParser.TryParse(out Consumed: Integer; out RawLabel: string;
                                       out Reference: TLinkReference): Boolean;
begin
  Consumed := 0;
  Reference.Destination := '';
  Reference.Title := '';

  var LabelLength: Integer;
  if not FScanner.TryParseLabel(RawLabel, LabelLength) then
    Exit(False);

  const HasColon = (FScanner.PeekChar = Colon);
  if not HasColon then
    Exit(False);

  FScanner.Advance(1);
  FScanner.SkipSpacesWithOneNewline;

  var Destination: string;
  if not FScanner.TryParseDestination(Destination) then
    Exit(False);

  const BeforeTitle = FScanner.Position;
  FScanner.SkipSpacesWithOneNewline;

  var Title := '';
  var HasTitle := False;

  const MovedPastDestination = (FScanner.Position <> BeforeTitle);
  if MovedPastDestination then
    HasTitle := FScanner.TryParseTitle(Title);

  if not HasTitle then
    FScanner.MoveTo(BeforeTitle);

  var AtLineEnd := FScanner.ConsumeSpacesToLineEnd;

  if (not AtLineEnd) and HasTitle then
  begin
    Title := '';
    FScanner.MoveTo(BeforeTitle);
    AtLineEnd := FScanner.ConsumeSpacesToLineEnd;
  end;

  if not AtLineEnd then
    Exit(False);

  const NormalizedLabel = TLinkReferenceMap.NormalizeLabel(RawLabel);
  const LabelIsEmpty = (NormalizedLabel = '');
  if LabelIsEmpty then
    Exit(False);

  const UnescapedDestination = TMarkdownUnescape.Unescape(Destination);
  Reference.Destination := TMarkdownUnescape.NormalizeUri(UnescapedDestination);
  Reference.Title := TMarkdownUnescape.Unescape(Title);
  Consumed := FScanner.Position - 1;
  Result := True;
end;

end.
