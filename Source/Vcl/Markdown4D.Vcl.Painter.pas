unit Markdown4D.Vcl.Painter;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
  Winapi.Windows,
  Vcl.Graphics,
  Markdown4D.Layout.Defaults,
  Markdown4D.Layout.Interfaces;

type
  TMarkdownVclImageResolver = reference to function(const Source: string): TGraphic;

  TMarkdownVclBrokenImageQuery = reference to function(const Source: string): Boolean;

  TMarkdownVclPainter = class(TInterfacedObject, IPainter)
  private
    const
      OpaqueAlpha = $FF;
      PlaceholderBorderColor = TLayoutColor($FF9E9E9E);
      PlaceholderStrokeWidth = 1.0;
      BrokenImageCrossColor = TLayoutColor($FFC0392B);
    var
      FCanvas: TCanvas;
      FPixelsPerInch: Integer;
      FSavedStates: TStack<Integer>;
      FFamilyCache: TDictionary<string, string>;
      FMetricsCache: TDictionary<string, TTextMetric>;
      FAppliedFontKey: string;
      FHasAppliedFont: Boolean;
      FImageResolver: TMarkdownVclImageResolver;
      FBrokenImageQuery: TMarkdownVclBrokenImageQuery;
    procedure ApplyFont(const Font: TMarkdownFontStyle);
    function FontKey(const Font: TMarkdownFontStyle): string;
    function FontPixelHeight(const Font: TMarkdownFontStyle): Integer;
    class function FontStylesOf(const Font: TMarkdownFontStyle): TFontStyles;
    function ResolveFamilyName(const FamilyName: string): string;
    class function LookupFamilyName(const FamilyName: string): string;
    class function IsFamilyInstalled(const FamilyName: string): Boolean;
    function TextMetricsOf(const Font: TMarkdownFontStyle): TTextMetric;
    procedure FillRectOpaque(const Bounds: TLayoutRectF; const Color: TLayoutColor);
    procedure FillRectBlended(const Bounds: TLayoutRectF; const Color: TLayoutColor);
    procedure DrawResolvedImage(const Bounds: TLayoutRectF; const Graphic: TGraphic; const SourceRect: TLayoutRectF);
    procedure BlitBitmap(const Bounds: TLayoutRectF; const Bitmap: TBitmap; const SourceRect: TLayoutRectF);
    procedure DrawImagePlaceholder(const Bounds: TLayoutRectF);
    procedure DrawBrokenImagePlaceholder(const Bounds: TLayoutRectF);
    procedure FillDevicePolygonOpaque(const Points: TArray<TPoint>; const Color: TLayoutColor);
    procedure FillDevicePolygonBlended(const Points: TArray<TPoint>; const Bounds: TLayoutRectF;
      const Color: TLayoutColor);
    class function WedgePolygon(const Center: TLayoutPointF;
      const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single): TArray<TPoint>;
    class function PremultipliedPixel(const Color: TLayoutColor): Cardinal;
    class function ToVclColor(const Color: TLayoutColor): TColor;
    class function AlphaOf(const Color: TLayoutColor): Byte;
    class function ToDeviceRect(const Bounds: TLayoutRectF): TRect;
    class function OpaqueBlendFunction: TBlendFunction;

  public
    constructor Create(const Canvas: TCanvas; const PixelsPerInch: Integer = ReferencePixelsPerInch);
    destructor Destroy; override;
    function MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
    function LineHeight(const Font: TMarkdownFontStyle): Single;
    function Baseline(const Font: TMarkdownFontStyle): Single;
    procedure DrawTextRun(const TopLeft: TLayoutPointF; const Text: string; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor);
    procedure FillRect(const Bounds: TLayoutRectF; const Color: TLayoutColor);
    procedure DrawRect(const Bounds: TLayoutRectF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
      const StrokeWidth: Single);
    procedure DrawImage(const Bounds: TLayoutRectF; const Source: string; const SourceRect: TLayoutRectF);
    procedure FillWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const Color: TLayoutColor);
    procedure FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
    procedure SaveState;
    procedure SetClip(const Bounds: TLayoutRectF);
    procedure RestoreState;
    property PixelsPerInch: Integer read FPixelsPerInch write FPixelsPerInch;
    property ImageResolver: TMarkdownVclImageResolver read FImageResolver write FImageResolver;
    property BrokenImageQuery: TMarkdownVclBrokenImageQuery read FBrokenImageQuery write FBrokenImageQuery;
  end;

implementation

uses
  System.Math,
  Vcl.Forms,
  Markdown4D.Defines;

