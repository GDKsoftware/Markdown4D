unit Markdown4D.Editor.PreviewScroll;

{$SCOPEDENUMS ON}

// Where an editor scrolls the preview beside it. The sums live here,
// framework-neutral, so the VCL and FMX editors share them.

interface

type
  TMarkdownPreviewScroll = record
  public
    // The offset that keeps the editor's top line at the top of the preview,
    // unless the line from LineTop to LineBottom would then drop below its
    // bottom edge. The preview then scrolls on just far enough to show that
    // line, or its top when the line is taller than the view.
    class function OffsetShowingLine(const TopLineOffset, LineTop, LineBottom, ViewHeight: Single): Single; static;
  end;

implementation

uses
  System.Math;

class function TMarkdownPreviewScroll.OffsetShowingLine(const TopLineOffset, LineTop, LineBottom,
  ViewHeight: Single): Single;
begin
  Result := TopLineOffset;

  const IsBelowView = (LineBottom > TopLineOffset + ViewHeight);
  if IsBelowView then
    Result := Min(LineTop, LineBottom - ViewHeight);
end;

end.
