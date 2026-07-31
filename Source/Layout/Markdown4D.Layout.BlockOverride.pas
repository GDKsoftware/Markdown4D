unit Markdown4D.Layout.BlockOverride;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Theme;

type
  IExtensionCanvas = interface
    ['{4B9F1D62-8C07-4A53-9E21-3D6B0F5A7C84}']
    function MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
    procedure DrawText(const TopLeft: TLayoutPointF; const Text: string; const Font: TMarkdownFontStyle;
      const Color: TLayoutColor);
    procedure DrawLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor; const StrokeWidth: Single);
    procedure DrawDashedLine(const StartPoint, EndPoint: TLayoutPointF; const Color: TLayoutColor;
      const StrokeWidth: Single);
    procedure FillRectangle(const Bounds: TLayoutRectF; const Color: TLayoutColor);
    procedure DrawRectangle(const Bounds: TLayoutRectF; const StrokeColor: TLayoutColor; const StrokeWidth: Single);
    procedure FillAndStrokeRectangle(const Bounds: TLayoutRectF; const FillColor, StrokeColor: TLayoutColor;
      const StrokeWidth: Single);
    procedure FillPolygon(const Points: TArray<TLayoutPointF>; const Color: TLayoutColor);
    procedure DrawPolygon(const Points: TArray<TLayoutPointF>; const StrokeColor: TLayoutColor;
      const StrokeWidth: Single);
    procedure FillAndStrokePolygon(const Points: TArray<TLayoutPointF>; const FillColor, StrokeColor: TLayoutColor;
      const StrokeWidth: Single);
    procedure FillWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const Color: TLayoutColor);
    procedure DrawWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle, SweepAngle: Single;
      const StrokeColor: TLayoutColor; const StrokeWidth: Single);
    procedure FillAndStrokeWedge(const Center: TLayoutPointF; const OuterRadius, InnerRadius, StartAngle,
      SweepAngle: Single; const FillColor, StrokeColor: TLayoutColor; const StrokeWidth: Single);
    procedure DrawImage(const Bounds: TLayoutRectF; const Source, AltText: string);
    procedure SaveState;
    procedure SetClip(const Bounds: TLayoutRectF);
    procedure RestoreState;
  end;

  ILayoutBlockContext = interface
    ['{5E1A7C34-9B62-4D08-A5F1-72C0E4B36D91}']
    function GetMeasurer: ITextMeasurer;
    function GetTheme: TMarkdownTheme;
    function GetWidth: Single;
    function GetCanvas: IExtensionCanvas;
    property Measurer: ITextMeasurer read GetMeasurer;
    property Theme: TMarkdownTheme read GetTheme;
    property Width: Single read GetWidth;
    property Canvas: IExtensionCanvas read GetCanvas;
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

  TLayoutDocumentProcessorRegistry = class
  private
    class var
      FProcessors: TArray<IMarkdownDocumentProcessor>;

  public
    class procedure Register(const Processor: IMarkdownDocumentProcessor);
    class procedure Process(const Document: IMarkdownDocument);
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

class procedure TLayoutDocumentProcessorRegistry.Register(const Processor: IMarkdownDocumentProcessor);
begin
  FProcessors := FProcessors + [Processor];
end;

class procedure TLayoutDocumentProcessorRegistry.Process(const Document: IMarkdownDocument);
begin
  if Document = nil then
    Exit;

  for var Processor in FProcessors do
  begin
    Processor.Process(Document);
  end;
end;

class procedure TLayoutDocumentProcessorRegistry.Clear;
begin
  FProcessors := nil;
end;

end.
