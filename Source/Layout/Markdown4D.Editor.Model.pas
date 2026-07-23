unit Markdown4D.Editor.Model;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Editor.Folding;

type
  TEditorCommand = (Bold, Italic, Link, CodeBlock, Heading1, Heading2, Heading3, BulletList, NumberedList, Quote,
    Strikethrough, Table);

  TEditorReplaceRange = record
    Start: Integer;
    Length: Integer;
    Replacement: string;
    class function Create(const Start, Length: Integer; const Replacement: string): TEditorReplaceRange; static;
    function Apply(const Source: string): string;
  end;

  TEditorChangeEvent = procedure(const Sender: TObject; const Range: TEditorReplaceRange) of object;

  TMarkdownUndoEntry = record
    Start: Integer;
    RemovedText: string;
    InsertedText: string;
    CaretBefore: Integer;
    AnchorBefore: Integer;
    CaretAfter: Integer;
  end;

  IMarkdownEditorState = interface
    ['{8F2D4A31-6B7C-4E19-9A03-2C5D8E1F4B60}']
  end;

  TMarkdownFindOptions = record
    MatchCase: Boolean;
    WholeWord: Boolean;
    class function Create(const MatchCase, WholeWord: Boolean): TMarkdownFindOptions; static;
  end;

  TMarkdownEditorModel = class
  strict private
    type
      TCharCategory = (Word, Space, Other);
    var
      FText: string;
      FLineStarts: TArray<Integer>;
      FCaret: Integer;
      FAnchor: Integer;
      FUndoStack: TArray<TMarkdownUndoEntry>;
      FRedoStack: TArray<TMarkdownUndoEntry>;
      FCoalesceBroken: Boolean;
      FOnChange: TEditorChangeEvent;
      FCollapsedFolds: TArray<Integer>;
      FFoldRegions: TArray<TFoldRegion>;
      FFoldRegionsDirty: Boolean;
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
    function IndexOfNeedle(const Needle: string; const FromOffset: Integer;
      const Options: TMarkdownFindOptions): Integer;
    function MatchesAt(const Needle: string; const CandidateStart: Integer;
      const Options: TMarkdownFindOptions): Boolean;
    function CollectMatches(const Needle: string; const Options: TMarkdownFindOptions): TArray<Integer>;
    function IsWordChar(const Ch: Char): Boolean;
    function CategoryOfChar(const Ch: Char): TCharCategory;
    function AllLines: TArray<string>;
    procedure ShiftFolds(const Start, OldLen, NewLen: Integer);
    function CollapsedIndexOf(const HeaderOffset: Integer): Integer;
    function TryRegionAtHeader(const HeaderLine: Integer; out Region: TFoldRegion): Boolean;
    procedure WrapOrToggle(const Marker: string);
    procedure InsertLink;
    procedure WrapCodeBlock;
    procedure ToggleHeading(const Level: Integer);
    procedure ToggleLinePrefix(const Marker: string);
    procedure ToggleNumberedList;
    procedure InsertTable;
    procedure SelectedLineRegion(out RegionStart, RegionLen: Integer; out Lines: TArray<string>;
      out SingleLine: Boolean);
    procedure ReplaceRegionAndSelect(const RegionStart, RegionLen: Integer; const NewBlock: string);
    class function HeadingPrefixLen(const Line: string): Integer; static;
    class function OrderedPrefixLen(const Line: string): Integer; static;
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
    function CaptureState: IMarkdownEditorState;
    procedure RestoreState(const State: IMarkdownEditorState);
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
    function FindText(const Needle: string): Integer; overload;
    function FindText(const Needle: string; const Options: TMarkdownFindOptions): Integer; overload;
    function FindNext(const Needle: string; const StartAfter: Integer): Integer; overload;
    function FindNext(const Needle: string; const StartAfter: Integer;
      const Options: TMarkdownFindOptions): Integer; overload;
    function FindPrevious(const Needle: string; const StartBefore: Integer;
      const Options: TMarkdownFindOptions): Integer;
    function ReplaceCurrent(const Needle, Replacement: string; const Options: TMarkdownFindOptions): Boolean;
    function ReplaceAll(const Needle, Replacement: string; const Options: TMarkdownFindOptions): Integer;
    procedure Undo;
    procedure Redo;
    function CanUndo: Boolean;
    function CanRedo: Boolean;
    procedure BreakUndoCoalescing;
    function FoldRegions: TArray<TFoldRegion>;
    function HasFoldRegions: Boolean;
    function IsFoldHeader(const LineIndex: Integer): Boolean;
    function IsRegionCollapsed(const HeaderLine: Integer): Boolean;
    function IsLineHidden(const LineIndex: Integer): Boolean;
    procedure ToggleFold(const HeaderLine: Integer);
    procedure ExpandAt(const Offset: Integer);
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

