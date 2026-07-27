unit Markdown4D.Text.FileFormat;

{$SCOPEDENUMS ON}

// Reading and writing markdown files without silently rewriting them: the line
// endings, the text encoding and the presence of a byte order mark are detected
// on load and reproduced on save. Editors work on LF-only text internally, so
// this unit is the single place where a file's on-disk shape is preserved.

interface

type
  TMarkdownLineEnding = (Lf, CrLf, Cr);

  TMarkdownTextEncoding = (Utf8, Utf8Bom, Utf16Le, Utf16Be, Ansi);

  TMarkdownTextFormat = record
    Encoding: TMarkdownTextEncoding;
    LineEnding: TMarkdownLineEnding;
    class function Create(const Encoding: TMarkdownTextEncoding;
      const LineEnding: TMarkdownLineEnding): TMarkdownTextFormat; static;
    // What a new, never-saved document gets: UTF-8 without a mark, and the line
    // ending the host platform writes by default.
    class function Default: TMarkdownTextFormat; static;
    function NewLine: string;
  end;

  TMarkdownTextFile = record
    // Returns the file content with every line ending normalized to LF, and
    // reports the shape it had on disk so Save can restore it.
    class function Load(const FileName: string; out Format: TMarkdownTextFormat): string; static;
    class procedure Save(const FileName, Text: string; const Format: TMarkdownTextFormat); static;
    class function DetectLineEnding(const Text: string): TMarkdownLineEnding; static;
    class function NormalizeToLf(const Text: string): string; static;
    class function ApplyLineEnding(const Text: string; const LineEnding: TMarkdownLineEnding): string; static;
    class function DecodeBytes(const Bytes: TArray<Byte>; out Encoding: TMarkdownTextEncoding): string; static;
    class function EncodeText(const Text: string; const Encoding: TMarkdownTextEncoding): TArray<Byte>; static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Markdown4D.Defines;

type
  TUtf8Scanner = record
    class function IsValid(const Bytes: TArray<Byte>): Boolean; static;
    class function SequenceLength(const Lead: Byte): Integer; static;
  end;

const
  Utf8BomBytes: array[0..2] of Byte = ($EF, $BB, $BF);
  Utf16LeBomBytes: array[0..1] of Byte = ($FF, $FE);
  Utf16BeBomBytes: array[0..1] of Byte = ($FE, $FF);
  ContinuationMask = $C0;
  ContinuationMarker = $80;

class function TMarkdownTextFormat.Create(const Encoding: TMarkdownTextEncoding;
  const LineEnding: TMarkdownLineEnding): TMarkdownTextFormat;
begin
  Result.Encoding := Encoding;
  Result.LineEnding := LineEnding;
end;

class function TMarkdownTextFormat.Default: TMarkdownTextFormat;
begin
  {$IFDEF MSWINDOWS}
  Result := TMarkdownTextFormat.Create(TMarkdownTextEncoding.Utf8, TMarkdownLineEnding.CrLf);
  {$ELSE}
  Result := TMarkdownTextFormat.Create(TMarkdownTextEncoding.Utf8, TMarkdownLineEnding.Lf);
  {$ENDIF}
end;

function TMarkdownTextFormat.NewLine: string;
begin
  case LineEnding of
    TMarkdownLineEnding.CrLf:
      Result := CarriageReturn + LineFeed;
    TMarkdownLineEnding.Cr:
      Result := CarriageReturn;
  else
    Result := LineFeed;
  end;
end;

class function TMarkdownTextFile.Load(const FileName: string; out Format: TMarkdownTextFormat): string;
begin
  const Bytes = TFile.ReadAllBytes(FileName);

  var Encoding: TMarkdownTextEncoding;
  const Decoded = DecodeBytes(Bytes, Encoding);

  Format := TMarkdownTextFormat.Create(Encoding, DetectLineEnding(Decoded));
  Result := NormalizeToLf(Decoded);
end;

class procedure TMarkdownTextFile.Save(const FileName, Text: string; const Format: TMarkdownTextFormat);
begin
  const Shaped = ApplyLineEnding(NormalizeToLf(Text), Format.LineEnding);
  TFile.WriteAllBytes(FileName, EncodeText(Shaped, Format.Encoding));
end;

class function TMarkdownTextFile.DetectLineEnding(const Text: string): TMarkdownLineEnding;
begin
  for var Index := 1 to Length(Text) do
  begin
    if Text[Index] = CarriageReturn then
    begin
      const FollowedByFeed = (Index < Length(Text)) and (Text[Index + 1] = LineFeed);
      if FollowedByFeed then
        Exit(TMarkdownLineEnding.CrLf);

      Exit(TMarkdownLineEnding.Cr);
    end;

    if Text[Index] = LineFeed then
      Exit(TMarkdownLineEnding.Lf);
  end;

  Result := TMarkdownTextFormat.Default.LineEnding;
