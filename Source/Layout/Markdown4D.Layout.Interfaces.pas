unit Markdown4D.Layout.Interfaces;

{$SCOPEDENUMS ON}

interface

type
  TLayoutColor = Cardinal;

  TLayoutPointF = record
    X: Single;
    Y: Single;
    class function Create(const X, Y: Single): TLayoutPointF; static;
  end;

  TLayoutSizeF = record
    Width: Single;
    Height: Single;
    class function Create(const Width, Height: Single): TLayoutSizeF; static;
  end;

  TLayoutRectF = record
    Left: Single;
    Top: Single;
    Right: Single;
    Bottom: Single;
    class function Create(const Left, Top, Right, Bottom: Single): TLayoutRectF; static;
    class function CreateFromOrigin(const Origin: TLayoutPointF; const Size: TLayoutSizeF): TLayoutRectF; static;
    function Width: Single;
    function Height: Single;
    function Contains(const Point: TLayoutPointF): Boolean;
  end;

  TMarkdownFontStyle = record
    FamilyName: string;
    Size: Single;
    Bold: Boolean;
    Italic: Boolean;
    Underline: Boolean;
    Strikeout: Boolean;
    class function Create(const FamilyName: string; const Size: Single; const Bold: Boolean = False;
      const Italic: Boolean = False): TMarkdownFontStyle; static;
  end;

  ITextMeasurer = interface
    ['{7D3A9C41-58E2-4F0B-A6D1-93C4B7E82F55}']
    function MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
    function LineHeight(const Font: TMarkdownFontStyle): Single;
    function Baseline(const Font: TMarkdownFontStyle): Single;
  end;

  IMarkdownImageSizeProvider = interface
    ['{B4E7A2D9-6C31-4F58-9E0D-7A15C8B3F642}']
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
  end;

  IPainter = interface(ITextMeasurer)
    ['{6E2D8B47-9A15-4C60-B3F7-52D0C8E19A64}']
    procedure DrawTextRun(const TopLeft: TLayoutPointF; const Text: string; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor);
    procedure FillRect(const Bounds: TLayoutRectF; const Color: TLayoutColor);
    procedure DrawRect(const Bounds: TLayoutRectF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure DrawImage(const Bounds: TLayoutRectF; const Source: string; const SourceRect: TLayoutRectF);
    procedure FillWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const Color: TLayoutColor);
    procedure FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
    procedure SaveState;
    procedure SetClip(const Bounds: TLayoutRectF);
    procedure RestoreState;
  end;

implementation

class function TLayoutPointF.Create(const X, Y: Single): TLayoutPointF;
begin
  Result.X := X;
  Result.Y := Y;
end;

class function TLayoutSizeF.Create(const Width, Height: Single): TLayoutSizeF;
begin
  Result.Width := Width;
  Result.Height := Height;
end;

class function TLayoutRectF.Create(const Left, Top, Right, Bottom: Single): TLayoutRectF;
begin
  Result.Left := Left;
  Result.Top := Top;
  Result.Right := Right;
  Result.Bottom := Bottom;
end;

class function TLayoutRectF.CreateFromOrigin(const Origin: TLayoutPointF; const Size: TLayoutSizeF): TLayoutRectF;
begin
  Result := Create(Origin.X, Origin.Y, Origin.X + Size.Width, Origin.Y + Size.Height);
end;

function TLayoutRectF.Width: Single;
begin
  Result := Right - Left;
end;

function TLayoutRectF.Height: Single;
begin
  Result := Bottom - Top;
end;

function TLayoutRectF.Contains(const Point: TLayoutPointF): Boolean;
begin
  Result := (Point.X >= Left) and (Point.X < Right) and (Point.Y >= Top) and (Point.Y < Bottom);
end;

class function TMarkdownFontStyle.Create(const FamilyName: string; const Size: Single; const Bold: Boolean;
  const Italic: Boolean): TMarkdownFontStyle;
begin
  Result.FamilyName := FamilyName;
  Result.Size := Size;
  Result.Bold := Bold;
  Result.Italic := Italic;
  Result.Underline := False;
  Result.Strikeout := False;
end;

end.
