unit Markdown4D.Layout.EmojiRuns;

{$SCOPEDENUMS ON}

interface

type
  TMarkdownEmojiRun = record
    Text: string;
    IsEmoji: Boolean;
    class function Create(const Text: string; const IsEmoji: Boolean): TMarkdownEmojiRun; static;
  end;

  // Splits a text run into stretches of plain text and stretches of emoji, so a
  // painter can hand the emoji to a renderer that draws colour fonts while the
  // plain text keeps its usual path. An emoji stretch holds whole sequences:
  // variation selectors, keycaps, skin tones, tags and ZWJ joins stay attached.
  TMarkdownEmojiRuns = class
  private
    type
      TCodePoint = record
        Value: Cardinal;
        StartIndex: Integer;
        Length: Integer;
      end;
    const
      ZeroWidthJoiner = $200D;
      TextPresentationSelector = $FE0E;
      EmojiPresentationSelector = $FE0F;
      CombiningKeycap = $20E3;
      FirstTag = $E0020;
      LastTag = $E007F;
      FirstPictographic = $1F000;
      LastPictographic = $1FAFF;
      FirstRegionalIndicator = $1F1E6;
      LastRegionalIndicator = $1F1FF;
      FirstSkinTone = $1F3FB;
      LastSkinTone = $1F3FF;
      // The BMP code points whose default presentation is emoji (Unicode
      // Emoji_Presentation property); every other BMP symbol is text unless an
      // emoji presentation selector follows it.
      EmojiPresentationRanges: array[0..33] of array[0..1] of Word = (
        ($231A, $231B), ($23E9, $23EC), ($23F0, $23F0), ($23F3, $23F3), ($25FD, $25FE), ($2614, $2615),
        ($2648, $2653), ($267F, $267F), ($2693, $2693), ($26A1, $26A1), ($26AA, $26AB), ($26BD, $26BE),
        ($26C4, $26C5), ($26CE, $26CE), ($26D4, $26D4), ($26EA, $26EA), ($26F2, $26F3), ($26F5, $26F5),
        ($26FA, $26FA), ($26FD, $26FD), ($2705, $2705), ($270A, $270B), ($2728, $2728), ($274C, $274C),
        ($274E, $274E), ($2753, $2755), ($2757, $2757), ($2795, $2797), ($27B0, $27B0), ($27BF, $27BF),
        ($2B1B, $2B1C), ($2B50, $2B50), ($2B55, $2B55), ($3030, $3030));
    class function CodePointsOf(const Text: string): TArray<TCodePoint>;
    class function EmojiFlagsOf(const CodePoints: TArray<TCodePoint>): TArray<Boolean>;
    class function IsEmojiAt(const CodePoints: TArray<TCodePoint>; const Index: Integer;
      const IsPreviousEmoji: Boolean): Boolean;
    class function IsEmojiBase(const Value: Cardinal): Boolean;
    class function IsSequenceComponent(const Value: Cardinal): Boolean;
    class function CodePointAt(const Text: string; const Index: Integer): Cardinal;
    class function CodePointBefore(const Text: string; const Index: Integer): Cardinal;
    class function IsAttachedToPrevious(const Value: Cardinal): Boolean;
    class function IsRegionalIndicator(const Value: Cardinal): Boolean;
    class function RegionalIndicatorsBefore(const Text: string; const Count: Integer): Integer;

  public
    // A cheap check without allocation: False means Split returns the whole
    // text as one plain run.
    class function HasEmojiCandidate(const Text: string): Boolean;
    class function Split(const Text: string): TArray<TMarkdownEmojiRun>;
    // True when a caret or selection edge may sit after the first Count
    // characters of Text: never between the halves of a surrogate pair and
    // never inside an emoji sequence (selectors, skin tones, keycaps, tags,
    // ZWJ joins and flag pairs).
    class function IsCharacterBoundary(const Text: string; const Count: Integer): Boolean;
    class function NextCharacterBoundary(const Text: string; const Count: Integer): Integer;
  end;

implementation

uses
  System.Character;

