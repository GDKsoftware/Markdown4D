unit Markdown4D.Image.Glyphs.Gdi;

{$SCOPEDENUMS ON}

// Reads glyph outlines from the fonts installed on Windows. The system font
// engine picks the face, applies the metrics and hands back the curves, so a
// drawing gets the same letters the rest of the application shows.
//
// The unit registers itself, and does nothing at all off Windows.

interface

procedure RegisterGdiGlyphOutliner;

implementation

{$IFDEF MSWINDOWS}
uses
  System.SysUtils,
  System.Math,
  Winapi.Windows,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Image.Glyphs;

const
  // Points along a quadratic curve segment. A letter at reading size needs
  // little more than this to look round.
  CurveSegments = 6;
  FixedScale = 65536.0;
  // Not declared by the RTL: asks the font engine for the outline as the
  // designer drew it, without the grid fitting a screen size would impose.
  UnhintedOutline = $0100;
  BoldWeight = 700;
  NormalWeight = 400;

type
  TOutlineReader = record
  private
    FData: TBytes;
    FIndex: Integer;
    FOffsetX: Single;
    function ReadWord: Word;
    function ReadLongWord: Cardinal;
    function ReadFixedPoint: TLayoutPointF;
  public
    class function Create(const Data: TBytes; const OffsetX: Single): TOutlineReader; static;
    function ReadContours: TArray<TArray<TLayoutPointF>>;
  end;

class function TOutlineReader.Create(const Data: TBytes; const OffsetX: Single): TOutlineReader;
begin
  Result.FData := Data;
  Result.FIndex := 0;
  Result.FOffsetX := OffsetX;
end;

function TOutlineReader.ReadWord: Word;
begin
  Result := FData[FIndex] or (Word(FData[FIndex + 1]) shl 8);
  Inc(FIndex, 2);
end;

function TOutlineReader.ReadLongWord: Cardinal;
begin
  Result := FData[FIndex] or (Cardinal(FData[FIndex + 1]) shl 8) or (Cardinal(FData[FIndex + 2]) shl 16) or
    (Cardinal(FData[FIndex + 3]) shl 24);
  Inc(FIndex, 4);
end;

// A POINTFX is two 16.16 fixed point numbers, and the outline grows downwards
// from the baseline where a raster grows down the page, so Y is flipped.
function TOutlineReader.ReadFixedPoint: TLayoutPointF;
begin
  const RawX = Integer(ReadLongWord);
  const RawY = Integer(ReadLongWord);

  Result := TLayoutPointF.Create(FOffsetX + RawX / FixedScale, -RawY / FixedScale);
end;

function TOutlineReader.ReadContours: TArray<TArray<TLayoutPointF>>;
begin
  Result := nil;

  while FIndex + SizeOf(TTPolygonHeader) <= Length(FData) do
  begin
    const HeaderStart = FIndex;
    const HeaderSize = ReadLongWord;
    if (HeaderSize = 0) or (HeaderStart + Integer(HeaderSize) > Length(FData)) then
      Exit;

    const HeaderType = ReadLongWord;
    var Points: TArray<TLayoutPointF> := [ReadFixedPoint];
    if HeaderType <> TT_POLYGON_TYPE then
      Exit;

    while FIndex < HeaderStart + Integer(HeaderSize) do
    begin
      const CurveType = ReadWord;
      const CurveCount = ReadWord;

      if CurveType = TT_PRIM_LINE then
      begin
        for var Step := 1 to CurveCount do
        begin
          Points := Points + [ReadFixedPoint];
        end;

        Continue;
      end;

      if CurveType <> TT_PRIM_QSPLINE then
        Exit;

      // Consecutive off-curve points share an implied on-curve point halfway
      // between them, which is how TrueType writes a run of curves.
      var Controls: TArray<TLayoutPointF> := nil;
      for var Step := 1 to CurveCount do
      begin
        Controls := Controls + [ReadFixedPoint];
      end;

      for var Index := 0 to High(Controls) do
      begin
        const Start = Points[High(Points)];
        const Control = Controls[Index];

        var Stop := Control;
        if Index < High(Controls) then
          Stop := TLayoutPointF.Create((Control.X + Controls[Index + 1].X) / 2,
            (Control.Y + Controls[Index + 1].Y) / 2)
        else
          Stop := Controls[Index];

        if Index = High(Controls) then
        begin
          Points := Points + [Stop];
          Continue;
        end;

        for var Step := 1 to CurveSegments do
        begin
          const T = Step / CurveSegments;
          const Inverse = 1 - T;

          Points := Points + [TLayoutPointF.Create(
            Inverse * Inverse * Start.X + 2 * Inverse * T * Control.X + T * T * Stop.X,
            Inverse * Inverse * Start.Y + 2 * Inverse * T * Control.Y + T * T * Stop.Y)];
        end;
      end;
    end;

    if Length(Points) >= 3 then
      Result := Result + [Points];

    FIndex := HeaderStart + Integer(HeaderSize);
  end;
