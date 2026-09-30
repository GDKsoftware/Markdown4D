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
      // File headers come before the first hunk of a file; inside a hunk a
      // line starting with --- is a removed line whose text starts with --.
      BeforeHunkState = THighlighterRegistry.DefaultState;
      InsideHunkState = BeforeHunkState + 1;
      InsertedMarker = '+';
      DeletedMarker = '-';
      HunkMarker = '@@';
      DiffHeader = 'diff ';
      IndexHeader = 'index ';
      OldFileHeader = '--- ';
      NewFileHeader = '+++ ';
    class function KindOf(const Line: string; const State: Integer): TSyntaxTokenKind; static;
    class function NextStateOf(const Line: string; const State: Integer): Integer; static;
    class function IsFileHeader(const Line: string): Boolean; static;

  public
    function InitialState: Integer;
    function TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
  end;

implementation

uses
  System.SysUtils;

function TDiffSyntaxHighlighter.InitialState: Integer;
begin
  Result := BeforeHunkState;
end;

function TDiffSyntaxHighlighter.TokenizeLine(const Line: string; const State: Integer): TSyntaxLine;
begin
  const IsEmpty = Line.IsEmpty;
  if IsEmpty then
  begin
    Result := TSyntaxLine.Create(nil, State);
    Exit;
  end;

  const Kind = KindOf(Line, State);
  const NextState = NextStateOf(Line, State);
  const Token = TSyntaxToken.Create(Kind, 1, Length(Line));
  Result := TSyntaxLine.Create([Token], NextState);
end;

class function TDiffSyntaxHighlighter.KindOf(const Line: string; const State: Integer): TSyntaxTokenKind;
begin
  const IsBeforeHunk = (State = BeforeHunkState);
  const IsHeader = (Line.StartsWith(DiffHeader) or (IsBeforeHunk and IsFileHeader(Line)));

  if Line.StartsWith(HunkMarker) then
    Result := TSyntaxTokenKind.Directive
  else if IsHeader then
    Result := TSyntaxTokenKind.Comment
  else if Line.StartsWith(InsertedMarker) then
    Result := TSyntaxTokenKind.Inserted
  else if Line.StartsWith(DeletedMarker) then
    Result := TSyntaxTokenKind.Deleted
  else
    Result := TSyntaxTokenKind.PlainText;
end;

// A hunk header starts the changes of a file; a diff line starts the next
// file and with it its headers.
class function TDiffSyntaxHighlighter.NextStateOf(const Line: string; const State: Integer): Integer;
begin
  if Line.StartsWith(HunkMarker) then
    Result := InsideHunkState
  else if Line.StartsWith(DiffHeader) then
    Result := BeforeHunkState
  else
    Result := State;
end;

class function TDiffSyntaxHighlighter.IsFileHeader(const Line: string): Boolean;
begin
  const IsIndexLine = Line.StartsWith(IndexHeader);
  const IsFileLine = (Line.StartsWith(OldFileHeader) or Line.StartsWith(NewFileHeader));
  Result := (IsIndexLine or IsFileLine);
end;

end.
