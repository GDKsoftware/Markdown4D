unit Markdown4D.Text.UrlSafety;

{$SCOPEDENUMS ON}

// Link and image destinations come straight out of the document, so a document
// can carry a destination that executes code the moment a reader clicks it.
// This unit decides which destinations may reach the output, using the same
// rule set as cmark's safe mode: the scripting schemes are dropped, and data:
// survives only for the four image types that cannot carry script.

interface

uses
  System.SysUtils;

type
  TMarkdownUrlSafety = class
  private
    const
      // Long enough for the longest prefix that is compared below.
      MaxProbeLength = 24;
      DangerousSchemes: array[0..2] of string = ('javascript:', 'vbscript:', 'file:');
      DataScheme = 'data:';
      SafeDataPrefixes: array[0..3] of string = ('data:image/png', 'data:image/gif', 'data:image/jpeg',
        'data:image/webp');
      SchemeSeparator = ':';
      // A browser reads //host/path, and also \\host or /\host, as a link to
      // another host over the page's own protocol, which on the web is https.
      ProtocolRelativeScheme = 'https';
      ProtocolRelativePrefixLength = 2;
      FirstCharacterLength = 1;
      PathSeparators: TSysCharSet = ['/', '\'];
      SchemeLetters: TSysCharSet = ['a'..'z', 'A'..'Z'];
      SchemeCharacters: TSysCharSet = ['a'..'z', 'A'..'Z', '0'..'9', '+', '-', '.'];
      SchemeTerminators: array[0..4] of Char = (':', '/', '\', '?', '#');
      InvalidSchemeMessage = 'Invalid URL scheme name: "%s"';
    class function SchemeProbe(const Url: string): string;
    class function IsListed(const Scheme: string; const AllowedSchemes: TArray<string>): Boolean;
    class function BareScheme(const Scheme: string): string;
    class function EffectiveScheme(const Url: string): string;
    class function SchemePrefix(const Url: string): string;
    class function IsProtocolRelative(const Prefix: string): Boolean;
    class function IsSchemeName(const Candidate: string): Boolean;

  public
    class function IsDangerous(const Url: string): Boolean;
    class function Sanitized(const Url: string): string;
    // Stricter than IsDangerous alone: a list of schemes cannot reopen what the
    // blocklist closes, so a dangerous destination stays out even when listed.
    class function IsAllowed(const Url: string; const AllowedSchemes: TArray<string>): Boolean;
    // Raises for a name that is not a scheme, such as 'https://', so a mistake
    // in a configuration shows at once instead of dropping every link.
    class function NormalizedScheme(const Scheme: string): string;
  end;

implementation

uses
  Markdown4D.Defines;

class function TMarkdownUrlSafety.IsDangerous(const Url: string): Boolean;
begin
  const Probe = SchemeProbe(Url);

  for var Scheme in DangerousSchemes do
  begin
    if Probe.StartsWith(Scheme) then
    begin
      Result := True;
      Exit;
    end;
  end;

  if not Probe.StartsWith(DataScheme) then
  begin
    Result := False;
    Exit;
  end;

  for var Prefix in SafeDataPrefixes do
  begin
    if Probe.StartsWith(Prefix) then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

class function TMarkdownUrlSafety.Sanitized(const Url: string): string;
begin
  if IsDangerous(Url) then
  begin
    Result := '';
    Exit;
  end;

  Result := Url;
end;

class function TMarkdownUrlSafety.IsAllowed(const Url: string; const AllowedSchemes: TArray<string>): Boolean;
begin
  Result := False;
  if IsDangerous(Url) then
    Exit;

  const Scheme = EffectiveScheme(Url);
  const IsRelative = (Scheme.IsEmpty);
  Result := (IsRelative or IsListed(Scheme, AllowedSchemes));
end;

class function TMarkdownUrlSafety.NormalizedScheme(const Scheme: string): string;
begin
  Result := BareScheme(Scheme);

  const IsValid = (IsSchemeName(Result));
  if not IsValid then
    raise EMarkdownError.CreateFmt(InvalidSchemeMessage, [Scheme]);
end;

// A browser drops tab, line feed and carriage return anywhere in a URL and other
// control characters and spaces at its ends. Dropping all of them everywhere is
// stricter, so a trick with them fails closed: "java&#9;script:x" and
// " JavaScript:x" are both judged as "javascript:". Only the leading characters
// matter, which keeps this cheap for documents with many links.
class function TMarkdownUrlSafety.SchemeProbe(const Url: string): string;
begin
  const Builder = TStringBuilder.Create;
  try
    for var Current in Url do
    begin
      if Builder.Length >= MaxProbeLength then
        Break;

      if Current > ' ' then
        Builder.Append(Current);
    end;

    Result := Builder.ToString.ToLowerInvariant;
  finally
    Builder.Free;
  end;
end;

// Entries are compared as BareScheme leaves them, so a list filled in directly
// with 'HTTPS' or 'https:' still means https. SameText compares ASCII letters
// without regard to the user's locale.
class function TMarkdownUrlSafety.IsListed(const Scheme: string; const AllowedSchemes: TArray<string>): Boolean;
begin
  Result := False;

  for var Entry in AllowedSchemes do
  begin
    const Listed = BareScheme(Entry);
    const IsMatch = (SameText(Listed, Scheme));
    if IsMatch then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

class function TMarkdownUrlSafety.BareScheme(const Scheme: string): string;
begin
  const Trimmed = Scheme.Trim;
  const WithoutSeparator = Trimmed.TrimRight([SchemeSeparator]);
  Result := WithoutSeparator.ToLowerInvariant;
end;

// A long made-up scheme must not pass for a relative path, so there is no
// fixed window here: the prefix runs to the first character that cannot be
// part of a scheme. Without a valid scheme before the first path, query or
// fragment character the destination is relative, and the result is empty.
class function TMarkdownUrlSafety.EffectiveScheme(const Url: string): string;
begin
  Result := '';

  const Prefix = SchemePrefix(Url);
  if IsProtocolRelative(Prefix) then
  begin
    Result := ProtocolRelativeScheme;
    Exit;
  end;

  const TerminatorIndex = Prefix.IndexOfAny(SchemeTerminators);
  const HasTerminator = (TerminatorIndex >= 0);
  if not HasTerminator then
    Exit;

  const EndsAtSeparator = (Prefix.Chars[TerminatorIndex] = SchemeSeparator);
  if not EndsAtSeparator then
    Exit;

  const Candidate = Prefix.Substring(0, TerminatorIndex);
  if IsSchemeName(Candidate) then
    Result := Candidate.ToLowerInvariant;
end;

// The characters that decide the scheme, with spaces and control characters
// left out as SchemeProbe does: everything up to and including the first one
// that cannot be part of a scheme name. A single leading separator does not
// end it, so a protocol-relative start is seen whole.
class function TMarkdownUrlSafety.SchemePrefix(const Url: string): string;
begin
  const Builder = TStringBuilder.Create;
  try
    for var Current in Url do
    begin
      const IsIgnored = (Current <= ' ');
      if IsIgnored then
        Continue;

      Builder.Append(Current);

      const IsFirstCharacter = (Builder.Length = FirstCharacterLength);
      const IsSchemeCharacter = (CharInSet(Current, SchemeCharacters));
      const IsLeadingSeparator = (IsFirstCharacter and CharInSet(Current, PathSeparators));
      const EndsPrefix = (not (IsSchemeCharacter or IsLeadingSeparator));
      if EndsPrefix then
        Break;
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TMarkdownUrlSafety.IsProtocolRelative(const Prefix: string): Boolean;
begin
  Result := False;

  const IsLongEnough = (Prefix.Length >= ProtocolRelativePrefixLength);
  if not IsLongEnough then
    Exit;

  const FirstIsSeparator = (CharInSet(Prefix.Chars[0], PathSeparators));
  const SecondIsSeparator = (CharInSet(Prefix.Chars[1], PathSeparators));
  Result := (FirstIsSeparator and SecondIsSeparator);
end;

// RFC 3986: an ASCII letter, then ASCII letters, digits, plus, minus and full stop.
class function TMarkdownUrlSafety.IsSchemeName(const Candidate: string): Boolean;
begin
  Result := False;
  if Candidate.IsEmpty then
    Exit;

  const StartsWithLetter = (CharInSet(Candidate.Chars[0], SchemeLetters));
  if not StartsWithLetter then
    Exit;

  for var Current in Candidate do
  begin
    const IsSchemeCharacter = (CharInSet(Current, SchemeCharacters));
    if not IsSchemeCharacter then
      Exit;
  end;

  Result := True;
end;

end.
