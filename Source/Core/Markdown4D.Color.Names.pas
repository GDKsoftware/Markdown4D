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
      HexPrefix = '#';
      DelphiHexPrefix = '$';
      ShortHexLength = 3;
      LongHexLength = 6;
    type
      TNamedColor = record
        Name: string;
        Rgb: Cardinal;
      end;
    class var
      FColors: TDictionary<string, Cardinal>;
    class procedure AddColors(const Colors: array of TNamedColor); static;
    class function Named(const Name: string; const Rgb: Cardinal): TNamedColor; static;
    class function TryParseHex(const Digits: string; out Color: Cardinal): Boolean; static;
    class function ExpandShortHex(const Digits: string): string; static;
    class function IsHexDigits(const Digits: string): Boolean; static;

  public
    class constructor Create;
    class destructor Destroy;
    class function TryParse(const Value: string; out Color: Cardinal): Boolean; static;
  end;

implementation

uses
  System.SysUtils;

class constructor TMarkdownColorNames.Create;
begin
  FColors := TDictionary<string, Cardinal>.Create;

  AddColors([Named('aliceblue', $F0F8FF), Named('antiquewhite', $FAEBD7), Named('aqua', $00FFFF),
    Named('aquamarine', $7FFFD4), Named('azure', $F0FFFF), Named('beige', $F5F5DC), Named('bisque', $FFE4C4),
    Named('black', $000000), Named('blanchedalmond', $FFEBCD), Named('blue', $0000FF),
    Named('blueviolet', $8A2BE2), Named('brown', $A52A2A), Named('burlywood', $DEB887),
    Named('cadetblue', $5F9EA0), Named('chartreuse', $7FFF00), Named('chocolate', $D2691E),
    Named('coral', $FF7F50), Named('cornflowerblue', $6495ED), Named('cornsilk', $FFF8DC),
    Named('crimson', $DC143C), Named('cyan', $00FFFF), Named('darkblue', $00008B), Named('darkcyan', $008B8B),
    Named('darkgoldenrod', $B8860B), Named('darkgray', $A9A9A9), Named('darkgreen', $006400),
    Named('darkgrey', $A9A9A9), Named('darkkhaki', $BDB76B), Named('darkmagenta', $8B008B),
    Named('darkolivegreen', $556B2F), Named('darkorange', $FF8C00), Named('darkorchid', $9932CC),
    Named('darkred', $8B0000), Named('darksalmon', $E9967A), Named('darkseagreen', $8FBC8F),
    Named('darkslateblue', $483D8B), Named('darkslategray', $2F4F4F), Named('darkslategrey', $2F4F4F),
    Named('darkturquoise', $00CED1), Named('darkviolet', $9400D3), Named('deeppink', $FF1493),
    Named('deepskyblue', $00BFFF), Named('dimgray', $696969), Named('dimgrey', $696969),
    Named('dodgerblue', $1E90FF), Named('firebrick', $B22222), Named('floralwhite', $FFFAF0),
    Named('forestgreen', $228B22), Named('fuchsia', $FF00FF), Named('gainsboro', $DCDCDC),
    Named('ghostwhite', $F8F8FF), Named('gold', $FFD700), Named('goldenrod', $DAA520), Named('gray', $808080),
    Named('green', $008000), Named('greenyellow', $ADFF2F), Named('grey', $808080), Named('honeydew', $F0FFF0),
    Named('hotpink', $FF69B4), Named('indianred', $CD5C5C), Named('indigo', $4B0082), Named('ivory', $FFFFF0),
    Named('khaki', $F0E68C), Named('lavender', $E6E6FA), Named('lavenderblush', $FFF0F5),
    Named('lawngreen', $7CFC00), Named('lemonchiffon', $FFFACD), Named('lightblue', $ADD8E6),
    Named('lightcoral', $F08080), Named('lightcyan', $E0FFFF), Named('lightgoldenrodyellow', $FAFAD2),
    Named('lightgray', $D3D3D3), Named('lightgreen', $90EE90), Named('lightgrey', $D3D3D3),
    Named('lightpink', $FFB6C1), Named('lightsalmon', $FFA07A), Named('lightseagreen', $20B2AA),
    Named('lightskyblue', $87CEFA), Named('lightslategray', $778899), Named('lightslategrey', $778899),
    Named('lightsteelblue', $B0C4DE), Named('lightyellow', $FFFFE0), Named('lime', $00FF00),
    Named('limegreen', $32CD32), Named('linen', $FAF0E6), Named('magenta', $FF00FF), Named('maroon', $800000),
    Named('mediumaquamarine', $66CDAA), Named('mediumblue', $0000CD), Named('mediumorchid', $BA55D3),
    Named('mediumpurple', $9370DB), Named('mediumseagreen', $3CB371), Named('mediumslateblue', $7B68EE),
    Named('mediumspringgreen', $00FA9A), Named('mediumturquoise', $48D1CC), Named('mediumvioletred', $C71585),
    Named('midnightblue', $191970), Named('mintcream', $F5FFFA), Named('mistyrose', $FFE4E1),
    Named('moccasin', $FFE4B5), Named('navajowhite', $FFDEAD), Named('navy', $000080),
    Named('oldlace', $FDF5E6), Named('olive', $808000), Named('olivedrab', $6B8E23), Named('orange', $FFA500),
    Named('orangered', $FF4500), Named('orchid', $DA70D6), Named('palegoldenrod', $EEE8AA),
    Named('palegreen', $98FB98), Named('paleturquoise', $AFEEEE), Named('palevioletred', $DB7093),
    Named('papayawhip', $FFEFD5), Named('peachpuff', $FFDAB9), Named('peru', $CD853F), Named('pink', $FFC0CB),
    Named('plum', $DDA0DD), Named('powderblue', $B0E0E6), Named('purple', $800080),
    Named('rebeccapurple', $663399), Named('red', $FF0000), Named('rosybrown', $BC8F8F),
    Named('royalblue', $4169E1), Named('saddlebrown', $8B4513), Named('salmon', $FA8072),
    Named('sandybrown', $F4A460), Named('seagreen', $2E8B57), Named('seashell', $FFF5EE),
    Named('sienna', $A0522D), Named('silver', $C0C0C0), Named('skyblue', $87CEEB), Named('slateblue', $6A5ACD),
    Named('slategray', $708090), Named('slategrey', $708090), Named('snow', $FFFAFA),
    Named('springgreen', $00FF7F), Named('steelblue', $4682B4), Named('tan', $D2B48C), Named('teal', $008080),
    Named('thistle', $D8BFD8), Named('tomato', $FF6347), Named('turquoise', $40E0D0), Named('violet', $EE82EE),
    Named('wheat', $F5DEB3), Named('white', $FFFFFF), Named('whitesmoke', $F5F5F5), Named('yellow', $FFFF00),
    Named('yellowgreen', $9ACD32)]);
