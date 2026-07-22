unit MarkdownPad.TabStrip.Layout;

{$SCOPEDENUMS ON}

interface

type
  TPadTabHitKind = (None, Tab, Close, Plus);

  TPadTabHit = record
    Kind: TPadTabHitKind;
    Index: Integer;
  end;

  /// <summary>
  /// Framework-neutral geometry for the browser-style tab strip. The VCL and FMX
  /// strip controls both delegate here so tab widths and hit regions stay identical
  /// across frameworks and can be unit tested without a window handle.
  /// </summary>
  TPadTabLayout = record
  public
    const
      MinTabWidth = 96;
      MaxTabWidth = 240;
      PlusButtonWidth = 34;
      CloseButtonSize = 16;
      CloseRightMargin = 8;

    class function ComputeTabWidth(const AvailableWidth, ATabCount: Integer): Integer; static;
    class function ContentWidthFor(const AvailableWidth, ATabCount, TabWidth: Integer): Integer; static;
    class function HitTest(const X, AvailableWidth, ATabCount: Integer): TPadTabHit; static;
    class function TabIndexAt(const X, TabWidth, ATabCount: Integer): Integer; static;
  end;

implementation

class function TPadTabLayout.ComputeTabWidth(const AvailableWidth, ATabCount: Integer): Integer;
begin
  if ATabCount <= 0 then
    Exit(0);

  var Avail := AvailableWidth - PlusButtonWidth;
  if Avail < 0 then
    Avail := 0;

  Result := Avail div ATabCount;

  if Result > MaxTabWidth then
    Result := MaxTabWidth
  else if Result < MinTabWidth then
    Result := MinTabWidth;
end;

class function TPadTabLayout.ContentWidthFor(const AvailableWidth, ATabCount, TabWidth: Integer): Integer;
begin
  Result := ATabCount * TabWidth + PlusButtonWidth;
  if Result > AvailableWidth then
    Result := AvailableWidth;
end;

class function TPadTabLayout.TabIndexAt(const X, TabWidth, ATabCount: Integer): Integer;
begin
  if (ATabCount <= 0) or (TabWidth <= 0) then
    Exit(-1);

  Result := X div TabWidth;
  if Result < 0 then
    Result := 0
  else if Result > ATabCount - 1 then
    Result := ATabCount - 1;
end;

class function TPadTabLayout.HitTest(const X, AvailableWidth, ATabCount: Integer): TPadTabHit;
begin
  Result.Kind := TPadTabHitKind.None;
  Result.Index := -1;

  if (ATabCount <= 0) or (X < 0) then
    Exit;

  const TabWidth = ComputeTabWidth(AvailableWidth, ATabCount);
  const Content = ContentWidthFor(AvailableWidth, ATabCount, TabWidth);
  const PlusLeft = Content - PlusButtonWidth;

  if X >= PlusLeft then
  begin
    if X < Content then
      Result.Kind := TPadTabHitKind.Plus;
    Exit;
  end;

  if TabWidth <= 0 then
    Exit;

  var Index := X div TabWidth;
  if Index > ATabCount - 1 then
    Index := ATabCount - 1;

  const TabRight = (Index + 1) * TabWidth;
  const CloseRight = TabRight - CloseRightMargin;
  const CloseLeft = CloseRight - CloseButtonSize;

  if (X >= CloseLeft) and (X < CloseRight) then
    Result.Kind := TPadTabHitKind.Close
  else
    Result.Kind := TPadTabHitKind.Tab;

  Result.Index := Index;
end;

end.
