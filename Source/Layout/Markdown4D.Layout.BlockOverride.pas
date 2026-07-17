unit Markdown4D.Layout.BlockOverride;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Theme;

type
  ILayoutBlockContext = interface
    ['{5E1A7C34-9B62-4D08-A5F1-72C0E4B36D91}']
    function GetMeasurer: ITextMeasurer;
    function GetTheme: TMarkdownTheme;
    function GetWidth: Single;
    procedure EmitRectangle(const Bounds: TLayoutRectF; const FillColor, StrokeColor: TLayoutColor;
      const StrokeWidth: Single);
    procedure EmitTextRun(const TopLeft: TLayoutPointF; const Text: string; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor);
    procedure EmitLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure EmitWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const Color: TLayoutColor);
    procedure EmitPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
    property Measurer: ITextMeasurer read GetMeasurer;
    property Theme: TMarkdownTheme read GetTheme;
    property Width: Single read GetWidth;
  end;

  ILayoutBlockOverride = interface
    ['{A0D46F17-3C85-4E29-8B60-91F5D2A7C438}']
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
    property Name: string read GetName;
  end;

  TLayoutBlockOverrideRegistry = class
  private
    type
      TRegistration = record
        Handler: ILayoutBlockOverride;
        Priority: Integer;
        Ordinal: Integer;
      end;
    class var
      FRegistrations: TArray<TRegistration>;
      FNextOrdinal: Integer;

  public
    class procedure Register(const Handler: ILayoutBlockOverride; const Priority: Integer);
    class function TryFind(const Node: IMarkdownNode; out Handler: ILayoutBlockOverride): Boolean;
    class procedure Clear;
  end;

implementation

class procedure TLayoutBlockOverrideRegistry.Register(const Handler: ILayoutBlockOverride; const Priority: Integer);
begin
  var Registration := Default(TRegistration);
  Registration.Handler := Handler;
  Registration.Priority := Priority;
  Registration.Ordinal := FNextOrdinal;
  Inc(FNextOrdinal);

  FRegistrations := FRegistrations + [Registration];
end;

class function TLayoutBlockOverrideRegistry.TryFind(const Node: IMarkdownNode;
  out Handler: ILayoutBlockOverride): Boolean;
begin
  Handler := nil;

  var BestIndex := -1;
  for var Index := 0 to High(FRegistrations) do
  begin
    if not FRegistrations[Index].Handler.Handles(Node) then
      Continue;

    const Wins = (BestIndex < 0) or (FRegistrations[Index].Priority > FRegistrations[BestIndex].Priority) or
      ((FRegistrations[Index].Priority = FRegistrations[BestIndex].Priority) and
      (FRegistrations[Index].Ordinal < FRegistrations[BestIndex].Ordinal));
    if Wins then
      BestIndex := Index;
  end;

  if BestIndex < 0 then
    Exit(False);

  Handler := FRegistrations[BestIndex].Handler;
  Result := True;
end;

class procedure TLayoutBlockOverrideRegistry.Clear;
begin
  FRegistrations := nil;
  FNextOrdinal := 0;
end;

end.
