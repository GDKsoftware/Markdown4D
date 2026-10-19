unit Markdown4D.FrontMatter.Properties;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections;

type
  TFrontMatterProperty = record
    Key: string;
    Values: TArray<string>;
    IsList: Boolean;
  end;

  // Reads the simple subset of YAML that front matter nearly always uses: one
  // "key: value" per line, a flow list "key: [a, b]", and a block list of
  // "- item" lines under "key:". Blank lines and comments are skipped. Anything
  // beyond that, such as a nested map or a block scalar, makes TryParse fail,
  // so the caller shows the raw text instead of a wrong reading of it.
  TFrontMatterProperties = class
  private
    const
      KeySeparator = ':';
      ListItemMarker = '-';
      CommentMarker = '#';
      TrailingCommentMarker = ' #';
      FlowListOpen = '[';
      FlowListClose = ']';
      FlowListSeparator = ',';
      Quotes = '"''';
      UnsupportedValueStarts = '[{|>';
      TrimChars: array[0..1] of Char = (' ', #9);
    var
      FProperties: TList<TFrontMatterProperty>;
      FAcceptsListItems: Boolean;
    function TryAddLine(const Line: string): Boolean;
    function TryAddListItem(const Stripped: string): Boolean;
    function TryAddProperty(const Content: string): Boolean;
    class function IsListItemLine(const Stripped: string): Boolean; static;
    class function IsSpaceOrTab(const Value: Char): Boolean; static;
    class function KeySeparatorIndex(const Content: string): Integer; static;
    class function TryParseFlowList(const Value: string; out Items: TArray<string>): Boolean; static;
    class function TryParseScalar(const Value: string; out Scalar: string): Boolean; static;
    class function IsQuoted(const Value: string): Boolean; static;
    class function WithoutTrailingComment(const Value: string): string; static;

  public
    class function TryParse(const RawText: string; out Properties: TArray<TFrontMatterProperty>): Boolean; static;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Defines;

class function TFrontMatterProperties.TryParse(const RawText: string;
                                               out Properties: TArray<TFrontMatterProperty>): Boolean;
begin
  Properties := nil;
  Result := False;

  const Reader = TFrontMatterProperties.Create;
  try
    const Lines = RawText.Replace(CarriageReturn, '').Split([LineFeed]);

    for var Line in Lines do
    begin
      if not Reader.TryAddLine(Line) then
        Exit;
    end;

    const HasProperties = (Reader.FProperties.Count > 0);
    if not HasProperties then
      Exit;

    Properties := Reader.FProperties.ToArray;
    Result := True;
  finally
    Reader.Free;
  end;
end;

constructor TFrontMatterProperties.Create;
begin
  inherited Create;

  FProperties := TList<TFrontMatterProperty>.Create;
end;

destructor TFrontMatterProperties.Destroy;
begin
  FProperties.Free;

  inherited Destroy;
end;

function TFrontMatterProperties.TryAddLine(const Line: string): Boolean;
begin
  const Content = Line.TrimRight(TrimChars);
  const Stripped = Content.TrimLeft(TrimChars);

  const IsSkipped = (Stripped = '') or Stripped.StartsWith(CommentMarker);
  if IsSkipped then
  begin
    Result := True;
    Exit;
  end;

  if IsListItemLine(Stripped) then
  begin
    Result := TryAddListItem(Stripped);
    Exit;
  end;

  const IsIndented = IsSpaceOrTab(Content[1]);
  if IsIndented then
  begin
    Result := False;
    Exit;
  end;

  Result := TryAddProperty(Content);
end;

function TFrontMatterProperties.TryAddListItem(const Stripped: string): Boolean;
begin
  Result := False;

  if not FAcceptsListItems then
    Exit;

  const ItemText = Copy(Stripped, Length(ListItemMarker) + 1, MaxInt).Trim(TrimChars);

  var Item: string;
  if not TryParseScalar(ItemText, Item) then
    Exit;

  const LastIndex = FProperties.Count - 1;
  var Owner := FProperties[LastIndex];
  Owner.Values := Owner.Values + [Item];
  Owner.IsList := True;
  FProperties[LastIndex] := Owner;

  Result := True;
end;

function TFrontMatterProperties.TryAddProperty(const Content: string): Boolean;
begin
  Result := False;
  FAcceptsListItems := False;

  const SeparatorIndex = KeySeparatorIndex(Content);
  if SeparatorIndex = 0 then
    Exit;

  var Key: string;
  const RawKey = Copy(Content, 1, SeparatorIndex - 1).TrimRight(TrimChars);
  if not TryParseScalar(RawKey, Key) or (Key = '') then
    Exit;

  var Entry := Default(TFrontMatterProperty);
  Entry.Key := Key;

  const Value = Copy(Content, SeparatorIndex + 1, MaxInt).Trim(TrimChars);
  const IsEmptyValue = (Value = '');
  const IsFlowList = Value.StartsWith(FlowListOpen);

  if IsEmptyValue then
  begin
    FAcceptsListItems := True;
  end
  else if IsFlowList then
  begin
    if not TryParseFlowList(Value, Entry.Values) then
      Exit;

    Entry.IsList := True;
  end
  else
  begin
    var Scalar: string;
    if not TryParseScalar(Value, Scalar) then
      Exit;

    Entry.Values := [Scalar];
  end;

  FProperties.Add(Entry);
  Result := True;
end;

class function TFrontMatterProperties.IsListItemLine(const Stripped: string): Boolean;
begin
  const IsBareMarker = (Stripped = ListItemMarker);
  const HasMarkerAndSpace = (Length(Stripped) > 1) and (Stripped[1] = ListItemMarker) and IsSpaceOrTab(Stripped[2]);

  Result := IsBareMarker or HasMarkerAndSpace;
end;

class function TFrontMatterProperties.IsSpaceOrTab(const Value: Char): Boolean;
begin
  Result := (Value = Space) or (Value = Tab);
end;

// In YAML a colon only separates a key when whitespace or the line end follows
// it, so "url: http://example.com" has one key and "a:b" is no pair at all.
class function TFrontMatterProperties.KeySeparatorIndex(const Content: string): Integer;
begin
  for var Index := 1 to Length(Content) do
  begin
    if Content[Index] <> KeySeparator then
      Continue;

    const AtLineEnd = (Index = Length(Content));
    if AtLineEnd or IsSpaceOrTab(Content[Index + 1]) then
    begin
      Result := Index;
      Exit;
    end;
  end;

  Result := 0;
end;

class function TFrontMatterProperties.TryParseFlowList(const Value: string; out Items: TArray<string>): Boolean;
begin
  Items := nil;
  Result := False;

  const Closed = WithoutTrailingComment(Value);
  if not Closed.EndsWith(FlowListClose) then
    Exit;

  const Inner = Copy(Closed, Length(FlowListOpen) + 1, Length(Closed) - Length(FlowListOpen) - Length(FlowListClose));
  const Parts = Inner.Split([FlowListSeparator]);

  for var Part in Parts do
  begin
    const ItemText = Part.Trim(TrimChars);
    if ItemText = '' then
      Continue;

    var Item: string;
    if not TryParseScalar(ItemText, Item) then
      Exit;

    Items := Items + [Item];
  end;

  Result := True;
end;

// A quoted scalar is taken as it stands between its quotes. An unquoted one
// must not start a collection or a block scalar, and must not hold a further
// key separator, which would make it a nested map.
class function TFrontMatterProperties.TryParseScalar(const Value: string; out Scalar: string): Boolean;
begin
  Scalar := '';

  var Plain := Value;
  if not IsQuoted(Plain) then
    Plain := WithoutTrailingComment(Plain);

  if IsQuoted(Plain) then
  begin
    Scalar := Copy(Plain, 2, Length(Plain) - 2);
    Result := True;
    Exit;
  end;

  const StartsUnsupported = (Plain <> '') and (Pos(Plain[1], UnsupportedValueStarts) > 0);
  const HoldsKeySeparator = (KeySeparatorIndex(Plain) > 0);
  if StartsUnsupported or HoldsKeySeparator then
  begin
    Result := False;
    Exit;
  end;

  Scalar := Plain;
  Result := True;
end;

class function TFrontMatterProperties.IsQuoted(const Value: string): Boolean;
begin
  const IsLongEnough = (Length(Value) >= 2);
  if not IsLongEnough then
  begin
    Result := False;
    Exit;
  end;

  const Opening = Value[1];
  const Closing = Value[Length(Value)];

  Result := (Pos(Opening, Quotes) > 0) and (Opening = Closing);
end;

class function TFrontMatterProperties.WithoutTrailingComment(const Value: string): string;
begin
  const CommentIndex = Pos(TrailingCommentMarker, Value);
  if CommentIndex = 0 then
  begin
    Result := Value;
    Exit;
  end;

  Result := Copy(Value, 1, CommentIndex - 1).TrimRight(TrimChars);
end;

end.
