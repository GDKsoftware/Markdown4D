unit Markdown4DStudioVCL.ToolButton;

{$SCOPEDENUMS ON}

// A flat toolbar button that paints its own hover and pressed backgrounds in
// the theme's colours. TSpeedButton draws its pressed state with a fixed light
// pattern built from the system colours, which stands out on a dark toolbar.

interface

uses
  System.Classes,
  Vcl.Graphics,
  Vcl.Buttons;

type
  TPadToolButton = class(TSpeedButton)
  private
    FHoverColor: TColor;
    FActiveColor: TColor;
    function BackgroundColor: TColor;
    procedure SetHoverColor(const Value: TColor);
    procedure SetActiveColor(const Value: TColor);

  protected
    procedure Paint; override;

  public
    // AOwner keeps the name TComponent gives it, so it does not hide Owner.
    constructor Create(AOwner: TComponent); override;
    property HoverColor: TColor read FHoverColor write SetHoverColor;
    property ActiveColor: TColor read FActiveColor write SetActiveColor;
  end;

implementation

uses
  System.Types,
  Winapi.Windows;

constructor TPadToolButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Flat := True;
  FHoverColor := clNone;
  FActiveColor := clNone;
end;

// DrawText rather than TCanvas.TextRect, whose TTextFormat overload does not
// accept a property such as Caption as its var text argument.
procedure TPadToolButton.Paint;
begin
  const Background = BackgroundColor;
  const HasBackground = (Background <> clNone);
  if HasBackground then
  begin
    Canvas.Brush.Style := TBrushStyle.bsSolid;
    Canvas.Brush.Color := Background;
    Canvas.FillRect(ClientRect);
  end;

  Canvas.Font := Font;
  if not Enabled then
    Canvas.Font.Color := clGrayText;

  var TextBounds := ClientRect;
  const Glyph = Caption;
  Canvas.Brush.Style := TBrushStyle.bsClear;
  DrawText(Canvas.Handle, PChar(Glyph), -1, TextBounds, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
end;

function TPadToolButton.BackgroundColor: TColor;
begin
  const IsPressed = (Down or (FState = TButtonState.bsDown));
  const IsHovered = (MouseInControl and Enabled);

  if IsPressed then
    Result := FActiveColor
  else if IsHovered then
    Result := FHoverColor
  else
    Result := clNone;
end;

procedure TPadToolButton.SetHoverColor(const Value: TColor);
begin
  FHoverColor := Value;
  Invalidate;
end;

procedure TPadToolButton.SetActiveColor(const Value: TColor);
begin
  FActiveColor := Value;
  Invalidate;
end;

end.
