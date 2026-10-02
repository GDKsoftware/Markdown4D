unit Markdown4D.Emoji.Segments;

{$SCOPEDENUMS ON}

// Splits a run of text into the parts that are emoji and the parts that are
// not. GDI draws a colour font in a single colour, so a painter that wants
// colour emoji hands the emoji parts to a colour-capable text engine and keeps
// drawing the rest of the run exactly as before.

interface

type
  TEmojiSegment = record
    Text: string;
    IsEmoji: Boolean;
  end;

  TEmojiSegments = class
  private
    const
      VariationSelectorEmoji = #$FE0F;
      CombiningEnclosingKeycap = #$20E3;
      ZeroWidthJoiner = #$200D;
      FirstEmojiHighSurrogate = #$D83C;
      LastEmojiHighSurrogate = #$D83E;
      TagHighSurrogate = #$DB40;
    class function CreateSegment(const Text: string; const Start, Count: Integer;
      const IsEmoji: Boolean): TEmojiSegment; static;
    class function IsEmojiAt(const Text: string; const Index: Integer;
      const IsAfterEmoji, IsAfterJoiner: Boolean): Boolean; static;
    class function IsEmojiHighSurrogate(const Text: string; const Index: Integer): Boolean; static;
    class function IsPresentationMarkAt(const Text: string; const Index: Integer): Boolean; static;
    class function IsEmojiPresentation(const Character: Char): Boolean; static;
    class function CodeUnitCountAt(const Text: string; const Index: Integer): Integer; static;

  public
    class function ContainsEmoji(const Text: string): Boolean; static;
    class function Split(const Text: string): TArray<TEmojiSegment>; static;
  end;

implementation

uses
  System.Character;

class function TEmojiSegments.ContainsEmoji(const Text: string): Boolean;
begin
  Result := False;

  var Index := 1;
  while Index <= Length(Text) do
  begin
    if IsEmojiAt(Text, Index, False, False) then
      Exit(True);

    Inc(Index, CodeUnitCountAt(Text, Index));
  end;
end;

class function TEmojiSegments.Split(const Text: string): TArray<TEmojiSegment>;
begin
  Result := nil;

  var SegmentStart := 1;
  var IsSegmentEmoji := False;
  var IsAfterJoiner := False;
  var Index := 1;
  while Index <= Length(Text) do
  begin
    const IsEmoji = IsEmojiAt(Text, Index, IsSegmentEmoji, IsAfterJoiner);
    const StartsNewSegment = (Index > SegmentStart) and (IsEmoji <> IsSegmentEmoji);
    if StartsNewSegment then
    begin
      Result := Result + [CreateSegment(Text, SegmentStart, Index - SegmentStart, IsSegmentEmoji)];
      SegmentStart := Index;
    end;

    IsSegmentEmoji := IsEmoji;
    IsAfterJoiner := IsEmoji and (Text[Index] = ZeroWidthJoiner);
    Inc(Index, CodeUnitCountAt(Text, Index));
  end;

  const HasTail = (SegmentStart <= Length(Text));
  if HasTail then
    Result := Result + [CreateSegment(Text, SegmentStart, Length(Text) - SegmentStart + 1, IsSegmentEmoji)];
end;

class function TEmojiSegments.CreateSegment(const Text: string; const Start, Count: Integer;
  const IsEmoji: Boolean): TEmojiSegment;
begin
  Result.Text    := Copy(Text, Start, Count);
  Result.IsEmoji := IsEmoji;
end;

// A code point belongs to an emoji when it is an emoji itself, when a
// presentation mark (U+FE0F or the keycap U+20E3) follows it, or when it
// continues an emoji sequence: a mark, a joiner, or the code point a joiner
// glues on. A joiner after ordinary text stays text, since scripts such as
// Devanagari use it for shaping.
class function TEmojiSegments.IsEmojiAt(const Text: string; const Index: Integer;
  const IsAfterEmoji, IsAfterJoiner: Boolean): Boolean;
begin
  if IsAfterJoiner then
    Exit(True);

  const Character = Text[Index];
  const IsSequenceMark = (Character = VariationSelectorEmoji) or (Character = CombiningEnclosingKeycap) or
    (Character = ZeroWidthJoiner);
  if IsSequenceMark then
    Exit(IsAfterEmoji);

  if IsEmojiHighSurrogate(Text, Index) or IsEmojiPresentation(Character) then
    Exit(True);

  Result := IsPresentationMarkAt(Text, Index + CodeUnitCountAt(Text, Index));
end;

class function TEmojiSegments.IsEmojiHighSurrogate(const Text: string; const Index: Integer): Boolean;
begin
  const Character = Text[Index];
  const IsEmojiPlane = ((Character >= FirstEmojiHighSurrogate) and (Character <= LastEmojiHighSurrogate)) or
    (Character = TagHighSurrogate);
  Result := IsEmojiPlane and (CodeUnitCountAt(Text, Index) = 2);
end;

class function TEmojiSegments.IsPresentationMarkAt(const Text: string; const Index: Integer): Boolean;
begin
  if Index > Length(Text) then
    Exit(False);

  Result := (Text[Index] = VariationSelectorEmoji) or (Text[Index] = CombiningEnclosingKeycap);
end;

// The Basic Multilingual Plane characters that Unicode shows as emoji by
// default (Emoji_Presentation=Yes), so they need no U+FE0F to be emoji.
class function TEmojiSegments.IsEmojiPresentation(const Character: Char): Boolean;
begin
  case Ord(Character) of
    $231A..$231B, $23E9..$23EC, $23F0, $23F3, $25FD..$25FE, $2614..$2615, $2648..$2653, $267F, $2693, $26A1,
    $26AA..$26AB, $26BD..$26BE, $26C4..$26C5, $26CE, $26D4, $26EA, $26F2..$26F3, $26F5, $26FA, $26FD, $2705,
    $270A..$270B, $2728, $274C, $274E, $2753..$2755, $2757, $2795..$2797, $27B0, $27BF, $2B1B..$2B1C, $2B50,
    $2B55:
      Result := True;
  else
    Result := False;
  end;
end;

class function TEmojiSegments.CodeUnitCountAt(const Text: string; const Index: Integer): Integer;
begin
  const IsSurrogatePair = (Index < Length(Text)) and Text[Index].IsHighSurrogate and Text[Index + 1].IsLowSurrogate;
  if IsSurrogatePair then
    Result := 2
  else
    Result := 1;
end;

end.