end;

class destructor TMarkdownColorNames.Destroy;
begin
  FColors.Free;
end;

class procedure TMarkdownColorNames.AddColors(const Colors: array of TNamedColor);
begin
  for var Color in Colors do
  begin
    FColors.Add(Color.Name, Color.Rgb);
  end;
end;

class function TMarkdownColorNames.Named(const Name: string; const Rgb: Cardinal): TNamedColor;
begin
  Result.Name := Name;
  Result.Rgb := Rgb;
end;

class function TMarkdownColorNames.TryParse(const Value: string; out Color: Cardinal): Boolean;
begin
  const Trimmed = Value.Trim;
  const Key = Trimmed.ToLower;

  var Rgb: Cardinal;
  if FColors.TryGetValue(Key, Rgb) then
  begin
    Color := OpaqueAlpha or Rgb;
    Exit(True);
  end;

  var Digits := Key;
  if Digits.StartsWith(HexPrefix) then
    Digits := Digits.Substring(Length(HexPrefix));

  Result := TryParseHex(Digits, Color);
end;

class function TMarkdownColorNames.TryParseHex(const Digits: string; out Color: Cardinal): Boolean;
begin
  Color := 0;

  const IsShort = (Digits.Length = ShortHexLength);
  const IsLong = (Digits.Length = LongHexLength);
  if not ((IsShort or IsLong) and IsHexDigits(Digits)) then
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
