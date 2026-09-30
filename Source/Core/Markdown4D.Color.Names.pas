unit Markdown4D.Color.Names;

{$SCOPEDENUMS ON}

interface

type
  // Resolves a colour as authors write it in TeX colour commands: one of the
  // CSS named colours, or a hex value with or without a leading #, in three
  // or six digits. The result is an opaque ARGB value.
  TMarkdownColorNames = class
  private
    const
      OpaqueAlpha = Cardinal($FF000000);
      AlphaMask = Cardinal($FF000000);
      RtlColorPrefix = 'cla';
      HexPrefix = '#';
      DelphiHexPrefix = '$';
      ShortHexLength = 3;
      LongHexLength = 6;
      // The RTL's web colour table predates CSS Color 4, which added this one.
      RebeccaPurpleName = 'rebeccapurple';
      RebeccaPurple = Cardinal($FF663399);
    class function TryParseName(const Name: string; out Color: Cardinal): Boolean; static;
    class function TryParseHex(const Digits: string; out Color: Cardinal): Boolean; static;
    class function ExpandShortHex(const Digits: string): string; static;
    class function IsHexDigits(const Digits: string): Boolean; static;

  public
    class function TryParse(const Value: string; out Color: Cardinal): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.UIConsts;

class function TMarkdownColorNames.TryParse(const Value: string; out Color: Cardinal): Boolean;
begin
  const Trimmed = Value.Trim;
  const Key = Trimmed.ToLower;

  if TryParseName(Key, Color) then
    Exit(True);

  var Digits := Key;
  if Digits.StartsWith(HexPrefix) then
    Digits := Digits.Substring(Length(HexPrefix));

  Result := TryParseHex(Digits, Color);
end;

// The CSS colour names are the RTL's web colours (claAliceBlue and so on).
// That table also holds transparent entries such as claNull, which are not
// colours an author can draw in, so only opaque entries count.
class function TMarkdownColorNames.TryParseName(const Name: string; out Color: Cardinal): Boolean;
begin
  Color := 0;

  if Name = RebeccaPurpleName then
  begin
    Color := RebeccaPurple;
    Exit(True);
  end;

  var Found: Integer;
  if not IdentToAlphaColor(RtlColorPrefix + Name, Found) then
    Exit(False);

  const Candidate = Cardinal(Found);
  const IsOpaque = ((Candidate and AlphaMask) = OpaqueAlpha);
  if IsOpaque then
    Color := Candidate;

  Result := IsOpaque;
end;

class function TMarkdownColorNames.TryParseHex(const Digits: string; out Color: Cardinal): Boolean;
begin
  Color := 0;

  const IsShort = (Digits.Length = ShortHexLength);
  const IsLong = (Digits.Length = LongHexLength);
  const HasHexLength = (IsShort or IsLong);
  if not HasHexLength then
    Exit(False);

  if not IsHexDigits(Digits) then
    Exit(False);

  var Full := Digits;
  if IsShort then
    Full := ExpandShortHex(Digits);

  const Rgb = Cardinal(StrToInt(DelphiHexPrefix + Full));
  Color := OpaqueAlpha or Rgb;
  Result := True;
end;

class function TMarkdownColorNames.ExpandShortHex(const Digits: string): string;
begin
  Result := '';
  for var Digit in Digits do
  begin
    Result := Result + Digit + Digit;
  end;
end;

class function TMarkdownColorNames.IsHexDigits(const Digits: string): Boolean;
begin
  for var Digit in Digits do
  begin
    const IsHexDigit = CharInSet(Digit, ['0'..'9', 'a'..'f']);
    if not IsHexDigit then
      Exit(False);
  end;

  Result := True;
end;

end.
