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
      FlowListOpen = '[';
      FlowListClose = ']';
      FlowListSeparator = ',';
      SingleQuote = '''';
      DoubleQuote = '"';
      EscapedSingleQuote = '''''';
      Backslash = '\';
      UnsupportedValueStarts = '[{|>&*!';
      TrimChars: array[0..1] of Char = (' ', #9);
    var
      FProperties: TList<TFrontMatterProperty>;
      FAcceptsListItems: Boolean;
    constructor Create;
    function TryAddLine(const Line: string): Boolean;
    function TryAddListItem(const Stripped: string): Boolean;
    function TryAddProperty(const Content: string): Boolean;
    class function IsListItemLine(const Stripped: string): Boolean; static;
    class function IsSpaceOrTab(const Value: Char): Boolean; static;
    class function KeySeparatorIndex(const Content: string): Integer; static;
    class function TryParseFlowList(const Value: string; out Items: TArray<string>): Boolean; static;
    class function TrySplitFlowItems(const Value: string; out Parts: TArray<string>; out CloseIndex: Integer): Boolean; static;
    class function IsBlankBetween(const Value: string; const FirstIndex, LastIndex: Integer): Boolean; static;
    class function TryParseScalar(const Value: string; out Scalar: string): Boolean; static;
    class function TryParseQuotedScalar(const Value: string; out Scalar: string): Boolean; static;
    class function IsQuote(const Value: Char): Boolean; static;
    class function QuoteEndIndex(const Value: string; const OpenIndex: Integer): Integer; static;
    class function Unquote(const Quoted: string): string; static;
    class function UnescapeDoubleQuoted(const Content: string): string; static;
    class function IsBlankOrComment(const Rest: string): Boolean; static;
    class function WithoutTrailingComment(const Value: string): string; static;

  public
    class function TryParse(const RawText: string; out Properties: TArray<TFrontMatterProperty>): Boolean; static;
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
    const LineFeedText = RawText.Replace(CarriageReturn, '');
    const Lines = LineFeedText.Split([LineFeed]);

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

// Private: a reader only lives inside TryParse, which hands out the result.
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

  const ContentStart = Length(ListItemMarker) + 1;
  const AfterMarker = Copy(Stripped, ContentStart, MaxInt);
  const ItemText = AfterMarker.Trim(TrimChars);

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
  const KeyText = Copy(Content, 1, SeparatorIndex - 1);
  const RawKey = KeyText.TrimRight(TrimChars);
  if not TryParseScalar(RawKey, Key) or (Key = '') then
    Exit;

  var Entry := Default(TFrontMatterProperty);
  Entry.Key := Key;

  const ValueText = Copy(Content, SeparatorIndex + 1, MaxInt);
  const Value = ValueText.Trim(TrimChars);
  const IsEmptyValue = (Value = '') or Value.StartsWith(CommentMarker);
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

  var Parts: TArray<string>;
  var CloseIndex: Integer;
  if not TrySplitFlowItems(Value, Parts, CloseIndex) then
    Exit;

  const Rest = Copy(Value, CloseIndex + 1, MaxInt);
  if not IsBlankOrComment(Rest) then
    Exit;

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

// Splits the items of a flow list on the commas outside quotes, up to the
// closing bracket. A quote only opens a quoted item at the start of an item, so
// "it's" stays a plain one. An unclosed quote or bracket gives False.
class function TFrontMatterProperties.TrySplitFlowItems(const Value: string; out Parts: TArray<string>;
                                                        out CloseIndex: Integer): Boolean;
begin
  Parts := nil;
  CloseIndex := 0;
  Result := False;

  const FirstItemStart = Length(FlowListOpen) + 1;
  var ItemStart := FirstItemStart;
  var Index := ItemStart;

  while Index <= Length(Value) do
  begin
    const Current = Value[Index];

    const OpensQuotedItem = IsQuote(Current) and IsBlankBetween(Value, ItemStart, Index - 1);
    if OpensQuotedItem then
    begin
      const QuoteEnd = QuoteEndIndex(Value, Index);
      const IsUnclosed = (QuoteEnd = 0);
      if IsUnclosed then
        Exit;

      Index := QuoteEnd + 1;
      Continue;
    end;

    const EndsItem = (Current = FlowListSeparator) or (Current = FlowListClose);
    if EndsItem then
    begin
      Parts := Parts + [Copy(Value, ItemStart, Index - ItemStart)];

      const ClosesList = (Current = FlowListClose);
      if ClosesList then
      begin
        CloseIndex := Index;
        Result := True;
        Exit;
      end;

      ItemStart := Index + 1;
    end;

    Inc(Index);
  end;
end;

class function TFrontMatterProperties.IsBlankBetween(const Value: string; const FirstIndex, LastIndex: Integer): Boolean;
begin
  for var Index := FirstIndex to LastIndex do
  begin
    if not IsSpaceOrTab(Value[Index]) then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

// A quoted scalar is taken as it stands between its quotes. An unquoted one
// must not start a collection or a block scalar, and must not hold a further
// key separator, which would make it a nested map.
class function TFrontMatterProperties.TryParseScalar(const Value: string; out Scalar: string): Boolean;
begin
  Scalar := '';

  const StartsQuoted = (Value <> '') and IsQuote(Value[1]);
  if StartsQuoted then
  begin
    Result := TryParseQuotedScalar(Value, Scalar);
    Exit;
  end;

  const Plain = WithoutTrailingComment(Value);
  const StartsUnsupported = (Plain <> '') and (Pos(Plain[1], UnsupportedValueStarts) > 0);
  const HoldsKeySeparator = (KeySeparatorIndex(Plain) > 0);
  const StartsNestedList = IsListItemLine(Plain);
  if StartsUnsupported or HoldsKeySeparator or StartsNestedList then
  begin
    Result := False;
    Exit;
  end;

  Scalar := Plain;
  Result := True;
end;

// Only one quoted piece makes a scalar: after its closing quote nothing but a
// comment may follow, so "a" "b" and an unclosed quote both fail.
class function TFrontMatterProperties.TryParseQuotedScalar(const Value: string; out Scalar: string): Boolean;
begin
  Scalar := '';
  Result := False;

  const CloseIndex = QuoteEndIndex(Value, 1);
  const IsUnclosed = (CloseIndex = 0);
  if IsUnclosed then
    Exit;

  const Rest = Copy(Value, CloseIndex + 1, MaxInt);
  if not IsBlankOrComment(Rest) then
    Exit;

  const Quoted = Copy(Value, 1, CloseIndex);
  Scalar := Unquote(Quoted);
  Result := True;
end;

class function TFrontMatterProperties.IsQuote(const Value: Char): Boolean;
begin
  Result := (Value = SingleQuote) or (Value = DoubleQuote);
end;

// The index of the quote that closes the one at OpenIndex, or 0 when it is
// never closed. A single quoted scalar escapes a quote by doubling it, a double
// quoted one with a backslash.
class function TFrontMatterProperties.QuoteEndIndex(const Value: string; const OpenIndex: Integer): Integer;
begin
  const Quote = Value[OpenIndex];
  var Index := OpenIndex + 1;

  while Index <= Length(Value) do
  begin
    const Current = Value[Index];
    const HasNext = (Index < Length(Value));
    const IsDoubledSingleQuote = (Quote = SingleQuote) and (Current = SingleQuote) and HasNext and (Value[Index + 1] = SingleQuote);
    const IsBackslashEscape = (Quote = DoubleQuote) and (Current = Backslash) and HasNext;

    if IsDoubledSingleQuote or IsBackslashEscape then
    begin
      Inc(Index, 2);
      Continue;
    end;

    const IsClosingQuote = (Current = Quote);
    if IsClosingQuote then
    begin
      Result := Index;
      Exit;
    end;

    Inc(Index);
  end;

  Result := 0;
end;

class function TFrontMatterProperties.Unquote(const Quoted: string): string;
begin
  const ContentLength = Length(Quoted) - 2;
  const Content = Copy(Quoted, 2, ContentLength);
  const IsSingleQuoted = (Quoted[1] = SingleQuote);

  if IsSingleQuoted then
    Result := Content.Replace(EscapedSingleQuote, SingleQuote)
  else
    Result := UnescapeDoubleQuoted(Content);
end;

// Only an escaped quote and an escaped backslash are resolved; other escapes
// are shown as written.
class function TFrontMatterProperties.UnescapeDoubleQuoted(const Content: string): string;
begin
  Result := '';
  var Index := 1;

  while Index <= Length(Content) do
  begin
    const HasNext = (Index < Length(Content));
    const IsEscape = (Content[Index] = Backslash) and HasNext and
                     ((Content[Index + 1] = DoubleQuote) or (Content[Index + 1] = Backslash));
    if IsEscape then
      Inc(Index);

    Result := Result + Content[Index];
    Inc(Index);
  end;
end;

class function TFrontMatterProperties.IsBlankOrComment(const Rest: string): Boolean;
begin
  const Trimmed = Rest.TrimLeft(TrimChars);
  const IsBlank = (Trimmed = '');
  const IsComment = Trimmed.StartsWith(CommentMarker) and (Length(Trimmed) < Length(Rest));

  Result := IsBlank or IsComment;
end;

// A comment starts at a "#" that opens the value or follows a space or a tab.
class function TFrontMatterProperties.WithoutTrailingComment(const Value: string): string;
begin
  for var Index := 1 to Length(Value) do
  begin
    const StartsComment = (Value[Index] = CommentMarker) and ((Index = 1) or IsSpaceOrTab(Value[Index - 1]));
    if StartsComment then
    begin
      const BeforeComment = Copy(Value, 1, Index - 1);
      Result := BeforeComment.TrimRight(TrimChars);
      Exit;
    end;
  end;

  Result := Value;
end;

end.
