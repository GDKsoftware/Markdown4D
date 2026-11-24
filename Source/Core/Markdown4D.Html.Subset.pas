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
// The inline tags markdown has no form for, such as <sub>, <mark> and <q>, stay
// as inline HTML, which a paragraph draws the way GitHub does. Which tags those
// are, the paragraph decides: TInlineHtmlTag holds the one list.
//
// The list of tags this understands is deliberately short. A tag that is not on
// it is dropped while its content is kept, which is what a browser would show
// with the styling removed. <script> and <style> are dropped with their content,
// because their content is not text a reader wants.

interface

type
  TMarkdownHtmlAlignment = (None, Left, Center, Right);

  TMarkdownHtmlSubset = class
  private
    const
      OpeningTagPattern = '^\s*<([A-Za-z][A-Za-z0-9]*)\b([^>]*)>';
      AlignPattern = '\balign\s*=\s*["'']?\s*(left|center|right)\b';
      CenterTag = 'center';
    class function AlignmentNamed(const Name: string): TMarkdownHtmlAlignment; static;

  public
    // Converts an HTML fragment to markdown. Returns an empty string when
    // nothing survives the translation.
    class function ToMarkdown(const Html: string): string; static;
    // True when the fragment holds nothing a reader would see.
    class function IsEmpty(const Html: string): Boolean; static;
    // How the outermost element of the fragment lines its content up: its
    // align attribute, as GitHub honours on <p>, <div> and headings, or a
    // <center> tag. None when it says nothing.
    class function BlockAlignment(const Html: string): TMarkdownHtmlAlignment; static;
    // Where the fragment has an element a link such as #Name points at: one
    // whose id is Name, or an <a> whose name is Name, as a browser looks them
    // up. Position is the 1-based index of its opening '<'.
    class function TryFindTarget(const Html, Name: string; out Position: Integer): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  System.Character,
  System.StrUtils,
  System.Classes,
  System.Generics.Collections,
  System.RegularExpressions,
  Markdown4D.Html.Entities,
  Markdown4D.Layout.InlineHtml;

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
    // Markdown has no form for it, but a paragraph draws it as inline HTML,
    // so the tag stays as it is.
    InlineHtml,
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

  // Reads an HTML fragment from the front: a tag with its attributes, the
  // text up to the next tag, or the raw content of an element such as <pre>.
  THtmlTagReader = class
  strict private
    var
      FSource: string;
      FLowered: string;
      FPosition: Integer;

  public
    class function DecodeEntities(const Value: string): string; static;
    constructor Create(const Html: string);
    function IsAtEnd: Boolean;
    function IsAtTag: Boolean;
    procedure Advance;
    function TryReadTag(out Tag: TParsedTag): Boolean;
    function ReadText: string;
    function ReadRawUntil(const ClosingTag: string): string;
    procedure SkipTo(const ClosingTag: string);
    function LoweredUntil(const ClosingTag: string): string;
    property Position: Integer read FPosition;
  end;

  // Finds the element a link such as #Name points at in an HTML fragment.
  THtmlTargetFinder = class
  strict private
    const
      AnchorTag = 'a';
      IdAttribute = 'id';
      NameAttribute = 'name';
      // The elements whose content the HTML parser reads as text.
      RawTextTags: array[0..7] of string = ('script', 'style', 'textarea', 'title', 'iframe', 'xmp', 'noembed',
        'noframes');
    var
      FReader: THtmlTagReader;
    class function IsTargetNamed(const Tag: TParsedTag; const Name: string): Boolean; static;
    class function HasAttributeValue(const Tag: TParsedTag; const Attribute, Value: string): Boolean; static;
    procedure SkipRawText(const Tag: TParsedTag);

  public
    constructor Create(const Html: string);
    destructor Destroy; override;
    function TryFind(const Name: string; out Position: Integer): Boolean;
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
      FReader: THtmlTagReader;
      FOutput: TStringBuilder;
      // A stack, but held as a list because closing a tag has to search it from
      // the top down and TStack enumerates the other way round.
      FOpen: TList<TOpenTag>;
      FListMarkers: TStack<string>;
      FQuoteDepth: Integer;
      FAtLineStart: Boolean;
      FPendingBlank: Boolean;
      FHasContent: Boolean;
      FAfterOpener: Boolean;
    class function TagInfoOf(const Name: string): TTagInfo; static;
    class function EscapeText(const Value: string): string; static;
    class function NormalizeWhitespace(const Value: string): string; static;
    class function FormatDestination(const Value: string): string; static;
    function LinePrefix: string;
    procedure Write(const Value: string);
    procedure WriteOpener(const Value: string);
    procedure StartLine;
    procedure StartBlock;
    function ReadPreformatted: string;
    procedure HandleOpenTag(const Tag: TParsedTag);
    procedure HandleCloseTag(const Name: string);
    procedure HandleImage(const Tag: TParsedTag);
    procedure HandleListItem;
    function IsHeadingSummary: Boolean;
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