end;

function CreateOutlineFont(const FamilyName: string; const PixelSize: Single; const Bold, Italic: Boolean): HFONT;
begin
  var Description := Default(TLogFont);
  Description.lfHeight := -Round(PixelSize);
  Description.lfWeight := NormalWeight;
  if Bold then
    Description.lfWeight := BoldWeight;
  Description.lfItalic := Byte(Italic);
  Description.lfCharSet := DEFAULT_CHARSET;
  Description.lfOutPrecision := OUT_TT_ONLY_PRECIS;
  Description.lfQuality := DEFAULT_QUALITY;
  StrLCopy(Description.lfFaceName, PChar(FamilyName), Length(Description.lfFaceName) - 1);

  Result := CreateFontIndirect(Description);
end;

function OutlineText(const FamilyName: string; const PixelSize: Single; const Bold, Italic: Boolean;
  const Text: string; out Run: TMarkdownGlyphRun): Boolean;
const
  Identity: TMat2 = (eM11: (fract: 0; value: 1); eM12: (fract: 0; value: 0); eM21: (fract: 0; value: 0);
    eM22: (fract: 0; value: 1));
begin
  Run := Default(TMarkdownGlyphRun);

  const Screen = GetDC(0);
  if Screen = 0 then
    Exit(False);

  try
    const Memory = CreateCompatibleDC(Screen);
    if Memory = 0 then
      Exit(False);

    try
      const Font = CreateOutlineFont(FamilyName, PixelSize, Bold, Italic);
      if Font = 0 then
        Exit(False);

      try
        const Previous = SelectObject(Memory, Font);
        try
          var Pen: Single := 0;

          for var Character in Text do
          begin
            var Metrics := Default(TGlyphMetrics);
            const Size = GetGlyphOutlineW(Memory, Ord(Character), GGO_NATIVE or UnhintedOutline, Metrics, 0, nil,
              Identity);
            if Size = GDI_ERROR then
              Exit(False);

            if Size > 0 then
            begin
              var Data: TBytes;
              SetLength(Data, Size);
              if GetGlyphOutlineW(Memory, Ord(Character), GGO_NATIVE or UnhintedOutline, Metrics, Size, Data,
                Identity) = GDI_ERROR then
                Exit(False);

              var Reader := TOutlineReader.Create(Data, Pen);
              Run.Contours := Run.Contours + Reader.ReadContours;
            end;

            Pen := Pen + Metrics.gmCellIncX;
          end;

          Run.Advance := Pen;
          Result := Length(Run.Contours) > 0;
        finally
          SelectObject(Memory, Previous);
        end;
      finally
        DeleteObject(Font);
      end;
    finally
      DeleteDC(Memory);
    end;
  finally
    ReleaseDC(0, Screen);
  end;
end;

procedure RegisterGdiGlyphOutliner;
begin
  TMarkdownGlyphSupport.RegisterOutliner(OutlineText);
end;

initialization
  RegisterGdiGlyphOutliner;

{$ELSE}

procedure RegisterGdiGlyphOutliner;
begin
end;

{$ENDIF}

end.
