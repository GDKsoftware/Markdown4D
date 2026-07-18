unit Markdown4D.Fmx.Painter;

{$SCOPEDENUMS ON}

interface

uses
  System.Types,
  System.UITypes,
  System.Generics.Collections,
  FMX.Types,
  FMX.Graphics,
  FMX.TextLayout,
  Markdown4D.Layout.Defaults,
  Markdown4D.Layout.Interfaces;

type
  TMarkdownFmxImageResolver = reference to function(const Source: string): TBitmap;

  TMarkdownFmxBrokenImageQuery = reference to function(const Source: string): Boolean;

  TMarkdownFmxPainter = class(TInterfacedObject, IPainter)
  private
    const
      OpaqueMask = TLayoutColor($FF000000);
      AscentFactor = 0.8;
      MeasurementReferenceText = 'Ag';
      LargeLayoutExtent = 100000.0;
      PlaceholderBorderColor = TLayoutColor($FF9E9E9E);
      PlaceholderStrokeWidth = 1.0;
      BrokenImageCrossColor = TLayoutColor($FFC0392B);
      GlyphOverhangLines = 2.0;
    var
      FCanvas: TCanvas;
      FPixelsPerInch: Integer;
      FLayout: TTextLayout;
      FSavedStates: TStack<TCanvasSaveState>;
      FMeasureCache: TDictionary<string, TLayoutSizeF>;
      FLineHeightCache: TDictionary<string, Single>;
      FAppliedFontKey: string;
      FHasAppliedFont: Boolean;
      FImageResolver: TMarkdownFmxImageResolver;
      FBrokenImageQuery: TMarkdownFmxBrokenImageQuery;
    function ResolveFamilyName(const FamilyName: string): string;
    class function FontStylesOf(const Font: TMarkdownFontStyle): TFontStyles;
    function FontKey(const Font: TMarkdownFontStyle): string;
    procedure ConfigureLayout(const Font: TMarkdownFontStyle; const Text: string);
    procedure ApplyCanvasFont(const Font: TMarkdownFontStyle);
    procedure DrawResolvedBitmap(const Bounds: TLayoutRectF; const Bitmap: TBitmap; const SourceRect: TLayoutRectF);
    procedure DrawImagePlaceholder(const Bounds: TLayoutRectF);
    procedure DrawBrokenImagePlaceholder(const Bounds: TLayoutRectF);
    class function ToRectF(const Bounds: TLayoutRectF): TRectF;
    class function AlphaOf(const Color: TLayoutColor): Byte;
    class function OpacityOf(const Color: TLayoutColor): Single;

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
    property ImageResolver: TMarkdownFmxImageResolver read FImageResolver write FImageResolver;
    property BrokenImageQuery: TMarkdownFmxBrokenImageQuery read FBrokenImageQuery write FBrokenImageQuery;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Defines;

constructor TMarkdownFmxPainter.Create(const Canvas: TCanvas; const PixelsPerInch: Integer);
begin
  inherited Create;

  FCanvas := Canvas;
  FPixelsPerInch := PixelsPerInch;
  FLayout := TTextLayoutManager.DefaultTextLayout.Create(Canvas);
  FSavedStates := TStack<TCanvasSaveState>.Create;
  FMeasureCache := TDictionary<string, TLayoutSizeF>.Create;
  FLineHeightCache := TDictionary<string, Single>.Create;
end;

destructor TMarkdownFmxPainter.Destroy;
begin
  FLineHeightCache.Free;
  FMeasureCache.Free;
  FSavedStates.Free;
  FLayout.Free;

  inherited Destroy;
end;

function TMarkdownFmxPainter.MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
begin
  const Key = FontKey(Font) + '|' + Text;
  if FMeasureCache.TryGetValue(Key, Result) then
    Exit;

  ConfigureLayout(Font, Text);
  Result := TLayoutSizeF.Create(FLayout.TextWidth, LineHeight(Font));
  FMeasureCache.Add(Key, Result);
end;

function TMarkdownFmxPainter.LineHeight(const Font: TMarkdownFontStyle): Single;
begin
  const Key = FontKey(Font);
  if FLineHeightCache.TryGetValue(Key, Result) then
    Exit;

  ConfigureLayout(Font, MeasurementReferenceText);
  Result := FLayout.TextHeight;
  FLineHeightCache.Add(Key, Result);
end;

function TMarkdownFmxPainter.Baseline(const Font: TMarkdownFontStyle): Single;
begin
  Result := LineHeight(Font) * AscentFactor;
end;

procedure TMarkdownFmxPainter.ConfigureLayout(const Font: TMarkdownFontStyle; const Text: string);
begin
  FLayout.BeginUpdate;
  try
    FLayout.Font.Family := ResolveFamilyName(Font.FamilyName);
    FLayout.Font.Size := Font.Size;
    FLayout.Font.Style := FontStylesOf(Font);
    FLayout.WordWrap := False;
    FLayout.MaxSize := TPointF.Create(LargeLayoutExtent, LargeLayoutExtent);
    FLayout.Text := Text;
  finally
    FLayout.EndUpdate;
  end;
