unit Markdown4D.Editor.Model;

{$SCOPEDENUMS ON}

interface

type
  TEditorCommand = (Bold, Italic, Link, CodeBlock);

  TEditorReplaceRange = record
    Start: Integer;
    Length: Integer;
    Replacement: string;
    class function Create(const Start, Length: Integer; const Replacement: string): TEditorReplaceRange; static;
    function Apply(const Source: string): string;
  end;

  TEditorChangeEvent = procedure(const Sender: TObject; const Range: TEditorReplaceRange) of object;

  TMarkdownEditorModel = class
  strict private
    type
      TUndoEntry = record
        Start: Integer;
        RemovedText: string;
        InsertedText: string;
        CaretBefore: Integer;
        AnchorBefore: Integer;
        CaretAfter: Integer;
      end;
      TCharCategory = (Word, Space, Other);
    var
      FText: string;
      FLineStarts: TArray<Integer>;
      FCaret: Integer;
      FAnchor: Integer;
      FUndoStack: TArray<TUndoEntry>;
      FRedoStack: TArray<TUndoEntry>;
      FCoalesceBroken: Boolean;
      FOnChange: TEditorChangeEvent;
    procedure NormalizeAndLoad(const Value: string);
    procedure RebuildLineStarts;
    procedure UpdateLineStartsForEdit(const Start, OldLen: Integer; const Replacement: string);
    procedure DoReplace(const Start, OldLen: Integer; const Replacement: string);
    procedure ApplyReplace(const Start, OldLen: Integer; const Replacement: string; const Coalescable: Boolean);
    procedure RecordUndo(const Start: Integer; const Removed, Inserted: string; const Coalescable: Boolean);
    procedure ApplyCaretMove(const NewCaret: Integer; const Extend: Boolean);
    function NextCaret(const Offset: Integer): Integer;
    function PrevCaret(const Offset: Integer): Integer;
    function ClampOffset(const Offset: Integer): Integer;
    function SnapOffset(const Offset: Integer): Integer;
    function IsWordChar(const Ch: Char): Boolean;
    function CategoryOfChar(const Ch: Char): TCharCategory;
    procedure WrapOrToggle(const Marker: string);
    procedure InsertLink;
    procedure WrapCodeBlock;
    function GetText: string;
    procedure SetText(const Value: string);
    function GetCaretPosition: Integer;
    procedure SetCaretPosition(const Value: Integer);
    function GetSelectionStart: Integer;
    function GetSelectionLength: Integer;
    function GetSelectedText: string;
    function GetOnChange: TEditorChangeEvent;
    procedure SetOnChange(const Value: TEditorChangeEvent);

  public
    constructor Create;
    procedure LoadText(const Value: string);
    function LineCount: Integer;
    function LineIndexOfOffset(const Offset: Integer): Integer;
    function OffsetOfLineStart(const LineIndex: Integer): Integer;
    procedure Insert(const Value: string);
    procedure DeleteBackward;
    procedure DeleteForward;
    procedure ReplaceRange(const Start, Length: Integer; const Replacement: string);
    procedure MoveCaret(const Delta: Integer; const Extend: Boolean);
    procedure MoveWordLeft(const Extend: Boolean);
    procedure MoveWordRight(const Extend: Boolean);
    procedure SelectAll;
    procedure SetSelection(const Start, Length: Integer);
    procedure SelectWordAt(const Offset: Integer);
    procedure SelectLineAt(const Offset: Integer);
    function HasSelection: Boolean;
    procedure Undo;
    procedure Redo;
    function CanUndo: Boolean;
    function CanRedo: Boolean;
    procedure BreakUndoCoalescing;
    procedure ExecuteCommand(const Command: TEditorCommand);
    property Text: string read GetText write SetText;
    property CaretPosition: Integer read GetCaretPosition write SetCaretPosition;
    property SelectionStart: Integer read GetSelectionStart;
    property SelectionLength: Integer read GetSelectionLength;
    property SelectedText: string read GetSelectedText;
    property OnChange: TEditorChangeEvent read GetOnChange write SetOnChange;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Character,
  Markdown4D.Defines;

class function TEditorReplaceRange.Create(const Start, Length: Integer;
  const Replacement: string): TEditorReplaceRange;
