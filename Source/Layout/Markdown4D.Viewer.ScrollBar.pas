unit Markdown4D.Viewer.ScrollBar;

{$SCOPEDENUMS ON}

// FMX has no native window scrollbar the way the VCL controls have, so the FMX
// viewer and editor draw their own overlay thumb. The geometry lives here,
// framework-neutral, so both controls share one set of sums.

interface

uses
  Markdown4D.Layout.Interfaces;

type
  TMarkdownScrollBarGeometry = record
  private
    class function ThumbHeightFor(const ViewHeight, ContentHeight: Single): Single; static;

  public
    const
      LaneWidth = 12.0;
      ThumbWidth = 6.0;
      Margin = 2.0;
      MinThumbHeight = 24.0;
      ThumbColor = TLayoutColor($66909090);
    class function IsVisible(const ViewHeight, ContentHeight: Single): Boolean; static;
    class function IsOnLane(const ViewWidth, X: Single): Boolean; static;
    class function ThumbRect(const ViewWidth, ViewHeight, ContentHeight, ScrollOffset: Single): TLayoutRectF; static;
    class function OffsetForThumbTop(const ViewHeight, ContentHeight, ThumbTop: Single): Single; static;
  end;

implementation

uses
  System.Math;

class function TMarkdownScrollBarGeometry.IsVisible(const ViewHeight, ContentHeight: Single): Boolean;
begin
  Result := ContentHeight > ViewHeight;
end;

class function TMarkdownScrollBarGeometry.IsOnLane(const ViewWidth, X: Single): Boolean;
begin
  Result := X >= (ViewWidth - LaneWidth);
end;

class function TMarkdownScrollBarGeometry.ThumbRect(const ViewWidth, ViewHeight, ContentHeight,
  ScrollOffset: Single): TLayoutRectF;
begin
  const TrackHeight = ViewHeight - 2 * Margin;
  const ThumbHeight = ThumbHeightFor(ViewHeight, ContentHeight);

  const MaxOffset = ContentHeight - ViewHeight;
  var Fraction := 0.0;
  if MaxOffset > 0 then
    Fraction := EnsureRange(ScrollOffset / MaxOffset, 0, 1);

  const Top = Margin + (TrackHeight - ThumbHeight) * Fraction;
  const Right = ViewWidth - Margin;
  Result := TLayoutRectF.Create(Right - ThumbWidth, Top, Right, Top + ThumbHeight);
end;

class function TMarkdownScrollBarGeometry.OffsetForThumbTop(const ViewHeight, ContentHeight,
  ThumbTop: Single): Single;
begin
  const TrackHeight = ViewHeight - 2 * Margin;
  const ThumbHeight = ThumbHeightFor(ViewHeight, ContentHeight);

  const Span = TrackHeight - ThumbHeight;
  if Span <= 0 then
    Exit(0);

  const Fraction = EnsureRange((ThumbTop - Margin) / Span, 0, 1);
  Result := Fraction * (ContentHeight - ViewHeight);
end;

class function TMarkdownScrollBarGeometry.ThumbHeightFor(const ViewHeight, ContentHeight: Single): Single;
begin
  const TrackHeight = ViewHeight - 2 * Margin;
  const Proportional = TrackHeight * (ViewHeight / ContentHeight);
  Result := Min(TrackHeight, Max(MinThumbHeight, Proportional));
end;

end.
