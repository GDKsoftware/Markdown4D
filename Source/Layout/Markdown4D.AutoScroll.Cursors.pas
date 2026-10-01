unit Markdown4D.AutoScroll.Cursors;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.AutoScroll;

type
  // The pan cursors Windows shows for autoscroll in RichEdit and the browsers.
  TMarkdownAutoScrollCursors = class
  public
    // Sets the cursor at once, for as long as nothing else sets one: while
    // the mouse is captured Windows sends no WM_SETCURSOR, so the caller
    // applies it again on every move. False where the platform has none.
    class function TryApply(const Direction: TMarkdownAutoScrollDirection): Boolean; static;
  end;

implementation

{$IF Defined(MSWINDOWS)}
uses
  Winapi.Windows;

type
  // The cursors live in user32 without a documented name, so one that fails
  // to load falls back to the plain up-down arrow.
  TWindowsPanCursors = class
  private
    const
      PanBothCursorId = 32652;
      PanUpCursorId = 32655;
      PanDownCursorId = 32656;
    class var
      FHandles: array[TMarkdownAutoScrollDirection] of HCURSOR;
    class function Load(const Direction: TMarkdownAutoScrollDirection): HCURSOR; static;
    class function CursorIdOf(const Direction: TMarkdownAutoScrollDirection): Integer; static;

  public
    class function HandleOf(const Direction: TMarkdownAutoScrollDirection): HCURSOR; static;
  end;

class function TWindowsPanCursors.HandleOf(const Direction: TMarkdownAutoScrollDirection): HCURSOR;
begin
  if FHandles[Direction] = 0 then
    FHandles[Direction] := Load(Direction);

  Result := FHandles[Direction];
end;

class function TWindowsPanCursors.Load(const Direction: TMarkdownAutoScrollDirection): HCURSOR;
begin
  // LR_SHARED leaves the handles to Windows, so they are never destroyed here.
  Result := LoadImage(GetModuleHandle(user32), MakeIntResource(CursorIdOf(Direction)), IMAGE_CURSOR, 0, 0,
    LR_DEFAULTSIZE or LR_SHARED);

  if Result = 0 then
    Result := LoadCursor(0, IDC_SIZENS);
end;

class function TWindowsPanCursors.CursorIdOf(const Direction: TMarkdownAutoScrollDirection): Integer;
begin
  case Direction of
    TMarkdownAutoScrollDirection.Up   : Result := PanUpCursorId;
    TMarkdownAutoScrollDirection.Down : Result := PanDownCursorId;
    TMarkdownAutoScrollDirection.Both : Result := PanBothCursorId;
  else
    Result := PanBothCursorId;
  end;
end;

class function TMarkdownAutoScrollCursors.TryApply(const Direction: TMarkdownAutoScrollDirection): Boolean;
begin
  Winapi.Windows.SetCursor(TWindowsPanCursors.HandleOf(Direction));
  Result := True;
end;
{$ELSE}
class function TMarkdownAutoScrollCursors.TryApply(const Direction: TMarkdownAutoScrollDirection): Boolean;
begin
  Result := False;
end;
{$ENDIF}

end.