begin
  Result.Start := Start;
  Result.Length := Length;
  Result.Replacement := Replacement;
end;

function TEditorReplaceRange.Apply(const Source: string): string;
begin
  Result := Copy(Source, 1, Start) + Replacement + Copy(Source, Start + Length + 1, System.Length(Source));
end;

constructor TMarkdownEditorModel.Create;
begin
  inherited Create;

  FLineStarts := [0];
end;

procedure TMarkdownEditorModel.LoadText(const Value: string);
begin
  NormalizeAndLoad(Value);
end;

function TMarkdownEditorModel.LineCount: Integer;
begin
  Result := System.Length(FLineStarts);
end;

function TMarkdownEditorModel.LineIndexOfOffset(const Offset: Integer): Integer;
begin
  var Lo := 0;
  var Hi := High(FLineStarts);
  Result := 0;
  while Lo <= Hi do
  begin
    const Mid = (Lo + Hi) div 2;
    if FLineStarts[Mid] <= Offset then
    begin
      Result := Mid;
      Lo := Mid + 1;
    end
    else
      Hi := Mid - 1;
  end;
end;

function TMarkdownEditorModel.OffsetOfLineStart(const LineIndex: Integer): Integer;
begin
  const Clamped = EnsureRange(LineIndex, 0, High(FLineStarts));
  Result := FLineStarts[Clamped];
end;

procedure TMarkdownEditorModel.Insert(const Value: string);
begin
  const Start = SelectionStart;
  const Len = SelectionLength;
  ApplyReplace(Start, Len, Value, Len = 0);
end;

procedure TMarkdownEditorModel.DeleteBackward;
begin
  if HasSelection then
  begin
    ApplyReplace(SelectionStart, SelectionLength, '', False);
    Exit;
  end;

  if FCaret <= 0 then
    Exit;

  const Previous = PrevCaret(FCaret);
  ApplyReplace(Previous, FCaret - Previous, '', False);
end;

procedure TMarkdownEditorModel.DeleteForward;
begin
  if HasSelection then
  begin
    ApplyReplace(SelectionStart, SelectionLength, '', False);
    Exit;
  end;

  if FCaret >= System.Length(FText) then
    Exit;

  const Next = NextCaret(FCaret);
  ApplyReplace(FCaret, Next - FCaret, '', False);
end;

procedure TMarkdownEditorModel.ReplaceRange(const Start, Length: Integer; const Replacement: string);
begin
  ApplyReplace(Start, Length, Replacement, False);
end;

procedure TMarkdownEditorModel.MoveCaret(const Delta: Integer; const Extend: Boolean);
begin
  var NewCaret := FCaret;
  if Delta > 0 then
  begin
    for var Step := 1 to Delta do
    begin
      NewCaret := NextCaret(NewCaret);
    end;
  end
  else
  begin
    for var Step := 1 to -Delta do
    begin
      NewCaret := PrevCaret(NewCaret);
    end;
  end;

  ApplyCaretMove(NewCaret, Extend);
end;

procedure TMarkdownEditorModel.MoveWordLeft(const Extend: Boolean);
begin
  var Offset := FCaret;
  while (Offset > 0) and FText[Offset].IsWhiteSpace do
    Dec(Offset);
  while (Offset > 0) and IsWordChar(FText[Offset]) do
    Dec(Offset);

  ApplyCaretMove(Offset, Extend);
end;

procedure TMarkdownEditorModel.MoveWordRight(const Extend: Boolean);
begin
  var Offset := FCaret;
  while (Offset < System.Length(FText)) and IsWordChar(FText[Offset + 1]) do
    Inc(Offset);
  while (Offset < System.Length(FText)) and FText[Offset + 1].IsWhiteSpace do
    Inc(Offset);

  ApplyCaretMove(Offset, Extend);
end;

procedure TMarkdownEditorModel.SelectAll;
begin
  FAnchor := 0;
  FCaret := System.Length(FText);
end;

procedure TMarkdownEditorModel.SetSelection(const Start, Length: Integer);
begin
  FAnchor := SnapOffset(Start);
  FCaret := SnapOffset(Start + Length);
end;

