unit Markdown4D.Color.Names;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections;

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
    class var
      FNamedColors: TDictionary<string, Cardinal>;
    // Not static: GetAlphaColorValues takes a method pointer.
    class procedure AddRtlColor(const Name: string);
    class function TryParseHex(const Digits: string; out Color: Cardinal): Boolean; static;
    class function ExpandShortHex(const Digits: string): string; static;

  public
    class constructor Create;
    class destructor Destroy;
    class function TryParse(const Value: string; out Color: Cardinal): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.UIConsts;

// The CSS colour names are the RTL's web colours (claAliceBlue and so on),
// read once into a table so a name matches exactly: IdentToAlphaColor on its
// own also accepts a name with its first letter missing.
class constructor TMarkdownColorNames.Create;
begin
  FNamedColors := TDictionary<string, Cardinal>.Create;
  GetAlphaColorValues(AddRtlColor);
  FNamedColors.AddOrSetValue(RebeccaPurpleName, RebeccaPurple);
end;

class destructor TMarkdownColorNames.Destroy;
begin
  FNamedColors.Free;
end;

// The table also holds transparent entries such as Null, which are not
// colours an author can draw in, so only opaque entries are kept.
class procedure TMarkdownColorNames.AddRtlColor(const Name: string);
begin
  var Value: Integer;
  if not IdentToAlphaColor(RtlColorPrefix + Name, Value) then
    Exit;

  const Color = Cardinal(Value);
  const IsOpaque = ((Color and AlphaMask) = OpaqueAlpha);
  if IsOpaque then
    FNamedColors.AddOrSetValue(Name.ToLower, Color);
end;

class function TMarkdownColorNames.TryParse(const Value: string; out Color: Cardinal): Boolean;
begin
  const Trimmed = Value.Trim;
  const Key = Trimmed.ToLower;

  Result := FNamedColors.TryGetValue(Key, Color);
  if Result then
    Exit;

  var Digits := Key;
  if Digits.StartsWith(HexPrefix) then
    Digits := Digits.Substring(Length(HexPrefix));

  Result := TryParseHex(Digits, Color);
end;

class function TMarkdownColorNames.TryParseHex(const Digits: string; out Color: Cardinal): Boolean;
begin
  Color := 0;
  Result := False;

  const IsShort = (Digits.Length = ShortHexLength);
  const IsLong = (Digits.Length = LongHexLength);
  const HasHexLength = (IsShort or IsLong);
  if not HasHexLength then
    Exit;

  var Full := Digits;
  if IsShort then
    Full := ExpandShortHex(Digits);

  var Rgb: Integer;
  Result := TryStrToInt(DelphiHexPrefix + Full, Rgb);
  if Result then
    Color := OpaqueAlpha or Cardinal(Rgb);
end;

class function TMarkdownColorNames.ExpandShortHex(const Digits: string): string;
begin
  Result := '';
  for var Digit in Digits do
  begin
    Result := Result + Digit + Digit;
  end;
end;

end.
