unit Markdown4D.Html.Subset;

{$SCOPEDENUMS ON}

// Translates the HTML that turns up inside markdown documents into markdown.
//
// Raw HTML is not rendered by the viewer: the HTML renderer omits it, and
// painting the markup as text would put tags in front of a reader. Dropping it
// wholesale is not right either, because a README leans on a handful of tags
// that markdown cannot express: centred images, <details> sections, <br>,
// <sub>, <kbd>. Those carry meaning a reader expects to see.
//
// So instead of a second rendering path, the allowed subset is translated to
// markdown and handed back to the parser. Everything downstream - layout,
// selection, hit-testing, theming, image loading - then works on it unchanged.
//
// The list of tags this understands is deliberately short. A tag that is not on
// it is dropped while its content is kept, which is what a browser would show
// with the styling removed. <script> and <style> are dropped with their content,
// because their content is not text a reader wants.

interface

type
  TMarkdownHtmlSubset = class
  public
    // Converts an HTML fragment to markdown. Returns an empty string when
    // nothing survives the translation.
    class function ToMarkdown(const Html: string): string; static;
    // True when the fragment holds nothing a reader would see.
    class function IsEmpty(const Html: string): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character,
  System.StrUtils,
  System.Classes,
  System.Generics.Collections,
  Markdown4D.Html.Entities;

