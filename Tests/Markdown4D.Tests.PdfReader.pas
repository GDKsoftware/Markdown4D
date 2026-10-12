unit Markdown4D.Tests.PdfReader;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  TMarkdownTestPdfReader = class
  private
    const
      ImageDictionary = '/Subtype /Image';
      StreamStartPattern = '/Length (\d+) >>'#10'stream'#10;
      PageCountPattern = '/Count (\d+)';

  public
    const
      PageObjectMarker = '/Type /Page ';
    class function AsText(const Bytes: TBytes): string; static;
    class function PageCount(const Bytes: TBytes): Integer; static;
    class function Occurrences(const Text, Needle: string): Integer; static;
    class function StreamData(const Bytes: TBytes; const Dictionary: string): TBytes; static;
    class function FirstPagePixels(const Bytes: TBytes): TBytes; static;
  end;

implementation

uses
  System.ZLib,
  System.RegularExpressions;

class function TMarkdownTestPdfReader.AsText(const Bytes: TBytes): string;
begin
  SetLength(Result, Length(Bytes));
  for var Index := 0 to High(Bytes) do
  begin
    Result[Index + 1] := Char(Bytes[Index]);
  end;
end;

class function TMarkdownTestPdfReader.PageCount(const Bytes: TBytes): Integer;
begin
  const Match = TRegEx.Match(AsText(Bytes), PageCountPattern);
  Result := 0;
  if Match.Success then
    Result := StrToInt(Match.Groups[1].Value);
end;

class function TMarkdownTestPdfReader.Occurrences(const Text, Needle: string): Integer;
begin
  Result := 0;
  var Offset := Pos(Needle, Text);
  while Offset > 0 do
  begin
    Inc(Result);
    Offset := Pos(Needle, Text, Offset + Length(Needle));
  end;
end;

class function TMarkdownTestPdfReader.StreamData(const Bytes: TBytes; const Dictionary: string): TBytes;
begin
  const Text = AsText(Bytes);
  const DictionaryOffset = Pos(Dictionary, Text);
  const Tail = Copy(Text, DictionaryOffset, MaxInt);
  const LengthMatch = TRegEx.Match(Tail, StreamStartPattern);
  const DataLength = StrToInt(LengthMatch.Groups[1].Value);
  const DataOffset = DictionaryOffset - 1 + LengthMatch.Index - 1 + LengthMatch.Length;

  Result := Copy(Bytes, DataOffset, DataLength);
end;

class function TMarkdownTestPdfReader.FirstPagePixels(const Bytes: TBytes): TBytes;
begin
  const Compressed = StreamData(Bytes, ImageDictionary);
  ZDecompress(Compressed, Result);
end;

end.