end;

procedure TMarkdownFmxPainter.DrawTextRun(const TopLeft: TLayoutPointF; const Text: string;
  const Font: TMarkdownFontStyle; const Color: TLayoutColor);
begin
  ApplyCanvasFont(Font);
  FCanvas.Fill.Kind := TBrushKind.Solid;
  FCanvas.Fill.Color := TAlphaColor(Color) or OpaqueMask;

  const LineHeightValue = LineHeight(Font);
  const Width = MeasureText(Text, Font).Width;
  const Rect = TRectF.Create(TopLeft.X, TopLeft.Y, TopLeft.X + Width + LineHeightValue,
    TopLeft.Y + (LineHeightValue * GlyphOverhangLines));
  FCanvas.FillText(Rect, Text, False, OpacityOf(Color), [], TTextAlign.Leading, TTextAlign.Leading);
end;

procedure TMarkdownFmxPainter.FillRect(const Bounds: TLayoutRectF; const Color: TLayoutColor);
begin
  if AlphaOf(Color) = 0 then
    Exit;

  FCanvas.Fill.Kind := TBrushKind.Solid;
  FCanvas.Fill.Color := TAlphaColor(Color) or OpaqueMask;
  FCanvas.FillRect(ToRectF(Bounds), 0, 0, [], OpacityOf(Color));
end;

