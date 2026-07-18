unit Markdown4D.Text.Unescape;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  TMarkdownUnescape = class
  private
    const
      Semicolon = ';';
      NumberSign = '#';
    class function TryReadEntity(const Value: string; const Start: Integer; out Decoded: string;
                                 out Consumed: Integer): Boolean;
    class function IsEntityNameChar(const Value: Char): Boolean;

  public
    class function IsAsciiPunctuation(const Value: Char): Boolean;
    class function IsMarkdownWhitespace(const Value: Char): Boolean;
    class function Unescape(const Value: string): string;
    class function TryDecodeEntityAt(const Value: string; const Start: Integer; out Decoded: string;
                                     out Consumed: Integer): Boolean;
    class function NormalizeUri(const Value: string): string;
  end;

implementation

uses
  Markdown4D.Defines,
  Markdown4D.Html.Entities;

class function TMarkdownUnescape.Unescape(const Value: string): string;
begin
  const Builder = TStringBuilder.Create;
  try
    var Index := 1;

    while Index <= Length(Value) do
    begin
      const Current = Value[Index];

      const IsEscape = (Current = Backslash) and (Index < Length(Value)) and IsAsciiPunctuation(Value[Index + 1]);
      if IsEscape then
      begin
        Builder.Append(Value[Index + 1]);
        Inc(Index, 2);
        Continue;
      end;

      if Current = Ampersand then
      begin
        var Decoded: string;
        var Consumed: Integer;

        if TryReadEntity(Value, Index, Decoded, Consumed) then
        begin
          Builder.Append(Decoded);
          Inc(Index, Consumed);
          Continue;
        end;
      end;

      Builder.Append(Current);
      Inc(Index);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TMarkdownUnescape.TryDecodeEntityAt(const Value: string; const Start: Integer; out Decoded: string;
                                                   out Consumed: Integer): Boolean;
begin
  Result := TryReadEntity(Value, Start, Decoded, Consumed);
end;

class function TMarkdownUnescape.TryReadEntity(const Value: string; const Start: Integer; out Decoded: string;
                                               out Consumed: Integer): Boolean;
begin
  Decoded := '';
  Consumed := 0;

  const StartsWithAmpersand = (Start <= Length(Value)) and (Value[Start] = Ampersand);
  if not StartsWithAmpersand then
    Exit(False);

  const IsNumeric = (Start < Length(Value)) and (Value[Start + 1] = NumberSign);
  var Index := Start + 1;
  if IsNumeric then
    Inc(Index);

  const IsHex = IsNumeric and (Index <= Length(Value)) and CharInSet(Value[Index], ['x', 'X']);
  if IsHex then
    Inc(Index);

  const BodyStart = Index;

  if IsNumeric then
  begin
    var AllowedDigits: TSysCharSet := ['0'..'9'];
    if IsHex then
      AllowedDigits := ['0'..'9', 'a'..'f', 'A'..'F'];

    while (Index <= Length(Value)) and CharInSet(Value[Index], AllowedDigits) do
    begin
      Inc(Index);
    end;
  end
  else
  begin
    while (Index <= Length(Value)) and IsEntityNameChar(Value[Index]) do
    begin
      Inc(Index);
    end;
  end;

  const HasBody = (Index > BodyStart);
  const HasTerminator = HasBody and (Index <= Length(Value)) and (Value[Index] = Semicolon);
  if not HasTerminator then
    Exit(False);

  const Body = Copy(Value, Start + 1, Index - Start - 1);

  if IsNumeric then
    Result := THtmlEntities.TryDecodeNumeric(Body, Decoded)
  else
    Result := THtmlEntities.TryDecode(Body, Decoded);

  if Result then
    Consumed := Index - Start + 1;
end;

class function TMarkdownUnescape.IsEntityNameChar(const Value: Char): Boolean;
begin
  Result := CharInSet(Value, ['0'..'9', 'a'..'z', 'A'..'Z']);
end;

class function TMarkdownUnescape.IsAsciiPunctuation(const Value: Char): Boolean;
begin
  Result := CharInSet(Value, ['!'..'/', ':'..'@', '['..'`', '{'..'~']);
end;

class function TMarkdownUnescape.IsMarkdownWhitespace(const Value: Char): Boolean;
begin
  Result := CharInSet(Value, [' ', #9, #10, #11, #12, #13]);
end;

class function TMarkdownUnescape.NormalizeUri(const Value: string): string;
const
  UnreservedChars: TSysCharSet = ['A'..'Z', 'a'..'z', '0'..'9', ';', ',', '/', '?', ':', '@', '&', '=', '+', '$',
    '-', '_', '.', '!', '~', '*', '''', '(', ')', '#', '%'];
  PercentEncodedFormat = '%%%2.2X';
begin
  const Builder = TStringBuilder.Create;
  try
    const Utf8Bytes = TEncoding.UTF8.GetBytes(Value);

    for var CurrentByte in Utf8Bytes do
    begin
      const IsUnreserved = (CurrentByte < $80) and CharInSet(Char(CurrentByte), UnreservedChars);

      if IsUnreserved then
        Builder.Append(Char(CurrentByte))
      else
        Builder.Append(Format(PercentEncodedFormat, [CurrentByte]));
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

end.
