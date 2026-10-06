unit Markdown4D.Tests.FmxClipboard;

{$SCOPEDENUMS ON}

interface

uses
  System.Rtti,
  FMX.Platform;

type
  // In-memory clipboard so the copy, cut and paste tests never touch the real
  // clipboard, which is a shared resource and makes them flaky under contention.
  TFakeClipboardService = class(TInterfacedObject, IFMXClipboardService)
  private
    FValue: TValue;

  public
    procedure SetClipboard(Value: TValue);
    function GetClipboard: TValue;
  end;

  // Puts the fake in place of the platform clipboard for one test and puts the
  // platform clipboard back afterwards.
  TFmxClipboardSwap = record
  private
    FSaved: IFMXClipboardService;
    FReplaced: Boolean;

  public
    procedure Replace;
    procedure Restore;
    function Text: string;
  end;

implementation

procedure TFakeClipboardService.SetClipboard(Value: TValue);
begin
  FValue := Value;
end;

function TFakeClipboardService.GetClipboard: TValue;
begin
  Result := FValue;
end;

procedure TFmxClipboardSwap.Replace;
begin
  var Existing: IFMXClipboardService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Existing) then
  begin
    FSaved := Existing;
    TPlatformServices.Current.RemovePlatformService(IFMXClipboardService);
  end;

  TPlatformServices.Current.AddPlatformService(IFMXClipboardService, TFakeClipboardService.Create);
  FReplaced := True;
end;

procedure TFmxClipboardSwap.Restore;
begin
  if not FReplaced then
    Exit;

  TPlatformServices.Current.RemovePlatformService(IFMXClipboardService);

  if FSaved <> nil then
    TPlatformServices.Current.AddPlatformService(IFMXClipboardService, FSaved);

  FSaved := nil;
  FReplaced := False;
end;

function TFmxClipboardSwap.Text: string;
begin
  var Service: IFMXClipboardService;
  TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Service);
  Result := Service.GetClipboard.ToString;
end;

end.
