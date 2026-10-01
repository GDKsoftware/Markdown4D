unit Markdown4D.Fmx.AutoScroll.Cursors;

{$SCOPEDENUMS ON}

interface

uses
  FMX.Forms,
  Markdown4D.AutoScroll;

type
  // The cursor per direction where the platform has one: the pan cursors on
  // Windows, the GTK resize cursors on Linux. Elsewhere the up-down arrow FMX
  // already shows stays.
  TMarkdownFmxAutoScrollCursors = class
  public
    class function TryApply(const Form: TCommonCustomForm; const Direction: TMarkdownAutoScrollDirection): Boolean;
      static;
    // Takes a cursor set past FMX off the window again. False where nothing
    // needs taking off.
    class function TryClear(const Form: TCommonCustomForm): Boolean; static;
  end;

implementation

{$IF Defined(MSWINDOWS)}
uses
  Markdown4D.AutoScroll.Cursors;

class function TMarkdownFmxAutoScrollCursors.TryApply(const Form: TCommonCustomForm;
  const Direction: TMarkdownAutoScrollDirection): Boolean;
begin
  Result := TMarkdownAutoScrollCursors.TryApply(Direction);
end;

// Windows keeps no cursor on the window; the next one set replaces it.
class function TMarkdownFmxAutoScrollCursors.TryClear(const Form: TCommonCustomForm): Boolean;
begin
  Result := False;
end;

{$ELSEIF Defined(LINUX)}
uses
  System.SysUtils,
  FMX.Platform.Linux;

type
  // GTK is loaded when it is first needed, as FMX for Linux does itself, so
  // building for Linux needs no GTK in the SDK. A cursor stays on the GDK
  // window until it is taken off.
  TGtkCursors = class
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
    class function TryLoad: Boolean; static;
    class function CursorOf(const Window: Pointer; const Direction: TMarkdownAutoScrollDirection): Pointer; static;
    class function CursorNameOf(const Direction: TMarkdownAutoScrollDirection): string; static;

  public
    class function TryWindowOf(const Form: TCommonCustomForm; out Window: Pointer): Boolean; static;
    class function TrySet(const Window: Pointer; const Direction: TMarkdownAutoScrollDirection): Boolean; static;
    class procedure Clear(const Window: Pointer); static;
  end;

class function TGtkCursors.TryWindowOf(const Form: TCommonCustomForm; out Window: Pointer): Boolean;
begin
  Window := nil;

  const HasNativeWindow = (TryLoad and (Form <> nil) and (Form.Handle <> nil));
  if HasNativeWindow then
  begin
    const Widget = TLinuxWindowHandle(Form.Handle).NativeHandle;
    if Widget <> nil then
      Window := FGtkWidgetGetWindow(Widget);
  end;

  Result := (Window <> nil);
end;

class function TGtkCursors.TrySet(const Window: Pointer; const Direction: TMarkdownAutoScrollDirection): Boolean;
begin
  const Cursor = CursorOf(Window, Direction);

  Result := (Cursor <> nil);
  if Result then
    FGdkWindowSetCursor(Window, Cursor);
end;

class procedure TGtkCursors.Clear(const Window: Pointer);
begin
  FGdkWindowSetCursor(Window, nil);
end;

class function TGtkCursors.TryLoad: Boolean;
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

// Created once per direction and kept for the life of the application, the
// way GTK shares its own named cursors. A theme without the name gives nil.
class function TGtkCursors.CursorOf(const Window: Pointer; const Direction: TMarkdownAutoScrollDirection): Pointer;
begin
  if FCursors[Direction] = nil then
  begin
    const Name = UTF8String(CursorNameOf(Direction));
    FCursors[Direction] := FGdkCursorNewFromName(FGdkWindowGetDisplay(Window), PUtf8Char(Name));
  end;

  Result := FCursors[Direction];
end;

class function TGtkCursors.CursorNameOf(const Direction: TMarkdownAutoScrollDirection): string;
begin
  case Direction of
    TMarkdownAutoScrollDirection.Up   : Result := UpCursorName;
    TMarkdownAutoScrollDirection.Down : Result := DownCursorName;
    TMarkdownAutoScrollDirection.Both : Result := BothCursorName;
  else
    Result := BothCursorName;
  end;
end;

class function TMarkdownFmxAutoScrollCursors.TryApply(const Form: TCommonCustomForm;
  const Direction: TMarkdownAutoScrollDirection): Boolean;
begin
  var Window: Pointer;
  Result := TGtkCursors.TryWindowOf(Form, Window) and TGtkCursors.TrySet(Window, Direction);
end;

class function TMarkdownFmxAutoScrollCursors.TryClear(const Form: TCommonCustomForm): Boolean;
begin
  var Window: Pointer;
  Result := TGtkCursors.TryWindowOf(Form, Window);
  if Result then
    TGtkCursors.Clear(Window);
end;

{$ELSE}
class function TMarkdownFmxAutoScrollCursors.TryApply(const Form: TCommonCustomForm;
  const Direction: TMarkdownAutoScrollDirection): Boolean;
begin
  Result := False;
end;

class function TMarkdownFmxAutoScrollCursors.TryClear(const Form: TCommonCustomForm): Boolean;
begin
  Result := False;
end;
{$ENDIF}

end.