end;

class function TMarkdownTextFile.NormalizeToLf(const Text: string): string;
begin
  Result := StringReplace(Text, CarriageReturn + LineFeed, LineFeed, [rfReplaceAll]);
  Result := StringReplace(Result, CarriageReturn, LineFeed, [rfReplaceAll]);
end;

class function TMarkdownTextFile.ApplyLineEnding(const Text: string;
  const LineEnding: TMarkdownLineEnding): string;
begin
  if LineEnding = TMarkdownLineEnding.Lf then
    Exit(Text);

  const Format = TMarkdownTextFormat.Create(TMarkdownTextEncoding.Utf8, LineEnding);
  Result := StringReplace(Text, LineFeed, Format.NewLine, [rfReplaceAll]);
end;

class function TMarkdownTextFile.DecodeBytes(const Bytes: TArray<Byte>;
  out Encoding: TMarkdownTextEncoding): string;
begin
  const Count = Length(Bytes);

  const StartsWithUtf8Bom = (Count >= 3) and (Bytes[0] = Utf8BomBytes[0]) and (Bytes[1] = Utf8BomBytes[1]) and
    (Bytes[2] = Utf8BomBytes[2]);
  if StartsWithUtf8Bom then
  begin
    Encoding := TMarkdownTextEncoding.Utf8Bom;
    Exit(TEncoding.UTF8.GetString(Bytes, 3, Count - 3));
  end;

  const StartsWithUtf16LeBom = (Count >= 2) and (Bytes[0] = Utf16LeBomBytes[0]) and
    (Bytes[1] = Utf16LeBomBytes[1]);
  if StartsWithUtf16LeBom then
  begin
    Encoding := TMarkdownTextEncoding.Utf16Le;
    Exit(TEncoding.Unicode.GetString(Bytes, 2, Count - 2));
  end;

  const StartsWithUtf16BeBom = (Count >= 2) and (Bytes[0] = Utf16BeBomBytes[0]) and
    (Bytes[1] = Utf16BeBomBytes[1]);
  if StartsWithUtf16BeBom then
  begin
    Encoding := TMarkdownTextEncoding.Utf16Be;
    Exit(TEncoding.BigEndianUnicode.GetString(Bytes, 2, Count - 2));
  end;

  // No mark: UTF-8 is the safe reading unless the bytes cannot be UTF-8 at all,
  // in which case the file predates Unicode and the system code page applies.
  if TUtf8Scanner.IsValid(Bytes) then
  begin
    Encoding := TMarkdownTextEncoding.Utf8;
    Exit(TEncoding.UTF8.GetString(Bytes));
  end;

  Encoding := TMarkdownTextEncoding.Ansi;
  Result := TEncoding.ANSI.GetString(Bytes);
end;

class function TMarkdownTextFile.EncodeText(const Text: string;
  const Encoding: TMarkdownTextEncoding): TArray<Byte>;
begin
  case Encoding of
    TMarkdownTextEncoding.Utf8Bom:
      Result := TEncoding.UTF8.GetPreamble + TEncoding.UTF8.GetBytes(Text);
    TMarkdownTextEncoding.Utf16Le:
      Result := TEncoding.Unicode.GetPreamble + TEncoding.Unicode.GetBytes(Text);
    TMarkdownTextEncoding.Utf16Be:
      Result := TEncoding.BigEndianUnicode.GetPreamble + TEncoding.BigEndianUnicode.GetBytes(Text);
    TMarkdownTextEncoding.Ansi:
      Result := TEncoding.ANSI.GetBytes(Text);
  else
    Result := TEncoding.UTF8.GetBytes(Text);
  end;
end;

class function TUtf8Scanner.IsValid(const Bytes: TArray<Byte>): Boolean;
begin
  var Index := 0;
  const Count = Length(Bytes);

  while Index < Count do
  begin
    const Extra = SequenceLength(Bytes[Index]);
    if Extra < 0 then
      Exit(False);

    if Index + Extra >= Count then
      Exit(False);

    for var Offset := 1 to Extra do
    begin
      if (Bytes[Index + Offset] and ContinuationMask) <> ContinuationMarker then
        Exit(False);
    end;

    Index := Index + Extra + 1;
  end;

  Result := True;
end;

class function TUtf8Scanner.SequenceLength(const Lead: Byte): Integer;
begin
  if Lead < $80 then
    Exit(0);

  if (Lead >= $C2) and (Lead <= $DF) then
    Exit(1);

  if (Lead >= $E0) and (Lead <= $EF) then
    Exit(2);

  if (Lead >= $F0) and (Lead <= $F4) then
    Exit(3);

  Result := -1;
end;

end.
