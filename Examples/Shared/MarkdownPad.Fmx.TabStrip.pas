unit MarkdownPad.Fmx.TabStrip;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.Types,
  System.UITypes,
  FMX.Controls,
  FMX.Graphics,
  FMX.Types,
  MarkdownPad.TabStrip.Layout;

type
  TPadFmxTabIndexEvent = procedure(Sender: TObject; const Index: Integer) of object;
  TPadFmxTabReorderEvent = procedure(Sender: TObject; const FromIndex, ToIndex: Integer) of object;

  /// <summary>
  /// Owner-drawn Firefox-style tab strip for FMX. Mirrors the VCL TPadTabStrip and
  /// shares the framework-neutral TPadTabLayout geometry, so tab widths, hit regions
  /// and interaction match across both example apps.
  /// </summary>
  TPadFmxTabStrip = class(TControl)
  public
    const
      TabLeftPadding = 12;
      TabGap = 2;
      TabTopMargin = 5;
      TabBottomMargin = 4;
      CornerRadius = 8;
      CloseGlyphSize = 11;
      PlusGlyphSize = 13;
      ModifiedMarkerSize = 6;
      DragThreshold = 6;
      GlyphClose = Char($E8BB);
      GlyphAdd = Char($E710);

  private
    FCaptions: TArray<string>;
    FModified: TArray<Boolean>;
    FActiveIndex: Integer;
    FAvailableWidth: Integer;
    FTabWidth: Integer;
    FContentWidth: Integer;
    FHotIndex: Integer;
    FHotKind: TPadTabHitKind;
    FPressIndex: Integer;
    FPressKind: TPadTabHitKind;
    FPressX: Single;
    FLastDownX: Single;
    FDragging: Boolean;
    FActiveColor: TAlphaColor;
    FInactiveColor: TAlphaColor;
    FHoverColor: TAlphaColor;
    FTextColor: TAlphaColor;
    FGlyphColor: TAlphaColor;
    FFontFamily: string;
    FGlyphFontName: string;
    FOnSelectTab: TPadFmxTabIndexEvent;
    FOnCloseTab: TPadFmxTabIndexEvent;
    FOnAddTab: TNotifyEvent;
    FOnReorderTab: TPadFmxTabReorderEvent;
    function EffectiveWidth: Integer;
    procedure RecalcLayout;
    function HitAtX(const X: Single): TPadTabHit;
    procedure UpdateHot(const X: Single);
    procedure DrawTab(const Index: Integer; const TabLeft: Single);
    procedure DrawPill(const Bounds: TRectF; const PillColor: TAlphaColor);
    procedure DrawCloseGlyph(const CenterX, CenterY: Single; const Highlight: Boolean);
    procedure DrawPlusGlyph(const CenterX, CenterY: Single; const Highlight: Boolean);
    procedure DrawGlyphText(const CenterX, CenterY: Single; const Glyph: string; const GlyphSize: Single);
    procedure DrawModifiedMarker(const CenterX, CenterY: Single);
    procedure SetAvailableWidth(const Value: Integer);

  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DblClick; override;
    procedure DoMouseLeave; override;

  public
    constructor Create(Owner: TComponent); override;
    procedure SetTabs(const Captions: TArray<string>; const Modified: TArray<Boolean>;
      const ActiveIndex: Integer);
    function TabCount: Integer;

    property ContentWidth: Integer read FContentWidth;
    property FontFamily: string read FFontFamily write FFontFamily;
    property GlyphFontName: string read FGlyphFontName write FGlyphFontName;
    property ActiveColor: TAlphaColor read FActiveColor write FActiveColor;
    property InactiveColor: TAlphaColor read FInactiveColor write FInactiveColor;
    property HoverColor: TAlphaColor read FHoverColor write FHoverColor;
    property TextColor: TAlphaColor read FTextColor write FTextColor;
    property GlyphColor: TAlphaColor read FGlyphColor write FGlyphColor;
    property AvailableWidth: Integer read FAvailableWidth write SetAvailableWidth;

    property OnSelectTab: TPadFmxTabIndexEvent read FOnSelectTab write FOnSelectTab;
    property OnCloseTab: TPadFmxTabIndexEvent read FOnCloseTab write FOnCloseTab;
    property OnAddTab: TNotifyEvent read FOnAddTab write FOnAddTab;
    property OnReorderTab: TPadFmxTabReorderEvent read FOnReorderTab write FOnReorderTab;
  end;

implementation

uses
  System.Math;

constructor TPadFmxTabStrip.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  HitTest := True;
  AutoCapture := True;

  FActiveIndex := -1;
  FHotIndex := -1;
  FHotKind := TPadTabHitKind.None;
  FPressIndex := -1;
  FPressKind := TPadTabHitKind.None;
  FFontFamily := 'Segoe UI';

  FActiveColor := TAlphaColors.White;
  FInactiveColor := TAlphaColors.Gainsboro;
  FHoverColor := TAlphaColors.Silver;
  FTextColor := TAlphaColors.Black;
  FGlyphColor := TAlphaColors.Black;
