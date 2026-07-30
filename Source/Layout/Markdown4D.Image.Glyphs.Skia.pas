unit Markdown4D.Image.Glyphs.Skia;

{$SCOPEDENUMS ON}

// Reads glyph outlines through Skia, which ships with RAD Studio and speaks the
// same way on every platform Delphi builds for. This is what makes text in an
// SVG render on macOS, iOS, Android and Linux, where the Windows font engine
// cannot go.
//
// Skia hands a glyph back as a path, and a path knows how to write itself as
// SVG path data, so the outlines come home through the parser this project
// already has.
//
// The unit registers itself only when nothing else has, so a Windows
// application keeps the font engine it already has and needs no library
// alongside it. Where the Skia library is missing, registration quietly does
// nothing rather than failing the application that linked this unit.

interface

procedure RegisterSkiaGlyphOutliner;

implementation

{$IFNDEF MSWINDOWS}

uses
  System.SysUtils,
  System.Types,
  System.Skia,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Image.Glyphs,
  Markdown4D.Image.Svg.Path;

function OutlineText(const FamilyName: string; const PixelSize: Single; const Bold, Italic: Boolean;
  const Text: string; out Run: TMarkdownGlyphRun): Boolean;
begin
  Run := Default(TMarkdownGlyphRun);

  try
    var Weight := TSkFontWeight.Normal;
    if Bold then
      Weight := TSkFontWeight.Bold;

    var Slant := TSkFontSlant.Upright;
    if Italic then
      Slant := TSkFontSlant.Italic;

    var Typeface: ISkTypeface := TSkTypeface.MakeFromName(FamilyName,
      TSkFontStyle.Create(Weight, TSkFontWidth.Normal, Slant));
    if Typeface = nil then
      Exit(False);

    // Through the interface: the outline of a glyph is reached there, not on
    // the class.
    var Font: ISkFont := TSkFont.Create(Typeface, PixelSize);
    const Glyphs = Font.GetGlyphs(Text);
    if Length(Glyphs) = 0 then
      Exit(False);

    var Widths: TArray<Single>;
    var Bounds: TArray<TRectF>;
    Font.GetWidthsAndBounds(Glyphs, Widths, Bounds);

    var Pen: Single := 0;
    for var Index := 0 to High(Glyphs) do
    begin
      var Path: ISkPath := Font.GetPath(Glyphs[Index]);
      if Path <> nil then
      begin
        // Skia draws text with the baseline at the origin and y growing down,
        // which is the space an SVG is written in, so only the pen moves.
        for var SubPath in TSvgPathParser.Parse(Path.ToSVG) do
        begin
          var Contour: TArray<TLayoutPointF>;
          SetLength(Contour, Length(SubPath.Points));
          for var Point := 0 to High(SubPath.Points) do
          begin
            Contour[Point] := TLayoutPointF.Create(SubPath.Points[Point].X + Pen, SubPath.Points[Point].Y);
          end;

          Run.Contours := Run.Contours + [Contour];
        end;
      end;

      if Index <= High(Widths) then
        Pen := Pen + Widths[Index];
    end;

    Run.Advance := Pen;
    Result := Length(Run.Contours) > 0;
  except
    // A missing or unusable Skia library is a text run this engine cannot
    // draw, not an application that fails to start.
    on Exception do
      Result := False;
  end;
end;

procedure RegisterSkiaGlyphOutliner;
begin
  if TMarkdownGlyphSupport.IsAvailable then
    Exit;

  TMarkdownGlyphSupport.RegisterOutliner(OutlineText);
end;

initialization
  RegisterSkiaGlyphOutliner;

{$ELSE}

// On Windows the font engine and the imaging library of the system already
// answer, and linking Skia here would make every application carry its
// library whether it draws an SVG or not: the Skia objects load it as the
// program starts, not when something is first asked of them.
procedure RegisterSkiaGlyphOutliner;
begin
end;

{$ENDIF}

end.