type
  TMarkdownEditorStateObject = class(TInterfacedObject, IMarkdownEditorState)
  public
    Text: string;
    Caret: Integer;
    Anchor: Integer;
    UndoStack: TArray<TMarkdownUndoEntry>;
    RedoStack: TArray<TMarkdownUndoEntry>;
    CoalesceBroken: Boolean;
  end;

const
  HeadingMarkerChar = '#';
  SpaceStr = ' ';
  DotStr = '.';
  BulletMarker = '- ';
  QuoteMarker = '> ';
  OrderedMarkerFormat = '%d. ';
  StrikeMarker = '~~';
  TableHeaderLine = '| Header 1 | Header 2 | Header 3 |';
  TableDelimiterLine = '| --- | --- | --- |';
  TableBodyLine = '| Cell | Cell | Cell |';

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

class function TMarkdownFindOptions.Create(const MatchCase, WholeWord: Boolean): TMarkdownFindOptions;
begin
  Result.MatchCase := MatchCase;
  Result.WholeWord := WholeWord;
end;

constructor TMarkdownEditorModel.Create;
begin
  inherited Create;

  FLineStarts := [0];
  FFoldRegionsDirty := True;
end;

procedure TMarkdownEditorModel.LoadText(const Value: string);
begin
  NormalizeAndLoad(Value);
end;

function TMarkdownEditorModel.CaptureState: IMarkdownEditorState;
begin
  const Snapshot = TMarkdownEditorStateObject.Create;

  Snapshot.Text := FText;
  Snapshot.Caret := FCaret;
  Snapshot.Anchor := FAnchor;
  Snapshot.UndoStack := FUndoStack;
  Snapshot.RedoStack := FRedoStack;
  Snapshot.CoalesceBroken := FCoalesceBroken;

  Result := Snapshot;
end;

procedure TMarkdownEditorModel.RestoreState(const State: IMarkdownEditorState);
begin
  const Snapshot = State as TMarkdownEditorStateObject;

  FText := Snapshot.Text;
  RebuildLineStarts;

  FCaret := Snapshot.Caret;
  FAnchor := Snapshot.Anchor;
  FUndoStack := Snapshot.UndoStack;
  FRedoStack := Snapshot.RedoStack;
  FCoalesceBroken := Snapshot.CoalesceBroken;
  FCollapsedFolds := nil;
  FFoldRegionsDirty := True;
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

function TMarkdownEditorModel.FindText(const Needle: string): Integer;
begin
  Result := FindText(Needle, Default(TMarkdownFindOptions));
end;

function TMarkdownEditorModel.FindText(const Needle: string; const Options: TMarkdownFindOptions): Integer;
begin
  Result := System.Length(CollectMatches(Needle, Options));
end;

function TMarkdownEditorModel.FindNext(const Needle: string; const StartAfter: Integer): Integer;
begin
  Result := FindNext(Needle, StartAfter, Default(TMarkdownFindOptions));
end;

function TMarkdownEditorModel.FindNext(const Needle: string; const StartAfter: Integer;
  const Options: TMarkdownFindOptions): Integer;
begin
  if Needle = '' then
    Exit(-1);

  if System.Length(Needle) > System.Length(FText) then
    Exit(-1);

  const Primary = IndexOfNeedle(Needle, StartAfter + 1, Options);
  if Primary >= 0 then
    Exit(Primary);

  Result := IndexOfNeedle(Needle, 0, Options);
end;

