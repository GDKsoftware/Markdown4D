unit Markdown4D.Parser.LineScanner;

{$SCOPEDENUMS ON}

interface

type
  TLineScannerState = record
    Index: Integer;
    Column: Integer;
    PartiallyConsumedTab: Boolean;
  end;

  TLineScanner = class
  private
    const
      TabStop = 4;
      Space = ' ';
      Tab = #9;
    var
      FLine: string;
      FIndex: Integer;
      FColumn: Integer;
      FPartiallyConsumedTab: Boolean;
      FNextNonSpaceIndex: Integer;
      FNextNonSpaceColumn: Integer;
    class function ColumnAfterTab(const Column: Integer): Integer;

  public
    class function IsSpaceOrTab(const Value: Char): Boolean;
    procedure Reset(const Line: string);
    procedure FindNextNonSpace;
    function Indent: Integer;
    function IsBlank: Boolean;
    function NextChar: Char;
    function CharAt(const Index: Integer): Char;
    procedure AdvanceOffset(const Count: Integer; const ByColumns: Boolean);
    procedure AdvanceNextNonSpace;
    procedure AdvanceToLineEnd;
    function RestOfLine: string;
    function TextFrom(const Index: Integer): string;
    function SaveState: TLineScannerState;
    procedure RestoreState(const State: TLineScannerState);
    property Line: string read FLine;
    property Offset: Integer read FIndex;
    property Column: Integer read FColumn;
    property NextNonSpaceIndex: Integer read FNextNonSpaceIndex;
  end;

implementation

procedure TLineScanner.Reset(const Line: string);
begin
  FLine := Line;
  FIndex := 1;
  FColumn := 0;
  FPartiallyConsumedTab := False;

  FindNextNonSpace;
end;

function TLineScanner.Indent: Integer;
begin
  Result := FNextNonSpaceColumn - FColumn;
end;

function TLineScanner.IsBlank: Boolean;
begin
  Result := (FNextNonSpaceIndex > Length(FLine));
end;

function TLineScanner.NextChar: Char;
begin
  if IsBlank then
    Exit(#0);

  Result := FLine[FNextNonSpaceIndex];
end;

function TLineScanner.CharAt(const Index: Integer): Char;
begin
  const OutOfRange = (Index < 1) or (Index > Length(FLine));
  if OutOfRange then
    Exit(#0);

  Result := FLine[Index];
end;

procedure TLineScanner.AdvanceNextNonSpace;
begin
  FIndex := FNextNonSpaceIndex;
  FColumn := FNextNonSpaceColumn;
  FPartiallyConsumedTab := False;
end;

procedure TLineScanner.AdvanceToLineEnd;
begin
  AdvanceOffset(Length(FLine) - FIndex + 1, False);
end;

procedure TLineScanner.AdvanceOffset(const Count: Integer; const ByColumns: Boolean);
begin
  var Remaining := Count;

  while (Remaining > 0) and (FIndex <= Length(FLine)) do
  begin
    const Current = FLine[FIndex];

    if Current = Tab then
    begin
      const CharsToTab = ColumnAfterTab(FColumn) - FColumn;

      if ByColumns then
      begin
        FPartiallyConsumedTab := (CharsToTab > Remaining);

        var CharsToAdvance := CharsToTab;
        if FPartiallyConsumedTab then
          CharsToAdvance := Remaining;

        Inc(FColumn, CharsToAdvance);
        Dec(Remaining, CharsToAdvance);

        if not FPartiallyConsumedTab then
          Inc(FIndex);
      end
      else
      begin
        FPartiallyConsumedTab := False;
        Inc(FColumn, CharsToTab);
        Inc(FIndex);
        Dec(Remaining);
      end;
    end
    else
    begin
      FPartiallyConsumedTab := False;
      Inc(FIndex);
      Inc(FColumn);
      Dec(Remaining);
    end;
  end;

  FindNextNonSpace;
end;

function TLineScanner.RestOfLine: string;
begin
  if FPartiallyConsumedTab then
  begin
    const CharsToTab = ColumnAfterTab(FColumn) - FColumn;

    Exit(StringOfChar(Space, CharsToTab) + Copy(FLine, FIndex + 1, MaxInt));
  end;

  Result := Copy(FLine, FIndex, MaxInt);
end;

function TLineScanner.TextFrom(const Index: Integer): string;
begin
  Result := Copy(FLine, Index, MaxInt);
end;

function TLineScanner.SaveState: TLineScannerState;
begin
  Result.Index := FIndex;
  Result.Column := FColumn;
  Result.PartiallyConsumedTab := FPartiallyConsumedTab;
end;

procedure TLineScanner.RestoreState(const State: TLineScannerState);
begin
  FIndex := State.Index;
  FColumn := State.Column;
  FPartiallyConsumedTab := State.PartiallyConsumedTab;

  FindNextNonSpace;
end;

procedure TLineScanner.FindNextNonSpace;
begin
  var Index := FIndex;
  var Column := FColumn;

  while (Index <= Length(FLine)) and IsSpaceOrTab(FLine[Index]) do
  begin
    if FLine[Index] = Tab then
      Column := ColumnAfterTab(Column)
    else
      Inc(Column);

    Inc(Index);
  end;

  FNextNonSpaceIndex := Index;
  FNextNonSpaceColumn := Column;
end;

class function TLineScanner.IsSpaceOrTab(const Value: Char): Boolean;
begin
  Result := (Value = Space) or (Value = Tab);
end;

class function TLineScanner.ColumnAfterTab(const Column: Integer): Integer;
begin
  Result := Column + (TabStop - (Column mod TabStop));
end;

end.