end;

procedure TPadFmxTabStrip.SetTabs(const Captions: TArray<string>; const Modified: TArray<Boolean>;
  const ActiveIndex: Integer);
begin
  FCaptions := Captions;
  FModified := Modified;
  FActiveIndex := ActiveIndex;

  RecalcLayout;
  Repaint;
end;

function TPadFmxTabStrip.TabCount: Integer;
begin
  Result := System.Length(FCaptions);
end;

function TPadFmxTabStrip.EffectiveWidth: Integer;
begin
  if FAvailableWidth > 0 then
    Result := FAvailableWidth
  else
    Result := Round(Width);
end;

procedure TPadFmxTabStrip.RecalcLayout;
begin
  FTabWidth := TPadTabLayout.ComputeTabWidth(EffectiveWidth, TabCount);
  FContentWidth := TPadTabLayout.ContentWidthFor(EffectiveWidth, TabCount, FTabWidth);

  if FAvailableWidth > 0 then
    Width := FContentWidth;
end;

function TPadFmxTabStrip.HitAtX(const X: Single): TPadTabHit;
begin
  Result := TPadTabLayout.HitTest(Round(X), EffectiveWidth, TabCount);
end;

procedure TPadFmxTabStrip.SetAvailableWidth(const Value: Integer);
begin
  if FAvailableWidth = Value then
    Exit;

  FAvailableWidth := Value;
  RecalcLayout;
  Repaint;
end;

procedure TPadFmxTabStrip.Resize;
begin
  inherited Resize;

  RecalcLayout;
  Repaint;
end;

procedure TPadFmxTabStrip.DrawPill(const Bounds: TRectF; const PillColor: TAlphaColor);
begin
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := PillColor;
  Canvas.FillRect(Bounds, CornerRadius, CornerRadius, AllCorners, 1);
end;

procedure TPadFmxTabStrip.Paint;
begin
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := FInactiveColor;
  Canvas.FillRect(RectF(0, 0, Width, Height), 0, 0, [], 1);

  if TabCount = 0 then
    Exit;

  for var Index := 0 to TabCount - 1 do
  begin
    const TabLeft = Index * FTabWidth;
    if TabLeft >= FContentWidth - TPadTabLayout.PlusButtonWidth then
      Break;

    DrawTab(Index, TabLeft);
  end;

  const PlusLeft = FContentWidth - TPadTabLayout.PlusButtonWidth;
  DrawPlusGlyph(PlusLeft + TPadTabLayout.PlusButtonWidth / 2, Height / 2,
    FHotKind = TPadTabHitKind.Plus);
end;

procedure TPadFmxTabStrip.DrawTab(const Index: Integer; const TabLeft: Single);
begin
  const Active = Index = FActiveIndex;
  const Hot = (FHotIndex = Index) and (FHotKind in [TPadTabHitKind.Tab, TPadTabHitKind.Close]);
  const TabRight = TabLeft + FTabWidth;

  const Pill = RectF(TabLeft + TabGap, TabTopMargin, TabRight - TabGap, Height - TabBottomMargin);
  if Active then
    DrawPill(Pill, FActiveColor)
  else if Hot then
    DrawPill(Pill, FHoverColor);

  const CloseRight = TabRight - TPadTabLayout.CloseRightMargin;
  const CloseLeft = CloseRight - TPadTabLayout.CloseButtonSize;
  const ShowClose = Active or Hot;

  var TextRight := CloseLeft - 4;
  const ShowMarker = (Index <= High(FModified)) and FModified[Index] and not ShowClose;
  if ShowMarker then
    TextRight := TextRight - ModifiedMarkerSize - 6;

  Canvas.Font.Family := FFontFamily;
  Canvas.Font.Size := 13;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := FTextColor;
  Canvas.FillText(RectF(TabLeft + TabLeftPadding, 0, TextRight, Height), FCaptions[Index],
    False, 1, [], TTextAlign.Leading, TTextAlign.Center);

  if ShowMarker then
    DrawModifiedMarker((CloseLeft + CloseRight) / 2 - TPadTabLayout.CloseButtonSize / 2, Height / 2);

  if ShowClose then
    DrawCloseGlyph((CloseLeft + CloseRight) / 2, Height / 2,
      (FHotIndex = Index) and (FHotKind = TPadTabHitKind.Close));
end;

procedure TPadFmxTabStrip.DrawModifiedMarker(const CenterX, CenterY: Single);
begin
  const Half = ModifiedMarkerSize / 2;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := FGlyphColor;
  Canvas.FillEllipse(RectF(CenterX - Half, CenterY - Half, CenterX + Half, CenterY + Half), 1);
end;

procedure TPadFmxTabStrip.DrawGlyphText(const CenterX, CenterY: Single; const Glyph: string;
  const GlyphSize: Single);