function TMarkdownEditorModel.FindPrevious(const Needle: string; const StartBefore: Integer;
  const Options: TMarkdownFindOptions): Integer;
begin
  const Matches = CollectMatches(Needle, Options);
  if System.Length(Matches) = 0 then
    Exit(-1);

  var Best := -1;
  for var Start in Matches do
  begin
    if Start < StartBefore then
      Best := Start;
  end;

  if Best >= 0 then
    Exit(Best);

  Result := Matches[High(Matches)];
end;

function TMarkdownEditorModel.ReplaceCurrent(const Needle, Replacement: string;
  const Options: TMarkdownFindOptions): Boolean;
begin
  if Needle = '' then
    Exit(False);

  Result := (SelectionLength = System.Length(Needle)) and MatchesAt(Needle, SelectionStart, Options);
  if Result then
    ReplaceRange(SelectionStart, SelectionLength, Replacement);

  const NextStart = FindNext(Needle, SelectionStart + SelectionLength - 1, Options);
  if NextStart >= 0 then
    SetSelection(NextStart, System.Length(Needle));
end;

function TMarkdownEditorModel.ReplaceAll(const Needle, Replacement: string;
  const Options: TMarkdownFindOptions): Integer;
begin
  const Matches = CollectMatches(Needle, Options);
  Result := System.Length(Matches);
  if Result = 0 then
    Exit;

  const NeedleLen = System.Length(Needle);
  const SpanStart = Matches[0];
  const SpanEnd = Matches[High(Matches)] + NeedleLen;

  var Builder := '';
  var Cursor := SpanStart;
  for var Start in Matches do
  begin
    Builder := Builder + Copy(FText, Cursor + 1, Start - Cursor) + Replacement;
    Cursor := Start + NeedleLen;
  end;

  ReplaceRange(SpanStart, SpanEnd - SpanStart, Builder);
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

function TMarkdownEditorModel.FoldRegions: TArray<TFoldRegion>;
begin
  if FFoldRegionsDirty then
  begin
    FFoldRegions := TMarkdownFoldComputer.ComputeRegions(AllLines);
    FFoldRegionsDirty := False;
  end;

  Result := FFoldRegions;
end;

function TMarkdownEditorModel.HasFoldRegions: Boolean;
begin
  Result := System.Length(FoldRegions) > 0;
end;

function TMarkdownEditorModel.IsFoldHeader(const LineIndex: Integer): Boolean;
begin
  for var Region in FoldRegions do
  begin
    if Region.HeaderLine = LineIndex then
      Exit(True);
  end;

  Result := False;
end;

function TMarkdownEditorModel.IsRegionCollapsed(const HeaderLine: Integer): Boolean;
begin
  Result := CollapsedIndexOf(OffsetOfLineStart(HeaderLine)) >= 0;
end;

function TMarkdownEditorModel.IsLineHidden(const LineIndex: Integer): Boolean;
begin
  for var Region in FoldRegions do
  begin
    if Region.Contains(LineIndex) and IsRegionCollapsed(Region.HeaderLine) then
      Exit(True);
  end;

  Result := False;
end;

procedure TMarkdownEditorModel.ToggleFold(const HeaderLine: Integer);
begin
  var Region: TFoldRegion;
  if not TryRegionAtHeader(HeaderLine, Region) then
    Exit;

  const HeaderOffset = OffsetOfLineStart(HeaderLine);
  const Existing = CollapsedIndexOf(HeaderOffset);

  if Existing >= 0 then
  begin
    System.Delete(FCollapsedFolds, Existing, 1);
    Exit;
  end;

  FCollapsedFolds := FCollapsedFolds + [HeaderOffset];

  const CaretLine = LineIndexOfOffset(FCaret);
  if Region.Contains(CaretLine) then
  begin
    FCaret := HeaderOffset;
    FAnchor := HeaderOffset;
  end;
end;

procedure TMarkdownEditorModel.ExpandAt(const Offset: Integer);
begin
  const Line = LineIndexOfOffset(ClampOffset(Offset));

  for var Region in FoldRegions do
  begin
    if not (Region.Contains(Line) and IsRegionCollapsed(Region.HeaderLine)) then
      Continue;

    const Existing = CollapsedIndexOf(OffsetOfLineStart(Region.HeaderLine));
    if Existing >= 0 then
      System.Delete(FCollapsedFolds, Existing, 1);
  end;
