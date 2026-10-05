unit Markdown4D.Layout.Zoom;

{$SCOPEDENUMS ON}

interface

type
  TMarkdownZoomAction = (None, StepIn, StepOut, Reset);

  // The zoom levels a reader steps through, in percent, the same ladder
  // browsers walk with Ctrl+wheel and Ctrl+Plus/Minus.
  TMarkdownZoom = record
  public
    const
      DefaultPercent = 100;
      MinimumPercent = 25;
      MaximumPercent = 500;
    class function StepIn(const Percent: Integer): Integer; static;
    class function StepOut(const Percent: Integer): Integer; static;
    class function Clamp(const Percent: Integer): Integer; static;
    // What a key pressed with Ctrl does to the zoom: Plus and Minus on the main
    // keyboard and on the numeric keypad step, 0 resets. Virtual key codes are
    // the same in the VCL and in FMX.
    class function ActionOfKey(const Key: Word): TMarkdownZoomAction; static;
  end;

implementation

uses
  System.Math,
  System.UITypes;

const
  Levels: array[0..16] of Integer = (25, 33, 50, 67, 75, 80, 90, 100, 110, 125, 150, 175, 200, 250, 300, 400, 500);

class function TMarkdownZoom.StepIn(const Percent: Integer): Integer;
begin
  Result := MaximumPercent;

  for var Level in Levels do
  begin
    const IsLarger = (Level > Percent);
    if IsLarger then
    begin
      Result := Level;
      Exit;
    end;
  end;
end;

class function TMarkdownZoom.StepOut(const Percent: Integer): Integer;
begin
  Result := MinimumPercent;

  for var Index := High(Levels) downto Low(Levels) do
  begin
    const IsSmaller = (Levels[Index] < Percent);
    if IsSmaller then
    begin
      Result := Levels[Index];
      Exit;
    end;
  end;
end;

class function TMarkdownZoom.Clamp(const Percent: Integer): Integer;
begin
  Result := EnsureRange(Percent, MinimumPercent, MaximumPercent);
end;

class function TMarkdownZoom.ActionOfKey(const Key: Word): TMarkdownZoomAction;
begin
  case Key of
    vkEqual, vkAdd:
      Result := TMarkdownZoomAction.StepIn;
    vkMinus, vkSubtract:
      Result := TMarkdownZoomAction.StepOut;
    vk0, vkNumpad0:
      Result := TMarkdownZoomAction.Reset;
  else
    Result := TMarkdownZoomAction.None;
  end;
end;

end.
