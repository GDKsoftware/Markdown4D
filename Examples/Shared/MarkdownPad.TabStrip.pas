unit MarkdownPad.TabStrip;

{$SCOPEDENUMS ON}

interface

uses
  Winapi.Messages,
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  MarkdownPad.TabStrip.Layout,
  MarkdownPad.TabStrip.Interaction;

type
  TPadTabHitKind = MarkdownPad.TabStrip.Layout.TPadTabHitKind;

  TPadTabIndexEvent = procedure(Sender: TObject; const Index: Integer) of object;
  TPadTabReorderEvent = procedure(Sender: TObject; const FromIndex, ToIndex: Integer) of object;

  /// <summary>
  /// Owner-drawn Firefox-style tab strip. Renders rounded tab "pills" plus a
  /// trailing add button, draws a close glyph and a modified marker per tab, and
  /// supports drag reordering. Geometry goes through TPadTabLayout and pointer
  /// handling through TPadTabInteraction, both shared with the FMX strip.
  /// </summary>
  TPadTabStrip = class(TCustomControl)
  public
    const
      MinTabWidth = TPadTabLayout.MinTabWidth;
      PlusButtonWidth = TPadTabLayout.PlusButtonWidth;
      CloseButtonSize = TPadTabLayout.CloseButtonSize;
      CloseRightMargin = TPadTabLayout.CloseRightMargin;
      TabLeftPadding = 12;
      TabGap = 2;
      TabTopMargin = 5;
      TabBottomMargin = 4;
      CornerRadius = 8;
      ModifiedMarkerSize = 6;
      CloseGlyphSize = 8;
      PlusGlyphSize = 10;
      GlyphClose = Char($E8BB);
      GlyphAdd = Char($E710);

  strict private
    FCaptions: TArray<string>;
    FModified: TArray<Boolean>;
    FActiveIndex: Integer;
    FAvailableWidth: Integer;
    FTabWidth: Integer;
    FContentWidth: Integer;
    FInteraction: TPadTabInteraction;
    FActiveColor: TColor;
    FInactiveColor: TColor;
    FHoverColor: TColor;
    FTextColor: TColor;
    FAccentColor: TColor;
    FGlyphColor: TColor;
    FGlyphFontName: string;
    FOnSelectTab: TPadTabIndexEvent;
    FOnCloseTab: TPadTabIndexEvent;
    FOnAddTab: TNotifyEvent;
    FOnReorderTab: TPadTabReorderEvent;
    function EffectiveWidth: Integer;
    procedure RecalcLayout;
    procedure ApplyPointerResult(const PointerResult: TPadTabPointerResult);
    procedure DrawTab(const Index: Integer; const TabRect: TRect);
    procedure DrawCloseGlyph(const CenterRect: TRect; const Highlight: Boolean);
    procedure DrawPlusGlyph(const PlusRect: TRect; const Highlight: Boolean);
    procedure DrawModifiedMarker(const CenterRect: TRect);
    procedure DrawGlyphText(const Bounds: TRect; const Glyph: string; const PointSize: Integer);
    procedure FillPill(const Bounds: TRect; const PillColor: TColor);
    procedure SetAvailableWidth(const Value: Integer);

  strict protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure WMLButtonDblClk(var Message: TWMLButtonDblClk); message WM_LBUTTONDBLCLK;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;

  public
    constructor Create(Owner: TComponent); override;
    procedure SetTabs(const Captions: TArray<string>; const Modified: TArray<Boolean>;
      const ActiveIndex: Integer);
    function TabCount: Integer;

    property ActiveIndex: Integer read FActiveIndex;
    property ContentWidth: Integer read FContentWidth;

    property ActiveColor: TColor read FActiveColor write FActiveColor;
    property InactiveColor: TColor read FInactiveColor write FInactiveColor;
    property HoverColor: TColor read FHoverColor write FHoverColor;
    property TextColor: TColor read FTextColor write FTextColor;
    property AccentColor: TColor read FAccentColor write FAccentColor;
    property GlyphColor: TColor read FGlyphColor write FGlyphColor;
    property GlyphFontName: string read FGlyphFontName write FGlyphFontName;
    property AvailableWidth: Integer read FAvailableWidth write SetAvailableWidth;

    property OnSelectTab: TPadTabIndexEvent read FOnSelectTab write FOnSelectTab;
    property OnCloseTab: TPadTabIndexEvent read FOnCloseTab write FOnCloseTab;
    property OnAddTab: TNotifyEvent read FOnAddTab write FOnAddTab;
    property OnReorderTab: TPadTabReorderEvent read FOnReorderTab write FOnReorderTab;
  end;

