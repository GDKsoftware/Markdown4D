unit Markdown4D.Export.ImageWait;

{$SCOPEDENUMS ON}

// Waits, on the main thread, until the images of a document have arrived. The
// pump hands control to whatever delivers them; a download comes in through
// TThread.Queue, so a viewer pumps with CheckSynchronize.

interface

uses
  System.SysUtils;

type
  TMarkdownExportImageWait = class
  private
    const
      MissingConditionMessage = 'Waiting for images needs a condition to wait for';
      MissingPumpMessage = 'Waiting for images needs a pump that lets them arrive';
    class procedure GuardArguments(const IsDone: TFunc<Boolean>; const Pump: TProc); static;

  public
    const
      DefaultImageTimeoutMilliseconds = 10000;
    // True once IsDone holds; False when the time ran out first.
    class function WaitUntil(const IsDone: TFunc<Boolean>; const TimeoutMilliseconds: Cardinal;
      const Pump: TProc): Boolean; static;
  end;

implementation

uses
  System.Diagnostics,
  Markdown4D.Export.Pdf.Errors;

class function TMarkdownExportImageWait.WaitUntil(const IsDone: TFunc<Boolean>; const TimeoutMilliseconds: Cardinal;
  const Pump: TProc): Boolean;
begin
  GuardArguments(IsDone, Pump);

  const Watch = TStopwatch.StartNew;
  while not IsDone() do
  begin
    const IsTimedOut = (Watch.ElapsedMilliseconds >= TimeoutMilliseconds);
    if IsTimedOut then
    begin
      Result := False;
      Exit;
    end;

    Pump();
  end;

  Result := True;
end;

class procedure TMarkdownExportImageWait.GuardArguments(const IsDone: TFunc<Boolean>; const Pump: TProc);
begin
  if not Assigned(IsDone) then
    raise EMarkdownPdfExportError.Create(MissingConditionMessage);

  if not Assigned(Pump) then
    raise EMarkdownPdfExportError.Create(MissingPumpMessage);
end;

end.