type
  TTagKind = (
    // Content is kept, the tag itself contributes nothing.
    Transparent,
    // Tag and content both disappear.
    Dropped,
    Paragraph,
    LineBreak,
    Heading,
    ThematicBreak,
    Strong,
    Emphasis,
    CodeSpan,
    Strikethrough,
    Anchor,
    Image,
    UnorderedList,
    OrderedList,
    ListItem,
    BlockQuote,
    Details,
    Summary,
    Preformatted);

  TTagInfo = record
    Kind: TTagKind;
    // Markdown emitted when the tag opens and when it closes. Blocks manage
    // their own spacing instead.
    Opener: string;
    Closer: string;
    IsBlock: Boolean;
  end;

  TParsedTag = record
    Name: string;
    IsClosing: Boolean;
    IsSelfClosing: Boolean;
    Attributes: TDictionary<string, string>;
  end;

  TOpenTag = record
    Name: string;
    Kind: TTagKind;
    Closer: string;
    class function Create(const Name: string; const Kind: TTagKind; const Closer: string): TOpenTag; static;
  end;

  TSubsetConverter = class
  strict private
    const
      MarkdownSpecials = ['\', '`', '*', '_', '[', ']', '<', '>', '#', '|', '~'];
      ListIndent = '  ';
    var
      FSource: string;
      FLowered: string;
      FPosition: Integer;
      FOutput: TStringBuilder;
      // A stack, but held as a list because closing a tag has to search it from
      // the top down and TStack enumerates the other way round.
      FOpen: TList<TOpenTag>;
      FListMarkers: TStack<string>;
      FQuoteDepth: Integer;
      FAtLineStart: Boolean;
      FPendingBlank: Boolean;
      FHasContent: Boolean;
    class function TagInfoOf(const Name: string): TTagInfo; static;
    class function EscapeText(const Value: string): string; static;
    class function DecodeEntities(const Value: string): string; static;
    class function NormalizeWhitespace(const Value: string): string; static;
    class function FormatDestination(const Value: string): string; static;
    function LinePrefix: string;
    procedure Write(const Value: string);
    procedure StartLine;
    procedure StartBlock;
    procedure SkipTo(const ClosingTag: string);
    function ReadPreformatted: string;
    function TryReadTag(out Tag: TParsedTag): Boolean;
    function ReadText: string;
    procedure HandleOpenTag(const Tag: TParsedTag);
    procedure HandleCloseTag(const Name: string);
    procedure HandleImage(const Tag: TParsedTag);
    procedure HandleListItem;
  public
    constructor Create(const Html: string);
    destructor Destroy; override;
    function Convert: string;
  end;

{ TOpenTag }

class function TOpenTag.Create(const Name: string; const Kind: TTagKind; const Closer: string): TOpenTag;
begin
  Result.Name := Name;
  Result.Kind := Kind;
  Result.Closer := Closer;
end;

{ TSubsetConverter }

constructor TSubsetConverter.Create(const Html: string);
begin
  inherited Create;

  FSource := Html;
  FLowered := Html.ToLower;
  FPosition := 1;
  FOutput := TStringBuilder.Create;
  FOpen := TList<TOpenTag>.Create;
  FListMarkers := TStack<string>.Create;
  FAtLineStart := True;
end;

destructor TSubsetConverter.Destroy;
begin
  FListMarkers.Free;
  FOpen.Free;
  FOutput.Free;

  inherited;
end;

class function TSubsetConverter.TagInfoOf(const Name: string): TTagInfo;
begin
  Result := Default(TTagInfo);
  Result.Kind := TTagKind.Transparent;

  if (Name = 'script') or (Name = 'style') or (Name = 'head') or (Name = 'iframe') or (Name = 'object') then
    Result.Kind := TTagKind.Dropped
  else if (Name = 'p') or (Name = 'div') or (Name = 'center') or (Name = 'section') or (Name = 'article') then
  begin
    Result.Kind := TTagKind.Paragraph;
    Result.IsBlock := True;
  end
  else if Name = 'br' then
    Result.Kind := TTagKind.LineBreak
  else if (Length(Name) = 2) and (Name[1] = 'h') and CharInSet(Name[2], ['1'..'6']) then
  begin
    Result.Kind := TTagKind.Heading;
    Result.Opener := StringOfChar('#', StrToInt(Name[2])) + ' ';
    Result.IsBlock := True;
  end
  else if Name = 'hr' then
  begin
    Result.Kind := TTagKind.ThematicBreak;
    Result.IsBlock := True;
  end
  else if (Name = 'strong') or (Name = 'b') then
  begin
    Result.Kind := TTagKind.Strong;
    Result.Opener := '**';
    Result.Closer := '**';
  end
  else if (Name = 'em') or (Name = 'i') then
  begin
    Result.Kind := TTagKind.Emphasis;
    Result.Opener := '*';
    Result.Closer := '*';
  end
  else if (Name = 'code') or (Name = 'kbd') or (Name = 'samp') or (Name = 'tt') then
  begin
    Result.Kind := TTagKind.CodeSpan;
    Result.Opener := '`';
    Result.Closer := '`';
  end
  else if (Name = 'del') or (Name = 's') or (Name = 'strike') then
  begin
    Result.Kind := TTagKind.Strikethrough;
    Result.Opener := '~~';
    Result.Closer := '~~';
  end
  else if Name = 'a' then
    Result.Kind := TTagKind.Anchor
  else if Name = 'img' then
    Result.Kind := TTagKind.Image
  else if Name = 'ul' then
  begin
    Result.Kind := TTagKind.UnorderedList;
    Result.IsBlock := True;
  end
  else if Name = 'ol' then
  begin
    Result.Kind := TTagKind.OrderedList;
    Result.IsBlock := True;
  end
  else if Name = 'li' then
    Result.Kind := TTagKind.ListItem
  else if Name = 'blockquote' then
  begin
    Result.Kind := TTagKind.BlockQuote;
    Result.IsBlock := True;
  end
  else if Name = 'details' then
  begin
    Result.Kind := TTagKind.Details;
    Result.IsBlock := True;
  end
  else if Name = 'summary' then
  begin
    Result.Kind := TTagKind.Summary;
    Result.Opener := '**';
    Result.Closer := '**';
    Result.IsBlock := True;
  end
  else if Name = 'pre' then
  begin
    Result.Kind := TTagKind.Preformatted;
    Result.IsBlock := True;
  end;
end;

class function TSubsetConverter.EscapeText(const Value: string): string;
begin
  const Builder = TStringBuilder.Create;
  try
    for var Index := 1 to Length(Value) do
    begin
      if CharInSet(Value[Index], MarkdownSpecials) then
        Builder.Append('\');

      Builder.Append(Value[Index]);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TSubsetConverter.DecodeEntities(const Value: string): string;
begin
  if not Value.Contains('&') then
    Exit(Value);

  const Builder = TStringBuilder.Create;
  try
    var Index := 1;
    while Index <= Length(Value) do
    begin
      if Value[Index] <> '&' then
      begin
        Builder.Append(Value[Index]);
        Inc(Index);
        Continue;
      end;

      const Semicolon = PosEx(';', Value, Index + 1);
      var Decoded := '';
      const HasReference = (Semicolon > Index + 1) and (Semicolon - Index <= 32);
      if HasReference then
      begin
        const Reference = Copy(Value, Index + 1, Semicolon - Index - 1);
        const IsNumeric = Reference.StartsWith('#');
        if IsNumeric then
          THtmlEntities.TryDecodeNumeric(Reference, Decoded)
        else
          THtmlEntities.TryDecode(Reference, Decoded);
      end;

      if Decoded <> '' then
      begin
        Builder.Append(Decoded);
        Index := Semicolon + 1;
      end
      else
      begin
        Builder.Append(Value[Index]);
        Inc(Index);
      end;
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

// HTML collapses runs of whitespace, including newlines, into a single space.
class function TSubsetConverter.NormalizeWhitespace(const Value: string): string;
begin
  const Builder = TStringBuilder.Create;
  try
    var InWhitespace := False;
    for var Index := 1 to Length(Value) do
    begin
      if Value[Index].IsWhiteSpace then
      begin
        InWhitespace := True;
        Continue;
      end;

      if InWhitespace and (Builder.Length > 0) then
        Builder.Append(' ');

      InWhitespace := False;
      Builder.Append(Value[Index]);
    end;

    Result := Builder.ToString;
    if InWhitespace and (Result <> '') then
      Result := Result + ' ';
  finally
    Builder.Free;
  end;
end;

class function TSubsetConverter.FormatDestination(const Value: string): string;
begin
  Result := DecodeEntities(Value).Trim;
  if Result.Contains(' ') then
    Result := '<' + Result + '>';
end;

function TSubsetConverter.LinePrefix: string;
begin
  Result := DupeString('> ', FQuoteDepth);
  if FListMarkers.Count > 0 then
    Result := Result + DupeString(ListIndent, FListMarkers.Count);
end;

procedure TSubsetConverter.Write(const Value: string);
begin
  if Value = '' then
    Exit;

  if FPendingBlank and FHasContent then
  begin
    FOutput.Append(sLineBreak);
    if FQuoteDepth > 0 then
      FOutput.Append('>' + sLineBreak);

    FAtLineStart := True;
  end;

  FPendingBlank := False;

  if FAtLineStart then
    FOutput.Append(LinePrefix);

  FOutput.Append(Value);
  FAtLineStart := False;
  FHasContent := True;
end;

procedure TSubsetConverter.StartLine;
begin
  if FAtLineStart then
    Exit;

  FOutput.Append(sLineBreak);
  FAtLineStart := True;
end;

procedure TSubsetConverter.StartBlock;
begin
  StartLine;
  if FHasContent then
    FPendingBlank := True;
end;

// Steps over everything up to and including the closing tag, for content a
// reader should never see.
procedure TSubsetConverter.SkipTo(const ClosingTag: string);
begin
  const Closing = '</' + ClosingTag;
  const Found = PosEx(Closing, FLowered, FPosition);
  if Found = 0 then
  begin
    FPosition := Length(FSource) + 1;
    Exit;
  end;

  FPosition := Found + Length(Closing);
  const Terminator = PosEx('>', FSource, FPosition);
  if Terminator > 0 then
    FPosition := Terminator + 1;
end;

// <pre> keeps its line breaks and its spacing, so it is read raw and emitted as
// a fenced code block.
function TSubsetConverter.ReadPreformatted: string;
begin
  const Found = PosEx('</pre', FLowered, FPosition);
  var Content := '';
  if Found = 0 then
  begin
    Content := Copy(FSource, FPosition, MaxInt);
    FPosition := Length(FSource) + 1;
  end
  else
  begin
    Content := Copy(FSource, FPosition, Found - FPosition);
    FPosition := Found + Length('</pre');
    const Terminator = PosEx('>', FSource, FPosition);
    if Terminator > 0 then
      FPosition := Terminator + 1;
  end;

  // A <code> wrapper inside <pre> is conventional and carries nothing extra.
  Content := Content.Replace('<code>', '', [rfReplaceAll, rfIgnoreCase]);
  Content := Content.Replace('</code>', '', [rfReplaceAll, rfIgnoreCase]);

  Result := DecodeEntities(Content).Trim([#10, #13, ' ']);
end;

function TSubsetConverter.TryReadTag(out Tag: TParsedTag): Boolean;
begin
  Tag := Default(TParsedTag);

  if (FPosition > Length(FSource)) or (FSource[FPosition] <> '<') then
    Exit(False);

  var Scan := FPosition + 1;
  if Scan > Length(FSource) then
    Exit(False);

  // Comments and declarations carry nothing for a reader.
  if Copy(FSource, Scan, 3) = '!--' then
  begin
    const CommentEnd = PosEx('-->', FSource, Scan);
    if CommentEnd = 0 then
      FPosition := Length(FSource) + 1
    else
      FPosition := CommentEnd + 3;

    Exit(False);
  end;

  if FSource[Scan] = '!' then
  begin
    const Terminator = PosEx('>', FSource, Scan);
    if Terminator = 0 then
      FPosition := Length(FSource) + 1
    else
      FPosition := Terminator + 1;

    Exit(False);
  end;

  Tag.IsClosing := FSource[Scan] = '/';
  if Tag.IsClosing then
    Inc(Scan);

  const NameStart = Scan;
  while (Scan <= Length(FSource)) and (FLowered[Scan].IsLetterOrDigit) do
    Inc(Scan);

  if Scan = NameStart then
    Exit(False);

  Tag.Name := Copy(FLowered, NameStart, Scan - NameStart);
  Tag.Attributes := TDictionary<string, string>.Create;

  while Scan <= Length(FSource) do
  begin
    while (Scan <= Length(FSource)) and FSource[Scan].IsWhiteSpace do
      Inc(Scan);

    if Scan > Length(FSource) then
      Break;

    if FSource[Scan] = '>' then
    begin
      Inc(Scan);
      Break;
    end;

    if FSource[Scan] = '/' then
    begin
      Tag.IsSelfClosing := True;
      Inc(Scan);
      Continue;
    end;

    const AttributeStart = Scan;
    while (Scan <= Length(FSource)) and (FLowered[Scan].IsLetterOrDigit or (FSource[Scan] = '-')) do
      Inc(Scan);

    if Scan = AttributeStart then
    begin
      Inc(Scan);
      Continue;
    end;

    const AttributeName = Copy(FLowered, AttributeStart, Scan - AttributeStart);

    while (Scan <= Length(FSource)) and FSource[Scan].IsWhiteSpace do
      Inc(Scan);

    var Value := '';
    if (Scan <= Length(FSource)) and (FSource[Scan] = '=') then
    begin
      Inc(Scan);
      while (Scan <= Length(FSource)) and FSource[Scan].IsWhiteSpace do
        Inc(Scan);

      if Scan <= Length(FSource) then
      begin
        const Quote = FSource[Scan];
        if (Quote = '"') or (Quote = '''') then
        begin
          Inc(Scan);
          const ValueStart = Scan;
          while (Scan <= Length(FSource)) and (FSource[Scan] <> Quote) do
            Inc(Scan);

          Value := Copy(FSource, ValueStart, Scan - ValueStart);
          if Scan <= Length(FSource) then
            Inc(Scan);
        end
        else
        begin
          const ValueStart = Scan;
          while (Scan <= Length(FSource)) and not FSource[Scan].IsWhiteSpace and (FSource[Scan] <> '>') do
            Inc(Scan);

          Value := Copy(FSource, ValueStart, Scan - ValueStart);
        end;
      end;
    end;

    Tag.Attributes.AddOrSetValue(AttributeName, Value);
  end;

  FPosition := Scan;
  Result := True;
end;

function TSubsetConverter.ReadText: string;
begin
  const Start = FPosition;
  while (FPosition <= Length(FSource)) and (FSource[FPosition] <> '<') do
    Inc(FPosition);

  Result := Copy(FSource, Start, FPosition - Start);
end;

procedure TSubsetConverter.HandleImage(const Tag: TParsedTag);
begin
  var Source := '';
  if not Tag.Attributes.TryGetValue('src', Source) or (Source.Trim = '') then
    Exit;

  var AltText := '';
  Tag.Attributes.TryGetValue('alt', AltText);

  Write('![' + EscapeText(DecodeEntities(AltText)) + '](' + FormatDestination(Source) + ')');
end;

procedure TSubsetConverter.HandleListItem;
begin
  StartLine;

  var Marker := '- ';
  if FListMarkers.Count > 0 then
    Marker := FListMarkers.Peek;

  // The marker sits one level out from the content indent the prefix adds.
  if FListMarkers.Count > 0 then
  begin
    const Outer = FListMarkers.Pop;
    try
      Write(Marker);
    finally
      FListMarkers.Push(Outer);
    end;
  end
  else
    Write(Marker);
end;

procedure TSubsetConverter.HandleOpenTag(const Tag: TParsedTag);
begin
  const Info = TagInfoOf(Tag.Name);

  case Info.Kind of
    TTagKind.Dropped:
      begin
        if not Tag.IsSelfClosing then
          SkipTo(Tag.Name);
        Exit;
      end;

    TTagKind.LineBreak:
      begin
        // Two trailing spaces are a hard break in markdown.
        if not FAtLineStart then
          FOutput.Append('  ');

        StartLine;
        Exit;
      end;

    TTagKind.ThematicBreak:
      begin
        StartBlock;
        Write('---');
        StartLine;
        FPendingBlank := True;
        Exit;
      end;

    TTagKind.Image:
      begin
        HandleImage(Tag);
        Exit;
      end;

    TTagKind.ListItem:
      begin
        HandleListItem;
        FOpen.Add(TOpenTag.Create(Tag.Name, Info.Kind, ''));
        Exit;
      end;

    TTagKind.UnorderedList,
    TTagKind.OrderedList:
      begin
        StartBlock;
        FListMarkers.Push(IfThen(Info.Kind = TTagKind.OrderedList, '1. ', '- '));
        FOpen.Add(TOpenTag.Create(Tag.Name, Info.Kind, ''));
        Exit;
      end;

    TTagKind.BlockQuote:
      begin
        StartBlock;
        Inc(FQuoteDepth);
        FOpen.Add(TOpenTag.Create(Tag.Name, Info.Kind, ''));
        Exit;
      end;

    TTagKind.Preformatted:
      begin
        StartBlock;
        const Content = ReadPreformatted;
        if Content <> '' then
        begin
          Write('```');
          StartLine;
          for var Line in Content.Split([#10]) do
          begin
            Write(Line.TrimRight([#13]));
            StartLine;
          end;
          Write('```');
          StartLine;
          FPendingBlank := True;
        end;
        Exit;
      end;
  end;

  if Info.IsBlock then
    StartBlock;

  if Info.Opener <> '' then
    Write(Info.Opener);

  if Info.Kind = TTagKind.Anchor then
  begin
    var Destination := '';
    Tag.Attributes.TryGetValue('href', Destination);
    if Destination.Trim <> '' then
    begin
      Write('[');
      FOpen.Add(TOpenTag.Create(Tag.Name, Info.Kind, '](' + FormatDestination(Destination) + ')'));
      Exit;
    end;
  end;

  if not Tag.IsSelfClosing then
    FOpen.Add(TOpenTag.Create(Tag.Name, Info.Kind, Info.Closer));
end;

procedure TSubsetConverter.HandleCloseTag(const Name: string);
begin
  // Unwind to the nearest matching tag, so unbalanced markup cannot leave the
  // stack stuck on something that never closes.
  var Match := -1;
  for var Index := FOpen.Count - 1 downto 0 do
  begin
    if FOpen[Index].Name = Name then
    begin
      Match := Index;
      Break;
    end;
  end;

  if Match < 0 then
    Exit;

  while FOpen.Count > Match do
  begin
    const Open = FOpen.Last;
    FOpen.Delete(FOpen.Count - 1);

    if Open.Closer <> '' then
      Write(Open.Closer);

    case Open.Kind of
      TTagKind.BlockQuote:
        begin
          Dec(FQuoteDepth);
          StartLine;
          FPendingBlank := True;
        end;
      TTagKind.UnorderedList,
      TTagKind.OrderedList:
        begin
          if FListMarkers.Count > 0 then
            FListMarkers.Pop;

          StartLine;
          FPendingBlank := True;
        end;
      TTagKind.ListItem:
        StartLine;
      TTagKind.Paragraph,
      TTagKind.Heading,
      TTagKind.Summary,
      TTagKind.Details:
        begin
          StartLine;
          FPendingBlank := True;
        end;
    end;
  end;
end;

function TSubsetConverter.Convert: string;
begin
  while FPosition <= Length(FSource) do
  begin
    if FSource[FPosition] = '<' then
    begin
      var Tag: TParsedTag;
      const Before = FPosition;
      if TryReadTag(Tag) then
      begin
        try
          if Tag.IsClosing then
            HandleCloseTag(Tag.Name)
          else
            HandleOpenTag(Tag);
        finally
          Tag.Attributes.Free;
        end;
      end
      else if FPosition = Before then
      begin
        // Not a tag after all; treat the character as text.
        Write(EscapeText('<'));
        Inc(FPosition);
      end;

      Continue;
    end;

    const Text = NormalizeWhitespace(DecodeEntities(ReadText));
    if Text.Trim <> '' then
      Write(EscapeText(Text))
    else if (Text <> '') and not FAtLineStart then
      Write(' ');
  end;

  // Close whatever the document left open.
  while FOpen.Count > 0 do
  begin
    const Open = FOpen.Last;
    FOpen.Delete(FOpen.Count - 1);

    if Open.Closer <> '' then
      Write(Open.Closer);
  end;

  Result := FOutput.ToString.Trim;
end;

{ TMarkdownHtmlSubset }

class function TMarkdownHtmlSubset.ToMarkdown(const Html: string): string;
begin
  const Converter = TSubsetConverter.Create(Html);
  try
    Result := Converter.Convert;
  finally
    Converter.Free;
  end;
end;

class function TMarkdownHtmlSubset.IsEmpty(const Html: string): Boolean;
begin
  Result := ToMarkdown(Html) = '';
end;

end.