end;

function TMarkdownEditorModel.AllLines: TArray<string>;
begin
  const Count = LineCount;
  SetLength(Result, Count);

  for var Index := 0 to Count - 1 do
  begin
    const StartOffset = FLineStarts[Index];

    var EndExclusive: Integer;
    if Index < Count - 1 then
      EndExclusive := FLineStarts[Index + 1] - 1
    else
      EndExclusive := System.Length(FText);

    Result[Index] := Copy(FText, StartOffset + 1, EndExclusive - StartOffset);
  end;
end;

procedure TMarkdownEditorModel.ShiftFolds(const Start, OldLen, NewLen: Integer);
begin
  if System.Length(FCollapsedFolds) = 0 then
    Exit;

  const Delta = NewLen - OldLen;
  const OldEnd = Start + OldLen;

  var Kept: TArray<Integer> := [];
  for var Offset in FCollapsedFolds do
  begin
    if Offset <= Start then
      Kept := Kept + [Offset]
    else if Offset >= OldEnd then
      Kept := Kept + [Offset + Delta];
  end;

  FCollapsedFolds := Kept;
end;

function TMarkdownEditorModel.CollapsedIndexOf(const HeaderOffset: Integer): Integer;
begin
  for var Index := 0 to High(FCollapsedFolds) do
  begin
    if FCollapsedFolds[Index] = HeaderOffset then
      Exit(Index);
  end;

  Result := -1;
end;

function TMarkdownEditorModel.TryRegionAtHeader(const HeaderLine: Integer; out Region: TFoldRegion): Boolean;
begin
  for var Candidate in FoldRegions do
  begin
    if Candidate.HeaderLine = HeaderLine then
    begin
      Region := Candidate;
      Exit(True);
    end;
  end;

  Region := Default(TFoldRegion);
  Result := False;
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
    TEditorCommand.Heading1:
      ToggleHeading(1);
    TEditorCommand.Heading2:
      ToggleHeading(2);
    TEditorCommand.Heading3:
      ToggleHeading(3);
    TEditorCommand.BulletList:
      ToggleLinePrefix(BulletMarker);
    TEditorCommand.NumberedList:
      ToggleNumberedList;
    TEditorCommand.Quote:
      ToggleLinePrefix(QuoteMarker);
    TEditorCommand.Strikethrough:
      WrapOrToggle(StrikeMarker);
    TEditorCommand.Table:
      InsertTable;
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
  FCollapsedFolds := nil;
  FFoldRegionsDirty := True;
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
  ShiftFolds(Start, OldLen, System.Length(Replacement));
  FFoldRegionsDirty := True;

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

  var Entry := Default(TMarkdownUndoEntry);
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

function TMarkdownEditorModel.IndexOfNeedle(const Needle: string; const FromOffset: Integer;
  const Options: TMarkdownFindOptions): Integer;
begin
  const NeedleLen = System.Length(Needle);
  const TextLen = System.Length(FText);
  const LastStart = TextLen - NeedleLen;

  const Start = EnsureRange(FromOffset, 0, TextLen);

  for var CandidateStart := Start to LastStart do
  begin
    if MatchesAt(Needle, CandidateStart, Options) then
      Exit(CandidateStart);
  end;

  Result := -1;
end;

function TMarkdownEditorModel.MatchesAt(const Needle: string; const CandidateStart: Integer;
  const Options: TMarkdownFindOptions): Boolean;
begin
  const NeedleLen = System.Length(Needle);
  const TextLen = System.Length(FText);

  if (CandidateStart < 0) or (CandidateStart + NeedleLen > TextLen) then
    Exit(False);

  for var Index := 1 to NeedleLen do
  begin
    const TextChar = FText[CandidateStart + Index];
    const NeedleChar = Needle[Index];
    if Options.MatchCase then
    begin
      if TextChar <> NeedleChar then
        Exit(False);
    end
    else if TextChar.ToLower <> NeedleChar.ToLower then
      Exit(False);
  end;

  if Options.WholeWord then
  begin
    const HasLeftBoundary = (CandidateStart = 0) or not IsWordChar(FText[CandidateStart]);
    const RightIndex = CandidateStart + NeedleLen + 1;
    const HasRightBoundary = (RightIndex > TextLen) or not IsWordChar(FText[RightIndex]);
    if not (HasLeftBoundary and HasRightBoundary) then
      Exit(False);
  end;

  Result := True;
