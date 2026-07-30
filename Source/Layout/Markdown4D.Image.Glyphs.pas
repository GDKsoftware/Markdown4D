unit Markdown4D.Image.Glyphs;

{$SCOPEDENUMS ON}

// Where the outlines of a piece of text come from. Turning a font into
// contours is the one part of drawing an SVG that needs to know about the
// machine it runs on, so it lives behind this seam: the layer that can ask the
// system registers a provider, and everything above it stays neutral.

interface

uses
  System.SysUtils,
  Markdown4D.Layout.Interfaces;

type
  // The outlines of a run of text, laid out from an origin at the baseline
  // start, in the same units as the size that was asked for.
  TMarkdownGlyphRun = record
    Contours: TArray<TArray<TLayoutPointF>>;
    Advance: Single;
  end;

  TMarkdownGlyphOutliner = reference to function(const FamilyName: string; const PixelSize: Single;
    const Bold, Italic: Boolean; const Text: string; out Run: TMarkdownGlyphRun): Boolean;

  TMarkdownGlyphSupport = class
  strict private
    class var FOutliner: TMarkdownGlyphOutliner;
  public
    class procedure RegisterOutliner(const Outliner: TMarkdownGlyphOutliner); static;
    class function IsAvailable: Boolean; static;
    class function TryOutline(const FamilyName: string; const PixelSize: Single; const Bold, Italic: Boolean;
      const Text: string; out Run: TMarkdownGlyphRun): Boolean; static;
  end;

implementation

class procedure TMarkdownGlyphSupport.RegisterOutliner(const Outliner: TMarkdownGlyphOutliner);
begin
  FOutliner := Outliner;
end;

class function TMarkdownGlyphSupport.IsAvailable: Boolean;
begin
  Result := Assigned(FOutliner);
end;

class function TMarkdownGlyphSupport.TryOutline(const FamilyName: string; const PixelSize: Single;
  const Bold, Italic: Boolean; const Text: string; out Run: TMarkdownGlyphRun): Boolean;
begin
  Run := Default(TMarkdownGlyphRun);

  if (not Assigned(FOutliner)) or (Text = '') or (PixelSize <= 0) then
    Exit(False);

  Result := FOutliner(FamilyName, PixelSize, Bold, Italic, Text, Run);
end;

end.