{ THtmlTagReader }

class function THtmlTagReader.DecodeEntities(const Value: string): string;
begin
  if not Value.Contains('&') then
  begin
    Result := Value;
    Exit;
  end;

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

constructor THtmlTagReader.Create(const Html: string);
begin
  inherited Create;

  FSource := Html;
  FLowered := Html.ToLower;
  FPosition := 1;
end;

function THtmlTagReader.IsAtEnd: Boolean;
begin
  Result := (FPosition > Length(FSource));
end;

function THtmlTagReader.IsAtTag: Boolean;
begin
  Result := ((not IsAtEnd) and (FSource[FPosition] = '<'));
end;

procedure THtmlTagReader.Advance;
begin
  Inc(FPosition);
end;

function THtmlTagReader.TryReadTag(out Tag: TParsedTag): Boolean;
begin
  Tag := Default(TParsedTag);

  if not IsAtTag then
  begin
    Result := False;
    Exit;
  end;

  var Scan := FPosition + 1;
  if Scan > Length(FSource) then
  begin
    Result := False;
    Exit;
  end;

  // Comments and declarations carry nothing for a reader.
  if Copy(FSource, Scan, 3) = '!--' then
  begin
    const CommentEnd = PosEx('-->', FSource, Scan);
    if CommentEnd = 0 then
      FPosition := Length(FSource) + 1
    else
      FPosition := CommentEnd + 3;

    Result := False;
    Exit;
  end;

  if FSource[Scan] = '!' then
  begin
    const Terminator = PosEx('>', FSource, Scan);
    if Terminator = 0 then
      FPosition := Length(FSource) + 1
    else
      FPosition := Terminator + 1;

    Result := False;
    Exit;
  end;

  Tag.IsClosing := FSource[Scan] = '/';
  if Tag.IsClosing then
    Inc(Scan);

  const NameStart = Scan;
  while (Scan <= Length(FSource)) and (FLowered[Scan].IsLetterOrDigit) do
    Inc(Scan);

  if Scan = NameStart then
  begin
    Result := False;
    Exit;
  end;

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

function THtmlTagReader.ReadText: string;
begin
  const Start = FPosition;
  while not (IsAtEnd or IsAtTag) do
    Inc(FPosition);

  Result := Copy(FSource, Start, FPosition - Start);
end;

// Everything up to the closing tag, as written, stepping past that tag; to
// the end when the element is never closed.
function THtmlTagReader.ReadRawUntil(const ClosingTag: string): string;
begin
  const Closing = '</' + ClosingTag;
  const Found = PosEx(Closing, FLowered, FPosition);
  if Found = 0 then
  begin
    Result := Copy(FSource, FPosition, MaxInt);
    FPosition := Length(FSource) + 1;
    Exit;
  end;

  Result := Copy(FSource, FPosition, Found - FPosition);
  FPosition := Found + Length(Closing);
  const Terminator = PosEx('>', FSource, FPosition);
  if Terminator > 0 then
    FPosition := Terminator + 1;
end;

// Steps past the content of the element and its closing tag.
procedure THtmlTagReader.SkipTo(const ClosingTag: string);
begin
  ReadRawUntil(ClosingTag);
end;

// The lower-cased source from here up to the closing tag, or to the end
// without one, leaving the position where it is.
function THtmlTagReader.LoweredUntil(const ClosingTag: string): string;
begin
  const Closing = '</' + ClosingTag;
  var ContentEnd := PosEx(Closing, FLowered, FPosition);
  const IsClosed = (ContentEnd > 0);
  if not IsClosed then
    ContentEnd := Length(FLowered) + 1;

  Result := Copy(FLowered, FPosition, ContentEnd - FPosition);
end;

{ THtmlTargetFinder }

constructor THtmlTargetFinder.Create(const Html: string);
begin
  inherited Create;

  FReader := THtmlTagReader.Create(Html);
end;

destructor THtmlTargetFinder.Destroy;
begin
  FReader.Free;

  inherited;
end;