end;

function TMarkdownEditorModel.CollectMatches(const Needle: string;
  const Options: TMarkdownFindOptions): TArray<Integer>;
begin
  Result := [];

  if Needle = '' then
    Exit;

  if System.Length(Needle) > System.Length(FText) then
    Exit;

  var Cursor := 0;
  var Hit := IndexOfNeedle(Needle, Cursor, Options);
  while Hit >= 0 do
  begin
    Result := Result + [Hit];
    Cursor := Hit + System.Length(Needle);
    Hit := IndexOfNeedle(Needle, Cursor, Options);
  end;
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

procedure TMarkdownEditorModel.ToggleHeading(const Level: Integer);
begin
  var RegionStart, RegionLen: Integer;
  var Lines: TArray<string>;
  var SingleLine: Boolean;
  SelectedLineRegion(RegionStart, RegionLen, Lines, SingleLine);

  const Prefix = StringOfChar(HeadingMarkerChar, Level) + SpaceStr;

  var AllApplied := True;
  var HasEligible := False;
  for var Index := 0 to High(Lines) do
  begin
    const Line = Lines[Index];
    const IsEligible = SingleLine or (Line <> '');
    if not IsEligible then
      Continue;

    HasEligible := True;
    if HeadingPrefixLen(Line) <> System.Length(Prefix) then
    begin
      AllApplied := False;
      Break;
    end;
  end;

  const Remove = HasEligible and AllApplied;

  for var Index := 0 to High(Lines) do
  begin
    var Line := Lines[Index];
    const IsEligible = SingleLine or (Line <> '');
    if not IsEligible then
      Continue;

    const Existing = HeadingPrefixLen(Line);
    if Existing > 0 then
      Line := Copy(Line, Existing + 1, System.Length(Line) - Existing);

    if not Remove then
      Line := Prefix + Line;

    Lines[Index] := Line;
  end;

  const NewBlock = string.Join(LineFeed, Lines);
  ReplaceRegionAndSelect(RegionStart, RegionLen, NewBlock);
end;

procedure TMarkdownEditorModel.ToggleLinePrefix(const Marker: string);
begin
  var RegionStart, RegionLen: Integer;
  var Lines: TArray<string>;
  var SingleLine: Boolean;
  SelectedLineRegion(RegionStart, RegionLen, Lines, SingleLine);

  const MarkerLen = System.Length(Marker);

  var AllApplied := True;
  var HasEligible := False;
  for var Index := 0 to High(Lines) do
  begin
    const Line = Lines[Index];
    const IsEligible = SingleLine or (Line <> '');
    if not IsEligible then
      Continue;

    HasEligible := True;
    if not Line.StartsWith(Marker) then
    begin
      AllApplied := False;
      Break;
    end;
  end;

  const Remove = HasEligible and AllApplied;

  for var Index := 0 to High(Lines) do
  begin
    var Line := Lines[Index];
    const IsEligible = SingleLine or (Line <> '');
    if not IsEligible then
      Continue;

    if Remove then
    begin
      if Line.StartsWith(Marker) then
        Line := Copy(Line, MarkerLen + 1, System.Length(Line) - MarkerLen);
    end
    else
      Line := Marker + Line;

    Lines[Index] := Line;
  end;

  const NewBlock = string.Join(LineFeed, Lines);
  ReplaceRegionAndSelect(RegionStart, RegionLen, NewBlock);
end;

