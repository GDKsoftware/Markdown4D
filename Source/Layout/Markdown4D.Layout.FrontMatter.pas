unit Markdown4D.Layout.FrontMatter;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Ast,
  Markdown4D.FrontMatter.Properties;

type
  // Turns a front matter node into a document the layout engine already knows
  // how to lay out: a table without a header row, one row per property with the
  // key in bold on the left and the value on the right, and every item of a
  // list value as a code span of its own, so it shows as a separate chip. YAML
  // beyond the simple subset becomes a yaml code block with the raw text.
  TLayoutFrontMatter = class
  private
    const
      YamlInfoString = 'yaml';
      ItemSeparator = ' ';
    class function TableDocument(const Properties: TArray<TFrontMatterProperty>): IMarkdownDocument; static;
    class function PropertyRow(const Entry: TFrontMatterProperty): TMarkdownTableRowNode; static;
    class function KeyCell(const Key: string): TMarkdownTableCellNode; static;
    class function ValueCell(const Entry: TFrontMatterProperty): TMarkdownTableCellNode; static;
    class procedure AddListItems(const Cell: TMarkdownTableCellNode; const Items: TArray<string>); static;
    class function SourceDocument(const RawText: string): IMarkdownDocument; static;

  public
    class function ToDocument(const Node: IMarkdownFrontMatter): IMarkdownDocument; static;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Defines;

class function TLayoutFrontMatter.ToDocument(const Node: IMarkdownFrontMatter): IMarkdownDocument;
begin
  var Properties: TArray<TFrontMatterProperty>;
  if TFrontMatterProperties.TryParse(Node.RawText, Properties) then
  begin
    Result := TableDocument(Properties);
    Exit;
  end;

  Result := SourceDocument(Node.RawText);
end;

class function TLayoutFrontMatter.TableDocument(const Properties: TArray<TFrontMatterProperty>): IMarkdownDocument;
begin
  const Document = TMarkdownDocumentNode.Create;
  Result := Document;

  const Table = TMarkdownAstNode.Create(TMarkdownNodeKind.Table);
  Document.AddChild(Table);

  for var Entry in Properties do
  begin
    const Row = PropertyRow(Entry);
    Table.AddChild(Row);
  end;
end;

class function TLayoutFrontMatter.PropertyRow(const Entry: TFrontMatterProperty): TMarkdownTableRowNode;
begin
  const Key = KeyCell(Entry.Key);
  const Value = ValueCell(Entry);

  Result := TMarkdownTableRowNode.Create(False);
  Result.AddChild(Key);
  Result.AddChild(Value);
end;

class function TLayoutFrontMatter.KeyCell(const Key: string): TMarkdownTableCellNode;
begin
  Result := TMarkdownTableCellNode.Create(TMarkdownTableColumnAlignment.None);

  const KeyText = TMarkdownTextNode.Create(TMarkdownNodeKind.Text, Key);
  const Strong = TMarkdownAstNode.Create(TMarkdownNodeKind.Strong);
  Strong.AddChild(KeyText);
  Result.AddChild(Strong);
end;

class function TLayoutFrontMatter.ValueCell(const Entry: TFrontMatterProperty): TMarkdownTableCellNode;
begin
  Result := TMarkdownTableCellNode.Create(TMarkdownTableColumnAlignment.None);

  if Entry.IsList then
  begin
    AddListItems(Result, Entry.Values);
    Exit;
  end;

  const Value = string.Join(ItemSeparator, Entry.Values);
  const HasValue = (Value <> '');
  if not HasValue then
    Exit;

  const ValueText = TMarkdownTextNode.Create(TMarkdownNodeKind.Text, Value);
  Result.AddChild(ValueText);
end;

// The items stand apart by a space, so the row wraps between two chips rather
// than inside one.
class procedure TLayoutFrontMatter.AddListItems(const Cell: TMarkdownTableCellNode; const Items: TArray<string>);
begin
  for var Index := 0 to High(Items) do
  begin
    const IsFollowUp = (Index > 0);
    if IsFollowUp then
    begin
      const Separator = TMarkdownTextNode.Create(TMarkdownNodeKind.Text, ItemSeparator);
      Cell.AddChild(Separator);
    end;

    const Chip = TMarkdownTextNode.Create(TMarkdownNodeKind.CodeSpan, Items[Index]);
    Cell.AddChild(Chip);
  end;
end;

class function TLayoutFrontMatter.SourceDocument(const RawText: string): IMarkdownDocument;
begin
  const Document = TMarkdownDocumentNode.Create;
  Result := Document;

  const Code = RawText + LineFeed;
  const CodeBlock = TMarkdownCodeBlockNode.Create(Code, YamlInfoString, True);
  Document.AddChild(CodeBlock);
end;

end.
