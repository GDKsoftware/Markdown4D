unit Markdown4D.Tests.ObservedClipboard;

{$SCOPEDENUMS ON}

interface

uses
  Vcl.Clipbrd;

type
  // The real clipboard, watched: it counts the opens that came through and
  // the ones it refused, and refuses the next FailingOpens opens as the VCL
  // does while another process holds the clipboard. SetClipboard puts it in
  // place of the VCL's own.
  //
  // There is one for the whole test run, never freed, as the VCL keeps its own.
  // Without an application window, as in a console test runner, the VCL makes a
  // window for every open and keeps it when another process refuses the open.
  // That window calls this clipboard when Windows sends it a message, such as
  // when a later test activates a form, so the clipboard must outlive it.
  TObservedClipboard = class(TClipboard)
  private
    const
      FailureMessage = 'Opening the clipboard failed on purpose';
    class var
      FInstance: TObservedClipboard;
    var
      FFailingOpens: Integer;
      FOpenCount: Integer;
      FRefusedOpenCount: Integer;

  public
    class function Instance: TObservedClipboard; static;
    procedure Open; override;
    // Leaves the open count of TClipboard alone: a test that leaves the clipboard
    // open passes that on to the next one, so close it in a try..finally.
    procedure ResetCounts;
    property FailingOpens: Integer read FFailingOpens write FFailingOpens;
    property OpenCount: Integer read FOpenCount;
    property RefusedOpenCount: Integer read FRefusedOpenCount;
  end;

implementation

class function TObservedClipboard.Instance: TObservedClipboard;
begin
  if not Assigned(FInstance) then
  begin
    FInstance := TObservedClipboard.Create;
    {$WARN SYMBOL_PLATFORM OFF}
    RegisterExpectedMemoryLeak(FInstance);
    {$WARN SYMBOL_PLATFORM DEFAULT}
  end;

  Result := FInstance;
end;

procedure TObservedClipboard.Open;
begin
  const ShouldFail = (FFailingOpens > 0);
  if ShouldFail then
  begin
    Dec(FFailingOpens);
    Inc(FRefusedOpenCount);
    raise EClipboardException.Create(FailureMessage);
  end;

  try
    inherited Open;
  except
    on EClipboardException do
    begin
      Inc(FRefusedOpenCount);
      raise;
    end;
  end;

  Inc(FOpenCount);
end;

procedure TObservedClipboard.ResetCounts;
begin
  FFailingOpens := 0;
  FOpenCount := 0;
  FRefusedOpenCount := 0;
end;

end.
