unit Markdown4D.Parser.Interfaces;

interface

type
  IMarkdownIncrementalParser = interface
    ['{35E81D1A-0056-4A57-B97E-F893032B2BE1}']
    procedure Append(const Chunk: string);
    procedure ReplaceRange(const StartIndex, Count: Integer; const Replacement: string);
    function ToHtml: string;
  end;

implementation

end.
