unit Markdown4D.Vcl.ScrollBarTheme;

// A native scroll bar follows the window theme, not the colours a control
// paints itself. Under a dark Markdown4D theme it stays light unless the
// window asks for the dark variant. An active VCL style draws the scroll bar
// through its style hook instead, so the window theme is left alone then.

interface

uses
  Vcl.Controls,
  Markdown4D.Layout.Interfaces;

type
  TMarkdownScrollBarTheme = class
  private
    const
      DarkThemeName = 'DarkMode_Explorer';
      DarkLuminanceLimit = 128;
      RedWeight = 0.2126;
      GreenWeight = 0.7152;
      BlueWeight = 0.0722;
    class function Luminance(const Color: TLayoutColor): Single; static;

  public
    class function IsDark(const BackgroundColor: TLayoutColor): Boolean; static;
    class function ThemeName(const BackgroundColor: TLayoutColor): string; static;
    class procedure Apply(const Control: TWinControl; const BackgroundColor: TLayoutColor); static;
  end;

implementation

uses
  System.SysUtils,
  Winapi.UxTheme,
  Vcl.Themes;

class function TMarkdownScrollBarTheme.Luminance(const Color: TLayoutColor): Single;
begin
  const Red   = (Color shr 16) and $FF;
  const Green = (Color shr 8) and $FF;
  const Blue  = Color and $FF;

  Result := RedWeight * Red + GreenWeight * Green + BlueWeight * Blue;
end;

class function TMarkdownScrollBarTheme.IsDark(const BackgroundColor: TLayoutColor): Boolean;
begin
  Result := Luminance(BackgroundColor) < DarkLuminanceLimit;
end;

// An empty name restores the default theme of the window.
class function TMarkdownScrollBarTheme.ThemeName(const BackgroundColor: TLayoutColor): string;
begin
  Result := '';
  if IsDark(BackgroundColor) then
    Result := DarkThemeName;
end;

class procedure TMarkdownScrollBarTheme.Apply(const Control: TWinControl; const BackgroundColor: TLayoutColor);
begin
  const CanApply = (Control.HandleAllocated and not TStyleManager.IsCustomStyleActive);
  if not CanApply then
    Exit;

  const WindowThemeName = ThemeName(BackgroundColor);
  if WindowThemeName.IsEmpty then
    SetWindowTheme(Control.Handle, nil, nil)
  else
    SetWindowTheme(Control.Handle, PChar(WindowThemeName), nil);
end;

end.