class function TMarkdownEmojiRun.Create(const Text: string; const IsEmoji: Boolean): TMarkdownEmojiRun;
begin
  Result.Text := Text;
  Result.IsEmoji := IsEmoji;
end;

class function TMarkdownEmojiRuns.Split(const Text: string): TArray<TMarkdownEmojiRun>;
begin
  if not HasEmojiCandidate(Text) then
  begin
    Result := [TMarkdownEmojiRun.Create(Text, False)];
    Exit;
  end;

  const CodePoints = CodePointsOf(Text);
  const Flags = EmojiFlagsOf(CodePoints);

  Result := nil;
  var RunStart := 0;
  for var Index := 1 to Length(CodePoints) do
  begin
    const IsRunEnd = ((Index = Length(CodePoints)) or (Flags[Index] <> Flags[RunStart]));
    if IsRunEnd then
    begin
      const StartIndex = CodePoints[RunStart].StartIndex;
      const EndIndex = CodePoints[Index - 1].StartIndex + CodePoints[Index - 1].Length;
      Result := Result + [TMarkdownEmojiRun.Create(Copy(Text, StartIndex, EndIndex - StartIndex), Flags[RunStart])];
      RunStart := Index;
    end;
  end;
end;

// Every emoji either uses a surrogate pair, a BMP symbol from U+2300 upwards,
// or an emoji presentation selector; text without any of them skips the split.
class function TMarkdownEmojiRuns.HasEmojiCandidate(const Text: string): Boolean;
begin
  for var Character in Text do
  begin
    const IsCandidate = ((Character >= #$2300) and not ((Character >= #$3100) and (Character < #$D800)));
    if IsCandidate then
      Exit(True);
  end;

  Result := False;
end;

class function TMarkdownEmojiRuns.CodePointsOf(const Text: string): TArray<TCodePoint>;
begin
  SetLength(Result, Length(Text));

  var Count := 0;
  var Index := 1;
  while Index <= Length(Text) do
  begin
    const IsPair = (Text[Index].IsHighSurrogate and (Index < Length(Text)) and Text[Index + 1].IsLowSurrogate);
    var CodePoint: TCodePoint;
    CodePoint.StartIndex := Index;
    if IsPair then
    begin
      CodePoint.Value := Cardinal(Char.ConvertToUtf32(Text[Index], Text[Index + 1]));
      CodePoint.Length := 2;
    end
    else
    begin
      CodePoint.Value := Ord(Text[Index]);
      CodePoint.Length := 1;
    end;

    Result[Count] := CodePoint;
    Inc(Count);
    Index := Index + CodePoint.Length;
  end;

  SetLength(Result, Count);
end;

class function TMarkdownEmojiRuns.EmojiFlagsOf(const CodePoints: TArray<TCodePoint>): TArray<Boolean>;
begin
  SetLength(Result, Length(CodePoints));

  var IsPreviousEmoji := False;
  for var Index := 0 to High(CodePoints) do
  begin
    Result[Index] := IsEmojiAt(CodePoints, Index, IsPreviousEmoji);
    IsPreviousEmoji := Result[Index];
  end;
end;

class function TMarkdownEmojiRuns.IsEmojiAt(const CodePoints: TArray<TCodePoint>; const Index: Integer;
  const IsPreviousEmoji: Boolean): Boolean;
begin
  const Value = CodePoints[Index].Value;
  const HasNext = (Index < High(CodePoints));
  const IsFollowedByEmojiSelector = (HasNext and (CodePoints[Index + 1].Value = EmojiPresentationSelector));
  const IsFollowedByTextSelector = (HasNext and (CodePoints[Index + 1].Value = TextPresentationSelector));
  const IsAfterJoiner = (IsPreviousEmoji and (Index > 0) and (CodePoints[Index - 1].Value = ZeroWidthJoiner));

  if IsFollowedByTextSelector then
    Exit(False);

  Result := IsEmojiBase(Value) or
            IsFollowedByEmojiSelector or
            IsAfterJoiner or
            (IsPreviousEmoji and IsSequenceComponent(Value));
end;

class function TMarkdownEmojiRuns.IsEmojiBase(const Value: Cardinal): Boolean;
begin
  const IsPictographic = ((Value >= FirstPictographic) and (Value <= LastPictographic));
  if IsPictographic then
    Exit(True);

  for var RangeIndex := Low(EmojiPresentationRanges) to High(EmojiPresentationRanges) do
  begin
    const IsInRange = ((Value >= EmojiPresentationRanges[RangeIndex, 0]) and
                       (Value <= EmojiPresentationRanges[RangeIndex, 1]));
    if IsInRange then
      Exit(True);
  end;

  Result := False;
end;

class function TMarkdownEmojiRuns.IsSequenceComponent(const Value: Cardinal): Boolean;
begin
  const IsTag = ((Value >= FirstTag) and (Value <= LastTag));
  Result := (Value = EmojiPresentationSelector) or
            (Value = CombiningKeycap) or
            (Value = ZeroWidthJoiner) or
            IsTag;
end;

class function TMarkdownEmojiRuns.IsCharacterBoundary(const Text: string; const Count: Integer): Boolean;
begin
  const IsAtEdge = ((Count <= 0) or (Count >= Length(Text)));
  if IsAtEdge then
    Exit(True);

  const SplitsSurrogatePair = (Text[Count].IsHighSurrogate and Text[Count + 1].IsLowSurrogate);
  if SplitsSurrogatePair then
    Exit(False);

  const Previous = CodePointBefore(Text, Count);
  const Next = CodePointAt(Text, Count + 1);
  const SplitsSequence = (IsAttachedToPrevious(Next) or (Previous = ZeroWidthJoiner));
  if SplitsSequence then
    Exit(False);

  const SplitsFlag = (IsRegionalIndicator(Previous) and
                      IsRegionalIndicator(Next) and
                      Odd(RegionalIndicatorsBefore(Text, Count)));
  Result := not SplitsFlag;
end;

class function TMarkdownEmojiRuns.NextCharacterBoundary(const Text: string; const Count: Integer): Integer;
begin
  Result := Count + 1;
  while not IsCharacterBoundary(Text, Result) do
  begin
    Inc(Result);
  end;
end;

class function TMarkdownEmojiRuns.CodePointAt(const Text: string; const Index: Integer): Cardinal;
begin
  const IsPair = (Text[Index].IsHighSurrogate and (Index < Length(Text)) and Text[Index + 1].IsLowSurrogate);
  if IsPair then
    Exit(Cardinal(Char.ConvertToUtf32(Text[Index], Text[Index + 1])));

  Result := Ord(Text[Index]);
end;

class function TMarkdownEmojiRuns.CodePointBefore(const Text: string; const Index: Integer): Cardinal;
begin
  const IsPair = (Text[Index].IsLowSurrogate and (Index > 1) and Text[Index - 1].IsHighSurrogate);
  if IsPair then
    Exit(Cardinal(Char.ConvertToUtf32(Text[Index - 1], Text[Index])));

  Result := Ord(Text[Index]);
end;

class function TMarkdownEmojiRuns.IsAttachedToPrevious(const Value: Cardinal): Boolean;
begin
  const IsSkinTone = ((Value >= FirstSkinTone) and (Value <= LastSkinTone));
  Result := IsSequenceComponent(Value) or
            (Value = TextPresentationSelector) or
            IsSkinTone;
end;

class function TMarkdownEmojiRuns.IsRegionalIndicator(const Value: Cardinal): Boolean;
begin
  Result := (Value >= FirstRegionalIndicator) and (Value <= LastRegionalIndicator);
end;

// Flags are pairs of regional indicators; an odd count before a boundary means
// it falls inside a pair.
class function TMarkdownEmojiRuns.RegionalIndicatorsBefore(const Text: string; const Count: Integer): Integer;
begin
  Result := 0;

  var Index := Count;
  while (Index > 1) and IsRegionalIndicator(CodePointBefore(Text, Index)) do
  begin
    Inc(Result);
    Index := Index - 2;
  end;
end;

end.