function THtmlTargetFinder.TryFind(const Name: string; out Position: Integer): Boolean;
begin
  Position := 0;

  while not FReader.IsAtEnd do
  begin
    if not FReader.IsAtTag then
    begin
      FReader.Advance;
      Continue;
    end;

    const TagStart = FReader.Position;
    var Tag: TParsedTag;
    if not FReader.TryReadTag(Tag) then
    begin
      const IsStuck = (FReader.Position = TagStart);
      if IsStuck then
        FReader.Advance;
      Continue;
    end;

    try
      if IsTargetNamed(Tag, Name) then
      begin
        Position := TagStart;
        Result := True;
        Exit;
      end;

      SkipRawText(Tag);
    finally
      Tag.Attributes.Free;
    end;
  end;

  Result := False;
end;

class function THtmlTargetFinder.IsTargetNamed(const Tag: TParsedTag; const Name: string): Boolean;
begin
  const IsAnchor = (Tag.Name = AnchorTag);
  const HasId = HasAttributeValue(Tag, IdAttribute, Name);
  const HasAnchorName = (IsAnchor and HasAttributeValue(Tag, NameAttribute, Name));
  Result := ((not Tag.IsClosing) and (HasId or HasAnchorName));
end;

class function THtmlTargetFinder.HasAttributeValue(const Tag: TParsedTag; const Attribute, Value: string): Boolean;
begin
  var Written: string;
  const HasAttribute = Tag.Attributes.TryGetValue(Attribute, Written);
  Result := (HasAttribute and (THtmlTagReader.DecodeEntities(Written) = Value));
end;

// What <script> and the like hold is text, not markup, so a tag in it is no
// target.
procedure THtmlTargetFinder.SkipRawText(const Tag: TParsedTag);
begin
  const HoldsContent = ((not Tag.IsClosing) and (not Tag.IsSelfClosing));
  const IsRawText = MatchText(Tag.Name, RawTextTags);
  if HoldsContent and IsRawText then
    FReader.SkipTo(Tag.Name);
end;

{ TSubsetConverter }

constructor TSubsetConverter.Create(const Html: string);
begin
  inherited Create;

  FReader := THtmlTagReader.Create(Html);
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
  FReader.Free;

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
  end
  else if TInlineHtmlTag.EffectOf(Name) <> TInlineHtmlEffect.Hidden then
  begin
    Result.Kind := TTagKind.InlineHtml;
    Result.Opener := Format('<%s>', [Name]);
    Result.Closer := Format('</%s>', [Name]);
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

      if InWhitespace then
        Builder.Append(' ');

      InWhitespace := False;
      Builder.Append(Value[Index]);
    end;

    if InWhitespace then
      Builder.Append(' ');

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TSubsetConverter.FormatDestination(const Value: string): string;
begin
  Result := THtmlTagReader.DecodeEntities(Value).Trim;
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
  FAfterOpener := False;
end;

procedure TSubsetConverter.WriteOpener(const Value: string);
begin
  Write(Value);
  FAfterOpener := True;
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

// <pre> keeps its line breaks and its spacing, so it is read raw and emitted as
// a fenced code block.
function TSubsetConverter.ReadPreformatted: string;
begin
  var Content := FReader.ReadRawUntil('pre');

  // A <code> wrapper inside <pre> is conventional and carries nothing extra.
  Content := Content.Replace('<code>', '', [rfReplaceAll, rfIgnoreCase]);
  Content := Content.Replace('</code>', '', [rfReplaceAll, rfIgnoreCase]);

  Result := THtmlTagReader.DecodeEntities(Content).Trim([LineFeed, CarriageReturn, ' ']);
end;

procedure TSubsetConverter.HandleImage(const Tag: TParsedTag);
begin
  var Source := '';
  if not Tag.Attributes.TryGetValue('src', Source) or (Source.Trim = '') then
    Exit;

  var AltText := '';
  Tag.Attributes.TryGetValue('alt', AltText);

  Write(Format('![%s](%s)', [EscapeText(THtmlTagReader.DecodeEntities(AltText)), FormatDestination(Source)]));
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

// A summary that is exactly one heading shows as that heading, as GitHub sets
// it next to the triangle, instead of as bold text around a heading block.
function TSubsetConverter.IsHeadingSummary: Boolean;
begin
  const Content = FReader.LoweredUntil('summary');
  const Inner = Content.Trim;
  const IsOneHeading = TRegEx.IsMatch(Inner, '^<h([1-6])[\s>].*</h\1\s*>$', [roSingleLine]);
  const HeadingTags = TRegEx.Matches(Inner, '<h[1-6][\s>]');
  Result := (IsOneHeading and (HeadingTags.Count = 1));
