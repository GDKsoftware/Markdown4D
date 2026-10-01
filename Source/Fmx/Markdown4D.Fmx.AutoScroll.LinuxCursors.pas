unit Markdown4D.Fmx.AutoScroll.LinuxCursors;

{$SCOPEDENUMS ON}

interface

uses
  FMX.Forms,
  Markdown4D.AutoScroll;

type
  // The GTK cursors for autoscroll, set straight on the form's GDK window.
  // FMX itself only knows the up-down arrow; GTK names one per direction. A
  // cursor theme without a name keeps the arrow FMX set.
  TMarkdownLinuxAutoScrollCursors = class
  {$IFDEF LINUX}
  private
    type
      TGtkWidgetGetWindow = function(Widget: Pointer): Pointer; cdecl;
      TGdkWindowGetDisplay = function(Window: Pointer): Pointer; cdecl;
      TGdkCursorNewFromName = function(Display: Pointer; Name: PUtf8Char): Pointer; cdecl;
      TGdkWindowSetCursor = procedure(Window: Pointer; Cursor: Pointer); cdecl;
    const
      GtkLibraryName = 'libgtk-3.so.0';
      GdkLibraryName = 'libgdk-3.so.0';
      UpCursorName = 'n-resize';
      DownCursorName = 's-resize';
      BothCursorName = 'ns-resize';
    class var
      FLoaded: Boolean;
      FGtkWidgetGetWindow: TGtkWidgetGetWindow;
      FGdkWindowGetDisplay: TGdkWindowGetDisplay;
      FGdkCursorNewFromName: TGdkCursorNewFromName;
      FGdkWindowSetCursor: TGdkWindowSetCursor;
      FCursors: array[TMarkdownAutoScrollDirection] of Pointer;
    class function TryLoadGtk: Boolean; static;
    class function GdkWindowOf(const Form: TCommonCustomForm): Pointer; static;
    class function CursorNameOf(const Direction: TMarkdownAutoScrollDirection): string; static;
  {$ENDIF}

  public
    class function TryApply(const Form: TCommonCustomForm; const Direction: TMarkdownAutoScrollDirection): Boolean;
      static;
    // Gives the window back the cursor of whatever is under the pointer.
    class procedure Clear(const Form: TCommonCustomForm); static;
  end;

implementation

{$IFDEF LINUX}
uses
  System.SysUtils,
  FMX.Platform.Linux;
{$ENDIF}

class function TMarkdownLinuxAutoScrollCursors.TryApply(const Form: TCommonCustomForm;
  const Direction: TMarkdownAutoScrollDirection): Boolean;
begin
  {$IFDEF LINUX}
  Result := False;
  if not TryLoadGtk then
    Exit;

  const Window = GdkWindowOf(Form);
  if Window = nil then
    Exit;

  // Created once per direction and kept for the life of the application, the
  // way GTK shares its own named cursors.
  if FCursors[Direction] = nil then
  begin
    const Name = UTF8String(CursorNameOf(Direction));
    FCursors[Direction] := FGdkCursorNewFromName(FGdkWindowGetDisplay(Window), PUtf8Char(Name));
  end;

  Result := (FCursors[Direction] <> nil);
  if Result then
    FGdkWindowSetCursor(Window, FCursors[Direction]);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

class procedure TMarkdownLinuxAutoScrollCursors.Clear(const Form: TCommonCustomForm);
begin
  {$IFDEF LINUX}
  if not TryLoadGtk then
    Exit;

  const Window = GdkWindowOf(Form);
  if Window <> nil then
    FGdkWindowSetCursor(Window, nil);
  {$ENDIF}
end;

{$IFDEF LINUX}
// GTK is loaded when it is first needed, as FMX for Linux does itself, so
// building for Linux needs no GTK in the SDK.
class function TMarkdownLinuxAutoScrollCursors.TryLoadGtk: Boolean;
begin
  if FLoaded then
  begin
    Result := Assigned(FGdkWindowSetCursor);
    Exit;
  end;

  FLoaded := True;

  const Gtk = LoadLibrary(PChar(GtkLibraryName));
  const Gdk = LoadLibrary(PChar(GdkLibraryName));
  if (Gtk = 0) or (Gdk = 0) then
  begin
    Result := False;
    Exit;
  end;

  FGtkWidgetGetWindow := GetProcAddress(Gtk, 'gtk_widget_get_window');
  FGdkWindowGetDisplay := GetProcAddress(Gdk, 'gdk_window_get_display');
  FGdkCursorNewFromName := GetProcAddress(Gdk, 'gdk_cursor_new_from_name');
  FGdkWindowSetCursor := GetProcAddress(Gdk, 'gdk_window_set_cursor');

  const AllFound = (Assigned(FGtkWidgetGetWindow) and Assigned(FGdkWindowGetDisplay) and
                    Assigned(FGdkCursorNewFromName) and Assigned(FGdkWindowSetCursor));
  if not AllFound then
    FGdkWindowSetCursor := nil;

  Result := AllFound;
end;

class function TMarkdownLinuxAutoScrollCursors.GdkWindowOf(const Form: TCommonCustomForm): Pointer;
begin
  Result := nil;
  if (Form = nil) or (Form.Handle = nil) then
    Exit;

  const Widget = TLinuxWindowHandle(Form.Handle).NativeHandle;
  if Widget <> nil then
    Result := FGtkWidgetGetWindow(Widget);
end;

class function TMarkdownLinuxAutoScrollCursors.CursorNameOf(const Direction: TMarkdownAutoScrollDirection): string;
begin
  case Direction of
    TMarkdownAutoScrollDirection.Up   : Result := UpCursorName;
    TMarkdownAutoScrollDirection.Down : Result := DownCursorName;
    TMarkdownAutoScrollDirection.Both : Result := BothCursorName;
  else
    Result := BothCursorName;
  end;
end;
{$ENDIF}

end.
