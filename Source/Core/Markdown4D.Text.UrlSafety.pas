unit Markdown4D.Text.UrlSafety;

{$SCOPEDENUMS ON}

// Link and image destinations come straight out of the document, so a document
// can carry a destination that executes code the moment a reader clicks it.
// This unit decides which destinations may reach the output, using the same
// rule set as cmark's safe mode: the scripting schemes are dropped, and data:
// survives only for the four image types that cannot carry script.

interface

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
    class function SchemeProbe(const Url: string): string;

  public
    class function IsDangerous(const Url: string): Boolean;
    class function Sanitized(const Url: string): string;
  end;

implementation

uses
  System.SysUtils;

class function TMarkdownUrlSafety.IsDangerous(const Url: string): Boolean;
begin
  const Probe = SchemeProbe(Url);

  for var Scheme in DangerousSchemes do
  begin
    if Probe.StartsWith(Scheme) then
      Exit(True);
  end;

  if not Probe.StartsWith(DataScheme) then
    Exit(False);

  for var Prefix in SafeDataPrefixes do
  begin
    if Probe.StartsWith(Prefix) then
      Exit(False);
  end;

  Result := True;
end;

class function TMarkdownUrlSafety.Sanitized(const Url: string): string;
begin
  if IsDangerous(Url) then
    Exit('');

  Result := Url;
end;

// A browser strips whitespace and control characters before it reads the scheme,
// so "java&#9;script:x" and " JavaScript:x" both have to be judged as
// "javascript:". Only the leading characters matter, which keeps this cheap for
// documents with many links.
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

end.
