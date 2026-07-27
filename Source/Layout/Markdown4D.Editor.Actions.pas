unit Markdown4D.Editor.Actions;

{$SCOPEDENUMS ON}

// Editing behaviour that is about the text, not about the screen: block indent,
// block outdent and the line break that continues what the current line started.
// Framework-neutral by construction, so every host editor behaves the same.

interface

uses
  Markdown4D.Editor.Model;

type
  TMarkdownEditorActions = record
  strict private
    class function LineTextAt(const Model: TMarkdownEditorModel; const LineIndex: Integer): string; static;
    class function LineEndOffset(const Model: TMarkdownEditorModel; const LineIndex: Integer): Integer; static;
    class procedure ReplaceLines(const Model: TMarkdownEditorModel; const FirstLine, LastLine: Integer;
      const Lines: TArray<string>); static;
    class function LeadingWhitespace(const Line: string): string; static;
    class function ListContinuation(const Line: string; out MarkerLength: Integer): string; static;
    class function BulletContinuation(const Line: string; const IndentLength: Integer;
      out MarkerLength: Integer): string; static;
    class function OrderedContinuation(const Line: string; const IndentLength: Integer;
      out MarkerLength: Integer): string; static;
    class function QuoteContinuation(const Line: string; const IndentLength: Integer;
      out MarkerLength: Integer): string; static;
    class function IsBlankAfter(const Line: string; const Offset: Integer): Boolean; static;
    class function OutdentedLine(const Line: string; const IndentWidth: Integer): string; static;
  public
    // Shifts every line the selection touches one indent step. A selection that
    // stays within one line is replaced by the indent, the way a plain editor
    // treats Tab.
    class procedure Indent(const Model: TMarkdownEditorModel; const IndentWidth: Integer); static;
    class procedure Outdent(const Model: TMarkdownEditorModel; const IndentWidth: Integer); static;
    // Enter that keeps the shape of the current line: its indent, and its list
    // or quote marker. An empty list item is cleared instead of continued.
    class procedure InsertLineBreak(const Model: TMarkdownEditorModel); static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Character,
  Markdown4D.Defines;

const
  BulletMarkers = ['-', '*', '+'];
  OrderedSuffixes = ['.', ')'];
  TaskOpen = '[ ] ';
  TaskDone = '[x] ';
  QuoteMarker = '>';

class procedure TMarkdownEditorActions.Indent(const Model: TMarkdownEditorModel; const IndentWidth: Integer);
begin
  const Step = StringOfChar(Space, Max(IndentWidth, 1));

  const SelectionEnd = Model.SelectionStart + Model.SelectionLength;
  const FirstLine = Model.LineIndexOfOffset(Model.SelectionStart);
  const LastLine = Model.LineIndexOfOffset(Max(SelectionEnd - 1, Model.SelectionStart));

  const SingleLine = FirstLine = LastLine;
  if SingleLine then
  begin
    Model.Insert(Step);
    Exit;
  end;

  var Lines: TArray<string> := [];
  for var LineIndex := FirstLine to LastLine do
    Lines := Lines + [Step + LineTextAt(Model, LineIndex)];

  ReplaceLines(Model, FirstLine, LastLine, Lines);
end;

class procedure TMarkdownEditorActions.Outdent(const Model: TMarkdownEditorModel; const IndentWidth: Integer);
begin
  const SelectionEnd = Model.SelectionStart + Model.SelectionLength;
  const FirstLine = Model.LineIndexOfOffset(Model.SelectionStart);
  const LastLine = Model.LineIndexOfOffset(Max(SelectionEnd - 1, Model.SelectionStart));

  var Lines: TArray<string> := [];
  var Changed := False;

  for var LineIndex := FirstLine to LastLine do
  begin
    const Original = LineTextAt(Model, LineIndex);
    const Shortened = OutdentedLine(Original, Max(IndentWidth, 1));

    Changed := Changed or (Shortened <> Original);
    Lines := Lines + [Shortened];
  end;

  if not Changed then
    Exit;

  ReplaceLines(Model, FirstLine, LastLine, Lines);
end;

class procedure TMarkdownEditorActions.InsertLineBreak(const Model: TMarkdownEditorModel);
begin
  const Caret = Model.SelectionStart;
  const LineIndex = Model.LineIndexOfOffset(Caret);
  const LineStart = Model.OffsetOfLineStart(LineIndex);
  const Line = LineTextAt(Model, LineIndex);
  const CaretColumn = Caret - LineStart;

  var MarkerLength := 0;
  const Continuation = ListContinuation(Line, MarkerLength);

  // An empty list item means the user is done with the list: Enter wipes the
  // marker instead of producing another one.
  const OnEmptyItem = (MarkerLength > 0) and (CaretColumn >= MarkerLength) and IsBlankAfter(Line, MarkerLength);
  if OnEmptyItem then
  begin
    Model.SetSelection(LineStart, Length(Line));
    Model.Insert(LineFeed);
    Exit;
  end;

  const Prefix = Copy(Continuation, 1, Min(Length(Continuation), Max(CaretColumn, 0)));
  Model.Insert(LineFeed + Prefix);
end;

class function TMarkdownEditorActions.LineTextAt(const Model: TMarkdownEditorModel;
  const LineIndex: Integer): string;
begin
  const StartOffset = Model.OffsetOfLineStart(LineIndex);
  Result := Copy(Model.Text, StartOffset + 1, LineEndOffset(Model, LineIndex) - StartOffset);
