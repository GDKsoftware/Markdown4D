unit Markdown4DStudio.SplitLayout;

// Geometry for the editor/preview split, deliberately free of any framework type
// so the rule that neither pane may collapse is testable without a form and is
// shared by the VCL and FMX studios.

interface

type
  TPadSplitLayout = record
  public
    /// <summary>
    ///   Editor width to apply for the window as it is now.
    /// </summary>
    /// <param name="SavedWidth">
    ///   Editor width remembered from the last time split view was active. It is
    ///   an absolute pixel value, so it can outlive the window size it was taken
    ///   at and ask for more room than there is.
    /// </param>
    /// <param name="AvailableWidth">
    ///   What the editor and the preview share, with the contents pane and every
    ///   splitter already subtracted.
    /// </param>
    /// <param name="MinPaneWidth">
    ///   The least either pane may become. When the available width cannot hold
    ///   two of these, the space is shared evenly instead.
    /// </param>
    class function ClampEditorWidth(const SavedWidth, AvailableWidth,
      MinPaneWidth: Integer): Integer; static;

    /// <summary>
    ///   The minimum a splitter can actually enforce for the window as it is
    ///   now. A splitter asked to honour a minimum the window cannot give lets a
    ///   drag hand the whole area to one pane, so below two minimums the answer
    ///   is half of what there is.
    /// </summary>
    class function EffectiveMinPaneWidth(const AvailableWidth,
      MinPaneWidth: Integer): Integer; static;

    /// <summary>
    ///   How wide a side panel, such as the contents pane, may be dragged before
    ///   it starts eating into the two halves of the split.
    /// </summary>
    /// <param name="TotalWidth">The whole client width.</param>
    /// <param name="ReservedWidth">Width taken by the splitters themselves.</param>
    /// <param name="MinSidePanelWidth">
    ///   How far the side panel may be asked to give way. Past that point it has
    ///   done all it can and the two panes share what is left between them. A
    ///   panel already narrower than this is never widened.
    /// </param>
    class function ClampSidePanelWidth(const DesiredWidth, TotalWidth,
      ReservedWidth, MinPaneWidth, MinSidePanelWidth: Integer): Integer; static;
  end;

implementation

uses
  System.Math;

class function TPadSplitLayout.ClampEditorWidth(const SavedWidth, AvailableWidth,
  MinPaneWidth: Integer): Integer;
begin
  // Too narrow to honour both minimums: share what there is rather than hand the
  // whole area to one pane and leave the other invisible.
  if AvailableWidth <= 2 * MinPaneWidth then
    Exit(Max(0, AvailableWidth div 2));

  Result := EnsureRange(SavedWidth, MinPaneWidth, AvailableWidth - MinPaneWidth);
end;

class function TPadSplitLayout.EffectiveMinPaneWidth(const AvailableWidth,
  MinPaneWidth: Integer): Integer;
begin
  Result := Min(MinPaneWidth, Max(0, AvailableWidth div 2));
end;

class function TPadSplitLayout.ClampSidePanelWidth(const DesiredWidth, TotalWidth,
  ReservedWidth, MinPaneWidth, MinSidePanelWidth: Integer): Integer;
begin
  // What the side panel could take while both panes still keep their minimum.
  const Allowed = Max(0, TotalWidth - ReservedWidth - 2 * MinPaneWidth);

  // Never widen the panel, only ask it to give way, and never past its own
  // minimum: below that the two panes share what is left instead.
  Result := Min(DesiredWidth, Max(Allowed, MinSidePanelWidth));
end;

end.
