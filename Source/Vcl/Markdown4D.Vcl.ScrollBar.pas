unit Markdown4D.Vcl.ScrollBar;

// Showing or hiding a native scroll bar resizes the control. A control that lays its
// content out again at the new width, and sets the scroll bar from the result, comes
// back while the bar is still changing. Content that needs the bar at one width and
// not at the other would then toggle it for ever. While the bar is changing, a nested
// update therefore keeps it shown, disabled when the content fits. That only holds
// when the control lays out the new width during the change, so a control that
// waits before it lays out a new width does not wait while IsChanging. While the
// user drags the control wider or narrower, each time the bar appears or disappears
// then costs one layout at once, however long that layout takes.

interface

uses
  Winapi.Windows;

type
  TMarkdownVerticalScrollBar = record
  private
    FIsChanging: Boolean;

  public
    /// <summary>
    /// Sets the vertical scroll bar of <c>Handle</c> to <c>ContentHeight</c> pixels of
    /// content, <c>PageHeight</c> of it visible and scrolled to <c>Position</c>.
    /// </summary>
    procedure Update(const Handle: HWND; const ContentHeight, PageHeight, Position: Integer);
    /// <summary>
    /// True while <c>Update</c> shows or hides the bar, so a resize now comes from the bar.
    /// </summary>
    function IsChanging: Boolean;
  end;

implementation

uses
  System.Math;

procedure TMarkdownVerticalScrollBar.Update(const Handle: HWND; const ContentHeight, PageHeight,
                                            Position: Integer);
begin
  var Info := Default(TScrollInfo);
  Info.cbSize := SizeOf(Info);
  Info.fMask := SIF_RANGE or SIF_PAGE or SIF_POS;
  Info.nMin := 0;
  Info.nMax := Max(0, ContentHeight - 1);
  Info.nPage := PageHeight;
  Info.nPos := Position;

  const IsNestedInChange = FIsChanging;
  if IsNestedInChange then
    Info.fMask := Info.fMask or SIF_DISABLENOSCROLL;

  FIsChanging := True;
  try
    SetScrollInfo(Handle, SB_VERT, Info, True);
  finally
    FIsChanging := IsNestedInChange;
  end;
end;

function TMarkdownVerticalScrollBar.IsChanging: Boolean;
begin
  Result := FIsChanging;
end;

end.
