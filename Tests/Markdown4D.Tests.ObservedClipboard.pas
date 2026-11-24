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
  TObservedClipboard = class(TClipboard)
  private
    const
      FailureMessage = 'Opening the clipboard failed on purpose';
    var
      FFailingOpens: Integer;
      FOpenCount: Integer;
      FRefusedOpenCount: Integer;

  public
    procedure Open; override;
    property FailingOpens: Integer read FFailingOpens write FFailingOpens;
    property OpenCount: Integer read FOpenCount;
    property RefusedOpenCount: Integer read FRefusedOpenCount;
  end;

implementation

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

end.