implementation

uses
  Winapi.Windows;

constructor TPadTabStrip.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse];
  DoubleBuffered := True;

  FActiveIndex := -1;
  FInteraction.Reset;

  FActiveColor := clWhite;
  FInactiveColor := clBtnFace;
  FHoverColor := clBtnHighlight;
  FTextColor := clWindowText;
  FAccentColor := clHighlight;
  FGlyphColor := clWindowText;
end;

procedure TPadTabStrip.SetTabs(const Captions: TArray<string>; const Modified: TArray<Boolean>;
  const ActiveIndex: Integer);
begin
  FCaptions := Captions;
  FModified := Modified;
  FActiveIndex := ActiveIndex;

  RecalcLayout;
  Invalidate;
end;

function TPadTabStrip.TabCount: Integer;
begin
  Result := System.Length(FCaptions);
end;

function TPadTabStrip.EffectiveWidth: Integer;
begin
  if FAvailableWidth > 0 then
    Result := FAvailableWidth
  else
    Result := ClientWidth;
end;

procedure TPadTabStrip.RecalcLayout;
begin
  FTabWidth := TPadTabLayout.ComputeTabWidth(EffectiveWidth, TabCount);
  FContentWidth := TPadTabLayout.ContentWidthFor(EffectiveWidth, TabCount, FTabWidth);

  if (Align = alNone) and (FAvailableWidth > 0) then
    Width := FContentWidth;
end;

procedure TPadTabStrip.SetAvailableWidth(const Value: Integer);
begin
  if FAvailableWidth = Value then
    Exit;

  FAvailableWidth := Value;
  RecalcLayout;
  Invalidate;
end;

procedure TPadTabStrip.Resize;
begin
  inherited Resize;

  RecalcLayout;
  Invalidate;
end;

procedure TPadTabStrip.FillPill(const Bounds: TRect; const PillColor: TColor);
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := PillColor;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Color := PillColor;
  Canvas.RoundRect(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom, CornerRadius * 2, CornerRadius * 2);
end;

procedure TPadTabStrip.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := FInactiveColor;
  Canvas.FillRect(ClientRect);

  if TabCount = 0 then
    Exit;

  for var Index := 0 to TabCount - 1 do
  begin
    const TabRect = Rect(Index * FTabWidth, 0, (Index + 1) * FTabWidth, Height);
    if TabRect.Left >= FContentWidth - PlusButtonWidth then
      Break;

    DrawTab(Index, TabRect);
  end;

  const PlusLeft = FContentWidth - PlusButtonWidth;
  DrawPlusGlyph(Rect(PlusLeft, 0, PlusLeft + PlusButtonWidth, Height),
    FInteraction.HotKind = TPadTabHitKind.Plus);
end;

procedure TPadTabStrip.DrawTab(const Index: Integer; const TabRect: TRect);
begin
  const Active = Index = FActiveIndex;
  const Hot = (FInteraction.HotIndex = Index) and
    (FInteraction.HotKind in [TPadTabHitKind.Tab, TPadTabHitKind.Close]);

  const Pill = Rect(TabRect.Left + TabGap, TabTopMargin, TabRect.Right - TabGap,
    Height - TabBottomMargin);

  if Active then
    FillPill(Pill, FActiveColor)
  else if Hot then
    FillPill(Pill, FHoverColor);

  const CloseRight = TabRect.Right - CloseRightMargin;
  const CloseLeft = CloseRight - CloseButtonSize;
  const CloseRect = Rect(CloseLeft, 0, CloseRight, Height);
  const ShowClose = Active or Hot;

  var TextRight := CloseLeft - 4;
  const ShowMarker = (Index <= High(FModified)) and FModified[Index] and not ShowClose;
  if ShowMarker then
    TextRight := TextRight - ModifiedMarkerSize - 6;

  const Caption = FCaptions[Index];
  var TextRect := Rect(TabRect.Left + TabLeftPadding, 0, TextRight, Height);

  Canvas.Font := Font;
  Canvas.Font.Color := FTextColor;
  Canvas.Brush.Style := bsClear;
  Winapi.Windows.DrawText(Canvas.Handle, PChar(Caption), System.Length(Caption), TextRect,
    DT_SINGLELINE or DT_VCENTER or DT_LEFT or DT_END_ELLIPSIS or DT_NOPREFIX);
  Canvas.Brush.Style := bsSolid;

  if ShowMarker then
    DrawModifiedMarker(Rect(CloseLeft - ModifiedMarkerSize - 6, 0, CloseLeft - 6, Height));

  if ShowClose then
    DrawCloseGlyph(CloseRect,
      (FInteraction.HotIndex = Index) and (FInteraction.HotKind = TPadTabHitKind.Close));