end;

procedure TSubsetConverter.HandleOpenTag(const Tag: TParsedTag);
begin
  const Info = TagInfoOf(Tag.Name);

  case Info.Kind of
    TTagKind.Dropped:
      begin
        if not Tag.IsSelfClosing then
          FReader.SkipTo(Tag.Name);
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

    TTagKind.Summary:
      begin
        if IsHeadingSummary then
        begin
          StartBlock;
          FOpen.Add(TOpenTag.Create(Tag.Name, Info.Kind, ''));
          Exit;
        end;
      end;

    TTagKind.Preformatted:
      begin
        StartBlock;
        const Content = ReadPreformatted;
        if Content <> '' then
        begin
          Write('```');
          StartLine;
          for var Line in Content.Split([LineFeed]) do
          begin
            Write(Line.TrimRight([CarriageReturn]));
            StartLine;
          end;
          Write('```');
          StartLine;
          FPendingBlank := True;
        end;
        Exit;
      end;
  else
    // Every other kind (Transparent, Paragraph, headings, inline styles,
    // anchors, Details, ...) and a summary with more than a heading share the
    // generic block/opener/closer handling below.
  end;

  if Info.IsBlock then
    StartBlock;

  if Info.Opener <> '' then
    WriteOpener(Info.Opener);

  if Info.Kind = TTagKind.Anchor then
  begin
    var Destination := '';
    Tag.Attributes.TryGetValue('href', Destination);
    if Destination.Trim <> '' then
    begin
      WriteOpener('[');
      FOpen.Add(TOpenTag.Create(Tag.Name, Info.Kind, Format('](%s)', [FormatDestination(Destination)])));
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
    else
      // Inline kinds (Strong, Emphasis, CodeSpan, Strikethrough, Anchor, ...)
      // only need their Closer text, already written above; nothing more to do.
    end;
  end;
end;

function TSubsetConverter.Convert: string;
begin
  while not FReader.IsAtEnd do
  begin
    if FReader.IsAtTag then
    begin
      var Tag: TParsedTag;
      const Before = FReader.Position;
      if FReader.TryReadTag(Tag) then
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
      else if FReader.Position = Before then
      begin
        // Not a tag after all; treat the character as text.
        Write(EscapeText('<'));
        FReader.Advance;
      end;

      Continue;
    end;

    var Text := NormalizeWhitespace(THtmlTagReader.DecodeEntities(FReader.ReadText));

    // A space at the start of a line would indent it, and one right after **
    // or [ stops markdown from seeing the emphasis or the link.
    const DropsLeadingSpace = (FAtLineStart or FAfterOpener);
    if DropsLeadingSpace then
      Text := Text.TrimLeft;

    if Text <> '' then
      Write(EscapeText(Text));
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

class function TMarkdownHtmlSubset.BlockAlignment(const Html: string): TMarkdownHtmlAlignment;
begin
  Result := TMarkdownHtmlAlignment.None;

  const Opening = TRegEx.Match(Html, OpeningTagPattern);
  if not Opening.Success then
    Exit;

  const TagName = Opening.Groups[1].Value;
  const IsCenterTag = SameText(TagName, CenterTag);
  if IsCenterTag then
    Exit(TMarkdownHtmlAlignment.Center);

  const Attributes = Opening.Groups[2].Value;
  const Align = TRegEx.Match(Attributes, AlignPattern, [roIgnoreCase]);
  if Align.Success then
    Result := AlignmentNamed(Align.Groups[1].Value);
end;

class function TMarkdownHtmlSubset.TryFindTarget(const Html, Name: string; out Position: Integer): Boolean;
begin
  Position := 0;
  Result := False;
  if Name.IsEmpty then
    Exit;

  const Finder = THtmlTargetFinder.Create(Html);
  try
    Result := Finder.TryFind(Name, Position);
  finally
    Finder.Free;
  end;
end;

class function TMarkdownHtmlSubset.AlignmentNamed(const Name: string): TMarkdownHtmlAlignment;
begin
  const Lowered = Name.ToLower;
  if Lowered = 'center' then
    Result := TMarkdownHtmlAlignment.Center
  else if Lowered = 'right' then
    Result := TMarkdownHtmlAlignment.Right
  else
    Result := TMarkdownHtmlAlignment.Left;
end;

end.