procedure TMarkdownEditorModel.SelectWordAt(const Offset: Integer);
begin
  const Len = System.Length(FText);
  if Len = 0 then
  begin
    SetSelection(0, 0);
    Exit;
  end;

  const Clamped = ClampOffset(Offset);

  var RefIndex := Min(Clamped + 1, Len);
  const PrefersLeft = (Clamped >= 1) and (Clamped < Len) and
    (CategoryOfChar(FText[RefIndex]) = TCharCategory.Space) and
    (CategoryOfChar(FText[Clamped]) <> TCharCategory.Space);
  if PrefersLeft then
    RefIndex := Clamped;

  const Category = CategoryOfChar(FText[RefIndex]);

  var StartIndex := RefIndex;
  while (StartIndex > 1) and (CategoryOfChar(FText[StartIndex - 1]) = Category) do
    Dec(StartIndex);

  var EndIndex := RefIndex;
  while (EndIndex < Len) and (CategoryOfChar(FText[EndIndex + 1]) = Category) do
    Inc(EndIndex);

  SetSelection(StartIndex - 1, EndIndex - StartIndex + 1);
end;

procedure TMarkdownEditorModel.SelectLineAt(const Offset: Integer);
begin
  const Clamped = ClampOffset(Offset);
  const Line = LineIndexOfOffset(Clamped);
  const Start = OffsetOfLineStart(Line);

  var EndOffset: Integer;
  if Line < LineCount - 1 then
    EndOffset := OffsetOfLineStart(Line + 1) - 1
  else
    EndOffset := System.Length(FText);

  SetSelection(Start, EndOffset - Start);
end;

function TMarkdownEditorModel.HasSelection: Boolean;
begin
  Result := FCaret <> FAnchor;
end;

procedure TMarkdownEditorModel.Undo;
begin
  if System.Length(FUndoStack) = 0 then
    Exit;

  const Entry = FUndoStack[High(FUndoStack)];
  SetLength(FUndoStack, System.Length(FUndoStack) - 1);

  DoReplace(Entry.Start, System.Length(Entry.InsertedText), Entry.RemovedText);
  FRedoStack := FRedoStack + [Entry];
  FCaret := Entry.CaretBefore;
  FAnchor := Entry.AnchorBefore;
  FCoalesceBroken := True;
end;

procedure TMarkdownEditorModel.Redo;
begin
  if System.Length(FRedoStack) = 0 then
    Exit;

  const Entry = FRedoStack[High(FRedoStack)];
  SetLength(FRedoStack, System.Length(FRedoStack) - 1);

  DoReplace(Entry.Start, System.Length(Entry.RemovedText), Entry.InsertedText);
  FUndoStack := FUndoStack + [Entry];
  FCaret := Entry.CaretAfter;
  FAnchor := Entry.CaretAfter;
  FCoalesceBroken := True;
end;

function TMarkdownEditorModel.CanUndo: Boolean;
begin
  Result := System.Length(FUndoStack) > 0;
end;

function TMarkdownEditorModel.CanRedo: Boolean;
begin
  Result := System.Length(FRedoStack) > 0;
end;

procedure TMarkdownEditorModel.BreakUndoCoalescing;
begin
  FCoalesceBroken := True;
end;

procedure TMarkdownEditorModel.ExecuteCommand(const Command: TEditorCommand);
begin
  BreakUndoCoalescing;

  case Command of
    TEditorCommand.Bold:
      WrapOrToggle('**');
    TEditorCommand.Italic:
      WrapOrToggle('*');
    TEditorCommand.Link:
      InsertLink;
    TEditorCommand.CodeBlock:
      WrapCodeBlock;
  else
    raise EMarkdownError.CreateFmt('Unhandled command: %d', [Ord(Command)]);
  end;

  BreakUndoCoalescing;
end;

