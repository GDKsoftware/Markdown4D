unit Markdown4DStudioVCL.ToolButton;

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
    procedure SetHoverColor(const Value: TColor);
    procedure SetActiveColor(const Value: TColor);
    function BackgroundColor: TColor;

  protected
    procedure Paint; override;

  public
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

procedure TPadToolButton.Paint;
begin
  const Background = BackgroundColor;
  const HasBackground = (Background <> clNone);
  if HasBackground then
  begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := Background;
    Canvas.FillRect(ClientRect);
  end;

  Canvas.Font := Font;
  if not Enabled then
    Canvas.Font.Color := clGrayText;

  var TextBounds := ClientRect;
  Canvas.Brush.Style := bsClear;
  DrawText(Canvas.Handle, PChar(Caption), -1, TextBounds, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
end;

function TPadToolButton.BackgroundColor: TColor;
begin
  const IsPressed = (Down or (FState = bsDown));
  if IsPressed then
    Exit(FActiveColor);

  const IsHovered = (MouseInControl and Enabled);
  if IsHovered then
    Exit(FHoverColor);

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