procedure TMarkdownEditorModel.ToggleNumberedList;
begin
  var RegionStart, RegionLen: Integer;
  var Lines: TArray<string>;
  var SingleLine: Boolean;
  SelectedLineRegion(RegionStart, RegionLen, Lines, SingleLine);

  var AllApplied := True;
  var HasEligible := False;
  for var Index := 0 to High(Lines) do
  begin
    const Line = Lines[Index];
    const IsEligible = SingleLine or (Line <> '');
    if not IsEligible then
      Continue;

    HasEligible := True;
    if OrderedPrefixLen(Line) = 0 then
    begin
      AllApplied := False;
      Break;
    end;
  end;

  const Remove = HasEligible and AllApplied;

  var Counter := 0;
  for var Index := 0 to High(Lines) do
  begin
    var Line := Lines[Index];
    const IsEligible = SingleLine or (Line <> '');
    if not IsEligible then
      Continue;

    const Existing = OrderedPrefixLen(Line);
    if Existing > 0 then
      Line := Copy(Line, Existing + 1, System.Length(Line) - Existing);

    if not Remove then
    begin
      Inc(Counter);
      Line := Format(OrderedMarkerFormat, [Counter]) + Line;
    end;

    Lines[Index] := Line;
  end;

  const NewBlock = string.Join(LineFeed, Lines);
  ReplaceRegionAndSelect(RegionStart, RegionLen, NewBlock);
end;

procedure TMarkdownEditorModel.InsertTable;
begin
  const Start = SelectionStart;
  const Len = SelectionLength;

  const Skeleton = TableHeaderLine + LineFeed + TableDelimiterLine + LineFeed + TableBodyLine + LineFeed +
    TableBodyLine + LineFeed + TableBodyLine;

  var Lead := '';
  if Start > 0 then
  begin
    if FText[Start] <> LineFeed then
      Lead := LineFeed + LineFeed
    else if (Start < 2) or (FText[Start - 1] <> LineFeed) then
      Lead := LineFeed;
  end;

  const Insertion = Lead + Skeleton + LineFeed;
  ApplyReplace(Start, Len, Insertion, False);
end;

procedure TMarkdownEditorModel.SelectedLineRegion(out RegionStart, RegionLen: Integer; out Lines: TArray<string>;
  out SingleLine: Boolean);
begin
  const FirstLine = LineIndexOfOffset(SelectionStart);

  var EndOffset := SelectionStart + SelectionLength;
  if SelectionLength > 0 then
    Dec(EndOffset);

  const LastLine = LineIndexOfOffset(EndOffset);

  RegionStart := OffsetOfLineStart(FirstLine);

  var RegionEnd: Integer;
  if LastLine < LineCount - 1 then
    RegionEnd := OffsetOfLineStart(LastLine + 1) - 1
  else
    RegionEnd := System.Length(FText);

  RegionLen := RegionEnd - RegionStart;

  Lines := Copy(FText, RegionStart + 1, RegionLen).Split([LineFeed]);
  if System.Length(Lines) = 0 then
    Lines := [''];

  SingleLine := (FirstLine = LastLine);
end;

procedure TMarkdownEditorModel.ReplaceRegionAndSelect(const RegionStart, RegionLen: Integer; const NewBlock: string);
begin
  ApplyReplace(RegionStart, RegionLen, NewBlock, False);
  FAnchor := RegionStart;
  FCaret := RegionStart + System.Length(NewBlock);
end;

class function TMarkdownEditorModel.HeadingPrefixLen(const Line: string): Integer;
begin
  var HashCount := 0;
  while (HashCount < System.Length(Line)) and (Line[HashCount + 1] = HeadingMarkerChar) do
    Inc(HashCount);

  const IsHeading = (HashCount >= 1) and (HashCount <= MaxHeadingLevel) and
    (System.Length(Line) > HashCount) and (Line[HashCount + 1] = SpaceStr);
  if IsHeading then
    Result := HashCount + 1
  else
    Result := 0;
end;

class function TMarkdownEditorModel.OrderedPrefixLen(const Line: string): Integer;
begin
  var DigitCount := 0;
  while (DigitCount < System.Length(Line)) and Line[DigitCount + 1].IsDigit do
    Inc(DigitCount);

  const IsOrdered = (DigitCount >= 1) and (System.Length(Line) >= DigitCount + 2) and
    (Line[DigitCount + 1] = DotStr) and (Line[DigitCount + 2] = SpaceStr);
  if IsOrdered then
    Result := DigitCount + 2
  else
    Result := 0;
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