constructor TMarkdownVclPainter.Create(const Canvas: TCanvas; const PixelsPerInch: Integer);
begin
  inherited Create;

  FCanvas := Canvas;
  FPixelsPerInch := PixelsPerInch;
  FSavedStates := TStack<Integer>.Create;
  FFamilyCache := TDictionary<string, string>.Create;
  FMetricsCache := TDictionary<string, TTextMetric>.Create;
end;

destructor TMarkdownVclPainter.Destroy;
begin
  FMetricsCache.Free;
  FFamilyCache.Free;
  FSavedStates.Free;

  inherited Destroy;
end;

function TMarkdownVclPainter.MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
begin
  ApplyFont(Font);

  const Extent = FCanvas.TextExtent(Text);
  const Metrics = TextMetricsOf(Font);
  Result := TLayoutSizeF.Create(Extent.cx, Metrics.tmHeight + Metrics.tmExternalLeading);
end;

function TMarkdownVclPainter.LineHeight(const Font: TMarkdownFontStyle): Single;
begin
  const Metrics = TextMetricsOf(Font);
  Result := Metrics.tmHeight + Metrics.tmExternalLeading;
end;

function TMarkdownVclPainter.Baseline(const Font: TMarkdownFontStyle): Single;
begin
  Result := TextMetricsOf(Font).tmAscent;
end;

procedure TMarkdownVclPainter.DrawTextRun(const TopLeft: TLayoutPointF; const Text: string;
  const Font: TMarkdownFontStyle; const Color: TLayoutColor);
begin
  ApplyFont(Font);
  FCanvas.Font.Color := ToVclColor(Color);
  FCanvas.Brush.Style := bsClear;

  const BaselineY = TopLeft.Y + TextMetricsOf(Font).tmAscent;
  const Handle = FCanvas.Handle;
  const PreviousAlign = GetTextAlign(Handle);
  SetTextAlign(Handle, TA_LEFT or TA_BASELINE);
  SetBkMode(Handle, TRANSPARENT);
  ExtTextOut(Handle, Round(TopLeft.X), Round(BaselineY), 0, nil, PChar(Text), Length(Text), nil);
  SetTextAlign(Handle, PreviousAlign);
end;

procedure TMarkdownVclPainter.FillRect(const Bounds: TLayoutRectF; const Color: TLayoutColor);
begin
  const Alpha = AlphaOf(Color);
  if Alpha = 0 then
    Exit;

  if Alpha = OpaqueAlpha then
    FillRectOpaque(Bounds, Color)
  else
    FillRectBlended(Bounds, Color);
end;

procedure TMarkdownVclPainter.FillRectOpaque(const Bounds: TLayoutRectF; const Color: TLayoutColor);
begin
  FCanvas.Brush.Style := bsSolid;
  FCanvas.Brush.Color := ToVclColor(Color);
  FCanvas.FillRect(ToDeviceRect(Bounds));
end;

procedure TMarkdownVclPainter.FillRectBlended(const Bounds: TLayoutRectF; const Color: TLayoutColor);
begin
  const Cell = TBitmap.Create;
  try
    Cell.PixelFormat := pf32bit;
    Cell.SetSize(1, 1);
    PCardinal(Cell.ScanLine[0])^ := PremultipliedPixel(Color);

    const Dest = ToDeviceRect(Bounds);
    const Blend = OpaqueBlendFunction;
    AlphaBlend(FCanvas.Handle, Dest.Left, Dest.Top, Dest.Width, Dest.Height, Cell.Canvas.Handle, 0, 0, 1, 1, Blend);
  finally
    Cell.Free;
  end;
end;

