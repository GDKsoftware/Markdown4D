unit Markdown4D.Fmx.Glyphs;

{$SCOPEDENUMS ON}

// Reads glyph outlines through FMX itself, which speaks to whatever draws text
// on the platform it was built for. This is what carries text in an SVG to
// macOS, iOS, Android and Linux with nothing deployed beside the application.
//
// FMX turns a laid out run into a path and a path writes itself as path data,
// so the outlines come home through the parser this project already has.
//
// The unit registers itself only when nothing else has, so a Windows
// application keeps the system font engine it already reached for.

interface

procedure RegisterFmxGlyphOutliner;

implementation

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Generics.Collections,
  FMX.Graphics,
  FMX.TextLayout,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Image.Glyphs,
  Markdown4D.Image.Svg.Path;

type
  TFmxGlyphOutliner = class
  strict private
    const
      // A capital H is flat along the bottom and rests on the baseline in every
      // Latin face, so where its outline ends is where the baseline runs.
      BaselineProbe = 'H';
    class var FBaselines: TDictionary<string, Single>;
    class function LayoutFor(const FamilyName: string; const PixelSize: Single;
      const Bold, Italic: Boolean; const Text: string): TTextLayout; static;
    class function BaselineOf(const FamilyName: string; const PixelSize: Single;
      const Bold, Italic: Boolean): Single; static;

  public
    class constructor Create;
    class destructor Destroy;
    class function TryOutline(const FamilyName: string; const PixelSize: Single; const Bold, Italic: Boolean;
      const Text: string; out Run: TMarkdownGlyphRun): Boolean; static;
  end;

class constructor TFmxGlyphOutliner.Create;
begin
  FBaselines := TDictionary<string, Single>.Create;
end;

class destructor TFmxGlyphOutliner.Destroy;
begin
  FBaselines.Free;
end;

class function TFmxGlyphOutliner.LayoutFor(const FamilyName: string; const PixelSize: Single;
  const Bold, Italic: Boolean; const Text: string): TTextLayout;
begin
  Result := TTextLayoutManager.DefaultTextLayout.Create;

  Result.BeginUpdate;
  try
    Result.Font.Family := FamilyName;
    Result.Font.Size := PixelSize;

    var Style: TFontStyles := [];
    if Bold then
      Include(Style, TFontStyle.fsBold);
    if Italic then
      Include(Style, TFontStyle.fsItalic);
    Result.Font.Style := Style;

    Result.Text := Text;
    Result.WordWrap := False;
    Result.TopLeft := TPointF.Create(0, 0);
  finally
    Result.EndUpdate;
  end;
end;

// FMX lays text out from the top of its line box, while a glyph run is measured
// from the baseline. The distance between the two is what the probe measures,
// and it only depends on the font and its size, so it is remembered.
class function TFmxGlyphOutliner.BaselineOf(const FamilyName: string; const PixelSize: Single;
  const Bold, Italic: Boolean): Single;
begin
  const Key = Format('%s|%.2f|%d%d', [FamilyName, PixelSize, Ord(Bold), Ord(Italic)]);

  if FBaselines.TryGetValue(Key, Result) then
    Exit;

  Result := 0;

  const Layout = LayoutFor(FamilyName, PixelSize, Bold, Italic, BaselineProbe);
  try
    const Path = TPathData.Create;
    try
      Layout.ConvertToPath(Path);
      if not Path.IsEmpty then
        Result := Path.GetBounds.Bottom;
    finally
      Path.Free;
    end;
  finally
    Layout.Free;
  end;

  FBaselines.AddOrSetValue(Key, Result);
end;

class function TFmxGlyphOutliner.TryOutline(const FamilyName: string; const PixelSize: Single;
  const Bold, Italic: Boolean; const Text: string; out Run: TMarkdownGlyphRun): Boolean;
begin
  Run := Default(TMarkdownGlyphRun);

  try
    const Baseline = BaselineOf(FamilyName, PixelSize, Bold, Italic);

    const Layout = LayoutFor(FamilyName, PixelSize, Bold, Italic, Text);
    try
      const Path = TPathData.Create;
      try
        Layout.ConvertToPath(Path);
        if Path.IsEmpty then
          Exit(False);

        for var SubPath in TSvgPathParser.Parse(Path.Data) do
        begin
          var Contour: TArray<TLayoutPointF>;
          SetLength(Contour, Length(SubPath.Points));
          for var Index := 0 to High(SubPath.Points) do
          begin
            Contour[Index] := TLayoutPointF.Create(SubPath.Points[Index].X,
              SubPath.Points[Index].Y - Baseline);
          end;

          Run.Contours := Run.Contours + [Contour];
        end;

        Run.Advance := Layout.TextWidth;
        Result := Length(Run.Contours) > 0;
      finally
        Path.Free;
      end;
    finally
      Layout.Free;
    end;
  except
    // A platform that cannot lay this run out is a text run this engine will
    // not draw, not an application that fails.
    on Exception do
      Result := False;
  end;
end;

procedure RegisterFmxGlyphOutliner;
begin
  if TMarkdownGlyphSupport.IsAvailable then
    Exit;

  TMarkdownGlyphSupport.RegisterOutliner(TFmxGlyphOutliner.TryOutline);
end;

initialization
  RegisterFmxGlyphOutliner;

end.