begin
  Canvas.Font.Family := FGlyphFontName;
  Canvas.Font.Size := GlyphSize;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := FGlyphColor;
  Canvas.FillText(RectF(CenterX - 12, CenterY - 12, CenterX + 12, CenterY + 12), Glyph,
    False, 1, [], TTextAlign.Center, TTextAlign.Center);
end;

procedure TPadFmxTabStrip.DrawCloseGlyph(const CenterX, CenterY: Single; const Highlight: Boolean);
begin
  const Half = TPadTabLayout.CloseButtonSize / 2;
  if Highlight then
  begin
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := FHoverColor;
    Canvas.FillRect(RectF(CenterX - Half, CenterY - Half, CenterX + Half, CenterY + Half), 4, 4,
      AllCorners, 1);
  end;

  DrawGlyphText(CenterX, CenterY, GlyphClose, CloseGlyphSize);
end;

procedure TPadFmxTabStrip.DrawPlusGlyph(const CenterX, CenterY: Single; const Highlight: Boolean);
begin
  if Highlight then
  begin
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := FHoverColor;
    Canvas.FillRect(RectF(CenterX - 12, TabTopMargin, CenterX + 12, Height - TabBottomMargin),
      CornerRadius, CornerRadius, AllCorners, 1);
  end;

  DrawGlyphText(CenterX, CenterY, GlyphAdd, PlusGlyphSize);
end;

procedure TPadFmxTabStrip.UpdateHot(const X: Single);
begin
  const Hit = HitAtX(X);
  if (Hit.Index = FHotIndex) and (Hit.Kind = FHotKind) then
    Exit;

  FHotIndex := Hit.Index;
  FHotKind := Hit.Kind;
  Repaint;
end;

procedure TPadFmxTabStrip.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseDown(Button, Shift, X, Y);

  FLastDownX := X;
  const Hit = HitAtX(X);

  if Button = TMouseButton.mbMiddle then
  begin
    if (Hit.Kind in [TPadTabHitKind.Tab, TPadTabHitKind.Close]) and Assigned(FOnCloseTab) then
      FOnCloseTab(Self, Hit.Index);
    Exit;
  end;

  if Button <> TMouseButton.mbLeft then
    Exit;

  FPressKind := Hit.Kind;
  FPressIndex := Hit.Index;
  FPressX := X;
  FDragging := False;

  if (Hit.Kind = TPadTabHitKind.Tab) and (Hit.Index <> FActiveIndex) and Assigned(FOnSelectTab) then
    FOnSelectTab(Self, Hit.Index);
end;

procedure TPadFmxTabStrip.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited MouseMove(Shift, X, Y);

  UpdateHot(X);

  if not (ssLeft in Shift) then
    Exit;

  if FPressKind <> TPadTabHitKind.Tab then
    Exit;

  if not FDragging and (Abs(X - FPressX) >= DragThreshold) then
    FDragging := True;

  if not FDragging then
    Exit;

  const Target = TPadTabLayout.TabIndexAt(Round(X), FTabWidth, TabCount);
  if (Target >= 0) and (Target <> FPressIndex) and Assigned(FOnReorderTab) then
  begin
    const From = FPressIndex;
    FPressIndex := Target;
    FPressX := X;
    FOnReorderTab(Self, From, Target);
  end;
end;

procedure TPadFmxTabStrip.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseUp(Button, Shift, X, Y);

  if Button <> TMouseButton.mbLeft then
    Exit;

  const Hit = HitAtX(X);
  const WasDragging = FDragging;
  const PressKind = FPressKind;
  const PressIndex = FPressIndex;

  FDragging := False;
  FPressKind := TPadTabHitKind.None;
  FPressIndex := -1;

  if WasDragging then
    Exit;

  case PressKind of
    TPadTabHitKind.Close:
      if (Hit.Kind = TPadTabHitKind.Close) and (Hit.Index = PressIndex) and Assigned(FOnCloseTab) then
        FOnCloseTab(Self, PressIndex);
    TPadTabHitKind.Plus:
      if (Hit.Kind = TPadTabHitKind.Plus) and Assigned(FOnAddTab) then
        FOnAddTab(Self);
  else
    // A press that started on a tab body or empty area needs no action on release.
  end;
end;

procedure TPadFmxTabStrip.DblClick;
begin
  inherited DblClick;

  // Close glyph already closes on a single click; only treat a double-click on the
  // tab body as a close so double-clicking the glyph does not close twice.
  const Hit = HitAtX(FLastDownX);
  if (Hit.Kind = TPadTabHitKind.Tab) and Assigned(FOnCloseTab) then
    FOnCloseTab(Self, Hit.Index);
end;

procedure TPadFmxTabStrip.DoMouseLeave;
begin
  inherited DoMouseLeave;

  if (FHotIndex <> -1) or (FHotKind <> TPadTabHitKind.None) then
  begin
    FHotIndex := -1;
    FHotKind := TPadTabHitKind.None;
    Repaint;
  end;
end;

end.