end;

class function TMarkdownEditorActions.LineEndOffset(const Model: TMarkdownEditorModel;
  const LineIndex: Integer): Integer;
begin
  if LineIndex < Model.LineCount - 1 then
    Exit(Model.OffsetOfLineStart(LineIndex + 1) - 1);

  Result := Length(Model.Text);
end;

class procedure TMarkdownEditorActions.ReplaceLines(const Model: TMarkdownEditorModel;
  const FirstLine, LastLine: Integer; const Lines: TArray<string>);
begin
  const RegionStart = Model.OffsetOfLineStart(FirstLine);
  const RegionEnd = LineEndOffset(Model, LastLine);
  const Block = string.Join(LineFeed, Lines);

  Model.ReplaceRange(RegionStart, RegionEnd - RegionStart, Block);
  Model.SetSelection(RegionStart, Length(Block));
end;

class function TMarkdownEditorActions.LeadingWhitespace(const Line: string): string;
begin
  var Count := 0;
  while (Count < Length(Line)) and ((Line[Count + 1] = Space) or (Line[Count + 1] = Tab)) do
    Inc(Count);

  Result := Copy(Line, 1, Count);
end;

class function TMarkdownEditorActions.ListContinuation(const Line: string; out MarkerLength: Integer): string;
begin
  const Indent = LeadingWhitespace(Line);
  const IndentLength = Length(Indent);

  Result := BulletContinuation(Line, IndentLength, MarkerLength);
  if MarkerLength > 0 then
    Exit;

  Result := OrderedContinuation(Line, IndentLength, MarkerLength);
  if MarkerLength > 0 then
    Exit;

  Result := QuoteContinuation(Line, IndentLength, MarkerLength);
  if MarkerLength > 0 then
    Exit;

  MarkerLength := 0;
  Result := Indent;
end;

class function TMarkdownEditorActions.BulletContinuation(const Line: string; const IndentLength: Integer;
  out MarkerLength: Integer): string;
begin
  MarkerLength := 0;
  Result := '';

  const HasMarker = (Length(Line) > IndentLength + 1) and CharInSet(Line[IndentLength + 1], BulletMarkers) and
    (Line[IndentLength + 2] = Space);
  if not HasMarker then
    Exit;

  var Marker := Copy(Line, IndentLength + 1, 2);
  MarkerLength := IndentLength + 2;

  const Rest = Copy(Line, MarkerLength + 1, Length(Line) - MarkerLength);
  const IsTask = Rest.StartsWith(TaskOpen) or Rest.StartsWith(TaskDone);
  if IsTask then
  begin
    Marker := Marker + TaskOpen;
    MarkerLength := MarkerLength + Length(TaskOpen);
  end;

  Result := Copy(Line, 1, IndentLength) + Marker;
end;

class function TMarkdownEditorActions.OrderedContinuation(const Line: string; const IndentLength: Integer;
  out MarkerLength: Integer): string;
begin
  MarkerLength := 0;
  Result := '';

  var DigitCount := 0;
  while (IndentLength + DigitCount < Length(Line)) and Line[IndentLength + DigitCount + 1].IsDigit do
    Inc(DigitCount);

  const HasMarker = (DigitCount > 0) and (Length(Line) > IndentLength + DigitCount + 1) and
    CharInSet(Line[IndentLength + DigitCount + 1], OrderedSuffixes) and
    (Line[IndentLength + DigitCount + 2] = Space);
  if not HasMarker then
    Exit;

  const Number = StrToInt64Def(Copy(Line, IndentLength + 1, DigitCount), 0);
  const Suffix = Line[IndentLength + DigitCount + 1];

  MarkerLength := IndentLength + DigitCount + 2;
  Result := Copy(Line, 1, IndentLength) + IntToStr(Number + 1) + Suffix + Space;
end;

class function TMarkdownEditorActions.QuoteContinuation(const Line: string; const IndentLength: Integer;
  out MarkerLength: Integer): string;
begin
  MarkerLength := 0;
  Result := '';

  var MarkerCount := 0;
  while (IndentLength + MarkerCount < Length(Line)) and (Line[IndentLength + MarkerCount + 1] = QuoteMarker) do
    Inc(MarkerCount);

  if MarkerCount = 0 then
    Exit;

  MarkerLength := IndentLength + MarkerCount;

  const FollowedBySpace = (Length(Line) > MarkerLength) and (Line[MarkerLength + 1] = Space);
  if FollowedBySpace then
    Inc(MarkerLength);

  Result := Copy(Line, 1, MarkerLength);
end;

class function TMarkdownEditorActions.IsBlankAfter(const Line: string; const Offset: Integer): Boolean;
begin
  for var Index := Offset + 1 to Length(Line) do
  begin
    if not Line[Index].IsWhiteSpace then
      Exit(False);
  end;

  Result := True;
end;

class function TMarkdownEditorActions.OutdentedLine(const Line: string; const IndentWidth: Integer): string;
begin
  if Line.StartsWith(Tab) then
    Exit(Copy(Line, 2, Length(Line) - 1));

  var Removable := 0;
  while (Removable < IndentWidth) and (Removable < Length(Line)) and (Line[Removable + 1] = Space) do
    Inc(Removable);

  Result := Copy(Line, Removable + 1, Length(Line) - Removable);
end;

end.
