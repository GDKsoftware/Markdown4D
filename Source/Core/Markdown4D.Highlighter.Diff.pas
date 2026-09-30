unit Markdown4D.Highlighter.Diff;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Highlighter.Interfaces;

type
  // Colours a unified diff by the start of each line, as GitHub, GitLab and
  // the common highlighters do: an added line, a removed line, a hunk header,
  // and the file headers of a git diff, which are muted like a comment.
  TDiffSyntaxHighlighter = class(TInterfacedObject, IMarkdownSyntaxHighlighter)
  private
    const
      InsertedMarker = '+';
      DeletedMarker = '-';
      HunkMarker = '@@';
      DiffHeader = 'diff ';
      IndexHeader = 'index ';
    class function KindOf(const Line: string): TSyntaxTokenKind; static;

  public
    function InitialState: Integer;
    function TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
  end;

implementation

uses
  System.SysUtils;

function TDiffSyntaxHighlighter.InitialState: Integer;
begin
  Result := THighlighterRegistry.DefaultState;
end;

function TDiffSyntaxHighlighter.TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
begin
  if Line = '' then
  begin
    Result := TSyntaxLine.Create(nil, State);
    Exit;
  end;

  const Token = TSyntaxToken.Create(KindOf(Line), 1, Length(Line));
  Result := TSyntaxLine.Create([Token], State);
end;

class function TDiffSyntaxHighlighter.KindOf(const Line: string): TSyntaxTokenKind;
begin
  if Line.StartsWith(HunkMarker) then
    Exit(TSyntaxTokenKind.Directive);

  const IsFileHeader = (Line.StartsWith(DiffHeader) or Line.StartsWith(IndexHeader));
  if IsFileHeader then
    Exit(TSyntaxTokenKind.Comment);

  if Line.StartsWith(InsertedMarker) then
    Exit(TSyntaxTokenKind.Inserted);

  if Line.StartsWith(DeletedMarker) then
    Exit(TSyntaxTokenKind.Deleted);

  Result := TSyntaxTokenKind.PlainText;
end;

end.
