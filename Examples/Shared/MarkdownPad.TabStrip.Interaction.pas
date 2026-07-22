unit MarkdownPad.TabStrip.Interaction;

{$SCOPEDENUMS ON}

interface

uses
  System.UITypes,
  MarkdownPad.TabStrip.Layout;

type
  /// <summary>
  /// Outcome of a pointer event: which callbacks the owning control should raise
  /// and whether it needs to repaint. Framework-neutral so the VCL and FMX tab
  /// strips share one interaction state machine.
  /// </summary>
  TPadTabPointerResult = record
    RepaintNeeded: Boolean;
    Select: Boolean;
    SelectIndex: Integer;
    Close: Boolean;
    CloseIndex: Integer;
    Add: Boolean;
    Reorder: Boolean;
    ReorderFrom: Integer;
    ReorderTo: Integer;
  end;

  /// <summary>
  /// Hover, press and drag state for a browser-style tab strip. The control feeds
  /// it pointer coordinates plus the current geometry (available width, tab count)
  /// and applies the returned result; all hit-testing goes through TPadTabLayout.
  /// </summary>
  TPadTabInteraction = record
  public
    const
      DragThreshold = 6;
  private
    FHotIndex: Integer;
    FHotKind: TPadTabHitKind;
    FPressIndex: Integer;
    FPressKind: TPadTabHitKind;
    FPressX: Integer;
    FDragging: Boolean;
  public
    procedure Reset;
    function BeginPress(const X, AvailableWidth, TabCount: Integer;
      const Button: TMouseButton): TPadTabPointerResult;
    function PointerMove(const X, AvailableWidth, TabCount: Integer;
      const LeftDown: Boolean): TPadTabPointerResult;
    function EndPress(const X, AvailableWidth, TabCount: Integer;
      const Button: TMouseButton): TPadTabPointerResult;
    function DoubleClickClose(const X, AvailableWidth, TabCount: Integer): TPadTabPointerResult;
    function ClearHover: Boolean;

    property HotIndex: Integer read FHotIndex;
    property HotKind: TPadTabHitKind read FHotKind;
  end;

implementation

uses
  System.Math;

procedure TPadTabInteraction.Reset;
begin
  FHotIndex := -1;
  FHotKind := TPadTabHitKind.None;
  FPressIndex := -1;
  FPressKind := TPadTabHitKind.None;
  FPressX := 0;
  FDragging := False;
end;

function TPadTabInteraction.BeginPress(const X, AvailableWidth, TabCount: Integer;
  const Button: TMouseButton): TPadTabPointerResult;
begin
  Result := Default(TPadTabPointerResult);

  const Hit = TPadTabLayout.HitTest(X, AvailableWidth, TabCount);

  if Button = TMouseButton.mbMiddle then
  begin
    if Hit.Kind in [TPadTabHitKind.Tab, TPadTabHitKind.Close] then
    begin
      Result.Close := True;
      Result.CloseIndex := Hit.Index;
    end;
    Exit;
  end;

  if Button <> TMouseButton.mbLeft then
    Exit;

  FPressKind := Hit.Kind;
  FPressIndex := Hit.Index;
  FPressX := X;
  FDragging := False;

  if Hit.Kind = TPadTabHitKind.Tab then
  begin
    Result.Select := True;
    Result.SelectIndex := Hit.Index;
  end;
end;

function TPadTabInteraction.PointerMove(const X, AvailableWidth, TabCount: Integer;
  const LeftDown: Boolean): TPadTabPointerResult;
begin
  Result := Default(TPadTabPointerResult);

  const Hit = TPadTabLayout.HitTest(X, AvailableWidth, TabCount);
  if (Hit.Index <> FHotIndex) or (Hit.Kind <> FHotKind) then
  begin
    FHotIndex := Hit.Index;
    FHotKind := Hit.Kind;
    Result.RepaintNeeded := True;
  end;

  if not LeftDown then
    Exit;

  if FPressKind <> TPadTabHitKind.Tab then
    Exit;

  if not FDragging and (Abs(X - FPressX) >= DragThreshold) then
    FDragging := True;

  if not FDragging then
    Exit;

  const TabWidth = TPadTabLayout.ComputeTabWidth(AvailableWidth, TabCount);
  const Target = TPadTabLayout.TabIndexAt(X, TabWidth, TabCount);
  if (Target >= 0) and (Target <> FPressIndex) then
  begin
    Result.Reorder := True;
    Result.ReorderFrom := FPressIndex;
    Result.ReorderTo := Target;
    FPressIndex := Target;
    FPressX := X;
  end;
end;

function TPadTabInteraction.EndPress(const X, AvailableWidth, TabCount: Integer;
  const Button: TMouseButton): TPadTabPointerResult;
begin
  Result := Default(TPadTabPointerResult);

  if Button <> TMouseButton.mbLeft then
    Exit;

  const Hit = TPadTabLayout.HitTest(X, AvailableWidth, TabCount);
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
      if (Hit.Kind = TPadTabHitKind.Close) and (Hit.Index = PressIndex) then
      begin
        Result.Close := True;
        Result.CloseIndex := PressIndex;
      end;
    TPadTabHitKind.Plus:
      if Hit.Kind = TPadTabHitKind.Plus then
        Result.Add := True;
  else
    // A press that started on a tab body or empty area needs no action on release.
  end;
end;

function TPadTabInteraction.DoubleClickClose(const X, AvailableWidth,
  TabCount: Integer): TPadTabPointerResult;
begin
  Result := Default(TPadTabPointerResult);

  // The close glyph already closes on a single click; only treat a double-click on
  // the tab body as a close so double-clicking the glyph does not close twice.
  const Hit = TPadTabLayout.HitTest(X, AvailableWidth, TabCount);
  if Hit.Kind = TPadTabHitKind.Tab then
  begin
    Result.Close := True;
    Result.CloseIndex := Hit.Index;
  end;
end;

function TPadTabInteraction.ClearHover: Boolean;
begin
  Result := (FHotIndex <> -1) or (FHotKind <> TPadTabHitKind.None);
  if not Result then
    Exit;

  FHotIndex := -1;
  FHotKind := TPadTabHitKind.None;
end;

end.
