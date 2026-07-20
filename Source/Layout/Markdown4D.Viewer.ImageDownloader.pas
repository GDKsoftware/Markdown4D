unit Markdown4D.Viewer.ImageDownloader;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TMarkdownImageDownloadCompleted = reference to procedure(const Source: string; const Data: TBytes);

  TMarkdownImageDownloadFailed = reference to procedure(const Source: string);

  IMarkdownDownloaderLifetime = interface
    ['{5C8E2A17-4B96-4D30-8F2A-D1637E94C0B5}']
    function IsAlive: Boolean;
    procedure Shutdown;
  end;

  TMarkdownImageDownloader = class
  private
    const
      MaxConcurrentDownloads = 4;
      ConnectionTimeoutMilliseconds = 10000;
      ResponseTimeoutMilliseconds = 30000;
      HttpStatusOk = 200;
    type
      TPendingDownload = record
        Source: string;
        Url: string;
      end;
    var
      FLifetime: IMarkdownDownloaderLifetime;
      FGeneration: Integer;
      FActiveCount: Integer;
      FQueue: TQueue<TPendingDownload>;
      FOnCompleted: TMarkdownImageDownloadCompleted;
      FOnFailed: TMarkdownImageDownloadFailed;
    procedure PumpQueue;
    procedure BeginDownload(const Pending: TPendingDownload);
    class function TryFetch(const Url: string; const Lifetime: IMarkdownDownloaderLifetime;
      out Data: TBytes): Boolean;
    procedure HandleDownloadResult(const Generation: Integer; const Source: string; const Data: TBytes;
      const Succeeded: Boolean);

  public
    constructor Create(const OnCompleted: TMarkdownImageDownloadCompleted;
      const OnFailed: TMarkdownImageDownloadFailed);
    destructor Destroy; override;
    procedure Download(const Source, Url: string);
    procedure CancelPending;
  end;

implementation

uses
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.Net.HttpClient;

type
  TMarkdownDownloaderLifetime = class(TInterfacedObject, IMarkdownDownloaderLifetime)
  private
    const
      StateAlive = 0;
      StateShutdown = 1;
    var
      FShutdownState: Int64;

  public
    function IsAlive: Boolean;
    procedure Shutdown;
  end;

function TMarkdownDownloaderLifetime.IsAlive: Boolean;
begin
  Result := TInterlocked.Read(FShutdownState) = StateAlive;
end;

procedure TMarkdownDownloaderLifetime.Shutdown;
begin
  TInterlocked.Exchange(FShutdownState, StateShutdown);
end;

constructor TMarkdownImageDownloader.Create(const OnCompleted: TMarkdownImageDownloadCompleted;
  const OnFailed: TMarkdownImageDownloadFailed);
begin
  inherited Create;

  FLifetime := TMarkdownDownloaderLifetime.Create;
  FQueue := TQueue<TPendingDownload>.Create;
  FOnCompleted := OnCompleted;
  FOnFailed := OnFailed;
end;

destructor TMarkdownImageDownloader.Destroy;
begin
  FLifetime.Shutdown;
  FQueue.Free;

  inherited Destroy;
end;

procedure TMarkdownImageDownloader.Download(const Source, Url: string);
begin
  var Pending := Default(TPendingDownload);
  Pending.Source := Source;
  Pending.Url := Url;
  FQueue.Enqueue(Pending);

  PumpQueue;
end;

procedure TMarkdownImageDownloader.CancelPending;
begin
  Inc(FGeneration);
  FQueue.Clear;
end;

procedure TMarkdownImageDownloader.PumpQueue;
begin
  while (FActiveCount < MaxConcurrentDownloads) and (FQueue.Count > 0) do
  begin
    BeginDownload(FQueue.Dequeue);
  end;
end;

procedure TMarkdownImageDownloader.BeginDownload(const Pending: TPendingDownload);
begin
  Inc(FActiveCount);

  const Lifetime = FLifetime;
  const Generation = FGeneration;
  const Source = Pending.Source;
  const Url = Pending.Url;
  TTask.Run(
    procedure
    begin
      var Data: TBytes := nil;
      const Succeeded = TryFetch(Url, Lifetime, Data);

      TThread.Queue(nil,
        procedure
        begin
          if Lifetime.IsAlive then
            HandleDownloadResult(Generation, Source, Data, Succeeded);
        end);
    end);
end;

class function TMarkdownImageDownloader.TryFetch(const Url: string;
  const Lifetime: IMarkdownDownloaderLifetime; out Data: TBytes): Boolean;
begin
  Data := nil;
  try
    const Client = THTTPClient.Create;
    try
      Client.ConnectionTimeout := ConnectionTimeoutMilliseconds;
      Client.ResponseTimeout := ResponseTimeoutMilliseconds;
      Client.ReceiveDataCallback :=
        procedure(const Sender: TObject; ContentLength, ReadCount: Int64; var ShouldAbort: Boolean)
        begin
          ShouldAbort := not Lifetime.IsAlive;
        end;

      const Content = TBytesStream.Create;
      try
        const Response = Client.Get(Url, Content);
        const IsUsable = (Response.StatusCode = HttpStatusOk) and (Content.Size > 0);
        if not IsUsable then
          Exit(False);

        Data := Copy(Content.Bytes, 0, Content.Size);
        Result := True;
      finally
        Content.Free;
      end;
    finally
      Client.Free;
    end;
  except
    on E: Exception do
      Result := False;
  end;
end;

procedure TMarkdownImageDownloader.HandleDownloadResult(const Generation: Integer; const Source: string;
  const Data: TBytes; const Succeeded: Boolean);
begin
  Dec(FActiveCount);

  const IsCurrent = (Generation = FGeneration);
  if IsCurrent then
  begin
    if Succeeded then
      FOnCompleted(Source, Data)
    else
      FOnFailed(Source);
  end;

  PumpQueue;
end;

end.