end;

procedure TPadTabStrip.DrawModifiedMarker(const CenterRect: TRect);
begin
  const Size = ModifiedMarkerSize;
  const Left = CenterRect.Left + (CenterRect.Width - Size) div 2;
  const Top = CenterRect.Top + (CenterRect.Height - Size) div 2;

  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := FGlyphColor;
  Canvas.Pen.Color := FGlyphColor;
  Canvas.Ellipse(Left, Top, Left + Size, Top + Size);
end;

procedure TPadTabStrip.DrawGlyphText(const Bounds: TRect; const Glyph: string; const PointSize: Integer);
begin
  Canvas.Font.Name := FGlyphFontName;
  Canvas.Font.Size := PointSize;
  Canvas.Font.Color := FGlyphColor;
  Canvas.Font.Style := [];
  Canvas.Brush.Style := bsClear;

  var GlyphRect := Bounds;
  Winapi.Windows.DrawText(Canvas.Handle, PChar(Glyph), System.Length(Glyph), GlyphRect,
    DT_SINGLELINE or DT_VCENTER or DT_CENTER or DT_NOPREFIX);

  Canvas.Brush.Style := bsSolid;
end;

procedure TPadTabStrip.DrawCloseGlyph(const CenterRect: TRect; const Highlight: Boolean);
begin
  if Highlight then
  begin
    const BoxSize = CloseButtonSize;
    const Left = CenterRect.Left + (CenterRect.Width - BoxSize) div 2;
    const Top = CenterRect.Top + (CenterRect.Height - BoxSize) div 2;

    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := FHoverColor;
    Canvas.Pen.Color := FHoverColor;
    Canvas.RoundRect(Left, Top, Left + BoxSize, Top + BoxSize, 4, 4);
  end;

  DrawGlyphText(CenterRect, GlyphClose, CloseGlyphSize);
end;

procedure TPadTabStrip.DrawPlusGlyph(const PlusRect: TRect; const Highlight: Boolean);
begin
  if Highlight then
  begin
    const HotBox = Rect(PlusRect.Left + 3, PlusRect.Top + TabTopMargin, PlusRect.Right - 3,
      PlusRect.Bottom - TabBottomMargin);
    FillPill(HotBox, FHoverColor);
  end;

  DrawGlyphText(PlusRect, GlyphAdd, PlusGlyphSize);
end;

procedure TPadTabStrip.ApplyPointerResult(const PointerResult: TPadTabPointerResult);
begin
  if PointerResult.RepaintNeeded then
    Invalidate;

  if PointerResult.Select and (PointerResult.SelectIndex <> FActiveIndex) and Assigned(FOnSelectTab) then
    FOnSelectTab(Self, PointerResult.SelectIndex);

  if PointerResult.Close and Assigned(FOnCloseTab) then
    FOnCloseTab(Self, PointerResult.CloseIndex);

  if PointerResult.Add and Assigned(FOnAddTab) then
    FOnAddTab(Self);

  if PointerResult.Reorder and Assigned(FOnReorderTab) then
    FOnReorderTab(Self, PointerResult.ReorderFrom, PointerResult.ReorderTo);
end;

procedure TPadTabStrip.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);

  ApplyPointerResult(FInteraction.BeginPress(X, EffectiveWidth, TabCount, Button));
end;

procedure TPadTabStrip.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);

  ApplyPointerResult(FInteraction.PointerMove(X, EffectiveWidth, TabCount, ssLeft in Shift));
end;

procedure TPadTabStrip.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);

  ApplyPointerResult(FInteraction.EndPress(X, EffectiveWidth, TabCount, Button));
end;

procedure TPadTabStrip.WMLButtonDblClk(var Message: TWMLButtonDblClk);
begin
  inherited;

  ApplyPointerResult(FInteraction.DoubleClickClose(Message.XPos, EffectiveWidth, TabCount));
end;

procedure TPadTabStrip.CMMouseLeave(var Message: TMessage);
begin
  inherited;

  if FInteraction.ClearHover then
    Invalidate;
end;

end.
