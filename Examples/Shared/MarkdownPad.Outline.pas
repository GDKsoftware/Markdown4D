unit MarkdownPad.Outline;

// Turns a parsed table of contents into the flat, indented list both pad builds
// show in their Contents panel, and locates the active entry for a source line.

interface

uses
  System.SysUtils,
  Markdown4D.Toc;

type
  TPadOutline = record
    Entries: TArray<IMarkdownTocEntry>;
    Captions: TArray<string>;
  end;

  TPadOutlineBuilder = record
    class function Build(const Toc: IMarkdownToc): TPadOutline; static;
    class function ActiveIndex(const Entries: TArray<IMarkdownTocEntry>;
      const SourceLine: Integer): Integer; static;
  end;

implementation

class function TPadOutlineBuilder.Build(const Toc: IMarkdownToc): TPadOutline;
begin
  Result.Entries := [];
  Result.Captions := [];

  var Stack: TArray<IMarkdownTocEntry> := [];
  for var Index := Toc.EntryCount - 1 downto 0 do
    Stack := Stack + [Toc.Entries[Index]];

  while Length(Stack) > 0 do
  begin
    const Entry = Stack[High(Stack)];
    SetLength(Stack, Length(Stack) - 1);

    Result.Entries := Result.Entries + [Entry];
    Result.Captions := Result.Captions +
      [Format('%s%s', [StringOfChar(' ', 2 * (Entry.Level - 1)), Entry.Caption])];

    for var Index := Entry.ChildCount - 1 downto 0 do
      Stack := Stack + [Entry.Children[Index]];
  end;
end;

class function TPadOutlineBuilder.ActiveIndex(const Entries: TArray<IMarkdownTocEntry>;
  const SourceLine: Integer): Integer;
begin
  Result := -1;

  for var Index := 0 to High(Entries) do
  begin
    if Entries[Index].SourceLine - 1 <= SourceLine then
      Result := Index;
  end;
end;

end.