procedure TMarkdownEditorModel.NormalizeAndLoad(const Value: string);
begin
  var Normalized := StringReplace(Value, #13#10, #10, [rfReplaceAll]);
  Normalized := StringReplace(Normalized, #13, #10, [rfReplaceAll]);

  FText := Normalized;
  RebuildLineStarts;
  FCaret := 0;
  FAnchor := 0;
  FUndoStack := nil;
  FRedoStack := nil;
  FCoalesceBroken := False;
end;

procedure TMarkdownEditorModel.RebuildLineStarts;
begin
  FLineStarts := [0];
  for var Index := 1 to System.Length(FText) do
  begin
    if FText[Index] = #10 then
      FLineStarts := FLineStarts + [Index];
  end;
end;

procedure TMarkdownEditorModel.UpdateLineStartsForEdit(const Start, OldLen: Integer; const Replacement: string);
begin
  const Delta = System.Length(Replacement) - OldLen;
  const OldEnd = Start + OldLen;

  var NewStarts: TArray<Integer> := [];
  for var LineStart in FLineStarts do
  begin
    if LineStart <= Start then
      NewStarts := NewStarts + [LineStart];
  end;

  for var Index := 1 to System.Length(Replacement) do
  begin
    if Replacement[Index] = #10 then
      NewStarts := NewStarts + [Start + Index];
  end;

  for var LineStart in FLineStarts do
  begin
    if LineStart > OldEnd then
      NewStarts := NewStarts + [LineStart + Delta];
  end;

  FLineStarts := NewStarts;
end;

procedure TMarkdownEditorModel.DoReplace(const Start, OldLen: Integer; const Replacement: string);
begin
  FText := Copy(FText, 1, Start) + Replacement + Copy(FText, Start + OldLen + 1, System.Length(FText));
  UpdateLineStartsForEdit(Start, OldLen, Replacement);

  if Assigned(FOnChange) then
    FOnChange(Self, TEditorReplaceRange.Create(Start, OldLen, Replacement));
end;

procedure TMarkdownEditorModel.ApplyReplace(const Start, OldLen: Integer; const Replacement: string;
  const Coalescable: Boolean);
begin
  RecordUndo(Start, Copy(FText, Start + 1, OldLen), Replacement, Coalescable);
  DoReplace(Start, OldLen, Replacement);
  FRedoStack := nil;
  FCaret := Start + System.Length(Replacement);
  FAnchor := FCaret;
end;

procedure TMarkdownEditorModel.RecordUndo(const Start: Integer; const Removed, Inserted: string;
  const Coalescable: Boolean);
begin
  const CanMerge = Coalescable and not FCoalesceBroken and (System.Length(FUndoStack) > 0);
  if CanMerge then
  begin
    var Top := FUndoStack[High(FUndoStack)];
    const IsContiguousInsertion = (Removed = '') and (Top.RemovedText = '') and
      (Top.Start + System.Length(Top.InsertedText) = Start);
    if IsContiguousInsertion then
    begin
      Top.InsertedText := Top.InsertedText + Inserted;
      Top.CaretAfter := Start + System.Length(Inserted);
      FUndoStack[High(FUndoStack)] := Top;
      Exit;
    end;
  end;

  var Entry := Default(TUndoEntry);
  Entry.Start := Start;
  Entry.RemovedText := Removed;
  Entry.InsertedText := Inserted;
  Entry.CaretBefore := FCaret;
  Entry.AnchorBefore := FAnchor;
  Entry.CaretAfter := Start + System.Length(Inserted);
  FUndoStack := FUndoStack + [Entry];
  FCoalesceBroken := not Coalescable;
end;

procedure TMarkdownEditorModel.ApplyCaretMove(const NewCaret: Integer; const Extend: Boolean);
begin
  FCaret := NewCaret;
  if not Extend then
    FAnchor := NewCaret;
end;

function TMarkdownEditorModel.NextCaret(const Offset: Integer): Integer;
begin
  if Offset >= System.Length(FText) then
    Exit(System.Length(FText));

  const IsPair = FText[Offset + 1].IsHighSurrogate and (Offset + 2 <= System.Length(FText)) and
    FText[Offset + 2].IsLowSurrogate;
  if IsPair then
    Result := Offset + 2
  else
    Result := Offset + 1;
end;

function TMarkdownEditorModel.PrevCaret(const Offset: Integer): Integer;
begin
  if Offset <= 0 then
    Exit(0);

  const IsPair = FText[Offset].IsLowSurrogate and (Offset - 1 >= 1) and FText[Offset - 1].IsHighSurrogate;
  if IsPair then
    Result := Offset - 2
  else
    Result := Offset - 1;
end;

function TMarkdownEditorModel.ClampOffset(const Offset: Integer): Integer;
begin
  Result := EnsureRange(Offset, 0, System.Length(FText));
end;

function TMarkdownEditorModel.SnapOffset(const Offset: Integer): Integer;
begin
  Result := ClampOffset(Offset);

  const IsMidPair = (Result > 0) and (Result < System.Length(FText)) and FText[Result].IsHighSurrogate and
    FText[Result + 1].IsLowSurrogate;
  if IsMidPair then
    Inc(Result);
end;

function TMarkdownEditorModel.IsWordChar(const Ch: Char): Boolean;
begin
  Result := Ch.IsLetterOrDigit or (Ch = '_');
end;

function TMarkdownEditorModel.CategoryOfChar(const Ch: Char): TCharCategory;
begin
  if IsWordChar(Ch) then
    Result := TCharCategory.Word
  else if Ch.IsWhiteSpace then
    Result := TCharCategory.Space
  else
    Result := TCharCategory.Other;
end;

procedure TMarkdownEditorModel.WrapOrToggle(const Marker: string);
begin
  const Start = SelectionStart;
  const Len = SelectionLength;
  const Selected = SelectedText;
  const MarkerLen = System.Length(Marker);

  const IsWrapped = (System.Length(Selected) >= 2 * MarkerLen) and Selected.StartsWith(Marker) and
    Selected.EndsWith(Marker);
  if IsWrapped then
  begin
    const Inner = Copy(Selected, MarkerLen + 1, System.Length(Selected) - 2 * MarkerLen);
    ApplyReplace(Start, Len, Inner, False);
    FAnchor := Start;
    FCaret := Start + System.Length(Inner);
    Exit;
  end;

  const Wrapped = Marker + Selected + Marker;
  ApplyReplace(Start, Len, Wrapped, False);
  FAnchor := Start + MarkerLen;
  FCaret := Start + MarkerLen + System.Length(Selected);
end;

procedure TMarkdownEditorModel.InsertLink;
begin
  const Start = SelectionStart;
  const Len = SelectionLength;
  const Selected = SelectedText;
  const UrlPlaceholder = 'url';
  const LinkPrefix = OpenBracket + Selected + CloseBracket + OpenParen;
  const LinkMarkup = LinkPrefix + UrlPlaceholder + CloseParen;

  ApplyReplace(Start, Len, LinkMarkup, False);

  const UrlStart = Start + System.Length(LinkPrefix);
  FAnchor := UrlStart;
  FCaret := UrlStart + System.Length(UrlPlaceholder);
end;

procedure TMarkdownEditorModel.WrapCodeBlock;
begin
  const Start = SelectionStart;
  const Len = SelectionLength;
  const Selected = SelectedText;
  const FenceMarker = StringOfChar(Backtick, MinFenceLength);
  const Block = FenceMarker + LineFeed + Selected + LineFeed + FenceMarker;

  ApplyReplace(Start, Len, Block, False);
end;

function TMarkdownEditorModel.GetText: string;
begin
  Result := FText;
end;

procedure TMarkdownEditorModel.SetText(const Value: string);
begin
  NormalizeAndLoad(Value);
end;

function TMarkdownEditorModel.GetCaretPosition: Integer;
begin
  Result := FCaret;
end;

procedure TMarkdownEditorModel.SetCaretPosition(const Value: Integer);
begin
  const Snapped = SnapOffset(Value);
  FCaret := Snapped;
  FAnchor := Snapped;
end;

function TMarkdownEditorModel.GetSelectionStart: Integer;
begin
  Result := Min(FCaret, FAnchor);
end;

function TMarkdownEditorModel.GetSelectionLength: Integer;
begin
  Result := Abs(FCaret - FAnchor);
end;

function TMarkdownEditorModel.GetSelectedText: string;
begin
  Result := Copy(FText, SelectionStart + 1, SelectionLength);
end;

function TMarkdownEditorModel.GetOnChange: TEditorChangeEvent;
begin
  Result := FOnChange;
end;

procedure TMarkdownEditorModel.SetOnChange(const Value: TEditorChangeEvent);
begin
  FOnChange := Value;
end;

end.