procedure TMarkdownVclPainter.DrawRect(const Bounds: TLayoutRectF; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  const IsInvisible = (AlphaOf(Color) = 0) or (StrokeWidth <= 0);
  if IsInvisible then
    Exit;

  FCanvas.Pen.Style := psSolid;
  FCanvas.Pen.Color := ToVclColor(Color);
  FCanvas.Pen.Width := Round(StrokeWidth);
  if FCanvas.Pen.Width < 1 then
    FCanvas.Pen.Width := 1;
  FCanvas.Brush.Style := bsClear;

  const Dest = ToDeviceRect(Bounds);
  FCanvas.Rectangle(Dest.Left, Dest.Top, Dest.Right, Dest.Bottom);
end;

procedure TMarkdownVclPainter.DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  if AlphaOf(Color) = 0 then
    Exit;

  FCanvas.Pen.Style := psSolid;
  FCanvas.Pen.Color := ToVclColor(Color);
  FCanvas.Pen.Width := Round(StrokeWidth);
  if FCanvas.Pen.Width < 1 then
    FCanvas.Pen.Width := 1;

  FCanvas.MoveTo(Round(StartPoint.X), Round(StartPoint.Y));
  FCanvas.LineTo(Round(EndPoint.X), Round(EndPoint.Y));
end;

procedure TMarkdownVclPainter.DrawImage(const Bounds: TLayoutRectF; const Source: string;
  const SourceRect: TLayoutRectF);
begin
  var Graphic: TGraphic := nil;
  if Assigned(FImageResolver) then
    Graphic := FImageResolver(Source);

  const IsAvailable = (Graphic <> nil) and not Graphic.Empty;
  if IsAvailable then
  begin
    DrawResolvedImage(Bounds, Graphic, SourceRect);
    Exit;
  end;

  const IsBroken = Assigned(FBrokenImageQuery) and FBrokenImageQuery(Source);
  if IsBroken then
    DrawBrokenImagePlaceholder(Bounds)
  else
    DrawImagePlaceholder(Bounds);
end;

procedure TMarkdownVclPainter.DrawResolvedImage(const Bounds: TLayoutRectF; const Graphic: TGraphic;
  const SourceRect: TLayoutRectF);
begin
  if Graphic is TBitmap then
  begin
    BlitBitmap(Bounds, TBitmap(Graphic), SourceRect);
    Exit;
  end;

  const Converted = TBitmap.Create;
  try
    Converted.Assign(Graphic);
    BlitBitmap(Bounds, Converted, SourceRect);
  finally
    Converted.Free;
  end;
end;

procedure TMarkdownVclPainter.BlitBitmap(const Bounds: TLayoutRectF; const Bitmap: TBitmap;
  const SourceRect: TLayoutRectF);
begin
  var Source := TRect.Create(0, 0, Bitmap.Width, Bitmap.Height);
  const HasSourceRect = (SourceRect.Width > 0) and (SourceRect.Height > 0);
  if HasSourceRect then
    Source := ToDeviceRect(SourceRect);

  const Dest = ToDeviceRect(Bounds);
  const HasAlphaChannel = (Bitmap.PixelFormat = pf32bit) and (Bitmap.AlphaFormat <> afIgnored);
  if HasAlphaChannel then
  begin
    const Blend = OpaqueBlendFunction;
    AlphaBlend(FCanvas.Handle, Dest.Left, Dest.Top, Dest.Width, Dest.Height, Bitmap.Canvas.Handle,
      Source.Left, Source.Top, Source.Width, Source.Height, Blend);
    Exit;
  end;

  SetStretchBltMode(FCanvas.Handle, HALFTONE);
  SetBrushOrgEx(FCanvas.Handle, 0, 0, nil);
  StretchBlt(FCanvas.Handle, Dest.Left, Dest.Top, Dest.Width, Dest.Height, Bitmap.Canvas.Handle,
    Source.Left, Source.Top, Source.Width, Source.Height, SRCCOPY);
end;

procedure TMarkdownVclPainter.DrawImagePlaceholder(const Bounds: TLayoutRectF);
begin
  DrawRect(Bounds, PlaceholderBorderColor, PlaceholderStrokeWidth);
end;

procedure TMarkdownVclPainter.DrawBrokenImagePlaceholder(const Bounds: TLayoutRectF);
begin
  DrawRect(Bounds, PlaceholderBorderColor, PlaceholderStrokeWidth);
  DrawLine(TLayoutPointF.Create(Bounds.Left, Bounds.Top), TLayoutPointF.Create(Bounds.Right, Bounds.Bottom),
    BrokenImageCrossColor, PlaceholderStrokeWidth);
  DrawLine(TLayoutPointF.Create(Bounds.Right, Bounds.Top), TLayoutPointF.Create(Bounds.Left, Bounds.Bottom),
    BrokenImageCrossColor, PlaceholderStrokeWidth);
end;

procedure TMarkdownVclPainter.FillWedge(const Center: TLayoutPointF;
  const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single; const Color: TLayoutColor);
begin
  const Alpha = AlphaOf(Color);
  if (Alpha = 0) or (OuterRadius <= 0) or (SweepAngle = 0) then
    Exit;

  const Points = WedgePolygon(Center, OuterRadius, InnerRadius, StartAngle, SweepAngle);
  if Length(Points) < 3 then
    Exit;

  if Alpha = OpaqueAlpha then
    FillDevicePolygonOpaque(Points, Color)
  else
  begin
    const Bounds = TLayoutRectF.Create(Center.X - OuterRadius, Center.Y - OuterRadius, Center.X + OuterRadius,
      Center.Y + OuterRadius);
    FillDevicePolygonBlended(Points, Bounds, Color);
  end;
end;

procedure TMarkdownVclPainter.FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
begin
  const Alpha = AlphaOf(Color);
  if (Alpha = 0) or (Length(Points) < 3) then
    Exit;

  var Device: TArray<TPoint>;
  SetLength(Device, Length(Points));

  var MinX := Points[0].X;
  var MinY := Points[0].Y;
  var MaxX := Points[0].X;
  var MaxY := Points[0].Y;

  for var Index := 0 to High(Points) do
  begin
    Device[Index] := TPoint.Create(Round(Points[Index].X), Round(Points[Index].Y));

    MinX := Min(MinX, Points[Index].X);
    MinY := Min(MinY, Points[Index].Y);
    MaxX := Max(MaxX, Points[Index].X);
    MaxY := Max(MaxY, Points[Index].Y);
  end;

  if Alpha = OpaqueAlpha then
    FillDevicePolygonOpaque(Device, Color)
  else
    FillDevicePolygonBlended(Device, TLayoutRectF.Create(MinX, MinY, MaxX, MaxY), Color);
end;

procedure TMarkdownVclPainter.FillDevicePolygonOpaque(const Points: TArray<TPoint>; const Color: TLayoutColor);
begin
  FCanvas.Brush.Style := bsSolid;
  FCanvas.Brush.Color := ToVclColor(Color);
  FCanvas.Pen.Style := psSolid;
  FCanvas.Pen.Color := ToVclColor(Color);
  FCanvas.Pen.Width := 1;
  FCanvas.Polygon(Points);
end;

procedure TMarkdownVclPainter.FillDevicePolygonBlended(const Points: TArray<TPoint>; const Bounds: TLayoutRectF;
  const Color: TLayoutColor);
begin
  const Saved = SaveDC(FCanvas.Handle);
  try
    const Region = CreatePolygonRgn(Points[0], Length(Points), WINDING);
    try
      ExtSelectClipRgn(FCanvas.Handle, Region, RGN_AND);
      FillRectBlended(Bounds, Color);
    finally
      DeleteObject(Region);
    end;
  finally
    RestoreDC(FCanvas.Handle, Saved);
  end;
end;

class function TMarkdownVclPainter.WedgePolygon(const Center: TLayoutPointF;
  const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single): TArray<TPoint>;
const
  DegreesToRadians = Pi / 180;
  SegmentDegrees = 3.0;
begin
  const Steps = Max(1, Ceil(Abs(SweepAngle) / SegmentDegrees));
  const HasHole = (InnerRadius > 0);

  var PointCount := Steps + 1;
  if HasHole then
    PointCount := PointCount + (Steps + 1)
  else
    PointCount := PointCount + 1;

  SetLength(Result, PointCount);

  var Index := 0;
  for var Step := 0 to Steps do
  begin
    const Angle = (StartAngle + SweepAngle * Step / Steps) * DegreesToRadians;
    Result[Index] := TPoint.Create(Round(Center.X + OuterRadius * Cos(Angle)),
      Round(Center.Y + OuterRadius * Sin(Angle)));
    Inc(Index);
  end;

  if HasHole then
  begin
    for var Step := Steps downto 0 do
    begin
      const Angle = (StartAngle + SweepAngle * Step / Steps) * DegreesToRadians;
      Result[Index] := TPoint.Create(Round(Center.X + InnerRadius * Cos(Angle)),
        Round(Center.Y + InnerRadius * Sin(Angle)));
      Inc(Index);
    end;
  end
  else
    Result[Index] := TPoint.Create(Round(Center.X), Round(Center.Y));
end;

procedure TMarkdownVclPainter.SaveState;
begin
  FSavedStates.Push(SaveDC(FCanvas.Handle));
end;

procedure TMarkdownVclPainter.SetClip(const Bounds: TLayoutRectF);
begin
  const Dest = ToDeviceRect(Bounds);
  IntersectClipRect(FCanvas.Handle, Dest.Left, Dest.Top, Dest.Right, Dest.Bottom);
end;

procedure TMarkdownVclPainter.RestoreState;
begin
  if FSavedStates.Count = 0 then
    raise EMarkdownError.Create(UnbalancedRestoreMessage);

  RestoreDC(FCanvas.Handle, FSavedStates.Pop);
  FCanvas.Refresh;
end;

procedure TMarkdownVclPainter.ApplyFont(const Font: TMarkdownFontStyle);
begin
  const Key = FontKey(Font);
  if FHasAppliedFont and (Key = FAppliedFontKey) then
    Exit;

  FCanvas.Font.Name := ResolveFamilyName(Font.FamilyName);
  FCanvas.Font.Height := FontPixelHeight(Font);
  FCanvas.Font.Style := FontStylesOf(Font);

  FAppliedFontKey := Key;
  FHasAppliedFont := True;
end;

function TMarkdownVclPainter.FontPixelHeight(const Font: TMarkdownFontStyle): Integer;
begin
  Result := -Round(Font.Size * FPixelsPerInch / ReferencePixelsPerInch);
end;

class function TMarkdownVclPainter.FontStylesOf(const Font: TMarkdownFontStyle): TFontStyles;
begin
  Result := [];
  if Font.Bold then
    Include(Result, fsBold);
  if Font.Italic then
    Include(Result, fsItalic);
  if Font.Underline then
    Include(Result, fsUnderline);
  if Font.Strikeout then
    Include(Result, fsStrikeOut);
end;

function TMarkdownVclPainter.FontKey(const Font: TMarkdownFontStyle): string;
begin
  Result := Format('%s|%d|%d', [ResolveFamilyName(Font.FamilyName), FontPixelHeight(Font),
    Byte(FontStylesOf(Font))]);
end;

function TMarkdownVclPainter.ResolveFamilyName(const FamilyName: string): string;
begin
  if FFamilyCache.TryGetValue(FamilyName, Result) then
    Exit;

  Result := LookupFamilyName(FamilyName);
  FFamilyCache.Add(FamilyName, Result);
end;

class function TMarkdownVclPainter.LookupFamilyName(const FamilyName: string): string;
begin
  if SameText(FamilyName, MonospaceFamilyName) then
    Exit(MonospaceFallbackFamilyName);

  if SameText(FamilyName, SansSerifFamilyName) then
    Exit(DefaultFallbackFamilyName);

  if SameText(FamilyName, SerifFamilyName) then
    Exit(SerifFallbackFamilyName);

  if IsFamilyInstalled(FamilyName) then
    Exit(FamilyName);

  Result := DefaultFallbackFamilyName;
end;

class function TMarkdownVclPainter.IsFamilyInstalled(const FamilyName: string): Boolean;
begin
  Result := Screen.Fonts.IndexOf(FamilyName) >= 0;
end;

function TMarkdownVclPainter.TextMetricsOf(const Font: TMarkdownFontStyle): TTextMetric;
begin
  const Key = FontKey(Font);
  if FMetricsCache.TryGetValue(Key, Result) then
    Exit;

  ApplyFont(Font);
  Result := Default(TTextMetric);
  GetTextMetrics(FCanvas.Handle, Result);
  FMetricsCache.Add(Key, Result);
end;

class function TMarkdownVclPainter.PremultipliedPixel(const Color: TLayoutColor): Cardinal;
begin
  const Alpha = AlphaOf(Color);
  const Red = ((Color shr 16) and $FF) * Alpha div ColorChannelMax;
  const Green = ((Color shr 8) and $FF) * Alpha div ColorChannelMax;
  const Blue = (Color and $FF) * Alpha div ColorChannelMax;
  Result := (Cardinal(Alpha) shl 24) or (Cardinal(Red) shl 16) or (Cardinal(Green) shl 8) or Cardinal(Blue);
end;

class function TMarkdownVclPainter.ToVclColor(const Color: TLayoutColor): TColor;
begin
  const Red = (Color shr 16) and $FF;
  const Green = (Color shr 8) and $FF;
  const Blue = Color and $FF;
  Result := TColor(RGB(Red, Green, Blue));
end;

class function TMarkdownVclPainter.AlphaOf(const Color: TLayoutColor): Byte;
begin
  Result := Color shr 24;
end;

class function TMarkdownVclPainter.ToDeviceRect(const Bounds: TLayoutRectF): TRect;
begin
  Result := TRect.Create(Round(Bounds.Left), Round(Bounds.Top), Round(Bounds.Right), Round(Bounds.Bottom));
end;

class function TMarkdownVclPainter.OpaqueBlendFunction: TBlendFunction;
begin
  Result := Default(TBlendFunction);
  Result.BlendOp := AC_SRC_OVER;
  Result.SourceConstantAlpha := ColorChannelMax;
  Result.AlphaFormat := AC_SRC_ALPHA;
end;

end.
