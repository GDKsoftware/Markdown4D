unit Markdown4D.Layout.ResizePacer;

{$SCOPEDENUMS ON}

interface

type
  // Decides whether a new width is laid out at once or once the width stops
  // changing. While a splitter or a window edge is dragged the width changes
  // on every pixel; a document whose layout takes longer than a frame would
  // otherwise lay out over and over and lag behind the mouse. A quick layout
  // keeps following the width live. A held mouse button means the drag goes
  // on, however long the pointer rests.
  TMarkdownResizePacer = record
  public
    const
      LiveLayoutMilliseconds = 40;
      SettleMilliseconds = 150;

  private
    FWaiting: Boolean;
    FLastChange: Int64;

  public
    function TryReflowNow(const NowMilliseconds, LastLayoutMilliseconds: Int64): Boolean;
    function TryFlush(const NowMilliseconds: Int64; const IsPointerHeld: Boolean): Boolean;
    function IsWaiting: Boolean;
  end;

implementation

function TMarkdownResizePacer.TryReflowNow(const NowMilliseconds, LastLayoutMilliseconds: Int64): Boolean;
begin
  Result := (LastLayoutMilliseconds <= LiveLayoutMilliseconds);
  FWaiting := not Result;
  FLastChange := NowMilliseconds;
end;

function TMarkdownResizePacer.TryFlush(const NowMilliseconds: Int64; const IsPointerHeld: Boolean): Boolean;
begin
  const IsSettled = ((NowMilliseconds - FLastChange >= SettleMilliseconds) and not IsPointerHeld);
  Result := FWaiting and IsSettled;
  if Result then
    FWaiting := False;
end;

function TMarkdownResizePacer.IsWaiting: Boolean;
begin
  Result := FWaiting;
end;

end.
