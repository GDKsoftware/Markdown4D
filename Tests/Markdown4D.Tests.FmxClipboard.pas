unit Markdown4D.Tests.FmxClipboard;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Rtti,
  FMX.Platform;

type
  EFakeClipboardFailure = class(Exception);

  // In-memory clipboard so the copy, cut and paste tests never touch the real
  // clipboard, which is a shared resource and makes them flaky under contention.
  TFakeClipboardService = class(TInterfacedObject, IFMXClipboardService)
  private
    const
      FailureMessage = 'The clipboard failed on purpose';
    var
      FValue: TValue;
      FWriteCount: Integer;
      FReadCount: Integer;
      FLostWrites: Integer;
      FEmptyReads: Integer;
      FFailingWrites: Integer;
      FFailingReads: Integer;
      FFailure: TProc;
    procedure RaiseFailure;

  public
    procedure SetClipboard(Value: TValue);
    function GetClipboard: TValue;
    property WriteCount: Integer read FWriteCount;
    property ReadCount: Integer read FReadCount;
    // The next writes that do not arrive and the next reads that give an empty
    // text, as with the clipboard service FMX has for Windows while another
    // program holds the clipboard.
    property LostWrites: Integer read FLostWrites write FLostWrites;
    property EmptyReads: Integer read FEmptyReads write FEmptyReads;
    // The next writes and reads that raise, as a clipboard service may when
    // the platform refuses it the clipboard.
    property FailingWrites: Integer read FFailingWrites write FFailingWrites;
    property FailingReads: Integer read FFailingReads write FFailingReads;
    // Raises what those raise; EFakeClipboardFailure when left unassigned.
    property Failure: TProc read FFailure write FFailure;
  end;

  // Puts the fake in place of the platform clipboard for one test and puts the
  // platform clipboard back afterwards.
  TFmxClipboardSwap = record
  private
    FSaved: IFMXClipboardService;
    FReplaced: Boolean;

  public
    procedure Replace; overload;
    // Puts Fake in place of the platform clipboard, for a fake of another kind.
    procedure Replace(const Fake: TFakeClipboardService); overload;
    procedure Restore;
    function Text: string;
    // How often the fake was written since it took the platform's place.
    function WriteCount: Integer;
    function Fake: TFakeClipboardService;
  end;

implementation

procedure TFakeClipboardService.SetClipboard(Value: TValue);
begin
  Inc(FWriteCount);

  if FFailingWrites > 0 then
  begin
    Dec(FFailingWrites);
    RaiseFailure;
  end;

  if FLostWrites > 0 then
  begin
    Dec(FLostWrites);
    Exit;
  end;

  FValue := Value;
end;

function TFakeClipboardService.GetClipboard: TValue;
begin
  Inc(FReadCount);

  if FFailingReads > 0 then
  begin
    Dec(FFailingReads);
    RaiseFailure;
  end;

  if FEmptyReads > 0 then
  begin
    Dec(FEmptyReads);
    Result := TValue.From<string>('');
    Exit;
  end;

  Result := FValue;
end;

procedure TFakeClipboardService.RaiseFailure;
begin
  if Assigned(FFailure) then
    FFailure();

  raise EFakeClipboardFailure.Create(FailureMessage);
end;

procedure TFmxClipboardSwap.Replace;
begin
  Replace(TFakeClipboardService.Create);
end;

procedure TFmxClipboardSwap.Replace(const Fake: TFakeClipboardService);
begin
  var Existing: IFMXClipboardService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Existing) then
  begin
    FSaved := Existing;
    TPlatformServices.Current.RemovePlatformService(IFMXClipboardService);
  end;

  TPlatformServices.Current.AddPlatformService(IFMXClipboardService, Fake);
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

function TFmxClipboardSwap.WriteCount: Integer;
begin
  Result := Fake.WriteCount;
end;

function TFmxClipboardSwap.Fake: TFakeClipboardService;
begin
  var Service: IFMXClipboardService;
  TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Service);
  Result := Service as TFakeClipboardService;
end;

end.
