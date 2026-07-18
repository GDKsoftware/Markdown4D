unit Markdown4D.Parser.LineReader;

{$SCOPEDENUMS ON}

interface

type
  TSourceLine = record
    Text: string;
    StartOffset: Integer;
    EndOffset: Integer;
  end;

  TLineReader = class
  private
    FSource: string;
    FPosition: Integer;

  public
    constructor Create(const Source: string);
    function TryReadLine(out Line: TSourceLine): Boolean;
  end;

implementation

uses
  Markdown4D.Defines;

constructor TLineReader.Create(const Source: string);
begin
  inherited Create;

  FSource := Source;
  FPosition := 1;
end;

function TLineReader.TryReadLine(out Line: TSourceLine): Boolean;
begin
  const SourceLength = Length(FSource);
  const HasMore = (FPosition <= SourceLength);
  if not HasMore then
    Exit(False);

  var Index := FPosition;

  while (Index <= SourceLength) and (FSource[Index] <> LineFeed) and (FSource[Index] <> #13) do
  begin
    Inc(Index);
  end;

  Line.StartOffset := FPosition;
  Line.EndOffset := Index;
  Line.Text := Copy(FSource, FPosition, Index - FPosition);

  const HasCarriageReturn = (Index <= SourceLength) and (FSource[Index] = #13);
  if HasCarriageReturn then
    Inc(Index);

  const HasLineFeed = (Index <= SourceLength) and (FSource[Index] = LineFeed);
  if HasLineFeed then
    Inc(Index);

  FPosition := Index;
  Result := True;
end;

end.
