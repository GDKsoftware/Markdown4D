unit Markdown4D.Parser.SourceMap;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections;

type
  // Maps a position in the text a block hands to the inline parser back to the
  // position of the same character in the markdown source. A block strips the
  // markers that opened it, and strips a different number of them on every
  // line, so one entry per line records where that line's text came from.
  TMarkdownContentSourceMap = class
  private
    type
      TLineOrigin = record
        ContentStart: Integer;
        SourceStart: Integer;
      end;
    var
      FLines: TList<TLineOrigin>;
    procedure ShiftLines(const Count: Integer);
    procedure DropCoveredLines;
    function IndexOfLineAt(const ContentIndex: Integer): Integer;

  public
    const
      // Answers a position the block rewrote on the way in, such as a tab it
      // replaced by the spaces it stands for. Nothing on such a line maps back.
      UnknownOffset = 0;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    // SourceStart is where ContentStart came from, both 1-based, or
    // UnknownOffset when the line no longer matches its source character for
    // character. Lines arrive in content order.
    procedure AddLine(const ContentStart, SourceStart: Integer);
    // Follows the block dropping Count characters off the front of its content.
    procedure DropLeading(const Count: Integer);
    function SourceOffsetOf(const ContentIndex: Integer): Integer;
  end;

implementation

constructor TMarkdownContentSourceMap.Create;
begin
  inherited Create;

  FLines := TList<TLineOrigin>.Create;
end;

destructor TMarkdownContentSourceMap.Destroy;
begin
  FLines.Free;

  inherited Destroy;
end;

procedure TMarkdownContentSourceMap.Clear;
begin
  FLines.Clear;
end;

procedure TMarkdownContentSourceMap.AddLine(const ContentStart, SourceStart: Integer);
begin
  var Line: TLineOrigin;
  Line.ContentStart := ContentStart;
  Line.SourceStart := SourceStart;

  FLines.Add(Line);
end;

procedure TMarkdownContentSourceMap.DropLeading(const Count: Integer);
begin
  if Count <= 0 then
    Exit;

  ShiftLines(Count);
  DropCoveredLines;
end;

procedure TMarkdownContentSourceMap.ShiftLines(const Count: Integer);
begin
  for var Index := 0 to FLines.Count - 1 do
  begin
    var Line := FLines[Index];
    Line.ContentStart := Line.ContentStart - Count;

    const StartsBeforeContent = (Line.ContentStart < 1);
    if StartsBeforeContent then
    begin
      const Missing = 1 - Line.ContentStart;
      Line.ContentStart := 1;

      if Line.SourceStart <> UnknownOffset then
        Line.SourceStart := Line.SourceStart + Missing;
    end;

    FLines[Index] := Line;
  end;
end;

// Every line the drop swallowed whole now claims to start at 1. Only the last
// of them still holds a character, so the ones before it go.
procedure TMarkdownContentSourceMap.DropCoveredLines;
begin
  while (FLines.Count > 1) and (FLines[1].ContentStart <= 1) do
  begin
    FLines.Delete(0);
  end;
end;

function TMarkdownContentSourceMap.SourceOffsetOf(const ContentIndex: Integer): Integer;
begin
  const LineIndex = IndexOfLineAt(ContentIndex);
  if LineIndex < 0 then
  begin
    Result := UnknownOffset;
    Exit;
  end;

  const Line = FLines[LineIndex];
  if Line.SourceStart = UnknownOffset then
  begin
    Result := UnknownOffset;
    Exit;
  end;

  Result := Line.SourceStart + (ContentIndex - Line.ContentStart);
end;

function TMarkdownContentSourceMap.IndexOfLineAt(const ContentIndex: Integer): Integer;
begin
  Result := -1;

  var FirstIndex := 0;
  var LastIndex := FLines.Count - 1;

  while FirstIndex <= LastIndex do
  begin
    const Middle = FirstIndex + ((LastIndex - FirstIndex) div 2);

    if FLines[Middle].ContentStart <= ContentIndex then
    begin
      Result := Middle;
      FirstIndex := Middle + 1;
    end
    else
    begin
      LastIndex := Middle - 1;
    end;
  end;
end;

end.