procedure TMarkdownFmxPainter.DrawRect(const Bounds: TLayoutRectF; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  const IsInvisible = (AlphaOf(Color) = 0) or (StrokeWidth <= 0);
  if IsInvisible then
    Exit;

  FCanvas.Stroke.Kind := TBrushKind.Solid;
  FCanvas.Stroke.Color := TAlphaColor(Color) or OpaqueMask;
  FCanvas.Stroke.Thickness := StrokeWidth;
  FCanvas.DrawRect(ToRectF(Bounds), 0, 0, [], OpacityOf(Color));
end;

procedure TMarkdownFmxPainter.DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  if AlphaOf(Color) = 0 then
    Exit;

  FCanvas.Stroke.Kind := TBrushKind.Solid;
  FCanvas.Stroke.Color := TAlphaColor(Color) or OpaqueMask;
  FCanvas.Stroke.Thickness := StrokeWidth;
  FCanvas.DrawLine(TPointF.Create(StartPoint.X, StartPoint.Y), TPointF.Create(EndPoint.X, EndPoint.Y),
    OpacityOf(Color));
end;

procedure TMarkdownFmxPainter.DrawImage(const Bounds: TLayoutRectF; const Source: string;
  const SourceRect: TLayoutRectF);
begin
  var Bitmap: TBitmap := nil;
  if Assigned(FImageResolver) then
    Bitmap := FImageResolver(Source);

  const IsAvailable = (Bitmap <> nil) and not Bitmap.IsEmpty;
  if IsAvailable then
  begin
    DrawResolvedBitmap(Bounds, Bitmap, SourceRect);
    Exit;
  end;

  const IsBroken = Assigned(FBrokenImageQuery) and FBrokenImageQuery(Source);
  if IsBroken then
    DrawBrokenImagePlaceholder(Bounds)
  else
    DrawImagePlaceholder(Bounds);
end;

procedure TMarkdownFmxPainter.DrawResolvedBitmap(const Bounds: TLayoutRectF; const Bitmap: TBitmap;
  const SourceRect: TLayoutRectF);
begin
  var Source := TRectF.Create(0, 0, Bitmap.Width, Bitmap.Height);
  const HasSourceRect = (SourceRect.Width > 0) and (SourceRect.Height > 0);
  if HasSourceRect then
    Source := ToRectF(SourceRect);

  FCanvas.DrawBitmap(Bitmap, Source, ToRectF(Bounds), 1.0, True);
end;

procedure TMarkdownFmxPainter.DrawImagePlaceholder(const Bounds: TLayoutRectF);
begin
  DrawRect(Bounds, PlaceholderBorderColor, PlaceholderStrokeWidth);
end;

procedure TMarkdownFmxPainter.DrawBrokenImagePlaceholder(const Bounds: TLayoutRectF);
begin
  DrawRect(Bounds, PlaceholderBorderColor, PlaceholderStrokeWidth);
  DrawLine(TLayoutPointF.Create(Bounds.Left, Bounds.Top), TLayoutPointF.Create(Bounds.Right, Bounds.Bottom),
    BrokenImageCrossColor, PlaceholderStrokeWidth);
  DrawLine(TLayoutPointF.Create(Bounds.Right, Bounds.Top), TLayoutPointF.Create(Bounds.Left, Bounds.Bottom),
    BrokenImageCrossColor, PlaceholderStrokeWidth);
end;

procedure TMarkdownFmxPainter.FillWedge(const Center: TLayoutPointF;
  const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single; const Color: TLayoutColor);
begin
  if (AlphaOf(Color) = 0) or (OuterRadius <= 0) or (SweepAngle = 0) then
    Exit;

  const CenterPoint = TPointF.Create(Center.X, Center.Y);
  const HasHole = (InnerRadius > 0);

  const Path = TPathData.Create;
  try
    if HasHole then
    begin
      Path.AddArc(CenterPoint, TPointF.Create(OuterRadius, OuterRadius), StartAngle, SweepAngle);
      Path.AddArc(CenterPoint, TPointF.Create(InnerRadius, InnerRadius), StartAngle + SweepAngle, -SweepAngle);
    end
    else
    begin
      Path.MoveTo(CenterPoint);
      Path.AddArc(CenterPoint, TPointF.Create(OuterRadius, OuterRadius), StartAngle, SweepAngle);
    end;
    Path.ClosePath;

    FCanvas.Fill.Kind := TBrushKind.Solid;
    FCanvas.Fill.Color := TAlphaColor(Color) or OpaqueMask;
    FCanvas.FillPath(Path, OpacityOf(Color));
  finally
    Path.Free;
  end;
end;

procedure TMarkdownFmxPainter.FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
begin
  if (AlphaOf(Color) = 0) or (Length(Points) < 3) then
    Exit;

  const Path = TPathData.Create;
  try
    Path.MoveTo(TPointF.Create(Points[0].X, Points[0].Y));

    for var Index := 1 to High(Points) do
    begin
      Path.LineTo(TPointF.Create(Points[Index].X, Points[Index].Y));
    end;

    Path.ClosePath;

    FCanvas.Fill.Kind := TBrushKind.Solid;
    FCanvas.Fill.Color := TAlphaColor(Color) or OpaqueMask;
    FCanvas.FillPath(Path, OpacityOf(Color));
  finally
    Path.Free;
  end;
end;

procedure TMarkdownFmxPainter.SaveState;
begin
  FSavedStates.Push(FCanvas.SaveState);
end;

procedure TMarkdownFmxPainter.SetClip(const Bounds: TLayoutRectF);
begin
  FCanvas.IntersectClipRect(ToRectF(Bounds));
end;

procedure TMarkdownFmxPainter.RestoreState;
begin
  if FSavedStates.Count = 0 then
    raise EMarkdownError.Create(UnbalancedRestoreMessage);

  FCanvas.RestoreState(FSavedStates.Pop);
end;

procedure TMarkdownFmxPainter.ApplyCanvasFont(const Font: TMarkdownFontStyle);
begin
  const Key = FontKey(Font);
  if FHasAppliedFont and (Key = FAppliedFontKey) then
    Exit;

  FCanvas.Font.Family := ResolveFamilyName(Font.FamilyName);
  FCanvas.Font.Size := Font.Size;
  FCanvas.Font.Style := FontStylesOf(Font);

  FAppliedFontKey := Key;
  FHasAppliedFont := True;
end;

function TMarkdownFmxPainter.ResolveFamilyName(const FamilyName: string): string;
begin
  if SameText(FamilyName, MonospaceFamilyName) then
    Exit(MonospaceFallbackFamilyName);

  if SameText(FamilyName, SansSerifFamilyName) then
    Exit(DefaultFallbackFamilyName);

  if SameText(FamilyName, SerifFamilyName) then
    Exit(SerifFallbackFamilyName);

  if FamilyName = '' then
    Exit(DefaultFallbackFamilyName);

  Result := FamilyName;
end;

class function TMarkdownFmxPainter.FontStylesOf(const Font: TMarkdownFontStyle): TFontStyles;
begin
  Result := [];
  if Font.Bold then
    Include(Result, TFontStyle.fsBold);
  if Font.Italic then
    Include(Result, TFontStyle.fsItalic);
  if Font.Underline then
    Include(Result, TFontStyle.fsUnderline);
  if Font.Strikeout then
    Include(Result, TFontStyle.fsStrikeOut);
end;

function TMarkdownFmxPainter.FontKey(const Font: TMarkdownFontStyle): string;
begin
  Result := Format('%s|%.2f|%d', [ResolveFamilyName(Font.FamilyName), Font.Size, Byte(FontStylesOf(Font))]);
end;

class function TMarkdownFmxPainter.ToRectF(const Bounds: TLayoutRectF): TRectF;
begin
  Result := TRectF.Create(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom);
end;

class function TMarkdownFmxPainter.AlphaOf(const Color: TLayoutColor): Byte;
begin
  Result := Color shr 24;
end;

class function TMarkdownFmxPainter.OpacityOf(const Color: TLayoutColor): Single;
begin
  Result := AlphaOf(Color) / ColorChannelMax;
end;

end.
