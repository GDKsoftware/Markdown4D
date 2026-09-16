unit Markdown4DStudio.Outline;

// Turns a parsed table of contents into the flat, indented list both studio builds
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

uses
  System.Generics.Collections;

class function TPadOutlineBuilder.Build(const Toc: IMarkdownToc): TPadOutline;
begin
  const Entries = TList<IMarkdownTocEntry>.Create;
  const Captions = TList<string>.Create;
  try
    // Depth-first flattening, so a heading always comes right before its own
    // children: a plain array-of-array-concat here would reallocate and copy
    // on every heading, which gets expensive on a document with many of them.
    const Stack = TList<IMarkdownTocEntry>.Create;
    try
      for var Index := Toc.EntryCount - 1 downto 0 do
      begin
        Stack.Add(Toc.Entries[Index]);
      end;

      while Stack.Count > 0 do
      begin
        const Entry = Stack[Stack.Count - 1];
        Stack.Delete(Stack.Count - 1);

        Entries.Add(Entry);
        Captions.Add(Format('%s%s', [StringOfChar(' ', 2 * (Entry.Level - 1)), Entry.Caption]));

        for var Index := Entry.ChildCount - 1 downto 0 do
        begin
          Stack.Add(Entry.Children[Index]);
        end;
      end;
    finally
      Stack.Free;
    end;

    Result.Entries := Entries.ToArray;
    Result.Captions := Captions.ToArray;
  finally
    Captions.Free;
    Entries.Free;
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
