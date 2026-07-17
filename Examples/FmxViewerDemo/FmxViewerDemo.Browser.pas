unit FmxViewerDemo.Browser;

{$SCOPEDENUMS ON}

interface

type
  TBrowserLauncher = class
  public
    class procedure Open(const Url: string); static;
  end;

implementation

uses
  System.SysUtils
{$IFDEF MSWINDOWS}
  , Winapi.Windows
  , Winapi.ShellAPI
{$ENDIF}
{$IFDEF POSIX}
  , Posix.Stdlib
{$ENDIF}
  ;

class procedure TBrowserLauncher.Open(const Url: string);
{$IFDEF MSWINDOWS}
const
  OpenVerb = 'open';
{$ENDIF}
{$IFDEF POSIX}
{$IFDEF MACOS}
const
  OpenCommandFormat = 'open "%s"';
{$ELSE}
const
  OpenCommandFormat = 'xdg-open "%s"';
{$ENDIF}
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  ShellExecute(0, OpenVerb, PChar(Url), nil, nil, SW_SHOWNORMAL);
{$ENDIF}
{$IFDEF POSIX}
  _system(PAnsiChar(AnsiString(Format(OpenCommandFormat, [Url]))));
{$ENDIF}
end;

end.
