unit Markdown4D.AutoScroll.Cursors;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.AutoScroll;

type
  // The pan cursors Windows shows for autoscroll in RichEdit and the
  // browsers. They live in user32 without a documented name, so a cursor
  // that fails to load falls back to the plain up-down arrow.
  TMarkdownAutoScrollCursors = class
  {$IFDEF MSWINDOWS}
  private
    const
      PanBothCursorId = 32652;
      PanUpCursorId = 32655;
      PanDownCursorId = 32656;
    class var
      FHandles: array[TMarkdownAutoScrollDirection] of NativeUInt;
    class function LoadPanCursor(const Direction: TMarkdownAutoScrollDirection): NativeUInt; static;
    class function CursorIdOf(const Direction: TMarkdownAutoScrollDirection): Integer; static;
  {$ENDIF}

  public
    // Sets the cursor at once, for as long as nothing else sets one: while
    // the mouse is captured Windows sends no WM_SETCURSOR, so the caller
    // applies it again on every move. False where the platform has none.
    class function TryApply(const Direction: TMarkdownAutoScrollDirection): Boolean; static;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;
{$ENDIF}

class function TMarkdownAutoScrollCursors.TryApply(const Direction: TMarkdownAutoScrollDirection): Boolean;
begin
  {$IFDEF MSWINDOWS}
  if FHandles[Direction] = 0 then
    FHandles[Direction] := LoadPanCursor(Direction);

  Winapi.Windows.SetCursor(FHandles[Direction]);
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

{$IFDEF MSWINDOWS}
class function TMarkdownAutoScrollCursors.LoadPanCursor(const Direction: TMarkdownAutoScrollDirection): NativeUInt;
begin
  // LR_SHARED leaves the handles to Windows, so they are never destroyed here.
  Result := LoadImage(GetModuleHandle(user32), MakeIntResource(CursorIdOf(Direction)), IMAGE_CURSOR, 0, 0,
    LR_DEFAULTSIZE or LR_SHARED);

  if Result = 0 then
    Result := LoadCursor(0, IDC_SIZENS);
end;

class function TMarkdownAutoScrollCursors.CursorIdOf(const Direction: TMarkdownAutoScrollDirection): Integer;
begin
  case Direction of
    TMarkdownAutoScrollDirection.Up   : Result := PanUpCursorId;
    TMarkdownAutoScrollDirection.Down : Result := PanDownCursorId;
    TMarkdownAutoScrollDirection.Both : Result := PanBothCursorId;
  else
    Result := PanBothCursorId;
  end;
end;
{$ENDIF}

end.
