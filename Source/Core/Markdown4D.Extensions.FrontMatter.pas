unit Markdown4D.Extensions.FrontMatter;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Extensions.Interfaces;

type
  // Recognises a YAML front matter block at the very start of a document and
  // delivers it as the first node, with the raw text between the fences as its
  // literal. Neither UseCommonMark nor UseGfm includes it: a host turns it on
  // with Use, or through TMarkdownParseOption.FrontMatter on TMarkdown.
  TFrontMatterExtension = class(TInterfacedObject, IMarkdownExtension)
  private
    const
      FenceTrigger = '-';

  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

  TFrontMatterProperty = record
    Key: string;
    Values: TArray<string>;
    IsList: Boolean;
  end;

  // A deliberately strict reading of front matter: flat "key: value" pairs,
  // flow lists ([a, b]) and block lists ("- a" lines under an empty key). Any
  // other YAML makes TryParse fail, so the caller shows the raw text instead.
  TFrontMatterProperties = class
  private
    const
      ListItemMarker = '-';
      CommentMarker = '#';
      KeySeparator = ':';
      FlowListOpen = '[';
      FlowListClose = ']';
      FlowMapOpen = '{';
      FlowListSeparator = ',';
      SingleQuote = '''';
      DoubleQuote = '"';
      UnsupportedValueStarts = '{|>';
      TrimChars: array[0..1] of Char = (' ', #9);
    var
      FProperties: TArray<TFrontMatterProperty>;
      FAcceptsListItems: Boolean;
    function TryReadLines(const Raw: string): Boolean;
    function TryReadLine(const Line: string): Boolean;
    function TryAddListItem(const Item: string): Boolean;
    function TryAddKeyLine(const Line: string): Boolean;
    class function TryParseKeyLine(const Line: string; out Prop: TFrontMatterProperty): Boolean;
    class function TryParseValue(const Key, Value: string; out Prop: TFrontMatterProperty): Boolean;
    class function TryParseFlowList(const Value: string; out Items: TArray<string>): Boolean;
    class function IsListItemLine(const Trimmed: string): Boolean;
    class function IsIndented(const Line: string): Boolean;
    class function Unquote(const Value: string): string;

  public
    class function TryParse(const Raw: string; out Properties: TArray<TFrontMatterProperty>): Boolean;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Defines,
  Markdown4D.Parser.Blocks;

procedure TFrontMatterExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterBlockParser(TFrontMatterBlockStarter.Create, FenceTrigger, TMarkdownPriorities.Lowest);
end;

class function TFrontMatterProperties.TryParse(const Raw: string;
                                               out Properties: TArray<TFrontMatterProperty>): Boolean;
begin
  Properties := nil;

  const Reader = TFrontMatterProperties.Create;
  try
    Result := Reader.TryReadLines(Raw);
    if Result then
      Properties := Reader.FProperties;
  finally
    Reader.Free;
  end;
end;

function TFrontMatterProperties.TryReadLines(const Raw: string): Boolean;
begin
  const Lines = Raw.Split([LineFeed]);
  for var Line in Lines do
  begin
    const WithoutCarriageReturn = Line.TrimRight([CarriageReturn]);
    if not TryReadLine(WithoutCarriageReturn) then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

function TFrontMatterProperties.TryReadLine(const Line: string): Boolean;
begin
  const Trimmed = Line.Trim(TrimChars);
  const IsSkipped = (Trimmed.IsEmpty or Trimmed.StartsWith(CommentMarker));
  if IsSkipped then
  begin
    Result := True;
    Exit;
  end;

  if IsListItemLine(Trimmed) then
  begin
    const AfterMarker = Trimmed.Substring(Length(ListItemMarker));
    const Item = AfterMarker.Trim(TrimChars);
    Result := TryAddListItem(Item);
    Exit;
  end;

  if IsIndented(Line) then
  begin
    Result := False;
    Exit;
  end;

  Result := TryAddKeyLine(Line);
end;

function TFrontMatterProperties.TryAddListItem(const Item: string): Boolean;
begin
  const Value = Unquote(Item);
  const IsQuoted = (Value <> Item);
  const IsMapping = (not IsQuoted and (Item.Contains(KeySeparator + Space) or Item.EndsWith(KeySeparator)));

  Result := FAcceptsListItems and not Item.IsEmpty and not IsMapping;
  if not Result then
    Exit;

  const LastIndex = High(FProperties);
  FProperties[LastIndex].Values := FProperties[LastIndex].Values + [Value];
  FProperties[LastIndex].IsList := True;
end;

function TFrontMatterProperties.TryAddKeyLine(const Line: string): Boolean;
begin
  var Prop: TFrontMatterProperty;
  Result := TryParseKeyLine(Line, Prop);
  if not Result then
    Exit;

  FProperties := FProperties + [Prop];
  FAcceptsListItems := (Length(Prop.Values) = 0) and not Prop.IsList;
end;

class function TFrontMatterProperties.TryParseKeyLine(const Line: string; out Prop: TFrontMatterProperty): Boolean;
begin
  Prop := Default(TFrontMatterProperty);

  const SeparatorIndex = Line.IndexOf(KeySeparator);
  const HasSeparator = (SeparatorIndex > 0);
  if not HasSeparator then
  begin
    Result := False;
    Exit;
  end;

  const Key = Line.Substring(0, SeparatorIndex).Trim(TrimChars);
  const Value = Line.Substring(SeparatorIndex + 1);
  const IsSeparatedFromValue = (Value.IsEmpty or CharInSet(Value.Chars[0], [Space, Tab]));
  const TrimmedValue = Value.Trim(TrimChars);

  Result := IsSeparatedFromValue and not Key.IsEmpty and TryParseValue(Key, TrimmedValue, Prop);
end;

class function TFrontMatterProperties.TryParseValue(const Key, Value: string; out Prop: TFrontMatterProperty): Boolean;
begin
  Prop := Default(TFrontMatterProperty);
  Prop.Key := Key;

  if Value.IsEmpty then
  begin
    Result := True;
    Exit;
  end;

  const IsUnsupported = (Pos(Value.Chars[0], UnsupportedValueStarts) > 0);
  if IsUnsupported then
  begin
    Result := False;
    Exit;
  end;

  if Value.StartsWith(FlowListOpen) then
  begin
    Prop.IsList := True;
    Result := TryParseFlowList(Value, Prop.Values);
    Exit;
  end;

  Prop.Values := [Unquote(Value)];
  Result := True;
end;

class function TFrontMatterProperties.TryParseFlowList(const Value: string; out Items: TArray<string>): Boolean;
begin
  Items := nil;

  const IsClosed = (Value.EndsWith(FlowListClose));
  if not IsClosed then
  begin
    Result := False;
    Exit;
  end;

  const InnerLength = Value.Length - Length(FlowListOpen) - Length(FlowListClose);
  const Inner = Value.Substring(Length(FlowListOpen), InnerLength);
  const IsNested = (Inner.IndexOfAny([FlowListOpen, FlowMapOpen]) >= 0);
  if IsNested then
  begin
    Result := False;
    Exit;
  end;

  const TrimmedInner = Inner.Trim(TrimChars);
  if TrimmedInner.IsEmpty then
  begin
    Result := True;
    Exit;
  end;

  const Parts = Inner.Split([FlowListSeparator]);
  for var Part in Parts do
  begin
    const TrimmedPart = Part.Trim(TrimChars);
    Items := Items + [Unquote(TrimmedPart)];
  end;

  Result := True;
end;

class function TFrontMatterProperties.IsListItemLine(const Trimmed: string): Boolean;
begin
  const IsBareMarker = (Trimmed = ListItemMarker);
  const HasMarkerAndSpace = (Trimmed.StartsWith(ListItemMarker + Space) or Trimmed.StartsWith(ListItemMarker + Tab));

  Result := (IsBareMarker or HasMarkerAndSpace);
end;

class function TFrontMatterProperties.IsIndented(const Line: string): Boolean;
begin
  Result := ((not Line.IsEmpty) and CharInSet(Line.Chars[0], [Space, Tab]));
end;

class function TFrontMatterProperties.Unquote(const Value: string): string;
begin
  Result := Value;

  const IsLongEnough = (Value.Length >= 2);
  if not IsLongEnough then
    Exit;

  const FirstChar = Value.Chars[0];
  const IsQuoted = (((FirstChar = SingleQuote) or (FirstChar = DoubleQuote)) and
                    Value.EndsWith(FirstChar));
  if IsQuoted then
    Result := Value.Substring(1, Value.Length - 2);
end;

end.
