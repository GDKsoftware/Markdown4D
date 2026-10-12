unit Markdown4D.Tests.RecordingPainter;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Markdown4D.Layout.Interfaces;

type
  TRecordedPrimitiveKind = (TextRun, FillRect, DrawRect, Line, Image, FillWedge, DrawWedge, FillPolygon,
    DrawPolygon, Clip);

  TRecordedPrimitive = record
    Kind: TRecordedPrimitiveKind;
    Bounds: TLayoutRectF;
    StartPoint: TLayoutPointF;
    EndPoint: TLayoutPointF;
    Text: string;
    Font: TMarkdownFontStyle;
    Color: TLayoutColor;
    StrokeWidth: Single;
    OuterRadius: Single;
    InnerRadius: Single;
    Points: TArray<TLayoutPointF>;
  end;

  // Measures like TFakeTextMeasurer and records every call that paints.
  TRecordingPainter = class(TInterfacedObject, IPainter)
  private
    FMeasurer: ITextMeasurer;
    FPrimitives: TList<TRecordedPrimitive>;
    procedure Add(const Primitive: TRecordedPrimitive);
    class function Primitive(const Kind: TRecordedPrimitiveKind): TRecordedPrimitive; static;

  public
    constructor Create;
    destructor Destroy; override;
    function OfKind(const Kind: TRecordedPrimitiveKind): TArray<TRecordedPrimitive>;
    function MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
    function LineHeight(const Font: TMarkdownFontStyle): Single;
    function Baseline(const Font: TMarkdownFontStyle): Single;
    procedure DrawTextRun(const TopLeft: TLayoutPointF; const Text: string; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor);
    procedure FillRect(const Bounds: TLayoutRectF; const Color: TLayoutColor);
    procedure DrawRect(const Bounds: TLayoutRectF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure DrawImage(const Bounds: TLayoutRectF; const Source: string; const SourceRect: TLayoutRectF);
    procedure FillWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const Color: TLayoutColor);
    procedure DrawWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const Color: TLayoutColor; const StrokeWidth: Single);
    procedure FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
    procedure DrawPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure SaveState;
    procedure SetClip(const Bounds: TLayoutRectF);
    procedure RestoreState;
  end;

implementation

uses
  Markdown4D.Layout.FakeMeasurer;

constructor TRecordingPainter.Create;
begin
  inherited Create;

  FMeasurer := TFakeTextMeasurer.Create;
  FPrimitives := TList<TRecordedPrimitive>.Create;
end;

destructor TRecordingPainter.Destroy;
begin
  FPrimitives.Free;

  inherited Destroy;
end;

function TRecordingPainter.OfKind(const Kind: TRecordedPrimitiveKind): TArray<TRecordedPrimitive>;
begin
  Result := [];
  for var Recorded in FPrimitives do
  begin
    if Recorded.Kind = Kind then
      Result := Result + [Recorded];
  end;
end;

procedure TRecordingPainter.Add(const Primitive: TRecordedPrimitive);
begin
  FPrimitives.Add(Primitive);
end;

class function TRecordingPainter.Primitive(const Kind: TRecordedPrimitiveKind): TRecordedPrimitive;
begin
  Result := Default(TRecordedPrimitive);
  Result.Kind := Kind;
end;

function TRecordingPainter.MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
begin
  Result := FMeasurer.MeasureText(Text, Font);
end;

function TRecordingPainter.LineHeight(const Font: TMarkdownFontStyle): Single;
begin
  Result := FMeasurer.LineHeight(Font);
end;

function TRecordingPainter.Baseline(const Font: TMarkdownFontStyle): Single;
begin
  Result := FMeasurer.Baseline(Font);
end;

procedure TRecordingPainter.DrawTextRun(const TopLeft: TLayoutPointF; const Text: string;
  const Font: TMarkdownFontStyle; const Color: TLayoutColor);
begin
  var Recorded := Primitive(TRecordedPrimitiveKind.TextRun);
  Recorded.StartPoint := TopLeft;
  Recorded.Text := Text;
  Recorded.Font := Font;
  Recorded.Color := Color;
  Add(Recorded);
end;

procedure TRecordingPainter.FillRect(const Bounds: TLayoutRectF; const Color: TLayoutColor);
begin
  var Recorded := Primitive(TRecordedPrimitiveKind.FillRect);
  Recorded.Bounds := Bounds;
  Recorded.Color := Color;
  Add(Recorded);
end;

procedure TRecordingPainter.DrawRect(const Bounds: TLayoutRectF; const Color: TLayoutColor; const StrokeWidth: Single);
begin
  var Recorded := Primitive(TRecordedPrimitiveKind.DrawRect);
  Recorded.Bounds := Bounds;
  Recorded.Color := Color;
  Recorded.StrokeWidth := StrokeWidth;
  Add(Recorded);
end;

procedure TRecordingPainter.DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  var Recorded := Primitive(TRecordedPrimitiveKind.Line);
  Recorded.StartPoint := StartPoint;
  Recorded.EndPoint := EndPoint;
  Recorded.Color := Color;
  Recorded.StrokeWidth := StrokeWidth;
  Add(Recorded);
end;

procedure TRecordingPainter.DrawImage(const Bounds: TLayoutRectF; const Source: string; const SourceRect: TLayoutRectF);
begin
  var Recorded := Primitive(TRecordedPrimitiveKind.Image);
  Recorded.Bounds := Bounds;
  Recorded.Text := Source;
  Add(Recorded);
end;

procedure TRecordingPainter.FillWedge(const Center: TLayoutPointF;
  const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single; const Color: TLayoutColor);
begin
  var Recorded := Primitive(TRecordedPrimitiveKind.FillWedge);
  Recorded.StartPoint := Center;
  Recorded.OuterRadius := OuterRadius;
  Recorded.InnerRadius := InnerRadius;
  Recorded.Color := Color;
  Add(Recorded);
end;

procedure TRecordingPainter.DrawWedge(const Center: TLayoutPointF;
  const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  var Recorded := Primitive(TRecordedPrimitiveKind.DrawWedge);
  Recorded.StartPoint := Center;
  Recorded.OuterRadius := OuterRadius;
  Recorded.InnerRadius := InnerRadius;
  Recorded.Color := Color;
  Recorded.StrokeWidth := StrokeWidth;
  Add(Recorded);
end;

procedure TRecordingPainter.FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
begin
  var Recorded := Primitive(TRecordedPrimitiveKind.FillPolygon);
  Recorded.Points := Copy(Points);
  Recorded.Color := Color;
  Add(Recorded);
end;

procedure TRecordingPainter.DrawPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor;
  const StrokeWidth: Single);
begin
  var Recorded := Primitive(TRecordedPrimitiveKind.DrawPolygon);
  Recorded.Points := Copy(Points);
  Recorded.Color := Color;
  Recorded.StrokeWidth := StrokeWidth;
  Add(Recorded);
end;

procedure TRecordingPainter.SaveState;
begin
  // Nothing to record: the tests look at what is painted.
end;

procedure TRecordingPainter.SetClip(const Bounds: TLayoutRectF);
begin
  var Recorded := Primitive(TRecordedPrimitiveKind.Clip);
  Recorded.Bounds := Bounds;
  Add(Recorded);
end;

procedure TRecordingPainter.RestoreState;
begin
  // Nothing to record: the tests look at what is painted.
end;

end.
