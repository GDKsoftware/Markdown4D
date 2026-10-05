unit Markdown4D.Layout.Pointer;

{$SCOPEDENUMS ON}

interface

type
  TMarkdownPointer = record
    // Whether the primary mouse button is down right now, also when another
    // control (a splitter, a window edge) holds the mouse. Only Windows answers;
    // elsewhere this is False and a caller falls back to waiting for the pointer
    // to rest.
    class function IsPrimaryButtonDown: Boolean; static;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;
{$ENDIF}

class function TMarkdownPointer.IsPrimaryButtonDown: Boolean;
begin
{$IFDEF MSWINDOWS}
  var PrimaryButton := VK_LBUTTON;
  const ButtonsSwapped = (GetSystemMetrics(SM_SWAPBUTTON) <> 0);
  if ButtonsSwapped then
    PrimaryButton := VK_RBUTTON;

  Result := (GetKeyState(PrimaryButton) < 0);
{$ELSE}
  Result := False;
{$ENDIF}
end;

end.
