unit Markdown4D.Layout.Zoom;

{$SCOPEDENUMS ON}

interface

type
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
  end;

implementation

uses
  System.Math;

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

end.
