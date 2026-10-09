unit Markdown4D.Tests.PdfReader;

interface

uses
  System.SysUtils,
  System.Classes;

type
  // Reads back just enough of a PDF written by TMarkdownPdfWriter for the
  // tests to check it: the page count and the pixels of the first page.
  TMarkdownTestPdfReader = class
  private
    const
      StreamKeyword = 'stream'#10;
      DarkChannelCeiling = 128;
      WhiteChannel = 255;
      BytesPerPixel = 3;
    class function NumberAfter(const Text, Key: string; const From: Integer): Integer;

  public
    class function BytesOf(const Stream: TMemoryStream): TBytes;
    // One character per byte, so a position in the text is one in the data.
    class function AsText(const Data: TBytes): string;
    class function PageCount(const Data: TBytes): Integer;
    class function FirstImage(const Data: TBytes; out Width, Height: Integer): TBytes;
    class function DarkPixelCount(const Pixels: TBytes): Integer;
    class function IsWhiteAt(const Pixels: TBytes; const Width, X, Y: Integer): Boolean;
    class function HasPixel(const Pixels: TBytes; const Red, Green, Blue, Tolerance: Byte): Boolean;
  end;

implementation

uses
  System.ZLib;

class function TMarkdownTestPdfReader.BytesOf(const Stream: TMemoryStream): TBytes;
begin
  SetLength(Result, Stream.Size);
  if Stream.Size > 0 then
    Move(Stream.Memory^, Result[0], Stream.Size);
end;

class function TMarkdownTestPdfReader.AsText(const Data: TBytes): string;
begin
  SetLength(Result, Length(Data));
  for var Index := 0 to High(Data) do
  begin
    Result[Index + 1] := Char(Data[Index]);
  end;
end;

class function TMarkdownTestPdfReader.PageCount(const Data: TBytes): Integer;
begin
  Result := NumberAfter(AsText(Data), '/Count ', 1);
end;

class function TMarkdownTestPdfReader.FirstImage(const Data: TBytes; out Width, Height: Integer): TBytes;
begin
  const Text = AsText(Data);
  const ImageAt = Pos('/Subtype /Image', Text);
  Width := NumberAfter(Text, '/Width ', ImageAt);
  Height := NumberAfter(Text, '/Height ', ImageAt);

  const CompressedLength = NumberAfter(Text, '/Length ', ImageAt);
  const DataStart = Pos(StreamKeyword, Text, ImageAt) + Length(StreamKeyword) - 1;
  const Compressed = Copy(Data, DataStart, CompressedLength);

  ZDecompress(Compressed, Result);
end;

class function TMarkdownTestPdfReader.NumberAfter(const Text, Key: string; const From: Integer): Integer;
begin
  var Index := Pos(Key, Text, From);
  if Index = 0 then
  begin
    Result := -1;
    Exit;
  end;

  Index := Index + Length(Key);
  var Digits := '';
  while (Index <= Length(Text)) and CharInSet(Text[Index], ['0'..'9']) do
  begin
    Digits := Digits + Text[Index];
    Inc(Index);
  end;

  Result := StrToIntDef(Digits, -1);
end;

class function TMarkdownTestPdfReader.DarkPixelCount(const Pixels: TBytes): Integer;
begin
  Result := 0;
  var Index := 0;
  while Index + 2 <= High(Pixels) do
  begin
    const IsDark = ((Pixels[Index] < DarkChannelCeiling) and
                    (Pixels[Index + 1] < DarkChannelCeiling) and
                    (Pixels[Index + 2] < DarkChannelCeiling));
    if IsDark then
      Inc(Result);

    Inc(Index, BytesPerPixel);
  end;
end;

class function TMarkdownTestPdfReader.IsWhiteAt(const Pixels: TBytes; const Width, X, Y: Integer): Boolean;
begin
  const Index = ((Y * Width) + X) * BytesPerPixel;
  Result := (Pixels[Index] = WhiteChannel) and (Pixels[Index + 1] = WhiteChannel) and
    (Pixels[Index + 2] = WhiteChannel);
end;

class function TMarkdownTestPdfReader.HasPixel(const Pixels: TBytes; const Red, Green, Blue, Tolerance: Byte): Boolean;
begin
  var Index := 0;
  while Index + 2 <= High(Pixels) do
  begin
    const Matches = ((Abs(Pixels[Index] - Red) <= Tolerance) and
                     (Abs(Pixels[Index + 1] - Green) <= Tolerance) and
                     (Abs(Pixels[Index + 2] - Blue) <= Tolerance));
    if Matches then
    begin
      Result := True;
      Exit;
    end;

    Inc(Index, BytesPerPixel);
  end;

  Result := False;
end;

end.
